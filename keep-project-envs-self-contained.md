---
name: keep-project-envs-self-contained
description: A project that implicitly leans on a sibling repo's virtualenv/PATH/tooling breaks the moment that sibling's env activates, moves, or upgrades; give each project its own pinned, self-contained env.
type: insight
tags: [engineering-discipline, environment, dependencies, durability, reproducibility]
created: 2026-06-17
---

Don't let a project depend on a *sibling* repo's environment — its virtualenv,
its PATH entries, its globally-installed CLIs. That implicit coupling works right
up until the sibling's env auto-activates, moves, or upgrades, and then your
project breaks for a reason that has nothing to do with your project.

Evidence (June 14): a project's ops broke because a **sibling repo's venv
auto-activated and PATH lost `kaggle`**. The fix was to make the project a
self-contained Claude start — a repo-local Python 3.12 `.venv` with the exact
tool versions pinned (`kaggle 2.2.1`, the version its ops quirks were tuned to).
The tell that you have this bug: *"it only works when I'm in the other repo's
shell."*

Same root principle as [[durable-nvm-node-in-claude-hooks]]: **don't pin your
correctness to a brittle external detail you don't control** — make the
dependency explicit and local. Sibling-env coupling and a hardcoded nvm path are
two faces of the same fragility.
