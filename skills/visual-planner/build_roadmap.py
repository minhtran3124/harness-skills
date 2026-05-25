#!/usr/bin/env python3
"""Render every plan under a specs/ dir to PLAN.html, then build a ROADMAP.html
index linking them — sorted newest-first, feature name only in the list, with
created/updated datetimes shown in a right-hand detail panel on click.

Usage:
    python3 build_roadmap.py <specs-dir>

Reuses render_plan.py (same dir) for the per-plan HTML so the index and the
plans share one renderer. Self-contained output (offline-safe).
"""
from __future__ import annotations

import importlib.util
import json
import re
import sys
from datetime import date
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_SPEC = importlib.util.spec_from_file_location("render_plan", _HERE / "render_plan.py")
assert _SPEC and _SPEC.loader, "could not load render_plan.py"
rp = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(rp)

# Plan-file preference: a real plan first, else the richest overview doc.
PLAN_NAMES = ["PLAN.md", "plan.md", "plan.MD", "prd.md", "tasks.md"]
_DATE_RX = re.compile(r"\b(\d{4}-\d{2}-\d{2})\b")
_DATE_SLUG = re.compile(r"^\d{4}-\d{2}-\d{2}$")
_TITLE_PREFIX = re.compile(
    r"^(implementation progress|engineering plan|plan|prd|spec|design|investigation)\s*[:\-]\s*",
    re.I,
)


def display_name(slug: str, title: str) -> str:
    """List label = feature name only. For historical date-named folders the slug
    IS a date, so fall back to the plan's (prefix-stripped) title; otherwise
    return "" and let the page prettify the slug."""
    if _DATE_SLUG.match(slug):
        return _TITLE_PREFIX.sub("", title).strip() or slug
    return ""


def find_plan(folder: Path) -> Path | None:
    for name in PLAN_NAMES:
        p = folder / name
        if p.exists():
            return p
    mds = sorted(folder.glob("*.md"))
    return mds[0] if mds else None


def folder_dates(folder: Path) -> list[str]:
    out: list[str] = []
    for md in folder.glob("*.md"):
        out += _DATE_RX.findall(md.read_text(encoding="utf-8", errors="ignore"))
    return out


# When the plan has no frontmatter `status`, fall back to a `progress.md`
# "Status:" line and normalize the free-text to the badge vocabulary.
_STATUS_MAP = [
    (re.compile(r"\b(shipped|released|done|complete|landed|merged)\b", re.I), "shipped"),
    (re.compile(r"\b(paused|blocked|on hold)\b", re.I), "paused"),
    (re.compile(r"\b(in[\s_-]?progress|active|implementing|wip)\b", re.I), "active"),
    (re.compile(r"\b(proposed|draft|planned|backlog)\b", re.I), "proposed"),
]


def _normalize_status(s: str) -> str:
    s = s.strip().lower()
    if s in ("proposed", "active", "paused", "shipped"):
        return s
    for rx, val in _STATUS_MAP:
        if rx.search(s):
            return val
    return s  # unknown -> raw text (badge falls back to a neutral pill)


def extract_status(fm: dict, folder: Path) -> str:
    if fm.get("status"):
        return _normalize_status(fm["status"])
    prog = folder / "progress.md"
    if prog.exists():
        m = re.search(
            r"(?im)^\s*[-*]?\s*\**status:?\**\s*(.+)$",
            prog.read_text(encoding="utf-8", errors="ignore"),
        )
        if m:
            return _normalize_status(m.group(1))
    return ""


def collect(specs: Path) -> list[dict]:
    plans = []
    for folder in sorted(p for p in specs.iterdir() if p.is_dir()):
        plan_path = find_plan(folder)
        if not plan_path:
            continue
        html_text, _, _ = rp.render(plan_path)
        (folder / "PLAN.html").write_text(html_text, encoding="utf-8")

        text = plan_path.read_text(encoding="utf-8").replace("\r\n", "\n")
        fm, body = rp.parse_frontmatter(text)
        dates = folder_dates(folder)
        created = fm.get("created") or (min(dates) if dates else
                                        date.fromtimestamp(plan_path.stat().st_mtime).isoformat())
        updated = fm.get("revised") or (max(dates) if dates else created)
        title = rp.get_title(body)
        plans.append({
            "slug": folder.name,
            "title": title,
            "name": display_name(folder.name, title),
            "href": f"{folder.name}/PLAN.html",
            "created": created,
            "updated": updated,
            "status": extract_status(fm, folder),
            "owner": fm.get("owner", ""),
            "source": plan_path.name,
        })
    plans.sort(key=lambda p: (p["created"], p["slug"]), reverse=True)  # newest on top
    return plans


