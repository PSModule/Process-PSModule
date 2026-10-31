[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Pester setup variables are used by test blocks and command replacements.'
)]
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

BeforeAll {
    $script:environmentMutex = [Threading.Mutex]::new($false, "PSModule-ActionTests-Environment-$PID")
    if (-not $script:environmentMutex.WaitOne([TimeSpan]::FromMinutes(5))) {
        throw 'Cannot acquire the process environment lock for action tests.'
    }
    Import-Module -Name 'PSModule' -Force
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'Publish-PSModule.TestFixture.psm1') -Force

    $script:publishScriptPath = [IO.Path]::GetFullPath(
        [IO.Path]::Combine($PSScriptRoot, '..', 'src', 'publish.ps1')
    )
    $script:environmentVariableNames = @(
        'GITHUB_EVENT_PATH'
        'GITHUB_REPOSITORY'
        'GITHUB_REPOSITORY_NAME'
        'GITHUB_SHA'
        'GITHUB_WORKSPACE'
        'PSMODULE_PUBLISH_PSMODULE_INPUT_Name'
        'PSMODULE_PUBLISH_PSMODULE_INPUT_ModulePath'
        'PSMODULE_PUBLISH_PSMODULE_INPUT_PSGALLERY_API_KEY'
        'PSMODULE_PUBLISH_PSMODULE_INPUT_PullRequest'
        'PSMODULE_PUBLISH_PSMODULE_INPUT_ReleaseTag'
        'PSMODULE_PUBLISH_PSMODULE_INPUT_CommitSha'
        'PSMODULE_PUBLISH_PSMODULE_INPUT_WhatIf'
    )
    $script:originalEnvironment = @{}
    foreach ($name in $script:environmentVariableNames) {
        $script:originalEnvironment[$name] = [Environment]::GetEnvironmentVariable($name)
    }
    $script:replacedCommands = @('gh', 'Find-PSResource', 'Publish-PSResource', 'Invoke-WebRequest', 'Save-PSResource')
    $script:originalFunctions = @{}
    foreach ($name in $script:replacedCommands) {
        $function = Get-Item -LiteralPath "Function:\$name" -ErrorAction SilentlyContinue
        $script:originalFunctions[$name] = $function.ScriptBlock
    }
}

AfterAll {
    try {
        foreach ($name in $script:environmentVariableNames) {
            [Environment]::SetEnvironmentVariable($name, $script:originalEnvironment[$name])
        }
        foreach ($name in $script:replacedCommands) {
            Remove-Item -LiteralPath "Function:\$name" -ErrorAction SilentlyContinue
            if ($null -ne $script:originalFunctions[$name]) {
                Set-Item -Path "Function:global:$name" -Value $script:originalFunctions[$name]
            }
        }
    } finally {
        $script:environmentMutex.ReleaseMutex()
        $script:environmentMutex.Dispose()
    }
}

