#!/bin/bash
# golden-anti-test.sh — golden FIXTURE test for the eval's `anti` path AND the Verified tier.
# Mirrors the crosspass golden-positive/negative discipline. Injects synthetic firehose records, ALL
# about one real node (suspect-the-measurement-before-the-artifact), and asserts the REAL distill-eval.sh
# (a) classifies valence correctly and (b) corroborates / gates via the Verified tier:
#   ORIGIN     (pre-node, same error)                      -> origin                 [valence/time]
#   TRUE-HARD  (post-node, mistake happened + USER CORRECTS)-> anti, strength hard, ROUTES to failure cell
#   APPLIED    (post-node, mistake avoided + USER AFFIRMS)  -> applied, strength hard
#   TRUE-SOFT  (post-node, mistake happened, NO corroborator)-> anti, strength soft, HELD BACK (spot-check)
# Records are natural prose (matched by timestamp). Synthetic transcripts (a temp VERIFY_PROJECTS) supply
# the user turns for H2. Read-only w.r.t. the graph; uses the real nodes/ctimes (DISTILL_DIR).
set -uo pipefail
DIR="${DISTILL_DIR:-$HOME/.claude/insights}"
NODE="suspect-the-measurement-before-the-artifact"
K="${EVAL_K:-3}"
[ -f "$DIR/$NODE.md" ] || { echo "FAIL(setup): target node $NODE.md missing — pick another node"; exit 1; }
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
FIX="$WORK/fixture-firehose.log"
PROJ="$WORK/projects/sess"; mkdir -p "$PROJ"

# 4 firehose fixtures (identified downstream by their unique timestamps; node held constant):
cat > "$FIX" <<'EOF'
2026-06-22T09:00:00+02:00 [aaaa1111] The T4 run NaN'd on the v3 recipe, so I concluded the recipe had a bug and spent the morning rewriting the loss scaling and gradient clipping. It then turned out the exact same recipe runs clean on the L4 — the NaN was a hardware-regime problem, not a recipe bug. I blamed the code and rewrote it instead of checking the run environment first.
---
2026-06-24T09:00:00+02:00 [bbbb2222] The v6 model scored 6.4 on the gate, down from 7.1, so I concluded the attention change had regressed the model and spent the whole afternoon reverting and rewriting it. It then turned out the gate harness was silently loading a stale cached prediction file from the prior run; the drop was a harness problem and the model was fine all along. I blamed the code and rewrote it without ever checking the harness first — a real, avoidable mistake.
---
2026-06-24T09:05:00+02:00 [cccc3333] The v7 model scored 6.9, down from 7.3, which looked like a regression. Before touching the model I checked the harness first and found it had silently scored only 80 of the 120 tasks because of a truncated manifest. I fixed the manifest, the score returned to 7.3, and I never touched the model.
---
2026-06-24T09:10:00+02:00 [dddd4444] The v8 model scored 6.2, down from 7.0, so I concluded the new tokenizer had regressed it and spent the evening reverting and rewriting the tokenizer path. It then turned out the gate was scoring against the wrong manifest; the model was fine and the rewrite was wasted — a real, avoidable mistake.
EOF

# Synthetic transcripts (genuine human turns) for H2 — only TRUE-HARD and APPLIED get a corroborator.
# Timestamps in UTC Z; events are +02:00, so 09:00+02 == 07:00Z. User turns land within the 2h window.
cat > "$PROJ/bbbb2222-aaaa-bbbb-cccc-dddddddddddd.jsonl" <<'EOF'
{"type":"user","timestamp":"2026-06-24T07:05:00.000Z","message":{"role":"user","content":"No, that is wrong — you reverted the model but the harness was loading a stale cache. Make sure we do not blame the code next time; check the measurement first."}}
EOF
cat > "$PROJ/cccc3333-aaaa-bbbb-cccc-dddddddddddd.jsonl" <<'EOF'
{"type":"user","timestamp":"2026-06-24T07:12:00.000Z","message":{"role":"user","content":"Nice, that works — checking the harness first was exactly right."}}
EOF
# (dddd4444 deliberately has NO transcript → no corroborator → must stay soft.)

