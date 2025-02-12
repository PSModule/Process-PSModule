function Get-PSModuleClassesToExport {
    <#
        .SYNOPSIS
        Gets the classes to export from the module source code.

        .DESCRIPTION
        This function will get the classes to export from the module source code.

        .EXAMPLE
        Get-PSModuleClassesToExport -SourceFolderPath 'C:\MyModule\src\MyModule'

        Book
        BookList

        This will return the classes to export from the module source code.

        .NOTES
        Inspired by [about_Classes | Exporting classes with type accelerators](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_classes?view=powershell-7.4#exporting-classes-with-type-accelerators)
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidLongLines', '', Justification = 'Contains long links.')]
    [CmdletBinding()]
    param (
        # The path to the module root folder.
        [Parameter(Mandatory)]
        [string] $SourceFolderPath
    )

    $files = Get-ChildItem -Path $SourceFolderPath -Recurse -Include '*.ps1' | Sort-Object -Property FullName

    foreach ($file in $files) {
        $content = Get-Content -Path $file.FullName -Raw
        $stringMatches = [Regex]::Matches($content, '(?i)^(class|enum)\s+([^\s{]+)', 'Multiline')
        foreach ($match in $stringMatches) {
            [pscustomobject]@{
                Type = $match.Groups[1].Value
                Name = $match.Groups[2].Value
            }
        }
    }
}
