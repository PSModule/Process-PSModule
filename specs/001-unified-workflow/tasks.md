# Tasks: Unified CI/CD Workflow

**Input**: Design documents from `/specs/001-unified-workflow/`
**Prerequisites**: plan.md (required), research.md, data-model.md, contracts/

## Execution Flow (main)

1. Load plan.md from feature directory
   → If not found: ERROR "No implementation plan found"
   → Extract: tech stack, libraries, structure
2. Load optional design documents:
   → data-model.md: Extract entities → model tasks
   → contracts/: Each file → contract test task
   → research.md: Extract decisions → setup tasks
3. Generate tasks by category:
   → Setup: project init, dependencies, linting
   → Tests: contract tests, integration tests
   → Core: models, services, CLI commands
   → Integration: DB, middleware, logging
   → Polish: unit tests, performance, docs
4. Apply task rules:
   → Different files = mark [P] for parallel
   → Same file = sequential (no [P])
   → Tests before implementation (TDD)
5. Number tasks sequentially (T001, T002...)
6. Generate dependency graph
7. Create parallel execution examples
8. Validate task completeness:
   → All contracts have tests?
   → All entities have models?
   → All endpoints implemented?
9. Return: SUCCESS (tasks ready for execution)

## Format: `[ID] [P?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- Include exact file paths in descriptions

## Path Conventions

- **Single project**: `.github/workflows/` at repository root
- Paths shown below assume single project structure

## Phase 3.1: Setup

- [X] T001: Create backup of existing `.github/workflows/CI.yml` and `.github/workflows/workflow.yml` for reference
      - After completing this task, update the PR description to mark this task as complete by changing `- [ ] T001:` to `- [X] T001:` in the Implementation Tasks section
- [X] T002: [P] Document the unified workflow structure in `docs/unified-workflow-migration.md` with migration guide for consuming repositories
      - After completing this task, update the PR description to mark this task as complete by changing `- [ ] T002:` to `- [X] T002:` in the Implementation Tasks section
- [X] T003: [P] Create test plan document in `specs/001-unified-workflow/test-plan.md` based on quickstart.md scenarios
      - After completing this task, update the PR description to mark this task as complete by changing `- [ ] T003:` to `- [X] T003:` in the Implementation Tasks section

## Phase 3.2: Tests First (TDD) ⚠️ MUST COMPLETE BEFORE 3.3

**CRITICAL: These tests MUST be written and MUST FAIL before ANY implementation**

- [X] T004: [P] Contract test for unified workflow trigger configuration in `tests/workflows/test-unified-workflow-triggers.Tests.ps1`
      - Verify workflow_call trigger exists
      - Verify required secrets are defined (APIKey, TEST_* secrets)
      - Verify required inputs are defined (Name, SettingsPath, Debug, Verbose, etc.)
      - Test should FAIL initially (workflow.yml not yet updated)
      - After completing this task, update the PR description to mark this task as complete by changing `- [ ] T004:` to `- [X] T004:` in the Implementation Tasks section

- [X] T005: [P] Contract test for concurrency group configuration in `tests/workflows/test-concurrency-group.Tests.ps1`
      - Verify concurrency group format: `${{ github.workflow }}-${{ github.ref }}`
      - Verify cancel-in-progress logic for PR vs main branch
      - Test should FAIL initially (concurrency not yet configured)
      - After completing this task, update the PR description to mark this task as complete by changing `- [ ] T005:` to `- [X] T005:` in the Implementation Tasks section

- [X] T006: [P] Contract test for job execution order in `tests/workflows/test-job-dependencies.Tests.ps1`
      - Verify Get-Settings has no dependencies
      - Verify Build-Module depends on Get-Settings
      - Verify Build-Docs depends on Get-Settings and Build-Module
      - Verify Build-Site depends on Get-Settings and Build-Docs
      - Verify Test-SourceCode and Lint-SourceCode depend on Get-Settings
      - Verify Test-Module depends on Get-Settings and Build-Module
      - Verify Test-ModuleLocal depends on Get-Settings, Build-Module, and BeforeAll-ModuleLocal
      - Verify Get-TestResults depends on all test jobs
      - Verify Get-CodeCoverage depends on Get-TestResults
      - Verify Publish-Module depends on Build-Module and Get-TestResults
      - Verify Publish-Site depends on Build-Site and Get-TestResults
      - Test should FAIL initially (dependencies not yet configured)
      - After completing this task, update the PR description to mark this task as complete by changing `- [ ] T006:` to `- [X] T006:` in the Implementation Tasks section

