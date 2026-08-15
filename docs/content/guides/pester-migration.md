---
title: Migrating Pester tests
description: A repository-wide checklist for migrating PSModule test sets to Pester 6.1.0.
---

# Migrating Pester tests

Use the reusable [`pester-migration`](https://github.com/PSModule/Process-PSModule/tree/main/skills/pester-migration/SKILL.md)
agent skill to migrate every Pester test set in a PSModule repository. It is
written for Pester **6.1.0** and distinguishes required compatibility changes
from optional v6 modernization.

The migration covers repository and test-set inventory, supported PowerShell
runtime and CI checks, per-file discovery and run isolation, hidden paths,
data-driven tests, setup blocks, mocks, pending tests, name templates,
coverage, `Invoke-Pester` configuration, reserved tags, and validation
reporting. It also defines the test-state/data contract: module-local tests
consume the target module already loaded by Process-PSModule and explicitly
load any PSD1 or other fixture data. They must not silently import the module as
a substitute for framework setup. It does not migrate consumer repositories as
part of this framework change.

## Required before declaring a migration complete

- Every test entry point is inventoried and runs on its supported runtime matrix.
- The target module is loaded by the framework before module-local Pester tests;
  tests do not hide a missing load with `Import-Module`.
- Every PSD1, JSON, CSV, XML, script, generated fixture, secret, variable, and
  service dependency has an owner and explicit loading phase.
- `Invoke-Pester`, `Test-PSModule`, module-local/source workflows,
  `BeforeAll`/`AfterAll`, `Expose-TestData`, result/coverage collectors, and
  linter result publishing are included in the repository inventory.
- Pester 6.1.0 is imported in local and CI acceptance runs.
- Each test file is self-contained under per-file discovery and run.
- Hidden paths, empty data, duplicate setup blocks, mocks, pending tests, name
  templates, coverage settings, legacy invocation parameters, and `None` tags
  have been reviewed.
- Serial results, coverage, and test-result artifacts are recorded and compared
  with the baseline.

## Optional after compatibility

`Should-*` assertions, `Run.Shuffle`, and experimental `Run.Parallel` are
independent adoption choices. Enable them only with separate validation and
document the choice.

## Primary and secondary sources

- [Official Pester v5-to-v6 migration](https://pester.dev/docs/migrations/v5-to-v6)
- [Pester installation](https://pester.dev/docs/introduction/installation)
- [Pester configuration](https://pester.dev/docs/usage/configuration)
- [Pester parallel execution](https://pester.dev/docs/usage/parallel)
- [Awesome Copilot pester-migration](https://github.com/github/awesome-copilot/tree/main/skills/pester-migration)
- [Awesome Copilot pester-should-migration](https://github.com/github/awesome-copilot/tree/main/skills/pester-should-migration)
