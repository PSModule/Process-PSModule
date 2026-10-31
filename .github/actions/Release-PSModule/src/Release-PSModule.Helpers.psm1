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
        if ($Body -match '(?:^|\r?\n)<!-- PSModule\.PrereleaseOwner:[^\r\n]*\s*\z') {
            throw 'The published ownership footer is malformed or uses an unsupported provenance version.'
        }
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

function Get-PSModuleProducingPullRequestNumber {
    <#
        .SYNOPSIS
        Validate the producing PR identity or a genuinely absent direct-release context.

        .EXAMPLE
        Get-PSModuleProducingPullRequestNumber -PullRequest $pullRequest

        Return a positive PR number, or zero only when no PR context was supplied.

        .INPUTS
        None

        You can't pipe objects to Get-PSModuleProducingPullRequestNumber.

        .OUTPUTS
        System.Int64

        The validated producing PR number, or zero for absent context.
    #>
    [CmdletBinding()]
    [OutputType([long])]
    param(
        # The normalized producing context, or null for a direct release.
        [Parameter()]
        [AllowNull()]
        [object] $PullRequest
    )

    if ($null -eq $PullRequest) {
        return 0L
    }
    $number = 0L
    if ($PullRequest -is [array] -or
        ($PullRequest -isnot [PSCustomObject] -and $PullRequest -isnot [Collections.IDictionary]) -or
        -not [long]::TryParse([string]$PullRequest.Number, [ref]$number) -or $number -lt 1) {
        throw 'Supplied pull request context requires a positive producing pull request number.'
    }
    $number
}

function Get-PSModuleReleaseOwnership {
    <#
        .SYNOPSIS
        Verify a release footer against its repository, producing PR, and immutable source.

        .DESCRIPTION
        Uses the canonical final-footer reader. Matching tag/source alone does not
        authorize another pull request's release, and missing proof remains an error.

        .EXAMPLE
        Get-PSModuleReleaseOwnership -Body $body -Repository $repository -PullRequest 42 -CommitSha $source

        Return the proven producing context or stop before a mutation.

        .INPUTS
        None

        You can't pipe objects to Get-PSModuleReleaseOwnership.

        .OUTPUTS
        System.Management.Automation.PSCustomObject

        The verified release ownership.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        # The expected base repository.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Repository,

        # The expected producing pull request.
        [Parameter(Mandatory)]
        [ValidateRange(1, [long]::MaxValue)]
        [long] $PullRequest,

        # The original build commit.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $CommitSha,

        # The complete existing release notes.
        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string] $Body
    )

    $ownership = Get-PSModulePrereleaseOwnership -Body $Body
    if ($null -eq $ownership) {
        throw 'The existing release has no verifiable repository/pull request/source ownership footer.'
    }
    if ($ownership.Repository -ine $Repository -or $ownership.CommitSha -cne $CommitSha) {
        throw 'The existing release ownership footer belongs to a different repository or immutable source.'
    }
    if ($ownership.PullRequest -ne $PullRequest) {
        throw "The existing release belongs to pull request [$($ownership.PullRequest)], not [$PullRequest]."
    }
    $ownership
}

