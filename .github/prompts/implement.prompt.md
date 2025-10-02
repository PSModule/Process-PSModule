---
description: Execute the implementation plan by processing and executing all tasks defined in tasks.md
---

# Implement

The user input can be provided directly by the agent or as a command argument - you **MUST** consider it before proceeding with the prompt (if not empty).

User input:

$ARGUMENTS

**Workflow Modes**: This command supports two modes:
- **Local (default)**: Work with the current repository (origin). No special configuration needed.
- **Fork**: Contribute to an upstream repository. Reads `.fork-info.json` created by `/specify`.

**Iteration Support**: This command supports iterative implementation - you can run it multiple times to complete remaining tasks, fix issues, or add refinements. Task completion state is tracked in tasks.md with [X] markers.

1. Run [`.specify/scripts/powershell/check-prerequisites.ps1 -Json -RequireTasks -IncludeTasks`](../../.specify/scripts/powershell/check-prerequisites.ps1) from repo root and parse FEATURE_DIR and AVAILABLE_DOCS list. All paths must be absolute.

2. Load and analyze the implementation context:
   - **REQUIRED**: Read tasks.md for the complete task list and execution plan
   - **REQUIRED**: Read plan.md for tech stack, architecture, and file structure
   - **IF EXISTS**: Read data-model.md for entities and relationships
   - **IF EXISTS**: Read contracts/ for API specifications and test requirements
   - **IF EXISTS**: Read research.md for technical decisions and constraints
   - **IF EXISTS**: Read quickstart.md for integration scenarios

3. Parse tasks.md structure and extract:
   - **Detect iteration state**: Check task completion markers
     - Tasks marked [X] are complete - skip unless user requests changes
     - Tasks marked [ ] are pending - these need implementation
     - If all tasks are complete, check if user input requests additional work
   - **Task phases**: Setup, Tests, Core, Integration, Polish
   - **Task dependencies**: Sequential vs parallel execution rules
   - **Task details**: ID, description, file paths, parallel markers [P]
   - **Execution flow**: Order and dependency requirements

4. Execute implementation following the task plan:
   - **Skip completed tasks**: Don't re-implement tasks marked [X] unless explicitly requested
   - **Resume from last incomplete task**: Start with first [ ] task found
   - **Phase-by-phase execution**: Complete each phase before moving to the next
   - **Respect dependencies**: Run sequential tasks in order, parallel tasks [P] can run together
   - **Follow TDD approach**: Execute test tasks before their corresponding implementation tasks
   - **File-based coordination**: Tasks affecting the same files must run sequentially
   - **Validation checkpoints**: Verify each phase completion before proceeding

5. Implementation execution rules:
   - **Setup first**: Initialize project structure, dependencies, and configuration
   - **Tests before code**: If you need to write tests for contracts, entities, and integration scenarios
   - **Core development**: Implement models, services, CLI commands, and endpoints
   - **Integration work**: Database connections, middleware, logging, and external services
   - **Polish and validation**: Unit tests, performance optimization, and documentation

6. Progress tracking and error handling:
   - Report progress after each completed task
   - Halt execution if any non-parallel task fails
   - For parallel tasks [P], continue with successful tasks and report failed ones
   - Provide clear error messages with context for debugging
   - Suggest next steps if implementation cannot proceed
   - **IMPORTANT**: For completed tasks, make sure to mark the task as [X] in the tasks file.

7. Completion validation:
   - Verify all required tasks are completed
   - Check that implemented features match the original specification
   - Validate that tests pass and coverage meets requirements
   - Confirm the implementation follows the technical plan
   - Report final status with summary of completed work

