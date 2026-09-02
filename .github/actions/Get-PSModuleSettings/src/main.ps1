'powershell-yaml', 'Hashtable' | Install-PSResource -Repository PSGallery -TrustRepository
Import-Module -Name "$PSScriptRoot/Get-PSModuleSettings.Helpers.psm1" -Force

$name = $env:PSMODULE_GET_SETTINGS_INPUT_Name
$settingsPath = $env:PSMODULE_GET_SETTINGS_INPUT_SettingsPath
$debug = $env:PSMODULE_GET_SETTINGS_INPUT_Debug
$verbose = $env:PSMODULE_GET_SETTINGS_INPUT_Verbose
$version = $env:PSMODULE_GET_SETTINGS_INPUT_Version
$prerelease = $env:PSMODULE_GET_SETTINGS_INPUT_Prerelease
$workingDirectory = $env:PSMODULE_GET_SETTINGS_INPUT_WorkingDirectory
$importantFilePatternsInput = $env:PSMODULE_GET_SETTINGS_INPUT_ImportantFilePatterns

LogGroup 'Inputs' {
    [pscustomobject]@{
        PWD          = (Get-Location).Path
        Name         = $name
        SettingsPath = $settingsPath
    } | Format-List | Out-String
}

if (![string]::IsNullOrEmpty($settingsPath) -and (Test-Path -Path $settingsPath)) {
    LogGroup 'Import settings' {
        $settingsFile = Get-Item -Path $settingsPath
        $relativeSettingsPath = $settingsFile | Resolve-Path -Relative
        Write-Host "Importing settings from [$relativeSettingsPath]"
        $content = $settingsFile | Get-Content -Raw
        switch -Regex ($settingsFile.Extension) {
            '.json' {
                $settings = $content | ConvertFrom-Json
                Write-Host ($settings | ConvertTo-Json -Depth 5 | Out-String)
            }
            '.yaml|.yml' {
                $settings = $content | ConvertFrom-Yaml
                Write-Host ($settings | ConvertTo-Yaml | Out-String)
            }
            '.psd1' {
                $settings = $content | ConvertFrom-Hashtable
                Write-Host ($settings | ConvertTo-Hashtable | Format-Hashtable | Out-String)
            }
            default {
                throw "Unsupported settings file format: [$settingsPath]. Supported formats are json, yaml/yml and psd1."
            }
        }
    }

    LogGroup 'Validate settings against schema' {
        $schemaPath = Join-Path $PSScriptRoot 'Settings.schema.json'
        if (Test-Path -Path $schemaPath) {
            Write-Host 'Validating settings against schema...'
            $schema = Get-Content $schemaPath -Raw

            # Convert settings to JSON for validation
            $settingsJson = $settings | ConvertTo-Json -Depth 10

            try {
                $isValid = Test-Json -Json $settingsJson -Schema $schema -ErrorAction Stop
                if ($isValid) {
                    Write-Host '✓ Settings conform to schema'
                } else {
                    throw 'Settings do not conform to the schema'
                }
            } catch {
                Write-Error "Schema validation failed: $_"
                Write-Error 'Your settings file does not match the expected schema structure.'
                throw
            }
        } else {
            Write-Warning "Schema file not found at [$schemaPath]. Skipping validation."
        }
    }
} else {
    Write-Host 'No settings file present.'
    $settings = @{}
}

LogGroup 'Name' {
    [pscustomobject]@{
        InputName      = $name
        SettingsName   = $settings.Name
        RepositoryName = $env:GITHUB_REPOSITORY_NAME
    } | Format-List | Out-String

    if (![string]::IsNullOrEmpty($name)) {
        Write-Host "Using name from input parameter: [$name]"
    } elseif (![string]::IsNullOrEmpty($settings.Name)) {
        $name = $settings.Name
        Write-Host "Using name from settings file: [$name]"
    } else {
        $name = $env:GITHUB_REPOSITORY_NAME
        Write-Host "Using repository name: [$name]"
    }
}

