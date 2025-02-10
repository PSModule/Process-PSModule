function ConvertTo-Hashtable {
    <#
        .SYNOPSIS
        Converts a string to a hashtable.

        .DESCRIPTION
        Converts a string to a hashtable.

        .EXAMPLE
        ConvertTo-Hashtable -InputString "@{Key1 = 'Value1'; Key2 = 'Value2'}"

        Key   Value
        ---   -----
        Key1  Value1
        Key2  Value2

        Converts the string to a hashtable.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingInvokeExpression', '', Scope = 'Function',
        Justification = 'Converting a string based hashtable to a hashtable.'
    )]
    [CmdletBinding()]
    param (
        # The string to convert to a hashtable.
        [Parameter(Mandatory = $true)]
        [string]$InputString
    )

    Invoke-Expression $InputString

}
