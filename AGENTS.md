# Agents

## Purpose

Use this file to understand how agents should gather context and execute work in
this repository.

## Core operating standard

1. Treat repository controls (linters, security checks, policies) as correct by
   default.
2. Align implementation with controls before considering exceptions.
3. If an exception is needed, make it explicit, minimal, and documented in code
   and PR context. Never bypass controls silently.

## Canonical context resolution

Determine repository identity from Git metadata (for example, `origin` remote and
repository settings). Do not hardcode a specific owner or host unless the task
explicitly requires it.

Process context in this order:

| Order | Source | What to read first | Why |
| --- | --- | --- | --- |
| 1 | Local repository | `README.md`, `CONTRIBUTING.md`, local docs index/start page | Local behavior and contribution rules are authoritative for this repo. |
| 2 | Project/framework guidance | Framework or shared project docs referenced by this repo | Align with shared implementation patterns used by sibling repos. |
| 3 | Central organization guidance | Organization-level docs and standards | Apply global policy after local/project specifics are known. |

## Documentation standards for commands and repos

1. Use canonical repository URLs in docs (full URLs such as
   `https://github.com/owner/repo`) instead of ambiguous short names.
2. For install and synchronization instructions, provide equivalent examples for
   native shells on Windows, macOS, and Linux.
