param(
    [Parameter(Mandatory)]
    [string]$WorkingDirectory
)

$ErrorActionPreference = 'Stop'

$resolvedWorkingDirectory = Resolve-Path -Path $WorkingDirectory | Select-Object -ExpandProperty Path
$siteWorkingDirectory = Join-Path -Path $resolvedWorkingDirectory -ChildPath '.PSModule/site'
$outputSitePath = Join-Path -Path $siteWorkingDirectory -ChildPath '_site'

Set-Location -Path $siteWorkingDirectory

if (-not (Test-Path -Path 'zensical.toml')) {
    throw "No documentation config file found in .PSModule/site. Expected zensical.toml."
}

zensical build --config-file 'zensical.toml'

if (-not (Test-Path -Path $outputSitePath)) {
    throw "Expected Zensical output at $outputSitePath but it was not created."
}
