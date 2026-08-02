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
    Describe 'Get-ReleaseTag' {
        Context 'Get-ReleaseTag - repository with a version prefix' {
            It 'Get-ReleaseTag - prefixes a stable release tag with the configured prefix' {
                Get-ReleaseTag -VersionPrefix 'v' -ModuleVersion '1.1.10' | Should -Be 'v1.1.10'
            }

            It 'Get-ReleaseTag - prefixes a stable release tag when the prerelease label is empty' {
                Get-ReleaseTag -VersionPrefix 'v' -ModuleVersion '1.1.10' -Prerelease '' | Should -Be 'v1.1.10'
            }

            It 'Get-ReleaseTag - prefixes a prerelease tag with the configured prefix' {
                Get-ReleaseTag -VersionPrefix 'v' -ModuleVersion '1.1.10' -Prerelease 'mybranch001' |
                    Should -Be 'v1.1.10-mybranch001'
            }

            It 'Get-ReleaseTag - supports a multi-character prefix' {
                Get-ReleaseTag -VersionPrefix 'release-v' -ModuleVersion '2.0.0' | Should -Be 'release-v2.0.0'
            }
        }

        Context 'Get-ReleaseTag - repository without a version prefix' {
            It 'Get-ReleaseTag - leaves a stable release tag unprefixed' {
                Get-ReleaseTag -VersionPrefix '' -ModuleVersion '1.1.10' | Should -Be '1.1.10'
            }

            It 'Get-ReleaseTag - leaves a prerelease tag unprefixed' {
                Get-ReleaseTag -VersionPrefix '' -ModuleVersion '1.1.10' -Prerelease 'mybranch001' |
                    Should -Be '1.1.10-mybranch001'
            }

            It 'Get-ReleaseTag - treats an absent prefix as no prefix' {
                Get-ReleaseTag -ModuleVersion '1.1.10' | Should -Be '1.1.10'
            }

            It 'Get-ReleaseTag - treats a null prefix as no prefix' {
                Get-ReleaseTag -VersionPrefix $null -ModuleVersion '1.1.10' | Should -Be '1.1.10'
            }
        }

        Context 'Get-ReleaseTag - input normalization' {
            It 'Get-ReleaseTag - trims whitespace around the prefix' {
                Get-ReleaseTag -VersionPrefix ' v ' -ModuleVersion '1.1.10' | Should -Be 'v1.1.10'
            }

            It 'Get-ReleaseTag - trims whitespace around the prerelease label' {
                Get-ReleaseTag -VersionPrefix 'v' -ModuleVersion '1.1.10' -Prerelease ' mybranch001 ' |
                    Should -Be 'v1.1.10-mybranch001'
            }

            It 'Get-ReleaseTag - treats a whitespace-only prerelease label as a stable release' {
                Get-ReleaseTag -VersionPrefix 'v' -ModuleVersion '1.1.10' -Prerelease '   ' | Should -Be 'v1.1.10'
            }

            It 'Get-ReleaseTag - requires a module version' {
                { Get-ReleaseTag -VersionPrefix 'v' -ModuleVersion '' } | Should -Throw
            }
        }

        # Cleanup-PSModulePrereleases selects the releases to delete with
        # `tagName -like "*$prereleaseName*" -and tagName -ne $publishedReleaseTag`, where the published tag is
        # the value publish.ps1 exports as PSMODULE_PUBLISH_PSMODULE_CONTEXT_ReleaseTag. Both halves of that
        # filter have to keep working once the tag carries a prefix.
        Context 'Get-ReleaseTag - AutoCleanup tag matching contract' {
            It 'Get-ReleaseTag - keeps the prerelease name inside a prefixed tag so cleanup still matches it' {
                Get-ReleaseTag -VersionPrefix 'v' -ModuleVersion '1.1.10' -Prerelease 'mybranch001' |
                    Should -BeLike '*mybranch*'
            }

            It 'Get-ReleaseTag - keeps the prerelease name inside an unprefixed tag so cleanup still matches it' {
                Get-ReleaseTag -VersionPrefix '' -ModuleVersion '1.1.10' -Prerelease 'mybranch001' |
                    Should -BeLike '*mybranch*'
            }

            It 'Get-ReleaseTag - produces the same tag twice so cleanup can exclude the published release' {
                $first = Get-ReleaseTag -VersionPrefix 'v' -ModuleVersion '1.1.10' -Prerelease 'mybranch001'
                $second = Get-ReleaseTag -VersionPrefix 'v' -ModuleVersion '1.1.10' -Prerelease 'mybranch001'
                $first | Should -Be $second
            }
        }
    }
}
