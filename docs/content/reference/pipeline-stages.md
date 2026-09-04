---
title: Pipeline stages
description: The job-by-job breakdown of the Process-PSModule workflow, from Plan through Publish Docs.
---

# Pipeline stages

The Process-PSModule workflow composes its work from a set of reusable jobs. Each
one is described below, in the order it runs, with a link to the workflow that
implements it.

For which of these jobs run in a given trigger scenario, see the [scenario matrix](scenario-matrix.md).

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

For the coding practices this step enforces, see [framework test IDs](framework-test-ids.md#source-code-tests).

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

For the checks this step enforces on the built module, see [framework test IDs](framework-test-ids.md#module-tests).

## Test module

[workflow](https://github.com/PSModule/Process-PSModule/blob/main/.github/workflows/Test-ModuleLocal.yml)

- Imports and tests the module in parallel (matrix) using module-local Pester tests.
- Discovers module-local tests recursively under `tests/`, applying a [per-directory precedence](../guides/writing-module-tests.md#test-discovery) independently at every level.
- Supports two special workflow phase scripts executed via separate dedicated jobs:
  - `tests/BeforeAll.ps1`: Runs once before all module-local test matrix jobs to set up the test environment.
  - `tests/AfterAll.ps1`: Runs once after all module-local test matrix jobs complete to clean up the test environment.
- The workflow checks only those exact repository-root paths; phase detection is non-recursive.
- This produces a JSON-based report that is used by [Get-PesterTestResults](#get-test-results) to evaluate the results of the tests.

How to write these tests, including the Pester version requirement and shared-infrastructure patterns, is covered in
[Writing module tests](../guides/writing-module-tests.md).

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

- An important default-branch push is the only stable-publication authority. A closed pull request performs
  prerelease cleanup only.
- Publishes the artifact to the PowerShell Gallery exactly as built — no version mutation.
- Creates a GitHub Release only after the Gallery publication succeeds, targeting the exact tested push SHA and using
  the version already stamped in the manifest.
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
- Resolves the module's canonical `.github/zensical.toml` into the staged
  site's `zensical.toml`.
- Uses Zensical's native folder-derived, alphabetical navigation when `nav` is
  omitted.

## Publish Docs

[workflow](https://github.com/PSModule/Process-PSModule/blob/main/.github/workflows/Publish-Docs.yml)
