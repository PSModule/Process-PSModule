@{
    ReleaseDecision   = @(
        @{
            Name         = 'Merged PR with a patch label publishes a stable release'
            ReleaseType  = 'Release'
            AutoPatching = $false
            IsOpen       = $false
            HeadRef      = 'feat/test-patch'
            Labels       = @('patch')
            Expected     = @{
                ShouldPublish    = $true
                CreateRelease    = $true
                CreatePrerelease = $false
                MajorRelease     = $false
                MinorRelease     = $false
                PatchRelease     = $true
                HasVersionBump   = $true
                PrereleaseName   = 'feattestpatch'
            }
        }
        @{
            Name         = 'Merged PR with a minor label publishes a stable release'
            ReleaseType  = 'Release'
            AutoPatching = $false
            IsOpen       = $false
            HeadRef      = 'feat/test-minor'
            Labels       = @('minor')
            Expected     = @{
                ShouldPublish    = $true
                CreateRelease    = $true
                CreatePrerelease = $false
                MajorRelease     = $false
                MinorRelease     = $true
                PatchRelease     = $false
                HasVersionBump   = $true
                PrereleaseName   = 'feattestminor'
            }
        }
        @{
            Name         = 'Merged PR with a major label publishes a stable release'
            ReleaseType  = 'Release'
            AutoPatching = $false
            IsOpen       = $false
            HeadRef      = 'feat/test-major'
            Labels       = @('major')
            Expected     = @{
                ShouldPublish    = $true
                CreateRelease    = $true
                CreatePrerelease = $false
                MajorRelease     = $true
                MinorRelease     = $false
                PatchRelease     = $false
                HasVersionBump   = $true
                PrereleaseName   = 'feattestmajor'
            }
        }
        @{
            Name         = 'Merged PR with AutoPatching and no label publishes a stable release'
            ReleaseType  = 'Release'
            AutoPatching = $true
            IsOpen       = $false
            HeadRef      = 'feat/test-autopatch'
            Labels       = @()
            Expected     = @{
                ShouldPublish    = $true
                CreateRelease    = $true
                CreatePrerelease = $false
                MajorRelease     = $false
                MinorRelease     = $false
                PatchRelease     = $true
                HasVersionBump   = $true
                PrereleaseName   = 'feattestautopatch'
            }
        }
        @{
            Name         = 'Merged PR with an ignore label keeps the current version'
            ReleaseType  = 'Release'
            AutoPatching = $false
            IsOpen       = $false
            HeadRef      = 'feat/test-ignore'
            Labels       = @('patch', 'skip-release')
            Expected     = @{
                ShouldPublish    = $false
                CreateRelease    = $false
                CreatePrerelease = $false
                MajorRelease     = $false
                MinorRelease     = $false
                PatchRelease     = $false
                HasVersionBump   = $false
                PrereleaseName   = 'feattestignore'
            }
        }
        @{
            Name         = 'Merged PR with ReleaseType None keeps the current version'
            ReleaseType  = 'None'
            AutoPatching = $true
            IsOpen       = $false
            HeadRef      = 'auto-update-20260712'
            Labels       = @('patch')
            Expected     = @{
                ShouldPublish    = $false
                CreateRelease    = $false
                CreatePrerelease = $false
                MajorRelease     = $false
                MinorRelease     = $false
                PatchRelease     = $false
                HasVersionBump   = $false
                PrereleaseName   = 'autoupdate20260712'
            }
        }
        @{
            Name         = 'Open PR with ReleaseType None previews a patch prerelease'
            ReleaseType  = 'None'
            AutoPatching = $false
            IsOpen       = $true
            HeadRef      = 'feat/test-none'
            Labels       = @('patch')
            Expected     = @{
                ShouldPublish    = $false
                CreateRelease    = $false
                CreatePrerelease = $true
                MajorRelease     = $false
                MinorRelease     = $false
                PatchRelease     = $true
                HasVersionBump   = $true
                PrereleaseName   = 'feattestnone'
            }
        }
        @{
            Name         = 'Open PR with ReleaseType None previews a minor prerelease'
            ReleaseType  = 'None'
            AutoPatching = $false
            IsOpen       = $true
            HeadRef      = 'feat/none-minor'
            Labels       = @('minor')
            Expected     = @{
                ShouldPublish    = $false
                CreateRelease    = $false
                CreatePrerelease = $true
                MajorRelease     = $false
                MinorRelease     = $true
                PatchRelease     = $false
                HasVersionBump   = $true
                PrereleaseName   = 'featnoneminor'
            }
        }
        @{
            Name         = 'Open PR with ReleaseType None previews a major prerelease'
            ReleaseType  = 'None'
            AutoPatching = $false
            IsOpen       = $true
            HeadRef      = 'feat/none-major'
            Labels       = @('major')
            Expected     = @{
                ShouldPublish    = $false
                CreateRelease    = $false
                CreatePrerelease = $true
                MajorRelease     = $true
                MinorRelease     = $false
                PatchRelease     = $false
                HasVersionBump   = $true
                PrereleaseName   = 'featnonemajor'
            }
        }
        @{
            Name         = 'Open PR with ReleaseType Prerelease publishes a prerelease'
            ReleaseType  = 'Prerelease'
            AutoPatching = $false
            IsOpen       = $true
            HeadRef      = 'feat/add-prerelease-support'
            Labels       = @('minor')
            Expected     = @{
                ShouldPublish    = $true
                CreateRelease    = $false
                CreatePrerelease = $true
                MajorRelease     = $false
                MinorRelease     = $true
                PatchRelease     = $false
                HasVersionBump   = $true
                PrereleaseName   = 'feataddprereleasesupport'
            }
        }
        @{
            Name         = 'Open PR with an ignore label still previews a prerelease'
            ReleaseType  = 'None'
            AutoPatching = $false
            IsOpen       = $true
            HeadRef      = 'feat/preview-with-ignore'
            Labels       = @('patch', 'skip-release')
            Expected     = @{
                ShouldPublish    = $false
                CreateRelease    = $false
                CreatePrerelease = $true
                MajorRelease     = $false
                MinorRelease     = $false
                PatchRelease     = $true
                HasVersionBump   = $true
                PrereleaseName   = 'featpreviewwithignore'
            }
        }
        @{
            Name         = 'Merged PR with no bump label and no AutoPatching keeps the current version'
            ReleaseType  = 'Release'
            AutoPatching = $false
            IsOpen       = $false
            HeadRef      = 'feat/no-label'
            Labels       = @()
            Expected     = @{
                ShouldPublish    = $false
                CreateRelease    = $false
                CreatePrerelease = $false
                MajorRelease     = $false
                MinorRelease     = $false
                PatchRelease     = $false
                HasVersionBump   = $false
                PrereleaseName   = 'featnolabel'
            }
        }
    )

    NextModuleVersion = @(
        @{
            Name                  = 'Patch bump - Release'
            LatestVersion         = '1.0.1'
            VersionPrefix         = 'v'
            IncrementalPrerelease = $false
            DatePrereleaseFormat  = ''
            ExpectedVersion       = '1.0.2'
            ExpectedPrerelease    = ''
            ExpectedPrefix        = 'v'
            Decision              = @{
                ShouldPublish    = $true
                CreateRelease    = $true
                CreatePrerelease = $false
                MajorRelease     = $false
                MinorRelease     = $false
                PatchRelease     = $true
                HasVersionBump   = $true
                PrereleaseName   = 'feattestpatch'
            }
        }
        @{
            Name                  = 'Minor bump - Release'
            LatestVersion         = '1.0.1'
            VersionPrefix         = 'v'
            IncrementalPrerelease = $false
            DatePrereleaseFormat  = ''
            ExpectedVersion       = '1.1.0'
            ExpectedPrerelease    = ''
            ExpectedPrefix        = 'v'
            Decision              = @{
                ShouldPublish    = $true
                CreateRelease    = $true
                CreatePrerelease = $false
                MajorRelease     = $false
                MinorRelease     = $true
                PatchRelease     = $false
                HasVersionBump   = $true
                PrereleaseName   = 'feattestminor'
            }
        }
        @{
            Name                  = 'Major bump - Release'
            LatestVersion         = '1.2.3'
            VersionPrefix         = 'v'
            IncrementalPrerelease = $false
            DatePrereleaseFormat  = ''
            ExpectedVersion       = '2.0.0'
            ExpectedPrerelease    = ''
            ExpectedPrefix        = 'v'
            Decision              = @{
                ShouldPublish    = $true
                CreateRelease    = $true
                CreatePrerelease = $false
                MajorRelease     = $true
                MinorRelease     = $false
                PatchRelease     = $false
                HasVersionBump   = $true
                PrereleaseName   = 'feattestmajor'
            }
        }
        @{
            Name                  = 'ReleaseType None - prerelease with incremental counter'
            LatestVersion         = '1.0.1'
            VersionPrefix         = 'v'
            IncrementalPrerelease = $false
            DatePrereleaseFormat  = ''
            ExpectedVersion       = '1.0.2'
            ExpectedPrerelease    = 'feattestnone001'
            ExpectedPrefix        = 'v'
            Decision              = @{
                ShouldPublish    = $false
                CreateRelease    = $false
                CreatePrerelease = $true
                MajorRelease     = $false
                MinorRelease     = $false
                PatchRelease     = $true
                HasVersionBump   = $true
                PrereleaseName   = 'feattestnone'
            }
        }
        @{
            Name                  = 'Prerelease type with IncrementalPrerelease'
            LatestVersion         = '1.0.1'
            VersionPrefix         = 'v'
            IncrementalPrerelease = $true
            DatePrereleaseFormat  = ''
            ExpectedVersion       = '1.1.0'
            ExpectedPrerelease    = 'feataddprereleasesupport001'
            ExpectedPrefix        = 'v'
            Decision              = @{
                ShouldPublish    = $true
                CreateRelease    = $false
                CreatePrerelease = $true
                MajorRelease     = $false
                MinorRelease     = $true
                PatchRelease     = $false
                HasVersionBump   = $true
                PrereleaseName   = 'feataddprereleasesupport'
            }
        }
        @{
            Name                  = 'Ignore label falls back to prerelease with counter'
            LatestVersion         = '1.0.1'
            VersionPrefix         = 'v'
            IncrementalPrerelease = $false
            DatePrereleaseFormat  = ''
            ExpectedVersion       = '1.0.2'
            ExpectedPrerelease    = 'feattestignore001'
            ExpectedPrefix        = 'v'
            Decision              = @{
                ShouldPublish    = $false
                CreateRelease    = $true
                CreatePrerelease = $true
                MajorRelease     = $false
                MinorRelease     = $false
                PatchRelease     = $true
                HasVersionBump   = $true
                PrereleaseName   = 'feattestignore'
            }
        }
        @{
            Name                  = 'No version prefix'
            LatestVersion         = '2.0.0'
            VersionPrefix         = ''
            IncrementalPrerelease = $false
            DatePrereleaseFormat  = ''
            ExpectedVersion       = '2.0.1'
            ExpectedPrerelease    = ''
            ExpectedPrefix        = ''
            Decision              = @{
                ShouldPublish    = $true
                CreateRelease    = $true
                CreatePrerelease = $false
                MajorRelease     = $false
                MinorRelease     = $false
                PatchRelease     = $true
                HasVersionBump   = $true
                PrereleaseName   = 'main'
            }
        }
        @{
            Name                  = 'AutoPatch - Release with no label'
            LatestVersion         = '1.0.1'
            VersionPrefix         = 'v'
            IncrementalPrerelease = $false
            DatePrereleaseFormat  = ''
            ExpectedVersion       = '1.0.2'
            ExpectedPrerelease    = ''
            ExpectedPrefix        = 'v'
            Decision              = @{
                ShouldPublish    = $true
                CreateRelease    = $true
                CreatePrerelease = $false
                MajorRelease     = $false
                MinorRelease     = $false
                PatchRelease     = $true
                HasVersionBump   = $true
                PrereleaseName   = 'feattestautopatch'
            }
        }
        @{
            Name                  = 'Prerelease without IncrementalPrerelease but ShouldPublish true'
            LatestVersion         = '1.0.0'
            VersionPrefix         = 'v'
            IncrementalPrerelease = $false
            DatePrereleaseFormat  = ''
            ExpectedVersion       = '1.0.1'
            ExpectedPrerelease    = 'dev'
            ExpectedPrefix        = 'v'
            Decision              = @{
                ShouldPublish    = $true
                CreateRelease    = $false
                CreatePrerelease = $true
                MajorRelease     = $false
                MinorRelease     = $false
                PatchRelease     = $true
                HasVersionBump   = $true
                PrereleaseName   = 'dev'
            }
        }
    )

    EndToEnd          = @(
        @{
            Name                  = 'Merged PR patch bump produces stable release version'
            LatestVersion         = '1.0.1'
            ReleaseType           = 'Release'
            AutoPatching          = $false
            IsOpen                = $false
            IncrementalPrerelease = $false
            VersionPrefix         = 'v'
            HeadRef               = 'feat/test-patch'
            Labels                = @('patch')
            ExpectedShouldPublish = $true
            ExpectedReleaseType   = 'Release'
            ExpectedVersion       = '1.0.2'
            ExpectedPrerelease    = ''
            ExpectedFullVersion   = 'v1.0.2'
        }
        @{
            Name                  = 'Merged PR minor bump produces stable release version'
            LatestVersion         = '1.0.1'
            ReleaseType           = 'Release'
            AutoPatching          = $false
            IsOpen                = $false
            IncrementalPrerelease = $false
            VersionPrefix         = 'v'
            HeadRef               = 'feat/test-minor'
            Labels                = @('minor')
            ExpectedShouldPublish = $true
            ExpectedReleaseType   = 'Release'
            ExpectedVersion       = '1.1.0'
            ExpectedPrerelease    = ''
            ExpectedFullVersion   = 'v1.1.0'
        }
        @{
            Name                  = 'Merged PR major bump produces stable release version'
            LatestVersion         = '1.0.1'
            ReleaseType           = 'Release'
            AutoPatching          = $false
            IsOpen                = $false
            IncrementalPrerelease = $false
            VersionPrefix         = 'v'
            HeadRef               = 'feat/test-major'
            Labels                = @('major')
            ExpectedShouldPublish = $true
            ExpectedReleaseType   = 'Release'
            ExpectedVersion       = '2.0.0'
            ExpectedPrerelease    = ''
            ExpectedFullVersion   = 'v2.0.0'
        }
        @{
            Name                  = 'Merged PR auto-patch with no label produces stable release version'
            LatestVersion         = '1.0.1'
            ReleaseType           = 'Release'
            AutoPatching          = $true
            IsOpen                = $false
            IncrementalPrerelease = $false
            VersionPrefix         = 'v'
            HeadRef               = 'feat/test-autopatch'
            Labels                = @()
            ExpectedShouldPublish = $true
            ExpectedReleaseType   = 'Release'
            ExpectedVersion       = '1.0.2'
            ExpectedPrerelease    = ''
            ExpectedFullVersion   = 'v1.0.2'
        }
        @{
            Name                  = 'Merged PR with an ignore label keeps the current version'
            LatestVersion         = '1.0.1'
            ReleaseType           = 'Release'
            AutoPatching          = $false
            IsOpen                = $false
            IncrementalPrerelease = $false
            VersionPrefix         = 'v'
            HeadRef               = 'feat/test-ignore'
            Labels                = @('patch', 'skip-release')
            ExpectedShouldPublish = $false
            ExpectedReleaseType   = 'None'
            ExpectedVersion       = '1.0.1'
            ExpectedPrerelease    = ''
            ExpectedFullVersion   = 'v1.0.1'
        }
        @{
            Name                  = 'Merged PR with ReleaseType None keeps the current version'
            LatestVersion         = '1.0.1'
            ReleaseType           = 'None'
            AutoPatching          = $true
            IsOpen                = $false
            IncrementalPrerelease = $false
            VersionPrefix         = 'v'
            HeadRef               = 'auto-update-20260712'
            Labels                = @('patch')
            ExpectedShouldPublish = $false
            ExpectedReleaseType   = 'None'
            ExpectedVersion       = '1.0.1'
            ExpectedPrerelease    = ''
            ExpectedFullVersion   = 'v1.0.1'
        }
        @{
            Name                  = 'Open PR with ReleaseType None previews a patch prerelease'
            LatestVersion         = '1.0.1'
            ReleaseType           = 'None'
            AutoPatching          = $false
            IsOpen                = $true
            IncrementalPrerelease = $false
            VersionPrefix         = 'v'
            HeadRef               = 'feat/test-none'
            Labels                = @('patch')
            ExpectedShouldPublish = $false
            ExpectedReleaseType   = 'None'
            ExpectedVersion       = '1.0.2'
            ExpectedPrerelease    = 'feattestnone001'
            ExpectedFullVersion   = 'v1.0.2-feattestnone001'
        }
        @{
            Name                  = 'Open PR with ReleaseType None previews a minor prerelease'
            LatestVersion         = '1.0.1'
            ReleaseType           = 'None'
            AutoPatching          = $false
            IsOpen                = $true
            IncrementalPrerelease = $false
            VersionPrefix         = 'v'
            HeadRef               = 'feat/none-minor'
            Labels                = @('minor')
            ExpectedShouldPublish = $false
            ExpectedReleaseType   = 'None'
            ExpectedVersion       = '1.1.0'
            ExpectedPrerelease    = 'featnoneminor001'
            ExpectedFullVersion   = 'v1.1.0-featnoneminor001'
        }
        @{
            Name                  = 'Open PR with ReleaseType None previews a major prerelease'
            LatestVersion         = '1.0.1'
            ReleaseType           = 'None'
            AutoPatching          = $false
            IsOpen                = $true
            IncrementalPrerelease = $false
            VersionPrefix         = 'v'
            HeadRef               = 'feat/none-major'
            Labels                = @('major')
            ExpectedShouldPublish = $false
            ExpectedReleaseType   = 'None'
            ExpectedVersion       = '2.0.0'
            ExpectedPrerelease    = 'featnonemajor001'
            ExpectedFullVersion   = 'v2.0.0-featnonemajor001'
        }
        @{
            Name                  = 'Open PR with ReleaseType Prerelease publishes a prerelease'
            LatestVersion         = '1.0.1'
            ReleaseType           = 'Prerelease'
            AutoPatching          = $false
            IsOpen                = $true
            IncrementalPrerelease = $true
            VersionPrefix         = 'v'
            HeadRef               = 'feat/add-prerelease-support'
            Labels                = @('minor')
            ExpectedShouldPublish = $true
            ExpectedReleaseType   = 'Prerelease'
            ExpectedVersion       = '1.1.0'
            ExpectedPrerelease    = 'feataddprereleasesupport001'
            ExpectedFullVersion   = 'v1.1.0-feataddprereleasesupport001'
        }
        @{
            Name                  = 'Open PR with an ignore label still previews a prerelease'
            LatestVersion         = '1.0.1'
            ReleaseType           = 'None'
            AutoPatching          = $false
            IsOpen                = $true
            IncrementalPrerelease = $false
            VersionPrefix         = 'v'
            HeadRef               = 'feat/preview-with-ignore'
            Labels                = @('patch', 'skip-release')
            ExpectedShouldPublish = $false
            ExpectedReleaseType   = 'None'
            ExpectedVersion       = '1.0.2'
            ExpectedPrerelease    = 'featpreviewwithignore001'
            ExpectedFullVersion   = 'v1.0.2-featpreviewwithignore001'
        }
        @{
            Name                  = 'Merged PR with no bump and no AutoPatching keeps the current version'
            LatestVersion         = '1.0.1'
            ReleaseType           = 'Release'
            AutoPatching          = $false
            IsOpen                = $false
            IncrementalPrerelease = $false
            VersionPrefix         = 'v'
            HeadRef               = 'feat/no-label'
            Labels                = @()
            ExpectedShouldPublish = $false
            ExpectedReleaseType   = 'None'
            ExpectedVersion       = '1.0.1'
            ExpectedPrerelease    = ''
            ExpectedFullVersion   = 'v1.0.1'
        }
    )
}
