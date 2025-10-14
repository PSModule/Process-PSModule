# Data Model: Settings-Driven Workflow Configuration

## Overview

The settings-driven workflow configuration system introduces a hierarchical configuration model that centralizes all Process-PSModule workflow settings into a single, authoritative source. This model supports environment-specific overrides and provides type-safe configuration validation.

## Core Entities

### Configuration File

**Entity: ConfigurationFile**
- **Purpose:** Root container for all workflow settings
- **Format:** YAML (primary), JSON, or PowerShell Data (PSD1)
- **Location:** `.github/PSModule.yml` (or `.json`/`.psd1`)
- **Validation:** Schema-based validation with clear error messages

**Properties:**
- `version`: String (semantic version of configuration schema)
- `workflows`: Object (workflow-specific settings)
- `environments`: Object (environment-specific overrides)
- `defaults`: Object (fallback values)

### Workflow Configuration

**Entity: WorkflowConfig**
- **Purpose:** Settings for a specific workflow execution
- **Scope:** Applied to individual workflow runs
- **Inheritance:** Can inherit from global defaults

**Properties:**
- `name`: String (workflow identifier)
- `enabled`: Boolean (whether workflow is active)
- `triggers`: Array<String> (GitHub event triggers)
- `matrix`: Object (test matrix configuration)
- `steps`: Array<StepConfig> (workflow step settings)

### Environment Override

**Entity: EnvironmentOverride**
- **Purpose:** Environment-specific configuration values
- **Scope:** Applied based on deployment environment
- **Precedence:** Overrides base configuration values

**Properties:**
- `name`: String (environment identifier: development, staging, production)
- `variables`: Object (environment-specific variables)
- `secrets`: Object (references to GitHub secrets)
- `matrix`: Object (environment-specific test matrix)

### Step Configuration

**Entity: StepConfig**
- **Purpose:** Configuration for individual workflow steps
- **Scope:** Applied to specific GitHub Actions steps
- **Flexibility:** Supports conditional execution and parameterization

**Properties:**
- `name`: String (step identifier)
- `action`: String (GitHub Action reference)
- `inputs`: Object (action input parameters)
- `conditions`: Array<String> (execution conditions)
- `timeout`: Number (step timeout in minutes)

## Data Relationships

### Configuration Hierarchy

```
ConfigurationFile (root)
├── defaults (global fallbacks)
├── workflows[] (workflow-specific settings)
│   └── steps[] (step configurations)
└── environments[] (environment overrides)
    ├── variables (env-specific values)
    ├── secrets (secure references)
    └── matrix (env-specific testing)
```

### Inheritance Rules

1. **Base Configuration:** Default values from `defaults` section
2. **Workflow Override:** Workflow-specific settings override defaults
3. **Environment Override:** Environment settings override workflow settings
4. **Runtime Override:** Command-line or trigger inputs override all above

### Validation Rules

**Required Fields:**
- `version`: Must be valid semantic version
- At least one workflow configuration
- Valid GitHub Actions syntax in step configurations

**Type Constraints:**
- `enabled`: Must be boolean
- `timeout`: Must be positive integer
- `triggers`: Must be valid GitHub event names
- `matrix`: Must follow GitHub Actions matrix syntax

**Cross-Reference Validation:**
- Referenced actions must exist in marketplace or repository
- Secret references must exist in GitHub Secrets
- Environment names must be valid deployment targets

## Data Flow

### Configuration Loading Process

1. **Discovery:** Locate configuration file in `.github/` directory
2. **Parsing:** Parse YAML/JSON/PSData into PowerShell objects
3. **Validation:** Apply schema validation and business rules
4. **Environment Selection:** Determine active environment based on context
5. **Merge:** Combine base config with environment overrides
6. **Export:** Make configuration available as environment variables

### Runtime Data Flow

```
Repository Context → Configuration Loader → Validation → Environment Merge → Workflow Execution
       ↓                    ↓              ↓              ↓              ↓
   Branch/PR Info     YAML Parser     Schema Check   Override Logic   Step Inputs
```

## Error Handling

### Configuration Errors

**Invalid Syntax:**
- **Detection:** YAML/JSON parsing failures
- **Response:** Fail workflow with syntax error details
- **Recovery:** Suggest configuration fixes

**Missing Required Fields:**
- **Detection:** Schema validation failures
- **Response:** List all missing required fields
- **Recovery:** Provide configuration template

**Invalid References:**
- **Detection:** Cross-reference validation
- **Response:** Identify invalid action/secret references
- **Recovery:** Suggest valid alternatives

### Runtime Errors

**Environment Variable Conflicts:**
- **Detection:** Duplicate environment variable names
- **Response:** Warn and use last-defined value
- **Recovery:** Document override behavior

**Type Conversion Failures:**
- **Detection:** Invalid type conversions
- **Response:** Fail with type error details
- **Recovery:** Validate configuration types

## Security Model

### Data Protection

**Sensitive Data Handling:**
- Configuration files: Public, no secrets allowed
- Secrets: Referenced via GitHub Secrets mechanism
- Logging: Sensitive values masked in output

**Access Control:**
- Configuration files: Readable by all repository collaborators
- Secrets: Controlled by repository permissions
- Validation: Runs in unprivileged workflow context

### Audit Trail

**Change Tracking:**
- Configuration changes tracked in git history
- Validation results logged in workflow runs
- Override applications documented in debug logs

## Migration Path

### Backward Compatibility

**Legacy Support:**
- Workflows without configuration files continue to work
- Default values provided for all optional settings
- Gradual migration with feature flags

**Migration Steps:**
1. Create configuration file with current hardcoded values
2. Replace hardcoded values with configuration references
3. Test configuration loading and validation
4. Remove legacy hardcoded values

### Versioning Strategy

**Configuration Schema Versions:**
- Semantic versioning for breaking changes
- Backward compatibility within major versions
- Migration guides for major version upgrades

**Deprecation Policy:**
- Deprecated settings warned in validation
- Removal announced in release notes
- Migration tools provided for complex changes