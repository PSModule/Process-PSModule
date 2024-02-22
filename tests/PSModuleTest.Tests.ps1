Describe 'PSModuleTestWFWF.Tests.ps1' {
    It "Should be able to import the module" {
        Import-Module -Name 'PSModuleTestWF'
        Get-Module -Name 'PSModuleTestWF' | Should -Not -BeNullOrEmpty
        Write-Verbose (Get-Module -Name 'PSModuleTestWF' | Out-String) -Verbose
    }
    It "Should be able to call the function" {
        Test-PSModuleTestWF -Name 'World' | Should -Be "Hello, World!"
        Write-Verbose (Test-PSModuleTestWF -Name 'World' | Out-String) -Verbose
    }
}
