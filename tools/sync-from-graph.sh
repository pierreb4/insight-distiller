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
# Case-insensitive, and every token comes from the machine, never from this file, so the check
# itself names nothing private: /home/<name>, the user and host names, and each pattern in
# $SRC/.publish-denylist (one ERE per line, kept in the private graph, never synced). A
# case-sensitive name grep let a capitalised name through in the 2026-09-30 sync.
pats=('/home/[a-z]' "$(id -un)" "$(hostname -s)")
if [ -f "$SRC/.publish-denylist" ]; then
  while IFS= read -r p; do case "$p" in ''|'#'*) ;; *) pats+=("$p") ;; esac; done < "$SRC/.publish-denylist"
else
  echo "  (no $SRC/.publish-denylist: checking user and host names only)"
fi
rx=$(IFS='|'; printf '%s' "${pats[*]}")
if grep -rniE "$rx" "${FILES[@]/#/$DST/}" "${DIRS[@]/#/$DST/}" 2>/dev/null | grep -v '<user>'; then
  echo "^^ REVIEW the hits above before committing" >&2; exit 1
else
  echo "  clean (${#pats[@]} patterns)"
fi
echo "now: git -C $DST diff  — review, then commit."
