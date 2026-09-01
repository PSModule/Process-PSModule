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
    # The 'global:' scope qualifier is not a valid provider path, so it must be omitted here.
    # Otherwise the shims leak into the global scope and shadow the real commands in later test files.
    Remove-Item -Path 'Function:\gh' -ErrorAction SilentlyContinue
    Remove-Item -Path 'Function:\git' -ErrorAction SilentlyContinue
}

Describe 'Release-PSModule WhatIf' {
    BeforeEach {
        $script:moduleName = 'TestModule'
        $script:workspacePath = Join-Path -Path $TestDrive -ChildPath 'workspace'
        $script:modulePath = Join-Path -Path $script:workspacePath -ChildPath "outputs/module/$script:moduleName"
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
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_ModulePath = 'outputs/module'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_WhatIf = 'true'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_UsePRBodyAsReleaseNotes = 'true'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_UsePRTitleAsReleaseName = 'false'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_UsePRTitleAsNotesHeading = 'true'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_ReleaseTag = 'v1.2.3-preview.1'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_PullRequest = ''
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_CommitSha = ''
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
