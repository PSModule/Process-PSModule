# Tasks: Local GitHub Composite Action for BeforeAll/AfterAll Test Scripts

**Input**: Design documents from `/specs/001-building-on-this/`
**Prerequisites**: plan.md, research.md, data-model.md, contracts/, quickstart.md

## Execution Flow (main)

1. Load plan.md from feature directory ✓
   → Tech stack: PowerShell 7.4+ (GitHub Actions composite actions)
   → Dependencies: PSModule/GitHub-Script@v1, PSModule/Install-PSModuleHelpers@v1
   → Structure: GitHub Actions workflow framework
2. Load optional design documents ✓
   → data-model.md: Setup-Test composite action entity, test script files
   → contracts/: action.yml.md, script-implementation.md, workflow-integration.md
   → research.md: Composite action patterns, error handling, mode-based behavior
   → quickstart.md: Integration and validation scenarios
3. Generate tasks by category:
   → Setup: Project structure, linting
   → Tests: Contract tests for action.yml, script logic, workflow integration
   → Core: Composite action implementation
   → Integration: Test-ModuleLocal.yml modification
   → Polish: Validation, documentation, cleanup
4. Apply task rules:
   → Different files = mark [P] for parallel
   → Same file = sequential (no [P])
   → Tests before implementation (TDD)
5. Number tasks sequentially (T001-T028)
6. Dependencies: Setup → Tests → Core → Integration → Polish

## Format: `[ID] [P?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- Include exact file paths in descriptions

## Path Conventions

- Repository root: `Process-PSModule/`
- Composite action: `.github/actions/setup-test/`
- Workflow: `.github/workflows/Test-ModuleLocal.yml`
- Tests: `tests/` (integration tests via workflow execution)
- Documentation: `specs/001-building-on-this/`

## Phase 3.1: Setup

- [ ] T001 Create composite action directory structure `.github/actions/setup-test/`
- [ ] T002 Create test repository structure for validation `tests/srcTestRepo/tests/`
- [ ] T003 [P] Configure YAML linting rules for composite action validation

## Phase 3.2: Tests First (TDD) ⚠️ MUST COMPLETE BEFORE 3.3

**CRITICAL: These tests MUST be written and MUST FAIL before ANY implementation**

### Contract Tests

- [ ] T004 [P] Contract test for action.yml structure in `tests/001-action-yml-structure.Tests.ps1`
  - Verify: name, description, inputs (mode, Debug, Verbose, Prerelease, Version, WorkingDirectory)
  - Verify: runs.using = 'composite'
  - Verify: steps include PSModule/Install-PSModuleHelpers@v1 and PSModule/GitHub-Script@v1
- [ ] T005 [P] Contract test for mode parameter validation in `tests/001-mode-validation.Tests.ps1`
  - Test: mode = "before" executes BeforeAll.ps1
  - Test: mode = "after" executes AfterAll.ps1
  - Test: invalid mode fails with error
- [ ] T006 [P] Contract test for BeforeAll error handling in `tests/001-beforeall-errors.Tests.ps1`
  - Test: missing tests directory exits successfully
  - Test: missing BeforeAll.ps1 exits successfully
  - Test: BeforeAll.ps1 failure causes job failure
  - Test: BeforeAll.ps1 success completes successfully
- [ ] T007 [P] Contract test for AfterAll error handling in `tests/001-afterall-errors.Tests.ps1`
  - Test: missing tests directory exits successfully
  - Test: missing AfterAll.ps1 exits successfully
  - Test: AfterAll.ps1 failure logs warning but completes successfully
  - Test: AfterAll.ps1 success completes successfully

### Integration Tests (via Test-ModuleLocal workflow execution)

- [ ] T008 [P] Create BeforeAll.ps1 test fixture in `tests/srcTestRepo/tests/BeforeAll.ps1`
  - Echo environment variable availability
  - Verify execution in tests directory
  - Test success case
