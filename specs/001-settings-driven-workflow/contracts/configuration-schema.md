# Configuration Schema Contract

## Overview

This contract defines the schema for Process-PSModule configuration files. The schema ensures type safety, validation, and consistent structure across all consuming repositories.

## Schema Definition

### Root Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://raw.githubusercontent.com/PSModule/Process-PSModule/main/schemas/configuration.schema.json",
  "title": "Process-PSModule Configuration",
  "description": "Configuration schema for Process-PSModule workflows",
  "type": "object",
  "properties": {
    "version": {
      "type": "string",
      "pattern": "^\\d+\\.\\d+\\.\\d+$",
      "description": "Configuration schema version (semantic versioning)"
    },
    "workflows": {
      "type": "object",
      "description": "Workflow-specific configurations",
      "patternProperties": {
        "^[a-zA-Z][a-zA-Z0-9_-]*$": {
          "$ref": "#/definitions/WorkflowConfig"
        }
      }
    },
    "environments": {
      "type": "object",
      "description": "Environment-specific overrides",
      "patternProperties": {
        "^[a-zA-Z][a-zA-Z0-9_-]*$": {
          "$ref": "#/definitions/EnvironmentConfig"
        }
      }
    },
    "defaults": {
      "type": "object",
      "description": "Global default values",
      "properties": {
        "timeout": {
          "type": "integer",
          "minimum": 1,
          "maximum": 3600,
          "description": "Default step timeout in minutes"
        },
        "retries": {
          "type": "integer",
          "minimum": 0,
          "maximum": 10,
          "description": "Default retry count for failed steps"
        },
        "concurrency": {
          "type": "integer",
          "minimum": 1,
          "maximum": 100,
          "description": "Default concurrency limit"
        }
      }
    }
  },
  "required": ["version"],
  "additionalProperties": false,
  "definitions": {
    "WorkflowConfig": {
      "type": "object",
      "properties": {
        "enabled": {
          "type": "boolean",
          "description": "Whether this workflow is enabled",
          "default": true
        },
        "triggers": {
          "type": "array",
          "items": {
            "type": "string",
            "enum": ["push", "pull_request", "pull_request_target", "schedule", "workflow_dispatch", "release"]
          },
          "description": "GitHub events that trigger this workflow"
        },
        "matrix": {
          "type": "object",
          "description": "Test matrix configuration",
          "properties": {
            "os": {
              "type": "array",
              "items": {
                "type": "string",
                "enum": ["ubuntu-latest", "windows-latest", "macos-latest"]
              }
            },
            "powershell": {
              "type": "array",
              "items": {
                "type": "string",
                "pattern": "^7\\.[4-9]\\.\\d+$"
              }
            }
          }
        },
        "steps": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/StepConfig"
          },
          "description": "Custom step configurations"
        }
      },
      "additionalProperties": false
    },
    "EnvironmentConfig": {
      "type": "object",
      "properties": {
        "variables": {
          "type": "object",
          "description": "Environment-specific variables",
          "patternProperties": {
            "^[A-Z][A-Z0-9_]*$": {
              "type": "string"
            }
          }
        },
        "secrets": {
          "type": "object",
          "description": "References to GitHub secrets",
          "patternProperties": {
            "^[A-Z][A-Z0-9_]*$": {
              "type": "string"
            }
          }
        },
        "matrix": {
          "type": "object",
          "description": "Environment-specific matrix overrides"
        }
      },
      "additionalProperties": false
    },
    "StepConfig": {
      "type": "object",
      "properties": {
        "name": {
          "type": "string",
          "description": "Step identifier"
        },
        "action": {
          "type": "string",
          "description": "GitHub Action reference (owner/repo@version)",
          "pattern": "^[^@]+@[^@]+$"
        },
        "inputs": {
          "type": "object",
          "description": "Action input parameters"
        },
        "conditions": {
          "type": "array",
          "items": {
            "type": "string"
          },
          "description": "Conditional execution expressions"
        },
        "timeout": {
          "type": "integer",
          "minimum": 1,
          "maximum": 3600,
          "description": "Step timeout in minutes"
        }
      },
      "required": ["name", "action"],
      "additionalProperties": false
    }
  }
}
```

## API Contract

### Configuration Loading API

**Endpoint:** `Get-Settings` Action

**Input Parameters:**
- `config-file`: Path to configuration file (default: `.github/PSModule.yml`)
- `environment`: Target environment (default: auto-detected)
- `strict-validation`: Enable strict schema validation (default: true)

**Output Parameters:**
- `config-json`: Complete configuration as JSON string
- `config-version`: Configuration schema version
- `environment-name`: Detected/active environment
- `validation-errors`: JSON array of validation errors (if any)

**Environment Variables:**
All configuration values exported as `PSMODULE_CONFIG_*` prefixed variables

### Configuration Validation API

**Endpoint:** `Test-Configuration` Action

**Input Parameters:**
- `config-file`: Path to configuration file
- `schema-file`: Path to JSON schema file
- `output-format`: Validation output format (json, text, junit)

**Output Parameters:**
- `is-valid`: Boolean indicating configuration validity
- `error-count`: Number of validation errors
- `warning-count`: Number of validation warnings
- `validation-report`: Detailed validation report

## Error Response Contract

### Validation Error Format

```json
{
  "errors": [
    {
      "type": "schema",
      "field": "workflows.build.steps[0].timeout",
      "message": "Value must be between 1 and 3600",
      "severity": "error",
      "line": 45,
      "column": 12
    }
  ],
  "warnings": [
    {
      "type": "deprecated",
      "field": "workflows.build.legacySetting",
      "message": "This setting is deprecated and will be removed in v2.0.0",
      "severity": "warning"
    }
  ],
  "summary": {
    "totalErrors": 1,
    "totalWarnings": 1,
    "isValid": false
  }
}
```

### Runtime Error Format

```json
{
  "error": {
    "code": "CONFIG_LOAD_FAILED",
    "message": "Failed to load configuration file",
    "details": {
      "file": ".github/PSModule.yml",
      "reason": "File not found or inaccessible"
    },
    "suggestions": [
      "Ensure .github/PSModule.yml exists in the repository",
      "Check file permissions and repository access"
    ]
  }
}
```

## Version Compatibility

### Schema Version Matrix

| Schema Version | PSModule Version | Breaking Changes | Migration Guide |
|----------------|------------------|------------------|-----------------|
| 1.0.0 | v4.x | Initial release | N/A |
| 1.1.0 | v4.1+ | Added environment overrides | [Migration Guide](migration-1.0-to-1.1.md) |
| 2.0.0 | v5.x | Removed deprecated fields | [Migration Guide](migration-1.x-to-2.0.md) |

### Backward Compatibility Rules

- Minor version increments: Additive changes only
- Major version increments: Breaking changes allowed
- Deprecated fields: Warned for one major version before removal
- Migration tools: Provided for complex schema changes

## Testing Contract

### Configuration Test Scenarios

**Valid Configurations:**
- Minimal configuration with required fields
- Full configuration with all optional fields
- Environment-specific overrides
- Matrix configurations for all platforms

**Invalid Configurations:**
- Missing required fields
- Invalid data types
- Malformed YAML/JSON
- Invalid GitHub Actions references
- Circular references

**Edge Cases:**
- Empty configuration files
- Very large configuration files (>1MB)
- Special characters in field names
- Unicode content
- Comments in YAML files

### Validation Test Contract

**Test Case Format:**
```yaml
test-case:
  name: "Valid minimal configuration"
  input: ".github/test-config.yml"
  expected:
    valid: true
    errors: []
    warnings: []
  environment: "development"
```

**Coverage Requirements:**
- 100% schema field coverage
- All validation rules tested
- Error message accuracy
- Performance benchmarks met