[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Variables are assigned in BeforeAll and used inside It blocks.'
)]
[CmdletBinding()]
param()

BeforeAll {
    Import-Module -Name 'PSModule' -Force
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../src/Publish-PSModule.Helpers.psm1') -Force
}

Describe 'Publish-PSModule.Helpers' {
    Describe 'Get-ModuleVersionString' {
        Context 'Get-ModuleVersionString - SemVer only, never prefixed' {
            It 'Get-ModuleVersionString - returns the module version for a stable release' {
                Get-ModuleVersionString -ModuleVersion '1.1.10' | Should -Be '1.1.10'
            }

            It 'Get-ModuleVersionString - appends the prerelease label' {
                Get-ModuleVersionString -ModuleVersion '1.1.10' -Prerelease 'mybranch001' |
                    Should -Be '1.1.10-mybranch001'
            }

            It 'Get-ModuleVersionString - treats an empty prerelease label as a stable release' {
                Get-ModuleVersionString -ModuleVersion '1.1.10' -Prerelease '' | Should -Be '1.1.10'
            }

            It 'Get-ModuleVersionString - treats a whitespace-only prerelease label as a stable release' {
                Get-ModuleVersionString -ModuleVersion '1.1.10' -Prerelease '   ' | Should -Be '1.1.10'
            }

            It 'Get-ModuleVersionString - trims whitespace around the prerelease label' {
                Get-ModuleVersionString -ModuleVersion '1.1.10' -Prerelease ' mybranch001 ' |
                    Should -Be '1.1.10-mybranch001'
            }

            It 'Get-ModuleVersionString - takes no version prefix parameter at all' {
                (Get-Command Get-ModuleVersionString).Parameters.Keys | Should -Not -Contain 'VersionPrefix'
            }

            It 'Get-ModuleVersionString - requires a module version' {
                { Get-ModuleVersionString -ModuleVersion '' } | Should -Throw
            }
        }
    }

}