function Get-PSModulePublicationClaim {
    <#
        .SYNOPSIS
        Read the final versioned source-and-artifact claim from an annotated tag.

        .DESCRIPTION
        The footer binds the repository, PR or direct-release context, resolved
        coordinates, tested file tree, and exact ZIP bytes. Legacy tags provide no proof.

        .EXAMPLE
        Get-PSModulePublicationClaim -Message $tag.message

        Return the validated claim without using numeric equality or mutable hints.

        .INPUTS
        None

        You can't pipe objects to Get-PSModulePublicationClaim.

        .OUTPUTS
        System.Management.Automation.PSCustomObject

        The publication claim, when present.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        # The full annotated tag message.
        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string] $Message
    )

    $match = [regex]::Match($Message, '(?:^|\r?\n)<!-- PSModule\.Publication:v1:([A-Za-z0-9+/=]+) -->\s*\z')
    if (-not $match.Success) {
        if ($Message -match 'PSModule\.Publication:') {
            throw 'The publication claim footer is malformed or uses an unsupported proof version.'
        }
        return
    }
    $bytes = [Convert]::FromBase64String($match.Groups[1].Value)
    $claim = [Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json -ErrorAction Stop
    $number = 0L
    if ($claim.Repository -notmatch '^[^/\s]+/[^/\s]+$' -or
        -not [long]::TryParse([string]$claim.PullRequest, [ref]$number) -or $number -lt 0 -or
        $claim.CommitSha -notmatch '^[0-9a-f]{40}$' -or
        $claim.ModuleName -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*$' -or
        $claim.GalleryVersion -notmatch '^\d+\.\d+\.\d+(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$' -or
        [string]::IsNullOrWhiteSpace($claim.ReleaseTag) -or
        $claim.ReleaseTag -match '[\s\x00-\x1f\x7f]' -or
        $claim.ReleaseTag -match '(^|/)\.|[~^:?*\[\\]|\.\.|@\{|//|/$|\.lock(?:/|$)|\.$' -or
        $claim.ReleaseType -cnotin @('Release', 'Prerelease') -or
        $claim.ArtifactSha256 -notmatch '^[0-9A-Fa-f]{64}$' -or
        $claim.AssetSha256 -notmatch '^[0-9A-Fa-f]{64}$' -or
        $claim.AssetName -cne "$($claim.ModuleName)-$($claim.GalleryVersion).zip") {
        throw 'The publication claim has invalid source, release context, coordinates, or artifact proof.'
    }
    $isPrerelease = $claim.GalleryVersion.Contains('-')
    if (($claim.ReleaseType -ceq 'Prerelease') -ne $isPrerelease) {
        throw 'The publication claim release type disagrees with its resolved module version.'
    }
    [pscustomobject]@{
        Repository     = [string]$claim.Repository
        PullRequest    = $number
        CommitSha      = [string]$claim.CommitSha
        ModuleName     = [string]$claim.ModuleName
        GalleryVersion = [string]$claim.GalleryVersion
        ReleaseTag     = [string]$claim.ReleaseTag
        ReleaseType    = [string]$claim.ReleaseType
        ArtifactSha256 = ([string]$claim.ArtifactSha256).ToLowerInvariant()
        AssetName      = [string]$claim.AssetName
        AssetSha256    = ([string]$claim.AssetSha256).ToLowerInvariant()
    }
}

function Get-PSModuleArtifactFile {
    <#
        .SYNOPSIS
        Enumerate the tested module files without following links.

        .EXAMPLE
        Get-PSModuleArtifactFile -Path $modulePath

        Return each file's exact relative path and full local path.

        .INPUTS
        None

        You can't pipe objects to Get-PSModuleArtifactFile.

        .OUTPUTS
        System.Management.Automation.PSCustomObject

        The module file records.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        # The absolute tested module directory.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    $directory = Get-Item -LiteralPath $Path -ErrorAction Stop
    if (-not $directory.PSIsContainer -or $directory.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw 'The tested module root is not a verifiable directory or contains a link.'
    }
    $root = $directory.FullName
    $items = @(Get-ChildItem -LiteralPath $root -Recurse -Force -ErrorAction Stop)
    if ($items | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }) {
        throw 'The tested artifact contains a link. Refusing to infer the published file tree.'
    }
    $files = @($items | Where-Object { -not $_.PSIsContainer })
    if ($files.Count -eq 0) {
        throw 'The tested module artifact contains no files.'
    }
    foreach ($file in $files) {
        $relativePath = [IO.Path]::GetRelativePath($root, $file.FullName)
        $relativePath = $relativePath.Replace([IO.Path]::DirectorySeparatorChar, [char]'/')
        if ($relativePath.Contains('\')) {
            throw 'The tested artifact contains a literal filename backslash. Refusing to rename its published file tree.'
        }
        [pscustomobject]@{
            RelativePath = $relativePath
            FullName     = $file.FullName
        }
    }
}

