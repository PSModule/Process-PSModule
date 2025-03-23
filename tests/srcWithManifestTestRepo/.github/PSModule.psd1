@{
    Name                      = 'PSModuleTest'
    CodeCoveragePercentTarget = 20
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
