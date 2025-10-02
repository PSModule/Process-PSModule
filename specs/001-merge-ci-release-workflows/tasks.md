# Tasks: Unified CI and Release Workflow

**Input**: Design documents from `/specs/001-merge-ci-release-workflows/`
**Prerequisites**: plan.md (required), research.md, data-model.md, contracts/

## Execution Flow (main)

1. Load plan.md from feature directory
   → Extract: GitHub Actions YAML, PowerShell 7.4+, reusable workflow structure
2. Load optional design documents:
   → data-model.md: Extract TriggerContext, JobExecutionPlan entities
   → contracts/workflow-api.md: Extract workflow inputs, secrets, conditional logic
   → research.md: Extract decisions on conditional execution, authentication
   → quickstart.md: Extract migration scenarios
3. Generate tasks by category:
   → Setup: Repository structure validation, deprecation notices
   → Tests: Workflow validation tests for CI-only and CI+Release modes
   → Core: Conditional job execution logic in workflow.yml
   → Integration: Deprecation of CI.yml, removal of separate publish workflows
   → Polish: Documentation updates, migration guide validation
4. Apply task rules:
   → Different workflow files = mark [P] for parallel
   → Same workflow file = sequential (no [P])
   → Tests before implementation (TDD)
5. Number tasks sequentially (T001, T002...)
6. Generate dependency graph
7. Create parallel execution examples
8. Validate task completeness:
   → Workflow API contract validated?
   → Both execution modes tested?
   → Migration paths documented?
9. Return: SUCCESS (tasks ready for execution)

## Format: `[ID] [P?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- Include exact file paths in descriptions

## Path Conventions

This is a GitHub Actions workflow project at repository root:
- `.github/workflows/` - Workflow YAML files
- `docs/migration/` - Migration guides
- `README.md` - Project documentation

## Phase 3.1: Setup

- [ ] T001 Validate current workflow structure in .github/workflows/
- [ ] T002 Create migration documentation directory docs/migration/
- [ ] T003 Add deprecation notice to .github/workflows/CI.yml header

## Phase 3.2: Tests First (TDD) ⚠️ MUST COMPLETE BEFORE 3.3

**CRITICAL: These tests MUST be written and MUST FAIL before ANY implementation**

- [ ] T004 [P] Create test workflow for CI-only mode (unmerged PR) in .github/workflows/Test-Workflow-CI-Only.yml
- [ ] T005 [P] Create test workflow for CI+Release mode (merged PR) in .github/workflows/Test-Workflow-Release.yml
- [ ] T006 [P] Create test workflow for manual trigger behavior in .github/workflows/Test-Workflow-Manual.yml
- [ ] T007 [P] Update .github/workflows/Workflow-Test-Default.yml to test unified workflow
- [ ] T008 [P] Update .github/workflows/Workflow-Test-WithManifest.yml to test unified workflow
- [ ] T009 Create validation script to verify conditional job execution in tests/Validate-ConditionalExecution.Tests.ps1
- [ ] T010 [P] Create test to validate PR status checks are reported correctly in .github/workflows/Test-Workflow-StatusChecks.yml

## Phase 3.3: Core Implementation (ONLY after tests are failing)

- [ ] T011 Add conditional execution logic to Publish-Module job in .github/workflows/workflow.yml
- [ ] T012 Add conditional execution logic to Publish-Site job in .github/workflows/workflow.yml
- [ ] T013 Update workflow triggers in .github/workflows/workflow.yml to handle all events
- [ ] T014 Update workflow permissions in .github/workflows/workflow.yml for both modes
- [ ] T015 Add workflow comments documenting CI-Only vs CI+Release execution paths in .github/workflows/workflow.yml
- [ ] T016 Verify job dependencies chain CI before Release jobs and validate fail-fast behavior when CI tests fail in .github/workflows/workflow.yml

## Phase 3.4: Integration

- [ ] T017 Add deprecation warning to .github/workflows/CI.yml with migration instructions
- [ ] T018 [P] Mark .github/workflows/Workflow-Test-Default-CI.yml as deprecated
- [ ] T019 [P] Mark .github/workflows/Workflow-Test-WithManifest-CI.yml as deprecated
- [ ] T020 Update workflow version references from v4 to v5 in test workflows

## Phase 3.5: Polish

- [ ] T022 [P] Create migration guide docs/migration/v5-unified-workflow.md with all three scenarios
- [ ] T023 [P] Update README.md with unified workflow documentation and breaking change notice
- [ ] T024 [P] Update .github/copilot-instructions.md with unified workflow as active technology
- [ ] T021 [P] Create manual test checklist docs/migration/manual-testing.md for consuming repositories
- [ ] T022 Run manual validation of all three migration scenarios from quickstart.md
- [ ] T023 Verify workflow execution time has no regression compared to separate workflows
- [ ] T024 [P] Add CHANGELOG.md entry for v5.0.0 breaking change

## Dependencies

