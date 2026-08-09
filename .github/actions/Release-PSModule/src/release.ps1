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
    'PSUseDeclaredVarsMoreThanAssignments', 'prNumber',
    Justification = 'Variable is used in script blocks.'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', 'prHeadRef',
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
    if ([string]::IsNullOrWhiteSpace($releaseTag)) {
        throw 'ReleaseTag is required. Ensure Publish.Module.Resolution.FullVersion is passed from the Plan job.'
    }

    Write-Host "Module name: [$name]"
    Write-Host "Module path: [$modulePath]"
    Write-Host "Release tag: [$releaseTag]"
    Write-Host "WhatIf:      [$whatIf]"
}

LogGroup 'Load PR information' {
    $githubEventJson = Get-Content -Raw $env:GITHUB_EVENT_PATH
    $githubEvent = $githubEventJson | ConvertFrom-Json
    $pull_request = $githubEvent.pull_request
    if (-not $pull_request) {
        throw 'GitHub event does not contain pull_request data. This script must be run from a pull_request event.'
    }
    $prNumber = $pull_request.number
    $prHeadRef = $pull_request.head.ref
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
        } | Format-List | Out-String
    )
}

# A zip of the built module is uploaded so the GitHub Release page exposes the exact bytes.
LogGroup 'Create GitHub release' {
    $releaseCreateCommand = @('release', 'create', $releaseTag)
    $notesFilePath = $null
    $releaseExists = $false

    if (-not $whatIf) {
        $encodedReleaseTag = [System.Uri]::EscapeDataString($releaseTag)
        $releaseLookupResult = gh api "repos/$env:GITHUB_REPOSITORY/releases/tags/$encodedReleaseTag" --jq '.html_url' 2>&1
        $releaseLookupExitCode = $LASTEXITCODE

        if ($releaseLookupExitCode -eq 0) {
            $releaseURL = ($releaseLookupResult | Out-String).Trim()
            $releaseExists = $true
            Write-Host "GitHub release [$releaseTag] already exists. Resuming its artifact upload."
        } elseif (($releaseLookupResult | Out-String) -notmatch 'HTTP 404') {
            throw "Unable to determine whether release [$releaseTag] exists: $($releaseLookupResult | Out-String)"
        }
    }

    if (-not $releaseExists) {
        if ($usePRTitleAsReleaseName -and $pull_request.title) {
            $releaseCreateCommand += @('--title', $pull_request.title)
            Write-Host "Using PR title as release name: [$($pull_request.title)]"
        } else {
            $releaseCreateCommand += @('--title', $releaseTag)
        }

        # Build release notes content. Uses a file to preserve special characters.
        if ($usePRTitleAsNotesHeading -and $usePRBodyAsReleaseNotes -and $pull_request.title -and $pull_request.body) {
            $notes = "# $($pull_request.title) (#$prNumber)`n`n$($pull_request.body)"
            $notesFilePath = [System.IO.Path]::GetTempFileName()
            Set-Content -Path $notesFilePath -Value $notes -Encoding utf8
            $releaseCreateCommand += @('--notes-file', $notesFilePath)
            Write-Host 'Using PR title as H1 heading with link and body as release notes'
        } elseif ($usePRBodyAsReleaseNotes -and $pull_request.body) {
            $notesFilePath = [System.IO.Path]::GetTempFileName()
            Set-Content -Path $notesFilePath -Value $pull_request.body -Encoding utf8
            $releaseCreateCommand += @('--notes-file', $notesFilePath)
            Write-Host 'Using PR body as release notes'
        } else {
            $releaseCreateCommand += @('--generate-notes')
        }

        if ($createPrerelease) {
            $releaseCreateCommand += @('--target', $prHeadRef, '--prerelease')
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
    $zipPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $zipFileName
    if (Test-Path -Path $zipPath) {
        Remove-Item -Path $zipPath -Force
    }
    if ($whatIf) {
        Write-Host "WhatIf: Compress-Archive -Path $modulePath -DestinationPath $zipPath -Force"
        Write-Host "WhatIf: gh release upload $releaseTag $zipPath --clobber"
    } else {
        Write-Host "Compressing module to [$zipPath]"
        Compress-Archive -Path $modulePath -DestinationPath $zipPath -Force
        try {
            gh release upload $releaseTag $zipPath --clobber
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to upload module artifact to release [$releaseTag]."
            }
            Write-Host "::notice title=📦 Attached module artifact to release::$zipFileName"
        } finally {
            if (Test-Path -Path $zipPath) {
                Remove-Item -Path $zipPath -Force
            }
        }
    }

    if ($whatIf) {
        Write-Host "gh pr comment $prNumber -b '✅ $($releaseType): GitHub - $name $releaseTag'"
    } else {
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
