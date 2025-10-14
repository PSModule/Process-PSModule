# Implementation Plan: Settings-Driven Workflow Configuration

**Branch**: `001-settings-driven-workflow` | **Date**: October 14, 2025 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-settings-driven-workflow/spec.md`

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

Implement a centralized configuration system for Process-PSModule workflows that eliminates scattered hardcoded values and reduces the complexity of conditional if: statements by at least 50%. The system will provide a single authoritative configuration file that makes settings available throughout the workflow via environment variables or step inputs, supporting hierarchical configuration with environment-specific overrides.

## Technical Context

| Aspect | Details |
|--------|---------|
| **Language/Version** | PowerShell 7.4+ |
| **Primary Dependencies** | GitHub Actions, PSModule framework actions (Build-PSModule, Test-ModuleLocal, etc.) |
| **Storage** | Configuration files (YAML/JSON/PSData) in `.github/PSModule.yml` |
| **Testing** | Pester for workflow validation, PSScriptAnalyzer for code quality |
| **Target Platform** | GitHub Actions execution environment (Linux, macOS, Windows runners) |
| **Project Type** | Workflow framework (Process-PSModule) |
| **Performance Goals** | Configuration loading within 10 seconds, workflow execution efficiency |
| **Constraints** | Must work within GitHub Actions syntax, support YAML/JSON/PSData formats, maintain backward compatibility |
| **Scale/Scope** | Single repository configuration, extensible to multiple consuming repositories |

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
specs/001-settings-driven-workflow/
├── plan.md              # This file (/plan command output)
├── research.md          # Phase 0 output (/plan command)
├── data-model.md        # Phase 1 output (/plan command)
├── quickstart.md        # Phase 1 output (/plan command)
├── contracts/           # Phase 1 output (/plan command)
└── tasks.md             # Phase 2 output (/tasks command - NOT created by /plan)
```

### Source Code (Process-PSModule framework)

This feature modifies the existing Process-PSModule framework structure by adding configuration management capabilities:

```plaintext
.github/
├── workflows/
│   ├── workflow.yml                    # Main workflow (MODIFIED: add configuration loading)
│   └── ci.yml                         # CI validation (MODIFIED: add config validation)
└── PSModule.example.yml               # Example configuration file (NEW)

.specify/
├── scripts/
│   └── powershell/
│       ├── Get-Settings.ps1           # NEW: Configuration loading action
│       └── Test-Configuration.ps1     # NEW: Configuration validation action
└── templates/
    └── PSModule.yml                   # NEW: Configuration template

src/                                  # Framework actions (MODIFIED)
├── actions/
│   ├── Get-Settings/                 # NEW: Configuration management action
│   │   ├── action.yml
│   │   └── Get-Settings.ps1
│   └── Test-Configuration/           # NEW: Configuration validation action
│       ├── action.yml
│       └── Test-Configuration.ps1
└── workflows/
    ├── workflow.yml                  # MODIFIED: Integrate configuration loading
    └── ci.yml                        # MODIFIED: Add configuration validation

tests/                                # Framework tests (MODIFIED)
├── Get-Settings.Tests.ps1            # NEW: Configuration loading tests
├── Test-Configuration.Tests.ps1      # NEW: Configuration validation tests
└── workflow-tests/                   # MODIFIED: Update workflow integration tests
```

**Structure Decision**: This feature extends the existing Process-PSModule framework by adding centralized configuration management. The implementation follows the established framework patterns with new actions for configuration loading and validation, integrated into the main workflow.

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

- Load `.specify/templates/tasks-template.md` as base
- Generate tasks from Phase 1 design docs (configuration schema, data model, quickstart)
- Each configuration entity → implementation task [P]
- Each API contract → test task [P]
- Each workflow integration → modification task
- Schema validation → dedicated task
- Documentation updates → separate tasks

**Ordering Strategy**:

- Foundation first: Configuration schema and validation
- Core implementation: Get-Settings and Test-Configuration actions
- Integration: Workflow modifications and testing
- Documentation: README and example updates
- Mark [P] for parallel execution (independent files/components)

**Specific Task Categories**:

1. **Configuration Schema Tasks** [Priority: High]
   - Create JSON schema file for configuration validation
   - Implement schema versioning and migration
   - Add schema documentation and examples

2. **Action Implementation Tasks** [Priority: High]
   - Create Get-Settings composite action
   - Create Test-Configuration composite action
   - Implement YAML/JSON/PSData parsing
   - Add environment variable export logic

3. **Workflow Integration Tasks** [Priority: Medium]
   - Modify main workflow.yml to use configuration
   - Update CI workflow for configuration validation
   - Add configuration loading to all relevant jobs
   - Implement environment detection logic

4. **Testing Tasks** [Priority: High]
   - Create unit tests for configuration parsing
   - Create integration tests for workflow execution
   - Add schema validation tests
   - Implement cross-platform testing

5. **Documentation Tasks** [Priority: Low]
   - Update README with configuration examples
   - Create configuration template files
   - Add troubleshooting guides
   - Update action documentation

**Estimated Output**: 20-25 numbered, ordered tasks in tasks.md focusing on TDD implementation of configuration management

**IMPORTANT**: This phase is executed by the /tasks command, NOT by /plan

**Estimated Output**: 25-30 numbered, ordered tasks in tasks.md

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
- [ ] Phase 2: Task planning complete (/plan command - describe approach only)
- [ ] Phase 3: Tasks generated (/tasks command)
- [ ] Phase 4: Implementation complete
- [ ] Phase 5: Validation passed

**Gate Status**:

- [x] Initial Constitution Check: PASS
- [x] Post-Design Constitution Check: PASS
- [x] All NEEDS CLARIFICATION resolved
- [ ] Complexity deviations documented

---
*Based on Constitution - See `.specify/memory/constitution.md`*
