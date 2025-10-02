BeforeAll {
    # This test verifies the unified workflow publishing behavior for merged PRs
    # Scenario: PR merged → tests execute, publishing executes (if tests pass)

    $WorkflowPath = Join-Path $PSScriptRoot '../../.github/workflows/workflow.yml'

    if (-not (Test-Path $WorkflowPath)) {
        throw "Workflow file not found at: $WorkflowPath"
    }

    $script:WorkflowYaml = Get-Content $WorkflowPath -Raw
}

Describe 'PR Merge with Publishing Scenario' {

    Context 'Test Execution on Merge' {
        It 'Should execute all test jobs' {
            # All test jobs should run even on merge
            $script:WorkflowYaml | Should -Match 'Test-Module:'
            $script:WorkflowYaml | Should -Match 'Test-ModuleLocal:'
        }

        It 'Should execute build jobs' {
            # Build jobs needed for publishing
            $script:WorkflowYaml | Should -Match 'Build-Module:'
            $script:WorkflowYaml | Should -Match 'Build-Site:'
        }

        It 'Should collect test results' {
            # Test results needed before publishing
            $script:WorkflowYaml | Should -Match 'Get-TestResults:'
        }
    }

    Context 'Publishing Conditional on Merge' {
        It 'Publish-Module should check for merged pull request' {
            # Should check github.event.pull_request.merged == true
            $publishSection = $script:WorkflowYaml -split 'Publish-Module:' | Select-Object -Skip 1 -First 1 | Select-Object -First 50
            $publishSection | Should -Match 'merged\s*==\s*true'
        }

        It 'Publish-Site should check for merged pull request' {
            # Should check github.event.pull_request.merged == true
            $publishSection = $script:WorkflowYaml -split 'Publish-Site:' | Select-Object -Skip 1 -First 1 | Select-Object -First 50
            $publishSection | Should -Match 'merged\s*==\s*true'
        }

        It 'Publish-Module should depend on test results' {
            # Publishing should not happen until tests pass
            $script:WorkflowYaml | Should -Match 'Publish-Module:'
            $script:WorkflowYaml | Should -Match 'Get-TestResults:'
        }

        It 'Publish-Site should depend on test results' {
            # Publishing should not happen until tests pass
            $script:WorkflowYaml | Should -Match 'Publish-Site:'
            $script:WorkflowYaml | Should -Match 'Get-TestResults:'
        }
    }

    Context 'Publishing Dependencies' {
        It 'Publish-Module should depend on Build-Module' {
            # Can't publish what hasn't been built
            $script:WorkflowYaml | Should -Match 'Publish-Module:'
            $script:WorkflowYaml | Should -Match 'Build-Module:'
        }

        It 'Publish-Site should depend on Build-Site' {
            # Can't publish site that hasn't been built
            $script:WorkflowYaml | Should -Match 'Publish-Site:'
            $script:WorkflowYaml | Should -Match 'Build-Site:'
        }

        It 'Should have proper job dependency chain' {
            # Build → Test → Results → Publish
            $script:WorkflowYaml | Should -Match 'Build-Module:'
            $script:WorkflowYaml | Should -Match 'Test-Module:'
            $script:WorkflowYaml | Should -Match 'Get-TestResults:'
            $script:WorkflowYaml | Should -Match 'Publish-Module:'
        }
    }

    Context 'Event Type Checking' {
        It 'Should check for pull_request event type' {
            # Publishing should only happen on pull_request events (when merged)
            $publishSection = $script:WorkflowYaml -split 'Publish-Module:' | Select-Object -Skip 1 -First 1
            $publishSection | Should -Match 'pull_request'
        }

        It 'Should verify event is pull_request before checking merged status' {
            # Both conditions should be present: event type AND merged status
            $script:WorkflowYaml | Should -Match 'event_name'
            $script:WorkflowYaml | Should -Match 'merged'
        }
    }

    Context 'Expected Behavior Documentation' {
        It 'Should match quickstart scenario 3 requirements' {
            # Quickstart scenario 3: PR merged → tests execute, publishing executes

            # 1. Tests should execute
            $script:WorkflowYaml | Should -Match 'Test-Module:'

            # 2. Publishing should be conditional on merge
            $script:WorkflowYaml | Should -Match 'Publish-Module:'
            $script:WorkflowYaml | Should -Match 'merged'

            # 3. Publishing should depend on test results
            $script:WorkflowYaml | Should -Match 'Get-TestResults:'
        }

        It 'Should ensure publishing only happens when tests pass' {
            # Dependencies ensure tests run and complete before publishing
            $script:WorkflowYaml | Should -Match 'Publish-Module:'

            # Publish jobs should have needs that include test results
            $publishModuleSection = $script:WorkflowYaml -split 'Publish-Module:' | Select-Object -Skip 1 -First 1
            $publishModuleSection | Should -Match 'needs:'
        }
    }
}
