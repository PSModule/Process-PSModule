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
    Import-Module -Name PSModule -Force
    $script:settingsScriptPath = Join-Path -Path $PSScriptRoot -ChildPath '../src/main.ps1'
    $script:environmentNames = @(
        'GITHUB_EVENT_NAME'
        'GITHUB_SHA'
        'GITHUB_REF'
        'GITHUB_REF_NAME'
        'GITHUB_REPOSITORY_NAME'
        'GITHUB_REPOSITORY_OWNER'
        'PSMODULE_GET_SETTINGS_INPUT_Name'
        'PSMODULE_GET_SETTINGS_INPUT_SettingsPath'
        'PSMODULE_GET_SETTINGS_INPUT_Debug'
        'PSMODULE_GET_SETTINGS_INPUT_Verbose'
        'PSMODULE_GET_SETTINGS_INPUT_Version'
        'PSMODULE_GET_SETTINGS_INPUT_Prerelease'
        'PSMODULE_GET_SETTINGS_INPUT_WorkingDirectory'
        'PSMODULE_GET_SETTINGS_INPUT_ImportantFilePatterns'
    )
    $script:originalEnvironment = @{}
    foreach ($name in $script:environmentNames) {
        $script:originalEnvironment[$name] = [Environment]::GetEnvironmentVariable($name)
    }
}

AfterAll {
    try {
        foreach ($name in $script:environmentNames) {
            [Environment]::SetEnvironmentVariable($name, $script:originalEnvironment[$name])
        }
        foreach ($name in @('Install-PSResource', 'Get-GitHubEventData', 'Invoke-GitHubAPI', 'Set-GitHubOutput')) {
            Remove-Item -Path "Function:\$name" -ErrorAction SilentlyContinue
        }
        Import-Module -Name PSModule -Force
    } finally {
        $script:environmentMutex.ReleaseMutex()
        $script:environmentMutex.Dispose()
    }
}

