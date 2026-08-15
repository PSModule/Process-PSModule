import { execFile, execFileSync } from "node:child_process";
import { createHash, randomBytes } from "node:crypto";
import {
    mkdir,
    readFile,
    rename,
    rm,
    writeFile,
} from "node:fs/promises";
import { createServer } from "node:http";
import { tmpdir } from "node:os";
import {
    dirname,
    isAbsolute,
    join,
    resolve,
} from "node:path";
import { promisify } from "node:util";

import {
    analyzeInventory,
    buildMigrationPrompt,
    buildMigrationRequest,
    getSummary,
    normalizeInventory,
} from "./fleet-model.mjs";
import { renderDashboard } from "./renderer.mjs";

const execFileAsync = promisify(execFile);
const STATE_VERSION = 1;
const MAX_REQUEST_BYTES = 1024 * 1024;
const servers = new Map();
const refreshes = new Map();

let createCanvasError = (code, message) => {
    const error = new Error(message);
    error.code = code;
    return error;
};

function pathLooksLikeRepository(candidate) {
    try {
        const root = execFileSync(
            "git",
            ["-C", candidate, "rev-parse", "--show-toplevel"],
            {
                encoding: "utf8",
                stdio: ["ignore", "pipe", "ignore"],
            },
        ).trim();
        return root || null;
    } catch (error) {
        if (
            error &&
            typeof error === "object" &&
            hasOwn(error, "status") &&
            error.status !== 0
        ) {
            return null;
        }
        throw error;
    }
}

function hasOwn(value, property) {
    return (
        value !== null &&
        typeof value === "object" &&
        Object.prototype.hasOwnProperty.call(value, property)
    );
}

export function resolveRepositoryRoot({
    currentWorkingDirectory,
    moduleDirectory,
    sessionWorkspacePath,
} = {}) {
    const candidates = [
        currentWorkingDirectory,
        process.env.GITHUB_WORKSPACE,
        process.env.COPILOT_WORKSPACE_PATH,
        sessionWorkspacePath,
        moduleDirectory,
    ].filter(Boolean);

    for (const candidate of candidates) {
        const root = pathLooksLikeRepository(resolve(candidate));
        if (root) {
            return root;
        }
    }

    throw new Error(
        `Could not locate the repository root from: ${candidates.join(", ")}.`,
    );
}

function workspaceIdentity(repositoryRoot) {
    return createHash("sha256")
        .update(resolve(repositoryRoot).toLowerCase())
        .digest("hex")
        .slice(0, 16);
}

function sanitizeDiagnostic(value) {
    return String(value ?? "")
        .replace(
            /\b(?:gh[opurs]_[A-Za-z0-9_]+|github_pat_[A-Za-z0-9_]+)\b/g,
            "[REDACTED_TOKEN]",
        )
        .replace(
            /(GH_TOKEN|GITHUB_TOKEN|PSGALLERY_API_KEY)\s*[:=]\s*\S+/gi,
            "$1=[REDACTED]",
        )
        .trim();
}

function initialState(repositoryRoot, organization = "PSModule") {
    return {
        stateVersion: STATE_VERSION,
        workspaceIdentity: workspaceIdentity(repositoryRoot),
        repositoryRoot,
        organization,
        inventoryStatus: "not-refreshed",
        generatedAt: null,
        command: null,
        error: null,
        records: [],
        selection: [],
    };
}

function responseJson(response, statusCode, value) {
    response.writeHead(statusCode, {
        "Cache-Control": "no-store",
        "Content-Type": "application/json; charset=utf-8",
        "X-Content-Type-Options": "nosniff",
    });
    response.end(JSON.stringify(value));
}

function responseHtml(response, html) {
    response.writeHead(200, {
        "Cache-Control": "no-store",
        "Content-Security-Policy":
            "default-src 'self'; connect-src 'self'; img-src 'self' data:; object-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; base-uri 'none'; frame-ancestors 'self'",
        "Content-Type": "text/html; charset=utf-8",
        "Referrer-Policy": "no-referrer",
        "X-Content-Type-Options": "nosniff",
    });
    response.end(html);
}

