$expectedTestData = @{
    PSMODULE_TEST_SINGLELINE_SECRET = 'psmodule-public-nonsecret-test-fixture-single-line'
    PSMODULE_TEST_VARIABLE          = 'psmodule-public-nonsecret-test-variable'
}

foreach ($entry in $expectedTestData.GetEnumerator()) {
    $actual = [System.Environment]::GetEnvironmentVariable($entry.Key)
    if ([string]::IsNullOrEmpty($actual)) {
        throw "TestData key '$($entry.Key)' is not available in the current module-local phase."
    }
    if ($actual -cne $entry.Value) {
        throw "TestData key '$($entry.Key)' has an unexpected value in the current module-local phase."
    }
}

Write-Warning 'TestData secret and variable fixtures are available in this module-local phase.'
