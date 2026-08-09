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
