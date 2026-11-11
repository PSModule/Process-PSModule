[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Variables are assigned in BeforeAll and used inside It blocks.'
)]
[CmdletBinding()]
param()

BeforeAll {
    Import-Module -Name 'PSModule' -Force

    $script:releaseScriptPath = Join-Path -Path $PSScriptRoot -ChildPath '../src/release.ps1'
    $script:environmentVariableNames = @(
        'GITHUB_EVENT_PATH'
        'GITHUB_OUTPUT'
        'GITHUB_REPOSITORY'
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
    foreach ($name in $script:environmentVariableNames) {
        [System.Environment]::SetEnvironmentVariable($name, $script:originalEnvironment[$name])
    }
}

Describe 'Release-PSModule WhatIf' {
    AfterEach {
        Remove-Item -Path 'Function:\gh' -ErrorAction SilentlyContinue
    }

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

        Set-Item -Path function:global:gh -Value {
            throw 'GitHub calls are not permitted in WhatIf tests.'
        }
    }

    It 'creates a prefixed prerelease tag without GitHub side effects' {
        { & $script:releaseScriptPath } | Should -Not -Throw

        Get-Content -Path $script:githubOutputPath | Should -Contain 'ReleaseTag=v1.2.3-preview.1'
        Get-Content -Path $script:githubOutputPath | Should -Contain 'ReleaseUrl=https://github.com/PSModule/TestModule/releases/tag/v1.2.3-preview.1'
    }

    It 'resumes an existing release after a partial failure' {
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_WhatIf = 'false'
        Set-Item -Path function:global:gh -Value {
            [CmdletBinding()]
            param(
                [Parameter(ValueFromRemainingArguments)]
                [string[]] $Arguments
            )

            Add-Content -Path $env:RELEASE_ACTION_GH_CALL_LOG -Value ($Arguments -join ' ')
            $global:LASTEXITCODE = 0
            if ($Arguments[0] -eq 'api') {
                return 'https://github.com/PSModule/TestModule/releases/tag/v1.2.3-preview.1'
            }
        }

        { & $script:releaseScriptPath } | Should -Not -Throw

        $ghCalls = Get-Content -Path $script:ghCallLogPath -Raw
        $ghCalls | Should -Match 'api repos/PSModule/TestModule/releases/tags/v1.2.3-preview.1 --jq .html_url'
        $ghCalls | Should -Match 'release upload v1.2.3-preview.1'
        $ghCalls | Should -Match 'pr comment 42'
        $ghCalls | Should -Not -Match 'release create'
        Get-Content -Path $script:githubOutputPath | Should -Contain 'ReleaseTag=v1.2.3-preview.1'
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

    It 'passes the dispatched commit message as release notes' {
        $manifest = Get-Content -Path $manifestPath -Raw
        $manifest -replace "Prerelease = 'preview.1'", "Prerelease = ''" | Set-Content -Path $manifestPath
        @{} | ConvertTo-Json | Set-Content -Path $eventPath
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_WhatIf = 'false'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_ReleaseTag = 'v1.2.3'
        $calls = @{ ReleaseArguments = @(); Notes = $null }
        git -C $script:workspacePath init --quiet
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not create the release test repository.'
        }
        $gitArguments = @(
            '-C', $script:workspacePath
            '-c', 'user.name=PSModule Test'
            '-c', 'user.email=test@example.invalid'
            '-c', 'commit.gpgsign=false'
            '-c', "core.hooksPath=$TestDrive"
            'commit', '--allow-empty', '--quiet', '-m', 'Publish manual dispatch release'
        )
        git @gitArguments
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not create the release test commit.'
        }
        $commitSha = git -C $script:workspacePath rev-parse HEAD
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not read the release test commit.'
        }
        $gitArguments[-1] = 'Do not use the latest commit for this release'
        git @gitArguments
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not create the newer unrelated test commit.'
        }
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_CommitSha = $commitSha

        # Intercept unsafe GitHub writes. This proves script inputs, not the live API contract.
        Set-Item -Path function:global:gh -Value {
            [CmdletBinding()]
            param(
                [Parameter(ValueFromRemainingArguments)]
                [string[]] $Arguments
            )

            $global:LASTEXITCODE = 0
            if ($Arguments[0] -eq 'api') {
                $global:LASTEXITCODE = 1
                return 'HTTP 404'
            }

            switch ($Arguments[0..1] -join ' ') {
                'release create' {
                    $notesIndex = [array]::IndexOf($Arguments, '--notes-file')
                    if ($notesIndex -lt 0) {
                        throw 'The release command did not supply a notes file.'
                    }
                    $calls.ReleaseArguments = $Arguments
                    $calls.Notes = Get-Content -LiteralPath $Arguments[$notesIndex + 1] -Raw
                    return 'https://github.com/PSModule/TestModule/releases/tag/v1.2.3'
                }
                'release upload' {}
                default {
                    throw "Unexpected GitHub command: $($Arguments -join ' ')"
                }
            }
        }.GetNewClosure()

        Push-Location -LiteralPath $script:workspacePath
        try {
            & $script:releaseScriptPath
        } finally {
            Pop-Location
        }

        $calls.Notes.TrimEnd([char[]] "`r`n") | Should -Be 'Publish manual dispatch release'
        $targetIndex = [array]::IndexOf($calls.ReleaseArguments, '--target')
        $targetIndex | Should -BeGreaterOrEqual 0
        $calls.ReleaseArguments[$targetIndex + 1] | Should -Be $commitSha
    }
}
