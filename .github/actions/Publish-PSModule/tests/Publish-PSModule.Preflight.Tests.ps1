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
    Import-Module -Name ([IO.Path]::Combine($PSScriptRoot, '..', 'src', 'Publish-PSModule.Helpers.psm1')) -Force
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'Publish-PSModule.TestFixture.psm1') -Force

    $script:publishScriptPath = [IO.Path]::GetFullPath(
        [IO.Path]::Combine($PSScriptRoot, '..', 'src', 'publish.ps1')
    )
    $script:releaseScriptPath = [IO.Path]::GetFullPath(
        [IO.Path]::Combine($PSScriptRoot, '..', '..', 'Release-PSModule', 'src', 'release.ps1')
    )
    $script:environmentVariableNames = @(
        'GITHUB_EVENT_PATH'
        'GITHUB_OUTPUT'
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
        'PSMODULE_RELEASE_PSMODULE_INPUT_Name'
        'PSMODULE_RELEASE_PSMODULE_INPUT_ModulePath'
        'PSMODULE_RELEASE_PSMODULE_INPUT_ReleaseTag'
        'PSMODULE_RELEASE_PSMODULE_INPUT_VersionPrefix'
        'PSMODULE_RELEASE_PSMODULE_INPUT_CommitSha'
        'PSMODULE_RELEASE_PSMODULE_INPUT_PullRequest'
        'PSMODULE_RELEASE_PSMODULE_INPUT_WhatIf'
        'PSMODULE_RELEASE_PSMODULE_INPUT_UsePRBodyAsReleaseNotes'
        'PSMODULE_RELEASE_PSMODULE_INPUT_UsePRTitleAsReleaseName'
        'PSMODULE_RELEASE_PSMODULE_INPUT_UsePRTitleAsNotesHeading'
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
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_Name = 'TestModule'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_ModulePath = '.PSModule/module'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_ReleaseTag = 'v1.2.4'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_VersionPrefix = 'v'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_CommitSha = $env:GITHUB_SHA
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_PullRequest = ''
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_WhatIf = 'false'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_UsePRBodyAsReleaseNotes = 'false'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_UsePRTitleAsReleaseName = 'false'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_UsePRTitleAsNotesHeading = 'false'
        $env:GITHUB_OUTPUT = Join-Path -Path $env:GITHUB_WORKSPACE -ChildPath 'outputs'
        $null = New-Item -Path $env:GITHUB_OUTPUT -ItemType File

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
            draft      = $false
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

    It 'rejects a malformed <Resource> response before publication' -ForEach @(
        @{ Resource = 'repository array' }
        @{ Resource = 'commit array' }
        @{ Resource = 'string write permission' }
        @{ Resource = 'release ref array' }
        @{ Resource = 'annotation target array' }
        @{ Resource = 'release array' }
        @{ Resource = 'asset digest array' }
    ) {
        if ($Resource -ceq 'commit array') {
            $endpoint = "repos/PSModule/TestModule/git/commits/$env:GITHUB_SHA"
            $script:state.ApiResponses[$endpoint] = @([pscustomobject]@{ sha = $env:GITHUB_SHA })
        } elseif ($Resource -in @('repository array', 'string write permission')) {
            $metadata = [pscustomobject]@{
                full_name = 'PSModule/TestModule'; permissions = [pscustomobject]@{ push = $true }
            }
            if ($Resource -ceq 'string write permission') {
                $metadata.permissions.push = 'true'
                $script:state.ApiResponses['repos/PSModule/TestModule'] = $metadata
            } else {
                $script:state.ApiResponses['repos/PSModule/TestModule'] = @($metadata)
            }
        } else {
            Set-PSModuleFixtureClaim -State $script:state -Claim $script:state.ExpectedClaim
            if ($Resource -ceq 'release ref array') {
                $script:state.ApiResponses['repos/PSModule/TestModule/git/ref/tags/v1.2.4'] = @([pscustomobject]@{
                        ref = 'refs/tags/v1.2.4'; object = $script:state.Tag
                    })
            } elseif ($Resource -ceq 'annotation target array') {
                $script:state.TagObject.object = @([pscustomobject]@{ type = 'commit'; sha = $env:GITHUB_SHA })
            } else {
                $release = [pscustomobject]@{
                    tag_name = 'v1.2.4'; html_url = 'https://github.com/PSModule/TestModule/releases/tag/v1.2.4'
                    prerelease = $false; draft = $false; body = 'Direct release notes.'; assets = @()
                }
                if ($Resource -ceq 'release array') {
                    $script:state.ApiResponses['repos/PSModule/TestModule/releases/tags/v1.2.4'] = @($release)
                } else {
                    $release.assets = @([pscustomobject]@{
                            name = 'TestModule-1.2.4.zip'; state = 'uploaded'
                            digest = @("sha256:$($script:state.ExpectedClaim.AssetSha256)")
                        })
                    $script:state.Release = $release
                }
            }
        }

        $failure = $null
        try { & $script:publishScriptPath 1>$null 6>$null } catch { $failure = $_ }

        $script:state.GalleryWrites | Should -Be 0
        $script:state.GitHubWrites | Should -Be 0
        $failure.Exception.Message | Should -Match 'metadata|access|source|tag'
    }

    It 'retains a verified empty tag enumeration instead of treating it as an unknown JSON response' {
        $script:state.ApiResponses['repos/PSModule/TestModule/git/matching-refs/tags/'] = @()

        $response = Invoke-PSModulePublicationApi -Endpoint 'repos/PSModule/TestModule/git/matching-refs/tags/'

        $response.Value -is [array] | Should -BeTrue
        $response.Value.Count | Should -Be 0
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

    It 'rejects a <Controller> ZIP payload inconsistent with the tested file-tree claim before all writes' -ForEach @(
        @{ Controller = 'publisher' }
        @{ Controller = 'release' }
    ) {
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

        $controllerPath = $script:publishScriptPath
        if ($Controller -ceq 'release') { $controllerPath = $script:releaseScriptPath }
        $failure = $null
        try { & $controllerPath 1>$null 6>$null } catch { $failure = $_ }

        Should -Invoke -CommandName Get-FileHash -Times 1 -Exactly -ParameterFilter { $LiteralPath -like '*.zip' }
        $script:state.GalleryWrites | Should -Be 0
        $script:state.GitHubWrites | Should -Be 0
        $failure.Exception.Message | Should -Match 'archive'
    }

    It 'rejects a changed <Controller> artifact before reserving any immutable claim' -ForEach @(
        @{ Controller = 'publisher' }
        @{ Controller = 'release' }
    ) {
        $script:state.PayloadPath = Join-Path -Path $script:modulePath -ChildPath 'TestModule.psm1'
        $script:state.OnTagRead = {
            param($State)
            if ($State.TagReads -eq 1) {
                [IO.File]::WriteAllText($State.PayloadPath, '# Changed candidate after the byte snapshot.')
            }
        }
        $controllerPath = $script:publishScriptPath
        if ($Controller -ceq 'release') { $controllerPath = $script:releaseScriptPath }

        { & $controllerPath 1>$null 6>$null } | Should -Throw '*artifact*immutable claim*'

        $script:state.GalleryWrites | Should -Be 0
        $script:state.GitHubWrites | Should -Be 0
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
            draft      = $false
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

    It 'rejects a terminal ownership marker with <Shape> before publication' -ForEach @(
        @{ Shape = 'indentation' }
        @{ Shape = 'inline placement' }
        @{ Shape = 'missing delimiter spacing' }
    ) {
        Set-PSModuleFixtureClaim -State $script:state -Claim $script:state.ExpectedClaim
        $owner = [pscustomobject]@{
            Repository = 'Other/TestModule'; PullRequest = 99; CommitSha = $env:GITHUB_SHA
        } | ConvertTo-Json -Compress
        $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($owner))
        $footer = "<!-- PSModule.PrereleaseOwner:v1:$encoded -->"
        if ($Shape -ceq 'indentation') {
            $body = "Notes.`n    $footer"
        } elseif ($Shape -ceq 'inline placement') {
            $body = "Notes. $footer"
        } else {
            $body = $footer.Replace('<!-- ', '<!--')
        }
        $script:state.Release = [pscustomobject]@{
            tag_name = 'v1.2.4'; html_url = 'https://github.com/PSModule/TestModule/releases/tag/v1.2.4'
            prerelease = $false; draft = $false; body = $body; assets = @()
        }

        $failure = $null
        try { & $script:publishScriptPath 1>$null 6>$null } catch { $failure = $_ }

        $script:state.GalleryWrites | Should -Be 0
        $script:state.GitHubWrites | Should -Be 0
        $failure.Exception.Message | Should -Match 'footer'
    }

    It 'rejects a stable PR release with no producing-context footer rather than inferring ownership from its tag' {
        $script:state.ExpectedClaim.PullRequest = 42
        $env:PSMODULE_PUBLISH_PSMODULE_INPUT_PullRequest = '{"Number":42}'
        Set-PSModuleFixtureClaim -State $script:state -Claim $script:state.ExpectedClaim
        $script:state.Release = [pscustomobject]@{
            tag_name = 'v1.2.4'; html_url = 'https://github.com/PSModule/TestModule/releases/tag/v1.2.4'
            prerelease = $false; draft = $false; body = 'Unknown stable publication context.'; assets = @()
        }

        $failure = $null
        try { & $script:publishScriptPath 1>$null 6>$null } catch { $failure = $_ }

        $script:state.GalleryWrites | Should -Be 0
        $script:state.GitHubWrites | Should -Be 0
        $failure.Exception.Message | Should -Match 'footer'
    }

    It 'retains complete stable PR notes and footer across an exact missing-upload retry' {
        $script:state.ExpectedClaim.PullRequest = 42
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_PullRequest = '{"Number":42,"Title":"Stable release","Body":"Complete authored stable notes."}'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_UsePRBodyAsReleaseNotes = 'true'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_UsePRTitleAsNotesHeading = 'true'

        { & $script:releaseScriptPath 1>$null 6>$null } | Should -Not -Throw

        $script:state.Release.body | Should -Match 'Complete authored stable notes\.'
        (Get-PSModulePrereleaseOwnership -Body $script:state.Release.body).PullRequest | Should -Be 42
        $originalNotes = $script:state.Release.body
        $script:state.Release.assets = @()
        $script:state.GitHubWrites = 0
        $script:state.GitHubCreationUpload = 0

        { & $script:releaseScriptPath 1>$null 6>$null } | Should -Not -Throw

        $script:state.GitHubCreationUpload | Should -Be 1
        $script:state.Release.body | Should -BeExactly $originalNotes
    }

    It 'rejects array-valued release <Field> metadata before any claim or upload' -ForEach @(
        @{ Field = 'Title' }
        @{ Field = 'Body' }
        @{ Field = 'HeadRef' }
    ) {
        $context = @{ Number = 42 }
        $context[$Field] = @('Unverifiable projected metadata.')
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_PullRequest = $context | ConvertTo-Json -Compress

        { & $script:releaseScriptPath 1>$null 6>$null } | Should -Throw '*metadata*'

        $script:state.GalleryWrites | Should -Be 0
        $script:state.GitHubWrites | Should -Be 0
    }

    It 'rejects <Shape> generated stable notes before release creation or upload' -ForEach @(
        @{ Shape = 'array-valued body' }
        @{ Shape = 'top-level array' }
    ) {
        $script:state.ExpectedClaim.PullRequest = 42
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_PullRequest = '{"Number":42}'
        [IO.File]::WriteAllText($env:GITHUB_EVENT_PATH, '{"head_commit":{"message":""}}')
        Mock -CommandName git -MockWith {
            $global:LASTEXITCODE = 0
            ''
        }
        $notes = [pscustomobject]@{ body = 'Complete notes.' }
        if ($Shape -ceq 'array-valued body') {
            $notes.body = @('Incomplete projected notes.')
            $script:state.ApiResponses['repos/PSModule/TestModule/releases/generate-notes'] = $notes
        } else {
            $script:state.ApiResponses['repos/PSModule/TestModule/releases/generate-notes'] = @($notes)
        }

        { & $script:releaseScriptPath 1>$null 6>$null } | Should -Throw '*notes*'

        Should -Invoke -CommandName git -Times 1 -Exactly
        ($script:state.Calls -join "`n") | Should -Match 'releases/generate-notes'
        $script:state.GalleryWrites | Should -Be 0
        $script:state.GitHubCreationUpload | Should -Be 0
    }

    It 'retains complete generated stable notes before the producing-context footer' {
        $script:state.ExpectedClaim.PullRequest = 42
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_PullRequest = '{"Number":42}'
        [IO.File]::WriteAllText($env:GITHUB_EVENT_PATH, '{"head_commit":{"message":""}}')
        Mock -CommandName git -MockWith {
            $global:LASTEXITCODE = 0
            ''
        }

        { & $script:releaseScriptPath 1>$null 6>$null } | Should -Not -Throw

        Should -Invoke -CommandName git -Times 1 -Exactly
        ($script:state.Calls -join "`n") | Should -Match 'releases/generate-notes'
        $script:state.Release.body | Should -Match '^Complete independently generated fixture notes\.'
        (Get-PSModulePrereleaseOwnership -Body $script:state.Release.body).PullRequest | Should -Be 42
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

    It 'rejects original event PR context before projection' -ForEach @(
        @{ EventJson = '{"pull_request":[{"number":42}]}' }
        @{ EventJson = '{"pull_request":{"number":[42]}}' }
        @{ EventJson = '[{"pull_request":{"number":42}}]' }
        @{ EventJson = '{"pull_request":{}}' }
    ) {
        [IO.File]::WriteAllText($env:GITHUB_EVENT_PATH, $EventJson)

        { & $script:publishScriptPath 1>$null 6>$null } | Should -Throw '*context*'

        $script:state.GalleryWrites | Should -Be 0
        $script:state.GitHubWrites | Should -Be 0
    }

    It 'retains the valid producing event PR number before projection' {
        [IO.File]::WriteAllText($env:GITHUB_EVENT_PATH, '{"pull_request":{"number":42}}')
        $script:state.ExpectedClaim.PullRequest = 42

        { & $script:publishScriptPath 1>$null 6>$null } | Should -Not -Throw

        $script:state.GalleryWrites | Should -Be 1
        $claim = Get-PSModulePublicationClaim -Message $script:state.TagObject.message
        $claim.PullRequest | Should -Be 42
    }

    It 'rejects original release event PR context before projection' -ForEach @(
        @{ EventJson = '{"pull_request":[{"number":42}]}' }
        @{ EventJson = '{"pull_request":{"number":[42]}}' }
        @{ EventJson = '[{"pull_request":{"number":42}}]' }
        @{ EventJson = '{"pull_request":{}}' }
    ) {
        [IO.File]::WriteAllText($env:GITHUB_EVENT_PATH, $EventJson)

        { & $script:releaseScriptPath 1>$null 6>$null } | Should -Throw '*context*'

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

    It 'rejects <Shape> draft metadata before Gallery or GitHub writes' -ForEach @(
        @{ Shape = 'missing' }
        @{ Shape = 'null' }
        @{ Shape = 'string false' }
        @{ Shape = 'array false' }
    ) {
        Set-PSModuleFixtureClaim -State $script:state -Claim $script:state.ExpectedClaim
        $release = [pscustomobject]@{
            tag_name = 'v1.2.4'; html_url = 'https://github.com/PSModule/TestModule/releases/tag/v1.2.4'
            prerelease = $false; body = 'Direct release notes.'; assets = @()
        }
        if ($Shape -ceq 'null') {
            $release | Add-Member -NotePropertyName draft -NotePropertyValue $null
        } elseif ($Shape -ceq 'string false') {
            $release | Add-Member -NotePropertyName draft -NotePropertyValue 'false'
        } elseif ($Shape -ceq 'array false') {
            $release | Add-Member -NotePropertyName draft -NotePropertyValue @($false)
        }
        $script:state.ApiResponses['repos/PSModule/TestModule/releases/tags/v1.2.4'] = $release

        $failure = $null
        try { & $script:publishScriptPath 1>$null 6>$null } catch { $failure = $_ }

        $script:state.GalleryWrites | Should -Be 0
        $script:state.GitHubWrites | Should -Be 0
        $failure.Exception.Message | Should -Match 'draft|published'
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
