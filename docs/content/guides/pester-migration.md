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
reporting. It does not migrate consumer repositories as part of this framework
change.

## Required before declaring a migration complete

- Every test entry point is inventoried and runs on its supported runtime matrix.
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
