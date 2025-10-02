---
description: Create (if absent) or iteratively update the project constitution from interactive or provided inputs, ensuring all dependent templates stay in sync.
---

# Constitution

The user input to you can be provided directly by the agent or as a command argument - you **MUST** consider it before proceeding with the prompt (if not empty).

User input:

$ARGUMENTS

**Note**: This command operates on the local repository's constitution and does not typically require fork-specific logic, as constitutional changes are usually made within the repository itself rather than targeting upstream repositories.

You are (a) creating or (b) iterating on the project constitution at `.specify/memory/constitution.md`.

Two operating modes:

1. Initial Creation Mode (constitution file does NOT exist):
   - Copy `.specify/templates/constitution-template.md` to `.specify/memory/constitution.md` verbatim before processing.
   - Treat the copied file as a TEMPLATE containing placeholder tokens in square brackets (e.g. `[PROJECT_NAME]`, `[PRINCIPLE_1_NAME]`).
   - Produce an initial version (default `1.0.0` unless the user specifies otherwise). Ratification date = today (unless user supplies one). Last amended date = same as ratification.
2. Iteration Mode (constitution file already exists):
   - Load the existing `.specify/memory/constitution.md` (NOT the template) as the authoritative current constitution.
   - Do NOT re-copy the template. Only reference the template to discover any NEW placeholders/sections that could be adopted.
   - Identify new functionality / sections / principles requested (from user input or arguments) and integrate them.
   - If a new principle or governance rule appears to REPLACE or substantially OVERLAP an existing one, generate a Replacement Analysis Table and request user confirmation before destructive changes. If interactive confirmation is not possible in this run, mark the affected original item with `TODO(REVIEW_REPLACEMENT): Proposed replacement: <new title>` and include in the Sync Impact Report under deferred actions.
   - Preserve original ratification date. Increment version per rules below. Update last amended date to today if any material change occurs.

Replacement Analysis Table (when overlap detected):

| Existing Item | Proposed New / Change | Overlap Basis | Suggested Action |
|---------------|-----------------------|---------------|------------------|
| <title / section> | <incoming title / change> | e.g. semantic similarity, scope duplication | Replace / Merge / Keep Both |

Heuristics for overlap:
- Title similarity score (case-insensitive) >= 0.6 (rough string similarity) OR
- >50% of bullet rules conceptually duplicate (same verbs/nouns) OR
- Governance rule introduces stricter variant of an existing rule.

If ambiguity remains, prefer non-destructive addition plus TODO marker.

Follow this execution flow:

0. Existence Check & Mode Selection:
   - If `.specify/memory/constitution.md` is missing → enter Initial Creation Mode (copy template, then proceed).
   - If it exists → Iteration Mode (operate directly on existing file; treat remaining bracket tokens, if any, as still-to-be-resolved placeholders).

1. Load Source Document:
   - Creation Mode: load freshly copied `.specify/memory/constitution.md` (formerly the template).
   - Iteration Mode: load existing `.specify/memory/constitution.md` and independently load `.specify/templates/constitution-template.md` only to detect any NEW placeholders/sections not yet present.
   - Identify every placeholder token `[ALL_CAPS_IDENTIFIER]` still unresolved in the working constitution (not just in template).
   - IMPORTANT: User may request changing the number of principles. Respect explicit user instruction; re-number or re-label as needed (maintain Roman numeral style if already in use; otherwise adopt consistent scheme).

2. Collect/derive values for placeholders (and new/changed content):
   - If user input (conversation) supplies a value, use it.
   - Otherwise infer from existing repo context (README, docs, prior constitution versions if embedded).
   - For governance dates: `RATIFICATION_DATE` is the original adoption date (if unknown ask or mark TODO), `LAST_AMENDED_DATE` is today if changes are made, otherwise keep previous.
   - `CONSTITUTION_VERSION` must increment according to semantic versioning rules:
     * MAJOR: Backward incompatible governance/principle removals or redefinitions.
     * MINOR: New principle/section added or materially expanded guidance.
     * PATCH: Clarifications, wording, typo fixes, non-semantic refinements.
   - If version bump type ambiguous, propose reasoning before finalizing.

3. Draft / Merge updated constitution content:
    - In Iteration Mode, integrate new principles/sections with minimal disruption:
       * Retain stable identifiers (e.g., keep existing principle numbering unless renumbering is explicitly required or gaps introduced by removals).
       * When replacing, either (a) fully substitute content if user confirmed or (b) append revised content and mark old with `DEPRECATED:` prefix plus TODO for removal in a future major version.
   - Replace every placeholder with concrete text (no bracketed tokens left except intentionally retained template slots that the project has chosen not to define yet—explicitly justify any left).
   - Preserve heading hierarchy and comments can be removed once replaced unless they still add clarifying guidance.
   - Ensure each Principle section: succinct name line, paragraph (or bullet list) capturing non‑negotiable rules, explicit rationale if not obvious.
   - Ensure Governance section lists amendment procedure, versioning policy, and compliance review expectations.

4. Consistency propagation checklist (convert prior checklist into active validations):
   - Read [`.specify/templates/plan-template.md`](../../.specify/templates/plan-template.md) and ensure any "Constitution Check" or rules align with updated principles.
   - Read [`.specify/templates/spec-template.md`](../../.specify/templates/spec-template.md) for scope/requirements alignment—update if constitution adds/removes mandatory sections or constraints.
   - Read [`.specify/templates/tasks-template.md`](../../.specify/templates/tasks-template.md) and ensure task categorization reflects new or removed principle-driven task types (e.g., observability, versioning, testing discipline).
   - Read each related prompt file in `.github/prompts/` (including this one) to verify no outdated agent-specific references remain (e.g., names tied to a specific LLM vendor) when generic guidance is required.
   - Read any runtime guidance docs (e.g., `README.md`, `docs/quickstart.md`, or agent-specific guidance files if present). Update references to principles changed.

5. Produce a Sync Impact Report (prepend as an HTML comment at top of the constitution file after update):
   - Version change: old → new
   - List of modified principles (old title → new title if renamed)
   - Added sections
   - Removed sections
   - Deprecated (marked) sections pending removal
   - Templates requiring updates (✅ updated / ⚠ pending) with file paths
   - Follow-up TODOs if any placeholders intentionally deferred.
   - Replacement items needing confirmation (if any)

6. Validation before final output:
   - No remaining unexplained bracket tokens.
   - Version line matches report.
   - Dates in ISO format (YYYY-MM-DD).
   - Principles are declarative, testable, and free of vague language ("should" → replace with MUST/SHOULD rationale where appropriate).

7. Write the completed constitution back to [`.specify/memory/constitution.md`](../../.specify/memory/constitution.md) (overwrite). Never write to the template path during iteration.

8. Output a final summary to the user with:
   - New version and bump rationale.
   - Any files flagged for manual follow-up.
   - Suggested commit message (e.g., `docs: amend constitution to vX.Y.Z (principle additions + governance update)`).

Formatting & Style Requirements:
- Use Markdown headings exactly as in the template (do not demote/promote levels).
- Wrap long rationale lines to keep readability (<100 chars ideally) but do not hard enforce with awkward breaks.
- Keep a single blank line between sections.
- Avoid trailing whitespace.

If the user supplies partial updates (e.g., only one principle revision), still perform validation and version decision steps.

If critical info missing (e.g., ratification date truly unknown), insert `TODO(<FIELD_NAME>): explanation` and include in the Sync Impact Report under deferred items.

Do not create a new template; always operate on the existing `.specify/memory/constitution.md` file.
