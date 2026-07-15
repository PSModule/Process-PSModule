[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost', '',
    Justification = 'Wriite to the GitHub Actions log, not the pipeline.'
)]
[CmdletBinding()]
param()

$PSModulePath = $env:PSModulePath -split [System.IO.Path]::PathSeparator | Select-Object -First 1
Remove-Module -Name Helpers -Force -ErrorAction SilentlyContinue
Get-Command -Module Helpers | ForEach-Object { Remove-Item -Path function:$_ -Force }
Get-Item -Path "$PSModulePath/Helpers/999.0.0" -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
$modulePath = New-Item -Path "$PSModulePath/Helpers/999.0.0" -ItemType Directory -Force | Select-Object -ExpandProperty FullName
Copy-Item -Path "$PSScriptRoot/Helpers/*" -Destination $modulePath -Recurse -Force
Write-Host '::group::Importing helpers'
Import-Module -Name Helpers -Verbose
Write-Host '::endgroup::'
