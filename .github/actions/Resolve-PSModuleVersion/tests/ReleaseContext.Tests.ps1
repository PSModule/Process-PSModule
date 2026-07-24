BeforeAll {
    function global:LogGroup {
        <#
            .SYNOPSIS
            Executes a test script block without GitHub Actions log grouping.
        #>
        param(
            [Parameter(Position = 0)]
            [string] $Name,

            [Parameter(Position = 1)]
            [scriptblock] $ScriptBlock
        )

        $null = $Name
        & $ScriptBlock
    }

    Import-Module "$PSScriptRoot/../src/Resolve-PSModuleVersion.Helpers.psm1" -Force
}

AfterAll {
    Remove-Item Function:/LogGroup -ErrorAction SilentlyContinue
}

Describe 'Get-GitHubPullRequest' {
    It 'reads push-derived pull request context from settings' {
        $settings = @{
            Context = @{
                IsPushToDefaultBranch = $true
                DefaultBranch         = 'main'
                PullRequest           = @{
                    Number  = 390
                    HeadRef = 'feature/push-release'
                    Labels  = @('minor', 'prerelease')
                }
            }
            Publish = @{ Module = @{ ReleaseType = 'Release' } }
        } | ConvertTo-Json -Depth 5

        $result = Get-GitHubPullRequest -SettingsJson $settings

        $result.Number | Should -Be 390
        $result.HeadRef | Should -Be 'feature/push-release'
        $result.Labels | Should -Be @('minor', 'prerelease')
    }

    It 'creates release context for an explicitly enabled direct push' {
        $settings = @{
            Context = @{
                IsPushToDefaultBranch = $true
                DefaultBranch         = 'main'
                PullRequest           = $null
            }
            Publish = @{ Module = @{ ReleaseType = 'Release' } }
        } | ConvertTo-Json -Depth 5

        $result = Get-GitHubPullRequest -SettingsJson $settings

        $result.Number | Should -BeNullOrEmpty
        $result.HeadRef | Should -Be 'main'
        $result.Labels | Should -BeNullOrEmpty
    }
}
