---
title: Module development orchestration
description: Coordinate substantial module work across an orchestrator session and narrowly scoped child sessions, then integrate it safely for release.
---

# Module development orchestration

Substantial module work is easier to review and integrate when it is split into
small, independently verifiable changes. Use one parent (orchestrator) session
to own the plan and integration, and use narrowly scoped child sessions for the
work that can proceed independently.

This complements [Module bootstrap](../get-started/module-bootstrap.md). During
bootstrap, the shared branch is an **integration branch** for the load-bearing
core. For an existing module, follow the repository's
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
- keeps shared design decisions, naming, and cross-cutting changes coherent
- reviews each child pull request, runs the relevant validation, and integrates
  it into the shared branch
- owns release readiness for the coordinated change set

The orchestrator coordinates the work; it does not become a second place where
the implementation is silently changed. Changes outside a child's scope should
become a new child task or an explicitly recorded decision.

### Child session

A child session owns one cohesive change, such as one public function and its
tests, one documentation page, or one focused fix. A child should be able to
describe its change without referring to unrelated planned work.

Each child:

1. starts from `main`, or from the bootstrap integration branch when one is
   required
2. opens a **draft pull request** targeting `main`, or the bootstrap integration
   branch when one is required
3. implements and validates only its assigned scope
4. updates the documentation and tests required by that scope
5. reports the result to the orchestrator before asking for integration

Use the repository's normal [branching and merging
practice](https://msx.no/docs/Ways-of-Working/Branching-and-Merging/) and the
shared [workflow](https://msx.no/docs/Ways-of-Working/Workflow/) for the
ordinary branch, draft PR, implementation, test, and review loop. This page
only describes how to coordinate several such changes.

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

If the child discovers a missing prerequisite or a conflicting design choice,
it should stop at that boundary and report it rather than expanding its scope
silently.

### Require a useful completion report

The child reports:

- the draft pull request URL and target branch
- what changed and what was intentionally left out
- the tests, lint, documentation build, or other validation that ran, including
  failures
- decisions or risks the orchestrator must review
- follow-up issues for work that does not belong in the child pull request

The orchestrator treats this as input to review, not as a substitute for
review. Read the diff, verify the acceptance criteria, and run the smallest
relevant checks before merging. Use
[Validating before review](validating-before-review.md) for the PSModule
specific validation pass.

### Integrate deliberately

Merge children only after their checks and review are complete. Merge
independent children into `main` in any order. For dependent work, either wait
for the prerequisite to merge or make the dependency explicit in a stacked
branch arrangement; do not make a child appear independent by copying
unreviewed changes. During bootstrap, merge children into the integration
branch, then merge that branch to `main` when the load-bearing core is ready.

Keep `main` or the bootstrap integration branch buildable. Resolve conflicts in
the orchestrator's context, rerun affected checks after integration, and record
any cross-cutting decision in the relevant pull request or issue.

## Release readiness

Release readiness is a property of the integrated change, not a reason to keep
a long-lived release branch. Before marking a bootstrap integration pull
request ready, or reporting a coordinated trunk-based change complete, confirm:

- every child pull request is merged, closed with a documented reason, or
  explicitly deferred with a follow-up issue
- the integrated branch passes the applicable build, test, lint, and
  documentation checks
- the final tree still follows
  [Structuring your module](structuring-your-module.md), the module
  [repository standard](../reference/repository-standard.md), and the
  [test specification](../reference/test-specification.md)
- user-facing documentation, examples, and generated-help inputs describe the
  integrated behavior
- the parent or coordinating pull request records the outcome, links the child
  pull requests when one exists, and identifies related issues without claiming
  unrelated work
- the version and prerelease intent match
  [Versioning and releases](versioning-and-releases.md)

If the change is not ready, keep the relevant pull request in draft and create
another focused child task or follow-up issue. Once it is ready, follow [Your
first release](../get-started/your-first-release.md) and the canonical MSX
[definition of ready for review](https://msx.no/docs/Ways-of-Working/Definition-of-Ready-and-Done/#definition-of-ready-for-review).

## Relationship to other work

- Use [Module bootstrap](../get-started/module-bootstrap.md) when a new module
  needs a load-bearing core before its first release.
- For an existing module, use short-lived topic branches targeting `main`, as
  described in [Principles and practices](../specification/principles-and-practices.md).
- Use a stacked pull request only when the changes genuinely depend on one
  another; see [MSX branching and
  merging](https://msx.no/docs/Ways-of-Working/Branching-and-Merging/).
