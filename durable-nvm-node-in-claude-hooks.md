---
name: durable-nvm-node-in-claude-hooks
description: In Claude Code hooks under nvm, source nvm.sh + exec node instead of a pinned version path so the hook survives nvm upgrades.
type: insight
tags: [claude-code, hooks, nvm, node, durability]
created: 2026-06-16
---

A Claude Code hook that runs Node under nvm should NOT hardcode
`/home/<user>/.nvm/versions/node/vX.Y.Z/bin/node` — that pin breaks the next
time the pinned patch version is uninstalled. Instead:

```
bash -c 'export NVM_DIR=$HOME/.nvm; [ -s $NVM_DIR/nvm.sh ] && . $NVM_DIR/nvm.sh; exec node <script> <args>'
```

Why each part matters:
- **Source `nvm.sh`; don't trust PATH.** nvm's init lives in `~/.bashrc`, which
  non-interactive / login hook shells don't source, and the hook environment may
  carry a minimal PATH. Sourcing `nvm.sh` explicitly activates the `default`
  alias regardless of PATH. (Verified working under a stripped
  `PATH=/usr/bin:/bin`.)
- **Follows the `default` alias** (here resolved to major `22`), so a later
  `nvm install 22.x` and removal of the old patch version don't break the hook.
- **Force `bash -c`** — nvm.sh uses bash-isms; the harness may invoke hooks via
  dash/`sh`, where sourcing it would fail.
- **`exec`** replaces the shell with node, leaving no lingering wrapper process.

Established 2026-06-16 replacing a pinned `v22.22.0` path in the seven-dpt-mcp
SessionStart digest hook. General to any nvm-based hook/cron, not just this
project.
