---
description: Create or update the feature specification from a natural language feature description.
---

# Specify

The user input to you can be provided directly by the agent or as a command argument - you **MUST** consider it before proceeding with the prompt (if not empty).

User input:

$ARGUMENTS

The text the user typed after `/specify` in the triggering message **is** the feature description. Assume you always have it available in this conversation even if `$ARGUMENTS` appears literally below. Do not ask the user to repeat it unless they provided an empty command.

Given that feature description, do this:

1. Analyze the feature description and generate a concise, descriptive branch name:
   - Extract the core concept/action from the description (2-4 words maximum)
   - Use kebab-case format (lowercase, hyphen-separated)
   - Focus on the primary change or feature being implemented
   - Examples: "user-authentication", "merge-workflows", "api-rate-limiting", "fix-memory-leak"
2. Run the script `.specify/scripts/powershell/create-new-feature.ps1 -Json "$ARGUMENTS" -BranchName "<your-generated-name>"` from repo root and parse its JSON output for BRANCH_NAME and SPEC_FILE. All file paths must be absolute.
  **IMPORTANT** You must only ever run this script once. The JSON is provided in the terminal as output - always refer to it to get the actual content you're looking for.
  **NOTE** The script will prepend an auto-incremented feature number (e.g., `003-`) to your branch name.
3. Load `.specify/templates/spec-template.md` to understand required sections.
4. Write the specification to SPEC_FILE using the template structure, replacing placeholders with concrete details derived from the feature description (arguments) while preserving section order and headings.
5. Create a GitHub issue for this feature with:
   - Title: Format as `<Icon> [Type]: <Feature name>` where:
     - Icon: 📖 (Docs), 🪲 (Fix), ⚠️ (Security fix), 🩹 (Patch), 🚀 (Feature/Minor), 🌟 (Breaking change/Major)
     - Type: Docs, Fix, Patch, Feature, or Breaking change
     - Feature name: Short description from the spec
   - Body: The complete content of the SPEC_FILE (spec.md)
   - Labels:
     - `Specification` (always - indicates current phase)
     - Type-based label: `Docs`, `Fix`, `Patch`, `Minor`, or `Major` based on the type of change
6. Report completion with branch name, spec file path, issue number, and readiness for the next phase.

Note: The script creates and checks out the new branch and initializes the spec file before writing.
