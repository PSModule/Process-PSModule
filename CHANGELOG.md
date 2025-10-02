# Changelog

All notable changes to Process-PSModule will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [5.0.0] - TBD

### 🌟 Breaking Changes

- **Unified CI and Release Workflow**: Consolidated separate CI.yml and workflow.yml into a single intelligent workflow
  - CI.yml is now **deprecated** and will be removed in v6.0.0
  - workflow.yml now handles both CI-only testing (unmerged PRs, manual triggers) and CI + release operations (merged PRs, direct pushes to main)
  - Automatic conditional execution based on trigger context
  - For repositories using CI.yml: Migration recommended during v5.x lifecycle (see [migration guide](./docs/migration/v5-unified-workflow.md))
  - For repositories already using workflow.yml: No changes required

### Added

- Conditional execution logic in workflow.yml for intelligent CI-only vs CI + Release mode determination
- Comprehensive inline documentation explaining workflow execution modes
- Migration guide for consuming repositories ([docs/migration/v5-unified-workflow.md](./docs/migration/v5-unified-workflow.md))
- Deprecation notice in CI.yml header with migration instructions

### Changed

- Publish-Module job now conditionally executes only on merged PRs or direct pushes to default branch
- Publish-Site job now conditionally executes only on merged PRs or direct pushes to default branch
- Updated README.md with breaking change notice and unified workflow documentation
- Updated .github/copilot-instructions.md with unified workflow as active technology

### Removed

- None (CI.yml marked deprecated but not removed; removal planned for v6.0.0)

### Migration

**Action Required for Repositories Using CI.yml**:
1. Update consuming repository workflow to call workflow.yml instead of CI.yml
2. Consolidate workflow triggers to single workflow file
3. Test both PR and merge workflows
4. Remove CI.yml reference after validation

**No Action Required for Repositories Using workflow.yml**:
- Existing behavior preserved
- Optional: Update workflow version reference from @v4 to @v5

For detailed migration instructions and validation procedures, see the [v5.0.0 Migration Guide](./docs/migration/v5-unified-workflow.md).

## [4.x] - Previous Releases

For changelog entries prior to v5.0.0, see the [GitHub Releases](https://github.com/PSModule/Process-PSModule/releases) page.
