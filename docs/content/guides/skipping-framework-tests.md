---
title: Skipping framework tests
description: Skip an individual framework test for one file and record the reason for the exception.
---

# Skipping individual framework tests

The PSModule framework runs tests in the `Test-Module` and `Test-SourceCode` jobs. Configuration settings, such as `Test.PSModule.Skip`, skip entire test categories. A skip comment exempts an individual test for one file.

## How to skip tests

To skip an individual framework test, add this comment at the top of the file:

```powershell
#SkipTest:<TestID>:<Reason>
```

- `<TestID>`: The unique identifier of the test to skip
- `<Reason>`: A brief explanation of why the file needs the exception

The framework skips only the identified test for that file. It writes the supplied reason as a warning in the build output.

## Available framework tests

The [Framework test IDs](../reference/framework-test-ids.md#source-code-tests) reference lists every source-code test ID,
its meaning, and an example skip comment.

[Module tests](../reference/framework-test-ids.md#module-tests) run against the compiled module in the
`.PSModule/module` directory. These tests validate the final built module.

## Example usage

This function file skips `FunctionCount` because it contains helper functions:

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
        https://<DocumentationHost>/<ModuleName>/Functions/Get-ComplexData
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
        https://<DocumentationHost>/<ModuleName>/Functions/Get-ComplexData
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
        https://<DocumentationHost>/<ModuleName>/Functions/Get-ComplexData
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

Replace `<DocumentationHost>` with the HTTPS host that publishes the module documentation. Replace `<ModuleName>` with the module's published name. If the public function belongs to a group, insert `<Group>/` between `Functions/` and `Get-ComplexData`.

The skip exempts only `FunctionCount`. Every function in the file must follow the [PowerShell function standard](https://msx.no/docs/Coding-Standards/PowerShell/Functions/). This includes complete comment-based help, matching `[OutputType()]` and `.OUTPUTS` metadata, typed parameters, and implicit output.

## Best practices

- **Use skip comments sparingly**: Use a skip comment only when a necessary exception prevents compliance with the test.
- **Provide clear reasons**: Include a reason that identifies the exception and explains why the file needs it.
- **Consider alternatives**: Before you skip a test, consider whether code refactoring improves long-term maintainability and satisfies the test.
- **Document exceptions**: Record the reason in the PR description or code comments.

## Related configuration

For broader test control, use the configuration file settings:

- Skip all framework tests: `Test.PSModule.Skip: true`
- Skip only source code tests: `Test.SourceCode.Skip: true`
- Skip framework tests on Windows: `Test.PSModule.Windows.Skip: true`

See [Settings](../reference/settings.md) for the full list and
[Configuring the pipeline](configuring-the-pipeline.md) for worked examples.
