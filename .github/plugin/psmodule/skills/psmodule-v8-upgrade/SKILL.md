---
name: psmodule-v8-upgrade
description: Upgrade a Process-PSModule consumer repository to framework version 8 while preserving repository intent, enforcing the caller workflow contract, migrating Pester tests to v6, and retaining the repository's Zensical documentation design.
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
2. Work on a dedicated branch, open a draft pull request early, and use small
   commits. Include the required Copilot co-author trailer in every commit.
3. Preserve test intent, fixtures, secrets, variables, documentation content,
   custom theme assets, and repository-owned automation unless the upgrade
   requires a direct change.
4. Report preserved TestData, Pester migration details, Zensical/theme changes,
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
the template's default files before adding, removing, or relocating anything.
The template is a starting point, not a reason to overwrite module-specific
content.

The current template's default repository anatomy is:

```text
<ModuleName>/
├── .github/
│   ├── CODEOWNERS
│   ├── dependabot.yml
│   ├── linters/
│   │   ├── .codespellrc
│   │   ├── .markdown-lint.yml
│   │   ├── .powershell-psscriptanalyzer.psd1
│   │   └── .textlintrc
│   ├── PSModule.yml
│   ├── pull_request_template.md
│   ├── release.yml
│   ├── workflows/
│       └── Process-PSModule.yml
│   └── zensical.toml
├── examples/
├── icon/
├── src/
│   ├── classes/
│   ├── data/
│   ├── formats/
│   ├── functions/
│   │   ├── private/
│   │   └── public/
│   ├── init/
│   ├── modules/
│   ├── scripts/
│   ├── types/
│   └── variables/
├── tests/
│   ├── AfterAll.ps1
│   ├── BeforeAll.ps1
│   └── <ModuleName>.Tests.ps1
├── .gitattributes
├── .gitignore
├── AGENTS.md
├── CONTRIBUTING.md
├── LICENSE
└── README.md
```

Treat files and directories as follows:

- Required baseline files should be present in the consumer and remain
  repository-local; do not rely on organization-level fallback files.
- `src/`, especially `src/functions/public/` and `src/functions/private/`,
  along with `tests/`, `examples/`, and `icon/`, is module-owned content.
  Preserve its intent and only migrate paths when the framework contract
  requires it.
- `.github/PSModule.yml`, linters, Dependabot, CODEOWNERS, release metadata,
  pull-request templates, and repository guidance are configuration surfaces.
  Inspect and preserve them independently of the caller workflow.
- `tests/BeforeAll.ps1` and `tests/AfterAll.ps1` are optional root-level
  module-local phases, not recursively discovered test files.
- Optional source folders such as `assemblies`, `formats`, `types`, `variables`,
  `data`, `modules`, and `scripts` are added when the module needs them; do not
  create empty placeholders solely to match the tree.
- The template's starter test declares Pester 6 with `#Requires` and uses the
  native `Describe`, `It`, and `Should-Be` syntax. Preserve that requirement
  when the consumer already has the Pester 6 baseline.
- The template's `.github/PSModule.yml` sets a zero code-coverage target and
  carries explicit linter environment defaults; compare these settings before
  replacing or deleting a consumer settings file.
- The template's `AGENTS.md` points to Template-PSModule quickstart, repository
  defaults, module anatomy, build/test/pack/publish, and standards guidance.
  Preserve the consumer's local onboarding contract while updating stale links.

If the template revision and the consumer's existing layout disagree, record
the difference and migrate only the requested integration surface. In
particular, the current template uses `.github/zensical.toml`, while this v8
upgrade request uses `docs/zensical.toml`, `docs/content/`, and
`docs/overrides/` (including `docs/overrides/assets/`) as its documentation
contract; a separate `docs/assets/` directory is optional. When that requested
documentation migration is in scope, move the template's Zensical settings
and custom assets into the `docs/` contract rather than maintaining both
configurations. When it is not in scope, preserve the consumer's existing
working configuration and report the difference.

For a documentation-only MkDocs migration, use the dedicated
[`psmodule-zensical-migration`](../psmodule-zensical-migration/SKILL.md) skill
so content, theme, assets, and link validation are handled independently from
the caller workflow upgrade.

## Caller workflow contract

Replace `.github/workflows/Process-PSModule.yml` with exactly this template:

```yaml
name: Process-PSModule

on:
  workflow_dispatch:
  schedule:
    - cron: '0 0 * * *'
  push:
    branches:
      - main
  pull_request:
    branches:
      - main
    types:
      - closed
      - opened
      - reopened
      - synchronize
      - labeled
      - unlabeled

concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

permissions: {}

jobs:
  Process-PSModule:
    permissions:
      contents: read
      pages: write
      id-token: write
    uses: PSModule/Process-PSModule/.github/workflows/workflow.yml@v8
    secrets:
      PSGALLERY_API_KEY: ${{ secrets.PSGALLERY_API_KEY }}
      GitHubAppClientId: ${{ secrets.SHELLY_CLIENT_ID }}
      GitHubAppPrivateKey: ${{ secrets.SHELLY_PRIVATE_KEY }}
```

