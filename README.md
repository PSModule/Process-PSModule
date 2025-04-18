# Process-PSModule

A workflow for crafting PowerShell modules using the PSModule framework, which builds, tests and publishes PowerShell modules to the PowerShell
Gallery and produces documentation that is published to GitHub Pages. The workflow is used by all PowerShell modules in the PSModule organization.

## Specifications and practices

Process-PSModule follows:

- [Test-Driven Development](https://testdriven.io/test-driven-development/) using [Pester](https://pester.dev) and [PSScriptAnalyzer](https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/overview?view=ps-modules)
- [GitHub Flow specifications](https://docs.github.com/en/get-started/using-github/github-flow)
- [SemVer 2.0.0 specifications](https://semver.org)
- [Continiuous Delivery practices](https://en.wikipedia.org/wiki/Continuous_delivery)

## How it works

The workflow is designed to be trigger on pull requests to the repository's default branch.
When a pull request is opened, closed, reopened, synchronized (push), or labeled, the workflow will run.
Depending on the labels in the pull requests, the workflow will result in different outcomes.

![Process diagram](./media/Process-PSModule.png)

- [Get settings](./.github/workflows/Get-Settings.yml)
  - Reads the settings file from a file in the module repository to configure the workflow.
  - Gathers tests and creates test configuration based on the settings and the tests available in the module repository.
  - This includes the selection of what OSes to run the tests on.
- [Build module](./.github/workflows/Build-Module.yml)
  - Compiles the module source code into a PowerShell module.
- [Test source code](./.github/workflows/Test-SourceCode.yml)
  - Tests the source code in parallel (matrix) using [PSModule framework settings for style and standards for source code](https://github.com/PSModule/Test-PSModule?tab=readme-ov-file#sourcecode-tests)
  - This produces a json based report that is used to later evaluate the results of the tests.
- [Lint source code](./.github/workflows/Lint-SourceCode.yml)
  - Lints the source code in parallel (matrix) using [PSScriptAnalyzer rules](https://github.com/PSModule/Invoke-ScriptAnalyzer).
  - This produces a json based report that is used to later evaluate the results of the linter.
- [Framework test](./.github/workflows/Test-Module.yml)
  - Tests and lints the module in parallel (matrix) using [PSModule framework settings for style and standards foor modules](https://github.com/PSModule/Test-PSModule?tab=readme-ov-file#module-tests) + [PSScriptAnalyzer rules](https://github.com/PSModule/Invoke-ScriptAnalyzer).
  - This produces a json based report that is used to later evaluate the results of the tests.
- [Test module](./.github/workflows/Test-ModuleLocal.yml)
  - Import and tests the module in parallel (matrix) using Pester tests from the module repository.
  - This produces a json based report that is used to later evaluate the results of the tests.
- [Get test results](./.github/workflows/Get-TestResults.yml)
  - Gathers the test results from the previous steps and creates a summary of the results.
  - If any tests have failed, the workflow will fail here.
- [Get code coverage](./.github/workflows/Get-CodeCoverage.yml)
  - Gathers the code coverage from the previous steps and creates a summary of the results.
  - If the code coverage is below the target, the workflow will fail here.
- [Build docs](./.github/workflows/Build-Docs.yml)
  - Generates documentation and lints the documentation using [super-linter](https://github.com/super-linter/super-linter).
- [Build site](./.github/workflows/Build-Site.yml)
  - Generates a static site using [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/).
- [Publish site](./.github/workflows/Publish-Site.yml)
  - Publishes the static site with the module documentationto GitHub Pages.
- [Publish module](./.github/workflows/Publish-Module.yml)
    - Publishes the module to the PowerShell Gallery.
    - Creates a release on the GitHub repository.

To use the workflow, create a new file in the `.github/workflows` directory of the module repository and add the following content.
<details>
<summary>Workflow suggestion</summary>

```yaml
name: Process-PSModule

on:
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

jobs:
  Process-PSModule:
    uses: PSModule/Process-PSModule/.github/workflows/workflow.yml@v2
    secrets: inherit

```
</details>

## Configuration

The workflow is configured using a settings file in the module repository.
The file can be a JSON, YML or PSD1 file. By default it will look for `.github/PSModule.yml`.

The following settings are available in the settings file:
Here's a Markdown-formatted table describing your PowerShell object structure clearly and concisely:

| Name                                   | Type      | Description                                                                                              | Default             |
|----------------------------------------|-----------|----------------------------------------------------------------------------------------------------------|---------------------|
| `Name`                                 | `String`  | Name of the module to publish. Defaults to repository name.                                              | `null`              |
| `Test.Skip`                            | `Boolean` | Skip all tests                                                                                           | `false`             |
| `Test.Linux.Skip`                      | `Boolean` | Skip tests on Linux                                                                                      | `false`             |
| `Test.MacOS.Skip`                      | `Boolean` | Skip tests on macOS                                                                                      | `false`             |
| `Test.Windows.Skip`                    | `Boolean` | Skip tests on Windows                                                                                    | `false`             |
| `Test.SourceCode.Skip`                 | `Boolean` | Skip source code tests                                                                                   | `false`             |
| `Test.SourceCode.Linux.Skip`           | `Boolean` | Skip source code tests on Linux                                                                          | `false`             |
| `Test.SourceCode.MacOS.Skip`           | `Boolean` | Skip source code tests on macOS                                                                          | `false`             |
| `Test.SourceCode.Windows.Skip`         | `Boolean` | Skip source code tests on Windows                                                                        | `false`             |
| `Test.PSModule.Skip`                   | `Boolean` | Skip PSModule framework tests                                                                            | `false`             |
| `Test.PSModule.Linux.Skip`             | `Boolean` | Skip PSModule framework tests on Linux                                                                   | `false`             |
| `Test.PSModule.MacOS.Skip`             | `Boolean` | Skip PSModule framework tests on macOS                                                                   | `false`             |
| `Test.PSModule.Windows.Skip`           | `Boolean` | Skip PSModule framework tests on Windows                                                                 | `false`             |
| `Test.Module.Skip`                     | `Boolean` | Skip module tests                                                                                        | `false`             |
| `Test.Module.Linux.Skip`               | `Boolean` | Skip module tests on Linux                                                                               | `false`             |
| `Test.Module.MacOS.Skip`               | `Boolean` | Skip module tests on macOS                                                                               | `false`             |
| `Test.Module.Windows.Skip`             | `Boolean` | Skip module tests on Windows                                                                             | `false`             |
| `Test.TestResults.Skip`                | `Boolean` | Skip test result processing                                                                              | `false`             |
| `Test.CodeCoverage.Skip`               | `Boolean` | Skip code coverage tests                                                                                 | `false`             |
| `Test.CodeCoverage.PercentTarget`      | `Integer` | Target code coverage percentage                                                                          | `0`                 |
| `Test.CodeCoverage.StepSummaryMode`    | `String`  | Step summary mode for code coverage reports                                                              | `'Missed, Files'`   |
| `Build.Skip`                           | `Boolean` | Skip all build tasks                                                                                     | `false`             |
| `Build.Module.Skip`                    | `Boolean` | Skip module build                                                                                        | `false`             |
| `Build.Docs.Skip`                      | `Boolean` | Skip documentation build                                                                                 | `false`             |
| `Build.Site.Skip`                      | `Boolean` | Skip website build                                                                                       | `false`             |
| `Publish.Module.Skip`                  | `Boolean` | Skip module publishing                                                                                   | `false`             |
| `Publish.Module.AutoCleanup`           | `Boolean` | Automatically cleanup old prerelease module versions                                                     | `true`              |
| `Publish.Module.AutoPatching`          | `Boolean` | Automatically patch module version                                                                       | `true`              |
| `Publish.Module.IncrementalPrerelease` | `Boolean` | Use incremental prerelease versioning                                                                    | `true`              |
| `Publish.Module.DatePrereleaseFormat`  | `String`  | Format for date-based prerelease ([.NET DateTime](https://learn.microsoft.com/dotnet/standard/base-types/standard-date-and-time-format-strings)) | `''`                |
| `Publish.Module.VersionPrefix`         | `String`  | Prefix for version tags                                                                                  | `'v'`               |
| `Publish.Module.MajorLabels`           | `String`  | Labels indicating a major version bump                                                                   | `'major, breaking'` |
| `Publish.Module.MinorLabels`           | `String`  | Labels indicating a minor version bump                                                                   | `'minor, feature'`  |
| `Publish.Module.PatchLabels`           | `String`  | Labels indicating a patch version bump                                                                   | `'patch, fix'`      |
| `Publish.Module.IgnoreLabels`          | `String`  | Labels indicating no release                                                                             | `'NoRelease'`       |

### Example 1 - Rapid testing

This example runs all steps and will require that code coverage is 80% before passing.

```yaml
Test:
  CodeCoverage:
    PercentTarget: 80
```

### Example 2 - Rapid testing

This example ends up running Get-Settings, Build-Module and Test-Module (tests from the module repo) on ubuntu-latest.

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

## Usage

### Inputs

| Name | Type | Description | Required | Default |
| ---- | ---- | ----------- | -------- | ------- |
| `Name` | `string` | The name of the module to process. This defaults to the repository name if nothing is specified. | `false` | N/A |
| `Path` | `string` | The path to the source code of the module. | `false` | `src` |
| `Version` | `string` | Specifies the version of the GitHub module to be installed. The value must be an exact version. | `false` | N/A |
| `Prerelease` | `boolean` | Whether to use a prerelease version of the 'GitHub' module. | `false` | `false` |
| `Debug` | `boolean` | Whether to enable debug output. Adds a `debug` step to every job. | `false` | `false` |
| `Verbose` | `boolean` | Whether to enable verbose output. | `false` | `false` |

### Secrets

The following secrets are used by the workflow. They can be automatically provided (if available) by setting the `secrets: inherit`
in the workflow file.

| Name | Location | Description | Default |
| ---- | -------- | ----------- | ------- |
| `GITHUB_TOKEN` | `github` context | The token used to authenticate with GitHub. | `${{ secrets.GITHUB_TOKEN }}` |
| `APIKey` | GitHub secrets | The API key for the PowerShell Gallery. | N/A |
| `TEST_APP_ENT_CLIENT_ID` | GitHub secrets | The client ID of an Enterprise GitHub App for running tests. | N/A |
| `TEST_APP_ENT_PRIVATE_KEY` | GitHub secrets | The private key of an Enterprise GitHub App for running tests. | N/A |
| `TEST_APP_ORG_CLIENT_ID` | GitHub secrets | The client ID of an Organization GitHub App for running tests. | N/A |
| `TEST_APP_ORG_PRIVATE_KEY` | GitHub secrets | The private key of an Organization GitHub App for running tests. | N/A |
| `TEST_USER_ORG_FG_PAT` | GitHub secrets | The fine-grained personal access token with org access for running tests. | N/A |
| `TEST_USER_USER_FG_PAT` | GitHub secrets | The fine-grained personal access token with user account access for running tests. | N/A |
| `TEST_USER_PAT` | GitHub secrets | The classic personal access token for running tests. | N/A |

## Permissions

The action requires the following permissions:

If running the action in a restrictive mode, the following permissions needs to be granted to the action:

```yaml
permissions:
  contents: write      # Create releases
  pull-requests: write # Create comments on the PRs
  statuses: write      # Update the status of the PRs from the linter
```

### Publishing to GitHub Pages

To publish the documentation to GitHub Pages, the action requires the following permissions:

```yaml
permissions:
  pages: write    # Deploy to Pages
  id-token: write # Verify the deployment originates from an appropriate source
```

For more info see [Deploy GitHub Pages site](https://github.com/marketplace/actions/deploy-github-pages-site).
