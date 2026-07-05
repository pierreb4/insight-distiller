#!/bin/bash
# sync-from-graph.sh — pull ENGINE files from the private working graph into this
# public repo. One-way, allowlist-driven: engine code only, never nodes/design/state.
#
# The working graph (~/.claude/insights, private) is where the engine is developed and
# dogfooded; this repo is the publish target. Run, review `git diff`, commit deliberately.
#   tools/sync-from-graph.sh [path-to-working-graph]   (default: ~/.claude/insights)
set -euo pipefail
SRC="${1:-$HOME/.claude/insights}"
DST="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$SRC/distill.sh" ] || { echo "no distill.sh under $SRC — wrong source?" >&2; exit 2; }

FILES=(distill.sh distill-run.sh distill-eval.sh distill-crosspass.sh distill-missed.sh
       boundary-probe.sh golden-anti-test.sh)
DIRS=(hooks systemd launchd shims skills)

for f in "${FILES[@]}"; do cp -f "$SRC/$f" "$DST/$f"; done
for d in "${DIRS[@]}";  do rm -rf "${DST:?}/$d"; cp -R "$SRC/$d" "$DST/$d"; done

# Nodes, INDEX, BOOTSTRAP, README are curated separately in THIS repo — never synced.
echo "engine files synced from $SRC"
echo "personal-token check on synced files:"
if grep -rn 'pierre\|/home/[a-z]' "${FILES[@]/#/$DST/}" "${DIRS[@]/#/$DST/}" 2>/dev/null | grep -v '<user>'; then
  echo "^^ REVIEW the hits above before committing" >&2; exit 1
else
  echo "  clean"
fi
echo "now: git -C $DST diff  — review, then commit."
