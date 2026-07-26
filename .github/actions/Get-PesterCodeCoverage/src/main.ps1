#Requires -Modules GitHub

[CmdletBinding()]
param()

LogGroup 'Init - Setup prerequisites' {
    'Markdown' | ForEach-Object {
        $name = $_
        Write-Output "Installing module: $name"
        $retryCount = 5
        $retryDelay = 10
        for ($i = 0; $i -lt $retryCount; $i++) {
            try {
                Install-PSResource -Name $name -WarningAction SilentlyContinue -TrustRepository -Repository PSGallery
                break
            } catch {
                Write-Warning "Installation of $name failed with error: $_"
                if ($i -eq $retryCount - 1) {
                    throw
                }
                Write-Warning "Retrying in $retryDelay seconds..."
                Start-Sleep -Seconds $retryDelay
            }
        }
        Import-Module -Name $name
    }
    Import-Module "$PSScriptRoot/Get-PesterCodeCoverage.Helpers.psm1"
}

$owner = $env:GITHUB_REPOSITORY_OWNER
$repo = $env:GITHUB_REPOSITORY_NAME
$runId = $env:GITHUB_RUN_ID

$files = Get-GitHubArtifact -Owner $owner -Repository $repo -WorkflowRunID $runId -Name '*-CodeCoverage' |
    Save-GitHubArtifact -Path 'CodeCoverage' -Force -Expand -PassThru | Get-ChildItem -Recurse -Filter *.json | Sort-Object Name -Unique

LogGroup 'List files' {
    $files.Name | Out-String
}

# Accumulators for coverage items across all files
$allMissed = @()
$allExecuted = @()
$allFiles = @()
$allTargets = @()

