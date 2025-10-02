# Changelog

All notable changes to Process-PSModule will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Unified CI/CD workflow configuration consolidating CI.yml and workflow.yml
- Conditional publishing logic: Publish-Module and Publish-Site only execute when PR is merged
- Concurrency groups to prevent duplicate workflow runs on PR updates
- Automatic cancellation of previous runs when PR is updated (non-default branch)
- Optional BeforeAll/AfterAll test scripts for external test resource management
- Comprehensive test suite for workflow triggers, concurrency, job dependencies, and publishing conditions
- Integration tests for PR execution, PR update, PR merge, and test failure scenarios
- Migration guide documentation (`docs/unified-workflow-migration.md`)
- Release notes documentation (`docs/release-notes/unified-workflow.md`)
- Breaking change notice in README.md

### Changed
- Merged CI.yml functionality into workflow.yml for single-file workflow management
- Updated .github/copilot-instructions.md with unified workflow context
- Enhanced README.md with breaking changes section and migration instructions

### Removed
- **BREAKING**: Deleted `.github/workflows/CI.yml` (functionality consolidated into `workflow.yml`)

### Fixed
- Resolved duplication between CI.yml and workflow.yml execution paths
- Improved conditional logic clarity for publishing jobs

## [3.x.x] - Previous Versions

_(Prior to unified workflow consolidation)_

[unreleased]: https://github.com/PSModule/Process-PSModule/compare/v3.0.0...HEAD