The only permitted variation is an optional `TestData` entry under
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

Treat `docs/zensical.toml` as authoritative. Do not create or maintain
`mkdocs.yml`, introduce MkDocs configuration, or replace the consumer's
documentation design with a parallel theme.

Compare the consumer's configuration with the Process-PSModule template and
preserve or migrate these surfaces deliberately:

- `docs/zensical.toml`, including `docs_dir` and navigation.
- `docs/content/` as the documentation source directory.
- `docs/overrides/` and custom templates.
- `docs/overrides/assets/stylesheets/navigation.css`.
- `docs/overrides/assets/`, any optional `docs/assets/`, logo, favicon, palette,
  fonts, and custom JavaScript/CSS.
- Existing navigation labels, page paths, and custom theme behavior.

Do not delete existing custom CSS/assets merely because the default theme also
provides an equivalent feature. Resolve duplicate configuration in favor of
the existing consumer source of truth, then validate the generated site.

## Pester v6 migration

The framework upgrade does not permit leaving tests on an undeclared or
unsupported Pester version. Inspect module requirements, dependency manifests,
local setup, CI installation, and every test entry point. Declare and run the
repository's supported Pester 6 dependency. If Pester 6 is already declared,
retain the declaration and focus on configuration, discovery, assertions,
setup/teardown, and output compatibility.

Rewrite tests using native Pester v6 terminology and APIs:

- Prefer `New-PesterConfiguration` and
  `Invoke-Pester -Configuration`.
- Update discovery, run configuration, output, result, and coverage handling
  without changing test intent.
- Make each test file safe under Pester v6 per-file discovery and execution.
- Preserve explicit fixture ownership and loading; do not silently import the
  target module as a fallback for a broken framework setup.
- Keep setup and teardown deterministic and scoped.
- Preserve data-driven cases, mocks, pending behavior, names, tags, coverage,
  and result reporting while applying the v6 compatibility rules.

Do not merely rename commands. Run the migrated tests with the declared Pester
6 dependency and investigate failures as migration or repository issues.

## Repository integration inventory

Before editing, record the current state and the intended v8 result for:

| Surface | Inspect | Required result |
| --- | --- | --- |
| Caller workflow | Triggers, permissions, concurrency, secrets, `with:` inputs | Exact v8 contract; only documented `TestData` may vary |
| TestData | Secret and variable names and consumers | Explicit compact JSON maps, or omitted when unused |
| Pester dependency | `#Requires`, manifests, install steps, lockfiles | Pester 6 is declared and installed consistently |
| Pester configuration | `Invoke-Pester`, output, result, coverage | Native configuration object and v6-compatible output |
| Test setup | Before/After blocks, module load, fixtures, services | Explicit ownership and deterministic per-file behavior |
| Documentation | Zensical config, content, overrides, assets | Existing Zensical design remains authoritative |
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
5. When documentation exists, run:

   ```powershell
   Push-Location docs
   zensical build --clean
   Pop-Location
   ```

6. Review the diff for accidental workflow permissions, trigger changes,
   secret exposure, fixture removal, generated files, or unrelated refactoring.

Report commands and outcomes, including blocked checks and why they were
blocked. A green documentation build does not substitute for Pester or
workflow validation.

## References

- [PSModule repository standard](https://github.com/PSModule/Process-PSModule/blob/main/docs/content/reference/repository-standard.md)
- [PSModule workflow inputs](https://github.com/PSModule/Process-PSModule/blob/main/docs/content/reference/workflow-inputs.md)
- [PSModule pipeline stages](https://github.com/PSModule/Process-PSModule/blob/main/docs/content/reference/pipeline-stages.md)
- [PSModule module test guidance](https://github.com/PSModule/Process-PSModule/blob/main/docs/content/guides/writing-module-tests.md)
- [PSModule workflow and test data guidance](https://github.com/PSModule/Process-PSModule/blob/main/docs/content/guides/calling-the-workflow.md)
- [Zensical setup basics](https://zensical.org/docs/setup/basics/)
- [Pester v6 quick start](https://pester.dev/docs/v6/quick-start)
- [Pester `New-PesterConfiguration` command](https://pester.dev/docs/commands/New-PesterConfiguration)
- [Pester `Invoke-Pester` command](https://pester.dev/docs/commands/Invoke-Pester)
- [MSX PR format](https://msxorg.github.io/docs/Ways-of-Working/PR-Format/)
