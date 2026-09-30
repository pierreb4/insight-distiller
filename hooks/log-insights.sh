#!/bin/bash
# Stop-hook: append assistant text blocks (prose + Insight blocks) from the
# just-finished turn to ~/.claude/insights/claude-insights.log. Filters out thinking + tool_use.
# A "turn" = all assistant JSONL entries since the last user message, because
# each tool-use round creates a new assistant line.
PAYLOAD=$(cat)
TRANSCRIPT=$(echo "$PAYLOAD" | jq -r '.transcript_path // empty')
SESSION=$(echo "$PAYLOAD" | jq -r '.session_id // empty')
LOG="$HOME/.claude/insights/claude-insights.log"
TS=$(date -Iseconds)

# Invocation heartbeat — one line per run so a capture gap is diagnosable data,
# not speculation (same canary philosophy as distill-writecheck).
DIAG="$HOME/.claude/insights/.hook-invocations.log"
[ -d "$HOME/.claude/insights" ] && echo "$TS [${SESSION:0:8}] stop-hook t=${TRANSCRIPT:-none}" >> "$DIAG"

[ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ] || exit 0

# Work on the transcript TAIL only: the turn slice lives near EOF and the full file
# grows tens of MB. 20k lines dwarfs any real turn.
TAILBUF=$(mktemp); trap 'rm -f "$TAILBUF"' EXIT

# The transcript is flushed ASYNCHRONOUSLY: at Stop time the turn-final text entry may
# not be on disk yet (2026-07-21: heartbeat proved the hook ran while the final text was
# absent from the slice; a replay minutes later captured it fine — a race, not logic).
# A finished turn always ends in a text block, so an empty slice means not-yet-flushed:
# retry briefly. Slice anchors: the turn ENDS at the last assistant entry, NOT at EOF
# (trailing metadata entries — bridge-session, queue-operation — follow the reply); the
# last user entry BEFORE it is the turn boundary.
CAPTURED=""
for try in 1 2 3; do
  tail -n 20000 "$TRANSCRIPT" > "$TAILBUF"
  LAST_ASST=$(grep -n '"type":"assistant"' "$TAILBUF" | tail -1 | cut -d: -f1)
  LAST_ASST=${LAST_ASST:-0}
  LAST_USER=$(grep -n '"type":"user"' "$TAILBUF" | awk -F: -v a="$LAST_ASST" '$1<a{l=$1} END{print l+0}')
  CAPTURED=$(awk -v start="$LAST_USER" -v end="$LAST_ASST" 'NR > start && NR <= end' "$TAILBUF" | \
    jq -r --arg s "$SESSION" --arg t "$TS" '
      select(.type=="assistant")
      | .message.content[]?
      | select(.type=="text")
      | "\($t) [\($s[0:8])] \(.text)\n---"
    ' 2>/dev/null)
  [ -n "$CAPTURED" ] && break
  sleep 2
done

if [ -n "$CAPTURED" ]; then
  printf '%s\n' "$CAPTURED" >> "$LOG"
else
  # Not an error state worth failing on (a rare turn can truly end without text),
  # but log it so silent gaps stay visible.
  [ -d "$HOME/.claude/insights" ] && echo "$TS [${SESSION:0:8}] stop-hook EMPTY-SLICE after $try tries" >> "$DIAG"
fi

# Marker ledger: pre-parsed [applied: slug] / [anti: slug] tags from the same captured
# text, one line each -> ~/.claude/insights/.markers.log (gitignored via *.log,
# machine-local like the firehose). Readers: distill.sh --status (line count),
# detector/detector.py and ~/.claude/scripts/memcheck.py (per-node applied/anti
# tallies, plain grep) — prose stays in $LOG.
MARKERS_DIR="$HOME/.claude/insights"
if [ -d "$MARKERS_DIR" ] && [ -n "$CAPTURED" ]; then
  printf '%s\n' "$CAPTURED" | \
    grep -oE '\[(applied|anti): *[a-z0-9][a-z0-9-]*' | tr -d '[' | sed 's/: */ /' | \
    while read -r kind slug; do
      echo "$TS [${SESSION:0:8}] $kind $slug" >> "$MARKERS_DIR/.markers.log"
    done
fi
exit 0
