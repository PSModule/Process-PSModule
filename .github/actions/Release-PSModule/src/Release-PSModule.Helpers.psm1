$ErrorActionPreference = 'Stop'

function Resolve-PSModuleReleaseTagCommit {
    <#
        .SYNOPSIS
        Resolve a release tag to its exact immutable commit.

        .DESCRIPTION
        Peels annotated tags and rejects unresolved or cyclic references. The
        release's mutable target_commitish hint is not used as ownership proof.

        .EXAMPLE
        Resolve-PSModuleReleaseTagCommit -Tag $tag -GetTagReference $readRef -GetTagObject $readTag

        Returns the commit referenced by the release tag.

        .INPUTS
        None

        You can't pipe objects to Resolve-PSModuleReleaseTagCommit.

        .OUTPUTS
        System.String

        The immutable commit SHA referenced by the tag.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        # The exact release tag name.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Tag,

        # Returns the object referenced by the tag name.
        [Parameter(Mandatory)]
        [scriptblock] $GetTagReference,

        # Returns the object targeted by an annotated-tag SHA.
        [Parameter(Mandatory)]
        [scriptblock] $GetTagObject,

        # Allow only a verified absent tag returned by the lookup boundary.
        [Parameter()]
        [switch] $AllowMissing
    )

    $reference = & $GetTagReference $Tag
    if ($null -eq $reference -and $AllowMissing) {
        return
    }
    $visited = [System.Collections.Generic.HashSet[string]]::new()
    while ($reference.type -eq 'tag') {
        if ([string]::IsNullOrWhiteSpace($reference.sha) -or -not $visited.Add($reference.sha)) {
            throw "Cannot determine release source: tag [$Tag] has invalid or cyclic tag data."
        }

        $reference = & $GetTagObject $reference.sha
    }
    if ($reference.type -ne 'commit' -or [string]::IsNullOrWhiteSpace($reference.sha)) {
        throw "Cannot determine the immutable commit for release tag [$Tag]."
    }
    [string]$reference.sha
}

function Get-PSModulePrereleaseOwnership {
    <#
        .SYNOPSIS
        Read the controller-owned prerelease provenance footer.

        .DESCRIPTION
        Reads only the final versioned footer appended after authored notes.
        Legacy records without that footer return no ownership evidence.

        .EXAMPLE
        Get-PSModulePrereleaseOwnership -Body $release.body

        Returns the recorded repository, PR number, and immutable source.

        .INPUTS
        None

        You can't pipe objects to Get-PSModulePrereleaseOwnership.

        .OUTPUTS
        System.Management.Automation.PSCustomObject

        Validated prerelease ownership evidence, when present.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        # The complete published release body.
        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string] $Body
    )

    $match = [regex]::Match($Body, '(?:^|\r?\n)<!-- PSModule\.PrereleaseOwner:v1:([A-Za-z0-9+/=]+) -->\s*\z')
    if (-not $match.Success) {
        return
    }
    $bytes = [Convert]::FromBase64String($match.Groups[1].Value)
    $ownership = [Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json -ErrorAction Stop
    $number = 0L
    if ([string]::IsNullOrWhiteSpace($ownership.Repository) -or
        $ownership.Repository -notmatch '^[^/\s]+/[^/\s]+$' -or
        -not [long]::TryParse([string]$ownership.PullRequest, [ref]$number) -or
        $number -lt 1 -or [string]::IsNullOrWhiteSpace($ownership.CommitSha)) {
        throw 'The published prerelease ownership footer is invalid. Refusing to infer cleanup ownership.'
    }
    [pscustomobject]@{
        Repository  = [string]$ownership.Repository
        PullRequest = $number
        CommitSha   = [string]$ownership.CommitSha
    }
}
