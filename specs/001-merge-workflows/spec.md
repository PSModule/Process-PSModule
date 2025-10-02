# Feature Specification: Merge CI and Main Workflows

## User Scenarios & Testing *(mandatory)*

### Primary User Story

As a PowerShell module maintainer, I want a unified workflow that handles both continuous integration (on PRs) and release publishing (on merge), with optional scheduled runs for nightly testing, so that I can reduce workflow duplication and simplify my repository configuration.

**⚠️ BREAKING CHANGE**: This will remove CI.yml, requiring all consuming repositories to update their workflow references from `CI.yml` to `workflow.yml`.

### Acceptance Scenarios

1. **Given** a pull request is opened/synchronized, **When** the workflow runs, **Then** it should build, test, lint, and collect test results/code coverage, but NOT publish the module/docs unless the PR has a "preview" label
2. **Given** a pull request is merged to main, **When** the workflow completes successfully, **Then** it should run all build, test, and quality checks AND publish both the module and documentation site
3. **Given** a scheduled/manual workflow run is triggered, **When** the workflow executes, **Then** it should run all build and test steps but skip the publish steps entirely
4. **Given** tests fail in any stage, **When** the workflow continues, **Then** it should still complete code coverage and test result summarization steps (no early termination)
5. **Given** a module repository uses this workflow, **When** it's configured, **Then** the Nightly-Run.yml workflow should no longer be needed
6. **Given** an existing repository references CI.yml, **When** upgrading to the new version, **Then** it must update references from `CI.yml` to `workflow.yml` or the workflow will fail

### Edge Cases

- What happens when test jobs fail but we still need code coverage reports? The workflow should continue processing with `always()` conditions
- How does the system handle preview publishes on non-merged PRs? The Publish-Module action already has logic to check for "preview" label and handle versioning accordingly
- What if a repository has no tests configured? The workflow should skip test-related jobs gracefully using conditional logic
- What happens to repositories that don't update their CI.yml references? Their workflows will fail with "workflow not found" errors

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The merged workflow MUST support three trigger modes: pull request events, scheduled runs, and manual dispatch
- **FR-002**: The workflow MUST execute build, test, and quality checks for all trigger types
- **FR-003**: The workflow MUST publish module and documentation ONLY when:
  - Trigger is a merged pull request (to main), OR
  - Trigger is an open/synchronized pull request with "preview" label
- **FR-004**: The workflow MUST skip publish steps when triggered by schedule or workflow_dispatch
- **FR-005**: Test result summarization and code coverage jobs MUST run even when test jobs fail (using `always()` and `!cancelled()` conditions)
- **FR-006**: The workflow MUST maintain all current permissions for different operations (contents, pull-requests, statuses, pages, id-token)
- **FR-007**: The workflow MUST support all existing inputs (Name, SettingsPath, Debug, Verbose, Version, Prerelease, WorkingDirectory)
- **FR-008**: The workflow MUST support all existing secrets (APIKey, test credentials)
- **FR-009**: Module repositories using this workflow MUST be able to remove their Nightly-Run.yml workflow file
- **FR-010**: The CI.yml workflow file in Process-PSModule MUST be removed as it becomes redundant (BREAKING CHANGE)
- **FR-011**: The workflow MUST include a concurrency group to cancel in-progress runs when new commits are pushed to the same PR
- **FR-012**: The workflow name and run-name MUST provide clear context about what triggered the run
- **FR-013**: Documentation MUST clearly indicate the breaking change and provide migration steps for consuming repositories
- **FR-014**: The release MUST be a major version bump due to the breaking change of removing CI.yml

### Breaking Changes

- **BC-001**: CI.yml will be deleted - all references to `PSModule/Process-PSModule/.github/workflows/CI.yml@vX` must be updated to `workflow.yml`
- **BC-002**: Repositories with Nightly-Run.yml or similar workflows calling CI.yml must update their configurations before upgrading

### Migration Requirements

- **MR-001**: Consuming repositories MUST update workflow references from `CI.yml` to `workflow.yml`
- **MR-002**: Consuming repositories SHOULD remove their Nightly-Run.yml files and update their main workflow to include schedule/dispatch triggers
- **MR-003**: Migration documentation MUST include before/after examples of workflow configurations

### Key Entities

- **Workflow Triggers**: Pull request events (opened, reopened, synchronize, closed, labeled), schedule (cron), workflow_dispatch
- **Job Dependencies**: Get-Settings → Build → Test → Summarization → Publish (conditional)
- **Execution Contexts**: PR validation mode (no publish unless preview), merge mode (full publish), scheduled mode (no publish)
- **Consuming Repositories**: Any repository using CI.yml that must migrate to workflow.yml

---

**Feature Branch**: `001-merge-workflows`
**Created**: 2025-10-02
**Status**: Draft
**Input**: User description: "Merge ci.yml into workflow.yml, so that we can deduplicate and two workflows and have less workflows in the repos that use this process. When the pr is created, we do want publish to run, but its got logic to not publish, unless the pull request has a 'preview' label. When merged, the full pipeline should run. When there are failures in tests, it should continue working as it is (completing code coverage and test result summarization). A repo will NEVER only need ci functionality. Check the Template-PSModule's workflow to see how its currently configured for module repos. We want to basically remove the need for the nightly run pipeline, and update the main process workflow with a schedule and a workflow dispatch. When its running in this mode, we do not want the publish steps (module and docs) to run."

## Execution Flow (main)

1. ✅ Parse user description from Input
2. ✅ Extract key concepts from description
   - Merge two workflow files (CI.yml and workflow.yml)
   - Support three execution modes: PR validation, merge/publish, scheduled testing
   - Maintain existing failure handling behavior
   - Eliminate Nightly-Run.yml from module repositories
3. ✅ Generate Functional Requirements
   - All requirements are testable through workflow execution
4. ✅ Identify Key Entities
   - Workflow triggers and execution contexts
5. ✅ Run Review Checklist
   - No implementation details included
   - All requirements clear and testable

---

## ⚡ Quick Guidelines

- ✅ Focus on WHAT users need and WHY
- ❌ Avoid HOW to implement (no tech stack, APIs, code structure)
- 👥 Written for business stakeholders, not developers

### Section Requirements

- **Mandatory sections**: Must be completed for every feature
- **Optional sections**: Include only when relevant to the feature
- When a section doesn't apply, remove it entirely (don't leave as "N/A")

---

## Review & Acceptance Checklist

*GATE: Automated checks run during main() execution*

### Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

### Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

---

## Execution Status

*Updated by main() during processing*

- [x] User description parsed
- [x] Key concepts extracted
- [x] Ambiguities marked (none found)
- [x] User scenarios defined
- [x] Requirements generated
- [x] Entities identified
- [x] Review checklist passed
