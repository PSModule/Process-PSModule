---
name: psmodule-v8-upgrade
description: Upgrade a Process-PSModule consumer repository to framework version 8, audit it against Template-PSModule, migrate every test set to Pester 6.1.0, and align its Zensical profile without changing repository-owned intent.
---

# Upgrade a Process-PSModule consumer to v8

Use this skill when a consumer repository needs to move its
`Process-PSModule.yml` caller to `PSModule/Process-PSModule/.github/workflows/workflow.yml@v8`.
Keep the change limited to the requested framework upgrade. Do not migrate
consumer repositories while developing or validating this skill.

## Operating contract

1. Inspect the consumer repository before editing. Read its local guidance,
   workflow, documentation configuration and content, tests, settings,
   dependencies, and existing validation commands.
2. Invoke
   [`psmodule-repository-audit`](../psmodule-repository-audit/SKILL.md) in Audit
   mode and record the resolved `Template-PSModule` commit.
3. Invoke
   [`psmodule-pester-migration`](../psmodule-pester-migration/SKILL.md) to
   inventory and validate every test set, then migrate every test set that does
   not already meet the Pester 6.1.0 contract.
4. Work on a dedicated branch, open a draft pull request early, and use small
   commits. Include the required Copilot co-author trailer in every commit.
5. Preserve test intent, fixtures, secrets, variables, documentation content,
   custom theme assets, and repository-owned automation unless the upgrade
   requires a direct change.
6. Report preserved TestData, Pester migration details, Zensical/theme changes,
   validation results, and blockers in the pull request.

Use the repository's applicable MSX workflow and PR format guidance. Do not
silently broaden the scope when the consumer has unrelated failures.

## Consumer layout variance

Do not assume that a consumer already resembles Process-PSModule. Inventory
what is present before deciding what to migrate:

- Many consumers have a legacy `.github/mkdocs.yml` and no `docs/` directory.
- Some consumers already have `docs/zensical.toml`, custom overrides, and
  assets that must be preserved.
- A consumer may already declare Pester 6; do not repeat a dependency migration
  that is already complete.
- Existing repository-owned workflows, scripts, and settings are not caller
  workflow extensions. Keep them in separate files and validate them in place.

When documentation is absent, do not invent a site as part of the caller
upgrade unless the requested scope explicitly includes documentation migration.
When a legacy MkDocs configuration exists and documentation migration is in
scope, migrate its content and design deliberately to Zensical, then remove
the obsolete configuration only after the generated site validates.

## Template-PSModule baseline

