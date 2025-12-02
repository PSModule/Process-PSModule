---
description: Create a pull request with a release note style description, appropriate title, and labels based on the change type.
---

# PR

The user input to you can be provided directly by the agent or as a command argument - you **MUST** consider it before proceeding with the prompt (if not empty).

## User input

$ARGUMENTS

**Purpose**: Create or update a pull request with a release note style description and title, automatically applying the appropriate labels based on the change type specified.

## Supported Change Types

| Type  | Icon | Labels         | Description                                |
| ----- | ---- | -------------- | ------------------------------------------ |
| Major | 🌟   | `Major`        | Breaking changes that affect compatibility |
| Minor | 🚀   | `Minor`        | New features or enhancements               |
| Patch | 🩹   | `Patch`        | Small fixes or improvements                |
| Fix   | 🪲   | `Fix`, `Patch` | Bugfixes                                   |
| Docs  | 📖   | `Docs`         | Documentation changes only                 |

## Execution Steps

0. If a folder is **explicitly attached to this chat** (“references”), you **must** change directory to the root of the git folder it is in. If there are no git folders you can change to the provided folder.

1. **Detect repository mode**:
   - Run `git remote -v` to check configured remotes.
   - **If `upstream` remote exists**: Fork mode
     - Use `upstream` owner/repo for all GitHub operations (PRs, Issues, labels)
     - Use `origin` for all git operations (push, fetch)
   - **If only `origin` remote exists**: Origin mode
     - Use `origin` owner/repo for all operations (both git push and GitHub operations)
   - Parse the URLs to extract owner and repo name: `https://github.com/<owner>/<repository>.git`.
   - If in doubt, ask the user to clarify which repository to target.

2. **Determine the change type**:
   1. Parse the user input to identify the change type (Major, Minor, Patch, Fix, or Docs)
   2. If nothing is provided, **analyze ALL changes in the branch** to infer the type:
      - Run `git diff origin/main...HEAD --name-only` to get all changed files in the branch
      - Read the diff content using `git diff origin/main...HEAD` to understand the nature of changes
      - Categorize based on ALL changes combined, not just recent commits:
        * **Docs**: ONLY if ALL changes are to documentation files (*.md, docs/, .github/prompts/, etc.) with no code/functionality changes
        * **Fix**: If changes specifically fix bugs without adding new features
        * **Patch**: Small fixes or improvements that do not add new features
        * **Minor**: New features or enhancements that do not break existing functionality
        * **Major**: Changes that break backward compatibility (e.g., removing public APIs, changing method signatures)
      - **Important**: If the branch contains BOTH code changes AND documentation changes, classify based on the code changes, not the documentation
      - **Important**: Check the entire branch diff, not just uncommitted changes or the last commit

3. **Stage, commit, and push all changes**:
   - **ALWAYS run these commands before creating/updating the PR**:
     1. `git add .` - Stage all changes (tracked and untracked files)
     2. Check if there are staged changes with `git diff --cached --quiet`
     3. If there are staged changes, commit with: `git commit -m "Update for PR"`
     4. `git push origin <branch-name>` - Push to origin remote (even in fork mode)
   - This ensures the PR reflects all local changes
   - Get the current branch name for the push command

4. **Retrieve linked issue information** (if available):
   - Attempt to find the GitHub issue number associated with the current branch
   - If found, retrieve the issue title from the **target repository** (upstream in fork mode, origin otherwise)
   - Use the issue title as the PR title (with appropriate icon prefix)
   - If no issue is found, ask the user to provide one of the following:
     - the number of the issue to link to the PR
     - if a new issue should be raised for this PR
     - Stop if the user cannot provide either of these.

5. **Generate PR title**:
   - **If issue title retrieved**: Use format `<Icon> <Issue Title>`
   - Examples:
     - `🚀 [Feature]: Add support for custom module templates`
     - `🪲 [Fix]: Resolve null reference in parameter validation`
     - `📖 [Docs]: Update installation guide with prerequisites`

