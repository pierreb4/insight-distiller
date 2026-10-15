#!/usr/bin/env python3
"""cohere-check: insight nodes whose relation to another node goes unstated.

Reading the store by tag cluster on 2026-10-13 found 51 pairs of
nodes that contradict, supersede, refine or overlap without saying so.
Three of the mechanisms that let them through are mechanical, and this script checks them:

  stale    (i)   a "not yet a node / no node yet / not yet written / staged sibling" phrase
                 naming a slug that exists as a node or an alias (B2, A8, B9; and INDEX on
                 2026-09-05, 8781f5c: 12 nodes filed as dangling while they existed)
  shared   (ii)  two nodes citing the same session id, or firehose lines within 20 of each
                 other, with neither naming the other (one incident banked twice: B6, A6, C3)
  onesided (iii) X says it refines / sharpens / supersedes / corrects / restates / is a twin
                 of [[Y]], and Y never names X: the older node did not hear (A16)
  cited    (iv)  report only: a line in ~/.claude/CLAUDE.md or runbooks/ that names a node
                 and is newer than the node's last commit, while the node never names that
                 file (C1, C2: a retraction landed outside the store)

Usage:
  cohere-check.py              report on the working tree, all four checks; exit 0
  cohere-check.py --staged     pre-commit: the index; only hits a staged node is party to
                               (shared: only an ADDED node); exit 1 on any hit
  cohere-check.py --selftest   positives and negatives from this repo's own history
"""
import os
import re
import subprocess
import sys

STORE = os.path.dirname(os.path.abspath(__file__))
HOME_CLAUDE = os.path.dirname(STORE)
NOT_NODES = {"INDEX", "README", "BOOTSTRAP"}

STALE = re.compile(r"not yet (?:a )?node|no node yet|not yet written|still[- ]deferred|"
                   r"staged sibling|deliberate dangling link", re.I)
RESOLVED = re.compile(r"promoted|written since|re-pointed|aliased|now a node|exists", re.I)
DANGLING_HEAD = re.compile(r"dangling|awaiting a node", re.I)
TYPED = re.compile(r"\b(refines|sharpens|supersedes|corrects|restates|generali[sz]es|twin)\b"
                   r"(?! by)[^.\n,;)\[]{0,100}?\[\[([a-z0-9-]+)\]\]", re.I)
RETRACT = re.compile(r"retract|supersed|regime|no longer|is not proof|not proof|withdrawn|"
                     r"was wrong|corrected|expired", re.I)
RARE = 2  # a session id cited by more nodes is a long working session, not one incident
SESSION = re.compile(r"(?:\[|`|session[s]? `?|\()([0-9a-f]{8})(?=[\]`,)\s])")
LOGLINE = re.compile(r"(?:claude-insights\.log:|\blog |\bIL:)(\d{4,6})")
WINDOW = 20


def git(*args, cwd=STORE):
    return subprocess.run(["git", "-C", cwd, *args], capture_output=True, text=True)


def load(rev=None):
    """slug -> text for every top-level node, at a revision, the index (rev=':') or on disk."""
    if rev is None:
        names = [f for f in os.listdir(STORE) if f.endswith(".md")]
        read = lambda f: open(os.path.join(STORE, f), encoding="utf-8").read()
    else:
        ls = git("ls-files") if rev == ":" else git("ls-tree", "--name-only", rev)
        names = [f for f in ls.stdout.split() if f.endswith(".md") and "/" not in f]
        read = lambda f: git("show", f"{rev}{f}" if rev == ":" else f"{rev}:{f}").stdout
    nodes = {}
    for f in names:
        slug = f[:-3]
        if slug in NOT_NODES:
            continue
        nodes[slug] = read(f)
    return nodes


def aliases(rev=None):
    if rev is None:
        try:
            text = open(os.path.join(STORE, "aliases.tsv"), encoding="utf-8").read()
        except OSError:
            return {}
    else:
        text = git("show", f"{rev}aliases.tsv" if rev == ":" else f"{rev}:aliases.tsv").stdout
    out = {}
    for line in text.splitlines():
        if line.startswith("#") or "\t" not in line:
            continue
        alias, host = line.split("\t")[:2]
        out[alias] = host
    return out


