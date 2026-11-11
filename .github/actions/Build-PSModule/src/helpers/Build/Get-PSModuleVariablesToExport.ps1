function Get-PSModuleVariablesToExport {
    <#
        .SYNOPSIS
        Get the variables to export from the module source code.

        .DESCRIPTION
        Get-PSModuleVariablesToExport reads root-level assignments in public variable files.

        .EXAMPLE
        Get-PSModuleVariablesToExport -SourceFolderPath 'C:\MyModule\src\MyModule'
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost', '', Scope = 'Function',
        Justification = 'Want to just write to the console, not the pipeline.'
    )]
    [OutputType([string])]
    [OutputType([Collections.Generic.List[string]])]
    [CmdletBinding()]
    param(
        # Path to the module source folder.
        [Parameter(Mandatory)]
        [string] $SourceFolderPath
    )

    $manifestPropertyName = 'VariablesToExport'

    Write-Host "[$manifestPropertyName]"

    $variablesToExport = [Collections.Generic.List[string]]::new()
    $variableFolderPath = Join-Path -Path $SourceFolderPath -ChildPath 'variables/public'
    if (-not (Test-Path -Path $variableFolderPath -PathType Container)) {
        Write-Host "[$manifestPropertyName] - [Folder not found] - [$variableFolderPath]"
        return ''
    }
    $scriptFilePaths = Get-ChildItem -Path $variableFolderPath -Recurse -File -Filter *.ps1 | Select-Object -ExpandProperty FullName

    $scriptFilePaths | ForEach-Object {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($_, [ref]$null, [ref]$null)
        $variables = Get-RootLevelVariable -Ast $ast
        $variables | ForEach-Object {
            $variablesToExport.Add($_)
        }
    }

    $variablesToExport | ForEach-Object {
        Write-Host "[$manifestPropertyName] - [$_]"
    }

    $variablesToExport
}
