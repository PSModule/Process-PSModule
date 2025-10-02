---
description: Execute the implementation planning workflow using the plan template to generate design artifacts.
---

# Plan

The user input to you can be provided directly by the agent or as a command argument - you **MUST** consider it before proceeding with the prompt (if not empty).

User input:

$ARGUMENTS

**Workflow Modes**: This command supports two modes:
- **Local (default)**: Work with the current repository (origin). No special configuration needed.
- **Fork**: Contribute to an upstream repository. Reads `.fork-info.json` created by `/specify`.

**Iteration Support**: This command detects whether you're creating a new plan or updating an existing one based on the presence of plan.md in the feature directory.

Given the implementation details provided as an argument, do this:

1. Run [`.specify/scripts/powershell/setup-plan.ps1 -Json`](../../.specify/scripts/powershell/setup-plan.ps1) from the repo root and parse JSON for FEATURE_SPEC, IMPL_PLAN, SPECS_DIR, BRANCH. All future file paths must be absolute.
   - **Detect iteration mode**: Check if IMPL_PLAN (plan.md) already exists:
     - **If exists**: You are ITERATING on an existing plan. User input should guide refinements/additions to the existing plan content.
     - **If not exists**: You are CREATING a new plan from scratch.
   - BEFORE proceeding, inspect FEATURE_SPEC for a `## Clarifications` section with at least one `Session` subheading. If missing or clearly ambiguous areas remain (vague adjectives, unresolved critical choices), PAUSE and instruct the user to run `/clarify` first to reduce rework. Only continue if: (a) Clarifications exist OR (b) an explicit user override is provided (e.g., "proceed without clarification"). Do not attempt to fabricate clarifications yourself.
2. Read and analyze the feature specification to understand:
   - The feature requirements and user stories
   - Functional and non-functional requirements
   - Success criteria and acceptance criteria
   - Any technical constraints or dependencies mentioned

3. Read the constitution at [`.specify/memory/constitution.md`](../../.specify/memory/constitution.md) to understand constitutional requirements.

4. Execute the implementation plan template:
   - Load [`.specify/templates/plan-template.md`](../../.specify/templates/plan-template.md) (already copied to IMPL_PLAN path)
   - Set Input path to FEATURE_SPEC
   - **If ITERATING** (plan.md exists):
     - Read existing plan.md content
     - Identify what needs updating based on user input ($ARGUMENTS)
     - Preserve existing valid content
     - Refine or expand sections as needed
     - Maintain consistency with existing decisions unless explicitly changing them
   - **If CREATING** (new plan):
     - Run the Execution Flow (main) function steps 1-9
     - The template is self-contained and executable
     - Follow error handling and gate checks as specified
   - Let the template guide artifact generation in $SPECS_DIR:
     * Phase 0 generates research.md
     * Phase 1 generates data-model.md, contracts/, quickstart.md
     * Phase 2 generates tasks.md
   - Incorporate user-provided details from arguments into Technical Context: $ARGUMENTS
   - Update Progress Tracking as you complete each phase

5. Verify execution completed:
   - Check Progress Tracking shows all phases complete
   - Ensure all required artifacts were generated
   - Confirm no ERROR states in execution

6. Commit and push the changes:
   - Stage all generated artifacts and modified files
   - Create a commit with a descriptive message summarizing the plan
   - Push the branch (BRANCH) to remote

7. Create or update a Pull Request:
   - **Determine workflow mode and target repository**:
     - Check if `.fork-info.json` exists in the feature directory (same directory as spec.md)
     - **If exists** (fork mode):
       - Validate required fields: `is_fork` (true), `upstream_owner` (non-empty), `upstream_repo` (non-empty)
       - If validation fails, halt and instruct user: "Invalid fork configuration in `.fork-info.json`. Please run `/specify` again with complete fork information: upstream owner, upstream repo."
       - Use `upstream_owner/upstream_repo` for all GitHub operations
     - **If not exists** (local mode - default):
       - Use the current repository (origin) for all GitHub operations
   - **Determine PR operation** (create vs update):
     - If PR already exists for this branch, UPDATE it
     - If no PR exists, CREATE a new one
   - The PR must be against the default branch.
   - The PR must be opened as a draft (or remain draft if updating).
   - **Retrieve the issue title**: Get the title from the linked GitHub issue (created in `/specify`) from the target repository
   - **Use the same title for the PR**: The PR title must match the issue title exactly
   - If unable to retrieve the issue title, determine the PR type and icon based on the changes:

     | Type of change | Icon | Label |
     |-|-|-|
     | Docs | 📖 | Docs |
     | Fix | 🪲 | Fix, Patch |
     | Security fix | ⚠️ | Fix |
     | Patch | 🩹 | Patch |
     | Feature | 🚀 | Minor |
     | Breaking change | 🌟 | Major |

   - Fallback PR title format (if issue title unavailable): `<Icon> [Type of change]: <Short description>`
   - Create PR description:
     * Start with a summary paragraph describing the key outcome and changes for user
     * DO NOT add a title before the leading paragraph
     * At the end of the PR paragraph, add a "- Fixes #<issue-number>" line to link the PR to the issue
     * Follow with additional details answering Why, How, and What
     * Avoid superfluous headers or sections
     * We do not need details, we need to add what changes for the user of the code
   - Apply appropriate label(s) based on the type of change
   - Link the PR to the associated issue
   - **After PR creation**: Update `.fork-info.json` (if it exists) with the PR number:
     ```json
     {
       "is_fork": true,
       "upstream_owner": "...",
       "upstream_repo": "...",
       "detected_from": "user_input",
       "created_at": "...",
       "issue_number": <issue-number>,
       "pr_number": <pr-number>
     }
     ```

   **GitHub Integration**: If GitHub tools or integrations are available (such as GitHub MCP Server or other GitHub integrations), use them to create/update the PR and manage labels automatically in the target repository. If not available, provide these fallback commands with the correct repository:
   ```bash
   # Create draft PR
   # If fork: gh pr create --repo <upstream_owner>/<upstream_repo> --draft ...
   # If local: gh pr create --draft ...
   gh pr create --draft --title "<Icon> [Type]: <Description>" --body "<PR description>" --label "<Type>"

   # Link to issue (if not using "Fixes #<issue>" in body)
   gh pr edit <PR-number> --add-label "<Type>"
   ```

8. Update issue labels:
   - **Determine target repository** (same logic as step 7):
     - Check if `.fork-info.json` exists in the feature directory
     - If it exists and validated, use `upstream_owner/upstream_repo`
     - If it doesn't exist, use the current repository (origin)
   - Remove 'specification' label from the linked issue in the target repository
   - Add 'plan' label to the linked issue
   - **After updating labels**: Update `.fork-info.json` (if it exists) with the issue number if not already present

   **GitHub Integration**: If GitHub tools are available, update labels automatically in the target repository. If not available, use:
   ```bash
   # If fork: gh issue edit <issue-number> --repo <upstream_owner>/<upstream_repo> ...
   # If local: gh issue edit <issue-number> ...
   gh issue edit <issue-number> --remove-label "Specification" --add-label "Plan"
   ```

9. Report results with branch name, PR URL, file paths, and generated artifacts.

Use absolute paths with the repository root for all file operations to avoid path issues.
