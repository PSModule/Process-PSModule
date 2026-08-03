function Get-ModuleVersionString {
    <#
        .SYNOPSIS
        Builds the SemVer version string that identifies the module itself.

        .DESCRIPTION
        Composes the module version and, when there is one, the prerelease label. This is the string the
        PowerShell Gallery and the module manifest understand: `Major.Minor.Patch` optionally followed by
        `-<prerelease>`. It never carries the repository's version prefix, because neither the manifest's
        `ModuleVersion` nor a Gallery package version accepts one.

        .OUTPUTS
        String with the module version.

        .EXAMPLE
        Get-ModuleVersionString -ModuleVersion '1.1.10'

        Returns '1.1.10'.

        .EXAMPLE
        Get-ModuleVersionString -ModuleVersion '1.1.10' -Prerelease 'mybranch001'

        Returns '1.1.10-mybranch001'.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        # The module version from the compiled manifest, in Major.Minor.Patch format.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ModuleVersion,

        # The prerelease label from the compiled manifest. Empty for a stable release.
        [Parameter()]
        [AllowEmptyString()]
        [AllowNull()]
        [string] $Prerelease
    )

    if ([string]::IsNullOrWhiteSpace($Prerelease)) {
        return $ModuleVersion
    }

    "$ModuleVersion-$($Prerelease.Trim())"
}

function Get-ReleaseTag {
    <#
        .SYNOPSIS
        Builds the git tag used for the GitHub release.

        .DESCRIPTION
        Prefixes the module's SemVer version string with the configured version prefix. The version comes
        from the compiled manifest, which is the artifact that is published, so the tag always names the
        exact bytes that were tested and pushed to the PowerShell Gallery. The manifest's ModuleVersion is
        Major.Minor.Patch by definition and cannot carry the prefix, so the prefix is supplied from the
        resolved settings (Publish.Module.VersionPrefix) instead.

        The prefix belongs to the GitHub release tag and to nothing else. PowerShell manifests and Gallery
        package versions only accept plain SemVer, so callers that need the module's own version use
        Get-ModuleVersionString. Deriving both from the same composition keeps the prefix as the only
        difference between them.

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

    "$($VersionPrefix.Trim())$(Get-ModuleVersionString -ModuleVersion $ModuleVersion -Prerelease $Prerelease)"
}
