# Test-PSModule

Test PowerShell modules with Pester and PSScriptAnalyzer.

This GitHub Action is a part of the [PSModule framework](https://github.com/PSModule). It is recommended to use the [Process-PSModule workflow](https://github.com/PSModule/Process-PSModule) to automate the whole process of managing the PowerShell module.

## Specifications and practices

Test-PSModule enables:

- [Test-Driven Development](https://testdriven.io/test-driven-development/) using [Pester](https://pester.dev) and [PSScriptAnalyzer](https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/overview?view=ps-modules)

## How it works

The action runs the following the Pester test framework:
- [PSScriptAnalyzer tests](https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/rules/readme?view=ps-modules)
- [PSModule framework tests](#psmodule-tests)
- If `TestType` is set to `Module`:
  - The module manifest is tested using [Test-ModuleManifest](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/test-modulemanifest).
  - The module is imported.
  - Custom module tests from the `tests` directory in the module repository are run.
  - CodeCoverage is calculated.
- If `TestType` is set to `SourceCode`:
  - The source code is tested with:
    - `PSScriptAnalyzer` for best practices, using custom settings.
    - `PSModule.SourceCode` for other PSModule standards.
- The action returns a `passed` output that is `true` if all tests pass, else `false`.
- The following reports are calculated and uploaded as artifacts:
  - Test suite results.
  - Code coverage results.

The action fails if any of the tests fail or it fails to run the tests.
This is mitigated by the `continue-on-error` option in the workflow.

## How to use it

To use the action, create a new file in the `.github/workflows` directory of the module repository and add the following content.
<details>
<summary>Workflow suggestion - before module is built</summary>

```yaml
name: Test-PSModule

on: [push]

jobs:
  Test-PSModule:
    name: Test-PSModule
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repo
        uses: actions/checkout@v4

      - name: Initialize environment
        uses: ./.github/actions/Initialize

      - name: Test-PSModule
        uses: PSModule/Test-PSModule@main
        with:
          Path: src
          TestType: SourceCode

```
</details>

<details>
<summary>Workflow suggestion - after module is built</summary>

```yaml
name: Test-PSModule

on: [push]

jobs:
  Test-PSModule:
    name: Test-PSModule
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repo
        uses: actions/checkout@v4

      - name: Initialize environment
        uses: ./.github/actions/Initialize

      - name: Test-PSModule
        uses: PSModule/Test-PSModule@main
        with:
          Path: outputs/modules
          TestType: Module

```
</details>

## Usage

### Inputs

| Name | Description | Required | Default |
| ---- | ----------- | -------- | ------- |
| `Path` | The path to the code to test. | `true` | |
| `TestType` | The type of tests to run. Can be either `Module` or `SourceCode`.  | `true` | |
| `Name` | The name of the module to test. The name of the repository is used if not specified. | `false` | |
| `TestsPath` | The path to the tests to run. | `false` | `tests` |
| `StackTraceVerbosity` | Verbosity level of the stack trace. Allowed values: `None`, `FirstLine`, `Filtered`, `Full`. | `false` | `Filtered` |
| `Verbosity` | Verbosity level of the test output. Allowed values: `None`, `Normal`, `Detailed`, `Diagnostic`. | `false` | `Detailed` |
| `Debug` | Enable debug output. | `'false'` | `false` |
| `Verbose` | Enable verbose output. | `'false'` | `false` |
| `Version` | Specifies the version of the GitHub module to be installed. The value must be an exact version. | | `false` |
| `Prerelease` | Allow prerelease versions if available. | `'false'` | `false` |

### Outputs

| Name | Description | Possible values |
| ---- | ----------- | --------------- |
| `passed` | If the tests passed. | `true`, `false` |

## PSModule tests

The [PSModule framework tests](https://github.com/PSModule/Test-PSModule/blob/main/scripts/tests/PSModule/PSModule.Tests.ps1) verifies the following coding practices that the framework enforces:

- Script filename and function/filter name should match.

## Tools

- Pester | [Docs](https://www.pester.dev) | [GitHub](https://github.com/Pester/Pester) | [PS Gallery](https://www.powershellgallery.com/packages/Pester/)
- PSScriptAnalyzer [Docs](https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/overview?view=ps-modules) | [GitHub](https://github.com/PowerShell/PSScriptAnalyzer) | [PS Gallery](https://www.powershellgallery.com/packages/PSScriptAnalyzer/)
- PSResourceGet | [Docs](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.psresourceget/?view=powershellget-3.x) | [GitHub](https://github.com/PowerShell/PSResourceGet) | [PS Gallery](https://www.powershellgallery.com/packages/Microsoft.PowerShell.PSResourceGet/)
- [Test-ModuleManifest | Microsoft Learn](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/test-modulemanifest)
- [PowerShellGet | Microsoft Learn](https://learn.microsoft.com/en-us/powershell/module/PowerShellGet/test-scriptfileinfo)
