<!--
Follow docs/content/guides/formatting-release-note-prs.md and the shared MSX PR format.
The release-bound title and complete description are the authored release record. Cover the entire delivered range,
including prior merged or skipped deltas entering the artifact. Write an audience-first title without an icon/type prefix.
Keep only applicable classifier sections in the order shown; repeat a section for each distinct result.
Put complete upgrade instructions and necessary old-to-new examples in each result's prose. PRs/diffs are optional depth.
Keep supporting blocks scoped to their result. For internal-only work without a classified result, place them after the marker.
Remove placeholders, empty blocks, and authoring comments; keep the ANNOUNCEMENT STOP marker.
-->

{{ Concise summary: what changes, why, who is affected, and required action or an explicit no-action result.
Lead with breaking impact when applicable. }}

<!-- ANNOUNCEMENT STOP -->

## Breaking: {{ Reader-facing result }}

{{ Explain the result, rationale, affected consumers, compatibility, and verified release/source baseline.
Give exact adoption or migration actions, prerequisites, order, and verification. Include necessary old-to-new examples.
Require intermediate installations or runs only when needed. State the no-action result for unaffected consumers. }}

<details>
<summary>Technical details</summary>

{{ Implementation, validation commands and results, compatibility evidence, and standards alignment for this result.
When an integration template applies, identify its repository and verified immutable compatible commit,
producer-source compatibility evidence, and linked template work or a justified no-change result. }}

</details>

<details>
<summary>Related references</summary>

- References Owner/Repository#123

</details>

## Removed: {{ Reader-facing result }}

{{ Explain what is removed and why, affected consumers, compatibility, and verified release/source baseline.
Give the supported replacement, exact actions or explicit no-action result, prerequisites, order, and verification.
Keep required transition examples here; require intermediate installations or runs only when needed. }}

<details>
<summary>Technical details</summary>

{{ Implementation, validation commands and results, compatibility and standards evidence for this result.
Include applicable verified immutable template evidence and linked work or a justified no-change result. }}

</details>

<details>
<summary>Related references</summary>

- References Owner/Repository#123

</details>

## New: {{ Reader-facing result }}

{{ Explain what consumers gain and why, applicability, compatibility, and verified release/source baseline.
Distinguish optional feature use from required upgrade actions. Give exact actions or an explicit no-action result,
prerequisites, order, verification, and any required intermediate installations or runs. }}

<details>
<summary>Technical details</summary>

{{ Implementation, validation commands and results, compatibility and standards evidence for this result.
Include applicable verified immutable template evidence and linked work or a justified no-change result. }}

</details>

<details>
<summary>Related references</summary>

- References Owner/Repository#123

</details>

## Changed: {{ Reader-facing result }}

{{ Explain what changes and why, affected consumers, compatibility, and verified release/source baseline.
Give exact adoption or migration actions or an explicit no-action result, prerequisites, order, and verification.
Keep required transition examples here; require intermediate installations or runs only when needed. }}

<details>
<summary>Technical details</summary>

{{ Implementation, validation commands and results, compatibility and standards evidence for this result.
Include applicable verified immutable template evidence and linked work or a justified no-change result. }}

</details>

<details>
<summary>Related references</summary>

- References Owner/Repository#123

</details>

## Fixed: {{ Reader-facing result }}

{{ Explain what works correctly and why it matters, affected consumers, compatibility, and verified release/source baseline.
Give exact actions or an explicit no-action result, prerequisites, order, verification, and any required intermediate
installations or runs. Keep necessary old-to-new examples in this prose. }}

<details>
<summary>Technical details</summary>

{{ Implementation, validation commands and results, compatibility and standards evidence for this result.
Include applicable verified immutable template evidence and linked work or a justified no-change result. }}

</details>

<details>
<summary>Related references</summary>

- References Owner/Repository#123

</details>

<!--
Keep Release decisions only when the target route invokes Release Management.
Use the actual publisher's configured labels/defaults; this template does not migrate them.
For no release, keep only Release and Labels, and state that no artifact or version is produced.
The publisher resolves final numeric coordinates; do not predict them.
-->
<details>
<summary>Release decisions</summary>

- **Release:** {{ Yes or No, with evidence from the artifact, target route, and supported consumer contracts. }}
- **Version bump:** {{ Patch, Minor, or Major, with verified semantic impact and the configured decision source. Omit for No. }}
- **Mode:** {{ Stable or Prerelease, with route or override evidence. Omit for No. }}
- **Labels:** {{ Exact applied labels, or None when effective configuration supplies the decision without an override. }}

</details>
