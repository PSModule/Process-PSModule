[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', 'psGalleryApiKey',
    Justification = 'Variable is used in script blocks.'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', 'publicationState',
    Justification = 'The verified state is shared across logging script blocks.'
)]
[CmdletBinding()]
param()

$PSStyle.OutputRendering = 'Ansi'
$ErrorActionPreference = 'Stop'

Import-Module -Name 'PSModule' -Force
Import-Module -Name "$PSScriptRoot/Publish-PSModule.Helpers.psm1" -Force
Import-Module -Name ([IO.Path]::Combine(
        $PSScriptRoot, '..', '..', 'Release-PSModule', 'src', 'Release-PSModule.Helpers.psm1'
    )) -Force

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
    $psGalleryApiKey = $env:PSMODULE_PUBLISH_PSMODULE_INPUT_PSGALLERY_API_KEY
    $whatIf = $env:PSMODULE_PUBLISH_PSMODULE_INPUT_WhatIf -eq 'true'
    $releaseTag = $env:PSMODULE_PUBLISH_PSMODULE_INPUT_ReleaseTag
    $versionPrefix = $env:PSMODULE_PUBLISH_PSMODULE_INPUT_VersionPrefix
    $sourceCommit = $env:PSMODULE_PUBLISH_PSMODULE_INPUT_CommitSha
    if ([string]::IsNullOrWhiteSpace($sourceCommit)) {
        $sourceCommit = $env:GITHUB_SHA
    }
    if ([string]::IsNullOrWhiteSpace($releaseTag)) {
        throw 'ReleaseTag is required. Pass the already-resolved Publish.Module.Resolution.FullVersion.'
    }
    if ([string]::IsNullOrWhiteSpace($sourceCommit)) {
        throw 'CommitSha or the original GITHUB_SHA is required to establish the tested artifact source.'
    }

    Write-Host "Module name: [$name]"
    Write-Host "Version prefix: [$versionPrefix]"
    Write-Host "Module path: [$modulePath]"
    Write-Host "WhatIf:      [$whatIf]"
}
#endregion Load inputs

#region Load release context
LogGroup 'Load release context' {
    $pullRequestJson = $env:PSMODULE_PUBLISH_PSMODULE_INPUT_PullRequest
    $pullRequest = $null
    if (-not [string]::IsNullOrWhiteSpace($pullRequestJson) -and $pullRequestJson -ne 'null') {
        $pullRequest = ConvertFrom-Json -InputObject $pullRequestJson -NoEnumerate -ErrorAction Stop
    } else {
        $githubEventJson = Get-Content -Raw $env:GITHUB_EVENT_PATH
        $githubEvent = $githubEventJson | ConvertFrom-Json
        if ($githubEvent.pull_request) {
            $pullRequest = [pscustomobject]@{
                Number = $githubEvent.pull_request.number
            }
        }
    }

    $prNumber = Get-PSModuleProducingPullRequestNumber -PullRequest $pullRequest
    if ($prNumber) {
        Write-Host "Pull request: [#$prNumber]"
    } else {
        Write-Host 'No pull request context is available; publication comments are disabled.'
    }
}
#endregion Load release context

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

    $publishPSVersion = Get-ModuleVersionString -ModuleVersion $moduleVersion -Prerelease $prerelease

    [PSCustomObject]@{
        ModuleVersion    = $moduleVersion
        Prerelease       = $prerelease
        CreatePrerelease = $createPrerelease
        GalleryVersion   = $publishPSVersion
        PRNumber         = $prNumber
    } | Format-List | Out-String
}
#endregion Resolve version from manifest

$zipDirectory = $null
$zipPath = $null
try {
    LogGroup 'Source-bound publication preflight' {
        if ($whatIf) {
            Write-Host "WhatIf: Verify source [$sourceCommit], tag [$releaseTag], and the tested module before publication."
        } else {
            $zipDirectory = Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath "PSModulePreflight-$([guid]::NewGuid())"
            $null = New-Item -Path $zipDirectory -ItemType Directory
            $zipFileName = "$name-$publishPSVersion.zip"
            $zipPath = Join-Path -Path $zipDirectory -ChildPath $zipFileName
            $artifactDigest = Get-PSModuleArtifactDigest -Path $modulePath
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
                ArtifactSha256 = $artifactDigest
                AssetName      = $zipFileName
                AssetSha256    = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
            }
            $publicationReader = Get-PSModulePublicationReader -Repository $env:GITHUB_REPOSITORY
            $publicationState = Get-PSModulePublicationState -ExpectedClaim $claim -Reader $publicationReader
        }
    }

    LogGroup 'Install module dependencies' {
        Resolve-PSModuleDependency -ManifestFilePath $manifestFilePath
    }

    LogGroup 'Publish to PSGallery' {
        $releaseType = if ($createPrerelease) { 'New prerelease' } else { 'New release' }
        $psGalleryReleaseLink = "https://www.powershellgallery.com/packages/$name/$publishPSVersion"

        if ($whatIf) {
            Write-Host "WhatIf: Create-only annotated claim for [$releaseTag]; retain any existing published bytes."
            Write-Host "Publish-PSResource -Path $modulePath -Repository PSGallery -ApiKey ***"
        } else {
            $publicationState = New-PSModulePublicationTag -Claim $claim -State $publicationState -Reader $publicationReader
            $currentState = Get-PSModulePublicationState -ExpectedClaim $claim -Reader $publicationReader
            if ($currentState.TagSha -cne $publicationState.TagSha -or
                $currentState.VersionTagSha -cne $publicationState.VersionTagSha -or
                (Get-PSModuleArtifactDigest -Path $modulePath) -cne $claim.ArtifactSha256) {
                throw 'The publication claim or tested artifact changed before the Gallery write. Refusing publication.'
            }
            if ($null -ne $currentState.Package) {
                Write-Host "Retaining the proven identical Gallery package [$name] [$publishPSVersion]."
            } else {
                Publish-PSResource -Path $modulePath -Repository PSGallery -ApiKey $psGalleryApiKey -ErrorAction Stop
            }
        }

        if ($whatIf -and $prNumber) {
            Write-Host (
                "gh pr comment $prNumber -b " +
                "'✅ $releaseType`: PowerShell Gallery - [$name $publishPSVersion]($psGalleryReleaseLink)'"
            )
        } elseif (-not $whatIf -and $prNumber) {
            gh pr comment $prNumber -b "✅ $releaseType`: PowerShell Gallery - [$name $publishPSVersion]($psGalleryReleaseLink)"
            if ($LASTEXITCODE -ne 0) {
                throw 'Failed to comment on the pull request.'
            }
        }
        Write-Host "::notice title=✅ $releaseType`: PowerShell Gallery - $name $publishPSVersion::$psGalleryReleaseLink"
    }
} finally {
    if ($zipPath -and (Test-Path -LiteralPath $zipPath)) {
        Remove-Item -LiteralPath $zipPath -Force
    }
    if ($zipDirectory -and (Test-Path -LiteralPath $zipDirectory)) {
        Remove-Item -LiteralPath $zipDirectory -Force
    }
}
Write-Host "Gallery publishing complete. Version: [$publishPSVersion]"