Use [`PSModule/Template-PSModule`](https://github.com/PSModule/Template-PSModule)
and the [PSModule Repository Standard](https://github.com/PSModule/Process-PSModule/blob/main/docs/content/reference/repository-standard.md)
as the structural baseline for module repositories. Compare the consumer with
the template's default files at one resolved commit before adding, removing, or
relocating anything. Do not duplicate the template tree or file contents in
this skill; the template default branch is the executable source.

Use the audit's classifications. Template-owned and parameterized files follow
the template. Established `src/`, tests, examples, documentation content,
settings overrides, and local automation remain repository-owned. Do not copy
starter source or starter tests over working module code.

If the template conflicts with the MSX or PSModule Repository Standard, block
consumer alignment and report the upstream gap. The Process-PSModule change
that introduced a new framework default is responsible for evaluating and
coordinating the corresponding template update.

For a documentation-only MkDocs migration, use the dedicated
[`psmodule-zensical-migration`](../psmodule-zensical-migration/SKILL.md) skill
so content, theme, assets, and link validation are handled independently from
the caller workflow upgrade.

## Caller workflow contract

Copy `.github/workflows/Process-PSModule.yml` from the recorded
`Template-PSModule` commit. Confirm that its reusable-workflow reference targets
`PSModule/Process-PSModule/.github/workflows/workflow.yml@v8`.

The only permitted consumer variation is an optional `TestData` entry under
`jobs.Process-PSModule.secrets`. Do not add `with:` inputs, extra jobs,
conditions, schedule changes, `run-name`, permission changes, trigger changes,
concurrency changes, debug options, or version overrides. Repository-owned
automation belongs in separate workflow files.

### TestData preservation

First determine whether the current caller passes secrets or variables to the
framework. Preserve a required payload by translating it to this compact JSON
shape:

```yaml
      TestData: >-
        {"secrets":{"SERVICE_TOKEN":"SERVICE_TOKEN"},"variables":{"ENVIRONMENT":"production"}}
```

Include only the `secrets` and/or `variables` maps that the consumer uses. Keep
the existing names and semantics. Omit `TestData` entirely when the repository
does not use it. Never move secrets into source files, workflow `env`, or
committed settings.

For example, preserve a secrets-only caller payload such as PSModule/GitHub's:

```yaml
      TestData: >-
        {"secrets":{"TEST_USER_USER_FG_PAT":"${{ secrets.TEST_USER_USER_FG_PAT }}","TEST_USER_ORG_FG_PAT":"${{ secrets.TEST_USER_ORG_FG_PAT }}","TEST_USER_PAT":"${{ secrets.TEST_USER_PAT }}","TEST_APP_ORG_CLIENT_ID":"${{ secrets.TEST_APP_ORG_CLIENT_ID }}","TEST_APP_ORG_PRIVATE_KEY":"${{ secrets.TEST_APP_ORG_PRIVATE_KEY }}","TEST_APP_ENT_CLIENT_ID":"${{ secrets.TEST_APP_ENT_CLIENT_ID }}","TEST_APP_ENT_PRIVATE_KEY":"${{ secrets.TEST_APP_ENT_PRIVATE_KEY }}"}}
```

Preserve a mixed secrets-and-variables payload such as PSModule/Confluence's:

```yaml
      TestData: >-
        {"secrets":{"CONFLUENCE_API_TOKEN":"${{ secrets.CONFLUENCE_API_TOKEN }}"},"variables":{"CONFLUENCE_SITE":"${{ vars.CONFLUENCE_SITE }}","CONFLUENCE_USERNAME":"${{ vars.CONFLUENCE_USERNAME }}","CONFLUENCE_SPACE_KEY":"${{ vars.CONFLUENCE_SPACE_KEY }}"}}
```

These examples are contracts, not values to copy into an unrelated consumer.
Read the original workflow and preserve only the maps and keys it actually
uses.

## Documentation integration

For a standard module repository,
`Template-PSModule/.github/zensical.toml` is authoritative. Keep that path
because Process-PSModule resolves it before `docs/zensical.toml` and root
`zensical.toml`. Do not leave multiple active configurations.

The standard module profile omits `nav`. Zensical derives navigation from the
staged folder structure, places index pages first, and sorts remaining pages
alphabetically. Preserve repository-owned content and supported assets, but do
not retain a manual navigation array merely because the legacy site had one.

Invoke `psmodule-zensical-migration` when the repository has MkDocs, multiple
documentation configurations, or a layout that must be migrated.

## Pester v6 migration

The framework upgrade does not permit leaving tests on an undeclared or
unsupported Pester version. The dedicated `psmodule-pester-migration` skill is
a required subprocedure, not an optional reference.

Inventory and execute every test entry point, including hidden and nested test
sets. Migrate discovery, configuration, setup and teardown, data-driven cases,
mocks, pending behavior, tags, results, and coverage as that skill requires.
Classic `Should -Be` syntax remains compatible and does not need a cosmetic
rewrite; Pester 6 breaking changes and deterministic per-file execution do.

Run every migrated test set with Pester 6.1.0. A declared dependency or one
green default workflow is not evidence that every test set was migrated.

## Repository integration inventory

Before editing, record the current state and the intended v8 result for:

| Surface | Inspect | Required result |
| --- | --- | --- |
| Caller workflow | Triggers, permissions, concurrency, secrets, `with:` inputs | Exact v8 contract; only documented `TestData` may vary |
| TestData | Secret and variable names and consumers | Explicit compact JSON maps, or omitted when unused |
| Pester dependency | `#Requires`, manifests, install steps, lockfiles | Pester 6 is declared and installed consistently |
| Pester configuration | `Invoke-Pester`, output, result, coverage | Native configuration object and v6-compatible output |
| Test setup | Before/After blocks, module load, fixtures, services | Explicit ownership and deterministic per-file behavior |
| Documentation | Active config, content, supported overrides and assets | Template module profile with native navigation, or a documented exception |
| Repository automation | Other workflows and scripts | Unrelated automation remains separate and unchanged |
| Validation | Existing tests, lint, site build, workflow checks | Existing repository-native validation is rerun |

## Validation

Run the smallest existing checks that cover the changed surfaces, then escalate
when a targeted check reveals a broader dependency:

1. Validate YAML syntax and confirm the caller has no forbidden variation.
2. Run the existing Process-PSModule workflow or its repository-native
   equivalent when available.
3. Run the Pester v6 test suites with the repository's declared configuration.
4. Run the repository's existing lint and test commands.
5. When documentation exists, run the repository's Process-PSModule site
   staging and build path. Do not substitute a direct `docs/` build when the
   module profile is stored in `.github/zensical.toml`.

6. Review the diff for accidental workflow permissions, trigger changes,
   secret exposure, fixture removal, generated files, or unrelated refactoring.

Report commands and outcomes, including blocked checks and why they were
blocked. A green documentation build does not substitute for Pester or
workflow validation.

## References

- [PSModule repository standard](https://github.com/PSModule/Process-PSModule/blob/main/docs/content/reference/repository-standard.md)
- [Template-PSModule](https://github.com/PSModule/Template-PSModule)
- [PSModule workflow inputs](https://github.com/PSModule/Process-PSModule/blob/main/docs/content/reference/workflow-inputs.md)
- [PSModule pipeline stages](https://github.com/PSModule/Process-PSModule/blob/main/docs/content/reference/pipeline-stages.md)
- [PSModule module test guidance](https://github.com/PSModule/Process-PSModule/blob/main/docs/content/guides/writing-module-tests.md)
- [PSModule workflow and test data guidance](https://github.com/PSModule/Process-PSModule/blob/main/docs/content/guides/calling-the-workflow.md)
- [Zensical setup basics](https://zensical.org/docs/setup/basics/)
- [Pester v6 quick start](https://pester.dev/docs/v6/quick-start)
- [Pester `New-PesterConfiguration` command](https://pester.dev/docs/commands/New-PesterConfiguration)
- [Pester `Invoke-Pester` command](https://pester.dev/docs/commands/Invoke-Pester)
- [MSX PR format](https://msxorg.github.io/docs/Ways-of-Working/PR-Format/)
