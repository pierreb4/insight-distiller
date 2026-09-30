#!/bin/bash
# distill.sh — surface raw insight-log records for distillation into linked
# insight nodes under ~/.claude/insights/.
#
# Model-driven by design: this only SHOWS candidate material from the firehose
# (~/.claude/insights/claude-insights.log). You (the model) read it, then write/extend nodes and
# their [[links]], update INDEX.md, and finally advance the marker. See README.md.
#
#   distill.sh                  show records since .last-distilled (or last 25)
#   distill.sh -n 50            show the last 50 records, ignoring the marker
#   distill.sh --mark <ISO-ts>  record how far you have distilled
#   distill.sh --status         dashboard: capture health, backlog, graph stats
#   distill.sh --brief          one-line health summary (used by the SessionStart hook)
#   distill.sh --gate           exit 0=run / 1=skip — does backlog warrant a distill agent now?
#   distill.sh --review         list staged proposals from the auto-distiller (distill-run.sh)
#   distill.sh --reuse          outcome audit: which promoted nodes get reused (incoming [[links]])
set -euo pipefail

LOG="$HOME/.claude/insights/claude-insights.log"
DIR="$HOME/.claude/insights"
MARK="$DIR/.last-distilled"

# GNU/BSD portability — Darwin's stat/date lack -c/-d. GNU path first so Linux
# behavior is byte-identical; BSD fallbacks parse the two formats we write
# (date -Iseconds markers, %F frontmatter dates).
_mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null; }
_fsize() { stat -c %s "$1" 2>/dev/null || stat -f %z "$1" 2>/dev/null; }
_epoch() { date -d "$1" +%s 2>/dev/null || python3 -c 'import sys; from datetime import datetime; print(int(datetime.fromisoformat(sys.argv[1]).timestamp()))' "$1" 2>/dev/null; }
_fmtts() { date -d "@$1" "$2" 2>/dev/null || date -r "$1" "$2" 2>/dev/null; }
# RESOLVED-MODEL STAMP (2026-09-29) — see distill-run.sh. The write canary runs claude -p with
# --output-format json; its text answer still reaches $ERR (the cause/evidence read) as text mode
# printed it, and its log/result line carries model_alias + model_resolved.
_unwrap() {  # $1=envelope (claude's stdout) $2=file to APPEND the text answer to; prints model_resolved
  # kept IN SYNC with distill-run.sh (which documents it)
  python3 - "$1" "$2" <<'PY'
import json, sys
raw = open(sys.argv[1], "rb").read()
try: env = json.loads(raw)
except ValueError: env = None
ids = []
if isinstance(env, dict) and env.get("type") == "result":
    mu = env.get("modelUsage"); ids = sorted(mu) if isinstance(mu, dict) else []
    t = env.get("result")
    if isinstance(t, str): t += "" if t.endswith("\n") else "\n"
    else:
        # error_during_execution: text mode printed "Execution error" unterminated and never the
        # envelope's errors (2.1.285 runHeadless). Both are added (2026-09-30): the next log line
        # starts on a line of its own, and a cause read (the write canary's) sees the real error.
        errs = env.get("errors") if isinstance(env.get("errors"), list) else []
        t = ("Execution error" + (": " + " | ".join(map(str, errs)) if errs else "") + "\n"
             if env.get("subtype") == "error_during_execution" else "")
    raw = t.encode("utf-8", "replace")
open(sys.argv[2], "ab").write(raw)
print(json.dumps(ids, separators=(",", ":")))
PY
}

