# Repository Standard

This is the PSModule organization's Repository Standard. It applies to the PSModule organization and is the standard for PowerShell module repositories. It describes what a newly created or maintained module repository should look like before module-specific code, tests, documentation, and managed repository files are considered.

This standard operates at the same altitude as the [MSX Enterprise Repository Standard](https://msx.no/docs/Ways-of-Working/Repository-Standard/): MSX sets the enterprise-wide default, and this standard adds to and adjusts that default for PowerShell module repositories. Rules this standard does not change are inherited from the MSX default; where this standard adds or overrides a rule, it governs PowerShell module repositories.

The implementation standard still lives in [PowerShell module standard](powershell-module-standard.md). Type-specific conventions for integration (API) and data modules live in [Module types](module-types.md). This page covers the repository standard for module repositories: files, metadata, README shape, release integration, placeholder handling, shared community files, and managed-file distribution.

## Scope

This standard applies to repositories whose primary artifact is a PowerShell module published through the PSModule framework.

It does not apply directly to:

- GitHub Action repositories such as `Build-PSModule`, `Invoke-Pester`, or `Publish-PSModule`.
- Documentation sites published from repositories such as `PSModule/Process-PSModule`.
- Template repositories other than `Template-PSModule`.
- Test, archive, service, or infrastructure repositories that are not published as module artifacts.

Two baseline expectations still apply to every PSModule repository, including
the types listed above. Each repository carries the repository-local files
required for its type and ships the [agent onboarding files](#agent-onboarding-files)
so an agent can work in it without prior context. Organization-owned community
policies may be inherited from `PSModule/.github` when this standard explicitly
allows it. What differs by type is the concrete file set and layout: the
required files, README shape, and framework wiring on the rest of this page are
the module standard, and non-module repositories keep only the equivalent
baseline appropriate to their own type.

`PSModule/Process-PSModule` is a documentation repository rather than a module
repository. It intentionally inherits the Code of Conduct, security policy, and
support guidance from [`PSModule/.github`](https://github.com/PSModule/.github/tree/main/.github)
instead of carrying repository-local `.github/CODE_OF_CONDUCT.md`,
`.github/SECURITY.md`, or `.github/SUPPORT.md`; this is an explicit
repository-specific exception.

Each initiative should keep its own repository standards in its central
documentation repository. For the PSModule organization, this repository owns
the requirements and `Template-PSModule` owns their executable file
implementations.

## Repository creation

Create new module repositories from
[`PSModule/Template-PSModule`](https://github.com/PSModule/Template-PSModule).
The template is the executable baseline for standard files, framework wiring,
starter layout, and CI/CD expectations. Do not recreate those files from
examples in this documentation.

After creating the repository:

1. Replace template tokens such as `{{ NAME }}` and `{{ DESCRIPTION }}`.
2. Remove scaffold functions, tests, and examples that do not represent the module.
3. Set repository metadata and custom properties.
4. Confirm the README answers the start-page questions and uses `Install-PSResource` for installation.
5. Confirm required common files are present.
6. Confirm `.github/PSModule.yml` only overrides defaults when the module needs different behavior.

## Required repository metadata

Each module repository should have:

- A concise GitHub repository description that starts with or clearly says `A PowerShell module ...`.
- `Type: Module` as the repository custom property.
- Topics that help users find the module, when relevant.
- Branch protection and workflow requirements inherited from organization defaults.
- `main` as the default branch unless there is a documented legacy reason.

The repository description is used as a short landing-page summary in documentation and automation. Keep it user-facing and avoid implementation details.

### Organization custom properties

Custom properties are defined once for the whole organization and set per repository. The organization schema is the source of truth; read it with `gh api /orgs/PSModule/properties/schema` before automating against a property, and update this page when the schema changes.

| Property | Value type | Required | Module repository expectation |
| --- | --- | --- | --- |
| `Type` | Single select: `Action`, `Archive`, `Docs`, `Framework`, `FunctionApp`, `Memory`, `Module`, `Other`, `Template`, `Workflow` | Yes, organization default `Other` | `Module`. Set it explicitly after repository creation; a new repository otherwise inherits `Other`. `Template-PSModule` itself is `Template`. |
| `SubscribeTo` | Multi select: `Custom Instructions`, `Prompts`, `Hooks`, `CODEOWNERS`, `dependabot.yml`, `PSModule Settings`, `Linter Settings`, `gitattributes`, `gitignore`, `License` | No | Opt-in for [managed file distribution](#managed-file-distribution). Select the file types the distribution runtime should own in this repository; leave a type unselected to keep a repository-local version. |
| `Description` | String | No | Optional machine-readable description for automation that needs it independently of the GitHub repository description. |
| `Archive` | True/false | No | Set to `true` only when the repository is no longer maintained. |
| `Upstream` | URL | No | Set when the module wraps, mirrors, or is generated from an upstream project. |

Automation and repository search select module repositories with the `props.Type:Module` qualifier, for example `gh search repos --owner PSModule 'props.Type:Module'`.

## Default branch and worktrees

Use `main` for active module repositories. Legacy repositories that still use `master` should not be used as examples for new work.

Local work should use the organization worktree convention:

- The bare repository stays at the repository root.
- `main/` tracks the default branch.
- Feature worktrees use `<type>-<slug>` directories and `<type>/<slug>` branches.

For branch and worktree details, see [Git Worktrees](https://msx.no/docs/Ways-of-Working/Git-Worktrees/).

## Default repository layout

Module repositories use the PSModule framework layout:

| Path | Default purpose |
| ---- | --------------- |
| `README.md` | Concise start page for the module. |
| `LICENSE` | Repository license. PSModule module repositories default to MIT unless a different license is explicitly decided. |
| `.github/CONTRIBUTING.md` | Self-contained contribution workflow for this repository. Does not rely on an organization-level fallback. |
| `.github/SECURITY.md` | Security support policy and private vulnerability reporting instructions. |
| `.github/SUPPORT.md` | Support expectations and where users ask for help. |
| `.github/CODE_OF_CONDUCT.md` | Community conduct expectations. |
| `AGENTS.md` | Agent onboarding entry point. Points agents to the canonical guidance at `https://psmodule.io/Process-PSModule/`. |
| `.claude/CLAUDE.md` | Claude Code entry point. Imports the root `AGENTS.md`. |
| `.github/copilot-instructions.md` | Route for Copilot surfaces that do not read `AGENTS.md` directly. |
| `.github/PSModule.yml` | Module workflow configuration overrides. |
| `.github/workflows/Process-PSModule.yml` | Caller workflow that runs the module's CI/CD by calling the shared Process-PSModule workflow. |
| `.github/zensical.toml` | Canonical generated-site configuration copied from `Template-PSModule`. |
| `.github/release.yml` | Release-note and changelog categorization for GitHub releases. |
| `.github/linters/` | Linter configuration used by the framework's linting stage, including `.markdown-lint.yml` and `.powershell-psscriptanalyzer.psd1`. |
| `.github/dependabot.yml` | Configures ecosystem-appropriate dependency-update pull requests. For PowerShell module repositories the `github-actions` ecosystem is expected; add any other ecosystems the module actually develops in. |
| `.github/CODEOWNERS` | Ownership routing for reviews and protected areas. |
| `.github/pull_request_template.md` | Scaffolds pull requests in the MSX PR Format (PR Manager) style — an icon + change-type + user-facing-outcome title, user-facing description sections, an optional technical-details block, and a related-issues block. |
| `.gitattributes` | Normalizes line endings and declares text/binary handling so the module can be developed and built consistently on Linux, macOS, and Windows. |
| `.gitignore` | Ignores files that must never be committed, tailored to the PowerShell-module ecosystem: operating-system files, editor and developer-tooling files, PowerShell and Pester test-harness artifacts, and all local build outputs and files created during build and test. |
| `src/` | Module source compiled into the shipped artifact. |
| `src/functions/public/` | Exported commands, grouped by domain. |
| `src/functions/private/` | Internal helper commands, grouped by domain. |
| `src/classes/public/` | Public classes that are part of the user-facing model. |
| `src/classes/private/` | Internal implementation classes. |
| `src/data/` | Static module data that ships with the module. |
| `examples/` | Realistic user scenarios, not copies of command help. |
| `docs/` | Product documentation source when the module needs documentation beyond generated command help. |
| `tests/` | Pester tests and test data. |
| `icon/` | Module icon assets. |

Detailed source layout rules live in [PowerShell module standard](powershell-module-standard.md#repository-layout).

### Caller workflow and reusable workflow

The module repository owns a caller workflow; the framework owns the reusable workflow it calls. These are two separate files in two separate repositories:

| Role | Repository | File |
| --- | --- | --- |
| Caller workflow | The module repository | `.github/workflows/Process-PSModule.yml` |
| Reusable workflow | [`PSModule/Process-PSModule`](https://github.com/PSModule/Process-PSModule) | `.github/workflows/workflow.yml` |

The caller workflow declares the triggers, concurrency, and permissions for the
module repository, then delegates the work. Copy
[`Template-PSModule/.github/workflows/Process-PSModule.yml`](https://github.com/PSModule/Template-PSModule/blob/main/.github/workflows/Process-PSModule.yml)
instead of maintaining another example here.

Name the caller file `Process-PSModule.yml`. `workflow.yml` is the reusable
workflow's own filename inside `PSModule/Process-PSModule` and belongs only in
the `uses:` reference. Process-PSModule is initiative-owned automation with a
controlled release process, so the template uses the floating `@v8` major
reference permitted by the MSX GitHub Actions standard.

## Required common files

Every module repository must carry the same baseline community, governance, and automation files. GitHub's organization-level `.github` community-file fallback is useful for display defaults, but it is not enough as the long-term PSModule standard because:

- agents and humans need the files in the repository they are changing, not only inherited through GitHub UI behavior;
- tools such as Dependabot and CODEOWNERS read repository-local files — as do linters and release automation when the module uses those linters or generates releases;
- reviews need diffs against the actual managed file in the target repository;
- repository-local files make the standard portable to other initiatives such as MSXOrg, where each initiative should define its own standards and managed files;
- central fallback files in `PSModule/.github` do not provide a reliable enforcement or update workflow across all repositories.

Required baseline files for module repositories:

| File | Why it is required |
| ---- | ------------------ |
| `README.md` | Repository landing page and evergreen context for humans and agents. |
| `LICENSE` | Clear legal terms for reuse, packaging, and redistribution. |
| `.github/CONTRIBUTING.md` | Self-contained contribution workflow and expectations for this repository. |
| `.github/SECURITY.md` | Private vulnerability reporting and latest-version support policy. |
| `.github/SUPPORT.md` | Support channel and issue-routing expectations. |
| `.github/CODE_OF_CONDUCT.md` | Community participation rules. |
| `AGENTS.md` | Cross-tool agent instructions pointing to the canonical guidance at `https://psmodule.io/Process-PSModule/`. |
| `.claude/CLAUDE.md` | Claude Code entry point that imports the root `AGENTS.md`. |
| `.github/copilot-instructions.md` | Route to `AGENTS.md` for Copilot surfaces that need their own filename. |
| `.github/dependabot.yml` | Configures ecosystem-appropriate dependency-update pull requests. For PowerShell module repositories the `github-actions` ecosystem is expected; add any other ecosystems the module actually develops in. |
| `.github/CODEOWNERS` | Review routing for source, docs, and GitHub workflow files. |
| `.github/pull_request_template.md` | Scaffolds pull requests in the MSX PR Format (PR Manager) style — an icon + change-type + user-facing-outcome title, user-facing description sections, an optional technical-details block, and a related-issues block. |
| `.github/PSModule.yml` | Module workflow defaults and overrides. |
| `.gitattributes` | Normalizes line endings and declares text/binary handling so the module can be developed and built consistently on Linux, macOS, and Windows. |
| `.gitignore` | Ignores files that must never be committed, tailored to the PowerShell-module ecosystem: operating-system files, editor and developer-tooling files, PowerShell and Pester test-harness artifacts, and all local build outputs and files created during build and test. |

Repositories can add local files, but they should not remove these baseline files unless the repository is explicitly outside the module standard.

Each repository must stand on its own. It carries its own copy of every file above and does not depend on the organization `.github` fallback: that fallback is only surfaced in GitHub's web UI, and agents, linters, and local tooling do not read it.

Keep repository-local community health files together under `.github/`.
GitHub discovers `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, and
`SUPPORT.md` there, so root-level duplicates add no value and are not part of
the PSModule layout. This is the PSModule initiative's explicit path override
of the MSX repository default. `README.md`, `LICENSE`, and `AGENTS.md` remain
at the repository root because they are repository entry points rather than
community health files.

## Agent onboarding files

Every repository must be usable by an agent that has never seen it before, without special configuration. Each repository carries its own agent entry points that point to the authoritative documentation instead of restating it:

- `AGENTS.md`: the cross-tool entry point, read by the GitHub Copilot coding agent, VS Code, and other AGENTS.md-aware tools. It names what the repository is in a line or two and points to the canonical agent guidance at [psmodule.io/Process-PSModule](https://psmodule.io/Process-PSModule/).
- `.claude/CLAUDE.md`: a thin file that imports the root router with
  `@../AGENTS.md`.
- `.github/copilot-instructions.md`: a thin link to `../AGENTS.md` for Copilot
  surfaces that do not read the root router directly.

See [PSModule/Template-PSModule](https://github.com/PSModule/Template-PSModule)
for the concrete implementation.

`AGENTS.md`, `.claude/CLAUDE.md`, and
`.github/copilot-instructions.md` are the required set. `AGENTS.md` is the
entry point that AGENTS.md-aware runtimes read directly.

Additional runtime-specific adapters and
`.github/instructions/*.instructions.md` are optional. MSX treats them as
client routes or path-scoped caveats, described in
[Agentic Development](https://msx.no/docs/Capabilities/agentic-development/)
and its
[capability specification](https://msx.no/docs/Capabilities/agentic-development/spec/).
Keep routes pointing at `AGENTS.md` rather than restating it.

These files are the agent equivalent of the README: pointers, not copies. Keep them short so the linked documentation stays the single source of truth. Like the other governance files, they live in the repository itself so it can stand on its own.

## Template ownership and reconciliation {#managed-file-distribution}

Policy ownership, executable templates, and distribution are separate
concerns:

| Concern | Source of truth |
| --- | --- |
| Enterprise requirements | [MSX Repository Standard](https://msx.no/docs/Ways-of-Working/Repository-Standard/) |
| PowerShell module requirements | This PSModule Repository Standard |
| Exact standard-file implementation | The default branch of [`PSModule/Template-PSModule`](https://github.com/PSModule/Template-PSModule) |
| Repository-specific code and content | The consumer repository |

The PSModule standard inherits MSX defaults and may explicitly adjust them for
PowerShell module repositories. For the shared Zensical presentation profile,
the MSXOrg documentation design takes precedence when it differs from the
Process-PSModule documentation site. Once the governing policy is clear, the
template is the byte-level source for standard module files. This keeps exact
file content in one place instead of duplicating templates in documentation or
skills.

Every standard file for a new module repository must exist in
`Template-PSModule`. Template files have one of these relationships to an
established repository:

| Relationship | Reconciliation behavior |
| --- | --- |
| Template-owned standard | Match the template unless a documented exception applies. |
| Parameterized standard | Match after applying only declared repository identity substitutions. |
| Configurable standard | Preserve supported repository-specific values and compare the remaining defaults. |
| Creation scaffold | Use when creating a repository; do not overwrite established source, tests, examples, or content. |
| Repository-owned addition | Preserve unless it violates a governing standard or framework contract. |

Use the
[`psmodule-repository-audit`](https://github.com/PSModule/Process-PSModule/blob/main/.github/plugin/psmodule/skills/psmodule-repository-audit/SKILL.md)
skill to audit a consumer repository. The skill never changes the template or
consumer; alignment is a separate delivery task. Each run records the resolved
template commit so its result remains reproducible after the template changes.

Automated managed-file distribution is not operating across the PSModule fleet.
Setting `SubscribeTo` does not currently synchronize files. Until a distribution
runtime is implemented, maintainers apply template changes through
repository-specific pull requests and use the repository audit skill to detect
drift. A future runtime must consume `Template-PSModule` rather than maintain a
second copy of standard files. Process-PSModule maintainers own detecting when
repository audits or distribution stop operating.

## Supply-chain defaults

Every module repository must include `.github/dependabot.yml`. Dependabot is part of the repository supply-chain control, not an optional convenience.

Configure the `github-actions` ecosystem. It keeps the pinned actions current, including the pinned `PSModule/Process-PSModule` reference in the [caller workflow](#caller-workflow-and-reusable-workflow). This is what [`PSModule/Template-PSModule`](https://github.com/PSModule/Template-PSModule) ships, and it is the default for new repositories:

```yaml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
    labels:
      - dependencies
      - github-actions
    schedule:
      interval: daily
    cooldown:
      default-days: 7
```

Add `nuget` when the module ships or builds against .NET dependencies, as [`PSModule/Sodium`](https://github.com/PSModule/Sodium) does:

```yaml
  - package-ecosystem: nuget
    directory: /
    labels:
      - dependencies
      - .NET
    schedule:
      interval: weekly
```

Repositories with other package ecosystems add them explicitly rather than replacing the `github-actions` entry. Older repositories still use a weekly interval without a cooldown; align them with the template default when the file is touched anyway.

Dependabot PRs still go through normal review. Automated dependency updates are not a substitute for reviewing release notes, changed permissions, pinned SHAs, or generated lockfiles.

### PowerShell dependencies

Dependabot's valid `package-ecosystem` values are enumerated in its configuration parser ([`common/lib/dependabot/config/file.rb`](https://github.com/dependabot/dependabot-core/blob/main/common/lib/dependabot/config/file.rb)) and listed in the [Dependabot options reference](https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-options-reference#package-ecosystem). Configure only values from that list: `powershell` is not among them, and an unsupported value makes `.github/dependabot.yml` invalid, which puts the repository's whole Dependabot configuration at risk, including the `github-actions` entry that does work.

PowerShell module dependencies are therefore declared with `#Requires -Modules` in the function files that use them, as described in [PowerShell module standard](powershell-module-standard.md), and the build collects them into the compiled manifest. Keeping those declarations current is a review responsibility.

A PowerShell ecosystem is proposed in [dependabot/dependabot-core#15501](https://github.com/dependabot/dependabot-core/issues/15501) and implemented in [dependabot/dependabot-core#15666](https://github.com/dependabot/dependabot-core/pull/15666), covering PowerShell's native declarations — `#Requires -Modules` in `.ps1` and `.psm1` files, and `RequiredModules` in a `.psd1` manifest — resolved against the PowerShell Gallery. Adopt it once it ships and `powershell` appears in the options reference, updating this section and the `dependabot.yml` that `Template-PSModule` distributes together.

## README default

A module README is a start page, not the command reference or full manual. It brings a reader in, answers the first questions, and sends them to the right documentation surface.

Making the README shorter must not delete unique information. The README is published as the module's landing page on the documentation site (for example `psmodule.io/<ModuleName>`); the per-command reference is generated separately from comment-based help. So the README is often the only published home for prerequisites, platform and dependency notes, authentication and setup guidance, operational behavior such as caching, state, or update and versioning semantics, and upstream attribution. Trimming the README must preserve that content: keep it on the landing page or in another surface that also publishes (a command group's overview page under `src/functions/public/<Group>/<Group>.md`, comment-based help, or published documentation in `docs/`). Only remove content that is genuinely duplicated by the generated command reference.

The README answers these questions, in this order:

| Question | Module README responsibility |
| --- | --- |
| What is it? | Name the module and define its scope in one short paragraph. |
| Why should I care? | State the value or kind of task the module makes easier. |
| How do I get it? | Show the PowerShell Gallery install and import commands. |
| How does it work? | Show one to three representative capabilities or usage examples. |
| How do I get more info? | Link to generated module documentation and PowerShell help. |

Module installation examples must use PSResourceGet:

```powershell
Install-PSResource -Name <ModuleName>
```

Do not use `Install-Module` in new module repository documentation. `Install-Module` belongs only in legacy/historical context where changing it would misrepresent the referenced system.

For implemented modules, use this shape:

````markdown
# <ModuleName>

<One short paragraph describing what the module is and why it is useful.>

## Installation

Install the module from the PowerShell Gallery:

```powershell
Install-PSResource -Name <ModuleName>
Import-Module -Name <ModuleName>
```

## Capabilities

Use this section as a short showcase and introduction to how the module works. Show the most important things the module makes possible with one to three realistic examples.

The goal is discovery and marketing, not exhaustive command documentation. A reader should understand why the module exists and what kind of tasks it helps with.

```powershell
# Replace this with a real example that demonstrates the module's value.
Get-Command -Module <ModuleName>
```

## Documentation

Documentation is published at [psmodule.io/<ModuleName>](https://psmodule.io/<ModuleName>/).

Use PowerShell help and command discovery for module details:

```powershell
Get-Command -Module <ModuleName>
Get-Help -Name <Command> -Examples
```
````

In the documentation examples, replace `<Command>` with a real command exported by the module, for example `Get-Help -Name Get-GitHubRepository -Examples`, so the snippet runs as written. Do not ship placeholder tokens such as `'CommandName'` or `<CommandName>` as if they were runnable commands.

Implemented modules must include the capabilities or usage showcase before the documentation link. Keep it focused on discovery: show one to three representative outcomes, not every command, parameter, or edge case. A landing page with only an installation snippet and a documentation link is not enough for a module that has working commands.

Keep, trim, or relocate content — do not delete it:

- **Keep on the landing page:** the overview, prerequisites and requirements (PowerShell version, supported platforms, module or native dependencies), installation, the capabilities showcase, and the short operational notes a reader needs before first use.
- **Trim:** exhaustive command inventories, parameter tables, and repetitive examples that differ only by a parameter. These come from comment-based help — point to `Get-Help` and the documentation site instead of restating them.
- **Keep content in a published home — never drop it:** long-form guides and unique conceptual content (authentication and setup walkthroughs, deep operational detail, end-to-end scenarios) belong in a surface that is actually published: a command group's overview page under `src/functions/public/<Group>/<Group>.md`, comment-based help, or published documentation in `docs/` or `examples/`. When no published home exists, keep the full content in the README to ensure it reaches users. A longer landing page is acceptable and expected for feature-rich modules; do not shorten by deleting.

Retain upstream attribution and licensing context. Credit, acknowledgements, donation notes, and third-party license notices for wrapped or bundled work must stay in the README or appear in a clearly linked location. The rule below about community and policy sections does not apply to attribution the project is expected to carry.

README pages should not duplicate generated command documentation. Do not add full command inventories, parameter tables, or long reference sections when those details are already produced from comment-based help.

Do not add a community-file or policy link section by default. Readers can find
standard files such as `LICENSE`, `.github/CONTRIBUTING.md`,
`.github/SECURITY.md`, and `.github/CODE_OF_CONDUCT.md` through GitHub
conventions and the repository file tree. Link them only when the module has an
unusual rule the user must know before using it, or when it carries required
upstream attribution.

## Placeholder and in-progress repositories

If a repository is reserved for a future module or still contains scaffold code, say that directly. Do not leave `{{ NAME }}`, `{{ DESCRIPTION }}`, `PSModuleTemplate`, `Greet-Entity`, or similar template examples in the README.

Use this shape for placeholder repositories:

````markdown
# <ModuleName>

<One sentence describing what the module is intended to become.>

## Status

This repository is currently a placeholder. The module source still contains scaffold code, so there are no supported commands or usage examples to document yet.

## Documentation

When this module is implemented, command details should live in PowerShell help and generated documentation rather than being duplicated in this README.
````

Use the same pattern for in-progress modules with stub commands, but name the stub honestly:

```markdown
This repository is currently in progress. The current `<CommandName>` command is a stub and throws `NotImplementedException`, so there are no supported conversion commands or usage examples to document yet.
```

## README validation

Before opening a README-only PR, check that the README follows the default and does not contain leftover scaffolding:

```powershell
Select-String -Path README.md -SimpleMatch -Pattern 'Greet-Entity', 'PSModuleTemplate', 'YourModuleName'
Select-String -Path README.md -SimpleMatch -Pattern '{{ NAME }}', '{{ DESCRIPTION }}'
Select-String -Path README.md -SimpleMatch -Pattern '<Command>', '<CommandName>', "-Name 'CommandName'"
Select-String -Path README.md -Pattern '^## (Commands|Capabilities)$'
Select-String -Path README.md -Pattern '^Install-Module\b'
git diff --check -- README.md
```

`Template-PSModule` is the exception: it intentionally keeps `{{ NAME }}` and `{{ DESCRIPTION }}` tokens because those are template inputs.

For an implemented module, also confirm the README keeps a capabilities or usage showcase and that any unique content removed from the previous version — prerequisites, setup or authentication guidance, operational notes, or upstream attribution — was relocated to `docs/`, `examples/`, or comment-based help rather than deleted.

## Documentation ownership

Command details belong in comment-based help and generated documentation. The README can showcase capability, then points to those sources for reference detail.

Use these defaults:

- Command synopsis, parameters, examples, links, and outputs live in comment-based help.
- Group overview pages live next to public command groups in `src/functions/public/<Group>/<Group>.md`.
- Realistic end-to-end scenarios live in `examples/`.
- Product docs beyond generated command help live under `docs/` and publish through GitHub Pages or the initiative's module documentation site.
- README capability examples are short, representative, and user-facing.
- README pages stay focused and stable, and keep the narrative content that has no other published home.

This keeps the repository landing page readable and prevents drift between README content, PowerShell help, and generated documentation.

### Zensical configuration

The canonical module-site configuration is
[`Template-PSModule/.github/zensical.toml`](https://github.com/PSModule/Template-PSModule/blob/main/.github/zensical.toml).
Keep its repository placeholders: Process-PSModule resolves them while staging
the generated site. The template carries the portable subset of the MSXOrg and
Process-PSModule documentation design, with the MSXOrg design taking precedence
when they differ.

Do not declare `nav` in a standard module repository. Zensical derives
navigation from the staged folder structure, places index pages first, and
sorts the remaining pages alphabetically. Organize generated function
references through their source folders instead of maintaining a second
navigation tree in TOML.

The template does not define `[project.extra.consent]`. Standard generated
module sites do not enable cookie-based measurement and must not display a
consent prompt. A repository adds consent configuration only when its own
documented functionality requires it.

Repository-specific documentation content remains repository-owned. A module
may depart from the template's site configuration only for a documented
requirement that the shared generated-site profile cannot satisfy.

## Release and PR defaults

Module repositories use the Process-PSModule workflow. Version and release behavior is driven by PR labels and workflow settings.

Default expectations:

- `Major`, `Minor`, `Patch`, and `Prerelease` labels determine release behavior.
- Documentation-only README standardization PRs use the `Docs`/`NoRelease` behavior when available.
- Source changes under `src/` are module-impacting and should trigger the full module workflow.
- README and documentation changes should update the site without pretending to be module API changes.

See [Versioning](versioning.md) for semantic version rules and [PowerShell module standard](powershell-module-standard.md#cicd-pipeline) for the Process-PSModule pipeline.

## Template maintenance

`Template-PSModule` contains the concrete files for the complete starter
repository contract. Every Process-PSModule change includes an impact
evaluation that determines whether the template must change. When a framework
contract or this page changes a default, update the template in the same work
item before aligning consumer repositories. A standard is not complete while
its required implementation is absent from the template.

The template README may contain tokens, but generated module repositories should not keep them after the initial setup commit.
