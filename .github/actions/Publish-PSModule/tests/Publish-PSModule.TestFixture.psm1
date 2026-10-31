$ErrorActionPreference = 'Stop'

Import-Module -Name ([IO.Path]::Combine(
        $PSScriptRoot, '..', '..', 'Release-PSModule', 'src', 'Release-PSModule.Helpers.psm1'
    )) -Force

function New-PSModuleFixturePackage {
    <#
        .SYNOPSIS
        Create an anonymous raw nupkg from local fixture files without running a publisher.

        .EXAMPLE
        New-PSModuleFixturePackage -Path $module -DestinationPath $package -Version 1.2.4

        Package the local test payload and independent NuGet identity metadata.

        .INPUTS
        None

        You can't pipe objects to New-PSModuleFixturePackage.

        .OUTPUTS
        None

        This test helper creates only the named local nupkg.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        # The local module fixture.
        [Parameter(Mandatory)]
        [string] $Path,

        # The named local nupkg destination.
        [Parameter(Mandatory)]
        [string] $DestinationPath,

        # The exact fixture package version.
        [Parameter(Mandatory)]
        [string] $Version
    )

    if (-not $PSCmdlet.ShouldProcess($DestinationPath, 'Create local raw package fixture')) {
        return
    }
    $name = (Get-Item -LiteralPath $Path).Name
    $stream = [IO.File]::Create($DestinationPath)
    $archive = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($file in Get-ChildItem -LiteralPath $Path -File -Recurse -Force) {
            $relative = [IO.Path]::GetRelativePath($Path, $file.FullName).Replace('\', '/')
            $entryStream = $archive.CreateEntry($relative).Open()
            $fileStream = $file.OpenRead()
            try {
                $fileStream.CopyTo($entryStream)
            } finally {
                $fileStream.Dispose()
                $entryStream.Dispose()
            }
        }
        $writer = [IO.StreamWriter]::new($archive.CreateEntry("$name.nuspec").Open())
        try {
            $writer.Write("<package><metadata><id>$name</id><version>$Version</version></metadata></package>")
        } finally {
            $writer.Dispose()
        }
        $writer = [IO.StreamWriter]::new($archive.CreateEntry('[Content_Types].xml').Open())
        try {
            $writer.Write('<Types />')
        } finally {
            $writer.Dispose()
        }
    } finally {
        $archive.Dispose()
        $stream.Dispose()
    }
}

function Set-PSModuleFixtureClaim {
    <#
        .SYNOPSIS
        Set the exact annotated claim returned by the isolated GitHub reader.

        .EXAMPLE
        Set-PSModuleFixtureClaim -State $state -Claim $state.ExpectedClaim

        Arrange an existing exact-source tag, including its byte/context proof.

        .INPUTS
        None

        You can't pipe objects to Set-PSModuleFixtureClaim.

        .OUTPUTS
        None

        This helper changes only the in-memory test state.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        # The isolated command state.
        [Parameter(Mandatory)]
        [hashtable] $State,

        # The desired source/context/artifact claim.
        [Parameter(Mandatory)]
        [object] $Claim,

        # The immutable annotation object identity used by the fixture.
        [Parameter()]
        [string] $TagSha = '3333333333333333333333333333333333333333'
    )

    if (-not $PSCmdlet.ShouldProcess('Publication fixture', 'Set local annotated claim')) {
        return
    }
    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($Claim | ConvertTo-Json -Compress)))
    $State.Tag = @{ type = 'tag'; sha = $TagSha }
    $State.TagObject = @{
        sha     = $TagSha
        tag     = $Claim.ReleaseTag
        message = "<!-- PSModule.Publication:v1:$encoded -->"
        object  = @{ type = 'commit'; sha = $Claim.CommitSha }
    }
    $State.VersionTag = $State.Tag
    $State.VersionTagObject = $State.TagObject
}

