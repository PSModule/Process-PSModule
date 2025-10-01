<!--
Sync Impact Report - Constitution v1.1.0
========================================
Version Change: 1.0.0 → 1.1.0 (MINOR - expanded guidance)
Date: 2025-10-01

Modified Principles:
- Expanded Principle I (Workflow-First Design) with action script requirements
- Enhanced Principle III (Platform Independence) with PowerShell 7.4+ requirement
- Added CI validation workflow requirement to Principle II

Added Sections:
- Technical Constraints (PowerShell version, action-based implementation)
- Workflow Testing Standards (CI vs production workflow distinction)

Removed Sections: None

Templates Status:
✅ plan-template.md - Already aligned with constitution checks
✅ spec-template.md - No changes needed (no constitution-specific requirements)
✅ tasks-template.md - No changes needed (general task structure applies)

Follow-up TODOs:
- TODO(RATIFICATION_DATE): Determine original constitution adoption date

Rationale for MINOR bump:
- Added specific technical requirements (PowerShell 7.4+, action scripts over inline)
- Expanded workflow-first principle with implementation details
- Added CI validation workflow as required testing standard
- Material expansion of existing principles without breaking compatibility
-->

# Process-PSModule Constitution

## Core Principles

### I. Workflow-First Design (NON-NEGOTIABLE)
Every feature MUST be implemented as a reusable GitHub Actions workflow component. This is NOT a local development framework; it is designed for CI/CD execution. Workflows MUST:
- Be composable and callable from other workflows using `uses:` syntax
- Use clearly defined inputs and outputs with proper documentation
- Follow the single responsibility principle (one workflow = one concern)
- Support matrix strategies for parallel execution where appropriate
- Be independently testable via the CI validation workflow (`.github/workflows/ci.yml`)
- Delegate logic to reusable GitHub Actions (from github.com/PSModule organization)
- **Avoid inline PowerShell code** in workflow YAML; use action-based script files instead
- Reference actions by specific versions or tags for stability

**Rationale**: Reusable workflow architecture enables maintainability, reduces duplication, and allows consuming repositories to leverage Process-PSModule capabilities consistently. Action-based scripts provide better testability, reusability, and version control than inline code.

### II. Test-Driven Development (NON-NEGOTIABLE)
All code changes MUST follow strict TDD practices using Pester and PSScriptAnalyzer:
- Tests MUST be written before implementation
- Tests MUST fail initially (Red phase)
- Implementation proceeds only after failing tests exist (Green phase)
- Code MUST be refactored while maintaining passing tests (Refactor phase)
- PSScriptAnalyzer rules MUST pass for all PowerShell code
- Manual testing procedures MUST be documented when automated testing is insufficient
- **Workflow functionality MUST be validated** through CI workflow tests (`.github/workflows/ci.yml`)
- Consuming module repositories SHOULD use CI workflow for nightly validation

**Rationale**: TDD ensures code quality, prevents regressions, and creates living documentation through tests. This is fundamental to project reliability. CI workflow validation ensures the entire framework functions correctly in real-world scenarios.

### III. Platform Independence with Modern PowerShell
All workflows and features MUST support cross-platform execution (Linux, macOS, Windows) using **PowerShell 7.4 or newer**:
- Use platform-agnostic PowerShell Core 7.4+ constructs exclusively
- Implement matrix testing across all supported operating systems
- Document any platform-specific behaviors or limitations
- Test failures on any platform MUST block merging
- Provide skip mechanisms for platform-specific tests when justified
- **No backward compatibility** required for Windows PowerShell 5.1 or earlier PowerShell Core versions

**Rationale**: PowerShell 7.4+ provides consistent cross-platform behavior and modern language features. Focusing on a single modern version reduces complexity and maintenance burden while ensuring maximum compatibility for consuming projects on contemporary platforms.

### IV. Quality Gates and Observability
Every workflow execution MUST produce verifiable quality metrics:
- Test results MUST be captured in structured formats (JSON reports)
- Code coverage MUST be measured and reported
- Linting results MUST be captured and enforced
- All quality gates MUST fail the workflow if thresholds are not met
- Workflow steps MUST produce clear, actionable error messages
- Debug mode MUST be available for troubleshooting

**Rationale**: Measurable quality gates prevent degradation over time and provide clear feedback. Observability enables rapid debugging and continuous improvement.

### V. Continuous Delivery with Semantic Versioning
Release management MUST be automated and follow SemVer 2.0.0:
- Version bumps MUST be determined by PR labels (major, minor, patch)
- Releases MUST be automated on merge to main branch
- PowerShell Gallery publishing MUST be automatic for labeled releases
- GitHub releases MUST be created with complete changelogs
- Prerelease versioning MUST support incremental or date-based formats
- Documentation MUST be published to GitHub Pages automatically

