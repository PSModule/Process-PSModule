[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
$helpersManifestPath = Join-Path -Path $repoRoot -ChildPath 'src/Helpers/Helpers.psd1'
$testRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "Import-TestData-$([guid]::NewGuid())"

$assert = {
    param(
        [bool] $Condition,
        [string] $Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

$assertThrows = {
    param(
        [scriptblock] $ScriptBlock,
        [string] $Pattern,
        [string] $Message
    )

    $threw = $false
    try {
        & $ScriptBlock 6> $null
    } catch {
        $threw = $_.Exception.Message -like $Pattern
    }
    if (-not $threw) {
        throw $Message
    }
}

$originalTestData = $env:PSMODULE_TEST_DATA
$originalGitHubEnv = $env:GITHUB_ENV

try {
    New-Item -Path $testRoot -ItemType Directory -Force | Out-Null

    Remove-Module -Name Helpers -Force -ErrorAction SilentlyContinue
    Import-Module -Name $helpersManifestPath -Force

    $githubEnvPath = Join-Path -Path $testRoot -ChildPath 'github_env'

    # Secrets and variables are written to GITHUB_ENV, and nothing leaks to the success/pipeline stream.
    Set-Content -Path $githubEnvPath -Value '' -NoNewline -Encoding utf8
    $env:GITHUB_ENV = $githubEnvPath
    $env:PSMODULE_TEST_DATA = '{"secrets":{"MY_SECRET":"not-a-real-secret"},"variables":{"MY_VARIABLE":"plain-text-value"}}'

    $pipelineOutput = Import-TestData 3> $null 4> $null 5> $null 6> $null

    & $assert ($null -eq $pipelineOutput) 'Import-TestData must not write workflow commands or status messages to the success/pipeline output stream.'

    $envContent = Get-Content -Path $githubEnvPath -Raw
    & $assert ($envContent -match 'MY_SECRET<<') 'Expected the secret to be written to GITHUB_ENV using heredoc syntax.'
    & $assert ($envContent -like '*not-a-real-secret*') 'Expected the secret value to be written to GITHUB_ENV.'
    & $assert ($envContent -match 'MY_VARIABLE<<') 'Expected the variable to be written to GITHUB_ENV using heredoc syntax.'
    & $assert ($envContent -like '*plain-text-value*') 'Expected the variable value to be written to GITHUB_ENV.'

    # The mask command is emitted on the information stream (never the success stream).
    Set-Content -Path $githubEnvPath -Value '' -NoNewline -Encoding utf8
    $env:PSMODULE_TEST_DATA = '{"secrets":{"MY_SECRET":"not-a-real-secret"}}'
    $information = Import-TestData 6>&1 | Out-String
    & $assert ($information -match '::add-mask::not-a-real-secret') 'Expected the secret to be masked via ::add-mask:: on the information stream.'

    # A no-op when no test data is provided; nothing on the success/pipeline stream.
    $env:PSMODULE_TEST_DATA = ''
    $noopOutput = Import-TestData 3> $null 4> $null 5> $null 6> $null
    & $assert ($null -eq $noopOutput) 'The no-op path must not emit anything to the success/pipeline output stream.'

    # Representative validation failure paths.
    $env:GITHUB_ENV = $githubEnvPath

    $env:PSMODULE_TEST_DATA = 'not-json'
    & $assertThrows { Import-TestData } '*valid JSON*' 'Expected invalid JSON to be rejected.'

    $env:PSMODULE_TEST_DATA = '{"unexpected":{"A":"1"}}'
    & $assertThrows { Import-TestData } "*only supports 'secrets' and 'variables'*" 'Expected unknown top-level keys to be rejected.'

    $env:PSMODULE_TEST_DATA = '{"variables":{"1INVALID":"x"}}'
    & $assertThrows { Import-TestData } '*valid environment variable names*' 'Expected invalid env var names to be rejected.'

    $env:PSMODULE_TEST_DATA = '{"variables":{"GITHUB_TOKEN":"x"}}'
    & $assertThrows { Import-TestData } '*reserved environment variables*' 'Expected reserved env var names to be rejected.'

    $env:PSMODULE_TEST_DATA = '{"secrets":{"DUP":"a"},"variables":{"DUP":"b"}}'
    & $assertThrows { Import-TestData } '*duplicated across secrets and variables*' 'Expected duplicate keys to be rejected.'

    # A non-scalar value is rejected, and the error names the section ('secrets'), not the entry key.
    # Regression guard for the case-insensitive $name/$Name clobber in Add-EnvFromMap.
    $env:PSMODULE_TEST_DATA = '{"secrets":{"MY_SECRET":[1,2]}}'
    & $assertThrows { Import-TestData } '*TestData.secrets*scalar*' 'Non-scalar value must be rejected naming the section.'

    # A failed write to GITHUB_ENV is terminating even when the caller's ErrorActionPreference is Continue.
    $env:PSMODULE_TEST_DATA = '{"variables":{"MY_VARIABLE":"plain-text-value"}}'
    $env:GITHUB_ENV = Join-Path -Path $testRoot -ChildPath 'missing-dir/github_env'
    $previousEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $assertThrows { Import-TestData } '*missing-dir*' 'Expected an unwritable GITHUB_ENV path to raise a terminating error.'
    } finally {
        $ErrorActionPreference = $previousEap
    }

    # Missing GITHUB_ENV fails fast with a clear message instead of a generic parameter-binding error.
    $env:PSMODULE_TEST_DATA = '{"variables":{"MY_VARIABLE":"plain-text-value"}}'
    $env:GITHUB_ENV = ''
    $clearError = $false
    try {
        Import-TestData 6> $null
    } catch {
        $clearError = $_.Exception.Message -like '*GITHUB_ENV*'
    }
    & $assert $clearError 'Expected a clear error mentioning GITHUB_ENV when the environment file is not available.'
} finally {
    $env:PSMODULE_TEST_DATA = $originalTestData
    $env:GITHUB_ENV = $originalGitHubEnv
    Remove-Module -Name Helpers -Force -ErrorAction SilentlyContinue
    if (Test-Path -Path $testRoot) {
        Remove-Item -Path $testRoot -Recurse -Force
    }
}
