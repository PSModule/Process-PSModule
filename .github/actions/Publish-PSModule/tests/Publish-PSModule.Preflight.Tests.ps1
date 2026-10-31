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
        'PSMODULE_PUBLISH_PSMODULE_INPUT_VersionPrefix'
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
        $workspaceName = "workspace-$([guid]::NewGuid())"
        $script:modulePath = Join-Path -Path $TestDrive -ChildPath $workspaceName -AdditionalChildPath '.PSModule', 'module', 'TestModule'
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
        $env:GITHUB_WORKSPACE = Join-Path -Path $TestDrive -ChildPath $workspaceName
        $env:PSMODULE_PUBLISH_PSMODULE_INPUT_Name = 'TestModule'
        $env:PSMODULE_PUBLISH_PSMODULE_INPUT_ModulePath = '.PSModule/module'
        $env:PSMODULE_PUBLISH_PSMODULE_INPUT_PSGALLERY_API_KEY = 'anonymous-fixture'
        $env:PSMODULE_PUBLISH_PSMODULE_INPUT_PullRequest = ''
        $env:PSMODULE_PUBLISH_PSMODULE_INPUT_ReleaseTag = 'v1.2.4'
        $env:PSMODULE_PUBLISH_PSMODULE_INPUT_VersionPrefix = 'v'
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

    It 'rejects a <Shape> publication claim before all writes' -ForEach @(
        @{ Shape = 'top-level array' }
        @{ Shape = 'array-valued field' }
    ) {
        $claim = $script:state.ExpectedClaim | ConvertTo-Json -Compress | ConvertFrom-Json
        if ($Shape -ceq 'array-valued field') {
            $claim.PullRequest = @(0)
        }
        $json = $claim | ConvertTo-Json -Compress
        if ($Shape -ceq 'top-level array') { $json = "[$json]" }
        Set-PSModuleFixtureClaim -State $script:state -Claim $script:state.ExpectedClaim
        $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($json))
        $script:state.TagObject.message = "<!-- PSModule.Publication:v1:$encoded -->"

        { & $script:publishScriptPath 1>$null 6>$null } | Should -Throw '*publication*'

        $script:state.GalleryWrites | Should -Be 0
        $script:state.GitHubWrites | Should -Be 0
    }

    It 'rejects a <Shape> release footer before all writes' -ForEach @(
        @{ Shape = 'top-level array' }
        @{ Shape = 'array-valued field' }
    ) {
        $script:state.ExpectedClaim.PullRequest = 42
        $env:PSMODULE_PUBLISH_PSMODULE_INPUT_PullRequest = '{"Number":42}'
        Set-PSModuleFixtureClaim -State $script:state -Claim $script:state.ExpectedClaim
        $owner = [pscustomobject]@{
            Repository = 'PSModule/TestModule'; PullRequest = 42; CommitSha = $env:GITHUB_SHA
        }
        if ($Shape -ceq 'array-valued field') { $owner.PullRequest = @(42) }
        $json = $owner | ConvertTo-Json -Compress
        if ($Shape -ceq 'top-level array') { $json = "[$json]" }
        $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($json))
        $script:state.Release = [pscustomobject]@{
            tag_name = 'v1.2.4'; html_url = 'https://github.com/PSModule/TestModule/releases/tag/v1.2.4'
            prerelease = $false; draft = $false; body = "<!-- PSModule.PrereleaseOwner:v1:$encoded -->"; assets = @()
        }

        { & $script:publishScriptPath 1>$null 6>$null } | Should -Throw '*footer*'

        $script:state.GalleryWrites | Should -Be 0
        $script:state.GitHubWrites | Should -Be 0
    }

    It 'rejects a ZIP payload inconsistent with the tested file-tree claim before all writes' {
        Mock -CommandName Get-FileHash -ParameterFilter { $LiteralPath -like '*.zip' } -MockWith {
            $archive = [IO.Compression.ZipFile]::Open($LiteralPath, [IO.Compression.ZipArchiveMode]::Update)
            try {
                $archive.GetEntry('TestModule/TestModule.psm1').Delete()
                $writer = [IO.StreamWriter]::new($archive.CreateEntry('TestModule/TestModule.psm1').Open())
                try { $writer.Write('# Different ZIP payload bytes.') } finally { $writer.Dispose() }
            } finally {
                $archive.Dispose()
            }
            $stream = [IO.File]::OpenRead($LiteralPath)
            $sha256 = [Security.Cryptography.SHA256]::Create()
            try {
                [pscustomobject]@{
                    Hash = [BitConverter]::ToString($sha256.ComputeHash($stream)).Replace('-', '')
                }
            } finally {
                $sha256.Dispose()
                $stream.Dispose()
            }
        }

        $failure = $null
        try { & $script:publishScriptPath 1>$null 6>$null } catch { $failure = $_ }

        Should -Invoke -CommandName Get-FileHash -Times 1 -Exactly -ParameterFilter { $LiteralPath -like '*.zip' }
        $script:state.GalleryWrites | Should -Be 0
        $script:state.GitHubWrites | Should -Be 0
        $failure.Exception.Message | Should -Match 'archive'
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

    It 'rejects an unreadable final ownership footer on a stable release' -ForEach @(
        @{ Footer = '<!-- PSModule.PrereleaseOwner:v2:e30= -->' }
        @{ Footer = '<!-- PSModule.PrereleaseOwner:v1:not-base64 -->' }
        @{ Footer = "<!-- PSModule.PrereleaseOwner:v1:`ne30= -->" }
    ) {
        Set-PSModuleFixtureClaim -State $script:state -Claim $script:state.ExpectedClaim
        $script:state.Release = [pscustomobject]@{
            tag_name = 'v1.2.4'; html_url = 'https://github.com/PSModule/TestModule/releases/tag/v1.2.4'
            prerelease = $false; draft = $false; body = "Notes.`n$Footer"; assets = @()
        }

        { & $script:publishScriptPath 1>$null 6>$null } | Should -Throw '*footer*'

        $script:state.GalleryWrites | Should -Be 0
        $script:state.GitHubWrites | Should -Be 0
    }

    It 'rejects a disappeared previously claimed tag rather than recreating it' {
        Set-PSModuleFixtureClaim -State $script:state -Claim $script:state.ExpectedClaim
        $script:state.OnTagRead = {
            param($State)
            if ($State.TagReads -eq 2) {
                $State.Tag = $null
                $State.TagObject = $null
            }
        }

        { & $script:publishScriptPath 1>$null 6>$null } | Should -Throw '*changed*'

        $script:state.GalleryWrites | Should -Be 0
        $script:state.GitHubWrites | Should -Be 0
    }

    It 'rejects an observed tag that <Mutation> during the shared coordinate reservation' -ForEach @(
        @{ Mutation = 'disappears' }
        @{ Mutation = 'is replaced' }
    ) {
        Set-PSModuleFixtureClaim -State $script:state -Claim $script:state.ExpectedClaim
        $script:state.VersionTag = $null
        $script:state.VersionTagObject = $null
        $script:state.LateTagMutation = $Mutation
        $script:state.OnVersionTagCreate = {
            param($State)
            if ($State.LateTagMutation -ceq 'disappears') {
                $State.Tag = $null
            } else {
                Set-PSModuleFixtureClaim -State $State -Claim $State.ExpectedClaim `
                    -TagSha '4444444444444444444444444444444444444444'
            }
        }

        $failure = $null
        try { & $script:publishScriptPath 1>$null 6>$null } catch { $failure = $_ }

        $script:state.GalleryWrites | Should -Be 0
        $script:state.GitHubCreationUpload | Should -Be 0
        $script:state.Calls | Should -Contain 'module-version-ref-create'
        $script:state.Calls | Should -Not -Contain 'tag-ref-create'
        $failure.Exception.Message | Should -Match 'tag.*changed|disappeared'
    }

    It 'rejects losing a tag first observed after preflight during the shared coordinate reservation' {
        $script:state.OnTagRead = {
            param($State)
            if ($State.TagReads -eq 2) {
                Set-PSModuleFixtureClaim -State $State -Claim $State.ExpectedClaim
                $State.VersionTag = $null
                $State.VersionTagObject = $null
            }
        }
        $script:state.OnVersionTagCreate = {
            param($State)
            $State.Tag = $null
        }

        $failure = $null
        try { & $script:publishScriptPath 1>$null 6>$null } catch { $failure = $_ }

        $script:state.GalleryWrites | Should -Be 0
        $script:state.GitHubCreationUpload | Should -Be 0
        $script:state.Calls | Should -Contain 'module-version-ref-create'
        $script:state.Calls | Should -Not -Contain 'tag-ref-create'
        $script:state.Tag | Should -BeNullOrEmpty
        $failure.Exception.Message | Should -Match 'tag.*changed|disappeared'
    }

    It 'reserves a missing shared coordinate without replacing an unchanged existing tag' {
        Set-PSModuleFixtureClaim -State $script:state -Claim $script:state.ExpectedClaim
        $script:state.VersionTag = $null
        $script:state.VersionTagObject = $null

        { & $script:publishScriptPath 1>$null 6>$null } | Should -Not -Throw

        $script:state.GalleryWrites | Should -Be 1
        $script:state.Tag.sha | Should -BeExactly '3333333333333333333333333333333333333333'
        $script:state.VersionTag.sha | Should -BeExactly $script:state.Tag.sha
        $script:state.Calls | Should -Contain 'module-version-ref-create'
        $script:state.Calls | Should -Not -Contain 'tag-ref-create'
        $script:state.Calls | Should -Not -Contain 'tag-object-create'
    }

    It 'completes a partial shared claim when the release tag has never been observed' {
        Set-PSModuleFixtureClaim -State $script:state -Claim $script:state.ExpectedClaim
        $script:state.Tag = $null
        $script:state.TagObject = $null

        { & $script:publishScriptPath 1>$null 6>$null } | Should -Not -Throw

        $script:state.GalleryWrites | Should -Be 1
        $script:state.Tag.sha | Should -BeExactly $script:state.VersionTag.sha
        $script:state.Calls | Should -Contain 'tag-ref-create'
        $script:state.Calls | Should -Not -Contain 'module-version-ref-create'
        $script:state.Calls | Should -Not -Contain 'tag-object-create'
    }

    It 'rejects supplied PR context without a positive identity before all writes' -ForEach @(
        @{ Json = '{}' }
        @{ Json = '{"Number":0}' }
        @{ Json = '{"Number":"unknown"}' }
        @{ Json = '{"Number":[42]}' }
        @{ Json = '42' }
        @{ Json = '[]' }
        @{ Json = '[null]' }
        @{ Json = '[{"Number":42}]' }
        @{ Json = '[{"Number":0}]' }
    ) {
        $env:PSMODULE_PUBLISH_PSMODULE_INPUT_PullRequest = $Json

        { & $script:publishScriptPath 1>$null 6>$null } | Should -Throw '*pull request*'

        $script:state.GalleryWrites | Should -Be 0
        $script:state.GitHubWrites | Should -Be 0
    }

    It 'rejects a draft release before Gallery publication rather than reporting completed publication' {
        Set-PSModuleFixtureClaim -State $script:state -Claim $script:state.ExpectedClaim
        $script:state.Release = [pscustomobject]@{
            tag_name = 'v1.2.4'; html_url = 'https://github.com/PSModule/TestModule/releases/tag/v1.2.4'
            prerelease = $false; draft = $true; body = 'Unpublished draft notes.'; assets = @()
        }

        { & $script:publishScriptPath 1>$null 6>$null } | Should -Throw '*draft*'

        $script:state.GalleryWrites | Should -Be 0
        $script:state.GitHubWrites | Should -Be 0
    }

    It 'rejects a competing module/version claim under another prefix with identical bytes' {
        $foreign = $script:state.ExpectedClaim | ConvertTo-Json -Compress | ConvertFrom-Json
        $foreign.CommitSha = '2222222222222222222222222222222222222222'
        $foreign.PullRequest = 99
        $foreign.VersionPrefix = ''
        $foreign.ReleaseTag = '1.2.4'
        Set-PSModuleFixtureClaim -State $script:state -Claim $foreign -TagSha '4444444444444444444444444444444444444444'
        $script:state.Tag = $null
        $script:state.TagObject = $null

        { & $script:publishScriptPath 1>$null 6>$null } | Should -Throw '*module/version*'

        $script:state.GalleryWrites | Should -Be 0
        $script:state.GitHubWrites | Should -Be 0
    }

    It 'rejects another prefix claiming the package coordinate concurrently before Gallery' {
        $script:state.OnVersionTagCreate = {
            param($State)
            $foreign = $State.ExpectedClaim | ConvertTo-Json -Compress | ConvertFrom-Json
            $foreign.CommitSha = '2222222222222222222222222222222222222222'
            $foreign.VersionPrefix = ''
            $foreign.ReleaseTag = '1.2.4'
            Set-PSModuleFixtureClaim -State $State -Claim $foreign -TagSha '4444444444444444444444444444444444444444'
            $State.Tag = $null
            $State.TagObject = $null
        }

        { & $script:publishScriptPath 1>$null 6>$null } | Should -Throw '*module/version*'

        $script:state.GalleryWrites | Should -Be 0
        $script:state.GitHubCreationUpload | Should -Be 0
    }

    It 'does not fabricate a shared coordinate for an already-published package' {
        Set-PSModuleFixtureClaim -State $script:state -Claim $script:state.ExpectedClaim
        $script:state.VersionTag = $null
        $script:state.VersionTagObject = $null
        $script:state.Package = [pscustomobject]@{ Name = 'TestModule'; Version = '1.2.4' }

        { & $script:publishScriptPath 1>$null 6>$null } | Should -Throw '*module/version ownership proof*'

        $script:state.GalleryWrites | Should -Be 0
        $script:state.GitHubWrites | Should -Be 0
    }

    It 'rejects a tag bound to another artifact version before any claim mutation' {
        $env:PSMODULE_PUBLISH_PSMODULE_INPUT_ReleaseTag = 'v1.2.5'

        { & $script:publishScriptPath 1>$null 6>$null } | Should -Throw '*tag*version*'

        $script:state.GalleryWrites | Should -Be 0
        $script:state.GitHubWrites | Should -Be 0
    }

    It 'preserves an existing custom prefix while reserving the shared package coordinate' {
        $env:PSMODULE_PUBLISH_PSMODULE_INPUT_VersionPrefix = 'release-'
        $env:PSMODULE_PUBLISH_PSMODULE_INPUT_ReleaseTag = 'release-1.2.4'
        $script:state.ExpectedClaim.VersionPrefix = 'release-'
        $script:state.ExpectedClaim.ReleaseTag = 'release-1.2.4'

        { & $script:publishScriptPath 1>$null 6>$null } | Should -Not -Throw

        $script:state.GalleryWrites | Should -Be 1
        $script:state.VersionTag.sha | Should -BeExactly $script:state.Tag.sha
        $script:state.Calls.IndexOf('module-version-ref-create') |
            Should -BeLessThan $script:state.Calls.IndexOf('tag-ref-create')
    }

    It 'rejects NuGet-reserved tested paths before a claim or upload' -ForEach @(
        @{ Components = @('extra.nuspec') }
        @{ Components = @('[Content_Types].xml') }
        @{ Components = @('_rels', '.rels') }
        @{ Components = @('package', 'services', 'metadata', 'core-properties', 'abc.psmdcp') }
    ) {
        $path = $script:modulePath
        foreach ($component in $Components) { $path = [IO.Path]::Combine($path, $component) }
        $null = New-Item -Path (Split-Path -Path $path -Parent) -ItemType Directory -Force
        [IO.File]::WriteAllText($path, 'Reserved anonymous artifact bytes.')

        { & $script:publishScriptPath 1>$null 6>$null } | Should -Throw '*NuGet-reserved*'

        $script:state.GalleryWrites | Should -Be 0
        $script:state.GitHubWrites | Should -Be 0
    }
}
