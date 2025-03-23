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
        SourceCode = @{
            Skip = $true
        }
        Module     = @{
            PSModule = @{
                Skip = $true
            }
            Module   = @{
                Skip = $true
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
