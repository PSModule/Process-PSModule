# PSModule process marketplace

This repository is a GitHub Copilot CLI plugin marketplace. The marketplace
and its `psmodule-process` plugin are versioned **1.0.0**.

## Install

Add the marketplace and install the plugin:

```console
copilot plugin marketplace add PSModule/Process-PSModule
copilot plugin install psmodule-process
```

The plugin provides the
[`pester-migration`](./plugins/psmodule-process/skills/pester-migration/SKILL.md)
skill for migrating every Pester test set in a PSModule repository to Pester
6.1.0. Verify the installation with:

```console
copilot plugin list
/skills list
```

The marketplace manifest is
[`marketplace.json`](./marketplace.json); plugin metadata is in
[`plugin.json`](./plugins/psmodule-process/plugin.json).
