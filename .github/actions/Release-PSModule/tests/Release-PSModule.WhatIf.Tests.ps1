[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Variables are assigned in BeforeAll and used inside It blocks.'
)]
[CmdletBinding()]
param()

BeforeAll {
    $script:environmentMutex = [Threading.Mutex]::new($false, "PSModule-ActionTests-Environment-$PID")
    if (-not $script:environmentMutex.WaitOne([TimeSpan]::FromMinutes(5))) {
        throw 'Cannot acquire the process environment lock for action tests.'
    }
    Import-Module -Name 'PSModule' -Force

    $script:releaseScriptPath = Join-Path -Path $PSScriptRoot -ChildPath '../src/release.ps1'
    $script:environmentVariableNames = @(
        'GITHUB_EVENT_PATH'
        'GITHUB_OUTPUT'
        'GITHUB_REPOSITORY'
        'GITHUB_SHA'
        'GITHUB_WORKSPACE'
        'RELEASE_ACTION_GH_CALL_LOG'
        'PSMODULE_RELEASE_PSMODULE_INPUT_Name'
        'PSMODULE_RELEASE_PSMODULE_INPUT_ModulePath'
        'PSMODULE_RELEASE_PSMODULE_INPUT_WhatIf'
        'PSMODULE_RELEASE_PSMODULE_INPUT_UsePRBodyAsReleaseNotes'
        'PSMODULE_RELEASE_PSMODULE_INPUT_UsePRTitleAsReleaseName'
        'PSMODULE_RELEASE_PSMODULE_INPUT_UsePRTitleAsNotesHeading'
        'PSMODULE_RELEASE_PSMODULE_INPUT_ReleaseTag'
        'PSMODULE_RELEASE_PSMODULE_INPUT_PullRequest'
        'PSMODULE_RELEASE_PSMODULE_INPUT_CommitSha'
    )
    $script:originalEnvironment = @{}
    foreach ($name in $script:environmentVariableNames) {
        $script:originalEnvironment[$name] = [System.Environment]::GetEnvironmentVariable($name)
    }
}

AfterAll {
    try {
        foreach ($name in $script:environmentVariableNames) {
            [System.Environment]::SetEnvironmentVariable($name, $script:originalEnvironment[$name])
        }
        Remove-Item -Path 'Function:\gh' -ErrorAction SilentlyContinue
        Remove-Item -Path 'Function:\git' -ErrorAction SilentlyContinue
    } finally {
        $script:environmentMutex.ReleaseMutex()
        $script:environmentMutex.Dispose()
    }
}

