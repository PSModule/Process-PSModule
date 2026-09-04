---
title: Workflow triggers - Spec
description: Preserve production runs, replace obsolete pull-request work, and clean up owned prereleases after closure.
---

# Workflow triggers - Spec

Process-PSModule admits work into independent production, pull-request, and closure tracks. Production runs retain accepted work; pull-request runs favor the latest revision; closure stops obsolete work before optionally removing its prereleases. Module repositories select events and provide credentials, not scheduling algorithms.

## Problem

One scheduling policy cannot safely serve both production publication and rapid pull-request updates. Replacing queued production work loses delivery intent; retaining obsolete pull-request work delays feedback. Cleanup that races a publisher can leave orphaned prereleases or remove another pull request's output.

## Outcomes and impact

- **Outcome:** Accepted production events reach a terminal result without replacement by later events, while obsolete pull-request runs yield to current work.
- **DORA:** Shorter feedback lead time without increasing publication failures caused by overlapping runs.
- **Domain signal:** Zero production events evicted within supported queue capacity, zero overlapping production pipelines, and zero owned GitHub prereleases remaining after successful enabled cleanup.

## Users and jobs

Module maintainers publish accepted changes reliably. Contributors receive feedback for the latest pull-request state. Repository operators choose whether to retain prereleases and can identify failed, canceled, or capacity-rejected work.

## Scope

**In scope:** Event admission, track isolation, production serialization, pull-request supersession, closure cancellation, prerelease cleanup, and the minimum caller contract.

**Out of scope:** Version-label policy, quality gates, module build logic, merge-queue integration, and changing the production branch model.

## Non-goals

- Unlimited durable event storage or guaranteed completion despite platform outages, failures, manual cancellation, or timeouts.
- Debouncing that prevents every obsolete run from starting.
- Deleting or unlisting PowerShell Gallery packages, or treating cancellation as rollback of an external publication.

## Functional requirements

### FR1 - Central scheduling policy {#fr1}

The framework MUST own track selection, queue policy, and cancellation rules. A caller MUST NOT need concurrency expressions, a dispatcher job, or separate jobs for each track. Callers MUST subscribe to the required events and supply the established credentials and permissions. Cleanup configuration MUST use the existing repository settings contract.

#### Caller scenario

```gherkin
Scenario: Use the standard caller
  Given a caller with the required event subscriptions, permissions, and secrets
  And no caller concurrency block or scheduling inputs
  When supported events invoke the framework
  Then the framework selects their tracks without additional caller logic
```

### FR2 - Retain and serialize production work {#fr2}

Each push to the repository default branch, normally `main`, MUST enter the production track. All supported stable-publication entry points MUST share its serialization boundary. At most one production pipeline MUST execute at a time, from planning and version resolution through its final enabled stage.

A later event MUST NOT cancel a running production pipeline or replace an accepted pending production event within supported capacity. Pending events MUST execute sequentially in admission order, subject to the platform ordering boundary in the design. Each run MUST retain its triggering revision; it MUST NOT silently build a newer branch tip after waiting. Admission does not bypass important-file, release-label, or quality gates.

#### Production scenarios

```gherkin
Scenario: Preserve a production burst
  Given production run A is executing
  When pushes B and C are admitted in that order
  Then A is not canceled by either push
  And B and C remain pending
  And B executes after A terminates
  And C executes after B terminates
  And each run uses its own triggering revision

Scenario: Share the production authority
  Given a production push run is executing
  When a supported manual stable-publication run is admitted
  Then the manual run waits in the same production track
```

### FR3 - Supersede obsolete pull-request work {#fr3}

An update to an open pull request MUST request cancellation of older running work and replace older pending work for that pull request. Different pull requests MUST NOT cancel one another. Once updates stop and cancellation settles, only the latest eligible state proceeds; obsolete work MUST NOT begin another publication after failing a freshness check.

The rule applies to revision updates and supported release-intent changes, including label removal. Cancellation MAY allow already-started steps or external requests to finish. A burst therefore guarantees latest-state convergence, not exactly one workflow start.

Supersession follows admission order, not a guaranteed chronological delivery order. If delayed delivery displaces the current revision and leaves only obsolete work, the framework MUST reject stale work and report that the current revision needs a rerun rather than report current validation as successful.

#### Supersession scenarios

```gherkin
Scenario: Push three revisions rapidly
  Given revision A is running for pull request 42
  When revisions B and C arrive in that order before A finishes
  And no later updates arrive
  Then cancellation is requested for superseded work
  And only C proceeds after cancellation settles
  And production runs and pull request 43 are unaffected

Scenario: Remove prerelease intent
  Given a pull-request run is eligible to publish a prerelease
  When the prerelease label is removed before publication begins
  Then the older run is superseded
  And its publication eligibility is rechecked before any new publication
```

### FR4 - Close, stop, then clean {#fr4}

Both merged and abandoned pull requests MUST enter the closure track. Closure MUST request cancellation of running and pending activity belonging to the closing pull-request lifecycle, then wait for that activity to reach a terminal state before deleting prereleases. Closure MUST NOT build, test, publish a module, deploy a site, or authorize a stable release.

Closure runs MUST NOT be canceled by production pushes, pull-request updates, or later closure events. A merge's closure and default-branch push MUST remain separate operations. Closing obsolete activity is independent of whether prerelease deletion is enabled.

