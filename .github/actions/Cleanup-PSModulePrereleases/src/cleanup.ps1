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
    $pullRequest = if (-not [string]::IsNullOrWhiteSpace($pullRequestJson) -and $pullRequestJson -ne 'null') {
        $pullRequestJson | ConvertFrom-Json
    } else {
        $githubEventJson = Get-Content -Raw $env:GITHUB_EVENT_PATH
        $githubEvent = $githubEventJson | ConvertFrom-Json
        [pscustomobject]@{
            Number         = $githubEvent.pull_request.number
            HeadRef        = $githubEvent.pull_request.head.ref
            HeadRepository = $githubEvent.pull_request.head.repo.full_name
        }
    }
    $prHeadRef = $pullRequest.HeadRef

    if ([string]::IsNullOrWhiteSpace($prHeadRef)) {
        Write-Host '::notice::No pull request head ref is available. Nothing to cleanup.'
        exit 0
    }
    if ([long]$pullRequest.Number -lt 1) {
        throw 'A positive source PR number is required for verified prerelease cleanup.'
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
        --jq '.[] | {tagName: .tag_name, isPrerelease: .prerelease, targetCommitish: .target_commitish, body: .body}'
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to list releases for the repository (gh exited $LASTEXITCODE)."
    }
    $releases = @($releaseListOutput | ForEach-Object { $_ | ConvertFrom-Json })
    $parameters = @{
        Repository        = $env:GITHUB_REPOSITORY
        PullRequestNumber = [long]$pullRequest.Number
        Release           = $releases
        ReleaseTag        = $publishedReleaseTag
        GetTagCommit      = {
            param($Tag)
            $tagParameters = @{
                Tag             = $Tag
                GetTagReference = {
                    param($TagName)
                    $encodedTag = [Uri]::EscapeDataString($TagName)
                    $response = gh api "repos/$env:GITHUB_REPOSITORY/git/ref/tags/$encodedTag"
                    if ($LASTEXITCODE -ne 0) {
                        throw "Cannot verify cleanup tag [$TagName] (gh exited $LASTEXITCODE)."
                    }
                    ($response | ConvertFrom-Json -ErrorAction Stop).object
                }
                GetTagObject    = {
                    param($TagSha)
                    $response = gh api "repos/$env:GITHUB_REPOSITORY/git/tags/$TagSha"
                    if ($LASTEXITCODE -ne 0) {
                        throw "Cannot verify cleanup tag object [$TagSha] (gh exited $LASTEXITCODE)."
                    }
                    ($response | ConvertFrom-Json -ErrorAction Stop).object
                }
            }
            Resolve-PSModuleReleaseTagCommit @tagParameters
        }
    }
    $prereleasesToCleanup = Get-PSModulePrereleaseForCleanup @parameters
    $tagsToDelete = @($prereleasesToCleanup | ForEach-Object { $_.tagName } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

    if ($tagsToDelete.Count -eq 0) {
        Write-Host "No prereleases have verified ownership for [$env:GITHUB_REPOSITORY#$($pullRequest.Number)]."
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
