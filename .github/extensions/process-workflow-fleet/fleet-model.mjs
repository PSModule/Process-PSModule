const EXPECTED_WORKFLOW_PATH = ".github/workflows/Process-PSModule.yml";
const EXPECTED_WORKFLOW_NAME = "Process-PSModule";
const EXPECTED_JOB_NAME = "Process-PSModule";
const EXPECTED_USES =
    "PSModule/Process-PSModule/.github/workflows/workflow.yml@v8";
const EXPECTED_CONCURRENCY_GROUP =
    "${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}";
const EXPECTED_CANCEL_IN_PROGRESS =
    "${{ github.event_name == 'pull_request' }}";

const REQUIRED_EVENTS = [
    "pull_request",
    "push",
    "schedule",
    "workflow_dispatch",
];
const REQUIRED_PULL_REQUEST_TYPES = [
    "closed",
    "labeled",
    "opened",
    "reopened",
    "synchronize",
    "unlabeled",
];
const REQUIRED_JOB_PERMISSIONS = {
    contents: "read",
    pages: "write",
    "id-token": "write",
};
const REQUIRED_SECRETS = {
    PSGALLERY_API_KEY: "${{ secrets.PSGALLERY_API_KEY }}",
    GitHubAppClientId: "${{ secrets.SHELLY_CLIENT_ID }}",
    GitHubAppPrivateKey: "${{ secrets.SHELLY_PRIVATE_KEY }}",
};
const OPTIONAL_INPUTS = new Set([
    "ImportantFilePatterns",
    "Prerelease",
    "SettingsPath",
    "Verbose",
    "Version",
    "WorkingDirectory",
]);
const OPTIONAL_SECRETS = new Set(["TestData"]);

const REQUIRED_RECORD_FIELDS = [
    "WorkflowName",
    "Events",
    "Schedules",
    "PushBranches",
    "PushBranchesIgnore",
    "PushPaths",
    "PushPathsIgnore",
    "PullRequestBranches",
    "PullRequestTypes",
    "PullRequestPaths",
    "PullRequestPathsIgnore",
    "ConcurrencyGroup",
    "CancelInProgress",
    "Permissions",
    "ProcessJobs",
    "AdditionalJobs",
];
const REQUIRED_JOB_FIELDS = [
    "Name",
    "Uses",
    "Reference",
    "Inputs",
    "SecretMode",
    "SecretMappings",
    "Permissions",
    "Condition",
];

export const TARGET_CONTRACT = Object.freeze({
    identity: {
        workflowPath: EXPECTED_WORKFLOW_PATH,
        workflowName: EXPECTED_WORKFLOW_NAME,
        jobName: EXPECTED_JOB_NAME,
    },
    triggers: {
        events: REQUIRED_EVENTS,
        scheduleRequired: true,
        pushBranches: ["main"],
        pullRequestBranches: ["main"],
        pullRequestTypes: REQUIRED_PULL_REQUEST_TYPES,
        pathFiltersAllowed: false,
    },
    concurrency: {
        group: EXPECTED_CONCURRENCY_GROUP,
        cancelInProgress: EXPECTED_CANCEL_IN_PROGRESS,
    },
    permissions: {
        workflow: {},
        job: REQUIRED_JOB_PERMISSIONS,
    },
    caller: {
        condition: null,
        uses: EXPECTED_USES,
        secrets: REQUIRED_SECRETS,
        optionalSecrets: [...OPTIONAL_SECRETS],
        optionalInputs: [...OPTIONAL_INPUTS].sort(),
        debugTrueAllowed: false,
    },
    additionalJobs: {
        allowed: true,
        boundaryReviewRequired: true,
    },
});

function hasOwn(value, property) {
    return (
        value !== null &&
        typeof value === "object" &&
        Object.prototype.hasOwnProperty.call(value, property)
    );
}

function toArray(value) {
    if (value === null || value === undefined) {
        return [];
    }
    return Array.isArray(value) ? value : [value];
}

function toObject(value) {
    if (
        value === null ||
        value === undefined ||
        Array.isArray(value) ||
        typeof value !== "object"
    ) {
        return {};
    }
    return { ...value };
}

