[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Variables are assigned in BeforeAll and used inside It blocks.'
)]
[CmdletBinding()]
param()

BeforeAll {
    Import-Module -Name 'PSModule' -Force
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../Get-PSModuleSettings/src/Get-PSModuleSettings.Helpers.psm1') -Force
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../src/Resolve-PSModuleVersion.Helpers.psm1') -Force

    function Get-TestConfiguration {
        <#
            .SYNOPSIS
            Builds a publish configuration object equivalent to what Get-PublishConfiguration returns.
        #>
        [CmdletBinding()]
        [OutputType([PSCustomObject])]
        param(
            # The bump used when no configured bump label is present.
            [Parameter()]
            [string] $DefaultBump = 'patch',

            # Whether prereleases get an incrementing number suffix.
            [Parameter()]
            [bool] $IncrementalPrerelease,

            # The date format appended to the prerelease tag.
            [Parameter()]
            [string] $DatePrereleaseFormat = '',

            # The prefix put in front of the version, for example 'v'.
            [Parameter()]
            [string] $VersionPrefix = 'v',

            # The release type resolved from the pull request labels.
            [Parameter()]
            [string] $ReleaseType = 'Release',

            # Whether the normalized event is closed-PR cleanup.
            [Parameter()]
            [switch] $CleanupOnly,

            # Labels indicating no release.
            [Parameter()]
            [string[]] $IgnoreLabels = @('release:skip'),

            # Labels indicating a major release.
            [Parameter()]
            [string[]] $MajorLabels = @('release:major'),

            # Labels indicating a minor release.
            [Parameter()]
            [string[]] $MinorLabels = @('release:minor'),

            # Labels indicating a patch release.
            [Parameter()]
            [string[]] $PatchLabels = @('release:patch'),

            # Labels indicating prerelease mode.
            [Parameter()]
            [string[]] $PrereleaseLabels = @('release:prerelease')
        )

        [PSCustomObject]@{
            DefaultBump           = $DefaultBump
            IncrementalPrerelease = $IncrementalPrerelease
            DatePrereleaseFormat  = $DatePrereleaseFormat
            VersionPrefix         = $VersionPrefix
            ReleaseType           = $ReleaseType
            IsCleanupOnly         = $CleanupOnly.IsPresent
            IgnoreLabels          = $IgnoreLabels
            MajorLabels           = $MajorLabels
            MinorLabels           = $MinorLabels
            PatchLabels           = $PatchLabels
            PrereleaseLabels      = $PrereleaseLabels
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
        }
    }
}

