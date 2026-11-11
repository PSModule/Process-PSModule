---
title: Workflow triggers
description: The scheduling and cleanup contract for publishing runs, pull-request updates, and pull-request closure.
---

# Workflow triggers

Process-PSModule separates production delivery, replaceable pull-request feedback, and prerelease cleanup.

| Page | Owns |
| --- | --- |
| [Spec](spec.md) | Required behavior, isolation, capacity, and acceptance scenarios. |
| [Design](design.md) | Event routing, concurrency ownership, cancellation, and cleanup coordination. |

The [framework spec](../spec.md) owns build, test, versioning, and publication requirements.
