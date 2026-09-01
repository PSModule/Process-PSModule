[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', 'psGalleryApiKey',
    Justification = 'Variable is used in script blocks.'
)]
[CmdletBinding()]
param()

$PSStyle.OutputRendering = 'Ansi'

Import-Module -Name 'PSModule' -Force
Import-Module -Name "$PSScriptRoot/Publish-PSModule.Helpers.psm1" -Force

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

    Write-Host "Module name: [$name]"
    Write-Host "Module path: [$modulePath]"
    Write-Host "WhatIf:      [$whatIf]"
}
#endregion Load inputs

#region Load release context
LogGroup 'Load release context' {
    $pullRequestJson = $env:PSMODULE_PUBLISH_PSMODULE_INPUT_PullRequest
    $pullRequest = if (-not [string]::IsNullOrWhiteSpace($pullRequestJson) -and $pullRequestJson -ne 'null') {
        $pullRequestJson | ConvertFrom-Json
    } else {
        $githubEventJson = Get-Content -Raw $env:GITHUB_EVENT_PATH
        $githubEvent = $githubEventJson | ConvertFrom-Json
        if ($githubEvent.pull_request) {
            [pscustomobject]@{
                Number = $githubEvent.pull_request.number
            }
        }
    }

    $prNumber = $pullRequest.Number
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

#region Install module dependencies
LogGroup 'Install module dependencies' {
    Resolve-PSModuleDependency -ManifestFilePath $manifestFilePath
}
#endregion Install module dependencies

#region Publish to PSGallery
LogGroup 'Publish to PSGallery' {
    $releaseType = if ($createPrerelease) { 'New prerelease' } else { 'New release' }
    $psGalleryReleaseLink = "https://www.powershellgallery.com/packages/$name/$publishPSVersion"

    Write-Host 'Publish module to PowerShell Gallery using API key from environment.'
    if ($whatIf) {
        Write-Host "Publish-PSResource -Path $modulePath -Repository PSGallery -ApiKey ***"
    } else {
        $publishedPackage = Find-PSResource -Name $name -Version $publishPSVersion -Repository PSGallery -ErrorAction SilentlyContinue
        if ($publishedPackage) {
            Write-Host (
                "::notice title=♻️ Resuming Gallery-only publication::$name $publishPSVersion is already " +
                'published to the PowerShell Gallery.'
            )
        } else {
            Publish-PSResource -Path $modulePath -Repository PSGallery -ApiKey $psGalleryApiKey
        }
    }

    if ($whatIf -and $prNumber) {
        Write-Host (
            "gh pr comment $prNumber -b " +
            "'✅ $releaseType`: PowerShell Gallery - [$name $publishPSVersion]($psGalleryReleaseLink)'"
        )
    } elseif (-not $whatIf -and $prNumber) {
        Write-Host "::notice title=✅ $releaseType`: PowerShell Gallery - $name $publishPSVersion::$psGalleryReleaseLink"
        gh pr comment $prNumber -b "✅ $releaseType`: PowerShell Gallery - [$name $publishPSVersion]($psGalleryReleaseLink)"
        if ($LASTEXITCODE -ne 0) {
            Write-Error 'Failed to comment on the pull request.'
            exit $LASTEXITCODE
        }
    } else {
        Write-Host "::notice title=✅ $releaseType`: PowerShell Gallery - $name $publishPSVersion::$psGalleryReleaseLink"
    }
}
#endregion Publish to PSGallery
Write-Host "Gallery publishing complete. Version: [$publishPSVersion]"
