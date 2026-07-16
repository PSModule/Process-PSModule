[CmdletBinding()]
param()

$PSStyle.OutputRendering = 'Ansi'

Import-Module -Name 'Helpers' -Force

#region Load inputs
LogGroup 'Load inputs' {
    $whatIf = $env:PSMODULE_PUBLISH_PSMODULE_INPUT_WhatIf -eq 'true'

    $githubEventJson = Get-Content -Raw $env:GITHUB_EVENT_PATH
    $githubEvent = $githubEventJson | ConvertFrom-Json
    $pull_request = $githubEvent.pull_request
    if (-not $pull_request) {
        throw 'GitHub event does not contain pull_request data. This script must be run from a pull_request event.'
    }
    $prHeadRef = $pull_request.head.ref
    $prereleaseName = $prHeadRef -replace '[^a-zA-Z0-9]'

    if ([string]::IsNullOrWhiteSpace($prereleaseName)) {
        Write-Host "No prerelease tag derivable from PR head ref [$prHeadRef]. Nothing to cleanup."
        exit 0
    }

    Write-Host "PR head ref:      [$prHeadRef]"
    Write-Host "Prerelease name:  [$prereleaseName]"
    Write-Host "WhatIf:           [$whatIf]"

    $publishedReleaseTag = $env:PSMODULE_PUBLISH_PSMODULE_CONTEXT_ReleaseTag
    if (-not [string]::IsNullOrWhiteSpace($publishedReleaseTag)) {
        Write-Host "Published tag:    [$publishedReleaseTag] (excluded from cleanup)"
    }
}
#endregion Load inputs

#region Find prereleases to cleanup
LogGroup "Find prereleases to cleanup for [$prereleaseName]" {
    $releaseListOutput = gh release list --json 'createdAt,isDraft,isLatest,isPrerelease,name,publishedAt,tagName'
    if ($LASTEXITCODE -ne 0) {
        Write-Error 'Failed to list releases for the repository.'
        exit $LASTEXITCODE
    }
    $releases = $releaseListOutput | ConvertFrom-Json

    $prereleasesToCleanup = $releases | Where-Object {
        $_.isPrerelease -eq $true -and $_.tagName -like "*$prereleaseName*" -and $_.tagName -ne $publishedReleaseTag
    }
    $tagsToDelete = @($prereleasesToCleanup | ForEach-Object { $_.tagName } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

    if ($tagsToDelete.Count -eq 0) {
        Write-Host "No prereleases found to cleanup for [$prereleaseName]."
        return
    }

    Write-Host "Found $($tagsToDelete.Count) prereleases to cleanup:"
    $tagsToDelete | ForEach-Object { Write-Host "  - $_" }
}
#endregion Find prereleases to cleanup

#region Delete prereleases
LogGroup "Delete prereleases for [$prereleaseName]" {
    foreach ($tag in $tagsToDelete) {
        Write-Host "Deleting prerelease: [$tag]"
        if ($whatIf) {
            Write-Host "WhatIf: gh release delete $tag --cleanup-tag --yes"
        } else {
            gh release delete $tag --cleanup-tag --yes
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Failed to delete release [$tag]."
                exit $LASTEXITCODE
            }
            Write-Host "Successfully deleted release [$tag]."
        }
    }

    Write-Host "::notice::Cleaned up $($tagsToDelete.Count) prerelease(s) for [$prereleaseName]."
}
#endregion Delete prereleases