def names_of(slug, alias_map):
    return {slug} | {a for a, h in alias_map.items() if h == slug}


def mentions(text, slug, alias_map):
    return any(n in text for n in names_of(slug, alias_map))


def check_stale(nodes, alias_map, index_text=None, only=None):
    known = set(nodes) | set(alias_map)
    hits = []
    files = dict(nodes)
    if index_text is not None:
        files["INDEX"] = index_text
    for slug, text in files.items():
        if only is not None and slug not in only:
            continue
        lines = text.splitlines()
        under = None  # a heading that says everything below it is not a node yet
        for i, line in enumerate(lines):
            if line.startswith("#"):
                under = line if DANGLING_HEAD.search(line) else None
            m = STALE.search(line) or (under and not line.startswith("#") and
                                       re.search(r"\S", line) and DANGLING_HEAD.search(under))
            if not m or RESOLVED.search(line):
                continue
            phrase = STALE.search(line)
            near = line + " " + (lines[i + 1] if phrase and i + 1 < len(lines) else "")
            named = [k for k in known if k != slug and re.search(
                r"(?<![a-z0-9-])" + re.escape(k) + r"(?![a-z0-9-])", near)]
            for k in sorted(named):
                hits.append(("stale", f"{slug}.md:{i + 1}",
                             f"'{m.group(0)}' names {k}, which exists"
                             + (f" (alias of {alias_map[k]})" if k in alias_map else ""),
                             line.strip()[:140]))
    return hits


def keys(text):
    sess = {s for s in SESSION.findall(text)
            if re.search(r"[a-f]", s) and re.search(r"\d", s)}
    logs = {int(n) for n in LOGLINE.findall(text)}
    return sess, logs


def check_shared(nodes, alias_map, only=None):
    k = {s: keys(t) for s, t in nodes.items()}
    cited_by = {}
    for s, (sess, _) in k.items():
        for x in sess:
            cited_by[x] = cited_by.get(x, 0) + 1
    slugs = sorted(nodes)
    hits = []
    for i, a in enumerate(slugs):
        for b in slugs[i + 1:]:
            if only is not None and a not in only and b not in only:
                continue
            sess = {x for x in k[a][0] & k[b][0] if cited_by[x] <= RARE}
            logs = sorted({(x, y) for x in k[a][1] for y in k[b][1] if abs(x - y) <= WINDOW})
            if not sess and not logs:
                continue
            if mentions(nodes[a], b, alias_map) or mentions(nodes[b], a, alias_map):
                continue
            ev = [f"session {s}" for s in sorted(sess)] + [f"log {x}~{y}" for x, y in logs[:3]]
            hits.append(("shared", f"{a}.md + {b}.md", "same evidence, neither names the other",
                         ", ".join(ev)))
    return hits


def check_onesided(nodes, alias_map, only=None):
    hits = []
    for x, text in nodes.items():
        if only is not None and x not in only:
            continue
        for i, line in enumerate(text.splitlines()):
            for m in TYPED.finditer(line):
                y = alias_map.get(m.group(2), m.group(2))
                if y == x or y not in nodes:
                    continue
                if not mentions(nodes[y], x, alias_map):
                    hits.append(("onesided", f"{x}.md:{i + 1}",
                                 f"'{m.group(1)}' [[{m.group(2)}]], which never names {x}",
                                 line.strip()[:140]))
    return hits


