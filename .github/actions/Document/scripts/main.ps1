#Requires -Modules GitHub

[CmdletBinding()]
param()

$path = (Join-Path -Path $PSScriptRoot -ChildPath 'helpers')
LogGroup "Loading helper scripts from [$path]" {
    Get-ChildItem -Path $path -Filter '*.ps1' -Recurse | ForEach-Object {
        Write-Host "[$($_.FullName)]"
        . $_.FullName
    }
}

LogGroup 'Loading inputs' {
    $moduleName = ($env:GITHUB_ACTION_INPUT_Name | IsNullOrEmpty) ? $env:GITHUB_REPOSITORY_NAME : $env:GITHUB_ACTION_INPUT_Name
    Write-Host "Module name:         [$moduleName]"

    $moduleSourceFolderPath = Join-Path -Path $env:GITHUB_WORKSPACE -ChildPath $env:GITHUB_ACTION_INPUT_Path $moduleName
    if (-not (Test-Path -Path $moduleSourceFolderPath)) {
        $moduleSourceFolderPath = Join-Path -Path $env:GITHUB_WORKSPACE -ChildPath $env:GITHUB_ACTION_INPUT_Path
    }
    Write-Host "Source module path:  [$moduleSourceFolderPath]"
    if (-not (Test-Path -Path $moduleSourceFolderPath)) {
        throw "Module path [$moduleSourceFolderPath] does not exist."
    }

    $modulesOutputFolderPath = Join-Path $env:GITHUB_WORKSPACE $env:GITHUB_ACTION_INPUT_ModulesOutputPath
    Write-Host "Modules output path: [$modulesOutputFolderPath]"
    $docsOutputFolderPath = Join-Path $env:GITHUB_WORKSPACE $env:GITHUB_ACTION_INPUT_DocsOutputPath
    Write-Host "Docs output path:    [$docsOutputFolderPath]"
}

$params = @{
    ModuleName              = $moduleName
    ModuleSourceFolderPath  = $moduleSourceFolderPath
    ModulesOutputFolderPath = $modulesOutputFolderPath
    DocsOutputFolderPath    = $docsOutputFolderPath
}

Build-PSModule @params
