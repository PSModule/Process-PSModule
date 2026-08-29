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

function Resolve-PSModulePublishSetting {
    <#
        .SYNOPSIS
        Resolves module publication settings and their defaults.

        .DESCRIPTION
        Applies Process-PSModule defaults while preserving every consumer-provided
        publication and release-label mapping. Rejects the removed AutoPatching
        setting and invalid DefaultBump values with migration guidance.

        .OUTPUTS
        System.Management.Automation.PSCustomObject

        .EXAMPLE
        Resolve-PSModulePublishSetting -PublishModule $settings.Publish.Module
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [AllowNull()]
        [object] $PublishModule
    )

    $propertyNames = if ($null -eq $PublishModule) {
        @()
    } elseif ($PublishModule -is [System.Collections.IDictionary]) {
        @($PublishModule.Keys)
    } else {
        @($PublishModule.PSObject.Properties.Name)
    }

    if ($propertyNames -contains 'AutoPatching') {
        throw (
            'Publish.Module.AutoPatching was removed in Process-PSModule v9. ' +
            'Replace it with Publish.Module.DefaultBump set to patch, minor, or major.'
        )
    }

    $hasDefaultBump = $propertyNames -contains 'DefaultBump'
    $defaultBump = if ($hasDefaultBump) {
        [string]$PublishModule.DefaultBump
    } else {
        'patch'
    }
    $validDefaultBumps = @('patch', 'minor', 'major')
    if ($validDefaultBumps -cnotcontains $defaultBump) {
        throw (
            "Invalid Publish.Module.DefaultBump: [$defaultBump]. " +
            "Valid values are: $($validDefaultBumps -join ', ')."
        )
    }

    [pscustomobject]@{
        Skip                     = $PublishModule.Skip ?? $false
        AutoCleanup              = $PublishModule.AutoCleanup ?? $true
        DefaultBump              = $defaultBump
        IncrementalPrerelease    = $PublishModule.IncrementalPrerelease ?? $true
        DatePrereleaseFormat     = $PublishModule.DatePrereleaseFormat ?? ''
        VersionPrefix            = $PublishModule.VersionPrefix ?? 'v'
        MajorLabels              = $PublishModule.MajorLabels ?? 'release:major'
        MinorLabels              = $PublishModule.MinorLabels ?? 'release:minor'
        PatchLabels              = $PublishModule.PatchLabels ?? 'release:patch'
        IgnoreLabels             = $PublishModule.IgnoreLabels ?? 'release:skip'
        PrereleaseLabels         = $PublishModule.PrereleaseLabels ?? 'release:pre-release'
        UsePRTitleAsReleaseName  = $PublishModule.UsePRTitleAsReleaseName ?? $false
        UsePRBodyAsReleaseNotes  = $PublishModule.UsePRBodyAsReleaseNotes ?? $true
        UsePRTitleAsNotesHeading = $PublishModule.UsePRTitleAsNotesHeading ?? $true
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
