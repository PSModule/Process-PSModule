$ErrorActionPreference = 'Stop'

Import-Module -Name ([IO.Path]::Combine(
        $PSScriptRoot, '..', '..', 'Release-PSModule', 'src', 'Release-PSModule.Helpers.psm1'
    )) -Force

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

function Invoke-PSModulePublicationApi {
    <#
        .SYNOPSIS
        Read an explicit GitHub API status or perform a guarded create-only request.

        .DESCRIPTION
        Only an observed HTTP 404 can represent absence. Authentication, API, empty,
        and malformed-response errors remain failures, including during claim creation.

        .EXAMPLE
        Invoke-PSModulePublicationApi -Endpoint $endpoint -AllowMissing

        Read a resource after repository/source access has been established.

        .INPUTS
        None

        You can't pipe objects to Invoke-PSModulePublicationApi.

        .OUTPUTS
        System.Management.Automation.PSCustomObject

        The HTTP status and parsed response value, when present.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        # A repository-scoped REST endpoint.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Endpoint,

        # GET reads resources; POST creates a tag object or reference.
        [Parameter()]
        [ValidateSet('GET', 'POST')]
        [string] $Method = 'GET',

        # Flat string fields passed as arguments, never evaluated as script.
        [Parameter()]
        [hashtable] $Field = @{},

        # Permit only a verified absent-resource HTTP status.
        [Parameter()]
        [switch] $AllowMissing,

        # Expose a create-reference conflict for exact proof revalidation.
        [Parameter()]
        [switch] $AllowConflict
    )

    $arguments = @('api', $Endpoint, '--include', '--method', $Method)
    foreach ($key in $Field.Keys) {
        $arguments += @('--raw-field', "$key=$($Field[$key])")
    }
    if ($Method -ne 'GET' -and -not $PSCmdlet.ShouldProcess($Endpoint, 'Create publication claim')) {
        return
    }
    $PSNativeCommandUseErrorActionPreference = $false
    $response = gh @arguments 2>&1
    $exitCode = $LASTEXITCODE
    $text = ($response | Out-String).Trim()
    $status = [regex]::Match($text, '(?m)^HTTP/\S+\s+(\d{3})\b')
    if (-not $status.Success) {
        throw "Cannot verify the GitHub API status for [$Endpoint] (gh exited $exitCode): $text"
    }
    $statusCode = [int]$status.Groups[1].Value
    if ($AllowMissing -and $Method -eq 'GET' -and $statusCode -eq 404 -and $exitCode -ne 0) {
        return
    }
    $isConflict = $AllowConflict -and $Method -eq 'POST' -and $statusCode -in @(409, 422) -and $exitCode -ne 0
    if (-not $isConflict -and ($exitCode -ne 0 -or $statusCode -notin @(200, 201))) {
        throw "GitHub API request [$Endpoint] failed (HTTP $statusCode, gh exited $exitCode): $text"
    }
    $parts = $text.Substring($status.Index) -split '\r?\n\r?\n', 2
    if ($parts.Count -ne 2 -or [string]::IsNullOrWhiteSpace($parts[1])) {
        throw "The GitHub API response for [$Endpoint] has no verifiable JSON body."
    }
    $body = $parts[1] -replace '(?m)^gh:.*(?:\r?\n|\z)', ''
    $value = ConvertFrom-Json -InputObject $body -NoEnumerate -ErrorAction Stop
    if ($null -eq $value) {
        throw "The GitHub API response for [$Endpoint] returned no resource metadata."
    }
    [pscustomobject]@{ StatusCode = $statusCode; Value = $value }
}

