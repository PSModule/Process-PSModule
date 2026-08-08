Import-Module -Name (Join-Path $PSScriptRoot 'Helper.psm1')

LogGroup 'Initialize update-index run' {
    Write-Host "Starting update-index in [$PSScriptRoot]"
}

LogGroup 'Collect repositories' {
    $repos = Show-RepoList
    Write-Host "Repository collection complete: $($repos.Count) records"
}

LogGroup 'Skipped generators' {
    Write-Host 'Update-ActionList is currently disabled in main.ps1'
    Write-Host 'Update-FunctionAppList is currently disabled in main.ps1'
}

LogGroup 'Update module catalog docs' {
    Update-ModuleList -Repos $repos
}

LogGroup 'Finalize update-index run' {
    Write-Host 'update-index run completed'
}
