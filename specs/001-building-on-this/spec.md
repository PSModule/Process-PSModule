# Feature Specification: Local GitHub Composite Action for BeforeAll/AfterAll Test Scripts

**Feature Branch**: `001-building-on-this`
**Created**: October 1, 2025
**Status**: Draft
**Input**: User description: "Building on this branch, we want to add a local github action (composite) to run the BeforeAll and AfterAll
scripts and call this from the workflows ci.yml and workflow (via Test-ModuleLocal)."

## Execution Flow (main)
```
1. Parse user description from Input
   → Feature request identified: Create reusable composite action for setup/teardown scripts
2. Extract key concepts from description
   → Actors: CI/CD workflows, test runners, module developers
   → Actions: Execute BeforeAll.ps1 scripts before tests, AfterAll.ps1 scripts after tests
   → Data: Test directories, setup/teardown scripts, environment secrets
   → Constraints: Must integrate with existing Test-ModuleLocal workflow
3. Unclear aspects identified:
   → Action location and naming convention - assumed ✓
   → Error handling differences from inline implementation - specified in requirements
   → Additional inputs/outputs beyond current inline version - specified in requirements
4. User Scenarios & Testing section completed
   → Primary flow: Workflow calls composite action for setup/teardown
   → Edge cases: Missing scripts, script failures, multiple test directories
5. Functional Requirements generated
   → All requirements are testable
   → No ambiguous requirements requiring clarification
6. Key Entities identified
   → Composite action, test directories, setup/teardown scripts
7. Review Checklist status
   → No implementation details included (GitHub Actions syntax is configuration, not implementation)
   → Focused on behavior and integration requirements
   → All sections completed with clear acceptance criteria
8. Return: SUCCESS (spec ready for planning)
```

---

## ⚡ Quick Guidelines
- ✅ Focus on WHAT users need and WHY
- ❌ Avoid HOW to implement (no tech stack, APIs, code structure)
- 👥 Written for business stakeholders, not developers

---

## Clarifications

### Session 2025-10-01
- Q: When multiple BeforeAll.ps1 scripts exist in nested directories, what execution order should be guaranteed? → A: Scripts only supported in root tests folder - no nested directory support.
- Q: Which runner OS should BeforeAll-ModuleLocal and AfterAll-ModuleLocal jobs use? → A: ubuntu-latest only - Keep current behavior, actions run on Linux only.
- Q: What level of detail is required for the output showing whether scripts were found and executed? → A: Match current - Same output format as current inline implementation in Test-ModuleLocal.yml.
- Q: Should separate actions be created for BeforeAll and AfterAll, or a different approach? → A: Single action with mode parameter (before/after modes).
- Q: What should the composite action be named and where should it be located? → A: Setup-Test - `.github/actions/setup-test/action.yml`.

---

## User Scenarios & Testing

### Primary User Story
As a module developer using the Process-PSModule framework, I want the BeforeAll and AfterAll test setup/teardown logic to be encapsulated in a
reusable local composite action so that the Test-ModuleLocal workflow is cleaner, more maintainable, and the logic can potentially be reused in other
workflows without duplication.

Currently, the BeforeAll-ModuleLocal and AfterAll-ModuleLocal jobs in Test-ModuleLocal.yml contain inline PowerShell scripts that locate and execute BeforeAll.ps1 and AfterAll.ps1 scripts in the root tests directory with environment variables.

This logic should be extracted into a single local composite action with a mode parameter (before/after) that both Test-ModuleLocal.yml and ci.yml can reference.

### Acceptance Scenarios

1. **Given** the local composite action exists with mode parameter set to "before" and a BeforeAll.ps1 script is in the root tests folder, **When** Test-ModuleLocal workflow executes the BeforeAll-ModuleLocal job, **Then** it should call the composite action which discovers and executes the BeforeAll.ps1 script with access to all required secrets and environment variables.

