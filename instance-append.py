#!/usr/bin/env python3
"""instance-append.py — the instance ledger of the insight store.

When a distiller finds that a record restates an existing node, it records the record as a
dated INSTANCE of that node instead of dropping it, so a node shows how often and where its
class recurs. The headless passes (distill-crosspass.sh, distill-run.sh) write rows to a
per-host ledger, instances/<host>.tsv, tracked in git: two hosts appending to one node's text
would diverge under a fast-forward-only sync, one file per host never does. The attended
SKILL step 2 writes the line into the node itself, under `## Instances`.

A row holds no agent text: the agent names a slug and a session (crosspass) or a session and a
record timestamp (distill-run), both validated here against the store and a wrapper-built
manifest, and the rest comes from that manifest.

  append   --store DIR --host H --via V --rows AGENT_TSV --manifest MANIFEST_TSV [--commit]
           AGENT_TSV rows: slug sid [record-ts]   (whitespace-separated, as the agent wrote them)
           MANIFEST rows:  sid ts project il       (written by the wrapper)
           prints "instances=N new_place=M rejected=K"; each rejection's reason on stderr;
           --commit commits instances/<host>.tsv alone (git commit --only) when DIR is a repo
  projects --store DIR          slug<TAB>proj,proj from the nodes' ## Instances lines and the ledgers
  show     --store DIR SLUG     the node's ## Instances lines and the ledgers' rows, dated
"""
import argparse, glob, os, re, socket, subprocess, sys

SLUG = re.compile(r"^[a-z0-9-]+$")
SID = re.compile(r"^[0-9a-f]{6,8}$")
COLS = ["date", "slug", "project", "sid", "il", "via", "new_place"]
HEADER = "# " + "\t".join(COLS) + "\n"
NODE_LINE = re.compile(r"^- (\d{4}-\d{2}-\d{2}) (\S+) ")


def node_path(store, slug):
    return os.path.join(store, slug + ".md")


def read_node(store, slug):
    try:
        return open(node_path(store, slug), encoding="utf-8").read()
    except OSError:
        return None


def is_insight(text):
    if not text or not text.startswith("---"):
        return False
    fm = text.split("\n---", 1)[0]
    return re.search(r"^type:\s*insight\s*$", fm, re.M) is not None


def source_block(text):
    """The frontmatter's source: entry (inline or nested), where via names what surfaced it."""
    fm = text.split("\n---", 1)[0].split("\n")
    out, on = [], False
    for ln in fm:
        if ln.startswith("source:"):
            on = True; out.append(ln); continue
        if on:
            if ln[:1] in (" ", "\t"): out.append(ln)
            else: break
    return "\n".join(out)


def node_instances(text):
    """(date, project, line) for each line of the node's ## Instances section."""
    if not text:
        return []
    out, on = [], False
    for ln in text.split("\n"):
        if ln.startswith("## "):
            on = ln.strip() == "## Instances"; continue
        if on:
            m = NODE_LINE.match(ln)
            if m: out.append((m.group(1), m.group(2), ln))
    return out


def ledger_rows(store):
    """Every ledger row, all hosts: dicts with COLS plus host."""
    rows = []
    for f in sorted(glob.glob(os.path.join(store, "instances", "*.tsv"))):
        host = os.path.basename(f)[:-4]
        for ln in open(f, encoding="utf-8"):
            if not ln.strip() or ln.startswith("#"): continue
            p = ln.rstrip("\n").split("\t")
            if len(p) < len(COLS): continue
            d = dict(zip(COLS, p)); d["host"] = host; rows.append(d)
    return rows


def projects_by_slug(store):
    seen = {}
    for f in glob.glob(os.path.join(store, "*.md")):
        slug = os.path.basename(f)[:-3]
        for _, proj, _ in node_instances(open(f, encoding="utf-8").read()):
            seen.setdefault(slug, set()).add(proj)
    for r in ledger_rows(store):
        if r["project"] != "?": seen.setdefault(r["slug"], set()).add(r["project"])
    return seen


def read_manifest(path):
    man = {}
    for ln in open(path, encoding="utf-8"):
        p = ln.rstrip("\n").split("\t")
        if len(p) < 4 or not SID.match(p[0]): continue
        man.setdefault(p[0], []).append({"ts": p[1], "project": p[2], "il": p[3]})
    return man


