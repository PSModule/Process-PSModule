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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Scope = 'Function', Justification = 'Want to just write to the console, not the pipeline.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidLongLines', '', Scope = 'Function', Justification = 'Contains long links.')]
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
    $cmdletsToExport = (($manifest.CmdletsToExport).count -eq 0) -or [string]::IsNullOrEmpty($manifest.CmdletsToExport) ? '' : $manifest.CmdletsToExport
    $cmdletsToExport | ForEach-Object {
        Write-Host "[$manifestPropertyName] - [$_]"
    }

    $cmdletsToExport
}