- [X] T007: [P] Contract test for conditional publishing logic in `tests/workflows/test-publish-conditions.Tests.ps1`
      - Verify Publish-Module condition: `github.event_name == 'pull_request' AND github.event.pull_request.merged == true`
      - Verify Publish-Site condition: `github.event_name == 'pull_request' AND github.event.pull_request.merged == true`
      - Verify Settings.Publish.*.Skip flags are respected
      - Test should FAIL initially (publish conditions not yet configured)
      - After completing this task, update the PR description to mark this task as complete by changing `- [ ] T007:` to `- [X] T007:` in the Implementation Tasks section

- [X] T008: [P] Integration test for PR-only execution scenario in `tests/integration/test-pr-execution.Tests.ps1`
      - Test scenario 1 from quickstart.md: PR opens → tests execute, publishing skipped
      - Verify all test jobs execute
      - Verify Publish-Module and Publish-Site are skipped
      - Test should FAIL initially (workflow not yet unified)
      - After completing this task, update the PR description to mark this task as complete by changing `- [ ] T008:` to `- [X] T008:` in the Implementation Tasks section

- [X] T009: [P] Integration test for PR update scenario in `tests/integration/test-pr-update.Tests.ps1`
      - Test scenario 2 from quickstart.md: PR updated → tests re-execute, previous run cancelled
      - Verify concurrency group cancels previous run
      - Verify all test jobs execute again
      - Verify publishing remains skipped
      - Test should FAIL initially (concurrency not yet configured)
      - After completing this task, update the PR description to mark this task as complete by changing `- [ ] T009:` to `- [X] T009:` in the Implementation Tasks section

- [X] T010: [P] Integration test for PR merge scenario in `tests/integration/test-pr-merge.Tests.ps1`
      - Test scenario 3 from quickstart.md: PR merged → tests execute, publishing executes
      - Verify all test jobs execute
      - Verify Publish-Module and Publish-Site execute when tests pass
      - Verify publishing is skipped when tests fail
      - Test should FAIL initially (publish conditions not yet configured)
      - After completing this task, update the PR description to mark this task as complete by changing `- [ ] T010:` to `- [X] T010:` in the Implementation Tasks section

- [X] T011: [P] Integration test for test failure scenario in `tests/integration/test-failure-handling.Tests.ps1`
      - Test scenario 4 from quickstart.md: Test failure on PR → workflow fails, publishing skipped
      - Verify workflow fails when tests fail
      - Verify Publish-Module and Publish-Site are skipped
      - Test should FAIL initially (workflow not yet unified)
      - After completing this task, update the PR description to mark this task as complete by changing `- [ ] T011:` to `- [X] T011:` in the Implementation Tasks section

## Phase 3.3: Core Implementation (ONLY after tests are failing)

- [X] T012: Add concurrency group configuration to `.github/workflows/workflow.yml`
      - Add concurrency group: `${{ github.workflow }}-${{ github.ref }}`
      - Add cancel-in-progress logic: `${{ github.ref != format('refs/heads/{0}', github.event.repository.default_branch) }}`
      - Verify T005 (concurrency test) now passes
      - After completing this task, update the PR description to mark this task as complete by changing `- [ ] T012:` to `- [X] T012:` in the Implementation Tasks section

- [X] T013: Add conditional publishing logic to Publish-Module job in `.github/workflows/workflow.yml`
      - Add condition: `github.event_name == 'pull_request' && github.event.pull_request.merged == true`
      - Preserve existing Settings.Publish.Module.Skip condition
      - Preserve dependency on Build-Module and Get-TestResults
      - Verify T007 (publish conditions test) now passes for Publish-Module
      - After completing this task, update the PR description to mark this task as complete by changing `- [ ] T013:` to `- [X] T013:` in the Implementation Tasks section

- [X] T014: Add conditional publishing logic to Publish-Site job in `.github/workflows/workflow.yml`
      - Add condition: `github.event_name == 'pull_request' && github.event.pull_request.merged == true`
      - Preserve existing Settings.Publish.Site.Skip condition
      - Preserve dependency on Build-Site and Get-TestResults
      - Verify T007 (publish conditions test) now passes for Publish-Site
      - After completing this task, update the PR description to mark this task as complete by changing `- [ ] T014:` to `- [X] T014:` in the Implementation Tasks section

- [X] T015: Verify all job dependencies match the contract in `.github/workflows/workflow.yml`
      - Verify Get-Settings has no dependencies
      - Verify all jobs have correct needs configuration per workflow-contract.md
      - Verify conditional skips are preserved (Settings.Build.*.Skip, Settings.Test.*.Skip)
      - Verify T006 (job dependencies test) now passes
      - After completing this task, update the PR description to mark this task as complete by changing `- [ ] T015:` to `- [X] T015:` in the Implementation Tasks section

