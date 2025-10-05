---
description: Create or update the feature specification from a natural language feature description.
---

# Specify

The user input to you can be provided directly by the agent or as a command argument - you **MUST** consider it before proceeding with the prompt (if not empty).

User input:

$ARGUMENTS

**Workflow Modes**: This command supports two modes:
- **Local (default)**: Work with the current repository (origin). No special configuration needed.
- **Fork**: Contribute to an upstream repository. Automatically detected via `git remote -v`.

**Iteration Support**: This command detects whether you're creating a new feature or refining an existing one based on your current branch.

The text the user typed after `/specify` in the triggering message **is** the feature description. Assume you always have it available in this conversation even if `$ARGUMENTS` appears literally below. Do not ask the user to repeat it unless they provided an empty command.

Given that feature description, do this:

1. **Detect repository mode**:
   - Run `git remote -v` to check configured remotes
   - **If `upstream` remote exists**: Fork mode detected
     - Parse the upstream URL to extract owner and repo name
     - Example: `upstream https://github.com/PSModule/Utilities.git` → owner: `PSModule`, repo: `Utilities`
     - Inform user: "Fork contribution detected. Issues and PRs will target `<upstream_owner>/<upstream_repo>`"
   - **If only `origin` remote exists**: Origin mode (default)
     - Parse the origin URL to extract owner and repo name
     - Use `origin_owner/origin_repo` for all GitHub operations

2. Analyze the feature description and generate a concise, descriptive branch name:
   - Extract the core concept/action from the description (2-4 words maximum)
   - Use kebab-case format (lowercase, hyphen-separated)
   - Focus on the primary change or feature being implemented
   - Examples: "user-authentication", "merge-workflows", "api-rate-limiting", "fix-memory-leak"

3. Run the script [`.specify/scripts/powershell/create-new-feature.ps1 -Json -FeatureDescription "$ARGUMENTS" -BranchName "<your-generated-name>"`](../../.specify/scripts/powershell/create-new-feature.ps1) from repo root and parse its JSON output for BRANCH_NAME, SPEC_FILE, and IS_EXISTING_BRANCH. All file paths must be absolute.

**IMPORTANT** You must only ever run this script once. The JSON is provided in the terminal as output - always refer to it to get the actual content you're looking for.

**NOTE**

- The script will prepend an auto-incremented feature number (e.g., `003-`) to your branch name.
- If you're currently on `main` branch, a new feature branch will be created.
- If you're already on a feature branch (starts with 3 digits like `001-`, `002-`, etc.), you'll stay on that branch to iterate on the existing feature.
- This allows you to refine specifications without creating multiple branches for the same feature.

4. Load [`.specify/templates/spec-template.md`](../../.specify/templates/spec-template.md) to understand required sections.

5. **Write or update the specification**:
   - **If IS_EXISTING_BRANCH is false** (new feature on main branch):
     - Write a new specification to SPEC_FILE using the template structure
     - Replace placeholders with concrete details derived from the feature description
     - Preserve section order and headings from the template
   - **If IS_EXISTING_BRANCH is true** (iterating on existing feature):
     - Read the existing SPEC_FILE to understand the current specification
     - Analyze the new feature description (arguments) to identify:
       - New requirements or details to add
       - Existing content that needs refinement or clarification
       - Sections that may need updating based on the new input
     - Update the specification incrementally:
       - Preserve all existing content that remains relevant
       - Add new sections or details where the new description adds information
       - Refine or expand existing sections where the new description provides clarification
       - Maintain the template structure and section order
     - The goal is evolution, not replacement - build upon the existing spec rather than starting over

6. Create or update a GitHub issue for this feature:
   - **Use target repository determined in step 1**:
     - If fork mode: Use `upstream_owner/upstream_repo` for all GitHub operations
     - If origin mode: Use `origin_owner/origin_repo` for all GitHub operations
   - **Generate the issue title** in format `<Icon> [Type]: <Feature name>` where:
     - Icon: 📖 (Docs), 🪲 (Fix), ⚠️ (Security fix), 🩹 (Patch), 🚀 (Feature/Minor), 🌟 (Breaking change/Major)
     - Type: Docs, Fix, Patch, Feature, or Breaking change
     - Feature name: Short description from the spec
   - **Store the generated title** for use in subsequent workflow steps (plan, implement)
   - **If IS_EXISTING_BRANCH is true**:
     - Update the existing issue associated with this feature branch (if one exists) with the refined specification
     - **Evaluate if the title needs updating**: If the feature scope has changed significantly (e.g., from patch to feature, or major functionality changes), update the issue title. For minor refinements or clarifications, keep the existing title.
     - **Ensure Specification label**: Verify the issue has the 'Specification' label (indicates current phase)
   - **If IS_EXISTING_BRANCH is false** (new branch): Create a new GitHub issue with:
     - Title: Use the generated title format above
     - Body: The complete content of the SPEC_FILE (spec.md). Remove the first H1 (#) header and the first H2 (##) header if they exist. We want the PR description to start with the "Primary user story" section.
     - Labels:
       - `Specification` (always - indicates current phase)
       - Type-based label: `Docs`, `Fix`, `Patch`, `Minor`, or `Major` based on the type of change

   **GitHub Integration**: If GitHub MCP Server is available, use it to create/update the issue automatically in the target repository. ONLY IF NOT AVAILABLE; provide the appropriate fallback command with the correct repository:

   For new issues:
   ```bash
   # If fork: gh issue create --repo <upstream_owner>/<upstream_repo> ...
   # If local: gh issue create ...
   gh issue create --title "<Icon> [Type]: <Feature name>" --body-file <SPEC_FILE> --label "Specification,<Type>" --body "<existing body>\n\n---\n**Feature Branch**: `<BRANCH_NAME>`"
   ```

   For updating existing issues (find the issue number associated with the branch):
   ```bash
   # If fork: gh issue edit <issue-number> --repo <upstream_owner>/<upstream_repo> ...
   # If local: gh issue edit <issue-number> ...
   gh issue edit <issue-number> --body-file <SPEC_FILE>
   ```

7. **Post final status comment**: "✅ Specification complete. Ready for clarification with `/clarify` or planning with `/plan`."

8. Report completion with branch name, spec file path, whether it's a new or updated feature, issue number, target repository (if fork), and readiness for the next phase.

Note: The script handles branch creation/reuse and initializes the spec file before writing.
