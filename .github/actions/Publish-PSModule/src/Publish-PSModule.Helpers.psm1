function Get-ReleaseTag {
    <#
        .SYNOPSIS
        Builds the git tag used for the GitHub release.

        .DESCRIPTION
        Composes the release tag from the module version and, when present, the prerelease label.
        The version comes from the compiled manifest, which is the artifact that is published, so the
        tag always names the exact bytes that were tested and pushed to the PowerShell Gallery.

        .OUTPUTS
        String with the release tag.

        .EXAMPLE
        Get-ReleaseTag -ModuleVersion '1.1.10'

        Returns '1.1.10'.

        .EXAMPLE
        Get-ReleaseTag -ModuleVersion '1.1.10' -Prerelease 'mybranch001'

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
