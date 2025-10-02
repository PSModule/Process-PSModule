BeforeAll {
    # This test verifies the unified workflow concurrency behavior for PR updates
    # Scenario: PR updated → tests re-execute, previous run cancelled

    $WorkflowPath = Join-Path $PSScriptRoot '../../.github/workflows/workflow.yml'

    if (-not (Test-Path $WorkflowPath)) {
        throw "Workflow file not found at: $WorkflowPath"
    }

    $script:WorkflowYaml = Get-Content $WorkflowPath -Raw
}

Describe 'PR Update with Concurrency Scenario' {

    Context 'Concurrency Configuration' {
        It 'Should have concurrency group defined' {
            $script:WorkflowYaml | Should -Match 'concurrency:'
            $script:WorkflowYaml | Should -Match 'group:'
        }

        It 'Should include workflow and ref in concurrency group' {
            # Group should be unique per workflow and branch/PR
            $script:WorkflowYaml | Should -Match 'github\.workflow'
            $script:WorkflowYaml | Should -Match 'github\.ref'
        }

        It 'Should have cancel-in-progress configured' {
            $script:WorkflowYaml | Should -Match 'cancel-in-progress:'
        }
    }

    Context 'Cancel-In-Progress Logic for PR Context' {
        It 'Should cancel previous runs when not on default branch' {
            # For PR branches, cancel-in-progress should be true
            # Expected pattern: github.ref != format('refs/heads/{0}', github.event.repository.default_branch)
            $script:WorkflowYaml | Should -Match 'cancel-in-progress:.*github\.ref.*!=.*default_branch'
        }

        It 'Should use conditional logic for cancel-in-progress' {
            # The cancel-in-progress should evaluate differently for PR vs main
            $script:WorkflowYaml | Should -Match '\$\{\{.*github\.ref.*\}\}'
        }

        It 'Should allow main branch builds to complete' {
            # When ref == default_branch, the condition should evaluate to false
            # This ensures main branch builds complete
            $script:WorkflowYaml | Should -Match 'github\.event\.repository\.default_branch'
        }
    }

    Context 'Workflow Re-Execution Behavior' {
        It 'Should allow tests to re-run on PR synchronize' {
            # Test jobs should not be blocked from re-running
            $script:WorkflowYaml | Should -Match 'Test-Module:'
            $script:WorkflowYaml | Should -Match 'Test-ModuleLocal:'
        }

        It 'Should maintain publishing conditional on re-run' {
            # Even on re-run, publishing should only happen on merge
            $script:WorkflowYaml | Should -Match 'Publish-Module:'
            $script:WorkflowYaml | Should -Match 'merged'
        }
    }

    Context 'Concurrency Group Uniqueness' {
        It 'Should create unique groups per PR' {
            # Different PRs (different refs) should have different concurrency groups
            # Pattern: workflow name + ref ensures this
            $script:WorkflowYaml | Should -Match 'group:.*github\.workflow.*github\.ref'
        }

        It 'Should not cancel builds from different PRs' {
            # Because group includes github.ref, different PRs have different groups
            # This test verifies the pattern exists
            $script:WorkflowYaml | Should -Match 'github\.ref'
        }
    }

    Context 'Expected Behavior Documentation' {
        It 'Should match quickstart scenario 2 requirements' {
            # Quickstart scenario 2: PR updated → tests re-execute, previous run cancelled

            # 1. Concurrency group should exist
            $script:WorkflowYaml | Should -Match 'concurrency:'

            # 2. Cancel-in-progress should be configured
            $script:WorkflowYaml | Should -Match 'cancel-in-progress:'

            # 3. Tests should still execute
            $script:WorkflowYaml | Should -Match 'Test-Module:'

            # 4. Publishing should remain conditional
            $script:WorkflowYaml | Should -Match 'Publish-Module:'
        }
    }
}
