---
name: calibrate-variance-before-reading-metric-deltas
description: Measure a metric's run-to-run variance before reading any delta as signal — without a noise floor, a "regression" or "improvement" may be sampling noise you'll wrongly chase or trust.
type: insight
tags: [methodology, measurement, variance, evaluation, statistics, meta-cognition]
created: 2026-06-17
---

Before treating a metric delta as improvement or regression, **measure the
metric's own run-to-run variance** and establish a noise floor. A sequence like
0.32 → 0.24 → 0.28 carries no information until you know whether the band is
±0.02 or ±0.10. A delta inside the noise band is **not a result** — acting on it
means chasing ghosts or trusting luck.

Evidence (arc-prize, June 12): a deliberate variance study "rewrote our
methodology." The apparent 25% regression to 0.24 had to be read against
calibrated variance before deciding whether it was real or a sampling artifact —
and the calibration is also what lets you set honest gate thresholds in the
first place.

Especially load-bearing when each measurement is **expensive** (so n is small
and the temptation to over-read a single number is highest) and when one number
gates a decision. This is the measurement substrate under
[[precommit-falsification-gates-with-stop-bands]] — the STOP/keep band edges are
only honest if they sit relative to the noise floor — and it guards the background-spend-policy problem
against spending budget chasing noise.
