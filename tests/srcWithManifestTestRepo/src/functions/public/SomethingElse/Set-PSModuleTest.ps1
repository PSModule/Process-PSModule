function Set-PSModuleTest {
    <#
        .SYNOPSIS
        Performs tests on a module.

        .DESCRIPTION
        Performs tests on a module.

        .EXAMPLE
        Test-PSModule -Name 'World'

        "Hello, World!"

        .NOTES
        Controls:
        - i       : Enter INSERT mode
        - Esc     : Enter NORMAL mode
        - y       : Yank (copy) line
        - dd      : Delete line
        - p       : Paste line
        - :w      : Save file
        - :q      : Quit
        - :q!     : Quit without saving
        - :wq     : Save and quit
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