function normalizedScalar(value) {
    if (value === null || value === undefined) {
        return null;
    }
    return typeof value === "string" ? value.trim() : value;
}

function normalizeJob(job, index) {
    const source = toObject(job);
    return {
        sourceIndex: index,
        sourceFields: Object.keys(source),
        name: normalizedScalar(source.Name),
        uses: normalizedScalar(source.Uses),
        reference: normalizedScalar(source.Reference),
        inputs: toObject(source.Inputs),
        secretMode: normalizedScalar(source.SecretMode),
        secretMappings: toObject(source.SecretMappings),
        permissions: source.Permissions,
        environment: source.Environment ?? null,
        condition: normalizedScalar(source.Condition),
    };
}

function normalizeRecord(record, index) {
    const source = toObject(record);
    const status = source.Status === "ParseError" ? "parse-error" : "parsed";
    return {
        sourceIndex: index,
        sourceFields: Object.keys(source),
        repository: normalizedScalar(source.Repository) ?? `unknown-${index + 1}`,
        defaultBranch: normalizedScalar(source.DefaultBranch),
        archived: source.Archived === true,
        repositoryUrl: normalizedScalar(source.RepositoryUrl),
        workflowPath: normalizedScalar(source.WorkflowPath),
        workflowUrl: normalizedScalar(source.WorkflowUrl),
        status,
        error: normalizedScalar(source.Error),
        workflowName: normalizedScalar(source.WorkflowName),
        runName: normalizedScalar(source.RunName),
        events: toArray(source.Events).map(String),
        schedules: toArray(source.Schedules).map(String),
        pushBranches: toArray(source.PushBranches).map(String),
        pushBranchesIgnore: toArray(source.PushBranchesIgnore).map(String),
        pushPaths: toArray(source.PushPaths).map(String),
        pushPathsIgnore: toArray(source.PushPathsIgnore).map(String),
        pullRequestBranches: toArray(source.PullRequestBranches).map(String),
        pullRequestTypes: toArray(source.PullRequestTypes).map(String),
        pullRequestPaths: toArray(source.PullRequestPaths).map(String),
        pullRequestPathsIgnore: toArray(source.PullRequestPathsIgnore).map(String),
        concurrencyGroup: normalizedScalar(source.ConcurrencyGroup),
        cancelInProgress: normalizedScalar(source.CancelInProgress),
        permissions: source.Permissions,
        processJobs: toArray(source.ProcessJobs).map(normalizeJob),
        additionalJobs: toArray(source.AdditionalJobs).map(String),
        versionComments: toArray(source.VersionComments).map((entry) => ({
            reference: normalizedScalar(entry?.Reference),
            version: normalizedScalar(entry?.Version),
        })),
    };
}

export function normalizeInventory(value) {
    const records = Array.isArray(value) ? value : value ? [value] : [];
    return records.map(normalizeRecord);
}

function stableJson(value) {
    if (Array.isArray(value)) {
        return JSON.stringify([...value].map(String).sort());
    }
    if (value !== null && typeof value === "object") {
        return JSON.stringify(
            Object.fromEntries(
                Object.entries(value)
                    .sort(([left], [right]) => left.localeCompare(right))
                    .map(([key, entry]) => [key, entry]),
            ),
        );
    }
    return JSON.stringify(value ?? null);
}

function equalArray(actual, expected) {
    return stableJson(actual) === stableJson(expected);
}

function equalObject(actual, expected) {
    return stableJson(toObject(actual)) === stableJson(expected);
}

function missingInventoryFields(record) {
    const missing = REQUIRED_RECORD_FIELDS.filter(
        (field) => !record.sourceFields.includes(field),
    );
    for (const job of record.processJobs) {
        for (const field of REQUIRED_JOB_FIELDS) {
            if (!job.sourceFields.includes(field)) {
                missing.push(`ProcessJobs[${job.sourceIndex}].${field}`);
            }
        }
    }
    return missing;
}

function addDelta(deltas, field, current, target, matches, instruction) {
    if (!matches) {
        deltas.push({
            field,
            current,
            target,
            instruction,
        });
    }
}

