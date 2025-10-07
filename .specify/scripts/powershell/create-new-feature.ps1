#!/usr/bin/env pwsh
# Create a new feature
[CmdletBinding()]
param(
    [switch]$Json,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FeatureDescription,
    [Parameter()]
    [string]$BranchName
)
$ErrorActionPreference = 'Stop'

# Source common functions
. "$PSScriptRoot/common.ps1"

if (-not $FeatureDescription -or $FeatureDescription.Count -eq 0) {
    Write-Error 'Usage: ./create-new-feature.ps1 [-Json] <feature description>'
    exit 1
}
$featureDesc = ($FeatureDescription -join ' ').Trim()

$fallbackRoot = (Find-RepositoryRoot -StartDir $PSScriptRoot)
if (-not $fallbackRoot) {
    Write-Error 'Error: Could not determine repository root. Please run this script from within the repository.'
    exit 1
}

try {
    $repoRoot = git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -eq 0) {
        $hasGit = $true
    } else {
        throw 'Git not available'
    }
} catch {
    $repoRoot = $fallbackRoot
    $hasGit = $false
}

Set-Location $repoRoot

$specsDir = Join-Path $repoRoot 'specs'
New-Item -ItemType Directory -Path $specsDir -Force | Out-Null

$highest = 0
if (Test-Path $specsDir) {
    Get-ChildItem -Path $specsDir -Directory | ForEach-Object {
        if ($_.Name -match '^(\d{3})') {
            $num = [int]$matches[1]
            if ($num -gt $highest) { $highest = $num }
        }
    }
}
$next = $highest + 1
$featureNum = ('{0:000}' -f $next)

# Determine if we should create a new branch or stay on the current one
$shouldCreateBranch = $false
$currentBranch = ''
$isExistingFeature = $false

if ($hasGit) {
    try {
        $currentBranch = git rev-parse --abbrev-ref HEAD 2>$null
        if ($LASTEXITCODE -eq 0) {
            # Create new branch only if we're on 'main' or a branch that doesn't start with 3 digits
            if ($currentBranch -eq 'main' -or $currentBranch -notmatch '^\d{3}-') {
                $shouldCreateBranch = $true
            } else {
                # We're on a feature branch, reuse it
                $isExistingFeature = $true
                $branchName = $currentBranch

                # Extract feature number from existing branch
                if ($branchName -match '^(\d{3})') {
                    $featureNum = $matches[1]
                }

                Write-Verbose "Staying on existing feature branch: $branchName"
            }
        }
    } catch {
        Write-Warning 'Failed to get current branch name'
        $shouldCreateBranch = $true
    }
}

# Only generate new branch name if we need to create a new branch
if ($shouldCreateBranch) {
    # Use provided BranchName if available, otherwise generate from feature description
    if ($BranchName) {
        # Sanitize the provided branch name
        $branchSuffix = $BranchName.ToLower() -replace '[^a-z0-9]', '-' -replace '-{2,}', '-' -replace '^-', '' -replace '-$', ''
    } else {
        # Fallback: Generate from feature description (first 3 words)
        $branchSuffix = $featureDesc.ToLower() -replace '[^a-z0-9]', '-' -replace '-{2,}', '-' -replace '^-', '' -replace '-$', ''
        $words = ($branchSuffix -split '-') | Where-Object { $_ } | Select-Object -First 3
        $branchSuffix = [string]::Join('-', $words)
    }

    $branchName = "$featureNum-$branchSuffix"
}

if ($hasGit -and $shouldCreateBranch) {
    try {
        git checkout -b $branchName | Out-Null
    } catch {
        Write-Warning "Failed to create git branch: $branchName"
    }
} elseif (-not $hasGit) {
    # If no git, still generate a branch name for directory structure
    if ($BranchName) {
        $branchSuffix = $BranchName.ToLower() -replace '[^a-z0-9]', '-' -replace '-{2,}', '-' -replace '^-', '' -replace '-$', ''
    } else {
        $branchSuffix = $featureDesc.ToLower() -replace '[^a-z0-9]', '-' -replace '-{2,}', '-' -replace '^-', '' -replace '-$', ''
        $words = ($branchSuffix -split '-') | Where-Object { $_ } | Select-Object -First 3
        $branchSuffix = [string]::Join('-', $words)
    }
    $branchName = "$featureNum-$branchSuffix"
    Write-Warning "[specify] Warning: Git repository not detected; skipped branch creation for $branchName"
}

$featureDir = Join-Path $specsDir $branchName
New-Item -ItemType Directory -Path $featureDir -Force | Out-Null

$template = Join-Path $repoRoot '.specify/templates/spec-template.md'
$specFile = Join-Path $featureDir 'spec.md'
if (Test-Path $template) {
    Copy-Item $template $specFile -Force
} else {
    New-Item -ItemType File -Path $specFile | Out-Null
}

# Set the SPECIFY_FEATURE environment variable for the current session
$env:SPECIFY_FEATURE = $branchName

if ($Json) {
    $obj = [PSCustomObject]@{
        BRANCH_NAME        = $branchName
        SPEC_FILE          = $specFile
        FEATURE_NUM        = $featureNum
        HAS_GIT            = $hasGit
        IS_EXISTING_BRANCH = $isExistingFeature
        CURRENT_BRANCH     = $currentBranch
    }
    $obj | ConvertTo-Json -Compress
} else {
    Write-Output "BRANCH_NAME: $branchName"
    Write-Output "SPEC_FILE: $specFile"
    Write-Output "FEATURE_NUM: $featureNum"
    Write-Output "HAS_GIT: $hasGit"
    Write-Output "IS_EXISTING_BRANCH: $isExistingFeature"
    if ($isExistingFeature) {
        Write-Output "Reusing existing feature branch: $branchName"
    }
    Write-Output "SPECIFY_FEATURE environment variable set to: $branchName"
}
