[CmdletBinding()]
param()

$path = (Join-Path -Path $PSScriptRoot -ChildPath 'helpers')
LogGroup "Loading helper scripts from [$path]" {
    Get-ChildItem -Path $path -Filter '*.ps1' -Recurse | ForEach-Object {
        Write-Verbose "[$($_.FullName)]"
        . $_.FullName
    }
}

LogGroup 'Loading inputs' {
    Write-Verbose "Name:              [$env:GITHUB_ACTION_INPUT_Name]"
    Write-Verbose "GITHUB_REPOSITORY: [$env:GITHUB_REPOSITORY]"
    Write-Verbose "GITHUB_WORKSPACE:  [$env:GITHUB_WORKSPACE]"

    $name = ($env:GITHUB_ACTION_INPUT_Name | IsNullOrEmpty) ? $env:GITHUB_REPOSITORY_NAME : $env:GITHUB_ACTION_INPUT_Name
    Write-Verbose "Module name:       [$name]"
    Write-Verbose "Module path:       [$env:GITHUB_ACTION_INPUT_ModulePath]"
    Write-Verbose "Doc path:          [$env:GITHUB_ACTION_INPUT_DocsPath]"

    $modulePath = Join-Path -Path $env:GITHUB_WORKSPACE -ChildPath $env:GITHUB_ACTION_INPUT_ModulePath $name
    Write-Verbose "Module path:       [$modulePath]"
    if (-not (Test-Path -Path $modulePath)) {
        throw "Module path [$modulePath] does not exist."
    }
}

$params = @{
    Name       = $name
    ModulePath = $modulePath
    APIKey     = $env:GITHUB_ACTION_INPUT_APIKey
}
Publish-PSModule @params
