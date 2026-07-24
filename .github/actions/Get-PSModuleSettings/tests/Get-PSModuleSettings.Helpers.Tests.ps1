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
