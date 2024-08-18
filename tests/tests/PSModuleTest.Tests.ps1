[CmdletBinding()]
Param(
    # Path to the module to test.
    [Parameter()]
    [string] $Path
)

Write-Verbose "Path to the module: [$Path]" -Verbose

Describe 'PSModuleTest.Tests.ps1' {
    Context 'Function: Test-PSModuleTest' {
        It 'Should be able to call the function' {
            Write-Verbose (Test-PSModuleTest | Out-String) -Verbose
            Test-PSModuleTest | Should -Be 'Hello, World!'
        }
    }

    Context 'Function: Get-PSModuleTest' {
        It 'Should be able to call the function' {
            Write-Verbose (Get-PSModuleTest | Out-String) -Verbose
            Get-PSModuleTest | Should -Be 'Hello, World!'
        }
    }

    Context 'Function: New-PSModuleTest' {
        It 'Should be able to call the function' {
            Write-Verbose (New-PSModuleTest | Out-String) -Verbose
            New-PSModuleTest | Should -Be 'Hello, World!'
        }
    }

    Context 'Variables' {
        It "Exports a variable for SolarSystems that contains 'Solar System'" {
            Write-Verbose ($SolarSystems | Out-String) -Verbose
            $SolarSystems[0].Name | Should -Be 'Solar System'
        }
    }
}
