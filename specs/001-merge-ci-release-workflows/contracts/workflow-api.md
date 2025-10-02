# Workflow API Contract: Unified CI and Release Workflow

**Feature**: 001-merge-ci-release-workflows
**Date**: 2025-10-02
**Workflow File**: `.github/workflows/workflow.yml`

## Contract Overview

The unified workflow maintains the same API surface as the existing workflow.yml to ensure backward compatibility with consuming repositories.

## Workflow Trigger

```yaml
on:
  workflow_call:
    # Unchanged from v4.x
```

**Contract**: Workflow is callable from consuming repository workflows using `uses:` syntax.

**Example Consumer Usage**:
```yaml
name: Process-PSModule

on:
  pull_request:
    branches: [main]
    types: [closed, opened, reopened, synchronize, labeled]
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  Process-PSModule:
    uses: PSModule/Process-PSModule/.github/workflows/workflow.yml@v5
    secrets:
      APIKEY: ${{ secrets.APIKEY }}
```

## Inputs

All inputs remain unchanged from workflow.yml v4.x:

### Input: Name
- **Type**: `string`
- **Description**: The name of the module to process. Scripts default to the repository name if nothing is specified.
- **Required**: `false`
- **Default**: Repository name (auto-detected)

### Input: SettingsPath
- **Type**: `string`
- **Description**: The path to the settings file. Settings in the settings file take precedence over the action inputs.
- **Required**: `false`
- **Default**: `.github/PSModule.yml`

### Input: Debug
- **Type**: `boolean`
- **Description**: Enable debug output.
- **Required**: `false`
- **Default**: `false`

### Input: Verbose
- **Type**: `boolean`
- **Description**: Enable verbose output.
- **Required**: `false`
- **Default**: `false`

### Input: Version
- **Type**: `string`
- **Description**: Specifies the version of the GitHub module to be installed. The value must be an exact version.
- **Required**: `false`
- **Default**: `''` (latest stable)

### Input: Prerelease
- **Type**: `boolean`
- **Description**: Whether to use a prerelease version of the 'GitHub' module.
- **Required**: `false`
- **Default**: `false`

### Input: WorkingDirectory
- **Type**: `string`
- **Description**: The path to the root of the repo.
- **Required**: `false`
- **Default**: `'.'` (repository root)

## Secrets

All secrets remain unchanged from workflow.yml v4.x:

### Secret: APIKey
- **Description**: The API key for the PowerShell Gallery.
- **Required**: `true` (for Publish-Module job execution)
- **Used By**: Publish-Module job
- **Note**: Required even in CI-only mode (job is skipped but secret must be defined)

### Secret: TEST_APP_ENT_CLIENT_ID
- **Description**: The client ID of an Enterprise GitHub App for running tests.
- **Required**: `false`
- **Used By**: Test-ModuleLocal job (if Enterprise App tests are enabled)

### Secret: TEST_APP_ENT_PRIVATE_KEY
- **Description**: The private key of an Enterprise GitHub App for running tests.
- **Required**: `false`
- **Used By**: Test-ModuleLocal job (if Enterprise App tests are enabled)

### Secret: TEST_APP_ORG_CLIENT_ID
- **Description**: The client ID of an Organization GitHub App for running tests.
- **Required**: `false`
- **Used By**: Test-ModuleLocal job (if Organization App tests are enabled)

### Secret: TEST_APP_ORG_PRIVATE_KEY
- **Description**: The private key of an Organization GitHub App for running tests.
- **Required**: `false`
- **Used By**: Test-ModuleLocal job (if Organization App tests are enabled)

### Secret: TEST_USER_ORG_FG_PAT
- **Description**: The fine-grained personal access token with org access for running tests.
- **Required**: `false`
- **Used By**: Test-ModuleLocal job (if org-level tests are enabled)

### Secret: TEST_USER_USER_FG_PAT
- **Description**: The fine-grained personal access token with user account access for running tests.
- **Required**: `false`
- **Used By**: Test-ModuleLocal job (if user-level tests are enabled)

### Secret: TEST_USER_PAT
- **Description**: The classic personal access token for running tests.
- **Required**: `false`
- **Used By**: Test-ModuleLocal job (if PAT-based tests are enabled)

