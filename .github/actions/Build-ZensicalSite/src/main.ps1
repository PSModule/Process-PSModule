#Requires -Version 7.0

<#
    .SYNOPSIS
    Builds the Zensical site and normalizes output to the expected _site path.

    .DESCRIPTION
    Runs zensical build from outputs/site and moves the generated _site directory
    to <WorkingDirectory>/_site for downstream workflow steps.

    .EXAMPLE
    ./main.ps1 -WorkingDirectory '.'

    .INPUTS
    None.

    .OUTPUTS
    None.
#>
[CmdletBinding()]
param(
    # Build working directory containing outputs/site and destination _site.
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
