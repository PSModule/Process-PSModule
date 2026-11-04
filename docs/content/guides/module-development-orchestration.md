---
title: Module development orchestration
description: Coordinate scoped module changes through an orchestrator, child sessions, and verified integration.
---

# Module development orchestration

Coordinate module work as small, independently verifiable changes. Use one
parent (orchestrator) session for the plan and integration. Assign independent
work to narrowly scoped child sessions.

During [Module bootstrap](../get-started/module-bootstrap.md), the shared
**integration branch** holds the load-bearing core. For an existing module,
follow the repository's
[trunk-based development](../specification/principles-and-practices.md#trunk-based-development)
default: child pull requests use short-lived branches and target `main`.
Use a stacked pull request only when a dependency requires it.

## Roles and boundaries

### Parent or orchestrator session

The orchestrator:

- defines the outcome, boundaries, dependencies, and acceptance criteria
- creates the bootstrap integration branch and its draft pull request to
  `main` when the module needs one
- gives each child one reviewable unit of work and the branch it must target
- keeps shared design decisions, naming, and cross-cutting changes consistent
- reviews each child pull request, runs the relevant validation, and integrates
  it into the shared branch
- owns release readiness for the coordinated change set

The orchestrator does not change a child's implementation without a recorded
scope decision. For changes outside a child's scope, the orchestrator should
create a separate child task or record an explicit decision.

### Child session

A child session owns one cohesive change. Examples include one public function
with tests, one documentation page, or one focused fix. A child should be able
to describe its change without references to unrelated planned work.

For each assigned change:

1. Start from `main` or the required bootstrap integration branch.
2. Open a **draft pull request** that targets the same branch.
3. Implement only the assigned scope. Validate the assigned change.
4. Update the documentation and tests required by that scope.
5. Before you request integration, report the result to the orchestrator.

Follow the repository's [branching and merging
practice](https://msx.no/docs/Ways-of-Working/Branching-and-Merging/) and the
shared [workflow](https://msx.no/docs/Ways-of-Working/Workflow/) for branches,
draft PRs, implementation, tests, and review. This page describes how to
coordinate those changes.

## Coordination protocol

### Give every child a complete handoff

The orchestrator's handoff should include:

- the user-visible outcome and the exact in-scope files or capability
- the base branch and the child pull request's target branch
- dependencies on other children, including what is deliberately out of scope
- the relevant [module
  standards](../reference/module-development-foundations.md), test guidance,
  and existing implementation to follow
- the validation expected before the child reports completion
- the orchestrator session's identifier or communication channel

If a prerequisite is missing or a design decision conflicts, the child should
stop at that boundary. The child should report the problem instead of
expanding its scope without a record.

### Require a useful completion report

The child reports:

- the draft pull request URL and target branch
- what changed and what was intentionally left out
- the tests, lint, documentation build, or other validation that ran, including
  failures
- decisions or risks the orchestrator must review
- follow-up issues for work that does not belong in the child pull request

The completion report does not replace review. Before you merge, read the
diff. Make sure that it satisfies the acceptance criteria. Run the smallest
relevant checks. Use
[Validating before review](validating-before-review.md) for the PSModule
validation pass.

### Integrate deliberately

After checks and review are complete, merge independent child pull requests
into `main` in any order. For dependent work, wait for the prerequisite to
merge or use an explicit stacked branch arrangement. Do not copy unreviewed
changes to make a child appear independent.

During bootstrap, merge child pull requests into the integration branch.
When the load-bearing core is ready, merge that branch to `main`.

Keep `main` or the bootstrap integration branch buildable. Resolve conflicts
in the orchestrator's context. After integration, rerun the affected checks.
Record cross-cutting decisions in the relevant pull request or issue.

## Release readiness

Release readiness applies to the integrated change. It does not justify a
long-lived release branch. Before you mark a bootstrap integration pull
request ready, examine the integrated change against these conditions.
Apply the same conditions before you report a coordinated trunk-based change
complete:

- every child pull request is merged, closed with a documented reason, or
  explicitly deferred with a follow-up issue
- the integrated branch passes the applicable build, test, lint, and
  documentation checks
- the final tree follows
  [Structuring your module](structuring-your-module.md), the module
  [repository standard](../reference/repository-standard.md), and the
  [test specification](../reference/test-specification.md)
- user-facing documentation, examples, and generated-help inputs describe the
  integrated behavior
- if a parent or coordinating pull request exists, it records the outcome and
  links the child pull requests. It identifies related issues without claiming
  unrelated work
- the version and prerelease intent match
  [Versioning and releases](versioning-and-releases.md)

If the change is not ready, keep the relevant pull request in draft.
Create a focused child task or follow-up issue for the remaining work.
When the change is ready, follow [Your first release](../get-started/your-first-release.md) and the canonical MSX
[definition of ready for review](https://msx.no/docs/Ways-of-Working/Definition-of-Ready-and-Done/#definition-of-ready-for-review).

## Relationship to other work

- Use [Module bootstrap](../get-started/module-bootstrap.md) when a new module
  needs a load-bearing core before its first release.
- For an existing module, use short-lived topic branches targeting `main`, as
  described in [Principles and practices](../specification/principles-and-practices.md).
- Use a stacked pull request only when one change depends on another.
  See [MSX branching and
  merging](https://msx.no/docs/Ways-of-Working/Branching-and-Merging/).
