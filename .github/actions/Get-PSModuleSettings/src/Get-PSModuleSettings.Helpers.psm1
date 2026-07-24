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
        [bool] $IsTargetDefaultBranch,

        [Parameter()]
        [bool] $IsPushToDefaultBranch,

        [Parameter()]
        [bool] $HasPullRequestContext,

        [Parameter()]
        [bool] $HasImportantChanges,

        [Parameter()]
        [bool] $HasPrereleaseLabel,

        [Parameter()]
        [bool] $AllowDirectPushRelease
    )

    $isPR = $EventName -eq 'pull_request'
    $isPush = $EventName -eq 'push'
    $isOpenOrUpdatedPR = $isPR -and $EventAction -in @('opened', 'reopened', 'synchronize', 'labeled', 'unlabeled')
    $isOpenOrLabeledPR = $isPR -and $EventAction -in @('opened', 'reopened', 'synchronize', 'labeled')
    $isClosedPR = $isPR -and $EventAction -eq 'closed'
    $isAbandonedPR = $isClosedPR -and -not $PullRequestIsMerged
    $isMergedPR = $isClosedPR -and $PullRequestIsMerged
    $shouldPrerelease = $isOpenOrLabeledPR -and $HasPrereleaseLabel -and $HasImportantChanges

    $releaseType = if (
        $IsPushToDefaultBranch -and
        $HasImportantChanges -and
        ($HasPullRequestContext -or $AllowDirectPushRelease)
    ) {
        'Release'
    } elseif ($shouldPrerelease) {
        'Prerelease'
    } else {
        'None'
    }

    [pscustomobject]@{
        IsPR                  = $isPR
        IsPush                = $isPush
        IsOpenOrUpdatedPR     = $isOpenOrUpdatedPR
        IsOpenOrLabeledPR     = $isOpenOrLabeledPR
        IsClosedPR            = $isClosedPR
        IsAbandonedPR         = $isAbandonedPR
        IsMergedPR            = $isMergedPR
        IsTargetDefaultBranch = $IsTargetDefaultBranch
        IsPushToDefaultBranch = $IsPushToDefaultBranch
        ShouldPrerelease      = $shouldPrerelease
        ReleaseType           = $releaseType
        ShouldRunBuildTest    = (-not $isClosedPR) -and $HasImportantChanges
        ShouldCleanupEvent    = (
            ($releaseType -eq 'Release') -or
            $isClosedPR -or
            ($IsPushToDefaultBranch -and $HasPullRequestContext)
        )
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
            -not [string]::IsNullOrWhiteSpace($_.'merged_at')
        } |
        Sort-Object -Property @{ Expression = { $_.'merge_commit_sha' -eq $CommitSha }; Descending = $true },
        @{ Expression = { $_.'merged_at' }; Descending = $true } |
        Select-Object -First 1
}
