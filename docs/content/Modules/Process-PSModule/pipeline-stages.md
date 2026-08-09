---
title: Pipeline stages
description: The job-by-job breakdown of the Process-PSModule workflow, from Plan through Publish Docs.
---

# Pipeline stages

The Process-PSModule workflow composes its work from a set of reusable jobs. Each
one is described below, in the order it runs, with a link to the workflow that
implements it.

## Plan

[workflow](https://github.com/PSModule/Process-PSModule/blob/main/.github/workflows/Plan.yml)

The Plan job is the single decision point of the workflow. It reads the settings file (`.github/PSModule.yml`),
collects event context from GitHub, and decides what should happen in the rest of the process. Using that
situational awareness, it calculates the next module version.

The user-facing settings file stays in `.github/PSModule.yml`. The workflow enriches that input into an internal runtime
`Settings` object passed between jobs. In this runtime contract, execution decisions are phase-owned (`*.Enabled`), test
suite matrices are computed under each owning test phase, and resolved version metadata is stored under
`Settings.Publish.Module.Resolution`. The `*.Suites` values are workflow outputs, not authorable layout settings.

### Internal runtime settings contract

| Runtime path | Meaning |
| --- | --- |
| `Settings.Linter.Repository.Enabled` | Whether repository linting runs. |
| `Settings.Build.Module.Enabled` | Whether module build runs. |
| `Settings.Test.SourceCode.Enabled` | Whether source-code tests run. |
| `Settings.Test.PSModule.Enabled` | Whether framework tests run. |
| `Settings.Test.Module.BeforeAllEnabled` | Whether setup scripts run before module-local tests. |
| `Settings.Test.Module.MainEnabled` | Whether module-local Pester tests run. |
| `Settings.Test.Module.AfterAllEnabled` | Whether teardown scripts run after module-local tests. |
| `Settings.Test.TestResults.Enabled` | Whether test results aggregation runs. |
| `Settings.Test.CodeCoverage.Enabled` | Whether code coverage aggregation/enforcement runs. |
| `Settings.Publish.Module.Enabled` | Whether module publication/release runs. |
| `Settings.Publish.Site.Enabled` | Whether documentation publication runs. |
| `Settings.Test.SourceCode.Suites` | Computed source-code test suite matrix. |
| `Settings.Test.PSModule.Suites` | Computed framework test suite matrix. |
| `Settings.Test.Module.Suites` | Computed module-local test suite matrix. |
| `Settings.Publish.Module.Resolution.Version` | Resolved semantic version used for build and publish. |
| `Settings.Publish.Module.Resolution.Prerelease` | Whether the resolved version is prerelease. |
| `Settings.Publish.Module.Resolution.FullVersion` | Resolved full version string. |
| `Settings.Publish.Module.Resolution.ReleaseType` | Resolved release classification for this run. |
| `Settings.Publish.Module.Resolution.CreateRelease` | Whether this run creates a release. |

## Lint-Repository

[workflow](https://github.com/PSModule/Process-PSModule/blob/main/.github/workflows/Lint-Repository.yml)

## Build module

[workflow](https://github.com/PSModule/Process-PSModule/blob/main/.github/workflows/Build-Module.yml)

- Compiles the module source code into a PowerShell module, stamping the version from `Settings.Publish.Module.Resolution.Version` into the manifest.
- Uploads the built artifact.

## Test source code

[workflow](https://github.com/PSModule/Process-PSModule/blob/main/.github/workflows/Test-SourceCode.yml)

- Tests the source code in parallel (matrix) using:
  - [PSModule framework settings for style and standards for source code](https://github.com/PSModule/Test-PSModule?tab=readme-ov-file#sourcecode-tests)
- This produces a JSON-based report that is used by [Get-PesterTestResults](#get-test-results) evaluate the results of the tests.

The [PSModule - SourceCode tests](https://github.com/PSModule/Process-PSModule/blob/main/scripts/tests/SourceCode/PSModule/PSModule.Tests.ps1) verifies the following coding practices that the framework enforces:

| ID                  | Category            | Description                                                                                |
|---------------------|---------------------|--------------------------------------------------------------------------------------------|
| NumberOfProcessors  | General             | Should use `[System.Environment]::ProcessorCount` instead of `$env:NUMBER_OF_PROCESSORS`.  |
| Verbose             | General             | Should not contain `-Verbose` unless it is explicitly disabled with `:$false`.             |
| OutNull             | General             | Should use `$null = ...` instead of piping output to `Out-Null`.                           |
| NoTernary           | General             | Should not use ternary operations to maintain compatibility with PowerShell 5.1 and below. |
| LowercaseKeywords   | General             | All PowerShell keywords should be written in lowercase.                                    |
| FunctionCount       | Functions (Generic) | Each script file should contain exactly one function or filter.                            |
| FunctionName        | Functions (Generic) | Script filenames should match the name of the function or filter they contain.             |
| CmdletBinding       | Functions (Generic) | Functions should include the `[CmdletBinding()]` attribute.                                |
| ParamBlock          | Functions (Generic) | Functions should have a parameter block (`param()`).                                       |
| FunctionTest        | Functions (Public)  | All public functions/filters should have corresponding tests.                              |

## Lint source code

[workflow](https://github.com/PSModule/Process-PSModule/blob/main/.github/workflows/Lint-SourceCode.yml)

- Lints the source code in parallel (matrix) using:
  - [PSScriptAnalyzer rules](https://github.com/PSModule/Invoke-ScriptAnalyzer)
- This produces a JSON-based report that is used by [Get-PesterTestResults](#get-test-results) evaluate the results of the linter.

## Framework test

[workflow](https://github.com/PSModule/Process-PSModule/blob/main/.github/workflows/Test-Module.yml)

- Tests and lints the module in parallel (matrix) using:
  - [PSModule framework settings for style and standards for modules](https://github.com/PSModule/Test-PSModule?tab=readme-ov-file#module-tests)
  - [PSScriptAnalyzer rules](https://github.com/PSModule/Invoke-ScriptAnalyzer)
- This produces a JSON-based report that is used by [Get-PesterTestResults](#get-test-results) evaluate the results of the tests.
- **Code coverage for framework-generated code**: This step collects code coverage for framework-generated
  boilerplate. During the [build step](#build-module), [Build-PSModule](https://github.com/PSModule/Build-PSModule)
  injects boilerplate code into the compiled `.psm1` file — including type accelerator registration for public classes
  and enums, and the `OnRemove` cleanup hook. The framework tests in
  [Test-PSModule](https://github.com/PSModule/Test-PSModule) exercise these code paths and produce coverage artifacts
  that are aggregated with coverage from [Test-ModuleLocal](#test-module) in the
  [Get code coverage](#get-code-coverage) step. This keeps framework-generated lines from counting against the module
  author's coverage report.

## Test module

[workflow](https://github.com/PSModule/Process-PSModule/blob/main/.github/workflows/Test-ModuleLocal.yml)

- Imports and tests the module in parallel (matrix) using module-local Pester tests.
- Discovers module-local tests recursively under `tests/`, applying the [per-directory precedence](#module-local-test-discovery) independently at every level.
- Module test files declare a Pester **6.x** requirement via `#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0'; MaximumVersion = '6.*' }` — a convention module authors add to each `*.Tests.ps1`, not something this pipeline injects. The [Invoke-Pester](https://github.com/PSModule/Invoke-Pester) action installs a matching `6.x`, so minor and patch updates flow in automatically while a new major stays a deliberate, reviewed change.
- Supports two special workflow phase scripts executed via separate dedicated jobs:
  - `tests/BeforeAll.ps1`: Runs once before all module-local test matrix jobs to set up the test environment (e.g., deploy infrastructure, download test data).
  - `tests/AfterAll.ps1`: Runs once after all module-local test matrix jobs complete to clean up the test environment (e.g., remove test resources, clean up databases).
- The workflow checks only those exact repository-root paths; phase detection is non-recursive. This is separate from the recursive discovery of ordinary module-local test entries described below; nested files named `BeforeAll.ps1` or `AfterAll.ps1` do not create workflow phases.
- The two phase scripts run with the same environment variables as the tests.
- This produces a JSON-based report that is used by [Get-PesterTestResults](#get-test-results) to evaluate the results of the tests.

### Module-local test discovery

Simple, Standard, and Advanced are [documentation profiles](https://msxorg.github.io/docs/Coding-Standards/PowerShell/Testing/#module-test-profiles), not selectable workflow modes. The same discovery engine handles every profile. `.github/PSModule.yml` has no test-layout or suite-matrix setting; `Settings.Test.Module.Suites` is computed internally from the repository files.

Process-PSModule inspects `tests/` recursively. Within each directory it uses the first matching form:

1. Exactly one `*.Configuration.ps1`. Discovery fails when a directory contains more than one. When selected, sibling `*.Container.ps1` and `*.Tests.ps1` files are not independently selected.
2. Otherwise, one or more `*.Container.ps1`. When selected, sibling `*.Tests.ps1` files are not independently selected.
3. Otherwise, all `*.Tests.ps1`.

The selected form takes precedence only in that directory. Child directories are still inspected independently, so a repository may mix configurations, containers, and ordinary test files across different directories.

Every discovered artifact needs a unique prefix before its first dot because that prefix becomes `TestName`. For example, `Users.Unit.Tests.ps1` and `Users.Integration.Tests.ps1` both become `Users`; use distinct prefixes such as `UsersUnit` and `UsersIntegration`.

### Setup and Teardown Scripts

The workflow supports automatic execution of setup and teardown scripts for module tests:

- `tests/BeforeAll.ps1` and `tests/AfterAll.ps1` are special workflow phase files, not ordinary recursively discovered test entries.
- Each phase is enabled only when its exact file exists at the root of `tests/`.
- If either file is absent, the workflow skips that phase and continues normally.

#### Setup - `BeforeAll.ps1`

- Place at the exact repository-root path `tests/BeforeAll.ps1`.
- Runs once before all test matrix jobs to prepare the test environment.
- Deploy test infrastructure, download test data, initialize databases, or configure services.
- Has access to the same environment variables as your tests (secrets, GitHub token, etc.).

##### Example - `BeforeAll.ps1`

```powershell
Write-Host "Setting up test environment..."
# Deploy test infrastructure
# Download test data
# Initialize test databases
Write-Host "Test environment ready!"
```

#### Teardown - `AfterAll.ps1`

- Place at the exact repository-root path `tests/AfterAll.ps1`.
- Runs once after all test matrix jobs complete to clean up the test environment.
- Remove test resources, clean up databases, stop services, or upload artifacts.
- Has access to the same environment variables as your tests.

##### Example - `AfterAll.ps1`

```powershell
Write-Host "Cleaning up test environment..."
# Remove test resources
# Clean up databases
# Stop services
Write-Host "Cleanup completed!"
```

#### Best practices for shared test infrastructure

Tests run in parallel across multiple OS runners. To avoid rate limits or conflicts from excessive resource creation,
provision shared infrastructure once in `BeforeAll.ps1` and tear it down in `AfterAll.ps1`. Individual test files
should consume the shared infrastructure instead of creating their own.

##### Use deterministic naming with `$env:GITHUB_RUN_ID`

Use `$env:GITHUB_RUN_ID` (stable per workflow run, shared across OS runners) to build deterministic resource names.
This lets test files reference shared resources by name without passing state between jobs.

```powershell
# BeforeAll.ps1
$os = $env:RUNNER_OS
$id = $env:GITHUB_RUN_ID
$resourceName = "Test-$os-$id"
```

Do **not** use `[guid]::NewGuid()` or `Get-Random` for shared resource names — these produce different values on
each runner and cannot be referenced by other jobs.

##### Clean up stale resources from previous failed runs

If a previous workflow run failed before teardown completed, stale resources may remain. Start `BeforeAll.ps1` by
removing any resources matching your naming prefix before creating new ones:

```powershell
# Remove stale resources from previous failed runs
Get-Resources -Filter "Test-$os-*" | Remove-Resource

# Create fresh shared resources
New-Resource -Name "Test-$os-$id"
```

##### Tests reference shared resources — they do not create them

Test files should fetch the shared resource by its deterministic name, not create new resources:

```powershell
# Inside a test file
BeforeAll {
    $os = $env:RUNNER_OS
    $id = $env:GITHUB_RUN_ID
    $resource = Get-Resource -Name "Test-$os-$id"
}
```

Test-specific ephemeral resources (for example, secrets, variables, or temporary items) can still be created and
cleaned up within each test file. Only long-lived or expensive resources should be shared.

##### Naming conventions

Use a consistent naming scheme so that resources are easy to identify and clean up. A recommended pattern:

| Resource          | Pattern                               | Example                    |
|-------------------|---------------------------------------|----------------------------|
| Shared resource   | `Test-{OS}-{RunID}`                   | `Test-Linux-1234`          |
| Extra resource    | `Test-{OS}-{RunID}-{N}`               | `Test-Linux-1234-1`        |
| Secret / variable | `{TestName}_{OS}_{RunID}`             | `Secrets_Linux_1234`       |
| Environment       | `{TestName}-{OS}-{RunID}`             | `Secrets-Linux-1234`       |

When tests use multiple authentication contexts that share the same runner, include a token or context identifier in
the name to avoid collisions (for example, `Test-{OS}-{ContextID}-{RunID}`).

### Module tests

The [PSModule - Module tests](https://github.com/PSModule/Process-PSModule/blob/main/scripts/tests/Module/PSModule/PSModule.Tests.ps1) verifies the following coding practices that the framework enforces:

| Name | Description |
| ------ | ----------- |
| Module Manifest exists | Verifies that a module manifest file is present. |
| Module Manifest is valid | Verifies that the module manifest file is valid. |

## Get test results

[workflow](https://github.com/PSModule/Process-PSModule/blob/main/.github/workflows/Get-TestResults.yml)

- Gathers the test results from the previous steps and creates a summary of the results.
- If any tests have failed, the workflow will fail here.

## Get code coverage

[workflow](https://github.com/PSModule/Process-PSModule/blob/main/.github/workflows/Get-CodeCoverage.yml)

- Gathers the code coverage from the previous steps and creates a summary of the results.
- Aggregates coverage from the [Framework test](#framework-test) step (framework-generated boilerplate) and the
  [Test module](#test-module) step (module author code). A command executed in either step counts as covered, so
  framework-generated lines do not count against the module author's coverage target.
- If the code coverage is below the target, the workflow will fail here.

## Publish module

[workflow](https://github.com/PSModule/Process-PSModule/blob/main/.github/workflows/Publish-Module.yml)

- Publishes the artifact to the PowerShell Gallery exactly as built — no version mutation.
- Creates a GitHub Release using the version already stamped in the manifest.
- Attaches the built module as a `.zip` asset on the GitHub Release so consumers can download the exact bytes that were tested and pushed to the PowerShell Gallery.
- **Abandoned PR cleanup**: When a PR is closed without merging (abandoned), the workflow automatically cleans up any
  prerelease versions and tags that were created for that PR. This ensures that abandoned work doesn't leave orphaned
  prereleases in the PowerShell Gallery or repository. This behavior is controlled by the `Publish.Module.AutoCleanup`
  setting.

## Build docs

[workflow](https://github.com/PSModule/Process-PSModule/blob/main/.github/workflows/Build-Docs.yml)

- Generates documentation and lints the documentation using:
  - [super-linter](https://github.com/super-linter/super-linter).

## Build site

[workflow](https://github.com/PSModule/Process-PSModule/blob/main/.github/workflows/Build-Site.yml)

- Generates a static site using:
  - [Zensical](https://zensical.org/).
- Uses `zensical.toml` as the site configuration contract.

## Publish Docs

[workflow](https://github.com/PSModule/Process-PSModule/blob/main/.github/workflows/Publish-Docs.yml)
