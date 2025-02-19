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
}
