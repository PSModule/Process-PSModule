BeforeAll {
    Import-Module "$PSScriptRoot/../src/Get-PSModuleSettings.Helpers.psm1" -Force
}

Describe 'Resolve-WorkflowEventRouting' {
    It 'routes an associated push to the default branch to a stable release' {
        $result = Resolve-WorkflowEventRouting -EventName push `
            -IsTargetDefaultBranch $true `
            -IsPushToDefaultBranch $true `
            -HasPullRequestContext $true `
            -HasImportantChanges $true

        $result.ReleaseType | Should -Be 'Release'
        $result.ShouldRunBuildTest | Should -BeTrue
        $result.ShouldCleanupEvent | Should -BeTrue
    }

    It 'does not publish an unassociated direct push by default' {
        $result = Resolve-WorkflowEventRouting -EventName push `
            -IsTargetDefaultBranch $true `
            -IsPushToDefaultBranch $true `
            -HasImportantChanges $true

        $result.ReleaseType | Should -Be 'None'
    }

    It 'allows an explicitly enabled direct push release' {
        $result = Resolve-WorkflowEventRouting -EventName push `
            -IsTargetDefaultBranch $true `
            -IsPushToDefaultBranch $true `
            -HasImportantChanges $true `
            -AllowDirectPushRelease $true

        $result.ReleaseType | Should -Be 'Release'
    }

    It 'routes a labeled open PR with important changes to a prerelease' {
        $result = Resolve-WorkflowEventRouting -EventName pull_request `
            -EventAction labeled `
            -IsTargetDefaultBranch $true `
            -HasPullRequestContext $true `
            -HasImportantChanges $true `
            -HasPrereleaseLabel $true

        $result.ReleaseType | Should -Be 'Prerelease'
        $result.ShouldRunBuildTest | Should -BeTrue
    }

    It 'routes an abandoned PR to cleanup only' {
        $result = Resolve-WorkflowEventRouting -EventName pull_request `
            -EventAction closed `
            -IsTargetDefaultBranch $true `
            -HasPullRequestContext $true `
            -HasImportantChanges $true

        $result.ReleaseType | Should -Be 'None'
        $result.IsAbandonedPR | Should -BeTrue
        $result.ShouldRunBuildTest | Should -BeFalse
        $result.ShouldCleanupEvent | Should -BeTrue
    }

    It 'routes a merged PR event to cleanup only' {
        $result = Resolve-WorkflowEventRouting -EventName pull_request `
            -EventAction closed `
            -PullRequestIsMerged $true `
            -IsTargetDefaultBranch $true `
            -HasPullRequestContext $true `
            -HasImportantChanges $true

        $result.ReleaseType | Should -Be 'None'
        $result.IsMergedPR | Should -BeTrue
        $result.ShouldRunBuildTest | Should -BeFalse
        $result.ShouldCleanupEvent | Should -BeTrue
    }
}

Describe 'Select-PullRequestForPush' {
    It 'selects the merged PR whose merge commit matches the push SHA' {
        $pullRequests = @(
            [pscustomobject]@{
                Number           = 411
                Base             = [pscustomobject]@{ Ref = 'main' }
                merged_at        = $null
                merge_commit_sha = 'open-pr-sha'
            },
            [pscustomobject]@{
                Number           = 390
                Base             = [pscustomobject]@{ Ref = 'main' }
                merged_at        = '2026-07-24T00:00:00Z'
                merge_commit_sha = 'pushed-sha'
            }
        )

        $result = Select-PullRequestForPush -PullRequest $pullRequests -DefaultBranch main -CommitSha pushed-sha

        $result.Number | Should -Be 390
    }

    It 'does not use an open PR association as stable release context' {
        $pullRequests = @(
            [pscustomobject]@{
                Number           = 411
                Base             = [pscustomobject]@{ Ref = 'main' }
                merged_at        = $null
                merge_commit_sha = 'pushed-sha'
            }
        )

        $result = Select-PullRequestForPush -PullRequest $pullRequests -DefaultBranch main -CommitSha pushed-sha

        $result | Should -BeNullOrEmpty
    }
}
