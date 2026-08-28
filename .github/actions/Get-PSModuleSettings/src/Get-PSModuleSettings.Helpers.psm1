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
        [bool] $HasImportantChanges
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
        ReleaseType                     = if ($shouldRelease) {
            'Release'
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

function Get-UnsupportedPSModuleReleaseSetting {
    <#
        .SYNOPSIS
        Returns release settings removed from the Process-PSModule v9 contract.

        .DESCRIPTION
        Inspects a publish-module settings object and returns any setting names that
        configured automatic patching or custom release-label aliases before v9.

        .OUTPUTS
        System.String

        .EXAMPLE
        Get-UnsupportedPSModuleReleaseSetting -PublishModule $settings.Publish.Module
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [AllowNull()]
        [object] $PublishModule
    )

    if ($null -eq $PublishModule) {
        return
    }

    $settingNames = if ($PublishModule -is [System.Collections.IDictionary]) {
        @($PublishModule.Keys)
    } else {
        @($PublishModule.PSObject.Properties.Name)
    }
    $unsupportedSettingNames = @(
        'AutoPatching'
        'MajorLabels'
        'MinorLabels'
        'PatchLabels'
        'PrereleaseLabels'
        'IgnoreLabels'
    )

    foreach ($settingName in $unsupportedSettingNames) {
        if ($settingNames -contains $settingName) {
            $settingName
        }
    }
}

function Resolve-PSModulePublishState {
    <#
        .SYNOPSIS
        Applies the resolved release decision to module and site publication state.

        .DESCRIPTION
        Updates the runtime settings after Resolve-PSModuleVersion has decided
        whether this run publishes a stable release, prerelease, or nothing.
        Closed pull requests retain their cleanup-only path.

        .OUTPUTS
        System.Management.Automation.PSCustomObject

        .EXAMPLE
        $params = @{
            Settings      = $settings
            ReleaseType   = 'None'
            ShouldPublish = $false
        }
        Resolve-PSModulePublishState @params
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject] $Settings,

        [Parameter(Mandatory)]
        [ValidateSet('Release', 'Prerelease', 'None')]
        [string] $ReleaseType,

        [Parameter(Mandatory)]
        [bool] $ShouldPublish
    )

    $isCleanupOnly = (
        $Settings.Context.EventName -eq 'pull_request' -and
        $Settings.Context.EventAction -eq 'closed'
    )
    $cleanupEnabled = $isCleanupOnly -and [bool]$Settings.Publish.Module.AutoCleanup
    $moduleEnabled = $ShouldPublish -or $cleanupEnabled
    $siteDesired = $ReleaseType -eq 'Release'

    $Settings.Publish.Module.ReleaseType = $ReleaseType
    $Settings.Publish.Module.Desired = $moduleEnabled
    $Settings.Publish.Module.Enabled = $moduleEnabled
    $Settings.Publish.Site.Desired = $siteDesired
    $Settings.Publish.Site.Enabled = $siteDesired -and -not [bool]$Settings.Publish.Site.Skip

    $Settings
}
