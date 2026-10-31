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
    Import-Module -Name ([IO.Path]::Combine(
            $PSScriptRoot, '..', '..', 'Publish-PSModule', 'tests', 'Publish-PSModule.TestFixture.psm1'
        )) -Force

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
        'PSMODULE_RELEASE_PSMODULE_INPUT_VersionPrefix'
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
        foreach ($name in @('gh', 'git', 'Find-PSResource', 'Publish-PSResource', 'Save-PSResource', 'Invoke-WebRequest')) {
            Remove-Item -LiteralPath "Function:\$name" -ErrorAction SilentlyContinue
        }
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
        $env:GITHUB_SHA = '1111111111111111111111111111111111111111'
        $env:GITHUB_WORKSPACE = $script:workspacePath
        $env:RELEASE_ACTION_GH_CALL_LOG = $script:ghCallLogPath
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_Name = $script:moduleName
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_ModulePath = '.PSModule/module'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_WhatIf = 'true'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_UsePRBodyAsReleaseNotes = 'true'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_UsePRTitleAsReleaseName = 'false'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_UsePRTitleAsNotesHeading = 'true'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_ReleaseTag = 'v1.2.3-preview.1'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_VersionPrefix = 'v'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_PullRequest = ''
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_CommitSha = ''
        $script:state = New-PSModulePublicationFixture -Path $script:modulePath `
            -Version '1.2.3-preview.1' -Tag 'v1.2.3-preview.1' -PullRequest 42
    }

    It 'creates a prefixed prerelease tag without GitHub side effects' {
        { & $script:releaseScriptPath 1>$null 6>$null } | Should -Not -Throw

        Get-Content -Path $script:githubOutputPath | Should -Contain 'ReleaseTag=v1.2.3-preview.1'
        Get-Content -Path $script:githubOutputPath | Should -Contain 'ReleaseUrl=https://github.com/PSModule/TestModule/releases/tag/v1.2.3-preview.1'
        $script:state.Calls.Count | Should -Be 0
    }

    It 'resumes an existing release after a partial failure' {
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_WhatIf = 'false'
        Set-PSModuleFixtureClaim -State $script:state -Claim $script:state.ExpectedClaim
        $owner = @{ Repository = 'PSModule/TestModule'; PullRequest = 42; CommitSha = $env:GITHUB_SHA } |
            ConvertTo-Json -Compress
        $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($owner))
        $script:state.Release = [pscustomobject]@{
            tag_name   = 'v1.2.3-preview.1'
            html_url   = 'https://github.com/PSModule/TestModule/releases/tag/v1.2.3-preview.1'
            prerelease = $true
            body       = "Original notes.`n<!-- PSModule.PrereleaseOwner:v1:$encoded -->"
            assets     = @()
        }

        { & $script:releaseScriptPath 1>$null 6>$null } | Should -Not -Throw

        $ghCalls = $script:state.Calls -join "`n"
        $ghCalls | Should -Match 'api repos/PSModule/TestModule/releases/tags/v1.2.3-preview.1 --include --method GET'
        $ghCalls | Should -Match 'release upload v1.2.3-preview.1'
        $ghCalls | Should -Match 'pr comment 42'
        $ghCalls | Should -Not -Match 'release create'
        $ghCalls | Should -Not -Match '--clobber'
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

    It 'creates a prerelease from the exact source and preserves notes before its provenance footer' {
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_WhatIf = 'false'

        { & $script:releaseScriptPath 1>$null 6>$null } | Should -Not -Throw

        $script:state.TagObject.object.sha | Should -BeExactly $env:GITHUB_SHA
        ($script:state.Calls -join "`n") | Should -Match "--target $env:GITHUB_SHA"
        ($script:state.Calls -join "`n") | Should -Not -Match '--target feature/release|--clobber'
        $script:state.Release.body | Should -Match '# Create test release \(#42\)'
        $script:state.Release.body | Should -Match 'Release notes'
        $owner = Get-PSModulePrereleaseOwnership -Body $script:state.Release.body
        $owner.PullRequest | Should -Be 42
        $owner.CommitSha | Should -BeExactly $env:GITHUB_SHA
        $script:state.GalleryWrites | Should -Be 0
    }

    It 'preserves complete generated notes before its provenance footer' {
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_WhatIf = 'false'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_UsePRBodyAsReleaseNotes = 'false'

        { & $script:releaseScriptPath 1>$null 6>$null } | Should -Not -Throw

        $script:state.Release.body | Should -Match '^Complete independently generated fixture notes\.'
        (Get-PSModulePrereleaseOwnership -Body $script:state.Release.body).PullRequest | Should -Be 42
    }

    It 'rejects another producing PR footer despite a matching tag and source' {
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_WhatIf = 'false'
        Set-PSModuleFixtureClaim -State $script:state -Claim $script:state.ExpectedClaim
        $owner = @{ Repository = 'PSModule/TestModule'; PullRequest = 99; CommitSha = $env:GITHUB_SHA } |
            ConvertTo-Json -Compress
        $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($owner))
        $script:state.Release = [pscustomobject]@{
            tag_name   = 'v1.2.3-preview.1'
            html_url   = 'https://github.com/PSModule/TestModule/releases/tag/v1.2.3-preview.1'
            prerelease = $true
            body       = "Foreign PR notes.`n<!-- PSModule.PrereleaseOwner:v1:$encoded -->"
            assets     = @()
        }

        { & $script:releaseScriptPath 1>$null 6>$null } | Should -Throw '*pull request*'

        $script:state.GitHubWrites | Should -Be 0
        $script:state.GalleryWrites | Should -Be 0
    }

    It 'retains existing identical asset bytes without another upload' {
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_WhatIf = 'false'
        { & $script:releaseScriptPath 1>$null 6>$null } | Should -Not -Throw
        $firstWrites = $script:state.GitHubWrites
        $originalBody = $script:state.Release.body
        $originalDigest = $script:state.Release.assets[0].digest

        { & $script:releaseScriptPath 1>$null 6>$null } | Should -Not -Throw

        $script:state.GitHubWrites | Should -Be $firstWrites
        $script:state.Release.body | Should -BeExactly $originalBody
        $script:state.Release.assets[0].digest | Should -BeExactly $originalDigest
    }

    It 'rejects a tag changed after preflight before the missing asset upload' {
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_WhatIf = 'false'
        { & $script:releaseScriptPath 1>$null 6>$null } | Should -Not -Throw
        $script:state.Release.assets = @()
        $script:state.TagReads = 0
        $script:state.GitHubWrites = 0
        $script:state.OnTagRead = {
            param($State)
            if ($State.TagReads -eq 3) {
                $foreign = $State.ExpectedClaim | ConvertTo-Json -Compress | ConvertFrom-Json
                $foreign.CommitSha = '2222222222222222222222222222222222222222'
                Set-PSModuleFixtureClaim -State $State -Claim $foreign -TagSha '4444444444444444444444444444444444444444'
            }
        }

        { & $script:releaseScriptPath 1>$null 6>$null } | Should -Throw '*source*'

        $script:state.GitHubWrites | Should -Be 0
        @($script:state.Release.assets).Count | Should -Be 0
    }

    It 'rejects supplied PR context without a positive identity before release writes' -ForEach @(
        @{ Json = '{}' }
        @{ Json = '[]' }
        @{ Json = '[null]' }
        @{ Json = '[{"Number":42}]' }
    ) {
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_WhatIf = 'false'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_PullRequest = $Json

        { & $script:releaseScriptPath 1>$null 6>$null } | Should -Throw '*pull request*'

        $script:state.GitHubWrites | Should -Be 0
    }

    It 'revalidates a changed claim immediately before release creation after generated notes' {
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_WhatIf = 'false'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_UsePRBodyAsReleaseNotes = 'false'
        $script:state.OnGeneratedNotes = {
            param($State)
            $foreign = $State.ExpectedClaim | ConvertTo-Json -Compress | ConvertFrom-Json
            $foreign.CommitSha = '2222222222222222222222222222222222222222'
            Set-PSModuleFixtureClaim -State $State -Claim $foreign -TagSha '4444444444444444444444444444444444444444'
        }

        { & $script:releaseScriptPath 1>$null 6>$null } | Should -Throw '*source*'

        $script:state.GitHubCreationUpload | Should -Be 0
        $script:state.Release | Should -BeNullOrEmpty
    }
}
