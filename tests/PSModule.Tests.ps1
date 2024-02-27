Describe 'PSModule.Tests.ps1' {
    It "Should be able to import the module" {
        Import-Module -Name 'PSModule'
        Get-Module -Name 'PSModule' | Should -Not -BeNullOrEmpty
        Write-Verbose (Get-Module -Name 'PSModule' | Out-String) -Verbose
    }
    It "Should be able to call the function" {
        Test-PSModule -Name 'World' | Should -Be "Hello, World!"
        Write-Verbose (Test-PSModule -Name 'World' | Out-String) -Verbose
    }
}