- [ ] T009 [P] Create AfterAll.ps1 test fixture in `tests/srcTestRepo/tests/AfterAll.ps1`
  - Echo cleanup steps
  - Verify execution in tests directory
  - Test success case
- [ ] T010 [P] Create failing BeforeAll.ps1 fixture in `tests/srcTestRepo/tests/BeforeAll-Fail.ps1`
  - Throw error to test failure handling
- [ ] T011 [P] Create failing AfterAll.ps1 fixture in `tests/srcTestRepo/tests/AfterAll-Fail.ps1`
  - Throw error to test warning handling

## Phase 3.3: Core Implementation (ONLY after tests are failing)

### Composite Action Implementation

- [ ] T012 Create action.yml metadata in `.github/actions/setup-test/action.yml`
  - Define: name, description, author
  - Define: inputs (mode, Debug, Verbose, Prerelease, Version, WorkingDirectory)
  - Define: runs.using = 'composite'
- [ ] T013 Add Install-PSModuleHelpers step in `.github/actions/setup-test/action.yml`
  - Add step: uses PSModule/Install-PSModuleHelpers@v1
- [ ] T014 Implement mode-based configuration logic in `.github/actions/setup-test/action.yml` GitHub-Script
  - Validate mode parameter (before/after)
  - Set scriptName based on mode (BeforeAll.ps1 / AfterAll.ps1)
  - Set logGroupTitle based on mode
- [ ] T015 Implement tests directory discovery in `.github/actions/setup-test/action.yml` GitHub-Script
  - Use Resolve-Path with -ErrorAction SilentlyContinue
  - Exit successfully if tests directory not found
  - Log tests directory path if found
- [ ] T016 Implement script file discovery in `.github/actions/setup-test/action.yml` GitHub-Script
  - Use Join-Path for path construction
  - Use Test-Path with -PathType Leaf
  - Exit successfully if script not found
  - Log script path if found
- [ ] T017 Implement BeforeAll execution logic in `.github/actions/setup-test/action.yml` GitHub-Script
  - Push-Location to tests directory
  - Execute script with & operator
  - Catch errors and throw (fail job)
  - Pop-Location in finally block
