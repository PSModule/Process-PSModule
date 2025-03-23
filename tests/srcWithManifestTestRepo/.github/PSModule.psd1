@{
    Name                      = 'PSModuleTest'
    CodeCoveragePercentTarget = 1
    Build                     = @{}
    Test                      = @{
        SourceCode = @{
            Skip = $true
        }
        PSModule   = @{
            Skip = $true
        }
    }
    Publishing                = @{
        AutoCleanup = $false
    }
}
