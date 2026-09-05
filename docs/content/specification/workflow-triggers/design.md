---
title: Workflow triggers - Design
description: Use one caller-owned GitHub Actions concurrency group for retained production and replaceable pull-request work.
---

# Workflow triggers - Design

The caller workflow holds one concurrency slot for its complete call to `.github/workflows/workflow.yml`. It retains
non-pull-request work, replaces activity for an individual pull request, and lets the reusable workflow select its
normal processing or close behavior from the incoming event.

## Specification

[Workflow triggers - Spec](spec.md) defines the required admission behavior.

## Approach

Every caller uses this workflow-level configuration:

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}
  queue: ${{ github.event_name == 'pull_request' && 'single' || 'max' }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
```

The group expression is a fallback, not concatenation. A pull-request event uses its number; every other event uses
its Git ref. The caller workflow name scopes the group from other workflow names in the same repository, so no
additional prefix is needed.

The queue expression distinguishes the two policies:

- Pull-request events use the one-pending replacement queue and cancel active work.
- All other events use the maximum retained queue and do not cancel active work. This includes `push`,
  `workflow_dispatch`, and any scheduled event.

## Alternatives considered

| Option | Trade-offs | Verdict |
| --- | --- | --- |
| One conditional caller workflow-level group | Covers the complete reusable-workflow call with three expressions and preserves the required event behavior. | Chosen. |
| One conditional producer workflow-level group | A live experiment failed concurrent production admission before jobs began. | Rejected. |
| One caller group with `queue: max` and no cancellation | Retains every event but does not converge pull-request activity or prioritize closure. | Rejected. |
| Per-track router jobs | Separates closure from activity but adds nested reusable workflows, receipts, and coordination beyond the required caller setting. | Rejected. |
| External dispatcher | Provides stronger retention and ordering at the cost of persistent state and operational ownership. | Rejected. |

## Architecture

| Component | Responsibility |
| --- | --- |
| Caller workflow | Subscribes to events and applies the concurrency group before invoking the reusable workflow. |
| GitHub Actions | Retains non-pull-request work or cancels superseded pull-request work for the matching group. |
| `workflow.yml` | Receives the original caller event and routes it through the existing processing or close path. |

The caller-level group covers all nested reusable jobs until the calling job completes. It therefore serializes
planning, version resolution, publication, and enabled teardown rather than only a short admission step.

## Data and contracts

| Event | Group identity | Queue | Cancel active work | Result |
| --- | --- | --- | --- | --- |
| Default-branch `push` | `<workflow>-refs/heads/<branch>` | `max` | No | Retained production work. |
| Default-branch `workflow_dispatch` | `<workflow>-refs/heads/<branch>` | `max` | No | Retained manual production work. |
| Open pull-request activity | `<workflow>-<number>` | `single` | Yes | Latest activity for that pull request. |
| `pull_request.closed` | `<workflow>-<number>` | `single` | Yes | Cancels activity and invokes the close path. |
| Scheduled event | `<workflow>-<ref>` | `max` | No | Retained non-pull-request work. |

A merge's close event has the same pull-request number as its activity even when its Git ref resolves to the default
branch. It therefore cancels activity in the pull-request group, while the resulting default-branch push uses a
different group and proceeds independently.

## Reusable workflow compatibility

The caller group is deliberately unprefixed. The current reusable workflow uses
`Process-PSModule-${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}`. The names differ,
which prevents a cancellation-enabled caller group from canceling its own caller job through the called workflow.

Do not add `Process-PSModule-` to the caller group while that reusable group exists. The group names are
repository-local and case-insensitive. If a future reusable workflow removes its group, this caller configuration
remains valid without modification.

## Security

Concurrency uses only GitHub event metadata. It requires no secrets and grants no additional permissions. The existing
reusable workflow retains responsibility for credential handling and for evaluating the trusted cleanup setting.

## Testing strategy

Use a disposable, nonpublishing caller and producer. Verify three competing production pushes finish serially, a
manual run waits behind production, rapid updates cancel activity for one pull request without affecting another, and
a close event cancels activity before the close path runs.

Live GitHub Actions experiments validated the configuration with a distinct prefixed group in the reusable producer:
three production runs completed serially; a manual run waited behind a push and executed the production path; three
rapid pull-request activity runs were canceled; and the closure run completed its close job. A separate experiment
showed that placing the conditional group in the producer fails under concurrent production admission.

## Rollout and operability

Replace the caller's existing `cancel-in-progress: false` block with the documented configuration. No new input,
secret, dispatcher, or reusable-workflow version is required. Keep the group distinct from the reusable workflow's
prefixed group.

GitHub retains one running and up to 100 pending executions for a `max` group. It does not guarantee commit-order
execution. Overflow, manual cancellation, and external publication results remain visible in Actions; concurrency
cancellation does not undo an already accepted external operation.
