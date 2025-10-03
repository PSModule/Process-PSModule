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

1. **Set Implementing label immediately**:
   - **Determine target repository**:
     - Check if `.fork-info.json` exists in the feature directory
     - If it exists:
       - Validate required fields: `is_fork` (true), `upstream_owner` (non-empty), `upstream_repo` (non-empty)
       - Use `upstream_owner/upstream_repo` for all GitHub operations
     - If it doesn't exist, use the current repository (origin)
   - Get the issue number associated with the current feature branch
   - **Add 'Implementing' label** to the issue and PR immediately in the target repository
   - **Remove 'Planning' label** from the issue and PR
   **GitHub Integration**: If GitHub tools are available, update labels automatically in the target repository. If not available, use:
   ```bash
   # If fork: gh issue edit <issue-number> --repo <upstream_owner>/<upstream_repo> --remove-label "Planning" --add-label "Implementing"
   # If local: gh issue edit <issue-number> --remove-label "Planning" --add-label "Implementing"
   gh issue edit <issue-number> --remove-label "Planning" --add-label "Implementing"
   ```
2. Run [`.specify/scripts/powershell/check-prerequisites.ps1 -Json -RequireTasks -IncludeTasks`](../../.specify/scripts/powershell/check-prerequisites.ps1) from repo root and parse FEATURE_DIR and AVAILABLE_DOCS list. All paths must be absolute.
3. Load and analyze the implementation context:
   - **REQUIRED**: Read tasks.md for the complete task list and execution plan
   - **REQUIRED**: Read plan.md for tech stack, architecture, and file structure
   - **IF EXISTS**: Read data-model.md for entities and relationships
   - **IF EXISTS**: Read contracts/ for API specifications and test requirements
   - **IF EXISTS**: Read research.md for technical decisions and constraints
   - **IF EXISTS**: Read quickstart.md for integration scenarios
4. Parse tasks.md structure and extract:
   - **Detect iteration state**: Check task completion markers
     - Tasks marked [X] are complete - skip unless user requests changes
     - Tasks marked [ ] are pending - these need implementation
     - If all tasks are complete, check if user input requests additional work
   - **Task phases**: Setup, Tests, Core, Integration, Polish
   - **Task dependencies**: Sequential vs parallel execution rules
   - **Task details**: ID, description, file paths, parallel markers [P]
   - **Execution flow**: Order and dependency requirements
5. Execute implementation following the task plan:
   - **Skip completed tasks**: Don't re-implement tasks marked [X] unless explicitly requested
   - **Resume from last incomplete task**: Start with first [ ] task found
   - **Phase-by-phase execution**: Complete each phase before moving to the next
   - **Respect dependencies**: Run sequential tasks in order, parallel tasks [P] can run together
   - **Follow TDD approach**: Execute test tasks before their corresponding implementation tasks
   - **File-based coordination**: Tasks affecting the same files must run sequentially
   - **Validation checkpoints**: Verify each phase completion before proceeding
6. Implementation execution rules:
   - **Setup first**: Initialize project structure, dependencies, and configuration
   - **Tests before code**: If you need to write tests for contracts, entities, and integration scenarios
   - **Core development**: Implement models, services, CLI commands, and endpoints
   - **Integration work**: Database connections, middleware, logging, and external services
   - **Polish and validation**: Unit tests, performance optimization, and documentation
7. Progress tracking and error handling:
   - Report progress after each completed task
   - Halt execution if any non-parallel task fails
   - For parallel tasks [P], continue with successful tasks and report failed ones
   - Provide clear error messages with context for debugging
   - Suggest next steps if implementation cannot proceed
   - **CRITICAL - Update task status immediately after completion**:
     * After completing each task, mark it as [X] in tasks.md
     * Update the PR description to mark the corresponding task checkbox from `- [ ] T###:` to `- [X] T###:`
     * This MUST be done task-by-task as you progress, not at the end
     * If GitHub tools are available, use them to update the PR description
     * If not available, use: `gh pr edit <PR-number> --body "<updated-description>"`
     * Ensure task progress is visible in real-time to users watching the PR
8. Completion validation:
   - Verify all required tasks are completed
   - Check that implemented features match the original specification
   - Validate that tests pass and coverage meets requirements
   - Confirm the implementation follows the technical plan
   - Report final status with summary of completed work
9. Update the constitution:
  - Read the [Constitution](../../.specify/memory/constitution.md) file.
  - Read the [constitution prompt](./constitution.prompt.md) for guidance on how to update the constitution.
  - Update the constitution file with details on what has been implemented in this PR
  - Document the functionality that was added or changed, remove the sections that are no longer relevant
  - Ensure the constitution reflects the current state of the codebase
