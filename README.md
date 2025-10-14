# Process-PSModule

Process-PSModule provides an opinionated, end-to-end GitHub Actions workflow that builds, tests, documents, and publishes PowerShell modules with minimal setup. It is the production workflow used across the PSModule organization and is designed for repositories created from the [Template-PSModule](https://github.com/PSModule/Template-PSModule) starter.

## Why Process-PSModule

- Streamlines CI/CD: a single workflow orchestrates build, validation, documentation, and release.
- Context aware: adapts execution automatically based on pull request state, labels, and settings.
- Quality focused: enforces testing, coverage, linting, and publishing gates.
- Configurable: behavior is shaped through `.github/PSModule` settings without editing workflow YAML.
- Opinionated by design: keeps module structure, tooling, and release automation consistent across repos.

## End-to-end flow

The workflow monitors pull requests to the default branch as well as manual and scheduled runs. It reacts to open, synchronize, reopen, label, and close events, then decides which jobs to run based on repository configuration and labels.

![Process diagram](./media/Process-PSModule.png)

### Phase 1: Discover and plan

- **Get Settings** (`./.github/workflows/Get-Settings.yml`)
  - Reads configuration from `.github/PSModule.yml` (YAML, JSON, or PSD1 supported).
  - Evaluates GitHub context (event type, branch, labels, repo structure).
  - Builds dynamic matrices for OS-specific testing and determines which jobs are required.
  - Outputs a single source of truth for later jobs so they only run when needed.

### Phase 2: Build module and docs

- **Build Module** (`./.github/workflows/Build-Module.yml`)
  - Compiles `src/` into a distributable module using the Build-PSModule action.
- **Build Docs** (`./.github/workflows/Build-Docs.yml`)
  - Generates and lints documentation with [super-linter](https://github.com/super-linter/super-linter).
- **Build Site** (`./.github/workflows/Build-Site.yml`)
  - Creates the MkDocs site via [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/).

### Phase 3: Validate quality

- **Test Source Code** (`./.github/workflows/Test-SourceCode.yml`)
  - Runs style and static tests defined by [Test-PSModule](https://github.com/PSModule/Test-PSModule?tab=readme-ov-file#sourcecode-tests).
- **Lint Source Code** (`./.github/workflows/Lint-SourceCode.yml`)
  - Executes [PSScriptAnalyzer](https://github.com/PSModule/Invoke-ScriptAnalyzer) rules in parallel matrices.
- **Test Module (Framework)** (`./.github/workflows/Test-Module.yml`)
  - Validates the module using framework tests plus PSScriptAnalyzer coverage.
- **Test Module Local** (`./.github/workflows/Test-ModuleLocal.yml`)
  - Imports the compiled module and runs repository Pester tests across Linux, macOS, and Windows.
  - Supports optional `BeforeAll.ps1` and `AfterAll.ps1` jobs for shared setup and teardown.
- **Get Test Results** (`./.github/workflows/Get-TestResults.yml`)
  - Aggregates JSON test reports and fails fast when issues remain.
- **Get Code Coverage** (`./.github/workflows/Get-CodeCoverage.yml`)
  - Summarizes coverage and stops the workflow when configured targets are missed.

### Phase 4: Publish and close out

- **Publish Site** (`./.github/workflows/Publish-Site.yml`)
  - Deploys the generated documentation site to GitHub Pages.
- **Publish Module** (`./.github/workflows/Publish-Module.yml`)
  - Publishes to the PowerShell Gallery and creates the GitHub release when gates pass.

### Scenario matrix

| Job | Open/updated PR | Merged PR | Abandoned PR | Manual run |
|-----|-----------------|-----------|--------------|------------|
| **Gather (Get-Settings)** | ✅ Always | ✅ Always | ✅ Always | ✅ Always |
| **Lint-Repository** | ✅ Yes | ❌ No | ❌ No | ❌ No |
| **Build-Module** | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| **Build-Docs** | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| **Build-Site** | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| **Test-SourceCode** | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| **Lint-SourceCode** | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| **Test-Module** | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| **BeforeAll-ModuleLocal** | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| **Test-ModuleLocal** | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| **AfterAll-ModuleLocal** | ✅ Yes | ✅ Yes | ✅ Yes* | ✅ Yes |
| **Get-TestResults** | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| **Get-CodeCoverage** | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| **Publish-Site** | ❌ No | ✅ Yes | ❌ No | ❌ No |
| **Publish-Module** | ✅ Yes** | ✅ Yes** | ✅ Yes*** | ✅ Yes** |

\* Runs for cleanup if tests were started.

\*\* Only when build, test, and coverage gates succeed.

\*\*\* Publishes a cleanup or retraction version when required.

## Repository setup

1. [Create a repository from the template](https://github.com/new?template_name=Template-PSModule&template_owner=PSModule&description=Add%20a%20description%20(required)&name=%3CModule%20name%3E).
1. Enable GitHub Pages for the repo, set deployment source to `GitHub Actions`, and remove the default `main` branch protection inside the `github-pages` environment.
1. [Create a PowerShell Gallery API key](https://www.powershellgallery.com/account/apikeys) with rights to publish your module.
1. Add a repository secret named `APIKEY` containing the gallery key.
1. Develop on a feature branch, open a pull request, and allow Process-PSModule to validate the changes.

## Module structure requirements

Process-PSModule expects repositories to follow the staged layout produced by Template-PSModule.

```plaintext
<ModuleName>/
├── .github/
│   ├── workflows/Process-PSModule.yml
│   ├── PSModule.yml
│   └── ...
├── src/
│   ├── functions/
│   │   ├── public/
│   │   └── private/
│   ├── classes/
│   ├── data/
│   ├── init/
│   ├── modules/
│   ├── scripts/
│   ├── variables/
│   ├── manifest.psd1 (optional)
│   ├── header.ps1
│   └── finally.ps1
├── tests/
│   ├── <ModuleName>.Tests.ps1
│   ├── BeforeAll.ps1 (optional)
│   └── AfterAll.ps1 (optional)
└── ...
```

Key expectations:

- Keep at least one exported function under `src/functions/public/` and corresponding tests in `tests/`.
- Optional folders (`assemblies`, `formats`, `types`, `variables`, and others) are processed automatically when present.
- The build step compiles `src/` into a root module file and prunes the original structure from the output artifact.

### Build execution flow

The Build-PSModule action powers the build job and runs the following pipeline:

1. Execute optional custom scripts that match `*build.ps1` (alphabetical order).
1. Copy the contents of `src/` to the staging folder, skipping any existing root module.
1. Generate or update the module manifest (`<ModuleName>.psd1`) using repository metadata.
1. Emit a new root module (`<ModuleName>.psm1`) by compiling source folders in a defined order.
1. Refresh manifest aliases based on the compiled module.
1. Upload the build artifact for downstream jobs.

Constraints to keep in mind: the build always targets PowerShell 7.4+, processes files alphabetically, and rewrites the root module in UTF-8 with BOM encoding.

## Workflow configuration file

Behavior is controlled through `.github/PSModule.yml` (or `.json`/`.psd1`). Settings cascade into the Get-Settings job, which then toggles downstream jobs and matrices.

### Settings catalog

| Name | Type | Description | Default |
|------|------|-------------|---------|
| `Name` | `String` | Overrides the module name (otherwise the repo name is used). | `null` |
| `Test.Skip` | `Boolean` | Bypass every test job. | `false` |
| `Test.Linux.Skip` | `Boolean` | Skip all Linux matrix runs. | `false` |
| `Test.MacOS.Skip` | `Boolean` | Skip all macOS matrix runs. | `false` |
| `Test.Windows.Skip` | `Boolean` | Skip all Windows matrix runs. | `false` |
| `Test.SourceCode.Skip` | `Boolean` | Skip source code tests. | `false` |
| `Test.SourceCode.Linux.Skip` | `Boolean` | Skip source code tests on Linux. | `false` |
| `Test.SourceCode.MacOS.Skip` | `Boolean` | Skip source code tests on macOS. | `false` |
| `Test.SourceCode.Windows.Skip` | `Boolean` | Skip source code tests on Windows. | `false` |
| `Test.PSModule.Skip` | `Boolean` | Skip framework-level module tests. | `false` |
| `Test.PSModule.Linux.Skip` | `Boolean` | Skip framework tests on Linux. | `false` |
| `Test.PSModule.MacOS.Skip` | `Boolean` | Skip framework tests on macOS. | `false` |
| `Test.PSModule.Windows.Skip` | `Boolean` | Skip framework tests on Windows. | `false` |
| `Test.Module.Skip` | `Boolean` | Skip repository module tests. | `false` |
| `Test.Module.Linux.Skip` | `Boolean` | Skip module tests on Linux. | `false` |
| `Test.Module.MacOS.Skip` | `Boolean` | Skip module tests on macOS. | `false` |
| `Test.Module.Windows.Skip` | `Boolean` | Skip module tests on Windows. | `false` |
| `Test.TestResults.Skip` | `Boolean` | Skip the consolidated results job. | `false` |
| `Test.CodeCoverage.Skip` | `Boolean` | Skip code coverage calculation. | `false` |
| `Test.CodeCoverage.PercentTarget` | `Integer` | Required coverage percentage before publishing. | `0` |
| `Test.CodeCoverage.StepSummaryMode` | `String` | Display mode for coverage summaries. | `Missed, Files` |
| `Build.Skip` | `Boolean` | Disable every build job. | `false` |
| `Build.Module.Skip` | `Boolean` | Skip module compilation. | `false` |
| `Build.Docs.Skip` | `Boolean` | Skip documentation linting. | `false` |
| `Build.Docs.ShowSummaryOnSuccess` | `Boolean` | Show super-linter summary even when linting succeeds. | `false` |
| `Build.Site.Skip` | `Boolean` | Skip site generation. | `false` |
| `Publish.Module.Skip` | `Boolean` | Skip module publishing. | `false` |
| `Publish.Module.AutoCleanup` | `Boolean` | Remove stale prerelease versions automatically. | `true` |
| `Publish.Module.AutoPatching` | `Boolean` | Auto-increment patch versions during release. | `true` |
| `Publish.Module.IncrementalPrerelease` | `Boolean` | Use incremental prerelease tagging. | `true` |
| `Publish.Module.DatePrereleaseFormat` | `String` | Date format for prerelease tags (uses .NET format strings). | `''` |
| `Publish.Module.VersionPrefix` | `String` | Prefix prepended to release tags. | `v` |
| `Publish.Module.MajorLabels` | `String` | Labels that trigger a major release. | `major, breaking` |
| `Publish.Module.MinorLabels` | `String` | Labels that trigger a minor release. | `minor, feature` |
| `Publish.Module.PatchLabels` | `String` | Labels that trigger a patch release. | `patch, fix` |
| `Publish.Module.IgnoreLabels` | `String` | Labels that skip releasing entirely. | `NoRelease` |
| `Linter.Skip` | `Boolean` | Skip repository linting. | `false` |
| `Linter.ShowSummaryOnSuccess` | `Boolean` | Show linter summary on success. | `false` |
| `Linter.env` | `Object` | Key/value pairs forwarded to super-linter. | `{}` |

<details>
<summary>Default configuration (`PSModule.yml`)</summary>

```yaml
Name: null

Build:
  Skip: false
  Module:
    Skip: false
  Docs:
    Skip: false
    ShowSummaryOnSuccess: false
  Site:
    Skip: false

Test:
  Skip: false
  Linux:
    Skip: false
  MacOS:
    Skip: false
  Windows:
    Skip: false
  SourceCode:
    Skip: false
    Linux:
      Skip: false
    MacOS:
      Skip: false
    Windows:
      Skip: false
  PSModule:
    Skip: false
    Linux:
      Skip: false
    MacOS:
      Skip: false
    Windows:
      Skip: false
  Module:
    Skip: false
    Linux:
      Skip: false
    MacOS:
      Skip: false
    Windows:
      Skip: false
  TestResults:
    Skip: false
  CodeCoverage:
    Skip: false
    PercentTarget: 0
    StepSummaryMode: 'Missed, Files'

Publish:
  Module:
    Skip: false
    AutoCleanup: true
    AutoPatching: true
    IncrementalPrerelease: true
    DatePrereleaseFormat: ''
    VersionPrefix: 'v'
    MajorLabels: 'major, breaking'
    MinorLabels: 'minor, feature'
    PatchLabels: 'patch, fix'
    IgnoreLabels: 'NoRelease'

Linter:
  Skip: false
  ShowSummaryOnSuccess: false
  env: {}
```
</details>

### Configuration patterns

**Enforce coverage targets**

```yaml
Test:
  CodeCoverage:
    PercentTarget: 80
```

**Fast local validation (Linux only)**

```yaml
Test:
  SourceCode:
    Skip: true
  PSModule:
    Skip: true
  Module:
    MacOS:
      Skip: true
    Windows:
      Skip: true
  TestResults:
    Skip: true
  CodeCoverage:
    Skip: true
Build:
  Docs:
    Skip: true
```

**Tune repository linting**

```yaml
Linter:
  env:
    LOG_LEVEL: DEBUG
    VALIDATE_JSON: true
    VALIDATE_YAML: true
    VALIDATE_MARKDOWN: true
```

## Workflow usage in consuming repos

Place the following workflow in `.github/workflows/Process-PSModule.yml`:

<details>
<summary>Reusable workflow reference</summary>

```yaml
name: Process-PSModule

on:
  workflow_dispatch:
  schedule:
    - cron: '0 0 * * *'
  pull_request:
    branches:
      - main
    types:
      - opened
      - reopened
      - synchronize
      - labeled
      - closed

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
      APIKEY: ${{ secrets.APIKEY }}
```
</details>

### Workflow inputs

| Name | Type | Description | Required | Default |
|------|------|-------------|----------|---------|
| `Name` | `string` | Overrides the module name; defaults to repository name. | `false` | N/A |
| `SettingsPath` | `string` | Path to the settings file. | `false` | `.github/PSModule.yml` |
| `Version` | `string` | Exact version of the `GitHub` PowerShell module to install. | `false` | `''` |
| `Prerelease` | `boolean` | Install a prerelease of the `GitHub` module. | `false` | `false` |
| `Debug` | `boolean` | Emit debug steps in every job. | `false` | `false` |
| `Verbose` | `boolean` | Enable verbose logging. | `false` | `false` |
| `WorkingDirectory` | `string` | Repository root path. | `false` | `.` |

### Setup and teardown scripts

`Test-ModuleLocal` automatically detects optional scripts to prepare and clean up shared test environments:

- `tests/BeforeAll.ps1` runs once before the matrix executes. Use it to deploy resources or download test data.
- `tests/AfterAll.ps1` runs once after the matrix completes. Use it for cleanup or artifact uploads.

```powershell
# tests/BeforeAll.ps1
Write-Host "Setting up test environment..."
```

```powershell
# tests/AfterAll.ps1
Write-Host "Cleaning up test environment..."
```

These scripts run with the same environment variables and secrets defined for your workflow jobs.

### Secrets

| Name | Location | Purpose |
|------|----------|---------|
| `APIKEY` | Repository secret | PowerShell Gallery publishing key. |
| `TEST_APP_ENT_CLIENT_ID` | Repository secret | Enterprise GitHub App client ID for integration tests. |
| `TEST_APP_ENT_PRIVATE_KEY` | Repository secret | Enterprise GitHub App private key for integration tests. |
| `TEST_APP_ORG_CLIENT_ID` | Repository secret | Organization GitHub App client ID for integration tests. |
| `TEST_APP_ORG_PRIVATE_KEY` | Repository secret | Organization GitHub App private key for integration tests. |
| `TEST_USER_ORG_FG_PAT` | Repository secret | Fine-grained PAT with org scope for tests. |
| `TEST_USER_USER_FG_PAT` | Repository secret | Fine-grained PAT with user scope for tests. |
| `TEST_USER_PAT` | Repository secret | Classic PAT fallback for legacy tests. |

To reuse organization secrets, configure `secrets: inherit` when referencing the workflow.

### Required permissions

```yaml
permissions:
  contents: write      # checkout and release management
  pull-requests: write # PR comments and status updates
  statuses: write      # commit status notifications from lint/test jobs
  pages: write         # publish GitHub Pages documentation
  id-token: write      # OIDC token for Pages deployment verification
```

Refer to [Deploy GitHub Pages site](https://github.com/marketplace/actions/deploy-github-pages-site) for details on `pages` and `id-token` requirements.

## Operating principles

Process-PSModule is guided by five non-negotiable practices:

1. **Workflow-first design**: all logic lives in reusable GitHub Actions, not ad-hoc inline scripts.
1. **Test-driven development**: Pester and PSScriptAnalyzer enforce red-green-refactor discipline for every change.
1. **Cross-platform parity**: PowerShell 7.4+ across Linux, macOS, and Windows is the baseline expectation.
1. **Quality gates and observability**: JSON reports, coverage metrics, and actionable errors surface every run.
1. **Continuous delivery with SemVer**: release labels drive automatic versioning, gallery publishing, and GitHub releases.

## Compatible practices and tooling

- [Test-Driven Development](https://testdriven.io/test-driven-development/) with [Pester](https://pester.dev) and [PSScriptAnalyzer](https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/overview?view=ps-modules)
- [GitHub Flow](https://docs.github.com/en/get-started/using-github/github-flow)
- [Semantic Versioning 2.0.0](https://semver.org)
- [Continuous Delivery](https://en.wikipedia.org/wiki/Continuous_delivery)
