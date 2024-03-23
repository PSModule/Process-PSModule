#Requires -Version 7.4
#Requires -Modules Utilities

function Get-PSModule {
    <#
        .SYNOPSIS
        Performs tests on a module, repo url.

        .EXAMPLE
        Test-PSModule -Name 'World'

        "Hello, World!"
    #>
    [CmdletBinding()]
    param (
        # Name of the person to greet.
        [Parameter(Mandatory)]
        [string] $Name
    )
    Write-Output "Hello, $Name!"
}
