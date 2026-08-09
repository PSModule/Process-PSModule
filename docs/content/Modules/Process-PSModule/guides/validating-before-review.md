---
title: Validating before review
description: PSModule-specific validation checks that extend the shared MSXOrg Build/Implement workflow step before a draft pull request is marked ready.
---

# Validating before review

Use this page after scaffolding a module change or implementing a function and before you finish self-review or mark a draft pull request ready. It extends the shared MSXOrg [Workflow Build step](https://msxorg.github.io/docs/Ways-of-Working/Workflow/#build) and [Implement guidance](https://msxorg.github.io/docs/Agents/implement/) with the PSModule-specific validation checks that module repositories must pass.

Do not repeat the shared workflow here. Follow the shared branch → draft PR → implement → test → self-review loop first, then run this PSModule pass to confirm the change still fits the module's design, documentation, and PowerShell standards.

## Validation sequence

1. **Module design alignment**

   Confirm that the change fits the module's archetype and the module-specific design rules before reviewing individual files.

   Check:

   - the module still follows the right archetype from [Module types](../../Module-Types.md)
   - the change respects the layout, private-helper boundaries, context rules, and SOLID guidance in [PowerShell module standard](../../Standards.md)
   - the function belongs in this module instead of a different module, a shared helper, or a follow-up issue

   A human contributor or agent should be able to explain why this change belongs in this module, in this shape, without inventing new local rules.

2. **Module documentation**

   Confirm that the repository-level and group-level documentation still matches the delivered behavior.

   Check:

   - `README.md` still answers the start-page questions and reflects any user-visible behavior, prerequisites, or setup changes from [Repository Standard](../../Repository-Standard.md#readme-default)
   - the relevant public command-group overview page (`src/functions/public/<Group>/<Group>.md`) exists or is updated when the change affects that group's purpose or usage, per [PowerShell module standard](../../Standards.md#repository-layout)
   - any module-level documentation under `docs/` or other published surfaces is updated when the change adds or changes guidance that should not live only in comment-based help

   If the change teaches the user something new, confirm that the user can discover it from the published documentation surfaces, not only from the diff.

3. **Function structure**

   Confirm that each changed function still follows the expected repository anatomy.

   Check:

   - public functions live under `src/functions/public/<Group>/` and private helpers live under `src/functions/private/<Group>/`
   - file placement, grouping, and exported surface match [Structuring your module](structuring-your-module.md) and the layout rules in [PowerShell module standard](../../Standards.md#repository-layout)
   - there are no nested helper functions, multi-function files, or naming shortcuts that break the "one declaration per file" rule

   This step is about shape, not behavior: the goal is that a reader or tool can find the module surface and its helpers exactly where PSModule expects them.

4. **Function documentation**

   Confirm that every changed function carries complete comment-based help and that the help matches the implementation contract.

   Check:

   - comment-based help is present for every changed function, including private helpers
   - help sections, examples, `.INPUTS`, `.OUTPUTS`, and parameter documentation match the function contract from [MSX PowerShell Functions](https://msxorg.github.io/docs/Coding-Standards/PowerShell/Functions/)
   - public-function links and usage examples are current enough that generated documentation will stay accurate

   Do not treat help as optional cleanup. In PSModule repositories, the function help is part of the delivered behavior.

5. **PowerShell best practices**

   Confirm that the implementation still reads like idiomatic PowerShell after the mechanical checks pass.

   Check:

   - advanced-function structure, parameter typing and validation, `ShouldProcess`, output behavior, and error handling align with [MSX PowerShell](https://msxorg.github.io/docs/Coding-Standards/PowerShell/) and [MSX PowerShell Functions](https://msxorg.github.io/docs/Coding-Standards/PowerShell/Functions/)
   - the code also satisfies the PSModule-specific conventions in [PowerShell module standard](../../Standards.md), especially around private helpers, context handling, and repository layout
   - PSScriptAnalyzer warnings are addressed or intentionally justified, but review does not stop there; also look for awkward parameter design, leaky transport details, non-idiomatic output, or code that technically passes lint but is not good PowerShell

   PSScriptAnalyzer is part of the validation loop, not the whole loop.

6. **Coding standards alignment**

   Run one final cross-check against the shared MSX coding standards before leaving self-review.

   Check:

   - naming, documentation, error handling, testing expectations, and security posture align with the relevant pages under [MSX Coding Standards](https://msxorg.github.io/docs/Coding-Standards/)
   - the change follows the shared "written once, referenced everywhere" rule by linking canonical guidance instead of copying it into local docs or code comments, as described in [Agentic Development](https://msxorg.github.io/docs/Ways-of-Working/Agentic-Development/)
   - the draft PR description, issue progress, and any follow-up issues reflect what actually shipped and what still belongs out of scope

   This is the last author-side gate before a PSModule draft PR is ready for independent review.

## Where this connects

- [MSX Workflow Build step](https://msxorg.github.io/docs/Ways-of-Working/Workflow/#build)
- [MSX Implement guidance](https://msxorg.github.io/docs/Agents/implement/)
- [PowerShell module standard](../../Standards.md)
- [Module types](../../Module-Types.md)
- [Structuring your module](structuring-your-module.md)
- [Repository Standard](../../Repository-Standard.md)
- [MSX Coding Standards](https://msxorg.github.io/docs/Coding-Standards/)
