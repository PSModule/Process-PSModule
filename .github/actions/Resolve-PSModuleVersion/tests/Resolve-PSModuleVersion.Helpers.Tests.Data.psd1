@{
    ReleaseDecision   = @(
        @{
            Name         = 'Patch label with Release type'
            ReleaseType  = 'Release'
            AutoPatching = $false
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
            Name         = 'Minor label with Release type'
            ReleaseType  = 'Release'
            AutoPatching = $false
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
            Name         = 'Major label with Release type'
            ReleaseType  = 'Release'
            AutoPatching = $false
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
            Name         = 'AutoPatching with no label'
            ReleaseType  = 'Release'
            AutoPatching = $true
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
            Name         = 'Ignore label suppresses release'
            ReleaseType  = 'Release'
            AutoPatching = $false
            HeadRef      = 'feat/test-ignore'
            Labels       = @('patch', 'skip-release')
            Expected     = @{
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
            Name         = 'ReleaseType None produces prerelease'
            ReleaseType  = 'None'
            AutoPatching = $false
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
            Name         = 'ReleaseType None with a minor label previews a minor bump'
            ReleaseType  = 'None'
            AutoPatching = $false
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
            Name         = 'ReleaseType None with a major label previews a major bump'
            ReleaseType  = 'None'
            AutoPatching = $false
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
            Name         = 'ReleaseType Prerelease with minor label'
            ReleaseType  = 'Prerelease'
            AutoPatching = $false
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
            Name         = 'No bump label and no AutoPatching falls back to prerelease'
            ReleaseType  = 'Release'
            AutoPatching = $false
            HeadRef      = 'feat/no-label'
            Labels       = @()
            Expected     = @{
                ShouldPublish    = $false
                CreateRelease    = $true
                CreatePrerelease = $true
                MajorRelease     = $false
                MinorRelease     = $false
                PatchRelease     = $true
                HasVersionBump   = $true
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
            Name                  = 'Patch bump produces release version'
            LatestVersion         = '1.0.1'
            ReleaseType           = 'Release'
            AutoPatching          = $false
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
            Name                  = 'Minor bump produces release version'
            LatestVersion         = '1.0.1'
            ReleaseType           = 'Release'
            AutoPatching          = $false
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
            Name                  = 'Major bump produces release version'
            LatestVersion         = '1.0.1'
            ReleaseType           = 'Release'
            AutoPatching          = $false
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
            Name                  = 'Auto-patch with no label produces release version'
            LatestVersion         = '1.0.1'
            ReleaseType           = 'Release'
            AutoPatching          = $true
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
            Name                  = 'Ignore label suppresses release, produces prerelease'
            LatestVersion         = '1.0.1'
            ReleaseType           = 'Release'
            AutoPatching          = $false
            IncrementalPrerelease = $false
            VersionPrefix         = 'v'
            HeadRef               = 'feat/test-ignore'
            Labels                = @('patch', 'skip-release')
            ExpectedShouldPublish = $false
            ExpectedReleaseType   = 'None'
            ExpectedVersion       = '1.0.2'
            ExpectedPrerelease    = 'feattestignore001'
            ExpectedFullVersion   = 'v1.0.2-feattestignore001'
        }
        @{
            Name                  = 'ReleaseType None produces prerelease with counter'
            LatestVersion         = '1.0.1'
            ReleaseType           = 'None'
            AutoPatching          = $false
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
            Name                  = 'ReleaseType None with a minor label previews a minor prerelease'
            LatestVersion         = '1.0.1'
            ReleaseType           = 'None'
            AutoPatching          = $false
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
            Name                  = 'ReleaseType None with a major label previews a major prerelease'
            LatestVersion         = '1.0.1'
            ReleaseType           = 'None'
            AutoPatching          = $false
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
            Name                  = 'Prerelease type with incremental counter'
            LatestVersion         = '1.0.1'
            ReleaseType           = 'Prerelease'
            AutoPatching          = $false
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
            Name                  = 'No label and no AutoPatching falls back to prerelease'
            LatestVersion         = '1.0.1'
            ReleaseType           = 'Release'
            AutoPatching          = $false
            IncrementalPrerelease = $false
            VersionPrefix         = 'v'
            HeadRef               = 'feat/no-label'
            Labels                = @()
            ExpectedShouldPublish = $false
            ExpectedReleaseType   = 'None'
            ExpectedVersion       = '1.0.2'
            ExpectedPrerelease    = 'featnolabel001'
            ExpectedFullVersion   = 'v1.0.2-featnolabel001'
        }
    )
}
