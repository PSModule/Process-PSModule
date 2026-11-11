# Get-PesterCodeCoverage

This GitHub Action collects Pester code coverage reports and writes a summary of coverage statistics.
If coverage is below the specified target, the action fails the workflow.

The [PSModule framework](https://github.com/PSModule) includes this action.
For the recommended setup, use the [Process-PSModule workflow](https://github.com/PSModule/Process-PSModule) to automate PowerShell module management.

## Features

- Collects code coverage reports from parallel test runs.
- Writes Markdown and HTML tables of missed and executed commands.
- Shows analyzed files and coverage statistics.
- Writes a missed-path report in Markdown and JSON.
- Selects step summary sections from the action input.
- Fails the workflow if coverage is below the target.

## Usage

### Inputs

| Name | Description | Required | Default |
| ---- | ----------- | -------- | ------- |
| `Debug` | Enable debug output | No | `false` |
| `Verbose` | Enable verbose output | No | `false` |
| `Version` | Version of the GitHub module to install; accepts an exact version or a NuGet version range (for example `[1.2.0, 2.0.0)`) | No | Latest |
| `Prerelease` | Allow prerelease versions | No | `false` |
| `WorkingDirectory` | Working directory for the action | No | `.` |
| `StepSummary_Mode` | Select the sections in the GitHub step summary. Use 'Full' for all sections, 'None' to disable, or a comma-separated list of 'Missed, Executed, Files'. | No | `Missed, Files` |
| `CodeCoveragePercentTarget` | Target code coverage percentage | No | Max target from individual reports |

### Example workflow

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
| `MissedPathReportPath` | Path to the folder with `CodeCoverage-MissedPaths.md` and `CodeCoverage-MissedPaths.json` |

### GitHub step summary

The action writes a detailed summary to the GitHub Actions UI:

1. **Coverage overview table**
   - Coverage percentage and target
   - Analyzed, executed, and missed command counts
   - Number of analyzed files

2. **Expandable sections**
   - **Missed commands**: HTML table with code snippets
   - **Executed commands**: HTML table with code snippets
   - **Analyzed files**: List of covered files
   - **Missed paths**: Missed-command counts for each file path

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

1. **Pester 6.1 code coverage reports**

   Earlier steps must create JSON coverage reports named `*-CodeCoverage*.json`
   from the Pester 6.1 `CodeCoverage` result object. The action reads
   `CoveragePercent`, `CoveragePercentTarget`, `CommandsMissed`,
   `CommandsExecuted`, and `FilesAnalyzed` plus their count properties.

2. **GitHub CLI**
   The action uses `gh run download` to fetch artifacts from the current workflow run

## Behavior

1. **Coverage calculation**
   - Collects multiple coverage reports.
   - Removes duplicate entries.
   - Calculates the total coverage percentage across all reports.

2. **Threshold enforcement**
   If coverage is below the applicable target, the action fails the workflow.
   The action uses:
   - The explicit `CodeCoveragePercentTarget` value, if the input has a value.
   - The highest target from individual reports, if the input has no value.

3. **Output control**
   Use `StepSummary_Mode` to select the summary sections:
   ```yaml
   # Show all sections
   StepSummary_Mode: Full

   # Disable summary
   StepSummary_Mode: None

   # Custom selection
   StepSummary_Mode: Missed, Files
   ```

## Troubleshooting

To get debug and verbose output, set these inputs:
```yaml
with:
  Debug: true
  Verbose: true
```