def check_cited(nodes, alias_map, rev=None, with_claude_md=True):
    """A retraction or regime stamp, within 8 lines of a line naming a node, newer than the
    node's last commit (at rev), while the node never names the file it landed in."""
    sources = [(HOME_CLAUDE, "CLAUDE.md")] if with_claude_md else []
    if rev is None:
        rb = os.path.join(STORE, "runbooks")
        names = sorted(os.listdir(rb)) if os.path.isdir(rb) else []
    else:
        names = [p.split("/", 1)[1] for p in git("ls-tree", "--name-only", rev, "runbooks/").stdout.split()]
    sources += [(STORE, f"runbooks/{f}") for f in names if f.endswith(".md")]
    last = {}
    hits = []
    for repo, rel in sources:
        args = ["blame", "--line-porcelain"] + ([rev] if rev and repo == STORE else []) + ["--", rel]
        rows, when = [], None
        for row in git(*args, cwd=repo).stdout.splitlines():
            if row.startswith("committer-time "):
                when = int(row.split()[1])
            elif row.startswith("\t"):
                rows.append((when, row[1:]))
        for n, (_, line) in enumerate(rows):
            for slug in nodes:
                if not re.search(r"(?<![a-z0-9-])" + re.escape(slug) + r"(?![a-z0-9-])", line):
                    continue
                window = rows[n:n + 1]  # the same bullet: stop at the next one or a heading
                for t, l in rows[n + 1:n + 9]:
                    if l.lstrip().startswith(("- ", "#")):
                        break
                    window.append((t, l))
                stamps = [(t, l) for t, l in window if RETRACT.search(l)]
                if not stamps:
                    continue
                if slug not in last:
                    t = git("log", "-1", "--format=%ct", *([rev] if rev else []), "--",
                            f"{slug}.md").stdout.strip()
                    last[slug] = int(t) if t else 0
                base = os.path.basename(rel)
                newest = max(t or 0 for t, _ in stamps)
                if newest > last[slug] and base not in nodes[slug]:
                    hits.append(("cited", f"{rel}:{n + 1}",
                                 f"names {slug}; a retraction/regime line below it is newer than "
                                 f"{slug}'s last commit, and {slug} never names {base}",
                                 stamps[0][1].strip()[:140]))
    return hits


def show(hits):
    for kind, where, what, raw in hits:
        print(f"{kind:8} {where}  {what}")
        print(f"{'':8}   | {raw}")


def staged_sets():
    out = git("diff", "--cached", "--name-status", "--", "*.md").stdout.splitlines()
    added, changed = set(), set()
    for row in out:
        st, *paths = row.split("\t")
        f = paths[-1]
        if "/" in f or not f.endswith(".md"):
            continue
        (added if st.startswith("A") else changed).add(f[:-3])
    return added, changed


