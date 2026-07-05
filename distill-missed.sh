#!/bin/bash
# distill-missed.sh — compact-time "missed insight" surfacer.
#
# At compact, if this session contains a GENUINE user correction (a non-prose mistake-marker —
# the highest-independence Verified-tier signal), surface up to two insight nodes whose lesson
# the correction's vocabulary overlaps AND that were never consulted this session. Otherwise stay
# SILENT — the common case. Read-only, fail-closed-to-silent: any error prints nothing and exits 0.
#
# Wired to the SessionStart:compact hook (it reads the hook's JSON on stdin for transcript_path).
# Cheap (no LLM): the mistake-gate makes it near-always silent, so a hot path is avoided.
# Test:  MISSED_TRANSCRIPT=/path/to.jsonl bash distill-missed.sh </dev/null
DIR="${DISTILL_DIR:-$HOME/.claude/insights}"
[ -d "$DIR" ] || exit 0
HOOK_JSON="$(cat 2>/dev/null || true)"   # SessionStart hook delivers {source, transcript_path, …} on stdin

python3 - "$DIR" "$HOOK_JSON" <<'PY' 2>/dev/null || true
import json, sys, os, re
DIR = sys.argv[1]
raw = sys.argv[2] if len(sys.argv) > 2 else ""
try:
    hook = json.loads(raw) if raw.strip() else {}
except Exception:
    hook = {}
tp = os.environ.get("MISSED_TRANSCRIPT") or hook.get("transcript_path") or ""
if not tp or not os.path.exists(tp):
    sys.exit(0)

# ---- the same genuine-human filter + correction marker the eval's Verified tier uses ----
NOISE = ("<task-notification>", "<command-", "<local-command", "<system-reminder", "<bash-", "Caveat:")
CORRECTION = re.compile(
    r"\b(no,?\s+(that|this|it)('?s| is)?\s*(wrong|not right|off|backwards|incorrect)|that'?s not (right|it|correct|true)"
    r"|didn'?t you|you (said|claimed)\b.*\bbut\b|revert|undo that|actually,?\s+no|still (broken|failing|wrong|not)"
    r"|make sure (we|you) (don'?t|do not)|confound|that'?s wrong|not what i)", re.I)
SLUGPATH = re.compile(r"/\.claude/insights/([a-z0-9-]+)\.md")
WIKILINK = re.compile(r"\[\[([a-z0-9-]+)\]\]")

corrections, seen = [], set()
try:
    for line in open(tp, encoding="utf-8"):
        for m in SLUGPATH.finditer(line):
            seen.add(m.group(1))          # node path mentioned (Read tool-use or prose) => surfaced
        for m in WIKILINK.finditer(line):
            seen.add(m.group(1))          # [[slug]] mentioned => surfaced
        if '"user"' not in line or '"toolUseResult"' in line:
            continue                       # cheap pre-filter (spacing-robust): skip non-user + tool-result lines
        try:
            o = json.loads(line)
        except Exception:
            continue
        if o.get("type") != "user" or "toolUseResult" in o:
            continue
        if o.get("isMeta") or o.get("isCompactSummary") or o.get("isVisibleInTranscriptOnly"):
            continue
        c = o.get("message", {}).get("content")
        if not isinstance(c, str) or not c.strip():
            continue
        if any(nz in c for nz in NOISE):
            continue
        if CORRECTION.search(c):
            corrections.append(c)
except Exception:
    sys.exit(0)

if not corrections:
    sys.exit(0)   # no genuine mistake this session -> silent (unobtrusive default)

# ---- significant terms from the correction context ----
STOP = set(
    "the a an of to and or is are was were be been being this that these those it its as at by for from in on with into "
    "about over under not no you your we our they their he she his her them then than so but if when while which who what "
    "how why where can could should would will may might do does did done have has had get got make made use used like "
    "just only also more most some any all each both few many much such own same other another new old now here there".split())
def terms(text):
    return {w for w in re.findall(r"[a-z][a-z-]{3,}", text.lower()) if w not in STOP}
mistake_terms = set()
for c in corrections:
    mistake_terms |= terms(c[:600])
if not mistake_terms:
    sys.exit(0)

# ---- score never-surfaced nodes by significant-term overlap with the correction ----
idx = {}
ipath = os.path.join(DIR, "INDEX.md")
if os.path.exists(ipath):
    for line in open(ipath, encoding="utf-8"):
        m = re.match(r"\s*-\s*\[([a-z0-9-]+)\]\(\1\.md\)\s*[—-]\s*(.+)", line)
        if m:
            idx[m.group(1)] = m.group(2).strip()
scored = []
for slug, desc in idx.items():
    if slug in seen:
        continue                            # already consulted this session -> not "missed"
    node_terms = terms(desc) | {w for w in slug.split("-") if len(w) >= 4}
    overlap = mistake_terms & node_terms
    if len(overlap) >= 2:                    # >=2 significant shared terms = a real topical hit
        scored.append((len(overlap), slug, desc))
scored.sort(reverse=True)
if not scored:
    sys.exit(0)

print("\n[insight] this session hit a correction; a lesson it didn't consult may apply:")
for n, slug, desc in scored[:2]:
    short = desc if len(desc) <= 130 else desc[:129] + "…"
    print(f"  ⚠ {slug} — {short}")
PY
exit 0
