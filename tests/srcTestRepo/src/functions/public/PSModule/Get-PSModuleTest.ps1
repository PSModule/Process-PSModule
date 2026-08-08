#Requires -Modules Utilities
#Requires -Modules @{ ModuleName = 'PSSemVer'; RequiredVersion = '1.1.4' }
#Requires -Modules @{ ModuleName = 'ThreadJob'; ModuleVersion = '1.0.0'; MaximumVersion = '1.*' }
#Requires -Modules @{ ModuleName = 'Store'; ModuleVersion = '0.3.1' }

function Get-PSModuleTest {
    <#
        .SYNOPSIS
        Performs tests on a module.

        .DESCRIPTION
        Performs tests on a module.

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
