---
name: psmodule-skill-authoring
description: Author and maintain thin PSModule plugin skills that keep shared process in documentation and agent-specific behavior in SKILL.md.
---

# Author PSModule plugin skills

Use this skill when creating or updating a skill in the PSModule plugin. First
read the shared
[writing plugin skills guide](../../../../../docs/content/guides/writing-plugin-skills.md);
it is the source of common authoring, structure, validation, and maintenance
guidance.

## Agent-specific contract

- Inspect the existing plugin, skill conventions, README, and manifest before
  editing.
- Keep common user and repository guidance in the linked documentation. Put
  only the skill's trigger, agent operating sequence, handoff/report contract,
  and stop conditions in `SKILL.md`.
- Preserve the plugin's scope and make adjacent work a separate change.
- Open a draft PR early, use small commits, include the required Copilot
  co-author trailer, and report the PR URL, files, validation, decisions, and
  blockers to the owning session.
- Stop and report instead of guessing when the skill boundary, source-of-truth
  document, plugin ownership, or validation requirement is unclear.
