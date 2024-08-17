[CmdletBinding()]
Param(
    # Path to the module to test.
    [Parameter()]
    [string] $Path
)

Write-Verbose "Path to the module: [$Path]" -Verbose

Describe 'PSModuleTest.Tests.ps1' {
    It 'Should be able to import the module' {
        Import-Module -name 'PSModuleTest' -Verbose
        Get-Module -name 'PSModuleTest' | Should -Not -BeNullOrEmpty
        Write-Verbose (Get-Module -name 'PSModuleTest' | Out-String) -Verbose
    }
    It 'Should be able to call the function' {
        Test-PSModuleTest -name 'World' | Should -Be 'Hello, World!'
        Write-Verbose (Test-PSModuleTest -name 'World' | Out-String) -Verbose
    }

    Context 'Variables' {
        It "Exports a variable for SolarSystems that contains 'Solar System'" {
            Write-Verbose ($SolarSystems | Out-String) -Verbose
            $SolarSystems[0].Name | Should -Be 'Solar System'
        }
    }
}
