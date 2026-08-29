# Agents

## Main directive

Everything is a work in progress and can be improved.
If you find a problem or improvement, fix if small; otherwise open an issue.

## Repo guidance

- [`README.md`](README.md) — what this repository is and its purpose as the
  Process-PSModule framework.

## PSModule Framework guidance

Regarding repo structure, module source code, and how the Process-PSModule workflow
works. For PSModule-specific build, layout, and process guidance:

- [Process-PSModule docs](https://psmodule.io/docs/) —
  repository structure, module anatomy, and the build/test/pack/publish pipeline.
- [Repository defaults](https://psmodule.github.io/docs/Modules/Repository-Defaults/) —
  the expected repository layout and required files.
- [Standards](https://psmodule.github.io/docs/Modules/Standards/) — PowerShell module
  coding standards.
- [PSModule/memory](https://github.com/PSModule/memory) — durable cross-session agent
  working memory for the PSModule organization.

## Template impact

For every Process-PSModule change, evaluate whether the framework contract,
repository defaults, or generated output changes what a new module repository
should contain. When it does, update `PSModule/Template-PSModule` in a
coordinated pull request. Do not add template-maintenance behavior to consumer
audit or migration skills.

## Org-wide guidance

For cross-cutting ways of working and standards:

- [Agentic Development](https://msx.no/docs/Ways-of-Working/Agentic-Development/) —
  how agents and humans collaborate in this ecosystem.
- [Ways of Working](https://msx.no/docs/Ways-of-Working/) — contribution
  workflow, branching, PRs, issues.
- [Coding Standards](https://msx.no/docs/Coding-Standards/) — language-level
  conventions.
- [MSXOrg/memory](https://github.com/MSXOrg/memory) — durable agent working memory:
  gotchas, knowledge, and agent role notes.
