# BOOTSTRAP — wire the insight distiller on a new machine

Everything is **user-scope** — no per-project setup; every Claude Code project on the
machine gets the digest + capture automatically.

First, clone this repo to the path the pipeline expects, and point `origin` at a
**private remote of your own** — from here on this directory IS your graph, and the
lessons your sessions distill into it are yours (and often not for the public):

```bash
git clone https://github.com/pierreb4/insight-distiller.git ~/.claude/insights
cd ~/.claude/insights
git remote rename origin upstream        # keep upstream for engine updates
git remote add origin <your-private-remote-url>
git push -u origin main
```

The repo ships with a **seed pack** — 21 general, battle-tested lessons — so recall has
something to bite on from day one; your own nodes join them as the distiller promotes them.

Three mechanisms make the loop:

| mechanism | what | where it's wired |
|---|---|---|
| capture (tier 1) | Stop hook appends each turn's assistant text to `~/.claude/insights/claude-insights.log` (gitignored) | `settings.json` → `hooks/log-insights.sh` |
| digest + missed-surfacer | SessionStart prints the store one-liner; on compact, surfaces un-consulted lessons after a genuine correction | `settings.json` → `distill.sh --brief`, `distill-missed.sh` |
| auto-distill + canary + cross-pass | hourly gated triage → `staging/`; daily real-write canary; daily cross-session pass | systemd user timers (or cron) |

## 0. Prerequisites
`bash`, `jq`, `python3`, `git`, the `claude` CLI **authenticated** (the timers spawn
headless `claude -p` agents). Linux with `systemd --user`, or use the cron fallback.

## 1. Install the capture hook (outside the repo tree — deliberate)
```bash
mkdir -p ~/.claude/hooks
cp ~/.claude/insights/hooks/log-insights.sh ~/.claude/hooks/log-insights.sh
chmod +x ~/.claude/hooks/log-insights.sh
```
Why copy instead of pointing at the repo file: the pipeline's sandboxed agents get write
access *inside* `~/.claude/insights/` (staging + markers). A script the Stop hook *executes*
must live outside that writable tree (`make-invalid-agent-actions-impossible`). After a
`git pull` that changes `hooks/log-insights.sh`, re-run the `cp`: an old copy keeps writing
the old path, and loses assistant text and markers (it sliced the transcript at the last
user entry; the current hook reads on from a per-session cursor).

Capture lives in the store since 2026-09-17 (`~/.claude/insights/claude-insights.log`). On a
machine with an older log at `~/claude-insights.log`, move it there and link the old name:
`mv ~/claude-insights.log ~/.claude/insights/ && ln -s ~/.claude/insights/claude-insights.log ~/claude-insights.log`.

Optional, the store's **pre-commit hook**, once per clone:
`ln -sf ../../hooks/pre-commit ~/.claude/insights/.git/hooks/pre-commit`. It refuses a commit
that drops a staged proposal without a record of it, a new node without a `## Consequences`
section (with a "looked at" line) and a `## Hindsight` section (with a "First available:"
line), and a node whose relation to another goes unstated: it runs `cohere-check.py` from the
repo root, so the two travel together. Write the two sections by hand; the
`consequences.py` the hook's message names isn't part of this repo.

Same deployed-copy pattern for the **distillation skill** — the distiller's operating manual
(when to distill, the ruthless bar, review etiquette), loaded into Claude's context on
`/distilling-insights`:
```bash
mkdir -p ~/.claude/skills
cp -R ~/.claude/insights/skills/distilling-insights ~/.claude/skills/
```
Re-run the `cp -r` after a pull that changes `skills/`; the skill appears after a session restart.

## 2. Merge the hooks into `~/.claude/settings.json`
Merge into the existing `hooks` object (create the file as `{"hooks": {...}}` if absent).
Commands are `$HOME`-relative and fail-silent — a machine without the repo just no-ops.

```json
{
  "SessionStart": [
    { "matcher": "startup", "hooks": [{ "type": "command", "command": "[ -d $HOME/.claude/insights ] && bash $HOME/.claude/insights/distill.sh --brief || true", "timeout": 5 }] },
    { "matcher": "resume",  "hooks": [{ "type": "command", "command": "[ -d $HOME/.claude/insights ] && bash $HOME/.claude/insights/distill.sh --brief || true", "timeout": 5 }] },
    { "matcher": "clear",   "hooks": [{ "type": "command", "command": "[ -d $HOME/.claude/insights ] && bash $HOME/.claude/insights/distill.sh --brief || true", "timeout": 5 }] },
    { "matcher": "compact", "hooks": [{ "type": "command", "command": "[ -d $HOME/.claude/insights ] && bash $HOME/.claude/insights/distill.sh --brief || true", "timeout": 5 }] },
    { "matcher": "compact", "hooks": [{ "type": "command", "command": "[ -d $HOME/.claude/insights ] && bash $HOME/.claude/insights/distill-missed.sh || true", "timeout": 10 }] }
  ],
  "Stop": [
    { "hooks": [{ "type": "command", "command": "~/.claude/hooks/log-insights.sh", "timeout": 10 }] }
  ]
}
```
Validate with `jq . ~/.claude/settings.json`. Hooks load at session start → restart the
session after editing.