def cmd_append(a):
    store, host = a.store, a.host or socket.gethostname().split(".")[0]
    man = read_manifest(a.manifest)
    rows = ledger_rows(store)
    done = {(r["slug"], r["sid"], r["il"]) for r in rows}
    ledger_seen = {}
    for r in rows:
        ledger_seen.setdefault(r["slug"], set()).add(r["project"])
    known = {}  # slug -> (projects in its node lines and the ledgers, its source: text)
    new, rejected, n_new_place = [], 0, 0
    try:
        lines = open(a.rows, encoding="utf-8", errors="replace").read().split("\n")
    except OSError:
        lines = []
    for i, ln in enumerate(lines, 1):
        p = ln.split()
        if not p or p[0].startswith("#"): continue
        why = None
        slug, sid, ts = p[0], (p[1] if len(p) > 1 else ""), (p[2] if len(p) > 2 else "")
        slug = slug.strip("[]`"); sid = sid.strip("[]`")
        text = read_node(store, slug) if SLUG.match(slug) else None
        hits = man.get(sid, [])
        if ts: hits = [h for h in hits if h["ts"] == ts]
        if not SLUG.match(slug): why = "bad slug"
        elif text is None: why = "no node %s.md" % slug
        elif not is_insight(text): why = "%s.md is not type: insight" % slug
        elif not SID.match(sid) or sid not in man: why = "session %r not in the manifest" % sid
        elif len(hits) != 1: why = "%d manifest entries for %s %s" % (len(hits), sid, ts or "(no ts)")
        if why:
            rejected += 1
            print("instance-append: rejected line %d (%s): %s" % (i, why, ln.strip()[:120]), file=sys.stderr)
            continue
        h = hits[0]
        key = (slug, sid, h["il"])
        if key in done:
            print("instance-append: repeat %s %s %s, skipped" % key, file=sys.stderr)
            continue
        proj = h["project"]
        if slug not in known:
            known[slug] = ({pr for _, pr, _ in node_instances(text)} | ledger_seen.get(slug, set()),
                           source_block(text))
        seen, via_text = known[slug]
        if proj == "?": np = "?"
        else:
            in_via = re.search(r"(?<![\w-])" + re.escape(proj) + r"(?![\w-])", via_text)
            np = "new" if (proj not in seen and not in_via) else "seen"
        if np == "new": n_new_place += 1
        seen.add(proj)
        new.append([h["ts"][:10], slug, proj, sid, h["il"], a.via, np])
        done.add(key)
    rel = os.path.join("instances", host + ".tsv")
    if new:
        os.makedirs(os.path.join(store, "instances"), exist_ok=True)
        f = os.path.join(store, rel)
        fresh = not os.path.exists(f)
        with open(f, "a", encoding="utf-8") as fh:
            if fresh: fh.write(HEADER)
            for r in new: fh.write("\t".join(r) + "\n")
    print("instances=%d new_place=%d rejected=%d" % (len(new), n_new_place, rejected))
    if a.commit and os.path.exists(os.path.join(store, rel)):   # also carries rows an earlier refused commit left
        commit(store, rel, host, a.via)


def commit(store, rel, host, via):
    """Commit the ledger file alone (--only: whatever else is staged stays staged). A store that
    isn't a repo's top, or a refused commit (index lock, a hook), leaves the rows uncommitted for
    the next run's commit to carry; the reason goes to stderr for the wrapper's log."""
    def git(*args):
        return subprocess.run(["git", "-C", store] + list(args), capture_output=True, text=True)
    top = git("rev-parse", "--show-toplevel")
    if top.returncode != 0 or os.path.realpath(top.stdout.strip()) != os.path.realpath(store):
        print("instance-append: %s is not a repo top, %s left uncommitted" % (store, rel), file=sys.stderr); return
    if not git("status", "--porcelain", "--", rel).stdout.strip():
        return
    r = git("add", "--", rel)
    if r.returncode == 0:
        added = [ln for ln in git("diff", "--cached", "-U0", "--", rel).stdout.split("\n")
                 if ln.startswith("+") and not ln.startswith(("+++", "+#"))]
        msg = "instances: %d row(s) from %s (%s)" % (len(added), host, via)
        r = git("commit", "--only", "-q", "-m", msg, "--", rel)
    if r.returncode != 0:
        print("instance-append: commit refused (rc=%d), %s left uncommitted: %s"
              % (r.returncode, rel, (r.stderr or r.stdout).strip()[-300:]), file=sys.stderr)
    else:
        print("instance-append: committed %s" % rel, file=sys.stderr)


def cmd_projects(a):
    for slug, ps in sorted(projects_by_slug(a.store).items()):
        print("%s\t%s" % (slug, ",".join(sorted(ps))))


def cmd_show(a):
    text = read_node(a.store, a.slug)
    if text is None:
        sys.exit("no node %s.md in %s" % (a.slug, a.store))
    out = [(d, "node    " + ln) for d, _, ln in node_instances(text)]
    out += [(r["date"], "%-7s %s %s [%s] %s via %s%s" % (r["host"], r["date"], r["project"], r["sid"], r["il"],
             r["via"], " (new place)" if r["new_place"] == "new" else ""))
            for r in ledger_rows(a.store) if r["slug"] == a.slug]
    for _, s in sorted(out):
        print(s)
    if not out:
        print("no instances of %s" % a.slug)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("append")
    s.add_argument("--store", required=True); s.add_argument("--host")
    s.add_argument("--via", required=True); s.add_argument("--rows", required=True)
    s.add_argument("--manifest", required=True)
    s.add_argument("--commit", action="store_true", help="commit instances/<host>.tsv alone when rows were added")
    s = sub.add_parser("projects"); s.add_argument("--store", default=os.path.expanduser("~/.claude/insights"))
    s = sub.add_parser("show"); s.add_argument("--store", default=os.path.expanduser("~/.claude/insights"))
    s.add_argument("slug")
    a = ap.parse_args()
    {"append": cmd_append, "projects": cmd_projects, "show": cmd_show}[a.cmd](a)


if __name__ == "__main__":
    main()
