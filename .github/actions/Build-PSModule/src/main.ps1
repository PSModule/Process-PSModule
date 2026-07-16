[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost', '',
    Justification = 'Want to just write to the console, not the pipeline.'
)]
[CmdletBinding()]
param()

$path = (Join-Path -Path $PSScriptRoot -ChildPath 'helpers') | Get-Item | Resolve-Path -Relative
Set-GitHubLogGroup "Loading helper scripts from [$path]" {
    Get-ChildItem -Path $path -Filter '*.ps1' -Recurse | Resolve-Path -Relative | ForEach-Object {
        Write-Host "$_"
        . $_
    }
}

$env:GITHUB_REPOSITORY_NAME = $env:GITHUB_REPOSITORY -replace '.+/'

Set-GitHubLogGroup 'Loading inputs' {
    $moduleName = if ([string]::IsNullOrEmpty($env:PSMODULE_BUILD_PSMODULE_INPUT_Name)) {
        $env:GITHUB_REPOSITORY_NAME
    } else {
        $env:PSMODULE_BUILD_PSMODULE_INPUT_Name
    }
    $moduleVersion = $env:PSMODULE_BUILD_PSMODULE_INPUT_Version
    $modulePrerelease = $env:PSMODULE_BUILD_PSMODULE_INPUT_Prerelease
    $sourceFolderPath = Resolve-Path -Path 'src' | Select-Object -ExpandProperty Path
    $moduleOutputFolderPath = Join-Path $pwd -ChildPath $env:PSMODULE_BUILD_PSMODULE_INPUT_OutputFolder
    [pscustomobject]@{
        moduleName             = $moduleName
        moduleVersion          = $moduleVersion
        modulePrerelease       = $modulePrerelease
        sourceFolderPath       = $sourceFolderPath
        moduleOutputFolderPath = $moduleOutputFolderPath
    } | Format-List | Out-String
}

if ([string]::IsNullOrWhiteSpace($moduleVersion)) {
    throw 'Version is required. Please provide a module version.'
}

if ($moduleVersion -notmatch '^\d+\.\d+\.\d+$') {
    throw "Version '$moduleVersion' is not a valid version. Expected format: 'Major.Minor.Patch' (e.g., '1.2.3')."
}

Set-GitHubLogGroup 'Build local scripts' {
    Write-Host 'Execution order:'
    $scripts = Get-ChildItem -Filter '*build.ps1' -Recurse | Sort-Object -Property Name | Resolve-Path -Relative
    $scripts | ForEach-Object {
        Write-Host " - $_"
    }
    $scripts | ForEach-Object {
        Set-GitHubLogGroup "Build local scripts - [$_]" {
            . $_
        }
    }
}

$params = @{
    ModuleName             = $moduleName
    ModuleSourceFolderPath = $sourceFolderPath
    ModuleOutputFolderPath = $moduleOutputFolderPath
    ModuleVersion          = $moduleVersion
    ModulePrerelease       = $modulePrerelease
}
Build-PSModule @params

"ModuleOutputFolderPath=$moduleOutputFolderPath" >> $env:GITHUB_OUTPUT

exit 0