## 3. Enable the timers
systemd (preferred — units use `%h`, nothing to edit):
```bash
mkdir -p ~/.config/systemd/user
cp ~/.claude/insights/systemd/distill*.{service,timer} ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now distill.timer distill-writecheck.timer distill-crosspass.timer
```
**Non-systemd machines** (macOS, minimal Linux) first need the `systemd-run` shim — the
scripts spawn agents via `systemd-run --user --scope`; the shim maps `--working-directory`
and execs the command. Copied OUTSIDE the agent-writable repo tree, same rationale as the
Stop hook:
```bash
mkdir -p ~/.local/bin
cp ~/.claude/insights/shims/systemd-run ~/.local/bin/systemd-run && chmod +x ~/.local/bin/systemd-run
```
Then pick ONE scheduler — launchd or cron, not both.

macOS (launchd — StartCalendarInterval fires missed jobs on wake, unlike cron on a
sleeping laptop). The plists carry their own `$HOME`-based `PATH` (`~/.local/bin` for
claude + the shim, homebrew ARM/Intel, pyenv if present); cadence mirrors the timers
(hourly :17, write-check 00:07, cross-pass 00:27):
```bash
cp ~/.claude/insights/launchd/local.distill*.plist ~/Library/LaunchAgents/
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/local.distill.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/local.distill-writecheck.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/local.distill-crosspass.plist
launchctl list | grep local.distill    # -> 3 jobs
```

cron fallback (any non-systemd box):
```cron
17 *  * * * $HOME/.claude/insights/distill-run.sh >/dev/null 2>&1
7  0  * * * $HOME/.claude/insights/distill.sh --write-check >/dev/null 2>&1
27 0  * * * $HOME/.claude/insights/distill-crosspass.sh >/dev/null 2>&1
```
- cron's default `PATH` won't have `claude`/`jq`/the shim — give the distill lines their own
  `PATH=` prefix (or a crontab env line) covering `~/.local/bin` and wherever `jq` lives.
- On macOS the CLI keeps its login in the Keychain, which cron jobs can't read: every agent
  fails `Not logged in` and `--status` shows `real-write .... FAIL`. Use launchd instead: its
  agents run in the login session and reach the Keychain. A `launchctl bootstrap gui/…` over
  ssh works while you're logged in at the console. Only if launchd can't be used, give cron a
  token from `claude setup-token` in `CLAUDE_CODE_OAUTH_TOKEN`.
- The launchd agents log to `~/Library/Logs/<label>.log`; read those when a job seems not
  to run.

## 4. Validate (fresh-machine expectations)
```bash
bash ~/.claude/insights/distill.sh --status
```
- tier-2 graph: **21 nodes, 0 dangling, 0 unindexed** (the seed pack) ✓
- tier-1: *no log / 0 records* is CORRECT until the first Stop hook fires — not a failure.
- Run one Claude session turn, then confirm capture: `tail ~/.claude/insights/claude-insights.log`, and a
  heartbeat line per Stop in `~/.claude/insights/.hook-invocations.log`.
- `systemctl --user list-timers | grep distill` → 3 timers (launchd: `launchctl list | grep -c local.distill` → 3; cron: `crontab -l | grep -c distill` → 3).
- Next morning: `--status` shows `real-write .... OK` (the daily canary proved a sandboxed
  agent can land a file in `staging/`).
- Missed-surfacer is silent by design unless a session contains a genuine user correction;
  test explicitly with `MISSED_TRANSCRIPT=/path/to.jsonl bash distill-missed.sh </dev/null`.

## Multi-machine notes
- `.gitignore` keeps all machine-local state out of git (`.last-*` cursors, `*.log`,
  `signatures/`, `staging/`, the firehose). Each machine triages its own firehose; only
  the curated graph syncs. Fresh cursors on a new machine are handled (falls back sanely).
- Both machines stage proposals independently; **review/promote wherever you review** —
  promotion commits merge additively (slug collisions are rare; resolve at review).
- Pull before review, push after promote: `git -C ~/.claude/insights pull --rebase` / `push`.

## Siblings (separate, optional)
- **[seven-dpt-mcp](https://github.com/pierreb4/seven-dpt-mcp)** — dormant long-running
  problems as an MCP server (Feynman's twelve-problems method); its own build + digest hooks.
- **claude-workflows** — deterministic multi-agent orchestration scripts (exploration
  harness); clone to `~/.claude/workflows`. *Not yet public.*
- A one-line guard in your global `~/.claude/CLAUDE.md` for each lesson you keep tripping
  over is cheap and always loaded — a "watch for" list whose entries point at nodes in
  this graph. The graph holds the full lesson; the guard is just the trigger.
