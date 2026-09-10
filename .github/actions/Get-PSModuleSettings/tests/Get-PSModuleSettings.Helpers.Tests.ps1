BeforeAll {
    Import-Module "$PSScriptRoot/../src/Get-PSModuleSettings.Helpers.psm1" -Force
}

Describe 'Resolve-WorkflowEventRouting' {
    It 'routes an associated push to the default branch to a stable release' {
        $result = Resolve-WorkflowEventRouting -EventName push `
            -IsTargetDefaultBranch $true `
            -IsPushToDefaultBranch $true `
            -HasImportantChanges $true

        $result.ReleaseType | Should -Be 'Release'
        $result.ShouldRunBuildTest | Should -BeTrue
        $result.ShouldCleanupEvent | Should -BeFalse
        $result.ShouldRunCleanup | Should -BeTrue
    }

    It 'routes a direct push to the default branch to a stable release' {
        $result = Resolve-WorkflowEventRouting -EventName push `
            -IsTargetDefaultBranch $true `
            -IsPushToDefaultBranch $true `
            -HasImportantChanges $true

        $result.ReleaseType | Should -Be 'Release'
    }

    It 'does not publish a documentation-only default-branch push' {
        $result = Resolve-WorkflowEventRouting -EventName push `
            -IsTargetDefaultBranch $true `
            -IsPushToDefaultBranch $true `
            -HasImportantChanges $false

        $result.ReleaseType | Should -Be 'None'
    }

    It 'routes a default-branch manual dispatch to a stable release' {
        $result = Resolve-WorkflowEventRouting -EventName workflow_dispatch `
            -IsTargetDefaultBranch $true `
            -IsManualDispatchToDefaultBranch $true `
            -HasImportantChanges $true

        $result.ReleaseType | Should -Be 'Release'
    }

    It 'routes a labeled open PR with important changes to a prerelease' {
        $result = Resolve-WorkflowEventRouting -EventName pull_request `
            -EventAction labeled `
            -IsTargetDefaultBranch $true `
            -HasImportantChanges $true `
            -HasPrereleaseLabel $true

        $result.ReleaseType | Should -Be 'Prerelease'
        $result.ShouldRunBuildTest | Should -BeTrue
    }

    It 'routes a closed PR to cleanup only' {
        $result = Resolve-WorkflowEventRouting -EventName pull_request `
            -EventAction closed `
            -PullRequestIsMerged $true `
            -IsTargetDefaultBranch $true `
            -HasImportantChanges $true

        $result.ReleaseType | Should -Be 'None'
        $result.ShouldRunBuildTest | Should -BeFalse
        $result.ShouldCleanupEvent | Should -BeTrue
        $result.ShouldRunCleanup | Should -BeTrue
    }

    It 'does not run a label event for a closed PR' {
        $result = Resolve-WorkflowEventRouting -EventName pull_request `
            -EventAction labeled `
            -PullRequestIsClosed $true `
            -IsTargetDefaultBranch $true `
            -HasImportantChanges $true `
            -HasPrereleaseLabel $true

        $result.ReleaseType | Should -Be 'None'
        $result.IsOpenOrUpdatedPR | Should -BeFalse
        $result.ShouldRunBuildTest | Should -BeFalse
        $result.ShouldCleanupEvent | Should -BeFalse
        $result.ShouldRunCleanup | Should -BeFalse
    }
}

Describe 'Select-PullRequestForPush' {
    It 'selects the merged PR whose merge commit matches the pushed commit' {
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
                merged_at        = '2026-08-15T00:00:00Z'
                merge_commit_sha = 'pushed-sha'
            }
        )

        $result = Select-PullRequestForPush -PullRequest $pullRequests -DefaultBranch main -CommitSha pushed-sha

        $result.Number | Should -Be 390
    }

    It 'rejects an open or mismatched PR association' {
        $pullRequests = @(
            [pscustomobject]@{
                Number           = 411
                Base             = [pscustomobject]@{ Ref = 'main' }
                merged_at        = $null
                merge_commit_sha = 'pushed-sha'
            },
            [pscustomobject]@{
                Number           = 390
                Base             = [pscustomobject]@{ Ref = 'main' }
                merged_at        = '2026-08-15T00:00:00Z'
                merge_commit_sha = 'different-sha'
            }
        )

        $result = Select-PullRequestForPush -PullRequest $pullRequests -DefaultBranch main -CommitSha pushed-sha

        $result | Should -BeNullOrEmpty
    }
}

Describe 'Resolve-ReleasePullRequest' {
    BeforeAll {
        $script:mergedPullRequest = [pscustomobject]@{
            Number           = 64
            Base             = [pscustomobject]@{ Ref = 'main' }
            merged_at        = '2026-09-02T09:02:24Z'
            merge_commit_sha = 'released-sha'
            Labels           = @([pscustomobject]@{ Name = 'minor' })
        }
    }

    It 'resolves the merged pull request for a push to the default branch' {
        $result = Resolve-ReleasePullRequest -EventName push `
            -CommitSha 'released-sha' `
            -DefaultBranch main `
            -IsPushToDefaultBranch $true `
            -GetAssociatedPullRequest { @($script:mergedPullRequest) }

        $result.Resolved | Should -BeTrue
        $result.PullRequest.Number | Should -Be 64
    }

    It 'resolves the merged pull request for a manual dispatch on the default branch' {
        # Regression guard for issue #530. Association was gated on the push event, so a recovery
        # dispatch resolved no pull request, discarded the merged pull request's version label, and
        # silently released a patch bump instead of the labeled minor bump.
        $result = Resolve-ReleasePullRequest -EventName workflow_dispatch `
            -CommitSha 'released-sha' `
            -DefaultBranch main `
            -IsManualDispatchToDefaultBranch $true `
            -GetAssociatedPullRequest { @($script:mergedPullRequest) }

        $result.Resolved | Should -BeTrue
        $result.PullRequest.Number | Should -Be 64
        @($result.PullRequest.Labels.Name) | Should -Be @('minor')
    }

    It 'does not look up a pull request for a manual dispatch outside the default branch' {
        $lookups = @{ Count = 0 }
        $result = Resolve-ReleasePullRequest -EventName workflow_dispatch `
            -CommitSha 'released-sha' `
            -DefaultBranch main `
            -IsManualDispatchToDefaultBranch $false `
            -GetAssociatedPullRequest ({ $lookups.Count++; @() }.GetNewClosure())

        $result.Resolved | Should -BeFalse
        $result.PullRequest | Should -BeNullOrEmpty
        $lookups.Count | Should -Be 0
    }

    It 'does not look up a pull request for a scheduled run' {
        $lookups = @{ Count = 0 }
        $result = Resolve-ReleasePullRequest -EventName schedule `
            -CommitSha 'released-sha' `
            -DefaultBranch main `
            -GetAssociatedPullRequest ({ $lookups.Count++; @() }.GetNewClosure())

        $result.Resolved | Should -BeFalse
        $lookups.Count | Should -Be 0
    }

    It 'does not look up a pull request without a commit' {
        $lookups = @{ Count = 0 }
        $result = Resolve-ReleasePullRequest -EventName workflow_dispatch `
            -CommitSha '' `
            -DefaultBranch main `
            -IsManualDispatchToDefaultBranch $true `
            -GetAssociatedPullRequest ({ $lookups.Count++; @() }.GetNewClosure())

        $result.Resolved | Should -BeFalse
        $lookups.Count | Should -Be 0
    }

    It 'releases a directly pushed commit that has no associated pull request' {
        $result = Resolve-ReleasePullRequest -EventName workflow_dispatch `
            -CommitSha 'direct-push-sha' `
            -DefaultBranch main `
            -IsManualDispatchToDefaultBranch $true `
            -GetAssociatedPullRequest { @() }

        $result.Resolved | Should -BeTrue
        $result.PullRequest | Should -BeNullOrEmpty
    }

    It 'tolerates an association response that yields a null element' {
        $result = Resolve-ReleasePullRequest -EventName push `
            -CommitSha 'direct-push-sha' `
            -DefaultBranch main `
            -IsPushToDefaultBranch $true `
            -GetAssociatedPullRequest { $null }

        $result.Resolved | Should -BeTrue
        $result.PullRequest | Should -BeNullOrEmpty
    }

    It 'fails rather than release a patch bump when a merged pull request does not match the commit' {
        # A silently wrong version cannot be withdrawn from the PowerShell Gallery, so a commit whose
        # version label cannot be determined must stop the run.
        $otherMerge = [pscustomobject]@{
            Number           = 412
            Base             = [pscustomobject]@{ Ref = 'main' }
            merged_at        = '2026-09-01T00:00:00Z'
            merge_commit_sha = 'merge-of-412'
        }

        $getAssociated = { @($otherMerge) }.GetNewClosure()
        {
            Resolve-ReleasePullRequest -EventName workflow_dispatch `
                -CommitSha 'released-sha' `
                -DefaultBranch main `
                -IsManualDispatchToDefaultBranch $true `
                -GetAssociatedPullRequest $getAssociated
        } | Should -Throw '*#412*merge-of-412*cannot be reclaimed*'
    }

    It 'releases the default patch bump when only an open pull request claims the commit' {
        # The commit association endpoint also returns open pull requests whose branch contains the
        # commit. They carry no release intent and must not fail a direct default-branch push.
        $openPullRequest = [pscustomobject]@{
            Number           = 411
            Base             = [pscustomobject]@{ Ref = 'main' }
            merged_at        = $null
            merge_commit_sha = 'not-merged-yet'
        }

        $result = Resolve-ReleasePullRequest -EventName push `
            -CommitSha 'direct-push-sha' `
            -DefaultBranch main `
            -IsPushToDefaultBranch $true `
            -GetAssociatedPullRequest ({ @($openPullRequest) }.GetNewClosure())

        $result.Resolved | Should -BeTrue
        $result.PullRequest | Should -BeNullOrEmpty
    }

    It 'does not fail a feature-branch push whose commit belongs to another merged pull request' {
        $otherMerge = [pscustomobject]@{
            Number           = 412
            Base             = [pscustomobject]@{ Ref = 'main' }
            merged_at        = '2026-09-01T00:00:00Z'
            merge_commit_sha = 'merge-of-412'
        }

        $result = Resolve-ReleasePullRequest -EventName push `
            -CommitSha 'feature-sha' `
            -DefaultBranch main `
            -IsPushToDefaultBranch $false `
            -GetAssociatedPullRequest ({ @($otherMerge) }.GetNewClosure())

        $result.Resolved | Should -BeTrue
        $result.PullRequest | Should -BeNullOrEmpty
    }
}