foreach ($file in $files) {
    $groupName = $file.BaseName.Replace('-CodeCoverage-Report', '')
    LogGroup " - $groupName" {
        Write-Verbose "Processing file: $($file.FullName)"

        # Convert each JSON file into an object
        $jsonContent = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json

        [pscustomobject]@{
            Coverage = "$([Math]::Round($jsonContent.CoveragePercent, 2))%"
            Target   = "$([Math]::Round($jsonContent.CoveragePercentTarget, 2))%"
            Analyzed = "$($jsonContent.CommandsAnalyzedCount) commands"
            Executed = "$($jsonContent.CommandsExecutedCount) commands"
            Missed   = "$($jsonContent.CommandsMissedCount) commands"
            Files    = "$($jsonContent.FilesAnalyzedCount) files"
        } | Format-Table -AutoSize | Out-String

        # --- Normalize file paths in CommandsMissed, CommandsExecuted, and FilesAnalyzed ---
        # 1. Normalize every "File" property in CommandsMissed
        foreach ($missed in $jsonContent.CommandsMissed) {
            if ($missed.File) {
                $missed.File = ($missed.File -Split '999.0.0')[-1].Replace('\', '/').TrimStart('/').TrimEnd('/')
            }
        }

        # 2. Normalize every "File" property in CommandsExecuted
        foreach ($exec in $jsonContent.CommandsExecuted) {
            if ($exec.File) {
                $exec.File = ($exec.File -Split '999.0.0')[-1].Replace('\', '/').TrimStart('/').TrimEnd('/')
            }
        }

        # 3. Normalize the file paths in FilesAnalyzed
        $normalizedFiles = @()
        $jsonContent.FilesAnalyzed = $jsonContent.FilesAnalyzed | Sort-Object -Unique
        foreach ($fa in $jsonContent.FilesAnalyzed) {
            $normalizedFiles += ($fa -Split '999.0.0')[-1].Replace('\', '/').TrimStart('/').TrimEnd('/')
        }
        $jsonContent.FilesAnalyzed = $normalizedFiles

        # Now accumulate coverage items
        $allMissed += $jsonContent.CommandsMissed
        $allExecuted += $jsonContent.CommandsExecuted
        $allFiles += $jsonContent.FilesAnalyzed
        $allTargets += $jsonContent.CoveragePercentTarget
    }
}

# -- Remove duplicates from each set --
$finalExecuted = $allExecuted |
    Sort-Object -Property File, Line, Command, StartColumn, EndColumn, Class, Function -Unique

$finalFiles = $allFiles | Sort-Object -Unique

# -- Remove from missed any command that shows up in executed --
$executedKeys = $finalExecuted | ForEach-Object {
    '{0}|{1}|{2}|{3}|{4}|{5}|{6}' -f $_.File, $_.Line, $_.Command, $_.StartColumn, $_.EndColumn, $_.Class, $_.Function
}
$finalMissed = $allMissed |
    Sort-Object -Property File, Line, Command, StartColumn, EndColumn, Class, Function -Unique |
    Where-Object {
        $key = '{0}|{1}|{2}|{3}|{4}|{5}|{6}' -f $_.File, $_.Line, $_.Command, $_.StartColumn, $_.EndColumn, $_.Class, $_.Function
        $executedKeys -notcontains $key
    }

# -- Compute the new coverage percentages --
$missedCount = $finalMissed.Count
$executedCount = $finalExecuted.Count
$totalAnalyzed = $missedCount + $executedCount

if ($totalAnalyzed -gt 0) {
    $coveragePercent = [Math]::Round(($executedCount / $totalAnalyzed) * 100, 2)
} else {
    $coveragePercent = 0
}

$CodeCoveragePercentTarget = $env:PSMODULE_GET_PESTERCODECOVERAGE_INPUT_CodeCoveragePercentTarget
if ($CodeCoveragePercentTarget) {
    $coveragePercentTarget = $CodeCoveragePercentTarget
} else {
    $coveragePercentTarget = $allTargets | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum
    if (-not $coveragePercentTarget) {
        $coveragePercentTarget = 0
    }
}

# -- Build final coverage object --
$codeCoverage = [PSCustomObject]@{
    CommandsMissed        = $finalMissed
    CommandsExecuted      = $finalExecuted
    FilesAnalyzed         = $finalFiles
    CoveragePercent       = $coveragePercent
    CoveragePercentTarget = $coveragePercentTarget
    CoverageReport        = ''
    CommandsAnalyzedCount = [Int64]$totalAnalyzed
    CommandsExecutedCount = [Int64]$executedCount
    CommandsMissedCount   = [Int64]$missedCount
    FilesAnalyzedCount    = [Int64]$finalFiles.Count
}

# Print stats:
$stats = [pscustomobject]@{
    Coverage = "$([Math]::Round($codeCoverage.CoveragePercent, 2))%"
    Target   = "$([Math]::Round($codeCoverage.CoveragePercentTarget, 2))%"
    Analyzed = "$($codeCoverage.CommandsAnalyzedCount) commands"
    Executed = "$($codeCoverage.CommandsExecutedCount) commands"
    Missed   = "$($codeCoverage.CommandsMissedCount) commands"
    Files    = "$($codeCoverage.FilesAnalyzedCount) files"
}

$success = $coveragePercent -ge $coveragePercentTarget
$statusIcon = $success ? '✅' : '❌'
$stats | Format-Table -AutoSize | Out-String

$missedPaths = $codeCoverage.CommandsMissed |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_.File) } |
    Group-Object -Property File |
    Sort-Object -Property @(
        @{ Expression = 'Count'; Descending = $true },
        @{ Expression = 'Name'; Descending = $false }
    ) |
    ForEach-Object {
        $lines = $_.Group |
            Where-Object { $_.Line -is [ValueType] } |
            ForEach-Object { [int]$_.Line } |
            Sort-Object -Unique
        [pscustomobject]@{
            Path           = $_.Name
            MissedCommands = [int]$_.Count
            MissedLines    = if ($lines.Count -eq 0) { '' } else { ($lines -join ', ') }
        }
    }

$missedPathReportPath = 'CodeCoverage-MissedPaths'
$null = New-Item -Path $missedPathReportPath -ItemType Directory -Force

$missedPathReport = [ordered]@{
    GeneratedAtUtc  = [DateTime]::UtcNow.ToString('o')
    CoveragePercent = [double]$coveragePercent
    CoverageTarget  = [double]$coveragePercentTarget
    MissedPaths     = @($missedPaths)
}

$missedPathReportJsonPath = Join-Path -Path $missedPathReportPath -ChildPath 'CodeCoverage-MissedPaths.json'
$missedPathReportMarkdownPath = Join-Path -Path $missedPathReportPath -ChildPath 'CodeCoverage-MissedPaths.md'
$missedPathReport | ConvertTo-Json -Depth 10 | Set-Content -Path $missedPathReportJsonPath -Encoding utf8NoBOM

$missedPathMarkdown = [System.Collections.Generic.List[string]]::new()
$null = $missedPathMarkdown.Add('# Code Coverage Missed Paths')
$null = $missedPathMarkdown.Add('')
$null = $missedPathMarkdown.Add("| Coverage | Target | Missed Paths | Missed Commands |")
$null = $missedPathMarkdown.Add("| --- | --- | --- | --- |")
$null = $missedPathMarkdown.Add("| $([Math]::Round($coveragePercent, 2))% | $([Math]::Round($coveragePercentTarget, 2))% | $($missedPaths.Count) | $($codeCoverage.CommandsMissedCount) |")
$null = $missedPathMarkdown.Add('')
$null = $missedPathMarkdown.Add('## Paths')
$null = $missedPathMarkdown.Add('| Path | Missed Commands | Missed Lines |')
$null = $missedPathMarkdown.Add('| --- | ---: | --- |')
if ($missedPaths.Count -eq 0) {
    $null = $missedPathMarkdown.Add('| _None_ | 0 |  |')
} else {
    foreach ($pathEntry in $missedPaths) {
        $safePath = ([string]$pathEntry.Path).Replace('|', '\|')
        $safeLines = ([string]$pathEntry.MissedLines).Replace('|', '\|')
        $null = $missedPathMarkdown.Add("| $safePath | $($pathEntry.MissedCommands) | $safeLines |")
    }
}

$missedPathMarkdown | Set-Content -Path $missedPathReportMarkdownPath -Encoding utf8NoBOM
Write-Output 'Missed path report generated:'
$missedPaths | Select-Object -First 20 | Format-Table -Property Path, MissedCommands, MissedLines -AutoSize | Out-String
if ($env:GITHUB_OUTPUT) {
    "MissedPathReportPath=$missedPathReportPath" >> $env:GITHUB_OUTPUT
}

# Build HTML table for 'missed' commands
$tableheader = @'
<table>
<thead>
<tr>
<th>File</th>
<th>Line</th>
<th>StartColumn</th>
<th>EndColumn</th>
<th>Class</th>
<th>Function</th>
<th>Command</th>
</tr>
</thead>
<tbody>
'@

$tablefooter = @'
</tbody>
</table>

'@

LogGroup 'Step Summary - Set table for missed commands' {
    $missedForDisplay = $tableheader

    foreach ($item in $codeCoverage.CommandsMissed | Sort-Object -Property File, Line) {
        $command = Normalize-IndentationExceptFirst -Code $item.Command
        $missedForDisplay += @"
<tr>
<td>$($item.File)</td>
<td>$($item.Line)</td>
<td>$($item.StartColumn)</td>
<td>$($item.EndColumn)</td>
<td>$($item.Class)</td>
<td>$($item.Function)</td>
<td>

``````pwsh
$command
``````

</td>
</tr>

"@
    }

    $missedForDisplay += $tablefooter
}

LogGroup 'Step Summary - Set table for executed commands' {
    $executedForDisplay = $tableheader

    foreach ($item in $codeCoverage.CommandsExecuted | Sort-Object -Property File, Line) {
        $command = Normalize-IndentationExceptFirst -Code $item.Command
        $executedForDisplay += @"
<tr>
<td>$($item.File)</td>
<td>$($item.Line)</td>
<td>$($item.StartColumn)</td>
<td>$($item.EndColumn)</td>
<td>$($item.Class)</td>
<td>$($item.Function)</td>
<td>

``````pwsh
$command
``````

</td>
</tr>

"@
    }

    $executedForDisplay += $tablefooter
}

LogGroup 'Step Summary - Set step summary' {
    # Get the step summary mode from the environment variable
    $stepSummaryMode = $env:PSMODULE_GET_PESTERCODECOVERAGE_INPUT_StepSummary_Mode
    if ([string]::IsNullOrEmpty($stepSummaryMode)) {
        $stepSummaryMode = 'Full'
    }

    Write-Verbose "Step Summary Mode: $stepSummaryMode"

    # If mode is 'None', skip step summary generation completely
    if ($stepSummaryMode -eq 'None') {
        Write-Verbose 'Step summary is disabled'
        return
    }

    # Define which sections to include
    $includeMissed = $false
    $includeExecuted = $false
    $includeFiles = $false

    if ($stepSummaryMode -eq 'Full') {
        # Include all sections
        $includeMissed = $true
        $includeExecuted = $true
        $includeFiles = $true
    } else {
        # Parse comma-separated list
        $sections = $stepSummaryMode -split ',' | ForEach-Object { $_.Trim() }

        $includeMissed = $sections -contains 'Missed'
        $includeExecuted = $sections -contains 'Executed'
        $includeFiles = $sections -contains 'Files'
    }

    # -- Output the markdown to GitHub step summary --
    $markdown = Heading 1 "$statusIcon Code Coverage Report" {

        Heading 2 'Summary' {
            Table {
                $stats
            }

            if ($includeMissed) {
                Details "Missed commands [$($codeCoverage.CommandsMissedCount)]" {
                    $missedForDisplay
                }
            }

            if ($includeExecuted) {
                Details "Executed commands [$($codeCoverage.CommandsExecutedCount)]" {
                    $executedForDisplay
                }
            }

            if ($includeFiles) {
                Details "Files analyzed [$($codeCoverage.FilesAnalyzedCount)]" {
                    Paragraph {
                        $codeCoverage.FilesAnalyzed | ForEach-Object {
                            Write-Output "- $_"
                        }
                    }
                }
            }

            Details "Missed paths [$($missedPaths.Count)]" {
                if ($missedPaths.Count -eq 0) {
                    Paragraph {
                        Write-Output 'No missed paths were detected.'
                    }
                } else {
                    Table {
                        $missedPaths | Select-Object -First 100
                    }
                }
            }
        }
    }

    Set-GitHubStepSummary -Summary $markdown
}


# Throw an error if coverage is below target
if ($coveragePercent -lt $coveragePercentTarget) {
    Write-GitHubError "Coverage is below target! Found $coveragePercent%, target is $coveragePercentTarget%."
    exit 1
}

Write-GitHubNotice "Coverage is above target! Found $coveragePercent%, target is $coveragePercentTarget%."
exit 0
