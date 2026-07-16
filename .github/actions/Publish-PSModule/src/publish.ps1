[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', 'apiKey',
    Justification = 'Variable is used in script blocks.'
)]
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
[CmdletBinding()]
param()

$PSStyle.OutputRendering = 'Ansi'

Import-Module -Name 'Helpers' -Force

#region Load inputs
LogGroup 'Load inputs' {
    $env:GITHUB_REPOSITORY_NAME = $env:GITHUB_REPOSITORY -replace '.+/'

    $name = if ([string]::IsNullOrEmpty($env:PSMODULE_PUBLISH_PSMODULE_INPUT_Name)) {
        $env:GITHUB_REPOSITORY_NAME
    } else {
        $env:PSMODULE_PUBLISH_PSMODULE_INPUT_Name
    }
    # Normalize to an absolute path anchored at the workspace root so that
    # the resolved location agrees with where actions/download-artifact writes
    # the artifact (workspace-root-relative), regardless of WorkingDirectory.
    $modulePathInput = $env:PSMODULE_PUBLISH_PSMODULE_INPUT_ModulePath
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
    $apiKey = $env:PSMODULE_PUBLISH_PSMODULE_INPUT_APIKey
    $whatIf = $env:PSMODULE_PUBLISH_PSMODULE_INPUT_WhatIf -eq 'true'
    $usePRBodyAsReleaseNotes = $env:PSMODULE_PUBLISH_PSMODULE_INPUT_UsePRBodyAsReleaseNotes -eq 'true'
    $usePRTitleAsReleaseName = $env:PSMODULE_PUBLISH_PSMODULE_INPUT_UsePRTitleAsReleaseName -eq 'true'
    $usePRTitleAsNotesHeading = $env:PSMODULE_PUBLISH_PSMODULE_INPUT_UsePRTitleAsNotesHeading -eq 'true'

    Write-Host "Module name: [$name]"
    Write-Host "Module path: [$modulePath]"
    Write-Host "WhatIf:      [$whatIf]"
}
#endregion Load inputs

#region Load PR information
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
#endregion Load PR information

#region Resolve version from manifest
# The manifest was stamped with the final version during Build-PSModule. This step is read-only
# to preserve artifact integrity (the tested artifact is identical to the published artifact).
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

    try {
        $manifestData = Import-PowerShellDataFile -Path $manifestFilePath
    } catch {
        Write-Error "Failed to import manifest data file [$manifestFilePath]: $($_.Exception.Message)"
        exit 1
    }
    $moduleVersion = $manifestData.ModuleVersion
    if (-not ($moduleVersion -match '^\d+\.\d+\.\d+$')) {
        Write-Error ("ModuleVersion [$moduleVersion] must be in Major.Minor.Patch format. " +
            'Ensure Build-PSModule has stamped the artifact with a final version.')
        exit 1
    }
    if ($moduleVersion -eq '999.0.0') {
        Write-Error ('ModuleVersion is the placeholder [999.0.0]. ' +
            'The artifact was not stamped with a real version by the build step.')
        exit 1
    }
    $prerelease = $manifestData.PrivateData.PSData.Prerelease
    if ([string]::IsNullOrWhiteSpace($prerelease)) {
        $prerelease = ''
        $createPrerelease = $false
    } else {
        if ($prerelease -notmatch '^[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*$') {
            Write-Error ("Prerelease label [$prerelease] is not a valid SemVer prerelease identifier. " +
                'It must contain only alphanumerics, hyphens, and dots as separators.')
            exit 1
        }
        $createPrerelease = $true
    }

    $releaseTag = if ($createPrerelease) { "$moduleVersion-$prerelease" } else { $moduleVersion }

    [PSCustomObject]@{
        ModuleVersion    = $moduleVersion
        Prerelease       = $prerelease
        CreatePrerelease = $createPrerelease
        ReleaseTag       = $releaseTag
        PRNumber         = $prNumber
        PRHeadRef        = $prHeadRef
    } | Format-List | Out-String

    # Expose publish context to subsequent steps so the cleanup step can gate on release type.
    $envLine = "PSMODULE_PUBLISH_PSMODULE_CONTEXT_IsPrerelease=$($createPrerelease.ToString().ToLower())"
    $envLine | Out-File -Path $env:GITHUB_ENV -Append -Encoding utf8NoBOM
    "PSMODULE_PUBLISH_PSMODULE_CONTEXT_ReleaseTag=$releaseTag" | Out-File -Path $env:GITHUB_ENV -Append -Encoding utf8NoBOM
}
#endregion Resolve version from manifest

