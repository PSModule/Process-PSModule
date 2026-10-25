---
title: Formatting release-note pull requests
description: Author complete release records that consumers can replay for upgrade instructions while resource documentation stays evergreen.
---

# Formatting release-note pull requests

The release-bound pull request title and complete description are the authored release record. Write them so consumers
can understand what changes, why it changes, how it affects them, and exactly what to do when upgrading. Published
release notes are sufficient for that decision; the pull request and commit diffs provide optional deeper evidence.

With the default Process-PSModule settings, automation reuses the pull request title as the release notes heading and
the description as the release notes body. The release name is the resolved version unless
`Publish.Module.UsePRTitleAsReleaseName` changes that setting. This guide governs authoring; it does not change the
publisher, version resolver, label mappings, or release-note settings.

Use the [MSX PR format](https://msx.no/docs/Ways-of-Working/PR-Format/) for titles and description structure, and the
[repository template](https://github.com/PSModule/Process-PSModule/blob/main/.github/PULL_REQUEST_TEMPLATE.md) as the
local starting point. The guidance applies to PowerShell modules, reusable workflows, GitHub Actions, libraries,
services, infrastructure modules, and published guidance.

## Release records and evergreen documentation

Each release records its incremental change from a declared release/source baseline. Consumers compose the applicable
records after their current baseline through their selected target. The newest note does not replace intervening
instructions, and an individual note does not need a migration manual from every historical version.
When later instructions supersede earlier edits, explain which actions remain for the target and preserve any
explicitly required intermediate installation or run.

| Surface | Content it owns |
| --- | --- |
| Published release record | Delivered changes, rationale, affected consumers, old-to-new transitions, exact adoption or migration actions, prerequisites, ordering, and verification. |
| Product or resource documentation | Supported current-state behavior, inputs, outputs, configuration, and usage examples. |
| Pull request and commit diffs | Optional implementation depth and supporting evidence beyond the complete published instructions. |

Keep necessary before-and-after examples in the release record. Keep current supported examples in resource
documentation, without migration history or instructions tied to an earlier release. Preserve legitimate decision and
research records in their established homes. Do not introduce a standalone changelog or version-specific migration-guide
hierarchy as a second upgrade history.

Missing applicable instructions are an evidence gap to resolve with the producer, not an expectation that consumers
reconstruct the upgrade from pull requests, diffs, or today's resource documentation.

## Before starting

- Identify the artifact, its supported consumers, and every affected public interface.
- Inspect the complete base-to-head diff and the full delivered range from the declared release/source baseline.
  Include prior merged or skipped deltas that now enter the artifact, not only the latest PR or bundled change.
- Establish the release/source baseline for the consumer delta from published records and immutable source evidence.
  Distinguish it from the version-computation base when they differ; state explicitly when there is no prior release.
- Inspect the publishing route and effective version-label settings. Verify semantic impact independently of the label
  name or default, and identify every applicable consumer action or verified no-action result.

## Steps

1. Write a short, audience-first outcome as the title, without an icon or type prefix.
2. Open with concise prose explaining the result, rationale, affected consumers, and required action. Lead with breaking
   impact when applicable. End the shareable summary with `<!-- ANNOUNCEMENT STOP -->`.
3. Group results in the shared order: `Breaking`, `Removed`, `New`, `Changed`, then `Fixed`. Use
   `## <classifier>: <result>`, omit empty groups, and explain each result before any example or table.
4. Put complete adoption or migration instructions in each result's reader-facing prose before its evidence blocks.
   Include exact transition examples when needed. Coordinate dependent actions in one ordered sequence within the
   record rather than maintaining competing instructions.
5. Keep implementation and validation evidence in the result's `Technical details`, with `Related references` scoped to
   that same result. References supplement the published instructions; they never replace required steps.
6. Include the conditional release-decision block only when the target route invokes Release Management. Describe
   verified semantic impact and its configured source, not a predicted final version; see
   [Release decisions and coordinates](#release-decisions-and-coordinates).
7. Update the relevant resource documentation to the supported current state. Remove authoring placeholders, empty
   scaffolding, and comments other than the shareable-summary marker.

## Writing an incremental upgrade record

Give every affected consumer a complete answer, including routine dependency, reference, configuration, or command
changes. Adoption and migration instructions are not limited to data or platform migrations.

| Information | What the record must answer |
| --- | --- |
| Baseline and applicability | Which prior release/source the delta starts from, who is affected, and which starting conditions or prerequisites matter. |
| Change, rationale, and impact | What changes, why it changes, and how supported consumers experience it. State breaking behavior independently of its SemVer classification. |
| Exact actions | Which public commands, configuration keys, defaults, inputs, outputs, permissions, secret names, runtimes, or references change. Include exact edits and necessary before-and-after examples; never include secret values. |
| Order and intermediate steps | Which edits, installations, runs, or deployments depend on others. Require an intermediate version only when the transition actually needs one. |
| Verification | Which observable result or existing check confirms that the consumer is aligned. |
| No-action result | Explicitly state when no configuration, code, or invocation change is required beyond selecting the release. Distinguish optional feature adoption from required changes. |
| Integration template | When applicable, identify the template repository and verified compatible immutable commit, producer-source compatibility evidence, and linked template work or a justified no-change result. |

If no integration template applies, explain why rather than inventing one. Do not substitute a moving template branch
or today's documentation for evidence about the released contract.

## Release decisions and coordinates

The [MSX PR format](https://msx.no/docs/Ways-of-Working/PR-Format/) owns the conditional `Release decisions` block.
Include it only when the target route invokes Release Management; inspect the caller and effective configuration
rather than inferring invocation from a settings file. Otherwise omit it and still explain the adoption or no-action
outcome in the result prose.

For the existing Process-PSModule resolver, inspect `Publish.Module.MajorLabels`, `MinorLabels`, `PatchLabels`,
`IgnoreLabels`, and `AutoPatching` in the effective [settings](../reference/settings.md). Preserve the configured
label names and defaults; this authoring guidance does not adopt another publisher's label namespace or configuration.
Describe the selected semantic effect and stable/prerelease mode. For a skip decision, state that no artifact is
published and no version transition occurs.

Authors state verified impact and the known consumer-change baseline. The publishing process resolves the final
numeric version and release identity from its actual version base. Do not calculate a planned release version or name
in the PR body. A known source baseline is evidence, not a prediction of publication coordinates.

## Replay an illustrative release range

This walkthrough reuses the timeout-setting example from the shared PR format. It illustrates already published
records, not Process-PSModule release history or changes to its settings. The version numbers below represent resolved
publication identities, not numbers assigned by a PR author. This example product has no integration template.

### Published v2.0.0 - Explicit timeout units

**Baseline:** `v1.4.2`. **Impact:** breaking, Major. The optional job configuration key `timeout` becomes
`timeoutSeconds` so its units are explicit. The positive integer value, seconds unit, and 30-second default remain
unchanged. Configurations using `timeout` are rejected; configurations that omit it need no edit.
The job invocation and all other settings remain unchanged.

1. If the configuration contains `timeout: 20`, replace it with `timeoutSeconds: 20`, preserving the value. Do not
   supply both keys. If the key is absent, keep it absent to retain the 30-second default.
2. Apply that configuration edit together with the selected target version, not to the previous version. No data
   conversion, intermediate installation, or intermediate run is required.
3. Verify with the unchanged job invocation against the selected version: `timeoutSeconds: 20` is accepted and
   `timeout: 20` is rejected. A job exceeding its timeout must be canceled at the configured limit, or 30 seconds
   when omitted.

### Published v2.0.1 - Clearer timeout validation errors

**Baseline:** `v2.0.0`. **Impact:** compatible Patch. Invalid timeout values report the accepted positive-integer
range, making configuration errors easier to correct. Accepted configuration, units, defaults, and invocation stay
unchanged. No configuration, code, or invocation change is required beyond selecting this release. Run the existing
job invocation to verify the same configuration acceptance and timeout cancellation behavior.

A consumer moving from `v1.4.2` to `v2.0.1` reads both records in order, applies the applicable key rename, selects
`v2.0.1` directly, and runs the stated checks. A consumer starting at `v2.0.0` reads only the patch record and needs no
configuration edit. Reading every applicable record does not require installing every intermediate version.

The resource documentation for this example describes only the optional positive-integer `timeoutSeconds` setting,
its seconds unit, 30-second default, and current usage. The release records carry the removed key, transition
instructions, and reasons for each change.

## Verify

- The complete published record explains what changed, why, impact, applicability, exact actions, and verification,
  or a verified no-action result.
- A consumer can compose all applicable records from an identified baseline through a selected target without
  consulting PRs, diffs, or historical versions of resource documentation for missing instructions.
- The summary marker, classifiers, scoped blocks, and conditional release metadata follow the shared format.
- Semantic impact and any reported label/default agree with the effective route; no final numeric version is predicted.
- Resource documentation contains the supported current state, and release records contain migration history.
- No placeholders, secret values, empty scaffolding, or authoring comments remain in the finalized record.

## If it fails

| Symptom | Cause | Resolution |
| --- | --- | --- |
| The final version is unknown before publication. | The publisher has not resolved its actual base. | State verified semantic impact and the known change baseline; leave numeric coordinates to the publisher. |
| A consumer cannot determine an applicable upgrade step. | The release record is incomplete or its baseline is unverified. | Report the evidence gap and complete the record from verified source evidence; do not infer no action or require consumers to mine diffs. |
| The newest note omits an earlier breaking transition. | The consumer read only the target note. | Compose every applicable release record after the current baseline through the target, in order. |
| Resource documentation contains an old-to-new walkthrough. | Release history was mixed with current usage. | Keep the required transition in the release record and the supported current example in resource documentation. |
