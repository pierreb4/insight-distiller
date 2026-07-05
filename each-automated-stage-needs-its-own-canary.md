---
name: each-automated-stage-needs-its-own-canary
description: Automated pipelines fail silently — a green upstream canary doesn't certify the next stage. Give each stage its own health signal, never advance progress state on a failed run, and validate the happy path in the real execution context, not a proxy.
type: insight
tags: [reliability, silent-failure, observability, agents, methodology, meta-cognition]
created: 2026-06-20
---

A multi-stage automated pipeline fails silently by default. This generalizes
`transcript-slice-anchor-on-last-assistant` (a Stop hook that exited 0 and wrote
nothing): the auto-distiller died on an auth 401 and stayed invisible **three ways at
once** — each a reusable lesson.

1. **A green upstream canary doesn't certify the downstream stage.** The tier-1
   capture canary (firehose last-write age) was fresh, so everything *looked* healthy
   — but the tier-1→2 distiller *agent* was dead. Each stage needs its OWN health
   signal; an upstream "OK" says nothing about the stage after it. (Fix: a per-run
   `rc` line the `--status` canary reads.)

2. **A failure must never advance its own progress state.** The 401'd run still
   advanced its `.last-staged` marker, so the gate read the backlog as "triaged" and
   stopped retrying — a failure that marks itself done is self-hiding *and*
   self-perpetuating. Advance state only on a clean exit; on failure, preserve the work
   for retry and log it loud.

3. **Validate the happy path in the REAL execution context, not a proxy.** The
   boundary-probe spawned a real agent and PASSED — but under *interactive* auth, while
   the timer runs the agent *headless*, where it 401'd. A test in the wrong context is a
   false positive (cf. [[test-boundaries-by-forcing-violation]] — passing the wrong
   test). Exercise the autonomous path *as the scheduler actually runs it*.

The through-line: a failure is "silent" when it **exits 0, advances state, or passes a
proxy test** while the real work never happened. Make each stage loud — its own canary,
fail-closed on state, in-situ validation. Judge automation by the artifact it should
have produced ([[cheap-probe-before-expensive-run]] is the pre-flight twin), never by
the mere absence of an error.