8. Create or update Pull Request:
   - **Determine workflow mode and target repository**:
     - Check if `.fork-info.json` exists in the feature directory (same directory as spec.md)
     - **If exists** (fork mode):
       - Validate required fields: `is_fork` (true), `upstream_owner` (non-empty), `upstream_repo` (non-empty)
       - If validation fails, halt and instruct user: "Invalid fork configuration in `.fork-info.json`. Please run `/specify` again with complete fork information: upstream owner, upstream repo."
       - Use `upstream_owner/upstream_repo` for all GitHub operations
     - **If not exists** (local mode - default):
       - Use the current repository (origin) for all GitHub operations
   - **Determine PR operation**:
     - If PR already exists for this branch, UPDATE it (description, status, labels)
     - If no PR exists, CREATE a new one
   - **Target branch**: The PR must be against the default branch
   - **PR status**: The PR must not be draft, it should be ready for review
   - **Retrieve the issue title**: Get the title from the linked GitHub issue (created in `/specify`) from the target repository
   - **Use the same title for the PR**: Verify the PR title matches the issue title exactly. If they differ, update the PR title to match the issue.
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
   - **PR description structure** (formatted as a release note):
     * Start with a user-focused summary paragraph describing what's new, improved, or fixed
     * Write in past tense, focusing on capabilities and user benefits (e.g., "Added support for...", "Improved performance of...", "Fixed issue where...")
     * DO NOT add a title or heading before the leading paragraph
     * Keep the tone professional and concise - this will be read as a release note
     * At the end of the summary paragraph, add "- Fixes #<issue-number>" to link the PR to the issue
     * Follow with additional release-note style details:
       - **What's Changed**: Brief bullet points of key changes from the user's perspective
       - **Technical Details** (optional): Implementation notes if relevant for maintainers
       - **Breaking Changes** (if applicable): Clear warning and migration guidance
       - **Usage** (if applicable): Brief example or updated command syntax
     * Avoid superfluous headers, verbose explanations, or internal implementation details
     * Focus on what changes for the end user or developer using this code
   - **Apply appropriate label(s)** based on the type of change
   - **Link the PR** to the associated issue
   - **After PR updates**: Update `.fork-info.json` (if it exists) with the latest PR number (if not already present)

   **GitHub Integration**: If GitHub tools or integrations are available (such as GitHub MCP Server or other GitHub integrations), use them to update the PR status and labels automatically in the target repository. If not available, provide these fallback commands with the correct repository:
   ```bash
   # Mark PR as ready for review
   # If fork: gh pr ready <PR-number> --repo <upstream_owner>/<upstream_repo>
   # If local: gh pr ready <PR-number>
   gh pr ready <PR-number>

   # Update PR title to match issue (if needed)
   gh pr edit <PR-number> --title "<Issue title>"

   # Update labels
   gh pr edit <PR-number> --add-label "<Type>"
   ```

9. Update issue labels:
   - **Determine target repository** (same logic as step 8):
     - Check if `.fork-info.json` exists in the feature directory
     - If it exists and validated, use `upstream_owner/upstream_repo`
     - If it doesn't exist, use the current repository (origin)
   - Remove 'plan' label from the linked issue in the target repository
   - Add 'implement' label to the linked issue
   - **After updating labels**: Ensure `.fork-info.json` (if it exists) has the issue number stored

   **GitHub Integration**: If GitHub tools are available, update labels automatically in the target repository. If not available, use:
   ```bash
   # If fork: gh issue edit <issue-number> --repo <upstream_owner>/<upstream_repo> ...
   # If local: gh issue edit <issue-number> ...
   gh issue edit <issue-number> --remove-label "Plan" --add-label "Implementation"
   ```

10. Update the constitution:
    - Read the [Constitution](../../.specify/memory/constitution.md) file.
    - Read the [constitution prompt](./constitution.prompt.md) for guidance on how to update the constitution.
    - Update the constitution file with details on what has been implemented in this PR
    - Document the functionality that was added or changed, remove the sections that are no longer relevant
    - Ensure the constitution reflects the current state of the codebase

Note: This command assumes a complete task breakdown exists in tasks.md. If tasks are incomplete or missing, suggest running `/tasks` first to regenerate the task list.
