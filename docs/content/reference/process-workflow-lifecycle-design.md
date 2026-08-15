---
title: Process-PSModule workflow lifecycle design
description: Architecture for Process-PSModule event routing, stamped artifacts, recovery release notes, and concurrency isolation.
---

# Process-PSModule workflow lifecycle design

This design defines the Process-PSModule lifecycle architecture. It implements the
[workflow lifecycle specification](process-workflow-lifecycle-specification.md) through a single policy authority,
immutable release records, and a general release executor.

## Architecture

Plan is the sole lifecycle-policy authority. It resolves each event before build and release work, emits enriched
Settings, and gates downstream execution. Build, validation, release, cleanup, and reporting consume Settings without
reinterpreting events, labels, or repository settings.

One general module release action or reusable workflow consumes Settings and performs stable release, prerelease,
recovery or resume, cleanup-only, or no-op actions. It verifies artifacts when required and reconciles only the
requested state.

## Event routing

| Event | Plan classification | Release action | Concurrency | Result |
| --- | --- | --- | --- | --- |
| `workflow_dispatch` on the default branch | Recovery or resume | Stable release or no-op | Full-ref serialization | Rebuild and validate the selected commit; reconstruct unreleased release notes. |
| `schedule` | Published-artifact validation | No-op after validation | Full-ref serialization | Validate the latest published stable artifact and documentation. |
| Fork `pull_request` | Restricted read-only validation | No-op after validation | Pull-request cancellation | Perform repository-local checkout, build, lint, and test only. |
| Pull request `opened`, `reopened`, `synchronize` | Pull-request classification | Prerelease or no-op | Pull-request cancellation | Run validation and execute the planned release action. |
| Pull request `labeled`, `unlabeled` | Pull-request classification refresh | Prerelease, cleanup-only, or no-op | Pull-request cancellation | Resolve the complete current classification and execute its action. |
| Merged pull request `closed` | Post-merge close | No-op | Pull-request cancellation | Leave promotion cleanup to the stable release. |
| Abandoned pull request `closed` | Abandoned-close classification | Cleanup-only | Pull-request cancellation | Reconcile only prereleases owned by the abandoned pull request. |
| Push to the default branch | Stable release | Stable release | Full-ref serialization | Aggregate merged-pull-request intent, publish, and perform promotion cleanup. |

## Caller boundary

The [Process-PSModule caller contract](process-workflow-fleet-standard.md) contains exactly one reusable-workflow call
job and the shared top-level triggers, concurrency, permissions, Plan authorization, and credential boundary that govern
it. Repository-owned jobs MAY coexist in the same workflow file or in separate workflows. They are visible to
conformance reporting and MUST NOT weaken or bypass the Process-PSModule call boundary.

## Event authorization

The caller invokes the reusable workflow without a caller-level fork or event condition. The controlled upstream Plan
implementation derives its security and capability envelope from immutable GitHub event metadata before it interprets
repository settings or executes checked-out code.

For a normal fork `pull_request`, Plan emits a restricted Settings record:

```text
IsFork=true
AllowAppToken=false
AllowPublication=false
AllowMutation=false
```

The restricted route permits only repository-local checkout, build, lint, and test with the least-privilege built-in
token. It provides a green or red validation outcome without contributor secrets. Fork settings and checked-out files
are untrusted validation and build inputs and cannot alter the capability envelope.

Restricted routes do not create App tokens; access PowerShell Gallery; mutate pull requests, statuses, releases, tags,
or assets; perform cleanup; deploy Pages; or run other privileged or user-facing operations. `pull_request_target` is
rejected before credentials or repository-defined code run.

Every downstream job first requires successful Plan execution and valid Settings. Jobs using `always()` apply this gate
before their own failure-handling logic. Privileged jobs also require their relevant Settings capability and never parse
missing or invalid Settings.

## Settings contract

Settings contains one immutable release record:

| Field | Purpose |
| --- | --- |
| Event and run type | Identifies the GitHub event and lifecycle classification. |
| Event action | Preserves the pull-request activity or non-pull-request action. |
| Pull-request identity, state, and merge status | Distinguishes active, merged, and abandoned outcomes. |
| Authorization capabilities and evidence | Records `IsFork`, immutable event metadata, and App-token, publication, and mutation capabilities. |
| Labels and repository settings result | Records the inputs resolved by Plan. |
| Version bump and base version | Defines the version transition. |
| Manifest version, prerelease identifier, and full version or tag | Defines the only version and tag permitted in an artifact and release. |
| Target commit | Binds validation, artifact, and release to one source revision. |
| Resolved release action and create or publish flags | Selects stable, prerelease, recovery or resume, cleanup-only, or no-op execution. |
| Cleanup intent and artifact identity | Defines the exact artifacts release execution may reconcile. |
| Release-note source and boundary | Identifies merged pull requests eligible for release notes. |

## Artifact and version boundary

Build stamps exactly the manifest version and prerelease identifier in Settings into the module artifact. Before any
package, tag, or release becomes visible, release execution verifies that the artifact equals the Settings record. A
mismatch stops execution; release execution does not recalculate versions or retag artifacts.

## Repository authorization

The caller uses the following job boundary:

