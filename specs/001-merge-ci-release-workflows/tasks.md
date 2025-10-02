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

## Phase 3.3: Core Implementation (ONLY after tests are failing)

- [ ] T010 Add conditional execution logic to Publish-Module job in .github/workflows/workflow.yml
- [ ] T011 Add conditional execution logic to Publish-Site job in .github/workflows/workflow.yml
- [ ] T012 Update workflow triggers in .github/workflows/workflow.yml to handle all events
- [ ] T013 Update workflow permissions in .github/workflows/workflow.yml for both modes
- [ ] T014 Add workflow comments documenting CI-Only vs CI+Release execution paths in .github/workflows/workflow.yml
- [ ] T015 Verify all job dependencies correctly chain CI before Release jobs in .github/workflows/workflow.yml

## Phase 3.4: Integration

- [ ] T016 Add deprecation warning to .github/workflows/CI.yml with migration instructions
- [ ] T017 [P] Remove .github/workflows/Publish-Module.yml (logic now in workflow.yml)
- [ ] T018 [P] Remove .github/workflows/Publish-Site.yml (logic now in workflow.yml)
- [ ] T019 [P] Mark .github/workflows/Workflow-Test-Default-CI.yml as deprecated
- [ ] T020 [P] Mark .github/workflows/Workflow-Test-WithManifest-CI.yml as deprecated
- [ ] T021 Update workflow version references from v4 to v5 in test workflows

## Phase 3.5: Polish

- [ ] T022 [P] Create migration guide docs/migration/v5-unified-workflow.md with all three scenarios
- [ ] T023 [P] Update README.md with unified workflow documentation and breaking change notice
- [ ] T024 [P] Update .github/copilot-instructions.md with unified workflow as active technology
- [ ] T025 [P] Create manual test checklist docs/migration/manual-testing.md for consuming repositories
- [ ] T026 Run manual validation of all three migration scenarios from quickstart.md
- [ ] T027 Verify workflow execution time has no regression compared to separate workflows
- [ ] T028 [P] Add CHANGELOG.md entry for v5.0.0 breaking change

## Dependencies

### Phase Dependencies
- Setup (T001-T003) before all other phases
- Tests (T004-T009) before Core implementation (T010-T015)
- Core (T010-T015) before Integration (T016-T021)
- Integration (T016-T021) before Polish (T022-T028)

### Specific Task Dependencies
- T004, T005, T006 must fail before T010, T011 implemented
- T007, T008 depend on T004, T005, T006 being written
- T010 blocks T016, T017, T018 (workflow.yml must have publish logic before removing separate files)
- T015 depends on T010, T011, T012, T013, T014 (all workflow changes complete)
- T021 depends on T010-T015 (v5 workflow ready)
- T022 depends on T016-T021 (migration scenarios finalized)
- T026 depends on T022 (migration guide complete)

## Parallel Execution Examples

### Phase 3.2: Tests (All Parallel)
```plaintext
# Launch all test creation tasks together:
Task: "Create test workflow for CI-only mode (unmerged PR) in .github/workflows/Test-Workflow-CI-Only.yml"
Task: "Create test workflow for CI+Release mode (merged PR) in .github/workflows/Test-Workflow-Release.yml"
Task: "Create test workflow for manual trigger behavior in .github/workflows/Test-Workflow-Manual.yml"
Task: "Update .github/workflows/Workflow-Test-Default.yml to test unified workflow"
Task: "Update .github/workflows/Workflow-Test-WithManifest.yml to test unified workflow"
```

### Phase 3.4: Integration (File Removals/Deprecations Parallel)
```plaintext
# Launch deprecation tasks together (different files):
Task: "Remove .github/workflows/Publish-Module.yml (logic now in workflow.yml)"
Task: "Remove .github/workflows/Publish-Site.yml (logic now in workflow.yml)"
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
- Avoid: modifying workflow.yml in multiple parallel tasks (sequential T010-T015)

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
   - Setup → Tests → Core (workflow.yml mods) → Integration (file removals) → Polish (docs)
   - All tests before implementation (strict TDD)
   - Sequential tasks within workflow.yml (T010-T015)
   - Parallel tasks for different files (tests, docs, deprecations)

## Validation Checklist

*GATE: Checked by main() before returning*

- [x] All contracts have corresponding tests (workflow-api.md → T004-T008)
- [x] All entities have tasks (TriggerContext → T010, JobExecutionPlan → T015)
- [x] All tests come before implementation (T004-T009 before T010-T015)
- [x] Parallel tasks truly independent (different files: [P] marked correctly)
- [x] Each task specifies exact file path (all tasks include file paths)
- [x] No task modifies same file as another [P] task (workflow.yml tasks sequential T010-T015)
- [x] Migration scenarios covered (T022 creates migration guide, T026 validates)
- [x] Breaking change documented (T023 README, T024 copilot-instructions, T028 CHANGELOG)
- [x] Both execution modes tested (T004 CI-only, T005 CI+Release)
- [x] Backward compatibility maintained (workflow API unchanged per contracts/)
