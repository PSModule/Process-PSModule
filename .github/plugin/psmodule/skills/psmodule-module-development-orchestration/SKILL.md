---
name: psmodule-module-development-orchestration
description: Coordinate substantial PSModule development across a parent session and narrowly scoped child sessions while preserving trunk-based delivery, reviewability, and release readiness.
---

# Orchestrate substantial PSModule development

Use this skill when a module change is large enough to need several independent
workstreams, explicit dependencies, or coordinated review. Use the repository
[module development orchestration guide](../../../../../docs/content/guides/module-development-orchestration.md)
as the detailed process reference. Do not copy organization-wide rules into
this skill; follow the canonical [MSX Agentic Development](https://msx.no/docs/Ways-of-Working/Agentic-Development/),
[Workflow](https://msx.no/docs/Ways-of-Working/Workflow/), and
[Branching and Merging](https://msx.no/docs/Ways-of-Working/Branching-and-Merging/)
guidance.

## Decide whether coordination is warranted

Coordinate through a parent session when the work has two or more genuinely
independent deliverables, crosses code/tests/documentation/workflow boundaries,
has dependencies that need an explicit order, or needs parallel review and
integration. Keep the work in one session when it is a small change, a single
coherent function, a focused documentation correction, or a change one agent
can implement and validate without handoffs.

Before splitting work, inspect the repository README, local agent guidance,
module layout, relevant tests, workflow, documentation, and existing
validation commands. Establish the requested outcome, constraints, acceptance
evidence, and files that are in scope.

## Decompose and hand off

The parent/orchestrator owns the overall outcome, scope, dependency order,
integration decisions, release readiness, and final report. Decompose by
coherent deliverable rather than by arbitrary file count. Each child handoff
must state:

- the narrow objective and acceptance criteria;
- the allowed files and the files it must not change;
- dependencies and the expected branch/PR target;
- repository-native validation to run;
- the expected report-back format, including changed files, validation,
  decisions, blockers, and draft PR URL.

Children own their assigned deliverable end to end: inspect before editing,
open a draft PR early, use small commits with the required Copilot co-author
trailer, validate their scope, and report back. A child must stop and notify
the parent when requirements conflict, its scope expands, a dependency is
missing, validation exposes an unrelated failure, or the requested branch
target is unclear. It must not silently absorb adjacent work.

## Branch and pull-request policy

For an existing module, use trunk-based development by default:

1. Create a short-lived topic branch from the default branch.
2. Open a draft PR targeting the default branch as soon as the first coherent
   increment is pushed.
3. Keep independent child PRs separate and merge them through normal review.
4. Use a stacked PR only when a real dependency makes a separate target branch
   necessary, and follow the canonical MSX stacked-PR procedure.

Do not create a long-lived integration branch for ordinary feature work. The
only exception is a brand-new module with no usable release whose
load-bearing core has not landed. In that bootstrap case, use the
[module bootstrap guide](../../../../../docs/content/get-started/module-bootstrap.md):
keep one narrowly scoped integration branch for the core, let focused child
PRs target it, and open the integration PR to the default branch when the core
is coherent. Once the first release is on the default branch, return to the
ordinary trunk-based policy.

Never target an existing documentation PR, issue, or unrelated worktree
instead of the agreed branch. Do not merge, close, retarget, or modify another
session's PR or issue without explicit ownership from the parent.

## Integrate and review

The parent reviews each child PR against its acceptance criteria and the
repository contract before integration. Confirm that:

- the child diff stays within its handoff and preserves unrelated behavior;
- dependent work is integrated in dependency order;
- tests, lint, build/package, workflow, and documentation changes are wired
  together rather than merely passing in isolation;
- generated files, permissions, release labels, and public module behavior
  receive deliberate review.

Merge through the agreed PR flow; do not bypass review with direct default
branch pushes. After each merge, refresh dependent branches and rerun affected
checks before integrating the next dependent change. Resolve conflicts by
preserving the repository's current source of truth, not by taking whichever
branch happens to be newer.

## Validate and assess release readiness

Use the repository's own commands and local guidance. At minimum, run the
smallest relevant checks for the changed surface, then escalate when results
show a broader dependency:

- build the module and run the affected Pester tests;
- run the repository's PSScriptAnalyzer/lint and workflow validation;
- build documentation when documentation or navigation changed;
- review the final diff, PR checks, public exports, version/release labels, and
  required artifacts.

Apply the PSModule
[validation before review](../../../../../docs/content/guides/validating-before-review.md)
checklist. A change is release-ready only when all child work is integrated,
required checks are green or explicitly blocked and owned, documentation and
tests match the delivered behavior, and the release intent follows
[versioning and releases](../../../../../docs/content/guides/versioning-and-releases.md).
For a bootstrap integration branch, release readiness means the minimum
load-bearing core is coherent; do not expand the exception to unrelated v1
features.

## Report back and stop

The parent report must include the draft PR URL, files changed, commits,
validation commands and outcomes, policy decisions (especially branch target
and any bootstrap exception), unresolved blockers, and the next integration
step. The parent should not mark the work complete or the PR ready for review
until every child has reported and the combined result has passed the
repository-native validation and review gates.

Stop instead of guessing when scope, ownership, branch target, release intent,
or acceptance evidence is ambiguous; when a required dependency or credential
is unavailable; when validation fails without an understood owner; or when
integration would modify unrelated work. Record the blocker and return control
to the parent.

## References

- [Module development orchestration](../../../../../docs/content/guides/module-development-orchestration.md)
- [PSModule repository standard](../../../../../docs/content/reference/repository-standard.md)
- [Structuring your module](../../../../../docs/content/guides/structuring-your-module.md)
- [MSX PR format](https://msx.no/docs/Ways-of-Working/PR-Format/)
- [MSX Implement guidance](https://msx.no/docs/Agents/implement/)
