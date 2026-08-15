---
title: Process-PSModule caller workflow candidate
description: Fleet research and candidate required and optional caller workflow elements for Process-PSModule consumers.
---

# Process-PSModule caller workflow candidate

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

## Candidate for discussion

The current candidate is:

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
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

permissions: {}

jobs:
  Process-PSModule:
    permissions:
      contents: read
      pages: write
      id-token: write
    uses: PSModule/Process-PSModule/.github/workflows/workflow.yml@v8
    secrets:
      PSGALLERY_API_KEY: ${{ secrets.PSGALLERY_API_KEY }}
      GitHubAppClientId: ${{ secrets.SHELLY_CLIENT_ID }}
      GitHubAppPrivateKey: ${{ secrets.SHELLY_PRIVATE_KEY }}
```

Modules whose local tests require repository-specific data may add the optional secret mapping:

```yaml
      TestData: >-
        {"secrets":{"TOKEN":"${{ secrets.TEST_TOKEN }}"},"variables":{"ENDPOINT":"${{ vars.TEST_ENDPOINT }}"}}
```

The reusable workflow exports only the declared entries to module-local test setup, tests, and teardown. Callers omit
`TestData` when no module-local test data is required.

This YAML is a recommendation derived from the v8 interface and fleet evidence. It is not an approved standard.
Issue [#514](https://github.com/PSModule/Process-PSModule/issues/514) must record agreement on the following structural
decisions before canonical guides, templates, or consumer workflows adopt it:

| Decision | Candidate | Alternatives still open |
| --- | --- | --- |
| Contract scope | Keep the file identical to the canonical template except for optional `TestData`. | Selected for the candidate; repository-owned jobs use separate workflow files. |
| Trigger ownership | The caller owns manual, schedule, default-branch push, and pull-request triggers. | Move some trigger policy into separate workflows or omit selected event classes. |
| Pull-request activities | Keep all six listed activity types. | Reduce the activity list if a v8 behavior is intentionally unsupported. |
| Concurrency | Use the workflow plus PR-number-or-full-ref key and cancel only pull-request runs. | Selected for the candidate: PR reconciliation must be resumable; non-PR runs serialize by full ref. |
| Permissions | Default deny at workflow level, then grant the caller job `contents: read`, `pages: write`, and `id-token: write`. | Selected for the candidate: use `GITHUB_TOKEN` for repository-local, non-user-facing platform operations and App tokens for user-facing or otherwise unsupported operations. |
| Fork behavior | Keep the caller unconditional; classify fork pull requests as restricted read-only validation in `Plan`. | Selected for the candidate; execution policy belongs to Process-PSModule rather than every consumer. |
| Credentials | Explicitly map the three v8 credentials; optionally map `TestData` when module-local tests need it. | Define a narrower credential profile for repositories that cannot publish. |
| Optional surface | Permit only the documented `TestData` secret mapping. | Selected for the candidate; every other caller-contract field matches the canonical template. |

The `v8` reference is the controlled moving major tag for this PSModule-owned workflow. On 2026-08-15, `v8`, `v8.0`,
and the immutable `v8.0.0` release tag all resolve to commit `5a11e8e8b018faf97017e0416f136a751c026713`.
`Release-GHRepository` creates and advances major and minor tags by default, while the organization tag ruleset prevents
deletion or non-fast-forward updates of exact `*.*.*` release tags.

The effective repository rulesets currently protect exact release tags but do not restrict movement of `v8` itself.
Release automation is therefore the operational owner, but actors with sufficient contents access are not yet blocked
from moving the major tag manually. Enforce release-identity-only governance for moving tags before migrating the fleet
to `@v8`; until then, consumers must retain immutable SHA references.

The reusable workflow remains at `.github/workflows/workflow.yml`. A private cross-repository experiment on 2026-08-15
confirmed that GitHub rejects a root-level reusable workflow reference with
`references to workflows must be rooted in '.github/workflows'`, even when the provider repository grants the caller
the required Actions access.

### Owned and external references

| Automation source | Standard reference | Update model |
| --- | --- | --- |
| PSModule-owned action or reusable workflow | Floating major tag such as `@v8` | Compatible patch and minor releases advance the major tag through controlled release automation. |
| External action or reusable workflow | Full commit SHA with a trailing release-version comment | Dependabot proposes reviewed SHA updates; upstream cannot silently change the referenced code. |

A major tag never crosses a breaking boundary. `v8` remains on the latest compatible `8.x` release; `v9` begins a new
fleet campaign. Branch names, `latest`, floating minor tags, and unqualified targets are not accepted pins.

## Candidate common elements

| Element | Candidate requirement | Reason |
| --- | --- | --- |
| Identity | Keep the candidate file, workflow, and job names shown above. | Stable discovery, status checks, and fleet maintenance. |
| Pull requests | Target `main` and keep all six listed activity types. | CI, prerelease publication, label changes, and closed-PR cleanup depend on them. |
| Default-branch push | Keep `push.branches: [main]`. | `v8` authorizes stable releases from the tested default-branch push. |
| Manual dispatch | Keep `workflow_dispatch`. | Provides the documented default-branch manual release and recovery path. |
| Schedule | Keep a scheduled health run. | Exercises current dependencies even when repository code is unchanged. |
| Concurrency | Use the PR-number-or-ref key and cancel only pull-request runs. | New PR events supersede older declarative reconciliation runs; same-ref push, dispatch, and schedule runs serialize without cancellation. |
| Permissions | Set top-level `permissions: {}` and grant only `contents: read`, `pages: write`, and `id-token: write` to the caller job. | Checkout and Pages remain repository-local built-in capabilities; user-facing interactions and operations outside the built-in token boundary use scoped GitHub App tokens. |
| Event gate | Keep the caller unconditional and authorize capabilities in `Plan`. | The reusable workflow owns execution policy; fork pull requests may validate but cannot obtain App credentials, publish, deploy, clean up, or mutate repository state. |
| Reference | Use the intended internal floating major tag (`v8`) after tag governance is enforced. | Compatible owned releases roll out centrally; breaking releases require a new major and campaign. |
| Credentials | Explicitly map the three required secrets. | Satisfies the `v7+` contract and prevents unrelated secret inheritance. |
| Scope | Require exactly the canonical `Process-PSModule` workflow file. | Repository-owned jobs use separate workflow files. |

## Allowed caller variation

The only conforming variation from the canonical template is the optional `TestData` secret mapping shown above.
Callers use it only when module-local tests need caller-defined secrets or variables, and expose only the required
values in the documented `secrets` and `variables` maps.

Every other field in the Process-PSModule workflow file matches the template exactly. Callers do not add jobs, `with:`
inputs, change schedule timing, add `run-name`, add a caller condition, or broaden permissions. Repository-owned
automation uses separate workflow files.

## Variations requiring a decision

The following differ from the candidate. They are inventory classifications, not policy violations, until #514 records
an approved structure:

- `secrets: inherit`;
- `APIKey` or `APIKEY` mappings from the pre-`v7` contract;
- any Process-PSModule reference other than the intended major tag (`v8`), including a branch, `latest`, minor tag,
  exact patch tag, or full commit SHA;
- missing `push` or `unlabeled` triggers;
- a concurrency key other than workflow plus PR number or full ref, or cancellation behavior other than pull-request-only;
- a caller-level fork or event-authorization condition;
- trigger-level path filters that bypass Process-PSModule important-file evaluation;
- any additional job in `.github/workflows/Process-PSModule.yml`;
- any `with:` input, including `Debug`, `ImportantFilePatterns`, `Prerelease`, `SettingsPath`, `Verbose`, `Version`, or
  `WorkingDirectory`;
- a schedule other than the canonical `0 0 * * *`;
- `run-name`;
- caller permissions beyond `contents: read`, `pages: write`, and `id-token: write`.

Use the built-in `GITHUB_TOKEN` for non-user-facing operations confined to the calling repository, including checkout
and the standard GitHub Pages deployment. Create narrowly scoped GitHub App installation tokens for user-facing
interactions such as pull-request comments, labels, statuses, releases, and release cleanup, and whenever the built-in
token cannot provide the required repository or cross-repository access. Tokens remain step-scoped and must not fall
back silently from App authorization to broader built-in-token authority.

The reusable workflow's Plan job classifies fork-originated `pull_request` events as restricted read-only validation.
It may allow repository-local checkout, build, lint, and test with least-privilege built-in access, but must explicitly
deny App-token creation, Gallery access, publication, Pages deployment, cleanup, and repository or user-facing
mutations. The controlled upstream Plan implementation derives this security envelope from GitHub event metadata before
it interprets repository settings or executes checked-out repository code. Fork-controlled files and settings remain
untrusted build inputs and cannot broaden the planned capabilities. Every downstream job, including jobs using
`always()`, must require a successful valid Plan and the planned capability for its operation before running or
evaluating Settings. Privileged-context events such as
`pull_request_target` remain unsupported unless separately designed to prevent untrusted code from crossing the
credential boundary.

The contract applies to the entire `.github/workflows/Process-PSModule.yml` file shown above. Repository-owned
automation uses separate workflow files so the canonical caller remains directly comparable across the fleet.

## Rollout boundary

This research does not approve or change consumer repositories. If #514 approves the candidate, the campaign would use
the stable slug
`process-v8-major-tag`, one delivery issue, branch, and early draft pull request per repository, and these waves:

| Wave | Repositories | Change profile |
| --- | ---: | --- |
| Pilot | 1 | Update `Template-PSModule` first and use its final caller as the generated-repository reference. |
| Inherited secrets | 41 | Replace `secrets: inherit` with the three explicit `v8` credential mappings. |
| Old API key only | 14 | Replace `APIKey`/`APIKEY` with the three explicit mappings; excludes the template pilot. |
| Test data | 3 | Preserve each existing `TestData` payload while replacing the old API key contract. |
| Custom input | 1 | Update `Yaml` last, preserve `TestData`, and remove the caller-level `ImportantFilePatterns` override. |

Before opening leaves:

1. Record approval of every structural decision above in #514 and update the canonical guides and template.
2. Confirm `v8` and `v8.0.0` resolve to the same tested release commit.
3. Restrict moving major-tag updates to the controlled release identity. Do not start the consumer rollout while another
   identity can move `v8`; retain immutable SHA references until this gate is enforced.
4. Have an organization administrator confirm `PSGALLERY_API_KEY`, `SHELLY_CLIENT_ID`, and `SHELLY_PRIVATE_KEY` coverage
   in Actions and Dependabot scope. The inventory token can list repository-local secrets but receives `403` for
   organization secret visibility, so inherited coverage is currently unresolved.
5. Refresh the inventory with `-TargetReference v8`; the starting target count should be `0/60`.
6. Confirm workflow-only changes are not important release changes. The fleet defaults match only `src/` and
   `README.md`; `Yaml` explicitly matches `src/`, `tests/`, and `README.md`, so this campaign should not publish modules.

After approval, each leaf would apply the canonical caller, retain optional `TestData` only where required, and prove the PR path
before merge. Advance one wave only after the previous wave's push run completes without an unintended release.
Completion would require a fresh inventory showing `60/60` on `v8`, the agreed trigger and concurrency contract,
the agreed credential mapping, and no unresolved review or CI failures.
