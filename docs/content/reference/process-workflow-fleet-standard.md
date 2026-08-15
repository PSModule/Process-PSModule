---
title: Process-PSModule caller workflow fleet standard
description: Fleet research and proposed required and optional caller workflow elements for Process-PSModule consumers.
---

# Process-PSModule caller workflow fleet standard

This page records the 2026-08-15 fleet research used to propose a common caller workflow for PowerShell module
repositories. It is a proposal for review before the consumer repositories are changed.

The generated [workflow fleet inventory](process-workflow-fleet-inventory.md) lists every matching repository and
workflow. Refresh it with:

```powershell
./.github/scripts/Get-ProcessPSModuleWorkflowInventory.ps1 `
    -Organization PSModule `
    -JsonPath ./output/process-workflows.json `
    -MarkdownPath ./docs/content/reference/process-workflow-fleet-inventory.md
```

GitHub mode uses the authenticated `gh` session, including `GH_TOKEN`. To inventory checked-out repositories without
GitHub discovery, use the local parameter set:

```powershell
./.github/scripts/Get-ProcessPSModuleWorkflowInventory.ps1 `
    -Path C:\Repos, C:\Users\me\.copilot\repos `
    -JsonPath ./output/process-workflows.json `
    -MarkdownPath ./output/process-workflows.md
```

## Current fleet

The authenticated organization scan found 60 default-branch caller workflows among 85 active repositories. Every
caller has the same structural baseline:

| Aspect | Observed value | Coverage |
| --- | --- | ---: |
| File | `.github/workflows/Process-PSModule.yml` | 60/60 |
| Workflow name | `Process-PSModule` | 60/60 |
| Run name | Not set | 60/60 |
| Reusable-workflow job | `Process-PSModule` | 60/60 |
| Reusable-workflow job condition | Not set | 60/60 |
| Events | `workflow_dispatch`, daily `schedule`, `pull_request` | 60/60 |
| Pull-request branch | `main` | 60/60 |
| Pull-request types | `closed`, `opened`, `reopened`, `synchronize`, `labeled` | 60/60 |
| Schedule | `0 0 * * *` | 60/60 |
| Concurrency group | `${{ github.workflow }}-${{ github.ref }}` | 60/60 |
| Cancel in progress | `true` | 60/60 |
| Permissions | `contents`, `pull-requests`, `statuses`, `pages`, and `id-token`: `write` | 60/60 |
| Additional jobs | None | 60/60 |

The uniform wrapper is a strong starting point, but it predates the two latest breaking releases:

- `v7.0.0` requires explicit PowerShell Gallery and GitHub App credentials.
- `v8.0.0` moves stable publication to a default-branch `push`, adds `unlabeled` routing, and requires non-cancelling
  pull-request-or-ref concurrency.

No current caller has the `v8.0.0` trigger and concurrency contract. The fleet spans nine older versions:

| Version | Repositories |
| --- | ---: |
| `v5.4.6` | 35 |
| `v6.1.13` | 6 |
| `v6.1.4` | 5 |
| `v5.5.0` | 4 |
| `v6.1.15` | 4 |
| `v5.5.7` | 3 |
| `v5.4.3` | 1 |
| `v6.1.16` | 1 |
| `v6.1.19` | 1 |

Secret forwarding is the only widespread caller variation:

- 41 callers use `secrets: inherit`.
- 15 callers explicitly map an `APIKey` or `APIKEY` secret.
- `Confluence`, `GitHub`, `Jwt`, and `Yaml` map the old API key plus `TestData`.
- `Yaml` is the only caller with a `with:` override (`ImportantFilePatterns`).

The case difference in the old API key name is historical drift, not a supported option in the current contract.

## Proposed standard

The standard caller should be:

```yaml
name: Process-PSModule

on:
  workflow_dispatch:
  schedule:
    - cron: '0 0 * * *'
  push:
    branches:
      - main
  pull_request:
    branches:
      - main
    types:
      - closed
      - opened
      - reopened
      - synchronize
      - labeled
      - unlabeled

concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: false

permissions:
  contents: write
  pull-requests: write
  statuses: write
  pages: write
  id-token: write

jobs:
  Process-PSModule:
    if: ${{ github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name == github.repository }}
    uses: PSModule/Process-PSModule/.github/workflows/workflow.yml@5a11e8e8b018faf97017e0416f136a751c026713 # v8.0.0
    secrets:
      PSGALLERY_API_KEY: ${{ secrets.PSGALLERY_API_KEY }}
      GitHubAppClientId: ${{ secrets.SHELLY_CLIENT_ID }}
      GitHubAppPrivateKey: ${{ secrets.SHELLY_PRIVATE_KEY }}
```

