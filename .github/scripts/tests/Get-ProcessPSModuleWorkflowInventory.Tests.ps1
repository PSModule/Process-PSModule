[CmdletBinding()]
param()

BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '../Get-ProcessPSModuleWorkflowInventory.ps1'
    $testRoot = Join-Path $TestDrive 'repositories'
    $repositoryRoot = Join-Path $testRoot 'Example'
    $workflowRoot = Join-Path $repositoryRoot '.github/workflows'
    New-Item -ItemType Directory -Path (Join-Path $repositoryRoot '.git') -Force | Out-Null
    New-Item -ItemType Directory -Path $workflowRoot -Force | Out-Null

    @'
name: Process-PSModule

on:
  workflow_dispatch:
  schedule:
    - cron: '0 0 * * *'
  push:
    branches:
      - main
  pull_request:
    branches:
      - main
    types:
      - opened
      - synchronize

concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: false

permissions:
  contents: write
  pull-requests: write

jobs:
  Process-PSModule:
    uses: PSModule/Process-PSModule/.github/workflows/workflow.yml@0123456789012345678901234567890123456789 # v8.0.0
    with:
      Debug: true
    secrets:
      PSGALLERY_API_KEY: ${{ secrets.PSGALLERY_API_KEY }}
      GitHubAppClientId: ${{ secrets.SHELLY_CLIENT_ID }}
      GitHubAppPrivateKey: ${{ secrets.SHELLY_PRIVATE_KEY }}
'@ | Set-Content -LiteralPath (Join-Path $workflowRoot 'Process-PSModule.yml')

    @'
name: Unrelated
on:
  workflow_dispatch:
jobs:
  Test:
    runs-on: ubuntu-latest
    steps:
      - run: echo test
'@ | Set-Content -LiteralPath (Join-Path $workflowRoot 'Unrelated.yml')
}

Describe 'Get-ProcessPSModuleWorkflowInventory' {
    It 'inventories matching local workflows and their compatibility dimensions' {
        $result = @(& $scriptPath -Path $testRoot)

        $result.Count | Should -Be 1
        $result[0].Repository | Should -Be 'Example'
        $result[0].WorkflowName | Should -Be 'Process-PSModule'
        $result[0].Events | Should -Be @('pull_request', 'push', 'schedule', 'workflow_dispatch')
        $result[0].PushBranches | Should -Be @('main')
        $result[0].PullRequestTypes | Should -Be @('opened', 'synchronize')
        $result[0].ConcurrencyGroup | Should -Be '${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}'
        $result[0].CancelInProgress | Should -BeFalse
        $result[0].ProcessJobs[0].Reference | Should -Be '0123456789012345678901234567890123456789'
        $result[0].ProcessJobs[0].Inputs.Keys | Should -Contain 'Debug'
        $result[0].ProcessJobs[0].SecretMappings.Keys | Should -Be @(
            'PSGALLERY_API_KEY'
            'GitHubAppClientId'
            'GitHubAppPrivateKey'
        )
    }

    It 'writes JSON and Markdown refresh artifacts' {
        $jsonPath = Join-Path $TestDrive 'inventory.json'
        $markdownPath = Join-Path $TestDrive 'inventory.md'

        & $scriptPath -Path $repositoryRoot -JsonPath $jsonPath -MarkdownPath $markdownPath | Out-Null

        Test-Path -LiteralPath $jsonPath | Should -BeTrue
        Test-Path -LiteralPath $markdownPath | Should -BeTrue
        Get-Content -LiteralPath $markdownPath -Raw | Should -Match 'Example'
        Get-Content -LiteralPath $markdownPath -Raw | Should -Match '0123456789012345678901234567890123456789'
    }

    It 'records a parse error for a matching malformed workflow' {
        $malformedRoot = Join-Path $testRoot 'Malformed'
        $malformedWorkflowRoot = Join-Path $malformedRoot '.github/workflows'
        New-Item -ItemType Directory -Path (Join-Path $malformedRoot '.git') -Force | Out-Null
        New-Item -ItemType Directory -Path $malformedWorkflowRoot -Force | Out-Null
        @'
name: Broken
jobs:
  Process:
    uses: PSModule/Process-PSModule/.github/workflows/workflow.yml@v8
  invalid: [
'@ | Set-Content -LiteralPath (Join-Path $malformedWorkflowRoot 'Process.yml')

        $result = @(& $scriptPath -Path $malformedRoot)

        $result.Count | Should -Be 1
        $result[0].Status | Should -Be 'ParseError'
        $result[0].Error | Should -Not -BeNullOrEmpty
    }

    It 'fails closed when no matching workflow is found' {
        $emptyRoot = Join-Path $testRoot 'Empty'
        New-Item -ItemType Directory -Path (Join-Path $emptyRoot '.git') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $emptyRoot '.github/workflows') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $emptyRoot '.github/workflows/Unrelated.yml') -Value @'
name: Unrelated
on:
  workflow_dispatch:
jobs:
  Test:
    runs-on: ubuntu-latest
    steps:
      - run: echo test
'@

        { & $scriptPath -Path $emptyRoot } |
            Should -Throw 'No reusable workflow jobs using*'
    }
}
