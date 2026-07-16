[CmdletBinding()]
param()

$PSStyle.OutputRendering = 'Ansi'

Import-Module -Name 'Helpers' -Force
Import-Module -Name "$PSScriptRoot/Resolve-PSModuleVersion.Helpers.psm1" -Force

$actionInput = Read-ActionInput
$config = Get-PublishConfiguration -SettingsJson $actionInput.SettingsJson
$pullRequest = Get-GitHubPullRequest

$decision = if ($null -eq $pullRequest) {
    # Non-PR event (for example workflow_dispatch or schedule): there are no pull request
    # labels to determine a version bump, so keep the current published version and publish
    # nothing. For a module that has never been released this floors at 0.0.0.
    [PSCustomObject]@{
        ShouldPublish    = $false
        CreateRelease    = $false
        CreatePrerelease = $false
        MajorRelease     = $false
        MinorRelease     = $false
        PatchRelease     = $false
        HasVersionBump   = $false
        PrereleaseName   = ''
    }
} else {
    Resolve-ReleaseDecision -Configuration $config -PullRequest $pullRequest
}

$releases = Get-GitHubRelease
$ghVersion = Get-LatestGitHubVersion -Releases $releases
$psGalleryVersion = Get-LatestPSGalleryVersion -ModuleName $actionInput.Name
$latestVersion = Get-LatestPublishedVersion -GitHubVersion $ghVersion -PSGalleryVersion $psGalleryVersion

$params = @{
    LatestVersion = $latestVersion
    Decision      = $decision
    Configuration = $config
    ModuleName    = $actionInput.Name
    Releases      = $releases
}
$newVersion = Get-NextModuleVersion @params

Write-ActionOutput -Decision $decision -NewVersion $newVersion
