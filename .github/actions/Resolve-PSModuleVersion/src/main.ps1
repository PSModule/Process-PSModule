[CmdletBinding()]
param()

$PSStyle.OutputRendering = 'Ansi'

Import-Module -Name 'PSModule' -Force
Import-Module -Name "$PSScriptRoot/Resolve-PSModuleVersion.Helpers.psm1" -Force

$actionInput = Read-ActionInput
$config = Get-PublishConfiguration -SettingsJson $actionInput.SettingsJson
$releaseContext = Get-ReleaseContext -SettingsJson $actionInput.SettingsJson `
    -ReleaseDecision $actionInput.ReleaseDecision
$decision = Resolve-ReleaseDecision -ReleaseContext $releaseContext

$releases = @(Get-GitHubRelease)
$ghVersion = Get-LatestGitHubVersion -Releases $releases
$psGalleryVersion = Get-LatestPSGalleryVersion -ModuleName $actionInput.Name

$params = @{
    GitHubVersion    = $ghVersion
    PSGalleryVersion = $psGalleryVersion
    Decision         = $decision
    Configuration    = $config
    ModuleName       = $actionInput.Name
    Releases         = $releases
}
$newVersion = Get-ResolvedModuleVersion @params

Write-ActionOutput -Decision $decision -NewVersion $newVersion
