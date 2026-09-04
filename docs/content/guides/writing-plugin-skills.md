---
title: Writing plugin skills
description: Design, author, validate, and maintain thin PSModule plugin skills that point to shared documentation.
---

# Writing plugin skills

Use this guide when creating or changing a skill in the PSModule plugin. A
skill is an operational entry point for an agent; shared process and policy
belongs in the documentation structure so people and agents can use the same
source of truth.

## Keep skills thin

Put common explanations, repository policy, standards, and user-facing
procedures in the appropriate `docs/content/` page. Keep `SKILL.md` focused on
the agent-specific information needed to apply that guidance:

- when the skill should be used and when it should not;
- the agent's operating sequence and required handoffs;
- explicit stop conditions and escalation boundaries;
- the repository-specific validation and report-back contract.

The skill should link to the shared guide near its beginning. Do not copy
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
The description should make the skill discoverable without embedding the full
procedure.

After the front matter, include:

1. a short purpose statement and the link to the shared documentation;
2. agent-specific operating instructions;
3. explicit stop conditions;
4. references to related repository and canonical MSX guidance.

Prefer short imperative instructions, checklists, and handoff fields over
background material. Do not include stale vendor-specific model recommendations
or obsolete tool instructions. If a procedure changes for both users and
agents, update the documentation guide first and reduce the skill to a pointer
plus the remaining agent contract.

## Plugin integration

Inspect the existing plugin before editing. Preserve its `plugin.json`
metadata and directory conventions. Add the new skill to the plugin README's
discoverability list with a repository-relative link. Do not add a second
manifest or duplicate marketplace registration for an individual skill.

Keep the skill's scope explicit. If it coordinates child sessions or other
agents, define the parent owner, child boundary, expected handoff, validation,
report-back, and stop conditions. Do not silently broaden a skill into
unrelated repository work.

## Contribution and validation

Work on a dedicated branch, open a draft pull request early, and use small
commits. Include the required co-author trailer in every commit:

```text
Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>
```

Run the smallest existing checks that cover the changed surfaces:

- `git diff --check`;
- repository Markdown and natural-language lint when available;
- plugin and marketplace metadata parsing;
- `zensical build --clean` when documentation or navigation changes.

Review every relative link from the skill and guide, the final plugin README
entry, and the diff for duplicated policy, stale instructions, accidental
generated files, or unrelated changes. Report the draft PR URL, files changed,
validation outcomes, policy decisions, and blockers to the owning session.

## Maintenance rule

When shared process changes, update the documentation page and its navigation,
then make each dependent skill point to the revised source. When only an
agent-specific trigger, handoff, stop condition, or tool boundary changes,
update the skill without duplicating the common documentation.

## References

- [PSModule process plugin](https://github.com/PSModule/Process-PSModule/tree/main/.github/plugin)
- [MSX Agentic Development](https://msx.no/docs/Ways-of-Working/Agentic-Development/)
- [MSX Documentation Model](https://msxorg.github.io/docs/Ways-of-Working/Documentation-Model/)
- [MSX Markdown standard](https://msxorg.github.io/docs/Coding-Standards/Markdown/)
- [MSX Natural Language standard](https://msxorg.github.io/docs/Coding-Standards/Natural-Language/)