Describe 'Resolve-PSModuleVersion' {
    Describe 'Get-PublishConfiguration' {
        It 'distinguishes cleanup from an open preview or recovered stable release' -ForEach @(
            @{ EventName = 'pull_request'; EventAction = 'labeled'; Closed = $false; Cleanup = $false }
            @{ EventName = 'pull_request'; EventAction = 'closed'; Closed = $true; Cleanup = $true }
            @{ EventName = 'workflow_dispatch'; EventAction = ''; Closed = $true; Cleanup = $false }
        ) {
            $publishModule = Resolve-PSModulePublishSetting -PublishModule $null
            $publishModule | Add-Member -NotePropertyName ReleaseType -NotePropertyValue 'None'
            $json = @{
                Publish = @{ Module = $publishModule }
                Context = @{
                    EventName = $EventName; EventAction = $EventAction; PullRequest = @{ Closed = $Closed }
                }
            } | ConvertTo-Json -Depth 6

            $configuration = Get-PublishConfiguration -SettingsJson $json

            $configuration.IsCleanupOnly | Should -Be $Cleanup
            $configuration.PrereleaseLabels | Should -Be @('release:prerelease')
        }

        It 'rejects legacy AutoPatching even when a valid DefaultBump is also present' {
            $json = @{
                Publish = @{ Module = @{ DefaultBump = 'patch'; AutoPatching = $true; ReleaseType = 'Release' } }
            } | ConvertTo-Json -Depth 5

            { Get-PublishConfiguration -SettingsJson $json } | Should -Throw '*AutoPatching*DefaultBump*'
        }

        It 'maps DefaultBump and configured labels from settings JSON' {
            $settings = @{
                Publish = @{
                    Module = @{
                        DefaultBump           = 'major'
                        IncrementalPrerelease = $true
                        DatePrereleaseFormat  = ''
                        VersionPrefix         = 'v'
                        ReleaseType           = 'Release'
                        IgnoreLabels          = 'custom:skip'
                        MajorLabels           = 'custom:major'
                        MinorLabels           = 'custom:minor'
                        PatchLabels           = 'custom:patch'
                    }
                }
            } | ConvertTo-Json -Depth 5

            $configuration = Get-PublishConfiguration -SettingsJson $settings
            $pullRequest = [pscustomobject]@{
                HeadRef = 'main'
                Labels  = @('custom:minor')
            }
            $result = Resolve-ReleaseDecision -Configuration $configuration -PullRequest $pullRequest

            $configuration.DefaultBump | Should -BeExactly 'major'
            $configuration.MinorLabels | Should -Be @('custom:minor')
            $result.MinorRelease | Should -BeTrue
            $result.MajorRelease | Should -BeFalse
        }
    }

    Describe 'ConvertFrom-GitHubReleaseJson' {
        Pester\Context 'ConvertFrom-GitHubReleaseJson - repository without releases' {
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

        Pester\Context 'ConvertFrom-GitHubReleaseJson - releases present' {
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
                $releases = @(Set-GitHubLogGroup 'Get releases - GitHub' { ConvertFrom-GitHubReleaseJson -Json $json })
                $releases.Count | Should -Be 2
                $releases[0].tagName | Should -Be 'v1.2.3'
            }
        }

        Describe 'Get-ResolvedModuleVersion' {
            Pester\Context 'Get-ResolvedModuleVersion - Gallery-only stable publication' {
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
        Pester\Context 'Get-LatestGitHubVersion - repository without releases' {
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

        Pester\Context 'Get-LatestGitHubVersion - releases present but none marked as latest' {
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

        Pester\Context 'Get-LatestGitHubVersion - releases present' {
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
        Pester\Context 'Get-LatestPublishedVersion - brand-new module' {
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

        Pester\Context 'Get-LatestPublishedVersion - one source has a version' {
            It 'Get-LatestPublishedVersion - returns the GitHub version when the gallery has none' {
                $result = Get-LatestPublishedVersion -GitHubVersion (New-PSSemVer -Version '1.2.3') -PSGalleryVersion $null
                $result.ToString() | Should -Be '1.2.3'
            }

            It 'Get-LatestPublishedVersion - returns the gallery version when GitHub has none' {
                $result = Get-LatestPublishedVersion -GitHubVersion $null -PSGalleryVersion (New-PSSemVer -Version '2.0.0')
                $result.ToString() | Should -Be '2.0.0'
            }
        }

        Pester\Context 'Get-LatestPublishedVersion - both sources have a version' {
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
        Pester\Context 'Get-NextPrereleaseNumber - repository without releases' {
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

        Pester\Context 'Get-NextPrereleaseNumber - matching prereleases exist on GitHub' {
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
        Pester\Context 'Get-NextModuleVersion - brand-new module without releases' {
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
                    Configuration = Get-TestConfiguration -ReleaseType 'Prerelease'
                    ModuleName    = 'MyBrandNewModule'
                    Releases      = @()
                }
                $result = Get-NextModuleVersion @params
                $result.ToString() | Should -Be 'v0.0.1-mybranch'
            }
        }

        Pester\Context 'Get-NextModuleVersion - existing module with releases' {
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
        Pester\Context 'Resolve-PSModuleVersion - brand-new module with no GitHub release and no gallery version' {
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

    Describe 'Get-GitHubPullRequest' {
        It 'uses the normalized pull request from a default-branch push' {
            $settings = @{
                Context = @{
                    IsPushToDefaultBranch = $true
                    DefaultBranch         = 'main'
                    PullRequest           = @{
                        Number  = 390
                        HeadRef = 'feature/push-release'
                        Labels  = @('release:minor')
                    }
                }
            } | ConvertTo-Json -Depth 5

            $result = Get-GitHubPullRequest -SettingsJson $settings

            $result.Number | Should -Be 390
            $result.HeadRef | Should -Be 'feature/push-release'
            $result.Labels | Should -Be @('release:minor')
        }

        It 'creates direct-release context for a default-branch push' {
            $settings = @{
                Context = @{
                    IsPushToDefaultBranch = $true
                    DefaultBranch         = 'main'
                    PullRequest           = $null
                }
            } | ConvertTo-Json -Depth 5

            $result = Get-GitHubPullRequest -SettingsJson $settings

            $result.Number | Should -BeNullOrEmpty
            $result.HeadRef | Should -Be 'main'
            $result.Labels | Should -BeNullOrEmpty
            $result.IsDirectRelease | Should -BeTrue
        }

        It 'honors the version label from a pull request resolved by a default-branch dispatch' {
            # Regression guard for issue #530. Before the fix, a manual dispatch resolved no pull
            # request, so Context.PullRequest was null and the direct-release branch applied a patch
            # bump. With the pull request resolved, the minor label must be carried through.
            $settings = @{
                Context = @{
                    IsPushToDefaultBranch           = $false
                    IsManualDispatchToDefaultBranch = $true
                    DefaultBranch                   = 'main'
                    PullRequest                     = @{
                        Number  = 64
                        HeadRef = 'feature/recovered-release'
                        Labels  = @('release:minor')
                    }
                }
            } | ConvertTo-Json -Depth 5

            $result = Get-GitHubPullRequest -SettingsJson $settings

            $result.Number | Should -Be 64
            $result.Labels | Should -Be @('release:minor')
            $result.IsDirectRelease | Should -BeNullOrEmpty
        }

        It 'creates direct-release context for a default-branch dispatch' {
            $settings = @{
                Context = @{
                    IsPushToDefaultBranch           = $false
                    IsManualDispatchToDefaultBranch = $true
                    DefaultBranch                   = 'main'
                    PullRequest                     = $null
                }
            } | ConvertTo-Json -Depth 5

            $result = Get-GitHubPullRequest -SettingsJson $settings

            $result.Number | Should -BeNullOrEmpty
            $result.IsDirectRelease | Should -BeTrue
        }
    }

    Describe 'Resolve-ReleaseDecision' {
        It 'uses the configured <DefaultBump> bump for a direct stable release' -ForEach @(
            @{ DefaultBump = 'patch'; Flag = 'PatchRelease' }
            @{ DefaultBump = 'minor'; Flag = 'MinorRelease' }
            @{ DefaultBump = 'major'; Flag = 'MajorRelease' }
        ) {
            $result = Resolve-ReleaseDecision -Configuration (Get-TestConfiguration -DefaultBump $DefaultBump) `
                -PullRequest ([pscustomobject]@{ HeadRef = 'main'; Labels = @(); IsDirectRelease = $true })

            $result.ShouldPublish | Should -BeTrue
            $result.$Flag | Should -BeTrue
        }

        It 'resolves <ExpectedVersion> for a <EventName> with <Label> release intent' -ForEach @(
            @{ EventName = 'workflow_dispatch'; Label = 'release:major'; ExpectedVersion = 'v1.0.0' }
            @{ EventName = 'workflow_dispatch'; Label = 'release:minor'; ExpectedVersion = 'v0.5.0' }
            @{ EventName = 'workflow_dispatch'; Label = 'release:patch'; ExpectedVersion = 'v0.4.14' }
            @{ EventName = 'workflow_dispatch'; Label = ''; ExpectedVersion = 'v0.4.14' }
            @{ EventName = 'workflow_dispatch'; Label = 'release:skip'; ExpectedVersion = 'no publication' }
            @{ EventName = 'push'; Label = 'release:major'; ExpectedVersion = 'v1.0.0' }
            @{ EventName = 'push'; Label = 'release:minor'; ExpectedVersion = 'v0.5.0' }
            @{ EventName = 'push'; Label = 'release:patch'; ExpectedVersion = 'v0.4.14' }
            @{ EventName = 'push'; Label = ''; ExpectedVersion = 'v0.4.14' }
            @{ EventName = 'push'; Label = 'release:skip'; ExpectedVersion = 'no publication' }
        ) {
            $associatedPullRequests = if ($Label) {
                @([pscustomobject]@{
                        Number           = 64
                        Base             = [pscustomobject]@{ Ref = 'main' }
                        Head             = [pscustomobject]@{ Ref = 'feature/recovered-release' }
                        merged_at        = '2026-09-02T09:02:24Z'
                        merge_commit_sha = 'released-sha'
                        Labels           = @([pscustomobject]@{ Name = $Label })
                    })
            } else {
                @()
            }
            $parameters = @{
                EventName                       = $EventName
                CommitSha                       = 'released-sha'
                DefaultBranch                   = 'main'
                IsPushToDefaultBranch           = $EventName -eq 'push'
                IsManualDispatchToDefaultBranch = $EventName -eq 'workflow_dispatch'
                GetAssociatedPullRequest        = { $associatedPullRequests }.GetNewClosure()
            }
            $resolution = Resolve-ReleasePullRequest @parameters
            $resolvedPullRequest = $resolution.PullRequest
            $normalizedPullRequest = if ($resolvedPullRequest) {
                @{
                    Number  = $resolvedPullRequest.Number
                    HeadRef = $resolvedPullRequest.Head.Ref
                    Labels  = @($resolvedPullRequest.Labels.Name)
                }
            } else {
                $null
            }
            $settingsJson = @{
                Context = @{
                    IsPushToDefaultBranch           = $parameters.IsPushToDefaultBranch
                    IsManualDispatchToDefaultBranch = $parameters.IsManualDispatchToDefaultBranch
                    DefaultBranch                   = 'main'
                    PullRequest                     = $normalizedPullRequest
                }
            } | ConvertTo-Json -Depth 5
            $configuration = Get-TestConfiguration
            $pullRequest = Get-GitHubPullRequest -SettingsJson $settingsJson
            $decision = Resolve-ReleaseDecision -Configuration $configuration -PullRequest $pullRequest
            $resolution.Resolved | Should -BeTrue
            if ($Label -eq 'release:skip') {
                $pullRequest.Number | Should -Be 64
                $decision.ShouldPublish | Should -BeFalse
                $decision.CreateRelease | Should -BeFalse
                return
            }
            $versionParameters = @{
                GitHubVersion    = New-PSSemVer -Version '0.4.13'
                PSGalleryVersion = New-PSSemVer -Version '0.4.13'
                Decision         = $decision
                Configuration    = $configuration
                ModuleName       = 'DispatchTestModule'
            }
            $resolvedVersion = Get-ResolvedModuleVersion @versionParameters

            $decision.ShouldPublish | Should -BeTrue
            $resolvedVersion.ToString() | Should -Be $ExpectedVersion
            if ($Label) {
                $pullRequest.Number | Should -Be 64
            } else {
                $pullRequest.IsDirectRelease | Should -BeTrue
            }
        }

        It 'uses the configured default bump for a prerelease mode label' {
            $result = Resolve-ReleaseDecision -Configuration (Get-TestConfiguration -DefaultBump 'major' -ReleaseType Prerelease) `
                -PullRequest ([pscustomobject]@{ HeadRef = 'feature'; Labels = @() })

            $result.ShouldPublish | Should -BeTrue
            $result.MajorRelease | Should -BeTrue
        }

        It 'does not validate cleanup-only pull request labels' {
            $result = Resolve-ReleaseDecision -Configuration (Get-TestConfiguration -ReleaseType None -CleanupOnly) `
                -PullRequest ([pscustomobject]@{ HeadRef = 'feature'; Labels = @('release:skip', 'release:patch') })

            $result.ShouldPublish | Should -BeFalse
            $result.HasVersionBump | Should -BeFalse
        }

        It 'rejects multiple version labels' {
            {
                Resolve-ReleaseDecision -Configuration (Get-TestConfiguration) `
                    -PullRequest ([pscustomobject]@{ HeadRef = 'main'; Labels = @('release:major', 'release:patch') })
            } | Should -Throw '*Conflicting version labels*'
        }

        It 'rejects release:skip combined with a version label' {
            {
                Resolve-ReleaseDecision -Configuration (Get-TestConfiguration) `
                    -PullRequest ([pscustomobject]@{ HeadRef = 'main'; Labels = @('release:skip', 'release:patch') })
            } | Should -Throw '*ignore label cannot be combined*'
        }

        It 'honors the canonical <Bump> label' -ForEach @(
            @{ Bump = 'Major'; Label = 'release:major'; Flag = 'MajorRelease' }
            @{ Bump = 'Minor'; Label = 'release:minor'; Flag = 'MinorRelease' }
            @{ Bump = 'Patch'; Label = 'release:patch'; Flag = 'PatchRelease' }
        ) {
            $pullRequest = [pscustomobject]@{
                HeadRef = 'main'
                Labels  = @($Label)
            }

            $result = Resolve-ReleaseDecision -Configuration (Get-TestConfiguration) -PullRequest $pullRequest

            $result.$Flag | Should -BeTrue
            $result.ShouldPublish | Should -BeTrue
        }

        It 'honors the configured <Bump> label mapping' -ForEach @(
            @{ Bump = 'Major'; Setting = 'MajorLabels'; Label = 'custom:major'; Flag = 'MajorRelease' }
            @{ Bump = 'Minor'; Setting = 'MinorLabels'; Label = 'custom:minor'; Flag = 'MinorRelease' }
            @{ Bump = 'Patch'; Setting = 'PatchLabels'; Label = 'custom:patch'; Flag = 'PatchRelease' }
        ) {
            $configuration = Get-TestConfiguration
            $configuration.$Setting = @($Label)
            $pullRequest = [pscustomobject]@{
                HeadRef = 'main'
                Labels  = @($Label)
            }

            $result = Resolve-ReleaseDecision -Configuration $configuration -PullRequest $pullRequest

            $result.$Flag | Should -BeTrue
            $result.ShouldPublish | Should -BeTrue
        }

        It 'gives an explicit bump label precedence over DefaultBump' {
            $configuration = Get-TestConfiguration -DefaultBump 'major'
            $pullRequest = [pscustomobject]@{
                HeadRef = 'main'
                Labels  = @('release:minor')
            }

            $result = Resolve-ReleaseDecision -Configuration $configuration -PullRequest $pullRequest

            $result.MinorRelease | Should -BeTrue
            $result.MajorRelease | Should -BeFalse
        }

        It 'honors a configured ignore label' {
            $configuration = Get-TestConfiguration -DefaultBump 'major' -IgnoreLabels @('custom:skip')
            $pullRequest = [pscustomobject]@{
                HeadRef = 'main'
                Labels  = @('custom:skip')
            }

            $result = Resolve-ReleaseDecision -Configuration $configuration -PullRequest $pullRequest

            $result.ShouldPublish | Should -BeFalse
            $result.CreateRelease | Should -BeFalse
        }

        It 'rejects an invalid DefaultBump with valid values' {
            $configuration = Get-TestConfiguration -DefaultBump 'none'
            $pullRequest = [pscustomobject]@{
                HeadRef = 'main'
                Labels  = @()
            }

            { Resolve-ReleaseDecision -Configuration $configuration -PullRequest $pullRequest } |
                Should -Throw '*Valid values are: patch, minor, major*'
        }

        It 'resolves the <DefaultBump> default for an open non-publishing preview' -ForEach @(
            @{ DefaultBump = 'patch'; Flag = 'PatchRelease' }
            @{ DefaultBump = 'minor'; Flag = 'MinorRelease' }
            @{ DefaultBump = 'major'; Flag = 'MajorRelease' }
        ) {
            $configuration = Get-TestConfiguration -DefaultBump $DefaultBump -ReleaseType None
            $pullRequest = [pscustomobject]@{ HeadRef = 'feature'; Labels = @() }

            $decision = Resolve-ReleaseDecision -Configuration $configuration -PullRequest $pullRequest

            $decision.$Flag | Should -BeTrue
            $decision.HasVersionBump | Should -BeTrue
            $decision.ShouldPublish | Should -BeFalse
            $decision.BumpSource | Should -BeExactly 'Publish.Module.DefaultBump'
        }

        It 'validates conflicting bump labels even when an open PR does not publish' {
            $configuration = Get-TestConfiguration -ReleaseType None
            $pullRequest = [pscustomobject]@{ HeadRef = 'feature'; Labels = @('release:major', 'release:minor') }

            { Resolve-ReleaseDecision -Configuration $configuration -PullRequest $pullRequest } |
                Should -Throw '*Conflicting version labels*'
        }

        It 'stops bump resolution for a valid skip rather than producing a preview version' {
            $configuration = Get-TestConfiguration -DefaultBump major
            $pullRequest = [pscustomobject]@{ HeadRef = 'feature'; Labels = @('release:skip') }

            $decision = Resolve-ReleaseDecision -Configuration $configuration -PullRequest $pullRequest

            $decision.ShouldPublish | Should -BeFalse
            $decision.HasVersionBump | Should -BeFalse
            $decision.CreateRelease | Should -BeFalse
            $decision.CreatePrerelease | Should -BeFalse
            $decision.BumpSource | Should -BeExactly 'Label:release:skip'
        }

        It 'rejects skip combined with prerelease intent in <ReleaseType> mode' -ForEach @(
            @{ ReleaseType = 'Release' }
            @{ ReleaseType = 'Prerelease' }
            @{ ReleaseType = 'None' }
        ) {
            $configuration = Get-TestConfiguration -ReleaseType $ReleaseType
            $pullRequest = [pscustomobject]@{ HeadRef = 'feature'; Labels = @('release:skip', 'release:prerelease') }

            { Resolve-ReleaseDecision -Configuration $configuration -PullRequest $pullRequest } |
                Should -Throw '*ignore*prerelease*'
        }

        It 'uses custom prerelease and skip mappings for the same conflict validation' {
            $configuration = Get-TestConfiguration -IgnoreLabels @('custom:skip') -PrereleaseLabels @('custom:preview')
            $pullRequest = [pscustomobject]@{ HeadRef = 'feature'; Labels = @('custom:skip', 'custom:preview') }

            { Resolve-ReleaseDecision -Configuration $configuration -PullRequest $pullRequest } |
                Should -Throw '*ignore*prerelease*'
        }
    }
}
