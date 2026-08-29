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

This skill does not maintain or reconcile `Template-PSModule`. Changes to
Process-PSModule include an impact evaluation that determines whether the
template also needs a coordinated update. Template changes are made and
validated in the template repository before consumer alignment begins.

## Authority and precedence

Use these sources together:

1. The [MSX Repository Standard](https://msx.no/docs/Ways-of-Working/Repository-Standard/)
   owns inherited enterprise policy.
2. The [PSModule Repository Standard](https://psmodule.io/docs/reference/repository-standard/)
   owns PSModule additions and explicit initiative overrides.
3. The default branch of `PSModule/Template-PSModule` owns the executable
   implementation of those requirements.
4. The target repository owns its module code, tests, documentation content,
   settings, secrets, and justified additions.

Resolve and record the template default-branch commit before comparing files.
Use that one commit throughout the run. Do not embed a snapshot of template
file contents in this skill.

When either governing standard and the template disagree, do not propagate the
discrepancy and do not repair the template from this skill. Report the upstream
gap and block consumer alignment until the policy owner and template agree.
When prose and template implementation express the same requirement
differently, use the template as the byte-level source. For shared Zensical
presentation settings, the MSXOrg documentation design takes precedence over
the Process-PSModule documentation-site implementation.

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

Classify every template path. Never infer that every template file can safely
overwrite an established repository.

| Class | Treatment |
| --- | --- |
| Template-owned standard | Compare with the template and report drift unless a documented target exception applies. |
| Parameterized standard | Compare after applying only the substitutions declared by the template or framework. |
| Configurable standard | Keep supported repository-specific values; compare the remaining structure and defaults. |
| Creation scaffold | Use for new repositories. Do not overwrite established module source, tests, examples, or content. |
| Repository-owned addition | Preserve it unless it violates a governing standard or breaks the framework contract. |

Treat governance files, caller workflows, linter settings, dependency
configuration, agent entry points, and documentation-site defaults as
template-owned or parameterized unless the template or PSModule standard says
otherwise. Treat `src/`, established `tests/`, `examples/`, documentation
content, and module-specific assets as repository-owned after creation.

Configuration is not automatically consumer-owned. For example,
`.github/PSModule.yml` may contain valid module-specific overrides while its
schema and unaffected defaults still come from the template. Compare fields,
not only whole-file hashes, when the standard permits overrides.

## Zensical contract

For module repositories, `.github/zensical.toml` comes from the matching path
in `Template-PSModule`.

- Preserve the template's repository placeholders when the framework resolves
  them during site staging.
- Do not add a `nav` setting. Zensical generates navigation from the staged
  folder structure, places index pages first, and sorts the remaining pages
  alphabetically.
- Confirm the template does not define `[project.extra.consent]`. Cookie
  consent is not a generated-module default and belongs only in a documented
  repository-specific configuration that actually requires it.
- Keep the template's theme, palette, typography, icons, plugins, Markdown
  extensions, and supported assets together as one baseline.
- Do not copy path-specific settings from `MSXOrg/docs` or
  `Process-PSModule/docs` directly into a generated module site. Their shared
  behavior must first be represented in `Template-PSModule` in a form the
  Process-PSModule site staging pipeline supports.
- Preserve repository-specific documentation content. A deliberate visual or
  functional exception must be documented in the target and reported as an
  accepted difference.

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

Follow the MSX Fleet Orchestration standard:

1. Discover repositories from authoritative organization metadata, such as the
   `Type: Module` custom property.
2. Use one Task or Bug, branch, draft pull request, and review loop per
   repository.
3. Put the campaign slug in every delivery issue and pull request title.
4. Adopt an existing matching pull request instead of opening a duplicate.
5. Store campaign state on GitHub. Local JSON or dashboards are disposable
   projections, not sources of truth.
6. Record the template commit in every report and pull request so a later run
   can distinguish new template changes from unfinished work.

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