LogGroup 'ImportantFilePatterns' {
    $defaultImportantFilePatterns = @('^src/', '^README\.md$')
    if ($null -ne $settings.ImportantFilePatterns) {
        $importantFilePatterns = @($settings.ImportantFilePatterns)
        Write-Host "Using ImportantFilePatterns from settings file: [$($importantFilePatterns -join ', ')]"
    } elseif (-not [string]::IsNullOrWhiteSpace($importantFilePatternsInput)) {
        $importantFilePatterns = @($importantFilePatternsInput -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        Write-Host "Using ImportantFilePatterns from action input: [$($importantFilePatterns -join ', ')]"
    } else {
        $importantFilePatterns = $defaultImportantFilePatterns
        Write-Host "Using default ImportantFilePatterns: [$($importantFilePatterns -join ', ')]"
    }

    # Validate that all patterns are valid regular expressions
    foreach ($pattern in $importantFilePatterns) {
        try {
            [void][regex]::new($pattern)
        } catch {
            throw "Invalid regex in ImportantFilePatterns: '$pattern'. $_"
        }
    }
}

$settings = [pscustomobject]@{
    Name                  = $name
    ImportantFilePatterns = $importantFilePatterns
    Test                  = [pscustomobject]@{
        Skip         = $settings.Test.Skip ?? $false
        Linux        = [pscustomobject]@{
            Skip = $settings.Test.Linux.Skip ?? $false
        }
        MacOS        = [pscustomobject]@{
            Skip = $settings.Test.MacOS.Skip ?? $false
        }
        Windows      = [pscustomobject]@{
            Skip = $settings.Test.Windows.Skip ?? $false
        }
        SourceCode   = [pscustomobject]@{
            Skip    = $settings.Test.SourceCode.Skip ?? $false
            Linux   = [pscustomobject]@{
                Skip = $settings.Test.SourceCode.Linux.Skip ?? $false
            }
            MacOS   = [pscustomobject]@{
                Skip = $settings.Test.SourceCode.MacOS.Skip ?? $false
            }
            Windows = [pscustomobject]@{
                Skip = $settings.Test.SourceCode.Windows.Skip ?? $false
            }
        }
        PSModule     = [pscustomobject]@{
            Skip    = $settings.Test.PSModule.Skip ?? $false
            Linux   = [pscustomobject]@{
                Skip = $settings.Test.PSModule.Linux.Skip ?? $false
            }
            MacOS   = [pscustomobject]@{
                Skip = $settings.Test.PSModule.MacOS.Skip ?? $false
            }
            Windows = [pscustomobject]@{
                Skip = $settings.Test.PSModule.Windows.Skip ?? $false
            }
        }
        Module       = [pscustomobject]@{
            Skip    = $settings.Test.Module.Skip ?? $false
            Linux   = [pscustomobject]@{
                Skip = $settings.Test.Module.Linux.Skip ?? $false
            }
            MacOS   = [pscustomobject]@{
                Skip = $settings.Test.Module.MacOS.Skip ?? $false
            }
            Windows = [pscustomobject]@{
                Skip = $settings.Test.Module.Windows.Skip ?? $false
            }
        }
        TestResults  = [pscustomobject]@{
            Skip = $settings.Test.TestResults.Skip ?? $false
        }
        CodeCoverage = [pscustomobject]@{
            Skip            = $settings.Test.CodeCoverage.Skip ?? $false
            PercentTarget   = $settings.Test.CodeCoverage.PercentTarget ?? 0
            StepSummaryMode = $settings.Test.CodeCoverage.StepSummaryMode ?? 'Missed, Files'
        }
    }
    Build                 = [pscustomobject]@{
        Skip   = $settings.Build.Skip ?? $false
        Module = [pscustomobject]@{
            Skip = $settings.Build.Module.Skip ?? $false
        }
        Docs   = [pscustomobject]@{
            Skip                 = $settings.Build.Docs.Skip ?? $false
            ShowSummaryOnSuccess = $settings.Build.Docs.ShowSummaryOnSuccess ?? $false
        }
        Site   = [pscustomobject]@{
            Skip = $settings.Build.Site.Skip ?? $false
        }
    }
    Publish               = [pscustomobject]@{
        Module = [pscustomobject]@{
            Skip                     = $settings.Publish.Module.Skip ?? $false
            AutoCleanup              = $settings.Publish.Module.AutoCleanup ?? $true
            AutoPatching             = $settings.Publish.Module.AutoPatching ?? $true
            IncrementalPrerelease    = $settings.Publish.Module.IncrementalPrerelease ?? $true
            DatePrereleaseFormat     = $settings.Publish.Module.DatePrereleaseFormat ?? ''
            VersionPrefix            = $settings.Publish.Module.VersionPrefix ?? 'v'
            MajorLabels              = $settings.Publish.Module.MajorLabels ?? 'major, breaking'
            MinorLabels              = $settings.Publish.Module.MinorLabels ?? 'minor, feature'
            PatchLabels              = $settings.Publish.Module.PatchLabels ?? 'patch, fix'
            IgnoreLabels             = $settings.Publish.Module.IgnoreLabels ?? 'NoRelease'
            PrereleaseLabels         = $settings.Publish.Module.PrereleaseLabels ?? 'prerelease'
            UsePRTitleAsReleaseName  = $settings.Publish.Module.UsePRTitleAsReleaseName ?? $false
            UsePRBodyAsReleaseNotes  = $settings.Publish.Module.UsePRBodyAsReleaseNotes ?? $true
            UsePRTitleAsNotesHeading = $settings.Publish.Module.UsePRTitleAsNotesHeading ?? $true
        }
        Site   = [pscustomobject]@{
            Skip = $settings.Publish.Site.Skip ?? $false
        }
    }
    Linter                = [pscustomobject]@{
        Skip                 = $settings.Linter.Skip ?? $false
        ShowSummaryOnSuccess = $settings.Linter.ShowSummaryOnSuccess ?? $false
        env                  = $settings.Linter.env ?? @{}
    }
}

# Add input properties to settings
$settings | Add-Member -MemberType NoteProperty -Name SettingsPath -Value $settingsPath
$settings | Add-Member -MemberType NoteProperty -Name Debug -Value $debug
$settings | Add-Member -MemberType NoteProperty -Name Verbose -Value $verbose
$settings | Add-Member -MemberType NoteProperty -Name Version -Value $version
$settings | Add-Member -MemberType NoteProperty -Name Prerelease -Value $prerelease
$settings | Add-Member -MemberType NoteProperty -Name WorkingDirectory -Value $workingDirectory

# Calculate job run conditions
LogGroup 'Calculate Job Run Conditions:' {
    $eventData = Get-GitHubEventData -ErrorAction Stop

    LogGroup 'GitHub Event Data' {
        $eventData | ConvertTo-Json -Depth 10 | Out-String
    }

    $eventName = $env:GITHUB_EVENT_NAME
    $isPush = $eventName -eq 'push'
    $isManualDispatch = $eventName -eq 'workflow_dispatch'
    $defaultBranch = $eventData.Repository.default_branch
    $pullRequestAction = $eventData.Action
    $commitSha = if ($isPush) { $eventData.After ?? $env:GITHUB_SHA } else { $env:GITHUB_SHA }
    $pushBranch = if ($isPush) { $eventData.Ref -replace '^refs/heads/', '' } else { '' }
    $workflowRef = if ($isPush) { $pushBranch } else { $env:GITHUB_REF_NAME }
    $isPushToDefaultBranch = $isPush -and $pushBranch -eq $defaultBranch
    $isManualDispatchToDefaultBranch = $isManualDispatch -and $workflowRef -eq $defaultBranch
    $pullRequest = $eventData.PullRequest

    # A manual dispatch on the default branch is the documented recovery route for a failed or
    # cancelled release run. It targets the same merge commit as the push it replaces, so it must
    # resolve the same pull request and honour the same version label. Gating this lookup on
    # $isPush alone left $pullRequest null for a dispatch, which silently downgraded a labelled
    # Major or Minor release to a Patch bump through the AutoPatching fallback.
    $shouldResolvePullRequest = Test-ShouldResolveAssociatedPullRequest -IsPush $isPush `
        -IsManualDispatchToDefaultBranch $isManualDispatchToDefaultBranch `
        -CommitSha $commitSha
    if ($shouldResolvePullRequest) {
        LogGroup "Resolve pull request for commit [$commitSha]" {
            $owner = $env:GITHUB_REPOSITORY_OWNER
            $repo = $env:GITHUB_REPOSITORY_NAME
            $response = Invoke-GitHubAPI -ApiEndpoint "/repos/$owner/$repo/commits/$commitSha/pulls" -Method GET
            $associatedPullRequests = @($response.Response | Where-Object { $null -ne $_ })
            $pullRequest = Select-PullRequestForPush -PullRequest $associatedPullRequests `
                -DefaultBranch $defaultBranch `
                -CommitSha $commitSha

            if ($pullRequest) {
                Write-Host "Resolved pull request #$($pullRequest.Number) from commit [$commitSha]."
            } else {
                # Distinguish 'no pull request carries release intent' from 'a merged default-branch
                # pull request exists but was not selected'. The first is a legitimate direct push to
                # the default branch, which the direct-release path handles with the default patch
                # bump. The second means the commit carries a version label that would be discarded,
                # and a wrong version published to the PowerShell Gallery cannot be reclaimed, so
                # fail loudly instead. Only release-bearing events are checked; a push to a feature
                # branch has no release to get wrong.
                $isReleaseEvent = $isPushToDefaultBranch -or $isManualDispatchToDefaultBranch
                $discardedPullRequests = if ($isReleaseEvent) {
                    @(Get-DiscardedReleasePullRequest -PullRequest $associatedPullRequests `
                            -DefaultBranch $defaultBranch `
                            -CommitSha $commitSha)
                } else {
                    @()
                }
                if ($discardedPullRequests.Count -gt 0) {
                    throw (
                        "Commit [$commitSha] cannot be released because its version label cannot be determined. " +
                        'The following merged pull request(s) are associated with it but none matches the commit ' +
                        "being released: $($discardedPullRequests -join '; '). " +
                        'Refusing to fall back to a patch bump, because a wrong version published to the ' +
                        'PowerShell Gallery cannot be reclaimed. Re-run the workflow against the merge commit ' +
                        'of the pull request you intend to release.'
                    )
                }
                Write-Host "::notice::No pull request is associated with commit [$commitSha]."
            }
        }
    }

    $pullRequestIsMerged = if ($null -eq $pullRequest) {
        $false
    } elseif ($null -ne $pullRequest.Merged) {
        [bool]$pullRequest.Merged
    } else {
        -not [string]::IsNullOrWhiteSpace($pullRequest.merged_at)
    }
    $pullRequestIsClosed = $null -ne $pullRequest -and $pullRequest.State -eq 'closed'
    $isOpenOrUpdatedPR = (
        $eventName -eq 'pull_request' -and
        -not $pullRequestIsClosed -and
        $pullRequestAction -in @('opened', 'reopened', 'synchronize', 'labeled', 'unlabeled')
    )
    $targetBranch = if ($pullRequest) { $pullRequest.Base.Ref } elseif ($isPush) { $pushBranch } else { $workflowRef }
    $isTargetDefaultBranch = $targetBranch -eq $defaultBranch
    $pullRequestContext = if ($pullRequest) {
        [pscustomobject]@{
            Number         = $pullRequest.Number
            Title          = $pullRequest.Title
            Body           = $pullRequest.Body
            HeadRef        = $pullRequest.Head.Ref
            BaseRef        = $pullRequest.Base.Ref
            Labels         = @($pullRequest.Labels.Name)
            Merged         = $pullRequestIsMerged
            Closed         = $pullRequestIsClosed
            MergeCommitSha = $pullRequest.merge_commit_sha
            HtmlUrl        = $pullRequest.html_url
        }
    } else {
        $null
    }

    $settings | Add-Member -MemberType NoteProperty -Name Context -Value ([pscustomobject]@{
            EventName                       = $eventName
            EventAction                     = $pullRequestAction
            CommitSha                       = $commitSha
            Ref                             = if ($isPush) { $eventData.Ref } else { $env:GITHUB_REF }
            DefaultBranch                   = $defaultBranch
            IsPushToDefaultBranch           = $isPushToDefaultBranch
            IsManualDispatchToDefaultBranch = $isManualDispatchToDefaultBranch
            PullRequest                     = $pullRequestContext
        }) -Force

    Write-Host 'GitHub event inputs:'
    [pscustomobject]@{
        GITHUB_EVENT_NAME                = $eventName
        GITHUB_EVENT_ACTION              = $pullRequestAction
        GITHUB_EVENT_PULL_REQUEST_MERGED = $pullRequestIsMerged
        GITHUB_EVENT_PULL_REQUEST_CLOSED = $pullRequestIsClosed
        CommitSha                        = $commitSha
        PushBranch                       = $pushBranch
        TargetBranch                     = $targetBranch
        DefaultBranch                    = $defaultBranch
        IsTargetDefaultBranch            = $isTargetDefaultBranch
        IsPushToDefaultBranch            = $isPushToDefaultBranch
        IsManualDispatchToDefaultBranch  = $isManualDispatchToDefaultBranch
        AssociatedPullRequest            = $pullRequestContext.Number
    } | Format-List | Out-String

    # Check if a prerelease label exists on the PR
    $prereleaseLabels = $settings.Publish.Module.PrereleaseLabels -split ',' | ForEach-Object { $_.Trim() }
    $prLabels = @($pullRequestContext.Labels)
    $hasPrereleaseLabel = ($prLabels | Where-Object { $prereleaseLabels -contains $_ }).Count -gt 0

    # Check if important files have changed in the PR
    # Important files are determined by the configured ImportantFilePatterns setting
    $hasImportantChanges = $false
    if ($eventName -eq 'pull_request' -and $pullRequestContext.Number) {
        LogGroup 'Check for Important File Changes' {
            $owner = $env:GITHUB_REPOSITORY_OWNER
            $repo = $env:GITHUB_REPOSITORY_NAME
            $prNumber = $pullRequestContext.Number

            Write-Host "Fetching changed files for PR #$prNumber..."
            $changedFiles = Invoke-GitHubAPI -ApiEndpoint "/repos/$owner/$repo/pulls/$prNumber/files" -Method GET |
                Select-Object -ExpandProperty Response |
                Select-Object -ExpandProperty filename

            Write-Host "Changed files ($($changedFiles.Count)):"
            $changedFiles | ForEach-Object { Write-Host "  - $_" }

            # Use configured important file patterns
            $importantPatterns = $settings.ImportantFilePatterns

            # Check if any changed file matches an important pattern
            foreach ($file in $changedFiles) {
                foreach ($pattern in $importantPatterns) {
                    if ($file -match $pattern) {
                        $hasImportantChanges = $true
                        Write-Host "Important file changed: [$file] (matches pattern: $pattern)"
                        break
                    }
                }
                if ($hasImportantChanges) { break }
            }

            if ($hasImportantChanges) {
                Write-Host '✓ Important files have changed - build/test stages will run'
            } else {
                Write-Host '✗ No important files changed - build/test stages will be skipped'

                # Add a comment to open PRs explaining why build/test is skipped (best-effort, may fail if permissions not granted)
                if ($isOpenOrUpdatedPR) {
                    $patternRows = ($importantPatterns | ForEach-Object {
                            $escapedPattern = $_.Replace('|', '\|')
                            $backtickMatches = [regex]::Matches($escapedPattern, '`+')
                            $maxRun = 0
                            foreach ($m in $backtickMatches) {
                                if ($m.Value.Length -gt $maxRun) { $maxRun = $m.Value.Length }
                            }
                            $codeDelimiter = '`' * ($maxRun + 1)
                            "| ${codeDelimiter}${escapedPattern}${codeDelimiter} | Matches files where path matches this pattern |"
                        }) -join "`n"
                    $commentBody = @"
### No Significant Changes Detected

This PR does not contain changes to files that would trigger a new release:

| Pattern | Description |
| :--- | :---------- |
$patternRows

**Build, test, and publish stages will be skipped** for this PR.

If you believe this is incorrect, please verify that your changes are in the correct locations.
"@
                    try {
                        Write-Host 'Adding comment to PR about skipped stages...'
                        $apiParams = @{
                            Method      = 'POST'
                            ApiEndpoint = "/repos/$owner/$repo/issues/$prNumber/comments"
                            Body        = @{ body = $commentBody } | ConvertTo-Json
                        }
                        $null = Invoke-GitHubAPI @apiParams
                        Write-Host '✓ Comment added successfully'
                    } catch {
                        Write-Warning "Could not add PR comment (may need 'issues: write' permission): $_"
                    }
                }
            }
        }
    } elseif ($isPushToDefaultBranch) {
        LogGroup 'Check for Important File Changes' {
            $beforeCommitSha = $eventData.Before
            $owner = $env:GITHUB_REPOSITORY_OWNER
            $repo = $env:GITHUB_REPOSITORY_NAME
            if ([string]::IsNullOrWhiteSpace($beforeCommitSha) -or $beforeCommitSha -match '^0+$') {
                Write-Host "Fetching files for the initial push commit [$commitSha]..."
                $commit = (Invoke-GitHubAPI -ApiEndpoint "/repos/$owner/$repo/git/commits/$commitSha" -Method GET).Response
                $treeSha = $commit.tree.sha
                if ([string]::IsNullOrWhiteSpace($treeSha)) {
                    throw "Cannot determine changed files because commit [$commitSha] has no tree."
                }

                $tree = (Invoke-GitHubAPI -ApiEndpoint "/repos/$owner/$repo/git/trees/$treeSha?recursive=1" -Method GET).Response
                $changedFiles = Get-FilesFromGitTree -Tree $tree
            } else {
                Write-Host "Fetching changed files between [$beforeCommitSha] and [$commitSha]..."
                $comparison = (Invoke-GitHubAPI -ApiEndpoint "/repos/$owner/$repo/compare/$beforeCommitSha...$commitSha" -Method GET).Response
                $changedFiles = Get-FilesFromGitHubComparison -Comparison $comparison
            }

            Write-Host "Changed files ($($changedFiles.Count)):"
            $changedFiles | ForEach-Object { Write-Host "  - $_" }

            foreach ($file in $changedFiles) {
                foreach ($pattern in $settings.ImportantFilePatterns) {
                    if ($file -match $pattern) {
                        $hasImportantChanges = $true
                        Write-Host "Important file changed: [$file] (matches pattern: $pattern)"
                        break
                    }
                }
                if ($hasImportantChanges) { break }
            }
        }
    } else {
        # Manual dispatch and schedule runs retain their existing build/test behavior.
        $hasImportantChanges = $true
        Write-Host 'Non-PR event - treating as having important changes'
    }

    $routing = Resolve-WorkflowEventRouting -EventName $eventName `
        -EventAction $pullRequestAction `
        -PullRequestIsMerged $pullRequestIsMerged `
        -PullRequestIsClosed $pullRequestIsClosed `
        -IsTargetDefaultBranch $isTargetDefaultBranch `
        -IsPushToDefaultBranch $isPushToDefaultBranch `
        -IsManualDispatchToDefaultBranch $isManualDispatchToDefaultBranch `
        -HasImportantChanges $hasImportantChanges `
        -HasPrereleaseLabel $hasPrereleaseLabel
    $releaseType = $routing.ReleaseType

    [pscustomobject]@{
        isPR                  = $routing.IsPR
        isOpenOrUpdatedPR     = $routing.IsOpenOrUpdatedPR
        isOpenOrLabeledPR     = $routing.IsOpenOrLabeledPR
        isClosedPR            = $routing.IsClosedPR
        isAbandonedPR         = $routing.IsAbandonedPR
        isMergedPR            = $routing.IsMergedPR
        isPush                = $routing.IsPush
        isManualDispatch      = $routing.IsManualDispatch
        isPushToDefaultBranch = $routing.IsPushToDefaultBranch
        isTargetDefaultBranch = $routing.IsTargetDefaultBranch
        hasPrereleaseLabel    = $hasPrereleaseLabel
        shouldPrerelease      = $routing.ShouldPrerelease
        ReleaseType           = $releaseType
        HasImportantChanges   = $hasImportantChanges
    } | Format-List | Out-String
}

# Get-TestSuites
if ($settings.Test.Skip) {
    Write-Host 'Skipping all tests.'
    $sourceCodeTestSuites = $null
    $psModuleTestSuites = $null
    $moduleTestSuites = $null
} else {

    # Define test configurations as an array of hashtables.
    $linux = [PSCustomObject]@{ RunsOn = 'ubuntu-latest'; OSName = 'Linux' }
    $macOS = [PSCustomObject]@{ RunsOn = 'macos-latest'; OSName = 'macOS' }
    $windows = [PSCustomObject]@{ RunsOn = 'windows-latest'; OSName = 'Windows' }

    LogGroup 'Source Code Test Suites:' {
        $sourceCodeTestSuites = if ($settings.Test.SourceCode.Skip) {
            Write-Host 'Skipping all source code tests.'
            $null
        } else {
            $result = @()
            if (-not $settings.Test.Linux.Skip -and -not $settings.Test.SourceCode.Linux.Skip) { $result += $linux }
            if (-not $settings.Test.MacOS.Skip -and -not $settings.Test.SourceCode.MacOS.Skip) { $result += $macOS }
            if (-not $settings.Test.Windows.Skip -and -not $settings.Test.SourceCode.Windows.Skip) { $result += $windows }
            if ($result.Count -gt 0) { $result } else { $null }
        }
        $sourceCodeTestSuites | Format-Table -AutoSize | Out-String
    }

    LogGroup 'PSModule Test Suites:' {
        $psModuleTestSuites = if ($settings.Test.PSModule.Skip) {
            Write-Host 'Skipping all PSModule tests.'
            $null
        } else {
            $result = @()
            if (-not $settings.Test.Linux.Skip -and -not $settings.Test.PSModule.Linux.Skip) { $result += $linux }
            if (-not $settings.Test.MacOS.Skip -and -not $settings.Test.PSModule.MacOS.Skip) { $result += $macOS }
            if (-not $settings.Test.Windows.Skip -and -not $settings.Test.PSModule.Windows.Skip) { $result += $windows }
            if ($result.Count -gt 0) { $result } else { $null }
        }
        $psModuleTestSuites | Format-Table -AutoSize | Out-String
    }

    LogGroup 'Module Local Test Suites:' {
        $moduleTestSuites = if ($settings.Test.Module.Skip) {
            Write-Host 'Skipping all module tests.'
            $null
        } else {
            # Locate the tests directory.
            $testsPath = Resolve-Path 'tests' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path
            if (-not $testsPath) {
                Write-Warning 'No tests found'
                return $null
            }
            Write-Host "Tests found at [$testsPath]"

            function Get-TestItemsFromFolder {
                <#
                    .SYNOPSIS
                        Retrieves test items from a specified folder.

                    .DESCRIPTION
                        This function searches for test-related files in the specified folder.
                        It looks for configuration files (*.Configuration.ps1), container files (*.Container.ps1),
                        and test files (*.Tests.ps1) in that order of precedence.

                    .PARAMETER FolderPath
                        The path to the folder to search for test items.

                    .OUTPUTS
                        System.IO.FileInfo[]
                        Returns an array of test-related files found in the folder.
                #>
                param ([string]$FolderPath)

                $configFiles = Get-ChildItem -Path $FolderPath -File -Filter '*.Configuration.ps1'
                if ($configFiles.Count -eq 1) {
                    return @($configFiles)
                } elseif ($configFiles.Count -gt 1) {
                    throw "Multiple configuration files found in [$FolderPath]. Please separate configurations into different folders."
                }

                $containerFiles = Get-ChildItem -Path $FolderPath -File -Filter '*.Container.ps1'
                if ($containerFiles.Count -ge 1) {
                    return $containerFiles
                }

                $testFiles = Get-ChildItem -Path $FolderPath -File -Filter '*.Tests.ps1'
                return $testFiles
            }

            function Find-TestDirectory {
                <#
                    .SYNOPSIS
                        Finds test directories recursively.

                    .DESCRIPTION
                        This function recursively searches for all directories starting from the specified path.
                        It returns a flat array of all directory paths found.

                    .PARAMETER Path
                        The root path to start searching for directories.

                    .OUTPUTS
                        System.String[]
                        Returns an array of directory paths.
                #>
                param ([string]$Path)

                $directories = @()
                $childDirs = Get-ChildItem -Path $Path -Directory

                foreach ($dir in $childDirs) {
                    $directories += $dir.FullName
                    $directories += Find-TestDirectory -Path $dir.FullName
                }

                return $directories
            }

            $allTestFolders = @($testsPath) + (Find-TestDirectory -Path $testsPath)

            foreach ($folder in $allTestFolders) {
                $testItems = Get-TestItemsFromFolder -FolderPath $folder
                foreach ($item in $testItems) {
                    if (-not $settings.Test.Linux.Skip -and -not $settings.Test.Module.Linux.Skip) {
                        [pscustomobject]@{
                            RunsOn   = $linux.RunsOn
                            OSName   = $linux.OSName
                            TestPath = Resolve-Path -Path $item.FullName -Relative
                            TestName = ($item.BaseName).Split('.')[0]
                        }
                    }
                    if (-not $settings.Test.MacOS.Skip -and -not $settings.Test.Module.MacOS.Skip) {
                        [pscustomobject]@{
                            RunsOn   = $macOS.RunsOn
                            OSName   = $macOS.OSName
                            TestPath = Resolve-Path -Path $item.FullName -Relative
                            TestName = ($item.BaseName).Split('.')[0]
                        }
                    }
                    if (-not $settings.Test.Windows.Skip -and -not $settings.Test.Module.Windows.Skip) {
                        [pscustomobject]@{
                            RunsOn   = $windows.RunsOn
                            OSName   = $windows.OSName
                            TestPath = Resolve-Path -Path $item.FullName -Relative
                            TestName = ($item.BaseName).Split('.')[0]
                        }
                    }
                }
            }
        }
        $moduleTestSuites | Format-Table -AutoSize | Out-String
    }

}

# Keep test suites with each test phase that owns them.
$settings.Test.SourceCode | Add-Member -MemberType NoteProperty -Name Suites -Value $sourceCodeTestSuites -Force
$settings.Test.PSModule | Add-Member -MemberType NoteProperty -Name Suites -Value $psModuleTestSuites -Force
$settings.Test.Module | Add-Member -MemberType NoteProperty -Name Suites -Value $moduleTestSuites -Force

# Calculate job-specific conditions and add to settings
LogGroup 'Calculate Job Run Conditions:' {
    $shouldAutoCleanup = $routing.ShouldRunCleanup -and ($settings.Publish.Module.AutoCleanup -eq $true)

    # Update Publish.Module with computed release values
    $settings.Publish.Module | Add-Member -MemberType NoteProperty -Name ReleaseType -Value $releaseType -Force
    $settings.Publish.Module.AutoCleanup = $shouldAutoCleanup

    # Closed PR events are cleanup-only. Other events run build/test only for important changes.
    $shouldRunBuildTest = $routing.ShouldRunBuildTest

    # Check if setup/teardown scripts exist in the repository
    $hasBeforeAllScript = Test-Path -Path 'tests/BeforeAll.ps1'
    $hasAfterAllScript = Test-Path -Path 'tests/AfterAll.ps1'
    Write-Host "Setup/teardown script detection:"
    Write-Host "  tests/BeforeAll.ps1 exists: $hasBeforeAllScript"
    Write-Host "  tests/AfterAll.ps1 exists:  $hasAfterAllScript"

    $sourceCodeEnabled = $shouldRunBuildTest -and ($null -ne $settings.Test.SourceCode.Suites)
    $psModuleEnabled = $shouldRunBuildTest -and ($null -ne $settings.Test.PSModule.Suites)
    $moduleLocalEnabled = $shouldRunBuildTest -and ($null -ne $settings.Test.Module.Suites)
    $beforeAllEnabled = $moduleLocalEnabled -and $hasBeforeAllScript
    $afterAllEnabled = $moduleLocalEnabled -and $hasAfterAllScript

    # Keep desired/computed execution state with each phase.
    $settings.Linter | Add-Member -MemberType NoteProperty -Name Repository -Value ([pscustomobject]@{
            Desired = -not $settings.Linter.Skip
            Enabled = $isOpenOrUpdatedPR -and (-not $settings.Linter.Skip)
        }) -Force
    $settings.Linter | Add-Member -MemberType NoteProperty -Name SourceCode -Value ([pscustomobject]@{
            Desired = -not $settings.Test.SourceCode.Skip
            Enabled = $sourceCodeEnabled
        }) -Force

    $settings.Build.Module | Add-Member -MemberType NoteProperty -Name Desired -Value (-not $settings.Build.Module.Skip) -Force
    $settings.Build.Module | Add-Member -MemberType NoteProperty -Name Enabled -Value (
        $shouldRunBuildTest -and (-not $settings.Build.Module.Skip)
    ) -Force
    $settings.Build.Docs | Add-Member -MemberType NoteProperty -Name Desired -Value (-not $settings.Build.Docs.Skip) -Force
    $settings.Build.Docs | Add-Member -MemberType NoteProperty -Name Enabled -Value ($shouldRunBuildTest -and (-not $settings.Build.Docs.Skip)) -Force
    $settings.Build.Site | Add-Member -MemberType NoteProperty -Name Desired -Value (-not $settings.Build.Site.Skip) -Force
    $settings.Build.Site | Add-Member -MemberType NoteProperty -Name Enabled -Value ($shouldRunBuildTest -and (-not $settings.Build.Site.Skip)) -Force

    $settings.Test.SourceCode | Add-Member -MemberType NoteProperty -Name Desired -Value (-not $settings.Test.SourceCode.Skip) -Force
    $settings.Test.SourceCode | Add-Member -MemberType NoteProperty -Name Enabled -Value $sourceCodeEnabled -Force
    $settings.Test.PSModule | Add-Member -MemberType NoteProperty -Name Desired -Value (-not $settings.Test.PSModule.Skip) -Force
    $settings.Test.PSModule | Add-Member -MemberType NoteProperty -Name Enabled -Value $psModuleEnabled -Force
    $settings.Test.Module | Add-Member -MemberType NoteProperty -Name Desired -Value (-not $settings.Test.Module.Skip) -Force
    $settings.Test.Module | Add-Member -MemberType NoteProperty -Name BeforeAllEnabled -Value $beforeAllEnabled -Force
    $settings.Test.Module | Add-Member -MemberType NoteProperty -Name MainEnabled -Value $moduleLocalEnabled -Force
    $settings.Test.Module | Add-Member -MemberType NoteProperty -Name AfterAllEnabled -Value $afterAllEnabled -Force

    $settings.Test.TestResults | Add-Member -MemberType NoteProperty -Name Desired -Value (-not $settings.Test.TestResults.Skip) -Force
    $settings.Test.TestResults | Add-Member -MemberType NoteProperty -Name Enabled -Value (
        $shouldRunBuildTest -and (-not $settings.Test.TestResults.Skip) -and (
            ($null -ne $settings.Test.SourceCode.Suites) -or ($null -ne $settings.Test.PSModule.Suites) -or ($null -ne $settings.Test.Module.Suites)
        )
    ) -Force
    $settings.Test.CodeCoverage | Add-Member -MemberType NoteProperty -Name Desired -Value (-not $settings.Test.CodeCoverage.Skip) -Force
    $settings.Test.CodeCoverage | Add-Member -MemberType NoteProperty -Name Enabled -Value (
        $shouldRunBuildTest -and (-not $settings.Test.CodeCoverage.Skip) -and (
            ($null -ne $settings.Test.PSModule.Suites) -or ($null -ne $settings.Test.Module.Suites)
        )
    ) -Force

    $settings.Publish.Module | Add-Member -MemberType NoteProperty -Name Desired -Value (($releaseType -ne 'None') -or $shouldAutoCleanup) -Force
    $settings.Publish.Module | Add-Member -MemberType NoteProperty -Name Enabled -Value (($releaseType -ne 'None') -or $shouldAutoCleanup) -Force
    $settings.Publish.Site | Add-Member -MemberType NoteProperty -Name Desired -Value ($releaseType -eq 'Release') -Force
    $settings.Publish.Site | Add-Member -MemberType NoteProperty -Name Enabled -Value (
        $releaseType -eq 'Release' -and -not $settings.Publish.Site.Skip
    ) -Force

    $settings | Add-Member -MemberType NoteProperty -Name HasImportantChanges -Value $hasImportantChanges

    Write-Host 'Phase execution state:'
    [pscustomobject]@{
        LintRepository       = $settings.Linter.Repository.Enabled
        BuildModule          = $settings.Build.Module.Enabled
        TestSourceCode       = $settings.Test.SourceCode.Enabled
        LintSourceCode       = $settings.Linter.SourceCode.Enabled
        TestModule           = $settings.Test.PSModule.Enabled
        BeforeAllModuleLocal = $settings.Test.Module.BeforeAllEnabled
        TestModuleLocal      = $settings.Test.Module.MainEnabled
        AfterAllModuleLocal  = $settings.Test.Module.AfterAllEnabled
        GetTestResults       = $settings.Test.TestResults.Enabled
        GetCodeCoverage      = $settings.Test.CodeCoverage.Enabled
        PublishModule        = $settings.Publish.Module.Enabled
        BuildDocs            = $settings.Build.Docs.Enabled
        BuildSite            = $settings.Build.Site.Enabled
        PublishSite          = $settings.Publish.Site.Enabled
    } | Format-List | Out-String
}

LogGroup 'Final settings' {
    switch -Regex ($settingsFile.Extension) {
        '.yaml|.yml' {
            Write-Host ($settings | ConvertTo-Yaml | Out-String)
        }
        '.psd1' {
            Write-Host ($settings | ConvertTo-Hashtable | Format-Hashtable | Out-String)
        }
        default {
            Write-Host ($settings | ConvertTo-Json -Depth 5 | Out-String)
        }
    }
    Set-GitHubOutput -Name Settings -Value ($settings | ConvertTo-Json -Depth 10)
}

LogGroup 'Validate output settings against schema' {
    $schemaPath = Join-Path $PSScriptRoot 'Settings.schema.json'
    if (Test-Path -Path $schemaPath) {
        Write-Host 'Validating output settings against schema...'
        $schema = Get-Content $schemaPath -Raw

        # Convert output settings to JSON for validation
        $outputJson = $settings | ConvertTo-Json -Depth 10

        try {
            $isValid = Test-Json -Json $outputJson -Schema $schema -ErrorAction Stop
            if ($isValid) {
                Write-Host '✓ Output settings conform to schema'
            } else {
                throw 'Output settings do not conform to the schema'
            }
        } catch {
            Write-Error "Output schema validation failed: $_"
            Write-Error 'The generated settings object does not match the expected schema structure.'
            Write-Error 'This indicates a bug in the action. Please report this issue.'
            throw
        }
    } else {
        Write-Warning "Schema file not found at [$schemaPath]. Skipping output validation."
    }
}
