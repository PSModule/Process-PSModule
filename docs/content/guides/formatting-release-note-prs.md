---
title: Formatting release-note pull requests
description: Control the title, description, and label that automated releases reuse as user-facing release notes.
---

# Formatting release-note pull requests

This guide is the final content-control plan for an author formatting a pull request. It is not release notes for a
specific change. It defines how the pull request title, description, and version label communicate what users receive
when the automated release process reuses them.

With the default Process-PSModule settings, automation reuses the pull request title as the release notes heading and
the description as the release notes body. The release name is the resolved version unless
`Publish.Module.UsePRTitleAsReleaseName` changes that setting. The author, rather than the automation, makes the final
message decision by formatting those three pull request fields before review.

This guide extends the [MSX PR format](https://msx.no/docs/Ways-of-Working/PR-Format/) with the release transition
and adoption information required by Process-PSModule consumers. It applies to any releasable artifact: a PowerShell
module, reusable workflow, GitHub Action, library, service, or infrastructure module.

## Before starting

- Identify the artifact and the people or systems that use it.
- Inspect the configured version-label mapping and select the label that matches the delivered compatibility impact.
  Do not assume a label name: repositories can configure their own mappings.
- Find the latest published stable version and calculate the expected SemVer transition. If another release can merge
  first, describe the semantic increment and re-check the numeric transition before the pull request is ready.
- Identify every user-visible change and the steps an existing user needs to take to use it safely.

## Steps

1. Format the title in the [MSX PR format](https://msx.no/docs/Ways-of-Working/PR-Format/#title). Describe the
   user-facing outcome, not the implementation activity.
2. Open with one concise paragraph that says what users receive and why it matters. Use present tense and active voice.
3. Group the changes by experience using `## New:`, `## Changed:`, `## Fixed:`, and, for an incompatible release,
   `## Breaking Changes`. Each group explains the outcome before any implementation detail.
4. Add `## Adopting this release` after the user-facing change groups. Give the steps in the order an existing user
   takes them from the currently supported version, workflow reference, configuration, or invocation. State explicitly
   when no configuration, code, or usage change is needed. This is normal release adoption, not a migration.
5. Add `## Release impact`. State the configured label, the resulting SemVer effect, and the transition from the
   current published version to the planned release version. Explain whether the numeric value is provisional because
   it is resolved from the current published version at release time.
6. Finish with the required `Technical details` and `Relevant issues (or links)` blocks from the
   [MSX PR format](https://msx.no/docs/Ways-of-Working/PR-Format/#description-structure). Technical details explain
   how the outcome was delivered; they do not replace the user-facing narrative or adoption steps.

## Pull-request description structure

Use only the user-facing change headings that apply, but always include an adoption answer and release impact for a
published change. This is the format of the pull-request description that the release process later reuses; it is not
a separate release-note document to maintain.

````markdown
<One paragraph explaining what users receive and why it matters.>

## New: <capability>

<What users can now do and the result they get.>

## Changed: <existing behavior>

<What users experience differently.>

## Fixed: <problem>

<What now works and how users benefit.>

## Breaking Changes

<What no longer works, who is affected, and the compatible replacement.>

## Adopting this release

1. <First action from the currently supported version or reference.>
2. <Next action, configuration change, or verification step.>

<Or: No configuration, code, or invocation change is required. Update to this version normally.>

## Release impact

- **Configured label:** `<label that selects this release>`
- **SemVer change:** `<Major | Minor | Patch>`
- **Version transition:** `<current published version> -> <planned release version>`
- **Release name:** `<planned release version>`

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
````

For `release:skip` or an equivalent configured label, replace the release-impact list with an explicit statement that
no artifact is published and no version transition occurs. For a prerelease, state the selected bump and that the
release is a validation channel rather than the latest stable version.

## Writing the adoption path

The adoption path is release-wide. It connects related changes into the sequence a user follows instead of leaving
instructions scattered through feature sections.

| Artifact users consume | Adoption path answers |
| --- | --- |
| PowerShell module | Which version to install, whether scripts or command usage change, and how to verify the updated behavior. |
| Reusable workflow | Which `uses:` reference to change, which trigger, permission, input, secret, or label changes are required, and the order to apply them. |
| GitHub Action | Which action reference and inputs change, whether permissions or secrets are affected, and how callers verify it. |
| Library or service | Which dependency, API contract, setting, or deployment step changes and what compatibility behavior remains. |
| Infrastructure module | Which module version and input or output contracts change, the safe rollout order, and any state or deployment action. |

Do not label this section `Migration` unless the release performs a genuine data or platform migration. A routine
version update, reference change, configuration adjustment, or command replacement belongs under
`Adopting this release`.

## Formatting release impact

The configured version label determines the next version by applying its SemVer bump to the current published
version. The exact label can differ between repositories; describe its effect rather than relying on a conventional
name. The pull-request title and description explain the user value, while the version becomes the default GitHub
Release name.

Before marking a pull request ready, refresh the current version and planned version if another release landed while
the branch was open. Do not publish a stale numeric transition. A prerelease label selects a release channel alongside
the version bump; it is not the bump itself.

## Verify

- The title, description, and selected label are understandable as one user-facing message without internal file,
  function, or class names.
- Every user-visible change says what the user gets, and the technical details remain in the final details block.
- `Adopting this release` gives complete, ordered instructions for affected users or explicitly says no action is
  needed.
- The configured label, SemVer effect, current version, and planned version agree with the release configuration.
- No placeholders or authoring comments remain in the release notes body.
- The final details blocks match the [MSX PR format](https://msx.no/docs/Ways-of-Working/PR-Format/#description-structure).

## If it fails

| Symptom | Cause | Resolution |
| --- | --- | --- |
| The next version cannot be stated accurately. | Another release may change the published baseline, or the configured label is unknown. | State the semantic impact, inspect the configured label mapping, and refresh the numeric transition before review. |
| A user cannot tell whether they need to change anything. | The change explanation describes implementation instead of adoption. | Add an ordered adoption path or explicitly state that normal updating is sufficient. |
| The release notes read like reviewer notes. | Technical implementation details appear in the user-facing sections. | Move implementation, validation, and design detail to `Technical details`; retain the user outcome and action in the main body. |
