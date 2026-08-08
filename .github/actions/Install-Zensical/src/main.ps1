#Requires -Version 7.0

<#
    .SYNOPSIS
    Installs the Zensical CLI used by site build workflows.

    .DESCRIPTION
    Installs the zensical Python package in the current runner environment.

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
