#Requires -Modules Retry

function Resolve-PSModuleDependency {
    <#
        .SYNOPSIS
        Resolve dependencies for a module based on the manifest file.

        .DESCRIPTION
        Resolve dependencies for a module based on the manifest file, following PSModuleInfo structure

        .EXAMPLE
        Resolve-PSModuleDependency -Path 'C:\MyModule\MyModule.psd1'

        Installs all modules defined in the manifest file, following PSModuleInfo structure.

        .NOTES
        Should later be adapted to support both pre-reqs, and dependencies.
        Should later be adapted to take 4 parameters sets: specific version ("requiredVersion" | "GUID"), latest version ModuleVersion,
        and latest version within a range MinimumVersion - MaximumVersion.
    #>
    [Alias('Resolve-PSModuleDependencies')]
    [CmdletBinding()]
    param(
        # The path to the manifest file.
        [Parameter(Mandatory)]
        [string] $ManifestFilePath
    )

    Write-Host 'Resolving dependencies'

    $manifest = Import-PowerShellDataFile -Path $ManifestFilePath
    Write-Host "Reading [$ManifestFilePath]"
    Write-Host "Found [$($manifest.RequiredModules.Count)] modules to install"

    foreach ($requiredModule in $manifest.RequiredModules) {
        $installParams = @{}

        if ($requiredModule -is [string]) {
            $installParams.Name = $requiredModule
        } else {
            $installParams.Name = $requiredModule.ModuleName
            $installParams.MinimumVersion = $requiredModule.ModuleVersion
            $installParams.RequiredVersion = $requiredModule.RequiredVersion
            $installParams.MaximumVersion = $requiredModule.MaximumVersion
        }
        $installParams.Force = $true
        $installParams.Verbose = $false

        Write-Host "[$($installParams.Name)] - Installing module"
        $VerbosePreferenceOriginal = $VerbosePreference
        $VerbosePreference = 'SilentlyContinue'
        Retry -Count 5 -Delay 10 {
            Install-Module @installParams -AllowPrerelease:$false
        }
        $VerbosePreference = $VerbosePreferenceOriginal
        Write-Host "[$($installParams.Name)] - Importing module"
        $VerbosePreferenceOriginal = $VerbosePreference
        $VerbosePreference = 'SilentlyContinue'
        Import-Module @installParams
        $VerbosePreference = $VerbosePreferenceOriginal
        Write-Host "[$($installParams.Name)] - Done"
    }
    Write-Host 'Resolving dependencies - Done'
}