- [X] T016: Validate unified workflow YAML syntax
      - Run `yamllint .github/workflows/workflow.yml` (or equivalent)
      - Verify no syntax errors
      - Verify GitHub Actions workflow schema compliance
      - After completing this task, update the PR description to mark this task as complete by changing `- [ ] T016:` to `- [X] T016:` in the Implementation Tasks section

## Phase 3.4: Integration

- [X] T017: Run contract tests (T004-T007) to verify implementation correctness
      - Execute all contract tests
      - Verify all tests pass
      - Fix any issues found
      - After completing this task, update the PR description to mark this task as complete by changing `- [ ] T017:` to `- [X] T017:` in the Implementation Tasks section

- [X] T018: Run integration tests (T008-T011) to verify scenario correctness
      - Execute all integration tests
      - Verify all tests pass
      - Fix any issues found
      - After completing this task, update the PR description to mark this task as complete by changing `- [ ] T018:` to `- [X] T018:` in the Implementation Tasks section

- [ ] T019: Execute manual test scenario 1: PR opens → tests execute, publishing skipped
      - Follow steps in `specs/001-unified-workflow/quickstart.md` scenario 1
      - Create test branch and PR
      - Verify workflow executes tests
      - Verify publishing is skipped
      - Document results
      - After completing this task, update the PR description to mark this task as complete by changing `- [ ] T019:` to `- [X] T019:` in the Implementation Tasks section

- [ ] T020: Execute manual test scenario 2: PR updated → tests re-execute, previous run cancelled
      - Follow steps in `specs/001-unified-workflow/quickstart.md` scenario 2
      - Push additional commit to test PR
      - Verify previous run is cancelled
      - Verify new run executes tests
      - Document results
      - After completing this task, update the PR description to mark this task as complete by changing `- [ ] T020:` to `- [X] T020:` in the Implementation Tasks section

- [ ] T021: Execute manual test scenario 3: PR merged → tests execute, publishing executes
      - Follow steps in `specs/001-unified-workflow/quickstart.md` scenario 3
      - Merge test PR
      - Verify tests execute
      - Verify publishing executes (if tests pass)
      - Document results
      - After completing this task, update the PR description to mark this task as complete by changing `- [ ] T021:` to `- [X] T021:` in the Implementation Tasks section

- [ ] T022: Execute manual test scenario 4: Test failure → workflow fails, publishing skipped
      - Follow steps in `specs/001-unified-workflow/quickstart.md` scenario 4
      - Create PR with test failure
      - Verify workflow fails
      - Verify publishing is skipped
      - Document results
      - After completing this task, update the PR description to mark this task as complete by changing `- [ ] T022:` to `- [X] T022:` in the Implementation Tasks section

## Phase 3.5: Polish

- [X] T023: [P] Delete `.github/workflows/CI.yml`
      - Remove CI.yml file
      - Verify unified workflow.yml contains all CI.yml functionality
      - After completing this task, update the PR description to mark this task as complete by changing `- [ ] T023:` to `- [X] T023:` in the Implementation Tasks section

- [X] T024: [P] Update `README.md` with breaking change notice and migration instructions
      - Document CI.yml deletion as breaking change
      - Link to migration guide
      - Update workflow status badge references if needed
      - After completing this task, update the PR description to mark this task as complete by changing `- [ ] T024:` to `- [X] T024:` in the Implementation Tasks section

- [X] T025: [P] Update `.github/copilot-instructions.md` with unified workflow context
      - Run `.specify/scripts/powershell/update-agent-context.ps1 -AgentType copilot` to update agent context
      - Verify new workflow information is added
      - Preserve manual additions between markers
      - After completing this task, update the PR description to mark this task as complete by changing `- [ ] T025:` to `- [X] T025:` in the Implementation Tasks section

- [X] T026: [P] Create release notes in `docs/release-notes/unified-workflow.md`
      - Document feature summary
      - List breaking changes
      - Provide migration checklist
      - Include quickstart validation steps
      - After completing this task, update the PR description to mark this task as complete by changing `- [ ] T026:` to `- [X] T026:` in the Implementation Tasks section

- [X] T027: Run PSScriptAnalyzer on test files to ensure code quality
      - Run linting on all new test files
      - Fix any issues found
      - Verify all tests follow best practices
      - After completing this task, update the PR description to mark this task as complete by changing `- [ ] T027:` to `- [X] T027:` in the Implementation Tasks section

- [ ] T028: Final validation using all quickstart.md scenarios
      - Execute all scenarios from `specs/001-unified-workflow/quickstart.md`
      - Verify all scenarios pass
      - Document any issues found
      - Ensure performance goal met (workflow execution under 10 minutes)
      - After completing this task, update the PR description to mark this task as complete by changing `- [ ] T028:` to `- [X] T028:` in the Implementation Tasks section

## Dependencies

