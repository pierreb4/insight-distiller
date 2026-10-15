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
# absent; a replay minutes later captured it fine — a race, not logic). A finished turn
# always ends in a text block, so retry until the LAST assistant entry carries text.
#
# PER-SESSION CURSOR (2026-09-24), replacing the turn slice. The slice lost text two ways,
# both shown on 09-23: (1) its boundary was the last "type":"user" entry, and
# every tool_result is one — so only text after the turn's LAST tool call was kept (the
# 09:04 turn's 4 text blocks yielded 1); (2) the retry accepted any NON-EMPTY slice, so an
# earlier text block passed while the final one was unflushed (09:08:53 lost 3 markers).
# Now every assistant text entry newer than the last one logged is captured; the cursor
# holds that entry's timestamp, so a block flushed too late is taken by the NEXT Stop.
CURDIR="$HOME/.claude/insights/.stop-cursor"; mkdir -p "$CURDIR" 2>/dev/null
CURSOR_F="$CURDIR/${SESSION:-none}"
ASSTBUF=$(mktemp); trap 'rm -f "$TAILBUF" "$ASSTBUF"' EXIT
for try in 1 2 3; do
  tail -n 20000 "$TRANSCRIPT" > "$TAILBUF"
  grep '"type":"assistant"' "$TAILBUF" > "$ASSTBUF"
  tail -1 "$ASSTBUF" | jq -e '[.message.content[]? | select(.type=="text")] | length > 0' >/dev/null 2>&1 && break
  sleep 2
done
CURSOR=$(cat "$CURSOR_F" 2>/dev/null)
# First Stop of a session under the cursor: start at the last real prompt (a user entry that
# is not a tool_result) — never at the tail's top, which would re-log history.
[ -n "$CURSOR" ] || CURSOR=$(grep '"type":"user"' "$TAILBUF" | grep -v '"type":"tool_result"' | tail -1 | jq -r '.timestamp // empty' 2>/dev/null)
[ -n "$CURSOR" ] || CURSOR=$(tail -2 "$ASSTBUF" | head -1 | jq -r '.timestamp // empty' 2>/dev/null)
CAPTURED=$(jq -r --arg c "$CURSOR" --arg s "$SESSION" --arg t "$TS" '
    select((.timestamp // "") > $c)
    | .message.content[]?
    | select(.type=="text")
    | "\($t) [\($s[0:8])] \(.text)\n---"
  ' "$ASSTBUF" 2>/dev/null)
NEWCUR=$(jq -r --arg c "$CURSOR" 'select((.timestamp // "") > $c and any(.message.content[]?; .type=="text")) | .timestamp' "$ASSTBUF" 2>/dev/null | sort | tail -1)
[ -n "$NEWCUR" ] && echo "$NEWCUR" > "$CURSOR_F"

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
#
# A marker only counts if it names a NODE THAT EXISTS (2026-09-09). 65 of the first 166 tallied
# hits (39%) named no file anywhere in the store — CLAUDE.md rules, project-memory slugs, and
# lessons recalled by a name that was never written — so the tally counted the store's reuse and
# the operator's memory together, and memcheck.py ranked quietness over a corpus that was 39%
# phantom. Unmatched slugs are not noise, though: they are the lessons that keep steering work
# with no node behind them, so they go to their own log as a backlog, never to the tally.
# Citation targets are top-level nodes plus runbooks/ (curated, and the graph already cites it).
#
# Join key + origin (2026-10-01, spark #83's first read). Every line now ends in
# sid=<full session id> msg=<uuid of the assistant entry whose text holds the marker>, so a
# marker resolves to its transcript line; before, [8-char prefix] + Stop time had to be matched
# by hand. An anti written [anti: slug <- WHERE] adds origin=WHERE, whitespace turned into _ so
# each field stays one token and the plain-grep tallies never read words inside it. Why: an anti
# lands in a later REVIEW turn, often in another session, and re-finding the turn that made the
# mistake took one subagent ~78k tokens for 3 hits. The fields trail slug (and alias=), as
# alias= does: readers that take the first four fields are unchanged; distill.sh's two
# end-anchored reads were loosened in the same change.
MARKERS_DIR="$HOME/.claude/insights"
if [ -d "$MARKERS_DIR" ] && [ -n "$CAPTURED" ]; then
  # The same entries and text blocks as CAPTURED (timestamp > CURSOR), scanned per entry so each
  # marker keeps its entry's uuid. Same slug pattern as the old grep; no closing ] required.
  jq -r --arg c "$CURSOR" '
      select((.timestamp // "") > $c) | (.uuid // "-") as $u
      | .message.content[]? | select(.type=="text") | .text
      | scan("\\[(applied|anti): *([a-z0-9][a-z0-9-]*)(?: *<- *([^\\]\\n]*))?")
      | [.[0], .[1], $u, ((.[2] // "") | sub("^\\s+"; "") | sub("\\s+$"; "") | gsub("\\s+"; "_"))]
      | @tsv
    ' "$ASSTBUF" 2>/dev/null | \
    while IFS=$'\t' read -r kind slug msg origin; do
      keys="sid=${SESSION:-none} msg=$msg${origin:+ origin=$origin}"
      # aliases.tsv (2026-09-21, spark #87): a project-local name for an existing node credits the HOST;
      # the trailing alias= field keeps the per-node plain-grep tallies working.
      host=$(awk -F'\t' -v s="$slug" '$1==s{print $2; exit}' "$MARKERS_DIR/aliases.tsv" 2>/dev/null)
      if [ -n "$host" ] && [ -f "$MARKERS_DIR/$host.md" ]; then
        echo "$TS [${SESSION:0:8}] $kind $host alias=$slug $keys" >> "$MARKERS_DIR/.markers.log"; continue
      fi
      if [ -f "$MARKERS_DIR/$slug.md" ] || [ -f "$MARKERS_DIR/runbooks/$slug.md" ]; then
        echo "$TS [${SESSION:0:8}] $kind $slug $keys" >> "$MARKERS_DIR/.markers.log"
      else
        echo "$TS [${SESSION:0:8}] $kind $slug $keys" >> "$MARKERS_DIR/.markers-unknown.log"
      fi
    done
fi
exit 0
