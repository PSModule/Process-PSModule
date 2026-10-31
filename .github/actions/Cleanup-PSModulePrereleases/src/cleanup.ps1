[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$PSStyle.OutputRendering = 'Ansi'

Import-Module -Name 'PSModule' -Force
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'Cleanup-PSModulePrereleases.Helpers.psm1') -Force

#region Load inputs
Set-GitHubLogGroup 'Load inputs' {
    $whatIf = $env:PSMODULE_CLEANUP_PSMODULEPRERELEASES_INPUT_WhatIf -eq 'true'

    $pullRequestJson = $env:PSMODULE_CLEANUP_PSMODULEPRERELEASES_INPUT_PullRequest
    $prHeadRef = if (-not [string]::IsNullOrWhiteSpace($pullRequestJson) -and $pullRequestJson -ne 'null') {
        ($pullRequestJson | ConvertFrom-Json).HeadRef
    } else {
        $githubEventJson = Get-Content -Raw $env:GITHUB_EVENT_PATH
        $githubEvent = $githubEventJson | ConvertFrom-Json
        $githubEvent.pull_request.head.ref
    }

    if ([string]::IsNullOrWhiteSpace($prHeadRef)) {
        Write-Host '::notice::No pull request head ref is available. Nothing to cleanup.'
        exit 0
    }
    Write-Host "PR head ref:      [$prHeadRef]"
    Write-Host "WhatIf:           [$whatIf]"

    $publishedReleaseTag = $env:PSMODULE_CLEANUP_PSMODULEPRERELEASES_CONTEXT_ReleaseTag
    if (-not [string]::IsNullOrWhiteSpace($publishedReleaseTag)) {
        Write-Host "Published tag:    [$publishedReleaseTag] (excluded from cleanup)"
    }
}
#endregion Load inputs

#region Find prereleases to cleanup
Set-GitHubLogGroup "Find prereleases to cleanup for [$prHeadRef]" {
    $releaseListOutput = gh api "repos/$env:GITHUB_REPOSITORY/releases?per_page=100" --paginate `
        --jq '.[] | {tagName: .tag_name, isPrerelease: .prerelease, targetCommitish: .target_commitish}'
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to list releases for the repository (gh exited $LASTEXITCODE)."
    }
    $releases = @($releaseListOutput | ForEach-Object { $_ | ConvertFrom-Json })
    $parameters = @{
        HeadRef    = $prHeadRef
        Release    = $releases
        ReleaseTag = $publishedReleaseTag
    }
    $prereleasesToCleanup = Get-PSModulePrereleaseForCleanup @parameters
    $tagsToDelete = @($prereleasesToCleanup | ForEach-Object { $_.tagName } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

    if ($tagsToDelete.Count -eq 0) {
        Write-Host "No prereleases have an exact cleanup target of [$prHeadRef]."
        return
    }

    Write-Host "Found $($tagsToDelete.Count) prereleases to cleanup:"
    $tagsToDelete | ForEach-Object { Write-Host "  - $_" }
}
#endregion Find prereleases to cleanup

#region Delete prereleases
Set-GitHubLogGroup "Delete prereleases for [$prHeadRef]" {
    foreach ($tag in $tagsToDelete) {
        Write-Host "Deleting prerelease: [$tag]"
        if ($whatIf) {
            Write-Host "WhatIf: gh release delete --cleanup-tag --yes -- $tag"
        } else {
            gh release delete --cleanup-tag --yes -- $tag
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to delete release [$tag] (gh exited $LASTEXITCODE)."
            }
            Write-Host "Successfully deleted release [$tag]."
        }
    }

    Write-Host "::notice::Cleaned up $($tagsToDelete.Count) prerelease(s) for [$prHeadRef]."
}
#endregion Delete prereleases
