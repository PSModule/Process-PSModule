---
title: Scenario matrix
description: Which Process-PSModule jobs run for each trigger scenario — open pull request, merged pull request, abandoned pull request, and manual run.
---

# Scenario matrix

This table shows when each job runs based on the trigger scenario. It is the single source of truth for job
execution; other pages link here rather than repeating it.

| Job                       | Open/Updated PR | Merged PR  | Abandoned PR | Manual Run |
| ------------------------- | --------------- | ---------- | ------------ | ---------- |
| **Plan**                  | ✅ Always       | ✅ Always  | ✅ Always    | ✅ Always  |
| **Lint-Repository**       | ✅ Yes          | ❌ No      | ❌ No        | ❌ No      |
| **Build-Module**          | ✅ Yes          | ✅ Yes     | ❌ No        | ✅ Yes     |
| **Build-Docs**            | ✅ Yes          | ✅ Yes     | ❌ No        | ✅ Yes     |
| **Build-Site**            | ✅ Yes          | ✅ Yes     | ❌ No        | ✅ Yes     |
| **Test-SourceCode**       | ✅ Yes          | ✅ Yes     | ❌ No        | ✅ Yes     |
| **Lint-SourceCode**       | ✅ Yes          | ✅ Yes     | ❌ No        | ✅ Yes     |
| **Test-Module**           | ✅ Yes          | ✅ Yes     | ❌ No        | ✅ Yes     |
| **BeforeAll-ModuleLocal** | ✅ Yes          | ✅ Yes     | ❌ No        | ✅ Yes     |
| **Test-ModuleLocal**      | ✅ Yes          | ✅ Yes     | ❌ No        | ✅ Yes     |
| **AfterAll-ModuleLocal**  | ✅ Yes          | ✅ Yes     | ✅ Yes*      | ✅ Yes     |
| **Get-TestResults**       | ✅ Yes          | ✅ Yes     | ❌ No        | ✅ Yes     |
| **Get-CodeCoverage**      | ✅ Yes          | ✅ Yes     | ❌ No        | ✅ Yes     |
| **Publish-Site**          | ❌ No           | ✅ Yes     | ❌ No        | ❌ No      |
| **Publish-Module**        | ✅ Yes**        | ✅ Yes**   | ✅ Yes***    | ✅ Yes**   |

- \* Runs for cleanup if tests were started
- \*\* Only when all tests/coverage/build succeed
- \*\*\* Cleans up prerelease versions and tags created for the abandoned PR (when `Publish.Module.AutoCleanup` is
  enabled)

A job that is enabled by this matrix can still be skipped by a setting (for example `Test.Skip`) or because the pull
request changed no [important files](../guides/calling-the-workflow.md#important-file-change-detection).

## Related

- [Pipeline stages](pipeline-stages.md) — what each job does.
- [Settings](settings.md) — how to disable individual stages.
