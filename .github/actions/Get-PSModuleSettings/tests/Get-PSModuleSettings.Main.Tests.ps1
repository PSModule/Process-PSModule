[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Variables are assigned in BeforeAll and used inside It blocks.'
)]
[CmdletBinding()]
param()

BeforeAll {
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
    foreach ($name in $script:environmentNames) {
        [Environment]::SetEnvironmentVariable($name, $script:originalEnvironment[$name])
    }
    foreach ($name in @('Install-PSResource', 'Get-GitHubEventData', 'Invoke-GitHubAPI', 'Set-GitHubOutput')) {
        Remove-Item -Path "Function:\$name" -ErrorAction SilentlyContinue
    }
    Import-Module -Name PSModule -Force
}

Describe 'Get-PSModuleSettings release-bearing push detection' {
    BeforeEach {
        $script:state = @{
            Files          = @('docs/guide.md')
            Calls          = [System.Collections.Generic.List[string]]::new()
            InstalledNames = [System.Collections.Generic.List[string]]::new()
            Outputs        = @{}
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
}
