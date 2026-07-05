---
name: sanitize-structured-output-args-for-delimiter-safety
description: Dense, punctuation-heavy strings passed as args to structured-output agents can bleed past close tags, silently dropping required fields on every retry — sanitize to ASCII-clean text first.
type: insight
tags: [structured-output, agent-tools, delimiter, silent-failure, args-hygiene]
created: 2026-06-29
---
When a structured-output agent receives args containing em-dashes, `<=`, `~`, `%`, `$`,
nested parentheses, or slashes, the parser can misidentify content as a close tag, bleed
past it, and silently drop a required field — causing all retries to fail identically.
The failure looks like a model problem (5/5 retries fail) but the cause is the input text.

Observed directly: a Scope agent run succeeded on shorter/simpler args (the JEPA run)
then VOIDed on a denser rephrasing of the same question; the agent's own diagnosis
identified the delimiter bleed. Fix: rephrase args as ASCII-clean, lightly-punctuated
prose before passing to any structured-output call.

**Why it's non-obvious:** the failure is silent and retry-stable — you get the same drop
on every attempt, which looks like a model capability gap rather than an input hygiene
issue. `suspect-the-measurement-before-the-artifact` applies, but the concrete trigger
(punctuation-heavy args → delimiter bleed) is worth naming explicitly.

**Reuse:** applies to any workflow that passes summarized notes, code snippets, or
metric strings as structured-output args — common in research loops and multi-agent
pipelines.

Connections: [[suspect-the-measurement-before-the-artifact]], [[each-automated-stage-needs-its-own-canary]]
