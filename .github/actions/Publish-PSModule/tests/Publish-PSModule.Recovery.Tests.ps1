[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Variables are assigned in BeforeAll and used inside It blocks.'
)]
[CmdletBinding()]
param()

BeforeAll {
    Import-Module -Name 'PSModule' -Force

    $script:publishScriptPath = Join-Path -Path $PSScriptRoot -ChildPath '../src/publish.ps1'
    $script:environmentVariableNames = @(
        'GITHUB_EVENT_PATH'
        'GITHUB_REPOSITORY'
        'GITHUB_WORKSPACE'
        'PSMODULE_PUBLISH_PSMODULE_INPUT_Name'
        'PSMODULE_PUBLISH_PSMODULE_INPUT_ModulePath'
        'PSMODULE_PUBLISH_PSMODULE_INPUT_PSGALLERY_API_KEY'
        'PSMODULE_PUBLISH_PSMODULE_INPUT_PullRequest'
        'PSMODULE_PUBLISH_PSMODULE_INPUT_WhatIf'
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
    # Otherwise the shims leak into the global scope and shadow the real cmdlets in later test files.
    Remove-Item -Path 'Function:\Find-PSResource' -ErrorAction SilentlyContinue
    Remove-Item -Path 'Function:\Publish-PSResource' -ErrorAction SilentlyContinue
    Remove-Item -Path 'Function:\Resolve-PSModuleDependency' -ErrorAction SilentlyContinue
}

Describe 'Publish-PSModule recovery' {
    BeforeEach {
        $script:moduleName = 'TestModule'
        $script:workspacePath = Join-Path -Path $TestDrive -ChildPath 'workspace'
        $script:modulePath = Join-Path -Path $script:workspacePath -ChildPath "outputs/module/$script:moduleName"
        $manifestPath = Join-Path -Path $script:modulePath -ChildPath "$script:moduleName.psd1"
        $eventPath = Join-Path -Path $TestDrive -ChildPath 'event.json'
        $null = New-Item -Path $script:modulePath -ItemType Directory -Force
        Set-Content -Path (Join-Path -Path $script:modulePath -ChildPath "$script:moduleName.psm1") -Value ''
        Set-Content -Path $manifestPath -Value @"
@{
    RootModule = '$script:moduleName.psm1'
    ModuleVersion = '1.2.4'
    GUID = '3c0f8d73-60b7-4f38-b3cf-9386db4982a4'
    Author = 'PSModule'
    Description = 'Test module'
    PowerShellVersion = '5.1'
    PrivateData = @{
        PSData = @{
            Prerelease = ''
        }
    }
}
"@
        @{} | ConvertTo-Json | Set-Content -Path $eventPath

        $env:GITHUB_EVENT_PATH = $eventPath
        $env:GITHUB_REPOSITORY = "PSModule/$script:moduleName"
        $env:GITHUB_WORKSPACE = $script:workspacePath
        $env:PSMODULE_PUBLISH_PSMODULE_INPUT_Name = $script:moduleName
        $env:PSMODULE_PUBLISH_PSMODULE_INPUT_ModulePath = 'outputs/module'
        $env:PSMODULE_PUBLISH_PSMODULE_INPUT_PSGALLERY_API_KEY = 'test-key'
        $env:PSMODULE_PUBLISH_PSMODULE_INPUT_PullRequest = ''
        $env:PSMODULE_PUBLISH_PSMODULE_INPUT_WhatIf = 'false'
        $script:publishInvoked = $false

        Set-Item -Path function:global:Resolve-PSModuleDependency -Value {}
        Set-Item -Path function:global:Find-PSResource -Value {
            [PSCustomObject]@{ Name = 'TestModule'; Version = '1.2.4' }
        }
        Set-Item -Path function:global:Publish-PSResource -Value {
            $script:publishInvoked = $true
        }
    }

    It 'skips Gallery publication when the resolved version already exists' {
        { & $script:publishScriptPath } | Should -Not -Throw

        $script:publishInvoked | Should -BeFalse
    }

    It 'publishes when the resolved version is not in the Gallery' {
        $publishMarkerPath = Join-Path -Path $script:workspacePath -ChildPath 'publish-invoked'
        Set-Item -Path function:global:Find-PSResource -Value {
            [CmdletBinding()]
            param(
                [string] $Name,
                [string] $Version,
                [string] $Repository
            )

            Write-Error "Package with name '$Name', version '$Version' could not be found in repository '$Repository'."
        }
        Set-Item -Path function:global:Publish-PSResource -Value {
            $null = New-Item -Path (Join-Path -Path $env:GITHUB_WORKSPACE -ChildPath 'publish-invoked') -ItemType File -Force
        }

        { & $script:publishScriptPath } | Should -Not -Throw

        (Test-Path -Path $publishMarkerPath) | Should -BeTrue
    }
}
