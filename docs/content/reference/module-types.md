# Module types

Most PSModule modules use one or both of the module types below. The general rules in
[PowerShell module standard](powershell-module-standard.md) and [MSX PowerShell Standards](https://msx.no/docs/Coding-Standards/PowerShell/)
always apply. This page defines additional conventions for each module type.

The module types are:

- **Integration (API) modules** provide PowerShell commands for an external service's REST or GraphQL API.
- **Data modules** convert or manage a data format or in-memory structure.

A module can serve both roles. For example, an integration module can also provide conversion helpers. Apply each relevant section.

## Integration (API) modules

Integration modules provide PowerShell commands for an external service. `GitHub` and the
service-client modules `Anthropic`, `OpenAI`, `Bluesky`, and `Domeneshop` are integration modules.

### Command naming maps to the resource, not the HTTP method

Name commands after the resource and the intended operation. Use approved verbs. Never name a command after
the HTTP method or the endpoint path. Map REST methods to verbs:

| REST method | PowerShell verb | Example |
| ----------- | --------------- | ------- |
| `GET` | `Get-` | `Get-GitHubRepository` |
| `POST` (create) | `New-` / `Add-` | `New-GitHubRepository` |
| `PUT` / `PATCH` (update) | `Set-` / `Update-` | `Set-GitHubRepository` |
| `DELETE` | `Remove-` | `Remove-GitHubRepository` |
| Non-CRUD action | Approved verb for the intent | `Invoke-`, `Start-`, `Stop-`, `Enable-`, ... |

Prefix the noun with the service-specific term (`GitHubRepository`, not `Repository`).

### Transport abstraction

Helper functions make the `Invoke-RestMethod`, GraphQL, or HTTP calls. Choose how to expose the transport and module state:

- **Private transport** (common): Keep REST, GraphQL, and HTTP helpers private. Public functions
  accept resolved inputs and typed objects. This applies the Dependency Inversion rule from
  [Standards](powershell-module-standard.md#solid-applied) to network calls.
- **Public transport**: Expose REST or GraphQL functions publicly for advanced users or module
  composition.
- **Public Context**: Expose the `Context` module so users can configure and manage
  module state, secrets, and settings directly.

Choose the strategy for the module's intended users.

### Use Context for user and module settings

Integration modules use the [`Context`](https://github.com/PSModule/Context) module to store state instead of a separate storage implementation.
Context stores user data and secrets on disk, organized by context and environment. It supports two standard kinds of state:

- **User settings and secrets**: accounts, tokens, sessions, and per-user configuration. Store these
  in a per-user context. `Context` encrypts stored secrets with `Sodium`.
  If the service supports session refresh, users can resume work without new configuration or another login.
- **Module settings**: module-wide defaults, endpoints, and feature flags that are not tied to a
  single user. Store these in a module-scoped context.

Your module must expose functions and object types for specific contexts and environments.
Users must be able to read, write, and manage contexts programmatically.
They must be able to select the environment or context that their functions use.
Use `Context` for both kinds of state to give integration modules the same settings model.
Keep secrets out of source code, logs, and unencrypted files.

## Data modules

Data modules convert between representations or manage an in-memory structure. `Hashtable` is the
reference implementation. `Base64`, `Json`, `Lua`, `Hcl`, `Sodium`, and `Uri` follow the same pattern.

<a id="the-neutral-object-is-the-pivot"></a>

### Conversions use the neutral object model

Every conversion uses the neutral PowerShell object model
(`[PSCustomObject]` / `[hashtable]` / `[PSObject]`) as the intermediate representation.
`ConvertFrom-<Format>` parses a format-specific representation into an object.
`ConvertTo-<Format>` converts an object into the target format.

To convert between formats, first convert the source representation to an object.
Then convert the object to the target format.
The common object model removes the need for a separate converter for each pair of formats.

Always provide both conversion directions so users can convert from a format to an object and back.

### Verb vocabulary

| Verb pattern | Purpose |
| ------------ | ------- |
| `ConvertFrom-<Format>` | Format-specific text/representation → `[PSCustomObject]` / `[hashtable]` |
| `ConvertTo-<Format>` | `[PSCustomObject]` / `[hashtable]` → format-specific text/representation |
| `Import-<Noun>` | Read objects from a file or data store |
| `Export-<Noun>` | Write objects to a file or data store |
| `Format-<Noun>` | Produce a normalized or human-readable representation |
| `Merge-<Noun>` | Combine two structures |
| `Compare-<Noun>` | Identify differences between two structures |
| `Test-<Noun>` | Validate a value or structure |
| `Remove-<Noun>Entry` | Remove elements that match specified criteria |

The `Hashtable` module demonstrates `ConvertFrom-Hashtable`, `ConvertTo-Hashtable`,
`Import-Hashtable`, `Export-Hashtable`, `Format-Hashtable`, `Merge-Hashtable`, and
`Remove-HashtableEntry`.

## Where this connects

- [PowerShell module standard](powershell-module-standard.md): layout, private functions, and the mandatory context parameter.
- [Repository Standard](repository-standard.md): repository files, README content, and instructions for agents.
