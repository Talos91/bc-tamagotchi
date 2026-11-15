"""Also generates the Backlog tab from BACKLOG.md (one source, never hand-edit #p-backlog). Regenerate the rules table in game-bible.md and splice stakes-rules.md and game-bible.md into the hub page
(docs/design/backlog-board.html) between <!--BEGIN:x--> and <!--END:x--> markers. Housekeeping only."""
import re, html, pathlib
D = pathlib.Path(__file__).parent
ROOT = D.parent.parent

def rules_table():
    rows, sec = [], ""
    for line in (ROOT / "game/scripts/rules.gd").read_text(encoding="utf-8").splitlines():
        m = re.match(r"# --- (.+?) -+\s*$", line)
        if m:
            sec = re.sub(r"\s*\(.*", "", m.group(1)); continue
        m = re.match(r"const (\w+)(?:: [^=]+)? := (.+?)\s*(?:##?\s*(.*))?$", line)
        if not m or m.group(2).endswith(("{", "[")) and "]" not in m.group(2) and "}" not in m.group(2):
            continue
        name, val, note = m.groups()
        val = re.sub(r"\s+#.*$", "", val.strip())
        if len(val) > 70 or val.startswith('"'): continue
        rows.append((sec, name, val, (note or "").replace("|", "/")))
    out = ["| Section | Constant | Value | Note |", "|---|---|---|---|"]
    out += [f"| {s} | `{n}` | `{v}` | {c} |" for s, n, v, c in rows]
    out += ["", "Refill actions (gains per action, caps) are the `ACTIONS` table in the same file; decay per real hour: music 0.55, friends 0.50, drinks 0.70, nightlife 0.45."]
    return "\n".join(out)

def inline(t):
    t = html.escape(t)
    t = re.sub(r"`([^`]+)`", r"<code>\1</code>", t)
    t = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", t)
    return t

def md(text):
    out, i, lines, inlist = [], 0, text.splitlines(), False
    def close():
        nonlocal inlist
        if inlist: out.append("</ul>"); inlist = False
    while i < len(lines):
        l = lines[i]
        if l.startswith("|"):
            close(); rows = []
            while i < len(lines) and lines[i].startswith("|"):
                rows.append([c.strip() for c in lines[i].strip().strip("|").split("|")]); i += 1
            out.append('<div class="tablewrap"><table class="doc"><thead><tr>' + "".join(f"<th>{inline(c)}</th>" for c in rows[0]) + "</tr></thead><tbody>")
            for r in rows[2:]: out.append("<tr>" + "".join(f"<td>{inline(c)}</td>" for c in r) + "</tr>")
            out.append("</tbody></table></div>"); continue
        if l.startswith("# "): close(); out.append(f"<h2>{inline(l[2:])}</h2>")
        elif l.startswith("## "): close(); out.append(f"<h3>{inline(l[3:])}</h3>")
        elif l.startswith("- "):
            if not inlist: out.append("<ul class=\"q\">"); inlist = True
            out.append(f"<li>{inline(l[2:])}</li>")
        elif l.startswith("<!--") or not l.strip(): close()
        else: close(); out.append(f"<p class=\"sub\">{inline(l)}</p>")
        i += 1
    close(); return "\n".join(out)


def backlog_html(text):
    """Render BACKLOG.md (0.3.0 now, sections A-D, F) as the Backlog tab: same table look, plus a Track column."""
    def pill(st):
        k = "ok" if st.startswith("live") else "wait" if st.startswith("built-awaiting") else "idea" if st.startswith(("idea", "parked")) else "plan"
        return f'<span class="pill {k}">{inline(st)}</span>'
    out = ['<div class="legend"><span class="s-ok">live</span><span class="s-wait">built, awaiting your acceptance</span><span class="s-plan">built / designed</span><span class="s-idea">idea or parked</span>'
           '<span>Effort: S a day · M a wave · L several waves · Track: T1 no server (0.3.0) · T2 needs Supabase · T3 needs a business decision</span></div>']
    for sec in re.split(r"(?m)^## ", text)[1:]:
        title, _, body = sec.partition(chr(10))
        if title.startswith("E.") or title.startswith("Log"): continue
        m = re.match(r"([A-H])\. (.+)", title)
        letter, name = (m.group(1), m.group(2)) if m else ("★", title)
        out.append(f'<section><h2><span class="letter">{letter}</span>{inline(name)}</h2>')
        lines, i = body.splitlines(), 0
        while i < len(lines):
            l = lines[i]
            if l.startswith("|"):
                rows = []
                while i < len(lines) and lines[i].startswith("|"):
                    rows.append([c.strip() for c in lines[i].strip().strip("|").split("|")]); i += 1
                out.append('<div class="tablewrap"><table><tr>' + "".join(f"<th>{inline(c)}</th>" for c in rows[0]) + "</tr>")
                for r in rows[2:]:
                    if len(r) != 6:
                        out.append("<tr>" + "".join(f'<td class="id">{inline(c)}</td>' if k == 0 else f'<td>{inline(c)}</td>' for k, c in enumerate(r)) + "</tr>"); continue
                    out.append(f'<tr><td class="id">{inline(r[0])}</td><td>{inline(r[1])}</td><td class="eff">{inline(r[2])}</td><td class="needs">{inline(r[3])}</td><td>{pill(r[4])}</td><td class="eff">{inline(r[5])}</td></tr>')
                out.append("</table></div>"); continue
            i += 1
        rest = chr(10).join(x for x in lines if not x.startswith("|"))
        out.append(md(rest) if rest.strip() else "")
        out.append("</section>")
    return chr(10).join(out)

bible = (D / "game-bible.md").read_text(encoding="utf-8")
head = bible.split("<!-- RULES-TABLE -->")[0]
bible = head + "<!-- RULES-TABLE -->\n" + rules_table() + "\n"
(D / "game-bible.md").write_text(bible, encoding="utf-8", newline="\n")
page = (D / "backlog-board.html").read_text(encoding="utf-8")
for key, src in (("stakes", D / "stakes-rules.md"), ("bible", D / "game-bible.md"), ("ask", D / "ask-black-cabin.md")):
    body = md(src.read_text(encoding="utf-8"))
    pat = re.compile(rf"(?s)<!--BEGIN:{key}-->.*?<!--END:{key}-->")
    page, n = pat.subn(lambda m: f"<!--BEGIN:{key}-->\n{body}\n<!--END:{key}-->", page)
    assert n == 1, key
body = backlog_html((D / "BACKLOG.md").read_text(encoding="utf-8"))
page, n = re.subn(r"(?s)<!--BEGIN:backlog-->.*?<!--END:backlog-->", lambda m: f"<!--BEGIN:backlog-->\n{body}\n<!--END:backlog-->", page)
assert n == 1, "backlog"
(D / "backlog-board.html").write_text(page, encoding="utf-8", newline="\n")
print("ok")
