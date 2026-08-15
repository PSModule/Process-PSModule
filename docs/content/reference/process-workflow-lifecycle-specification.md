---
title: Process-PSModule workflow lifecycle candidate specification
description: Candidate behavior-driven requirements for Process-PSModule caller event routing, recovery releases, validation, and cleanup.
---

# Process-PSModule workflow lifecycle candidate specification

**Status:** This is a candidate for discussion. It is not an approved workflow standard and does not change the candidate caller contract in [Process-PSModule caller workflow candidate](process-workflow-fleet-standard.md).

## Problem and outcome

Module repositories need each workflow event to have one safe, observable lifecycle outcome. A failed or missed publication needs a recoverable path; published artifacts need continuing validation; and pull-request activity must not create an accidental stable release.

This candidate defines the behavior required from a Process-PSModule workflow lifecycle. Its requirements follow [spec-driven development](https://msx.no/docs/Ways-of-Working/Spec-Driven-Development/) and use [Given / When / Then scenarios](https://msx.no/docs/Ways-of-Working/Spec-Driven-Development/#behavioral-scenarios) as the acceptance contract.

## Scope

The candidate covers dispatch recovery, scheduled validation, pull-request validation and prerelease evaluation, closed-pull-request cleanup, and stable publication after a default-branch push.

It does not approve a caller layout, change module build or publication implementation, define label names, or prescribe release-note presentation. Those choices remain in the caller candidate, the existing versioning guidance, and the companion [candidate design](process-workflow-lifecycle-design.md).

## Confirmed implementation baseline

The reusable workflow has a single planning decision that enriches downstream settings with a resolved version and release decision. It also serializes runs by pull request number or ref without canceling a running workflow.

The version resolver treats non-pull-request events, including `workflow_dispatch` and `schedule`, as events without a pull request and does not create a release decision. The existing workflow supports pull-request validation, prerelease publication, default-branch publication, and closed-pull-request prerelease cleanup. Scheduled published-artifact validation and manual recovery publication are not confirmed behavior.

The following requirements describe desired behavior, not a claim that the confirmed implementation already satisfies it.

## Functional requirements

### FR1 — Manual dispatch MUST provide a safe recovery release {#fr1}

A default-branch manual dispatch MUST either publish one recoverable stable release after all required validation succeeds or report that the selected commit is already covered by a stable publication. It MUST NOT create a duplicate stable publication.

#### Behavioral scenarios {#fr1-scenarios}

```gherkin
Scenario: Recover a missing stable publication
  Given the default branch contains a validated commit without a stable publication
  When a maintainer dispatches the workflow for that commit
  Then the workflow publishes one stable artifact and release for the commit
  And the release notes identify merged pull requests since the previous published version

Scenario: Repeat a completed recovery dispatch
  Given a stable publication already covers the selected default-branch commit
  When a maintainer dispatches the workflow again
  Then the workflow reports that no recovery release is required
  And it does not create another artifact, tag, or release
```

### FR2 — Scheduled runs MUST validate published artifacts without publishing {#fr2}

A scheduled run MUST validate the latest published stable artifact and its published documentation against the repository's configured checks. It MUST NOT create, replace, or delete a package, tag, release, or prerelease.

#### Behavioral scenarios {#fr2-scenarios}

```gherkin
Scenario: Validate the latest published artifact
  Given a stable module version and its documentation are published
  When the scheduled workflow runs
  Then the workflow validates that published version
  And it reports the validated version and result
  And it creates no release-related artifact
```

### FR3 — Pull-request delivery events MUST run validation only {#fr3}

An `opened`, `reopened`, or `synchronize` pull-request event targeting the default branch MUST run the configured validation for the pull request. It MUST NOT create a stable publication.

#### Behavioral scenarios {#fr3-scenarios}

```gherkin
Scenario: Validate a synchronized pull request
  Given a pull request targets the default branch
  When a new commit synchronizes the pull request
  Then the workflow reports the configured validation result on that pull request
  And it does not publish a stable version
```

### FR4 — Label changes MUST re-evaluate prerelease eligibility {#fr4}

A `labeled` or `unlabeled` pull-request event targeting the default branch MUST re-evaluate prerelease eligibility from the complete current label set. A prerelease publication MUST occur only when the pull request is eligible and every required validation succeeds.

#### Behavioral scenarios {#fr4-scenarios}

```gherkin
Scenario: Add prerelease eligibility
  Given a validated pull request has no prerelease eligibility
  When a prerelease label is added
  Then the workflow re-evaluates the pull request
  And it publishes at most one eligible prerelease version

Scenario: Remove prerelease eligibility
  Given a pull request has prerelease eligibility
  When its prerelease label is removed
  Then the workflow re-evaluates the pull request as ineligible
  And it does not create a new prerelease version
```

### FR5 — Closed pull requests MUST route cleanup by close outcome {#fr5}

A merged pull request close MUST NOT perform prerelease cleanup. A successful default-branch release for the merge MUST own promotion cleanup. An abandoned pull request close MUST run cleanup-only behavior for prerelease artifacts associated with that pull request when cleanup is enabled. Neither close outcome MUST authorize or create a stable publication.

#### Behavioral scenarios {#fr5-scenarios}

```gherkin
Scenario: Merge a pull request with prereleases
  Given a merged pull request owns prerelease artifacts
  When its close event is processed
  Then the close event does not clean up prerelease artifacts
  And the successful default-branch release owns promotion cleanup

Scenario: Abandon a pull request with prereleases
  Given an unmerged closed pull request owns prerelease artifacts
  When its close event is processed
  Then the workflow runs cleanup only for that pull request's prerelease artifacts
  And no stable artifact, tag, or release is created
```

### FR6 — Default-branch pushes MUST authorize stable publication after validation {#fr6}

A push to the default branch MUST publish a stable version only after all required build, test, quality, and publication gates succeed. When the pushed commit is the merge commit of a pull request, the stable-release decision MUST use that pull request's release intent. A successful stable release for a merged pull request MUST own promotion cleanup.

#### Behavioral scenarios {#fr6-scenarios}

```gherkin
Scenario: Publish a merged pull request
  Given a merged pull request has an unambiguous release intent
  And its merge commit is pushed to the default branch
  When all required validation gates succeed
  Then the workflow publishes the resulting stable version
  And the publication is associated with the pushed commit
  And the successful release performs promotion cleanup
```

### FR7 — Published artifacts MUST match the resolved version {#fr7}

Every prerelease or stable publication MUST contain the version and prerelease identity resolved for its workflow run. A version mismatch MUST fail publication before the release is made visible.

#### Behavioral scenarios {#fr7-scenarios}

```gherkin
Scenario: Reject an incorrectly stamped artifact
  Given a workflow resolves a release version
  And the built artifact reports a different version
  When publication is attempted
  Then publication fails
  And no release is made visible for that artifact
```

## Non-functional requirements

### NFR1 — Lifecycle mutations MUST be idempotent {#nfr1}

Retrying the same event for the same commit and resolved version MUST produce no more than one package, tag, and release for that version.

#### Behavioral scenarios {#nfr1-scenarios}

```gherkin
Scenario: Retry a publication after an interrupted run
  Given a publication for a resolved version was interrupted
  When the workflow retries the same event
  Then it completes the missing work or reports the completed work
  And it does not duplicate the package, tag, or release
```

### NFR2 — Cancellation MUST be conditional on an explicit mutability mode {#nfr2}

A run explicitly classified as read-only pull-request CI SHOULD cancel a superseded `opened`, `reopened`, or `synchronize` run for the same pull request. A run that may publish to the PowerShell Gallery, create or upload a GitHub Release or tag, deploy Pages, or clean up prereleases MUST NOT be canceled. Caller-level label inspection MUST NOT determine mutability because repository settings can change the release decision. Manual and scheduled runs sharing a ref MUST NOT cancel a default-branch release.

#### Behavioral scenarios {#nfr2-scenarios}

```gherkin
Scenario: Supersede read-only pull-request CI
  Given an explicitly read-only pull-request CI run is in progress
  When a newer synchronize event starts the same read-only route
  Then the older run may be canceled
  And no release-related resource is mutated by either run

Scenario: Preserve a release-capable run
  Given a run may publish, deploy, or clean up prereleases
  When a newer event starts
  Then the release-capable run is not canceled
  And the newer event does not infer safety from pull-request labels alone

Scenario: Keep main release independent from manual and scheduled runs
  Given a default-branch release is in progress
  When a manual dispatch or scheduled validation starts for the same ref
  Then neither event cancels the default-branch release
```

### NFR3 — Each lifecycle outcome MUST be auditable {#nfr3}

Every run MUST report its event category, resolved version or validated published version, release decision, and terminal outcome before the run completes.

#### Behavioral scenarios {#nfr3-scenarios}

```gherkin
Scenario: Inspect a scheduled validation result
  Given a scheduled validation has completed
  When a maintainer inspects the workflow result
  Then the result identifies the validated published version
  And it identifies whether validation passed or failed
  And it identifies that no release mutation occurred
```

## Cross-cutting acceptance criteria

### AC1 — Verifies: [FR1](#fr1), [FR6](#fr6), [FR7](#fr7), [NFR1](#nfr1)

```gherkin
Scenario: Recover release notes after a missed main-push publication
  Given merged pull requests exist after the last published stable version
  And the selected default-branch commit has no stable publication
  When a maintainer dispatches a recovery release
  Then the published artifact matches the resolved version
  And the release notes identify the merged pull requests in that unreleased range
  And a retry creates no duplicate publication
```

### AC2 — Verifies: [FR2](#fr2), [FR5](#fr5), [FR6](#fr6), [NFR2](#nfr2), [NFR3](#nfr3)

```gherkin
Scenario: Lifecycle runs preserve release ownership
  Given a scheduled validation and an abandoned pull-request cleanup overlap a main-push release
  When all three runs complete
  Then the scheduled run reports validation without a release mutation
  And the cleanup affects only the abandoned pull request's prereleases
  And none of the runs cancel the main-push release
  And the main-push run is the only run that publishes the stable release and performs promotion cleanup
```

## Impact

This candidate aims to reduce time to restore a missed publication and reduce change failure risk by separating validation, cleanup, prerelease, and stable-release authority. Its domain signal is the count of duplicate, missing, or incorrectly stamped published versions per release cycle; the target is zero.

## Dependencies and constraints

Approval of the caller event and concurrency contract in [PSModule/Process-PSModule#514](https://github.com/PSModule/Process-PSModule/issues/514) is required before this candidate becomes an implementation commitment. The candidate depends on repository credentials that can query pull requests and publish module artifacts. It retains the caller candidate's default-branch and fork boundaries.

## Related

- [Candidate design](process-workflow-lifecycle-design.md) — proposed routing and recovery approach.
- [Scenario matrix](scenario-matrix.md) — established job-level routing reference.
- [Process-PSModule caller workflow candidate](process-workflow-fleet-standard.md) — candidate caller event and concurrency contract.
