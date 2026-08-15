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

These facts establish the starting point. They do not implement the scheduled validation or manual recovery behavior proposed below.

## Candidate event routing

The planner classifies the caller event before build and publication work begins. Each route produces one of three mutation classes: validation only, prerelease mutation, or stable-release mutation. Pull-request events may cancel their predecessors, so every pull-request route must converge to the latest pull-request state.

| Event | Candidate route | Mutation class | Cancellation | Required result |
| --- | --- | --- | --- | --- |
| `workflow_dispatch` on the default branch | Recovery release | Stable release or explicit no-op | Never cancel | Rebuild and validate the selected commit; reconstruct the unreleased release notes. |
| `schedule` | Published-artifact validation | Validation only | Never cancel | Validate the latest published stable artifact and its documentation. |
| Pull request `opened`, `reopened`, `synchronize` | Pull-request CI | Validation only | Cancels a superseded pull-request run; the later run converges state | Report configured validation on the pull request. |
| Pull request `labeled`, `unlabeled` | Prerelease evaluation | Prerelease or validation only | Cancels a superseded pull-request run; the later run converges state | Re-evaluate the full label set and publish only an eligible prerelease. |
| Merged pull request `closed` | Post-merge close | Validation only | Cancels a superseded pull-request run; the later run converges state | Do not clean up; the successful main-push release owns promotion cleanup. |
| Abandoned pull request `closed` | Pull-request cleanup | Prerelease cleanup only | Cancels a superseded pull-request run; the later run converges state | Remove only prereleases owned by the abandoned pull request. |
| Push to the default branch | Stable release | Stable release | Never cancel | Resolve merged-pull-request intent when applicable, then publish and perform promotion cleanup after required gates. |

The classifier records the route, mutable resource scope, commit identity, and release decision in the plan result. Downstream jobs consume that record rather than infer the event again.

## Candidate artifact and version boundary

Version resolution is the boundary between planning and release-capable work. The candidate carries one immutable release record through build, test, and publication:

| Record field | Purpose |
| --- | --- |
| Commit identity | Binds validation, artifact, and release to one source revision. |
| Resolved stable version and prerelease identity | Defines the only version permitted in the built artifact. |
| Event route and mutation class | Restricts each downstream stage to its authorized behavior. |
| Release-note range | Identifies the merged pull requests eligible for a recovery release note. |

The build stage stamps the resolved version into the module artifact. Before any package, tag, or release becomes visible, the publication stage verifies that the artifact version and prerelease identity equal the immutable release record. A mismatch stops publication; it is not corrected by retagging or by recalculating a version after the artifact is built.

## Candidate manual recovery

A manual recovery route accepts only a selected default-branch commit. It first determines whether a stable publication already covers that commit and returns a no-op when one exists.

For a missing publication, the route identifies the last published stable version and its associated default-branch commit. It then queries merged pull requests targeting the default branch between that publication boundary and the selected commit. The release-note reconstruction uses that ordered, de-duplicated result rather than the manual-dispatch event payload, which has no pull-request context.

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

This is a candidate, not an approved caller contract. All pull-request events for one pull request share a group and may cancel an earlier run. Push, manual-dispatch, and scheduled events serialize by ref and never cancel; a manual dispatch or schedule therefore cannot interrupt a main release.

Cancellation can leave only transient partial state. Every pull-request route, including prerelease publication and abandoned-close cleanup, resumes and reconciles on the next `synchronize`, `labeled`, `unlabeled`, or `closed` event:

| External operation | Required recovery behavior |
| --- | --- |
| PowerShell Gallery publication | Detect the existing resolved version and continue without duplicate publication. |
| GitHub Release creation | Resume or upsert the release and replace its asset set. |
| Prerelease cleanup | Repeat safely after partial deletion and converge to the latest pull-request state. |
| Prerelease lifecycle | A subsequent synchronize, label, unlabel, or close reconciles obsolete prereleases. |
| Production boundary | No pull-request event creates a stable or signable production artifact. |

Cleanup receives a pull-request-scoped artifact set and MUST NOT perform a broad prerelease deletion while a stable release can be active. Any future broad cleanup needs a separately approved exclusive scope; it cannot share the abandoned-close route.

## Candidate verification strategy

The lifecycle contract is exercised with event payload fixtures and publication fakes before credentials are used:

| Candidate behavior | Verification |
| --- | --- |
| Event routing | One fixture for each supported event and pull-request activity, including merged and abandoned close outcomes. |
| Version boundary | A mismatched artifact fixture that proves publication stops. |
| Recovery release notes | Merged-pull-request query fixtures covering an empty range, one pull request, and multiple pull requests. |
| Scheduled validation | A published-version fixture that proves no release mutation is requested. |
| Pull-request convergence | Canceled prerelease-publication and cleanup fixtures followed by synchronize, label, unlabel, and close events that prove the latest pull-request state is reconciled. |
| Non-pull-request serialization | Overlapping main-push, manual-dispatch, and scheduled fixtures that prove runs queue by ref and do not cancel. |

## Decisions requiring approval

The candidate does not decide the following:

- Whether a recovery release always uses the normal next patch version or permits an explicit version input.
- Which source is authoritative when a PowerShell Gallery publication and GitHub release disagree about the last published stable version.
- Which consumer-facing checks comprise scheduled published-artifact validation.
- Whether removing prerelease eligibility cleans up existing prereleases immediately or leaves them until the abandoned-close cleanup route.
- Approval of the selected caller concurrency expression in [PSModule/Process-PSModule#514](https://github.com/PSModule/Process-PSModule/issues/514).

## Related

- [Candidate specification](process-workflow-lifecycle-specification.md) — behavior and acceptance criteria.
- [Scenario matrix](scenario-matrix.md) — established job-level routing reference.
- [Process-PSModule caller workflow candidate](process-workflow-fleet-standard.md) — candidate event and concurrency contract.
