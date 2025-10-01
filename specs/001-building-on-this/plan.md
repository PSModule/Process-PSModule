
# Implementation Plan: Local GitHub Composite Action for BeforeAll/AfterAll Test Scripts

**Branch**: `001-building-on-this` | **Date**: October 1, 2025 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-building-on-this/spec.md`

## Execution Flow (/plan command scope)
```
1. Load feature spec from Input path
   → If not found: ERROR "No feature spec at {path}"
2. Fill Technical Context (scan for NEEDS CLARIFICATION)
   → Detect Project Type from file system structure or context (web=frontend+backend, mobile=app+api)
   → Set Structure Decision based on project type
3. Fill the Constitution Check section based on the content of the constitution document.
4. Evaluate Constitution Check section below
   → If violations exist: Document in Complexity Tracking
   → If no justification possible: ERROR "Simplify approach first"
   → Update Progress Tracking: Initial Constitution Check
5. Execute Phase 0 → research.md
   → If NEEDS CLARIFICATION remain: ERROR "Resolve unknowns"
6. Execute Phase 1 → contracts, data-model.md, quickstart.md, agent-specific template file (e.g., `CLAUDE.md` for Claude Code, `.github/copilot-instructions.md` for GitHub Copilot, `GEMINI.md` for Gemini CLI, `QWEN.md` for Qwen Code or `AGENTS.md` for opencode).
7. Re-evaluate Constitution Check section
   → If new violations: Refactor design, return to Phase 1
   → Update Progress Tracking: Post-Design Constitution Check
