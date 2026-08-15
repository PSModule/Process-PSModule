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

The planner classifies the caller event before build and publication work begins. Each route produces one of three mutation classes: validation only, prerelease mutation, or stable-release mutation. The candidate also assigns an explicit mutability mode, because callers cannot safely infer it from labels alone.

| Event | Candidate route | Mutability mode | Cancellation | Required result |
| --- | --- | --- | --- | --- |
| `workflow_dispatch` on the default branch | Recovery release | Stable release or explicit no-op | Never cancel | Rebuild and validate the selected commit; reconstruct the unreleased release notes. |
| `schedule` | Published-artifact validation | Validation only | May cancel only another explicitly read-only validation; never cancel a default-branch release | Validate the latest published stable artifact and its documentation. |
| Pull request `opened`, `reopened`, `synchronize` | Pull-request CI | Explicitly read-only | May cancel a superseded run in the same read-only CI domain | Report configured validation on the pull request. |
| Pull request `labeled`, `unlabeled` | Prerelease evaluation | Potential prerelease mutation | Never cancel | Re-evaluate the full label set and publish only an eligible prerelease. |
| Merged pull request `closed` | Post-merge close | Validation only | May cancel only when explicitly routed as read-only | Do not clean up; the successful main-push release owns promotion cleanup. |
| Abandoned pull request `closed` | Pull-request cleanup | Prerelease cleanup only | Never cancel | Remove only prereleases owned by the abandoned pull request. |
| Push to the default branch | Stable release | Stable release | Never cancel | Resolve merged-pull-request intent when applicable, then publish and perform promotion cleanup after required gates. |

The classifier records the route, mutability mode, mutable resource scope, commit identity, and release decision in the plan result. Downstream jobs consume that record rather than infer the event again.

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

## Candidate concurrency isolation

Cancellation is conditional, not globally disabled. Only an explicit read-only mode may cancel a superseded run. A route that can mutate an external release resource never cancels and is never canceled.

| Lifecycle route | Concurrency domain | Cancellation policy | Mutable resources |
| --- | --- | --- | --- |
| Explicitly read-only pull-request CI | Pull request number and read-only mode | Superseded runs may cancel | None. |
| Prerelease evaluation and abandoned-close cleanup | Pull request number and mutation mode | Never cancel | Prerelease artifacts associated with that pull request. |
| Default-branch push and manual recovery | Default-branch ref and mutation mode | Never cancel | Stable package, GitHub Release, tag, uploads, Pages, and promotion cleanup. |
| Scheduled validation | Published-version read domain | May cancel only another explicit scheduled validation | None. |

Concurrency selection occurs before the reusable workflow can produce a planner output. The candidate therefore requires either an explicit event mode at the caller boundary or separate read-only and mutation workflow domains. Caller-level label inspection is insufficient: repository settings can make a label event release-capable. Manual and scheduled runs must not share a cancellation domain that can cancel a default-branch release.

Cleanup receives a pull-request-scoped artifact set and MUST NOT perform a broad prerelease deletion while a stable release can be active. Any future broad cleanup needs a separately approved exclusive scope; it cannot share the abandoned-close route.

## Why mutation-capable runs never cancel

Cancellation after an external mutation begins can leave the release lifecycle partially complete:

| Mutation path | Cancellation hazard |
| --- | --- |
| PowerShell Gallery publication | The package can publish before the GitHub Release, release-asset upload, or pull-request comment completes. |
| Prerelease cleanup | Cleanup can delete only part of a prerelease tag and release set. |
| Default-branch release | A main release can stop between package publication, tag or GitHub Release creation, uploads, comments, Pages deployment, and promotion cleanup. |
| Manual or scheduled run sharing a ref | A cancellation domain keyed only by ref can interrupt a main release with a manual dispatch or scheduled validation. |

## Candidate verification strategy

The lifecycle contract is exercised with event payload fixtures and publication fakes before credentials are used:

| Candidate behavior | Verification |
| --- | --- |
| Event routing | One fixture for each supported event and pull-request activity, including merged and abandoned close outcomes. |
| Version boundary | A mismatched artifact fixture that proves publication stops. |
| Recovery release notes | Merged-pull-request query fixtures covering an empty range, one pull request, and multiple pull requests. |
| Scheduled validation | A published-version fixture that proves no release mutation is requested. |
| Conditional cancellation | A superseded read-only CI fixture plus release-capable label, cleanup, main-push, manual, and scheduled fixtures that prove mutation-capable runs do not cancel. |

## Decisions requiring approval

The candidate does not decide the following:

- Whether a recovery release always uses the normal next patch version or permits an explicit version input.
- Which source is authoritative when a PowerShell Gallery publication and GitHub release disagree about the last published stable version.
- Which consumer-facing checks comprise scheduled published-artifact validation.
- Whether removing prerelease eligibility cleans up existing prereleases immediately or leaves them until the abandoned-close cleanup route.
- The exact caller triggers and concurrency expression, which remain subject to [PSModule/Process-PSModule#514](https://github.com/PSModule/Process-PSModule/issues/514).

## Related

- [Candidate specification](process-workflow-lifecycle-specification.md) — behavior and acceptance criteria.
- [Scenario matrix](scenario-matrix.md) — established job-level routing reference.
- [Process-PSModule caller workflow candidate](process-workflow-fleet-standard.md) — candidate event and concurrency contract.