function Get-PSModuleContentDigest {
    <#
        .SYNOPSIS
        Hash exact file paths, lengths, and SHA-256 content hashes.

        .DESCRIPTION
        Length-prefixed records are sorted ordinally. Archive timestamps and generated
        NuGet metadata are not part of the tested file-tree identity.

        .EXAMPLE
        Get-PSModuleContentDigest -File $files

        Return the deterministic file-tree SHA-256.

        .INPUTS
        None

        You can't pipe objects to Get-PSModuleContentDigest.

        .OUTPUTS
        System.String

        The lowercase SHA-256 of the file records.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        # Exact relative paths, byte lengths, and raw SHA-256 hashes.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [object[]] $File
    )

    $records = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
    $portablePaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($item in $File) {
        $relativePath = [string]$item.RelativePath
        if ([string]::IsNullOrWhiteSpace($relativePath) -or $relativePath -match '[\\\x00-\x1f\x7f:]' -or
            $relativePath.StartsWith('/') -or $relativePath.Split('/') -contains '..' -or
            $relativePath.Split('/') -contains '.' -or $relativePath.Split('/') -contains '' -or
            -not $portablePaths.Add($relativePath) -or $item.Hash.Length -ne 32 -or $item.Length -lt 0) {
            throw "The artifact has an invalid or ambiguous file path/content record [$relativePath]."
        }
        $records.Add($relativePath, $item)
    }
    $paths = [Collections.Generic.List[string]]::new($records.Keys)
    $paths.Sort([StringComparer]::Ordinal)
    $stream = [IO.MemoryStream]::new()
    $writer = [IO.BinaryWriter]::new($stream, [Text.UTF8Encoding]::new($false), $true)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
        $writer.Write([int]$paths.Count)
        foreach ($relativePath in $paths) {
            $item = $records[$relativePath]
            $writer.Write($relativePath)
            $writer.Write([long]$item.Length)
            $writer.Write([byte[]]$item.Hash)
        }
        $writer.Flush()
        $stream.Position = 0
        [BitConverter]::ToString($sha256.ComputeHash($stream)).Replace('-', '').ToLowerInvariant()
    } finally {
        $sha256.Dispose()
        $writer.Dispose()
        $stream.Dispose()
    }
}

function Get-PSModuleArtifactDigest {
    <#
        .SYNOPSIS
        Compute the tested module's exact file-tree identity.

        .EXAMPLE
        Get-PSModuleArtifactDigest -Path $modulePath

        Return a digest without modifying or importing module files.

        .INPUTS
        None

        You can't pipe objects to Get-PSModuleArtifactDigest.

        .OUTPUTS
        System.String

        The lowercase tested file-tree SHA-256.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        # The tested module directory.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    $records = [Collections.Generic.List[object]]::new()
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
        foreach ($file in Get-PSModuleArtifactFile -Path $Path) {
            $stream = [IO.File]::OpenRead($file.FullName)
            try {
                $records.Add([pscustomobject]@{
                        RelativePath = $file.RelativePath
                        Length       = $stream.Length
                        Hash         = $sha256.ComputeHash($stream)
                    })
            } finally {
                $stream.Dispose()
            }
        }
    } finally {
        $sha256.Dispose()
    }
    Get-PSModuleContentDigest -File $records.ToArray()
}

function New-PSModuleReleaseArchive {
    <#
        .SYNOPSIS
        Package the tested module into repeatable ZIP bytes.

        .DESCRIPTION
        Uses ordinal file order, fixed ZIP timestamps, and no host-specific attributes.
        Retries of the same tested files therefore compare exact published asset bytes.

        .EXAMPLE
        New-PSModuleReleaseArchive -Path $modulePath -DestinationPath $zipPath

        Create the local release asset without modifying the module.

        .INPUTS
        None

        You can't pipe objects to New-PSModuleReleaseArchive.

        .OUTPUTS
        System.IO.FileInfo

        The newly created ZIP.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([IO.FileInfo])]
    param(
        # The tested module directory.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        # A new absolute ZIP path in the controller's temporary directory.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $DestinationPath
    )

    $files = @(Get-PSModuleArtifactFile -Path $Path)
    $records = [Collections.Generic.Dictionary[string, string]]::new([StringComparer]::Ordinal)
    foreach ($file in $files) {
        $records.Add($file.RelativePath, $file.FullName)
    }
    $paths = [Collections.Generic.List[string]]::new($records.Keys)
    $paths.Sort([StringComparer]::Ordinal)
    if (-not $PSCmdlet.ShouldProcess($DestinationPath, 'Create tested module ZIP')) {
        return
    }
    $name = (Get-Item -LiteralPath $Path -ErrorAction Stop).Name
    $stream = [IO.File]::Open($DestinationPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write)
    $archive = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($relativePath in $paths) {
            $entry = $archive.CreateEntry("$name/$relativePath", [IO.Compression.CompressionLevel]::Optimal)
            $entry.LastWriteTime = [DateTimeOffset]::new(1980, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
            $entry.ExternalAttributes = 0
            $inputStream = [IO.File]::OpenRead($records[$relativePath])
            $outputStream = $entry.Open()
            try {
                $inputStream.CopyTo($outputStream)
            } finally {
                $outputStream.Dispose()
                $inputStream.Dispose()
            }
        }
    } finally {
        $archive.Dispose()
        $stream.Dispose()
    }
    [IO.FileInfo]::new($DestinationPath)
}

