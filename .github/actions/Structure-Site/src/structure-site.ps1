param(
    [Parameter(Mandatory)]
    [string]$WorkingDirectory,

    [Parameter()]
    [string]$Name
)

$ErrorActionPreference = 'Stop'

$resolvedWorkingDirectory = Resolve-Path -Path $WorkingDirectory | Select-Object -ExpandProperty Path
$siteOutputPath = Join-Path -Path $resolvedWorkingDirectory -ChildPath 'outputs/site'
$docsOutputPath = Join-Path -Path $resolvedWorkingDirectory -ChildPath 'outputs/docs'
$moduleSourcePath = Join-Path -Path $resolvedWorkingDirectory -ChildPath 'src'
$moduleName = if ([string]::IsNullOrEmpty($Name)) { $env:GITHUB_REPOSITORY_NAME } else { $Name }

$functionDocsFolder = New-Item -Path (Join-Path -Path $siteOutputPath -ChildPath 'docs/Functions') -ItemType Directory -Force
Copy-Item -Path (Join-Path -Path $docsOutputPath -ChildPath '*') -Destination $functionDocsFolder.FullName -Recurse -Force

Write-Host "Function Docs Folder: $($functionDocsFolder.FullName)"
Write-Host "Module Name:          $moduleName"
Write-Host "Module Source Path:   $moduleSourcePath"
Write-Host "Site Output Path:     $siteOutputPath"

$aboutDocsFolder = New-Item -Path (Join-Path -Path $siteOutputPath -ChildPath 'docs/About') -ItemType Directory -Force
$aboutSourceFolder = Join-Path -Path $moduleSourcePath -ChildPath 'en-US'
if (Test-Path -Path $aboutSourceFolder) {
    Get-ChildItem -Path $aboutSourceFolder -Filter '*.txt' | Copy-Item -Destination $aboutDocsFolder.FullName -Force -PassThru |
        Rename-Item -NewName { $_.Name -replace '\.txt$', '.md' }
}

$assetsFolder = New-Item -Path (Join-Path -Path $siteOutputPath -ChildPath 'docs/Assets') -ItemType Directory -Force
$iconPath = Join-Path -Path $resolvedWorkingDirectory -ChildPath 'icon/icon.png'
if (Test-Path -Path $iconPath) {
    Copy-Item -Path $iconPath -Destination $assetsFolder.FullName -Force
}

$readmePath = Join-Path -Path $resolvedWorkingDirectory -ChildPath 'README.md'
$readmeTargetPath = Join-Path -Path $siteOutputPath -ChildPath 'docs/README.md'
Copy-Item -Path $readmePath -Destination $readmeTargetPath -Force

$possiblePaths = @(
    '.github/zensical.toml',
    'docs/zensical.toml',
    'zensical.toml'
)

$docsConfigSourcePath = $null
foreach ($relativePath in $possiblePaths) {
    $candidatePath = Join-Path -Path $resolvedWorkingDirectory -ChildPath $relativePath
    if (Test-Path -Path $candidatePath) {
        $docsConfigSourcePath = $candidatePath
        break
    }
}

if (-not $docsConfigSourcePath) {
    throw "Documentation config file not found. Expected one of: $($possiblePaths -join ', ')"
}

$docsConfigFileName = [System.IO.Path]::GetFileName($docsConfigSourcePath)
$docsConfigTargetPath = Join-Path -Path $siteOutputPath -ChildPath $docsConfigFileName

$docsConfigContent = Get-Content -Path $docsConfigSourcePath -Raw
$docsConfigContent = $docsConfigContent.Replace('-{{ REPO_NAME }}-', $moduleName)
$docsConfigContent = $docsConfigContent.Replace('-{{ REPO_OWNER }}-', $env:GITHUB_REPOSITORY_OWNER)

if ($docsConfigFileName -eq 'zensical.toml') {
    if ($docsConfigContent -match '(?m)^\s*site_dir\s*=') {
        $docsConfigContent = $docsConfigContent -replace '(?m)^\s*site_dir\s*=.*$', 'site_dir = "_site"'
    } else {
        $docsConfigContent = $docsConfigContent -replace '(?m)^\[project\]\s*$', "[project]`nsite_dir = ""_site"""
    }
}

Set-Content -Path $docsConfigTargetPath -Value $docsConfigContent -Force
Write-Host "Build Config Type:    $docsConfigFileName"
