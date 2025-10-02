# Quickstart: Migrating to Unified CI and Release Workflow

**Feature**: 001-merge-ci-release-workflows
**Date**: 2025-10-02
**Target Audience**: PowerShell module maintainers consuming Process-PSModule workflows

## Overview

Process-PSModule v5.0.0 introduces a **unified workflow** that handles both continuous integration testing and automated release publishing in a single workflow file. This eliminates the need to maintain separate CI.yml and workflow.yml files.

**Key Benefits**:
- ✅ Single source of truth for CI/CD pipeline
- ✅ Reduced configuration complexity
- ✅ Consistent behavior across all trigger scenarios
- ✅ Easier maintenance across multiple repositories

## Migration Scenarios

### Scenario 1: Already Using workflow.yml Only

**Current State**: Your repository calls workflow.yml for all events (PRs and merges)

**Impact**: ✅ **None** - Your repository continues working without changes

**Action Required**: None (optional: review this guide for new features)

**Example Current Workflow**:
```yaml
name: Process-PSModule

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  Process-PSModule:
    uses: PSModule/Process-PSModule/.github/workflows/workflow.yml@v4
    secrets:
      APIKEY: ${{ secrets.APIKEY }}
```

**After v5 Upgrade**: Update version tag to `@v5`
```yaml
jobs:
  Process-PSModule:
    uses: PSModule/Process-PSModule/.github/workflows/workflow.yml@v5
    secrets:
      APIKEY: ${{ secrets.APIKEY }}
```

### Scenario 2: Using Both CI.yml and workflow.yml

**Current State**: Your repository has two workflow files:
- One calling CI.yml for PR validation
- One calling workflow.yml for releases

**Impact**: ⚠️ **Migration Recommended** - CI.yml is deprecated

**Action Required**: Consolidate to single workflow file calling workflow.yml

**Example Current Setup**:

File: `.github/workflows/CI.yml` (PR validation)
```yaml
name: CI

on:
  pull_request:
    branches: [main]

jobs:
  CI:
    uses: PSModule/Process-PSModule/.github/workflows/CI.yml@v4
    secrets:
      APIKEY: ${{ secrets.APIKEY }}
```

File: `.github/workflows/Process-PSModule.yml` (Release)
```yaml
name: Process-PSModule

on:
  pull_request:
    branches: [main]
    types: [closed]

jobs:
  Process-PSModule:
    if: github.event.pull_request.merged == true
    uses: PSModule/Process-PSModule/.github/workflows/workflow.yml@v4
    secrets:
      APIKEY: ${{ secrets.APIKEY }}
```

**After Migration** (single unified workflow):

File: `.github/workflows/Process-PSModule.yml`
```yaml
name: Process-PSModule

on:
  pull_request:
    branches: [main]
    types: [opened, reopened, synchronize, closed, labeled]
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  Process-PSModule:
    uses: PSModule/Process-PSModule/.github/workflows/workflow.yml@v5
    secrets:
      APIKEY: ${{ secrets.APIKEY }}
      # Add any test-related secrets your module needs
```

**Cleanup**: Delete `.github/workflows/CI.yml` from your repository

### Scenario 3: Custom Trigger Configurations

**Current State**: Your repository has custom workflow triggers or conditions

**Impact**: ⚠️ **Review Required** - Ensure trigger patterns align with unified workflow

**Action Required**: Review and update triggers to match recommended patterns

**Recommended Trigger Pattern**:
```yaml
on:
  pull_request:
    branches: [main]
    types:
      - opened        # PR created
      - reopened      # PR reopened
      - synchronize   # New commits pushed
      - closed        # PR closed (merged or closed without merge)
      - labeled       # PR labeled (for prerelease publishing)
  push:
    branches: [main]  # Direct pushes to main
  workflow_dispatch:  # Manual triggers
  schedule:           # Nightly regression tests (optional)
    - cron: '0 2 * * *'  # 2 AM daily
```

**Key Points**:
- `closed` type required to detect merged PRs
- `labeled` type enables prerelease publishing workflow
- `workflow_dispatch` allows manual testing without releases
- `schedule` useful for nightly validation (optional)

## Validation Steps

After migration, validate these scenarios:

### Test 1: PR Opened (CI-Only Mode)

**Steps**:
1. Create a feature branch
2. Make a code change
3. Open a pull request to main

**Expected Behavior**:
- ✅ Workflow runs automatically
- ✅ All CI jobs execute (build, test, lint)
- ✅ Test results reported as PR status checks
- ❌ Publish-Module job skipped
- ❌ Publish-Site job skipped

**Validation**:
```bash
# Check workflow run in GitHub Actions UI
# Verify Publish-Module and Publish-Site show as "Skipped"
```

### Test 2: PR Updated (CI-Only Mode)

**Steps**:
1. Push new commits to the open PR

**Expected Behavior**:
- ✅ Workflow runs automatically
- ✅ All CI jobs execute with new changes
- ❌ Publish jobs still skipped

### Test 3: PR Merged (CI + Release Mode)

**Steps**:
1. Merge the pull request to main branch

**Expected Behavior**:
- ✅ Workflow runs automatically
- ✅ All CI jobs execute
- ✅ Publish-Module job executes (if tests pass)
- ✅ Publish-Site job executes (if tests pass)
- ✅ Module published to PowerShell Gallery
- ✅ Documentation deployed to GitHub Pages
- ✅ GitHub release created

