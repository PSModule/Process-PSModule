function Invoke-Function4 {
    <#
        .SYNOPSIS
        Demonstrates Get-PSCallStack at the deepest call level.
    #>
    [CmdletBinding()]
    param()
    'In: ' + $MyInvocation.InvocationName
    Get-PSCallStack
}

function Invoke-Function3 {
    <#
        .SYNOPSIS
        Demonstrates Get-PSCallStack at call depth 3.
    #>
    [CmdletBinding()]
    param()
    'In: ' + $MyInvocation.InvocationName
    Get-PSCallStack
    Invoke-Function4
}

function Invoke-Function2 {
    <#
        .SYNOPSIS
        Demonstrates Get-PSCallStack at call depth 2.
    #>
    [CmdletBinding()]
    param()
    'In: ' + $MyInvocation.InvocationName
    Get-PSCallStack
    Invoke-Function3
}

function Invoke-Function1 {
    <#
        .SYNOPSIS
        Entry point demonstrating Get-PSCallStack through nested calls.
    #>
    [CmdletBinding()]
    param()
    "In: " + $MyInvocation.InvocationName
    Get-PSCallStack
    Invoke-Function2
}

# Test the functions
Invoke-Function1