2. **Given** the local composite action exists with mode parameter set to "after" and an AfterAll.ps1 script is in the root tests folder, **When** Test-ModuleLocal workflow executes the AfterAll-ModuleLocal job (even if tests fail), **Then** it should call the composite action which discovers and executes the AfterAll.ps1 script and continues execution even if the script fails.

3. **Given** no tests directory exists in the repository, **When** the composite action runs in either mode, **Then** it should exit successfully with a clear message indicating no tests were found.

4. **Given** a tests directory exists but no BeforeAll.ps1 script is present, **When** the composite action runs in "before" mode, **Then** it should exit successfully with a message indicating no setup script was found.

5. **Given** a tests directory exists but no AfterAll.ps1 script is present, **When** the composite action runs in "after" mode, **Then** it should exit successfully with a message indicating no teardown script was found.

6. **Given** a BeforeAll.ps1 script in the root tests folder fails during execution, **When** the composite action runs in "before" mode, **Then** it should fail the workflow job and provide clear error output indicating the script failed.

7. **Given** an AfterAll.ps1 script in the root tests folder fails during execution, **When** the composite action runs in "after" mode, **Then** it should log a warning but complete successfully to ensure the workflow can finish.

8. **Given** the composite action is called from Test-ModuleLocal.yml, **When** it needs access to test secrets (TEST_APP_*, TEST_USER_*, GITHUB_TOKEN), **Then** those secrets should be available to the BeforeAll/AfterAll scripts through environment variables regardless of mode.

### Edge Cases

- What happens when the composite action is called from a workflow that requires a different runner OS?
  - **Answer**: The composite actions run on ubuntu-latest runners as part of BeforeAll-ModuleLocal and AfterAll-ModuleLocal jobs; the actions themselves are not directly portable to other OS runners

- What happens when a script takes an exceptionally long time to execute?
  - **Answer**: Standard GitHub Actions timeout limits apply; workflows should set appropriate timeout-minutes if needed

- What happens when BeforeAll.ps1 or AfterAll.ps1 scripts exist in nested subdirectories under tests/?
  - **Answer**: Nested scripts are not supported; only scripts in the root tests folder (tests/BeforeAll.ps1, tests/AfterAll.ps1) are discovered and executed

---

## Requirements

### Functional Requirements

- **FR-001**: System MUST provide a single local composite action that can execute either BeforeAll.ps1 or AfterAll.ps1 scripts based on a mode parameter.

- **FR-002**: The composite action MUST accept a required "mode" input parameter with allowed values of "before" or "after".

- **FR-003**: When mode is "before", the action MUST look for BeforeAll.ps1 only in the root 'tests' folder (tests/BeforeAll.ps1).

- **FR-004**: When mode is "after", the action MUST look for AfterAll.ps1 only in the root 'tests' folder (tests/AfterAll.ps1).

- **FR-005**: The composite action MUST change to the tests directory before script execution and restore the previous directory afterward.

- **FR-006**: When mode is "before", the action MUST fail the workflow job if the BeforeAll.ps1 script fails, providing clear error messages.

- **FR-007**: When mode is "after", the action MUST log warnings for script failures but complete successfully to allow workflow cleanup to finish.

- **FR-008**: The composite action MUST exit successfully with informative messages when no tests directory exists, regardless of mode.

- **FR-009**: When mode is "before" and no BeforeAll.ps1 script exists, the action MUST exit successfully with an informative message.

- **FR-010**: When mode is "after" and no AfterAll.ps1 script exists, the action MUST exit successfully with an informative message.

- **FR-011**: The composite action MUST accept all environment secrets currently used in Test-ModuleLocal workflow (TEST_APP_ENT_CLIENT_ID, TEST_APP_ENT_PRIVATE_KEY, TEST_APP_ORG_CLIENT_ID, TEST_APP_ORG_PRIVATE_KEY, TEST_USER_ORG_FG_PAT, TEST_USER_USER_FG_PAT, TEST_USER_PAT, GITHUB_TOKEN).

