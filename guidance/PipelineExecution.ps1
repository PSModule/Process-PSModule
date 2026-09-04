function Set-DefaultParameterValue {
    <#
        .SYNOPSIS
        Sets a default parameter value with a simulated delay.

        .PARAMETER Parameter
        The parameter value to set.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([string])]
    param (
        [string]$Parameter = 'Default-Parameter'
    )
    if ($PSCmdlet.ShouldProcess($Parameter, 'Set default parameter value')) {
        Write-Verbose "Set-DefaultParameterValue: Setting Parameter to '$Parameter'"
        Start-Sleep -Seconds 1
        return $Parameter
    }
}

function Step-One {
    <#
        .SYNOPSIS
        First pipeline step that multiplies input by 10.

        .PARAMETER InputNumber
        The number to process.

        .PARAMETER Parameter
        Optional parameter with a default value.
    #>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true)]
        [int]$InputNumber,

        [string]$Parameter = (Set-DefaultParameterValue -Parameter 'Step-One-Default')
    )
    begin {
        Write-Verbose "Step-One: BEGIN block. Parameter=$Parameter"
        Start-Sleep -Seconds 1
    }
    process {
        Write-Verbose "Step-One: PROCESS block. InputNumber=$InputNumber, Parameter=$Parameter"
        $Output = $InputNumber * 10
        Write-Output $Output
        Start-Sleep -Seconds 1
    }
    end {
        Write-Verbose "Step-One: END block. Parameter=$Parameter"
        Start-Sleep -Seconds 1
    }

    clean {
        Write-Verbose "Step-One: CLEANUP block. Parameter=$Parameter"
        Start-Sleep -Seconds 1
    }
}

function Step-Two {
    <#
        .SYNOPSIS
        Second pipeline step that adds 5 to input.

        .PARAMETER InputNumber
        The number to process.

        .PARAMETER Parameter
        Optional parameter with a default value.
    #>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true)]
        [int]$InputNumber,

        [string]$Parameter = (Set-DefaultParameterValue -Parameter 'Step-Two-Default')
    )
    begin {
        Write-Verbose "Step-Two: BEGIN block. Parameter=$Parameter"
        Start-Sleep -Seconds 1
    }
    process {
        Write-Verbose "Step-Two: PROCESS block. InputNumber=$InputNumber, Parameter=$Parameter"
        $Output = $InputNumber + 5
        Write-Output $Output
        Start-Sleep -Seconds 1
    }
    end {
        Write-Verbose "Step-Two: END block. Parameter=$Parameter"
        Start-Sleep -Seconds 1
    }
    clean {
        Write-Verbose "Step-One: CLEANUP block. Parameter=$Parameter"
        Start-Sleep -Seconds 1
    }
}

function Step-Three {
    <#
        .SYNOPSIS
        Third pipeline step that subtracts 2 from input.

        .PARAMETER InputNumber
        The number to process.

        .PARAMETER Parameter
        Optional parameter with a default value.
    #>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true)]
        [int]$InputNumber,

        [string]$Parameter = (Set-DefaultParameterValue -Parameter 'Step-Three-Default')
    )
    begin {
        Write-Verbose "Step-Three: BEGIN block. Parameter=$Parameter"
        Start-Sleep -Seconds 1
    }
    process {
        Write-Verbose "Step-Three: PROCESS block. InputNumber=$InputNumber, Parameter=$Parameter"
        $Output = $InputNumber - 2
        Write-Output $Output
        Start-Sleep -Seconds 1
    }
    end {
        Write-Verbose "Step-Three: END block. Parameter=$Parameter"
        Start-Sleep -Seconds 1
    }
    clean {
        Write-Verbose "Step-One: CLEANUP block. Parameter=$Parameter"
        Start-Sleep -Seconds 1
    }
}

$VerbosePreference = 'Continue'
1, 2, 3 | Step-One | Step-Two | Step-Three
