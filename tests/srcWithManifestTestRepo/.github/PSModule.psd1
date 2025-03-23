@{
    Name       = 'PSModuleTest'
    Build      = @{
        Skip   = $true
        Module = @{
            Skip = $true
        }
        Docs   = @{
            Skip = $true
        }
    }
    Test       = @{
        Skip       = $true
        Linux      = @{
            Skip = $true
        }
        Windows    = @{
            Skip = $true
        }
        macOS      = @{
            Skip = $true
        }
        SourceCode = @{
            Skip    = $true
            Linux   = @{
                Skip = $true
            }
            Windows = @{
                Skip = $true
            }
            macOS   = @{
                Skip = $true
            }
        }
        Module     = @{
            PSModule = @{
                Skip    = $true
                Linux   = @{
                    Skip = $true
                }
                Windows = @{
                    Skip = $true
                }
                macOS   = @{
                    Skip = $true
                }
            }
            Module   = @{
                Skip    = $true
                Linux   = @{
                    Skip = $true
                }
                Windows = @{
                    Skip = $true
                }
                macOS   = @{
                    Skip = $true
                }
            }
        }
    }
    Publishing = @{
        AutoCleanup           = 'true'
        AutoPatching          = 'true'
        DatePrereleaseFormat  = ''
        IgnoreLabels          = 'NoRelease'
        IncrementalPrerelease = 'true'
        MajorLabels           = 'major', 'breaking'
        MinorLabels           = 'minor', 'feature'
        PatchLabels           = 'patch', 'fix'
        VersionPrefix         = 'v'
    }
}
