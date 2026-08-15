# Process workflow fleet canvas

This project-scoped Copilot canvas lets maintainers refresh the authenticated
Process-PSModule caller inventory, inspect each repository against the v8 caller
contract, and send a confirmed migration request to the active agent. The
loopback server never edits another repository or opens a pull request.

## Structure

| File | Responsibility |
| --- | --- |
| `extension.mjs` | Declares the canvas, strict open/action schemas, lifecycle, and SDK wiring. |
| `fleet-service.mjs` | Resolves the repository, stores workspace-scoped state, runs inventory refreshes, serves loopback HTTP, and calls `session.send()`. |
| `fleet-model.mjs` | Normalizes inventory records, encodes the v8 target, computes deltas, and builds structured migration prompts. |
| `renderer.mjs` | Returns the dependency-free dashboard HTML, CSS, and browser interactions. |
| `fleet-model.test.mjs` | Tests normalization, comparison, fail-closed behavior, and prompt generation with built-in Node modules. |

`extension.mjs` must remain an ES module with that exact name. Copilot resolves
`@github/copilot-sdk` for the extension process, so this directory does not need
a `package.json` or `node_modules`.

## Load and open

Copilot discovers immediate children of `.github/extensions/`. After changing
the extension, reload project extensions and confirm
`project:process-workflow-fleet` is running:

```text
extensions_reload({})
extensions_manage({ operation: "list" })
extensions_manage({ operation: "inspect", name: "process-workflow-fleet" })
```

Inspect the declaration, then open a stable panel instance:

```text
list_canvas_capabilities({ canvasId: "process-workflow-fleet" })
open_canvas({
  canvasId: "process-workflow-fleet",
  instanceId: "process-workflow-fleet-main",
  input: { organization: "PSModule" }
})
```

Reopening the same `instanceId` focuses the panel. Durable inventory and
selection state is keyed by the repository workspace under the Copilot session
`files/process-workflow-fleet/` artifact directory, not by the panel ID.
Refreshed evidence is disposable user-specific state and is never committed
automatically.

## Use and test

The dashboard automatically refreshes missing inventory and evidence older than
15 minutes. Its refresh button provides an explicit retry. Both paths run
`.github/scripts/Get-ProcessPSModuleWorkflowInventory.ps1` in authenticated
GitHub mode with target `v8`. A failed refresh clears prior success state and
shows the command context and sanitized diagnostic.

Agent-facing actions are:

- `refresh_inventory`
- `get_summary`
- `get_repository`
- `set_selection`
- `request_migration`

`request_migration` returns a preview by default. It calls `session.send()` only
when `dryRun` is `false`, `confirmed` is `true`, the selection is nonempty, and
the current inventory is complete.

Run deterministic helper tests with:

```powershell
node --test .github/extensions/process-workflow-fleet/fleet-model.test.mjs
```

## Debug

Start with `extensions_manage({ operation: "inspect", name:
"process-workflow-fleet" })`. The reported log captures provider startup and
runtime failures; do not add `console.log`, because standard output carries the
JSON-RPC protocol. Use `session.log()` for deliberate diagnostics.

For lifecycle and schema checks, reload before testing and verify:

1. discovery and capabilities;
2. valid and invalid open input;
3. each declared action and invalid action input;
4. reserved `canvas.*` action rejection;
5. loopback rendering and panel cleanup.

## Extend safely

Keep the SDK declaration in `extension.mjs`, domain logic in
`fleet-model.mjs`, privileged boundaries in `fleet-service.mjs`, and rendering
in `renderer.mjs`. Add a strict JSON schema for every new agent action and a
deterministic test for every comparison or prompt change.

Bind HTTP only to `127.0.0.1`, require the per-panel request token for writes,
and close the server in `onClose`. HTTP handlers may prepare evidence or
requests, but repository mutations must stay in normal Copilot sessions where
the user can see tool calls and permission prompts. Never include credentials
in state, HTML, diagnostics, or migration requests.
