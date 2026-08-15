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
    -TargetReference v8 `
    -JsonPath ./output/process-workflows.json `
    -MarkdownPath ./docs/content/reference/process-workflow-fleet-inventory.md
```

GitHub mode uses the authenticated `gh` session, including `GH_TOKEN`. To inventory checked-out repositories without
GitHub discovery, use the local parameter set:

```powershell
./.github/scripts/Get-ProcessPSModuleWorkflowInventory.ps1 `
    -Path C:\Repos, C:\Users\me\.copilot\repos `
    -TargetReference v8 `
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
- 15 callers explicitly map only an `APIKey` or `APIKEY` secret.
- Four more callers (`Confluence`, `GitHub`, `Jwt`, and `Yaml`) map the old API key plus `TestData`, for 19 explicit
  API-key callers in total.
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
    uses: PSModule/Process-PSModule/.github/workflows/workflow.yml@v8
    secrets:
      PSGALLERY_API_KEY: ${{ secrets.PSGALLERY_API_KEY }}
      GitHubAppClientId: ${{ secrets.SHELLY_CLIENT_ID }}
      GitHubAppPrivateKey: ${{ secrets.SHELLY_PRIVATE_KEY }}
```

The `v8` reference is the controlled moving major tag for this PSModule-owned workflow. On 2026-08-15, `v8`, `v8.0`,
and the immutable `v8.0.0` release tag all resolve to commit `5a11e8e8b018faf97017e0416f136a751c026713`.
`Release-GHRepository` creates and advances major and minor tags by default, while the organization tag ruleset prevents
deletion or non-fast-forward updates of exact `*.*.*` release tags.

The effective repository rulesets currently protect exact release tags but do not restrict movement of `v8` itself.
Release automation is therefore the operational owner, but actors with sufficient contents access are not yet blocked
from moving the major tag manually. Enforce release-identity-only governance for moving tags before migrating the fleet
to `@v8`; until then, consumers must retain immutable SHA references.

### Owned and external references

| Automation source | Standard reference | Update model |
| --- | --- | --- |
| PSModule-owned action or reusable workflow | Floating major tag such as `@v8` | Compatible patch and minor releases advance the major tag through controlled release automation. |
| External action or reusable workflow | Full commit SHA with a trailing release-version comment | Dependabot proposes reviewed SHA updates; upstream cannot silently change the referenced code. |

A major tag never crosses a breaking boundary. `v8` remains on the latest compatible `8.x` release; `v9` begins a new
fleet campaign. Branch names, `latest`, floating minor tags, and unqualified targets are not accepted pins.

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
| Reference | Use the approved internal floating major tag (`v8`). | Compatible owned releases roll out centrally; breaking releases require a new major and campaign. |
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
- any Process-PSModule reference other than the approved major tag (`v8`), including a branch, `latest`, minor tag,
  exact patch tag, or full commit SHA;
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

This research does not change consumer repositories. The campaign should use the stable slug
`process-v8-major-tag`, one delivery issue, branch, and early draft pull request per repository, and these waves:

| Wave | Repositories | Change profile |
| --- | ---: | --- |
| Pilot | 1 | Update `Template-PSModule` first and use its final caller as the generated-repository reference. |
| Inherited secrets | 41 | Replace `secrets: inherit` with the three explicit `v8` credential mappings. |
| Old API key only | 14 | Replace `APIKey`/`APIKEY` with the three explicit mappings; excludes the template pilot. |
| Test data | 3 | Preserve each existing `TestData` payload while replacing the old API key contract. |
| Custom input | 1 | Update `Yaml` last while preserving `TestData` and `ImportantFilePatterns`. |

Before opening leaves:

1. Confirm `v8` and `v8.0.0` resolve to the same tested release commit.
2. Restrict moving major-tag updates to the controlled release identity. Do not start the consumer rollout while another
   identity can move `v8`; retain immutable SHA references until this gate is enforced.
3. Have an organization administrator confirm `PSGALLERY_API_KEY`, `SHELLY_CLIENT_ID`, and `SHELLY_PRIVATE_KEY` coverage
   in Actions and Dependabot scope. The inventory token can list repository-local secrets but receives `403` for
   organization secret visibility, so inherited coverage is currently unresolved.
4. Refresh the inventory with `-TargetReference v8`; the starting target count should be `0/60`.
5. Confirm workflow-only changes are not important release changes. The fleet defaults match only `src/` and
   `README.md`; `Yaml` explicitly matches `src/`, `tests/`, and `README.md`, so this campaign should not publish modules.

Each leaf applies the common caller, retains only the supported optional mappings, and proves the PR path before merge.
Advance one wave only after the previous wave's push run completes without an unintended release. Completion requires a
fresh inventory showing `60/60` on `v8`, the complete trigger/concurrency contract, explicit credentials, no inherited
secrets or old API-key mappings, and no unresolved review or CI failures.