Describe 'Publish-PSModule source-bound preflight' {
    BeforeEach {
        $script:modulePath = Join-Path -Path $TestDrive -ChildPath 'workspace' -AdditionalChildPath '.PSModule', 'module', 'TestModule'
        $null = New-Item -Path $script:modulePath -ItemType Directory -Force
        Set-Content -LiteralPath (Join-Path -Path $script:modulePath -ChildPath 'TestModule.psm1') -Value '# Tested bytes.'
        Set-Content -LiteralPath (Join-Path -Path $script:modulePath -ChildPath 'TestModule.psd1') -Value @'
@{
    RootModule = 'TestModule.psm1'
    ModuleVersion = '1.2.4'
    GUID = '3c0f8d73-60b7-4f38-b3cf-9386db4982a4'
    Author = 'PSModule'
    Description = 'Anonymous publication fixture'
    PrivateData = @{
        ConsumerMetadata = 'Preserve this value.'
        PSData = @{ Prerelease = '' }
    }
}
'@
        $eventPath = Join-Path -Path $TestDrive -ChildPath 'event.json'
        @{ head_commit = @{ message = 'Anonymous release notes.' } } |
            ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $eventPath

        $env:GITHUB_EVENT_PATH = $eventPath
        $env:GITHUB_REPOSITORY = 'PSModule/TestModule'
        $env:GITHUB_SHA = '1111111111111111111111111111111111111111'
        $env:GITHUB_WORKSPACE = Join-Path -Path $TestDrive -ChildPath 'workspace'
        $env:PSMODULE_PUBLISH_PSMODULE_INPUT_Name = 'TestModule'
        $env:PSMODULE_PUBLISH_PSMODULE_INPUT_ModulePath = '.PSModule/module'
        $env:PSMODULE_PUBLISH_PSMODULE_INPUT_PSGALLERY_API_KEY = 'anonymous-fixture'
        $env:PSMODULE_PUBLISH_PSMODULE_INPUT_PullRequest = ''
        $env:PSMODULE_PUBLISH_PSMODULE_INPUT_ReleaseTag = 'v1.2.4'
        $env:PSMODULE_PUBLISH_PSMODULE_INPUT_CommitSha = $env:GITHUB_SHA
        $env:PSMODULE_PUBLISH_PSMODULE_INPUT_WhatIf = 'false'

        $script:state = New-PSModulePublicationFixture -Path $script:modulePath -Version '1.2.4' -Tag 'v1.2.4'
    }

    It 'rejects a conflicting standalone tag before a Gallery write or a GitHub mutation' {
        $script:state.Tag = @{
            type = 'commit'
            sha  = '2222222222222222222222222222222222222222'
        }

        $failure = $null
        try { & $script:publishScriptPath 1>$null 6>$null } catch { $failure = $_ }

        $script:state.GalleryWrites | Should -Be 0
        $script:state.GitHubWrites | Should -Be 0
        $failure | Should -Not -BeNullOrEmpty
        $failure.Exception.Message | Should -Match 'source|belongs|ownership'
    }

    It 'rejects different release asset bytes before a Gallery write or a GitHub mutation' {
        Set-PSModuleFixtureClaim -State $script:state -Claim $script:state.ExpectedClaim
        $asset = @{
            name   = 'TestModule-1.2.4.zip'
            digest = 'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
            state  = 'uploaded'
        }
        $script:state.Release = @{
            id         = 10
            tag_name   = 'v1.2.4'
            html_url   = 'https://github.com/PSModule/TestModule/releases/tag/v1.2.4'
            prerelease = $false
            assets     = @($asset)
        }

        $failure = $null
        try { & $script:publishScriptPath 1>$null 6>$null } catch { $failure = $_ }

        $script:state.GalleryWrites | Should -Be 0
        $script:state.GitHubWrites | Should -Be 0
        $failure | Should -Not -BeNullOrEmpty
        $failure.Exception.Message | Should -Match 'asset|contents|proof|ownership'
    }

    It 'does not confuse GitHub API failure with an absent release or tag' {
        $script:state.ApiError = "HTTP/2.0 503 Service Unavailable`n`n{`"message`":`"Service Unavailable`"}`ngh: Service Unavailable (HTTP 503)"

        $failure = $null
        try { & $script:publishScriptPath 1>$null 6>$null } catch { $failure = $_ }

        $script:state.GalleryWrites | Should -Be 0
        $script:state.GitHubWrites | Should -Be 0
        $failure | Should -Not -BeNullOrEmpty
        $failure.Exception.Message | Should -Match '503|API|read|lookup'
    }

    It 'rejects a Gallery-only package with no source and artifact proof' {
        $script:state.Package = [pscustomobject]@{ Name = 'TestModule'; Version = '1.2.4' }

        $failure = $null
        try { & $script:publishScriptPath 1>$null 6>$null } catch { $failure = $_ }

        $script:state.GalleryWrites | Should -Be 0
        $script:state.GitHubWrites | Should -Be 0
        $failure | Should -Not -BeNullOrEmpty
        $failure.Exception.Message | Should -Match 'proof|ownership|unverifiable'
    }

    It 'rejects a same-source tag without artifact and release-context proof' {
        $script:state.Tag = @{ type = 'commit'; sha = $env:GITHUB_SHA }

        $failure = $null
        try { & $script:publishScriptPath 1>$null 6>$null } catch { $failure = $_ }

        $script:state.GalleryWrites | Should -Be 0
        $script:state.GitHubWrites | Should -Be 0
        $failure | Should -Not -BeNullOrEmpty
        $failure.Exception.Message | Should -Match 'proof|ownership|unverifiable'
    }

    It 'rejects an unverifiable annotated tag rather than trusting its release target hint' {
        $script:state.Tag = @{ type = 'tag'; sha = '3333333333333333333333333333333333333333' }
        $script:state.TagObject = @{
            sha     = $script:state.Tag.sha
            tag     = 'v1.2.4'
            message = 'Legacy annotation.'
            object  = @{ type = 'tree'; sha = $env:GITHUB_SHA }
        }

        $failure = $null
        try { & $script:publishScriptPath 1>$null 6>$null } catch { $failure = $_ }

        $script:state.GalleryWrites | Should -Be 0
        $script:state.GitHubWrites | Should -Be 0
        $failure | Should -Not -BeNullOrEmpty
        $failure.Exception.Message | Should -Match 'commit|immutable|tag'
    }

    It 'rejects a missing immutable source before all external mutations' {
        $env:PSMODULE_PUBLISH_PSMODULE_INPUT_CommitSha = ''
        $env:GITHUB_SHA = ''

        $failure = $null
        try { & $script:publishScriptPath 1>$null 6>$null } catch { $failure = $_ }

        $script:state.GalleryWrites | Should -Be 0
        $script:state.GitHubWrites | Should -Be 0
        $failure | Should -Not -BeNullOrEmpty
        $failure.Exception.Message | Should -Match 'source|CommitSha|GITHUB_SHA'
    }

    It 'keeps WhatIf free of Gallery and GitHub calls' {
        $env:PSMODULE_PUBLISH_PSMODULE_INPUT_WhatIf = 'true'

        { & $script:publishScriptPath 1>$null 6>$null } | Should -Not -Throw

        $script:state.GalleryWrites | Should -Be 0
        $script:state.GitHubWrites | Should -Be 0
        $script:state.Calls.Count | Should -Be 0
    }

    It 'claims the exact source and tested bytes before a valid new Gallery publication' {
        { & $script:publishScriptPath 1>$null 6>$null } | Should -Not -Throw

        $script:state.GalleryWrites | Should -Be 1
        $script:state.GitHubCreationUpload | Should -Be 0
        $script:state.Calls.IndexOf('tag-ref-create') | Should -BeLessThan $script:state.Calls.IndexOf('gallery-write')
        $script:state.TagObject.object.sha | Should -BeExactly $env:GITHUB_SHA
        $claim = Get-PSModulePublicationClaim -Message $script:state.TagObject.message
        $claim.ArtifactSha256 | Should -BeExactly $script:state.ExpectedClaim.ArtifactSha256
        $claim.AssetSha256 | Should -BeExactly $script:state.ExpectedClaim.AssetSha256
    }

    It 'retains a proven exact-version Gallery package without any duplicate upload' {
        Set-PSModuleFixtureClaim -State $script:state -Claim $script:state.ExpectedClaim
        $script:state.Package = [pscustomobject]@{ Name = 'TestModule'; Version = '1.2.4' }
        $script:state.RawPackage = Join-Path -Path $TestDrive -ChildPath 'original.nupkg'
        New-PSModuleFixturePackage -Path $script:modulePath -DestinationPath $script:state.RawPackage -Version '1.2.4'

        { & $script:publishScriptPath 1>$null 6>$null } | Should -Not -Throw

        $script:state.GalleryWrites | Should -Be 0
        $script:state.GitHubWrites | Should -Be 0
        $script:state.Calls | Should -Contain 'raw-package-read'
    }

    It 'rejects a foreign concurrent claim before Gallery or GitHub release creation/upload' {
        $script:state.OnTagCreate = {
            param($State)
            $foreign = $State.ExpectedClaim | ConvertTo-Json -Compress | ConvertFrom-Json
            $foreign.CommitSha = '2222222222222222222222222222222222222222'
            Set-PSModuleFixtureClaim -State $State -Claim $foreign -TagSha '4444444444444444444444444444444444444444'
        }

        $failure = $null
        try { & $script:publishScriptPath 1>$null 6>$null } catch { $failure = $_ }

        $script:state.GalleryWrites | Should -Be 0
        $script:state.GitHubCreationUpload | Should -Be 0
        $script:state.Tag.sha | Should -BeExactly '4444444444444444444444444444444444444444'
        $failure.Exception.Message | Should -Match 'belongs|source|ownership'
    }

    It 'rejects a changed same-source claim during the final pre-Gallery recheck' {
        Set-PSModuleFixtureClaim -State $script:state -Claim $script:state.ExpectedClaim
        $script:state.OnTagRead = {
            param($State)
            if ($State.TagReads -eq 3) {
                $foreign = $State.ExpectedClaim | ConvertTo-Json -Compress | ConvertFrom-Json
                $foreign.AssetSha256 = 'a' * 64
                Set-PSModuleFixtureClaim -State $State -Claim $foreign -TagSha '4444444444444444444444444444444444444444'
            }
        }

        $failure = $null
        try { & $script:publishScriptPath 1>$null 6>$null } catch { $failure = $_ }

        $script:state.GalleryWrites | Should -Be 0
        $script:state.GitHubWrites | Should -Be 0
        $failure.Exception.Message | Should -Match 'artifact|asset|contents'
    }

    It 'rejects malformed provenance before all external writes' {
        Set-PSModuleFixtureClaim -State $script:state -Claim $script:state.ExpectedClaim
        $script:state.TagObject.message = '<!-- PSModule.Publication:v1:invalid -->'

        $failure = $null
        try { & $script:publishScriptPath 1>$null 6>$null } catch { $failure = $_ }

        $script:state.GalleryWrites | Should -Be 0
        $script:state.GitHubWrites | Should -Be 0
        $failure | Should -Not -BeNullOrEmpty
    }

    It 'rejects changed Gallery package bytes despite matching numeric version and source claim' {
        Set-PSModuleFixtureClaim -State $script:state -Claim $script:state.ExpectedClaim
        $script:state.Package = [pscustomobject]@{ Name = 'TestModule'; Version = '1.2.4' }
        $script:state.RawPackage = Join-Path -Path $TestDrive -ChildPath 'foreign.nupkg'
        $payloadPath = Join-Path -Path $script:modulePath -ChildPath 'TestModule.psm1'
        $original = [IO.File]::ReadAllBytes($payloadPath)
        [IO.File]::WriteAllText($payloadPath, '# Foreign package bytes.')
        New-PSModuleFixturePackage -Path $script:modulePath -DestinationPath $script:state.RawPackage -Version '1.2.4'
        [IO.File]::WriteAllBytes($payloadPath, $original)

        $failure = $null
        try { & $script:publishScriptPath 1>$null 6>$null } catch { $failure = $_ }

        $script:state.GalleryWrites | Should -Be 0
        $script:state.GitHubWrites | Should -Be 0
        $failure.Exception.Message | Should -Match 'Gallery package.*different|unverifiable'
    }

    It 'rejects another PR footer even when tag, source, and ZIP proof match' {
        $script:state.ExpectedClaim.PullRequest = 42
        $env:PSMODULE_PUBLISH_PSMODULE_INPUT_PullRequest = '{"Number":42}'
        Set-PSModuleFixtureClaim -State $script:state -Claim $script:state.ExpectedClaim
        $foreign = @{ Repository = 'PSModule/TestModule'; PullRequest = 99; CommitSha = $env:GITHUB_SHA } |
            ConvertTo-Json -Compress
        $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($foreign))
        $script:state.Release = [pscustomobject]@{
            tag_name   = 'v1.2.4'
            html_url   = 'https://github.com/PSModule/TestModule/releases/tag/v1.2.4'
            prerelease = $false
            body       = "Notes.`n<!-- PSModule.PrereleaseOwner:v1:$encoded -->"
            assets     = @()
        }

        $failure = $null
        try { & $script:publishScriptPath 1>$null 6>$null } catch { $failure = $_ }

        $script:state.GalleryWrites | Should -Be 0
        $script:state.GitHubWrites | Should -Be 0
        $failure.Exception.Message | Should -Match 'pull request'
    }
}
