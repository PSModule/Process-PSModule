# Process-PSModule

Process-PSModule is the corner-stone of the PSModule framework. It is an end-to-end GitHub Actions workflow that automates the entire lifecycle of a
PowerShell module. The workflow builds the PowerShell module, runs cross-platform tests, enforces code quality and coverage requirements, generates
documentation, and publishes module to the PowerShell Gallery and its documentation site to GitHub Pages. It is the core workflow used across all
PowerShell modules in the [PSModule organization](https://github.com/PSModule), ensuring reliable, automated, and maintainable delivery of PowerShell
projects.

## How to get started

1. [Create a repository from the Template-Module](https://github.com/new?template_name=Template-PSModule&template_owner=PSModule&description=Add%20a%20description%20(required)&name=%3CModule%20name%3E).
2. Configure the repository:
   1. Enable GitHub Pages in the repository settings. Set it to deploy from **GitHub Actions**.
   2. This will create an environment called `github-pages` that GitHub deploys your site to.
      <details><summary>Within the <code>github-pages</code> environment, remove the branch protection for <code>main</code>.</summary>
        <img src="./media/pagesEnvironment.png" alt="Remove the branch protection on main">
      </details>
   3. [Create an API key on the PowerShell Gallery](https://www.powershellgallery.com/account/apikeys). Give it permission to manage the module you
      are working on.
   4. Create a new secret called `APIKEY` in the repository and set the API key for the PowerShell Gallery as its value.
   5. If you are planning on creating many modules, you could use a glob pattern for the API key permissions in PowerShell Gallery and store the
      secret on the organization.
3. Clone the repo locally, create a branch, make your changes, push the changes, create a PR and let the workflow run.
   - Adding a `Prerelease` label to the PR will create a prerelease version of the module.
4. When merging to `main`, the workflow automatically builds, tests, and publishes your module to the PowerShell Gallery and maintains the
   documentation on GitHub Pages. By default the process releases a patch version, which you can change by applying labels like `minor` or `major` on
   the PR to bump the version accordingly.

## How it works

Everything is packaged into this single workflow to simplify full configuration of the workflow via this repository. Simplifying management and
operations across all PowerShell module projects. A user can configure how it works by simply configuring settings using a single file.

### Workflow overview

The workflow is designed to be triggered on pull requests to the repository's default branch.
When a pull request is opened, closed, reopened, synchronized (push), or labeled, the workflow will run.
Depending on the labels in the pull requests, the [workflow will result in different outcomes](#scenario-matrix).

![Process diagram](./media/Process-PSModule.png)

- [Process-PSModule](#process-psmodule)
  - [How to get started](#how-to-get-started)
  - [How it works](#how-it-works)
    - [Workflow overview](#workflow-overview)
    - [Get-Settings](#get-settings)
    - [Lint-Repository](#lint-repository)
    - [Get settings](#get-settings-1)
    - [Build module](#build-module)
    - [Test source code](#test-source-code)
    - [Lint source code](#lint-source-code)
    - [Framework test](#framework-test)
    - [Test module](#test-module)
      - [Setup and Teardown Scripts](#setup-and-teardown-scripts)
        - [Setup - `BeforeAll.ps1`](#setup---beforeallps1)
          - [Example - `BeforeAll.ps1`](#example---beforeallps1)
        - [Teardown - `AfterAll.ps1`](#teardown---afterallps1)
          - [Example - `AfterAll.ps1`](#example---afterallps1)
      - [Module tests](#module-tests)
    - [Get test results](#get-test-results)
    - [Get code coverage](#get-code-coverage)
    - [Publish module](#publish-module)
    - [Build docs](#build-docs)
    - [Build site](#build-site)
    - [Publish Docs](#publish-docs)
  - [Usage](#usage)
    - [Inputs](#inputs)
    - [Secrets](#secrets)
    - [Permissions](#permissions)
    - [Scenario Matrix](#scenario-matrix)
    - [Important file change detection](#important-file-change-detection)
      - [Default files that trigger releases](#default-files-that-trigger-releases)
      - [Customizing important file patterns](#customizing-important-file-patterns)
      - [Files that do NOT trigger releases](#files-that-do-not-trigger-releases)
      - [Behavior when no important files are changed](#behavior-when-no-important-files-are-changed)
  - [Configuration](#configuration)
    - [Example 1 - Defaults with Code Coverage target](#example-1---defaults-with-code-coverage-target)
    - [Example 2 - Rapid testing](#example-2---rapid-testing)
    - [Example 3 - Configuring the Repository Linter](#example-3---configuring-the-repository-linter)
      - [Disabling the Linter](#disabling-the-linter)
      - [Configuring Linter Validation Rules](#configuring-linter-validation-rules)
      - [Additional Configuration](#additional-configuration)
      - [Showing Linter Summary on Success](#showing-linter-summary-on-success)
    - [Example 4 - Configuring PR-based release notes](#example-4---configuring-pr-based-release-notes)
      - [Default configuration (recommended)](#default-configuration-recommended)
      - [Version-only release names](#version-only-release-names)
      - [Auto-generated notes](#auto-generated-notes)
  - [Skipping Individual Framework Tests](#skipping-individual-framework-tests)
    - [How to Skip Tests](#how-to-skip-tests)
    - [Available Framework Tests](#available-framework-tests)
      - [SourceCode Tests](#sourcecode-tests)
      - [Module Tests](#module-tests-1)
    - [Example Usage](#example-usage)
    - [Best Practices](#best-practices)
    - [Related Configuration](#related-configuration)
  - [Repository structure](#repository-structure)
  - [Module source code structure](#module-source-code-structure)
  - [Principles and practices](#principles-and-practices)

### Get-Settings

[workflow](./.github/workflows/Get-Settings.yml)

### Lint-Repository

[workflow](./.github/workflows/Lint-Repository.yml)

### Get settings

[workflow](#get-settings)
- Reads the settings file `github/PSModule.yml` in the module repository to configure the workflow.
- Gathers context for the process from GitHub and the repo files, configuring what tests to run, if and what kind of release to create, and whether
  to setup testing infrastructure and what operating systems to run the tests on.

### Build module

[workflow](./.github/workflows/Build-Module.yml)
- Compiles the module source code into a PowerShell module.

### Test source code

[workflow](./.github/workflows/Test-SourceCode.yml)
- Tests the source code in parallel (matrix) using:
  - [PSModule framework settings for style and standards for source code](https://github.com/PSModule/Test-PSModule?tab=readme-ov-file#sourcecode-tests)
- This produces a JSON-based report that is used by [Get-PesterTestResults](#get-test-results) evaluate the results of the tests.

The [PSModule - SourceCode tests](./scripts/tests/SourceCode/PSModule/PSModule.Tests.ps1) verifies the following coding practices that the framework enforces:

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


### Lint source code

[workflow](./.github/workflows/Lint-SourceCode.yml)
- Lints the source code in parallel (matrix) using:
  - [PSScriptAnalyzer rules](https://github.com/PSModule/Invoke-ScriptAnalyzer)
- This produces a JSON-based report that is used by [Get-PesterTestResults](#get-test-results) evaluate the results of the linter.

### Framework test

[workflow](./.github/workflows/Test-Module.yml)
- Tests and lints the module in parallel (matrix) using:
  - [PSModule framework settings for style and standards for modules](https://github.com/PSModule/Test-PSModule?tab=readme-ov-file#module-tests)
  - [PSScriptAnalyzer rules](https://github.com/PSModule/Invoke-ScriptAnalyzer)
- This produces a JSON-based report that is used by [Get-PesterTestResults](#get-test-results) evaluate the results of the tests.

### Test module

[workflow](./.github/workflows/Test-ModuleLocal.yml)
- Imports and tests the module in parallel (matrix) using Pester tests from the module repository.
- Supports setup and teardown scripts executed via separate dedicated jobs:
  - `BeforeAll`: Runs once before all test matrix jobs to set up the test environment (e.g., deploy infrastructure, download test data).
  - `AfterAll`: Runs once after all test matrix jobs complete to clean up the test environment (e.g., remove test resources, clean up databases).
- Setup/teardown scripts are automatically detected in test directories and executed with the same environment variables as the tests.
- This produces a JSON-based report that is used by [Get-PesterTestResults](#get-test-results) evaluate the results of the tests.

#### Setup and Teardown Scripts

The workflow supports automatic execution of setup and teardown scripts for module tests:

- Scripts are automatically detected and executed if present.
- If no scripts are found, the workflow continues normally.

##### Setup - `BeforeAll.ps1`

- Place in your test directories (`tests/BeforeAll.ps1`).
- Runs once before all test matrix jobs to prepare the test environment.
- Deploy test infrastructure, download test data, initialize databases, or configure services.
- Has access to the same environment variables as your tests (secrets, GitHub token, etc.).

###### Example - `BeforeAll.ps1`

```powershell
Write-Host "Setting up test environment..."
# Deploy test infrastructure
# Download test data
# Initialize test databases
Write-Host "Test environment ready!"
```

##### Teardown - `AfterAll.ps1`

- Place in your test directories (`tests/AfterAll.ps1`).
- Runs once after all test matrix jobs complete to clean up the test environment.
- Remove test resources, clean up databases, stop services, or upload artifacts.
- Has access to the same environment variables as your tests.

###### Example - `AfterAll.ps1`

```powershell
Write-Host "Cleaning up test environment..."
# Remove test resources
# Clean up databases
# Stop services
Write-Host "Cleanup completed!"
```


#### Module tests

The [PSModule - Module tests](./scripts/tests/Module/PSModule/PSModule.Tests.ps1) verifies the following coding practices that the framework enforces:

| Name | Description |
| ------ | ----------- |
| Module Manifest exists | Verifies that a module manifest file is present. |
| Module Manifest is valid | Verifies that the module manifest file is valid. |

### Get test results

[workflow](./.github/workflows/Get-TestResults.yml)
- Gathers the test results from the previous steps and creates a summary of the results.
- If any tests have failed, the workflow will fail here.

### Get code coverage

[workflow](./.github/workflows/Get-CodeCoverage.yml)
- Gathers the code coverage from the previous steps and creates a summary of the results.
- If the code coverage is below the target, the workflow will fail here.

### Publish module

[workflow](./.github/workflows/Publish-Module.yml)
- Publishes the module to the PowerShell Gallery.
- Creates a release on the GitHub repository.
- **Abandoned PR cleanup**: When a PR is closed without merging (abandoned), the workflow automatically cleans up any
  prerelease versions and tags that were created for that PR. This ensures that abandoned work doesn't leave orphaned
  prereleases in the PowerShell Gallery or repository. This behavior is controlled by the `Publish.Module.AutoCleanup`
  setting.

### Build docs

[workflow](./.github/workflows/Build-Docs.yml)
- Generates documentation and lints the documentation using:
  - [super-linter](https://github.com/super-linter/super-linter).

### Build site

[workflow](./.github/workflows/Build-Site.yml)
- Generates a static site using:
  - [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/).

### Publish Docs

[workflow](./.github/workflows/Publish-Docs.yml)

## Usage

To use the workflow, create a new file in the `.github/workflows` directory of the module repository and add the following content.

<details>
<summary>Workflow suggestion</summary>

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
      APIKEY: ${{ secrets.APIKEY }}
```

</details>

### Inputs

| Name | Type | Description | Required | Default |
| ---- | ---- | ----------- | -------- | ------- |
| `SettingsPath` | `string` | The path to the settings file. All workflow configuration is controlled through this settings file. | `false` | `.github/PSModule.yml` |
| `Debug` | `boolean` | Enable debug output. | `false` | `false` |
| `Verbose` | `boolean` | Enable verbose output. | `false` | `false` |
| `Version` | `string` | Specifies the version of the GitHub module to be installed. The value must be an exact version. | `false` | `''` |
| `Prerelease` | `boolean` | Whether to use a prerelease version of the 'GitHub' module. | `false` | `false` |
| `WorkingDirectory` | `string` | The path to the root of the repo. | `false` | `'.'` |

### Secrets

The following secrets are used by the workflow. They can be automatically provided (if available) by setting `secrets: inherit` in the workflow file.

| Name | Location       | Description                                                               | Default |
| ---- | -------------- | ------------------------------------------------------------------------- | ------- |
| `APIKEY`                 | GitHub secrets | The API key for the PowerShell Gallery.                                      | N/A |
| `TEST_APP_ENT_CLIENT_ID` | GitHub secrets | The client ID of an Enterprise GitHub App for running tests.                 | N/A |
| `TEST_APP_ENT_PRIVATE_KEY` | GitHub secrets | The private key of an Enterprise GitHub App for running tests.             | N/A |
| `TEST_APP_ORG_CLIENT_ID` | GitHub secrets | The client ID of an Organization GitHub App for running tests.              | N/A |
| `TEST_APP_ORG_PRIVATE_KEY` | GitHub secrets | The private key of an Organization GitHub App for running tests.           | N/A |
| `TEST_USER_ORG_FG_PAT`   | GitHub secrets | The fine-grained PAT with organization access for running tests.           | N/A |
| `TEST_USER_USER_FG_PAT`  | GitHub secrets | The fine-grained PAT with user account access for running tests.           | N/A |
| `TEST_USER_PAT`          | GitHub secrets | The classic personal access token for running tests.                       | N/A |

### Permissions

The following permissions are needed for the workflow to be able to perform all tasks.

```yaml
permissions:
  contents: write      # to checkout the repo and create releases on the repo
  pull-requests: write # to write comments to PRs
  statuses: write      # to update the status of the workflow from linter
  pages: write         # to deploy to Pages
  id-token: write      # to verify the Pages deployment originates from an appropriate source
```

For more info, see [Deploy GitHub Pages site](https://github.com/marketplace/actions/deploy-github-pages-site).

### Scenario Matrix

This table shows when each job runs based on the trigger scenario:

| Job                       | Open/Updated PR | Merged PR  | Abandoned PR | Manual Run |
| ------------------------- | --------------- | ---------- | ------------ | ---------- |
| **Get-Settings**          | ✅ Always       | ✅ Always  | ✅ Always    | ✅ Always  |
| **Lint-Repository**       | ✅ Yes          | ❌ No      | ❌ No        | ❌ No      |
| **Build-Module**          | ✅ Yes          | ✅ Yes     | ❌ No        | ✅ Yes     |
| **Build-Docs**            | ✅ Yes          | ✅ Yes     | ❌ No        | ✅ Yes     |
| **Build-Site**            | ✅ Yes          | ✅ Yes     | ❌ No        | ✅ Yes     |
| **Test-SourceCode**       | ✅ Yes          | ✅ Yes     | ❌ No        | ✅ Yes     |
| **Lint-SourceCode**       | ✅ Yes          | ✅ Yes     | ❌ No        | ✅ Yes     |
| **Test-Module**           | ✅ Yes          | ✅ Yes     | ❌ No        | ✅ Yes     |
| **BeforeAll-ModuleLocal** | ✅ Yes          | ✅ Yes     | ❌ No        | ✅ Yes     |
| **Test-ModuleLocal**      | ✅ Yes          | ✅ Yes     | ❌ No        | ✅ Yes     |
| **AfterAll-ModuleLocal**  | ✅ Yes          | ✅ Yes     | ✅ Yes*      | ✅ Yes     |
| **Get-TestResults**       | ✅ Yes          | ✅ Yes     | ❌ No        | ✅ Yes     |
| **Get-CodeCoverage**      | ✅ Yes          | ✅ Yes     | ❌ No        | ✅ Yes     |
| **Publish-Site**          | ❌ No           | ✅ Yes     | ❌ No        | ❌ No      |
| **Publish-Module**        | ✅ Yes**        | ✅ Yes**   | ✅ Yes***    | ✅ Yes**   |

- \* Runs for cleanup if tests were started
- \*\* Only when all tests/coverage/build succeed
- \*\*\* Cleans up prerelease versions and tags created for the abandoned PR (when `Publish.Module.AutoCleanup` is
  enabled)

### Important file change detection

The workflow automatically detects whether a pull request contains changes to "important" files that warrant a new
release. This prevents unnecessary releases when only non-functional files (such as workflow configurations, linter
settings, or test files) are modified.

#### Default files that trigger releases

By default, the following file patterns are considered important and will trigger a release:

| Pattern | Description |
| :------ | :---------- |
| `^src/` | Module source code |
| `^README\.md$` | Module documentation |

These patterns are regular expressions matched against the file paths changed in a pull request.

#### Customizing important file patterns

You can override the default patterns using the `Publish.Module.ImportantFilesPatterns` setting in your
`PSModule.yml` file. The value is a comma-separated list of regular expression patterns:

```yaml
Publish:
  Module:
    ImportantFilesPatterns: '^src/, ^README\.md$'
```

For example, to also trigger releases when example scripts or a changelog are modified:

```yaml
Publish:
  Module:
    ImportantFilesPatterns: '^src/, ^README\.md$, ^examples/, ^CHANGELOG\.md$'
```

#### Files that do NOT trigger releases

Changes to files that do not match any of the important file patterns will not trigger a release.
With the default patterns, this includes:

- `.github/workflows/*` - Workflow configurations
- `.github/linters/*` - Linter configuration files
- `tests/**` - Test files
- `examples/**` - Example scripts
- `.gitignore`, `.editorconfig`, etc. - Repository configuration files

#### Behavior when no important files are changed

When a pull request does not contain changes to important files:

1. A comment is automatically added to the PR explaining why build/test stages are skipped
2. The `ReleaseType` output is set to `None`
3. Build, test, and publish stages are skipped
4. The PR can still be merged for non-release changes (documentation updates, CI improvements, etc.)

This behavior ensures that maintenance PRs (such as updating GitHub Actions versions or fixing typos in comments)
don't create unnecessary releases in the PowerShell Gallery.

## Configuration

The workflow is configured using a settings file in the module repository.
The file can be a `JSON`, `YAML`, or `PSD1` file. By default, it will look for `.github/PSModule.yml`.

The following settings are available in the settings file:

| Name                                      | Type      | Description                                                                                                                                                          | Default             |
| ----------------------------------------- | --------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------- |
| `Name`                                    | `String`  | Name of the module to publish. Defaults to the repository name.                                                                                                      | `null`              |
| `Test.Skip`                               | `Boolean` | Skip all tests                                                                                                                                                       | `false`             |
| `Test.Linux.Skip`                         | `Boolean` | Skip tests on Linux                                                                                                                                                  | `false`             |
| `Test.MacOS.Skip`                         | `Boolean` | Skip tests on macOS                                                                                                                                                  | `false`             |
| `Test.Windows.Skip`                       | `Boolean` | Skip tests on Windows                                                                                                                                                | `false`             |
| `Test.SourceCode.Skip`                    | `Boolean` | Skip source code tests                                                                                                                                               | `false`             |
| `Test.SourceCode.Linux.Skip`              | `Boolean` | Skip source code tests on Linux                                                                                                                                      | `false`             |
| `Test.SourceCode.MacOS.Skip`              | `Boolean` | Skip source code tests on macOS                                                                                                                                      | `false`             |
| `Test.SourceCode.Windows.Skip`            | `Boolean` | Skip source code tests on Windows                                                                                                                                    | `false`             |
| `Test.PSModule.Skip`                      | `Boolean` | Skip PSModule framework tests                                                                                                                                        | `false`             |
| `Test.PSModule.Linux.Skip`                | `Boolean` | Skip PSModule framework tests on Linux                                                                                                                               | `false`             |
| `Test.PSModule.MacOS.Skip`                | `Boolean` | Skip PSModule framework tests on macOS                                                                                                                               | `false`             |
| `Test.PSModule.Windows.Skip`              | `Boolean` | Skip PSModule framework tests on Windows                                                                                                                             | `false`             |
| `Test.Module.Skip`                        | `Boolean` | Skip module tests                                                                                                                                                    | `false`             |
| `Test.Module.Linux.Skip`                  | `Boolean` | Skip module tests on Linux                                                                                                                                           | `false`             |
| `Test.Module.MacOS.Skip`                  | `Boolean` | Skip module tests on macOS                                                                                                                                           | `false`             |
| `Test.Module.Windows.Skip`                | `Boolean` | Skip module tests on Windows                                                                                                                                         | `false`             |
| `Test.TestResults.Skip`                   | `Boolean` | Skip test result processing                                                                                                                                          | `false`             |
| `Test.CodeCoverage.Skip`                  | `Boolean` | Skip code coverage tests                                                                                                                                             | `false`             |
| `Test.CodeCoverage.PercentTarget`         | `Integer` | Target code coverage percentage                                                                                                                                      | `0`                 |
| `Test.CodeCoverage.StepSummaryMode`       | `String`  | Step summary mode for code coverage reports                                                                                                                          | `'Missed, Files'`   |
| `Build.Skip`                              | `Boolean` | Skip all build tasks                                                                                                                                                 | `false`             |
| `Build.Module.Skip`                       | `Boolean` | Skip module build                                                                                                                                                    | `false`             |
| `Build.Docs.Skip`                         | `Boolean` | Skip documentation build                                                                                                                                             | `false`             |
| `Build.Docs.ShowSummaryOnSuccess`         | `Boolean` | Show super-linter summary on success for documentation linting                                                                                                       | `false`             |
| `Build.Site.Skip`                         | `Boolean` | Skip site build                                                                                                                                                      | `false`             |
| `Publish.Module.Skip`                     | `Boolean` | Skip module publishing                                                                                                                                               | `false`             |
| `Publish.Module.AutoCleanup`              | `Boolean` | Automatically clean up old prerelease tags when merging to main or when a PR is abandoned                                                                            | `true`              |
| `Publish.Module.AutoPatching`             | `Boolean` | Automatically patch module version                                                                                                                                   | `true`              |
| `Publish.Module.IncrementalPrerelease`    | `Boolean` | Use incremental prerelease versioning                                                                                                                                | `true`              |
| `Publish.Module.DatePrereleaseFormat`     | `String`  | Format for date-based prerelease (uses [.NET DateTime format strings](https://learn.microsoft.com/dotnet/standard/base-types/standard-date-and-time-format-strings)) | `''`                |
| `Publish.Module.VersionPrefix`            | `String`  | Prefix for version tags                                                                                                                                              | `'v'`               |
| `Publish.Module.MajorLabels`              | `String`  | Labels indicating a major version bump                                                                                                                               | `'major, breaking'` |
| `Publish.Module.MinorLabels`              | `String`  | Labels indicating a minor version bump                                                                                                                               | `'minor, feature'`  |
| `Publish.Module.PatchLabels`              | `String`  | Labels indicating a patch version bump                                                                                                                               | `'patch, fix'`      |
| `Publish.Module.IgnoreLabels`             | `String`  | Labels indicating no release                                                                                                                                         | `'NoRelease'`       |
| `Publish.Module.UsePRTitleAsReleaseName`  | `Boolean` | Use the PR title as the GitHub release name instead of version string                                                                                                | `false`             |
| `Publish.Module.UsePRBodyAsReleaseNotes`  | `Boolean` | Use the PR body as the release notes content                                                                                                                         | `true`              |
| `Publish.Module.UsePRTitleAsNotesHeading` | `Boolean` | Prepend PR title as H1 heading with PR number link before the body                                                                                                   | `true`              |
| `Publish.Module.ImportantFilesPatterns`   | `String`  | Comma-separated list of regex patterns for files that trigger a release (see [Important file change detection](#important-file-change-detection))                     | `'^src/, ^README\.md$'` |
| `Linter.Skip`                             | `Boolean` | Skip repository linting                                                                                                                                              | `false`             |
| `Linter.ShowSummaryOnSuccess`             | `Boolean` | Show super-linter summary on success for repository linting                                                                                                          | `false`             |
| `Linter.env`                              | `Object`  | Environment variables for super-linter configuration                                                                                                                 | `{}`                |

<details>
<summary>`PSModule.yml` with all defaults</summary>

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
    ImportantFilesPatterns: '^src/, ^README\.md$'
    UsePRTitleAsReleaseName: false
    UsePRBodyAsReleaseNotes: true
    UsePRTitleAsNotesHeading: true

Linter:
  Skip: false
  ShowSummaryOnSuccess: false
  env: {}
```

</details>

### Example 1 - Defaults with Code Coverage target

This example runs all steps and will require that code coverage is 80% before passing.

```yaml
Test:
  CodeCoverage:
    PercentTarget: 80
```

### Example 2 - Rapid testing

This example ends up running Get-Settings, Build-Module and Test-Module (tests from the module repo) on **ubuntu-latest** only.

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

### Example 3 - Configuring the Repository Linter

The workflow uses [super-linter](https://github.com/super-linter/super-linter) to lint your repository code.
The linter runs on pull requests and provides status updates directly in the PR.

#### Disabling the Linter

You can skip repository linting entirely:

```yaml
Linter:
  Skip: true
```

#### Configuring Linter Validation Rules

The workflow supports all environment variables that **super-linter** provides. You can configure these through the `Linter.env` object:

```yaml
Linter:
  env:
    # Disable specific validations
    VALIDATE_BIOME_FORMAT: false
    VALIDATE_BIOME_LINT: false
    VALIDATE_GITHUB_ACTIONS_ZIZMOR: false
    VALIDATE_JSCPD: false
    VALIDATE_JSON_PRETTIER: false
    VALIDATE_MARKDOWN_PRETTIER: false
    VALIDATE_YAML_PRETTIER: false

    # Or enable only specific validations
    VALIDATE_YAML: true
    VALIDATE_JSON: true
    VALIDATE_MARKDOWN: true
```

#### Additional Configuration

Any super-linter environment variable can be set through the `Linter.env` object:

```yaml
Linter:
  env:
    LOG_LEVEL: DEBUG
    FILTER_REGEX_EXCLUDE: '.*test.*'
    VALIDATE_ALL_CODEBASE: false
```

#### Showing Linter Summary on Success

By default, the linter only shows a summary when it finds issues. You can enable summary display on successful runs:

```yaml
Linter:
  ShowSummaryOnSuccess: true
```

This is useful for reviewing what was checked even when no issues are found.

**Note:** The `GITHUB_TOKEN` is automatically provided by the workflow to enable status updates in pull requests.

For a complete list of available environment variables and configuration options, see the
[super-linter environment variables documentation](https://github.com/super-linter/super-linter#environment-variables).

### Example 4 - Configuring PR-based release notes

The workflow can automatically generate GitHub release names and notes from your pull request content.
Three parameters control this behavior:

| Parameter | Description |
|-----------|-------------|
| `UsePRTitleAsReleaseName` | Use the PR title as the GitHub release name instead of the version string |
| `UsePRBodyAsReleaseNotes` | Use the PR body as the release notes content |
| `UsePRTitleAsNotesHeading` | Prepend PR title as H1 heading with PR number link before the body |

These parameters follow specific precedence rules when building release notes:

1. **Heading + Body** (`UsePRTitleAsNotesHeading: true` + `UsePRBodyAsReleaseNotes: true`): Creates formatted notes with the PR title as an H1 heading followed by the PR body. The output format is `# PR Title (#123)\n\nPR body content`. Both the PR title and body must be present.
1. **Body only** (`UsePRBodyAsReleaseNotes: true`): Uses the PR body as-is for release notes. Takes effect when heading option is disabled or PR title is missing.
1. **Fallback**: When neither option is enabled or required PR content is missing, GitHub's auto-generated release notes are used via `--generate-notes`.

#### Default configuration (recommended)

The defaults provide rich release notes with the PR title as a heading:

```yaml
Publish:
  Module:
    UsePRTitleAsReleaseName: false
    UsePRBodyAsReleaseNotes: true
    UsePRTitleAsNotesHeading: true
```

This produces release notes like:

```markdown
# 🚀 Add new authentication feature (#42)

This PR adds OAuth2 support with the following changes:
- Added `Connect-OAuth2` function
- Updated documentation
```

#### Version-only release names

If you prefer version numbers as release names but still want PR-based notes:

```yaml
Publish:
  Module:
    UsePRTitleAsReleaseName: false
    UsePRBodyAsReleaseNotes: true
    UsePRTitleAsNotesHeading: false
```

#### Auto-generated notes

To use GitHub's auto-generated release notes instead of PR content:

```yaml
Publish:
  Module:
    UsePRTitleAsReleaseName: false
    UsePRBodyAsReleaseNotes: false
    UsePRTitleAsNotesHeading: false
```

## Skipping Individual Framework Tests

The PSModule framework tests run automatically as part of the `Test-Module` and `Test-SourceCode` jobs. While you can skip entire test categories using the configuration settings (e.g., `Test.PSModule.Skip`), you can also skip individual framework tests on a per-file basis when needed.

### How to Skip Tests

To skip an individual framework test for a specific file, add a special comment at the top of that file:

```powershell
#SkipTest:<TestID>:<Reason>
```

- `<TestID>`: The unique identifier of the test to skip (see list below)
- `<Reason>`: A brief explanation of why the test is being skipped

The skip comment will cause the framework to skip that specific test for that file only, and will log a warning in the build output with the reason provided.

### Available Framework Tests

#### SourceCode Tests

These tests run against your source code files in the `src` directory:

| Test ID | Description | Example Skip Comment |
|---------|-------------|---------------------|
| `NumberOfProcessors` | Enforces use of `[System.Environment]::ProcessorCount` instead of `$env:NUMBER_OF_PROCESSORS` | `#SkipTest:NumberOfProcessors:Legacy code compatibility required` |
| `Verbose` | Ensures code does not pass `-Verbose` to other commands (which would override user preference), unless explicitly disabled with `-Verbose:$false` | `#SkipTest:Verbose:Required for debugging output` |
| `OutNull` | Enforces use of `$null = ...` instead of `... \| Out-Null` for better performance | `#SkipTest:OutNull:Pipeline processing required` |
| `NoTernary` | Prohibits ternary operators for PowerShell 5.1 compatibility (this test is skipped by default in the framework) | `#SkipTest:NoTernary:PowerShell 7+ only module` |
| `LowercaseKeywords` | Ensures all PowerShell keywords are lowercase | `#SkipTest:LowercaseKeywords:Generated code` |
| `FunctionCount` | Ensures each file contains exactly one function | `#SkipTest:FunctionCount:Helper functions included` |
| `FunctionName` | Ensures the filename matches the function name | `#SkipTest:FunctionName:Legacy naming convention` |
| `CmdletBinding` | Requires all functions to have `[CmdletBinding()]` attribute | `#SkipTest:CmdletBinding:Simple helper function` |
| `ParamBlock` | Requires all functions to have a `param()` block | `#SkipTest:ParamBlock:No parameters needed` |
| `FunctionTest` | Ensures all public functions have corresponding tests | `#SkipTest:FunctionTest:Test in development` |

#### Module Tests

These tests run against the compiled module in the `outputs/module` directory:

- Module import validation
- Module manifest validation

Module tests typically don't need to be skipped as they validate the final built module.

### Example Usage

Here's an example of a function file that skips the `FunctionCount` test because it includes helper functions:

```powershell
#SkipTest:FunctionCount:This file contains helper functions for the main function

function Get-ComplexData {
    <#
        .SYNOPSIS
        Retrieves complex data using helper functions.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $data = Get-RawData -Path $Path
    $processed = Format-ComplexData -Data $data
    return $processed
}

function Get-RawData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )
    # Helper function implementation
}

function Format-ComplexData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Data
    )
    # Helper function implementation
}
```

### Best Practices

- **Use skip comments sparingly**: Framework tests exist to maintain code quality and consistency. Only skip tests when absolutely necessary.
- **Provide clear reasons**: Always include a meaningful explanation in the skip comment to help reviewers understand why the test is being skipped.
- **Consider alternatives**: Before skipping a test, consider whether refactoring the code to comply with the test would be better for long-term maintainability.
- **Document exceptions**: If you skip a test, document the reason in your PR description or code comments.

### Related Configuration

For broader test control, use the configuration file settings:

- Skip all framework tests: `Test.PSModule.Skip: true`
- Skip only source code tests: `Test.SourceCode.Skip: true`
- Skip framework tests on specific OS: `Test.PSModule.Windows.Skip: true`

See the [Configuration](#configuration) section for more details.

## Repository structure

Process-PSModule expects repositories to follow the staged layout produced by Template-PSModule. The workflow inspects this structure to decide what to compile, document, and publish.

```plaintext
<ModuleName>/
├── .github/                                   # Workflow config, doc/site templates, automation policy
│   ├── linters/                               # Rule sets applied by shared lint steps
│   │   ├── .markdown-lint.yml                 # Markdown rules enforced via super-linter
│   │   ├── .powershell-psscriptanalyzer.psd1  # Analyzer profile for test jobs
│   │   └── .textlintrc                        # Text lint rules surfaced in Build Docs summaries
│   ├── workflows/                             # Entry points for the reusable workflow
│   │   └── Process-PSModule.yml               # Consumer hook into this workflow bundle
│   ├── CODEOWNERS                             # Default reviewers enforced by Process-PSModule checks
│   ├── dependabot.yml                         # Dependency update cadence handled by GitHub
│   ├── mkdocs.yml                             # MkDocs config consumed during site builds
│   ├── PSModule.yml                           # Settings parsed to drive matrices
│   └── release.yml                            # Release automation template invoked on publish
├── examples/                                  # Samples referenced in generated documentation
│   └── General.ps1                            # Example script ingested by Document-PSModule
├── icon/                                      # Icon assets linked from manifest and documentation
│   └── icon.png                               # Default module icon (PNG format)
├── src/                                       # Module source, see "Module source code structure" below
├── tests/                                     # Pester suites executed during validation
│   ├── AfterAll.ps1 (optional)                # Cleanup script for ModuleLocal runs
│   ├── BeforeAll.ps1 (optional)               # Setup script for ModuleLocal runs
│   └── <ModuleName>.Tests.ps1                 # Primary test entry point
├── .gitattributes                             # Normalizes line endings across platforms
├── .gitignore                                 # Excludes build artifacts from source control
├── LICENSE                                    # License text surfaced in manifest metadata
└── README.md                                  # Repository overview rendered on GitHub and docs landing
```

Key expectations:

- Keep at least one exported function under `src/functions/public/` and corresponding tests in `tests/`.
- Optional folders (`assemblies`, `formats`, `types`, `variables`, and others) are processed automatically when present.
- Markdown files in `src/functions/public` subfolders become documentation pages alongside generated help.
- The build step compiles `src/` into a root module file and removes the original project layout from the artifact.
- Documentation generation mirrors the `src/functions/public` hierarchy so help content always aligns with source.

## Module source code structure

How the module is built.

```plaintext
├── src/                                    # Module source compiled and documented by the pipeline
│   ├── assemblies/                         # Bundled binaries copied into the build artifact
│   ├── classes/                            # Class scripts merged into the root module
│   │   ├── private/                        # Internal classes kept out of exports
│   │   │   └── SecretWriter.ps1            # Example internal class implementation
│   │   └── public/                         # Public classes exported via type accelerators
│   │       └── Book.ps1                    # Example public class documented for consumers
│   ├── data/                               # Configuration loaded into `$script:` scope at runtime
│   │   ├── Config.psd1                     # Example config surfaced in generated help
│   │   └── Settings.psd1                   # Additional configuration consumed on import
│   ├── formats/                            # Formatting metadata registered during build
│   │   ├── CultureInfo.Format.ps1xml       # Example format included in manifest
│   │   └── Mygciview.Format.ps1xml         # Additional format loaded at import
│   ├── functions/                          # Function scripts exported by the module
│   │   ├── private/                        # Helper functions scoped to the module
│   │   │   ├── Get-InternalPSModule.ps1    # Sample internal helper
│   │   │   └── Set-InternalPSModule.ps1    # Sample internal helper
│   │   └── public/                         # Public commands documented and tested
│   │       ├── Category/                   # Optional: organize commands into categories
│   │       │   ├── Get-CategoryCommand.ps1 # Command file within category
│   │       │   └── Category.md             # Category overview merged into docs output
│   │       ├── Get-PSModuleTest.ps1        # Example command captured by Microsoft.PowerShell.PlatyPS
│   │       ├── New-PSModuleTest.ps1        # Example command exported and tested
│   │       ├── Set-PSModuleTest.ps1        # Example command exported and tested
│   │       └── Test-PSModuleTest.ps1       # Example command exported and tested
│   ├── init/                               # Initialization scripts executed during module load
│   │   └── initializer.ps1                 # Example init script included in build output
│   ├── modules/                            # Nested modules packaged with the compiled output
│   │   └── OtherPSModule.psm1              # Example nested module staged for export
│   ├── scripts/                            # Scripts listed in 'ScriptsToProcess'
│   │   └── loader.ps1                      # Loader executed when the module imports
│   ├── types/                              # Type data merged into the manifest
│   │   ├── DirectoryInfo.Types.ps1xml      # Type definition registered on import
│   │   └── FileInfo.Types.ps1xml           # Type definition registered on import
│   ├── variables/                          # Variable scripts exported by the module
│   │   ├── private/                        # Internal variables scoped to the module
│   │   │   └── PrivateVariables.ps1        # Example private variable seed
│   │   └── public/                         # Public variables exported and documented
│   │       ├── Moons.ps1                   # Example variable surfaced in generated docs
│   │       ├── Planets.ps1                 # Example variable surfaced in generated docs
│   │       └── SolarSystems.ps1            # Example variable surfaced in generated docs
│   ├── finally.ps1                         # Cleanup script appended to the root module
│   ├── header.ps1                          # Optional header injected at the top of the module
│   ├── manifest.psd1 (optional)            # Source manifest reused when present
│   └── README.md                           # Module-level docs ingested by Document-PSModule
```

## Principles and practices

The contribution and release process is based on the idea that a PR is a release, and we only maintain a single linear ancestry of versions, not going
back to patch and update old versions of the modules. This means that if we are on version `2.1.3` of a module and there is a security issue, we only
patch the latest version with a fix, not releasing new versions based on older versions of the module, i.e. not updating the latest 1.x with the
patch.

If you need to work forth a bigger release, create a branch representing the release (a release branch) and open a PR towards `main` for this branch.
For each topic or feature to add to the release, open a new branch representing the feature (a feature branch) and open a PR towards the release
branch. Optionally add the `Prerelease` label on the PR for the release branch, to release preview versions before merging and releasing a published
version of the PowerShell module.


The process is compatible with:

- [Test-Driven Development](https://testdriven.io/test-driven-development/) using [Pester](https://pester.dev) and [PSScriptAnalyzer](https://learn.microsoft.com/powershell/utility-modules/psscriptanalyzer/overview)
- [GitHub Flow specifications](https://docs.github.com/en/get-started/using-github/github-flow)
- [SemVer 2.0.0 specifications](https://semver.org)
- [Continuous Delivery practices](https://en.wikipedia.org/wiki/Continuous_delivery)
