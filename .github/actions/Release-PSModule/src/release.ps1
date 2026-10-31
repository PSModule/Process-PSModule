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

Set-GitHubLogGroup 'Load inputs' {
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
    $commitSha = $env:PSMODULE_RELEASE_PSMODULE_INPUT_CommitSha
    if ([string]::IsNullOrWhiteSpace($releaseTag)) {
        throw 'ReleaseTag is required. Ensure Publish.Module.Resolution.FullVersion is passed from the Plan job.'
    }

    Write-Host "Module name: [$name]"
    Write-Host "Module path: [$modulePath]"
    Write-Host "Release tag: [$releaseTag]"
    Write-Host "WhatIf:      [$whatIf]"
}

Set-GitHubLogGroup 'Load release context' {
    $githubEventJson = Get-Content -Raw $env:GITHUB_EVENT_PATH
    $githubEvent = $githubEventJson | ConvertFrom-Json
    $pullRequestJson = $env:PSMODULE_RELEASE_PSMODULE_INPUT_PullRequest
    $pullRequest = if (-not [string]::IsNullOrWhiteSpace($pullRequestJson) -and $pullRequestJson -ne 'null') {
        $pullRequestJson | ConvertFrom-Json
    } elseif ($githubEvent.pull_request) {
        [pscustomobject]@{
            Number  = $githubEvent.pull_request.number
            Title   = $githubEvent.pull_request.title
            Body    = $githubEvent.pull_request.body
            HeadRef = $githubEvent.pull_request.head.ref
        }
    }
    $prNumber = $pullRequest.Number
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

Set-GitHubLogGroup 'Resolve version from manifest' {
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
Set-GitHubLogGroup 'Create GitHub release' {
    $releaseCreateCommand = @('release', 'create', $releaseTag)
    $notesFilePath = $null
    $releaseExists = $false
    $existingRelease = $null
    $sourceCommit = if (-not [string]::IsNullOrWhiteSpace($commitSha)) { $commitSha } else { $env:GITHUB_SHA }

    if (-not $whatIf) {
        $encodedReleaseTag = [System.Uri]::EscapeDataString($releaseTag)
        $releaseLookupResult = gh api "repos/$env:GITHUB_REPOSITORY/releases/tags/$encodedReleaseTag" 2>&1
        $releaseLookupExitCode = $LASTEXITCODE

        if ($releaseLookupExitCode -eq 0) {
            $existingRelease = ($releaseLookupResult | Out-String) | ConvertFrom-Json
            if ($existingRelease.tag_name -cne $releaseTag -or
                [string]::IsNullOrWhiteSpace($existingRelease.html_url) -or
                $existingRelease.PSObject.Properties.Name -notcontains 'assets') {
                throw "Cannot verify the existing release metadata for [$releaseTag]."
            }
            $releaseURL = $existingRelease.html_url
            $releaseExists = $true
        } elseif (($releaseLookupResult | Out-String) -notmatch 'HTTP 404') {
            throw "Unable to determine whether release [$releaseTag] exists: $($releaseLookupResult | Out-String)"
        }
        if ([string]::IsNullOrWhiteSpace($sourceCommit)) {
            throw 'CommitSha or the original GITHUB_SHA is required to establish immutable publication ownership.'
        }
        $tagParameters = @{
            Tag             = $releaseTag
            AllowMissing    = $true
            GetTagReference = {
                param($Tag)
                $encodedTag = [Uri]::EscapeDataString($Tag)
                $response = gh api "repos/$env:GITHUB_REPOSITORY/git/ref/tags/$encodedTag" 2>&1
                $lookupExit = $LASTEXITCODE
                if ($lookupExit -ne 0) {
                    if (($response | Out-String) -match 'HTTP 404') {
                        return
                    }
                    throw "Cannot read release tag [$Tag] (gh exited $lookupExit): $($response | Out-String)"
                }
                $metadata = ($response | Out-String) | ConvertFrom-Json -ErrorAction Stop
                if ($null -eq $metadata.object) {
                    throw "Tag lookup for [$Tag] did not return an object."
                }
                $metadata.object
            }
            GetTagObject    = {
                param($TagSha)
                $response = gh api "repos/$env:GITHUB_REPOSITORY/git/tags/$TagSha"
                if ($LASTEXITCODE -ne 0) {
                    throw "Cannot resolve annotated tag [$TagSha] (gh exited $LASTEXITCODE)."
                }
                ($response | ConvertFrom-Json -ErrorAction Stop).object
            }
        }
        $tagCommit = Resolve-PSModuleReleaseTagCommit @tagParameters
        if ($null -ne $tagCommit -and $tagCommit -cne $sourceCommit) {
            throw "Release tag [$releaseTag] belongs to [$tagCommit], not the original source [$sourceCommit]. Refusing to publish."
        }
        if ($releaseExists -and $null -eq $tagCommit) {
            throw "Existing release [$releaseTag] has no verifiable tag. Refusing to resume."
        }
        if ($releaseExists) {
            $owner = Get-PSModulePrereleaseOwnership -Body $existingRelease.body
            if ($null -ne $owner -and ($owner.Repository -ine $env:GITHUB_REPOSITORY -or
                    $owner.PullRequest -ne $prNumber -or $owner.CommitSha -cne $sourceCommit)) {
                throw 'The existing release ownership footer conflicts with the producing repository, pull request, or source.'
            }
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

        if ($createPrerelease) {
            $artifactCommit = if (-not [string]::IsNullOrWhiteSpace($commitSha)) { $commitSha } else { $env:GITHUB_SHA }
            if ([string]::IsNullOrWhiteSpace($artifactCommit)) {
                throw 'The original build commit is required to create an immutable prerelease tag.'
            }
            $releaseCreateCommand += @('--target', $artifactCommit, '--prerelease')
            if ($prNumber) {
                $ownership = [pscustomobject]@{
                    Repository  = $env:GITHUB_REPOSITORY
                    PullRequest = [long]$prNumber
                    CommitSha   = $artifactCommit
                } | ConvertTo-Json -Compress
                $encodedOwnership = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($ownership))
                $ownershipFooter = "<!-- PSModule.PrereleaseOwner:v1:$encodedOwnership -->"
                if ($null -eq $notesFilePath) {
                    if ($whatIf) {
                        Write-Host (
                            "WhatIf: gh api repos/$env:GITHUB_REPOSITORY/releases/generate-notes --method POST " +
                            "--field tag_name=$releaseTag --field target_commitish=$artifactCommit"
                        )
                        $generatedBody = ''
                    } else {
                        $generatedNotes = gh api "repos/$env:GITHUB_REPOSITORY/releases/generate-notes" --method POST `
                            --field "tag_name=$releaseTag" --field "target_commitish=$artifactCommit"
                        if ($LASTEXITCODE -ne 0) {
                            throw "Cannot generate prerelease notes (gh exited $LASTEXITCODE)."
                        }
                        $generated = $generatedNotes | ConvertFrom-Json -ErrorAction Stop
                        if ($generated.PSObject.Properties.Name -notcontains 'body') {
                            throw 'Generated release notes have no body. Refusing to publish incomplete notes.'
                        }
                        $generatedBody = [string]$generated.body
                    }
                    $notesFilePath = [IO.Path]::GetTempFileName()
                    Set-Content -LiteralPath $notesFilePath -Value $generatedBody -Encoding utf8
                    $releaseCreateCommand = @($releaseCreateCommand | Where-Object { $_ -ne '--generate-notes' })
                    $releaseCreateCommand += @('--notes-file', $notesFilePath)
                }
                Add-Content -LiteralPath $notesFilePath -Value "`n$ownershipFooter" -Encoding utf8
            }
        } elseif (-not [string]::IsNullOrWhiteSpace($sourceCommit)) {
            $releaseCreateCommand += @('--target', $sourceCommit)
        }

        try {
            if ($whatIf) {
                Write-Host "WhatIf: gh $($releaseCreateCommand -join ' ')"
                $releaseURL = "https://github.com/$env:GITHUB_REPOSITORY/releases/tag/$releaseTag"
            } else {
                $releaseURL = gh @releaseCreateCommand
                if ($LASTEXITCODE -ne 0) {
                    throw "Failed to create the release [$releaseTag]."
                }
            }
        } finally {
            if ($notesFilePath -and (Test-Path -Path $notesFilePath)) {
                Remove-Item -Path $notesFilePath -Force
            }
        }
    }

    # Attach the built module as a release artifact so consumers can download the exact bytes.
    $zipFileName = "$name-$publishPSVersion.zip"
    $zipDirectory = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "PSModuleRelease-$([Guid]::NewGuid())"
    $zipPath = Join-Path -Path $zipDirectory -ChildPath $zipFileName
    if ($whatIf) {
        Write-Host "WhatIf: Compress-Archive -Path $modulePath -DestinationPath $zipPath"
        Write-Host "WhatIf: gh release upload $releaseTag $zipPath"
    } else {
        $null = New-Item -Path $zipDirectory -ItemType Directory
        try {
            Write-Host "Compressing module to [$zipPath]"
            Compress-Archive -Path $modulePath -DestinationPath $zipPath
            $tagParameters.AllowMissing = $false
            $currentTagCommit = Resolve-PSModuleReleaseTagCommit @tagParameters
            if ($currentTagCommit -cne $sourceCommit) {
                throw "Release tag [$releaseTag] moved to [$currentTagCommit], not the original source [$sourceCommit]. Refusing upload."
            }
            $matchingAssets = @($existingRelease.assets | Where-Object { $_.name -ceq $zipFileName })
            if ($matchingAssets.Count -gt 1) {
                throw "Release [$releaseTag] contains ambiguous assets named [$zipFileName]."
            }
            if ($matchingAssets.Count -eq 1) {
                $digest = [regex]::Match([string]$matchingAssets[0].digest, '^sha256:([0-9A-Fa-f]{64})$')
                if (-not $digest.Success) {
                    throw "Cannot verify the SHA-256 digest of the already-published asset [$zipFileName]. Refusing to replace it."
                }
                $localHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
                if ($localHash -ne $digest.Groups[1].Value) {
                    throw "Asset [$zipFileName] already has different published contents. Refusing to overwrite it."
                }
                Write-Host "Existing asset [$zipFileName] has identical contents; retaining its immutable bytes."
            } else {
                gh release upload $releaseTag $zipPath
                if ($LASTEXITCODE -ne 0) {
                    throw "Failed to upload module artifact to release [$releaseTag]."
                }
                Write-Host "::notice title=📦 Attached module artifact to release::$zipFileName"
            }
        } finally {
            if (Test-Path -Path $zipPath) {
                Remove-Item -Path $zipPath -Force
            }
            if (Test-Path -Path $zipDirectory) {
                Remove-Item -Path $zipDirectory -Force
            }
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
