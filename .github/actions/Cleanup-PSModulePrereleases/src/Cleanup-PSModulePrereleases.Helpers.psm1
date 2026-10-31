$ErrorActionPreference = 'Stop'
Import-Module -Name (
    Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath '..', 'Release-PSModule', 'src', 'Release-PSModule.Helpers.psm1'
) -Force

function Get-PSModulePrereleaseForCleanup {
    <#
        .SYNOPSIS
        Select prereleases with verified producing PR and source ownership.

        .DESCRIPTION
        Uses controller-owned repository, PR, and commit provenance rather than
        branch or tag substrings. Stable and unverified legacy releases, another
        PR's releases, and the supplied published tag are never selected.

        .EXAMPLE
        Get-PSModulePrereleaseForCleanup -Release $releases -Repository 'PSModule/MyModule' `
            -PullRequestNumber 42 -GetTagCommit $readTagCommit

        Returns only verified prereleases produced for MyModule PR 42.

        .INPUTS
        None

        You can't pipe objects to Get-PSModulePrereleaseForCleanup.

        .OUTPUTS
        System.Management.Automation.PSCustomObject

        A release eligible for branch-scoped cleanup.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        # The base repository in owner/name form.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Repository,

        # The source PR number within the base repository.
        [Parameter()]
        [long] $PullRequestNumber,

        # Returns the exact immutable commit referenced by a release tag.
        [Parameter()]
        [scriptblock] $GetTagCommit,

        # Release objects with tagName, isPrerelease, and targetCommitish.
        [Parameter()]
        [object[]] $Release,

        # The tag created by the current publication, which must be retained.
        [Parameter()]
        [string] $ReleaseTag
    )

    foreach ($candidate in $Release) {
        if ($null -eq $candidate -or -not $candidate.isPrerelease -or $candidate.tagName -ceq $ReleaseTag) {
            continue
        }
        if ([string]::IsNullOrWhiteSpace($candidate.tagName) -or
            [string]::IsNullOrWhiteSpace($candidate.targetCommitish)) {
            throw 'Cannot determine prerelease cleanup ownership: a release is missing its tag or targetCommitish.'
        }
        $ownership = Get-PSModulePrereleaseOwnership -Body ([string]$candidate.body)
        if ($null -ne $ownership) {
            if ($ownership.Repository -ne $Repository -or $ownership.PullRequest -ne $PullRequestNumber) {
                continue
            }
            if ($candidate.targetCommitish -cne $ownership.CommitSha) {
                Write-Verbose "Retaining [$($candidate.tagName)] because its creation target does not bind the ownership source."
                continue
            }
            if ($null -eq $GetTagCommit) {
                throw 'Immutable tag lookup is required to verify published prerelease ownership.'
            }
            $tagCommit = & $GetTagCommit $candidate.tagName
            if ($tagCommit -cne $ownership.CommitSha) {
                throw "Prerelease tag [$($candidate.tagName)] no longer matches its recorded source. Refusing cleanup."
            }
            $candidate
        } else {
            Write-Verbose "Retaining legacy release [$($candidate.tagName)] without producing PR/source ownership evidence."
        }
    }
}
