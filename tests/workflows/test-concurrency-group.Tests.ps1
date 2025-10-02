BeforeAll {
    $WorkflowPath = Join-Path $PSScriptRoot '../../.github/workflows/workflow.yml'

    if (-not (Test-Path $WorkflowPath)) {
        throw "Workflow file not found at: $WorkflowPath"
    }

    # Parse YAML workflow file
    $WorkflowContent = Get-Content $WorkflowPath -Raw
    $script:WorkflowYaml = $WorkflowContent
}

Describe 'Unified Workflow Concurrency Group Configuration' {

    Context 'Concurrency Configuration Exists' {
        It 'Should have concurrency section defined' {
            $script:WorkflowYaml | Should -Match 'concurrency:'
        }

        It 'Should have group defined' {
            $script:WorkflowYaml | Should -Match 'group:'
        }

        It 'Should have cancel-in-progress defined' {
            $script:WorkflowYaml | Should -Match 'cancel-in-progress:'
        }
    }

    Context 'Concurrency Group Format' {
        It 'Should use workflow and ref in group identifier' {
            # Expected format: ${{ github.workflow }}-${{ github.ref }}
            $script:WorkflowYaml | Should -Match 'group:\s*\$\{\{\s*github\.workflow\s*\}\}-\$\{\{\s*github\.ref\s*\}\}'
        }
    }

    Context 'Cancel-In-Progress Logic' {
        It 'Should have conditional cancel-in-progress based on branch' {
            # Expected: cancel-in-progress is false for main branch, true for others
            # Pattern: ${{ github.ref != format('refs/heads/{0}', github.event.repository.default_branch) }}
            $script:WorkflowYaml | Should -Match 'cancel-in-progress:\s*\$\{\{.*github\.ref.*!=.*format.*refs/heads.*github\.event\.repository\.default_branch.*\}\}'
        }

        It 'Should use github.event.repository.default_branch in condition' {
            $script:WorkflowYaml | Should -Match 'github\.event\.repository\.default_branch'
        }
    }

    Context 'Behavior Verification' {
        It 'Concurrency group should be unique per workflow and ref' {
            # This ensures different PRs don't cancel each other
            $script:WorkflowYaml | Should -Match 'github\.workflow'
            $script:WorkflowYaml | Should -Match 'github\.ref'
        }

        It 'Should allow main branch builds to complete' {
            # Verify the logic: when ref == default_branch, cancel-in-progress should be false
            # The condition should evaluate to false for main, true for PRs
            $script:WorkflowYaml | Should -Match 'github\.ref\s*!=\s*format'
        }
    }
}
