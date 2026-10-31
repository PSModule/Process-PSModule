#Requires -Version 7.0
#Requires -Modules PSModule

<#
    .SYNOPSIS
    Creates or resumes a GitHub release for a versioned PowerShell module artifact.

    .DESCRIPTION
    Validates the supplied module artifact, creates a GitHub release when its tag does not
    already exist, uploads the artifact ZIP, and reports the result on the source pull request.

    .EXAMPLE
    ./release.ps1

    Creates or resumes the release using inputs supplied by the Release-PSModule action.

    .INPUTS
    None. The Release-PSModule composite action supplies values through environment variables.

    .OUTPUTS
    None. The script writes ReleaseTag and ReleaseUrl to the GitHub Actions output file.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', 'usePRBodyAsReleaseNotes',
    Justification = 'Variable is used in script blocks.'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', 'usePRTitleAsReleaseName',
    Justification = 'Variable is used in script blocks.'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', 'usePRTitleAsNotesHeading',
    Justification = 'Variable is used in script blocks.'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', 'prHeadRef',
    Justification = 'Variable is used in script blocks.'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', 'commitSha',
    Justification = 'Variable is used in script blocks.'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', 'releaseType',
    Justification = 'Variable is used in script blocks.'
)]
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$PSStyle.OutputRendering = 'Ansi'

Import-Module -Name 'PSModule' -Force
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'Release-PSModule.Helpers.psm1') -Force
Import-Module -Name ([IO.Path]::Combine(
        $PSScriptRoot, '..', '..', 'Publish-PSModule', 'src', 'Publish-PSModule.Helpers.psm1'
    )) -Force

LogGroup 'Load inputs' {
    $env:GITHUB_REPOSITORY_NAME = $env:GITHUB_REPOSITORY -replace '.+/'

    $name = if ([string]::IsNullOrEmpty($env:PSMODULE_RELEASE_PSMODULE_INPUT_Name)) {
        $env:GITHUB_REPOSITORY_NAME
    } else {
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_Name
    }
    # Normalize to an absolute path anchored at the workspace root so that
    # the resolved location agrees with where actions/download-artifact writes
    # the artifact (workspace-root-relative), regardless of WorkingDirectory.
    $modulePathInput = $env:PSMODULE_RELEASE_PSMODULE_INPUT_ModulePath
    $modulePathCandidate = if ([System.IO.Path]::IsPathRooted($modulePathInput)) {
        Join-Path -Path $modulePathInput -ChildPath $name
    } else {
        Join-Path -Path $env:GITHUB_WORKSPACE -ChildPath $modulePathInput -AdditionalChildPath $name
    }
    if (-not (Test-Path -Path $modulePathCandidate -PathType Container)) {
        Write-Error ("Module directory not found at [$modulePathCandidate]. " +
            'Ensure the artifact contains a <ModulePath>/<Name>/ subdirectory layout.')
        exit 1
    }
    $modulePath = Resolve-Path -Path $modulePathCandidate | Select-Object -ExpandProperty Path
    $whatIf = $env:PSMODULE_RELEASE_PSMODULE_INPUT_WhatIf -eq 'true'
    $usePRBodyAsReleaseNotes = $env:PSMODULE_RELEASE_PSMODULE_INPUT_UsePRBodyAsReleaseNotes -eq 'true'
    $usePRTitleAsReleaseName = $env:PSMODULE_RELEASE_PSMODULE_INPUT_UsePRTitleAsReleaseName -eq 'true'
    $usePRTitleAsNotesHeading = $env:PSMODULE_RELEASE_PSMODULE_INPUT_UsePRTitleAsNotesHeading -eq 'true'
    $releaseTag = $env:PSMODULE_RELEASE_PSMODULE_INPUT_ReleaseTag
    $versionPrefix = $env:PSMODULE_RELEASE_PSMODULE_INPUT_VersionPrefix
    $commitSha = $env:PSMODULE_RELEASE_PSMODULE_INPUT_CommitSha
    if ([string]::IsNullOrWhiteSpace($releaseTag)) {
        throw 'ReleaseTag is required. Ensure Publish.Module.Resolution.FullVersion is passed from the Plan job.'
    }

    Write-Host "Module name: [$name]"
    Write-Host "Version prefix: [$versionPrefix]"
    Write-Host "Module path: [$modulePath]"
    Write-Host "Release tag: [$releaseTag]"
    Write-Host "WhatIf:      [$whatIf]"
}

