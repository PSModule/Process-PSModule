---
title: Design
description: How Process-PSModule delivers the spec — a single reusable GitHub Actions workflow composing sub-workflows, a settings file contract, and the scenario matrix.
---

# Process-PSModule — Design

The behaviour in the [spec](spec.md) is delivered by a **single reusable GitHub Actions workflow** at `PSModule/Process-PSModule/.github/workflows/workflow.yml`. A repository using the workflow provides a caller workflow and a minimal `.github/PSModule.yml` settings file; everything else uses sensible defaults.

## Workflow architecture

### Single entry point

The reusable workflow accepts a caller workflow and minimal caller configuration:

```yaml
# .github/workflows/Process-PSModule.yml in the module repository
name: Process-PSModule

on:
  workflow_dispatch:
  schedule:
    - cron: '0 0 * * *'
  pull_request:
    branches:
      - main
    types:
      - closed
      - opened
      - reopened
      - synchronize
      - labeled

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: write
  pull-requests: write
  statuses: write
  pages: write
  id-token: write

jobs:
  Process-PSModule:
    uses: PSModule/Process-PSModule/.github/workflows/workflow.yml@v5
    secrets:
      APIKey: ${{ secrets.APIKey }}
```

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

The caller provides `.github/PSModule.yml`:

```yaml
# Minimal example — defaults apply for everything not specified
Linter:
  Repository:
    Enabled: true

Build:
  Module:
    Enabled: true

Test:
  SourceCode:
    Enabled: true
  PSModule:
    Enabled: true
  Module:
    Enabled: true
  CodeCoverage:
    Enabled: true
    Threshold: 80

Publish:
  Module:
    Enabled: true
  Site:
    Enabled: true
```

The Plan job reads this settings file, enriches it with computed values (phase enables, test matrices, resolved version, release decision), and passes the enriched settings to downstream jobs as a JSON string in workflow outputs.

### Runtime settings contract

| Path | Meaning |
| --- | --- |
| `Settings.Linter.Repository.Enabled` | Whether repository linting runs. |
| `Settings.Build.Module.Enabled` | Whether module build runs. |
| `Settings.Test.SourceCode.Enabled` | Whether source-code tests run. |
| `Settings.Test.PSModule.Enabled` | Whether framework tests run. |
| `Settings.Test.Module.Enabled` | Whether module-local tests run. |
| `Settings.Test.TestResults.Enabled` | Whether test-results aggregation runs. |
| `Settings.Test.CodeCoverage.Enabled` | Whether code-coverage gates run. |
| `Settings.Publish.Module.Enabled` | Whether module publication runs. |
| `Settings.Publish.Site.Enabled` | Whether documentation publication runs. |
| `Settings.Test.SourceCode.Suites` | Computed source-code test matrix (platform × test suite). |
| `Settings.Test.PSModule.Suites` | Computed framework test matrix (platform × test suite). |
| `Settings.Test.Module.Suites` | Computed module-local test matrix (platform × test suite). |
| `Settings.Publish.Module.Resolution.Version` | Resolved semantic version (e.g., `v1.2.3`). |
| `Settings.Publish.Module.Resolution.Prerelease` | Whether the version is prerelease. |
| `Settings.Publish.Module.Resolution.FullVersion` | Full version string (e.g., `v1.2.3-pr.1.5`). |
| `Settings.Publish.Module.Resolution.ReleaseType` | `stable`, `prerelease`, or `none`. |
| `Settings.Publish.Module.Resolution.CreateRelease` | Whether to create a GitHub Release. |

## Scenario matrix

### Version labeling

- **Major** — breaking change; bump `MAJOR` in SemVer
- **Minor** — new feature; bump `MINOR`
- **Patch** — bugfix; bump `PATCH` (default if no label)
- **Prerelease** — publish as prerelease, not promoted to latest
- **NoRelease** — run pipeline, skip publication

Multiple SemVer labels or conflicting labels (e.g., `Major` + `NoRelease`) are rejected and block the merge.

### Branch types

- **Main (stable)** — publishes stable releases. A prerelease label publishes a prerelease from `main`.
- **Development** — optional prerelease branch (e.g., `dev`). Each push publishes a prerelease.
- **Feature branch** — optional feature branch. A prerelease label publishes a prerelease for testing.

### Platform matrix

Tests run on:

- **Windows** (latest)
- **Linux** (Ubuntu latest)
- **macOS** (latest)

Failures on any platform block the build.

### Test suites

Each platform runs in parallel:

- **Source-code tests** — style, naming, structure (PSModule framework)
- **Framework tests** — module structure, common issues (PSModule framework)
- **Module-local tests** — Pester tests written by the module author
- **Linting** — PSScriptAnalyzer rules

Test results are aggregated into a single pass/fail and reported to the PR.

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

The workflow relies on:

- **[PSModule/Build-PSModule](https://github.com/PSModule/Build-PSModule)** — compiles and versions the module
- **[PSModule/Test-PSModule](https://github.com/PSModule/Test-PSModule)** — runs framework tests and style validation
- **[PSModule/Invoke-ScriptAnalyzer](https://github.com/PSModule/Invoke-ScriptAnalyzer)** — runs PSScriptAnalyzer linting
- **[Pester](https://pester.dev/)** — runs module tests
- **[GitHub Actions](https://github.com/features/actions)** — workflow engine
- **PowerShell Gallery API** — publishes module packages
- **GitHub Pages** — hosts documentation
- **Zensical** — generates documentation from source

Each is versioned independently; the main workflow pins versions explicitly.

## Where this connects

- [Spec](spec.md) — the requirements this design delivers.
- [Pipeline stages](pipeline-stages.md) — detailed breakdown of each job.
- [Usage](usage.md) — how to invoke and configure.
- [Configuration](configuration.md) — the settings file reference.
- [Principles and practices](principles-and-practices.md) — the principles guiding this design.
- [Repository structure](repository-structure.md) — the repo layout the workflow expects.