8. Plan Phase 2 → Describe task generation approach (DO NOT create tasks.md)
9. STOP - Ready for /tasks command
```

**IMPORTANT**: The /plan command STOPS at step 7. Phases 2-4 are executed by other commands:
- Phase 2: /tasks command creates tasks.md
- Phase 3-4: Implementation execution (manual or via tools)

## Summary
Extract BeforeAll/AfterAll test setup/teardown logic from Test-ModuleLocal.yml into a reusable local composite action. This reduces workflow duplication, improves maintainability, and enables reuse across workflows. The single composite action will accept a mode parameter (before/after) to control which script to execute (BeforeAll.ps1 or AfterAll.ps1) and error handling behavior. The action will be located at `.github/actions/setup-test/action.yml` and will integrate with existing PSModule/GitHub-Script and PSModule/Install-PSModuleHelpers actions. Documentation will clearly explain that BeforeAll/AfterAll scripts are intended for managing external test resources (cloud infrastructure, external databases, third-party services) that are independent of the test platform/OS, while test-specific resources should be created within the tests themselves.

## Technical Context
**Language/Version**: PowerShell 7.4+ (GitHub Actions composite actions)
**Primary Dependencies**: PSModule/GitHub-Script@v1, PSModule/Install-PSModuleHelpers@v1
**Storage**: N/A (stateless GitHub Actions workflow execution)
**Testing**: CI validation workflow for action testing
**Target Platform**: GitHub Actions (ubuntu-latest runners)
**Project Type**: GitHub Actions workflow framework (Process-PSModule)
**Performance Goals**: Sub-second execution overhead for action invocation
**Constraints**: Must maintain exact behavior of current inline implementation, ubuntu-latest runner only
**Scale/Scope**: Single composite action with 2 modes, integration into 1 primary workflow (Test-ModuleLocal.yml)

## Constitution Check
*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. Workflow-First Design (NON-NEGOTIABLE)
- [x] Feature is implemented as reusable GitHub Actions workflow(s)
  - Composite action is a reusable GitHub Actions component
- [x] Workflows have clearly defined inputs and outputs
  - Mode parameter (before/after), configuration inputs, secret inputs defined
- [x] Workflows follow single responsibility principle
  - Single composite action with focused responsibility: test setup/teardown script execution
- [x] Matrix strategies used for parallel execution where appropriate
  - N/A for this feature (sequential setup/teardown by design)
- [x] Workflows are independently testable via CI validation workflow
  - Will be tested via Test-ModuleLocal.yml integration
- [x] Logic delegated to reusable GitHub Actions (PSModule organization)
  - Uses PSModule/GitHub-Script@v1 for PowerShell execution
- [x] Inline PowerShell code avoided; action-based scripts used instead
  - PowerShell logic encapsulated in composite action via GitHub-Script
- [x] Actions referenced by specific versions/tags
  - PSModule/GitHub-Script@v1, PSModule/Install-PSModuleHelpers@v1

### II. Test-Driven Development (NON-NEGOTIABLE)
- [x] Tests will be written before implementation
  - Will create test scenarios in Test-ModuleLocal integration workflow
- [x] Initial tests will fail (Red phase documented)
  - Will document expected failure before composite action exists
- [x] Implementation plan includes making tests pass (Green phase)
  - Implementation will make integration tests pass
- [x] Refactoring phase planned while maintaining tests
  - Plan includes validation that behavior matches current inline implementation
- [x] PSScriptAnalyzer validation included
  - Linting applied to composite action YAML and embedded PowerShell
- [x] Manual testing documented if needed
  - Manual validation via Test-ModuleLocal workflow execution
- [x] CI validation workflow tests included
  - Integration tests via Test-ModuleLocal.yml execution

### III. Platform Independence with Modern PowerShell
- [x] PowerShell 7.4+ constructs used exclusively
  - Composite action uses GitHub-Script which runs PowerShell 7.4+
- [x] Matrix testing across Linux, macOS, Windows included
  - N/A: Action runs on ubuntu-latest only (per requirements FR-016)
- [x] Platform-specific behaviors documented
  - Documented: ubuntu-latest runner requirement
- [x] Skip mechanisms justified if platform-specific tests needed
  - N/A: Single platform by design
- [x] No backward compatibility with PowerShell 5.1 required
  - PowerShell 7.4+ only

### IV. Quality Gates and Observability
- [x] Test results captured in structured JSON format
  - Integration test results via Test-ModuleLocal workflow
- [x] Code coverage measurement included
  - N/A for GitHub Actions YAML (coverage applies to PowerShell scripts)
- [x] Linting results captured and enforced
  - YAML linting for action.yml structure
- [x] Quality gate thresholds defined
  - Test-ModuleLocal workflow must pass with composite action
- [x] Clear error messages planned
  - FR-006, FR-007 specify error handling and messages
- [x] Debug mode support included
  - Debug input parameter specified in FR-012

### V. Continuous Delivery with Semantic Versioning
- [x] Version bump strategy documented (labels, SemVer)
  - Follows Process-PSModule release workflow
- [x] Release automation compatible with existing workflow
  - Changes integrated into existing Process-PSModule versioning
- [x] Documentation updates included
  - README and workflow documentation updates planned
- [x] GitHub Pages publishing considered if docs changes
  - Documentation updates will be published via existing docs workflow

## Project Structure

### Documentation (this feature)
```
specs/001-building-on-this/
├── spec.md              # Feature specification (already exists)
├── plan.md              # This file (/plan command output)
├── research.md          # Phase 0 output (/plan command)
├── data-model.md        # Phase 1 output (/plan command)
├── quickstart.md        # Phase 1 output (/plan command)
├── contracts/           # Phase 1 output (/plan command)
└── tasks.md             # Phase 2 output (/tasks command - NOT created by /plan)
```

### Source Code (repository root)
```
Process-PSModule/
├── .github/
│   ├── actions/
│   │   └── setup-test/        # NEW: Composite action for BeforeAll/AfterAll
│   │       └── action.yml     # Composite action definition
│   └── workflows/
│       ├── Test-ModuleLocal.yml  # MODIFIED: Use setup-test composite action
│       └── ci.yml                # NO CHANGE: Calls Test-ModuleLocal.yml
├── specs/
│   └── 001-building-on-this/
│       └── [documentation files as above]
└── tests/
    └── [test files for validating composite action behavior]
