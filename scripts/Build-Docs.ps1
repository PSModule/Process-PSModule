﻿
[CmdletBinding()]
param(
    # Name of the module.
    [Parameter(Mandatory)]
    [string] $ModuleName,

    # Path to the folder where the module source code is located.
    [Parameter(Mandatory)]
    [System.IO.DirectoryInfo] $ModuleSourceFolder,

    # Folder where the documentation for the modules should be outputted. 'outputs\docs\'
    [Parameter(Mandatory)]
    [System.IO.DirectoryInfo] $DocsOutputFolder
)

if (-not $ModuleName) {
    $ModuleName = $env:GITHUB_REPOSITORY -replace '.+/'
}
Write-Verbose "Module name: $ModuleName"

$functionDocsFolderPath = Join-Path -Path $DocsOutputFolder -ChildPath 'Functions'
$functionDocsFolder = New-Item -Path $functionDocsFolderPath -ItemType Directory -Force

Get-ChildItem -Path $functionDocsFolder -Recurse -Force -Include '*.md' | ForEach-Object {
    $fileName = $_.Name
    $hash = (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash
    Start-LogGroup " - [$fileName] - [$hash]"
    Show-FileContent -Path $_
    Stop-LogGroup
}

Start-LogGroup 'Build docs - Process about topics'
$aboutDocsFolderPath = Join-Path -Path $DocsOutputFolder -ChildPath 'About'
$aboutDocsFolder = New-Item -Path $aboutDocsFolderPath -ItemType Directory -Force
$aboutSourceFolder = Get-ChildItem -Path $ModuleSourceFolder -Directory | Where-Object { $_.Name -eq 'en-US' }
Get-ChildItem -Path $aboutSourceFolder -Filter *.txt | Copy-Item -Destination $aboutDocsFolder -Force -Verbose -PassThru |
    Rename-Item -NewName { $_.Name -replace '.txt', '.md' }
Stop-LogGroup

Start-LogGroup 'Build docs - Copy icon to assets'
$assetsFolderPath = Join-Path -Path $DocsOutputFolder -ChildPath 'assets'
$null = New-Item -Path $assetsFolderPath -ItemType Directory -Force
$rootPath = Split-Path -Path $ModuleSourceFolder -Parent
$iconPath = Join-Path -Path $rootPath -ChildPath 'icon\icon.png'
Copy-Item -Path $iconPath -Destination $assetsFolderPath -Force -Verbose

Start-LogGroup 'Build docs - Copy readme.md'
$rootPath = Split-Path -Path $ModuleSourceFolder -Parent
$readmePath = Join-Path -Path $rootPath -ChildPath 'README.md'
Copy-Item -Path $readmePath -Destination $DocsOutputFolder -Force -Verbose
Stop-LogGroup

Start-LogGroup 'Build docs - Copy mkdocs.yml'
$mkdocsPath = Join-Path -Path $DocsOutputFolder -ChildPath 'mkdocs.yml'
Copy-Item -Path (Join-Path -Path $PSScriptRoot -ChildPath 'mkdocs.yml') -Destination $mkdocsPath -Force -Verbose
Stop-LogGroup

Start-LogGroup 'Build docs - Token replacement on mkdocs.yml'
$mkdocsContent = Get-Content -Path $mkdocsPath
$mkdocsContent = $mkdocsContent.Replace('\$\{\{ REPO_NAME \}\}', $ModuleName)
$mkdocsContent | Set-Content -Path $mkdocsPath
Stop-LogGroup
