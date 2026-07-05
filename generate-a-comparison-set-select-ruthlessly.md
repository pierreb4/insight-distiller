---
name: generate-a-comparison-set-select-ruthlessly
description: You can't judge a candidate in isolation — "is this good?" is only answerable against alternatives. Generate a diverse comparison set, then select ruthlessly: breadth at generation, ruthlessness at retention.
type: insight
tags: [methodology, decision-making, agents, search, knowledge-management, meta-cognition]
created: 2026-06-20
---

A single candidate has no quality on its own; "is this good?" only has an answer
*relative to alternatives*. So the route to a better choice is to widen the
**generation** surface (more angles, more neighbours) and then **select ruthlessly**.

Reconciliation with the ruthless distillation bar (0-2 keepers; don't pad) — the
phases differ. **Breadth at generation, ruthlessness at retention.** The extra
candidates are *ephemeral comparison scaffolding*: generate 3-5 to choose 1, then
discard the rest (or keep one recorded runner-up). Generating wide isn't padding the
store; it makes the one kept thing better-chosen. Same shape as the judge-panel (N
attempts → compare → synthesise from the winner) we already use to verify.

Two requirements, or the comparison surface is illusory:
- **Real diversity** — variants must differ in *mechanism or altitude*, not be
  rewordings (the perspective-diverse vs N-identical-refuters distinction).
- **Separate the phases** — if "derive alternatives" leaks into "*keep* the
  alternatives," you've rebuilt the more-stuff-to-sort failure. Generate wide,
  retain narrow.

Applications:
- **Per candidate:** capture each spark / proposal with 2-3 adjacent framings (a
  generalisation, an alternative mechanism, a specialisation) as comparison fodder.
- **Per problem (costlier, speculative):** anticipate a few solution-angles before a
  trick sparks one, so the incoming trick lands against a baseline — mark these
  speculative, hold lightly ([[develop-own-policy-for-fast-churning-domains]];
  validate-first).
- **Keep the runner-up, not just the winner** — record the best *alternative* so a
  future trick re-opens the comparison instead of starting cold.
- **Eval by comparison, not in isolation** — rank a small set rather than score one
  1-5 in a vacuum; comparative judgements are more reliable (sharpens the deferred
  LLM-judge in `distillation-policy`). A comparison needs a baseline:
  [[calibrate-variance-before-reading-metric-deltas]].

Bears on the recurring-issue-detection problem (detection) and the proactive-surfacing problem; the capture
side is adopted as a working convention (see the `capture-with-a-comparison-set`
project-memory note).
