$ErrorActionPreference = 'Stop'

function Get-PSModulePrereleaseForCleanup {
    <#
        .SYNOPSIS
        Select prereleases published from the exact pull request branch.

        .DESCRIPTION
        Uses the GitHub release target retained by Release-PSModule instead of a
        lossy branch-name substring in the version tag. Stable releases, another
        branch's releases, and the supplied published tag are never selected.

        .EXAMPLE
        Get-PSModulePrereleaseForCleanup -Release $releases -HeadRef 'feature/a'

        Returns only prereleases whose targetCommitish is exactly feature/a.

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
        # The unsanitized branch used as the prerelease publication target.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $HeadRef,

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
        if ($candidate.targetCommitish -ceq $HeadRef) {
            $candidate
        }
    }
}
