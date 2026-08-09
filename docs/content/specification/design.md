---
title: Design
description: How Process-PSModule delivers the spec — a single reusable GitHub Actions workflow composing sub-workflows, a settings file contract, and the scenario matrix.
---

# Process-PSModule — Design

The behaviour in the [spec](spec.md) is delivered by a **single reusable GitHub Actions workflow** at `PSModule/Process-PSModule/.github/workflows/workflow.yml`. A repository using the workflow provides a caller workflow and a minimal `.github/PSModule.yml` settings file; everything else uses sensible defaults.

## Workflow architecture

### Single entry point

The reusable workflow accepts a caller workflow and minimal caller configuration: a `pull_request`-triggered job that
calls `workflow.yml` and passes the `APIKey` secret. The full caller template is in
[Repository setup](../get-started/repository-setup.md#3-add-the-caller-workflow), and the interface it targets is
documented in [Workflow inputs](../reference/workflow-inputs.md).

### Composed reusable workflows

The main workflow composes work across specialized reusable workflows, each owning a pipeline stage:

- **Plan** — reads the settings file and event context, decides what runs, computes the next version
- **Lint-Repository** — validates repository structure and configuration
- **Build-Module** — compiles the module source and versions the manifest
- **Test-SourceCode** — validates source-code style and standards (PSScriptAnalyzer, framework tests)
- **Lint-SourceCode** — runs static analysis on source
- **Test-Module** — runs framework tests and module-local Pester tests in parallel per platform
- **Get-TestResults** — aggregates test results and enforces pass/fail
- **Get-CodeCoverage** — collects coverage from tests and enforces thresholds
- **Publish-Module** — publishes the module to the PowerShell Gallery
- **Publish-Site** — generates and publishes documentation to GitHub Pages

Each workflow is reusable so it can be tested and versioned independently, invoked by name in the main orchestration workflow.

## Settings file contract

The caller provides `.github/PSModule.yml`. Every key is optional and every setting has a default, so a repository can
start with an effectively empty file and opt out of individual phases as needed. The authorable contract is documented
in [Settings](../reference/settings.md).

The Plan job reads this settings file, enriches it with computed values (phase enables, test matrices, resolved version, release decision), and passes the enriched settings to downstream jobs as a JSON string in workflow outputs.

That enriched object is an internal inter-workflow contract, not an authoring format. It is documented in
[Pipeline stages](../reference/pipeline-stages.md#internal-runtime-settings-contract).

## Scenario matrix

Release intent comes from pull-request labels and is resolved once, in the Plan job. The label-to-bump mapping, the
handling of conflicting labels, and the branch types that may publish are documented in
[Versioning and releases](../guides/versioning-and-releases.md).

Tests run on **Windows** (latest), **Linux** (Ubuntu latest), and **macOS** (latest). Failures on any platform block
the build. Each platform runs four suites in parallel:

- **Source-code tests** — style, naming, structure (PSModule framework)
- **Framework tests** — module structure, common issues (PSModule framework)
- **Module-local tests** — Pester tests written by the module author
- **Linting** — PSScriptAnalyzer rules

Test results are aggregated into a single pass/fail and reported to the PR.

Which jobs run for which trigger scenario is defined in the
[scenario matrix](../reference/scenario-matrix.md).

## Alternatives considered

### Monolithic workflow vs. composable reusable workflows

**Chosen: Composable reusable workflows**

Each stage of the pipeline is a reusable workflow so it can be tested independently, versioned, and reused across the ecosystem. This trades orchestration complexity for testability and clarity.

**Alternative: Single monolithic workflow**

All logic in one workflow file. Pros: simpler to read end-to-end. Cons: harder to test, version, and reuse; changes in one stage risk all stages; every module repo copies the full logic.

### Settings file format

**Chosen: YAML with runtime enrichment**

The caller provides a simple YAML file; the Plan job enriches it with computed values and passes the enriched settings to all downstream jobs. Pros: simple, readable, minimal to start. Cons: only the Plan job computes the settings; other jobs consume them.

**Alternative: JSON in workflow outputs**

Settings live only as workflow outputs, computed by Plan. Pros: single source of truth. Cons: harder to read and edit; no local file to inspect.

### Version computation

**Chosen: PR label + current version**

The bump comes from the PR label; the next version is computed as `current_version + bump`. Pros: explicit, git-traceable (the label is recorded in the PR). Cons: must be re-computed if a PR is re-run or the base version changes.

**Alternative: Conventional Commits**

Parse commit messages for `feat:`, `fix:`, `BREAKING CHANGE:` to infer the bump. Pros: automatic. Cons: less explicit; easy to forget the convention; harder to override.

## External dependencies

The workflow composes reusable workflows, actions, PowerShell modules, and external services. Each is versioned
independently; the main workflow pins versions explicitly. The full list is in
[Dependencies](../reference/dependencies.md).

## Where this connects

- [Spec](spec.md) — the requirements this design delivers.
- [Pipeline stages](../reference/pipeline-stages.md) — detailed breakdown of each job.
- [Calling the workflow](../guides/calling-the-workflow.md) — how to invoke it.
- [Settings](../reference/settings.md) — the settings file reference.
- [Principles and practices](principles-and-practices.md) — the principles guiding this design.
- [Structuring your module](../guides/structuring-your-module.md) — the repo layout the workflow expects.
