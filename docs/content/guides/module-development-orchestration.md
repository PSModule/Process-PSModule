---
title: Module development orchestration
description: Coordinate substantial module work across an orchestrator session and narrowly scoped child sessions, then integrate it safely for release.
---

# Module development orchestration

Substantial module work is easier to review and integrate when it is split into
small, independently verifiable changes. Use one parent (orchestrator) session
to own the plan and integration branch, and use narrowly scoped child sessions
for the work that can proceed independently.

This complements [Module bootstrap](../get-started/module-bootstrap.md). During
bootstrap, the shared branch is an **integration branch** for the load-bearing
core. For a larger change to an existing module, it is usually a **release
branch** representing the intended release. In both cases, child pull requests
target the shared branch and the parent owns the pull request to `main`.

## Roles and boundaries

### Parent or orchestrator session

The orchestrator:

- defines the outcome, boundaries, dependencies, and acceptance criteria
- creates the integration or release branch and its draft pull request to
  `main`
- gives each child one reviewable unit of work and the branch it must target
- keeps shared design decisions, naming, and cross-cutting changes coherent
- reviews each child pull request, runs the relevant validation, and integrates
  it into the shared branch
- owns release readiness and the final pull request to `main`

The orchestrator coordinates the work; it does not become a second place where
the implementation is silently changed. Changes outside a child's scope should
become a new child task or an explicitly recorded decision.

### Child session

A child session owns one cohesive change, such as one public function and its
tests, one documentation page, or one focused fix. A child should be able to
describe its change without referring to unrelated planned work.

Each child:

1. starts from the shared integration or release branch
2. opens a **draft pull request** targeting that branch, not `main`
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

Merge children into the shared branch only after their checks and review are
complete. Integrate independent children in any order. For dependent work,
either wait for the prerequisite to merge or make the dependency explicit in a
stacked branch arrangement; do not make a child appear independent by copying
unreviewed changes.

Keep the shared branch buildable. Resolve conflicts in the orchestrator's
context, rerun affected checks after integration, and record any cross-cutting
decision in the relevant pull request or issue.

## Release readiness

Keep the parent pull request to `main` in draft until the shared branch is a
coherent release candidate. Before marking it ready, confirm:

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
- the release pull request records the outcome, links the child pull requests,
  and identifies related issues without claiming unrelated work
- the version and prerelease intent match
  [Versioning and releases](versioning-and-releases.md)

If the branch is not ready, keep the parent pull request in draft and create
another focused child task or follow-up issue. Once it is ready, follow [Your
first release](../get-started/your-first-release.md) and the canonical MSX
[definition of ready for review](https://msx.no/docs/Ways-of-Working/Definition-of-Ready-and-Done/#definition-of-ready-for-review).

## Relationship to other work

- Use [Module bootstrap](../get-started/module-bootstrap.md) when a new module
  needs a load-bearing core before its first release.
- Use a release branch for a larger post-release effort, as described in
  [Principles and practices](../specification/principles-and-practices.md).
- Use an ordinary topic branch for a self-contained change that does not need
  coordination across several child sessions.
- Use a stacked pull request only when the changes genuinely depend on one
  another; see [MSX branching and
  merging](https://msx.no/docs/Ways-of-Working/Branching-and-Merging/).