function Get-PSModuleGalleryPackage {
    <#
        .SYNOPSIS
        Read only the exact resolved Gallery package.

        .EXAMPLE
        Get-PSModuleGalleryPackage -Name TestModule -Version 1.2.4

        Return the exact package or verified PackageNotFound absence.

        .INPUTS
        None

        You can't pipe objects to Get-PSModuleGalleryPackage.

        .OUTPUTS
        System.Object

        The Gallery package metadata, when present.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        # The resolved module name.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        # The exact Gallery version, including any prerelease label.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Version
    )

    $parameters = @{
        Name        = $Name
        Version     = $Version
        Repository  = 'PSGallery'
        ErrorAction = 'Stop'
    }
    if ($Version.Contains('-')) {
        $parameters.Prerelease = $true
    }
    try {
        $packages = @(Find-PSResource @parameters)
    } catch {
        $failure = $_
        if ($failure.FullyQualifiedErrorId -notlike 'PackageNotFound,*') {
            throw
        }
        Write-Verbose "The exact Gallery package [$Name] [$Version] is absent."
        return
    }
    if ($packages.Count -ne 1) {
        throw "The exact Gallery lookup for [$Name] [$Version] returned missing or ambiguous metadata."
    }
    $package = $packages[0]
    $packageVersion = Get-ModuleVersionString -ModuleVersion ([string]$package.Version) -Prerelease $package.Prerelease
    if ($package.Name -ine $Name -or $packageVersion -cne $Version) {
        throw "The Gallery lookup returned [$($package.Name)] [$packageVersion], not [$Name] [$Version]."
    }
    $package
}

function Get-PSModuleGalleryArtifactDigest {
    <#
        .SYNOPSIS
        Download an exact raw nupkg solely to verify its tested file-tree identity.

        .DESCRIPTION
        Downloads no dependencies, never installs or imports the package, and removes
        the isolated raw package after reading its identity and payload streams.

        .EXAMPLE
        Get-PSModuleGalleryArtifactDigest -Name TestModule -Version 1.2.4

        Return the proven package payload digest or surface a download/identity error.

        .INPUTS
        None

        You can't pipe objects to Get-PSModuleGalleryArtifactDigest.

        .OUTPUTS
        System.String

        The Gallery package file-tree SHA-256.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        # The exact Gallery package name.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        # The exact Gallery version.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Version
    )

    $directory = Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath "PSModulePackage-$([guid]::NewGuid())"
    $null = New-Item -Path $directory -ItemType Directory -ErrorAction Stop
    try {
        $parameters = @{
            Name                = $Name
            Version             = "[$Version]"
            Repository          = 'PSGallery'
            Path                = $directory
            AsNupkg             = $true
            SkipDependencyCheck = $true
            TrustRepository     = $true
            ErrorAction         = 'Stop'
        }
        if ($Version.Contains('-')) {
            $parameters.Prerelease = $true
        }
        $null = Save-PSResource @parameters
        $files = @(Get-ChildItem -LiteralPath $directory -File -Force -ErrorAction Stop)
        if ($files.Count -ne 1 -or $files[0].Extension -ine '.nupkg') {
            throw "The exact package download for [$Name] [$Version] did not produce one raw nupkg."
        }
        Get-PSModulePackageArtifactDigest -Path $files[0].FullName -ModuleName $Name -GalleryVersion $Version
    } finally {
        foreach ($file in Get-ChildItem -LiteralPath $directory -File -Force -ErrorAction Stop) {
            Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
        }
        Remove-Item -LiteralPath $directory -Force -ErrorAction Stop
    }
}

