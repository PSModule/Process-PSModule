---
name: psmodule-module-development-orchestration
description: Coordinate substantial PSModule development across a parent session and narrowly scoped child sessions while preserving trunk-based delivery, reviewability, and release readiness.
---

# Orchestrate substantial PSModule development

Use this skill when a module change needs multiple independent workstreams,
explicit dependencies, or coordinated integration. First read the repository
[module development orchestration guide](../../../../../docs/content/guides/module-development-orchestration.md).
That guide is the source of common user and agent process. This skill adds only
the session-specific operating contract below.

## Decide and decompose

Keep small, coherent changes in one session. Create a parent/orchestrator
session when the work crosses capabilities or code, tests, documentation, or
workflow surfaces; has dependencies; or needs parallel review.

The parent owns the outcome, boundaries, dependency order, shared decisions,
integration, release readiness, and final report. Give each child one
reviewable deliverable. Every handoff must include:

- the objective and acceptance evidence;
- allowed files and explicit exclusions;
- dependencies, base branch, and PR target;
- repository-native validation;
- the parent session or communication channel for report-back.

## Agent operating contract

For an existing module, use a short-lived topic branch from the default branch
and target the default branch. Use the integration-branch exception only for a
brand-new module's load-bearing first-release core, as described in the
[module bootstrap guide](../../../../../docs/content/get-started/module-bootstrap.md).
Use a stacked PR only for a genuine dependency.

Each child must:

1. Inspect local guidance, the module layout, and the assigned surface before
   editing.
2. Stay within the handoff; make adjacent work a new child task.
3. Open a draft PR early, push small commits, and include the required Copilot
   co-author trailer in each commit.
4. Run the validation named in the handoff and record commands and outcomes.
5. Report the draft PR URL and target, changed and excluded files, validation,
   decisions or risks, blockers, and follow-up work before requesting
   integration.

The parent reviews each child diff and acceptance criterion, integrates through
the normal PR flow, and reruns affected checks after each dependent merge. Do
not bypass review with a direct default-branch push or modify another session's
PR or issue without explicit ownership.

Use the PSModule
[validation before review](../../../../../docs/content/guides/validating-before-review.md)
guidance and [versioning and releases](../../../../../docs/content/guides/versioning-and-releases.md)
for the common validation and release-readiness gates. Keep the coordinated PR
in draft when the integrated result is not ready.

## Stop conditions

Stop and report to the parent instead of guessing when scope, ownership,
acceptance evidence, branch target, release intent, or a required dependency is
ambiguous; when validation fails without a known owner; or when integration
would modify unrelated work. Do not silently expand scope, merge unreviewed
changes, or claim release readiness.

## References

- [Module development orchestration](../../../../../docs/content/guides/module-development-orchestration.md)
- [PSModule repository standard](../../../../../docs/content/reference/repository-standard.md)
- [Structuring your module](../../../../../docs/content/guides/structuring-your-module.md)
- [MSX Agentic Development](https://msx.no/docs/Capabilities/agentic-development/)
- [MSX Workflow](https://msx.no/docs/Ways-of-Working/Workflow/)
- [MSX Branching and Merging](https://msx.no/docs/Ways-of-Working/Branching-and-Merging/)
- [MSX PR format](https://msx.no/docs/Ways-of-Working/PR-Format/)
