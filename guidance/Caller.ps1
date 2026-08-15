function Invoke-Function4 {
    <#
        .SYNOPSIS
        Demonstrates caller detection using Get-PSCallStack.
    #>
    [CmdletBinding()]
    param()
    'In: ' + $MyInvocation.InvocationName
    $caller = (Get-PSCallStack)[1].Command
    'Caller: ' + $caller
}

function Invoke-Function3 {
    <#
        .SYNOPSIS
        Demonstrates nested caller detection at depth 3.
    #>
    [CmdletBinding()]
    param()
    'In: ' + $MyInvocation.InvocationName
    $caller = (Get-PSCallStack)[1].Command
    'Caller: ' + $caller
    Invoke-Function4
}

function Invoke-Function2 {
    <#
        .SYNOPSIS
        Demonstrates nested caller detection at depth 2.
    #>
    [CmdletBinding()]
    param()
    'In: ' + $MyInvocation.InvocationName
    $caller = (Get-PSCallStack)[1].Command
    'Caller: ' + $caller
    Invoke-Function3
}

function Invoke-Function1 {
    <#
        .SYNOPSIS
        Entry point demonstrating caller detection through the call stack.
    #>
    [CmdletBinding()]
    param()
    'In: ' + $MyInvocation.InvocationName
    Get-PSCallStack
    $caller = (Get-PSCallStack)[1].Command
    'Caller: ' + $caller
    Invoke-Function2
}

# Test the functions
Invoke-Function1
