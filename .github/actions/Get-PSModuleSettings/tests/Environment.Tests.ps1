#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0'; MaximumVersion = '6.*' }

BeforeAll {
    # Minimal test file for validation purposes
}

Describe 'Environment' {
    It 'Should have PowerShell available' {
        $PSVersionTable.PSVersion | Should -Not -BeNullOrEmpty
    }

    It 'Should have expected OS platform' {
        $PSVersionTable.Platform | Should -BeIn @('Win32NT', 'Unix')
    }
}