```plaintext
Setup Phase (T001-T003):
  T001 → T002, T003 (parallel after backup)

Tests Phase (T004-T011):
  All tests are parallel (different files, no dependencies)
  ALL tests must be complete before implementation (T012-T016)

Core Implementation Phase (T012-T016):
  T012 → T013, T014 (concurrency config before publish logic)
  T013 → T015 (Publish-Module before job verification)
  T014 → T015 (Publish-Site before job verification)
  T015 → T016 (dependencies before YAML validation)

Integration Phase (T017-T022):
  T016 → T017 (YAML validation before contract tests)
  T017 → T018 (contract tests before integration tests)
  T018 → T019 (integration tests before manual scenarios)
  T019 → T020 → T021 → T022 (manual scenarios sequential)

Polish Phase (T023-T028):
  T022 → T023, T024, T025, T026 (manual tests before cleanup)
  T023, T024, T025, T026 → T027 (all docs before linting)
  T027 → T028 (linting before final validation)
```

## Parallel Execution Examples

### Setup Phase
```plaintext
# After T001 completes, launch T002 and T003 together:
Task: "Document unified workflow structure in docs/unified-workflow-migration.md"
Task: "Create test plan in specs/001-unified-workflow/test-plan.md"
```

### Tests Phase
```plaintext
# Launch all test tasks together (T004-T011):
Task: "Contract test for triggers in tests/workflows/test-unified-workflow-triggers.Tests.ps1"
Task: "Contract test for concurrency in tests/workflows/test-concurrency-group.Tests.ps1"
Task: "Contract test for job dependencies in tests/workflows/test-job-dependencies.Tests.ps1"
Task: "Contract test for publish conditions in tests/workflows/test-publish-conditions.Tests.ps1"
Task: "Integration test for PR execution in tests/integration/test-pr-execution.Tests.ps1"
Task: "Integration test for PR update in tests/integration/test-pr-update.Tests.ps1"
Task: "Integration test for PR merge in tests/integration/test-pr-merge.Tests.ps1"
Task: "Integration test for failure handling in tests/integration/test-failure-handling.Tests.ps1"
```

### Polish Phase
```plaintext
# After T022 completes, launch T023-T026 together:
Task: "Delete .github/workflows/CI.yml"
Task: "Update README.md with breaking change notice"
Task: "Update .github/copilot-instructions.md with workflow context"
Task: "Create release notes in docs/release-notes/unified-workflow.md"
```

## Notes

- **[P] tasks**: Different files, no dependencies - can run in parallel
- **TDD critical**: All tests (T004-T011) MUST fail before implementation begins
- **Breaking change**: CI.yml deletion requires consumer repository updates
- **Commit strategy**: Commit after each phase completion
- **Performance target**: Workflow execution should complete in under 10 minutes
- **Validation**: All quickstart.md scenarios must pass before considering feature complete

## Task Generation Rules

*Applied during main() execution*

1. **From Contracts**:
   - workflow-contract.md → 4 contract test tasks (T004-T007) [P]
   - Each job definition → job dependency verification (T006)
   - Each conditional → conditional logic test (T007)

2. **From Data Model**:
   - Workflow Configuration entity → trigger test (T004)
   - GitHub Event Context entity → conditional logic tests (T007, T013, T014)
   - Concurrency Group entity → concurrency test (T005, T012)
   - Job Definition entity → job dependency test (T006, T015)

3. **From Quickstart Scenarios**:
   - Scenario 1 (PR opens) → integration test T008, manual test T019
   - Scenario 2 (PR updates) → integration test T009, manual test T020
   - Scenario 3 (PR merged) → integration test T010, manual test T021
   - Scenario 4 (Test failure) → integration test T011, manual test T022

4. **From Research**:
   - Conditional execution pattern → T007, T013, T014
   - Concurrency control strategy → T005, T012
   - Migration path → T002, T024, T026

5. **Ordering**:
   - Setup (T001-T003) → Tests (T004-T011) → Implementation (T012-T016) → Integration (T017-T022) → Polish (T023-T028)
   - Tests MUST fail before implementation
   - Manual scenarios follow automated tests
   - Documentation and cleanup parallel when possible

## Validation Checklist

*GATE: Checked by main() before returning*

- [x] All contracts have corresponding tests (workflow-contract.md → T004-T007)
- [x] All entities have model tasks (Workflow Config → T004, T012-T016)
- [x] All tests come before implementation (T004-T011 before T012-T016)
- [x] Parallel tasks truly independent (different files, verified)
- [x] Each task specifies exact file path (all tasks have paths)
- [x] No task modifies same file as another [P] task (verified)
- [x] All quickstart scenarios covered (scenarios 1-4 → T008-T011, T019-T022)
- [x] Breaking change documented (T002, T023, T024, T026)
- [x] Performance goal included (T028)