async function readRequestJson(request) {
    let size = 0;
    const chunks = [];
    for await (const chunk of request) {
        size += chunk.length;
        if (size > MAX_REQUEST_BYTES) {
            throw createCanvasError(
                "request_too_large",
                `Canvas request exceeds ${MAX_REQUEST_BYTES} bytes.`,
            );
        }
        chunks.push(chunk);
    }
    if (chunks.length === 0) {
        return {};
    }
    try {
        return JSON.parse(Buffer.concat(chunks).toString("utf8"));
    } catch (error) {
        throw createCanvasError(
            "request_json_invalid",
            `Canvas request JSON is invalid: ${sanitizeDiagnostic(error.message)}`,
        );
    }
}

function requireCanvasToken(request, token) {
    if (request.headers["x-canvas-token"] !== token) {
        throw createCanvasError(
            "canvas_request_forbidden",
            "Canvas request token is missing or invalid.",
        );
    }
}

async function closeHttpServer(server) {
    await new Promise((resolveClose, rejectClose) => {
        server.close((error) => {
            if (error) {
                rejectClose(error);
            } else {
                resolveClose();
            }
        });
    });
}

export function createFleetService({ getSession, repositoryRoot }) {
    const identity = workspaceIdentity(repositoryRoot);

    function stateDirectory() {
        const sessionWorkspacePath = getSession()?.workspacePath;
        if (sessionWorkspacePath) {
            return join(
                sessionWorkspacePath,
                "files",
                "process-workflow-fleet",
                identity,
            );
        }
        return join(tmpdir(), "copilot-process-workflow-fleet", identity);
    }

    function statePath() {
        return join(stateDirectory(), "state.json");
    }

    function inventoryPath() {
        return join(stateDirectory(), "inventory.json");
    }

    async function writeState(state) {
        const directory = stateDirectory();
        await mkdir(directory, { recursive: true });
        const path = statePath();
        const temporaryPath = `${path}.${process.pid}.${randomBytes(6).toString("hex")}.tmp`;
        try {
            await writeFile(
                temporaryPath,
                `${JSON.stringify(state, null, 2)}\n`,
                "utf8",
            );
            await rename(temporaryPath, path);
        } finally {
            await rm(temporaryPath, { force: true });
        }
        return state;
    }

    async function readState() {
        try {
            const state = JSON.parse(await readFile(statePath(), "utf8"));
            if (
                state.stateVersion !== STATE_VERSION ||
                state.workspaceIdentity !== identity
            ) {
                throw new Error(
                    `Unsupported or mismatched state at ${statePath()}.`,
                );
            }
            return state;
        } catch (error) {
            if (error?.code === "ENOENT") {
                return null;
            }
            throw createCanvasError(
                "fleet_state_read_failed",
                `Could not read workflow fleet state at ${statePath()}: ${sanitizeDiagnostic(error.message)}`,
            );
        }
    }

    async function ensureState({ organization } = {}) {
        const existing = await readState();
        if (existing) {
            if (organization && organization !== existing.organization) {
                return writeState({
                    ...initialState(repositoryRoot, organization),
                    selection: [],
                });
            }
            return existing;
        }
        return writeState(initialState(repositoryRoot, organization));
    }

    function inventoryCommand(input, outputPath) {
        const organization = input.organization || "PSModule";
        const scriptPath = join(
            repositoryRoot,
            ".github",
            "scripts",
            "Get-ProcessPSModuleWorkflowInventory.ps1",
        );
        if (!isAbsolute(scriptPath)) {
            throw createCanvasError(
                "inventory_script_path_invalid",
                `Inventory script path is not absolute: ${scriptPath}`,
            );
        }
        const args = [
            "-NoLogo",
            "-NoProfile",
            "-File",
            scriptPath,
            "-Organization",
            organization,
        ];
        if (input.repositories?.length) {
            args.push("-Repository", ...input.repositories);
        }
        args.push("-TargetReference", "v8", "-JsonPath", outputPath);
        if (input.includeArchived === true) {
            args.push("-IncludeArchived");
        }
        return {
            executable: "pwsh",
            args,
            organization,
            repositories: input.repositories ?? [],
            display: `pwsh -NoLogo -NoProfile -File ${scriptPath} -Organization ${organization}${input.repositories?.length ? ` -Repository ${input.repositories.join(",")}` : ""} -TargetReference v8 -JsonPath ${outputPath}${input.includeArchived ? " -IncludeArchived" : ""}`,
        };
    }

    async function loadGeneratedInventory() {
        const content = await readFile(inventoryPath(), "utf8");
        const parsed = JSON.parse(content.replace(/^\uFEFF/, ""));
        const records = analyzeInventory(normalizeInventory(parsed));
        if (records.length === 0) {
            throw new Error(
                `Inventory command wrote no workflow records to ${inventoryPath()}.`,
            );
        }
        return records;
    }

    async function refreshInventory(input = {}) {
        if (refreshes.has(identity)) {
            throw createCanvasError(
                "inventory_refresh_in_progress",
                "A workflow inventory refresh is already running for this workspace.",
            );
        }

        const refresh = (async () => {
            const previous = await ensureState({
                organization: input.organization,
            });
            const command = inventoryCommand(
                {
                    ...input,
                    organization: input.organization || previous.organization,
                },
                inventoryPath(),
            );
            await rm(inventoryPath(), { force: true });
            await writeState({
                ...previous,
                organization: command.organization,
                inventoryStatus: "refreshing",
                generatedAt: null,
                command: command.display,
                error: null,
                records: [],
                selection: [],
            });

            try {
                await execFileAsync(command.executable, command.args, {
                    cwd: repositoryRoot,
                    encoding: "utf8",
                    maxBuffer: 10 * 1024 * 1024,
                    windowsHide: true,
                });
                const records = await loadGeneratedInventory();
                const state = await writeState({
                    ...previous,
                    organization: command.organization,
                    inventoryStatus: "ready",
                    generatedAt: new Date().toISOString(),
                    command: command.display,
                    error: null,
                    records,
                    selection: [],
                });
                return {
                    summary: getSummary(state),
                    artifactPath: inventoryPath(),
                };
            } catch (error) {
                let records = [];
                try {
                    records = await loadGeneratedInventory();
                } catch (artifactError) {
                    if (artifactError?.code !== "ENOENT") {
                        error.message = `${error.message}; generated inventory could not be read: ${artifactError.message}`;
                    }
                }

                const diagnostic = sanitizeDiagnostic(
                    error.stderr || error.stdout || error.message,
                );
                const failure = await writeState({
                    ...previous,
                    organization: command.organization,
                    inventoryStatus: "failed",
                    generatedAt: new Date().toISOString(),
                    command: command.display,
                    error: {
                        code: "inventory_refresh_failed",
                        message: diagnostic,
                        organization: command.organization,
                        repositories: command.repositories,
                    },
                    records,
                    selection: [],
                });
                getSession()?.log(
                    `Process workflow fleet refresh failed for ${command.organization}: ${diagnostic}`,
                    { level: "error", ephemeral: false },
                );
                throw createCanvasError(
                    "inventory_refresh_failed",
                    `Inventory command failed for ${command.organization}: ${diagnostic}. State: ${statePath()}`,
                );
            }
        })();

        refreshes.set(identity, refresh);
        try {
            return await refresh;
        } finally {
            refreshes.delete(identity);
        }
    }

    async function getSummaryResult() {
        return getSummary(await ensureState());
    }

    async function getRepository(repository) {
        const state = await ensureState();
        const record = state.records.find(
            (item) => item.repository === repository,
        );
        if (!record) {
            throw createCanvasError(
                "repository_not_found",
                `Repository [${repository}] is not present in the current inventory.`,
            );
        }
        return record;
    }

    async function setSelection(repositories) {
        const state = await ensureState();
        if (state.inventoryStatus !== "ready") {
            throw createCanvasError(
                "inventory_not_ready",
                "Refresh inventory successfully before selecting repositories.",
            );
        }
        const known = new Set(state.records.map((record) => record.repository));
        const unknown = repositories.filter((repository) => !known.has(repository));
        if (unknown.length > 0) {
            throw createCanvasError(
                "selection_repository_unknown",
                `Selection contains repositories outside the current inventory: ${unknown.join(", ")}.`,
            );
        }
        const selection = [...new Set(repositories)].sort();
        await writeState({
            ...state,
            selection,
        });
        return {
            repositories: selection,
            count: selection.length,
        };
    }

    async function requestMigration({
        repositories,
        dryRun = true,
        confirmed = false,
    } = {}) {
        const state = await ensureState();
        if (state.inventoryStatus !== "ready") {
            throw createCanvasError(
                "inventory_not_ready",
                "Migration requests require a successful current inventory refresh.",
            );
        }
        const selection = repositories ?? state.selection;
        if (!selection || selection.length === 0) {
            throw createCanvasError(
                "migration_selection_empty",
                "Select at least one repository before requesting migration.",
            );
        }
        const selected = selection.map((repository) => {
            const record = state.records.find(
                (item) => item.repository === repository,
            );
            if (!record) {
                throw createCanvasError(
                    "migration_repository_unknown",
                    `Repository [${repository}] is not present in the current inventory.`,
                );
            }
            return record;
        });

        let request;
        try {
            request = buildMigrationRequest(selected);
        } catch (error) {
            throw createCanvasError(
                "migration_inventory_incomplete",
                error.message,
            );
        }
        const prompt = buildMigrationPrompt(request);

        if (dryRun !== false) {
            return {
                dryRun: true,
                sent: false,
                request,
                prompt,
            };
        }
        if (confirmed !== true) {
            throw createCanvasError(
                "migration_confirmation_required",
                "Set confirmed to true only after the user explicitly confirms the migration request.",
            );
        }

        const activeSession = getSession();
        if (!activeSession) {
            throw createCanvasError(
                "session_unavailable",
                "The active Copilot session is not available for migration orchestration.",
            );
        }
        const messageId = await activeSession.send({ prompt });
        return {
            dryRun: false,
            sent: true,
            messageId,
            repositories: selection,
        };
    }

    async function handleHttpRequest(request, response, token, organization) {
        const url = new URL(request.url ?? "/", "http://127.0.0.1");
        if (request.method === "GET" && url.pathname === "/") {
            responseHtml(response, renderDashboard(token));
            return;
        }
        if (request.method === "GET" && url.pathname === "/api/state") {
            responseJson(response, 200, await ensureState({ organization }));
            return;
        }
        if (request.method !== "POST") {
            responseJson(response, 404, {
                error: {
                    code: "route_not_found",
                    message: `No canvas route for ${request.method} ${url.pathname}.`,
                },
            });
            return;
        }

        requireCanvasToken(request, token);
        const input = await readRequestJson(request);
        if (url.pathname === "/api/refresh") {
            responseJson(response, 200, await refreshInventory(input));
            return;
        }
        if (url.pathname === "/api/selection") {
            responseJson(
                response,
                200,
                await setSelection(input.repositories ?? []),
            );
            return;
        }
        if (url.pathname === "/api/migration") {
            responseJson(response, 200, await requestMigration(input));
            return;
        }
        responseJson(response, 404, {
            error: {
                code: "route_not_found",
                message: `No canvas route for POST ${url.pathname}.`,
            },
        });
    }

    async function openPanel(instanceId, { organization } = {}) {
        const existing = servers.get(instanceId);
        if (existing) {
            return existing;
        }

        const token = randomBytes(24).toString("base64url");
        const server = createServer((request, response) => {
            handleHttpRequest(request, response, token, organization).catch(
                (error) => {
                    const code = error.code || "canvas_http_failed";
                    const message = sanitizeDiagnostic(error.message);
                    getSession()?.log(
                        `Process workflow fleet request failed: ${message}`,
                        { level: "error", ephemeral: true },
                    );
                    if (!response.headersSent) {
                        responseJson(
                            response,
                            code === "route_not_found" ? 404 : 500,
                            {
                                error: { code, message },
                            },
                        );
                    } else {
                        response.end();
                    }
                },
            );
        });
        server.on("clientError", (error, socket) => {
            getSession()?.log(
                `Process workflow fleet HTTP client error: ${sanitizeDiagnostic(error.message)}`,
                { level: "warning", ephemeral: true },
            );
            socket.end("HTTP/1.1 400 Bad Request\r\n\r\n");
        });
        await new Promise((resolveListen, rejectListen) => {
            server.once("error", rejectListen);
            server.listen(0, "127.0.0.1", () => {
                server.off("error", rejectListen);
                resolveListen();
            });
        });
        const address = server.address();
        if (!address || typeof address === "string") {
            await closeHttpServer(server);
            throw createCanvasError(
                "canvas_server_address_invalid",
                "Loopback canvas server did not return a TCP address.",
            );
        }
        const entry = {
            server,
            token,
            url: `http://127.0.0.1:${address.port}/`,
        };
        servers.set(instanceId, entry);
        return entry;
    }

    async function closePanel(instanceId) {
        const entry = servers.get(instanceId);
        if (!entry) {
            return;
        }
        servers.delete(instanceId);
        await closeHttpServer(entry.server);
    }

    return {
        closePanel,
        ensureState,
        getRepository,
        getSummary: getSummaryResult,
        openPanel,
        refreshInventory,
        requestMigration,
        setCanvasErrorFactory(factory) {
            createCanvasError = factory;
        },
        setSelection,
    };
}
