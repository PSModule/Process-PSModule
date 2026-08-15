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

### FR4 — Label changes MUST refresh the planned release classification {#fr4}

A `labeled` or `unlabeled` pull-request event targeting the default branch MUST refresh the complete planned release classification from the current label set and repository settings. A prerelease publication MUST occur only when the planned classification is prerelease and every required validation succeeds.

#### Behavioral scenarios {#fr4-scenarios}

```gherkin
Scenario: Add prerelease eligibility
  Given a validated pull request has no prerelease eligibility
  When a prerelease label is added
  Then the plan resolves the pull request as prerelease eligible
  And it publishes at most one eligible prerelease version

Scenario: Remove prerelease eligibility
  Given a pull request has prerelease eligibility
  When its prerelease label is removed
  Then the plan resolves the pull request as prerelease ineligible
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

### FR7 — Published artifacts MUST match the planned version {#fr7}

Every prerelease or stable publication MUST contain the version and prerelease identity in the planned release decision. A version mismatch MUST fail publication before the release is made visible.

#### Behavioral scenarios {#fr7-scenarios}

```gherkin
Scenario: Reject an incorrectly stamped artifact
  Given the plan resolves a release version
  And the built artifact reports a different version
  When publication is attempted
  Then publication fails
  And no release is made visible for that artifact
```

### FR8 — Pull-request prereleases MUST have deterministic scoped identities {#fr8}

A pull-request prerelease MUST use a deterministic identity scoped to its pull request. Reprocessing the same pull-request state MUST resolve the same prerelease identity, and different pull requests MUST NOT resolve the same identity.

#### Behavioral scenarios {#fr8-scenarios}

```gherkin
Scenario: Reprocess the same pull-request state
  Given a pull request has resolved a prerelease identity
  When the same pull-request state is processed again
  Then the workflow resolves the same prerelease identity
  And it detects an existing publication instead of attempting an overwrite

Scenario: Publish prereleases for distinct pull requests
  Given two pull requests are eligible for prerelease publication
  When both pull requests are processed
  Then each pull request resolves a distinct prerelease identity
```

### FR9 — Lifecycle policy MUST be resolved once before downstream work {#fr9}

The plan MUST resolve the lifecycle policy before build, test, or release execution begins. Downstream work MUST consume that planned policy and MUST NOT reinterpret event data, labels, or repository settings.

#### Behavioral scenarios {#fr9-scenarios}

```gherkin
Scenario: Execute a planned prerelease action
  Given the plan resolves a pull request as an eligible prerelease publication
  When downstream work executes
  Then it consumes the planned release action and version
  And it does not re-evaluate pull-request labels or event data

Scenario: Execute a planned cleanup-only action
  Given the plan resolves an abandoned pull-request close as cleanup only
  When release execution runs
  Then it reconciles only the planned cleanup state
  And it does not create or publish an artifact
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

### NFR2 — Pull-request cancellation MUST preserve non-pull-request serialization {#nfr2}

All pull-request events for one pull request MUST share a cancellation scope, so a newer pull-request event cancels a superseded run. Push, manual dispatch, and scheduled runs MUST share ref-based serialization and MUST NOT cancel an in-progress run.

#### Behavioral scenarios {#nfr2-scenarios}

```gherkin
Scenario: Supersede a pull-request run
  Given a pull-request run is in progress
  When a newer synchronize, label, unlabel, or close event starts
  Then the older pull-request run is canceled

Scenario: Serialize non-pull-request runs
  Given a default-branch release is in progress
  When a manual dispatch or scheduled validation starts for the same ref
  Then the later run waits for the default-branch release
  And neither run cancels the other
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

### NFR4 — Pull-request mutation paths MUST resume and converge {#nfr4}

Every pull-request path, including prerelease publication and cleanup, MUST be idempotent and resumable after cancellation. The next `synchronize`, `labeled`, `unlabeled`, or `closed` event MUST converge release-related state to the latest pull-request state. Cancellation MAY leave transient partial state, but it MUST NOT leave a permanent duplicate or an obsolete artifact without the required disposition.

#### Behavioral scenarios {#nfr4-scenarios}

```gherkin
Scenario: Resume a canceled prerelease publication
  Given a canceled pull-request run published a prerelease package but did not finish its release metadata
  When a later pull-request event is processed
  Then the workflow detects the existing version
  And it completes or reconciles the prerelease release state without duplication

Scenario: Reconcile obsolete prereleases
  Given a canceled pull-request run left prerelease artifacts for an earlier pull-request state
  When a synchronize, label, unlabel, or close event is processed
  Then the workflow reconciles prerelease artifacts to the latest pull-request state
  And every obsolete prerelease has the required disposition
```

### NFR5 — Pull-request events MUST NOT produce production artifacts {#nfr5}

A pull-request event MUST NOT create a stable or signable production artifact. Pull-request events MAY create only eligible prerelease artifacts and their associated metadata.

#### Behavioral scenarios {#nfr5-scenarios}

```gherkin
Scenario: Evaluate an eligible prerelease pull request
  Given a pull request is eligible for prerelease publication
  When its release-capable path completes
  Then it creates only prerelease artifacts and metadata
  And it does not create a stable or signable production artifact
```

### NFR6 — Immutable Gallery prereleases MUST have a disposition policy {#nfr6}

PowerShell Gallery packages MUST be treated as immutable and MUST NOT be overwritten. The candidate MUST define whether obsolete pull-request prereleases are unlisted through a supported Gallery API or retained as documented immutable versions when unlisting is not feasible. This policy is distinct from GitHub Release and tag cleanup.

#### Behavioral scenarios {#nfr6-scenarios}

```gherkin
Scenario: Dispose of an obsolete Gallery prerelease
  Given a pull-request prerelease is obsolete
  And a supported Gallery API can unlist that version
  When the prerelease is reconciled
  Then the workflow unlists the immutable Gallery package
  And it performs GitHub Release and tag cleanup independently

Scenario: Retain an immutable Gallery prerelease
  Given a pull-request prerelease is obsolete
  And unlisting that Gallery version is not feasible
  When the prerelease is reconciled
  Then the workflow records the retained immutable Gallery version
  And it performs GitHub Release and tag cleanup independently
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

### AC2 — Verifies: [FR2](#fr2), [FR4](#fr4), [FR5](#fr5), [FR6](#fr6), [FR8](#fr8), [FR9](#fr9), [NFR2](#nfr2), [NFR3](#nfr3), [NFR4](#nfr4), [NFR5](#nfr5), [NFR6](#nfr6)

```gherkin
Scenario: Lifecycle runs preserve release ownership after cancellation
  Given a scheduled validation and an abandoned pull-request cleanup overlap a main-push release
  And the cleanup supersedes a canceled prerelease publication
  When all three runs complete
  Then the scheduled run reports validation without a release mutation
  And the cleanup reconciles only the abandoned pull request's prereleases
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
