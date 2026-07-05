#!/bin/bash
# Stop-hook: append assistant text blocks (prose + Insight blocks) from the
# just-finished turn to ~/claude-insights.log. Filters out thinking + tool_use.
# A "turn" = all assistant JSONL entries since the last user message, because
# each tool-use round creates a new assistant line.
PAYLOAD=$(cat)
TRANSCRIPT=$(echo "$PAYLOAD" | jq -r '.transcript_path // empty')
SESSION=$(echo "$PAYLOAD" | jq -r '.session_id // empty')
LOG="$HOME/claude-insights.log"
[ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ] || exit 0
TS=$(date -Iseconds)

# The turn the Stop just finished ENDS at the last assistant entry, NOT at EOF.
# The transcript now appends trailing user/metadata entries (bridge-session,
# queue-operation, queued prompts) AFTER the assistant's reply, so the old
# "everything after the last user line" slice came up empty. Anchor on the last
# assistant entry; take the last user entry BEFORE it as the turn boundary.
LAST_ASST=$(grep -n '"type":"assistant"' "$TRANSCRIPT" | tail -1 | cut -d: -f1)
LAST_ASST=${LAST_ASST:-0}
LAST_USER=$(grep -n '"type":"user"' "$TRANSCRIPT" | awk -F: -v a="$LAST_ASST" '$1<a{l=$1} END{print l+0}')

awk -v start="$LAST_USER" -v end="$LAST_ASST" 'NR > start && NR <= end' "$TRANSCRIPT" | \
  jq -r --arg s "$SESSION" --arg t "$TS" '
    select(.type=="assistant")
    | .message.content[]?
    | select(.type=="text")
    | "\($t) [\($s[0:8])] \(.text)\n---"
  ' >> "$LOG" 2>/dev/null
exit 0
