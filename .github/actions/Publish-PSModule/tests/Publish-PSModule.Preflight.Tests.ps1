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
    $script:replacedCommands = @('gh', 'Find-PSResource', 'Publish-PSResource', 'Invoke-WebRequest')
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

        $state = @{
            Calls         = [Collections.Generic.List[string]]::new()
            GalleryWrites = 0
            GitHubWrites  = 0
            Tag           = $null
            TagObject     = $null
            Release       = $null
            Package       = $null
            ApiError      = ''
        }
        $script:state = $state

        Set-Item -Path function:global:Find-PSResource -Value {
            [CmdletBinding()]
            param(
                [string] $Name,
                [string] $Version,
                [string] $Repository
            )
            if ($Name -cne 'TestModule' -or $Version -cne '1.2.4' -or $Repository -cne 'PSGallery') {
                throw "Unexpected exact package lookup: [$Name] [$Version] [$Repository]."
            }
            $state.Calls.Add('gallery-read')
            if ($null -ne $state.Package) {
                return $state.Package
            }
            Write-Error -Message 'The exact fixture package is absent.' -ErrorId PackageNotFound -Category ObjectNotFound
        }.GetNewClosure()

        Set-Item -Path function:global:Publish-PSResource -Value {
            $state.Calls.Add('gallery-write')
            $state.GalleryWrites++
        }.GetNewClosure()

        Set-Item -Path function:global:Invoke-WebRequest -Value {
            throw 'Package bytes must come from an explicitly injected local fixture, never a network request.'
        }

        Set-Item -Path function:global:gh -Value {
            [CmdletBinding()]
            param(
                [Parameter(ValueFromRemainingArguments)]
                [string[]] $Arguments
            )
            $state.Calls.Add("github: $($Arguments -join ' ')")
            $global:LASTEXITCODE = 0
            if ($Arguments[0] -eq 'api' -and $Arguments -notcontains 'POST' -and $Arguments -notcontains 'PATCH') {
                if ($state.ApiError) {
                    $global:LASTEXITCODE = 1
                    return $state.ApiError
                }
                if ($Arguments[1] -like '*/git/ref/tags/*') {
                    if ($null -ne $state.Tag) {
                        return (@{ object = $state.Tag } | ConvertTo-Json -Depth 10 -Compress)
                    }
                } elseif ($Arguments[1] -like '*/git/tags/*') {
                    return ($state.TagObject | ConvertTo-Json -Depth 10 -Compress)
                } elseif ($Arguments[1] -like '*/releases/tags/*') {
                    if ($null -ne $state.Release) {
                        return ($state.Release | ConvertTo-Json -Depth 10 -Compress)
                    }
                } else {
                    throw "Unexpected read in publication fixture: $($Arguments -join ' ')."
                }
                $global:LASTEXITCODE = 1
                return 'gh: Not Found (HTTP 404)'
            }
            $state.GitHubWrites++
            throw "Unexpected mutation in a rejected publication fixture: $($Arguments -join ' ')."
        }.GetNewClosure()
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
        $script:state.Tag = @{ type = 'commit'; sha = $env:GITHUB_SHA }
        $asset = @{
            name   = 'TestModule-1.2.4.zip'
            digest = 'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
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
        $script:state.ApiError = 'gh: Service Unavailable (HTTP 503)'

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
            object = @{ type = 'tree'; sha = $env:GITHUB_SHA }
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
}
