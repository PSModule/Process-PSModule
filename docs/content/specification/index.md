---
title: Specification
description: The requirements and architecture behind Process-PSModule, for those maintaining the pipeline itself.
---

# Specification

These pages describe **why** Process-PSModule exists, **what** it must guarantee, and **how** those guarantees are
delivered. They are aimed at people maintaining Process-PSModule itself. Module authors normally only need the
[guides](../guides/calling-the-workflow.md) and [reference](../reference/settings.md).

| Page | Description |
| --- | --- |
| [Spec](spec.md) | Requirements — an end-to-end pipeline guaranteeing build, testing, quality gates, documentation, and versioned publication. |
| [Design](design.md) | How the spec is delivered — a single reusable workflow composing sub-workflows, and the settings contract. |
| [Principles and practices](principles-and-practices.md) | The versioning, branching, and colocation principles behind the design. |