## Outputs

The workflow does not define explicit outputs. Results are communicated through:

1. **Workflow Artifacts**:
   - `module`: Built module artifact (from Build-Module job)
   - `site`: Documentation site artifact (from Build-Site job)
   - `test-results`: Test result files (from test jobs)
   - `code-coverage`: Code coverage reports (from Get-CodeCoverage job)

2. **GitHub Releases**: Created by Publish-Module job (release mode only)

3. **GitHub Pages**: Deployed by Publish-Site job (release mode only)

4. **Workflow Status**: Success/failure status reported to PR and commit status checks

## Permissions

The workflow requires the following permissions:

```yaml
permissions:
  contents: write      # to checkout the repo and create releases on the repo
  pull-requests: write # to write comments to PRs
  statuses: write      # to update the status of the workflow from linter
  pages: write         # to deploy to Pages
  id-token: write      # to verify the deployment originates from an appropriate source
```

**Note**: These permissions are required for full functionality (CI + Release mode). In CI-only mode, `pages` and `id-token` permissions are unused but do not cause issues.

## Job Execution Contract

### Always Executed Jobs

The following jobs execute in all modes (CI-only and CI + Release):

1. **Get-Settings**: Load and parse module settings
2. **Build-Module**: Compile module from source
3. **Build-Docs**: Generate module documentation
4. **Build-Site**: Build documentation site
5. **Test-SourceCode**: Matrix test source code (multiple OS)
6. **Lint-SourceCode**: Matrix lint source code (multiple OS)
7. **Test-Module**: Test built module integrity
8. **BeforeAll-ModuleLocal**: Setup external test resources (if tests/BeforeAll.ps1 exists)
9. **Test-ModuleLocal**: Matrix test module functionality (ubuntu, windows, macos)
10. **AfterAll-ModuleLocal**: Teardown external test resources (if tests/AfterAll.ps1 exists)
11. **Get-TestResults**: Aggregate and validate test results
12. **Get-CodeCoverage**: Analyze code coverage

### Conditionally Executed Jobs

The following jobs execute only in CI + Release mode:

13. **Publish-Module**: Publish module to PowerShell Gallery
    - **Condition**: Tests pass AND (merged PR OR push to default branch)
    
14. **Publish-Site**: Deploy documentation to GitHub Pages
    - **Condition**: Tests pass AND Build-Site succeeds AND (merged PR OR push to default branch)

## Conditional Execution Logic

### Publish-Module Condition

```yaml
if: |
  needs.Get-Settings.result == 'success' &&
  needs.Get-TestResults.result == 'success' &&
  needs.Get-CodeCoverage.result == 'success' &&
  !cancelled() &&
  (
    (github.event_name == 'pull_request' && github.event.pull_request.merged == true) ||
    (github.event_name == 'push' && github.ref == format('refs/heads/{0}', github.event.repository.default_branch))
  )
```

**Publishes When**:
- All tests pass (Get-TestResults, Get-CodeCoverage success)
- Workflow not cancelled
- **Either**:
  - Pull request merged to default branch, **OR**
  - Direct push to default branch

**Skips When**:
- Tests fail
- Workflow cancelled
- Unmerged pull request
- Manual trigger (`workflow_dispatch`)
- Scheduled run (`schedule`)
- Push to non-default branch

### Publish-Site Condition

```yaml
if: |
  needs.Get-Settings.result == 'success' &&
  needs.Get-TestResults.result == 'success' &&
  needs.Get-CodeCoverage.result == 'success' &&
  needs.Build-Site.result == 'success' &&
  !cancelled() &&
  (
    (github.event_name == 'pull_request' && github.event.pull_request.merged == true) ||
    (github.event_name == 'push' && github.ref == format('refs/heads/{0}', github.event.repository.default_branch))
  )
```

**Publishes When**: Same as Publish-Module, plus Build-Site must succeed

## Behavioral Contract by Trigger Type

### Trigger: Pull Request (Opened/Synchronized/Reopened)

**Event**: `github.event_name == 'pull_request'` AND `github.event.pull_request.merged == false`

