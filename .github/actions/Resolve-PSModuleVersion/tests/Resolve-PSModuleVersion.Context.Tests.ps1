[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Pester setup state is used by test blocks.'
)]
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

BeforeAll {
    $script:environmentMutex = [Threading.Mutex]::new($false, "PSModule-ActionTests-Environment-$PID")
    if (-not $script:environmentMutex.WaitOne([TimeSpan]::FromMinutes(5))) {
        throw 'Cannot acquire the action-test environment lock.'
    }
    Import-Module PSModule -Force
    Import-Module -Name ([IO.Path]::Combine(
            $PSScriptRoot, '..', 'src', 'Resolve-PSModuleVersion.Helpers.psm1'
        )) -Force
    $script:eventInput = [Environment]::GetEnvironmentVariable('PSMODULE_RESOLVE_PSMODULEVERSION_INPUT_EventJson')
}

AfterAll {
    try {
        [Environment]::SetEnvironmentVariable('PSMODULE_RESOLVE_PSMODULEVERSION_INPUT_EventJson', $script:eventInput)
    } finally {
        $script:environmentMutex.ReleaseMutex()
        $script:environmentMutex.Dispose()
    }
}

Describe 'Producing context is validated before resolver projection' {
    It 'retains the actual PR number in the supported event fallback' {
        $env:PSMODULE_RESOLVE_PSMODULEVERSION_INPUT_EventJson = @'
{"pull_request":{"number":42,"head":{"ref":"fixture"},"labels":[{"name":"patch"}]}}
'@

        $result = Get-GitHubPullRequest -SettingsJson '{}'

        $result.Number | Should -Be 42
        $result.HeadRef | Should -BeExactly 'fixture'
        $result.Labels | Should -Be @('patch')
    }

    It 'rejects raw normalized malformed PR context before creating a direct identity' -ForEach @(
        @{ Raw = '{}' }
        @{ Raw = '[]' }
        @{ Raw = '[null]' }
        @{ Raw = '[{"Number":42}]' }
        @{ Raw = '{"Number":0}' }
    ) {
        $settings = '{"Context":{"IsPushToDefaultBranch":true,"DefaultBranch":"main","PullRequest":' + $Raw + '}}'

        { Get-GitHubPullRequest -SettingsJson $settings } | Should -Throw '*pull request*'
    }

    It 'rejects an event PR array before projecting its Number' {
        $env:PSMODULE_RESOLVE_PSMODULEVERSION_INPUT_EventJson = '{"pull_request":[{"number":42}]}'

        { Get-GitHubPullRequest -SettingsJson '{}' } | Should -Throw '*pull request*'
    }

    It 'retains genuinely absent context for supported direct releases' {
        $settings = '{"Context":{"IsPushToDefaultBranch":true,"DefaultBranch":"main","PullRequest":null}}'

        $result = Get-GitHubPullRequest -SettingsJson $settings

        $result.IsDirectRelease | Should -BeTrue
        $result.Number | Should -BeNullOrEmpty
    }
}