function isEmptyCondition(value) {
    return value === null || value === "";
}

function hasDebugTrue(inputs) {
    return Object.entries(inputs).some(
        ([key, value]) =>
            key.toLowerCase() === "debug" &&
            String(value).trim().toLowerCase() === "true",
    );
}

function compareSecrets(job, deltas) {
    addDelta(
        deltas,
        "job.secretMode",
        job.secretMode,
        "explicit",
        job.secretMode === "explicit",
        "Replace inherited or missing secrets with explicit mappings.",
    );

    for (const [name, target] of Object.entries(REQUIRED_SECRETS)) {
        addDelta(
            deltas,
            `job.secrets.${name}`,
            job.secretMappings[name] ?? null,
            target,
            job.secretMappings[name] === target,
            `Map ${name} to the agreed repository or organization secret.`,
        );
    }

    const unsupported = Object.keys(job.secretMappings).filter(
        (name) => !hasOwn(REQUIRED_SECRETS, name) && !OPTIONAL_SECRETS.has(name),
    );
    addDelta(
        deltas,
        "job.secrets.unsupported",
        unsupported,
        [],
        unsupported.length === 0,
        "Remove unsupported mappings after checking whether they belong in TestData.",
    );
}

function compareInputs(job, deltas, preservation) {
    const inputNames = Object.keys(job.inputs);
    if (hasOwn(job.inputs, "TestData")) {
        deltas.push({
            field: "job.inputs.TestData",
            current: job.inputs.TestData,
            target: "secret mapping named TestData",
            instruction:
                "Move test data to the optional TestData secret mapping without exposing values.",
        });
    }

    addDelta(
        deltas,
        "job.inputs.Debug",
        job.inputs.Debug ?? null,
        "omitted or false",
        !hasDebugTrue(job.inputs),
        "Remove Debug: true so the reusable workflow default remains false.",
    );

    const unsupported = inputNames.filter(
        (name) =>
            name !== "Debug" &&
            name !== "TestData" &&
            !OPTIONAL_INPUTS.has(name),
    );
    addDelta(
        deltas,
        "job.inputs.unsupported",
        unsupported,
        [],
        unsupported.length === 0,
        "Inspect unsupported inputs against the current reusable-workflow interface.",
    );

    for (const name of inputNames.filter((entry) => OPTIONAL_INPUTS.has(entry))) {
        preservation.push({
            field: `job.inputs.${name}`,
            value: job.inputs[name],
            instruction: `Preserve ${name} when it remains valid for this repository.`,
        });
    }
    if (hasOwn(job.secretMappings, "TestData")) {
        preservation.push({
            field: "job.secrets.TestData",
            value: job.secretMappings.TestData,
            instruction:
                "Preserve the TestData JSON mapping after verifying referenced secrets and variables.",
        });
    }
}