Describe 'Get-PSModuleSettings release-bearing push detection' {
    BeforeEach {
        $script:state = @{
            Files          = @('docs/guide.md')
            Calls          = [System.Collections.Generic.List[string]]::new()
            InstalledNames = [System.Collections.Generic.List[string]]::new()
            Outputs        = @{}
            Releases       = @()
            TagReferences  = @{}
            TagObjects     = @{}
            Event          = [pscustomobject]@{
                Repository  = [pscustomobject]@{ default_branch = 'main' }
                Action      = ''
                Before      = 'previous-sha'
                After       = 'pushed-sha'
                Ref         = 'refs/heads/main'
                PullRequest = $null
            }
            Associated     = @([pscustomobject]@{
                    Number           = 412
                    Base             = [pscustomobject]@{ Ref = 'main' }
                    merged_at        = '2026-09-01T00:00:00Z'
                    merge_commit_sha = 'another-merge-sha'
                })
        }
        $state = $script:state
        Set-Item -Path 'Function:global:Install-PSResource' -Value {
            [CmdletBinding()]
            param(
                [Parameter(ValueFromPipeline)]
                [string[]] $Name,

                [Parameter()]
                [string] $Repository,

                [Parameter()]
                [switch] $TrustRepository
            )
            process {
                $state.InstalledNames.AddRange($Name)
                $state.Calls.Add("Install $Repository $TrustRepository")
            }
        }.GetNewClosure()
        Set-Item -Path 'Function:global:Get-GitHubEventData' -Value {
            [CmdletBinding()]
            param()
            $state.Event
        }.GetNewClosure()
        Set-Item -Path 'Function:global:Invoke-GitHubAPI' -Value {
            [CmdletBinding()]
            param(
                [Parameter()]
                [string] $ApiEndpoint,

                [Parameter()]
                [string] $Method
            )
            $state.Calls.Add("$Method $ApiEndpoint")
            if ($ApiEndpoint -match '/compare/') {
                [pscustomobject]@{
                    Response = [pscustomobject]@{
                        files = @($state.Files | ForEach-Object { [pscustomobject]@{ filename = $_ } })
                    }
                }
            } elseif ($ApiEndpoint -match '/commits/.+/pulls$') {
                [pscustomobject]@{ Response = $state.Associated }
            } elseif ($ApiEndpoint -match '/releases') {
                [pscustomobject]@{ Response = $state.Releases }
            } elseif ($ApiEndpoint -match '/git/ref/tags/(.+)$') {
                $tag = [Uri]::UnescapeDataString($Matches[1])
                [pscustomobject]@{ Response = [pscustomobject]@{ object = $state.TagReferences[$tag] } }
            } elseif ($ApiEndpoint -match '/git/tags/(.+)$') {
                [pscustomobject]@{ Response = [pscustomobject]@{ object = $state.TagObjects[$Matches[1]] } }
            } else {
                throw "Unexpected GitHub endpoint in settings test: [$ApiEndpoint]."
            }
        }.GetNewClosure()
        Set-Item -Path 'Function:global:Set-GitHubOutput' -Value {
            [CmdletBinding()]
            param(
                [Parameter()]
                [string] $Name,

                [Parameter()]
                [string] $Value
            )
            $state.Outputs[$Name] = $Value
        }.GetNewClosure()

        $settingsPath = Join-Path -Path $TestDrive -ChildPath 'settings.json'
        @{ Name = 'SettingsFixture'; Test = @{ Skip = $true } } |
            ConvertTo-Json -Depth 4 |
            Set-Content -LiteralPath $settingsPath
        foreach ($name in $script:environmentNames) {
            [Environment]::SetEnvironmentVariable($name, $null)
        }
        $env:GITHUB_EVENT_NAME = 'push'
        $env:GITHUB_SHA = 'pushed-sha'
        $env:GITHUB_REF = 'refs/heads/main'
        $env:GITHUB_REF_NAME = 'main'
        $env:GITHUB_REPOSITORY_NAME = 'SettingsFixture'
        $env:GITHUB_REPOSITORY_OWNER = 'PSModule'
        $env:PSMODULE_GET_SETTINGS_INPUT_Debug = 'false'
        $env:PSMODULE_GET_SETTINGS_INPUT_Verbose = 'false'
        $env:PSMODULE_GET_SETTINGS_INPUT_Prerelease = 'false'
        $env:PSMODULE_GET_SETTINGS_INPUT_SettingsPath = $settingsPath
        $env:PSMODULE_GET_SETTINGS_INPUT_WorkingDirectory = $TestDrive
    }

    It 'checks important files before allowing a documentation-only push with an unmatched association' {
        & $script:settingsScriptPath
        $settings = $script:state.Outputs.Settings | ConvertFrom-Json
        $apiCalls = @($script:state.Calls | Where-Object { $_ -like 'GET *' })

        $apiCalls.Count | Should -Be 2
        $apiCalls[0] | Should -Match '/compare/'
        $apiCalls[1] | Should -Match '/commits/pushed-sha/pulls$'
        $settings.HasImportantChanges | Should -BeFalse
        $settings.Publish.Module.ReleaseType | Should -Be 'None'
        $settings.Build.Module.Enabled | Should -BeFalse
    }

    It 'rejects the same unmatched association when the pushed files are important' {
        $script:state.Files = @('src/Module.psm1')

        { & $script:settingsScriptPath } | Should -Throw '*another-merge-sha*cannot be reclaimed*'

        $script:state.Outputs.Count | Should -Be 0
    }

    It 'does not classify <Reference> as a default-branch dispatch' -ForEach @(
        @{ Reference = 'refs/tags/main'; RefName = 'main' }
        @{ Reference = 'refs/heads/Main'; RefName = 'Main' }
    ) {
        $env:GITHUB_EVENT_NAME = 'workflow_dispatch'
        $env:GITHUB_REF = $Reference
        $env:GITHUB_REF_NAME = $RefName
        $script:state.Associated[0].merge_commit_sha = 'pushed-sha'

        & $script:settingsScriptPath
        $settings = $script:state.Outputs.Settings | ConvertFrom-Json

        $settings.Context.IsManualDispatchToDefaultBranch | Should -BeFalse
        $settings.Publish.Module.ReleaseType | Should -Be 'None'
        @($script:state.Calls | Where-Object { $_ -match '/commits/.+/pulls$' }).Count | Should -Be 0
    }

    It 'rejects a dispatch whose commit already has a GitHub release instead of resolving another bump' {
        $env:GITHUB_EVENT_NAME = 'workflow_dispatch'
        $script:state.Associated[0].merge_commit_sha = 'pushed-sha'
        $script:state.Releases = @([pscustomobject]@{
                tag_name = 'v1.1.0'; prerelease = $false; draft = $false; target_commitish = 'main'
            })
        $script:state.TagReferences['v1.1.0'] = [pscustomobject]@{ type = 'commit'; sha = 'pushed-sha' }

        { & $script:settingsScriptPath } | Should -Throw '*already*release*v1.1.0*original*'

        $script:state.Outputs.Count | Should -Be 0
    }

    It 'honors repository-wide module publication skip for an important default-branch push' {
        $script:state.Files = @('src/Module.psm1')
        $script:state.Associated[0].merge_commit_sha = 'pushed-sha'
        @{
            Name = 'SettingsFixture'; Test = @{ Skip = $true }; Publish = @{ Module = @{ Skip = $true } }
        } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $env:PSMODULE_GET_SETTINGS_INPUT_SettingsPath

        & $script:settingsScriptPath
        $settings = $script:state.Outputs.Settings | ConvertFrom-Json

        $settings.HasImportantChanges | Should -BeTrue
        $settings.Publish.Module.Skip | Should -BeTrue
        $settings.Publish.Module.Enabled | Should -BeFalse
    }
}
