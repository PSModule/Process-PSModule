---
title: Get started
description: Create a module repository from the PSModule template and get the Process-PSModule pipeline running.
---

# Get started

Start new modules from the PSModule template repository:
[Template-PSModule](https://github.com/PSModule/Template-PSModule).

## Quickstart

1. [Create a new repository from the template](https://github.com/new?template_name=Template-PSModule&template_owner=PSModule&description=Add%20a%20description%20(required)&name=%3CModule%20name%3E).
2. Complete the [module repository baseline](repository-setup.md#1-complete-the-module-repository-baseline): replace
   template tokens, remove scaffolding, set `Type: Module`, and confirm required files.
3. [Configure the repository](repository-setup.md) — GitHub Pages, workflow secrets, the caller workflow, settings, and
   Zensical.
4. Add your first public command and tests.
5. [Open a draft pull request](your-first-release.md), then release from its resulting important default-branch push.

If the module needs several interdependent commands before it is usable at all, see
[Module bootstrap](module-bootstrap.md) instead of shipping them as one command per step.

## Expected outcomes

- The repository follows the [repository standard](../reference/repository-standard.md) and
  [expected structure](../guides/structuring-your-module.md).
- The module can be built and tested in CI.
- The release strategy is ready when functionality is implemented.

## In this section

| Page | Description |
| --- | --- |
| [Repository setup](repository-setup.md) | Repository baseline, GitHub Pages, workflow secrets, and the caller workflow. |
| [Your first release](your-first-release.md) | The pull request flow, version labels, and the resulting default-branch release. |
| [Module bootstrap](module-bootstrap.md) | Getting a brand-new module to its first release with an integration branch. |

For framework-level practices, refer to [MSX Ways of Working](https://msx.no/docs/Ways-of-Working/).
