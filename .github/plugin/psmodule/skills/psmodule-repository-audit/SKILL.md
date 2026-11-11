---
name: psmodule-repository-audit
description: Audit a PSModule repository against the current Template-PSModule baseline while distinguishing template drift from repository-owned code, tests, settings, and content.
---

# Audit a PSModule repository against Template-PSModule

Use this read-only skill when checking an established PowerShell module
repository against the standard files in
[`PSModule/Template-PSModule`](https://github.com/PSModule/Template-PSModule).
Use the same procedure for one repository or as the repository-level audit
inside a fleet campaign. Report changes for a separate migration or delivery
task; do not edit either repository while running this audit.

Read the [PSModule Repository Standard](https://psmodule.io/Process-PSModule/reference/repository-standard/)
and its [source ownership and file classes](https://psmodule.io/Process-PSModule/reference/repository-standard/#managed-file-distribution)
before comparing. Those pages own shared policy; this skill defines the audit
sequence, handoffs, report, and stop conditions.

This skill does not maintain or reconcile `Template-PSModule`. Changes to
Process-PSModule include an impact evaluation that determines whether the
template also needs a coordinated update. Template changes are made and
validated in the template repository before consumer alignment begins.

## Source and stop conditions

Resolve and record the template default-branch commit before comparing files.
Use that one commit throughout the run. Do not embed a snapshot of template
file contents in this skill.

When either governing standard and the template disagree, do not propagate the
discrepancy and do not repair the template from this skill. Report the upstream
gap and block consumer alignment until the policy owner and template agree.
When prose and template implementation express the same requirement
differently, apply the linked source-ownership rules. Do not resolve policy
differences independently in a consumer.

## Audit boundary

The audit records aligned paths, drift, accepted differences, and blocked
comparisons. It does not edit the template or consumer. A fleet run invokes the
audit once per repository and creates a separate delivery task for each
consumer that needs alignment.

## Inventory

Before comparing:

1. Read the target repository's local guidance, README, workflow, settings,
   documentation configuration, tests, and validation commands.
2. Confirm that the target is a PowerShell module repository. Do not force the
   module template onto framework, documentation, action, archive, or other
   repository types.
3. Resolve the current default branch and commit of `Template-PSModule`.
4. Inventory every template path, including hidden files.
5. Inventory every target path and any explicit local ownership or exception.
6. Record the Process-PSModule caller version, Pester requirement, and
   documentation configuration.

## Classify before comparing

Classify every template path with the shared file classes. Never infer that
every template file can safely overwrite an established repository. Preserve
repository-owned source, tests, examples, content, and assets.

Compare community and automation paths against the
[required common files](https://psmodule.io/Process-PSModule/reference/repository-standard/#required-common-files).
Record documented exceptions as accepted differences and stale local
configurations or root duplicates as drift.

Configuration is not automatically consumer-owned. For example,
`.github/PSModule.yml` may contain valid module-specific overrides while its
schema and unaffected defaults still come from the template. Compare fields,
not only whole-file hashes, when the standard permits overrides.

## Pull request authoring

Apply the [no-file authoring rule](https://psmodule.io/Process-PSModule/reference/repository-standard/#pull-request-authoring)
when classifying PR-template paths. Use the
[canonical MSX PR Format](https://msx.no/docs/Ways-of-Working/PR-Format/) for the
actual record, not a repository or organization PR-template file.

Do not classify PR-template files as template-owned standards or creation
scaffolds. Their absence is intentional, not missing baseline drift. Report
existing files as stale drift for a separate removal task. Do not recommend
adding, recreating, copying, or generating them, and do not rely on a central
fallback.

If the recorded template contains a PR-template file, report the upstream
policy gap and block consumer alignment rather than propagating it.

## Zensical contract

Compare the recorded template profile against the shared
[generated-module documentation contract](https://psmodule.io/Process-PSModule/reference/repository-standard/#generated-module-documentation).
Record documented visual or functional exceptions as accepted differences.

When the target still uses MkDocs or requires a documentation layout
migration, report
[`psmodule-zensical-migration`](../psmodule-zensical-migration/SKILL.md) as
required follow-up. Do not invoke a migration skill from this read-only audit.

## Pester and workflow contracts

Template comparison does not prove that an established test suite is compatible
with the template's Pester version. If the target does not already meet the
template's Pester baseline, report
[`psmodule-pester-migration`](../psmodule-pester-migration/SKILL.md) as required
follow-up. If the Process-PSModule caller needs a major-version migration,
report [`psmodule-v8-upgrade`](../psmodule-v8-upgrade/SKILL.md) as required
follow-up.

## Audit output

Report each compared path with:

| Field | Meaning |
| --- | --- |
| Path | Repository-relative path. |
| Class | One of the comparison classes above. |
| Status | Aligned, missing, drifted, extra, accepted difference, or blocked. |
| Action | None, add, update, preserve, remove, or report upstream. |
| Evidence | Template commit and governing standard or documented exception. |

Do not count an extra repository-owned file as drift. Do not call a repository
aligned when a required template-owned file is absent, a Pester migration is
incomplete, or validation did not execute.

## Fleet operation

Follow the [MSX Fleet Orchestration standard](https://msx.no/docs/Ways-of-Working/Fleet-Orchestration/).
Run this audit once per target. Record the template commit in every report so
a later run can distinguish new template changes from unfinished work.

## Validation

1. Repeat the comparison against the same recorded template commit.
2. Confirm the audit did not change either repository.
3. Run the target's smallest repository-native checks for every changed
   surface.
4. Run Pester with the declared version when tests changed.
5. Build the Zensical site when documentation settings or assets changed.
6. Review the diff for unresolved placeholders, generated output, and unrelated
   changes.

Report blocked checks and their causes. A clean file comparison is not a
substitute for repository tests, and a green build is not a substitute for
checking template drift.
