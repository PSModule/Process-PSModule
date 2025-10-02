# Test Plan: Unified CI/CD Workflow

**Feature**: 001-unified-workflow
**Date**: 2025-10-02
**Status**: In Progress

## Test Strategy

This test plan follows a Test-Driven Development (TDD) approach with three phases:

1. **Contract Tests** (T004-T007): Verify workflow structure and configuration
2. **Integration Tests** (T008-T011): Verify end-to-end workflow behavior
3. **Manual Tests** (T019-T022): Validate real-world scenarios from quickstart.md

## Test Phases

### Phase 1: Contract Tests (Automated)

**Objective**: Verify the unified workflow YAML structure matches the contract specification

| Test ID | Test Name | File | Status |
|---------|-----------|------|--------|
| T004 | Workflow Trigger Configuration | `tests/workflows/test-unified-workflow-triggers.Tests.ps1` | ⏳ Pending |
| T005 | Concurrency Group Configuration | `tests/workflows/test-concurrency-group.Tests.ps1` | ⏳ Pending |
| T006 | Job Execution Order | `tests/workflows/test-job-dependencies.Tests.ps1` | ⏳ Pending |
| T007 | Conditional Publishing Logic | `tests/workflows/test-publish-conditions.Tests.ps1` | ⏳ Pending |

**Expected Outcome**: All contract tests FAIL initially (Red phase), then PASS after implementation (Green phase)

### Phase 2: Integration Tests (Automated)

**Objective**: Verify workflow behavior in different GitHub event contexts

| Test ID | Test Name | File | Status |
|---------|-----------|------|--------|
| T008 | PR-Only Execution | `tests/integration/test-pr-execution.Tests.ps1` | ⏳ Pending |
| T009 | PR Update with Cancellation | `tests/integration/test-pr-update.Tests.ps1` | ⏳ Pending |
| T010 | PR Merge with Publishing | `tests/integration/test-pr-merge.Tests.ps1` | ⏳ Pending |
| T011 | Test Failure Handling | `tests/integration/test-failure-handling.Tests.ps1` | ⏳ Pending |

**Expected Outcome**: All integration tests FAIL initially, then PASS after implementation

### Phase 3: Manual Tests (Real Workflow Execution)

**Objective**: Validate complete workflow behavior in actual GitHub Actions environment

Based on `specs/001-unified-workflow/quickstart.md` scenarios:

| Test ID | Scenario | Reference | Status |
|---------|----------|-----------|--------|
| T019 | PR Opens → Tests Run, Publishing Skipped | Quickstart Scenario 1 | ⏳ Pending |
| T020 | PR Updated → Tests Re-Run, Previous Cancelled | Quickstart Scenario 2 | ⏳ Pending |
| T021 | PR Merged → Tests Run, Publishing Executes | Quickstart Scenario 3 | ⏳ Pending |
| T022 | Test Failure → Workflow Fails, No Publishing | Quickstart Scenario 4 | ⏳ Pending |

**Additional Manual Scenarios** (from quickstart.md, not in tasks.md):

| Scenario | Reference | Priority |
|----------|-----------|----------|
| Test Failure After Merge | Quickstart Scenario 5 | Medium |
| Concurrency Control Verification | Quickstart Scenario 6 | Medium |
| Manual Re-Run After Publish Failure | Quickstart Scenario 7 | Low |

**Expected Outcome**: All manual tests demonstrate expected workflow behavior

## Test Environment

### Prerequisites

- GitHub Actions environment
- Access to Process-PSModule repository
- Permissions to create branches and PRs
- GitHub CLI (`gh`) installed (for manual tests)

### Test Data

- **Test Branches**: `test/unified-workflow-*`
- **Test PRs**: Draft PRs for validation
- **Test Modules**: `tests/srcTestRepo`, `tests/srcWithManifestTestRepo`

## Success Criteria

### Contract Tests
- ✅ All contract tests pass (T004-T007)
- ✅ Tests verify workflow.yml structure matches contracts/workflow-contract.md
- ✅ Tests fail before implementation (TDD Red phase verified)

### Integration Tests
- ✅ All integration tests pass (T008-T011)
- ✅ Tests verify workflow behavior in different GitHub event contexts
- ✅ Tests fail before implementation (TDD Red phase verified)

### Manual Tests
- ✅ PR-only execution works correctly (tests run, no publishing)
- ✅ Concurrency cancellation works (old runs cancelled on new commits)
- ✅ Merge triggers publishing when tests pass
- ✅ Test failures prevent publishing

