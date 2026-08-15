# Get-PesterCodeCoverage

A GitHub Action that aggregates Pester code coverage reports and generates a detailed summary with coverage statistics.
Fails the workflow if coverage falls below specified targets.

This GitHub Action is a part of the [PSModule framework](https://github.com/PSModule). It is recommended to use the
[Process-PSModule workflow](https://github.com/PSModule/Process-PSModule) to automate the whole process of managing the PowerShell module.

## Features

- Combines multiple code coverage reports from parallel test runs
- Generates Markdown/HTML tables showing missed & executed commands
- Displays analyzed files and coverage statistics
- Generates a generic missed-path report (Markdown + JSON)
- Configurable step summary sections
- Threshold enforcement for minimum code coverage

## Usage

### Inputs

| Name | Description | Required | Default |
| ---- | ----------- | -------- | ------- |
| `Debug` | Enable debug output | No | `false` |
| `Verbose` | Enable verbose output | No | `false` |
| `Version` | Version of the GitHub module to install; accepts an exact version or a NuGet version range (for example `[1.2.0, 2.0.0)`) | No | Latest |
| `Prerelease` | Allow prerelease versions | No | `false` |
| `WorkingDirectory` | Working directory for the action | No | `.` |
| `StepSummary_Mode` | Controls which sections to show in the GitHub step summary. Use 'Full' for all sections, 'None' to disable, or a comma-separated list of 'Missed, Executed, Files'. | No | `Missed, Files` |
| `CodeCoveragePercentTarget` | Target code coverage percentage | No | Max target from individual reports |

### Example Workflow

```yaml
    - name: Process Code Coverage
      uses: PSModule/Get-PesterCodeCoverage@v1
      with:
        StepSummary_Mode: Full
        CodeCoveragePercentTarget: 80
```

## Outputs

| Name | Description |
| ---- | ----------- |
| `MissedPathReportPath` | Folder path containing `CodeCoverage-MissedPaths.md` and `CodeCoverage-MissedPaths.json` |

### GitHub Step Summary

The action generates a detailed summary visible in the GitHub Actions UI:

1. **Coverage Overview Table**
   - Coverage percentage vs target
   - Analyzed/executed/missed command counts
   - Number of files analyzed

2. **Expandable Sections**
   - **Missed Commands**: HTML table with code snippets
   - **Executed Commands**: HTML table with code snippets
   - **Analyzed Files**: List of covered files
   - **Missed Paths**: Aggregated missed-command counts grouped by file path

Example summary:

```markdown
✅ Code Coverage Report

Summary:
| Coverage | Target | Analyzed      | Executed      | Missed        | Files         |
| -------- | ------ | ------------- | ------------- | ------------- | ------------- |
| 85%      | 80%    | 1000 commands | 850 commands  | 150 commands  | 15 files      |

▶️ Missed commands [150] (click to expand)
▶️ Executed commands [850] (click to expand)
▶️ Files analyzed [15] (click to expand)
```

## Requirements

1. **Pester 6.1 Code Coverage Reports**
   Preceding steps must generate JSON coverage reports named `*-CodeCoverage*.json`

2. **GitHub CLI**
   The action uses `gh run download` to fetch artifacts from the current workflow run

## Behavior

1. **Coverage Calculation**
   - Combines multiple coverage reports
   - Removes duplicate entries
   - Calculates aggregate coverage percentage

2. **Threshold Enforcement**
   Fails the workflow if coverage is below either:
   - Explicitly specified `CodeCoveragePercentTarget`
   - Highest target from individual reports (if no target specified)

3. **Output Control**
   Configure visibility of sections using `StepSummary_Mode`:
   ```yaml
   # Show all sections
   StepSummary_Mode: Full

   # Disable summary
   StepSummary_Mode: None

   # Custom selection
   StepSummary_Mode: Missed, Files
   ```

## Troubleshooting

Enable debugging by setting inputs:
```yaml
with:
  Debug: true
  Verbose: true
```
