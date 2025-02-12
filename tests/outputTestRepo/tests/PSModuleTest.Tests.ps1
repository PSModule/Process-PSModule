[CmdletBinding()]
Param(
    # Path to the module to test.
    [Parameter()]
    [string] $Path
)

Write-Verbose "Path to the module: [$Path]" -Verbose
Describe 'Environment Variables are available' {
    It 'Should be available [<_>]' -ForEach @(
        'TEST_APP_ENT_CLIENT_ID',
        'TEST_APP_ENT_PRIVATE_KEY',
        'TEST_APP_ORG_CLIENT_ID',
        'TEST_APP_ORG_PRIVATE_KEY',
        'TEST_USER_ORG_FG_PAT',
        'TEST_USER_USER_FG_PAT',
        'TEST_USER_PAT'
    ) {
        $name = $_
        Write-Verbose "Environment variable: [$name]" -Verbose
        Get-ChildItem env: | Where-Object { $_.Name -eq $name } | Should -Not -BeNullOrEmpty
    }
}

Describe 'PSModuleTest.Tests.ps1' {
    Context 'Function: Test-PSModuleTest' {
        It 'Should be able to call the function' {
            Write-Verbose (Test-PSModuleTest -Name 'World' | Out-String) -Verbose
            Test-PSModuleTest -Name 'World' | Should -Be 'Hello, World!'
        }
    }

    Context 'Function: Get-PSModuleTest' {
        It 'Should be able to call the function' {
            Write-Verbose (Get-PSModuleTest -Name 'World' | Out-String) -Verbose
            Get-PSModuleTest -Name 'World' | Should -Be 'Hello, World!'
        }
    }

    Context 'Function: New-PSModuleTest' {
        It 'Should be able to call the function' {
            Write-Verbose (New-PSModuleTest -Name 'World' | Out-String) -Verbose
            New-PSModuleTest -Name 'World' | Should -Be 'Hello, World!'
        }
    }

    Context 'Function: Set-PSModuleTest' {
        It 'Should be able to call the function' {
            Write-Verbose (Set-PSModuleTest -Name 'World' | Out-String) -Verbose
            Set-PSModuleTest -Name 'World' | Should -Be 'Hello, World!'
        }
    }

    Context 'Variables' {
        It "Exports a variable for SolarSystems that contains 'Solar System'" {
            Write-Verbose ($SolarSystems | Out-String) -Verbose
            $SolarSystems[0].Name | Should -Be 'Solar System'
        }
    }
}