function Get-PSModulePublicationReader {
    <#
        .SYNOPSIS
        Bind source, tag, release, and exact-package readers to the consumer repository.

        .EXAMPLE
        Get-PSModulePublicationReader -Repository PSModule/TestModule

        Return the injectable read boundaries used by preflight and recovery.

        .INPUTS
        None

        You can't pipe objects to Get-PSModulePublicationReader.

        .OUTPUTS
        System.Collections.Hashtable

        The source-bound resource readers.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        # The base consumer repository, not the workflow provider.
        [Parameter(Mandatory)]
        [ValidatePattern('^[^/\s]+/[^/\s]+$')]
        [string] $Repository,

        # Plan can inspect immutable claims without the publisher's write token.
        [Parameter()]
        [switch] $ReadOnly
    )

    Write-Verbose "Binding publication readers to [$Repository]."
    $requiresWriteAccess = -not $ReadOnly
    $readTagReference = {
        param($Tag)
        $encodedTag = [Uri]::EscapeDataString($Tag)
        $response = Invoke-PSModulePublicationApi -Endpoint "repos/$Repository/git/ref/tags/$encodedTag" -AllowMissing
        if ($null -eq $response) { return }
        $value = $response.Value
        if ($value -isnot [PSCustomObject] -or $value -is [array] -or
            $value.ref -isnot [string] -or $value.ref -cne "refs/tags/$Tag" -or
            $value.object -isnot [PSCustomObject] -or $value.object -is [array] -or
            $value.object.sha -isnot [string] -or $value.object.sha -notmatch '^[0-9a-f]{40}$' -or
            $value.object.type -isnot [string] -or $value.object.type -cnotin @('tag', 'commit')) {
            throw "The tag lookup for [$Tag] returned unverifiable reference metadata."
        }
        $value.object
    }.GetNewClosure()
    @{
        GetSource                = {
            param($CommitSha)
            $repositoryMetadata = (Invoke-PSModulePublicationApi -Endpoint "repos/$Repository").Value
            if ($repositoryMetadata -isnot [PSCustomObject] -or $repositoryMetadata -is [array] -or
                $repositoryMetadata.full_name -isnot [string] -or $repositoryMetadata.full_name -ine $Repository) {
                throw "Cannot establish access to the exact consumer repository [$Repository]."
            }
            if ($requiresWriteAccess -and ($repositoryMetadata.permissions.push -isnot [bool] -or
                    $repositoryMetadata.permissions.push -ne $true)) {
                throw "Cannot verify release visibility and write access in [$Repository]. Refusing to treat hidden releases as absent."
            }
            $commit = (Invoke-PSModulePublicationApi -Endpoint "repos/$Repository/git/commits/$CommitSha").Value
            if ($commit -isnot [PSCustomObject] -or $commit -is [array] -or
                $commit.sha -isnot [string] -or $commit.sha -cne $CommitSha) {
                throw "Cannot verify the original immutable source [$CommitSha] in [$Repository]."
            }
            [string]$commit.sha
        }.GetNewClosure()
        GetTagReference          = $readTagReference
        GetVersionReference      = {
            param($Name, $Version)
            $tag = Get-PSModulePublicationVersionTag -ModuleName $Name -GalleryVersion $Version
            & $readTagReference $tag
        }.GetNewClosure()
        GetTagObject             = {
            param($Sha)
            $response = (Invoke-PSModulePublicationApi -Endpoint "repos/$Repository/git/tags/$Sha").Value
            if ($response -isnot [PSCustomObject] -or $response -is [array] -or
                $response.sha -isnot [string] -or $response.sha -cne $Sha -or $response.tag -isnot [string] -or
                $response.object -isnot [PSCustomObject] -or $response.object -is [array] -or
                $response.object.type -isnot [string] -or $response.object.sha -isnot [string] -or
                $response.object.sha -notmatch '^[0-9a-f]{40}$' -or $response.message -isnot [string]) {
                throw "Cannot verify the annotated publication tag [$Sha]."
            }
            $response
        }.GetNewClosure()
        GetRelease               = {
            param($Tag)
            $encodedTag = [Uri]::EscapeDataString($Tag)
            $response = Invoke-PSModulePublicationApi -Endpoint "repos/$Repository/releases/tags/$encodedTag" -AllowMissing
            if ($null -eq $response) { return }
            if ($response.Value -isnot [PSCustomObject] -or $response.Value -is [array]) {
                throw "The release lookup for [$Tag] returned unverifiable resource metadata."
            }
            $response.Value
        }.GetNewClosure()
        GetPackage               = {
            param($Name, $Version)
            Get-PSModuleGalleryPackage -Name $Name -Version $Version
        }
        GetPackageArtifactDigest = {
            param($Name, $Version)
            Get-PSModuleGalleryArtifactDigest -Name $Name -Version $Version
        }
    }
}

