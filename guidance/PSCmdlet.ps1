function Invoke-Function4 {
    <#
        .SYNOPSIS
        Demonstrates PSCmdlet variable at the deepest call level.
    #>
    [CmdletBinding()]
    param()
    '4: ' + $MyInvocation.InvocationName
    $PSCmdlet | ConvertTo-Json
}

function Invoke-Function3 {
    <#
        .SYNOPSIS
        Demonstrates PSCmdlet variable at call depth 3.
    #>
    [CmdletBinding()]
    param()
    '3: ' + $MyInvocation.InvocationName
    $PSCmdlet | ConvertTo-Json
    Invoke-Function4
}

function Invoke-Function2 {
    <#
        .SYNOPSIS
        Demonstrates PSCmdlet variable at call depth 2.
    #>
    [CmdletBinding()]
    param()
    '2: ' + $MyInvocation.InvocationName
    $PSCmdlet | ConvertTo-Json
    Invoke-Function3
}

function Invoke-Function1 {
    <#
        .SYNOPSIS
        Entry point demonstrating PSCmdlet variable through nested calls.
    #>
    [CmdletBinding()]
    param()
    '1: ' + $MyInvocation.InvocationName
    $PSCmdlet | ConvertTo-Json
    Invoke-Function2
}

# Test the functions
Invoke-Function1
