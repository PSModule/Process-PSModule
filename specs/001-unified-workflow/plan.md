# Implementation Plan: Unified CI/CD Workflow for PowerShell Modules

**Branch**: `001-unified-workflow` | **Date**: 2025-10-02 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-unified-workflow/spec.md`

## Execution Flow (/plan command scope)

1. Load feature spec from Input path
   → If not found: ERROR "No feature spec at {path}"
2. Fill Technical Context (scan for NEEDS CLARIFICATION)
   → Detect Project Type from file system structure or context (web=frontend+backend, mobile=app+API)
   → Set Structure Decision based on project type
3. Fill the Constitution Check section based on the content of the constitution document.
4. Evaluate Constitution Check section below
   → If violations exist: Document them in Complexity Tracking
   → If no justification is possible: ERROR "Simplify approach first"
   → Update Progress Tracking: Initial Constitution Check
5. Execute Phase 0 → research.md
   → If NEEDS CLARIFICATION remain: ERROR "Resolve unknowns"
6. Execute Phase 1 → contracts, data-model.md, quickstart.md, agent-specific template file (e.g., `CLAUDE.md` for Claude Code, `.github/copilot-instructions.md` for GitHub Copilot, `GEMINI.md` for Gemini CLI, `QWEN.md` for Qwen Code or `AGENTS.md` for opencode).
7. Re-evaluate Constitution Check section
   → If new violations: Refactor design, return to Phase 1
   → Update Progress Tracking: Post-Design Constitution Check
8. Plan Phase 2 → Describe task generation approach (DO NOT create tasks.md)
9. STOP - Ready for /tasks command

**IMPORTANT**: The /plan command STOPS at step 7. Phases 2-4 are executed by other commands:

- Phase 2: /tasks command creates tasks.md
- Phase 3-4: Implementation execution (manual or via tools)

## Summary

Consolidate the separate CI.yml and workflow.yml files into a single unified workflow.yml that handles both pull request testing and release publishing. This breaking change simplifies repository configuration by reducing the number of workflow files from two to one while maintaining all existing functionality. The unified workflow uses conditional logic based on GitHub event triggers to determine whether to run tests only (PR context) or tests followed by publishing (main branch context after merge). This change requires consuming repositories to delete CI.yml and update any external references or automated processes that depend on it.

## Technical Context

| Aspect | Details |
|--------|---------|
| **Language/Version** | PowerShell 7.4+, GitHub Actions YAML |
| **Primary Dependencies** | GitHub Actions (workflow_call), PSModule composite actions, GitHub CLI |
| **Storage** | N/A (stateless CI/CD workflows) |
| **Testing** | Pester 5.x, PSScriptAnalyzer, CI validation workflow |
| **Target Platform** | GitHub Actions runners (ubuntu-latest, windows-latest, macos-latest) |
| **Project Type** | Single project (GitHub Actions reusable workflow framework) |
| **Performance Goals** | Workflow execution under 10 minutes for typical module |
| **Constraints** | Breaking change (CI.yml deletion), must maintain backward compatibility with existing test/publish processes |
| **Scale/Scope** | Framework used by multiple consuming repositories, affects all PSModule organization repos |

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. Workflow-First Design (NON-NEGOTIABLE)

- [x] Feature is implemented as reusable GitHub Actions workflow(s)
- [x] Workflows have clearly defined inputs and outputs
- [x] Workflows follow single responsibility principle
- [x] Matrix strategies used for parallel execution where appropriate
- [x] Workflows are independently testable via CI validation workflow
- [x] Logic delegated to reusable GitHub Actions (PSModule organization)
- [x] Inline PowerShell code avoided; action-based scripts used instead
- [x] Actions referenced by specific versions/tags

### II. Test-Driven Development (NON-NEGOTIABLE)

- [x] Tests will be written before implementation
- [x] Initial tests will fail (Red phase documented)
- [x] Implementation plan includes making tests pass (Green phase)
- [x] Refactoring phase planned while maintaining tests
- [x] PSScriptAnalyzer validation included
- [x] Manual testing documented if needed
- [x] CI validation workflow tests included

### III. Platform Independence with Modern PowerShell

- [x] PowerShell 7.4+ constructs used exclusively
- [x] Matrix testing across Linux, macOS, Windows included
- [x] Platform-specific behaviors documented
- [x] Skip mechanisms justified if platform-specific tests needed
- [x] No backward compatibility with PowerShell 5.1 required

### IV. Quality Gates and Observability

- [x] Test results captured in structured JSON format
- [x] Code coverage measurement included
- [x] Linting results captured and enforced
- [x] Quality gate thresholds defined
- [x] Clear error messages planned
- [x] Debug mode support included

### V. Continuous Delivery with Semantic Versioning

- [x] Version bump strategy documented (labels, SemVer)
- [x] Release automation compatible with existing workflow
- [x] Documentation updates included
- [x] GitHub Pages publishing considered if docs changes

## Project Structure

### Documentation (this feature)

```plaintext
specs/[###-feature]/
├── plan.md              # This file (/plan command output)
├── research.md          # Phase 0 output (/plan command)
├── data-model.md        # Phase 1 output (/plan command)
├── quickstart.md        # Phase 1 output (/plan command)
├── contracts/           # Phase 1 output (/plan command)
└── tasks.md             # Phase 2 output (/tasks command - NOT created by /plan)
```

### Source Code (repository root)

```plaintext
.github/
├── workflows/
│   ├── workflow.yml          # MODIFIED: Unified workflow (consolidates CI.yml functionality)
│   ├── CI.yml                # DELETED: Functionality moved to workflow.yml
│   ├── Get-Settings.yml      # Existing: Used by both workflows
│   ├── Build-Module.yml      # Existing: Called by unified workflow
│   ├── Build-Docs.yml        # Existing: Called by unified workflow
│   ├── Build-Site.yml        # Existing: Called by unified workflow
│   ├── Test-SourceCode.yml   # Existing: Called by unified workflow
│   ├── Lint-SourceCode.yml   # Existing: Called by unified workflow
│   ├── Test-Module.yml       # Existing: Called by unified workflow
│   ├── Test-ModuleLocal.yml  # Existing: Called by unified workflow
│   ├── Get-TestResults.yml   # Existing: Called by unified workflow
│   ├── Get-CodeCoverage.yml  # Existing: Called by unified workflow
│   ├── Publish-Module.yml    # Existing: Called by unified workflow (optional, may not exist yet)
│   └── Publish-Site.yml      # Existing: Called by unified workflow (optional, may not exist yet)
├── PSModule.yml              # Existing: Configuration file
└── README.md                 # MODIFIED: Documentation updated

tests/
├── srcTestRepo/              # Existing test repository
└── srcWithManifestTestRepo/  # Existing test repository with manifest

docs/
└── README.md                 # MODIFIED: Migration guide added
```

**Structure Decision**: This is a GitHub Actions workflow framework modification. The structure focuses on consolidating workflow.yml and CI.yml into a single unified workflow.yml file while maintaining all existing reusable workflow components. The change affects the .github/workflows/ directory primarily, with documentation updates required.

## Phase 0: Outline & Research

1. **Extract unknowns from Technical Context** above:
   - For each NEEDS CLARIFICATION → research task
   - For each dependency → best practices task
   - For each integration → patterns task
2. **Generate and dispatch research agents**:
   ```plaintext
   For each unknown in Technical Context:
     Task: "Research {unknown} for {feature context}"
   For each technology choice:
     Task: "Find best practices for {tech} in {domain}"
   ```
3. **Consolidate findings** in `research.md` using format:
   - Decision: [what was chosen]
   - Rationale: [why chosen]
   - Alternatives considered: [what else evaluated]

**Output**: research.md with all NEEDS CLARIFICATION resolved

## Phase 1: Design & Contracts

*Prerequisites: research.md complete*

1. **Extract entities from feature spec** → `data-model.md`:
   - Entity name, fields, relationships
   - Validation rules from requirements
   - State transitions if applicable
2. **Generate API contracts** from functional requirements:
   - For each user action → endpoint
   - Use standard REST/GraphQL patterns
   - Output OpenAPI/GraphQL schema to `/contracts/`
3. **Generate contract tests** from contracts:
   - One test file per endpoint
   - Assert request/response schemas
   - Tests must fail (no implementation yet)
4. **Extract test scenarios** from user stories:
   - Each story → integration test scenario
   - Quickstart test = story validation steps
5. **Update agent file incrementally** (O(1) operation):
   - Run `.specify/scripts/powershell/update-agent-context.ps1 -AgentType copilot`
     **IMPORTANT**: Execute it exactly as specified above. Do not add or remove any arguments.
   - If exists: Add only NEW tech from current plan
   - Preserve manual additions between markers
   - Update recent changes (keep last 3)
   - Keep under 150 lines for token efficiency
   - Output to repository root

**Output**: data-model.md, /contracts/*, failing tests, quickstart.md, agent-specific file

## Phase 2: Task Planning Approach

*This section describes what the /tasks command will do - DO NOT execute during /plan*

**Task Generation Strategy**:

The /tasks command will generate implementation tasks based on the design artifacts created in Phase 1:

1. **From workflow-contract.md**:
   - Task for updating workflow.yml with unified logic
   - Task for adding concurrency configuration
   - Task for implementing conditional publishing logic
   - Task for deleting CI.yml

2. **From data-model.md**:
   - Task for validating workflow event context handling
   - Task for ensuring job dependency graph correctness
   - Task for testing concurrency group behavior

3. **From quickstart.md**:
   - Integration test task for each test scenario (7 scenarios)
   - Task for documenting manual test procedures
   - Task for creating automated validation tests

4. **From research.md**:
   - Task for documenting migration guide
   - Task for updating README with breaking change notice
   - Task for updating consuming repository documentation

**Ordering Strategy**:

Tasks will be ordered following TDD and dependency principles:

1. **Phase 1: Test Infrastructure** (Parallel where possible)
   - Create test workflow files [P]
   - Define test scenarios as Pester tests [P]
   - Document manual test procedures [P]

2. **Phase 2: Workflow Modification** (Sequential)
   - Add concurrency configuration to workflow.yml
   - Add conditional publishing logic to workflow.yml
   - Update job dependencies and conditions
   - Validate workflow YAML syntax

3. **Phase 3: Testing** (Sequential with parallel sub-tasks)
   - Run automated workflow tests [P]
   - Execute manual test scenarios from quickstart.md
   - Validate concurrency behavior
   - Validate conditional execution

4. **Phase 4: Cleanup and Documentation** (Parallel where possible)
   - Delete CI.yml [P]
   - Update README.md with migration guide [P]
   - Update consuming repository documentation [P]
   - Create release notes [P]

5. **Phase 5: Integration Validation** (Sequential)
   - Test in Process-PSModule repository
   - Test in Template-PSModule repository
   - Validate breaking change impact
   - Final quickstart validation

**Estimated Output**: 20-25 numbered, ordered tasks in tasks.md

**Key Parallelization Opportunities**:
- Test file creation can happen in parallel
- Documentation updates can happen in parallel
- Manual test execution can be distributed

**Critical Path**:
Workflow modification → Testing → Cleanup → Integration validation

**IMPORTANT**: This phase is executed by the /tasks command, NOT by /plan

## Phase 3+: Future Implementation

*These phases are beyond the scope of the /plan command*

**Phase 3**: Task execution (/tasks command creates tasks.md)
**Phase 4**: Implementation (execute tasks.md following constitutional principles)
**Phase 5**: Validation (run tests, execute quickstart.md, performance validation)

## Complexity Tracking

*Fill ONLY if Constitution Check has violations that must be justified*

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |

## Progress Tracking

*This checklist is updated during execution flow*

**Phase Status**:

- [x] Phase 0: Research complete (/plan command)
- [x] Phase 1: Design complete (/plan command)
- [x] Phase 2: Task planning complete (/plan command - describe approach only)
- [ ] Phase 3: Tasks generated (/tasks command)
- [ ] Phase 4: Implementation complete
- [ ] Phase 5: Validation passed

**Gate Status**:

- [x] Initial Constitution Check: PASS
- [x] Post-Design Constitution Check: PASS
- [x] All NEEDS CLARIFICATION resolved
- [x] Complexity deviations documented (N/A - no violations)

---
*Based on Constitution - See `.specify/memory/constitution.md`*
