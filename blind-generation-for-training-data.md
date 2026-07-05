---
name: blind-generation-for-training-data
description: Collect fine-tuning/distillation traces by having models solve blind, filter by exact match — never by revealing the answer and asking for an explanation
type: insight
tags: [ml, fine-tuning, distillation, synthetic-data, rejection-sampling]
created: 2026-06-28
---
When generating reasoning traces to fine-tune or distill a smaller model, give the agent the problem without the answer, let it derive a solution, and keep only traces that reach the exact correct answer (rejection sampling / STaR recipe). The alternative — handing the model the known correct output and asking it to explain — produces post-hoc rationalization: the model reverse-engineers a plausible-sounding justification rather than deriving the answer. A student trained on rationalizations learns to mimic the surface of reasoning, not the substance, and performance craters on novel problems where the surface pattern doesn't transfer.

Practical gate: agent sees demos + optional draft, truth hidden → reason → produce output → exact-match filter against ground truth → keep only hits. Over-provision ~1.5–2× agents to absorb rejection-rate waste.

Evidence: an ARC-AGI corrector-model design (2026-06-25). Matches STaR (Zelikman 2022) and rejection-sampling fine-tuning literature; the work-log labels the failure mode explicitly as "imitate, not reason."

Connections: [[generate-a-comparison-set-select-ruthlessly]] (ruthlessness at the filter stage); [[precommit-falsification-gates-with-stop-bands]] (blind generation is a pre-commitment that prevents answer-contaminated traces from entering the set).