```yaml
permissions: {}
jobs:
  Process-PSModule:
    permissions:
      contents: read
      pages: write
      id-token: write
    secrets:
      PSGALLERY_API_KEY: ${{ secrets.PSGALLERY_API_KEY }}
      GitHubAppClientId: ${{ secrets.SHELLY_CLIENT_ID }}
      GitHubAppPrivateKey: ${{ secrets.SHELLY_PRIVATE_KEY }}
```

These explicit secret mappings are required. `secrets: inherit` is prohibited. The only optional secret mapping is
`TestData` for module-local tests:

```yaml
      TestData: ${{ secrets.TestData }}
```

When present, `TestData` contains a JSON object with separate `secrets` and `variables` maps. It is omitted when
unused. It is the only permitted variation from the canonical caller template. Callers do not declare `run-name`,
alter the canonical schedule, add a caller condition, or pass `with:` inputs. Repository-owned jobs may coexist
outside this caller contract.

Built-in `GITHUB_TOKEN` authorizes checkout, repository-local reads, and standard Pages/OIDC deployment within the job
boundary. Step-scoped GitHub App installation tokens authorize pull-request comments and labels, commit statuses and
check-facing reporting, releases, tags, assets, and cleanup. An App-required operation fails before its API request or
mutation when its App token is unavailable; it never falls back to the built-in token.

Restricted fork Settings override the caller job boundary: no App token is created, no Pages deployment runs, and no
repository mutation or user-facing action runs.

## Stable aggregation and recovery

Every stable push and recovery target finds the last successfully published stable version and associated target commit,
then aggregates merged pull requests through the requested target commit. The aggregated release intent determines the
stable version and release-note range.

Manual recovery accepts a selected default-branch commit and applies the same aggregation and validation path as a
default-branch push. It returns no-op when a stable publication already covers that commit. Release notes use the
ordered, de-duplicated merged-pull-request range rather than manual-dispatch payload data.

## Scheduled validation and close behavior

Scheduled validation resolves the latest published stable version as input and sets a validation-only mutation class.
Publication and cleanup execution do not run.

A merged pull-request close performs no prerelease cleanup. The successful default-branch stable release owns promotion
cleanup. An abandoned pull-request close receives a pull-request-scoped artifact set and performs only prerelease
cleanup. Broad prerelease deletion requires its own exclusive scope and does not share the abandoned-close route.

## Concurrency and recovery

The caller uses:

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
```

All pull-request events for one pull request share a group and cancel superseded runs. Push, manual-dispatch, and
scheduled events use full `github.ref`, do not cancel a running run, and serialize by ref. GitHub retains one running
and one pending run per group; a later same-group event can replace an earlier pending run. Full `github.ref` prevents
branch and tag name collisions that `github.ref_name` cannot distinguish.

Cancellation leaves only transient partial state. A subsequent `synchronize`, `labeled`, `unlabeled`, or `closed`
event resumes and reconciles the latest pull-request state:

| External operation | Reconciliation |
| --- | --- |
| PowerShell Gallery publication | Resolve a deterministic pull-request-scoped prerelease identity, detect the existing version, and continue without duplicate publication. |
| GitHub Release creation | Resume or upsert the release and replace its asset set. |
| Prerelease cleanup | Repeat safely after partial deletion and converge to the latest pull-request state. |
| Production boundary | Do not create a stable or signable production artifact from a pull-request event. |

## Gallery prerelease disposition

PowerShell Gallery packages are immutable and cannot be overwritten. Each prerelease uses a deterministic
pull-request-scoped version. When a prerelease becomes obsolete, release execution unlists it through a supported
Gallery API when feasible. When unlisting is infeasible, release execution retains and records the immutable version.
GitHub Release and tag cleanup execute independently from Gallery disposition.

## Verification

The lifecycle is verified with event payload fixtures and publication fakes before credentials are used:

| Behavior | Verification |
| --- | --- |
| Event routing | Fixtures for each supported event and pull-request activity, including merged and abandoned close outcomes. |
| Version boundary | A mismatched artifact fixture proves publication stops. |
| Recovery release notes | Merged-pull-request query fixtures cover empty, single, and multiple pull-request ranges. |
| Scheduled validation | A published-version fixture proves no release mutation is requested. |
| Pull-request convergence | Canceled prerelease publication and cleanup fixtures followed by synchronize, label, unlabel, and close events prove reconciliation. |
| Gallery disposition | Fixtures cover deterministic identity, existing-version detection, supported unlisting, and retained-version recording. |
| Stable aggregation | Push, manual-dispatch, and scheduled bursts replace a pending run and prove all unreleased merged pull requests are aggregated. |
| Caller authorization | Fixtures verify the explicit permissions and credential mappings, App-token failure, and no built-in-token fallback. |
| Fork authorization | Fixtures verify immutable-metadata-first restricted Settings, no privileged operations, and `pull_request_target` rejection. |
| Caller boundary | Fixtures verify repository-owned jobs remain visible without weakening or bypassing the reusable-workflow call boundary. |

## Related

- [Process-PSModule workflow lifecycle specification](process-workflow-lifecycle-specification.md)
- [Process-PSModule caller contract](process-workflow-fleet-standard.md)
