---
title: Configuring the pipeline
description: Worked examples for the Process-PSModule settings file — coverage targets, rapid testing, repository linting, and PR-based release notes.
---

# Configuring the pipeline

Everything the workflow does is controlled by a single settings file in the module repository — by default
`.github/PSModule.yml`, which can also be JSON or PSD1. Every setting has a default, so the file only needs to contain
what you want to change.

This page shows the common changes. For the complete list of settings and their defaults, see
[Settings](../reference/settings.md).

## Example 1 - Defaults with Code Coverage target

This example runs all steps and will require that code coverage is 80% before passing.

```yaml
Test:
  CodeCoverage:
    PercentTarget: 80
```

## Example 2 - Rapid testing

This example ends up running Plan, Build-Module and Test-Module (tests from the module repo) on **ubuntu-latest** only.

```yaml
Test:
  SourceCode:
    Skip: true
  PSModule:
    Skip: true
  Module:
    MacOS:
      Skip: true
    Windows:
      Skip: true
  TestResults:
    Skip: true
  CodeCoverage:
    Skip: true
Build:
  Docs:
    Skip: true
```

To skip an individual framework test for one file instead of a whole category, see
[Skipping framework tests](skipping-framework-tests.md).

## Example 3 - Configuring the Repository Linter

The workflow uses [super-linter](https://github.com/super-linter/super-linter) to lint your repository code.
The linter runs on pull requests and provides status updates directly in the PR.

### Disabling the Linter

You can skip repository linting entirely:

```yaml
Linter:
  Skip: true
```

### Configuring Linter Validation Rules

The workflow supports all environment variables that **super-linter** provides. You can configure these through the `Linter.env` object:

```yaml
Linter:
  env:
    # Disable specific validations
    VALIDATE_BIOME_FORMAT: false
    VALIDATE_BIOME_LINT: false
    VALIDATE_GITHUB_ACTIONS_ZIZMOR: false
    VALIDATE_JSCPD: false
    VALIDATE_JSON_PRETTIER: false
    VALIDATE_MARKDOWN_PRETTIER: false
    VALIDATE_YAML_PRETTIER: false

    # Or enable only specific validations
    VALIDATE_YAML: true
    VALIDATE_JSON: true
    VALIDATE_MARKDOWN: true
```

### Additional Configuration

Any super-linter environment variable can be set through the `Linter.env` object:

```yaml
Linter:
  env:
    LOG_LEVEL: DEBUG
    FILTER_REGEX_EXCLUDE: '.*test.*'
    VALIDATE_ALL_CODEBASE: false
```

### Showing Linter Summary on Success

By default, the linter only shows a summary when it finds issues. You can enable summary display on successful runs:

```yaml
Linter:
  ShowSummaryOnSuccess: true
```

This is useful for reviewing what was checked even when no issues are found.

**Note:** The `GITHUB_TOKEN` is automatically provided by the workflow to enable status updates in pull requests.

For a complete list of available environment variables and configuration options, see the
[super-linter environment variables documentation](https://github.com/super-linter/super-linter#environment-variables).

## Example 4 - Configuring PR-based release notes

The workflow can automatically generate GitHub release names and notes from your pull request content.
Three parameters control this behavior:

| Parameter | Description |
| ----------- | ------------- |
| `UsePRTitleAsReleaseName` | Use the PR title as the GitHub release name instead of the version string |
| `UsePRBodyAsReleaseNotes` | Use the PR body as the release notes content |
| `UsePRTitleAsNotesHeading` | Prepend PR title as H1 heading with PR number link before the body |

These parameters follow specific precedence rules when building release notes:

1. **Heading + Body** (`UsePRTitleAsNotesHeading: true` + `UsePRBodyAsReleaseNotes: true`): Creates formatted notes with the PR title as an H1 heading followed by the PR body. The output format is `# PR Title (#123)\n\nPR body content`. Both the PR title and body must be present.
1. **Body only** (`UsePRBodyAsReleaseNotes: true`): Uses the PR body as-is for release notes. Takes effect when heading option is disabled or PR title is missing.
1. **Fallback**: When neither option is enabled or required PR content is missing, GitHub's auto-generated release notes are used via `--generate-notes`.

### Default configuration (recommended)

The defaults provide rich release notes with the PR title as a heading:

```yaml
Publish:
  Module:
    UsePRTitleAsReleaseName: false
    UsePRBodyAsReleaseNotes: true
    UsePRTitleAsNotesHeading: true
```

This produces release notes like:

```markdown
# 🚀 Add new authentication feature (#42)

This PR adds OAuth2 support with the following changes:
- Added `Connect-OAuth2` function
- Updated documentation
```

### Version-only release names

If you prefer version numbers as release names but still want PR-based notes:

```yaml
Publish:
  Module:
    UsePRTitleAsReleaseName: false
    UsePRBodyAsReleaseNotes: true
    UsePRTitleAsNotesHeading: false
```

### Auto-generated notes

To use GitHub's auto-generated release notes instead of PR content:

```yaml
Publish:
  Module:
    UsePRTitleAsReleaseName: false
    UsePRBodyAsReleaseNotes: false
    UsePRTitleAsNotesHeading: false
```
