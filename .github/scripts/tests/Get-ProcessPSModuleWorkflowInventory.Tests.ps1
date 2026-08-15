[CmdletBinding()]
param()

BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '../Get-ProcessPSModuleWorkflowInventory.ps1'
    $testRoot = Join-Path ([IO.Path]::GetTempPath()) "process-workflow-inventory-$([guid]::NewGuid())"
    $repositoryRoot = Join-Path $testRoot 'Example'
    $workflowRoot = Join-Path $repositoryRoot '.github/workflows'
    & git init --quiet --initial-branch=main $repositoryRoot
    & git -C $repositoryRoot config user.email 'inventory-tests@example.invalid'
    & git -C $repositoryRoot config user.name 'Inventory Tests'
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
    if: ${{ github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name == github.repository }}
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

    & git -C $repositoryRoot add .
    & git -C $repositoryRoot commit --quiet -m 'Add test workflows'
    & git -C $repositoryRoot update-ref refs/remotes/origin/main HEAD
    & git -C $repositoryRoot symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
    & git -C $repositoryRoot switch --quiet -c feature
    $featureContent = Get-Content -LiteralPath (Join-Path $workflowRoot 'Process-PSModule.yml') -Raw
    $featureContent.Replace(
        '0123456789012345678901234567890123456789',
        'ffffffffffffffffffffffffffffffffffffffff'
    ) |
        Set-Content -LiteralPath (Join-Path $workflowRoot 'Process-PSModule.yml')
}

AfterAll {
    if (Test-Path -LiteralPath $testRoot) {
        Get-ChildItem -LiteralPath $testRoot -Recurse -Force |
            ForEach-Object { $_.Attributes = [IO.FileAttributes]::Normal }
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}

Describe 'Get-ProcessPSModuleWorkflowInventory' {
    It 'inventories matching local workflows and their compatibility dimensions' {
        $result = @(
            & $scriptPath `
                -Path $testRoot `
                -TargetReference '0123456789012345678901234567890123456789'
        )

        $result.Count | Should -Be 1
        $result[0].Repository | Should -Be 'Example'
        $result[0].WorkflowName | Should -Be 'Process-PSModule'
        $result[0].Events | Should -Be @('pull_request', 'push', 'schedule', 'workflow_dispatch')
        $result[0].PushBranches | Should -Be @('main')
        $result[0].PullRequestTypes | Should -Be @('opened', 'synchronize')
        $result[0].ConcurrencyGroup | Should -Be '${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}'
        $result[0].CancelInProgress | Should -BeFalse
        $result[0].ProcessJobs[0].Reference | Should -Be '0123456789012345678901234567890123456789'
        $result[0].ProcessJobs[0].MatchesTarget | Should -BeTrue
        $result[0].MatchesTarget | Should -BeTrue
        $result[0].ProcessJobs[0].Condition | Should -Match 'head.repo.full_name'
        $result[0].ProcessJobs[0].Inputs.Keys | Should -Contain 'Debug'
        $result[0].ProcessJobs[0].SecretMappings.Keys | Should -Be @(
            'PSGALLERY_API_KEY'
            'GitHubAppClientId'
            'GitHubAppPrivateKey'
        )
    }

    It 'reads the remote default branch instead of feature-worktree changes' {
        $result = @(& $scriptPath -Path $repositoryRoot)

        $result[0].DefaultBranch | Should -Be 'main'
        $result[0].ProcessJobs[0].Reference | Should -Be '0123456789012345678901234567890123456789'
    }

    It 'writes JSON and Markdown refresh artifacts' {
        $jsonPath = Join-Path $testRoot 'inventory.json'
        $markdownPath = Join-Path $testRoot 'inventory.md'

        & $scriptPath `
            -Path $repositoryRoot `
            -TargetReference '0123456789012345678901234567890123456789' `
            -JsonPath $jsonPath `
            -MarkdownPath $markdownPath |
            Out-Null

        Test-Path -LiteralPath $jsonPath | Should -BeTrue
        Test-Path -LiteralPath $markdownPath | Should -BeTrue
        (Get-Content -LiteralPath $jsonPath -Raw).TrimStart() | Should -Match '^\['
        Get-Content -LiteralPath $markdownPath -Raw | Should -Match 'Example'
        Get-Content -LiteralPath $markdownPath -Raw | Should -Match '0123456789012345678901234567890123456789'
        Get-Content -LiteralPath $markdownPath -Raw | Should -Match 'Matching target: 1/1'
    }

    It 'records a parse error for a matching malformed workflow' {
        $malformedRoot = Join-Path $testRoot 'Malformed'
        $malformedWorkflowRoot = Join-Path $malformedRoot '.github/workflows'
        & git init --quiet --initial-branch=main $malformedRoot
        & git -C $malformedRoot config user.email 'inventory-tests@example.invalid'
        & git -C $malformedRoot config user.name 'Inventory Tests'
        New-Item -ItemType Directory -Path $malformedWorkflowRoot -Force | Out-Null
        @'
name: Broken
jobs:
  Process:
    uses: PSModule/Process-PSModule/.github/workflows/workflow.yml@v8
  invalid: [
'@ | Set-Content -LiteralPath (Join-Path $malformedWorkflowRoot 'Process.yml')
        & git -C $malformedRoot add .
        & git -C $malformedRoot commit --quiet -m 'Add malformed workflow'

        $result = @(& $scriptPath -Path $malformedRoot)

        $result.Count | Should -Be 1
        $result[0].Status | Should -Be 'ParseError'
        $result[0].Error | Should -Not -BeNullOrEmpty
    }

    It 'fails closed when no matching workflow is found' {
        $emptyRoot = Join-Path $testRoot 'Empty'
        & git init --quiet --initial-branch=main $emptyRoot
        & git -C $emptyRoot config user.email 'inventory-tests@example.invalid'
        & git -C $emptyRoot config user.name 'Inventory Tests'
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
        & git -C $emptyRoot add .
        & git -C $emptyRoot commit --quiet -m 'Add unrelated workflow'

        { & $scriptPath -Path $emptyRoot } |
            Should -Throw 'No reusable workflow jobs using*'
    }

    It 'normalizes shorthand trigger lists' {
        $shorthandRoot = Join-Path $testRoot 'Shorthand'
        $shorthandWorkflowRoot = Join-Path $shorthandRoot '.github/workflows'
        & git init --quiet --initial-branch=main $shorthandRoot
        & git -C $shorthandRoot config user.email 'inventory-tests@example.invalid'
        & git -C $shorthandRoot config user.name 'Inventory Tests'
        New-Item -ItemType Directory -Path $shorthandWorkflowRoot -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $shorthandWorkflowRoot 'Process.yml') -Value @'
name: Shorthand
on: [push, workflow_dispatch]
permissions: read-all
concurrency: process-${{ github.ref }}
jobs:
  Process:
    uses: PSModule/Process-PSModule/.github/workflows/workflow.yml@v8
'@
        & git -C $shorthandRoot add .
        & git -C $shorthandRoot commit --quiet -m 'Add shorthand workflow'

        $result = @(& $scriptPath -Path $shorthandRoot)

        $result[0].Events | Should -Be @('push', 'workflow_dispatch')
        $result[0].Permissions | Should -Be 'read-all'
        $result[0].ConcurrencyGroup | Should -Be 'process-${{ github.ref }}'
        $result[0].CancelInProgress | Should -BeNullOrEmpty
    }
}