```

**Structure Decision**: This is a GitHub Actions workflow enhancement within the Process-PSModule framework. The structure follows the standard Process-PSModule repository layout with additions to `.github/actions/` for the new composite action and modifications to `.github/workflows/Test-ModuleLocal.yml` to consume the action. The composite action is a local action (not published separately) located within the Process-PSModule repository structure.

## Phase 0: Outline & Research
1. **Extract unknowns from Technical Context** above:
   - All technical context items are resolved (no NEEDS CLARIFICATION)
   - Composite action structure and syntax patterns needed
   - Error handling patterns for composite actions
   - Best practices for mode-based behavior in actions
   - Integration patterns with existing PSModule actions

2. **Generate and dispatch research agents**:
   ```
   Task 1: "Research GitHub composite action structure and syntax best practices"
   Task 2: "Research error handling patterns in GitHub composite actions (continue-on-error, fail-fast)"
   Task 3: "Research mode/parameter-based behavior patterns in reusable actions"
   Task 4: "Research integration patterns for PSModule/GitHub-Script and PSModule/Install-PSModuleHelpers"
   Task 5: "Review current Test-ModuleLocal.yml BeforeAll/AfterAll implementation for exact behavior"
   ```

3. **Consolidate findings** in `research.md` using format:
   - Decision: [what was chosen]
   - Rationale: [why chosen]
   - Alternatives considered: [what else evaluated]

**Output**: research.md with all technical decisions documented

## Phase 1: Design & Contracts
*Prerequisites: research.md complete*

1. **Extract entities from feature spec** → `data-model.md`:
   - Entity: Setup-Test composite action (inputs, environment variables, behavior contract)
   - Entity: Test script files (BeforeAll.ps1, AfterAll.ps1, script contract)
   - Entity: Workflow integration contract (job dependencies, data flow)
   - Validation rules for inputs and runtime checks
   - State transitions for execution flow

2. **Generate API contracts** from functional requirements:
   - action.yml contract: Composite action definition with inputs/outputs
   - script-implementation.md contract: Embedded PowerShell script specification
   - workflow-integration.md contract: Test-ModuleLocal.yml integration changes
   - Output to `/contracts/` directory

3. **Generate contract tests** from contracts:
   - Test scenarios defined in quickstart.md
   - Integration tests via Test-ModuleLocal.yml execution
   - Validation checklist for each scenario

4. **Extract test scenarios** from user stories:
   - Scenario 1: Happy path (all scripts present and succeed)
   - Scenario 2: No tests directory
   - Scenario 3: No BeforeAll.ps1 script
   - Scenario 4: No AfterAll.ps1 script
   - Scenario 5: BeforeAll.ps1 fails
   - Scenario 6: AfterAll.ps1 fails
   - Scenario 7: Test-ModuleLocal fails but AfterAll runs

5. **Update agent file incrementally** (O(1) operation):
   - Executed: `.specify/scripts/powershell/update-agent-context.ps1 -AgentType copilot`
   - Created: `.github/copilot-instructions.md`
   - Added: Language (PowerShell 7.4+), Framework (PSModule actions), Database (N/A)

**Output**: ✅ data-model.md, /contracts/*, quickstart.md, .github/copilot-instructions.md created

## Phase 2: Task Planning Approach
*This section describes what the /tasks command will do - DO NOT execute during /plan*

**Task Generation Strategy**:
The /tasks command will load `.specify/templates/tasks-template.md` and generate ordered tasks from Phase 1 design artifacts:

**From data-model.md**:
- Task: Create `.github/actions/setup-test/` directory structure
- Task: Define composite action inputs/outputs structure
- Task: Implement mode parameter validation logic
- Task: Implement environment variable pass-through mechanism

**From contracts/action.yml.md**:
- Task: Create `.github/actions/setup-test/action.yml` file [P]
- Task: Define action metadata (name, description, author)
- Task: Define inputs section with all required/optional inputs [P]
- Task: Implement composite action steps (Install-PSModuleHelpers, GitHub-Script)
- Task: Embed PowerShell script from script-implementation.md contract

**From contracts/script-implementation.md**:
- Task: Implement mode validation (before/after) in PowerShell script [P]
- Task: Implement tests directory discovery logic [P]
- Task: Implement script file discovery (BeforeAll.ps1/AfterAll.ps1) [P]
- Task: Implement mode="before" execution with error propagation
- Task: Implement mode="after" execution with warning-only errors
- Task: Implement Push-Location/Pop-Location with finally block
- Task: Implement LogGroup output formatting

**From contracts/workflow-integration.md**:
- Task: Update BeforeAll-ModuleLocal job in Test-ModuleLocal.yml
- Task: Update AfterAll-ModuleLocal job in Test-ModuleLocal.yml
- Task: Verify job dependency chain preserved (BeforeAll → Test → AfterAll)
- Task: Verify if: always() conditions preserved
- Task: Verify secrets pass-through preserved

**From quickstart.md**:
- Task: Create test repository with tests/ directory for validation
- Task: Create BeforeAll.ps1 test script that succeeds
- Task: Create AfterAll.ps1 test script that succeeds
- Task: Validate Scenario 1: Happy path (all scripts present) [Integration Test]
- Task: Validate Scenario 2: No tests directory [Integration Test]
- Task: Validate Scenario 3: No BeforeAll.ps1 [Integration Test]
- Task: Validate Scenario 4: No AfterAll.ps1 [Integration Test]
- Task: Validate Scenario 5: BeforeAll.ps1 fails [Integration Test]
- Task: Validate Scenario 6: AfterAll.ps1 fails [Integration Test]
- Task: Validate Scenario 7: Test-ModuleLocal fails but AfterAll runs [Integration Test]

**From documentation requirements**:
- Task: Update Process-PSModule README with composite action documentation
- Task: Create comprehensive BeforeAll/AfterAll usage documentation explaining:
  * Intended purpose: external test resource setup (cloud infrastructure, external databases, third-party services via APIs)
  * Clear distinction: external resources in BeforeAll/AfterAll vs. test-specific resources within tests
  * Examples: deploying Azure resources, initializing external databases, creating test data in SaaS platforms
  * Guidance on when to use BeforeAll/AfterAll vs. in-test setup for OS/platform-specific resources
- Task: Update Template-PSModule with example BeforeAll/AfterAll scripts showing external resource management
- Task: Create migration guide for nested script consolidation
- Task: Update .github/copilot-instructions.md (already done in Phase 1)

**Ordering Strategy**:
1. **TDD Order**: Tests/contracts before implementation
   - Create test repository structure first
   - Define contracts before implementing
2. **Dependency Order**: Foundation before dependent components
   - Directory structure → action.yml → PowerShell script → workflow integration
3. **Parallel Execution**: Mark independent tasks with [P]
   - action.yml structure and script logic can be developed in parallel
   - Different test scenarios can be validated in parallel

**Estimated Task Count**: ~32-37 tasks
- Setup: 2 tasks (directory structure, test repository)
- Composite Action: 8-10 tasks (action.yml, script implementation)
- Workflow Integration: 4 tasks (modify jobs, verify dependencies)
- Testing: 7 tasks (integration test scenarios)
- Documentation: 6 tasks (README, usage documentation, examples, migration guide, templates)

**Task Priorities**:
- P0 (Critical Path): Composite action implementation, workflow integration
- P1 (High): Core test scenarios (1, 5, 6, 7)
- P2 (Medium): Edge case scenarios (2, 3, 4)
- P3 (Low): Documentation and migration guides

**IMPORTANT**: This phase is executed by the /tasks command, NOT by /plan

## Phase 3+: Future Implementation
*These phases are beyond the scope of the /plan command*

**Phase 3**: Task execution (/tasks command creates tasks.md)
**Phase 4**: Implementation (execute tasks.md following constitutional principles)
**Phase 5**: Validation (run tests, execute quickstart.md, performance validation)

## Complexity Tracking
*Fill ONLY if Constitution Check has violations that must be justified*

**Status**: ✅ No constitutional violations identified

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| None | N/A | N/A |

All constitutional requirements are satisfied:
- Workflow-first design: Composite action is a reusable GitHub Actions component
- Test-driven development: Integration tests defined in quickstart.md
- Platform independence: PowerShell 7.4+ on ubuntu-latest (per requirements)
- Quality gates: Testing and validation strategies defined
- Continuous delivery: Follows existing Process-PSModule release workflow


## Progress Tracking
*This checklist is updated during execution flow*

**Phase Status**:
- [x] Phase 0: Research complete (/plan command)
- [x] Phase 1: Design complete (/plan command)
- [x] Phase 2: Task planning approach described (/plan command)
- [ ] Phase 3: Tasks generated (/tasks command - NOT executed)
- [ ] Phase 4: Implementation complete
- [ ] Phase 5: Validation passed

**Gate Status**:
- [x] Initial Constitution Check: PASS (all requirements met)
- [x] Post-Design Constitution Check: PASS (no new violations)
- [x] All NEEDS CLARIFICATION resolved (none existed)
- [x] Complexity deviations documented (None - all constitutional requirements satisfied)

---
*Based on Constitution v1.3.0 - See `.specify/memory/constitution.md`*