**Behavior**:
- ✅ Execute all CI jobs (build, test, lint)
- ❌ Skip Publish-Module
- ❌ Skip Publish-Site
- ✅ Report test results as PR status checks
- ✅ Comment on PR with test/coverage results

**Exit**: Workflow completes after test results

### Trigger: Pull Request (Merged)

**Event**: `github.event_name == 'pull_request'` AND `github.event.pull_request.merged == true`

**Behavior**:
- ✅ Execute all CI jobs (build, test, lint)
- ✅ Execute Publish-Module (if tests pass)
- ✅ Execute Publish-Site (if tests pass and Build-Site succeeds)
- ✅ Create GitHub release
- ✅ Deploy documentation to GitHub Pages

**Exit**: Workflow completes after successful publish

### Trigger: Push to Default Branch

**Event**: `github.event_name == 'push'` AND `github.ref == 'refs/heads/main'`

**Behavior**: Same as merged pull request
- ✅ Execute all CI jobs
- ✅ Execute Publish-Module (if tests pass)
- ✅ Execute Publish-Site (if tests pass)

**Note**: Direct pushes bypass PR validation; use with caution

### Trigger: Push to Non-Default Branch

**Event**: `github.event_name == 'push'` AND `github.ref != 'refs/heads/main'`

**Behavior**:
- ✅ Execute all CI jobs
- ❌ Skip Publish-Module
- ❌ Skip Publish-Site

**Use Case**: Feature branch validation without PR

### Trigger: Manual (workflow_dispatch)

**Event**: `github.event_name == 'workflow_dispatch'`

**Behavior**:
- ✅ Execute all CI jobs
- ❌ Skip Publish-Module
- ❌ Skip Publish-Site

**Use Case**: On-demand validation without publishing

### Trigger: Scheduled (schedule)

**Event**: `github.event_name == 'schedule'`

**Behavior**:
- ✅ Execute all CI jobs
- ❌ Skip Publish-Module
- ❌ Skip Publish-Site

**Use Case**: Nightly regression testing

## Breaking Changes from v4.x

### For Consuming Repositories Using workflow.yml

**Impact**: ✅ **None** - Existing behavior preserved

**Changes Required**: None (optional: review trigger conditions in consuming repo workflow)

### For Consuming Repositories Using CI.yml

**Impact**: ⚠️ **Deprecation Warning** - CI.yml marked deprecated

**Changes Required**: Migrate to workflow.yml during v5.x lifecycle

**Migration Path**:
1. Update consuming repository workflow to call workflow.yml instead of CI.yml
2. Test both PR and merge workflows
3. Remove CI.yml reference from consuming repository

### For Process-PSModule Framework

**Impact**: 🌟 **Breaking Change** - Major version bump (v5.0.0)

**Changes**:
- CI.yml deprecated (removed in v6.0.0)
- Unified workflow.yml handles all scenarios
- New conditional execution logic

## Validation Test Cases

Consuming repositories should validate these scenarios after migration:

1. ✅ **PR Opened**: CI runs, no publish
2. ✅ **PR Synchronized**: CI runs, no publish
3. ✅ **PR Merged**: CI runs, publish succeeds
4. ✅ **Direct Push to Main**: CI runs, publish succeeds
5. ✅ **Push to Feature Branch**: CI runs (if configured), no publish
6. ✅ **Manual Trigger**: CI runs, no publish
7. ✅ **Test Failure**: Workflow fails, no publish
8. ✅ **Coverage Below Threshold**: Workflow fails, no publish

## Support and Compatibility

| Process-PSModule Version | Unified Workflow | CI.yml Support | API Breaking Changes |
|-------------------------|------------------|----------------|---------------------|
| v4.x (current) | ❌ No | ✅ Yes | N/A |
| v5.0 (this feature) | ✅ Yes | ⚠️ Deprecated | No (for workflow.yml users) |
| v6.0 (future) | ✅ Yes | ❌ Removed | Yes (CI.yml removed) |

## Conclusion

The unified workflow maintains API compatibility with workflow.yml v4.x while adding intelligent conditional execution. Consuming repositories using workflow.yml continue working without changes. Consumers using CI.yml should migrate during the v5.x support period.
