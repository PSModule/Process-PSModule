# Quickstart: Unified CI/CD Workflow

**Feature**: 001-unified-workflow
**Date**: 2025-10-02

## Overview

This quickstart guide validates the unified workflow behavior by testing key scenarios. Follow these steps to verify the unified workflow correctly handles PR testing and merge-triggered publishing.

## Prerequisites

- Access to the Process-PSModule repository or a consuming repository
- Git installed and configured
- GitHub CLI (`gh`) installed (optional but recommended)
- Permissions to create branches and PRs

## Test Scenario 1: PR Opens → Tests Execute, Publishing Skipped

**Objective**: Verify that opening a PR triggers tests but does not execute publishing jobs

**Steps**:

1. Create a test branch:
   ```bash
   git checkout -b test/unified-workflow-pr-test
   ```

2. Make a trivial change (e.g., add a comment to README):
   ```bash
   echo "# Test change for unified workflow" >> README.md
   git add README.md
   git commit -m "test: Validate unified workflow PR behavior"
   git push origin test/unified-workflow-pr-test
   ```

3. Open a PR:
   ```bash
   gh pr create --title "test: Unified workflow PR test" --body "Testing PR-only execution" --draft
   ```

4. Navigate to Actions tab and observe workflow execution

**Expected Results**:
- ✅ Workflow starts automatically
- ✅ Get-Settings job executes
- ✅ Build-Module job executes
- ✅ Build-Docs job executes
- ✅ Build-Site job executes
- ✅ Test-SourceCode job executes (if applicable)
- ✅ Lint-SourceCode job executes (if applicable)
- ✅ Test-Module job executes
- ✅ Test-ModuleLocal job executes
- ✅ Get-TestResults job executes
- ✅ Get-CodeCoverage job executes
- ✅ Publish-Module job is **SKIPPED** (condition not met)
- ✅ Publish-Site job is **SKIPPED** (condition not met)
- ✅ PR shows workflow status check

**Validation**:
```bash
gh pr checks
# Should show all test jobs passed, publish jobs skipped
```

---

## Test Scenario 2: PR Updated → Tests Re-Execute, Publishing Skipped

**Objective**: Verify that pushing new commits to a PR triggers tests again but does not execute publishing

**Steps**:

1. Make another change to the same branch:
   ```bash
   echo "# Another test change" >> README.md
   git add README.md
   git commit -m "test: Second commit to validate re-run"
   git push origin test/unified-workflow-pr-test
   ```

2. Observe workflow execution in Actions tab

**Expected Results**:
- ✅ Previous workflow run is cancelled (concurrency group behavior)
- ✅ New workflow run starts
- ✅ All test jobs execute
- ✅ Publish jobs remain skipped
- ✅ PR status updated with new workflow result

**Validation**:
```bash
gh run list --branch test/unified-workflow-pr-test
# Should show cancelled run and new in-progress/completed run
```

---

## Test Scenario 3: PR Merged → Tests Execute, Publishing Executes

**Objective**: Verify that merging a PR triggers tests and, if passing, executes publishing jobs

**Steps**:

1. Mark PR as ready for review and merge:
   ```bash
   gh pr ready
   gh pr merge --squash --delete-branch
   ```

2. Observe workflow execution in Actions tab

**Expected Results**:
- ✅ Workflow starts on main branch
- ✅ All test jobs execute
- ✅ If tests pass:
  - ✅ Publish-Module job executes
  - ✅ Publish-Site job executes
- ✅ If tests fail:
  - ⛔ Publish-Module job skipped (dependency failed)
  - ⛔ Publish-Site job skipped (dependency failed)

**Validation**:
```bash
gh run list --branch main --limit 1
gh run view <run-id>
# Should show publish jobs executed (if tests passed)
```

---

## Test Scenario 4: Test Failure on PR → Workflow Fails

**Objective**: Verify that test failures on PR prevent merge and publishing

**Steps**:

1. Create a new test branch with a breaking change:
   ```bash
   git checkout -b test/unified-workflow-fail-test
   ```

2. Introduce a test failure (e.g., modify a test to fail):
   ```bash
   # Edit a test file to make it fail
   # Example: tests/PSModuleTest.Tests.ps1
   ```

3. Commit and push:
   ```bash
   git add .
   git commit -m "test: Introduce test failure"
   git push origin test/unified-workflow-fail-test
   ```

