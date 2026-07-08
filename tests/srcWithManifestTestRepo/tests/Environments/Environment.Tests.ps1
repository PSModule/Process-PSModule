Describe 'Environment Variables are available' {
    It 'Should be available [<_>]' -ForEach @(
        'TEST_APP_ENT_CLIENT_ID',
        'TEST_APP_ENT_PRIVATE_KEY',
        'TEST_APP_ORG_CLIENT_ID',
        'TEST_APP_ORG_PRIVATE_KEY',
        'TEST_USER_ORG_FG_PAT',
        'TEST_USER_USER_FG_PAT',
        'TEST_USER_PAT'
    ) {
        $name = $_
        Write-Verbose "Environment variable: [$name]" -Verbose
        Get-ChildItem env: | Where-Object { $_.Name -eq $name } | Should -Not -BeNullOrEmpty
    }

    It 'Exposes caller-defined secret names with their values' {
        # CUSTOM_TEST_ENV_VAR is provided by the calling workflow through the TestSecrets JSON object.
        # It proves arbitrary, caller-defined names are plumbed through as environment variables that
        # the tests read via $env:<name>, without relying on secrets: inherit.
        $env:CUSTOM_TEST_ENV_VAR | Should -Be 'caller-provided-value'
    }
}
