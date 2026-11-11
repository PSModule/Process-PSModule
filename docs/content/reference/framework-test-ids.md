---
title: Framework test IDs
description: The PSModule framework tests enforced on module source code and on the built module, with the IDs used to skip them per file.
---

# Framework test IDs

The PSModule framework runs a fixed set of tests on every module. These tests are separate from the module's own Pester tests.
Each source-code test has an ID. Use the ID to
[skip the test for a single file](../guides/skipping-framework-tests.md).

## Source-code tests

The [Test source code](pipeline-stages.md#test-source-code) job runs these tests against files in `src/`.
The [PSModule - SourceCode tests](https://github.com/PSModule/Process-PSModule/blob/main/.github/actions/Test-PSModule/src/tests/SourceCode/PSModule/PSModule.Tests.ps1)
file defines them.

| ID | Category | Description | Example skip comment |
| ---- | ---------- | ------------- | ---------------------- |
| `NumberOfProcessors` | General | Should use `[System.Environment]::ProcessorCount` instead of `$env:NUMBER_OF_PROCESSORS`. | `#SkipTest:NumberOfProcessors:Legacy code compatibility required` |
| `Verbose` | General | Should not pass `-Verbose` to other commands (which would override user preference), unless explicitly disabled with `-Verbose:$false`. | `#SkipTest:Verbose:Required for debugging output` |
| `OutNull` | General | Should use `$null = ...` instead of piping output to `Out-Null`. | `#SkipTest:OutNull:Pipeline processing required` |
| `NoTernary` | General | Should not use ternary operations, to maintain compatibility with PowerShell 5.1 and below. Skipped by default in the framework. | `#SkipTest:NoTernary:PowerShell 7+ only module` |
| `LowercaseKeywords` | General | All PowerShell keywords should be written in lowercase. | `#SkipTest:LowercaseKeywords:Generated code` |
| `FunctionCount` | Functions (Generic) | Each script file should contain exactly one function or filter. | `#SkipTest:FunctionCount:Helper functions included` |
| `FunctionName` | Functions (Generic) | Script filenames should match the name of the function or filter they contain. | `#SkipTest:FunctionName:Legacy naming convention` |
| `CmdletBinding` | Functions (Generic) | Functions should include the `[CmdletBinding()]` attribute. | `#SkipTest:CmdletBinding:Simple helper function` |
| `ParamBlock` | Functions (Generic) | Functions should have a parameter block (`param()`). | `#SkipTest:ParamBlock:No parameters needed` |
| `FunctionTest` | Functions (Public) | All public functions and filters should have corresponding tests. | `#SkipTest:FunctionTest:Test in development` |
| `PublicHelpLink` | Functions (Public) | Every public function and filter should have a first `.LINK` entry with an absolute HTTPS URL whose path matches its generated command documentation path. | `#SkipTest:PublicHelpLink:Legacy documentation link` |

## Module tests

The [Framework test](pipeline-stages.md#framework-test) job runs these tests against the compiled module in
`.PSModule/module`. The
[PSModule - Module tests](https://github.com/PSModule/Process-PSModule/blob/main/.github/actions/Test-PSModule/src/tests/Module/PSModule/PSModule.Tests.ps1)
file defines them.

| Name | Description |
| ---- | ----------- |
| Module Manifest exists | Verifies that a module manifest file is present. |
| Module Manifest is valid | Verifies that the module manifest file is valid. |
| Module import validation | Verifies that an import of the built module does not throw an error. |

In most cases, keep module tests enabled to validate the final built module.

## Related

- [Skipping framework tests](../guides/skipping-framework-tests.md) — how to use the IDs above.
- [Settings](settings.md) — how to skip whole test categories or platforms.
