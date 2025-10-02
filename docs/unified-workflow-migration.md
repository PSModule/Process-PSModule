# Unified Workflow Migration Guide

**Version**: 1.0.0 | **Date**: 2025-10-02 | **Breaking Change**: Yes

## Overview

Process-PSModule has consolidated the separate `CI.yml` and `workflow.yml` files into a single unified `workflow.yml` that handles both pull request testing and release publishing. This breaking change simplifies repository configuration by reducing workflow file count from two to one while maintaining all existing functionality.

## What Changed

### Before (v3.x)

```plaintext
.github/workflows/
├── CI.yml          # Test execution on PRs
└── workflow.yml    # Release publishing on merge
```

### After (v4.x)

```plaintext
.github/workflows/
└── workflow.yml    # Unified: Tests + Publishing
```

## Breaking Changes

1. **CI.yml is deleted** - All test execution logic is now in `workflow.yml`
2. **External references must be updated** - Any automation or documentation referencing `CI.yml` must be updated
3. **Branch protection rules** - Status checks must reference `workflow.yml` instead of `CI.yml`

## Migration Steps for Consuming Repositories

### Step 1: Update Process-PSModule Version

Update your workflow file to use the new version:

```yaml
# .github/workflows/Process-PSModule.yml
jobs:
  Process-PSModule:
    uses: PSModule/Process-PSModule/.github/workflows/workflow.yml@v4  # Update to v4
    secrets:
      APIKEY: ${{ secrets.APIKEY }}
```

### Step 2: Delete CI.yml (if it exists)

If your repository has a custom `CI.yml` file, delete it:

```bash
git rm .github/workflows/CI.yml
git commit -m "chore: Remove CI.yml (migrated to unified workflow)"
```

**Note**: Most consuming repositories won't have a custom `CI.yml` as they use the reusable workflow from Process-PSModule.

### Step 3: Update External References

Update any references to `CI.yml` in:

- **Documentation** - README, contributing guides, wiki pages
- **CI/CD scripts** - Deployment automation, testing scripts
- **Monitoring/alerting** - Workflow status monitoring
- **Branch protection rules** - Update required status checks

### Step 4: Update Branch Protection Rules

Update GitHub branch protection rules to reference the unified workflow:

1. Navigate to **Settings** → **Branches** → **Branch protection rules**
2. Edit the rule for `main` (or your default branch)
3. Under "Require status checks to pass before merging":
   - Remove any checks referencing `CI` or old workflow names
   - Add checks for `Process-PSModule` (the unified workflow job)
4. Save changes

### Step 5: Test the Migration

1. Create a test branch and open a PR:
   ```bash
   git checkout -b test/unified-workflow-migration
   echo "# Test change" >> README.md
   git add README.md
   git commit -m "test: Verify unified workflow"
   git push origin test/unified-workflow-migration
   gh pr create --title "test: Unified workflow migration" --body "Testing migration" --draft
   ```

2. Verify workflow execution:
   - Go to the **Actions** tab
   - Confirm the workflow runs and all tests execute
   - Verify publishing jobs are skipped (PR not merged)

3. If successful, close the test PR and delete the branch:
   ```bash
   gh pr close --delete-branch
   ```

## Unified Workflow Behavior

### PR Context (opened, synchronized, reopened)

**What executes**:
- ✅ Get-Settings
- ✅ Build-Module
- ✅ Build-Docs
- ✅ Build-Site
- ✅ Test-SourceCode
- ✅ Lint-SourceCode
- ✅ Test-Module
- ✅ Test-ModuleLocal (cross-platform)
- ✅ Get-TestResults
- ✅ Get-CodeCoverage
- ❌ Publish-Module (skipped)
- ❌ Publish-Site (skipped)

### Merge Context (PR merged to main)

**What executes**:
- ✅ All test and build jobs (same as PR)
- ✅ Publish-Module (if tests pass)
- ✅ Publish-Site (if tests pass)

### Concurrency Control

The unified workflow uses concurrency groups to manage workflow runs:

