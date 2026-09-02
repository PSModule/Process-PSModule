function Resolve-WorkflowEventRouting {
    <#
        .SYNOPSIS
        Resolves release and execution routing from normalized GitHub event state.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string] $EventName,

        [Parameter()]
        [string] $EventAction,

        [Parameter()]
        [bool] $PullRequestIsMerged,

        [Parameter()]
        [bool] $PullRequestIsClosed,

        [Parameter()]
        [bool] $IsTargetDefaultBranch,

        [Parameter()]
        [bool] $IsPushToDefaultBranch,

        [Parameter()]
        [bool] $IsManualDispatchToDefaultBranch,

        [Parameter()]
        [bool] $HasImportantChanges,

        [Parameter()]
        [bool] $HasPrereleaseLabel
    )

    $isPR = $EventName -eq 'pull_request'
    $isPush = $EventName -eq 'push'
    $isManualDispatch = $EventName -eq 'workflow_dispatch'
    $isActivePR = $isPR -and -not $PullRequestIsClosed
    $isOpenOrUpdatedPR = $isActivePR -and $EventAction -in @('opened', 'reopened', 'synchronize', 'labeled', 'unlabeled')
    $isOpenOrLabeledPR = $isActivePR -and $EventAction -in @('opened', 'reopened', 'synchronize', 'labeled')
    $isClosedPR = $isPR -and $EventAction -eq 'closed'
    $isAbandonedPR = $isClosedPR -and -not $PullRequestIsMerged
    $isMergedPR = $isClosedPR -and $PullRequestIsMerged
    $shouldPrerelease = $isOpenOrLabeledPR -and $HasPrereleaseLabel -and $HasImportantChanges
    $shouldRelease = (
        ($IsPushToDefaultBranch -or $IsManualDispatchToDefaultBranch) -and
        $HasImportantChanges
    )

    [pscustomobject]@{
        IsPR                            = $isPR
        IsPush                          = $isPush
        IsManualDispatch                = $isManualDispatch
        IsOpenOrUpdatedPR               = $isOpenOrUpdatedPR
        IsOpenOrLabeledPR               = $isOpenOrLabeledPR
        IsClosedPR                      = $isClosedPR
        IsAbandonedPR                   = $isAbandonedPR
        IsMergedPR                      = $isMergedPR
        IsTargetDefaultBranch           = $IsTargetDefaultBranch
        IsPushToDefaultBranch           = $IsPushToDefaultBranch
        IsManualDispatchToDefaultBranch = $IsManualDispatchToDefaultBranch
        ShouldPrerelease                = $shouldPrerelease
        ReleaseType                     = if ($shouldRelease) {
            'Release'
        } elseif ($shouldPrerelease) {
            'Prerelease'
        } else {
            'None'
        }
        ShouldRunBuildTest              = (
            -not $isClosedPR -and
            ((-not $isPR) -or (-not $PullRequestIsClosed)) -and
            $HasImportantChanges
        )
        ShouldCleanupEvent              = $isClosedPR
        ShouldRunCleanup                = $isClosedPR -or $shouldRelease
    }
}

function Select-PullRequestForPush {
    <#
        .SYNOPSIS
        Selects the merged default-branch pull request associated with a pushed commit.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
        Justification = 'Parameter is used inside a Sort-Object script block.')]
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [object[]] $PullRequest,

        [Parameter(Mandatory)]
        [string] $DefaultBranch,

        [Parameter(Mandatory)]
        [string] $CommitSha
    )

    $PullRequest |
        Where-Object {
            $_.Base.Ref -eq $DefaultBranch -and
            -not [string]::IsNullOrWhiteSpace($_.merged_at) -and
            $_.merge_commit_sha -eq $CommitSha
        } |
        Sort-Object -Property @{ Expression = { $_.merged_at }; Descending = $true } |
        Select-Object -First 1
}

function Get-DiscardedReleasePullRequest {
    <#
        .SYNOPSIS
        Reports merged default-branch pull requests whose version label would be discarded.

        .DESCRIPTION
        Select-PullRequestForPush returns nothing both when a commit has no associated pull request
        and when every associated pull request fails its criteria. Only the first case is safe: a
        commit pushed directly to the default branch has no label to honour, so the direct-release
        path applies the default patch bump.

        The unsafe case is a pull request that was merged into the default branch, and therefore
        carries the version label that was meant to drive the release, but was not selected because
        its merge commit does not match the commit being released. Falling back to a patch bump
        there publishes a version nobody asked for, and a PowerShell Gallery version cannot be
        reclaimed, so the caller must fail instead.

        Pull requests that are not merged are ignored. The GitHub commit association endpoint also
        returns open pull requests whose branch contains the commit, which is expected and carries
        no release intent.

        .OUTPUTS
        String, one description per merged pull request that was rejected. Nothing when the
        associated pull requests carry no release intent.

        .EXAMPLE
        Get-DiscardedReleasePullRequest -PullRequest $associated -DefaultBranch main -CommitSha $sha

        Returns '#412 was merged into [main] with merge commit [abc123]'.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        # The pull requests the GitHub API associated with the commit.
        [Parameter()]
        [object[]] $PullRequest,

        # The repository default branch a release must target.
        [Parameter(Mandatory)]
        [string] $DefaultBranch,

        # The commit the workflow is resolving a release for.
        [Parameter(Mandatory)]
        [string] $CommitSha
    )

    foreach ($candidate in ($PullRequest | Where-Object { $null -ne $_ })) {
        $isMergedToDefaultBranch = (
            $candidate.Base.Ref -eq $DefaultBranch -and
            -not [string]::IsNullOrWhiteSpace($candidate.merged_at)
        )
        if (-not $isMergedToDefaultBranch) { continue }
        if ($candidate.merge_commit_sha -eq $CommitSha) { continue }

        "#$($candidate.Number) was merged into [$DefaultBranch] with merge commit [$($candidate.merge_commit_sha)]"
    }
}

