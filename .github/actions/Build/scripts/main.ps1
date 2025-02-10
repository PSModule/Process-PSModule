#Requires -Modules Utilities

[CmdletBinding()]
param()

$path = (Join-Path -Path $PSScriptRoot -ChildPath 'helpers') | Get-Item | Resolve-Path -Relative
LogGroup "Loading helper scripts from [$path]" {
    Get-ChildItem -Path $path -Filter '*.ps1' -Recurse | Resolve-Path -Relative | ForEach-Object {
        Write-Host "$_"
        . $_
    }
}

LogGroup 'Loading inputs' {
    $moduleName = ($env:GITHUB_ACTION_INPUT_Name | IsNullOrEmpty) ? $env:GITHUB_REPOSITORY_NAME : $env:GITHUB_ACTION_INPUT_Name
    Write-Host "Module name:         [$moduleName]"

    $moduleSourceFolderPath = Join-Path -Path $env:GITHUB_WORKSPACE -ChildPath $env:GITHUB_ACTION_INPUT_Path/$moduleName
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

LogGroup 'Build local scripts' {
    Write-Host 'Execution order:'
    $scripts = Get-ChildItem -Filter '*build.ps1' -Recurse | Sort-Object -Property Name | Resolve-Path -Relative
    $scripts | ForEach-Object {
        Write-Host " - $_"
    }
    $scripts | ForEach-Object {
        LogGroup "Build local scripts - [$_]" {
            . $_
        }
    }
}

$params = @{
    ModuleName              = $moduleName
    ModuleSourceFolderPath  = $moduleSourceFolderPath
    ModulesOutputFolderPath = $modulesOutputFolderPath
    DocsOutputFolderPath    = $docsOutputFolderPath
}

Build-PSModule @params
