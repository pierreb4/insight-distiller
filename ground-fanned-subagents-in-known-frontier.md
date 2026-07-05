---
name: ground-fanned-subagents-in-known-frontier
description: Fresh subagents fanned out for exploration/research start with zero project context — seed their prompt with the current known frontier (what's already been tried/ruled out) as an explicit baseline to beat, or they burn their slots re-deriving generic or already-covered ground.
type: insight
tags: [agent-orchestration, exploration, prompting, delegation]
created: 2026-07-01
---
Twice in one session, before launching an exploration-harness fan-out, the operator caught that a bare/terse question handed to fresh subagents "would reach fresh subagents with zero project context and produce generic ML advice," and deliberately enriched the prompt with project grounding — the constraints already discovered, the pipeline already deployed, and critically "the full list of already-closed levers (so the generators spend their slots on genuinely new ground, not re-treading what we've killed)." The second instance went further: seeding the harness with "the entire known frontier ... as the exploitation baseline to beat — so the run is forced to find genuinely new territory."

The reusable pattern: stateless subagents have no memory of prior sessions, so absent explicit grounding they default to the center of the distribution for the bare question — generic, mainstream answers indistinguishable from what any onlooker would say, or a re-discovery of ideas already tried and killed. Exploration/research fan-outs only pay for themselves if the agents are pushed past a known baseline; that requires the orchestrator to explicitly hand over (a) what's already been tried and ruled out, and (b) the current best answer(s), framed as the bar to clear — not just a well-worded question. This is a concrete mechanism, not just "give context": treat the known frontier as an explicit exploitation-baseline artifact injected into every fan-out prompt.

Sharpens [[engineer-exploration-over-exploitation]] (which covers forcing diversity via stances/model-families/phase-separation but not this grounding step) and `agent-involvement-policy` (delegate-then-synthesize, but not what the delegation prompt itself needs to contain). A human reviewer may want to merge this in as an added clause on one of those two rather than keep it standalone.