def build_html(plans: list[dict]) -> str:
    # Embedded in a <script> block, whose content is RAW text (the browser does
    # NOT decode HTML entities there) — so emit literal JSON and only neutralize
    # "<" to "<" so a stray "</script>" in data can't break out.
    data = json.dumps(plans).replace("<", "\\u003c")
    return _ROADMAP_TEMPLATE.replace("{{COUNT}}", str(len(plans))).replace("{{DATA}}", data)


def main(argv):
    if len(argv) < 2:
        raise SystemExit("Usage: build_roadmap.py <specs-dir>")
    specs = Path(argv[1]).resolve()
    if not specs.is_dir():
        raise SystemExit(f"Not a directory: {specs}")
    plans = collect(specs)
    out = specs / "ROADMAP.html"
    out.write_text(build_html(plans), encoding="utf-8")
    print(f"Rendered {len(plans)} plan(s); wrote {out} ({out.stat().st_size} bytes).")
    for p in plans:
        print(f"  {p['created']}  {p['slug']} -> {p['href']}")
    print(f"Open with: open {out}")


_ROADMAP_TEMPLATE = r"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Specs Roadmap</title>
<style>
  :root {
    --bg:#ffffff; --fg:#111827; --muted:#6b7280; --border:#e5e7eb; --accent:#6366f1;
    --accent-soft:#eef2ff; --card-bg:#ffffff; --shadow:0 1px 2px rgba(17,24,39,.05);
    --shadow-hover:0 8px 24px rgba(17,24,39,.1);
    --s-proposed-fg:#475569; --s-proposed-bg:#f1f5f9; --s-active-fg:#4338ca; --s-active-bg:#eef2ff;
    --s-paused-fg:#92400e; --s-paused-bg:#fef3c7; --s-shipped-fg:#065f46; --s-shipped-bg:#d1fae5;
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --bg:#0b0d12; --fg:#e5e7eb; --muted:#9ca3af; --border:#1f2937; --accent:#818cf8;
      --accent-soft:#1e1b4b; --card-bg:#11141b; --shadow:0 1px 2px rgba(0,0,0,.4);
      --shadow-hover:0 8px 24px rgba(0,0,0,.5);
      --s-proposed-fg:#cbd5e1; --s-proposed-bg:#1f2937; --s-active-fg:#c7d2fe; --s-active-bg:#312e81;
      --s-paused-fg:#fde68a; --s-paused-bg:#422006; --s-shipped-fg:#a7f3d0; --s-shipped-bg:#064e3b;
    }
  }
  * { box-sizing:border-box; }
  html,body { margin:0; padding:0; height:100%; }
  body {
    font-family:system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;
    background:var(--bg); color:var(--fg); line-height:1.6; -webkit-font-smoothing:antialiased;
    background-image:radial-gradient(ellipse 80% 50% at 50% -20%, var(--accent-soft) 0%, transparent 60%);
    background-repeat:no-repeat; background-attachment:fixed;
  }
  .app { display:grid; grid-template-columns: minmax(280px,380px) 1fr; gap:24px; max-width:1180px; margin:0 auto; padding:28px 22px; min-height:100vh; }
  @media (max-width:760px){ .app{ grid-template-columns:1fr; } }
  h1 { font-size:1.8rem; margin:0 0 2px; letter-spacing:-0.02em;
    background:linear-gradient(120deg,var(--fg),var(--accent) 80%); -webkit-background-clip:text; background-clip:text; -webkit-text-fill-color:transparent; color:transparent; }
  .sub { color:var(--muted); font-size:.86rem; margin:0 0 16px; }
  ul.plan-list { list-style:none; margin:0; padding:0; display:flex; flex-direction:column; gap:6px; }
  .plan-item { display:flex; align-items:center; gap:10px; padding:11px 13px; border:1px solid var(--border); border-radius:11px; background:var(--card-bg); cursor:pointer; box-shadow:var(--shadow); transition:border-color .15s,box-shadow .15s,transform .15s; }
  .plan-item:hover { border-color:color-mix(in oklab,var(--accent) 40%,var(--border)); box-shadow:var(--shadow-hover); transform:translateY(-1px); }
  .plan-item[aria-selected="true"] { border-color:var(--accent); box-shadow:0 0 0 3px var(--accent-soft); }
  .dot { width:9px; height:9px; border-radius:999px; flex:none; background:var(--muted); }
  .dot[data-status="proposed"]{ background:var(--s-proposed-fg);} .dot[data-status="active"]{ background:var(--s-active-fg);}
  .dot[data-status="paused"]{ background:var(--s-paused-fg);} .dot[data-status="shipped"]{ background:var(--s-shipped-fg);}
  .plan-name { font-weight:600; min-width:0; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
  .detail { position:sticky; top:28px; align-self:start; }
  .detail-card { border:1px solid var(--border); border-radius:16px; background:var(--card-bg); box-shadow:var(--shadow); padding:24px; }
  .detail-card h2 { margin:0 0 6px; font-size:1.35rem; letter-spacing:-0.01em; }
  .detail-slug { font-family:ui-monospace,SFMono-Regular,Menlo,monospace; font-size:.82rem; color:var(--muted); }
  .badge { display:inline-block; padding:3px 11px; border-radius:999px; font-size:.72rem; font-weight:700; text-transform:uppercase; letter-spacing:.03em; margin:12px 0; color:var(--s-proposed-fg); background:var(--s-proposed-bg); }
  .badge[data-status="proposed"]{ color:var(--s-proposed-fg); background:var(--s-proposed-bg);}
  .badge[data-status="active"]{ color:var(--s-active-fg); background:var(--s-active-bg);}
  .badge[data-status="paused"]{ color:var(--s-paused-fg); background:var(--s-paused-bg);}
  .badge[data-status="shipped"]{ color:var(--s-shipped-fg); background:var(--s-shipped-bg);}
  .badge[data-status=""]{ color:var(--muted); background:var(--border);}
  .meta-grid { display:grid; grid-template-columns:max-content 1fr; gap:10px 16px; margin:16px 0; font-size:.92rem; }
  .meta-grid dt { color:var(--muted); font-weight:600; font-size:.78rem; text-transform:uppercase; letter-spacing:.04em; }
  .meta-grid dd { margin:0; font-variant-numeric:tabular-nums; }
  .open-btn { display:inline-flex; align-items:center; gap:8px; margin-top:8px; padding:9px 16px; border-radius:9px; background:var(--accent); color:#fff; font-weight:600; font-size:.9rem; text-decoration:none; transition:filter .15s; }
  .open-btn:hover { filter:brightness(1.08); }
  .empty { color:var(--muted); padding:40px 16px; text-align:center; }
</style>
</head>
<body>
<div class="app">
  <aside>
    <h1>Roadmap</h1>
    <p class="sub">{{COUNT}} plans · newest first</p>
    <ul class="plan-list" id="list" role="listbox" aria-label="Plans"></ul>
  </aside>
  <main class="detail"><div id="detail"></div></main>
</div>
<script id="data" type="application/json">{{DATA}}</script>
<script>
(() => {
  const PLANS = JSON.parse(document.getElementById('data').textContent);
  const ACR = {ai:'AI',kb:'KB',xml:'XML',api:'API',sse:'SSE',db:'DB',rag:'RAG',ui:'UI',ux:'UX',pr:'PR',eng:'ENG',iac:'IaC',sdk:'SDK',cron:'cron',jwt:'JWT'};
  const pretty = (s) => s.split('-').map(w => ACR[w.toLowerCase()] || (w.charAt(0).toUpperCase()+w.slice(1))).join(' ');
  const fmtDate = (d) => { if(!d) return '—'; const m=String(d).match(/^(\d{4})-(\d{2})-(\d{2})/); if(!m) return d;
    const dt=new Date(+m[1],+m[2]-1,+m[3]); return dt.toLocaleDateString(undefined,{year:'numeric',month:'long',day:'numeric'}); };

  const list = document.getElementById('list');
  const detail = document.getElementById('detail');

  function renderDetail(p) {
    document.querySelectorAll('.plan-item').forEach(el => el.setAttribute('aria-selected', el.dataset.slug === p.slug));
    detail.innerHTML = `
      <div class="detail-card">
        <h2>${p.title ? p.title.replace(/[<>&]/g,'') : pretty(p.slug)}</h2>
        <div class="detail-slug">🔖 ${p.slug}</div>
        <span class="badge" data-status="${p.status}">${p.status || 'unknown'}</span>
        <dl class="meta-grid">
          <dt>Created</dt><dd>${fmtDate(p.created)}</dd>
          <dt>Updated</dt><dd>${fmtDate(p.updated)}</dd>
          ${p.owner ? `<dt>Owner</dt><dd>${p.owner}</dd>` : ''}
          <dt>Source</dt><dd><code>${p.source}</code></dd>
        </dl>
        <a class="open-btn" href="${p.href}">Open full plan →</a>
      </div>`;
  }

  if (!PLANS.length) { detail.innerHTML = '<div class="empty">No plans found.</div>'; return; }
  PLANS.forEach((p, i) => {
    const li = document.createElement('li');
    li.className = 'plan-item'; li.dataset.slug = p.slug; li.setAttribute('role','option');
    const label = p.name || pretty(p.slug);
    li.innerHTML = `<span class="dot" data-status="${p.status}"></span><span class="plan-name">${label.replace(/[<>&]/g,'')}</span>`;
    li.addEventListener('click', () => renderDetail(p));
    list.appendChild(li);
    if (i === 0) renderDetail(p);
  });
})();
</script>
</body>
</html>
"""


if __name__ == "__main__":
    main(sys.argv)