### Phase Dependencies
- Setup (T001-T003) before all other phases
- Tests (T004-T010) before Core implementation (T011-T016)
- Core (T011-T016) before Integration (T017-T020)
- Integration (T017-T020) before Polish (T021-T024)

### Specific Task Dependencies
- T004, T005, T006 must fail before T011, T012 implemented
- T007, T008 depend on T004, T005, T006 being written
- T011 blocks T017 (workflow.yml must have conditional logic before adding deprecation warnings)
- T016 depends on T011, T012, T013, T014, T015 (all workflow changes complete)
- T020 depends on T011-T016 (v5 workflow ready)
- T022 depends on T017-T020 (migration scenarios finalized)

## Parallel Execution Examples

### Phase 3.2: Tests (All Parallel)
```plaintext
# Launch all test creation tasks together:
Task: "Create test workflow for CI-only mode (unmerged PR) in .github/workflows/Test-Workflow-CI-Only.yml"
Task: "Create test workflow for CI+Release mode (merged PR) in .github/workflows/Test-Workflow-Release.yml"
Task: "Create test workflow for manual trigger behavior in .github/workflows/Test-Workflow-Manual.yml"
Task: "Create test to validate PR status checks are reported correctly in .github/workflows/Test-Workflow-StatusChecks.yml"
Task: "Update .github/workflows/Workflow-Test-Default.yml to test unified workflow"
Task: "Update .github/workflows/Workflow-Test-WithManifest.yml to test unified workflow"
Task: "Create test scenario in tests/Workflow-FailFast.Tests.ps1 to validate PR check failures"
```

### Phase 3.4: Integration (Deprecations Parallel)
```plaintext
# Launch deprecation tasks together (different files):
Task: "Mark .github/workflows/Workflow-Test-Default-CI.yml as deprecated"
Task: "Mark .github/workflows/Workflow-Test-WithManifest-CI.yml as deprecated"
```

### Phase 3.5: Polish (Documentation Parallel)
```plaintext
# Launch documentation tasks together:
Task: "Create migration guide docs/migration/v5-unified-workflow.md with all three scenarios"
Task: "Update README.md with unified workflow documentation and breaking change notice"
Task: "Update .github/copilot-instructions.md with unified workflow as active technology"
Task: "Create manual test checklist docs/migration/manual-testing.md for consuming repositories"
Task: "Add CHANGELOG.md entry for v5.0.0 breaking change"
```

## Notes

- **[P] tasks** = different files, no dependencies, safe to run in parallel
- **Sequential tasks** (no [P]) = modify same file (.github/workflows/workflow.yml) and must run in order
- Verify all test workflows FAIL before implementing conditional logic (TDD Red phase)
- Commit after each task to enable rollback if needed
- Test workflow execution locally where possible using `act` or GitHub CLI
- Avoid: modifying workflow.yml in multiple parallel tasks (sequential T011-T016)

## Task Generation Rules

*Applied during main() execution*

1. **From Contracts** (workflow-api.md):
   - Workflow API contract → test workflow validation tasks [P]
   - Conditional execution logic → implementation tasks (sequential, same file)
   - Input/output compatibility → validation test tasks [P]

2. **From Data Model** (data-model.md):
   - TriggerContext entity → conditional logic implementation tasks
   - CI-Only execution mode → test workflow task
   - CI+Release execution mode → test workflow task
   - JobExecutionPlan → job dependency validation task

3. **From Research** (research.md):
   - Publishing target decision → Publish-Module job update task
   - Versioning strategy → version reference update tasks
   - Manual trigger behavior → manual trigger test task
   - Authentication → secrets validation task

4. **From Quickstart** (quickstart.md):
   - Migration Scenario 1 → documentation task
   - Migration Scenario 2 → documentation task
   - Migration Scenario 3 → documentation task
   - Manual testing steps → manual validation task

5. **Ordering**:
   - Setup → Tests → Core (workflow.yml mods) → Integration (deprecations) → Polish (docs)
   - All tests before implementation (strict TDD)
   - Sequential tasks within workflow.yml (T011-T016)
   - Parallel tasks for different files (tests, docs, deprecations)

## Validation Checklist

*GATE: Checked by main() before returning*

- [x] All contracts have corresponding tests (workflow-api.md → T004-T010)
- [x] All entities have tasks (TriggerContext → T011, JobExecutionPlan → T016)
- [x] All tests come before implementation (T004-T010 before T011-T016)
- [x] Parallel tasks truly independent (different files: [P] marked correctly)
- [x] Each task specifies exact file path (all tasks include file paths)
- [x] No task modifies same file as another [P] task (workflow.yml tasks sequential T011-T016)
- [x] Migration scenarios covered (T022 validates migration guide from quickstart.md)
- [x] Breaking change documented (T019 README via quickstart.md, T020 copilot-instructions, T024 CHANGELOG)
- [x] Both execution modes tested (T004 CI-only, T005 CI+Release)
- [x] Backward compatibility maintained (workflow API unchanged per contracts/)
- [x] PR status checks validated (T010 tests FR-006)
- [x] Fail-fast behavior validated (T016 includes FR-007 validation)
