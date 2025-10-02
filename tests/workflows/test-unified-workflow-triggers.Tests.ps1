BeforeAll {
    $WorkflowPath = Join-Path $PSScriptRoot '../../.github/workflows/workflow.yml'

    if (-not (Test-Path $WorkflowPath)) {
        throw "Workflow file not found at: $WorkflowPath"
    }

    # Parse YAML workflow file
    $WorkflowContent = Get-Content $WorkflowPath -Raw

    # Simple YAML parsing for workflow structure
    # Note: This is a basic parser - for production, consider using a YAML module
    $script:WorkflowYaml = $WorkflowContent
}

Describe 'Unified Workflow Trigger Configuration' {

    Context 'Workflow Call Trigger' {
        It 'Should have workflow_call trigger defined' {
            $script:WorkflowYaml | Should -Match 'on:\s*\n\s*workflow_call:'
        }
    }

    Context 'Required Secrets' {
        It 'Should define APIKey secret' {
            $script:WorkflowYaml | Should -Match 'APIKey:\s*\n\s*required:\s*true'
        }

        It 'Should define TEST_APP_ENT_CLIENT_ID secret (optional)' {
            $script:WorkflowYaml | Should -Match 'TEST_APP_ENT_CLIENT_ID:'
        }

        It 'Should define TEST_APP_ENT_PRIVATE_KEY secret (optional)' {
            $script:WorkflowYaml | Should -Match 'TEST_APP_ENT_PRIVATE_KEY:'
        }

        It 'Should define TEST_APP_ORG_CLIENT_ID secret (optional)' {
            $script:WorkflowYaml | Should -Match 'TEST_APP_ORG_CLIENT_ID:'
        }

        It 'Should define TEST_APP_ORG_PRIVATE_KEY secret (optional)' {
            $script:WorkflowYaml | Should -Match 'TEST_APP_ORG_PRIVATE_KEY:'
        }

        It 'Should define TEST_USER_ORG_FG_PAT secret (optional)' {
            $script:WorkflowYaml | Should -Match 'TEST_USER_ORG_FG_PAT:'
        }

        It 'Should define TEST_USER_USER_FG_PAT secret (optional)' {
            $script:WorkflowYaml | Should -Match 'TEST_USER_USER_FG_PAT:'
        }

        It 'Should define TEST_USER_PAT secret (optional)' {
            $script:WorkflowYaml | Should -Match 'TEST_USER_PAT:'
        }
    }

    Context 'Required Inputs' {
        It 'Should define Name input' {
            $script:WorkflowYaml | Should -Match 'Name:\s*\n\s*type:\s*string'
        }

        It 'Should define SettingsPath input with default' {
            $script:WorkflowYaml | Should -Match 'SettingsPath:\s*\n\s*type:\s*string'
            $script:WorkflowYaml | Should -Match 'default:\s*.\.github/PSModule\.yml'
        }

        It 'Should define Debug input' {
            $script:WorkflowYaml | Should -Match 'Debug:\s*\n\s*type:\s*boolean'
        }

        It 'Should define Verbose input' {
            $script:WorkflowYaml | Should -Match 'Verbose:\s*\n\s*type:\s*boolean'
        }

        It 'Should define Version input' {
            $script:WorkflowYaml | Should -Match 'Version:\s*\n\s*type:\s*string'
        }

        It 'Should define Prerelease input' {
            $script:WorkflowYaml | Should -Match 'Prerelease:\s*\n\s*type:\s*boolean'
        }

        It 'Should define WorkingDirectory input' {
            $script:WorkflowYaml | Should -Match 'WorkingDirectory:\s*\n\s*type:\s*string'
        }
    }
}