#### Closure scenarios

```gherkin
Scenario: Close during prerelease publication
  Given a pull-request activity run is publishing a prerelease
  When that pull request closes
  Then the closure run requests cancellation of that activity
  And it waits for the activity to terminate before deleting prereleases
  And it reports incomplete cleanup if termination cannot be confirmed

Scenario: Merge creates two independent operations
  Given a prerelease pull request is merged
  When its closure event and default-branch push are admitted
  Then closure stops obsolete pull-request work and evaluates cleanup
  And the push enters the production queue
  And neither operation cancels the other
```

### FR5 - Optional, exact, repeatable cleanup {#fr5}

Automatic cleanup MUST be enabled by default and MUST be disableable through the established cleanup setting. Enabled cleanup MUST enumerate all GitHub prerelease releases and tags provably owned by the closing pull-request lifecycle, including recoverable partial publication records. It MUST preserve stable releases, other pull requests' resources, and resources from a later reopening.

Cleanup MUST work without the prerelease label still being present, without important-file changes, and without the source branch still existing. Repeating successful cleanup MUST succeed with nothing left to delete. Ambiguous ownership, incomplete enumeration, or an unresolved deletion MUST be reported, not presented as successful complete cleanup.

#### Cleanup scenarios

```gherkin
Scenario: Retain prereleases by configuration
  Given automatic cleanup is disabled
  When a pull request closes
  Then obsolete activity is stopped
  And no prerelease release or tag is deleted
  And retention is reported as intentional

Scenario: Clean beyond the first page
  Given a closed pull request owns prereleases spanning multiple result pages
  And its prerelease label and source branch have been removed
  When enabled cleanup succeeds
  Then all its owned GitHub prerelease releases and tags are absent
  And stable releases and other pull requests' resources are unchanged

Scenario: Reopen while cleanup is pending
  Given a closure run is pending for an earlier pull-request lifecycle
  When the pull request reopens and produces another prerelease
  Then the earlier closure neither cancels the reopened activity nor deletes its output
```

## Non-functional requirements

### NFR1 - Maximum supported queue capacity {#nfr1}

The production track MUST use the platform's maximum supported pending-run capacity, with no smaller framework or caller limit. Capacity and ordering guarantees MUST be documented precisely. Overflow or expiry MUST remain visible as unsuccessful admission or execution; it MUST NOT be described as successful delivery.

#### Capacity scenario

```gherkin
Scenario: Fill the production queue
  Given one production run is active
  When pending runs fill the documented maximum capacity
  Then every admitted pending run is retained
  When another run exceeds capacity
  Then the platform's rejection or cancellation is visible
  And no retained run is silently replaced by the framework
```

### NFR2 - Bounded and diagnosable cleanup {#nfr2}

Every executing closure run MUST record its pull request, lifecycle boundary, cleanup decision, targeted run IDs, and resource outcomes without exposing secrets. Waiting for canceled activity MUST have a finite documented deadline. Deadline expiry MUST fail cleanup without beginning deletion; enumeration and deletion failures MUST produce a failing result with enough identity to retry safely.

### NFR3 - Narrow authority {#nfr3}

Cancellation and deletion MUST be restricted to the caller repository and verified framework-owned work. Cleanup MUST NOT execute untrusted pull-request code with write credentials. Unsupported credential contexts MUST fail or explicitly skip privileged work; they MUST NOT appear to have cleaned resources.

## Acceptance criteria

```gherkin
# AC1 - Verifies: FR2, FR3, FR4, FR5, NFR2
Scenario: Production burst during pull-request closure
  Given one production run and one prerelease pull-request run are active
  When two more production pushes arrive and the pull request closes
  Then all three production runs remain serialized and are not superseded
  And the closing pull-request activity is canceled before cleanup deletes anything
  And successful enabled cleanup leaves no owned GitHub prereleases
  And the closure run records what was stopped and removed

# AC2 - Verifies: FR1, FR4, FR5, NFR3
Scenario: Clean an abandoned change with the standard caller
  Given the standard caller and default cleanup settings
  And an abandoned pull request owns several prereleases
  When it closes without merging
  Then cleanup runs without a special caller job
  And no stable release is created
  And only resources with verified ownership are deleted
```

## Constraints and assumptions

- **Constraint:** Platform scheduling and cancellation are asynchronous. Cancellation does not undo PowerShell Gallery uploads or already-accepted API requests.
- **Constraint:** Native supersession selects the latest admitted invocation. Freshness checks prevent obsolete publication but do not make event delivery and cancellation atomic.
- **Constraint:** The caller controls event delivery, filtering, permissions, and any outer concurrency policy. The framework cannot recover events the caller never invokes.
- **Constraint:** Guarantees apply within documented platform queue and runtime limits, not to arbitrary external cancellation or failed quality gates.
- **Assumption:** A repository has one production caller for a module. Independent modules or unrelated workflows are not coordinated unless they share an explicit framework identity.

## Dependencies

- [Framework spec](../spec.md) - release authority and publication requirements.
- [Settings](../../reference/settings.md) - authorable cleanup policy.

## Where this connects

- [Design](design.md) - scheduling boundaries, platform limits, and cleanup implementation.