function Resolve-ReleasePullRequest {
    <#
        .SYNOPSIS
        Resolves the pull request whose version label drives the release for a commit.

        .DESCRIPTION
        A push resolves the pull request associated with the pushed commit so a default-branch
        release honours the merged pull request's version label. A manual dispatch on the default
        branch is the documented recovery route for a failed or cancelled release run and targets
        the same merge commit, so it must resolve the same pull request. Excluding it left the pull
        request unresolved, and the version silently fell back to a patch bump through AutoPatching.

        When no pull request is selected, the outcome depends on why. A commit pushed directly to
        the default branch has no label to honour, so the release proceeds with the default patch
        bump. A commit associated with a merged default-branch pull request that does not match it
        does carry a label, and applying a patch bump would publish a version nobody asked for. A
        PowerShell Gallery version cannot be reclaimed, so that case throws instead.

        .OUTPUTS
        PSCustomObject with Resolved, indicating whether the lookup ran, and PullRequest, which is
        null when the commit has no associated release pull request.

        .EXAMPLE
        Resolve-ReleasePullRequest -EventName workflow_dispatch -CommitSha $sha -DefaultBranch main `
            -IsManualDispatchToDefaultBranch $true -GetAssociatedPullRequest { param($Sha) $pulls }

        Resolves the merged pull request for a recovery dispatch so its version label is honoured.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '',
        Justification = 'Parameters are used inside a LogGroup script block.')]
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        # The name of the GitHub event that triggered the workflow.
        [Parameter(Mandatory)]
        [string] $EventName,

        # The commit the workflow is resolving a release for.
        [Parameter()]
        [AllowEmptyString()]
        [AllowNull()]
        [string] $CommitSha,

        # The repository default branch a release must target.
        [Parameter(Mandatory)]
        [string] $DefaultBranch,

        # Whether the workflow was triggered by a push to the default branch.
        [Parameter()]
        [bool] $IsPushToDefaultBranch,

        # Whether the workflow was manually dispatched against the default branch.
        [Parameter()]
        [bool] $IsManualDispatchToDefaultBranch,

        # Returns the pull requests GitHub associates with a commit. Takes the commit SHA.
        [Parameter(Mandatory)]
        [scriptblock] $GetAssociatedPullRequest
    )

    $isPush = $EventName -eq 'push'
    $shouldResolve = (
        ($isPush -or $IsManualDispatchToDefaultBranch) -and
        -not [string]::IsNullOrWhiteSpace($CommitSha)
    )
    if (-not $shouldResolve) {
        return [pscustomobject]@{ Resolved = $false; PullRequest = $null }
    }

    LogGroup "Resolve pull request for commit [$CommitSha]" {
        $associated = @((& $GetAssociatedPullRequest $CommitSha) | Where-Object { $null -ne $_ })
        $pullRequest = Select-PullRequestForPush -PullRequest $associated `
            -DefaultBranch $DefaultBranch `
            -CommitSha $CommitSha

        if ($pullRequest) {
            Write-Host "Resolved pull request #$($pullRequest.Number) from commit [$CommitSha]."
            return [pscustomobject]@{ Resolved = $true; PullRequest = $pullRequest }
        }

        # Only a release-bearing event can publish a wrong version. A push to a feature branch has
        # no release to get wrong, and its commit is legitimately claimed by an open pull request.
        $isReleaseEvent = $IsPushToDefaultBranch -or $IsManualDispatchToDefaultBranch
        $discarded = if ($isReleaseEvent) {
            @(Get-DiscardedReleasePullRequest -PullRequest $associated `
                    -DefaultBranch $DefaultBranch `
                    -CommitSha $CommitSha)
        } else {
            @()
        }
        if ($discarded.Count -gt 0) {
            throw (
                "Commit [$CommitSha] cannot be released because its version label cannot be determined. " +
                'The following merged pull request(s) are associated with it but none matches the commit ' +
                "being released: $($discarded -join '; '). " +
                'Refusing to fall back to a patch bump, because a wrong version published to the ' +
                'PowerShell Gallery cannot be reclaimed. Re-run the workflow against the merge commit ' +
                'of the pull request you intend to release.'
            )
        }

        Write-Host "::notice::No pull request is associated with commit [$CommitSha]."
        [pscustomobject]@{ Resolved = $true; PullRequest = $null }
    }
}

function Get-FilesFromGitTree {
    <#
        .SYNOPSIS
        Returns the files contained in a complete Git tree response.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject] $Tree
    )

    if ($Tree.truncated) {
        throw 'Cannot determine changed files because the Git tree response was truncated.'
    }

    $Tree.tree |
        Where-Object { $_.type -eq 'blob' } |
        Select-Object -ExpandProperty path
}

function Get-FilesFromGitHubComparison {
    <#
        .SYNOPSIS
        Returns files from a complete GitHub compare response.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject] $Comparison
    )

    $files = @($Comparison.files | Where-Object { $null -ne $_ })
    if ($files.Count -ge 300) {
        throw 'Cannot determine changed files because the GitHub compare response reached its 300-file limit.'
    }

    $files | Select-Object -ExpandProperty filename
}
