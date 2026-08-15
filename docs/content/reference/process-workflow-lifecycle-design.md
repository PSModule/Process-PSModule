---
title: Process-PSModule workflow lifecycle candidate design
description: Candidate design for Process-PSModule event routing, stamped artifacts, recovery release notes, and concurrency isolation.
---

# Process-PSModule workflow lifecycle candidate design

**Status:** This is a candidate design for discussion. It is not approved and does not change the reusable workflow or its caller contract.

This design describes one way to meet the [workflow lifecycle candidate specification](process-workflow-lifecycle-specification.md). It follows the [spec/design separation](https://msx.no/docs/Ways-of-Working/Spec-Driven-Development/#what-a-design-is); detailed implementation choices remain free until the candidate is approved.

## Confirmed implementation baseline

The confirmed reusable workflow runs a `Plan` job, enriches one settings object with the resolved version, and passes that object to downstream jobs. The module build action accepts the resolved version and prerelease identity; the publish workflow consumes the built artifact and uses the resolved full version for the release.

The version resolver treats non-pull-request events, including `workflow_dispatch` and `schedule`, as events without a release decision. The workflow's concurrency identity contains either the pull request number or the Git ref, and its runs are not canceled. The documented scenario matrix also identifies closed-pull-request cleanup as non-stable behavior.

The current code detects an existing published version, resumes GitHub Release creation, and repeats GitHub Release and tag cleanup. Full reconciliation of immutable PowerShell Gallery prereleases is a design gap: it requires implementation and cancellation-boundary tests. Current reusable jobs create App tokens after checkout; that sequencing does not satisfy the candidate App-token boundary for user-facing operations. The Pages workflow's `pages: write` and `id-token: write` permissions align with the candidate's standard Pages/OIDC path. These facts establish the starting point. They do not implement the scheduled validation or manual recovery behavior proposed below.

## Candidate event routing

Plan resolves the caller event into one release classification before build and publication work begins. The classification is stable release, prerelease, recovery or resume, cleanup-only, or no-op. Pull-request events may cancel their predecessors, so every pull-request route must converge to the latest pull-request state.

| Event | Candidate Plan classification | Desired release action | Cancellation | Required result |
| --- | --- | --- | --- | --- |
| `workflow_dispatch` on the default branch | Recovery or resume | Stable release or no-op | Never cancel | Rebuild and validate the selected commit; reconstruct the unreleased release notes. |
| `schedule` | Published-artifact validation | No-op after validation | Never cancel | Validate the latest published stable artifact and its documentation. |
| Fork `pull_request` | Restricted read-only validation | No-op after validation | Cancels a superseded pull-request run; the later run converges state | Perform only safe repository-local checkout, build, lint, and test with no privileged or user-facing operation. |
| Pull request `opened`, `reopened`, `synchronize` | Pull-request classification | Prerelease or no-op | Cancels a superseded pull-request run; the later run converges state | Report configured validation and execute the planned release action. |
| Pull request `labeled`, `unlabeled` | Pull-request classification refresh | Prerelease, cleanup-only, or no-op | Cancels a superseded pull-request run; the later run converges state | Resolve the complete current classification and execute its action. |
| Merged pull request `closed` | Post-merge close | No-op | Cancels a superseded pull-request run; the later run converges state | Do not clean up; the successful main-push release owns promotion cleanup. |
| Abandoned pull request `closed` | Abandoned-close classification | Cleanup-only | Cancels a superseded pull-request run; the later run converges state | Reconcile only prereleases owned by the abandoned pull request. |
| Push to the default branch | Stable release | Stable release | Never cancel | Resolve merged-pull-request intent when applicable, then publish and perform promotion cleanup after required gates. |

Plan records its classification and release decision in enriched Settings. Downstream jobs consume that Settings object and do not infer policy from events, labels, or repository settings again.

## Candidate event authorization

The caller invokes the reusable workflow without a caller-level fork or event condition. Plan is the event-authorization
boundary. For a normal fork `pull_request`, the controlled upstream Process-PSModule `v8` Plan implementation first
derives the security and capability envelope from immutable GitHub event metadata: the fork condition and the base and
head identities. It may query trusted upstream or base version and state as needed. GitHub withholds fork secrets, so
Plan then emits an authorized restricted read-only validation record rather than rejecting the event. That record sets
`IsFork=true`, `AllowAppToken=false`, `AllowPublication=false`, and `AllowMutation=false`. It permits only
repository-local checkout, build, lint, and test with the least-privilege built-in token, giving the contributor the
standard green/red validation outcome without configured secrets.

Repository settings and checked-out fork files are consumed only after that envelope is fixed, and only as untrusted
validation or build inputs. They cannot enable an App token; publication, mutation, deployment, or cleanup; or broader
permissions.

No restricted fork path may create an App token; access PowerShell Gallery; comment on, label, or mutate a pull request;
write a status or other check-facing report; create releases, tags, or assets; perform cleanup; deploy Pages; or perform
another privileged or user-facing operation. `pull_request_target` remains unsupported because it could combine
privileged context with untrusted code. Plan rejects that event before credentials or repository-defined code run. An
authorization rejection produces no usable Settings and no credentialed follow-on work.

Every downstream job depends on a successful authorized Plan and valid Settings. This requirement applies equally to jobs
that use `always()`: their conditions first require the Plan result and Settings validity, then apply their own
failure-handling logic. Privileged jobs additionally require their relevant explicit capability. A downstream job never
parses missing or invalid Settings and cannot bypass the Plan gate.

## Candidate artifact and version boundary

Version resolution is the boundary between planning and release-capable work. The candidate carries one immutable release record in enriched Settings through build, test, and release execution:

| Record field | Purpose |
| --- | --- |
| Event and run type | Identifies the GitHub event and its candidate lifecycle classification. |
| Event action | Preserves the relevant pull-request activity or non-pull-request action. |
| Pull-request identity, state, and merged status | Distinguishes active, merged, and abandoned pull-request outcomes. |
| Authorization capabilities and evidence | Records `IsFork`, the immutable event metadata used to derive it, and the explicit App-token, publication, and mutation capabilities that each downstream job must enforce. |
| Labels and repository settings result | Captures the input policy state used only by Plan. |
| Version bump and base version | Explains the selected version transition. |
| Manifest version, prerelease identifier, and full version or tag | Defines the only version and tag permitted in the built artifact and release. |
| Target commit | Binds validation, artifact, and release to one source revision. |
| Desired release action and create or publish flags | Selects stable release, prerelease, recovery or resume, cleanup-only, or no-op. |
| Cleanup intent and artifact identity | Defines the exact artifacts that release execution may reconcile. |
| Release-note source and boundary | Identifies the merged pull requests eligible for a recovery release note. |

The build stage stamps exactly the planned manifest version and prerelease identifier into the module artifact. Before any package, tag, or release becomes visible, release execution verifies that the artifact equals the immutable Settings record. A mismatch stops execution; it is not corrected by retagging or by recalculating a version after the artifact is built.

## Candidate general release execution

One general module release action or reusable workflow consumes enriched Settings after validation. It handles stable release, prerelease, recovery or resume, cleanup-only, and no-op actions according to the planned desired release action and flags. It verifies the artifact when an artifact is required and reconciles only the requested state. It does not recompute versioning, labels, event routing, or cleanup policy.

## Candidate repository authorization

The caller sets no top-level default and grants its Process-PSModule job only the built-in permissions needed for repository-local reads and standard Pages/OIDC deployment:

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

These three explicit mappings are the required caller baseline; `secrets: inherit` is nonconforming. The only optional
secret mapping is `TestData` for module-local tests:

```yaml
      TestData: ${{ secrets.TestData }}
```

When present, `TestData` contains a JSON object with separate `secrets` and `variables` maps. It is omitted when
unused. A conforming caller does not set `with.Debug: true`; the reusable workflow default remains `false`.

Built-in `GITHUB_TOKEN` authorization is permitted for checkout, repository-local reads, and standard Pages/OIDC deployment within that job boundary. GitHub App installation tokens are step-scoped and authorize every user-facing interaction and every operation that needs broader reach or permissions: pull-request comments and labels, commit statuses and check-facing reporting, releases, tags, assets, and cleanup.

Each App-token step requests only the installation permissions required for its operation. A missing App token is an authorization failure for App-required work: that operation stops before its API request or mutation, without silently falling back to the built-in workflow token. Built-in-token reads and Pages deployment remain available only within the explicit caller job permissions.

For a Plan-classified restricted fork run, the Settings capabilities override the caller job's otherwise available
permissions: no App token is created, no Pages deployment runs, and no repository mutation or user-facing action runs.
The fork path has only the least-privilege built-in-token access required for repository-local checkout, build, lint,
and test.

## Candidate Pages authorization

The standard `actions/deploy-pages` path uses the built-in token's `pages: write` and `id-token: write` permissions granted only to the caller's Process-PSModule job. It remains inside the candidate's repository-local, non-user-facing boundary and does not require an App token.

## Candidate stable Plan aggregation

Every stable push and recovery target uses the same aggregation rule. Plan finds the last successfully published stable version and its associated target commit, then queries merged pull requests through the requested target commit. It aggregates their release intent and uses that range for the stable version decision and release notes.

This aggregation is not limited to manual recovery. GitHub can replace an intermediate pending run when a newer run enters the same concurrency group, so the later stable target must carry forward every merged pull request since the last successful publication.

## Candidate manual recovery

A manual recovery route accepts only a selected default-branch commit. It uses the stable Plan aggregation rule and returns a no-op when a stable publication already covers that commit.

For a missing publication, the release-note reconstruction uses the ordered, de-duplicated aggregated pull-request range rather than the manual-dispatch event payload, which has no pull-request context.

The recovery route validates the selected commit using the same release gates as a default-branch push. It produces a stable release only after the artifact/version boundary succeeds. This keeps recovery notes traceable even when the normal main-push run was missed or interrupted.

## Candidate scheduled validation

The scheduled route resolves the latest published stable version as an input, not as a version to create. It validates the downloaded package and its published documentation with the checks appropriate to a published consumer artifact. Its plan record sets the mutation class to validation only, so publication and cleanup stages cannot run.

## Candidate close behavior

A merged pull-request close performs no prerelease cleanup because the default-branch push is the release authority. After its stable release succeeds, that main-push route owns promotion cleanup. An abandoned pull-request close runs only pull-request-scoped prerelease cleanup because no main push will occur.

The alternative of never cleaning up on a close requires scheduled garbage collection and leaves abandoned prereleases available until that collection runs. This candidate selects abandoned-close cleanup instead; it does not change the existing unapproved caller contract.

## Candidate concurrency and recovery

The candidate caller recommendation is:

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
```

This is a candidate, not an approved caller contract. All pull-request events for one pull request share a group and may cancel an earlier run. Push, manual-dispatch, and scheduled events serialize by the full `github.ref` and do not cancel a running run. GitHub permits at most one running and one pending run per group, so a newer same-group event can replace an older pending run even when cancellation is disabled. A manual dispatch on `main` shares `refs/heads/main` with a push: it queues behind a running push but can replace an older pending main run.

The candidate retains full `github.ref`. `github.ref_name` neither prevents pending-run replacement nor distinguishes branches and tags with the same name.

Cancellation can leave only transient partial state. Every pull-request route, including prerelease publication and abandoned-close cleanup, resumes and reconciles on the next `synchronize`, `labeled`, `unlabeled`, or `closed` event:

| External operation | Required recovery behavior |
| --- | --- |
| PowerShell Gallery publication | Use a deterministic pull-request-scoped prerelease identity, detect the existing resolved version, and continue without duplicate publication. |
| GitHub Release creation | Resume or upsert the release and replace its asset set. |
| Prerelease cleanup | Repeat safely after partial deletion and converge to the latest pull-request state. |
| Prerelease lifecycle | A subsequent synchronize, label, unlabel, or close reconciles obsolete prereleases. |
| Production boundary | No pull-request event creates a stable or signable production artifact. |

Cleanup receives a pull-request-scoped artifact set and MUST NOT perform a broad prerelease deletion while a stable release can be active. Any future broad cleanup needs a separately approved exclusive scope; it cannot share the abandoned-close route.

## Candidate Gallery prerelease disposition

PowerShell Gallery packages are immutable and cannot be overwritten. Gallery reconciliation is therefore separate from GitHub Release and tag cleanup:

| Obsolete Gallery prerelease condition | Candidate disposition |
| --- | --- |
| A supported Gallery API can unlist the version | Unlist the immutable package through that API. |
| Unlisting is not feasible | Retain the immutable version and record it as retained in the lifecycle result. |

The selected disposition policy remains unapproved. A cancellation can leave a published immutable package even when its GitHub Release and tag cleanup has not completed; the next pull-request event must detect that version and apply the approved Gallery disposition rather than attempting to overwrite it.

## Candidate verification strategy

The lifecycle contract is exercised with event payload fixtures and publication fakes before credentials are used:

| Candidate behavior | Verification |
| --- | --- |
| Event routing | One fixture for each supported event and pull-request activity, including merged and abandoned close outcomes. |
| Version boundary | A mismatched artifact fixture that proves publication stops. |
| Recovery release notes | Merged-pull-request query fixtures covering an empty range, one pull request, and multiple pull requests. |
| Scheduled validation | A published-version fixture that proves no release mutation is requested. |
| Pull-request convergence | Canceled prerelease-publication and cleanup fixtures followed by synchronize, label, unlabel, and close events that prove the latest pull-request state is reconciled. |
| Gallery immutability | Deterministic pull-request identity, existing-version detection, supported-unlist, and retained-version fixtures across the cancellation boundary. |
| Stable aggregation | Bursts of main-push, manual-dispatch, and scheduled fixtures that replace an intermediate pending run and prove the later stable target aggregates all unreleased merged pull requests. |
| Scoped caller permissions | Empty caller top-level permissions, the three job grants, built-in-token checkout/read, and standard Pages/OIDC verification. |
| Caller credential contract | Explicit baseline mappings for `PSGALLERY_API_KEY`, `GitHubAppClientId`, and `GitHubAppPrivateKey`; rejected `secrets: inherit`; optional `TestData` JSON with separate `secrets` and `variables` maps; and no `with.Debug: true`. |
| App authorization failure | Missing-App-token fixtures that prove user-facing operations fail closed without built-in token fallback. |
| Token boundary | Fixtures that prove App tokens are step-scoped and built-in-token operations remain within the caller job's boundary. |
| Event authorization | Normal-fork `pull_request` fixtures that prove the controlled upstream Plan derives restricted capabilities from immutable fork/base/head metadata before it consumes settings or checked-out code, then permits only checkout/build/lint/test with a green/red outcome and no configured secrets; `pull_request_target` fixtures prove Plan rejects before credentialed or repository-defined code, including for downstream `always()` jobs. |
| Capability enforcement | Restricted-fork fixtures that prove App-token creation, Gallery access, comments, labels, statuses, releases, tags, assets, cleanup, Pages deployment, and other privileged paths cannot run. |

## Decisions requiring approval

The candidate does not decide the following:

- Whether a recovery release always uses the normal next patch version or permits an explicit version input.
- Which source is authoritative when a PowerShell Gallery publication and GitHub release disagree about the last published stable version.
- Which consumer-facing checks comprise scheduled published-artifact validation.
- Whether removing prerelease eligibility cleans up existing prereleases immediately or leaves them until the abandoned-close cleanup route.
- Whether the supported Gallery API can unlist obsolete prereleases; otherwise, how retained immutable versions are recorded.
- Approval of the selected caller concurrency expression in [PSModule/Process-PSModule#514](https://github.com/PSModule/Process-PSModule/issues/514).

## Related

- [Candidate specification](process-workflow-lifecycle-specification.md) — behavior and acceptance criteria.
- [Scenario matrix](scenario-matrix.md) — established job-level routing reference.
- [Process-PSModule caller workflow candidate](process-workflow-fleet-standard.md) — candidate event and concurrency contract.
