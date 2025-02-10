#Requires -Modules @{ ModuleName = 'GitHub'; ModuleVersion = '0.13.2' }

function Build-PSModuleBase {
    <#
        .SYNOPSIS
        Compiles the base module files.

        .DESCRIPTION
        This function will compile the base module files.
        It will copy the source files to the output folder and remove the files that are not needed.

        .EXAMPLE
        Build-PSModuleBase -SourceFolderPath 'C:\MyModule\src\MyModule' -OutputFolderPath 'C:\MyModule\build\MyModule'
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '', Scope = 'Function',
        Justification = 'LogGroup - Scoping affects the variables line of sight.'
    )]
    param(
        # Name of the module.
        [Parameter(Mandatory)]
        [string] $ModuleName,

        # Path to the folder where the module source code is located.
        [Parameter(Mandatory)]
        [System.IO.DirectoryInfo] $ModuleSourceFolder,

        # Path to the folder where the built modules are outputted.
        [Parameter(Mandatory)]
        [System.IO.DirectoryInfo] $ModuleOutputFolder
    )

    LogGroup 'Build base' {
        Write-Host "Copying files from [$ModuleSourceFolder] to [$ModuleOutputFolder]"
        Copy-Item -Path "$ModuleSourceFolder\*" -Destination $ModuleOutputFolder -Recurse -Force -Verbose -Exclude "$ModuleName.psm1"
        New-Item -Path $ModuleOutputFolder -Name "$ModuleName.psm1" -ItemType File -Force -Verbose
    }

    LogGroup 'Build base - Result' {
        (Get-ChildItem -Path $ModuleOutputFolder -Recurse -Force).FullName | Sort-Object
    }
}
