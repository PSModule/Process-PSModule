# Feature Specification: Merge CI.yml into Workflow.yml

## User Scenarios & Testing

### Primary User Story

As a PowerShell module maintainer using the Process-PSModule framework, I want a single reusable workflow file that intelligently handles pull requests (with optional preview publishing), merged releases (with full publishing), and scheduled/manual test runs (without publishing), so that my repository configuration is simpler with fewer workflow files to maintain and the Nightly-Run.yml workflow is no longer needed.

### Acceptance Scenarios

1. **Given** a pull request is opened, **When** the workflow runs, **Then** all build/test/lint jobs execute and publish jobs run but skip publishing unless the PR has a "preview" label
2. **Given** a pull request with "preview" label is opened, **When** the workflow runs, **Then** the full pipeline executes including module and documentation publishing to preview environments
3. **Given** a pull request is merged to main, **When** the workflow runs, **Then** the full pipeline executes including module publishing to PowerShell Gallery and documentation deployment to GitHub Pages
4. **Given** the workflow is triggered by workflow_dispatch or schedule (nightly), **When** the workflow runs, **Then** all build/test/lint jobs execute but publish jobs (Publish-Site, Publish-Module) are skipped
5. **Given** test jobs fail during execution, **When** the workflow continues, **Then** code coverage aggregation and test result summarization still complete successfully
6. **Given** a repository currently uses both Process-PSModule.yml and Nightly-Run.yml, **When** migrated to the unified workflow, **Then** only Process-PSModule.yml is needed with workflow_dispatch and schedule triggers added

### Edge Cases

- What happens when a pull request is created? → Should run full pipeline including publish jobs, but publish jobs contain logic to skip unless PR has "preview" label
- What happens when a pull request is merged to main? → Should run full pipeline including all publishing steps
- How does the system handle test failures? → Should continue to completion, including code coverage and test result summarization (existing behavior)
- What happens when triggered by workflow_dispatch or schedule (nightly run)? → Should run all build/test/lint jobs but skip publishing steps (replaces separate Nightly-Run.yml workflow)
- What happens if a repository only needs CI functionality? → Not applicable - all repositories using Process-PSModule run the full workflow

---

## Requirements

### Functional Requirements

- **FR-001**: System MUST preserve all job definitions from CI.yml (Get-Settings, Build-Module, Build-Docs, Build-Site, Test-SourceCode, Lint-SourceCode, Test-Module, Test-ModuleLocal, BeforeAll-ModuleLocal, AfterAll-ModuleLocal, Get-TestResults, Get-CodeCoverage)
- **FR-002**: System MUST preserve all job definitions from workflow.yml (all jobs from CI.yml plus Publish-Site and Publish-Module)
- **FR-003**: System MUST maintain identical input parameters as defined in both workflows (Name, SettingsPath, Debug, Verbose, Version, Prerelease, WorkingDirectory)
- **FR-004**: System MUST maintain identical secrets definitions as defined in both workflows (APIKey, TEST_APP_ENT_CLIENT_ID, TEST_APP_ENT_PRIVATE_KEY, TEST_APP_ORG_CLIENT_ID, TEST_APP_ORG_PRIVATE_KEY, TEST_USER_ORG_FG_PAT, TEST_USER_USER_FG_PAT, TEST_USER_PAT)
- **FR-005**: System MUST support workflow_dispatch trigger to allow manual workflow execution
- **FR-006**: System MUST support schedule trigger for nightly automated test runs
- **FR-007**: Publish-Site job MUST execute when a pull request is merged to main and all prerequisite jobs succeed
- **FR-008**: Publish-Module job MUST execute when a pull request is merged to main and all prerequisite jobs succeed
- **FR-009**: Publish-Site job MUST execute when a pull request has the "preview" label and is not merged
- **FR-010**: Publish-Module job MUST execute when a pull request has the "preview" label and is not merged (with preview/prerelease publishing logic)
- **FR-011**: Publish-Site and Publish-Module jobs MUST be skipped when triggered via workflow_dispatch or schedule
- **FR-012**: System MUST maintain all job dependencies and execution order as defined in the original workflows
- **FR-013**: System MUST continue executing code coverage and test result jobs even when test jobs fail
- **FR-014**: System MUST maintain all conditional logic for job execution (if conditions) from both workflows
- **FR-015**: Repositories using Process-PSModule MUST be able to reference a single workflow file for all execution modes (PR, merge, scheduled, manual)
- **FR-016**: CI.yml file MUST be removed after successful migration to prevent confusion
- **FR-017**: Nightly-Run.yml workflow in module repositories MUST be removed as its functionality is absorbed into the unified workflow
- **FR-018**: Unified workflow MUST use write permissions (contents: write, pull-requests: write, statuses: write, pages: write, id-token: write) to support all execution modes

### Key Entities

- **CI.yml Workflow**: GitHub Actions reusable workflow file that currently handles continuous integration tasks (build, test, lint) with read-only permissions, used by Nightly-Run.yml for scheduled testing
- **workflow.yml Workflow**: GitHub Actions reusable workflow file that handles full pipeline including CI tasks plus publishing (site deployment, module publishing) with write permissions, used for pull request workflows
- **Nightly-Run.yml**: Repository-level workflow in module repos that triggers CI.yml on a schedule or manual dispatch for testing without publishing
- **Process-PSModule.yml**: Repository-level workflow in module repos that triggers workflow.yml for pull request and merge operations
- **Job Definitions**: Reusable workflow jobs that perform specific operations (Get-Settings, Build-Module, Test-Module, etc.)
- **Publish Jobs**: Publish-Site and Publish-Module jobs that deploy documentation and modules, with conditional execution based on trigger type and PR labels
- **Trigger Types**: Different invocation methods (pull_request opened/synchronized, pull_request merged, workflow_dispatch, schedule) that determine which jobs execute
- **Preview Label**: Pull request label that enables preview publishing for testing changes before merge
- **Permissions**: GitHub Actions permission sets that control what the workflow can do (write permissions needed for all modes)

---

**Feature Branch**: `002-merge-ci-yml`
**Created**: 2025-10-02
**Status**: Draft
**Input**: User description: "Merge ci.yml into workflow.yml, so that we can deduplicate and two workflows and have less workflows in the repos that use this process."

## Execution Flow (main)

1. Parse user description from Input
   → Feature description is clear: consolidate two similar workflow files
2. Extract key concepts from description
   → Actors: PowerShell module maintainers, CI/CD pipeline
   → Actions: Merge workflows, deduplicate configuration, reduce workflow count
   → Data: Workflow YAML files, job definitions, permissions
   → Constraints: Must maintain existing functionality
3. For each unclear aspect:
   → No major ambiguities; requirements are well-defined
4. Fill User Scenarios & Testing section
   → Primary user flow: Repository using Process-PSModule framework references a single workflow
5. Generate Functional Requirements
   → Requirements focus on workflow consolidation and preservation of functionality
6. Identify Key Entities
   → CI.yml workflow, workflow.yml, job definitions, permissions
7. Run Review Checklist
   → No implementation details included; focused on user value
8. Return: SUCCESS (spec ready for planning)

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

- [x] User description parsed
- [x] Key concepts extracted
- [x] Ambiguities marked (none identified)
- [x] User scenarios defined
- [x] Requirements generated
- [x] Entities identified
- [x] Review checklist passed
