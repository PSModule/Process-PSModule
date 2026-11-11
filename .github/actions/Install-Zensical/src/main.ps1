#Requires -Version 7.0

<#
    .SYNOPSIS
    Install the Zensical CLI for site build workflows.

    .DESCRIPTION
    The script installs the zensical Python package in the runner environment.

    .EXAMPLE
    ./main.ps1

    .INPUTS
    None.

    .OUTPUTS
    None.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

pip install zensical
