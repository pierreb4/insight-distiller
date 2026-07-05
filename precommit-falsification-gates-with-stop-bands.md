---
name: precommit-falsification-gates-with-stop-bands
description: Before an expensive experiment, pre-commit the decision gate — the outcome bands and what each means, including an explicit STOP/kill band — so the result adjudicates cleanly instead of becoming fuel for post-hoc rationalization.
type: insight
tags: [methodology, research, falsification, decision-making, experiment-design, meta-cognition]
created: 2026-06-17
---

Write the **decision rule before you run the experiment**: enumerate the outcome
bands and what each one will *mean*, and crucially include an explicit **STOP
band** — the outcome that kills the hypothesis or halts the spend. Then a result
*adjudicates to a band* instead of becoming raw material for in-the-moment
optimism to rationalize.

Evidence (arc-prize, June 11–13): a training gate was pre-committed with a STOP band —
*"if the retrain still yields neural-exact 0 and fewer than 4 near-misses, the
hypothesis is falsified at achievable scale; no further training spend without a
structurally new hypothesis."* It later adjudicated to exactly that band and the
lane was closed cleanly, no relitigating. Same shape for the sibling gates — every
gate pre-committed in the plan doc, gate-before-measurement order.

The **STOP band is what makes it a real gate**: it pre-authorizes *quitting*,
which momentum and sunk cost otherwise resist. This is a hand-authored spend
policy — directly the question in the background-spend-policy problem (learn when/how-much to spend on a
background problem). You can't draw honest band edges without
[[calibrate-variance-before-reading-metric-deltas]], and the cheapest gate to
run first is [[cheap-probe-before-expensive-run]].