#region Install module dependencies
LogGroup 'Install module dependencies' {
    Resolve-PSModuleDependency -ManifestFilePath $manifestFilePath
}
#endregion Install module dependencies

#region Publish to PSGallery
LogGroup 'Publish to PSGallery' {
    $releaseType = if ($createPrerelease) { 'New prerelease' } else { 'New release' }
    $publishPSVersion = if ($createPrerelease) { "$moduleVersion-$prerelease" } else { $moduleVersion }
    $psGalleryReleaseLink = "https://www.powershellgallery.com/packages/$name/$publishPSVersion"

    Write-Host 'Publish module to PowerShell Gallery using API key from environment.'
    if ($whatIf) {
        Write-Host "Publish-PSResource -Path $modulePath -Repository PSGallery -ApiKey ***"
    } else {
        try {
            Publish-PSResource -Path $modulePath -Repository PSGallery -ApiKey $apiKey
        } catch {
            Write-Error $_.Exception.Message
            exit 1
        }
    }

    if ($whatIf) {
        Write-Host (
            "gh pr comment $prNumber -b " +
            "'✅ $releaseType`: PowerShell Gallery - [$name $publishPSVersion]($psGalleryReleaseLink)'"
        )
    } else {
        Write-Host "::notice title=✅ $releaseType`: PowerShell Gallery - $name $publishPSVersion::$psGalleryReleaseLink"
        gh pr comment $prNumber -b "✅ $releaseType`: PowerShell Gallery - [$name $publishPSVersion]($psGalleryReleaseLink)"
        if ($LASTEXITCODE -ne 0) {
            Write-Error 'Failed to comment on the pull request.'
            exit $LASTEXITCODE
        }
    }
}
#endregion Publish to PSGallery

#region Create GitHub release with module artifact attached
# A zip of the published module is uploaded so the GitHub Release page exposes the exact bytes
# that were tested and pushed to the PowerShell Gallery.
LogGroup 'Create GitHub release' {
    $releaseCreateCommand = @('release', 'create', $releaseTag)
    $notesFilePath = $null

    if ($usePRTitleAsReleaseName -and $pull_request.title) {
        $releaseCreateCommand += @('--title', $pull_request.title)
        Write-Host "Using PR title as release name: [$($pull_request.title)]"
    } else {
        $releaseCreateCommand += @('--title', $releaseTag)
    }

    # Build release notes content. Uses temp file to avoid escaping issues with special characters.
    # Precedence rules for the three UsePR* parameters:
    #   1. UsePRTitleAsNotesHeading + UsePRBodyAsReleaseNotes: Creates "# Title (#PR)\n\nBody" format.
    #   2. UsePRBodyAsReleaseNotes only: Uses PR body as-is.
    #   3. Fallback: Auto-generates notes via GitHub's --generate-notes.
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

    if ($whatIf) {
        Write-Host "WhatIf: gh $($releaseCreateCommand -join ' ')"
        $releaseURL = "https://github.com/$env:GITHUB_REPOSITORY/releases/tag/$releaseTag"
    } else {
        try {
            $releaseURL = gh @releaseCreateCommand
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Failed to create the release [$releaseTag]."
                exit $LASTEXITCODE
            }
        } finally {
            if ($notesFilePath -and (Test-Path -Path $notesFilePath)) {
                Remove-Item -Path $notesFilePath -Force
            }
        }
    }

    # Attach the built module as a release artifact so consumers can download the exact
    # bytes that were tested and published to the PowerShell Gallery.
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
                Write-Error "Failed to upload module artifact to release [$releaseTag]."
                exit $LASTEXITCODE
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
            Write-Error 'Failed to comment on the pull request.'
            exit $LASTEXITCODE
        }
    }
    Write-Host "::notice title=✅ $releaseType`: GitHub - $name $releaseTag::$releaseURL"
}
#endregion Create GitHub release

Write-Host "Publishing complete. Version: [$releaseTag]"