LogGroup 'Load release context' {
    $githubEventJson = Get-Content -Raw $env:GITHUB_EVENT_PATH
    $githubEvent = ConvertFrom-Json -InputObject $githubEventJson -NoEnumerate -ErrorAction Stop
    if ($githubEvent -is [array] -or $githubEvent -isnot [PSCustomObject]) {
        throw 'The original GitHub event context requires one event object.'
    }
    $pullRequestJson = $env:PSMODULE_RELEASE_PSMODULE_INPUT_PullRequest
    $pullRequest = $null
    if (-not [string]::IsNullOrWhiteSpace($pullRequestJson) -and $pullRequestJson -ne 'null') {
        $pullRequest = ConvertFrom-Json -InputObject $pullRequestJson -NoEnumerate -ErrorAction Stop
    } else {
        $eventPullRequest = $githubEvent.pull_request
        $null = Get-PSModuleProducingPullRequestNumber -PullRequest $eventPullRequest
        if ($null -ne $eventPullRequest) {
            $pullRequest = [pscustomobject]@{
                Number  = $eventPullRequest.number
                Title   = $eventPullRequest.title
                Body    = $eventPullRequest.body
                HeadRef = $eventPullRequest.head.ref
            }
        }
    }
    $prNumber = Get-PSModuleProducingPullRequestNumber -PullRequest $pullRequest
    foreach ($field in @('Title', 'Body', 'HeadRef')) {
        if ($null -ne $pullRequest.$field -and $pullRequest.$field -isnot [string]) {
            throw "Supplied release context requires scalar string metadata for [$field]."
        }
    }
    $prHeadRef = $pullRequest.HeadRef
    $commitMessage = $githubEvent.head_commit.message
    if ([string]::IsNullOrWhiteSpace($commitMessage) -and -not [string]::IsNullOrWhiteSpace($commitSha)) {
        $commitMessage = git log -1 --format=%B $commitSha
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to read commit message for [$commitSha]."
        }
    }

    if ($prNumber) {
        Write-Host "Pull request: [#$prNumber]"
    } else {
        Write-Host 'No pull request context is available; using the pushed commit message for release notes.'
    }
}

LogGroup 'Resolve version from manifest' {
    Add-PSModulePath -Path (Split-Path -Path $modulePath -Parent)
    $manifestFilePath = Join-Path -Path $modulePath -ChildPath "$name.psd1"
    Write-Host "Module manifest file path: [$manifestFilePath]"
    if (-not (Test-Path -Path $manifestFilePath)) {
        Write-Error "Module manifest file not found at [$manifestFilePath]"
        exit 1
    }

    Show-FileContent -Path $manifestFilePath

    $manifest = Test-ModuleManifest -Path $manifestFilePath -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    if ($manifest) {
        Write-Host "Manifest validated: [$($manifest.Name)] v[$($manifest.Version)]"
    } else {
        Write-Host '::warning::Test-ModuleManifest returned warnings (e.g. unresolved RequiredModules). Continuing with data-file validation.'
    }

    $manifestData = Import-PowerShellDataFile -Path $manifestFilePath -ErrorAction Stop
    $moduleVersion = $manifestData.ModuleVersion
    if (-not ($moduleVersion -match '^\d+\.\d+\.\d+$')) {
        throw ("ModuleVersion [$moduleVersion] must be in Major.Minor.Patch format. " +
            'Ensure Build-PSModule has stamped the artifact with a final version.')
    }
    if ($moduleVersion -eq '999.0.0') {
        throw ('ModuleVersion is the placeholder [999.0.0]. ' +
            'The artifact was not stamped with a real version by the build step.')
    }
    $prerelease = $manifestData.PrivateData.PSData.Prerelease
    if ([string]::IsNullOrWhiteSpace($prerelease)) {
        $prerelease = ''
        $createPrerelease = $false
    } else {
        if ($prerelease -notmatch '^[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*$') {
            throw ("Prerelease label [$prerelease] is not a valid SemVer prerelease identifier. " +
                'It must contain only alphanumerics, hyphens, and dots as separators.')
        }
        $createPrerelease = $true
    }

    $releaseType = if ($createPrerelease) { 'New prerelease' } else { 'New release' }
    $publishPSVersion = if ($createPrerelease) { "$moduleVersion-$prerelease" } else { $moduleVersion }

    Write-Host (
        [PSCustomObject]@{
            ModuleVersion    = $moduleVersion
            Prerelease       = $prerelease
            CreatePrerelease = $createPrerelease
            GalleryVersion   = $publishPSVersion
            ReleaseTag       = $releaseTag
            PRNumber         = $prNumber
            PRHeadRef        = $prHeadRef
            CommitSha        = $commitSha
        } | Format-List | Out-String
    )
}

