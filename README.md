# insight-distiller

**Weightless memory for coding agents — with the eval discipline to prove it works.**

Agents repeat mistakes. Session N solves a problem the hard way; session N+40 makes the
same wrong turn, because nothing durable connected them. This pipeline turns that lost
experience into a curated graph of **insight nodes** — short, linked lessons distilled
from your real sessions — and puts them back in reach of every future session.

What makes it different is not the memory. It's the **measurement**:

- **Real-write canary** — a daily probe proves the automated distiller can actually land
  a file where it claims to (silent write-permission failures are the classic way
  pipelines rot for weeks).
- **Pre-committed falsification gates** — every automated stage ships with its decision
  thresholds and explicit STOP bands fixed *before* it runs, so results adjudicate cleanly.
- **Goodhart-resistant reuse metric** — a node earns its keep by being *linked by later
  nodes* (in-degree from real future work), a signal you cannot fake without doing the work.
- **Boundary probe** — an adversarial 3-phase red-team that verifies the pipeline's
  sandboxed agents stay confined, with the verdict rendered by filesystem diff, not judgment.
- **Golden anti-tests** — designed-bad inputs that must be *rejected*, so the ruthless
  quality bar is tested, not asserted.
- **Human review is load-bearing** — the machine only *stages* proposals; nothing becomes
  canonical without promotion. The two-marker design keeps "agent triaged" and "human
  promoted" states honestly separate.

## How it works

```
every session turn ──▶ firehose log            (Stop hook, append-only)
hourly, gated      ──▶ staged proposal nodes    (cheap sandboxed agent, staging/ only)
your review        ──▶ promoted insight nodes   (wikilinked graph + INDEX.md — canonical)
every session      ──▶ digest + missed-lesson surfacing (SessionStart hooks)
```

The graph is markdown + `[[wikilinks]]` in a git repo — no database, no embeddings
required, portable across machines by `git pull` (a working Linux + macOS setup ships in
this repo: systemd timers, launchd agents, and a `systemd-run` shim).

## Quick start

See **[BOOTSTRAP.md](BOOTSTRAP.md)** — clone to `~/.claude/insights`, point `origin` at
your own private remote, wire two hooks and three timers. Ships with a **21-node seed
pack** of general lessons (research methodology, agent ops, eval discipline) distilled
from real agent-assisted engineering, so recall works on day one.

## Status

Early and honest about it: this is the extraction of a working single-operator setup,
freshly opened. Interfaces may move. The eval discipline is the part we consider
load-bearing; if you adopt one thing, adopt the gates-and-canaries habit.

## Want this run for you — or independently verified?

Two things some teams would rather not self-host:

- **Run it for you** — the pipeline, timers, and review loop operated as a managed setup, so
  your agents get durable mistake-avoidance memory without babysitting cron.
- **Verify an agent-memory setup** — an *independent* check (your own, or a vendor you're
  sizing up): a sandbox-confinement red-team, memory-persistence tests (cross-session bleed,
  injection), and measured regression. An executed result you can hand a security team — not a
  checklist, and not a signed self-report.

Early, hands-on, a few design-partner slots. Details in **[MANAGED.md](MANAGED.md)**; if either
is useful → **[tell us what you're running](https://docs.google.com/forms/d/e/1FAIpQLSd_Mw31bkBUS7nPrMlnwzlw2DtQpNpFZP52vEqawDM_M4w4hQ/viewform)**.

## Siblings

- [seven-dpt-mcp](https://github.com/pierreb4/seven-dpt-mcp) — Feynman's twelve-problems
  method as an MCP server: dormant problems + an evoke loop, the complement to this repo's
  mistake-avoidance memory.
- **claude-workflows** — deterministic multi-agent orchestration scripts (exploration harness
  with forced diversity + steelman + comparative judging). *Not yet public.*

## License

Apache-2.0 — see [LICENSE](LICENSE).
