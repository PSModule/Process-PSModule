# Get-PesterTestResults

This GitHub Action collects Pester test results from workflow artifacts for the PSModule process.
The action examines test execution and results. It writes a summary and fails if tests do not pass.

The [PSModule framework](https://github.com/PSModule) includes this action.
For the recommended setup, use the [Process-PSModule workflow](https://github.com/PSModule/Process-PSModule) to automate PowerShell module management.

## Usage

The action gets artifacts named `*-TestResults` and reads their JSON files.
It finds test failures, tests that did not run, and missing results.
The action supports Source Code, PSModule, and Module test suites.

### Inputs

| Input                   | Description                                                                                                                   | Required | Default   |
|-------------------------|-------------------------------------------------------------------------------------------------------------------------------|----------|-----------|
| `SourceCodeTestSuites`  | JSON array that specifies OS names for Source Code test suites. Example: `[{"OSName": "Windows"}]`                                | Yes      |           |
| `PSModuleTestSuites`    | JSON array that specifies OS names for PSModule test suites. Example: `[{"OSName": "Linux"}]`                                     | Yes      |           |
| `ModuleTestSuites`      | JSON array that specifies TestName and OSName for Module test suites. Example: `[{"TestName": "Integration", "OSName": "MacOS"}]` | Yes      |           |
| `BeforeAllModuleLocalResult` | Workflow result for the `BeforeAll-ModuleLocal` job (`success`, `failure`, `skipped`).                                  | No       | `skipped` |
| `Debug`                 | Enable debug output (`true`/`false`).                                                                                         | No       | `false`   |
| `Verbose`               | Enable verbose output (`true`/`false`).                                                                                       | No       | `false`   |
| `Version`               | Exact version of the GitHub module to install (for example, `1.0.0`).                                                                | No       | Latest    |
| `Prerelease`            | Allow prerelease module versions (`true`/`false`).                                                                 | No       | `false`   |
| `WorkingDirectory`      | Working directory for the script.                                                                                             | No       | `.`       |

### Secrets

For runs in the same repository, the action needs no additional secrets.
The action uses the default `GITHUB_TOKEN` from GitHub Actions to access workflow artifacts.

### Outputs

The action defines no explicit outputs.

- If tests fail or errors occur, the action exits with a nonzero code. GitHub Actions marks the workflow step as failed.
- The action writes detailed results to the workflow run log.

### Example

```yaml
- name: Run and Collect Pester Tests
  uses: PSModule/Get-PesterTestResults@v1
  with:
    SourceCodeTestSuites: '[{"OSName": "Windows"}, {"OSName": "Linux"}]'
    PSModuleTestSuites: '[{"OSName": "Windows"}]'
    ModuleTestSuites: '[{"TestName": "Integration", "OSName": "Windows"}]'
```

### Notes
- **Test suite inputs**: The test suite inputs must be valid JSON arrays.
  - `SourceCodeTestSuites` and `PSModuleTestSuites` require `OSName`.
  - `ModuleTestSuites` requires both `TestName` and `OSName`.
- **BeforeAll module-local failures**: If `BeforeAllModuleLocalResult` is `failure`, the action exits immediately and reports the setup failure as the root cause.
- **Artifact names**: The action expects artifacts named `*-TestResults` with Pester JSON reports.
- **Failure conditions**: The action fails if tests do not run, tests fail, or result files are missing.
