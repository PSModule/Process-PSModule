---
title: Settings
description: The Process-PSModule settings file — every available setting in .github/PSModule.yml and the full defaults.
---

# Settings

The workflow is configured using a settings file in the module repository.
The file can be a `JSON`, `YAML`, or `PSD1` file. By default, it will look for `.github/PSModule.yml`.

The settings listed on this page are the user-facing configuration contract in `.github/PSModule.yml`. During the
Plan phase, Process-PSModule enriches this input into an internal runtime `Settings` object that downstream workflows
consume. Internal runtime paths in workflow docs (for example, `Settings.Publish.Module.Resolution.*`) describe that
enriched inter-workflow contract, not a different authoring format for repository settings files. See
[Pipeline stages](pipeline-stages.md#internal-runtime-settings-contract) for that contract.

Simple, Standard, and Advanced test profiles are repository conventions, not settings. `.github/PSModule.yml` has no
layout or suite-matrix selector; Process-PSModule
[discovers the files under `tests/` recursively](../guides/writing-module-tests.md#test-discovery)
and computes its internal `Settings.Test.Module.Suites` matrix from them.

Test discovery and change triggering are separate. The default `ImportantFilePatterns` match only `^src/` and
`^README\.md$`, so a test-only change does not enter the important-change build, test, and publish path. Repositories
that need test or automation changes to exercise that path must
[add `^tests/` and any relevant settings or workflow paths](../guides/calling-the-workflow.md#customizing-important-file-patterns)
while retaining every default they still need.

For worked examples, see [Configuring the pipeline](../guides/configuring-the-pipeline.md).

## Available settings

| Name                                      | Type      | Description                                                                                                                                                          | Default             |
| ----------------------------------------- | --------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------- |
| `Name`                                    | `String`  | Name of the module to publish. Defaults to the repository name.                                                                                                      | `null`              |
| `ImportantFilePatterns`                   | `Array`   | Regular expression patterns that identify important files. Changes matching these patterns trigger build, test, and publish stages. When set, fully replaces the defaults. | `['^src/', '^README\.md$']` |
| `Test.Skip`                               | `Boolean` | Skip all tests                                                                                                                                                       | `false`             |
| `Test.Linux.Skip`                         | `Boolean` | Skip tests on Linux                                                                                                                                                  | `false`             |
| `Test.MacOS.Skip`                         | `Boolean` | Skip tests on macOS                                                                                                                                                  | `false`             |
| `Test.Windows.Skip`                       | `Boolean` | Skip tests on Windows                                                                                                                                                | `false`             |
| `Test.SourceCode.Skip`                    | `Boolean` | Skip source code tests                                                                                                                                               | `false`             |
| `Test.SourceCode.Linux.Skip`              | `Boolean` | Skip source code tests on Linux                                                                                                                                      | `false`             |
| `Test.SourceCode.MacOS.Skip`              | `Boolean` | Skip source code tests on macOS                                                                                                                                      | `false`             |
| `Test.SourceCode.Windows.Skip`            | `Boolean` | Skip source code tests on Windows                                                                                                                                    | `false`             |
| `Test.PSModule.Skip`                      | `Boolean` | Skip PSModule framework tests                                                                                                                                        | `false`             |
| `Test.PSModule.Linux.Skip`                | `Boolean` | Skip PSModule framework tests on Linux                                                                                                                               | `false`             |
| `Test.PSModule.MacOS.Skip`                | `Boolean` | Skip PSModule framework tests on macOS                                                                                                                               | `false`             |
| `Test.PSModule.Windows.Skip`              | `Boolean` | Skip PSModule framework tests on Windows                                                                                                                             | `false`             |
| `Test.Module.Skip`                        | `Boolean` | Skip module tests                                                                                                                                                    | `false`             |
| `Test.Module.Linux.Skip`                  | `Boolean` | Skip module tests on Linux                                                                                                                                           | `false`             |
| `Test.Module.MacOS.Skip`                  | `Boolean` | Skip module tests on macOS                                                                                                                                           | `false`             |
| `Test.Module.Windows.Skip`                | `Boolean` | Skip module tests on Windows                                                                                                                                         | `false`             |
| `Test.TestResults.Skip`                   | `Boolean` | Skip test result processing                                                                                                                                          | `false`             |
| `Test.CodeCoverage.Skip`                  | `Boolean` | Skip code coverage tests                                                                                                                                             | `false`             |
| `Test.CodeCoverage.PercentTarget`         | `Integer` | Target code coverage percentage                                                                                                                                      | `0`                 |
| `Test.CodeCoverage.StepSummaryMode`       | `String`  | Step summary mode for code coverage reports                                                                                                                          | `'Missed, Files'`   |
| `Build.Skip`                              | `Boolean` | Skip all build tasks                                                                                                                                                 | `false`             |
| `Build.Module.Skip`                       | `Boolean` | Skip module build                                                                                                                                                    | `false`             |
| `Build.Docs.Skip`                         | `Boolean` | Skip documentation build                                                                                                                                             | `false`             |
| `Build.Docs.ShowSummaryOnSuccess`         | `Boolean` | Show super-linter summary on success for documentation linting                                                                                                       | `false`             |
| `Build.Site.Skip`                         | `Boolean` | Skip site build                                                                                                                                                      | `false`             |
| `Publish.Site.Skip`                       | `Boolean` | Skip publishing the generated documentation site                                                                                                                     | `false`             |
| `Publish.Module.Skip`                     | `Boolean` | Skip module publishing                                                                                                                                               | `false`             |
| `Publish.Module.AutoCleanup`              | `Boolean` | Automatically clean up old prerelease tags when merging to main or when a PR is abandoned                                                                            | `true`              |
| `Publish.Module.AutoPatching`             | `Boolean` | Automatically patch module version                                                                                                                                   | `true`              |
| `Publish.Module.IncrementalPrerelease`    | `Boolean` | Use incremental prerelease versioning                                                                                                                                | `true`              |
| `Publish.Module.DatePrereleaseFormat`     | `String`  | Format for date-based prerelease (uses [.NET DateTime format strings](https://learn.microsoft.com/dotnet/standard/base-types/standard-date-and-time-format-strings)) | `''`                |
| `Publish.Module.VersionPrefix`            | `String`  | Prefix for version tags                                                                                                                                              | `'v'`               |
| `Publish.Module.MajorLabels`              | `String`  | Labels indicating a major version bump                                                                                                                               | `'major, breaking'` |
| `Publish.Module.MinorLabels`              | `String`  | Labels indicating a minor version bump                                                                                                                               | `'minor, feature'`  |
| `Publish.Module.PatchLabels`              | `String`  | Labels indicating a patch version bump                                                                                                                               | `'patch, fix'`      |
| `Publish.Module.IgnoreLabels`             | `String`  | Labels indicating no release                                                                                                                                         | `'NoRelease'`       |
| `Publish.Module.UsePRTitleAsReleaseName`  | `Boolean` | Use the PR title as the GitHub release name instead of version string                                                                                                | `false`             |
| `Publish.Module.UsePRBodyAsReleaseNotes`  | `Boolean` | Use the PR body as the release notes content                                                                                                                         | `true`              |
| `Publish.Module.UsePRTitleAsNotesHeading` | `Boolean` | Prepend PR title as H1 heading with PR number link before the body                                                                                                   | `true`              |
| `Linter.Skip`                             | `Boolean` | Skip repository linting                                                                                                                                              | `false`             |
| `Linter.ShowSummaryOnSuccess`             | `Boolean` | Show super-linter summary on success for repository linting                                                                                                          | `false`             |
| `Linter.env`                              | `Object`  | Environment variables for super-linter configuration                                                                                                                 | `{}`                |

## Defaults

<details>
<summary>`PSModule.yml` with all defaults</summary>

```yaml
Name: null

ImportantFilePatterns:
  - '^src/'
  - '^README\.md$'

Build:
  Skip: false
  Module:
    Skip: false
  Docs:
    Skip: false
    ShowSummaryOnSuccess: false
  Site:
    Skip: false

Test:
  Skip: false
  Linux:
    Skip: false
  MacOS:
    Skip: false
  Windows:
    Skip: false
  SourceCode:
    Skip: false
    Linux:
      Skip: false
    MacOS:
      Skip: false
    Windows:
      Skip: false
  PSModule:
    Skip: false
    Linux:
      Skip: false
    MacOS:
      Skip: false
    Windows:
      Skip: false
  Module:
    Skip: false
    Linux:
      Skip: false
    MacOS:
      Skip: false
    Windows:
      Skip: false
  TestResults:
    Skip: false
  CodeCoverage:
    Skip: false
    PercentTarget: 0
    StepSummaryMode: 'Missed, Files'

Publish:
  Site:
    Skip: false
  Module:
    Skip: false
    AutoCleanup: true
    AutoPatching: true
    IncrementalPrerelease: true
    DatePrereleaseFormat: ''
    VersionPrefix: 'v'
    MajorLabels: 'major, breaking'
    MinorLabels: 'minor, feature'
    PatchLabels: 'patch, fix'
    IgnoreLabels: 'NoRelease'
    UsePRTitleAsReleaseName: false
    UsePRBodyAsReleaseNotes: true
    UsePRTitleAsNotesHeading: true

Linter:
  Skip: false
  ShowSummaryOnSuccess: false
  env: {}
```

</details>