- **FR-012**: The composite action MUST accept standard configuration inputs: Debug, Verbose, Prerelease, Version, WorkingDirectory.

- **FR-013**: The composite action MUST provide output matching the current inline implementation format, including LogGroup wrappers, status messages for script discovery, execution confirmation, and completion status.

- **FR-014**: Test-ModuleLocal.yml workflow MUST replace its inline BeforeAll and AfterAll logic with calls to the new composite action with appropriate mode parameters.

- **FR-015**: The composite action MUST be stored at `.github/actions/setup-test/action.yml`.

- **FR-016**: The composite action MUST support execution on ubuntu-latest runners where the BeforeAll-ModuleLocal and AfterAll-ModuleLocal jobs run.

- **FR-017**: The composite action MUST use PSModule/GitHub-Script@v1 for executing PowerShell logic to maintain consistency with current implementation.

- **FR-018**: The composite action MUST use PSModule/Install-PSModuleHelpers@v1 to ensure required helper modules are available.

- **FR-019**: When called with mode "after", the workflow job MUST always execute regardless of previous job failures (if: always() condition).

- **FR-020**: The composite action MUST maintain the same functional behavior as the current inline implementation in Test-ModuleLocal.yml for root-level scripts.

### Key Entities

- **Local Composite Action (Setup-Test)**: A reusable GitHub Actions composite action that encapsulates the logic for discovering and executing either BeforeAll.ps1 or AfterAll.ps1 scripts based on a mode parameter. Located at `.github/actions/setup-test/action.yml`. Accepts a required mode input ("before" or "after"), along with configuration and secrets inputs. Uses GitHub-Script action for PowerShell execution. Behavior changes based on mode: "before" mode fails on script errors, "after" mode continues on errors.

- **Mode Parameter**: An input parameter that controls which script the action looks for and how it handles errors. Valid values: "before" (looks for BeforeAll.ps1, fails on errors) or "after" (looks for AfterAll.ps1, continues on errors).

- **Test Directory**: The root 'tests' folder in the repository that may contain optional BeforeAll.ps1 or AfterAll.ps1 scripts. Nested subdirectories are not searched for these scripts.

- **BeforeAll.ps1 Script**: An optional PowerShell script located at tests/BeforeAll.ps1 that runs once before all test matrix jobs to set up the test environment (e.g., deploy infrastructure, initialize test data). Executed when the composite action is called with mode="before". Executed with full access to environment secrets. Failures halt the testing workflow.

- **AfterAll.ps1 Script**: An optional PowerShell script located at tests/AfterAll.ps1 that runs once after all test matrix jobs complete to clean up the test environment (e.g., remove test resources, cleanup databases). Executed when the composite action is called with mode="after". Executed with full access to environment secrets. Failures are logged but do not prevent workflow completion.

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
- [x] Ambiguities marked (none requiring clarification)
- [x] User scenarios defined
- [x] Requirements generated
- [x] Entities identified
- [x] Review checklist passed

---

## Additional Context

### Integration Points
- **Test-ModuleLocal.yml**: Primary workflow that will consume both composite actions
- **ci.yml**: Main CI workflow that orchestrates Test-ModuleLocal.yml
- **Existing Actions**: PSModule/GitHub-Script@v1 and PSModule/Install-PSModuleHelpers@v1 used by composite actions

### Assumptions
- The composite actions will be created as local actions within the repository (not published separately)
- Composite action files will follow GitHub Actions composite action specification
- The current inline logic in Test-ModuleLocal.yml is correct and complete
- No changes to the behavior of BeforeAll/AfterAll script execution are desired, only encapsulation

### Success Criteria
- Test-ModuleLocal workflow is cleaner with reduced duplication
- BeforeAll and AfterAll logic can be tested and maintained independently
- All existing tests continue to pass with identical behavior
- Workflow execution time remains the same or improves
- Other workflows can reuse these composite actions if needed in the future
