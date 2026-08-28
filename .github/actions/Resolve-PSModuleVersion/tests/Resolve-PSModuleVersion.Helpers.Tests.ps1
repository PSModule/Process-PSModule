[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Variables are assigned in BeforeAll and used inside It blocks.'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingCmdletAliases', 'Context',
    Justification = 'Context is part of the Pester DSL, not the Get-Context alias.'
)]
[CmdletBinding()]
param()

BeforeAll {
    Import-Module -Name 'PSModule' -Force
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../src/Resolve-PSModuleVersion.Helpers.psm1') -Force

    function Get-TestConfiguration {
        <#
            .SYNOPSIS
            Builds a publish configuration object equivalent to what Get-PublishConfiguration returns.
        #>
        [CmdletBinding()]
        [OutputType([PSCustomObject])]
        param(
            # Whether prereleases get an incrementing number suffix.
            [Parameter()]
            [bool] $IncrementalPrerelease,

            # The date format appended to the prerelease tag.
            [Parameter()]
            [string] $DatePrereleaseFormat = '',

            # The prefix put in front of the version, for example 'v'.
            [Parameter()]
            [string] $VersionPrefix = 'v'
        )

        [PSCustomObject]@{
            IncrementalPrerelease = $IncrementalPrerelease
            DatePrereleaseFormat  = $DatePrereleaseFormat
            VersionPrefix         = $VersionPrefix
        }
    }

    function Get-TestDecision {
        <#
            .SYNOPSIS
            Builds a release decision object equivalent to what Resolve-ReleaseDecision returns.
        #>
        [CmdletBinding()]
        [OutputType([PSCustomObject])]
        param(
            # The version bump to apply - Major, Minor, Patch, or None.
            [Parameter()]
            [ValidateSet('Major', 'Minor', 'Patch', 'None')]
            [string] $Bump = 'Patch',

            # Whether a prerelease tag is added to the resolved version.
            [Parameter()]
            [bool] $CreatePrerelease,

            # The sanitized prerelease name derived from the branch name.
            [Parameter()]
            [string] $PrereleaseName = '',

            # Whether the run publishes the resolved version.
            [Parameter()]
            [bool] $ShouldPublish = $true
        )

        [PSCustomObject]@{
            ShouldPublish    = $ShouldPublish
            CreateRelease    = $ShouldPublish -and -not $CreatePrerelease
            CreatePrerelease = $CreatePrerelease
            MajorRelease     = $Bump -eq 'Major'
            MinorRelease     = $Bump -eq 'Minor'
            PatchRelease     = $Bump -eq 'Patch'
            HasVersionBump   = $Bump -ne 'None'
            PrereleaseName   = $PrereleaseName
            SkipRelease      = $Bump -eq 'None'
            Bump             = $Bump
        }
    }

    function Get-TestReleaseContext {
        <#
            .SYNOPSIS
            Builds a normalized release context for decision tests.
        #>
        [CmdletBinding()]
        [OutputType([PSCustomObject])]
        param(
            [Parameter()]
            [ValidateSet('PullRequest', 'Stable', 'Cleanup', 'Validation')]
            [string] $Type = 'Stable',

            [Parameter()]
            [AllowEmptyCollection()]
            [AllowNull()]
            [string[]] $Labels = @('release:patch'),

            [Parameter()]
            [ValidateSet('Labels', 'Input', 'None')]
            [string] $DecisionSource = 'Labels',

            [Parameter()]
            [string] $ExplicitDecision = '',

            [Parameter()]
            [bool] $RequiresDecision = $true,

            [Parameter()]
            [bool] $CanPublish = $true,

            [Parameter()]
            [bool] $HasImportantChanges = $true,

            [Parameter()]
            [string] $HeadRef = 'feature-release'
        )

        [PSCustomObject]@{
            Type                = $Type
            DecisionSource      = $DecisionSource
            RequiresDecision    = $RequiresDecision
            CanPublish          = $CanPublish
            HasImportantChanges = $HasImportantChanges
            Number              = 42
            HeadRef             = $HeadRef
            Labels              = $Labels
            ExplicitDecision    = $ExplicitDecision
            IsDirectRelease     = $DecisionSource -eq 'Input'
        }
    }
}