function Get-PSModulePackageArtifactDigest {
    <#
        .SYNOPSIS
        Verify an exact Gallery nupkg's identity and tested file-tree digest.

        .DESCRIPTION
        Reads ZIP streams and a DTD-disabled nuspec without extracting or importing
        package code. Only standard generated NuGet container metadata is excluded.

        .EXAMPLE
        Get-PSModulePackageArtifactDigest -Path $package -ModuleName TestModule -GalleryVersion 1.2.4

        Return the package payload digest after checking its name and exact version.

        .INPUTS
        None

        You can't pipe objects to Get-PSModulePackageArtifactDigest.

        .OUTPUTS
        System.String

        The lowercase file-tree SHA-256 of the package payload.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        # The exact raw nupkg, never an installed module.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        # The expected Gallery package name.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ModuleName,

        # The resolved Gallery version, including a prerelease label when present.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $GalleryVersion
    )

    $archive = [IO.Compression.ZipFile]::OpenRead($Path)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
        $nuspecs = @($archive.Entries | Where-Object { $_.FullName -match '^[^/\\]+\.nuspec$' })
        if ($nuspecs.Count -ne 1) {
            throw 'The Gallery package has missing or ambiguous nuspec identity metadata.'
        }
        $settings = [Xml.XmlReaderSettings]::new()
        $settings.DtdProcessing = [Xml.DtdProcessing]::Prohibit
        $settings.XmlResolver = $null
        $stream = $nuspecs[0].Open()
        $reader = [Xml.XmlReader]::Create($stream, $settings)
        try {
            $document = [Xml.XmlDocument]::new()
            $document.XmlResolver = $null
            $document.Load($reader)
        } finally {
            $reader.Dispose()
            $stream.Dispose()
        }
        $metadata = $document.SelectSingleNode("/*[local-name()='package']/*[local-name()='metadata']")
        if ($null -eq $metadata) {
            throw 'The Gallery package is missing its nuspec identity metadata.'
        }
        $ids = @($metadata.SelectNodes("*[local-name()='id']"))
        $versions = @($metadata.SelectNodes("*[local-name()='version']"))
        if ($ids.Count -ne 1 -or $versions.Count -ne 1) {
            throw 'The Gallery package has missing or ambiguous name/version identity metadata.'
        }
        $id = $ids[0].InnerText
        $version = $versions[0].InnerText
        if ($id -ine $ModuleName -or $version -cne $GalleryVersion) {
            throw "The raw Gallery package identity [$id] [$version] does not match [$ModuleName] [$GalleryVersion]."
        }
        $records = [Collections.Generic.List[object]]::new()
        foreach ($entry in $archive.Entries) {
            $relativePath = $entry.FullName
            if ($relativePath.EndsWith('/')) {
                continue
            }
            if ($relativePath -ceq $nuspecs[0].FullName -or $relativePath -ceq '[Content_Types].xml' -or
                $relativePath -ceq '_rels/.rels' -or $relativePath -ceq '.signature.p7s' -or
                $relativePath -cmatch '^package/services/metadata/core-properties/[0-9a-f]+\.psmdcp$') {
                continue
            }
            $stream = $entry.Open()
            try {
                $records.Add([pscustomobject]@{
                        RelativePath = $relativePath
                        Length       = $entry.Length
                        Hash         = $sha256.ComputeHash($stream)
                    })
            } finally {
                $stream.Dispose()
            }
        }
        if ($records.Count -eq 0) {
            throw 'The Gallery package has no verifiable module payload files.'
        }
        Get-PSModuleContentDigest -File $records.ToArray()
    } finally {
        $sha256.Dispose()
        $archive.Dispose()
    }
}
