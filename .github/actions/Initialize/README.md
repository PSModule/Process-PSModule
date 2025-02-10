# Initialize-PSModule

An action that is used to prepare the runner for PSModule framework.

This GitHub Action is a part of the [PSModule framework](https://github.com/PSModule). It is recommended to use the [Process-PSModule workflow](https://github.com/PSModule/Process-PSModule) to automate the whole process of managing the PowerShell module.

## Specifications and practices

Initiate-PSModule follows:

- [SemVer 2.0.0 specifications](https://semver.org)
- [GitHub Flow specifications](https://docs.github.com/en/get-started/using-github/github-flow)
- [Continiuous Delivery practices](https://en.wikipedia.org/wiki/Continuous_delivery)

... and supports the following practices in the PSModule framework:

- [DRY](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself)

## How it works

The Initialize-PSModule action will prepare the runner for the PSModule framework by installing the following dependencies:

| Module | Description |
| --- | --- |
| GitHub | Used to interact with the GitHub API and GitHub Action workflow commands. |
| PSScriptAnalyzer | Used to lint and format PowerShell code. |
| PSSemVer | Used to create an object for the semantic version numbers. Has functionality to compare, and bump versions. |
| Pester | Used for testing PowerShell code. |
| Utilities | Used by all actions, contains common function and classes. |
| platyPS | Used to generate Markdown documentation from PowerShell code. |
| powershell-yaml | Used to parse and serialize YAML files, typically for reading configuration files. |

## Usage

### Inputs

| Name | Description | Required | Default |
| - | - | - | - |
| `Debug` | Enable debug output. | `false` | `'false'` |
| `Verbose` | Enable verbose output. | `false` | `'false'` |
| `Version` | Specifies the version of the GitHub module to be installed. The value must be an exact version. | `false` | |
| `Prerelease` | Allow prerelease versions if available. | `false` | `'false'` |

## Example

The action can be used in a workflow to prepare the runner for the PSModule framework by adding it at the start of the workflow.

```yaml
name: Process-PSModule

on: [push]

jobs:
  Process-PSModule:
    name: Process module
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Initialize environment
        uses: ./.github/actions/Initialize
```

## Permissions

The action does not require any permissions.

## Compatibility

The action is compatible with the following configurations:

| OS | Shell |
| --- | --- |
| windows-latest | pwsh |
| macos-latest | pwsh |
| ubuntu-latest | pwsh |
