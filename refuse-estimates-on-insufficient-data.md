---
name: refuse-estimates-on-insufficient-data
description: When the data needed to compute an estimate is too sparse (few resolved outcomes, missing cost/failure fields), refuse to emit a number rather than produce a false-precision estimate.
type: insight
tags: [measurement, estimation, epistemic-discipline, false-precision]
created: 2026-07-01
---
A prototype built to estimate a reservation-value / priority metric (Gittins-index-style) for background "sparks" was audited before being trusted, and the audit found only 2 resolved outcomes out of 7 sparks, no cost field, no graded outcome, and zero logged failures. The correct move was not to compute the number anyway with wide error bars, but to refuse to emit it at all: "Reservation values aren't estimable; emitting them would be the exact false-precision trap." (record 2026-06-30T16:33:55, seven-dpt spark #5/Gittins probe).

The reusable lesson: an estimator that *can* produce a number will produce one even when the underlying sample is too thin to support it, and a confident-looking number gets used downstream as if it were calibrated — the failure mode is silent because nothing errors, it just quietly encodes noise as a decision input. The fix is a structural check *before* the estimate is trusted or acted on: does the data actually support this quantity (enough resolved outcomes, the fields the formula needs, some negative examples)? If not, the correct output is "insufficient data," not a hedged guess. This generalizes past this one metric to any pipeline that computes a derived number (priority scores, confidence estimates, ETAs, ROI) from a log of mostly-open/mostly-unresolved records.

Related but distinct from [[precommit-falsification-gates-with-stop-bands]] (which pre-commits how to *read* a result once you have one) — this is about recognizing when the inputs don't support computing a result at all. Also adjacent to [[calibrate-variance-before-reading-metric-deltas]] (noise floor for deltas) and the broader `remediate-fallacies-up-a-ladder` catalogue.
