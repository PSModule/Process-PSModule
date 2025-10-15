# Process-PSModule

A workflow for crafting PowerShell modules using the PSModule framework, which builds, tests, and publishes PowerShell modules to the PowerShell Gallery and produces documentation that is published to GitHub Pages. The workflow is used by all PowerShell modules in the PSModule organization.

## How to get started

- [Create a repository from the Template-Module](https://github.com/new?template_name=Template-PSModule&template_owner=PSModule&description=Add%20a%20description%20%28required%29&name=%3CModule%20name%3E).
- Configure the repository:
- Enable GitHub Pages in the repository settings. Set it to deploy from **GitHub Actions**.
- This will create an environment called **github-pages** that GitHub deploys your site to. &lt;details&gt;&lt;summary&gt;Within the environment, remove the branch protection for &lt;code&gt;main&lt;/code&gt;.&lt;/summary&gt; &lt;img src="./media/pagesEnvironment.png" alt="Remove the branch protection on main"&gt; &lt;/details&gt;
- [Create an API key on the PowerShell Gallery](https://www.powershellgallery.com/account/apikeys). Give it permission to manage the module you are working on.
- Create a new secret in the repository called APIKEY and set it to the API key for the PowerShell Gallery.
- Create a branch, make your changes, create a PR and let the workflow run.

## How it works

The workflow is designed to run on pull requests to the repository's default branch. When a pull request is opened, updated, merged, or closed, the workflow will run. Depending on the labels on the pull request, the workflow will result in different outcomes (e.g. version bumps or skipping release). The diagram below shows a high-level view of the process:

Process diagram

- **Get settings** - Reads the configuration from a settings file in the module repository (by default .github/PSModule.yml[\[1\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/.github/workflows/workflow.yml#L34-L39)). If no settings file is present, all default settings are used. This step also discovers the test files in the repository and prepares the test matrix (including selecting which OSes to run tests on) based on the settings and available tests.
- **Lint repository** - Lints the entire repository code base (e.g. all scripts, JSON/YAML files, markdown, etc.) using [GitHub Super-Linter](https://github.com/super-linter/super-linter). This runs on pull request events to catch formatting and style issues in the repository's files, and reports any issues in the PR status[\[2\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/.github/workflows/workflow.yml#L134-L142).
- **Build module** - Compiles or packages the module source code into a PowerShell module (build output is placed in the outputs/module directory as an artifact for later steps).
- **Test source code** - Runs automated tests on the module's source code (e.g. functions or scripts) in parallel on multiple platforms. This uses PSModule framework rules for source code quality[\[3\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/README.md#L34-L42) (for example, ensuring coding standards and best practices). A JSON report is produced for later evaluation of these static analysis tests.
- **Lint source code** - Runs PowerShell ScriptAnalyzer rules on the source code in parallel on multiple platforms[\[4\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/README.md#L36-L44). This performs style and linting checks specific to PowerShell code. A JSON report is produced for later evaluation of the linter results.
- **Framework test** - Runs the PSModule **framework tests** on the built module in parallel on multiple platforms. These are standardized tests (using Pester) that validate the module against PSModule framework guidelines[\[5\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/README.md#L40-L45) (for example, module manifest correctness, public functions have help, PSScriptAnalyzer rules on the module, etc.). A JSON report is produced for later evaluation of the results.
- **Test module** - Imports and tests the built module using the module's own Pester test files (from the module repository). These tests run in parallel on multiple platforms. The workflow automatically handles any special setup or teardown scripts:
- **BeforeAll** - If a tests/BeforeAll.ps1 script is present, it will be executed _once_ before all the test jobs to set up the test environment (e.g. deploy test infrastructure, seed data). This runs on a single job before the matrix of tests starts[\[6\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/README.md#L46-L54)[\[7\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/README.md#L134-L142).
- **AfterAll** - If a tests/AfterAll.ps1 script is present, it will be executed _once_ after all test jobs have completed to clean up the test environment (e.g. remove test resources, stop services). This runs even if tests failed, ensuring cleanup happens[\[8\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/README.md#L152-L160)[\[9\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/.github/workflows/workflow.yml#L394-L402).
- The setup/teardown scripts (if present) use the same environment (including any secrets and module files) as the tests. If no such scripts are found, the tests simply run without additional setup/teardown.
- A JSON report is produced for later evaluation of the module test results.
- **Get test results** - Aggregates the results from all test phases (source code tests, framework tests, and module tests) and creates a summary. If any tests failed, this step will mark the workflow as failed at this point. The summary (and detailed test results artifact) helps identify which tests failed.
- **Get code coverage** - Aggregates code coverage results from the tests (if code coverage was enabled) and produces a summary. If the coverage percentage is below the configured target, the workflow fails at this step. This ensures a minimum code coverage threshold can be enforced.
- **Build docs** - Generates the module's documentation and then lints the generated docs for correctness. Documentation is typically produced by extracting comment-based help or markdown from the module (using the PSModule **Document-PSModule** tool) and saved to the outputs/docs folder. After generation, [Super-Linter](https://github.com/super-linter/super-linter) runs to check the documentation files (e.g. markdown formatting) for issues. Any documentation changes (e.g. updated help files) are automatically committed to the repo (in the PR) as part of this step, so that the docs stay up to date.
- **Build site** - Uses the generated documentation to build a static website for the module. This uses [MkDocs Material](https://squidfunk.github.io/mkdocs-material/) to produce a full documentation website from the markdown docs. The static site output is generated (usually into a site directory) and prepared for publishing.
- **Publish site** - Deploys the static documentation site to **GitHub Pages** for the repository. This runs when a pull request is **merged** into the default branch (i.e. on a successful merge) and uses GitHub Pages Actions to publish the site content to the github-pages environment (which was set up in the beginning). This makes the latest module documentation available online at https://&lt;username&gt;.github.io/&lt;Repository&gt;/.
- **Publish module** - Publishes the PowerShell module to the PowerShell Gallery, and creates a release in the GitHub repository. This step handles versioning and release logic:
- On an **open pull request**, it publishes a **prerelease** version of the module (e.g. an incremented prerelease build) to the gallery so it can be tested before merging.
- On a **merged pull request**, it publishes a **stable release** version of the module to the gallery and creates a corresponding GitHub release (with release notes, etc.).
- If a pull request is **closed without merging** (abandoned), the workflow will publish a special **cleanup** or retraction version to the gallery to effectively undo or de-list the previously published prerelease (this behavior is controlled by the AutoCleanup setting, enabled by default[\[10\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/README.md#L260-L263)[\[11\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/README.md#L218-L224)).
- The version number for the release is determined automatically based on the labels on the pull request. For example, labeling the PR as **major** or **breaking** will trigger a major version bump; **minor** or **feature** will trigger a minor version bump; **patch** or **fix** will trigger a patch version bump[\[12\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/README.md#L264-L269). If none of these labels are present, the workflow will by default increment the patch version (this can be configured via **AutoPatching**). If a **NoRelease** label is present on the PR, the workflow will skip publishing a module release entirely[\[12\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/README.md#L264-L269).

## Usage

To use the workflow in your module repository, create a new YAML workflow file (e.g. .github/workflows/Process-PSModule.yml) in your repository with the following content:

&lt;details&gt; &lt;summary&gt;Example workflow file&lt;/summary&gt;

name: Process-PSModule
<br/>on:
workflow_dispatch:
schedule:
\- cron: '0 0 \* \* \*'
pull_request:
branches:
\- main
types:
\- closed
\- opened
\- reopened
\- synchronize
\- labeled
<br/>concurrency:
group: \${{ github.workflow }}-\${{ github.ref }}
cancel-in-progress: true
<br/>permissions:
contents: write
pull-requests: write
statuses: write
pages: write
id-token: write
<br/>jobs:
Process-PSModule:
uses: PSModule/Process-PSModule/.github/workflows/workflow.yml@v5
secrets:
APIKEY: \${{ secrets.APIKEY }}

&lt;/details&gt;

### Inputs

When calling the **Process-PSModule** workflow (as shown above), you can configure it with the following inputs:

| Name | Type | Description | Required | Default |
| --- | --- | --- | --- | --- |
| **Name** | string | The name of the module to process. If not specified, the repository name is used by default. | false | (Repo name) |
| **SettingsPath** | string | The path to the settings file. Settings in this file take precedence over these inputs. | false | .github/PSModule.yml[\[1\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/.github/workflows/workflow.yml#L34-L39) |
| **Version** | string | Specific version of the **GitHub** PowerShell module to install (if needed for this workflow). Must be an exact version number. | false | (Latest stable) |
| **Prerelease** | boolean | Whether to allow prerelease versions of the **GitHub** module (if a prerelease is needed/available). | false | false |
| **Debug** | boolean | Whether to enable detailed debug output. If true, adds extra debug logging steps in each job. | false | false |
| **Verbose** | boolean | Whether to enable verbose output. This can help with troubleshooting by producing more detailed logs. | false | false |
| **WorkingDirectory** | string | The path to the root of the repository (if your repository content is in a sub-folder, adjust this). | false | .   |

### Setup and Teardown Scripts

The workflow supports automatic execution of **setup** and **teardown** scripts around your module tests:

- **Setup script (BeforeAll.ps1)** - If you include a PowerShell script at tests/BeforeAll.ps1 in your module repo, the workflow will run this script once _before_ running any of your module's tests (the **Test module** phase). Use this to set up any required infrastructure or environment for tests (e.g., deploy a test database, set environment variables, etc.). The script runs with the same environment context as the tests (so you have access to secrets, the checked-out code, etc.).
- **Teardown script (AfterAll.ps1)** - Similarly, if you include a tests/AfterAll.ps1 script, the workflow will run this once _after_ all module test jobs have finished. Use this to clean up resources that were set up for testing (e.g., remove test data, destroy infrastructure, etc.), even if some tests failed.

**Note:** These scripts are optional. If they are not present, the workflow will simply proceed without running any extra setup/teardown steps.

**Example** - A simple BeforeAll.ps1 might deploy a required service and a matching AfterAll.ps1 would shut it down:

\# tests/BeforeAll.ps1
Write-Host "Setting up test environment..."
\# (Your setup code here)
Write-Host "Test environment ready."

\# tests/AfterAll.ps1
Write-Host "Cleaning up test environment..."
\# (Your cleanup code here)
Write-Host "Cleanup completed."

### Secrets

The following secrets can be utilized by the workflow. To make them available to the workflow jobs, you can either pass them in the workflow file (similar to the APIKEY in the example above) or use secrets: inherit to provide all repository secrets to the workflow.

| Name | Location (Secret Name) | Description | Required? |
| --- | --- | --- | --- |
| **APIKEY** | GitHub repository secret | API key for the PowerShell Gallery (used to publish the module). | Yes (for publishing) |
| **TEST_APP_ENT_CLIENT_ID** | GitHub repository secret | Client ID of an **Enterprise** GitHub App (for integration tests). | No  |
| **TEST_APP_ENT_PRIVATE_KEY** | GitHub repository secret | Private key of an **Enterprise** GitHub App (for integration tests). | No  |
| **TEST_APP_ORG_CLIENT_ID** | GitHub repository secret | Client ID of an **Organization** GitHub App (for integration tests). | No  |
| **TEST_APP_ORG_PRIVATE_KEY** | GitHub repository secret | Private key of an **Organization** GitHub App (for integration tests). | No  |
| **TEST_USER_ORG_FG_PAT** | GitHub repository secret | Fine-grained PAT (Personal Access Token) with org access (for integration tests). | No  |
| **TEST_USER_USER_FG_PAT** | GitHub repository secret | Fine-grained PAT with user account access (for integration tests). | No  |
| **TEST_USER_PAT** | GitHub repository secret | Classic Personal Access Token (for integration tests). | No  |

These additional secrets are generally used if your module's tests need to interact with the GitHub API or other external systems (for example, testing GitHub integration using a PAT or GitHub App credentials). If you don't need them, you can ignore them. If they are present in your repository and you use secrets: inherit, the workflow will pick them up automatically.

### Permissions

The workflow requires certain GitHub token permissions to operate. In the example workflow file above, these permissions are set under permissions:. For reference, here are the required permissions and why they are needed:

permissions:
contents: write # allows checking out code and creating releases/tags in the repo
pull-requests: write # allows posting status checks or comments to pull requests
statuses: write # allows updating commit status (used by linter results)
pages: write # allows deploying to GitHub Pages environments
id-token: write # allows OIDC token for deploying to Pages (authentication)

These should be included in your workflow file as shown. (If you use the template as given, they are already set.)

For more information on Pages deployment permissions, see GitHub's docs on \[Deploying to GitHub Pages\][\[13\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/README.md#L186-L194).

### Scenario Matrix

The following table summarizes which jobs run in various scenarios. This can help you understand what happens, for example, when a PR is merged versus just opened, etc.:

| Job | Open/Updated PR | Merged PR | Closed (Abandoned) PR | Manual Run |
| --- | --- | --- | --- | --- |
| **Get-Settings** | ✅ (Always) | ✅ (Always) | ✅ (Always) | ✅ (Always) |
| **Lint-Repository** | ✅ Yes | ❌ No | ❌ No | ❌ No |
| **Build-Module** | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| **Build-Docs** | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| **Build-Site** | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| **Test-SourceCode** | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| **Lint-SourceCode** | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| **Test-Module** (Framework tests) | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| **BeforeAll-ModuleLocal** (Setup) | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| **Test-ModuleLocal** (Module tests) | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| **AfterAll-ModuleLocal** (Teardown) | ✅ Yes | ✅ Yes | ✅ Yes\* | ✅ Yes |
| **Get-TestResults** | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| **Get-CodeCoverage** | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| **Publish-Site** | ❌ No | ✅ Yes | ❌ No | ❌ No |
| **Publish-Module** | ✅ Yes\*\* | ✅ Yes\*\* | ✅ Yes\*\*\* | ✅ Yes\*\* |

\* Teardown runs for an abandoned PR only if tests had started (to ensure cleanup)
\*\* Runs only when all previous build/tests/coverage steps succeeded
\*\*\* For an abandoned PR, a cleanup/retraction version is published[\[11\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/README.md#L218-L224)

From the above: on a typical **pull request open/update**, all steps through testing and artifact generation run, and a prerelease module is published if everything passes. On **merge**, a full release (and site publish) occurs. On **closing a PR without merge**, no tests are run (if not already started), but a cleanup release may run to retract the prerelease. Manual runs behave similar to an open PR (run tests, etc.) but do not deploy the site or typically publish a module (since those are tied to PR merge logic).

## Configuration

The workflow is primarily configured via a **settings file** in your module repository. By default this is .github/PSModule.yml (YAML or JSON format), though you can specify a different path via the SettingsPath input. A PowerShell Data (.PSD1) file is also supported. Settings in this file will override the default behavior and allow you to skip or adjust various phases of the process.

Here are the available settings and their default values:

| Setting Key | Type | Description | Default value |
| --- | --- | --- | --- |
| **Name** | String | Name of the module (for publishing). If not set, defaults to the repository name. | (none) |
| **Test.Skip** | Boolean | Skip all testing phases entirely. | false |
| **Test.Linux.Skip**, **.MacOS.Skip**, **.Windows.Skip** | Boolean | Skip all tests on the specified OS only. | false for each |
| **Test.SourceCode.Skip** | Boolean | Skip the Source Code tests phase. | false |
| **Test.SourceCode.Linux.Skip**, **.MacOS.Skip**, **.Windows.Skip** | Boolean | Skip Source Code tests on that OS only. | false for each |
| **Test.PSModule.Skip** | Boolean | Skip the Framework (PSModule) tests phase. | false |
| **Test.PSModule.Linux.Skip**, **.MacOS.Skip**, **.Windows.Skip** | Boolean | Skip Framework tests on that OS only. | false for each |
| **Test.Module.Skip** | Boolean | Skip the Module tests phase (your module's own tests). | false |
| **Test.Module.Linux.Skip**, **.MacOS.Skip**, **.Windows.Skip** | Boolean | Skip module tests on that OS only. | false for each |
| **Test.TestResults.Skip** | Boolean | Skip collecting/processing test results (not recommended to skip). | false |
| **Test.CodeCoverage.Skip** | Boolean | Skip code coverage calculation entirely. | false |
| **Test.CodeCoverage.PercentTarget** | Integer | Required code coverage percentage. If >0, workflow fails if coverage is below this. | 0 (no minimum) |
| **Test.CodeCoverage.StepSummaryMode** | String | Controls the level of detail in the GitHub Step Summary for coverage. Options include combinations like "Missed, Files" (to show missed lines and file summaries). | 'Missed, Files' |
| **Build.Skip** | Boolean | Skip all build tasks entirely. | false |
| **Build.Module.Skip** | Boolean | Skip the Module build phase. | false |
| **Build.Docs.Skip** | Boolean | Skip the Documentation build phase. | false |
| **Build.Docs.ShowSummaryOnSuccess** | Boolean | Show the documentation linter summary even if no issues (on success). | false |
| **Build.Site.Skip** | Boolean | Skip the Site generation phase. | false |
| **Publish.Module.Skip** | Boolean | Skip publishing the module entirely (no PowerShell Gallery release, no GitHub release). | false |
| **Publish.Module.AutoCleanup** | Boolean | Automatically publish a retraction if a PR is closed without merging (cleanup prerelease). | true[\[10\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/README.md#L260-L263) |
| **Publish.Module.AutoPatching** | Boolean | Automatically bump the patch version if no other version-bump label is present. | true |
| **Publish.Module.IncrementalPrerelease** | Boolean | Use incremental prerelease numbering for successive updates to the same PR (e.g., increment build number on each push). | true |
| **Publish.Module.DatePrereleaseFormat** | String | Use date-based prerelease tag format. If set (e.g. "yyyyMMdd-HHmm"), uses current date/time in prerelease tag. Overrides incremental if non-empty. | '' (empty) |
| **Publish.Module.VersionPrefix** | String | Prefix for version tags (e.g., "v" means releases will be tagged like v1.2.3). | 'v' |
| **Publish.Module.MajorLabels** | String | Comma-separated labels that indicate a **major** version bump. | 'major, breaking'[\[12\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/README.md#L264-L269) |
| **Publish.Module.MinorLabels** | String | Comma-separated labels that indicate a **minor** version bump. | 'minor, feature'[\[12\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/README.md#L264-L269) |
| **Publish.Module.PatchLabels** | String | Comma-separated labels that indicate a **patch** version bump. | 'patch, fix'[\[12\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/README.md#L264-L269) |
| **Publish.Module.IgnoreLabels** | String | Comma-separated labels that indicate **no release** should be done. | 'NoRelease'[\[14\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/README.md#L266-L269) |
| **Linter.Skip** | Boolean | Skip repository linting (Super-Linter) phase. | false |
| **Linter.ShowSummaryOnSuccess** | Boolean | Show the Super-Linter summary even if no issues were found (successful run). | false |
| **Linter.env** | Object | Key-value pairs of environment variables to configure Super-Linter (advanced). E.g., you can set any Super-Linter config like LOG_LEVEL, VALIDATE_\* toggles, etc. | {} (empty) |

The configuration above allows fine-grained control over the workflow. The defaults are suitable for most cases, but you can adjust them by adding any of these entries to your .github/PSModule.yml (or equivalent config file) in your repo.

&lt;details&gt; &lt;summary&gt;Default configuration file (PSModule.yml)&lt;/summary&gt;

Name: null
<br/>Build:
Skip: false
Module:
Skip: false
Docs:
Skip: false
ShowSummaryOnSuccess: false
Site:
Skip: false
<br/>Test:
Skip: false
Linux:
Skip: false
MacOS:
Skip: false
Windows:
Skip: false
SourceCode:
Skip: false
Linux:
Skip: false
MacOS:
Skip: false
Windows:
Skip: false
PSModule:
Skip: false
Linux:
Skip: false
MacOS:
Skip: false
Windows:
Skip: false
Module:
Skip: false
Linux:
Skip: false
MacOS:
Skip: false
Windows:
Skip: false
TestResults:
Skip: false
CodeCoverage:
Skip: false
PercentTarget: 0
StepSummaryMode: 'Missed, Files'
<br/>Publish:
Module:
Skip: false
AutoCleanup: true
AutoPatching: true
IncrementalPrerelease: true
DatePrereleaseFormat: ''
VersionPrefix: 'v'
MajorLabels: 'major, breaking'
MinorLabels: 'minor, feature'
PatchLabels: 'patch, fix'
IgnoreLabels: 'NoRelease'
<br/>Linter:
Skip: false
ShowSummaryOnSuccess: false
env: {}

&lt;/details&gt;

### Examples

Here are a few example configurations to illustrate common customizations:

- **Enforcing Code Coverage**: Require at least 80% code coverage for tests to pass:

Test:
CodeCoverage:
PercentTarget: 80

- **Rapid CI (skip non-essential steps)**: Only build the module and run its own tests on Linux (skip static analysis, framework tests, other OSes, and documentation steps) for faster feedback:

Test:
SourceCode:
Skip: true # skip source code analysis tests
PSModule:
Skip: true # skip framework tests
Module:
MacOS:
Skip: true # skip module tests on MacOS
Windows:
Skip: true # skip module tests on Windows
TestResults:
Skip: true # skip aggregating test results (since we only run a subset)
CodeCoverage:
Skip: true # skip code coverage
Build:
Docs:
Skip: true # skip documentation generation

- **Disabling Repository Linter**: If you don't want to run the Super-Linter on your repository (for example, if you have your own linting setup or to speed up PR checks):

Linter:
Skip: true

- **Customizing Linter Rules**: To configure which linters run (Super-Linter supports many languages/linters):

You can pass any Super-Linter environment variable via the Linter.env configuration. For example, to disable certain linters and enable others explicitly:

Linter:
env:
VALIDATE_BIOME_FORMAT: false
VALIDATE_BIOME_LINT: false
VALIDATE_GITHUB_ACTIONS_ZIZMOR: false
VALIDATE_JSCPD: false
VALIDATE_JSON_PRETTIER: false
VALIDATE_MARKDOWN_PRETTIER: false
VALIDATE_YAML_PRETTIER: false
<br/>VALIDATE_YAML: true
VALIDATE_JSON: true
VALIDATE_MARKDOWN: true

You can also set other options like log level or filters:

Linter:
env:
LOG_LEVEL: DEBUG
FILTER_REGEX_EXCLUDE: '.\*test.\*' # ignore files/folders with "test" in name
VALIDATE_ALL_CODEBASE: false # only changed files are linted

- **Show Linter Summary on Success**: By default, the Super-Linter will only post a summary if issues are found. If you want to always see a summary of what was checked (even when everything passes):

Linter:
ShowSummaryOnSuccess: true

This can be useful to review the linter output to see which files were scanned.

**Note:** The GITHUB_TOKEN is automatically provided to the linter to publish status checks on your PR. You do not need to supply this token manually.

## Specifications and Practices

The Process-PSModule workflow and the PSModule framework adhere to several best practices and standards:

- **Test-Driven Development (TDD)** - The workflow encourages TDD by integrating [Pester](https://pester.dev) tests and enforcing coding standards (via Pester-based tests and PSScriptAnalyzer) as part of every pull request[\[15\]](https://github.com/PSModule/Test-PSModule/blob/a4ca518fd2f2130e14c9cda3dfab5deb60d80ea6/README.md#L10-L19).
- **GitHub Flow** - It is designed around the GitHub Flow model (feature branch -> pull request -> merge), automating checks on PRs and releases on merge.
- **Semantic Versioning (SemVer 2.0.0)** - Module versioning and releases follow SemVer principles[\[16\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/README.md#L200-L208), automatically incrementing major/minor/patch based on changes (as indicated by PR labels)[\[12\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/README.md#L264-L269).
- **Continuous Integration & Delivery** - The workflow automates building, testing (CI) and publishing (CD) of PowerShell modules, enabling continuous delivery of module updates to users, with quality gates (tests, linters, coverage) ensuring reliability[\[17\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/README.md#L204-L212)[\[18\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/README.md#L216-L224).

By using this workflow through the provided template, PowerShell module developers can focus on writing code and tests for their module, while the PSModule framework takes care of the heavy lifting for build, quality assurance, and publishing.

[\[1\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/.github/workflows/workflow.yml) [\[2\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/.github/workflows/workflow.yml#L134-L142) [\[9\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/.github/workflows/workflow.yml#L394-L402) workflow.yml

<https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/.github/workflows/workflow.yml>

[\[3\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/README.md#L34-L42) [\[4\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/README.md#L36-L44) [\[5\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/README.md#L40-L45) [\[6\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/README.md#L46-L54) [\[7\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/README.md#L134-L142) [\[8\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/README.md#L152-L160) [\[10\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/README.md#L260-L263) [\[11\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/README.md#L218-L224) [\[12\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/README.md#L264-L269) [\[13\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/README.md#L186-L194) [\[14\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/README.md#L266-L269) [\[16\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/README.md#L200-L208) [\[17\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/README.md#L204-L212) [\[18\]](https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/README.md#L216-L224) README.md

<https://github.com/PSModule/Process-PSModule/blob/eaf0f3086f35179eb9985c876748ad9dfa3a6fc7/README.md>

[\[15\]](https://github.com/PSModule/Test-PSModule/blob/a4ca518fd2f2130e14c9cda3dfab5deb60d80ea6/README.md#L10-L19) README.md

<https://github.com/PSModule/Test-PSModule/blob/a4ca518fd2f2130e14c9cda3dfab5deb60d80ea6/README.md>