case "${1:-show}" in
  --mark)
    ts="${2:-}"
    [ -n "$ts" ] || { echo "usage: distill.sh --mark <ISO-timestamp>" >&2; exit 2; }
    printf '%s\n' "$ts" > "$MARK"
    echo "marked distilled through: $ts"
    ;;
  -n)
    n="${2:-25}"; since=""
    [ -f "$LOG" ] || { echo "no log at $LOG"; exit 0; }
    echo "# last $n records (marker ignored)"; echo
    awk -v since="$since" -v N="$n" '
      BEGIN { RS="\n---\n" }
      length($0) > 0 { rec[++c]=$0; t=$0; sub(/ .*/,"",t); ts[c]=t }
      END {
        start = (c > N) ? c - N + 1 : 1
        for (i = start; i <= c; i++) print rec[i] "\n---"
      }' "$LOG"
    ;;
  --write-check|--canary-write)
    # Real-write canary: actively confirm a sandboxed headless agent can produce a file that
    # LANDS in staging/. Guards the silent class that hid for weeks (the staging write was
    # permission-blocked; rc/marker looked fine). ~20-30s, one cheap agent — run occasionally
    # (manually or from the timer), NOT in --brief. Outcome -> .last-write-check (shown by --status).
    #
    # The canary RECORDS WHY (2026-09-09). It used to discard the agent's output and report every
    # FAIL as the 2026-06-23 permission finding — so a failure with a different cause (the credit
    # limit, expired auth, the scope refusing to start) arrived wearing the old label and its real
    # cause stayed invisible: a hardcoded cause is how the next different failure hides. Line 1 of
    # .last-write-check keeps its `TS OK|FAIL` shape (old readers still parse it); line 2 is
    # `<cause-token> <stage> | <evidence>`, read off what was observed, never assumed. `unknown` is
    # a legitimate verdict here and says so out loud — it is the honest answer when nothing matched.
    # The LAST line (2026-09-29) is `model_alias=<--model> model_resolved=<JSON list>` — line 2 on OK.
    set +e
    OUT="$(mktemp -d)"; ERR="$(mktemp)"; ENVF="$(mktemp)"; mkdir -p "$DIR/staging"
    systemd-run --user --scope --collect --quiet --slice=claude.slice --working-directory="$OUT" -p MemoryMax=2G -- \
      claude -p "Use the Write tool to create ./_writecheck.md with EXACTLY the text: ok. Nothing else." \
      --model "${DISTILL_MODEL:-sonnet}" --output-format json --allowed-tools Write --add-dir "$OUT" --permission-mode acceptEdits > "$ENVF" 2>"$ERR"
    rc=$?; produced=0; landed=0; cause=""; stage=""; evid=""
    resolved="$(_unwrap "$ENVF" "$ERR")"; stamp="model_alias=${DISTILL_MODEL:-sonnet} model_resolved=${resolved:-[]}"
    [ -s "$OUT/_writecheck.md" ] && produced=1
    if [ "$rc" -eq 0 ] && [ "$produced" -eq 1 ]; then
      cp -f "$OUT/_writecheck.md" "$DIR/staging/_writecheck.md" 2>/dev/null && [ -s "$DIR/staging/_writecheck.md" ] && landed=1
      rm -f "$DIR/staging/_writecheck.md"
    fi
    if [ "$landed" -ne 1 ]; then
      # STAGE first — where it broke narrows the cause further than any string match can
      if [ "$produced" -eq 1 ]; then stage="agent produced the file, the copy into staging/ failed (the 2026-06-23 class)"
      else                           stage="the agent never produced a file"; fi
      out=$(tr -d '\000' < "$ERR" 2>/dev/null | tr '\n\t' '  ' | tr -s ' ')
      case "$out" in
        *"redit balance"*|*"usage limit"*|*"quota"*)                          cause=credit ;;
        *"ate limit"*|*429*)                                                  cause=rate-limit ;;
        *"Invalid API key"*|*"uthentication"*|*"/login"*|*"log in"*)          cause=auth ;;
        *"ermission denied"*|*"not allowed"*|*"permission mode"*)             cause=permission ;;
        *"transient scope"*|*"systemd-run"*|*"MemoryMax"*|*"cgroup"*)         cause=sandbox ;;
        *"imed out"*|*"imeout"*)                                              cause=timeout ;;
        *)                                                                    cause=unknown ;;
      esac
      evid=$(printf '%s' "$out" | cut -c1-160)
    fi
    rm -rf "$OUT"; rm -f "$ERR" "$ENVF"; ts=$(date -Iseconds)
    if [ "$landed" -eq 1 ]; then
      { printf '%s OK\n' "$ts"; printf '%s\n' "$stamp"; } > "$DIR/.last-write-check"
      echo "real-write canary: OK — a sandboxed agent produced a file and it landed in staging/  ($ts)  $stamp"
    else
      { printf '%s FAIL\n' "$ts"; printf '%s %s | %s\n' "$cause" "$stage" "${evid:-<no output captured>}"; printf '%s\n' "$stamp"; } > "$DIR/.last-write-check"
      echo "real-write canary: FAIL (rc=$rc, cause=$cause) — the distiller cannot deliver a file to staging/; proposals would be silently lost.  $stamp"
      echo "   stage: $stage"
      echo "   saw:   ${evid:-<no output captured>}"
      [ "$cause" = unknown ] && echo "   cause NOT identified — do not reach for the 2026-06-23 permission finding; read the line above."
    fi
    ;;
  --status|status)
    set +e   # read-only reporting: never abort mid-report on an empty grep
    now=$(date +%s)
    _age() {  # $1 = elapsed seconds -> "Xd Yh / Xh Ym / Xm ago"
      local s="$1"
      [ -z "$s" ] && { echo "?"; return; }
      [ "$s" -lt 0 ] && { echo "just now"; return; }
      local d=$((s/86400)) h=$(((s%86400)/3600)) m=$(((s%3600)/60))
      if   [ "$d" -gt 0 ]; then echo "${d}d ${h}h ago"
      elif [ "$h" -gt 0 ]; then echo "${h}h ${m}m ago"
      else echo "${m}m ago"; fi
    }
    echo "insight store status   ($(date '+%F %H:%M'))"
    echo "============================================"

    # tier 1 — capture firehose
    if [ -f "$LOG" ]; then
      recs=$(grep -c '^---$' "$LOG" 2>/dev/null)
      mt=$(_mtime "$LOG")
      sz=$(_fsize "$LOG" | numfmt --to=iec 2>/dev/null)
      lastrec=$(grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]+\+[0-9:]+' "$LOG" 2>/dev/null | sort | tail -1)
      echo "tier-1  capture    $LOG"
      printf '   records ....... %s\n' "${recs:-0}"
      if [ -n "$mt" ]; then
        printf '   last write .... %s  (%s)  <- canary\n' "$(_fmtts "$mt" '+%F %H:%M')" "$(_age $((now-mt)))"
      else
        echo   "   last write .... ?"
      fi
      printf '   last record ... %s\n' "${lastrec:-?}"
      printf '   size .......... %s\n' "${sz:-?}"
      if [ -n "$mt" ] && [ $((now-mt)) -gt 86400 ]; then
        echo "   WARN  no capture in >24h — if sessions have run, check the Stop hook (log-insights.sh)"
      fi
    else
      echo "tier-1  capture    MISSING: $LOG  (Stop hook not writing?)"
    fi

    # tier 1 -> 2 — distillation.  TWO markers, kept distinct so a big "since last promotion" count
    # can't masquerade as an agent backlog: the cheap agent TRIAGES into staging/ (.last-staged), and
    # REVIEW promotes staged drafts into canonical nodes (.last-distilled, which advances only on review).
    echo
    echo "tier-1->2  distillation"
    STAGEMARK="$DIR/.last-staged"
    if [ -f "$LOG" ]; then
      sbase="$STAGEMARK"; [ -f "$sbase" ] || sbase="$MARK"
      if [ -f "$sbase" ]; then
        ssince=$(cat "$sbase" 2>/dev/null); sts=$(_epoch "$ssince")
        pending=$(awk -v s="$ssince" 'BEGIN{RS="\n---\n"} length($0){t=$0;sub(/ .*/,"",t); if(t>s)c++} END{print c+0}' "$LOG" 2>/dev/null)
        verdict="caught up"; [ "${pending:-0}" -ge 75 ] && verdict="due — gate fires next run"   # 75 = gate T_MIN floor; keep in sync
        printf '   agent triaged . up to %s  (%s)\n' "$ssince" "$([ -n "$sts" ] && _age $((now-sts)) || echo '?')"
        printf '   pending triage  %s new records since  (%s; agent runs hourly-gated)\n' "${pending:-0}" "$verdict"
      else
        tot=$(grep -c '^---$' "$LOG" 2>/dev/null)
        printf '   pending triage  no marker yet — all %s records pending\n' "${tot:-0}"
      fi
      nstaged=$(ls "$DIR"/staging/*.md 2>/dev/null | grep -c .)
      if [ "${nstaged:-0}" -gt 0 ]; then
        printf '   awaiting review %s staged  → distill.sh --review\n' "$nstaged"
      else
        printf '   awaiting review none staged\n'
      fi
      if [ -f "$MARK" ]; then
        psince=$(cat "$MARK" 2>/dev/null); pts=$(_epoch "$psince")
        printf '   promoted to ... %s  (%s — canonical; advances only on review)\n' "$psince" "$([ -n "$pts" ] && _age $((now-pts)) || echo '?')"
        # REVIEW-STALL ALERT (added 2026-09-04). Every other stage here is gated and
        # self-clearing; review is the one manual step, and staging is the one queue with
        # nothing that retires items — so it grows monotonically and each deferral makes the
        # next review more expensive. On 2026-09-04 the marker had sat 20d 21h with 13 staged
        # and NOTHING in the system said so. Gated on staging being non-empty on purpose: a
        # stale marker with an empty staging is "nothing to review", not a stall, and a WARN
        # that fires on nothing is the alert-that-cries-wolf failure this store already has a
        # node for. Threshold 14d = ~2x the observed healthy review interval.
        if [ -n "$pts" ] && [ "${nstaged:-0}" -gt 0 ] && [ $((now-pts)) -gt 1209600 ]; then
          echo "   WARN  review stalled — canonical marker last advanced $(_age $((now-pts))) with ${nstaged} staged; run: distill.sh --review"
        fi
      fi
    fi
    # auto-distiller agent health — it can die silently (401 / crash / disabled timer),
    # leaving empty staging that LOOKS like "nothing to distill" when the agent never ran.
    RUNLOG="$DIR/.distill-run.log"
    if [ -f "$RUNLOG" ]; then
      lastdone=$(grep -E '\] done rc=' "$RUNLOG" 2>/dev/null | tail -1)
      if [ -n "$lastdone" ]; then
        drc=$(printf '%s' "$lastdone" | sed -n 's/.*done rc=\([0-9-]*\).*/\1/p')
        dwhen=$(printf '%s' "$lastdone" | sed -n 's/^\[\([^]]*\)\].*/\1/p')
        printf '   last agent run  %s  rc=%s\n' "${dwhen:-?}" "${drc:-?}"
        case "$drc" in 0|''|*[!0-9]*) ;; *) echo "   WARN  last auto-distill FAILED (rc=$drc) — empty staging = the AGENT died, not 'nothing to distill'. See $RUNLOG" ;; esac
      fi
      # only auth-failures SINCE the last clean run — a resolved 401 shouldn't warn forever
      lastok=$(grep -nE '\] done rc=0' "$RUNLOG" 2>/dev/null | tail -1 | cut -d: -f1)
      # 401 only as the API's status ("API Error: 401 ..."): a bare 401 also matched model ids and
      # counts, and the done line this tail starts on now carries model_resolved (2026-09-30)
      af=$(tail -n +"${lastok:-1}" "$RUNLOG" 2>/dev/null | grep -ciE 'api error:? *401|failed to authenticate|invalid authentication')
      [ "${af:-0}" -gt 0 ] && echo "   WARN  ${af} auth-failure line(s) since the last clean run — headless 'claude -p' can't authenticate (reauth needed)"
    fi
    if command -v systemctl >/dev/null 2>&1; then
      ta=$(systemctl --user is-active distill.timer 2>/dev/null)
      [ "$ta" = "active" ] || echo "   WARN  distill.timer is '${ta:-unknown}' — auto-distiller not scheduled"
      wt=$(systemctl --user is-active distill-writecheck.timer 2>/dev/null)
      [ "$wt" = "active" ] || echo "   WARN  distill-writecheck.timer is '${wt:-unknown}' — daily write-canary not scheduled"
    elif command -v launchctl >/dev/null 2>&1 || command -v crontab >/dev/null 2>&1; then
      # non-systemd machines: launchd agents (macOS) or cron may carry the timers
      # (BOOTSTRAP.md); both exist on a Mac, so WARN only when NEITHER schedules a job.
      lj=$(launchctl list 2>/dev/null); ct=$(crontab -l 2>/dev/null)
      printf '%s\n' "$lj" | grep -q 'local\.distill$' || printf '%s' "$ct" | grep -q 'distill-run\.sh' \
        || echo "   WARN  auto-distiller not scheduled — no local.distill launchd job, no distill-run.sh cron entry"
      printf '%s\n' "$lj" | grep -q 'local\.distill-writecheck$' || printf '%s' "$ct" | grep -q 'write-check' \
        || echo "   WARN  daily write-canary not scheduled — no local.distill-writecheck launchd job, no write-check cron entry"
    fi
    # real-write canary (set by `distill.sh --write-check`; spawns an agent, so it's NOT in --brief)
    if [ -f "$DIR/.last-write-check" ]; then
      wcl=$(head -1 "$DIR/.last-write-check" 2>/dev/null); wcst=${wcl##* }; wcts=${wcl% *}
      wcwhy=$(sed -n '2p' "$DIR/.last-write-check" 2>/dev/null)   # `<cause> <stage> | <evidence>`, written by --write-check
      wcs=$(_epoch "$wcts"); wcage=""; [ -n "$wcs" ] && wcage="  ($(_age $((now-wcs))))"
      printf '   real-write .... %s%s\n' "${wcst:-?}" "$wcage"
      if [ "$wcst" = FAIL ]; then
        echo "   WARN  distiller CANNOT write to staging — proposals silently lost"
        if [ -n "$wcwhy" ]; then echo "         cause: $wcwhy"
        else echo "         cause not recorded (canary predates 2026-09-09) — re-run: distill.sh --write-check"; fi
      fi
      [ "$wcst" = OK ] && [ -n "$wcs" ] && [ $((now-wcs)) -gt 604800 ] && echo "   WARN  write-canary stale (>7d) — run: distill.sh --write-check"
    else
      echo "   real-write .... <never> — run: distill.sh --write-check"
    fi

    # tier 1 -> 2 — cross-session pass (manual / draft-only; sibling script, reused via --status)
    if [ -x "$DIR/distill-crosspass.sh" ]; then
      echo
      echo "tier-1->2  cross-session pass"
      "$DIR/distill-crosspass.sh" --status 2>/dev/null | sed -n '3,$p'
    fi

    # tier 2 — curated graph
    echo
    echo "tier-2  graph      $DIR"
    nodes=$(ls "$DIR"/*.md 2>/dev/null | grep -vE '/(INDEX|README|BOOTSTRAP)\.md$')
    printf '   nodes ......... %s\n' "$(printf '%s\n' "$nodes" | grep -c .)"
    if [ -n "$nodes" ]; then
      edges=$(grep -hoE '\[\[[a-z0-9-]+\]\]' $nodes 2>/dev/null | sort -u | tr -d '][')
      printf '   edges ......... %s unique [[wikilinks]]\n' "$(printf '%s\n' "$edges" | grep -c .)"
      dangling=""
      for slug in $edges; do [ -f "$DIR/$slug.md" ] || dangling="$dangling $slug"; done
      [ -n "$dangling" ] && echo "   dangling ......$dangling  (forward-refs; see README)" || echo "   dangling ...... none"
      unindexed=""
      for f in $nodes; do b=$(basename "$f"); grep -qF "$b" "$DIR/INDEX.md" 2>/dev/null || unindexed="$unindexed $b"; done
      [ -n "$unindexed" ] && echo "   unindexed .....$unindexed" || echo "   unindexed ..... none (all nodes in INDEX.md)"
    fi
    ;;
  --brief)
    set +e   # one-line health summary, e.g. for a SessionStart hook
    [ -f "$LOG" ] || { echo "insight store · capture MISSING ($LOG)"; exit 0; }
    now=$(date +%s)
    recs=$(grep -c '^---$' "$LOG" 2>/dev/null)
    mt=$(_mtime "$LOG")
    a=$((now-${mt:-now}))
    if   [ "$a" -ge 86400 ]; then age="$((a/86400))d"
    elif [ "$a" -ge 3600 ]; then age="$((a/3600))h"
    else age="$((a/60))m"; fi
    sbase="$DIR/.last-staged"; [ -f "$sbase" ] || sbase="$MARK"   # agent-triage marker = true intake backlog, not the review backlog
    since=""; [ -f "$sbase" ] && since=$(cat "$sbase" 2>/dev/null)
    if [ -n "$since" ]; then
      undist=$(awk -v s="$since" 'BEGIN{RS="\n---\n"} length($0){t=$0;sub(/ .*/,"",t); if(t>s)c++} END{print c+0}' "$LOG" 2>/dev/null)
    else
      undist="${recs:-0}"
    fi
    nodes=$(ls "$DIR"/*.md 2>/dev/null | grep -vcE '/(INDEX|README|BOOTSTRAP)\.md$')
    stale=""; [ -n "$mt" ] && [ "$a" -gt 86400 ] && stale="[!] capture stale · "
    # cross-session pass: surface ONLY staged proposals awaiting review. The old manual
    # "x-pass: N new sessions" nudge was retired 2026-06-26 when the crosspass timer began
    # auto-running the gated pass (the nudge to run it by hand is now obsolete). Its N was also a
    # RAW firehose session-count — NOT sandbox-filtered — so it over-reported vs the gate/--status,
    # which count real sessions via count_real_sessions. Staged is the only actionable signal left
    # here (promotion stays manual); the real session-count lives in `--status`.
    cpstg=$(ls "$DIR"/staging/*.md 2>/dev/null | grep -c .)
    cpx=""; [ "${cpstg:-0}" -gt 0 ] && cpx=" · ${cpstg} staged"
    echo "insight store · ${stale}${recs:-0} captured, last write ${age} ago · ${undist:-0} untriaged · ${nodes:-0} nodes${cpx}"
    # ambient marker reminder — the [applied]/[anti] convention only fires if it rides into
    # every session's context (CLAUDE.md alone measured 1 marker in 12.8k records, 2026-07-21)
    mk=0; [ -f "$DIR/.markers.log" ] && mk=$(grep -c . "$DIR/.markers.log" 2>/dev/null)
    echo "markers · when an insight node steers an action, tag it INLINE in visible reply text: [applied: node-slug] / [anti: node-slug] for a miss a node should have prevented — Stop-hook tallies to .markers.log (${mk:-0} so far)"
    # Markers naming no node land in .markers-unknown.log (2026-09-09). Read as a BACKLOG, not as
    # error: a slug applied repeatedly with nothing behind it is a lesson the store never wrote down.
    if [ -s "$DIR/.markers-unknown.log" ]; then
      # The log is append-only, so a slug written up since still sits in it: skip any slug whose
      # node exists NOW (09-21: buildable-is-not-missing, promoted 09-18, was still ranked first).
      live=$(sed -E 's/.*(applied|anti) //' "$DIR/.markers-unknown.log" 2>/dev/null \
             | while read -r s; do [ -n "$s" ] && [ ! -f "$DIR/$s.md" ] && ! grep -q "^$s	" "$DIR/aliases.tsv" 2>/dev/null && echo "$s"; done)
      uk=$(printf '%s\n' "$live" | grep -c .)
      top=$(printf '%s\n' "$live" | sort | uniq -c | sort -rn | head -3 | awk '{printf "%s(%s) ", $2, $1}')
      echo "markers · ${uk:-0} hit(s) name no node — candidates to WRITE, ranked: ${top:-none}"
    fi
    ;;
  --gate)
    # cron/timer decision: exit 0 = backlog warrants a distill-agent run, 1 = skip.
    # Cheap (no LLM). Cadence = f(traffic, open-issues) — the agreed starting policy.
    set +e
    # -- tunables (adjust as we go) --
    T_BASE=200; T_MIN=75; O_REF=5      # threshold T(O)=clamp(T_BASE*O_REF/(O_REF+O), T_MIN, T_BASE)
    FRESH_DAYS=2; FRESH_MIN=20         # freshness floor: backlog>=FRESH_MIN unstaged >FRESH_DAYS -> run
    MIN_INTERVAL_H=3                   # cost ceiling: at most one run per this many hours
    STAGEMARK="$DIR/.last-staged"      # how far the agent has triaged (vs MARK=.last-distilled=canonical)
    LASTRUN="$DIR/.last-run"           # agent run timestamps (appended by the distiller wrapper)
    [ -f "$LOG" ] || { echo "gate: SKIP — no firehose at $LOG"; exit 1; }
    now=$(date +%s)

    # traffic U = records the agent hasn't triaged yet (since .last-staged, else .last-distilled)
    base="$STAGEMARK"; [ -f "$base" ] || base="$MARK"
    since=""; [ -f "$base" ] && since=$(cat "$base" 2>/dev/null)
    if [ -n "$since" ]; then
      U=$(awk -v s="$since" 'BEGIN{RS="\n---\n"} length($0){t=$0;sub(/ .*/,"",t); if(t>s)c++} END{print c+0}' "$LOG" 2>/dev/null)
      ss=$(_epoch "$since"); age_d=$(( (now - ${ss:-now}) / 86400 ))
    else
      U=$(grep -c '^---$' "$LOG" 2>/dev/null); age_d=999
    fi
    U=${U:-0}

    # open issues O = dangling links in the graph + open seven-dpt problems
    nodes=$(ls "$DIR"/*.md 2>/dev/null | grep -vE '/(INDEX|README|BOOTSTRAP)\.md$')
    dangling=0
    if [ -n "$nodes" ]; then
      for slug in $(grep -hoE '\[\[[a-z0-9-]+\]\]' $nodes 2>/dev/null | sort -u | tr -d ']['); do
        [ -f "$DIR/$slug.md" ] || dangling=$((dangling+1))
      done
    fi
    store="${SEVEN_DPT_DB:-${XDG_DATA_HOME:-$HOME/.local/share}/seven-dpt/store.json}"
    probs=$(python3 -c 'import json,sys
try:
    d=json.load(open(sys.argv[1])); print(sum(1 for x in d.get("problems",[]) if x.get("status")=="open"))
except Exception: print(0)' "$store" 2>/dev/null)
    probs=${probs:-0}
    O=$((dangling + probs))

    # dynamic threshold: distill more eagerly when more is open
    T=$(( T_BASE * O_REF / (O_REF + O) ))
    [ "$T" -lt "$T_MIN" ] && T=$T_MIN
    [ "$T" -gt "$T_BASE" ] && T=$T_BASE

    # cost ceiling: too soon since the last run?
    too_soon=0; lastrun_h=999
    if [ -f "$LASTRUN" ]; then
      lr=$(tail -n1 "$LASTRUN" 2>/dev/null); lrs=$(_epoch "$lr")
      if [ -n "$lrs" ]; then lastrun_h=$(( (now-lrs)/3600 )); [ "$lastrun_h" -lt "$MIN_INTERVAL_H" ] && too_soon=1; fi
    fi

    # decision
    go=0; why="below threshold (U=$U < T=$T)"
    if [ "$U" -ge "$T" ]; then go=1; why="volume (U=$U >= T=$T)"; fi
    if [ "$go" -eq 0 ] && [ "$U" -ge "$FRESH_MIN" ] && [ "$age_d" -ge "$FRESH_DAYS" ]; then
      go=1; why="freshness (U=$U unstaged ${age_d}d >= ${FRESH_DAYS}d)"
    fi
    if [ "$too_soon" -eq 1 ]; then go=0; why="cost ceiling (last run ${lastrun_h}h < ${MIN_INTERVAL_H}h ago)"; fi

    [ "$go" -eq 1 ] && v=RUN || v=SKIP
    echo "gate: $v — traffic U=$U · open-issues O=$O (dangling $dangling + open-problems $probs) · threshold T=$T · $why"
    [ "$go" -eq 1 ] && exit 0 || exit 1
    ;;
  --review)
    set +e
    S="$DIR/staging"
    if [ ! -d "$S" ] || [ -z "$(ls -A "$S" 2>/dev/null)" ]; then echo "no staged proposals in $S"; exit 0; fi
    # snapshot the staged set (union, never shrink): hooks/pre-commit fails a commit that
    # drops a slug from staging/ without naming it — the rejection ledger's enforcement
    { cat "$DIR/.last-staged-set" 2>/dev/null
      ls "$S"/*.md 2>/dev/null | sed 's|.*/||; s|\.md$||' | grep -v '^REVIEW-'
    } | sed '/^$/d' | sort -u > "$DIR/.last-staged-set.tmp" && mv "$DIR/.last-staged-set.tmp" "$DIR/.last-staged-set"
    echo "staged proposals ($S) — unreviewed drafts from the auto-distiller:"
    echo
    for f in "$S"/*.md; do
      [ -f "$f" ] || continue
      d="$(sed -n 's/^description:[[:space:]]*//p' "$f" | head -1)"
      echo "  • ${f##*/}"
      echo "      $d"
    done
    echo
    echo "promote:  mv $S/<slug>.md $DIR/   then add its line to $DIR/INDEX.md"
    echo "discard:  rm $S/<slug>.md   AND a '— REJECTED <date>' line in distillation-policy.md § Rejection ledger (pre-commit enforces)"
    echo "when the batch is cleared, sync canonical marker:  distill.sh --mark \"\$(cat $DIR/.last-staged)\""
    ;;
  --reuse|--outcomes)
    # Reuse/outcome audit — the NON-CIRCULAR quality signal for promoted nodes:
    # does a node get *used* (linked to by later nodes)? Reality, not a judge's
    # opinion; Goodhart-resistant (in-degree can't be faked without writing real
    # linked nodes). DIAGNOSTIC only — read it to spot a too-loose bar or merge/
    # retire candidates (seven-dpt#4); never optimize it.
    #
    # "Maturity" is INFORMATION VOLUME — firehose records since a node was created
    # — not wall-clock days: busy spells carry more reuse-opportunity than quiet
    # ones, and a record count doesn't lean on anyone's (or any cron's) sense of
    # time. A node's reuse is judged only once enough later traffic has flowed past it.
    #
    # retired-to-mechanism: a node whose directive is now enforced by a hook/injection
    # (frontmatter `retired-to-mechanism: <date> — <mechanism>`) stops accruing markers
    # precisely BECAUSE the lesson won — classify it out of UNREUSED, never merge-bait.
    #
    # UNREUSED IS THREE CAUSES, NOT ONE (2026-09-09). A mature node with in-degree 0 can mean
    # the bar was too loose (merge/retire it), a mechanism now does its applying, or THE SUBSTRATE
    # MOVED — the CLI bug it routes around was fixed, the model stopped making the mistake. They
    # share a bucket and have opposite remedies, and the third is the expensive one: a live
    # workaround for a fixed bug is read every session and steers against the now-correct default.
    # So a reviewed node carries `unreused-cause: bar|mechanism|substrate — <note>` and the audit
    # prints the split; anything without one reads "needs a call" instead of "review / merge?".
    # No cause is inferred here: marker silence cannot tell "the model stopped doing it" from
    # "nobody hit it this month" ([[absence-needs-a-positive-control]]), so the call stays human
    # and a substrate retirement wants a re-test, not a date.
    set +e
    AGED_RECS="${AGED_RECS:-500}"  # records of later traffic before reuse is judgeable (tunable; ~2-3 distill rounds)
    now=$(date +%s)
    nodes=$(ls "$DIR"/*.md 2>/dev/null | grep -vE '/(INDEX|README|BOOTSTRAP)\.md$')
    [ -n "$nodes" ] || { echo "no nodes yet in $DIR"; exit 0; }
    # LINK SOURCES are a wider set than SCORED NODES (2026-08-30). in-degree used to grep only
    # the top-level nodes, so when runbooks/ was added as a curated consumer of the graph, three
    # nodes it actively cites (colab-idle-timeout, guard-notebook-cell-edits, keep-project-envs)
    # kept reading UNREUSED. Nothing broke: the scan was correct until a new kind of citer
    # existed, then silently stopped covering the corpus — [[gate-on-the-quantity-not-a-correlate]]
    # aimed at this file's own instrument. design/ and runbooks/ are curated and count;
    # staging/ deliberately does NOT — an unreviewed draft must never confer reuse credit on
    # the node it cites, or the bar would grade itself.
    link_srcs="$nodes $(ls "$DIR"/design/*.md "$DIR"/runbooks/*.md 2>/dev/null)"
    # TWO CAUSES ARE COMPUTED, NOT DECLARED (2026-09-14). A `mechanism` call used to be a reviewer
    # matching a node's claim against a script's behaviour by eye — no record that the script ever
    # meant to discharge that node. Now the SCRIPT carries the claim, at the line that enforces it:
    #     # discharges: <node-slug>
    # and this report scans DISCHARGE_ROOTS for the token. mechanism WITHOUT a back-reference is
    # flagged UNBACKED (same class as a malformed token); a back-reference with no frontmatter is
    # printed so the call can be written. Likewise `bar` for prose-only use is evidenced by the
    # .markers.log count per slug, joined here instead of grepped by hand. substrate stays human.
    DISCHARGE_ROOTS="${DISCHARGE_ROOTS:-$HOME/.claude/scripts $HOME/.claude/hooks $HOME/projects/*/scripts $HOME/projects/*/analysis $HOME/projects/*/.claude/hooks}"
    disch=$(grep -rnoE -- '# discharges: [a-z0-9-]+' $DISCHARGE_ROOTS 2>/dev/null || true)
    echo "insight reuse / outcome audit   ($(date '+%F'))"
    echo "============================================"
    echo "reuse = incoming [[wikilinks]] from later nodes;  maturity = firehose records since creation"
    echo "(information volume, not days).  Diagnostic, never a target."
    echo
    printf '   %-46s %5s %6s %5s  %s\n' "node" "age" "info" "in<-" "verdict"
    total=0; reused=0; mature=0; mature_unreused=0; young=0; retired=0
    u_bar=0; u_mech=0; u_sub=0; u_none=0; u_bad=0   # the UNREUSED bucket, split by declared cause
    for f in $nodes; do
      slug=$(basename "$f" .md); total=$((total+1))
      created=$(sed -n 's/^created:[[:space:]]*//p' "$f" | head -1)
      [ -n "$created" ] || created=$(sed -n 's/^[[:space:]]*date:[[:space:]]*//p' "$f" | head -1)
      cs=$(_epoch "$created")
      if [ -n "$cs" ]; then age="$(( (now-cs)/86400 ))d"; else age="?"; fi
      info=0
      [ -f "$LOG" ] && [ -n "$created" ] && info=$(awk -v c="$created" 'BEGIN{RS="\n---\n"} length($0){t=$0;sub(/ .*/,"",t); if(t>c)n++} END{print n+0}' "$LOG" 2>/dev/null)
      info=${info:-0}
      indeg=$(grep -lF -- "[[$slug]]" $link_srcs 2>/dev/null | grep -v "/$slug\.md" | grep -c .)
      [ "$indeg" -gt 0 ] && reused=$((reused+1))
      mech=$(sed -n 's/^retired-to-mechanism:[[:space:]]*//p' "$f" | head -1)
      if   [ -n "$mech" ];               then verdict="retired-to-mechanism ($mech)"; retired=$((retired+1))
      elif [ "$info" -lt "$AGED_RECS" ]; then verdict="new (info<$AGED_RECS)"; young=$((young+1))
      elif [ "$indeg" -gt 0 ];           then verdict="reused"; mature=$((mature+1))
      else
        mature=$((mature+1)); mature_unreused=$((mature_unreused+1))
        cause=$(sed -n 's/^unreused-cause:[[:space:]]*//p' "$f" | head -1)
        ctok=${cause%%[[:space:]]*}; cnote=${cause#"$ctok"}   # note keeps its own em-dash; don't print the token twice
        dref=$(printf '%s\n' "$disch" | grep -E -- "# discharges: $slug\$" | head -1 | sed 's/:# discharges:.*//; s|^'"$HOME"'/||')
        mk=0; [ -f "$DIR/.markers.log" ] && mk=$(grep -cE -- "(applied|anti) $slug\$" "$DIR/.markers.log" 2>/dev/null || true)
        ev=""; [ -n "$dref" ] && ev="$ev [discharged @$dref]"; [ "${mk:-0}" -gt 0 ] && ev="$ev [markers $mk]"
        case "$ctok" in
          bar)       verdict="UNREUSED / bar$cnote$ev"; u_bar=$((u_bar+1)) ;;
          mechanism) if [ -n "$dref" ]; then verdict="UNREUSED / mechanism$cnote$ev"; u_mech=$((u_mech+1))
                     else verdict="UNREUSED -> mechanism UNBACKED: no '# discharges: $slug' in any script$ev"; u_bad=$((u_bad+1)); fi ;;
          substrate) verdict="UNREUSED / substrate$cnote$ev"; u_sub=$((u_sub+1)) ;;
          "")        if [ -n "$dref" ]; then verdict="UNREUSED -> a script discharges this; write 'unreused-cause: mechanism'$ev"
                     else verdict="UNREUSED -> needs a call (bar|mechanism|substrate)$ev"; fi; u_none=$((u_none+1)) ;;
          *)         verdict="UNREUSED -> BAD unreused-cause '$ctok' (want bar|mechanism|substrate)$ev"; u_bad=$((u_bad+1)) ;;
        esac
      fi
      printf '   %-46s %5s %6s %5s  %s\n' "$slug" "$age" "$info" "$indeg" "$verdict"
    done
    echo
    rate=0; [ "$total" -gt 0 ] && rate=$(( reused*100/total ))
    printf '   %s nodes · linked (in-degree>0): %s (%s%%) · mature (info>=%s recs): %s · mature & UNREUSED: %s\n' \
      "$total" "$reused" "$rate" "$AGED_RECS" "$mature" "$mature_unreused"
    [ "$retired" -gt 0 ] && printf '   retired-to-mechanism: %s  (marker stream dry because the lesson WON — excluded from the unreused pool)\n' "$retired"
    if [ "$young" -eq "$total" ]; then
      echo "   note  no node has seen >=$AGED_RECS records of later traffic yet — reuse verdict premature."
    elif [ "$mature_unreused" -gt 0 ]; then
      printf '   UNREUSED by cause: bar %s · mechanism %s · substrate %s · NO CALL YET %s' "$u_bar" "$u_mech" "$u_sub" "$u_none"
      [ "$u_bad" -gt 0 ] && printf ' · malformed/unbacked %s' "$u_bad"
      printf '\n'
      echo "   note  three causes share this bucket and their remedies are opposite — record which one in frontmatter:"
      echo "           unreused-cause: bar — too loose, or in-degree missing a node used only in prose (merge / add a link)"
      echo "           unreused-cause: mechanism — a script applies it AND carries '# discharges: <slug>' at that line (else UNBACKED)"
      echo "           unreused-cause: substrate — the CLI bug it routes around is fixed, or the model no longer errs this way"
      echo "         substrate is the costly one: a live workaround for a fixed bug still steers every session that reads it."
      echo "         Retire a substrate node on a RE-TEST that passes, never on a date or on marker silence — and keep the"
      echo "         node with the test recorded, because model regressions happen (seven-dpt#4)."
    fi
    ;;
  show|*)
    [ -f "$LOG" ] || { echo "no log at $LOG"; exit 0; }
    since=""; [ -f "$MARK" ] && since="$(cat "$MARK")"
    total="$(grep -c '^---$' "$LOG" 2>/dev/null || true)"
    if [ -n "$since" ]; then
      echo "# records since $since (of ~$total total)"; echo
      awk -v since="$since" '
        BEGIN { RS="\n---\n" }
        length($0) > 0 { t=$0; sub(/ .*/,"",t); if (t > since) print $0 "\n---" }
      ' "$LOG"
    else
      echo "# last 25 records (no .last-distilled marker yet; ~$total total)"
      echo "# tip: after distilling, run  distill.sh --mark <ISO-ts of last handled record>"; echo
      awk '
        BEGIN { RS="\n---\n" }
        length($0) > 0 { rec[++c]=$0 }
        END { start = (c > 25) ? c - 24 : 1; for (i = start; i <= c; i++) print rec[i] "\n---" }
      ' "$LOG"
    fi
    ;;
esac
