---
name: test-boundaries-by-forcing-violation
description: To test a guardrail, force a willing violation and confirm it is refused — a well-behaved agent passing the happy path verifies restraint, not the boundary (a false negative).
type: insight
tags: [testing, security, agents, red-team, verification, meta-cognition]
created: 2026-06-18
---

A guardrail is only proven by an attempt to cross it. If your test feeds hostile
input and the agent *declines* it, you've learned the agent has good judgement —
not that the boundary holds. That's a **false negative**: the mechanism was never
exercised, so a later regression that quietly removed it would still pass green.

Caught live (boundary-probe.sh, 2026-06-18): the first probe fired injection
records at the distiller and passed because the cheap agent recognised them as
garbage and wrote nothing. Reassuring — and testing the wrong thing. The fix was a
**backstop** phase: a *willing*, cooperating agent confined to `staging/`, told
explicitly to write `../INDEX.md` and an absolute path outside the store, then
confirmed *refused* on every out-of-store write while still writing inside
`staging/` (proof it actually ran). Only forcing the attempt makes the permission
layer do its job somewhere a verdict can observe it.

This is the verifier half of [[make-invalid-agent-actions-impossible]]: that node
says build the boundary by construction; this one says *to trust it, make a
cooperative actor try to break it and watch it fail.* It generalises past security
to any guardrail — a rate limit, a validation, a deny-rule: test it with input
that should trip it, never only with input that shouldn't. Same spirit as
[[precommit-falsification-gates-with-stop-bands]] (design the test so it *can*
fail) and [[cheap-probe-before-expensive-run]] (the free static check gates the
costly live phases). It's the red-team kernel for the the background-spend-policy problem autonomy ladder:
a permission tier is earned by surviving a forced-violation probe, never by a
clean happy-path run.