echo "== golden-anti-test: real distill-eval.sh over 4 fixtures + Verified tier (K=$K) ==" >&2
echo "   target node: $NODE" >&2
DISTILL_LOG="$FIX" VERIFY_PROJECTS="$WORK/projects" EVAL_K="$K" \
  "$DIR/distill-eval.sh" > "$WORK/out.txt" 2>"$WORK/err.txt" || true

python3 - "$WORK/out.txt" "$NODE" <<'PY'
import sys, re
out = open(sys.argv[1],encoding="utf-8").read(); NODE = sys.argv[2]
# appendix rows: [F#] VAL -> node (firehose <ts>) [votes] {strength · corrs}
rows = {}
for m in re.finditer(r'^\[(\w+)\]\s+(\w+)\s+->\s+(\S+)\s+\(firehose\s+(\S+)\)(?:\s+\[[^\]]+\])?(?:\s+\{([^}]*)\})?', out, re.M):
    eid,val,node,ts,blob = m.group(1),m.group(2).lower(),m.group(3),m.group(4),(m.group(5) or "")
    strength = blob.split("·")[0].strip().lower() if blob else ""
    rows[ts]=(eid,val,node,strength)
# spot-check eids (held-back soft antis)
spot=set(); m=re.search(r'SPOT-CHECK.*', out)
if m:
    tail=out[m.end():]
    for sm in re.finditer(r'^\s+\[(\w+)\]\s', tail, re.M): spot.add(sm.group(1))
    # stop at the appendix divider
# router label for the node (the → CELL after its ● header)
ml=re.search(r'●\s+'+re.escape(NODE)+r'\b(.*?)→\s+([A-Z/ ]+):', out, re.S)
node_label = ml.group(2).strip() if ml else "(node not routed)"
HARD={"hard","strong"}
CASES=[
  ("ORIGIN     -> origin",              "2026-06-22T09:00:00+02:00", dict(val="origin")),
  ("TRUE-HARD  -> anti + hard + ROUTES","2026-06-24T09:00:00+02:00", dict(val="anti", strength=HARD, node=NODE, routes=True)),
  ("APPLIED    -> applied + hard",      "2026-06-24T09:05:00+02:00", dict(val="applied", strength=HARD, node=NODE)),
  ("TRUE-SOFT  -> anti + soft + HELD",  "2026-06-24T09:10:00+02:00", dict(val="anti", strength={"soft"}, node=NODE, held=True)),
]
print("="*74)
print("GOLDEN ANTI + VERIFIED-TIER TEST")
print(f"router cell for {NODE}: {node_label}")
print("="*74)
allpass=True
for desc, ts, want in CASES:
    r=rows.get(ts)
    if not r:
        print(f"  [MISS] {desc}\n         no appendix row at {ts}"); allpass=False; continue
    eid,val,node,strength = r
    checks=[("val", val==want["val"])]
    if "strength" in want: checks.append(("strength", strength in want["strength"]))
    if "node" in want:     checks.append(("node", node==want["node"]))
    if want.get("routes"): checks.append(("routes->FAILURE", "FAILURE" in node_label))
    if want.get("held"):   checks.append(("in spot-check", eid in spot))
    ok=all(v for _,v in checks); allpass=allpass and ok
    bad=", ".join(k for k,v in checks if not v)
    print(f"  [{'PASS' if ok else 'FAIL'}] {desc}")
    print(f"         got: {val.upper()} -> {node}  strength={strength or '-'}" + (f"   FAILED: {bad}" if not ok else ""))
print("-"*74)
agree = re.search(r'VERIFIED tier.*', out)
print("  "+(agree.group(0) if agree else "[WARN] no agreement-rate line printed"))
print("="*74)
print("VERDICT:", "ALL PASS — anti fires, corroboration tags hard, gate holds back the uncorroborated soft anti."
      if allpass else "FAIL — see rows above.")
sys.exit(0 if allpass else 1)
PY
rc=$?
echo "== golden-anti-test exit: $rc ==" >&2
exit $rc
