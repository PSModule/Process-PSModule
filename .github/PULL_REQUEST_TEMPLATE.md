<!--
This is the final content-control plan for the pull request author. The automated release process reuses this title
and description as the GitHub Release notes by default; it does not create a separate release-note document. Format
the title, description, and selected version label for the people who use the released artifact. See
docs/content/guides/formatting-release-note-prs.md and the psmodule-release-note-authoring skill. Delete headings
that do not apply. Remove every placeholder and comment before marking the pull request ready.
-->

<One concise paragraph: what users receive and why it matters.>

## New: <capability>

<What users can now do and the result they get.>

## Changed: <behavior>

<What users experience differently.>

## Fixed: <problem>

<What now works and how users benefit.>

## Breaking Changes

<What no longer works, who is affected, and the compatible replacement.>

## Adopting this release

1. <First action from the currently supported version, reference, configuration, or invocation.>
2. <Next action and how the user verifies the outcome.>

<Or: No configuration, code, or invocation change is required. Update to this version normally.>

## Release impact

- **Configured label:** `<label that selects this release>`
- **SemVer change:** `<Major | Minor | Patch>`
- **Version transition:** `<current published version> -> <planned release version>`
- **Release name:** `<planned release version>`

<!--
For a skip/no-release label, say that no artifact is published and no version transition occurs.
For a prerelease, state the selected bump and that it is not the latest stable version.
-->

---
<details>
<summary>Technical details</summary>

<Implementation approach, compatibility evidence, validation, and standards alignment.>

</details>

<details>
<summary>Relevant issues (or links)</summary>

- Resolves Owner/Repository#123

### Related work

- References Owner/Repository#456

</details>
