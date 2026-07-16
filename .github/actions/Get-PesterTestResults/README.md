# Get-PesterTestResults

A GitHub Action that gathers Pester test results for the PSModule process by analyzing test artifacts from the workflow run.
It validates test execution and results, providing a summary and failing if any tests are unsuccessful.

This GitHub Action is a part of the [PSModule framework](https://github.com/PSModule). It is recommended to use the
[Process-PSModule workflow](https://github.com/PSModule/Process-PSModule) to automate the whole process of managing the PowerShell module.

## Usage

This action retrieves test artifacts named `*-TestResults`, processes the contained JSON files, and checks for test failures, unexecuted tests,
or missing results. It supports three categories of test suites: Source Code, PSModule, and Module tests.

### Inputs

| Input                   | Description                                                                                                                   | Required | Default   |
|-------------------------|-------------------------------------------------------------------------------------------------------------------------------|----------|-----------|
| `SourceCodeTestSuites`  | JSON array specifying OS names for Source Code test suites. Example: `[{"OSName": "Windows"}]`                                | Yes      |           |
| `PSModuleTestSuites`    | JSON array specifying OS names for PSModule test suites. Example: `[{"OSName": "Linux"}]`                                     | Yes      |           |
| `ModuleTestSuites`      | JSON array specifying TestName and OSName for Module test suites. Example: `[{"TestName": "Integration", "OSName": "MacOS"}]` | Yes      |           |
| `Debug`                 | Enable debug output (`true`/`false`).                                                                                         | No       | `false`   |
| `Verbose`               | Enable verbose output (`true`/`false`).                                                                                       | No       | `false`   |
| `Version`               | Exact version of the GitHub module to install (e.g., `1.0.0`).                                                                | No       | Latest    |
| `Prerelease`            | Allow installing prerelease module versions (`true`/`false`).                                                                 | No       | `false`   |
| `WorkingDirectory`      | Working directory for the script.                                                                                             | No       | `.`       |

### Secrets

No secrets are required if the action runs in the same repository. The action uses the default `GITHUB_TOKEN` provided by GitHub Actions to access workflow artifacts.

### Outputs

This action does not define explicit outputs. Instead:

- If any tests fail or errors occur, the action exits with a non-zero code, marking the workflow step as failed.
- Detailed results are logged in the workflow run's output.

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
- **Test Suite Inputs**: Must be valid JSON arrays.
  - `SourceCodeTestSuites` and `PSModuleTestSuites` require `OSName`.
  - `ModuleTestSuites` requires both `TestName` and `OSName`.
- **Artifact Names**: The action expects artifacts named `*-TestResults` containing Pester JSON reports.
- **Failure Conditions**: The action fails if tests are unexecuted, explicitly failed, or if result files are missing.
