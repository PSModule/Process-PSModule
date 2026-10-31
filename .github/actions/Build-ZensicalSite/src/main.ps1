#Requires -Version 7.0

<#
    .SYNOPSIS
    Builds the Zensical site under the framework artifact directory.

    .DESCRIPTION
    Runs zensical build from .PSModule/site. The generated site remains at
    <WorkingDirectory>/.PSModule/site/_site for downstream workflow steps.

    .EXAMPLE
    ./main.ps1 -WorkingDirectory '.'

    .INPUTS
    None.

    .OUTPUTS
    None.
#>
[CmdletBinding()]
param(
    # Build working directory containing the Zensical project and output.
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
