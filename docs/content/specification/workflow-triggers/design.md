---
title: Workflow triggers - Design
description: Use separate caller-owned GitHub Actions job policies for retained production and replaceable pull-request work.
---

# Workflow triggers - Design

The caller workflow uses two mutually exclusive calling jobs for `.github/workflows/workflow.yml`. One retains
non-pull-request work; the other replaces activity for an individual pull request. The reusable workflow selects its
normal processing or close behavior from the incoming event.

## Specification

[Workflow triggers - Spec](spec.md) defines the required admission behavior.

## Approach

Every caller uses these job-level policies:

```yaml
jobs:
  Process-PSModule-Production:
    if: ${{ github.event_name != 'pull_request' }}
    concurrency:
      group: ${{ github.workflow }}-${{ github.ref }}
      queue: max

  Process-PSModule-PullRequest:
    if: ${{ github.event_name == 'pull_request' }}
    concurrency:
      group: ${{ github.workflow }}-${{ github.event.pull_request.number }}
      queue: single
      cancel-in-progress: true
```

Each calling job uses the same permissions, reusable-workflow reference, and secret mapping. The caller workflow name
scopes both groups from other workflows in the same repository, so no additional prefix is needed. GitHub requires a
literal queue value and rejects `queue: max` with `cancel-in-progress: true`; separate jobs are therefore required to
apply both policies.

## Alternatives considered

| Option | Trade-offs | Verdict |
| --- | --- | --- |
| Two caller job-level policies | Each complete reusable-workflow call has a static, compatible queue and cancellation policy. | Chosen. |
| One conditional caller workflow-level group | GitHub requires a literal `queue` value and rejects `queue: max` with cancellation enabled. | Rejected. |
| One conditional producer workflow-level group | A live experiment failed concurrent production admission before jobs began. | Rejected. |
| One caller group with `queue: max` and no cancellation | Retains every event but does not converge pull-request activity or prioritize closure. | Rejected. |
| Per-track router jobs | Separates closure from activity but adds nested reusable workflows, receipts, and coordination beyond the required caller setting. | Rejected. |
| External dispatcher | Provides stronger retention and ordering at the cost of persistent state and operational ownership. | Rejected. |

## Architecture

| Component | Responsibility |
| --- | --- |
| Caller workflow | Subscribes to events and routes each event to the calling job with its concurrency policy. |
| GitHub Actions | Retains non-pull-request work or cancels superseded pull-request work for the matching group. |
| `workflow.yml` | Receives the original caller event and routes it through the existing processing or close path. |

Each caller job-level group covers all nested reusable jobs until the calling job completes. It therefore serializes
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

The caller groups are deliberately unprefixed. The current reusable workflow uses
`Process-PSModule-${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}`. The names differ,
which prevents the cancellation-enabled caller job from canceling its own caller job through the called workflow.

Do not add `Process-PSModule-` to either caller group while that reusable group exists. The group names are
repository-local and case-insensitive. If a future reusable workflow removes its group, this caller configuration
remains valid without modification.

## Security

Concurrency uses only GitHub event metadata. It requires no secrets and grants no additional permissions. The existing
reusable workflow retains responsibility for credential handling and for evaluating the trusted cleanup setting.

## Testing strategy

Use a disposable, nonpublishing caller and producer. Verify three competing production pushes finish serially, a
manual run waits behind production, rapid updates cancel activity for one pull request without affecting another, and
a close event cancels activity before the close path runs. Confirm the pull-request job uses `queue: single` and the
production job uses `queue: max`.

## Rollout and operability

Replace the caller's existing generic calling job with the documented production and pull-request jobs. No new input,
secret, dispatcher, or reusable-workflow version is required. Keep both groups distinct from the reusable workflow's
prefixed group.

GitHub retains one running and up to 100 pending executions for a `max` group. It does not guarantee commit-order
execution. Overflow, manual cancellation, and external publication results remain visible in Actions; concurrency
cancellation does not undo an already accepted external operation.
