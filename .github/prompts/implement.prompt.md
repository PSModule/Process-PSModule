---
description: Execute the implementation plan by processing and executing all tasks defined in tasks.md
---

# Implement

The user input can be provided directly by the agent or as a command argument — you **MUST** consider it before proceeding with the prompt (if not empty).

**User input:**

$ARGUMENTS

---

**Workflow Modes**: This command supports two modes:

- **Local (default)**: Work with the current repository (origin). No special configuration needed.
- **Fork**: Contribute to an upstream repository. Detected via `git remote -v`.

**Iteration Support**: This command supports iterative implementation — you can run it multiple times to complete remaining tasks, fix issues, or add refinements. Task completion state is tracked in `tasks.md` with `[X]` markers.

---

## Workflow Steps

1. **Set Implementing label immediately**
   - **Determine target repository**:
     - Run `git remote -v` to check configured remotes.
     - **If `upstream` remote exists**: Fork mode
       - Use `upstream` owner/repo for all GitHub operations (PRs, Issues, labels)
       - Use `origin` for all git operations (push, fetch)
     - **If only `origin` remote exists**: Origin mode
       - Use `origin` owner/repo for all operations (both git push and GitHub operations)
     - Parse the URLs to extract owner and repo name: `https://github.com/<owner>/<repository>.git`.
     - If in doubt, ask the user to clarify which repository to target.
   - Get the issue number associated with the current feature branch.
   - **Add `Implementing` label** to the issue and PR immediately in the target repository.
   - **Remove `Planning` label** from the issue and PR.

   **GitHub Integration**: If GitHub tools are available, update labels automatically in the target repository. If not available, use:

   ```bash
   # If fork: gh issue edit <issue-number> --repo <upstream_owner>/<upstream_repo> --remove-label "Planning" --add-label "Implementing"
   # If local: gh issue edit <issue-number> --remove-label "Planning" --add-label "Implementing"
   gh issue edit <issue-number> --remove-label "Planning" --add-label "Implementing"
   ```

2. **Run prerequisites**
   Run [`check-prerequisites.ps1`](../../.specify/scripts/powershell/check-prerequisites.ps1) from repo root:

   ```powershell
   .specify/scripts/powershell/check-prerequisites.ps1 -Json -RequireTasks -IncludeTasks
   ```

   Parse `FEATURE_DIR` and `AVAILABLE_DOCS` list. All paths must be absolute.

3. **Load and analyze the implementation context**

   * **REQUIRED**: Read `tasks.md` for the complete task list and execution plan.
   * **REQUIRED**: Read `plan.md` for tech stack, architecture, and file structure.
   * **IF EXISTS**: Read `data-model.md` for entities and relationships.
   * **IF EXISTS**: Read `contracts/` for API specifications and test requirements.
   * **IF EXISTS**: Read `research.md` for technical decisions and constraints.
   * **IF EXISTS**: Read `quickstart.md` for integration scenarios.

4. **Parse `tasks.md` structure and extract**

   * Detect iteration state (completed `[X]`, pending `[ ]`).
   * Identify task phases: Setup, Tests, Core, Integration, Polish.
   * Capture dependencies: sequential vs parallel (`[P]`).
   * Build execution flow based on order and requirements.

5. **Execute implementation following the task plan**

   * Skip completed `[X]` tasks.
   * Resume from first `[ ]` task.
   * Execute phase-by-phase, respecting dependencies.
   * Follow TDD: tests before implementation.
   * Coordinate tasks by file access.
   * Add validation checkpoints.

6. **Implementation execution rules**

   * Setup first (dependencies, configs).
   * Tests before code.
   * Core development.
   * Integration (DB, middleware, logging, external services).
   * Polish (tests, performance, docs).

7. **Progress tracking and error handling**

   * Report progress after each task.
   * Halt on failed sequential tasks; continue parallel `[P]` where possible.
   * Provide clear error messages and next-step suggestions.
   * **Update task status immediately after completion**:

     * Mark as `[X]` in `tasks.md`.
     * Update PR task list (`- [ ] T###:` → `- [X] T###:`).
     * Use `gh pr edit <PR-number> --body "<updated-description>"` if needed.

8. **Completion validation**

   * Verify required tasks.
   * Confirm spec compliance.
   * Ensure tests pass and coverage is met.
   * Check against `plan.md`.
   * Report final status.

9. **Update the constitution**

   * Read [Constitution](../../.specify/memory/constitution.md).
   * Read [constitution prompt](./constitution.prompt.md).
   * Update constitution with implemented details.
   * Remove obsolete sections.

10. **Update the CHANGELOG**

    * Use `CHANGELOG.md` in root.
    * Add entry in [Keep a Changelog](https://keepachangelog.com) format.
    * Categories: Added, Changed, Deprecated, Removed, Fixed, Security.
    * Keep user-focused and concise.
    * Example:

      ```markdown
      ## [Unreleased] - 2025-10-03

      ### Added
      - Support for new implementation workflow [#123]
      ```

11. **Final commit and push**

    * Stage all changes (`tasks.md`, `CHANGELOG.md`, `constitution.md`, code, configs).
    * Commit using Conventional Commit format:

      ```markdown
      <type>(<scope>): <description>
      Fixes #<issue-number>
      ```
    * Push branch to remote.

12. **Update PR description with release notes**

    * Replace PR body entirely with release notes.
    * Ensure title matches issue.
    * Release note structure:

      * Opening summary (what, why, impact).
      * **What's Changed** (3–5 bullets).
      * **Usage** (if needed).
      * **Breaking Changes** (if any).
      * **Technical Notes** (optional).

    **Fallback command:**

    ```bash
    gh pr edit <PR-number> --body "<release-note-description>"
    ```

13. **Mark PR as ready for review**

    * Remove `Implementing` label.
    * Ensure PR is not draft.

    **Fallback commands:**

    ```bash
    gh pr ready <PR-number>
    gh issue edit <issue-number> --remove-label "Implementing"
    gh pr edit <PR-number> --remove-label "Implementing"
    ```

---

**Note**: This command assumes a complete task breakdown exists in `tasks.md`. If missing, run `/tasks` first to regenerate.