**Rationale**: Automated releases reduce human error, ensure consistency, and enable rapid iteration while maintaining clear version semantics.

## Quality Standards

### Technical Constraints
- **PowerShell Version**: 7.4 or newer (no backward compatibility with 5.1 or older Core versions)
- **Execution Environment**: GitHub Actions runners (not designed for local development)
- **Code Organization**: Action-based scripts preferred over inline workflow code
- **Action References**: Use PSModule organization actions (github.com/PSModule) with version tags
- **Workflow Structure**: Reusable workflows in `.github/workflows/` using `workflow_call` trigger

### Code Quality
- All PowerShell code MUST pass PSScriptAnalyzer with project-defined rules
- Source code structure MUST follow PSModule framework conventions
- Code coverage target MUST be configurable per repository (default 0% for flexibility)
- All workflow YAML MUST be valid and pass linting
- Action scripts MUST be testable and maintainable
- Inline code in workflows SHOULD be avoided; extract to action scripts

### Documentation
- README MUST provide clear setup instructions and workflow usage examples
- All workflows MUST include descriptive comments explaining inputs, outputs, and purpose
- Changes MUST update relevant documentation in the same PR
- GitHub Pages documentation MUST be generated automatically using Material for MkDocs

### Testing
- Source code tests MUST validate framework compliance
- Module tests MUST validate built module integrity
- Local module tests (Pester) MUST validate functional behavior
- BeforeAll/AfterAll setup and teardown scripts MUST be supported for test environments
- Test matrices MUST be configurable via repository settings
- **CI validation workflow** (`.github/workflows/ci.yml`) MUST be maintained for integration testing
- **Production workflow** (`.github/workflows/workflow.yml`) is the primary consumer-facing workflow
- Consuming repositories SHOULD use CI workflow for nightly regression testing

## Development Workflow

### Branching and Pull Requests
- Follow GitHub Flow: feature branches → PR → main
- PR MUST be opened for all changes
- CI workflows MUST execute on PR synchronize, open, reopen, label events
- PR labels determine release behavior (major, minor, patch, NoRelease)

### Workflow Execution Order
The standard execution order for Process-PSModule workflows MUST be:
1. **Get-Settings** - Reads configuration and prepares test matrices
2. **Build-Module** - Compiles source into module
3. **Test-SourceCode** - Parallel matrix testing of source code standards
4. **Lint-SourceCode** - Parallel matrix linting of source code
5. **Test-Module** - Framework validation and linting of built module
6. **Test-ModuleLocal** - Runs Pester tests with BeforeAll/AfterAll support
7. **Get-TestResults** - Aggregates and validates test results
8. **Get-CodeCoverage** - Validates coverage thresholds
9. **Build-Docs** and **Build-Site** - Generates documentation
10. **Publish-Module** and **Publish-Site** - Automated publishing on release

**Workflow Types**:
- **Production Workflow** (`.github/workflows/workflow.yml`) - Main workflow for consuming repositories
- **CI Validation Workflow** (`.github/workflows/ci.yml`) - Integration tests for framework development
- Consuming repositories use production workflow for releases, CI workflow for nightly validation

### Configuration
- Settings MUST be stored in `.github/PSModule.yml` (or JSON/PSD1 format)
- Skip flags MUST be available for all major workflow steps
- OS-specific skip flags MUST be supported (Linux, macOS, Windows)
- Settings MUST support test configuration, build options, and publish behavior

## Governance

### Constitution Authority
This constitution supersedes all other development practices. When conflicts arise between this document and other guidance, the constitution takes precedence.

### Amendments
Changes to this constitution require:
1. Documentation of the proposed change with clear rationale
2. Review and approval by project maintainers
3. Migration plan for existing code/workflows if applicable
4. Version bump according to impact:
   - MAJOR: Backward incompatible principle removals or redefinitions
   - MINOR: New principles or materially expanded guidance
   - PATCH: Clarifications, wording fixes, non-semantic refinements

### Compliance
- All PRs MUST be validated against constitutional principles
- Workflow design MUST align with Workflow-First Design principle
- Test-First principle compliance is NON-NEGOTIABLE and enforced by review
- Platform Independence MUST be verified through matrix testing results
- Quality Gates MUST be enforced by workflow automation
- PowerShell 7.4+ compatibility MUST be verified
- Action-based implementation preferred over inline workflow code
- CI validation workflow MUST pass before merging changes to core workflows

### Runtime Development Guidance
For agent-specific runtime development guidance, agents should reference:
- GitHub Copilot: `.github/copilot-instructions.md` (if exists)
- Other agents: Check for `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, or `QWEN.md`

**Version**: 1.1.0 | **Ratified**: TODO(RATIFICATION_DATE) | **Last Amended**: 2025-10-01
