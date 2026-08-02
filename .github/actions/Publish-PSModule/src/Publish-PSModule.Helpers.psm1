function Get-ReleaseTag {
    <#
        .SYNOPSIS
        Builds the git tag used for the GitHub release.

        .DESCRIPTION
        Composes the release tag from the configured version prefix, the module version, and the
        prerelease label when there is one. The version comes from the compiled manifest, which is the
        artifact that is published, so the tag always names the exact bytes that were tested and pushed
        to the PowerShell Gallery. The manifest's ModuleVersion is Major.Minor.Patch by definition and
        cannot carry the prefix, so the prefix is supplied from the resolved settings
        (Publish.Module.VersionPrefix) instead. An empty prefix produces an unprefixed tag.

        .OUTPUTS
        String with the release tag.

        .EXAMPLE
        Get-ReleaseTag -VersionPrefix 'v' -ModuleVersion '1.1.10'

        Returns 'v1.1.10'.

        .EXAMPLE
        Get-ReleaseTag -VersionPrefix 'v' -ModuleVersion '1.1.10' -Prerelease 'mybranch001'

        Returns 'v1.1.10-mybranch001'.

        .EXAMPLE
        Get-ReleaseTag -VersionPrefix '' -ModuleVersion '1.1.10'

        Returns '1.1.10'.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        # The module version from the compiled manifest, in Major.Minor.Patch format.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ModuleVersion,

        # The prefix put in front of the version, for example 'v'. Empty for an unprefixed repository.
        [Parameter()]
        [AllowEmptyString()]
        [AllowNull()]
        [string] $VersionPrefix,

        # The prerelease label from the compiled manifest. Empty for a stable release.
        [Parameter()]
        [AllowEmptyString()]
        [AllowNull()]
        [string] $Prerelease
    )

    $tag = "$($VersionPrefix.Trim())$ModuleVersion"

    if ([string]::IsNullOrWhiteSpace($Prerelease)) {
        return $tag
    }

    "$tag-$($Prerelease.Trim())"
}