Describe 'Resolve-PSModuleVersion' {
    Describe 'ConvertFrom-GitHubReleaseJson' {
        Context 'ConvertFrom-GitHubReleaseJson - repository without releases' {
            It 'ConvertFrom-GitHubReleaseJson - returns an empty array for an empty JSON array' {
                $result = ConvertFrom-GitHubReleaseJson -Json '[]'
                @($result).Count | Should -Be 0
            }

            It 'ConvertFrom-GitHubReleaseJson - returns an empty array when the command produced no output' {
                $result = ConvertFrom-GitHubReleaseJson -Json ''
                @($result).Count | Should -Be 0
            }

            It 'ConvertFrom-GitHubReleaseJson - returns an empty array for null input' {
                $result = ConvertFrom-GitHubReleaseJson -Json $null
                @($result).Count | Should -Be 0
            }
        }

        Context 'ConvertFrom-GitHubReleaseJson - releases present' {
            It 'ConvertFrom-GitHubReleaseJson - returns a flat array of release objects' {
                $json = '[{"tagName":"v1.2.3","isLatest":true},{"tagName":"v1.2.2","isLatest":false}]'
                $result = @(ConvertFrom-GitHubReleaseJson -Json $json)
                $result.Count | Should -Be 2
                $result[0].tagName | Should -Be 'v1.2.3'
            }

            It 'ConvertFrom-GitHubReleaseJson - returns a single release without nesting it in an inner array' {
                $result = @(ConvertFrom-GitHubReleaseJson -Json '[{"tagName":"v0.0.1","isLatest":true}]')
                $result.Count | Should -Be 1
                $result[0].tagName | Should -Be 'v0.0.1'
            }

            It 'ConvertFrom-GitHubReleaseJson - output binds to the Releases parameter without nesting' {
                $json = '[{"tagName":"v1.2.3","isLatest":true},{"tagName":"v1.2.2","isLatest":false}]'
                $releases = @(ConvertFrom-GitHubReleaseJson -Json $json)
                $result = Get-LatestGitHubVersion -Releases $releases
                $result.ToString() | Should -Be 'v1.2.3'
            }

            It 'ConvertFrom-GitHubReleaseJson - survives the log group wrapper without nesting' {
                $json = '[{"tagName":"v1.2.3","isLatest":true},{"tagName":"v1.2.2","isLatest":false}]'
                $releases = @(LogGroup 'Get releases - GitHub' { ConvertFrom-GitHubReleaseJson -Json $json })
                $releases.Count | Should -Be 2
                $releases[0].tagName | Should -Be 'v1.2.3'
            }
        }

        Describe 'Get-ResolvedModuleVersion' {
            Context 'Get-ResolvedModuleVersion - Gallery-only stable publication' {
                It 'Get-ResolvedModuleVersion - reuses the Gallery version that is the next GitHub patch release' {
                    $params = @{
                        GitHubVersion    = New-PSSemVer -Version '1.2.3'
                        PSGalleryVersion = New-PSSemVer -Version '1.2.4'
                        Decision         = Get-TestDecision -Bump 'Patch'
                        Configuration    = Get-TestConfiguration
                        ModuleName       = 'MyModule'
                        Releases         = @()
                    }

                    $result = Get-ResolvedModuleVersion @params

                    $result.ToString() | Should -Be 'v1.2.4'
                }

                It 'Get-ResolvedModuleVersion - preserves the normal Gallery baseline when versions do not identify a retry' {
                    $params = @{
                        GitHubVersion    = New-PSSemVer -Version '1.2.3'
                        PSGalleryVersion = New-PSSemVer -Version '1.2.5'
                        Decision         = Get-TestDecision -Bump 'Patch'
                        Configuration    = Get-TestConfiguration
                        ModuleName       = 'MyModule'
                        Releases         = @()
                    }

                    $result = Get-ResolvedModuleVersion @params

                    $result.ToString() | Should -Be 'v1.2.6'
                }
            }
        }
    }

    Describe 'Get-LatestGitHubVersion' {
        Context 'Get-LatestGitHubVersion - repository without releases' {
            It 'Get-LatestGitHubVersion - returns 0.0.0 when the releases list is null' {
                $result = Get-LatestGitHubVersion -Releases $null
                $result.ToString() | Should -Be '0.0.0'
            }

            It 'Get-LatestGitHubVersion - returns 0.0.0 when the releases list is an empty array' {
                $result = Get-LatestGitHubVersion -Releases @()
                $result.ToString() | Should -Be '0.0.0'
            }

            It 'Get-LatestGitHubVersion - returns 0.0.0 when no releases list is passed at all' {
                $result = Get-LatestGitHubVersion
                $result.ToString() | Should -Be '0.0.0'
            }

            It 'Get-LatestGitHubVersion - does not fail parameter binding on a null releases list' {
                { Get-LatestGitHubVersion -Releases $null } | Should -Not -Throw
            }
        }

        Context 'Get-LatestGitHubVersion - releases present but none marked as latest' {
            It 'Get-LatestGitHubVersion - returns 0.0.0 when no release is marked as latest' {
                $releases = @(
                    [PSCustomObject]@{ tagName = 'v1.2.3'; isLatest = $false; isPrerelease = $false }
                    [PSCustomObject]@{ tagName = 'v1.2.2'; isLatest = $false; isPrerelease = $false }
                )
                $result = Get-LatestGitHubVersion -Releases $releases
                $result.ToString() | Should -Be '0.0.0'
            }

            It 'Get-LatestGitHubVersion - returns 0.0.0 when the repository only has prereleases' {
                $releases = @(
                    [PSCustomObject]@{ tagName = 'v0.0.1-mybranch001'; isLatest = $false; isPrerelease = $true }
                )
                $result = Get-LatestGitHubVersion -Releases $releases
                $result.ToString() | Should -Be '0.0.0'
            }
        }

        Context 'Get-LatestGitHubVersion - releases present' {
            It 'Get-LatestGitHubVersion - returns the version of the release marked as latest' {
                $releases = @(
                    [PSCustomObject]@{ tagName = 'v1.2.2'; isLatest = $false; isPrerelease = $false }
                    [PSCustomObject]@{ tagName = 'v1.2.3'; isLatest = $true; isPrerelease = $false }
                    [PSCustomObject]@{ tagName = 'v1.3.0-mybranch001'; isLatest = $false; isPrerelease = $true }
                )
                $result = Get-LatestGitHubVersion -Releases $releases
                $result.Major | Should -Be 1
                $result.Minor | Should -Be 2
                $result.Patch | Should -Be 3
            }

            It 'Get-LatestGitHubVersion - returns the version when the repository has a single release' {
                $releases = @(
                    [PSCustomObject]@{ tagName = 'v0.0.1'; isLatest = $true; isPrerelease = $false }
                )
                $result = Get-LatestGitHubVersion -Releases $releases
                $result.Patch | Should -Be 1
            }
        }
    }

    Describe 'Get-LatestPublishedVersion' {
        Context 'Get-LatestPublishedVersion - brand-new module' {
            It 'Get-LatestPublishedVersion - returns 0.0.0 when neither source has a version' {
                $result = Get-LatestPublishedVersion -GitHubVersion $null -PSGalleryVersion $null
                $result.ToString() | Should -Be '0.0.0'
            }

            It 'Get-LatestPublishedVersion - returns 0.0.0 when both sources report the 0.0.0 baseline' {
                $params = @{
                    GitHubVersion    = New-PSSemVer -Version '0.0.0'
                    PSGalleryVersion = New-PSSemVer -Version '0.0.0'
                }
                $result = Get-LatestPublishedVersion @params
                $result.ToString() | Should -Be '0.0.0'
            }

            It 'Get-LatestPublishedVersion - returns 0.0.0 when no versions are passed at all' {
                $result = Get-LatestPublishedVersion
                $result.ToString() | Should -Be '0.0.0'
            }
        }

        Context 'Get-LatestPublishedVersion - one source has a version' {
            It 'Get-LatestPublishedVersion - returns the GitHub version when the gallery has none' {
                $result = Get-LatestPublishedVersion -GitHubVersion (New-PSSemVer -Version '1.2.3') -PSGalleryVersion $null
                $result.ToString() | Should -Be '1.2.3'
            }

            It 'Get-LatestPublishedVersion - returns the gallery version when GitHub has none' {
                $result = Get-LatestPublishedVersion -GitHubVersion $null -PSGalleryVersion (New-PSSemVer -Version '2.0.0')
                $result.ToString() | Should -Be '2.0.0'
            }
        }

        Context 'Get-LatestPublishedVersion - both sources have a version' {
            It 'Get-LatestPublishedVersion - returns the highest of the two versions' {
                $params = @{
                    GitHubVersion    = New-PSSemVer -Version '1.4.2'
                    PSGalleryVersion = New-PSSemVer -Version '1.5.0'
                }
                $result = Get-LatestPublishedVersion @params
                $result.ToString() | Should -Be '1.5.0'
            }
        }
    }

    Describe 'Get-NextPrereleaseNumber' {
        Context 'Get-NextPrereleaseNumber - repository without releases' {
            It 'Get-NextPrereleaseNumber - returns 001 when the releases list is null' {
                $params = @{
                    ModuleName     = 'PSModuleNonExistentModuleForTesting'
                    BaseVersion    = '0.0.1'
                    PrereleaseName = 'mybranch'
                    Releases       = $null
                }
                Get-NextPrereleaseNumber @params | Should -Be '001'
            }

            It 'Get-NextPrereleaseNumber - returns 001 when the releases list is an empty array' {
                $params = @{
                    ModuleName     = 'PSModuleNonExistentModuleForTesting'
                    BaseVersion    = '0.0.1'
                    PrereleaseName = 'mybranch'
                    Releases       = @()
                }
                Get-NextPrereleaseNumber @params | Should -Be '001'
            }

            It 'Get-NextPrereleaseNumber - returns 001 when no releases list is passed at all' {
                $params = @{
                    ModuleName     = 'PSModuleNonExistentModuleForTesting'
                    BaseVersion    = '0.0.1'
                    PrereleaseName = 'mybranch'
                }
                Get-NextPrereleaseNumber @params | Should -Be '001'
            }
        }

        Context 'Get-NextPrereleaseNumber - matching prereleases exist on GitHub' {
            It 'Get-NextPrereleaseNumber - returns the number after the highest matching GitHub prerelease' {
                $params = @{
                    ModuleName     = 'PSModuleNonExistentModuleForTesting'
                    BaseVersion    = '1.2.3'
                    PrereleaseName = 'mybranch'
                    Releases       = @(
                        [PSCustomObject]@{ tagName = 'v1.2.3-mybranch001'; isLatest = $false; isPrerelease = $true }
                        [PSCustomObject]@{ tagName = 'v1.2.3-mybranch005'; isLatest = $false; isPrerelease = $true }
                    )
                }
                Get-NextPrereleaseNumber @params | Should -Be '006'
            }
        }
    }

    Describe 'Get-NextModuleVersion' {
        Context 'Get-NextModuleVersion - brand-new module without releases' {
            It 'Get-NextModuleVersion - resolves the first patch release to 0.0.1' {
                $params = @{
                    LatestVersion = New-PSSemVer -Version '0.0.0'
                    Decision      = Get-TestDecision -Bump 'Patch'
                    Configuration = Get-TestConfiguration
                    ModuleName    = 'MyBrandNewModule'
                    Releases      = @()
                }
                $result = Get-NextModuleVersion @params
                $result.ToString() | Should -Be 'v0.0.1'
            }

            It 'Get-NextModuleVersion - resolves the first minor release to 0.1.0' {
                $params = @{
                    LatestVersion = New-PSSemVer -Version '0.0.0'
                    Decision      = Get-TestDecision -Bump 'Minor'
                    Configuration = Get-TestConfiguration
                    ModuleName    = 'MyBrandNewModule'
                    Releases      = @()
                }
                $result = Get-NextModuleVersion @params
                $result.ToString() | Should -Be 'v0.1.0'
            }

            It 'Get-NextModuleVersion - resolves the first major release to 1.0.0' {
                $params = @{
                    LatestVersion = New-PSSemVer -Version '0.0.0'
                    Decision      = Get-TestDecision -Bump 'Major'
                    Configuration = Get-TestConfiguration
                    ModuleName    = 'MyBrandNewModule'
                    Releases      = @()
                }
                $result = Get-NextModuleVersion @params
                $result.ToString() | Should -Be 'v1.0.0'
            }

            It 'Get-NextModuleVersion - resolves a version when the releases list is null' {
                $params = @{
                    LatestVersion = New-PSSemVer -Version '0.0.0'
                    Decision      = Get-TestDecision -Bump 'Patch'
                    Configuration = Get-TestConfiguration
                    ModuleName    = 'MyBrandNewModule'
                    Releases      = $null
                }
                $result = Get-NextModuleVersion @params
                $result.ToString() | Should -Be 'v0.0.1'
            }

            It 'Get-NextModuleVersion - resolves a version when no releases list is passed at all' {
                $params = @{
                    LatestVersion = New-PSSemVer -Version '0.0.0'
                    Decision      = Get-TestDecision -Bump 'Patch'
                    Configuration = Get-TestConfiguration
                    ModuleName    = 'MyBrandNewModule'
                }
                $result = Get-NextModuleVersion @params
                $result.ToString() | Should -Be 'v0.0.1'
            }

            It 'Get-NextModuleVersion - falls back to the 0.0.0 baseline when no latest version was resolved' {
                $params = @{
                    LatestVersion = $null
                    Decision      = Get-TestDecision -Bump 'Patch'
                    Configuration = Get-TestConfiguration
                    ModuleName    = 'MyBrandNewModule'
                    Releases      = @()
                }
                $result = Get-NextModuleVersion @params
                $result.ToString() | Should -Be 'v0.0.1'
            }

            It 'Get-NextModuleVersion - resolves the first prerelease from an empty releases list' {
                $params = @{
                    LatestVersion = New-PSSemVer -Version '0.0.0'
                    Decision      = Get-TestDecision -Bump 'Patch' -CreatePrerelease $true -PrereleaseName 'mybranch'
                    Configuration = Get-TestConfiguration
                    ModuleName    = 'MyBrandNewModule'
                    Releases      = @()
                }
                $result = Get-NextModuleVersion @params
                $result.ToString() | Should -Be 'v0.0.1-mybranch'
            }
        }

        Context 'Get-NextModuleVersion - existing module with releases' {
            It 'Get-NextModuleVersion - bumps the patch version of the latest release' {
                $params = @{
                    LatestVersion = New-PSSemVer -Version '1.2.3'
                    Decision      = Get-TestDecision -Bump 'Patch'
                    Configuration = Get-TestConfiguration
                    ModuleName    = 'MyModule'
                    Releases      = @(
                        [PSCustomObject]@{ tagName = 'v1.2.3'; isLatest = $true; isPrerelease = $false }
                    )
                }
                $result = Get-NextModuleVersion @params
                $result.ToString() | Should -Be 'v1.2.4'
            }
        }
    }

    Describe 'Resolve-PSModuleVersion' {
        Context 'Resolve-PSModuleVersion - brand-new module with no GitHub release and no gallery version' {
            It 'Resolve-PSModuleVersion - resolves the full chain to the first patch version' {
                $githubVersion = Get-LatestGitHubVersion -Releases @()
                $latestVersion = Get-LatestPublishedVersion -GitHubVersion $githubVersion -PSGalleryVersion $null
                $params = @{
                    LatestVersion = $latestVersion
                    Decision      = Get-TestDecision -Bump 'Patch'
                    Configuration = Get-TestConfiguration
                    ModuleName    = 'MyBrandNewModule'
                    Releases      = @()
                }
                $result = Get-NextModuleVersion @params

                $latestVersion.ToString() | Should -Be '0.0.0'
                $result.ToString() | Should -Be 'v0.0.1'
            }

            It 'Resolve-PSModuleVersion - resolves the full chain to the first minor version' {
                $githubVersion = Get-LatestGitHubVersion -Releases $null
                $psGalleryVersion = New-PSSemVer -Version '0.0.0'
                $latestVersion = Get-LatestPublishedVersion -GitHubVersion $githubVersion -PSGalleryVersion $psGalleryVersion
                $params = @{
                    LatestVersion = $latestVersion
                    Decision      = Get-TestDecision -Bump 'Minor'
                    Configuration = Get-TestConfiguration
                    ModuleName    = 'MyBrandNewModule'
                    Releases      = $null
                }
                $result = Get-NextModuleVersion @params

                $result.ToString() | Should -Be 'v0.1.0'
            }

            It 'Resolve-PSModuleVersion - resolves the full chain to the first major version' {
                $githubVersion = Get-LatestGitHubVersion -Releases @()
                $psGalleryVersion = New-PSSemVer -Version '0.0.0'
                $latestVersion = Get-LatestPublishedVersion -GitHubVersion $githubVersion -PSGalleryVersion $psGalleryVersion
                $params = @{
                    LatestVersion = $latestVersion
                    Decision      = Get-TestDecision -Bump 'Major'
                    Configuration = Get-TestConfiguration
                    ModuleName    = 'MyBrandNewModule'
                    Releases      = @()
                }
                $result = Get-NextModuleVersion @params

                $result.ToString() | Should -Be 'v1.0.0'
            }
        }
    }

    Describe 'Get-ReleaseContext' {
        It 'uses merged pull request labels for an associated default-branch push' {
            $settings = @{
                HasImportantChanges = $true
                Context             = @{
                    EventName             = 'push'
                    EventAction           = ''
                    IsPushToDefaultBranch = $true
                    DefaultBranch         = 'main'
                    PullRequest           = @{
                        Number  = 390
                        HeadRef = 'feature/push-release'
                        Labels  = @('release:minor')
                    }
                }
            } | ConvertTo-Json -Depth 5

            $result = Get-ReleaseContext -SettingsJson $settings -ReleaseDecision 'release:skip'

            $result.Type | Should -BeExactly 'Stable'
            $result.DecisionSource | Should -BeExactly 'Labels'
            $result.Number | Should -Be 390
            $result.Labels | Should -Be @('release:minor')
            $result.IsDirectRelease | Should -BeFalse
        }

        It 'uses the explicit input for an unassociated default-branch push' {
            $settings = @{
                HasImportantChanges = $true
                Context             = @{
                    EventName             = 'push'
                    EventAction           = ''
                    IsPushToDefaultBranch = $true
                    DefaultBranch         = 'main'
                    PullRequest           = $null
                }
            } | ConvertTo-Json -Depth 5

            $result = Get-ReleaseContext -SettingsJson $settings -ReleaseDecision 'release:major'

            $result.Type | Should -BeExactly 'Stable'
            $result.DecisionSource | Should -BeExactly 'Input'
            $result.ExplicitDecision | Should -BeExactly 'release:major'
            $result.IsDirectRelease | Should -BeTrue
        }

        It 'uses the explicit input for a default-branch workflow dispatch' {
            $settings = @{
                HasImportantChanges = $true
                Context             = @{
                    EventName                       = 'workflow_dispatch'
                    EventAction                     = ''
                    IsManualDispatchToDefaultBranch = $true
                    DefaultBranch                   = 'main'
                    PullRequest                     = $null
                }
            } | ConvertTo-Json -Depth 5

            $result = Get-ReleaseContext -SettingsJson $settings -ReleaseDecision 'release:patch'

            $result.Type | Should -BeExactly 'Stable'
            $result.DecisionSource | Should -BeExactly 'Input'
            $result.CanPublish | Should -BeTrue
        }

        It 'creates a cleanup context for a closed pull request' {
            $settings = @{
                HasImportantChanges = $true
                Context             = @{
                    EventName     = 'pull_request'
                    EventAction   = 'closed'
                    DefaultBranch = 'main'
                    PullRequest   = @{
                        Number  = 390
                        HeadRef = 'feature/closed'
                        Labels  = @('release:major', 'release:minor')
                    }
                }
            } | ConvertTo-Json -Depth 5

            $result = Get-ReleaseContext -SettingsJson $settings

            $result.Type | Should -BeExactly 'Cleanup'
            $result.RequiresDecision | Should -BeFalse
            $result.Labels | Should -BeNullOrEmpty
        }

        It 'creates a validation context for a scheduled run' {
            $settings = @{
                HasImportantChanges = $true
                Context             = @{
                    EventName     = 'schedule'
                    EventAction   = ''
                    DefaultBranch = 'main'
                    PullRequest   = $null
                }
            } | ConvertTo-Json -Depth 5

            $result = Get-ReleaseContext -SettingsJson $settings

            $result.Type | Should -BeExactly 'Validation'
            $result.RequiresDecision | Should -BeFalse
            $result.CanPublish | Should -BeFalse
        }

        It 'does not authorize unsupported events that carry pull request data' {
            $settings = @{
                HasImportantChanges = $true
                Context             = @{
                    EventName     = 'pull_request_target'
                    EventAction   = 'opened'
                    DefaultBranch = 'main'
                    PullRequest   = @{
                        Number  = 390
                        HeadRef = 'untrusted/fork'
                        Labels  = @('release:patch', 'release:pre-release')
                    }
                }
            } | ConvertTo-Json -Depth 5

            $result = Get-ReleaseContext -SettingsJson $settings

            $result.Type | Should -BeExactly 'Validation'
            $result.RequiresDecision | Should -BeFalse
            $result.CanPublish | Should -BeFalse
            $result.Labels | Should -BeNullOrEmpty
        }

        It 'fails closed when a push lacks normalized default-branch context' {
            $previousEventName = $env:GITHUB_EVENT_NAME
            $previousEventJson = $env:PSMODULE_RESOLVE_PSMODULEVERSION_INPUT_EventJson
            try {
                $env:GITHUB_EVENT_NAME = 'push'
                $env:PSMODULE_RESOLVE_PSMODULEVERSION_INPUT_EventJson = '{}'
                $settings = @{ HasImportantChanges = $true } | ConvertTo-Json

                { Get-ReleaseContext -SettingsJson $settings -ReleaseDecision 'release:patch' } |
                    Should -Throw '*without normalized default-branch context*'
            } finally {
                $env:GITHUB_EVENT_NAME = $previousEventName
                $env:PSMODULE_RESOLVE_PSMODULEVERSION_INPUT_EventJson = $previousEventJson
            }
        }
    }

    Describe 'Resolve-ReleaseDecision' {
        It 'resolves a stable <Bump> release' -ForEach @(
            @{ Label = 'release:patch'; Bump = 'Patch' }
            @{ Label = 'release:minor'; Bump = 'Minor' }
            @{ Label = 'release:major'; Bump = 'Major' }
        ) {
            $context = Get-TestReleaseContext -Type Stable -Labels @($Label)

            $result = Resolve-ReleaseDecision -ReleaseContext $context

            $result.Bump | Should -BeExactly $Bump
            $result.ShouldPublish | Should -BeTrue
            $result.CreateRelease | Should -BeTrue
            $result.CreatePrerelease | Should -BeFalse
        }

        It 'resolves a <Bump> pull request prerelease' -ForEach @(
            @{ Label = 'release:patch'; Bump = 'Patch' }
            @{ Label = 'release:minor'; Bump = 'Minor' }
            @{ Label = 'release:major'; Bump = 'Major' }
        ) {
            $labels = @($Label, 'release:pre-release')
            $context = Get-TestReleaseContext -Type PullRequest -Labels $labels

            $result = Resolve-ReleaseDecision -ReleaseContext $context

            $result.Bump | Should -BeExactly $Bump
            $result.ShouldPublish | Should -BeTrue
            $result.CreateRelease | Should -BeFalse
            $result.CreatePrerelease | Should -BeTrue
        }

        It 'creates a non-publishing preview version for a bump-only pull request' {
            $context = Get-TestReleaseContext -Type PullRequest -Labels @('release:minor')

            $result = Resolve-ReleaseDecision -ReleaseContext $context

            $result.Bump | Should -BeExactly 'Minor'
            $result.ShouldPublish | Should -BeFalse
            $result.CreatePrerelease | Should -BeTrue
        }

        It 'publishes a merged pull request as stable when prerelease mode remains applied' {
            $labels = @('release:minor', 'release:pre-release')
            $context = Get-TestReleaseContext -Type Stable -Labels $labels

            $result = Resolve-ReleaseDecision -ReleaseContext $context

            $result.ShouldPublish | Should -BeTrue
            $result.CreateRelease | Should -BeTrue
            $result.CreatePrerelease | Should -BeFalse
        }

        It 'resolves release:skip without a version bump' -ForEach @(
            @{ Type = 'PullRequest' }
            @{ Type = 'Stable' }
        ) {
            $context = Get-TestReleaseContext -Type $Type -Labels @('release:skip')

            $result = Resolve-ReleaseDecision -ReleaseContext $context

            $result.Bump | Should -BeExactly 'None'
            $result.SkipRelease | Should -BeTrue
            $result.ShouldPublish | Should -BeFalse
            $result.HasVersionBump | Should -BeFalse
        }

        It 'ignores unrelated labels alongside one canonical decision' {
            $labels = @('dependencies', 'Major', 'release:patch', 'release:unknown')
            $context = Get-TestReleaseContext -Type Stable -Labels $labels

            $result = Resolve-ReleaseDecision -ReleaseContext $context

            $result.Bump | Should -BeExactly 'Patch'
            $result.ShouldPublish | Should -BeTrue
        }

        It 'validates but does not publish an unimportant canonical change' {
            $contextParams = @{
                Type                = 'Stable'
                Labels              = @('release:major')
                HasImportantChanges = $false
            }
            $context = Get-TestReleaseContext @contextParams

            $result = Resolve-ReleaseDecision -ReleaseContext $context

            $result.Bump | Should -BeExactly 'Major'
            $result.ShouldPublish | Should -BeFalse
        }

        It 'rejects <Name>' -ForEach @(
            @{
                Name    = 'an empty label set'
                Labels  = @()
                Message = '*Release decision is missing*'
            }
            @{
                Name    = 'legacy bare labels'
                Labels  = @('Major', 'Minor', 'Patch', 'Prerelease', 'NoRelease')
                Message = '*Release decision is missing*'
            }
            @{
                Name    = 'lowercase bare labels and aliases'
                Labels  = @('major', 'minor', 'patch', 'prerelease', 'breaking', 'feature', 'fix')
                Message = '*Release decision is missing*'
            }
            @{
                Name    = 'noncanonical casing'
                Labels  = @('Release:Patch')
                Message = '*Release decision is missing*'
            }
            @{
                Name    = 'prerelease without a bump'
                Labels  = @('release:pre-release')
                Message = '*release:pre-release requires exactly one release bump label*'
            }
            @{
                Name    = 'patch and minor'
                Labels  = @('release:patch', 'release:minor')
                Message = '*Conflicting release bump labels*'
            }
            @{
                Name    = 'minor and major'
                Labels  = @('release:minor', 'release:major')
                Message = '*Conflicting release bump labels*'
            }
            @{
                Name    = 'patch and major'
                Labels  = @('release:patch', 'release:major')
                Message = '*Conflicting release bump labels*'
            }
            @{
                Name    = 'all bumps'
                Labels  = @('release:patch', 'release:minor', 'release:major')
                Message = '*Conflicting release bump labels*'
            }
            @{
                Name    = 'skip and patch'
                Labels  = @('release:skip', 'release:patch')
                Message = '*release:skip must not be combined*'
            }
            @{
                Name    = 'skip and prerelease'
                Labels  = @('release:skip', 'release:pre-release')
                Message = '*release:skip must not be combined*'
            }
        ) {
            $context = Get-TestReleaseContext -Type PullRequest -Labels $Labels

            { Resolve-ReleaseDecision -ReleaseContext $context } |
                Should -Throw $Message
        }

        It 'resolves an explicit <Bump> decision' -ForEach @(
            @{ Decision = 'release:patch'; Bump = 'Patch' }
            @{ Decision = 'release:minor'; Bump = 'Minor' }
            @{ Decision = 'release:major'; Bump = 'Major' }
        ) {
            $contextParams = @{
                Type             = 'Stable'
                DecisionSource   = 'Input'
                ExplicitDecision = $Decision
                Labels           = @()
            }
            $context = Get-TestReleaseContext @contextParams

            $result = Resolve-ReleaseDecision -ReleaseContext $context

            $result.Bump | Should -BeExactly $Bump
            $result.CreateRelease | Should -BeTrue
        }

        It 'resolves explicit release:skip' {
            $contextParams = @{
                Type             = 'Stable'
                DecisionSource   = 'Input'
                ExplicitDecision = 'release:skip'
                Labels           = @()
            }
            $context = Get-TestReleaseContext @contextParams

            $result = Resolve-ReleaseDecision -ReleaseContext $context

            $result.SkipRelease | Should -BeTrue
            $result.ShouldPublish | Should -BeFalse
        }

        It 'rejects the invalid explicit decision <Decision>' -ForEach @(
            @{ Decision = ''; Message = '*Invalid or missing ReleaseDecision*' }
            @{ Decision = 'release:pre-release'; Message = '*Invalid or missing ReleaseDecision*' }
            @{ Decision = 'patch'; Message = '*Invalid or missing ReleaseDecision*' }
            @{ Decision = 'Release:Patch'; Message = '*Invalid or missing ReleaseDecision*' }
        ) {
            $contextParams = @{
                Type             = 'Stable'
                DecisionSource   = 'Input'
                ExplicitDecision = $Decision
                Labels           = @()
            }
            $context = Get-TestReleaseContext @contextParams

            { Resolve-ReleaseDecision -ReleaseContext $context } |
                Should -Throw $Message
        }

        It 'does not let an explicit input override associated pull request labels' {
            $context = Get-TestReleaseContext -Type Stable -Labels @('release:minor')
            $context | Add-Member -MemberType NoteProperty `
                -Name ExplicitDecision -Value 'release:major' -Force

            $result = Resolve-ReleaseDecision -ReleaseContext $context

            $result.Bump | Should -BeExactly 'Minor'
        }

        It 'bypasses a release decision for <Type>' -ForEach @(
            @{ Type = 'Cleanup' }
            @{ Type = 'Validation' }
        ) {
            $contextParams = @{
                Type             = $Type
                DecisionSource   = 'None'
                RequiresDecision = $false
                Labels           = @('release:major', 'release:minor')
            }
            $context = Get-TestReleaseContext @contextParams

            $result = Resolve-ReleaseDecision -ReleaseContext $context

            $result.ShouldPublish | Should -BeFalse
            $result.HasVersionBump | Should -BeFalse
        }

        It 'rejects a pull request context without a head branch' {
            $contextParams = @{
                Type    = 'PullRequest'
                Labels  = @('release:patch')
                HeadRef = ''
            }
            $context = Get-TestReleaseContext @contextParams

            { Resolve-ReleaseDecision -ReleaseContext $context } |
                Should -Throw '*head branch name is missing*'
        }
    }
}
