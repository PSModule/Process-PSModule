﻿[CmdletBinding()]
Param(
    # Path to the module to test.
    [Parameter()]
    [string] $Path
)

Write-Verbose "Path to the module: [$Path]" -Verbose

Describe 'PSModuleTest.Tests.ps1' {
    It 'Should be able to import the module' {
        Import-Module -Name 'PSModuleTest' -Verbose
        Get-Module -Name 'PSModuleTest' | Should -Not -BeNullOrEmpty
        Write-Verbose (Get-Module -Name 'PSModuleTest' | Out-String) -Verbose
    }
    It 'Should be able to call the function' {
        Test-PSModuleTest -Name 'World' | Should -Be 'Hello, World!'
        Write-Verbose (Test-PSModuleTest -Name 'World' | Out-String) -Verbose
    }
}
