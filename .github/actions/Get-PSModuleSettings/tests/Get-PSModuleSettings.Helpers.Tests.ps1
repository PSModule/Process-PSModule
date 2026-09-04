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

Describe 'Resolve-PSModulePublishSetting' {
    It 'uses the canonical release-label defaults' {
        $result = Resolve-PSModulePublishSetting -PublishModule $null

        $result.DefaultBump | Should -BeExactly 'patch'
        $result.MajorLabels | Should -BeExactly 'release:major'
        $result.MinorLabels | Should -BeExactly 'release:minor'
        $result.PatchLabels | Should -BeExactly 'release:patch'
        $result.PrereleaseLabels | Should -BeExactly 'release:prerelease'
        $result.IgnoreLabels | Should -BeExactly 'release:skip'
    }

    It 'preserves consumer-controlled release settings' {
        $publishModule = [pscustomobject]@{
            DefaultBump      = 'minor'
            MajorLabels      = 'custom:major'
            MinorLabels      = 'custom:minor'
            PatchLabels      = 'custom:patch'
            PrereleaseLabels = 'custom:pre-release'
            IgnoreLabels     = 'custom:skip'
        }

        $result = Resolve-PSModulePublishSetting -PublishModule $publishModule

        $result.DefaultBump | Should -BeExactly 'minor'
        $result.MajorLabels | Should -BeExactly 'custom:major'
        $result.MinorLabels | Should -BeExactly 'custom:minor'
        $result.PatchLabels | Should -BeExactly 'custom:patch'
        $result.PrereleaseLabels | Should -BeExactly 'custom:pre-release'
        $result.IgnoreLabels | Should -BeExactly 'custom:skip'
    }

    It 'declares the same canonical defaults in the settings schema' {
        $schemaPath = Join-Path -Path $PSScriptRoot -ChildPath '../src/Settings.schema.json'
        $schema = Get-Content -Path $schemaPath -Raw | ConvertFrom-Json
        $moduleProperties = $schema.properties.Publish.properties.Module.properties

        $moduleProperties.DefaultBump.default | Should -BeExactly 'patch'
        $moduleProperties.DefaultBump.enum | Should -Be @('patch', 'minor', 'major')
        $moduleProperties.PSObject.Properties.Name | Should -Not -Contain 'AutoPatching'
        $moduleProperties.MajorLabels.default | Should -BeExactly 'release:major'
        $moduleProperties.MinorLabels.default | Should -BeExactly 'release:minor'
        $moduleProperties.PatchLabels.default | Should -BeExactly 'release:patch'
        $moduleProperties.PrereleaseLabels.default | Should -BeExactly 'release:prerelease'
        $moduleProperties.IgnoreLabels.default | Should -BeExactly 'release:skip'
    }

    It 'rejects the invalid DefaultBump value <DefaultBump>' -ForEach @(
        @{ DefaultBump = $null }
        @{ DefaultBump = '' }
        @{ DefaultBump = 'Patch' }
        @{ DefaultBump = 'none' }
    ) {
        $publishModule = [pscustomobject]@{ DefaultBump = $DefaultBump }

        { Resolve-PSModulePublishSetting -PublishModule $publishModule } |
            Should -Throw '*Valid values are: patch, minor, major*'
    }

    It 'rejects AutoPatching with migration guidance' {
        $publishModule = [pscustomobject]@{ AutoPatching = $true }

        { Resolve-PSModulePublishSetting -PublishModule $publishModule } |
            Should -Throw '*AutoPatching was removed*Replace it with Publish.Module.DefaultBump*'
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
