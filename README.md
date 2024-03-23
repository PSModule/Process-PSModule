# Process-PSModule

A workflow for the PSModule process, stitching together the `Initialize`, `Build`, `Test`, and `Publish` actions to create a complete
CI/CD pipeline for PowerShell modules. The workflow is used by all PowerShell modules in the PSModule organization.

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

- [Initialize-PSModule](https://github.com/PSModule/Initialize-PSModule/) - Prepares the runner with all the framework requirements.
- [Test-PSModule](https://github.com/PSModule/Test-PSModule/) - Tests the source code using only PSScriptAnalyzer and the PSModule test suites.
- [Build-PSModule](https://github.com/PSModule/Build-PSModule/) - Compiles the repository into an efficient PowerShell module.
- [Test-PSModule](https://github.com/PSModule/Test-PSModule/) - Tests the compiled module using PSScriptAnalyzer, PSModule and module tests suites from the module repository.
- [Publish-PSModule](https://github.com/PSModule/Publish-PSModule/) - Publishes the module to the PowerShell Gallery, docs to GitHub Pages, and creates a release on the GitHub repository.

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
  group: ${{ github.workflow }}

permissions:
  contents: write
  pull-requests: write

jobs:
  Process-PSModule:
    uses: PSModule/Process-PSModule/.github/workflows/workflow.yml@v1
    secrets: inherit

```
</details>

## Usage

### Inputs

| Name | Type | Description | Required | Default |
| ---- | ---- | ----------- | -------- | ------- |
| `Name` | `string` | The name of the module to process. This defaults to the repository name if nothing is specified. | `false` | N/A |
| `Path` | `string` | The path to the source code of the module. | `false` | `src` |
| `ModulesOutputPath` | `string` | The path to the output directory for the modules. | `false` | `outputs/modules` |
| `DocsOutputPath` | `string` | The path to the output directory for the documentation. | `false` | `outputs/docs` |
| `SkipTests` | `boolean` | Whether to skip the tests. | false | `false` |
| `TestProcess` | `boolean` | Whether to test the process. | false | `false` |

### Secrets

The following secrets are **required** for the workflow to run:

| Name | Location | Description | Default |
| ---- | -------- | ----------- | ------- |
| `GITHUB_TOKEN` | `github` context | The token used to authenticate with GitHub. | `${{ secrets.GITHUB_TOKEN }}` |
| `APIKey` | GitHub secrets | The API key for the PowerShell Gallery. | N/A |

## In detail

The following steps will be run when the workflow triggers:

- Checkout Code [actions/checkout](https://github.com/actions/checkout/)
  - Checks out the code of the repository to the runner.
- Initialize environment [PSModule/Initialize-PSModule](https://github.com/PSModule/Initialize-PSModule/)
- Test source code [PSModule/Test-PSModule](https://github.com/PSModule/Test-PSModule/)
  - Looks for the module in the `src` directory and runs the PSScriptAnalyzer and PSModule testing suite on the code.
- Build module [PSModule/Build-PSModule](https://github.com/PSModule/Build-PSModule/)
  - Build the manifest file for the module.
  - Compiles the `src` directory into a PowerShell module and docs.
  - The compiled module is output to the `outputs/modules` directory.
  - The compiled docs are output to the `outputs/docs` directory.
- Test built module [PSModule/Test-PSModule](https://github.com/PSModule/Test-PSModule/)
  - Looks for the module in the `outputs/modules` directory and runs the PSScriptAnalyzer, PSModule testing suite and the custom module tests from the `tests` directory on the code.
- Publish module [PSModule/Publish-PSModule](https://github.com/PSModule/Publish-PSModule/)
  - Calculates the next version of the module based on the latest release and labels on the PR.
  - Publishes the module to the PowerShell Gallery using the API key stored in as a secret named `APIKey`.
  - Publishes the docs to GitHub Pages from the `outputs/docs` directory.
    - Creates a release on the GitHub repository with the source code.

## Permissions

The action requires the following permissions:

If running the action in a restrictive mode, the following permissions needs to be granted to the action:

```yaml
permissions:
  contents: write # Required to create releases
  pull-requests: write # Required to create comments on the PRs
```

## Links

- [Storing workflow data as artifacts | GitHub Docs](https://docs.github.com/en/actions/using-workflows/storing-workflow-data-as-artifacts)
- [Building and testing PowerShell | GitHub Docs](https://docs.github.com/en/actions/automating-builds-and-tests/building-and-testing-powershell)
