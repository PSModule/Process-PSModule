---
title: Writing module tests
description: How Process-PSModule discovers module-local Pester tests, the setup and teardown phases, and how to share test infrastructure across the platform matrix.
---

# Writing module tests

Module-local tests are the Pester tests you write for your own module, as opposed to the framework tests that
Process-PSModule enforces on every module. They run in parallel across Windows, Linux, and macOS after the module has
been built and imported.

## Pester version

Module test files declare a Pester **6.x** requirement at the top of each `*.Tests.ps1`:

```powershell
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0'; MaximumVersion = '6.*' }
```

This is a convention module authors add, not something the pipeline injects. The
[Invoke-Pester](https://github.com/PSModule/Invoke-Pester) action installs a matching `6.x`, so minor and patch updates
flow in automatically while a new major stays a deliberate, reviewed change.

## Test discovery

Simple, Standard, and Advanced are
[documentation profiles](https://msxorg.github.io/docs/Coding-Standards/PowerShell/Testing/#module-test-profiles), not
selectable workflow modes. The same discovery engine handles every profile. `.github/PSModule.yml` has no test-layout
or suite-matrix setting; `Settings.Test.Module.Suites` is computed internally from the repository files.

Process-PSModule inspects `tests/` recursively. Within each directory it uses the first matching form:

1. Exactly one `*.Configuration.ps1`. Discovery fails when a directory contains more than one. When selected, sibling `*.Container.ps1` and `*.Tests.ps1` files are not independently selected.
2. Otherwise, one or more `*.Container.ps1`. When selected, sibling `*.Tests.ps1` files are not independently selected.
3. Otherwise, all `*.Tests.ps1`.

The selected form takes precedence only in that directory. Child directories are still inspected independently, so a repository may mix configurations, containers, and ordinary test files across different directories.

Every discovered artifact needs a unique prefix before its first dot because that prefix becomes `TestName`. For example, `Users.Unit.Tests.ps1` and `Users.Integration.Tests.ps1` both become `Users`; use distinct prefixes such as `UsersUnit` and `UsersIntegration`.

Discovery does not affect which changes trigger a release. A test-only change does not enter the build, test, and
publish path unless `^tests/` is added to
[`ImportantFilePatterns`](calling-the-workflow.md#customizing-important-file-patterns).

## Setup and teardown scripts

The workflow supports automatic execution of setup and teardown scripts for module tests:

- `tests/BeforeAll.ps1` and `tests/AfterAll.ps1` are special workflow phase files, not ordinary recursively discovered test entries.
- Each phase is enabled only when its exact file exists at the root of `tests/`.
- If either file is absent, the workflow skips that phase and continues normally.
- Phase detection is **not** recursive. Nested files named `BeforeAll.ps1` or `AfterAll.ps1` do not create workflow phases.
- Both scripts run with the same environment variables as the tests, including anything passed through
  [`TestData`](calling-the-workflow.md#passing-test-data).

### Setup - `BeforeAll.ps1`

- Place at the exact repository-root path `tests/BeforeAll.ps1`.
- Runs once before all test matrix jobs to prepare the test environment.
- Deploy test infrastructure, download test data, initialize databases, or configure services.

```powershell
Write-Host "Setting up test environment..."
# Deploy test infrastructure
# Download test data
# Initialize test databases
Write-Host "Test environment ready!"
```

### Teardown - `AfterAll.ps1`

- Place at the exact repository-root path `tests/AfterAll.ps1`.
- Runs once after all test matrix jobs complete to clean up the test environment.
- Remove test resources, clean up databases, stop services, or upload artifacts.

```powershell
Write-Host "Cleaning up test environment..."
# Remove test resources
# Clean up databases
# Stop services
Write-Host "Cleanup completed!"
```

## Sharing test infrastructure

Tests run in parallel across multiple OS runners. To avoid rate limits or conflicts from excessive resource creation,
provision shared infrastructure once in `BeforeAll.ps1` and tear it down in `AfterAll.ps1`. Individual test files
should consume the shared infrastructure instead of creating their own.

### Use deterministic naming with `$env:GITHUB_RUN_ID`

Use `$env:GITHUB_RUN_ID` (stable per workflow run, shared across OS runners) to build deterministic resource names.
This lets test files reference shared resources by name without passing state between jobs.

```powershell
# BeforeAll.ps1
$os = $env:RUNNER_OS
$id = $env:GITHUB_RUN_ID
$resourceName = "Test-$os-$id"
```

Do **not** use `[guid]::NewGuid()` or `Get-Random` for shared resource names — these produce different values on
each runner and cannot be referenced by other jobs.

### Clean up stale resources from previous failed runs

If a previous workflow run failed before teardown completed, stale resources may remain. Start `BeforeAll.ps1` by
removing any resources matching your naming prefix before creating new ones:

```powershell
# Remove stale resources from previous failed runs
Get-Resources -Filter "Test-$os-*" | Remove-Resource

# Create fresh shared resources
New-Resource -Name "Test-$os-$id"
```

### Tests reference shared resources — they do not create them

Test files should fetch the shared resource by its deterministic name, not create new resources:

```powershell
# Inside a test file
BeforeAll {
    $os = $env:RUNNER_OS
    $id = $env:GITHUB_RUN_ID
    $resource = Get-Resource -Name "Test-$os-$id"
}
```

Test-specific ephemeral resources (for example, secrets, variables, or temporary items) can still be created and
cleaned up within each test file. Only long-lived or expensive resources should be shared.

### Naming conventions

Use a consistent naming scheme so that resources are easy to identify and clean up. A recommended pattern:

| Resource          | Pattern                               | Example                    |
|-------------------|---------------------------------------|----------------------------|
| Shared resource   | `Test-{OS}-{RunID}`                   | `Test-Linux-1234`          |
| Extra resource    | `Test-{OS}-{RunID}-{N}`               | `Test-Linux-1234-1`        |
| Secret / variable | `{TestName}_{OS}_{RunID}`             | `Secrets_Linux_1234`       |
| Environment       | `{TestName}-{OS}-{RunID}`             | `Secrets-Linux-1234`       |

When tests use multiple authentication contexts that share the same runner, include a token or context identifier in
the name to avoid collisions (for example, `Test-{OS}-{ContextID}-{RunID}`).

## Related

- [Pipeline stages](../reference/pipeline-stages.md#test-module) — the jobs that run these tests.
- [Framework test IDs](../reference/framework-test-ids.md) — the tests the framework enforces on every module.
- [Settings](../reference/settings.md) — how to skip test categories or platforms.
