[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Variables are assigned in BeforeAll and used inside It blocks.'
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
            # Whether an unlabeled pull request is treated as a patch.
            [Parameter()]
            [bool] $AutoPatching = $true,

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
            [string[]] $PatchLabels = @('release:patch')
        )

        [PSCustomObject]@{
            AutoPatching          = $AutoPatching
            IncrementalPrerelease = $IncrementalPrerelease
            DatePrereleaseFormat  = $DatePrereleaseFormat
            VersionPrefix         = $VersionPrefix
            ReleaseType           = $ReleaseType
            IgnoreLabels          = $IgnoreLabels
            MajorLabels           = $MajorLabels
            MinorLabels           = $MinorLabels
            PatchLabels           = $PatchLabels
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
                    Configuration = Get-TestConfiguration -ReleaseType 'Prerelease'
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

        It 'creates default patch context for a direct default-branch push' {
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
    }

    Describe 'Resolve-ReleaseDecision' {
        It 'uses the default patch bump for a direct stable release' {
            $result = Resolve-ReleaseDecision -Configuration (Get-TestConfiguration -AutoPatching $false) `
                -PullRequest ([pscustomobject]@{ HeadRef = 'main'; Labels = @(); IsDirectRelease = $true })

            $result.ShouldPublish | Should -BeTrue
            $result.PatchRelease | Should -BeTrue
        }

        It 'does not publish an unlabeled prerelease when AutoPatching is disabled' {
            $result = Resolve-ReleaseDecision -Configuration (Get-TestConfiguration -AutoPatching $false -ReleaseType Prerelease) `
                -PullRequest ([pscustomobject]@{ HeadRef = 'feature'; Labels = @() })

            $result.ShouldPublish | Should -BeFalse
            $result.PatchRelease | Should -BeTrue
        }

        It 'does not validate cleanup-only pull request labels' {
            $result = Resolve-ReleaseDecision -Configuration (Get-TestConfiguration -ReleaseType None) `
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

        It 'honors the canonical <Bump> default' -ForEach @(
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

        It 'honors a configured ignore label' {
            $configuration = Get-TestConfiguration -IgnoreLabels @('custom:skip')
            $pullRequest = [pscustomobject]@{
                HeadRef = 'main'
                Labels  = @('custom:skip')
            }

            $result = Resolve-ReleaseDecision -Configuration $configuration -PullRequest $pullRequest

            $result.ShouldPublish | Should -BeFalse
        }
    }
}