The full commit SHA is the machine-enforced pin. The version comment is required for humans and Dependabot.

## Required elements

| Element | Requirement | Reason |
| --- | --- | --- |
| Identity | Keep the standard file, workflow, and job names shown above. | Stable discovery, status checks, and fleet maintenance. |
| Pull requests | Target `main` and keep all six listed activity types. | CI, prerelease publication, label changes, and closed-PR cleanup depend on them. |
| Default-branch push | Keep `push.branches: [main]`. | `v8` authorizes stable releases from the tested default-branch push. |
| Manual dispatch | Keep `workflow_dispatch`. | Provides the documented default-branch manual release and recovery path. |
| Schedule | Keep a scheduled health run. | Exercises current dependencies even when repository code is unchanged. |
| Concurrency | Use the PR-number-or-ref key with `cancel-in-progress: false`. | Cleanup and stable release runs stay distinct; release mutations queue instead of being interrupted. |
| Permissions | Declare the five documented permissions explicitly. | The called workflow cannot elevate caller permissions. |
| Fork guard | Skip pull requests whose head repository differs from `github.repository`. | GitHub withholds the required repository secrets from fork pull requests. |
| Reference | Pin the latest approved release to its full commit SHA and retain the version comment. | Immutable supply-chain reference with readable update context. |
| Credentials | Explicitly map the three required secrets. | Satisfies the `v7+` contract and prevents unrelated secret inheritance. |
| Scope | Keep the caller as a single delegation job. | Repository-specific automation remains independently understandable and maintainable. |

## Supported optional elements

Optional elements are supported contract variations, not permission to retain historical drift.

| Option | When it is appropriate | Constraint |
| --- | --- | --- |
| `TestData` secret | Module-local tests need caller-defined secrets or variables. | Use the documented compact single-line JSON object and expose only required values. |
| `with.SettingsPath` | The settings file is not `.github/PSModule.yml`. | Prefer the standard path for normal module repositories. |
| `with.WorkingDirectory` | The module is intentionally rooted below the repository root. | Keep the default `.` for the standard layout. |
| `with.ImportantFilePatterns` | A caller must override change detection at the workflow boundary. | Prefer stable configuration in `.github/PSModule.yml`; the supplied list replaces all defaults. |
| `with.Debug`, `Verbose`, `Version`, or `Prerelease` | A deliberate diagnostic or dependency-selection scenario needs it. | Do not hard-code temporary diagnostics into the fleet baseline. |
| Schedule time | Health runs need staggering or a repository-specific maintenance window. | Keep at least one documented schedule unless the repository records why health runs are unnecessary. |
| `run-name` | A repository needs clearer run presentation. | Presentation must not change job names or routing behavior. |

## Out-of-standard variations

The following are migration defects or require a documented exception:

- `secrets: inherit`;
- `APIKey` or `APIKEY` mappings from the pre-`v7` contract;
- a mutable tag instead of a full commit SHA;
- missing `push` or `unlabeled` triggers;
- `cancel-in-progress: true` or the old ref-only concurrency key;
- trigger-level path filters that bypass Process-PSModule important-file evaluation;
- unrelated additional jobs in the caller wrapper;
- omitted documented permissions without a verified settings-based least-privilege profile.

Fork-originated pull requests are skipped by the standard caller because reusable-workflow caller jobs cannot select a
GitHub Environment and repository secrets are unavailable to forks. Supporting fork CI requires a separate, secret-free,
read-only validation workflow; removing the guard is not a supported shortcut.

Repository-specific automation should normally use a separate workflow file. That keeps the Process-PSModule wrapper
identical enough for automated comparison while allowing modules to own unrelated schedules, generation, or integration
tasks.

## Rollout boundary

This research does not change consumer repositories. A fleet campaign should use one delivery issue and one early draft
pull request per repository, preserve the supported optional mappings discovered here, and replace every historical
credential mapping with the explicit `v8` contract. The inventory should be refreshed immediately before creating the
campaign leaves and again before declaring the campaign complete.
