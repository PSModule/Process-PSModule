# PSModule process plugin

This repository hosts the canonical `psmodule-process` GitHub Copilot CLI
plugin. The shared MSXOrg marketplace publishes this plugin alongside the
other initiative plugins.

## Install directly

Install the plugin directly from this repository:

```console
copilot plugin install PSModule/Process-PSModule:.github/plugin/plugins/psmodule-process
```

The plugin provides the
[`pester-migration`](./plugins/psmodule-process/skills/pester-migration/SKILL.md)
skill for migrating every Pester test set in a PSModule repository to Pester
6.1.0. Verify the installation with:

```console
copilot plugin list
/skills list
```

The shared marketplace is maintained in
[MSXOrg/docs](https://github.com/MSXOrg/docs/tree/main/.github/plugin).
Plugin metadata is in
[`plugin.json`](./plugins/psmodule-process/plugin.json).
