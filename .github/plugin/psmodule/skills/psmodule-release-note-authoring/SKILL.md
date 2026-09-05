---
name: psmodule-release-note-authoring
description: Write or review release-bound pull requests as user-facing release notes with adoption steps and a verified version transition.
---

# Author release-note pull requests

Use this skill when authoring, rewriting, or reviewing a pull request whose title and description will be published as
release notes. Read the [release-note pull request guide](../../../../../docs/content/guides/writing-release-note-prs.md)
before editing the pull request. That guide owns the release-note structure and the user-facing writing rules.

## Operating contract

1. Identify the artifact users consume, its current published version or reference, its configured version-label
   mapping, and the users affected by the change.
2. Write the title and leading paragraph around the user outcome. Group changes by what users experience, not by files
   or implementation activity.
3. Include an ordered `Adopting this release` section for every affected user. State that normal updating is sufficient
   when no configuration, code, or invocation change is required.
4. Verify the configured label, SemVer effect, current published version, and planned release version together. Refresh
   the numeric transition before the pull request is ready if another release may have changed the baseline.
5. Put implementation, validation, compatibility evidence, and standards alignment in the final `Technical details`
   block. Preserve the MSX `Relevant issues (or links)` block at the end.
6. Rework the title, adoption path, and release impact whenever the diff, selected label, or compatibility impact
   changes. Do not leave placeholders, stale version values, or reviewer-oriented prose in the published body.

## Stop conditions

Stop and report when the release label mapping, current published version, artifact consumer, or compatibility impact
cannot be determined. Do not infer a version transition from conventional label names, describe routine adoption as a
migration, or claim that no user action is needed without inspecting the delivered behavior.

## References

- [Writing release-note pull requests](../../../../../docs/content/guides/writing-release-note-prs.md)
- [Versioning and releases](../../../../../docs/content/guides/versioning-and-releases.md)
- [MSX PR format](https://msx.no/docs/Ways-of-Working/PR-Format/)
