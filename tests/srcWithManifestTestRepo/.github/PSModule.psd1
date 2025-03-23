@{
    Name       = 'PSModuleTest'
    Build      = @{}
    Test       = @{
        SourceCode = @{
            Skip = $true
        }
        PSModule   = @{
            Skip = $true
        }
    }
    Publishing = @{
        AutoCleanup = $false
    }
}
