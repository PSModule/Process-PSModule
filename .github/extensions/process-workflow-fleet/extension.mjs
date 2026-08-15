import { dirname } from "node:path";
import { fileURLToPath } from "node:url";

import {
    CanvasError,
    createCanvas,
    joinSession,
} from "@github/copilot-sdk/extension";

import {
    createFleetService,
    resolveRepositoryRoot,
} from "./fleet-service.mjs";

const moduleDirectory = dirname(fileURLToPath(import.meta.url));
const repositoryRoot = resolveRepositoryRoot({
    currentWorkingDirectory: process.cwd(),
    moduleDirectory,
});

let session;
const fleet = createFleetService({
    getSession: () => session,
    repositoryRoot,
});

const canvas = createCanvas({
    id: "process-workflow-fleet",
    displayName: "Process workflow fleet",
    description:
        "Inspect Process-PSModule caller workflows, compare them with the v8 contract, and request repository-scoped migrations.",
    inputSchema: {
        type: "object",
        additionalProperties: false,
        properties: {
            organization: {
                type: "string",
                minLength: 1,
                maxLength: 100,
                pattern: "^[A-Za-z0-9][A-Za-z0-9-]*$",
            },
        },
    },
    actions: [
        {
            name: "refresh_inventory",
            description:
                "Refresh the authenticated GitHub inventory and replace prior canvas data fail-closed.",
            inputSchema: {
                type: "object",
                additionalProperties: false,
                properties: {
                    organization: {
                        type: "string",
                        minLength: 1,
                        maxLength: 100,
                        pattern: "^[A-Za-z0-9][A-Za-z0-9-]*$",
                    },
                    repositories: {
                        type: "array",
                        uniqueItems: true,
                        maxItems: 500,
                        items: {
                            type: "string",
                            minLength: 1,
                            maxLength: 200,
                            pattern:
                                "^[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)?$",
                        },
                    },
                    includeArchived: {
                        type: "boolean",
                    },
                },
            },
            handler: async (ctx) => fleet.refreshInventory(ctx.input ?? {}),
        },
        {
            name: "get_summary",
            description:
                "Return refresh health and v8 compliance counts for the current workspace inventory.",
            inputSchema: {
                type: "object",
                additionalProperties: false,
                properties: {},
            },
            handler: async () => fleet.getSummary(),
        },
        {
            name: "get_repository",
            description:
                "Return normalized workflow evidence and the migration delta for one repository.",
            inputSchema: {
                type: "object",
                additionalProperties: false,
                required: ["repository"],
                properties: {
                    repository: {
                        type: "string",
                        minLength: 1,
                        maxLength: 200,
                    },
                },
            },
            handler: async (ctx) => fleet.getRepository(ctx.input.repository),
        },
        {
            name: "set_selection",
            description:
                "Persist the selected repository identities for this session workspace.",
            inputSchema: {
                type: "object",
                additionalProperties: false,
                required: ["repositories"],
                properties: {
                    repositories: {
                        type: "array",
                        uniqueItems: true,
                        maxItems: 500,
                        items: {
                            type: "string",
                            minLength: 1,
                            maxLength: 200,
                        },
                    },
                },
            },
            handler: async (ctx) => fleet.setSelection(ctx.input.repositories),
        },
        {
            name: "request_migration",
            description:
                "Preview or confirm an agent-orchestrated migration request for selected repositories; never mutates repositories directly.",
            inputSchema: {
                type: "object",
                additionalProperties: false,
                properties: {
                    repositories: {
                        type: "array",
                        uniqueItems: true,
                        maxItems: 500,
                        items: {
                            type: "string",
                            minLength: 1,
                            maxLength: 200,
                        },
                    },
                    dryRun: {
                        type: "boolean",
                    },
                    confirmed: {
                        type: "boolean",
                    },
                },
            },
            handler: async (ctx) => fleet.requestMigration(ctx.input ?? {}),
        },
    ],
    open: async (ctx) => {
        const entry = await fleet.openPanel(ctx.instanceId, {
            organization: ctx.input?.organization,
        });
        return {
            title: "Process workflow fleet",
            status: "Inventory updates automatically",
            url: entry.url,
        };
    },
    onClose: async (ctx) => {
        await fleet.closePanel(ctx.instanceId);
    },
});

session = await joinSession({
    canvases: [canvas],
});

fleet.setCanvasErrorFactory((code, message) => new CanvasError(code, message));
