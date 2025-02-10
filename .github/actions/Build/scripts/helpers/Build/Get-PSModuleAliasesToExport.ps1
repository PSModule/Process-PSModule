#Requires -Modules @{ ModuleName = 'Utilities'; ModuleVersion = '0.3.0' }

function Get-PSModuleAliasesToExport {
    <#
        .SYNOPSIS
        Gets the aliases to export from the module manifest.

        .DESCRIPTION
        This function will get the aliases to export from the module manifest.

        .EXAMPLE
        Get-PSModuleAliasesToExport -SourceFolderPath 'C:\MyModule\src\MyModule'
    #>
    [CmdletBinding()]
    param(
        # Path to the folder where the module source code is located.
        [Parameter(Mandatory)]
        [string] $SourceFolderPath
    )

    $manifestPropertyName = 'AliasesToExport'

    $moduleName = Split-Path -Path $SourceFolderPath -Leaf
    $manifestFileName = "$moduleName.psd1"
    $manifestFilePath = Join-Path -Path $SourceFolderPath $manifestFileName

    $manifest = Get-ModuleManifest -Path $manifestFilePath -Verbose:$false

    Write-Host "[$manifestPropertyName]"
    $aliasesToExport = (($manifest.AliasesToExport).count -eq 0) -or ($manifest.AliasesToExport | IsNullOrEmpty) ? '*' : $manifest.AliasesToExport
    $aliasesToExport | ForEach-Object {
        Write-Host "[$manifestPropertyName] - [$_]"
    }

    $aliasesToExport
}
