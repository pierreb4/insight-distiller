# Managed & verification — design-partner program

`insight-distiller` is open source; run it yourself and never talk to us. This page is for
teams who'd rather not self-host, or who need an *independent* check they can show someone.

Two engagements, both early and hands-on (a small number of design-partner slots):

## 1 · Run it for you (managed memory)

We operate the pipeline for your team — capture, hourly-gated distillation, the timers, and
the human-review loop — so your agents accumulate durable mistake-avoidance memory without
anyone babysitting cron. You keep the graph (it's just markdown in your git repo); we keep it
healthy and the canaries green.

## 2 · Verify an agent-memory setup (the independent check)

An independent assessment of an agent-memory / AI-coding setup — your own, or a vendor you're
evaluating — built on the discipline this repo is about:

- **Sandbox confinement** — an adversarial red-team that tries to make the memory pipeline's
  agents escape their sandbox; verdict by filesystem diff, not opinion (see `boundary-probe.sh`).
- **Memory-persistence safety** — cross-session bleed and prompt-injection tests against the
  memory surface.
- **Regression** — does a change actually stop the recurring mistake, measured (reuse +
  golden anti-tests), or did it just feel better?

The deliverable is an *executed* result you can hand a customer's security team — not a
checklist, and not a cryptographically-signed self-report. If it would break, we show you where.

## Pricing & how to start

Design-partner pricing (early-adopter rate, held while we build with you). To start — or just
to see if you're a fit → **[tell us what you're running](https://docs.google.com/forms/d/e/1FAIpQLSd_Mw31bkBUS7nPrMlnwzlw2DtQpNpFZP52vEqawDM_M4w4hQ/viewform)**.

*Status: early. This is a working single-operator setup, freshly opened — engagements are
correspondingly hands-on and limited.*