Describe 'Get-DiscardedReleasePullRequest' {
    It 'reports a merged default-branch pull request that does not match the released commit' {
        $pullRequests = @(
            [pscustomobject]@{
                Number           = 412
                Base             = [pscustomobject]@{ Ref = 'main' }
                merged_at        = '2026-08-15T00:00:00Z'
                merge_commit_sha = 'merge-of-412'
            }
        )

        $result = @(Get-DiscardedReleasePullRequest -PullRequest $pullRequests -DefaultBranch main -CommitSha 'other-sha')

        $result.Count | Should -Be 1
        $result[0] | Should -BeLike '*#412*merge-of-412*'
    }

    It 'reports nothing when the merged pull request matches the released commit' {
        $pullRequests = @(
            [pscustomobject]@{
                Number           = 390
                Base             = [pscustomobject]@{ Ref = 'main' }
                merged_at        = '2026-08-15T00:00:00Z'
                merge_commit_sha = 'released-sha'
            }
        )

        $result = @(Get-DiscardedReleasePullRequest -PullRequest $pullRequests -DefaultBranch main -CommitSha 'released-sha')

        $result.Count | Should -Be 0
    }

    It 'ignores a pull request merged into a branch other than the default branch' {
        $pullRequests = @(
            [pscustomobject]@{
                Number           = 401
                Base             = [pscustomobject]@{ Ref = 'release/1.x' }
                merged_at        = '2026-08-15T00:00:00Z'
                merge_commit_sha = 'merge-of-401'
            }
        )

        $result = @(Get-DiscardedReleasePullRequest -PullRequest $pullRequests -DefaultBranch main -CommitSha 'released-sha')

        $result.Count | Should -Be 0
    }

    It 'reports nothing for a commit with no associated pull request' {
        $result = @(Get-DiscardedReleasePullRequest -PullRequest @() -DefaultBranch main -CommitSha 'direct-push-sha')

        $result.Count | Should -Be 0
    }
}

