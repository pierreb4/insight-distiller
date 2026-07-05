---
name: distilling-insights
description: >-
  Distill the ~/.claude/insights firehose into durable, linked insight nodes. Use
  when asked to "distill insights", run a distillation round, process the
  claude-insights.log backlog, write or curate insight nodes, or review staged
  auto-distiller proposals. NOT for project-specific notes (those go in that
  repo's memory/), NOT the seven-dpt problem/spark loop, NOT building the deferred
  embeddings tier.
---

# Distilling insights

Turn the raw `~/claude-insights.log` firehose into durable, linked insight nodes
in `~/.claude/insights/`. This is the **model-driven** step between tier-1 capture
and tier-2 curation: the script only *surfaces* candidates; the judgement is
yours. The store is global and **not auto-loaded** — it grows without bloating
sessions, so read `INDEX.md` on demand.

## When to use
- The user asks to "distill insights", run a distillation round, or work the backlog.
- A session surfaced a genuinely durable, cross-project lesson worth a node.
- The user asks to review the auto-distiller's staged proposals (`staging/`).

## When NOT to use
- Project-specific notes, status, benchmark numbers, or one-off fixes → those
  belong in that repo's own `memory/`, never here.
- The seven-dpt problem↔spark loop → that's the seven-dpt MCP, a separate store
  (cross-reference it as `seven-dpt#<id>` in prose, never fold the two stores).
- Building the embeddings/SQLite tier-3 → deferred (seven-dpt#5); don't build it early.

## The bar (be ruthless — a typical round yields 0–2 keepers, often zero)
KEEP only a lesson that is **durable AND reusable across projects**: a method, a
principle, a non-obvious gotcha, a transferable pattern. DROP project status, a
single benchmark, a one-off fix, an n=1 unvalidated claim, anything tied to one
task. When unsure, DROP it. Signal accrues slowly; **zero keepers is a correct,
common outcome** — never invent nodes to look productive.

## Workflow
1. **Surface:** `bash ~/.claude/insights/distill.sh` (records since
   `.last-distilled`). Use `--status` for the health dashboard, `-n 50` to
   override the marker, `--brief` for the one-line summary.
2. **Dedup hard:** read `INDEX.md` first. If a record restates an existing node,
   *extend that node* or skip — don't duplicate. Connect newer→established with
   `[[wikilink]]` edges, liberally.
3. **Write each keeper:** create `~/.claude/insights/<slug>.md` in the node format
   (frontmatter + the insight: what's true *and why it's reusable* + `[[links]]`
   + `seven-dpt#<id>` refs). The full format/convention is in
   `~/.claude/insights/README.md` — read it if anything here is ambiguous.
4. **Index it:** add the one-liner to `INDEX.md`.
5. **Mark the position:** `bash ~/.claude/insights/distill.sh --mark <ISO-ts-of-last-handled-record>`.
   Advance the marker only past records you actually handled.

## Reviewing staged proposals (validate-first)
The auto-distiller (`distill-run.sh`, hourly via `distill.timer`) drafts **only**
into `staging/`, never canonical nodes (the boundary is sandbox-enforced). To
promote: `bash ~/.claude/insights/distill.sh --review`, judge each draft against
the bar above, and only then move a keeper to a canonical `<slug>.md` + `INDEX.md`
entry. **Never auto-promote** — staging exists precisely because the cheap agent's
proposals are unverified.

## Anti-patterns
- A node for something that only matters to one project or task.
- Duplicating an existing node instead of extending it.
- Advancing `.last-distilled` past records you didn't handle (silently loses them).
- Putting insight nodes in a project `memory/` dir (auto-loaded, must stay tiny).
- Treating zero keepers as failure, or padding a round to seem productive.
