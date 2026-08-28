---
title: Scenario matrix
description: Which Process-PSModule jobs run for each trigger scenario — open pull request, default-branch push, closed pull request, and default-branch manual run.
---

# Scenario matrix

This table shows when each job runs based on the trigger scenario. It is the single source of truth for job
execution; other pages link here rather than repeating it.

| Job                       | Open/Updated PR | Default-branch push | Closed PR | Default-branch manual run |
| ------------------------- | --------------- | ------------------- | --------- | ------------------------- |
| **Plan**                  | ✅ Always       | ✅ Always           | ✅ Always | ✅ Always                 |
| **Lint-Repository**       | ✅ Yes          | ❌ No               | ❌ No     | ❌ No                     |
| **Build-Module**          | ✅ Yes          | ✅ Yes              | ❌ No     | ✅ Yes                    |
| **Build-Docs**            | ✅ Yes          | ✅ Yes              | ❌ No     | ✅ Yes                    |
| **Build-Site**            | ✅ Yes          | ✅ Yes              | ❌ No     | ✅ Yes                    |
| **Test-SourceCode**       | ✅ Yes          | ✅ Yes              | ❌ No     | ✅ Yes                    |
| **Lint-SourceCode**       | ✅ Yes          | ✅ Yes              | ❌ No     | ✅ Yes                    |
| **Test-Module**           | ✅ Yes          | ✅ Yes              | ❌ No     | ✅ Yes                    |
| **BeforeAll-ModuleLocal** | ✅ Yes          | ✅ Yes              | ❌ No     | ✅ Yes                    |
| **Test-ModuleLocal**      | ✅ Yes          | ✅ Yes              | ❌ No     | ✅ Yes                    |
| **AfterAll-ModuleLocal**  | ✅ Yes          | ✅ Yes              | ❌ No     | ✅ Yes                    |
| **Get-TestResults**       | ✅ Yes          | ✅ Yes              | ❌ No     | ✅ Yes                    |
| **Get-CodeCoverage**      | ✅ Yes          | ✅ Yes              | ❌ No     | ✅ Yes                    |
| **Publish-Site**          | ❌ No           | ✅ Yes*             | ❌ No     | ✅ Yes*                   |
| **Publish-Module**        | ✅ Prerelease†  | ✅ Stable†§         | ✅ Cleanup‡ | ✅ Stable†§             |

- \* Only when `Publish.Site.Skip` is `false`.
- † Requires an important change and all required build, test, and coverage gates to succeed. An open PR also requires
  the configured prerelease label (`release:pre-release` by default) and a resolved bump. A default-branch push uses labels and notes only when its SHA exactly matches a merged pull
  request; otherwise it releases a Patch version with commit-based notes. A default-branch manual run is also a Patch
  release with commit-based notes.
- ‡ Cleans up prerelease versions and tags for the closed pull request when `Publish.Module.AutoCleanup` is enabled;
  it does not publish a stable release.
- § A successful stable release also retries prerelease cleanup when `Publish.Module.AutoCleanup` is enabled.

A job that is enabled by this matrix can still be skipped by a setting (for example `Test.Skip`) or because an open PR
or default-branch push changed no
[important files](../guides/calling-the-workflow.md#important-file-change-detection). Default-branch manual dispatch
runs are intentionally treated as important.

## Related

- [Pipeline stages](pipeline-stages.md) — what each job does.
- [Settings](settings.md) — how to disable individual stages.