Describe 'Get-FilesFromGitTree' {
    It 'returns only files from a complete tree response' {
        $tree = [pscustomobject]@{
            truncated = $false
            tree      = @(
                [pscustomobject]@{ type = 'blob'; path = 'src/Module.psm1' }
                [pscustomobject]@{ type = 'tree'; path = 'src' }
                [pscustomobject]@{ type = 'blob'; path = 'README.md' }
            )
        }

        $result = Get-FilesFromGitTree -Tree $tree

        $result | Should -Be @('src/Module.psm1', 'README.md')
    }

    It 'rejects a truncated tree response' {
        $tree = [pscustomobject]@{
            truncated = $true
            tree      = @()
        }

        { Get-FilesFromGitTree -Tree $tree } | Should -Throw '*tree response was truncated*'
    }
}

Describe 'Get-FilesFromGitHubComparison' {
    It 'returns filenames from a compare response below the file limit' {
        $comparison = [pscustomobject]@{
            files = @(
                [pscustomobject]@{ filename = 'src/Module.psm1' }
                [pscustomobject]@{ filename = 'README.md' }
            )
        }

        $result = Get-FilesFromGitHubComparison -Comparison $comparison

        $result | Should -Be @('src/Module.psm1', 'README.md')
    }

    It 'rejects a compare response that reaches the file limit' {
        $comparison = [pscustomobject]@{
            files = @(1..300 | ForEach-Object {
                    [pscustomobject]@{ filename = "src/File$_.ps1" }
                })
        }

        { Get-FilesFromGitHubComparison -Comparison $comparison } |
            Should -Throw '*compare response reached its 300-file limit*'
    }
}