- [ ] T018 Implement AfterAll execution logic in `.github/actions/setup-test/action.yml` GitHub-Script
  - Push-Location to tests directory
  - Execute script with & operator
  - Catch errors and log warning (don't throw)
  - Pop-Location in finally block
- [ ] T019 Add LogGroup wrapper for formatted output in `.github/actions/setup-test/action.yml` GitHub-Script
  - Wrap execution in LogGroup with appropriate title
  - Use PSModule/GitHub-Script@v1 LogGroup helper

## Phase 3.4: Integration

### Workflow Modification

- [ ] T020 Backup current Test-ModuleLocal.yml to `tests/Test-ModuleLocal.yml.backup`
  - Preserve original for comparison
- [ ] T021 Replace BeforeAll-ModuleLocal job in `.github/workflows/Test-ModuleLocal.yml`
  - Remove Install-PSModuleHelpers step (lines ~75-76)
  - Remove GitHub-Script step with inline script (lines ~77-158)
  - Add setup-test composite action call with mode: before
  - Pass all environment variables (secrets)
  - Pass all workflow inputs (Debug, Verbose, Prerelease, Version, WorkingDirectory)
- [ ] T022 Replace AfterAll-ModuleLocal job in `.github/workflows/Test-ModuleLocal.yml`
  - Remove Install-PSModuleHelpers step (lines ~231-232)
  - Remove GitHub-Script step with inline script (lines ~233-314)
  - Add setup-test composite action call with mode: after
  - Pass all environment variables (secrets)
  - Pass all workflow inputs (Debug, Verbose, Prerelease, Version, WorkingDirectory)
  - Maintain if: always() condition

## Phase 3.5: Polish

### Validation & Testing
- [ ] T023 [P] Run PSScriptAnalyzer on composite action YAML in `tests/001-lint-action.Tests.ps1`
  - Validate YAML structure
  - Check for best practices

- [ ] T024 [P] Execute quickstart validation steps from `specs/001-building-on-this/quickstart.md`
  - Verify composite action exists
  - Verify action.yml structure
  - Verify Test-ModuleLocal.yml integration
  - Create test repository with BeforeAll.ps1 and AfterAll.ps1
  - Trigger workflow and verify execution
- [ ] T025 [P] Create comprehensive BeforeAll/AfterAll usage documentation (FR-021)
  - Create new documentation file explaining intended use case
  - Document: BeforeAll/AfterAll are for external test resources (cloud infrastructure, external databases, third-party services via APIs)
  - Document: Test-specific resources for individual OS/platform combinations should be created within tests
  - Include DO examples: Azure/AWS deployment, external database initialization, SaaS test data creation
  - Include DON'T examples: OS-specific dependencies, platform-specific files, test-specific resources
  - Provide practical examples with Azure CLI and REST API calls
  - Document when to use BeforeAll/AfterAll vs. in-test setup:
- [ ] T027 [P] Update Process-PSModule and Template-PSModule documentation
  - Update Process-PSModule README with composite action documentation
  - Update Template-PSModule with example BeforeAll/AfterAll scripts showing external resource management
  - Document integration steps for consuming repositories
  - Create migration guide for nested script consolidation
- [ ] T028 Compare before/after behavior in `.github/workflows/Test-ModuleLocal.yml`
  - Verify line count reduction (~130 lines removed)
  - Verify identical behavior (no functional changes)
  - Verify all environment variables passed correctly
  - Verify FR-021 documentation is complete and clear
  - Remove backup file after validation

## Dependencies

### Sequential Dependencies

- T001, T002, T003 (Setup) → T004-T011 (Tests)
- T004-T011 (Tests) → T012 (Core Implementation Start)
- T012 → T013 → T014 → T015 → T016 → T017, T018 (same file, sequential)
- T017, T018 → T019 (same file, adds LogGroup wrapper)
- T019 (Core Complete) → T020, T021, T022 (Integration)
- T020 → T021, T022 (backup before modification)
- T021, T022 (Integration Complete) → T023, T024, T025, T027, T028 (Polish)

### Parallel Opportunities

- T004, T005, T006, T007 can run in parallel (different test files)
- T008, T009, T010, T011 can run in parallel (different fixture files)
- T023, T024, T025, T027 can run in parallel (different files/different documentation)
- T017 and T018 can be implemented in parallel (different logic branches in same file, but use branches to test independently)

## Parallel Execution Examples

### Contract Tests (after T003)

```powershell
# Launch T004-T007 together:
Task: "Contract test for action.yml structure in tests/001-action-yml-structure.Tests.ps1"
Task: "Contract test for mode parameter validation in tests/001-mode-validation.Tests.ps1"
Task: "Contract test for BeforeAll error handling in tests/001-beforeall-errors.Tests.ps1"
Task: "Contract test for AfterAll error handling in tests/001-afterall-errors.Tests.ps1"
```

### Integration Test Fixtures (after T007)

```powershell
# Launch T008-T011 together:
Task: "Create BeforeAll.ps1 test fixture in tests/srcTestRepo/tests/BeforeAll.ps1"
Task: "Create AfterAll.ps1 test fixture in tests/srcTestRepo/tests/AfterAll.ps1"
Task: "Create failing BeforeAll.ps1 fixture in tests/srcTestRepo/tests/BeforeAll-Fail.ps1"
Task: "Create failing AfterAll.ps1 fixture in tests/srcTestRepo/tests/AfterAll-Fail.ps1"
```

### Polish Tasks (after T022)

```powershell
# Launch T023-T025, T027 together:
Task: "Run PSScriptAnalyzer on composite action YAML in tests/001-lint-action.Tests.ps1"
Task: "Execute quickstart validation steps from specs/001-building-on-this/quickstart.md"
Task: "Create comprehensive BeforeAll/AfterAll usage documentation (FR-021)"
Task: "Update Process-PSModule and Template-PSModule documentation"
```

## Notes

- [P] tasks = different files, no dependencies
- Verify tests fail before implementing (TDD Red-Green-Refactor)
- Commit after each task for clear history
- T012-T019 modify same file sequentially (no parallel execution)
- T021 and T022 modify same file but different sections (can be done sequentially or carefully in parallel with different branches)
- Integration tests (T008-T011) are fixtures for manual workflow testing via Test-ModuleLocal.yml
- Actual test execution happens via GitHub Actions workflow run, not Pester

## Task Generation Rules Applied

1. **From Contracts**:
   - action.yml.md → T004 (contract test for action structure)
   - script-implementation.md → T005-T007 (contract tests for script logic)
   - workflow-integration.md → T021-T022 (workflow modification tasks)
2. **From Data Model**:
   - Setup-Test composite action entity → T012-T019 (action implementation)
   - BeforeAll.ps1/AfterAll.ps1 test scripts → T008-T011 (test fixtures)
3. **From Quickstart**:
   - Validation steps → T024 (quickstart execution)
   - Integration scenarios → T008-T011 (test fixtures for scenarios)
4. **Ordering Applied**:
   - Setup (T001-T003) → Tests (T004-T011) → Core (T012-T019) → Integration (T020-T022) → Polish (T023-T028)
   - Dependencies enforced via sequential task ordering

## Validation Checklist

*GATE: Checked before execution*

- [x] All contracts have corresponding tests (T004-T007)
- [x] All entities have implementation tasks (T012-T019 for composite action)
- [x] All tests come before implementation (T004-T011 before T012)
- [x] Parallel tasks truly independent (verified file paths)
- [x] Each task specifies exact file path (verified)
- [x] No task modifies same file as another [P] task (T012-T019 are sequential)
- [x] Integration tests defined (T008-T011 fixtures, T024 validation)
- [x] TDD approach enforced (tests T004-T011 before implementation T012-T019)
- [x] Constitution check requirements met (workflow-first, TDD, PowerShell 7.4+, quality gates)

## Execution Strategy

### Phase 1: Foundation (Manual Setup)

Execute T001-T003 to establish project structure and linting.

### Phase 2: TDD Red Phase (Write Failing Tests)

Execute T004-T011 in parallel groups:
- Contract tests: T004-T007 (parallel)
- Integration fixtures: T008-T011 (parallel)

Verify all tests fail appropriately (Red phase).

### Phase 3: TDD Green Phase (Make Tests Pass)

Execute T012-T019 sequentially (same file modifications):
- T012: Action metadata
- T013: Install helpers step
- T014-T016: Script discovery logic
- T017-T018: Execution logic
- T019: LogGroup wrapper

Verify tests pass after each task (Green phase).

### Phase 4: Integration (Workflow Modification)

Execute T020-T022 sequentially:
- T020: Backup original
- T021: Replace BeforeAll job
- T022: Replace AfterAll job

### Phase 5: Validation (Polish & Verify)

Execute T023-T025, T027 in parallel, then T028:

- T023-T025, T027: Linting, quickstart, FR-021 documentation, repository documentation (parallel)
- T028: Final comparison, FR-021 verification, and cleanup (sequential)

## Success Criteria

1. **Functional**: Test-ModuleLocal.yml workflow executes successfully with composite action
2. **Behavioral**: Identical behavior to original inline implementation
3. **Quality**: All contract tests pass, PSScriptAnalyzer clean
4. **Documentation**: README updated, quickstart validated
5. **Efficiency**: ~130 lines of code removed from Test-ModuleLocal.yml
6. **Reusability**: Composite action can be used in other workflows