**Validation**:
```bash
# Check PowerShell Gallery for new version
Find-PSResource -Name YourModuleName | Select-Object -First 1

# Check GitHub Releases
# Visit: https://github.com/yourorg/yourrepo/releases

# Check GitHub Pages
# Visit: https://yourorg.github.io/yourrepo/
```

### Test 4: Manual Trigger (CI-Only Mode)

**Steps**:
1. Go to Actions tab in GitHub
2. Select "Process-PSModule" workflow
3. Click "Run workflow" button
4. Select branch and click "Run workflow"

**Expected Behavior**:
- ✅ Workflow runs on selected branch
- ✅ All CI jobs execute
- ❌ Publish jobs skipped (no release from manual trigger)

### Test 5: Direct Push to Main (CI + Release Mode)

**Steps**:
1. Push commits directly to main branch (bypass PR)

**Expected Behavior**:
- ✅ Workflow runs automatically
- ✅ All CI jobs execute
- ✅ Publish jobs execute (if tests pass)

**Warning**: Direct pushes skip PR review; use with caution

## Troubleshooting

### Issue: Workflow Not Triggering on PR

**Symptom**: Workflow doesn't run when PR opened

**Solution**: Ensure your workflow file includes the correct PR trigger types
```yaml
on:
  pull_request:
    branches: [main]
    types: [opened, reopened, synchronize, closed, labeled]
```

### Issue: Publish Jobs Not Running After Merge

**Symptom**: PR merged but publish jobs skipped

**Possible Causes**:
1. Tests failed - check test results
2. PR not actually merged (closed without merge)
3. Workflow file missing `closed` trigger type

**Solution**: Check workflow run logs for skip reason; verify PR actually merged

### Issue: Accidental Release from Unmerged PR

**Symptom**: Module published before PR merged

**Cause**: Likely using prerelease workflow with `prerelease` label

**Solution**: This is expected behavior for prerelease publishing. Remove `prerelease` label if unintended.

### Issue: Workflow Runs But Skips All Jobs

**Symptom**: Workflow triggers but all jobs show as skipped

**Possible Causes**:
1. Settings file has skip flags enabled
2. Workflow conditions not met

**Solution**: Check `.github/PSModule.yml` for skip settings:
```yaml
Build:
  Module:
    Skip: false  # Ensure not set to true
Test:
  Skip: false
```

## Configuration Options

The unified workflow respects all existing settings in `.github/PSModule.yml`:

### Skip Publishing

Prevent releases even on merged PRs:
```yaml
Publish:
  Module:
    Skip: true  # Skip PowerShell Gallery publishing
  Site:
    Skip: true  # Skip GitHub Pages deployment
```

### Versioning Configuration

```yaml
Publish:
  Module:
    AutoPatching: true  # Auto-apply patch version on unlabeled PRs
    IncrementalPrerelease: true  # Use incremental prerelease tags
    MajorLabels: ['major', 'breaking']
    MinorLabels: ['minor', 'feature']
    PatchLabels: ['patch', 'fix', 'bug']
```

### Test Configuration

```yaml
Test:
  CodeCoverage:
    Skip: false
    PercentTarget: 80  # Minimum code coverage percentage
  TestResults:
    Skip: false
```

## Best Practices

### 1. Use PR Workflow for All Changes

**Recommended**: Always use pull requests for code changes
```
feature branch → PR → merge to main → automatic release
```

**Avoid**: Direct pushes to main (bypasses review)

### 2. Label PRs for Version Control

**Major Release** (breaking changes):
```bash
gh pr edit <PR> --add-label "major"
```

**Minor Release** (new features):
```bash
gh pr edit <PR> --add-label "minor"
```

**Patch Release** (bug fixes):
```bash
gh pr edit <PR> --add-label "patch"
# OR enable AutoPatching for automatic patch bumps
```

### 3. Enable Nightly Validation (Optional)

Add scheduled trigger for regression testing:
```yaml
on:
  schedule:
    - cron: '0 2 * * *'  # 2 AM daily
```

### 4. Use Manual Triggers for Testing

Test workflow changes without publishing:
1. Push changes to feature branch
2. Manually trigger workflow on that branch
3. Verify workflow behaves correctly
4. Merge PR when validated

## Migration Checklist

Use this checklist when migrating a repository:

- [ ] Backup existing workflow files
- [ ] Update workflow to use workflow.yml@v5
- [ ] Add required PR trigger types (opened, reopened, synchronize, closed, labeled)
- [ ] Remove or deprecate CI.yml references
- [ ] Update repository documentation referencing workflow files
- [ ] Test PR opened scenario (CI-only)
- [ ] Test PR merged scenario (CI + release)
- [ ] Test manual trigger scenario (CI-only)
- [ ] Verify PowerShell Gallery publishing works
- [ ] Verify GitHub Pages deployment works
- [ ] Delete deprecated workflow files (after validation)

## Support

For issues or questions about migration:

1. Check the [Process-PSModule documentation](https://github.com/PSModule/Process-PSModule)
2. Review workflow run logs in GitHub Actions
3. Open an issue on the Process-PSModule repository
4. Consult the [workflow API contract](./contracts/workflow-api.md)

## Next Steps

After successful migration:

1. ✅ Monitor first few releases to ensure smooth operation
2. ✅ Update team documentation about the unified workflow
3. ✅ Share migration experience with other repository maintainers
4. ✅ Consider migrating other repositories following the same pattern

---

**Last Updated**: 2025-10-02
**Process-PSModule Version**: v5.0.0
**Breaking Change**: Yes - CI.yml deprecated
