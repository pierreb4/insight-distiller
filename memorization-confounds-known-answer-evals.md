---
name: memorization-confounds-known-answer-evals
description: When you evaluate an LLM discovery/reasoning/generation method by whether it RECOVERS a known answer, a high score can mean the method works OR that the answer was in the training data and the model simply recited it — the two are indistinguishable from the raw recovery number. Two controls, both required: credit the LIFT over a recall baseline (a no-method arm), not the raw score; AND confirm the target is genuinely OFF-CENTER for the model (pre-screen its own ranking), or a method that exploits low-prior targets was never actually exercised. Add a swap/placebo arm too, since a WRONG input can still score high if the model ignores it and drifts back to the memorized answer.
type: insight
tags: [evaluation, benchmarks, memorization, llm-behavior, methodology, meta-cognition]
---
When you evaluate an LLM *discovery / reasoning / generation* method by checking whether it
RECOVERS a known answer, a high score can mean the method works — or that the answer was in
the training data and the model recited it. From the raw recovery number alone the two are
indistinguishable. Most "can the model find X" benchmarks built on documented results bake
this confound in.

Two controls turn raw recovery into an honest signal, and you need **both**:
1. **Credit the LIFT over a recall baseline, not the raw score.** Run a no-method arm that asks
   for the answer with the method's machinery stripped out. The method's real contribution is
   `score(method) − score(recall)`. If the lift is ~0, the method added nothing — the score was
   memory. (Invert-probe 2026-06-30: raw R=0.96 looked like a clean pass; recall baseline 0.95,
   so the lift was **+0.016** — pure recall.)
2. **Confirm the target is OFF-CENTER for the model.** A method that exploits low-prior /
   non-obvious targets cannot be tested on cases the model already ranks #1. Pre-screen: where
   does the intended target fall in the model's *own* relevance ranking? If it's already the top
   pick, the method's premise was never exercised and a "pass" is vacuous. (Same probe: mean
   target-rank = 1 of 5 — every "off-center" endpoint was the model's first choice; the famous
   breakthroughs were too well-known to test a discovery method at all.)

Corollary guard: even a *wrong* planted input can score high if the model ignores it and drifts
back to the memorized answer (placebo overlap 0.70 in that probe) — so a **swap/placebo arm** is
the recall-robust check (is the output actually controlled by the input, or confabulated around
a remembered answer?).

This is the evaluation-side twin of [[blind-generation-for-training-data]] (which keeps memorized
answers OUT of training traces); here you keep memorization from masquerading as capability at
EVAL time. It is a [[suspect-the-measurement-before-the-artifact]] aimed at capability benchmarks,
and the controls are the structurally-independent check of [[corroborate-before-course-change]] —
they are what let a [[cheap-probe-before-expensive-run]] cheaply KILL a confounded design instead
of funding the full study on it. Practical fix when the method targets the unknown: pick test
cases whose answers are genuinely outside the model's reach (recent, held-out, or its own
bottom-k), and judge USEFULNESS/novelty comparatively rather than recovery-of-a-known-answer.
