Describe 'TestSecrets and TestVariables are exposed to the module tests' {
    # PSMODULE_TEST_SINGLELINE_SECRET / PSMODULE_TEST_MULTILINE_SECRET (secrets, masked) and
    # PSMODULE_TEST_VARIABLE (a non-secret variable, not masked) are dedicated fixtures that exist only
    # to prove the TestSecrets/TestVariables plumbing. The calling workflow passes them through and the
    # framework exposes them as environment variables; these tests confirm they arrive correct.

    It 'Exposes the single-line secret with the exact expected value' {
        $expected = 'psmodule-public-nonsecret-test-fixture-single-line'
        $actual = [System.Environment]::GetEnvironmentVariable('PSMODULE_TEST_SINGLELINE_SECRET')
        $actual | Should -Not -BeNullOrEmpty
        $actual | Should -BeExactly $expected
        $actual.Length | Should -Be 50
    }

    It 'Exposes the multi-line secret with every line intact' {
        $expected = @(
            'psmodule-public-nonsecret-test-fixture-line-1'
            'psmodule-public-nonsecret-test-fixture-line-2'
            'psmodule-public-nonsecret-test-fixture-line-3'
        ) -join "`n"
        $actual = [System.Environment]::GetEnvironmentVariable('PSMODULE_TEST_MULTILINE_SECRET')
        $actual | Should -Not -BeNullOrEmpty
        $lines = $actual -split "`r?`n"
        $lines.Count | Should -Be 3
        $lines[0] | Should -BeExactly 'psmodule-public-nonsecret-test-fixture-line-1'
        $lines[2] | Should -BeExactly 'psmodule-public-nonsecret-test-fixture-line-3'
        ($actual -replace "`r`n", "`n") | Should -BeExactly $expected
        ($actual -replace "`r`n", "`n").Length | Should -Be 137
    }

    It 'Exposes a non-secret variable via TestVariables' {
        $actual = [System.Environment]::GetEnvironmentVariable('PSMODULE_TEST_VARIABLE')
        $actual | Should -Not -BeNullOrEmpty
        $actual | Should -BeExactly 'psmodule-public-nonsecret-test-variable'
        $actual.Length | Should -Be 39
    }
}