export function compareRepository(record) {
    if (record.status === "parse-error") {
        return {
            repository: record.repository,
            workflowPath: record.workflowPath,
            status: "parse-error",
            compliant: false,
            complete: false,
            requestReady: false,
            missingFields: [],
            deltas: [
                {
                    field: "inventory.parse",
                    current: record.error,
                    target: "a parsed workflow",
                    instruction:
                        "Fix or inspect the YAML parse error before planning migration.",
                },
            ],
            preservation: [],
            reviewWarnings: [],
        };
    }

    const missingFields = missingInventoryFields(record);
    const deltas = [];
    const preservation = [];
    const reviewWarnings = [];

    addDelta(
        deltas,
        "identity.workflowPath",
        record.workflowPath,
        EXPECTED_WORKFLOW_PATH,
        record.workflowPath === EXPECTED_WORKFLOW_PATH,
        "Use the standard caller workflow path.",
    );
    addDelta(
        deltas,
        "identity.workflowName",
        record.workflowName,
        EXPECTED_WORKFLOW_NAME,
        record.workflowName === EXPECTED_WORKFLOW_NAME,
        "Use the standard workflow name.",
    );
    addDelta(
        deltas,
        "triggers.events",
        record.events,
        REQUIRED_EVENTS,
        equalArray(record.events, REQUIRED_EVENTS),
        "Declare workflow_dispatch, schedule, push, and pull_request.",
    );
    addDelta(
        deltas,
        "triggers.schedule",
        record.schedules,
        "at least one schedule",
        record.schedules.length > 0,
        "Keep at least one repository-appropriate scheduled health run.",
    );
    addDelta(
        deltas,
        "triggers.push.branches",
        record.pushBranches,
        ["main"],
        equalArray(record.pushBranches, ["main"]),
        "Target the main branch for stable default-branch publication.",
    );
    addDelta(
        deltas,
        "triggers.push.filters",
        {
            branchesIgnore: record.pushBranchesIgnore,
            paths: record.pushPaths,
            pathsIgnore: record.pushPathsIgnore,
        },
        {},
        record.pushBranchesIgnore.length === 0 &&
            record.pushPaths.length === 0 &&
            record.pushPathsIgnore.length === 0,
        "Remove push filters that bypass reusable-workflow change evaluation.",
    );
    addDelta(
        deltas,
        "triggers.pullRequest.branches",
        record.pullRequestBranches,
        ["main"],
        equalArray(record.pullRequestBranches, ["main"]),
        "Target pull requests into main.",
    );
    addDelta(
        deltas,
        "triggers.pullRequest.types",
        record.pullRequestTypes,
        REQUIRED_PULL_REQUEST_TYPES,
        equalArray(record.pullRequestTypes, REQUIRED_PULL_REQUEST_TYPES),
        "Declare closed, opened, reopened, synchronize, labeled, and unlabeled.",
    );
    addDelta(
        deltas,
        "triggers.pullRequest.filters",
        {
            paths: record.pullRequestPaths,
            pathsIgnore: record.pullRequestPathsIgnore,
        },
        {},
        record.pullRequestPaths.length === 0 &&
            record.pullRequestPathsIgnore.length === 0,
        "Remove pull-request path filters that bypass Process-PSModule planning.",
    );
    addDelta(
        deltas,
        "concurrency.group",
        record.concurrencyGroup,
        EXPECTED_CONCURRENCY_GROUP,
        record.concurrencyGroup === EXPECTED_CONCURRENCY_GROUP,
        "Key concurrency by workflow and pull-request number or full ref.",
    );
    addDelta(
        deltas,
        "concurrency.cancelInProgress",
        record.cancelInProgress,
        EXPECTED_CANCEL_IN_PROGRESS,
        record.cancelInProgress === EXPECTED_CANCEL_IN_PROGRESS,
        "Cancel superseded pull-request runs only.",
    );
    addDelta(
        deltas,
        "permissions.workflow",
        record.permissions,
        {},
        equalObject(record.permissions, {}),
        "Set top-level permissions to an empty mapping.",
    );
    addDelta(
        deltas,
        "jobs.count",
        record.processJobs.length,
        1,
        record.processJobs.length === 1,
        "Keep exactly one Process-PSModule delegation job.",
    );

    for (const job of record.processJobs) {
        addDelta(
            deltas,
            "job.name",
            job.name,
            EXPECTED_JOB_NAME,
            job.name === EXPECTED_JOB_NAME,
            "Use the standard Process-PSModule job identity.",
        );
        addDelta(
            deltas,
            "job.permissions",
            job.permissions,
            REQUIRED_JOB_PERMISSIONS,
            equalObject(job.permissions, REQUIRED_JOB_PERMISSIONS),
            "Grant only contents:read, pages:write, and id-token:write.",
        );
        addDelta(
            deltas,
            "job.condition",
            job.condition,
            null,
            isEmptyCondition(job.condition),
            "Remove the caller condition so the reusable workflow owns authorization.",
        );
        addDelta(
            deltas,
            "job.uses",
            job.uses,
            EXPECTED_USES,
            job.uses === EXPECTED_USES,
            "Pin the caller to the controlled v8 major reference.",
        );
        compareSecrets(job, deltas);
        compareInputs(job, deltas, preservation);
    }

    if (record.additionalJobs.length > 0) {
        reviewWarnings.push({
            field: "additionalJobs",
            value: record.additionalJobs,
            instruction:
                "Read each repository-owned job before migration and verify it cannot bypass the Process-PSModule trigger, concurrency, permission, or authorization boundary.",
        });
    }

    const complete = missingFields.length === 0;
    const compliant = complete && deltas.length === 0;
    return {
        repository: record.repository,
        workflowPath: record.workflowPath,
        status: complete
            ? compliant
                ? "compliant"
                : "migration-needed"
            : "incomplete",
        compliant,
        complete,
        requestReady: complete,
        missingFields,
        deltas,
        preservation,
        reviewWarnings,
    };
}

