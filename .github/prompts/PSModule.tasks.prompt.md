---
description: Generate an actionable, dependency-ordered tasks.md for the feature based on available design artifacts.
---

# Tasks

The user input to you can be provided directly by the agent or as a command argument - you **MUST** consider it before proceeding with the prompt (if not empty).

User input:

$ARGUMENTS

**Workflow Modes**: This command supports two modes:
- **Local (default)**: Work with the current repository (origin). No special configuration needed.
- **Fork**: Contribute to an upstream repository. Detected via `git remote -v`.

**Iteration Support**: This command detects whether you're creating new tasks or updating existing ones based on the presence of tasks.md in the feature directory.

1. Run [`.specify/scripts/powershell/check-prerequisites.ps1 -Json`](../../.specify/scripts/powershell/check-prerequisites.ps1) from repo root and parse FEATURE_DIR and AVAILABLE_DOCS list. All paths must be absolute.
   - **Detect iteration mode**: Check if FEATURE_DIR/tasks.md already exists:
     - **If exists**: You are ITERATING on existing tasks. User input should guide refinements, additions, or reordering of tasks.
     - **If not exists**: You are CREATING new tasks from scratch.

2. Load and analyze available design documents:
   - Always read plan.md for tech stack and libraries
   - IF EXISTS: Read data-model.md for entities
   - IF EXISTS: Read contracts/ for API endpoints
   - IF EXISTS: Read research.md for technical decisions
   - IF EXISTS: Read quickstart.md for test scenarios

   Note: Not all projects have all documents. For example:
   - Command-line tools might not have contracts/
   - Simple libraries might not need data-model.md
   - Generate tasks based on what's available

3. Generate tasks following the template:
   - **If ITERATING** (tasks.md exists):
     - Read existing tasks.md content
     - Identify what needs updating based on user input ($ARGUMENTS)
     - Preserve completed tasks (marked with [X])
     - Add new tasks as needed
     - Reorder or refine task descriptions
     - Maintain task ID sequence
   - **If CREATING** (new tasks):
     - Use [`.specify/templates/tasks-template.md`](../../.specify/templates/tasks-template.md) as the base
     - Replace example tasks with actual tasks based on:
       * **Setup tasks**: Project init, dependencies, linting
       * **Test tasks [P]**: One per contract, one per integration scenario
       * **Core tasks**: One per entity, service, CLI command, endpoint
       * **Integration tasks**: DB connections, middleware, logging
       * **Polish tasks [P]**: Unit tests, performance, docs

4. Task generation rules:
   - Each contract file → contract test task marked [P]
   - Each entity in data-model → model creation task marked [P]
   - Each endpoint → implementation task (not parallel if files are shared)
   - Each user story → integration test marked [P]
   - Different files = can be parallel [P]
   - Same file = sequential (no [P])

5. Order tasks by dependencies:
   - Setup before everything
   - Tests before implementation (TDD)
   - Models before services
   - Services before endpoints
   - Core before integration
   - Everything before polish

6. Include parallel execution examples:
   - Group [P] tasks that can run together
   - Show actual Task agent commands

7. Create FEATURE_DIR/tasks.md with:
   - Correct feature name from implementation plan
   - Numbered tasks (T001, T002, etc.)
   - Clear file paths for each task
   - Dependency notes
   - Parallel execution guidance
   - **IMPORTANT**: After each task in the task list, add a sub-step to update the PR description:
     * Add: "After completing this task, update the PR description to mark this task as complete by changing `- [ ] T###:` to `- [X] T###:` in the Implementation Tasks section"
     * This ensures that the PR description stays synchronized with actual progress
     * Each task should have this update step included in its description or as a final action item

8. Update the Pull Request description:
   - **Determine workflow mode and target repository**:
     - Run `git remote -v` to check configured remotes.
     - **If `upstream` remote exists**: Fork mode
       - Use `upstream` owner/repo for all GitHub operations (PRs, Issues, labels)
       - Use `origin` for all git operations (push, fetch)
     - **If only `origin` remote exists**: Origin mode
       - Use `origin` owner/repo for all operations (both git push and GitHub operations)
     - Parse the URLs to extract owner and repo name: `https://github.com/<owner>/<repository>.git`.
     - If in doubt, ask the user to clarify which repository to target.
   - Append or update the tasks.md content in the existing PR description
   - Format tasks with checkboxes for each task phase:
     * Setup: `- [ ] T001: Task description`
     * Tests: `- [ ] T002: Task description [P]`
     * Core: `- [ ] T003: Task description`
     * Integration: `- [ ] T004: Task description`
     * Polish: `- [ ] T005: Task description [P]`
   - Keep the existing PR content (summary, plan.md content, issue link)
   - Add a section header before tasks: `## Implementation Tasks`

   **GitHub Integration**: If GitHub tools or integrations are available (such as GitHub MCP Server or other GitHub integrations), use them to update the PR description automatically in the target repository. If not available, provide this fallback command with the correct repository:
   ```bash
   # Get current PR description and append tasks
   # If fork: gh pr view <PR-number> --repo <upstream_owner>/<upstream_repo> --json body --jq .body > temp_body.md
   # If local: gh pr view <PR-number> --json body --jq .body > temp_body.md
   gh pr view <PR-number> --json body --jq .body > temp_body.md
   cat tasks.md >> temp_body.md
   # If fork: gh pr edit <PR-number> --repo <upstream_owner>/<upstream_repo> --body-file temp_body.md
   # If local: gh pr edit <PR-number> --body-file temp_body.md
   gh pr edit <PR-number> --body-file temp_body.md
   rm temp_body.md
   ```

9. **Post final status comment**: "✅ Task list ready. Run `/analyze` for quality check or `/implement` to begin execution."

10. Report completion with task count, file path, and PR update status.

Context for task generation: $ARGUMENTS

The tasks.md should be immediately executable - each task must be specific enough that an LLM can complete it without requiring additional context.