# A zip of the built module is uploaded so the GitHub Release page exposes the exact bytes.
LogGroup 'Create GitHub release' {
    $releaseCreateCommand = @('release', 'create', $releaseTag, '--repo', $env:GITHUB_REPOSITORY, '--verify-tag')
    $notesFilePath = $null
    $releaseExists = $false
    $sourceCommit = if (-not [string]::IsNullOrWhiteSpace($commitSha)) { $commitSha } else { $env:GITHUB_SHA }
    $zipFileName = "$name-$publishPSVersion.zip"
    $zipDirectory = Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath "PSModuleRelease-$([guid]::NewGuid())"
    $zipPath = Join-Path -Path $zipDirectory -ChildPath $zipFileName
    try {
        if (-not $whatIf) {
            $null = New-Item -Path $zipDirectory -ItemType Directory
            $null = New-PSModuleReleaseArchive -Path $modulePath -DestinationPath $zipPath
            $claim = [pscustomobject]@{
                Repository     = $env:GITHUB_REPOSITORY
                PullRequest    = if ($null -eq $prNumber) { 0 } else { $prNumber }
                CommitSha      = $sourceCommit
                ModuleName     = $name
                GalleryVersion = $publishPSVersion
                VersionPrefix  = $versionPrefix
                ReleaseTag     = $releaseTag
                ReleaseType    = if ($createPrerelease) { 'Prerelease' } else { 'Release' }
                ArtifactSha256 = Get-PSModuleArtifactDigest -Path $modulePath
                AssetName      = $zipFileName
                AssetSha256    = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
            }
            $archiveProof = Get-PSModuleReleaseArchiveProof -Path $zipPath -ModuleName $name
            if ($archiveProof.ArtifactSha256 -cne $claim.ArtifactSha256 -or
                $archiveProof.AssetSha256 -cne $claim.AssetSha256) {
                throw 'The release archive does not match the tested file-tree and asset claim. Refusing publication.'
            }
            $publicationReader = Get-PSModulePublicationReader -Repository $env:GITHUB_REPOSITORY
            $publicationState = Get-PSModulePublicationState -ExpectedClaim $claim -Reader $publicationReader
            $archiveProof = Get-PSModuleReleaseArchiveProof -Path $zipPath -ModuleName $name
            if ($archiveProof.ArtifactSha256 -cne $claim.ArtifactSha256 -or
                $archiveProof.AssetSha256 -cne $claim.AssetSha256 -or
                (Get-PSModuleArtifactDigest -Path $modulePath) -cne $claim.ArtifactSha256) {
                throw 'The tested artifact or release archive changed before the immutable claim. Refusing publication.'
            }
            $publicationState = New-PSModulePublicationTag -Claim $claim -State $publicationState -Reader $publicationReader
            $releaseExists = $null -ne $publicationState.Release
            if ($releaseExists) {
                $releaseURL = $publicationState.Release.html_url
                Write-Host "GitHub release [$releaseTag] already belongs to this source and artifact. Resuming its upload."
            }
        }

        if (-not $releaseExists) {
            if ($usePRTitleAsReleaseName -and $pullRequest.Title) {
                $releaseCreateCommand += @('--title', $pullRequest.Title)
                Write-Host "Using PR title as release name: [$($pullRequest.Title)]"
            } else {
                $releaseCreateCommand += @('--title', $releaseTag)
            }

            # Build release notes content. Uses a file to preserve special characters.
            if ($usePRTitleAsNotesHeading -and $usePRBodyAsReleaseNotes -and $pullRequest.Title -and $pullRequest.Body) {
                $notes = "# $($pullRequest.Title) (#$prNumber)`n`n$($pullRequest.Body)"
                $notesFilePath = [System.IO.Path]::GetTempFileName()
                Set-Content -Path $notesFilePath -Value $notes -Encoding utf8
                $releaseCreateCommand += @('--notes-file', $notesFilePath)
                Write-Host 'Using PR title as H1 heading with link and body as release notes'
            } elseif ($usePRBodyAsReleaseNotes -and $pullRequest.Body) {
                $notesFilePath = [System.IO.Path]::GetTempFileName()
                Set-Content -Path $notesFilePath -Value $pullRequest.Body -Encoding utf8
                $releaseCreateCommand += @('--notes-file', $notesFilePath)
                Write-Host 'Using PR body as release notes'
            } elseif (-not [string]::IsNullOrWhiteSpace($commitMessage)) {
                $notesFilePath = [System.IO.Path]::GetTempFileName()
                Set-Content -Path $notesFilePath -Value $commitMessage -Encoding utf8
                $releaseCreateCommand += @('--notes-file', $notesFilePath)
                Write-Host 'Using the pushed commit message as release notes'
            } else {
                $releaseCreateCommand += @('--generate-notes')
            }

            if ([string]::IsNullOrWhiteSpace($sourceCommit)) {
                throw 'CommitSha or the original GITHUB_SHA is required to target the exact tested source.'
            }
            $releaseCreateCommand += @('--target', $sourceCommit)
            if ($createPrerelease) {
                $releaseCreateCommand += '--prerelease'
            }
            if ($prNumber) {
                $ownership = [pscustomobject]@{
                    Repository  = $env:GITHUB_REPOSITORY
                    PullRequest = [long]$prNumber
                    CommitSha   = $sourceCommit
                } | ConvertTo-Json -Compress
                $encodedOwnership = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($ownership))
                $ownershipFooter = "<!-- PSModule.PrereleaseOwner:v1:$encodedOwnership -->"
                if ($null -eq $notesFilePath) {
                    if ($whatIf) {
                        Write-Host (
                            "WhatIf: gh api repos/$env:GITHUB_REPOSITORY/releases/generate-notes --method POST " +
                            "--field tag_name=$releaseTag --field target_commitish=$sourceCommit"
                        )
                        $generatedBody = ''
                    } else {
                        $generatedNotes = gh api "repos/$env:GITHUB_REPOSITORY/releases/generate-notes" --method POST `
                            --field "tag_name=$releaseTag" --field "target_commitish=$sourceCommit"
                        if ($LASTEXITCODE -ne 0) {
                            throw "Cannot generate release notes (gh exited $LASTEXITCODE)."
                        }
                        $generated = ConvertFrom-Json -InputObject ($generatedNotes -join "`n") -NoEnumerate -ErrorAction Stop
                        if ($generated -isnot [PSCustomObject] -or $generated -is [array] -or $generated.body -isnot [string]) {
                            throw 'Generated release notes have no scalar body. Refusing incomplete notes.'
                        }
                        $generatedBody = $generated.body
                    }
                    $notesFilePath = [IO.Path]::GetTempFileName()
                    Set-Content -LiteralPath $notesFilePath -Value $generatedBody -Encoding utf8
                    $releaseCreateCommand = @($releaseCreateCommand | Where-Object { $_ -ne '--generate-notes' })
                    $releaseCreateCommand += @('--notes-file', $notesFilePath)
                }
                Add-Content -LiteralPath $notesFilePath -Value "`n$ownershipFooter" -Encoding utf8
            }

            try {
                if ($whatIf) {
                    Write-Host "WhatIf: gh $($releaseCreateCommand -join ' ')"
                    $releaseURL = "https://github.com/$env:GITHUB_REPOSITORY/releases/tag/$releaseTag"
                } else {
                    $beforeCreate = Get-PSModulePublicationState -ExpectedClaim $claim -Reader $publicationReader
                    $archiveProof = Get-PSModuleReleaseArchiveProof -Path $zipPath -ModuleName $name
                    if ($beforeCreate.TagSha -cne $publicationState.TagSha -or
                        $beforeCreate.VersionTagSha -cne $publicationState.VersionTagSha -or
                        $archiveProof.ArtifactSha256 -cne $claim.ArtifactSha256 -or
                        $archiveProof.AssetSha256 -cne $claim.AssetSha256 -or
                        (Get-PSModuleArtifactDigest -Path $modulePath) -cne $claim.ArtifactSha256) {
                        throw 'The source claim or tested artifact changed before release creation. Refusing publication.'
                    }
                    if ($null -ne $beforeCreate.Release) {
                        $releaseURL = $beforeCreate.Release.html_url
                        Write-Host 'An identical owned release appeared during notes preparation; retaining it.'
                    } else {
                        $releaseURL = gh @releaseCreateCommand
                        if ($LASTEXITCODE -ne 0) {
                            throw "Failed to create the release [$releaseTag]."
                        }
                    }
                }
            } finally {
                if ($notesFilePath -and (Test-Path -Path $notesFilePath)) {
                    Remove-Item -Path $notesFilePath -Force
                }
            }
        }

        if ($whatIf) {
            Write-Host "WhatIf: New-PSModuleReleaseArchive -Path $modulePath -DestinationPath $zipPath"
            Write-Host "WhatIf: gh release upload $releaseTag $zipPath --repo $env:GITHUB_REPOSITORY"
        } else {
            $currentState = Get-PSModulePublicationState -ExpectedClaim $claim -Reader $publicationReader
            $archiveProof = Get-PSModuleReleaseArchiveProof -Path $zipPath -ModuleName $name
            if ($currentState.TagSha -cne $publicationState.TagSha -or $null -eq $currentState.Release -or
                $currentState.VersionTagSha -cne $publicationState.VersionTagSha -or
                $archiveProof.ArtifactSha256 -cne $claim.ArtifactSha256 -or
                $archiveProof.AssetSha256 -cne $claim.AssetSha256 -or
                (Get-PSModuleArtifactDigest -Path $modulePath) -cne $claim.ArtifactSha256) {
                throw 'The release tag, release context, or tested artifact changed before upload. Refusing publication.'
            }
            if (@($currentState.Release.assets).Count -eq 0) {
                gh release upload $releaseTag $zipPath --repo $env:GITHUB_REPOSITORY
                if ($LASTEXITCODE -ne 0) {
                    throw "Failed to upload module artifact to release [$releaseTag]."
                }
                Write-Host "::notice title=📦 Attached module artifact to release::$zipFileName"
            } else {
                Write-Host "Existing asset [$zipFileName] has identical contents; retaining its immutable bytes."
            }
        }
    } finally {
        if ($notesFilePath -and (Test-Path -LiteralPath $notesFilePath)) {
            Remove-Item -LiteralPath $notesFilePath -Force
        }
        if (Test-Path -LiteralPath $zipPath) {
            Remove-Item -LiteralPath $zipPath -Force
        }
        if (Test-Path -LiteralPath $zipDirectory) {
            Remove-Item -LiteralPath $zipDirectory -Force
        }
    }

    if ($whatIf -and $prNumber) {
        Write-Host "gh pr comment $prNumber -b '✅ $($releaseType): GitHub - $name $releaseTag'"
    } elseif (-not $whatIf -and $prNumber) {
        gh pr comment $prNumber -b "✅ $releaseType`: GitHub - [$name $releaseTag]($releaseURL)"
        if ($LASTEXITCODE -ne 0) {
            throw 'Failed to comment on the pull request.'
        }
    }
    if ($env:GITHUB_OUTPUT) {
        "ReleaseTag=$releaseTag" | Out-File -Path $env:GITHUB_OUTPUT -Append -Encoding utf8NoBOM
        "ReleaseUrl=$releaseURL" | Out-File -Path $env:GITHUB_OUTPUT -Append -Encoding utf8NoBOM
    }
    Write-Host "::notice title=✅ $releaseType`: GitHub - $name $releaseTag::$releaseURL"
}

Write-Host "Release creation complete. Version: [$releaseTag]"
