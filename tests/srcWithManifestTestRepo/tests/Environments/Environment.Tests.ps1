Describe 'Environment Variables are available' {
    It 'Exposes [<Name>] with the caller-provided value' -ForEach @(
        @{ Name = 'TEST_APP_ENT_CLIENT_ID'; Expected = 'tmp-ent-client-id-01' }
        @{ Name = 'TEST_APP_ORG_CLIENT_ID'; Expected = 'tmp-org-client-id-02' }
        @{ Name = 'TEST_USER_ORG_FG_PAT'; Expected = 'tmp-user-org-fgpat-03' }
        @{ Name = 'TEST_USER_USER_FG_PAT'; Expected = 'tmp-user-usr-fgpat-04' }
        @{ Name = 'TEST_USER_PAT'; Expected = 'tmp-user-pat-05' }
        @{ Name = 'CUSTOM_TEST_ENV_VAR'; Expected = 'caller-provided-value' }
    ) {
        Write-Verbose "Environment variable: [$Name]" -Verbose
        [System.Environment]::GetEnvironmentVariable($Name) | Should -Be $Expected
    }

    It 'Preserves multi-line values in [<Name>]' -ForEach @(
        @{ Name = 'TEST_APP_ENT_PRIVATE_KEY'; Expected = "tmp-ent-key-a1`ntmp-ent-key-a2" }
        @{ Name = 'TEST_APP_ORG_PRIVATE_KEY'; Expected = "tmp-org-key-b1`ntmp-org-key-b2" }
    ) {
        [System.Environment]::GetEnvironmentVariable($Name) | Should -Be $Expected
    }
}