4. Open a PR:
   ```bash
   gh pr create --title "test: Unified workflow failure test" --body "Testing failure handling" --draft
   ```

**Expected Results**:
- ✅ Workflow starts
- ⛔ Test jobs execute and fail
- ⛔ Workflow overall status is failure
- ⛔ PR cannot be merged (if branch protection enabled)
- ✅ Publish jobs skipped (never attempted)

**Validation**:
```bash
gh pr checks
# Should show failed status
```

---

## Test Scenario 5: Test Failure After Merge → Publishing Skipped

**Objective**: Verify that if tests fail after merge, publishing is skipped

**Note**: This scenario is difficult to test in practice without introducing a race condition. The typical approach is to ensure test coverage is sufficient during PR phase.

**Conceptual Validation**:
- If tests pass on PR but fail on main (e.g., merge conflict, environment difference), the workflow should:
  - Execute test jobs
  - Tests fail
  - Publish-Module job is skipped (dependency failed)
  - Publish-Site job is skipped (dependency failed)
  - Maintainer receives GitHub notification of workflow failure

**Manual Test** (if needed):
1. Merge a PR that may have environment-specific issues
2. Observe workflow failure on main branch
3. Verify publish jobs did not execute

---

## Test Scenario 6: Concurrency Control → Old Runs Cancelled

**Objective**: Verify that pushing multiple commits rapidly cancels in-progress runs for PR contexts

**Steps**:

1. Create a test branch:
   ```bash
   git checkout -b test/unified-workflow-concurrency
   ```

2. Push multiple commits in rapid succession:
   ```bash
   for i in {1..3}; do
     echo "# Change $i" >> README.md
     git add README.md
     git commit -m "test: Concurrency test $i"
     git push origin test/unified-workflow-concurrency
     sleep 5
   done
   ```

3. Open a PR:
   ```bash
   gh pr create --title "test: Concurrency control" --body "Testing concurrency behavior" --draft
   ```

4. Observe Actions tab

**Expected Results**:
- ✅ Multiple workflow runs triggered
- ✅ Earlier runs are cancelled when new commits pushed
- ✅ Only latest run completes
- ✅ Concurrency group identifier matches pattern: `Process-PSModule-refs/heads/test/unified-workflow-concurrency`

**Validation**:
```bash
gh run list --branch test/unified-workflow-concurrency
# Should show cancelled runs and one completed run
```

---

## Test Scenario 7: Manual Re-Run After Publish Failure

**Objective**: Verify that if publishing fails, maintainer can manually re-run the workflow

**Steps**:

1. Simulate a publish failure (e.g., temporarily revoke API key or publish to a test gallery)

2. Merge a PR

3. Observe workflow execution with publish failure

4. Manually re-run the workflow:
   ```bash
   gh run rerun <run-id>
   ```

**Expected Results**:
- ✅ Entire workflow re-runs (tests + publish)
- ✅ If publish issue resolved, publish succeeds on re-run
- ✅ No partial re-run (tests are re-executed)

**Validation**:
- Check workflow run logs for re-run execution
- Verify all jobs executed, not just publish jobs

---

## Cleanup

After completing quickstart tests, clean up test branches and PRs:

```bash
# Close and delete test PRs
gh pr close <pr-number> --delete-branch

# Delete local test branches
git checkout main
git branch -D test/unified-workflow-pr-test
git branch -D test/unified-workflow-fail-test
git branch -D test/unified-workflow-concurrency
```

---

## Success Criteria

All test scenarios above should pass with expected results. If any scenario fails, investigate and resolve before considering the unified workflow feature complete.

---

## Troubleshooting

### Workflow not triggering
- Check workflow file syntax: `gh workflow view`
- Verify trigger configuration matches PR events
- Check repository settings for Actions enablement

### Publish jobs executing on PR
- Verify conditional expression: `github.event.pull_request.merged == true`
- Check event context in workflow logs

### Concurrency not cancelling old runs
- Verify concurrency group configuration
- Check `cancel-in-progress` expression evaluates correctly for PR contexts

### Tests passing on PR but failing on merge
- Check for environment-specific test dependencies
- Verify test isolation and cleanup
- Consider adding integration tests that match production conditions

---

## References

- [GitHub Actions Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [GitHub CLI Manual](https://cli.github.com/manual/)
- [Process-PSModule Workflow Documentation](../../README.md)
