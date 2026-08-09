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
        'GITHUB_ENV'
        'GITHUB_EVENT_PATH'
        'GITHUB_REPOSITORY'
        'GITHUB_WORKSPACE'
        'PSMODULE_RELEASE_PSMODULE_INPUT_Name'
        'PSMODULE_RELEASE_PSMODULE_INPUT_ModulePath'
        'PSMODULE_RELEASE_PSMODULE_INPUT_WhatIf'
        'PSMODULE_RELEASE_PSMODULE_INPUT_UsePRBodyAsReleaseNotes'
        'PSMODULE_RELEASE_PSMODULE_INPUT_UsePRTitleAsReleaseName'
        'PSMODULE_RELEASE_PSMODULE_INPUT_UsePRTitleAsNotesHeading'
        'PSMODULE_RELEASE_PSMODULE_INPUT_ReleaseTag'
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
    It 'creates a prefixed prerelease tag without GitHub side effects' {
        $moduleName = 'TestModule'
        $workspacePath = Join-Path -Path $TestDrive -ChildPath 'workspace'
        $modulePath = Join-Path -Path $workspacePath -ChildPath "outputs/module/$moduleName"
        $manifestPath = Join-Path -Path $modulePath -ChildPath "$moduleName.psd1"
        $eventPath = Join-Path -Path $TestDrive -ChildPath 'event.json'
        $githubEnvironmentPath = Join-Path -Path $TestDrive -ChildPath 'github-environment'

        New-Item -Path $modulePath -ItemType Directory -Force | Out-Null
        Set-Content -Path (Join-Path -Path $modulePath -ChildPath "$moduleName.psm1") -Value ''
        Set-Content -Path $manifestPath -Value @"
@{
    RootModule = '$moduleName.psm1'
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

        $env:GITHUB_ENV = $githubEnvironmentPath
        $env:GITHUB_EVENT_PATH = $eventPath
        $env:GITHUB_REPOSITORY = "PSModule/$moduleName"
        $env:GITHUB_WORKSPACE = $workspacePath
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_Name = $moduleName
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_ModulePath = 'outputs/module'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_WhatIf = 'true'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_UsePRBodyAsReleaseNotes = 'true'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_UsePRTitleAsReleaseName = 'false'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_UsePRTitleAsNotesHeading = 'true'
        $env:PSMODULE_RELEASE_PSMODULE_INPUT_ReleaseTag = 'v1.2.3-preview.1'

        { & $script:releaseScriptPath } | Should -Not -Throw

        Get-Content -Path $githubEnvironmentPath | Should -Contain 'PSMODULE_RELEASE_PSMODULE_CONTEXT_ReleaseTag=v1.2.3-preview.1'
    }
}