def selftest():
    """Each positive is a real state of this repo before its fix; each negative is the fixed state."""
    # The cases replay the working graph's own history; a store without those commits (the
    # public insight-distiller, a fresh one) can't run them, and says so rather than failing.
    missing = [r for r in ("8781f5c^", "b6937c2^", "b9acf1e^", "c389fa9^")
               if git("cat-file", "-e", f"{r}^{{commit}}").returncode]
    if missing:
        print(f"selftest: skipped, this store lacks the commits it replays ({', '.join(missing)})")
        return 2
    def at(rev):
        nodes = load(rev)
        return nodes, aliases(rev), git("show", f"{rev}:INDEX.md").stdout

    cases = []
    # (i) stale: B2, A8, B9 before c389fa9; foreign: INDEX before 8781f5c (2026-09-05)
    n, a, idx = at("c389fa9^")
    s = check_stale(n, a)
    for slug in ("serving-is-not-the-lever", "insight-memory-has-two-tiers", "agent-involvement-policy"):
        cases.append((f"stale+ {slug} @c389fa9^", any(h[1].startswith(slug + ".md") for h in s)))
    n, a, idx = at("8781f5c^")
    cases.append(("stale+ INDEX @8781f5c^ (foreign: 2026-09-05)",
                  any(h[1].startswith("INDEX.md") for h in check_stale(n, a, idx))))
    n, a, idx = at("c389fa9")
    s = check_stale(n, a, idx)
    for slug in ("serving-is-not-the-lever", "insight-memory-has-two-tiers", "agent-involvement-policy"):
        cases.append((f"stale- {slug} @c389fa9", not any(h[1].startswith(slug + ".md") for h in s)))
    # (ii) shared: B6 before b9acf1e (same S7 record 0fe2fb99); C3 before eba9698
    n, a, _ = at("b9acf1e^")
    pair = "check-structural-bounds-before-trusting-a-statistic.md + enabler-vs-shortcut.md"
    cases.append(("shared+ B6 @b9acf1e^", any(h[1] == pair for h in check_shared(n, a))))
    n, a, _ = at("b9acf1e")
    cases.append(("shared- B6 @b9acf1e", not any(h[1] == pair for h in check_shared(n, a))))
    # (iii) onesided: A16 before b9acf1e ("sharpens [[corroborate...]]", never named back)
    n, a, _ = at("b9acf1e^")
    cases.append(("onesided+ A16 @b9acf1e^", any(h[1].startswith("verify-counterpartys-reason")
                                                for h in check_onesided(n, a))))
    n, a, _ = at("b9acf1e")
    cases.append(("onesided- A16 @b9acf1e", not any(h[1].startswith("verify-counterpartys-reason")
                                                   for h in check_onesided(n, a))))
    # negatives that must stay quiet: a true absence ("no node yet" naming no slug) and a
    # cleared pair (single-carrier <-> closed-reader, relation stated, incidents.md)
    n, a, _ = at("b9acf1e")
    cases.append(("stale- remediate 'downstream-only fixing -> no node yet'",
                  not any(h[1].startswith("remediate-fallacies-up-a-ladder") for h in check_stale(n, a))))
    cleared = ("closed-reader-silently-drops-open-writer-vocabulary.md + "
               "single-carrier-enumeration-undercounts-silently.md")
    cases.append(("shared- cleared single-carrier/closed-reader",
                  not any(h[1] == cleared for h in check_shared(n, a))))
    # false positives the first run found (2026-10-13), kept quiet since
    cases.append(("stale- distillation-policy 'staged sibling, PROMOTED this round'",
                  not any(h[1].startswith("distillation-policy") for h in check_stale(n, a))))
    cases.append(("onesided- null-arm 'generalises this), [[pair-an-absence...]]'",
                  not any(h[1].startswith("null-arm") for h in check_onesided(load("b9acf1e"), a))))
    # (iv) cited: C2, the runbook's 09-29 regime stamp under the kaggle-push pointer, before
    # b6937c2 gave the node its rider; runbooks only (CLAUDE.md's blame is not at that rev)
    n, a, _ = at("b6937c2^")
    hit = lambda hs: any("kaggle-push-cannot-set-premium-accelerator" in h[2] for h in hs)
    cases.append(("cited+ C2 kaggle-push @b6937c2^", hit(check_cited(n, a, "b6937c2^", False))))
    n, a, _ = at("b6937c2")
    cases.append(("cited- C2 kaggle-push @b6937c2", not hit(check_cited(n, a, "b6937c2", False))))
    cases.append(("cited- cheap-probe pointer (the stamp below belongs to the next bullet)",
                  not any("cheap-probe-before-expensive-run" in h[2]
                          for h in check_cited(n, a, "b6937c2", False))))
    bad = [c for c, ok in cases if not ok]
    for c, ok in cases:
        print(("ok   " if ok else "FAIL ") + c)
    print(f"selftest: {len(cases) - len(bad)}/{len(cases)}")
    return 1 if bad else 0


def main(argv):
    if "--selftest" in argv:
        return selftest()
    if "--staged" in argv:
        nodes, alias_map = load(":"), aliases(":")
        added, changed = staged_sets()
        touched = added | changed
        if not touched:
            return 0
        hits = (check_stale(nodes, alias_map, only=touched)
                + check_shared(nodes, alias_map, only=added)
                + check_onesided(nodes, alias_map, only=touched))
        if hits:
            print("pre-commit: cohere-check found relations left unstated:",
                  file=sys.stderr)
            sys.stdout = sys.stderr
            show(hits)
            print("fix: point a stale phrase at the node; name the other node with its relation "
                  "(refines/supersedes/contradicts/twin), and edit the older node in this commit.",
                  file=sys.stderr)
            return 1
        return 0
    nodes, alias_map = load(), aliases()
    index_text = open(os.path.join(STORE, "INDEX.md"), encoding="utf-8").read()
    hits = (check_stale(nodes, alias_map, index_text) + check_shared(nodes, alias_map)
            + check_onesided(nodes, alias_map) + check_cited(nodes, alias_map))
    show(hits)
    counts = {}
    for h in hits:
        counts[h[0]] = counts.get(h[0], 0) + 1
    print("cohere-check: " + (", ".join(f"{k} {v}" for k, v in sorted(counts.items())) or "clean")
          + f" ({len(nodes)} nodes)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