export function analyzeInventory(records) {
    return records.map((record) => ({
        ...record,
        analysis: compareRepository(record),
    }));
}

export function getSummary(state) {
    const records = state.records ?? [];
    const analyses = records.map((record) => record.analysis);
    return {
        inventoryStatus: state.inventoryStatus,
        generatedAt: state.generatedAt ?? null,
        organization: state.organization ?? null,
        total: records.length,
        parsed: records.filter((record) => record.status === "parsed").length,
        parseErrors: analyses.filter((item) => item.status === "parse-error").length,
        incomplete: analyses.filter((item) => item.status === "incomplete").length,
        compliant: analyses.filter((item) => item.compliant).length,
        migrationNeeded: analyses.filter(
            (item) => item.status === "migration-needed",
        ).length,
        requestReady: analyses.filter(
            (item) => item.requestReady && !item.compliant,
        ).length,
        selected: state.selection?.length ?? 0,
        error: state.error ?? null,
    };
}

export function buildMigrationRequest(records) {
    if (!Array.isArray(records) || records.length === 0) {
        throw new Error("Select at least one repository before requesting migration.");
    }

    const blocked = records.filter((record) => !record.analysis.requestReady);
    if (blocked.length > 0) {
        throw new Error(
            `Migration request blocked because inventory is incomplete for: ${blocked
                .map((record) => record.repository)
                .join(", ")}.`,
        );
    }

    return {
        schemaVersion: 1,
        target: TARGET_CONTRACT,
        repositories: records.map((record) => ({
            repository: record.repository,
            defaultBranch: record.defaultBranch,
            workflowPath: record.workflowPath,
            workflowUrl: record.workflowUrl,
            currentReferences: record.processJobs.map((job) => job.reference),
            deltas: record.analysis.deltas,
            preserve: record.analysis.preservation,
            reviewWarnings: record.analysis.reviewWarnings,
        })),
    };
}

export function buildMigrationPrompt(request) {
    const repositoryNames = request.repositories
        .map((record) => record.repository)
        .join(", ");
    return `Orchestrate the Process-PSModule v8 caller migration for these repositories: ${repositoryNames}.

Invoke the orchestrate skill and follow the MSX fleet orchestration and contribution workflows. Create exactly one coordinated child project session per selected repository. In each repository:

1. Refresh and read the target repository's default-branch caller workflow before editing; do not trust this snapshot as the source of truth.
2. Create one repository-scoped delivery branch and open one draft pull request early. Adopt a matching open pull request instead of creating a duplicate.
3. Preserve valid repository-specific schedule timing, optional TestData JSON, and valid ImportantFilePatterns, SettingsPath, WorkingDirectory, Version, Prerelease, or Verbose behavior after verifying each value against the current repository and reusable-workflow interface.
4. Apply the agreed caller identity, trigger, concurrency, permission, unconditional-call, explicit-secret, and @v8 contract from the structured request below. Do not set Debug: true.
5. Read every additional repository-owned job and verify it cannot bypass the Process-PSModule trigger, concurrency, permission, or authorization boundary. Stop and report a blocker instead of guessing when inventory or workflow parsing is incomplete.
6. Run the repository-native validation and the applicable review loop. Report every child session, branch, validation result, blocker, and draft pull request URL to this parent session.

Do not batch repositories into one branch or pull request. Do not mutate repositories from outside their child sessions.

Structured migration request:

\`\`\`json
${JSON.stringify(request, null, 2)}
\`\`\``;
}
