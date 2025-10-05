function Set-PSModuleTest {
    <#
        .SYNOPSIS
        Performs tests on a module.

        .EXAMPLE
        Test-PSModule -Name 'World'

        "Hello, World!"

        .NOTES
        - Author: Your Name
        - Date: 2024-06-10
        - Version:q! 1.0.0
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