6. **Generate release note style description**:
   - The PR description will be used automatically as the release note in an automated release
   - Use this exact structure (ordered list format):

   **1. Leading Paragraph (Summary)**
   - Write a concise paragraph describing **what changes for the user** of the solution
   - Focus on user-facing value and impact, not implementation details
   - Use present tense and active voice
   - Audience: Users of the solution (not developers)

   **2. Issue Links (Unordered List)**
   - Add one or more issue links as unordered list items
   - Format: `- Fixes #<issue-number>`
   - If multiple issues: `- Fixes #<issue-1>`, `- Fixes #<issue-2>`

   **3. Details (Sections with Headers)**
   - For each significant change, add a header (e.g., `## Configuration`, `## Breaking Changes`, `## Usage`)
   - Under each header, provide:
     * Details of what changed
     * What the user needs to change or do differently (if anything)
     * Examples or code snippets if helpful for understanding
   - Keep sections concise and user-focused
   - Avoid implementation details unless necessary for user understanding

   **Example Structure:**
   ````markdown
   The workflow now provides fine-grained control over repository linting behavior through simple configuration options. You can disable the linter entirely or customize which validations run by configuring super-linter environment variables directly in your settings file.

   - Fixes #218

   ## Configure settings for repository linting

   You can now control the linter behavior via the `Linter` section in your `.settings.yml` file. This allows you to skip linting altogether or customize which validations are performed.

   Added `Linter.Skip` and `Linter.env` settings to control linter behavior. You can now disable the linter entirely or customize which validations run.

   To disable the linter:
   ```yaml
   Linter:
     Skip: true
   ```

   To customize validations:
   ```yaml
   Linter:
     env:
       VALIDATE_JSCPD: false
   ```

   ````

7. **Create or update the pull request**:
   - **Check if PR already exists** for this branch in the **target repository** (upstream in fork mode, origin otherwise)
   - **If PR exists**: Update the title, description, and labels
   - **If PR does not exist**: Create a new PR from your fork's branch to the target repository's default branch
   - In fork mode, the PR will be from `<fork-owner>:<branch>` to `<upstream-owner>:<default-branch>`
   - Set PR to target the default branch (main/master) of the target repository
   - Open as a **draft PR** (or keep as draft if updating)
   - **Use GitHub MCP tools** to perform these operations in the **target repository**:
     - Create PR (if not exists) - owner/repo should be target repository, use `create_pull_request`
     - Update PR (if exists) - owner/repo should be target repository, use `update_pull_request`
     - Add labels to PR - owner/repo should be target repository, use `update_issue` (PRs are issues in GitHub API)

8. **Apply labels to the PR**:
   - Add the **change type label** based on the type specified (Major, Minor, Patch, Fix, or Docs)
   - For Fix type, add both `Fix` and `Patch` labels
   - If currently in a feature workflow phase (e.g., Planning, Implementation), also apply that phase label
   - Use GitHub MCP to add labels in the **target repository** (upstream in fork mode, origin otherwise)

9. **Confirm completion**:
   - Display the PR URL to the user
   - Summarize the PR title, type, and labels applied
   - If in fork mode, remind the user that the PR was created in the upstream repository

## Example usage

- `/PR` - Create a PR for the current changes
- `/PR Minor` - Create a PR for a new feature
- `/PR Fix` - Create a PR for a bugfix
- `/PR Docs` - Create a PR for documentation changes
- `/PR Major` - Create a PR for breaking changes
- `/PR Patch` - Create a PR for small improvements

## Notes

- **This command always stages all changes (`git add .`), commits if needed, and pushes to origin before creating/updating the PR**
- Changes are always pushed to `origin` remote
- In fork mode, PRs and Issue operations are performed on the `upstream` repository
- In origin mode, all operations use the `origin` repository
- The PR is always created as a draft to allow for review before marking as ready
- Labels can be manually adjusted after PR creation if needed
- **The PR description uses a structured format designed for automated release notes**:
  1. Leading paragraph (user-focused summary)
  2. Issue links (unordered list)
  3. Details (sections with headers explaining changes and user actions needed)
