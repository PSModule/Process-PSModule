function Build-PSModuleBase {
    <#
    .SYNOPSIS
    Build the base module files.

    .DESCRIPTION
    Build-PSModuleBase copies source files to the output folder.
    It creates an empty root module file.

    .EXAMPLE
    Build-PSModuleBase -SourceFolderPath 'C:\MyModule\src\MyModule' -OutputFolderPath 'C:\MyModule\build\MyModule'
    #>
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
        [System.IO.DirectoryInfo] $ModuleSourceFolder,

        # Path to the folder for the built module.
        [Parameter(Mandatory)]
        [System.IO.DirectoryInfo] $ModuleOutputFolder
    )

    Set-GitHubLogGroup 'Build base' {
        $relModuleSourceFolder = $ModuleSourceFolder | Resolve-Path -Relative
        $relModuleOutputFolder = $ModuleOutputFolder | Resolve-Path -Relative
        Write-Host "Copying files from [$relModuleSourceFolder] to [$relModuleOutputFolder]"
        Copy-Item -Path "$ModuleSourceFolder\*" -Destination $ModuleOutputFolder -Recurse -Force -Exclude "$ModuleName.psm1"
        $null = New-Item -Path $ModuleOutputFolder -Name "$ModuleName.psm1" -ItemType File -Force
    }

    Set-GitHubLogGroup 'Build base - Result' {
        Get-ChildItem -Path $ModuleOutputFolder -Recurse -Force | Resolve-Path -Relative | Sort-Object
    }
}