function Get-PSModulePublicationState {
    <#
        .SYNOPSIS
        Verify source, tag, release, and package ownership before any publication mutation.

        .DESCRIPTION
        Uses the canonical immutable-tag and final-footer algorithms. The returned
        snapshot is not a lease; callers atomically claim a new tag and recheck it.

        .EXAMPLE
        Get-PSModulePublicationState -ExpectedClaim $claim -Reader $reader

        Return the proven exact publication state or fail without writing.

        .INPUTS
        None

        You can't pipe objects to Get-PSModulePublicationState.

        .OUTPUTS
        System.Management.Automation.PSCustomObject

        The verified tag object, release, and package state.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        # The immutable source, resolved context, and tested artifact identity.
        [Parameter(Mandatory)]
        [PSCustomObject] $ExpectedClaim,

        # Injected read-only boundaries, including exact raw package verification.
        [Parameter(Mandatory)]
        [hashtable] $Reader
    )

    $readerNames = @(
        'GetSource', 'GetTagReference', 'GetVersionReference', 'GetTagObject',
        'GetRelease', 'GetPackage', 'GetPackageArtifactDigest'
    )
    foreach ($name in $readerNames) {
        if ($Reader[$name] -isnot [scriptblock]) {
            throw "The publication reader [$name] is missing."
        }
    }
    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($ExpectedClaim | ConvertTo-Json -Compress)))
    $expected = Get-PSModulePublicationClaim -Message "<!-- PSModule.Publication:v1:$encoded -->"
    $source = & $Reader.GetSource $expected.CommitSha
    if ($source -cne $expected.CommitSha) {
        throw "Cannot verify the original immutable publication source [$($expected.CommitSha)]."
    }
    $tagEvidence = @{ Reference = $null; Annotation = $null }
    $tagParameters = @{
        Tag             = $expected.ReleaseTag
        AllowMissing    = $true
        GetTagReference = {
            param($Tag)
            $tagEvidence.Reference = & $Reader.GetTagReference $Tag
            $tagEvidence.Reference
        }.GetNewClosure()
        GetTagObject    = {
            param($Sha)
            $annotation = & $Reader.GetTagObject $Sha
            if ($null -eq $tagEvidence.Annotation) {
                $tagEvidence.Annotation = $annotation
            }
            $annotation.object
        }.GetNewClosure()
    }
    $tagCommit = Resolve-PSModuleReleaseTagCommit @tagParameters
    if ($null -ne $tagCommit -and $tagCommit -cne $expected.CommitSha) {
        throw "Release tag [$($expected.ReleaseTag)] belongs to [$tagCommit], not source [$($expected.CommitSha)]."
    }
    $claim = Get-PSModulePublicationClaim -Message $tagEvidence.Annotation.message
    $versionTag = Get-PSModulePublicationVersionTag -ModuleName $expected.ModuleName -GalleryVersion $expected.GalleryVersion
    $versionEvidence = @{ Reference = $null; Annotation = $null }
    $versionParameters = @{
        Tag             = $versionTag
        AllowMissing    = $true
        GetTagReference = {
            param($Tag)
            if ($Tag -cne $versionTag) { throw 'Unexpected package ownership coordinate.' }
            $versionEvidence.Reference = & $Reader.GetVersionReference $expected.ModuleName $expected.GalleryVersion
            $versionEvidence.Reference
        }.GetNewClosure()
        GetTagObject    = {
            param($Sha)
            $annotation = & $Reader.GetTagObject $Sha
            if ($null -eq $versionEvidence.Annotation) { $versionEvidence.Annotation = $annotation }
            $annotation.object
        }.GetNewClosure()
    }
    $versionCommit = Resolve-PSModuleReleaseTagCommit @versionParameters
    if ($null -ne $versionCommit -and $versionCommit -cne $expected.CommitSha) {
        throw "Module/version coordinate [$versionTag] belongs to another source [$versionCommit]."
    }
    $versionClaim = Get-PSModulePublicationClaim -Message $versionEvidence.Annotation.message
    $release = & $Reader.GetRelease $expected.ReleaseTag
    $package = & $Reader.GetPackage $expected.ModuleName $expected.GalleryVersion
    if ($null -eq $tagCommit) {
        if ($null -ne $release -or $null -ne $package) {
            throw "Existing release or Gallery version [$($expected.GalleryVersion)] has no verifiable source/artifact ownership proof."
        }
    } elseif ($null -eq $claim -or $tagEvidence.Annotation.tag -cne $expected.ReleaseTag) {
        throw "The existing tag [$($expected.ReleaseTag)] has no verifiable publication ownership proof."
    }
    if ($null -ne $versionCommit -and
        ($null -eq $versionClaim -or $versionEvidence.Annotation.tag -cne $expected.ReleaseTag)) {
        throw "The module/version coordinate [$versionTag] has no verifiable publication proof."
    }
    if ($null -ne $package -and $null -eq $versionCommit) {
        throw "The existing Gallery package [$($expected.GalleryVersion)] has no shared module/version ownership proof."
    }
    if ($null -ne $tagCommit -and $null -ne $versionCommit -and
        $tagEvidence.Reference.sha -cne $versionEvidence.Reference.sha) {
        throw 'The release tag and module/version coordinate reference different immutable claims.'
    }
    foreach ($proof in @($claim, $versionClaim) | Where-Object { $null -ne $_ }) {
        if ($proof.Repository -ine $expected.Repository -or $proof.PullRequest -ne $expected.PullRequest) {
            throw 'The publication claim belongs to a different repository or producing pull request.'
        }
        foreach ($name in @('CommitSha', 'ModuleName', 'GalleryVersion', 'VersionPrefix', 'ReleaseTag', 'ReleaseType', 'AssetName')) {
            if ($proof.$name -cne $expected.$name) {
                throw "The publication claim has conflicting [$name] ownership."
            }
        }
        if ($proof.ArtifactSha256 -cne $expected.ArtifactSha256 -or $proof.AssetSha256 -cne $expected.AssetSha256) {
            throw 'The claimed version belongs to different tested artifact or release asset contents.'
        }
    }
    if ($null -ne $release) {
        if ($release.draft -isnot [bool] -or $release.draft -ne $false) {
            throw 'The existing release has no verified boolean draft:false status. Refusing publication or an incomplete release.'
        }
        if ($release.tag_name -isnot [string] -or $release.tag_name -cne $expected.ReleaseTag -or
            [string]::IsNullOrWhiteSpace($release.html_url) -or
            $release.prerelease -isnot [bool] -or
            $release.prerelease -ne ($expected.ReleaseType -ceq 'Prerelease') -or
            $release.PSObject.Properties.Name -notcontains 'assets' -or $null -eq $release.assets) {
            throw "Cannot verify the existing release context for [$($expected.ReleaseTag)]."
        }
        $owner = Get-PSModulePrereleaseOwnership -Body $release.body
        if ($null -ne $owner -or $expected.PullRequest -gt 0) {
            if ($expected.PullRequest -lt 1) {
                throw 'The existing release ownership footer conflicts with the direct-release context.'
            }
            $null = Get-PSModuleReleaseOwnership -Body $release.body -Repository $expected.Repository `
                -PullRequest $expected.PullRequest -CommitSha $expected.CommitSha
        }
        $assets = @($release.assets)
        if ($assets.Count -gt 1 -or ($assets.Count -eq 1 -and $assets[0].name -cne $expected.AssetName)) {
            throw 'The existing release contains foreign or ambiguous module assets.'
        }
        if ($assets.Count -eq 1) {
            if ($assets[0].name -isnot [string] -or $assets[0].digest -isnot [string] -or $assets[0].state -isnot [string]) {
                throw 'The existing module asset has unverifiable byte-proof metadata.'
            }
            $digest = [regex]::Match([string]$assets[0].digest, '^sha256:([0-9A-Fa-f]{64})$')
            if (-not $digest.Success -or $assets[0].state -cne 'uploaded') {
                throw "The existing asset [$($expected.AssetName)] has no verifiable published-byte proof."
            }
            if ($digest.Groups[1].Value.ToLowerInvariant() -cne $expected.AssetSha256) {
                throw "The existing asset [$($expected.AssetName)] contains different published bytes."
            }
        }
    }
    if ($null -ne $package) {
        $packageDigest = & $Reader.GetPackageArtifactDigest $expected.ModuleName $expected.GalleryVersion
        if ($packageDigest -cne $expected.ArtifactSha256) {
            throw "The Gallery package [$($expected.GalleryVersion)] has different or unverifiable tested artifact contents."
        }
    }
    [pscustomobject]@{
        TagSha        = $tagEvidence.Reference.sha
        VersionTagSha = $versionEvidence.Reference.sha
        Claim         = if ($null -ne $versionClaim) { $versionClaim } else { $claim }
        Release       = $release
        Package       = $package
    }
}

function New-PSModulePublicationTag {
    <#
        .SYNOPSIS
        Atomically claim an absent version tag for the verified tested artifact.

        .DESCRIPTION
        Creates an annotated object and a create-only ref. Never updates an existing
        tag. A competing ref is accepted only after proving identical source/context/bytes.

        .EXAMPLE
        New-PSModulePublicationTag -Claim $claim -State $state -Reader $reader

        Return the claimed and reverified tag state before Gallery publication.

        .INPUTS
        None

        You can't pipe objects to New-PSModulePublicationTag.

        .OUTPUTS
        System.Management.Automation.PSCustomObject

        The verified immutable publication claim.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        # The verified resolved source, release context, and artifact claim.
        [Parameter(Mandatory)]
        [PSCustomObject] $Claim,

        # The preceding read-only preflight snapshot.
        [Parameter(Mandatory)]
        [PSCustomObject] $State,

        # The same read boundaries used to verify concurrent claims.
        [Parameter(Mandatory)]
        [hashtable] $Reader
    )

    $current = Get-PSModulePublicationState -ExpectedClaim $Claim -Reader $Reader
    if ($null -ne $State.TagSha -and $current.TagSha -cne $State.TagSha) {
        throw 'The existing publication tag changed or disappeared after preflight. Refusing Gallery publication.'
    }
    if ($null -ne $State.VersionTagSha -and $current.VersionTagSha -cne $State.VersionTagSha) {
        throw 'The shared module/version claim changed or disappeared after preflight. Refusing publication.'
    }
    if ($null -ne $current.TagSha -and $null -ne $current.VersionTagSha) {
        return $current
    }
    if (-not $PSCmdlet.ShouldProcess("$($Claim.Repository):$($Claim.ModuleName):$($Claim.GalleryVersion)",
            'Create shared module/version ownership and immutable release tag')) {
        return
    }
    $claimSha = $current.VersionTagSha
    if ($null -eq $claimSha) {
        $claimSha = $current.TagSha
    }
    if ($null -eq $claimSha) {
        $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($Claim | ConvertTo-Json -Compress)))
        $message = "<!-- PSModule.Publication:v1:$encoded -->"
        $tagFields = @{
            tag     = $Claim.ReleaseTag
            message = $message
            object  = $Claim.CommitSha
            type    = 'commit'
        }
        $tag = (Invoke-PSModulePublicationApi -Endpoint "repos/$($Claim.Repository)/git/tags" `
                -Method POST -Field $tagFields).Value
        if ($tag -isnot [PSCustomObject] -or $tag -is [array] -or
            $tag.sha -isnot [string] -or $tag.sha -notmatch '^[0-9a-f]{40}$' -or $tag.tag -isnot [string] -or
            $tag.message -isnot [string] -or $tag.object.sha -isnot [string] -or $tag.object.type -isnot [string] -or
            $tag.tag -cne $Claim.ReleaseTag -or
            $tag.object.type -cne 'commit' -or $tag.object.sha -cne $Claim.CommitSha -or $tag.message -cne $message) {
            throw 'The annotated object did not preserve the exact source/context/artifact claim.'
        }
        $claimSha = $tag.sha
    }
    if ($null -eq $current.VersionTagSha) {
        $versionTag = Get-PSModulePublicationVersionTag -ModuleName $Claim.ModuleName -GalleryVersion $Claim.GalleryVersion
        $observedTagSha = $current.TagSha
        $reference = Invoke-PSModulePublicationApi -Endpoint "repos/$($Claim.Repository)/git/refs" `
            -Method POST -Field @{ ref = "refs/tags/$versionTag"; sha = $claimSha } -AllowConflict
        if ($reference.StatusCode -ne 201 -and $reference.Value.message -cne 'Reference already exists') {
            throw "Cannot atomically reserve module/version [$versionTag] (HTTP $($reference.StatusCode))."
        }
        $current = Get-PSModulePublicationState -ExpectedClaim $Claim -Reader $Reader
        if ($null -ne $observedTagSha -and $current.TagSha -cne $observedTagSha) {
            throw 'The existing publication tag changed or disappeared during the shared module/version claim. Refusing publication.'
        }
        if ($null -eq $current.VersionTagSha -or
            ($reference.StatusCode -eq 201 -and $current.VersionTagSha -cne $claimSha)) {
            throw 'The module/version coordinate changed during its create-only claim. Refusing publication.'
        }
        $claimSha = $current.VersionTagSha
    }
    if ($null -eq $current.TagSha) {
        $reference = Invoke-PSModulePublicationApi -Endpoint "repos/$($Claim.Repository)/git/refs" `
            -Method POST -Field @{ ref = "refs/tags/$($Claim.ReleaseTag)"; sha = $claimSha } -AllowConflict
        if ($reference.StatusCode -ne 201 -and $reference.Value.message -cne 'Reference already exists') {
            throw "Cannot atomically create release tag [$($Claim.ReleaseTag)] (HTTP $($reference.StatusCode))."
        }
    }
    $verified = Get-PSModulePublicationState -ExpectedClaim $Claim -Reader $Reader
    if ($verified.TagSha -cne $claimSha -or $verified.VersionTagSha -cne $claimSha) {
        throw 'The release tag or shared module/version coordinate changed before publication.'
    }
    $verified
}
