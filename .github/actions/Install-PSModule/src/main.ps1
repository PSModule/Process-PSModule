[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost', '',
    Justification = 'Wriite to the GitHub Actions log, not the pipeline.'
)]
[CmdletBinding()]
param()

$moduleName = 'PSModule'
$PSModulePath = $env:PSModulePath -split [System.IO.Path]::PathSeparator | Select-Object -First 1
Remove-Module -Name $moduleName -Force -ErrorAction SilentlyContinue
Get-Command -Module $moduleName | ForEach-Object { Remove-Item -Path function:$_ -Force }
Get-Item -Path "$PSModulePath/$moduleName/999.0.0" -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
$modulePath = New-Item -Path "$PSModulePath/$moduleName/999.0.0" -ItemType Directory -Force | Select-Object -ExpandProperty FullName
Copy-Item -Path "$PSScriptRoot/$moduleName/*" -Destination $modulePath -Recurse -Force
Write-Host ":::group::Importing $moduleName"
Import-Module -Name $moduleName -Verbose
Write-Host '::endgroup::'
