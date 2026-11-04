---
title: Writing plugin skills
description: Create and maintain plugin skills with agent-specific instructions and links to shared guidance.
---

# Writing plugin skills

Use this guide to create or change a skill in the PSModule plugin.
A skill is an agent's entry point. Shared process and policy belong in the
documentation, where people and agents use the same source.

## Keep skills thin

Put shared explanations, repository policy, standards, and user-facing
procedures in the appropriate `docs/content/` page. Keep `SKILL.md` focused on
the agent-specific information needed to apply that guidance:

- when the skill should be used and when it should not.
- the agent's operating sequence and required handoffs.
- explicit stop conditions and escalation boundaries.
- the repository-specific validation and report-back contract.

The skill should link to the shared guide near its start. Do not copy
organization-wide MSX rules, module standards, or long tutorials into the
skill. Link to the canonical source instead.

## Skill structure

Create one directory per skill:

```text
.github/plugin/<plugin-name>/skills/<skill-name>/
└── SKILL.md
```

Use lowercase, descriptive, hyphen-separated identifiers. Start `SKILL.md`
with front matter containing the matching `name` and a concise `description`.
The description should identify when to use the skill without the full procedure.

After the front matter, include:

1. State the purpose. Link to the shared documentation.
2. Add agent-specific operating instructions.
3. State explicit stop conditions.
4. Link to related repository and canonical MSX guidance.

Prefer short imperative instructions, checklists, and handoff fields to
background explanations. Do not include model recommendations or tool
instructions that no longer apply. If a procedure changes for both users and
agents, update the documentation guide first. Then reduce the skill to a link
and the remaining agent-specific instructions.

## Plugin integration

Before you edit, examine the existing plugin. Preserve its `plugin.json`
metadata and directory conventions. Add the skill to the plugin README's
discoverability list with a repository-relative link. Do not add a second
manifest or duplicate marketplace registration for an individual skill.

Keep the skill's scope explicit. If it coordinates child sessions or other
agents, define the parent owner and each child's scope.
Specify handoffs, validation, completion reports, and stop conditions.
Do not broaden a skill into unrelated repository work without an explicit scope decision.

## Validation

Run the smallest existing checks that cover the changed surfaces:

- `git diff --check`.
- repository Markdown and natural-language lint when available.
- plugin and marketplace metadata parsing.
- `zensical build --clean` when documentation or navigation changes.

Review every relative link from the skill and guide. Make sure that the plugin
README entry identifies the skill and links to it.
Examine the diff for duplicate policy, outdated instructions, generated files,
or unrelated changes.
Report the draft PR URL, changed files, validation results, policy decisions,
and blockers to the owning session.

## Maintenance rule

When shared process changes, update the documentation page and its navigation.
Then make each dependent skill link to the revised source.
When only the agent contract changes, update the skill. Agent-specific changes
include triggers, handoffs, stop conditions, and tool boundaries.
Do not duplicate shared documentation.

## References

- [PSModule process plugin](https://github.com/PSModule/Process-PSModule/tree/main/.github/plugin)
- [MSX Agentic Development](https://msx.no/docs/Capabilities/agentic-development/)
- [MSX Documentation Model](https://msx.no/docs/Ways-of-Working/Documentation-Model/)
- [MSX Markdown standard](https://msx.no/docs/Coding-Standards/Markdown/)
- [MSX Natural Language standard](https://msx.no/docs/Coding-Standards/Natural-Language/)
