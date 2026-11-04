function Get-ModuleVersionString {
    <#
        .SYNOPSIS
        Build the SemVer version string that identifies the module.

        .DESCRIPTION
        If a prerelease label is present, the function puts the module version and the label together.
        The PowerShell Gallery and the module manifest use this string: `Major.Minor.Patch` optionally followed by `-<prerelease>`.
        The string never includes the repository's version prefix.
        Neither the manifest's `ModuleVersion` nor a Gallery package version accepts a prefix.

        .OUTPUTS
        System.String

        The module version.

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