- **PR builds**: Cancel in-progress runs when new commits are pushed
- **Main branch builds**: Allow runs to complete (no cancellation)

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.ref != format('refs/heads/{0}', github.event.repository.default_branch) }}
```

## Configuration Changes

### No Changes Required

The following configuration remains unchanged:

- ✅ `.github/PSModule.yml` (or JSON/PSD1) settings file
- ✅ Secret names (`APIKEY`, `TEST_*` secrets)
- ✅ Workflow inputs (Name, SettingsPath, Debug, Verbose, etc.)
- ✅ Module structure requirements
- ✅ Test frameworks and patterns

### Optional Enhancements

You may want to update your workflow trigger configuration to be more explicit:

```yaml
# .github/workflows/Process-PSModule.yml
name: Process-PSModule

on:
  pull_request:
    branches: [main]
    types:
      - closed        # Detect merged PRs
      - opened        # Initial PR creation
      - reopened      # Reopened PR
      - synchronize   # New commits pushed
      - labeled       # Label changes (for prerelease)

jobs:
  Process-PSModule:
    uses: PSModule/Process-PSModule/.github/workflows/workflow.yml@v4
    secrets:
      APIKEY: ${{ secrets.APIKEY }}
```

## Troubleshooting

### Workflow not triggering

**Issue**: Workflow doesn't run after migration

**Solutions**:
1. Verify workflow file syntax: `gh workflow view`
2. Check trigger configuration matches PR events
3. Confirm Actions are enabled in repository settings
4. Check workflow file is in `.github/workflows/` directory

### Publishing jobs executing on PR

**Issue**: Publishing happens on PR before merge

**Solutions**:
1. Verify you're using Process-PSModule v4+
2. Check conditional expressions in workflow logs
3. Confirm PR is not accidentally merged

### Tests passing on PR but failing after merge

**Issue**: Tests pass during PR review but fail on main branch

**Solutions**:
1. Check for environment-specific dependencies
2. Verify test isolation and cleanup
3. Review test data management
4. Consider adding integration tests matching production

### Status checks not appearing

**Issue**: PR doesn't show required status checks

**Solutions**:
1. Update branch protection rules to reference unified workflow
2. Verify workflow name matches expected check name
3. Allow workflow to run at least once to register the check
4. Check if workflow is set to draft (won't report status)

## Rollback Procedure

If you encounter issues and need to rollback:

1. **Revert to v3.x**:
   ```yaml
   uses: PSModule/Process-PSModule/.github/workflows/workflow.yml@v3
   ```

2. **Restore CI.yml** (if you had customizations):
   ```bash
   git revert <commit-hash>  # Revert the commit that deleted CI.yml
   ```

3. **Update branch protection rules** back to reference old checks

4. **Report issues**: Open an issue at [Process-PSModule Issues](https://github.com/PSModule/Process-PSModule/issues)

## Benefits of Unified Workflow

### Simplified Maintenance
- **Single file to update** instead of coordinating changes across two files
- Reduced configuration complexity
- Easier to understand workflow logic

### Consistent Behavior
- Same test execution in PR and merge contexts
- Clear conditional logic for publishing
- Predictable workflow execution

### Better Developer Experience
- Fewer files to manage
- Clearer workflow structure
- Easier to debug and troubleshoot

## FAQ

**Q: Do I need to change my module structure?**
A: No, module structure requirements remain unchanged.

**Q: Will my existing secrets still work?**
A: Yes, all secret names and configurations are preserved.

**Q: What happens to in-flight PRs during migration?**
A: Existing PRs will use the old workflow until you update the Process-PSModule version reference.

**Q: Can I test the migration without affecting production?**
A: Yes, create a test repository or test branch to validate before updating production repositories.

**Q: Is there a performance impact?**
A: No, workflow execution time should be equivalent or slightly better due to optimized concurrency control.

**Q: How do I verify the migration was successful?**
A: Create a test PR and verify all expected jobs execute and status checks pass.

## Support

For questions or issues:
- **Documentation**: [Process-PSModule README](https://github.com/PSModule/Process-PSModule)
- **Issues**: [GitHub Issues](https://github.com/PSModule/Process-PSModule/issues)
- **Discussions**: [GitHub Discussions](https://github.com/PSModule/Process-PSModule/discussions)

## References

- [Process-PSModule v4 Release Notes](../../CHANGELOG.md)
- [GitHub Actions Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [GitHub Actions Reusable Workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows)
- [Branch Protection Rules](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
