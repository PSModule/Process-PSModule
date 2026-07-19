#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$WorkingDirectory
)

$ErrorActionPreference = 'Stop'

$resolvedWorkingDirectory = Resolve-Path -Path $WorkingDirectory | Select-Object -ExpandProperty Path
$siteWorkingDirectory = Join-Path -Path $resolvedWorkingDirectory -ChildPath 'outputs/site'
$outputSitePath = Join-Path -Path $resolvedWorkingDirectory -ChildPath '_site'

Set-Location -Path $siteWorkingDirectory

if (-not (Test-Path -Path 'zensical.toml')) {
    throw "No documentation config file found in outputs/site. Expected zensical.toml."
}

zensical build --config-file 'zensical.toml'

if (Test-Path -Path '_site') {
    if (Test-Path -Path $outputSitePath) {
        Remove-Item -Path $outputSitePath -Recurse -Force
    }
    Move-Item -Path '_site' -Destination $outputSitePath -Force
}

if (-not (Test-Path -Path $outputSitePath)) {
    throw "Expected Zensical output at $outputSitePath but it was not created."
}
