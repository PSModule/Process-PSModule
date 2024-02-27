Describe 'PSModule.Process.Tests.ps1' {
    It "Should be able to import the module" {
        Import-Module -Name 'PSModule.Process'
        Get-Module -Name 'PSModule.Process' | Should -Not -BeNullOrEmpty
        Write-Verbose (Get-Module -Name 'PSModule.Process' | Out-String) -Verbose
    }
    It "Should be able to call the function" {
        Test-PSModuleTestWF -Name 'World' | Should -Be "Hello, World!"
        Write-Verbose (Test-PSModuleTestWF -Name 'World' | Out-String) -Verbose
    }
}
