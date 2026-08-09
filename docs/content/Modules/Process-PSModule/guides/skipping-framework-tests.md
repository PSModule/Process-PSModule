---
title: Skipping framework tests
description: How to skip individual PSModule framework tests on a per-file basis, the available test IDs, and the broader configuration alternatives.
---

# Skipping individual framework tests

The PSModule framework tests run automatically as part of the `Test-Module` and `Test-SourceCode` jobs. While you can skip entire test categories using the configuration settings (e.g., `Test.PSModule.Skip`), you can also skip individual framework tests on a per-file basis when needed.

## How to Skip Tests

To skip an individual framework test for a specific file, add a special comment at the top of that file:

```powershell
#SkipTest:<TestID>:<Reason>
```

- `<TestID>`: The unique identifier of the test to skip (see list below)
- `<Reason>`: A brief explanation of why the test is being skipped

The skip comment will cause the framework to skip that specific test for that file only, and will log a warning in the build output with the reason provided.

## Available framework tests

Every source-code test ID, its meaning, and an example skip comment are listed in
[Framework test IDs](../reference/framework-test-ids.md#source-code-tests).

[Module tests](../reference/framework-test-ids.md#module-tests) run against the compiled module in the
`outputs/module` directory and typically don't need to be skipped, as they validate the final built module.

## Example Usage

Here's an example of a function file that skips the `FunctionCount` test because it includes helper functions:

```powershell
#SkipTest:FunctionCount:This file contains helper functions for the main function

function Get-ComplexData {
    <#
        .SYNOPSIS
        Get formatted data from a file.

        .DESCRIPTION
        Read data from a file and format it as a structured object.

        .EXAMPLE
        Get-ComplexData -Path '.\data.txt'

        Get the file content and its character count.

        .INPUTS
        None

        You can't pipe objects to Get-ComplexData.

        .OUTPUTS
        System.Management.Automation.PSCustomObject

        The formatted file data.

        .NOTES
        This file intentionally skips only the FunctionCount framework test.

        .LINK
        https://psmodule.io/<ModuleName>/Functions/Get-ComplexData
    #>
    [OutputType([PSCustomObject])]
    [CmdletBinding()]
    param(
        # The path to the data file.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    $data = Get-RawData -Path $Path
    Format-ComplexData -Data $data
}

function Get-RawData {
    <#
        .SYNOPSIS
        Get unformatted data from a file.

        .DESCRIPTION
        Read the complete content of a data file as one string.

        .EXAMPLE
        Get-RawData -Path '.\data.txt'

        Get the complete content of the data file.

        .INPUTS
        None

        You can't pipe objects to Get-RawData.

        .OUTPUTS
        System.String

        The unformatted file content.

        .NOTES
        This function is a private helper for Get-ComplexData.

        .LINK
        https://psmodule.io/<ModuleName>/Functions/Get-ComplexData
    #>
    [OutputType([string])]
    [CmdletBinding()]
    param(
        # The path to the data file.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    Get-Content -LiteralPath $Path -Raw
}

function Format-ComplexData {
    <#
        .SYNOPSIS
        Format raw data as a structured object.

        .DESCRIPTION
        Add useful metadata to raw data while preserving its content.

        .EXAMPLE
        Format-ComplexData -Data 'example'

        Format the string and include its character count.

        .INPUTS
        None

        You can't pipe objects to Format-ComplexData.

        .OUTPUTS
        System.Management.Automation.PSCustomObject

        The formatted data and its character count.

        .NOTES
        This function is a private helper for Get-ComplexData.

        .LINK
        https://psmodule.io/<ModuleName>/Functions/Get-ComplexData
    #>
    [OutputType([PSCustomObject])]
    [CmdletBinding()]
    param(
        # The raw content to format.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Data
    )

    [PSCustomObject] @{
        Content        = $Data
        CharacterCount = $Data.Length
    }
}
```

Replace `<ModuleName>` with the module's published name. If the public function belongs to a group, insert `<Group>/` between `Functions/` and `Get-ComplexData`.

The skip exempts only `FunctionCount`. Every function in the file must still follow the [PowerShell function standard](https://msxorg.github.io/docs/Coding-Standards/PowerShell/Functions/), including complete comment-based help, matching `[OutputType()]` and `.OUTPUTS` metadata, typed parameters, and implicit output.

## Best Practices

- **Use skip comments sparingly**: Framework tests exist to maintain code quality and consistency. Only skip tests when absolutely necessary.
- **Provide clear reasons**: Always include a meaningful explanation in the skip comment to help reviewers understand why the test is being skipped.
- **Consider alternatives**: Before skipping a test, consider whether refactoring the code to comply with the test would be better for long-term maintainability.
- **Document exceptions**: If you skip a test, document the reason in your PR description or code comments.

## Related Configuration

For broader test control, use the configuration file settings:

- Skip all framework tests: `Test.PSModule.Skip: true`
- Skip only source code tests: `Test.SourceCode.Skip: true`
- Skip framework tests on specific OS: `Test.PSModule.Windows.Skip: true`

See [Settings](../reference/settings.md) for the full list and
[Configuring the pipeline](configuring-the-pipeline.md) for worked examples.
