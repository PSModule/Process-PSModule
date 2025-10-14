# Quickstart: Settings-Driven Workflow Configuration

## Overview

This guide shows how to configure Process-PSModule workflows using the new centralized configuration system. The settings-driven approach eliminates hardcoded values and reduces workflow complexity by at least 50%.

## Prerequisites

- Process-PSModule v4.1+ (with configuration support)
- Repository with PowerShell module structure
- GitHub repository with Actions enabled

## Step 1: Create Configuration File

Create a configuration file in your repository:

```bash
# Create the .github directory if it doesn't exist
mkdir -p .github

# Create the configuration file
touch .github/PSModule.yml
```

## Step 2: Basic Configuration

Add a minimal configuration to `.github/PSModule.yml`:

```yaml
version: "1.0.0"

workflows:
  build:
    enabled: true
    triggers:
      - push
      - pull_request

environments:
  development:
    variables:
      PSMODULE_ENV: "development"
    matrix:
      os: [ubuntu-latest]

  production:
    variables:
      PSMODULE_ENV: "production"
    matrix:
      os: [ubuntu-latest, windows-latest, macos-latest]

defaults:
  timeout: 30
  retries: 2
```

## Step 3: Update Workflow File

Modify your `.github/workflows/Process-PSModule.yml` to use configuration:

```yaml
name: Process-PSModule

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
    types: [opened, synchronize, reopened, labeled]

jobs:
  Process-PSModule:
    uses: PSModule/Process-PSModule/.github/workflows/workflow.yml@v4
    with:
      config-file: .github/PSModule.yml
      environment: development
    secrets:
      APIKEY: ${{ secrets.APIKEY }}
```

## Step 4: Advanced Configuration

### Environment-Specific Settings

```yaml
environments:
  staging:
    variables:
      PSMODULE_LOG_LEVEL: "Debug"
      PSMODULE_TEST_COVERAGE: "80"
    secrets:
      APIKEY: "STAGING_API_KEY"
    matrix:
      os: [ubuntu-latest, windows-latest]

  production:
    variables:
      PSMODULE_LOG_LEVEL: "Error"
      PSMODULE_TEST_COVERAGE: "90"
    secrets:
      APIKEY: "PROD_API_KEY"
    matrix:
      os: [ubuntu-latest, windows-latest, macos-latest]
      powershell: ["7.4.0"]
```

### Workflow-Specific Overrides

```yaml
workflows:
  ci:
    enabled: true
    triggers:
      - push
      - pull_request
    matrix:
      os: [ubuntu-latest]
      powershell: ["7.4.0"]
    steps:
      - name: "lint"
        action: "PSModule/PSScriptAnalyzer@latest"
        inputs:
          path: "src/"
        conditions:
          - "github.event_name == 'pull_request'"

  release:
    enabled: true
    triggers:
      - release
    matrix:
      os: [ubuntu-latest, windows-latest, macos-latest]
      powershell: ["7.4.0", "7.4.1"]
```

### Custom Step Configuration

```yaml
workflows:
  build:
    steps:
      - name: "build-module"
        action: "PSModule/Build-PSModule@main"
        inputs:
          source-path: "src"
          output-path: "output"
        timeout: 10
        conditions:
          - "always()"

      - name: "test-module"
        action: "PSModule/Test-ModuleLocal@main"
        inputs:
          path: "output"
          import-module: true
        timeout: 20
```

## Step 5: Migration from Hardcoded Values

### Before (Hardcoded)

```yaml
jobs:
  test:
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
        powershell: ['7.4.0', '7.4.1']
    steps:
      - uses: actions/checkout@v4
      - name: Test Module
        shell: pwsh
        run: |
          $matrix = @(
            @{os = 'ubuntu-latest'; pwsh = '7.4.0'}
            @{os = 'windows-latest'; pwsh = '7.4.1'}
            @{os = 'macos-latest'; pwsh = '7.4.2'}
          )
          # Complex conditional logic here...
```

### After (Configuration-Driven)

```yaml
jobs:
  Process-PSModule:
    uses: PSModule/Process-PSModule/.github/workflows/workflow.yml@v4
    with:
      config-file: .github/PSModule.yml
```

