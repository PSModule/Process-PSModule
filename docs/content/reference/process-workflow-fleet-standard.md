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

This YAML is a recommendation derived from the v8 interface and fleet evidence. It is not an approved standard.
Issue [#514](https://github.com/PSModule/Process-PSModule/issues/514) must record agreement on the following structural
decisions before canonical guides, templates, or consumer workflows adopt it:

| Decision | Candidate | Alternatives still open |
| --- | --- | --- |
| Wrapper scope | Exactly one reusable-workflow job. | Permit repository-specific jobs in the same file, or define pre/post extension jobs. |
| Trigger ownership | The caller owns manual, schedule, default-branch push, and pull-request triggers. | Move some trigger policy into separate workflows or omit selected event classes. |
| Pull-request activities | Keep all six listed activity types. | Reduce the activity list if a v8 behavior is intentionally unsupported. |
| Concurrency | Use the PR-number-or-ref key and cancel only superseded pull-request runs. | Use separate groups per event class or disable cancellation for all runs. |
| Permissions | Set top-level permissions to empty and grant only `contents: read`, `pages: write`, and `id-token: write` to the caller job. | Define a narrower profile for repositories that do not publish Pages. |
| Fork behavior | Invoke the reusable workflow unconditionally; Plan classifies normal fork `pull_request` events into restricted read-only validation and rejects `pull_request_target` until separately designed. | Omit fork validation or design a separate `pull_request_target` trust boundary. |
| Credentials | Explicitly map the three v8 credentials. | Define a narrower credential profile for repositories that cannot publish. |
| Optional surface | Permit only documented `TestData`, workflow inputs, schedule timing, and presentation metadata. | Allow additional extension points after naming and compatibility rules are agreed. |

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

## Candidate common elements

| Element | Candidate requirement | Reason |
| --- | --- | --- |
| Identity | Keep the candidate file, workflow, and job names shown above. | Stable discovery, status checks, and fleet maintenance. |
| Pull requests | Target `main` and keep all six listed activity types. | CI, prerelease publication, label changes, and closed-PR cleanup depend on them. |
| Default-branch push | Keep `push.branches: [main]`. | `v8` authorizes stable releases from the tested default-branch push. |
| Manual dispatch | Keep `workflow_dispatch`. | Provides the documented default-branch manual release and recovery path. |
| Schedule | Keep a scheduled health run. | Exercises current dependencies even when repository code is unchanged. |
| Concurrency | Use the PR-number-or-ref key and cancel only pull-request runs. | Pull-request changes converge promptly while non-pull-request runs serialize by ref. |
| Permissions | Use empty top-level permissions and the three caller-job permissions shown above. | Repository-local reads and Pages/OIDC stay narrow; App tokens provide broader authority. |
| Fork authorization | Leave the caller job unconditional. | Plan grants normal fork `pull_request` events only restricted read-only validation capabilities and rejects `pull_request_target` before credentials or repository-defined code run. |
| Reference | Use the intended internal floating major tag (`v8`) after tag governance is enforced. | Compatible owned releases roll out centrally; breaking releases require a new major and campaign. |
| Credentials | Explicitly map the three required secrets. | Satisfies the `v7+` contract and prevents unrelated secret inheritance. |
| Scope | Keep the caller as a single delegation job. | Repository-specific automation remains independently understandable and maintainable. |

## Candidate optional elements

These are evidence-based candidate variations, not approved policy.

| Option | When it is appropriate | Constraint |
| --- | --- | --- |
| `TestData` secret | Module-local tests need caller-defined secrets or variables. | Use the documented compact single-line JSON object and expose only required values. |
| `with.SettingsPath` | The settings file is not `.github/PSModule.yml`. | Prefer the standard path for normal module repositories. |
| `with.WorkingDirectory` | The module is intentionally rooted below the repository root. | Keep the default `.` for the standard layout. |
| `with.ImportantFilePatterns` | A caller must override change detection at the workflow boundary. | Prefer stable configuration in `.github/PSModule.yml`; the supplied list replaces all defaults. |
| `with.Debug`, `Verbose`, `Version`, or `Prerelease` | A deliberate diagnostic or dependency-selection scenario needs it. | Do not hard-code temporary diagnostics into the fleet baseline. |
| Schedule time | Health runs need staggering or a repository-specific maintenance window. | Keep at least one documented schedule unless the repository records why health runs are unnecessary. |
| `run-name` | A repository needs clearer run presentation. | Presentation must not change job names or routing behavior. |

## Variations requiring a decision

The following differ from the candidate. They are inventory classifications, not policy violations, until #514 records
an approved structure:

- `secrets: inherit`;
- `APIKey` or `APIKEY` mappings from the pre-`v7` contract;
- any Process-PSModule reference other than the intended major tag (`v8`), including a branch, `latest`, minor tag,
  exact patch tag, or full commit SHA;
- missing `push` or `unlabeled` triggers;
- a `cancel-in-progress` expression other than `github.event_name == 'pull_request'` or the old ref-only concurrency key;
- trigger-level path filters that bypass Process-PSModule important-file evaluation;
- unrelated additional jobs in the caller wrapper;
- omitted documented permissions without a verified settings-based least-privilege profile.

The candidate caller invokes the reusable workflow for fork-originated `pull_request` events. Plan classifies them into a
restricted, read-only validation mode that permits only repository-local checkout, build, lint, and test with the
least-privilege built-in token. It emits explicit capabilities that prohibit App-token creation, publication, mutation,
Pages deployment, cleanup, and user-facing reporting. `pull_request_target` remains unsupported and Plan must reject it
before credentials or repository-defined code run; issue [#514](https://github.com/PSModule/Process-PSModule/issues/514)
must approve any separate trust boundary for that event.

The controlled upstream `v8` Plan implementation derives that restricted envelope first from immutable GitHub event
metadata, including fork, base, and head identities. It may then use fork settings and checked-out files only as
untrusted validation and build inputs; they cannot enable credentials, broaden permissions, or change the capability
envelope. This permits ordinary fork contributors to receive the standard workflow green/red validation without
configuring secrets.

The candidate keeps repository-specific automation in a separate workflow file. That keeps the Process-PSModule wrapper
identical enough for automated comparison while allowing modules to own unrelated schedules, generation, or integration
tasks.

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
| Custom input | 1 | Update `Yaml` last while preserving `TestData` and `ImportantFilePatterns`. |

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

After approval, each leaf would apply the agreed caller, retain the agreed optional mappings, and prove the PR path
before merge. Advance one wave only after the previous wave's push run completes without an unintended release.
Completion would require a fresh inventory showing `60/60` on `v8`, the agreed trigger and concurrency contract,
the agreed credential mapping, and no unresolved review or CI failures.
