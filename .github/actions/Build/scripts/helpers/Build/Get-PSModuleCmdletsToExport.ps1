#Requires -Modules @{ ModuleName = 'Utilities'; ModuleVersion = '0.3.0' }

function Get-PSModuleCmdletsToExport {
    <#
        .SYNOPSIS
        Gets the cmdlets to export from the module manifest.

        .DESCRIPTION
        This function will get the cmdlets to export from the module manifest.

        .EXAMPLE
        Get-PSModuleCmdletsToExport -SourceFolderPath 'C:\MyModule\src\MyModule'
    #>
    [CmdletBinding()]
    param(
        # Path to the folder where the module source code is located.
        [Parameter(Mandatory)]
        [string] $SourceFolderPath
    )

    $manifestPropertyName = 'CmdletsToExport'

    $moduleName = Split-Path -Path $SourceFolderPath -Leaf
    $manifestFileName = "$moduleName.psd1"
    $manifestFilePath = Join-Path -Path $SourceFolderPath $manifestFileName

    $manifest = Get-ModuleManifest -Path $manifestFilePath -Verbose:$false

    Write-Host "[$manifestPropertyName]"
    $cmdletsToExport = (($manifest.CmdletsToExport).count -eq 0) -or ($manifest.CmdletsToExport | IsNullOrEmpty) ? '' : $manifest.CmdletsToExport
    $cmdletsToExport | ForEach-Object {
        Write-Host "[$manifestPropertyName] - [$_]"
    }

    $cmdletsToExport
}
