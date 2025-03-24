@{
    Name    = 'PSModuleTest'
    Test    = @{
        SourceCode   = @{
            Skip = $true
        }
        PSModule     = @{
            Linux = @{
                Skip = $true
            }
        }
        Module       = @{
            Skip = $false
        }
        CodeCoverage = @{
            PercentTarget = 1
        }
    }
    Publish = @{
        AutoCleanup = $false
    }
}
