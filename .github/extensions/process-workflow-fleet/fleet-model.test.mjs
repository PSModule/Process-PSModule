import assert from "node:assert/strict";
import { describe, it } from "node:test";

import {
    analyzeInventory,
    buildMigrationPrompt,
    buildMigrationRequest,
    compareRepository,
    normalizeInventory,
} from "./fleet-model.mjs";

function createRecord(overrides = {}) {
    return {
        Repository: "PSModule/Example",
        DefaultBranch: "main",
        Archived: false,
        RepositoryUrl: "https://github.com/PSModule/Example",
        WorkflowPath: ".github/workflows/Process-PSModule.yml",
        WorkflowUrl:
            "https://github.com/PSModule/Example/blob/main/.github/workflows/Process-PSModule.yml",
        Status: "Parsed",
        Error: null,
        WorkflowName: "Process-PSModule",
        RunName: null,
        Events: ["pull_request", "push", "schedule", "workflow_dispatch"],
        Schedules: ["0 0 * * *"],
        PushBranches: ["main"],
        PushBranchesIgnore: [],
        PushPaths: [],
        PushPathsIgnore: [],
        PullRequestBranches: ["main"],
        PullRequestTypes: [
            "closed",
            "opened",
            "reopened",
            "synchronize",
            "labeled",
            "unlabeled",
        ],
        PullRequestPaths: [],
        PullRequestPathsIgnore: [],
        ConcurrencyGroup:
            "${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}",
        CancelInProgress: "${{ github.event_name == 'pull_request' }}",
        Permissions: {},
        ProcessJobs: [
            {
                Name: "Process-PSModule",
                Uses: "PSModule/Process-PSModule/.github/workflows/workflow.yml@v8",
                Reference: "v8",
                Inputs: {},
                SecretMode: "explicit",
                SecretMappings: {
                    PSGALLERY_API_KEY: "${{ secrets.PSGALLERY_API_KEY }}",
                    GitHubAppClientId: "${{ secrets.SHELLY_CLIENT_ID }}",
                    GitHubAppPrivateKey: "${{ secrets.SHELLY_PRIVATE_KEY }}",
                },
                Permissions: {
                    contents: "read",
                    pages: "write",
                    "id-token": "write",
                },
                Environment: null,
                Condition: null,
            },
        ],
        AdditionalJobs: [],
        VersionComments: [{ Reference: "v8", Version: "v8.0.1" }],
        ...overrides,
    };
}

describe("inventory normalization and comparison", () => {
    it("recognizes the agreed v8 caller contract", () => {
        const [record] = normalizeInventory([createRecord()]);
        const analysis = compareRepository(record);

        assert.equal(record.repository, "PSModule/Example");
        assert.equal(analysis.status, "compliant");
        assert.equal(analysis.compliant, true);
        assert.deepEqual(analysis.deltas, []);
    });

    it("reports migration deltas and preserves supported optional behavior", () => {
        const source = createRecord({
            Events: ["pull_request", "schedule", "workflow_dispatch"],
            ProcessJobs: [
                {
                    ...createRecord().ProcessJobs[0],
                    Uses: "PSModule/Process-PSModule/.github/workflows/workflow.yml@v6",
                    Reference: "v6",
                    Inputs: {
                        Debug: true,
                        ImportantFilePatterns: '["src/**","README.md"]',
                    },
                    SecretMappings: {
                        PSGALLERY_API_KEY: "${{ secrets.PSGALLERY_API_KEY }}",
                        GitHubAppClientId: "${{ secrets.SHELLY_CLIENT_ID }}",
                        GitHubAppPrivateKey: "${{ secrets.SHELLY_PRIVATE_KEY }}",
                        TestData:
                            '{"secrets":{"TOKEN":"${{ secrets.TEST_TOKEN }}"}}',
                    },
                },
            ],
        });
        const [record] = analyzeInventory(normalizeInventory(source));

        assert.equal(record.analysis.status, "migration-needed");
        assert.ok(
            record.analysis.deltas.some((delta) => delta.field === "job.uses"),
        );
        assert.ok(
            record.analysis.deltas.some(
                (delta) => delta.field === "job.inputs.Debug",
            ),
        );
        assert.deepEqual(
            record.analysis.preservation.map((item) => item.field).sort(),
            ["job.inputs.ImportantFilePatterns", "job.secrets.TestData"],
        );
    });

    it("fails closed when the inventory contract is incomplete", () => {
        const source = createRecord();
        delete source.PullRequestPaths;
        const [record] = analyzeInventory(normalizeInventory(source));

        assert.equal(record.analysis.status, "incomplete");
        assert.equal(record.analysis.requestReady, false);
        assert.deepEqual(record.analysis.missingFields, ["PullRequestPaths"]);
        assert.throws(
            () => buildMigrationRequest([record]),
            /inventory is incomplete/,
        );
    });

    it("fails closed on parse errors", () => {
        const [record] = analyzeInventory(
            normalizeInventory({
                Repository: "PSModule/Broken",
                WorkflowPath: ".github/workflows/Process-PSModule.yml",
                Status: "ParseError",
                Error: "Unexpected token",
            }),
        );

        assert.equal(record.analysis.status, "parse-error");
        assert.equal(record.analysis.requestReady, false);
    });
});

describe("migration request generation", () => {
    it("creates a complete orchestration prompt without mutating repositories", () => {
        const [record] = analyzeInventory(normalizeInventory(createRecord()));
        const request = buildMigrationRequest([record]);
        const prompt = buildMigrationPrompt(request);

        assert.match(prompt, /exactly one coordinated child project session/);
        assert.match(prompt, /open one draft pull request early/);
        assert.match(prompt, /refresh and read/i);
        assert.match(prompt, /ImportantFilePatterns/);
        assert.match(prompt, /workflow\.yml@v8/);
        assert.match(prompt, /repository-native validation/);
        assert.match(prompt, /PSModule\/Example/);
    });

    it("rejects an empty repository selection", () => {
        assert.throws(
            () => buildMigrationRequest([]),
            /Select at least one repository/,
        );
    });
});
