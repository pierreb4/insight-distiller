---
name: invert-to-escape-mode-seeking
description: Mode-seeking makes widening the OUTPUT weak — hot resampling or "give me wild ideas" yields paraphrases of the modal answer, because a long shot is a low-probability continuation by construction. Work the CONDITIONING side instead — fix an off-center endpoint and make the model construct a valid BRIDGE from the problem to it, so the improbable destination is PLANTED, not sampled; the model needn't assign it high probability, only justify a path, which it is good at. Apply it to the NO-HITS you are about to dismiss (that is where the mainstream reflex closes early), not the obvious wins. Bounded probe: if no bridge survives scrutiny, discard. Prompt-only (no logit access) — the conditioning-side lever inside engineer-exploration-over-exploitation. Evidence is MIDDLE, not proven: use as a cheap reflex, don't spend big compute on it.
type: insight
tags: [research-methodology, exploration, llm-behavior, ideation, prompting, conditioning, meta-cognition]
created: 2026-07-01
---
A subtype of [[engineer-exploration-over-exploitation]], sharp enough to earn its own trigger.
That node says LLMs emit the **center** of their distribution; this one is the specific move for
when the center is the enemy.

The trap: the intuitive fix for mode-seeking is to widen the **output** — raise temperature,
resample, ask for "10 wild ideas." All weak, because a long shot is a low-probability
continuation *by construction*, so hot sampling just draws more mass from the same modes
(paraphrases, not new mechanisms). You cannot exhort your way off the mode.

The move — **invert to the conditioning side.** Don't ask the model to *reach* an off-center
answer; **plant** the off-center endpoint as fixed, and ask it to construct a valid **bridge**
from the problem to that endpoint. Now the improbable destination is a *given*, not something the
model has to assign high probability to — it only has to justify a path between two fixed points,
which is exactly what it is good at. This routes around mode-seeking instead of fighting it, and
it is **prompt-only**: no logit access, no fine-tuning, works through any API.

Where it pays: run it on the **no-hits** — the options you are one reflex away from dismissing as
non-mainstream. That is where mode-seeking closes early ("no, that's not how this is done"). The
ideas that already lit up don't need it. Operationally: *assume* the off-center thing is exactly
the key; name the **least-obvious bridge** that would have to hold; if none survives a second look,
discard it and keep the no-hit. A **bounded probe against the reflexive "no," not a mandate to find
links** — otherwise it just manufactures rationalizations (the failure mode of
[[blind-generation-for-training-data]] in reverse).

Honest evidence — **MIDDLE, not proven.** `invert-probe` v1 seeded famous breakthroughs as
endpoints and looked like a win (R≈0.96), but that was **recall, not method**: recovering a
documented answer scores memorization — a false positive caught only by the recall-baseline arm and
an off-centeredness pre-screen ([[memorization-confounds-known-answer-evals]]). v2, re-run on
genuinely open problems (no known answer, so no recall confound), came back **MIDDLE** — not a
slam dunk, not a dud. So the correct dose is a **cheap reflex in cheap surfaces**, never a big-compute
default; and calibrate any apparent win against noise first ([[calibrate-variance-before-reading-metric-deltas]]).

Operationalized: baked into the **seven-dpt `evoke` loop** as step 2 (INVERT, run on the no-hits)
so it fires in every project that uses the loop; available as the `invert-probe`
and `exploration-harness` workflows for the heavy, matched-compute treatment. Evaluation companion:
[[steelman-the-long-shot-before-comparing]] (a planted long shot still loses on articulation effort
unless you equalize it before judging).
