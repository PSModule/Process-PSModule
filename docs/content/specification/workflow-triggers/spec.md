---
title: Workflow triggers - Spec
description: Retain production work while superseding obsolete pull-request activity with separate caller policies.
---

# Workflow triggers - Spec

The caller workflow admits Process-PSModule work with separate native GitHub Actions policies. Default-branch
production and manual releases are retained; activity for each pull request converges on its latest event; a close
event supersedes that pull request's activity before the reusable workflow evaluates optional prerelease cleanup.

## Problem

Production publication cannot safely lose queued runs, while rapid pull-request updates should not consume resources
after they are obsolete. Both event types invoke the same reusable workflow, so admission must distinguish a
default-branch Git ref from a pull-request number without adding workflow jobs or a dispatcher.

## Outcomes and impact

- **Outcome:** Production work is retained, and a pull request receives feedback for its latest admitted state.
- **DORA:** Shorter pull-request feedback lead time without losing accepted production delivery intent.
- **Domain signal:** No accepted production event is replaced within the native queue capacity.

## Users and jobs

Module maintainers retain stable publication runs and manual releases. Contributors avoid waiting for obsolete
pull-request activity. Repository operators retain the existing close-triggered prerelease cleanup setting.

## Scope

**In scope:** Caller admission, production serialization, pull-request supersession, and admission of close events.

**Out of scope:** An external queue, custom dispatcher jobs, version-label policy, build logic, and prerelease
ownership or deletion implementation.

## Non-goals

- Unlimited event storage or strict chronological execution when GitHub delivery order differs from push order.
- Preventing every obsolete run from starting before a later event arrives.
- Restoring external publication after cancellation.

## Functional requirements

### FR1 - Admit work through caller policies {#fr1}

The caller workflow MUST apply a retained policy to non-pull-request work and a superseding policy to pull-request
work. The retained policy MUST group work by Git ref without canceling it; the superseding policy MUST group work by
pull-request number and cancel obsolete activity. Each policy MUST cover its complete reusable-workflow call. The
reusable workflow selects processing or close behavior from the original event.

#### Caller admission scenario

```gherkin
Scenario: Call the workflow
  Given a caller subscribes to default-branch and pull-request events
  And it declares the documented concurrency policies
  When it calls Process-PSModule
  Then each complete reusable-workflow call has its required admission policy
  And no dispatcher is required
```

### FR2 - Retain and serialize production work {#fr2}

Each default-branch push and manual default-branch release MUST share a retained group. A later admitted production
event MUST NOT cancel a running production pipeline or replace an accepted pending production event within supported
capacity. The complete pipeline executes at most once at a time and retains its triggering revision.

#### Production retention scenario

```gherkin
Scenario: Preserve a production burst
  Given production run A is executing
  When pushes B and C are admitted
  Then A is not canceled
  And B and C wait and execute serially
  And each run uses its triggering revision
```

### FR3 - Supersede pull-request activity {#fr3}

An `opened`, `reopened`, `synchronize`, `labeled`, or `unlabeled` event MUST cancel running activity and replace
pending activity for the same pull request. Different pull requests and production work MUST remain independent.
Once updates stop, the latest admitted pull-request activity proceeds.

#### Pull-request activity scenario

```gherkin
Scenario: Push three revisions rapidly
  Given revision A is processing for pull request 42
  When revisions B and C arrive
  Then superseded activity for pull request 42 is canceled
  And only the latest admitted activity proceeds
  And production and pull request 43 are unaffected
```

### FR4 - Supersede activity on closure {#fr4}

A merged or abandoned pull request MUST use the same pull-request group as its activity. Its `closed` event MUST
cancel outstanding activity for that pull request and invoke the reusable workflow's close path. The close path MUST
NOT authorize build, test, stable publication, or site deployment. It evaluates prerelease cleanup through the
existing repository setting.

#### Closure scenario

```gherkin
Scenario: Close during pull-request activity
  Given pull-request activity is running for pull request 42
  When pull request 42 closes
  Then its activity is canceled
  And the close path runs after cancellation
  And a default-branch production run is unaffected
```

## Non-functional requirements

### NFR1 - Use maximum native retention {#nfr1}

The production group MUST use GitHub's `max` queue: one running execution and up to 100 pending executions. Overflow
remains visible as a canceled execution; it MUST NOT be reported as retained work.

### NFR2 - Keep lifecycle identities isolated {#nfr2}

Concurrency identity MUST distinguish every pull request from all Git refs. A closed pull request uses its number,
not the default-branch ref associated with a merge. Caller groups MUST differ from any reusable-workflow group to avoid
recursive cancellation.

## Acceptance criteria

```gherkin
# AC1 - Verifies: FR1, FR2, FR3, FR4, NFR1, NFR2
Scenario: Production and pull-request lifecycle
  Given a production run and pull-request activity are running
  When two production pushes, two pull-request updates, and a close event arrive
  Then production work completes serially
  And obsolete pull-request activity is canceled
  And the close path executes
  And no production run is canceled by pull-request activity or closure
```

## Constraints and assumptions

- **Constraint:** GitHub queues by when an execution starts waiting, not strict push or commit chronology.
- **Constraint:** Cancellation is asynchronous and does not roll back an already accepted external operation.
- **Constraint:** A later event for a reopened pull request can supersede a still-running close path; cleanup checks
  the live lifecycle before mutation.
- **Assumption:** Each repository uses one named caller workflow for Process-PSModule.

## Dependencies

- [GitHub concurrency](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency)
  - queue and cancellation semantics.
- [Settings](../../reference/settings.md) - existing prerelease cleanup setting.

## Where this connects

- [Design](design.md) - caller configuration and compatibility.
