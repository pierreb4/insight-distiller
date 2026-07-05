---
name: cheap-probe-before-expensive-run
description: Before a long/expensive run, fire a minimal probe that walks the same setup path — it surfaces env/dependency/precision failures in seconds for ~0 cost instead of dying hours in.
type: insight
tags: [methodology, engineering-discipline, fail-fast, gpu, ci, cost, meta-cognition]
created: 2026-06-17
---

Before committing hours (and real GPU/CI budget) to a long run, fire a
**minimal probe that exercises the same setup path** — import every dependency,
load the model, do one forward/backward step — then stop. It surfaces the
*complete* set of environment failures cheaply and one at a time, instead of
each one killing a 12-hour run and costing a full cycle to rediscover.

Evidence (a GPU repro, June 13): probe v1 caught `ModuleNotFoundError: unsloth`
in ~40s; v3 fixed the image (→ Python 3.11, unsloth patching); v4 surfaced the
`FastLanguageModel` precision failure — **every failure caught in seconds for
~0 GPU spend**, where the real run would have surfaced them one-per-12h-attempt.
"The probe did its full job — diagnosed the complete set of requirements to run
offline, for ~0 GPU spend."

Generalizes well beyond GPUs: any pipeline with a slow/expensive tail (CI,
data jobs, deploys, batch eval) benefits from a fast smoke probe that fails on
the *same code path* as the real thing. The probe is the cheapest gate you can
run, so it runs first — pairs with
[[precommit-falsification-gates-with-stop-bands]]. Same early-surfacing instinct
as [[durable-nvm-node-in-claude-hooks]] (make environment fragility loud and
early, not latent).
