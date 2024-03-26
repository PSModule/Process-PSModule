#Requires -Modules @{ModuleName='PSSemVer'; ModuleVersion='1.0'}

function New-PSModuleTest {
    <#
        .SYNOPSIS
        Performs tests on a module. Repo.

        .EXAMPLE
        Test-PSModule -Name 'World'

        "Hello, World!"
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '', Scope = 'Function',
        Justification = 'Reason for suppressing'
    )]
    [CmdletBinding()]
    param (
        # Name of the person to greet.
        [Parameter(Mandatory)]
        [string] $Name
    )
    Write-Output "Hello, $Name!"
}