With configuration in `.github/PSModule.yml`:

```yaml
workflows:
  test:
    matrix:
      os: [ubuntu-latest, windows-latest, macos-latest]
      powershell: ['7.4.0', '7.4.1', '7.4.2']
```

## Step 6: Validation and Testing

### Validate Configuration

```bash
# Use the Test-Configuration action
- name: Validate Configuration
  uses: PSModule/Process-PSModule/.github/actions/Test-Configuration@main
  with:
    config-file: .github/PSModule.yml
```

### Test Workflow Execution

1. Create a test branch
2. Push changes to trigger workflow
3. Verify configuration is loaded correctly
4. Check that environment variables are set
5. Validate matrix expansion works as expected

## Step 7: Troubleshooting

### Common Issues

**Configuration file not found:**
```
Error: Configuration file .github/PSModule.yml not found
```
**Solution:** Ensure the file exists and is properly formatted YAML

**Invalid configuration:**
```
Error: Configuration validation failed: version is required
```
**Solution:** Check the configuration against the schema and fix validation errors

**Environment not found:**
```
Warning: Environment 'production' not found, using defaults
```
**Solution:** Add the missing environment configuration or use a valid environment name

### Debug Mode

Enable debug logging:

```yaml
jobs:
  Process-PSModule:
    uses: PSModule/Process-PSModule/.github/workflows/workflow.yml@v4
    with:
      config-file: .github/PSModule.yml
      debug: true
```

## Step 8: Advanced Usage

### Conditional Workflows

```yaml
workflows:
  nightly:
    enabled: true
    triggers:
      - schedule
    conditions:
      - "github.event.schedule == '0 2 * * *'"
    matrix:
      os: [ubuntu-latest]

  pr-only:
    enabled: true
    triggers:
      - pull_request
    conditions:
      - "github.event_name == 'pull_request'"
    matrix:
      os: [ubuntu-latest, windows-latest]
```

### Dynamic Configuration

Use repository variables for dynamic values:

```yaml
environments:
  dynamic:
    variables:
      PSMODULE_VERSION: ${{ vars.MODULE_VERSION }}
      PSMODULE_BRANCH: ${{ github.ref_name }}
```

### Secrets Management

```yaml
environments:
  production:
    secrets:
      API_KEY: "PROD_API_KEY"
      DB_PASSWORD: "DATABASE_PASSWORD"
```

## Examples

### Complete Configuration Example

```yaml
version: "1.0.0"

defaults:
  timeout: 30
  retries: 2
  concurrency: 4

workflows:
  ci:
    enabled: true
    triggers:
      - push
      - pull_request
    matrix:
      os: [ubuntu-latest]
      powershell: ["7.4.0"]

  release:
    enabled: true
    triggers:
      - release
    matrix:
      os: [ubuntu-latest, windows-latest, macos-latest]
      powershell: ["7.4.0", "7.4.1"]

environments:
  development:
    variables:
      PSMODULE_ENV: "dev"
      PSMODULE_DEBUG: "true"

  staging:
    variables:
      PSMODULE_ENV: "staging"
      PSMODULE_DEBUG: "false"
    secrets:
      API_KEY: "STAGING_API_KEY"

  production:
    variables:
      PSMODULE_ENV: "prod"
      PSMODULE_DEBUG: "false"
    secrets:
      API_KEY: "PROD_API_KEY"
    matrix:
      os: [ubuntu-latest, windows-latest, macos-latest]
      powershell: ["7.4.0", "7.4.1", "7.4.2"]
```

## Next Steps

1. **Monitor workflow execution** to ensure configuration is applied correctly
2. **Gradually migrate** remaining hardcoded values to configuration
3. **Add environment-specific settings** as needed
4. **Implement automated validation** in CI pipeline
5. **Document configuration options** for team members

## Support

- **Documentation:** [Process-PSModule Configuration Guide](https://psmodule.io/configuration)
- **Issues:** [GitHub Issues](https://github.com/PSModule/Process-PSModule/issues)
- **Discussions:** [GitHub Discussions](https://github.com/PSModule/Process-PSModule/discussions)

---

**Version:** 1.0.0
**Last Updated:** October 14, 2025