function New-PSModulePublicationFixture {
    <#
        .SYNOPSIS
        Replace all publication read/write boundaries with isolated local state.

        .DESCRIPTION
        The fake API follows HTTP status, create-only refs, annotated tags, release
        metadata, and no-clobber uploads. Gallery packages are raw local nupkg fixtures.

        .EXAMPLE
        New-PSModulePublicationFixture -Path $module -Version 1.2.4 -Tag v1.2.4

        Return the shared write-spy state after replacing the external commands.

        .INPUTS
        None

        You can't pipe objects to New-PSModulePublicationFixture.

        .OUTPUTS
        System.Collections.Hashtable

        The mutable local fixture state and exact expected claim.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([hashtable])]
    param(
        # The already-created local tested module.
        [Parameter(Mandatory)]
        [string] $Path,

        # The exact resolved fixture Gallery version.
        [Parameter(Mandatory)]
        [string] $Version,

        # The exact resolved fixture GitHub tag.
        [Parameter(Mandatory)]
        [string] $Tag,

        # The producing PR, or zero for a direct stable release.
        [Parameter()]
        [long] $PullRequest = 0,

        # The immutable build source used by the anonymous fixture.
        [Parameter()]
        [string] $CommitSha = '1111111111111111111111111111111111111111',

        # The existing resolver prefix used by this fixture.
        [Parameter()]
        [string] $VersionPrefix = 'v'
    )

    if (-not $PSCmdlet.ShouldProcess($Path, 'Install local publication command replacements')) {
        return
    }
    $name = (Get-Item -LiteralPath $Path).Name
    $zipPath = Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath "$([guid]::NewGuid()).zip"
    try {
        $null = New-PSModuleReleaseArchive -Path $Path -DestinationPath $zipPath
        $assetDigest = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    } finally {
        if (Test-Path -LiteralPath $zipPath) {
            Remove-Item -LiteralPath $zipPath -Force
        }
    }
    $state = @{
        Calls                = [Collections.Generic.List[string]]::new()
        GalleryWrites        = 0
        GitHubWrites         = 0
        GitHubCreationUpload = 0
        Tag                  = $null
        TagObject            = $null
        VersionTag           = $null
        VersionTagObject     = $null
        NewTagObject         = $null
        Release              = $null
        Package              = $null
        RawPackage           = ''
        ApiError             = ''
        TagReads             = 0
        OnTagRead            = $null
        OnTagCreate          = $null
        OnVersionTagCreate   = $null
        OnGeneratedNotes     = $null
        FailReleaseCreate    = $false
        ExpectedClaim        = [pscustomobject]@{
            Repository     = "PSModule/$name"
            PullRequest    = $PullRequest
            CommitSha      = $CommitSha
            ModuleName     = $name
            GalleryVersion = $Version
            VersionPrefix  = $VersionPrefix
            ReleaseTag     = $Tag
            ReleaseType    = if ($Version.Contains('-')) { 'Prerelease' } else { 'Release' }
            ArtifactSha256 = Get-PSModuleArtifactDigest -Path $Path
            AssetName      = "$name-$Version.zip"
            AssetSha256    = $assetDigest
        }
    }
    Set-Item -Path function:global:Find-PSResource -Value {
        [CmdletBinding()]
        param(
            [string] $Name,
            [string] $Version,
            [string] $Repository,
            [switch] $Prerelease
        )
        if ($Name -ine $state.ExpectedClaim.ModuleName -or
            $Version -cne $state.ExpectedClaim.GalleryVersion -or $Repository -cne 'PSGallery' -or
            $Prerelease.IsPresent -ne ($state.ExpectedClaim.ReleaseType -ceq 'Prerelease')) {
            throw "Unexpected exact Gallery lookup: [$Name] [$Version] [$Repository]."
        }
        $state.Calls.Add('gallery-read')
        if ($null -ne $state.Package) {
            return $state.Package
        }
        Write-Error -Message 'The exact fixture package is absent.' -ErrorId PackageNotFound -Category ObjectNotFound
    }.GetNewClosure()
    Set-Item -Path function:global:Publish-PSResource -Value {
        $state.Calls.Add('gallery-write')
        $state.GalleryWrites++
    }.GetNewClosure()
    Set-Item -Path function:global:Save-PSResource -Value {
        [CmdletBinding()]
        param(
            [string] $Name,
            [string] $Version,
            [string] $Repository,
            [string] $Path,
            [switch] $AsNupkg,
            [switch] $SkipDependencyCheck,
            [switch] $TrustRepository,
            [switch] $Prerelease
        )
        if ($Name -ine $state.ExpectedClaim.ModuleName -or $Version -cne "[$($state.ExpectedClaim.GalleryVersion)]" -or
            $Repository -cne 'PSGallery' -or -not $AsNupkg -or -not $SkipDependencyCheck -or -not $TrustRepository -or
            $Prerelease.IsPresent -ne ($state.ExpectedClaim.ReleaseType -ceq 'Prerelease') -or
            -not (Test-Path -LiteralPath $state.RawPackage -PathType Leaf)) {
            throw 'The exact raw package fixture is unavailable; never download or import real packages for proof.'
        }
        Copy-Item -LiteralPath $state.RawPackage -Destination (Join-Path -Path $Path -ChildPath 'fixture.nupkg')
        $state.Calls.Add('raw-package-read')
    }.GetNewClosure()
    Set-Item -Path function:global:Invoke-WebRequest -Value {
        throw 'Unexpected network access in an isolated publication fixture.'
    }
    Set-Item -Path function:global:gh -Value {
        [CmdletBinding()]
        param(
            [Parameter(ValueFromRemainingArguments)]
            [string[]] $Arguments
        )
        $state.Calls.Add("github: $($Arguments -join ' ')")
        $global:LASTEXITCODE = 0
        $claim = $state.ExpectedClaim
        if ($Arguments[0] -ceq 'api') {
            if ($state.ApiError) {
                $global:LASTEXITCODE = 1
                return $state.ApiError
            }
            $endpoint = $Arguments[1]
            $status = 200
            $value = $null
            if ($Arguments -contains 'POST') {
                $state.GitHubWrites++
                $fields = @{}
                for ($index = 0; $index -lt $Arguments.Count - 1; $index++) {
                    if ($Arguments[$index] -ceq '--raw-field' -or $Arguments[$index] -ceq '--field') {
                        $pair = $Arguments[$index + 1].Split('=', 2)
                        $fields[$pair[0]] = $pair[1]
                    }
                }
                if ($endpoint -ceq "repos/$($claim.Repository)/git/tags") {
                    $state.Calls.Add('tag-object-create')
                    $value = @{
                        sha     = '3333333333333333333333333333333333333333'
                        tag     = $fields.tag
                        message = $fields.message
                        object  = @{ type = $fields.type; sha = $fields.object }
                    }
                    $state.NewTagObject = $value
                    $status = 201
                } elseif ($endpoint -ceq "repos/$($claim.Repository)/git/refs") {
                    $versionTagName = Get-PSModulePublicationVersionTag -ModuleName $claim.ModuleName -GalleryVersion $claim.GalleryVersion
                    $isVersionTag = $fields.ref -ceq "refs/tags/$versionTagName"
                    if ($isVersionTag) {
                        $state.Calls.Add('module-version-ref-create')
                        if ($null -ne $state.OnVersionTagCreate) { & $state.OnVersionTagCreate $state }
                        $existing = $state.VersionTag
                    } else {
                        $state.Calls.Add('tag-ref-create')
                        if ($null -ne $state.OnTagCreate) { & $state.OnTagCreate $state }
                        $existing = $state.Tag
                    }
                    if ($null -ne $existing) {
                        $status = 422
                        $global:LASTEXITCODE = 1
                        $value = @{ message = 'Reference already exists' }
                    } else {
                        $referenceObject = @{ type = 'tag'; sha = $fields.sha }
                        if ($isVersionTag) {
                            $state.VersionTag = $referenceObject
                            $state.VersionTagObject = if ($null -ne $state.NewTagObject) {
                                $state.NewTagObject
                            } else { $state.TagObject }
                        } else {
                            $state.Tag = $referenceObject
                            $state.TagObject = $state.VersionTagObject
                        }
                        $value = @{ ref = $fields.ref; object = $referenceObject }
                        $status = 201
                    }
                } elseif ($endpoint -ceq "repos/$($claim.Repository)/releases/generate-notes") {
                    if ($null -ne $state.OnGeneratedNotes) {
                        & $state.OnGeneratedNotes $state
                    }
                    $value = @{ body = 'Complete independently generated fixture notes.' }
                } else {
                    throw "Unexpected create API in the publication fixture: [$endpoint]."
                }
            } elseif ($endpoint -ceq "repos/$($claim.Repository)") {
                $value = @{ full_name = $claim.Repository; permissions = @{ push = $true } }
            } elseif ($endpoint -ceq "repos/$($claim.Repository)/git/commits/$($claim.CommitSha)") {
                $value = @{ sha = $claim.CommitSha }
            } elseif ($endpoint -like '*/git/ref/tags/*') {
                $tagName = [Uri]::UnescapeDataString(($endpoint -split '/git/ref/tags/', 2)[1])
                $versionTagName = Get-PSModulePublicationVersionTag -ModuleName $claim.ModuleName -GalleryVersion $claim.GalleryVersion
                if ($tagName -ceq $versionTagName) {
                    if ($null -ne $state.VersionTag) {
                        $value = @{ ref = "refs/tags/$versionTagName"; object = $state.VersionTag }
                    }
                } else {
                    $state.TagReads++
                    if ($null -ne $state.OnTagRead) { & $state.OnTagRead $state }
                    if ($null -ne $state.Tag) {
                        $value = @{ ref = "refs/tags/$($claim.ReleaseTag)"; object = $state.Tag }
                    }
                }
            } elseif ($endpoint -like '*/git/tags/*') {
                $sha = ($endpoint -split '/git/tags/', 2)[1]
                if ($null -ne $state.VersionTag -and $sha -ceq $state.VersionTag.sha) {
                    $value = $state.VersionTagObject
                } else {
                    $value = $state.TagObject
                }
            } elseif ($endpoint -like '*/releases/tags/*') {
                $value = $state.Release
            } else {
                throw "Unexpected read API in the publication fixture: [$endpoint]."
            }
            if ($null -eq $value) {
                $status = 404
                $global:LASTEXITCODE = 1
                $value = @{ message = 'Not Found' }
            }
            $json = $value | ConvertTo-Json -Depth 20 -Compress
            if ($Arguments -contains '--include') {
                return "HTTP/2.0 $status Fixture`n`n$json"
            }
            return $json
        }
        if ($Arguments[0] -ceq 'release' -and $Arguments[1] -ceq 'create') {
            $state.GitHubWrites++
            $state.GitHubCreationUpload++
            $state.Calls.Add('release-create')
            if ($state.FailReleaseCreate) {
                $global:LASTEXITCODE = 1
                return 'Injected GitHub release creation failure.'
            }
            $notes = ''
            $notesIndex = [array]::IndexOf($Arguments, '--notes-file')
            if ($notesIndex -ge 0) {
                $notes = [IO.File]::ReadAllText($Arguments[$notesIndex + 1])
            }
            $state.Release = [pscustomobject]@{
                id         = 10
                tag_name   = $claim.ReleaseTag
                html_url   = "https://github.com/$($claim.Repository)/releases/tag/$($claim.ReleaseTag)"
                prerelease = $claim.ReleaseType -ceq 'Prerelease'
                draft      = $false
                body       = $notes
                assets     = @()
            }
            return $state.Release.html_url
        }
        if ($Arguments[0] -ceq 'release' -and $Arguments[1] -ceq 'upload') {
            $state.GitHubWrites++
            $state.GitHubCreationUpload++
            $state.Calls.Add('asset-upload')
            if ($Arguments -contains '--clobber' -or $null -eq $state.Release -or @($state.Release.assets).Count -gt 0) {
                throw 'The fixture refuses missing-release uploads and replacement of published bytes.'
            }
            $path = $Arguments[3]
            $state.Release.assets = @([pscustomobject]@{
                    name   = [IO.Path]::GetFileName($path)
                    state  = 'uploaded'
                    digest = "sha256:$((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant())"
                })
            return
        }
        if ($Arguments[0] -ceq 'pr' -and $Arguments[1] -ceq 'comment') {
            $state.Calls.Add('pr-comment')
            return
        }
        throw "Unexpected command in the isolated publication fixture: $($Arguments -join ' ')."
    }.GetNewClosure()
    $state
}
