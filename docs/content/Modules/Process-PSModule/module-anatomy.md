# Module Anatomy

This page explains what goes where inside PSModule module repositories.

## Public command surface

Public command files belong in `src/functions/public/<Group>/` and define the module API.

## Private implementation

Private helpers belong in `src/functions/private/<Group>/` and are not exported.

## Types and format

- public and private classes under `src/classes/`
- formatting definitions under `src/formats/`
- type extensions under `src/types/`

## Initialization and shared state

- import-time setup in `src/init/`
- scoped variables in `src/variables/private/` and `src/variables/public/`

## Tests and examples

- behavior tests in `tests/`
- representative usage in `examples/`

The goal is stable repository anatomy so both humans and automation know exactly where to place and find module concerns.