Describe 'Release-PSModule WhatIf' {
    BeforeEach {
        $script:moduleName = 'TestModule'
        $script:workspacePath = Join-Path -Path $TestDrive -ChildPath 'workspace'
        $script:modulePath = Join-Path -Path $script:workspacePath -ChildPath ".PSModule/module/$script:moduleName"
        $manifestPath = Join-Path -Path $script:modulePath -ChildPath "$script:moduleName.psd1"
        $eventPath = Join-Path -Path $TestDrive -ChildPath 'event.json'
        $script:githubOutputPath = Join-Path -Path $TestDrive -ChildPath 'github-output'
        $script:ghCallLogPath = Join-Path -Path $TestDrive -ChildPath 'gh-calls'

        $null = New-Item -Path $script:modulePath -ItemType Directory -Force
        $null = New-Item -Path $script:githubOutputPath -ItemType File -Force
        $null = New-Item -Path $script:ghCallLogPath -ItemType File -Force
        Set-Content -Path (Join-Path -Path $script:modulePath -ChildPath "$script:moduleName.psm1") -Value ''
        Set-Content -Path $manifestPath -Value @"
@{
    RootModule = '$script:moduleName.psm1'
    ModuleVersion = '1.2.3'
    GUID = '3c0f8d73-60b7-4f38-b3cf-9386db4982a4'
    Author = 'PSModule'
    Description = 'Test module'
    PowerShellVersion = '5.1'
    PrivateData = @{
        PSData = @{
            Prerelease = 'preview.1'
        }
    }
}
"@
        @{
            pull_request = @{
                number = 42
                title  = 'Create test release'
                body   = 'Release notes'
                head   = @{
                    ref = 'feature/release'
                }
            }
        } | ConvertTo-Json -Depth 5 | Set-Content -Path $eventPath

        $env:GITHUB_EVENT_PATH = $eventPath
        $env:GITHUB_OUTPUT = $script:githubOutputPath
        $env:GITHUB_REPOSITORY = "PSModule/$script:moduleName"
        $env:GITHUB_SHA = 'original-source-sha'
        $env:GITHUB_WORKSPACE = $script:workspacePath
        $env:RELEASE_ACTION_GH_CALL_LOG = $script:ghCallLogPath
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_Name = $script:moduleName
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_ModulePath = '.PSModule/module'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_WhatIf = 'true'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_UsePRBodyAsReleaseNotes = 'true'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_UsePRTitleAsReleaseName = 'false'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_UsePRTitleAsNotesHeading = 'true'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_ReleaseTag = 'v1.2.3-preview.1'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_PullRequest = ''
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_CommitSha = ''
        $script:releaseFixture = @{
            SourceSha = 'original-source-sha'
            Assets    = @()
        }
        $fixture = $script:releaseFixture
        Set-Item -Path 'Function:global:gh' -Value {
            [CmdletBinding()]
            param(
                [Parameter(ValueFromRemainingArguments)]
                [string[]] $Arguments
            )
            Add-Content -Path $env:RELEASE_ACTION_GH_CALL_LOG -Value ($Arguments -join ' ')
            $global:LASTEXITCODE = 0
            if ($Arguments[0] -eq 'api' -and $Arguments[1] -match '/releases/tags/') {
                if ($Arguments -contains '--jq') {
                    'https://github.com/PSModule/TestModule/releases/tag/v1.2.3-preview.1'
                } else {
                    @{
                        tag_name = 'v1.2.3-preview.1'
                        html_url = 'https://github.com/PSModule/TestModule/releases/tag/v1.2.3-preview.1'
                        assets   = $fixture.Assets
                    } | ConvertTo-Json -Depth 5 -Compress
                }
            } elseif ($Arguments[0] -eq 'api' -and $Arguments[1] -match '/git/ref/tags/') {
                @{ object = @{ type = 'commit'; sha = $fixture.SourceSha } } | ConvertTo-Json -Compress
            }
        }.GetNewClosure()
        Set-Item -Path 'Function:global:git' -Value {
            $global:LASTEXITCODE = 0
            'Original commit message'
        }
    }

    It 'creates a prefixed prerelease tag without GitHub side effects' {
        { & $script:releaseScriptPath } | Should -Not -Throw

        Get-Content -Path $script:githubOutputPath | Should -Contain 'ReleaseTag=v1.2.3-preview.1'
        Get-Content -Path $script:githubOutputPath | Should -Contain 'ReleaseUrl=https://github.com/PSModule/TestModule/releases/tag/v1.2.3-preview.1'
    }

    It 'resumes an existing release after a partial failure' {
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_WhatIf = 'false'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_CommitSha = 'original-source-sha'

        { & $script:releaseScriptPath } | Should -Not -Throw

        $ghCalls = Get-Content -Path $script:ghCallLogPath -Raw
        $ghCalls | Should -Match 'api repos/PSModule/TestModule/releases/tags/v1.2.3-preview.1'
        $ghCalls | Should -Match 'release upload v1.2.3-preview.1'
        $ghCalls | Should -Match 'pr comment 42'
        $ghCalls | Should -Not -Match 'release create'
        Get-Content -Path $script:githubOutputPath | Should -Contain 'ReleaseTag=v1.2.3-preview.1'
    }

    It 'refuses to resume a tag owned by a different commit without uploading' {
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_WhatIf = 'false'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_CommitSha = 'original-source-sha'
        $script:releaseFixture.SourceSha = 'newer-source-sha'

        { & $script:releaseScriptPath } | Should -Throw '*newer-source-sha*original-source-sha*'

        Get-Content -Path $script:ghCallLogPath -Raw | Should -Not -Match 'release upload'
    }

    It 'refuses differing already-published contents even for the same source' {
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_WhatIf = 'false'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_CommitSha = 'original-source-sha'
        $script:releaseFixture.Assets = @(@{
                name = 'TestModule-1.2.3-preview.1.zip'; digest = "sha256:$('0' * 64)"
            })

        { & $script:releaseScriptPath } | Should -Throw '*different*published*contents*'

        Get-Content -Path $script:ghCallLogPath -Raw | Should -Not -Match 'release upload'
    }

    It 'retains an identical same-source asset instead of replacing it' {
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_WhatIf = 'false'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_CommitSha = 'original-source-sha'
        $expectedZip = Join-Path -Path $TestDrive -ChildPath 'expected.zip'
        Compress-Archive -Path $script:modulePath -DestinationPath $expectedZip
        $digest = [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData([IO.File]::ReadAllBytes($expectedZip))
        ).ToLowerInvariant()
        $script:releaseFixture.Assets = @(@{
                name = 'TestModule-1.2.3-preview.1.zip'; digest = "sha256:$digest"
            })

        { & $script:releaseScriptPath } | Should -Not -Throw

        Get-Content -Path $script:ghCallLogPath -Raw | Should -Not -Match 'release upload'
        Get-Content -Path $script:githubOutputPath | Should -Contain 'ReleaseTag=v1.2.3-preview.1'
    }

    It 'refuses an asset whose published digest cannot be verified' {
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_WhatIf = 'false'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_CommitSha = 'original-source-sha'
        $script:releaseFixture.Assets = @(@{
                name = 'TestModule-1.2.3-preview.1.zip'; digest = $null
            })

        { & $script:releaseScriptPath } | Should -Throw '*Cannot verify*SHA-256*digest*'

        Get-Content -Path $script:ghCallLogPath -Raw | Should -Not -Match 'release upload'
    }

    It 'uses the original GitHub source context when the optional CommitSha input is omitted' {
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_WhatIf = 'false'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_CommitSha = ''

        { & $script:releaseScriptPath } | Should -Not -Throw

        Get-Content -Path $script:ghCallLogPath -Raw | Should -Match 'release upload v1.2.3-preview.1'
        Get-Content -Path $script:ghCallLogPath -Raw | Should -Not -Match 'clobber'
    }

    It 'creates a stable release from a direct push without pull request context' {
        $manifest = Get-Content -Path $manifestPath -Raw
        $manifest -replace "Prerelease = 'preview.1'", "Prerelease = ''" | Set-Content -Path $manifestPath
        @{ head_commit = @{ message = 'Publish direct push release' } } |
            ConvertTo-Json -Depth 5 | Set-Content -Path $eventPath
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_ReleaseTag = 'v1.2.3'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_CommitSha = 'pushed-commit-sha'

        $releaseOutput = & $script:releaseScriptPath 6>&1 | Out-String

        Get-Content -Path $script:githubOutputPath | Should -Contain 'ReleaseTag=v1.2.3'
        $releaseOutput | Should -Match '--target pushed-commit-sha'
    }

    It 'uses the checked-out commit message for a manual dispatch' {
        $manifest = Get-Content -Path $manifestPath -Raw
        $manifest -replace "Prerelease = 'preview.1'", "Prerelease = ''" | Set-Content -Path $manifestPath
        @{} | ConvertTo-Json | Set-Content -Path $eventPath
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_ReleaseTag = 'v1.2.3'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_CommitSha = 'dispatched-commit-sha'
        Set-Item -Path function:global:git -Value {
            $global:LASTEXITCODE = 0
            'Publish manual dispatch release'
        }

        $releaseOutput = & $script:releaseScriptPath 6>&1 | Out-String

        $releaseOutput | Should -Match 'Using the pushed commit message as release notes'
    }
}
