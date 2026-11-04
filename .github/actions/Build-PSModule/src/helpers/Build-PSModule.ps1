function Build-PSModule {
    <#
        .SYNOPSIS
        Build a PowerShell module from source files.

        .DESCRIPTION
        Build-PSModule copies the source files, creates the manifest, and combines the scripts into the root module.
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

        # Path to the module source folder.
        [Parameter(Mandatory)]
        [string] $ModuleSourceFolderPath,

        # Path to the folder for the built module.
        [Parameter(Mandatory)]
        [string] $ModuleOutputFolderPath,

        # Module version to stamp into the manifest.
        [Parameter(Mandatory)]
        [string] $ModuleVersion,

        # Prerelease tag for the manifest. An empty value omits the prerelease tag.
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
