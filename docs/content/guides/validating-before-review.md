---
title: Validating before review
description: Validate a module change against design, documentation, and PowerShell requirements before independent review.
---

# Validating before review

Use this sequence after you scaffold a module change or implement a function. Run it before you complete self-review or mark a draft pull request ready. It extends the shared MSXOrg [Workflow Build step](https://msx.no/docs/Ways-of-Working/Workflow/#build) and [Implement guidance](https://msx.no/docs/Ways-of-Working/Workflow-Stages/Implement/). Module repositories must satisfy these PSModule-specific validation requirements.

Follow the shared branch → draft PR → implement → test → self-review loop first. Then run this author-side validation sequence for module design, documentation, and PowerShell standards.

## Validation sequence

1. **Module design alignment**

   Before you review individual files, make sure that the change fits the module's archetype and design rules.

   Make sure that:

   - the module follows the applicable archetype from [Module types](../reference/module-types.md)
   - the change follows the layout, private-helper boundaries, context rules, and SOLID guidance in [PowerShell module standard](../reference/powershell-module-standard.md)
   - the function belongs in this module instead of a different module, a shared helper, or a follow-up issue

   A contributor or agent should be able to explain why this change and its design belong in this module. The explanation should not introduce local rules.

2. **Module documentation**

   Make sure that the repository-level and group-level documentation describes the delivered behavior.

   Make sure that:

   - `README.md` answers the start-page questions and reflects user-visible behavior, prerequisites, or setup changes from [Repository Standard](../reference/repository-standard.md#readme-default)
   - the relevant public command-group overview page (`src/functions/public/<Group>/<Group>.md`) exists or reflects changes to that group's purpose or usage, as required by [PowerShell module standard](../reference/powershell-module-standard.md#repository-layout)
   - module-level documentation under `docs/` or other published surfaces includes guidance that should not appear only in comment-based help

   If the change affects user guidance, make sure that users can find it in published documentation, not only the diff.

3. **Function structure**

   Make sure that each changed function follows the repository layout.

   Make sure that:

   - public functions live under `src/functions/public/<Group>/` and private helpers live under `src/functions/private/<Group>/`
   - file placement, grouping, and exported surface match [Structuring your module](structuring-your-module.md) and the layout rules in [PowerShell module standard](../reference/powershell-module-standard.md#repository-layout)
   - there are no nested helper functions, multi-function files, or naming shortcuts that break the "one declaration per file" rule

   This step concerns file layout, not function behavior. The layout lets readers and tools locate the module's public functions and private helpers.

4. **Function documentation**

   Make sure that every changed function has complete comment-based help that matches the implementation contract.

   Make sure that:

   - comment-based help is present for every changed function, including private helpers
   - help sections, examples, `.INPUTS`, `.OUTPUTS`, and parameter documentation match the function contract from [MSX PowerShell Functions](https://msx.no/docs/Coding-Standards/PowerShell/Functions/)
   - every public function has a first `.LINK` entry using an absolute HTTPS URL whose path matches the generated command documentation path
   - links to new, moved, or unpublished public-function pages match targets in the generated documentation
   - links to already-published public-function pages resolve on the published site
   - usage examples match the implemented parameters and outputs

   Function help is part of the delivered behavior in PSModule repositories. Do not defer help as optional cleanup.

5. **PowerShell best practices**

   After the mechanical checks pass, review the implementation against the PowerShell standards.

   Make sure that:

   - advanced-function structure, parameter typing and validation, `ShouldProcess`, output behavior, and error handling align with [MSX PowerShell](https://msx.no/docs/Coding-Standards/PowerShell/) and [MSX PowerShell Functions](https://msx.no/docs/Coding-Standards/PowerShell/Functions/)
   - the code satisfies the PSModule-specific conventions in [PowerShell module standard](../reference/powershell-module-standard.md), including private helpers, context handling, and repository layout
   - PSScriptAnalyzer warnings have fixes or intentional justifications

   Do not limit the review to PSScriptAnalyzer. Also examine parameter design, exposed transport details, output behavior, and deviations from PowerShell conventions, even when lint passes.

6. **Coding standards alignment**

   Before you complete self-review, compare the change with the shared MSX coding standards.

   Make sure that:

   - naming, documentation, error handling, testing expectations, and security posture align with the relevant pages under [MSX Coding Standards](https://msx.no/docs/Coding-Standards/)
   - the change follows the shared "written once, referenced everywhere" rule from [Agentic Development](https://msx.no/docs/Capabilities/agentic-development/)
   - local documentation and code comments link to canonical guidance instead of copying it
   - the draft PR description, issue progress, and follow-up issues describe the delivered change and its exclusions

   This completes the author-side validation before independent review of a PSModule draft PR.

## Where this connects

- [MSX Workflow Build step](https://msx.no/docs/Ways-of-Working/Workflow/#build)
- [MSX Implement guidance](https://msx.no/docs/Ways-of-Working/Workflow-Stages/Implement/)
- [PowerShell module standard](../reference/powershell-module-standard.md)
- [Module types](../reference/module-types.md)
- [Structuring your module](structuring-your-module.md)
- [Repository Standard](../reference/repository-standard.md)
- [MSX Coding Standards](https://msx.no/docs/Coding-Standards/)
