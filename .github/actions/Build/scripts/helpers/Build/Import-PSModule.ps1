#Requires -Modules @{ ModuleName = 'Utilities'; ModuleVersion = '0.3.0' }

function Import-PSModule {
    <#
        .SYNOPSIS
        Imports a build PS module.

        .DESCRIPTION
        Imports a build PS module.

        .EXAMPLE
        Import-PSModule -SourceFolderPath $ModuleFolderPath -ModuleName $ModuleName

        Imports a module located at $ModuleFolderPath with the name $ModuleName.
    #>
    [CmdletBinding()]
    param(
        # Path to the folder where the module source code is located.
        [Parameter(Mandatory)]
        [string] $Path,

        # Name of the module.
        [Parameter(Mandatory)]
        [string] $ModuleName
    )

    $moduleName = Split-Path -Path $Path -Leaf
    $manifestFileName = "$moduleName.psd1"
    $manifestFilePath = Join-Path -Path $Path $manifestFileName
    $manifestFile = Get-ModuleManifest -Path $manifestFilePath -As FileInfo -Verbose

    Write-Host "Manifest file path: [$($manifestFile.FullName)]" -Verbose
    $existingModule = Get-Module -Name $ModuleName -ListAvailable
    $existingModule | Remove-Module -Force -Verbose
    $existingModule.RequiredModules | ForEach-Object { $_ | Remove-Module -Force -Verbose -ErrorAction SilentlyContinue }
    $existingModule.NestedModules | ForEach-Object { $_ | Remove-Module -Force -Verbose -ErrorAction SilentlyContinue }
    # Get-InstalledPSResource | Where-Object Name -EQ $ModuleName | Uninstall-PSResource -SkipDependencyCheck -Verbose:$false
    Resolve-PSModuleDependency -ManifestFilePath $manifestFile
    Import-Module -Name $ModuleName -RequiredVersion '999.0.0'

    Write-Host 'List loaded modules'
    $availableModules = Get-Module -ListAvailable -Refresh -Verbose:$false
    $availableModules | Select-Object Name, Version, Path | Sort-Object Name | Format-Table -AutoSize
    Write-Host 'List commands'
    Write-Host (Get-Command -Module $moduleName | Format-Table -AutoSize | Out-String)

    if ($ModuleName -notin $availableModules.Name) {
        throw 'Module not found'
    }
}
