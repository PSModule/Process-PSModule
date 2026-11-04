---
title: Writing module tests
description: Discover module-local Pester tests and share test infrastructure across the platform matrix.
---

# Writing module tests

Module-local Pester tests verify the module's own behavior. They are separate from the framework tests that
Process-PSModule enforces on every module. The workflow builds and imports the module before it runs module-local tests.
The tests run in parallel across Windows, Linux, and macOS.

## Pester version

At the top of each `*.Tests.ps1`, declare this Pester requirement:

```powershell
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.1.0'; MaximumVersion = '6.*' }
```

This declaration is a module-author convention. Process-PSModule pins its reusable
[Invoke-Pester](https://github.com/PSModule/Invoke-Pester) action runs to the
`[6.1.0,7.0.0)` range. Patch updates install automatically. A major-version
change requires explicit review.

Pester 6.1 provides opt-in controls for shuffled and parallel file execution
(`Run.Shuffle`, `Run.ShuffleSeed`, `Run.Parallel`, and
`Run.ParallelThrottleLimit`) and diagnostic start markers
(`Debug.ShowStartMarkers`). Direct Pester invocations with
`New-PesterConfiguration` support these controls. The pinned
`PSModule/Invoke-Pester` v5.1.1
[action contract](https://github.com/PSModule/Invoke-Pester/blob/c5494aba3c07d7bfd81bdbbc9f301e8fa4a729fb/action.yml)
does not accept these controls. Process-PSModule does not expose them through
its reusable workflow.

## Test discovery

Simple, Standard, and Advanced are
[documentation profiles](https://msx.no/docs/Coding-Standards/PowerShell/Testing/#module-test-profiles), not
selectable workflow modes. The same discovery engine handles every profile. `.github/PSModule.yml` has no test-layout
or suite-matrix setting. Process-PSModule calculates `Settings.Test.Module.Suites` from the repository files.

Process-PSModule inspects `tests/` recursively. In each directory, it selects the first matching form:

1. Exactly one `*.Configuration.ps1`. If a directory contains more than one, discovery fails. Discovery does not independently select sibling `*.Container.ps1` or `*.Tests.ps1` files.
2. Otherwise, one or more `*.Container.ps1`. Discovery does not independently select sibling `*.Tests.ps1` files.
3. Otherwise, all `*.Tests.ps1`.

Precedence applies separately to each directory. Discovery also inspects child directories.
A repository can mix configurations, containers, and ordinary test files across different directories.

Each discovered artifact needs a unique filename prefix before its first dot. Discovery uses that prefix as `TestName`.
For example, `Users.Unit.Tests.ps1` and `Users.Integration.Tests.ps1` both produce `Users`.
Use distinct prefixes such as `UsersUnit` and `UsersIntegration`.

Discovery does not affect which changes trigger a release. A test-only change does not enter the build, test, and
publish path unless `^tests/` is added to
[`ImportantFilePatterns`](calling-the-workflow.md#customizing-important-file-patterns).

## Setup and teardown scripts

The workflow runs setup and teardown scripts for module tests:

- `tests/BeforeAll.ps1` and `tests/AfterAll.ps1` are special workflow phase files, not ordinary recursively discovered test entries.
- The workflow enables each phase only when its exact file exists at the root of `tests/`.
- If either file is absent, the workflow skips that phase and continues without it.
- Phase detection is **not** recursive. Nested files named `BeforeAll.ps1` or `AfterAll.ps1` do not create workflow phases.
- Both scripts receive the same caller-provided environment variables as the tests through
  [`TestData`](calling-the-workflow.md#passing-test-data).

### Setup - `BeforeAll.ps1`

- Place the script at the exact repository-root path `tests/BeforeAll.ps1`.
- The workflow runs this script once before all test matrix jobs to prepare the test environment.
- Use it to deploy test infrastructure, download test data, initialize databases, or configure services.

```powershell
Write-Host "Setting up test environment..."
# Deploy test infrastructure
# Download test data
# Initialize test databases
Write-Host "Test environment ready!"
```

### Teardown - `AfterAll.ps1`

- Place the script at the exact repository-root path `tests/AfterAll.ps1`.
- The workflow runs this script once after all test matrix jobs complete to clean up the test environment.
- Use it to remove test resources, clean up databases, stop services, or upload artifacts.

```powershell
Write-Host "Cleaning up test environment..."
# Remove test resources
# Clean up databases
# Stop services
Write-Host "Cleanup completed!"
```

## Sharing test infrastructure

Tests run in parallel across multiple OS runners. To limit resource creation and avoid rate limits or conflicts,
provision shared infrastructure once in `BeforeAll.ps1`. Remove it in `AfterAll.ps1`.
Individual test files should use the shared infrastructure instead of creating their own.

### Use deterministic naming with `$env:GITHUB_RUN_ID`

Use `$env:GITHUB_RUN_ID` to build deterministic resource names. The value is stable per workflow run and shared across OS runners.
Test files can then reference shared resources by name without state transfer between jobs.

```powershell
# BeforeAll.ps1
$os = $env:RUNNER_OS
$id = $env:GITHUB_RUN_ID
$resourceName = "Test-$os-$id"
```

Do **not** use `[guid]::NewGuid()` or `Get-Random` for shared resource names.
These produce different values on each runner. Other jobs cannot derive those values.

### Clean up stale resources from previous failed runs

After a failed workflow run, stale resources can remain if teardown does not complete.
At the start of `BeforeAll.ps1`, remove resources with the naming prefix before you create others:

```powershell
# Remove stale resources from previous failed runs
Get-Resources -Filter "Test-$os-*" | Remove-Resource

# Create fresh shared resources
New-Resource -Name "Test-$os-$id"
```

### Tests reference shared resources — they do not create them

Test files should get the shared resource by its deterministic name, not create another resource:

```powershell
# Inside a test file
BeforeAll {
    $os = $env:RUNNER_OS
    $id = $env:GITHUB_RUN_ID
    $resource = Get-Resource -Name "Test-$os-$id"
}
```

Test files can create and remove test-specific resources, such as secrets, variables, or temporary items.
Test files should share only long-lived or expensive resources.

### Naming conventions

Use a consistent naming scheme to identify and remove resources. The following table gives recommended patterns:

| Resource          | Pattern                               | Example                    |
|-------------------|---------------------------------------|----------------------------|
| Shared resource   | `Test-{OS}-{RunID}`                   | `Test-Linux-1234`          |
| Extra resource    | `Test-{OS}-{RunID}-{N}`               | `Test-Linux-1234-1`        |
| Secret / variable | `{TestName}_{OS}_{RunID}`             | `Secrets_Linux_1234`       |
| Environment       | `{TestName}-{OS}-{RunID}`             | `Secrets-Linux-1234`       |

If multiple authentication contexts share a runner, include a token or context identifier in each resource name to prevent collisions.
For example, use `Test-{OS}-{ContextID}-{RunID}`.

## Related

- [Pipeline stages](../reference/pipeline-stages.md#test-module) — the jobs that run these tests.
- [Framework test IDs](../reference/framework-test-ids.md) — the tests the framework enforces on every module.
- [Settings](../reference/settings.md) — how to skip test categories or platforms.
