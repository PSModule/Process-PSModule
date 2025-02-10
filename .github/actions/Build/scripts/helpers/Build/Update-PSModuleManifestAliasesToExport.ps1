#Requires -Modules @{ ModuleName = 'GitHub'; ModuleVersion = '0.13.2' }
#Requires -Modules @{ ModuleName = 'Utilities'; ModuleVersion = '0.3.0' }

function Update-PSModuleManifestAliasesToExport {
    <#
        .SYNOPSIS
        Updates the aliases to export in the module manifest.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '', Scope = 'Function',
        Justification = 'Updates a file that is being built.'
    )]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '', Scope = 'Function',
        Justification = 'LogGroup - Scoping affects the variables line of sight.'
    )]
    [CmdletBinding()]
    param(
        # Name of the module.
        [Parameter(Mandatory)]
        [string] $ModuleName,

        # Folder where the module is outputted.
        [Parameter(Mandatory)]
        [System.IO.DirectoryInfo] $ModuleOutputFolder
    )
    LogGroup 'Updating aliases to export in module manifest' {
        Write-Host "Module name: [$ModuleName]"
        Write-Host "Module output folder: [$ModuleOutputFolder]"
        $aliases = Get-Command -Module $ModuleName -CommandType Alias
        Write-Host "Found aliases: [$($aliases.Count)]"
        foreach ($alias in $aliases) {
            Write-Host "Alias: [$($alias.Name)]"
        }
        $outputManifestPath = Join-Path -Path $ModuleOutputFolder -ChildPath "$ModuleName.psd1"
        Write-Host "Output manifest path: [$outputManifestPath]"
        Write-Host 'Setting module manifest with AliasesToExport'
        Set-ModuleManifest -Path $outputManifestPath -AliasesToExport $aliases.Name -Verbose
    }
}