10. Update the CHANGELOG:
  - **Locate or create CHANGELOG.md** in the repository root
  - **Add a new entry** for this feature/change following the Keep a Changelog format
  - **Structure the entry** with:
    - Version header (use `[Unreleased]` if version isn't determined yet)
    - Date (current date)
    - Category sections as applicable:
      - `### Added` - for new features
      - `### Changed` - for changes in existing functionality
      - `### Deprecated` - for soon-to-be removed features
      - `### Removed` - for now removed features
      - `### Fixed` - for any bugfixes
      - `### Security` - for vulnerability fixes
    - Write entries from the user's perspective, focusing on what changed and why it matters
    - Include brief usage examples where helpful
    - Link to the PR or issue: `[#<issue-number>]`
  - **Keep it concise**: Focus on user-impacting changes, not internal refactoring details
11. Final commit and push:
  - **Stage all implemented changes** including:
    - All source code files created or modified
    - Updated tasks.md with completed task markers [X]
    - Updated CHANGELOG.md
    - Updated constitution.md
    - Any configuration or documentation files
  - **Create a descriptive commit message**:
    - Use conventional commit format: `<type>(<scope>): <description>`
    - Types: feat, fix, docs, refactor, test, chore
    - Include reference to issue: `Fixes #<issue-number>`
  - **Push the branch** to remote
  - Verify the push completed successfully
12. Update PR description with release notes:
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
  - **REPLACE the entire PR description with release notes**:
    - **IMPORTANT**: Clear the existing PR description completely (including task list) and replace it with the release notes
    - This ensures the PR description is ready to be used as GitHub Release notes when merged to main
    - **Opening summary** (1-2 paragraphs):
      - Start with what was accomplished in user-focused language
      - Write in past tense: "Added...", "Improved...", "Fixed..."
      - Focus on the "why" - what problem does this solve or what capability does it enable?
      - Mention the user impact - who benefits and how?
      - At the end, add: "Fixes #<issue-number>"
    - **What's Changed** section:
      - 3-5 bullet points highlighting key changes from the user's perspective
      - Focus on capabilities, not implementation details
      - Example: "✨ Added support for custom templates" not "Created new Template class"
    - **Usage** section (if applicable):
      - Brief example showing how to use the new functionality
      - Keep it minimal - just enough to get started
      - Use code blocks for commands or code snippets
    - **Breaking Changes** section (if applicable):
      - Clear warning about what breaks
      - Migration guidance for users
      - What they need to change in their code
    - **Technical Notes** section (optional, for maintainers):
      - Brief implementation notes if relevant for reviewers
      - Dependencies added or updated
      - Architecture decisions
    - **Tone and style**:
      - Professional and concise
      - Avoid jargon and internal terminology
      - Write for the end user, not just developers
      - This description will be used in release notes
  - **Apply appropriate label(s)** based on the type of change
  - **Link the PR** to the associated issue
  - **Update `.fork-info.json`** (if it exists) with the latest PR number (if not already present)
  **GitHub Integration**: If GitHub tools or integrations are available (such as GitHub MCP Server or other GitHub integrations), use them to update the PR description in the target repository. If not available, provide this fallback command:

  ```bash
  # Replace PR description with release notes
  # If fork: gh pr edit <PR-number> --repo <upstream_owner>/<upstream_repo> --body "<release-note-description>"
  # If local: gh pr edit <PR-number> --body "<release-note-description>"
  gh pr edit <PR-number> --body "<release-note-description>"
  ```

13. Mark PR as ready for review:
  - **Determine target repository** (same logic as step 12):
    - Check if `.fork-info.json` exists in the feature directory
    - If it exists and validated, use `upstream_owner/upstream_repo`
    - If it doesn't exist, use the current repository (origin)
  - **Remove 'Implementing' label** from the linked issue and the PR in the target repository
  - **Mark PR as ready for review** (no longer draft)
  - **After updates**: Ensure `.fork-info.json` (if it exists) has both issue and PR numbers stored
  **GitHub Integration**: If GitHub tools are available, update labels and PR status automatically in the target repository. If not available, use:

  ```bash
  # Mark PR as ready for review
  # If fork: gh pr ready <PR-number> --repo <upstream_owner>/<upstream_repo>
  # If local: gh pr ready <PR-number>
  gh pr ready <PR-number>

  # Remove Implementing label from issue
  # If fork: gh issue edit <issue-number> --repo <upstream_owner>/<upstream_repo> --remove-label "Implementing"
  # If local: gh issue edit <issue-number> --remove-label "Implementing"
  gh issue edit <issue-number> --remove-label "Implementing"

  # Remove Implementing label from PR
  # If fork: gh pr edit <PR-number> --repo <upstream_owner>/<upstream_repo> --remove-label "Implementing"
  # If local: gh pr edit <PR-number> --remove-label "Implementing"
  gh pr edit <PR-number> --remove-label "Implementing"
  ```

Note: This command assumes a complete task breakdown exists in tasks.md. If tasks are incomplete or missing, suggest running `/tasks` first to regenerate the task list.
