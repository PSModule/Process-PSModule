Describe 'TestData is exposed to the module tests' {
    # PSMODULE_TEST_SINGLELINE_SECRET (a secret, masked) and PSMODULE_TEST_VARIABLE (a non-secret
    # variable, not masked) are dedicated fixtures that exist only to prove the TestData plumbing. The
    # calling workflow passes them through a single TestData object and the framework exposes them as
    # environment variables; these tests confirm they arrive correct.

    It 'Exposes the single-line secret with the exact expected value' {
        $expected = 'psmodule-public-nonsecret-test-fixture-single-line'
        $actual = [System.Environment]::GetEnvironmentVariable('PSMODULE_TEST_SINGLELINE_SECRET')
        $actual | Should -Not -BeNullOrEmpty
        $actual | Should -BeExactly $expected
        $actual.Length | Should -Be 50
    }

    It 'Exposes a non-secret variable via the variables map' {
        $actual = [System.Environment]::GetEnvironmentVariable('PSMODULE_TEST_VARIABLE')
        $actual | Should -Not -BeNullOrEmpty
        $actual | Should -BeExactly 'psmodule-public-nonsecret-test-variable'
        $actual.Length | Should -Be 39
    }
}
