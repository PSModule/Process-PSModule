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
        [scriptblock] $GetTagObject
    )

    $reference = & $GetTagReference $Tag
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