### Performance
- ✅ Workflow completes within 10 minutes for typical module (NFR-001)
- ✅ No regression in execution time compared to separate workflows

### Compatibility
- ✅ All existing job configurations preserved
- ✅ All existing secrets work without changes
- ✅ Cross-platform testing continues to work (ubuntu, windows, macos)

## Test Execution Schedule

### Phase 1: Setup (T001-T003)
- **Duration**: 1 hour
- **Tasks**: Backup files, create documentation, create test plan
- **Validation**: Documentation complete, backups created

### Phase 2: Contract Tests (T004-T007)
- **Duration**: 2-3 hours
- **Tasks**: Write contract tests that verify workflow structure
- **Validation**: All tests run and FAIL (Red phase)

### Phase 3: Implementation (T012-T016)
- **Duration**: 2-3 hours
- **Tasks**: Implement unified workflow changes
- **Validation**: Contract tests now PASS (Green phase)

### Phase 4: Integration Tests (T008-T011)
- **Duration**: 2-3 hours
- **Tasks**: Write integration tests for workflow behavior
- **Validation**: Integration tests PASS

### Phase 5: Validation (T017-T022)
- **Duration**: 3-4 hours
- **Tasks**: Run automated tests + manual scenarios
- **Validation**: All tests pass, manual scenarios successful

### Phase 6: Polish (T023-T028)
- **Duration**: 2-3 hours
- **Tasks**: Delete CI.yml, update docs, final validation
- **Validation**: Breaking change complete, migration guide available

**Total Estimated Duration**: 12-17 hours

## Risk Assessment

### High Risk
- **Breaking change impact**: CI.yml deletion affects all consuming repositories
  - **Mitigation**: Comprehensive migration guide, clear communication, draft PR
- **Production workflow modification**: Changes affect live repositories
  - **Mitigation**: Keep PR in draft, test thoroughly before merge

### Medium Risk
- **Test coverage gaps**: Manual scenarios 5-7 not fully automated
  - **Mitigation**: Document manual test procedures in quickstart.md
- **Cross-platform compatibility**: Workflow changes might behave differently on different runners
  - **Mitigation**: Test on ubuntu, windows, macos (though workflow runs on GitHub infrastructure)

### Low Risk
- **Configuration preservation**: Secrets and settings might not work
  - **Mitigation**: Contract tests verify all configurations preserved
- **Performance regression**: Unified workflow might be slower
  - **Mitigation**: Performance validation in T028

## Test Reporting

### Automated Test Reports
- **Format**: Pester NUnit XML + JSON
- **Location**: GitHub Actions artifacts
- **Coverage**: PSScriptAnalyzer + Pester coverage reports

### Manual Test Reports
- **Format**: Markdown checklist in quickstart.md
- **Documentation**: Results documented in PR comments
- **Evidence**: Workflow run URLs and screenshots

### Test Metrics
- **Contract Test Coverage**: 4 tests covering workflow structure
- **Integration Test Coverage**: 4 tests covering workflow behavior
- **Manual Test Coverage**: 4 core scenarios + 3 additional scenarios
- **Total Test Coverage**: 11 scenarios

## Test Maintenance

### Update Triggers
- Contract specification changes → Update contract tests
- Workflow behavior changes → Update integration tests
- New scenarios identified → Add to quickstart.md

### Test Review Schedule
- **After implementation**: Full test suite review
- **After breaking changes**: Update all affected tests
- **Quarterly**: Review test coverage and effectiveness

## Dependencies

### External Dependencies
- GitHub Actions platform
- GitHub CLI (`gh`)
- PowerShell 7.4+
- Pester 5.x
- PSScriptAnalyzer

### Internal Dependencies
- `.github/workflows/workflow.yml` (target of changes)
- `.github/workflows/CI.yml` (to be deleted)
- `specs/001-unified-workflow/contracts/workflow-contract.md`
- `specs/001-unified-workflow/quickstart.md`

## Notes

- **TDD Approach**: Tests MUST fail initially to verify they're testing real conditions
- **Draft PR**: Keep PR in draft until all tests pass and migration guide is complete
- **Communication**: Breaking change requires clear communication to all repository maintainers
- **Rollback Plan**: Documented in migration guide for emergency rollback

## References

- [Specification](../spec.md)
- [Implementation Plan](../plan.md)
- [Contract Definition](../contracts/workflow-contract.md)
- [Quickstart Guide](../quickstart.md)
- [Migration Guide](../../docs/unified-workflow-migration.md)
