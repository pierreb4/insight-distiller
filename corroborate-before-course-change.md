---
name: corroborate-before-course-change
description: A confident finding from ONE source (a subagent, a one-pass reviewer, a single probe/run) that would reverse your direction is a WEAK PRIOR, not evidence — require a structurally INDEPENDENT check (one that cannot have been influenced by or derived from the first) before reversing a hypothesis, cancelling a fix, or promoting a result. Confident tone is not replication. The general principle of which suspect-the-measurement (the "source" is your measurement) and the verified-tier (corroborate a judge with an independent signal) are special cases.
type: insight
tags: [verification, epistemics, subagents, diagnosis, cross-validation, attribution, meta-cognition]
created: 2026-06-25
---

When a SINGLE source — a subagent, a one-pass reviewer, a single probe or run — produces a confident
finding that would make you **reverse a hypothesis, cancel a (correct) fix, or promote a result**, treat
it as a weak prior, not as evidence. Require corroboration from a **structurally independent** source —
one that cannot have been influenced by, or derived from, the first — before you act. **Confident tone is
not a substitute for replication**, and a single convenient test (even from a confident agent) is not a
verdict.

**The independent check must be blind to the first source's conclusion** — a re-run of the same thing, or
a second pass primed by the first, does not count. If no independent check is feasible, *lower your
confidence* rather than acting on the single source.

**Instances (cross-project):**
- **arc-agi-3:** a subagent confidently diagnosed "determinism coupling" as the regression cause and would
  have cancelled the original (correct) fix; an own **attribution-clean probe** showed the real cause (a
  too-broad match firing 416× on the affected level), confirming the original hypothesis. Separately, a
  second subagent's "clean fire-probe" on a hand-picked subset missed a regression on an excluded game —
  one convenient test from a confident agent, insufficient.
- **arc-prize-2026:** the persistent "stability-basin / scale" story of the TTT failure (a confident
  diagnosis carried across many sessions) was overturned only by an **independent profiler probe** that
  exposed the real cause — a tokenizer-serialization bug producing grad-0. See
  [[restore-a-gradient-before-reasoning-harder]].
- **seven-dpt-mcp (the Verified tier):** the insight-eval refuses to act on an LLM-judge's `anti` verdict
  (the model grading its own prose) unless an **independent non-prose signal** corroborates it — a user
  correction in the transcript, or a git revert. The same move, applied to memory-writes.

**How to apply:** before reversing a hypothesis, cancelling a fix, or promoting a finding on one source's
output, ask "what **structurally independent** check could confirm or deny this?" — then run it. This is
the general principle of which [[suspect-the-measurement-before-the-artifact]] (the "source" is your
measurement) and the convergence threshold in `distillation-policy` (promote only on agreement across
blind passes) are special cases. (Well-established beyond us — LLM self-reports and judges are known to
need independent grounding; this node is the working reminder to *actually run the independent check
before changing course*.)

**Connections:** [[suspect-the-measurement-before-the-artifact]] · [[generate-a-comparison-set-select-ruthlessly]]
(independent *sources* here, vs that node's independent *alternatives*) · `agent-involvement-policy`
(verifying a subagent's output is a distinct concern from involving it) · `distillation-policy`
(the convergence threshold is one application).
