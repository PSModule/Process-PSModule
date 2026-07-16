function Build-PSModule {
    <#
        .SYNOPSIS
        Builds a module.

        .DESCRIPTION
        Builds a module.
    #>
    [OutputType([void])]
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '', Scope = 'Function',
        Justification = 'LogGroup - Scoping affects the variables line of sight.'
    )]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost', '', Scope = 'Function',
        Justification = 'Want to just write to the console, not the pipeline.'
    )]
    param(
        # Name of the module.
        [Parameter(Mandatory)]
        [string] $ModuleName,

        # Path to the folder where the modules are located.
        [Parameter(Mandatory)]
        [string] $ModuleSourceFolderPath,

        # Path to the folder where the built modules are outputted.
        [Parameter(Mandatory)]
        [string] $ModuleOutputFolderPath,

        # Module version to stamp into the manifest.
        [Parameter(Mandatory)]
        [string] $ModuleVersion,

        # Prerelease tag to stamp into the manifest. When empty, no prerelease tag is written.
        [Parameter()]
        [string] $ModulePrerelease
    )

    Set-GitHubLogGroup "Building module [$ModuleName]" {
        $moduleSourceFolder = Get-Item -Path $ModuleSourceFolderPath
        $moduleOutputFolder = New-Item -Path $ModuleOutputFolderPath -Name $ModuleName -ItemType Directory -Force
        [pscustomobject]@{
            ModuleSourceFolderPath = $moduleSourceFolder
            ModuleOutputFolderPath = $moduleOutputFolder
        } | Format-List | Out-String
    }

    Build-PSModuleBase -ModuleName $ModuleName -ModuleSourceFolder $moduleSourceFolder -ModuleOutputFolder $moduleOutputFolder
    Build-PSModuleManifest -ModuleName $ModuleName -ModuleOutputFolder $moduleOutputFolder `
        -ModuleVersion $ModuleVersion -ModulePrerelease $ModulePrerelease
    Build-PSModuleRootModule -ModuleName $ModuleName -ModuleOutputFolder $moduleOutputFolder
    Update-PSModuleManifestAliasesToExport -ModuleName $ModuleName -ModuleSourceFolder $moduleSourceFolder -ModuleOutputFolder $moduleOutputFolder

    Set-GitHubLogGroup 'Build manifest file - Final Result' {
        $outputManifestPath = Join-Path -Path $ModuleOutputFolder -ChildPath "$ModuleName.psd1"
        Show-FileContent -Path $outputManifestPath
    }
}
