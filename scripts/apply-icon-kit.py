#!/usr/bin/env python3
"""One-time migration: swap the site's inline Lucide-style icons for the Inlet icon kit.
Sample-app icons inside demo tiles (class "ico") are left alone: they imitate other apps."""
import re, json, pathlib
ROOT = pathlib.Path(__file__).resolve().parent.parent
kit = {k: v[1] for g in json.loads((ROOT/"design/icons/kit.json").read_text()).values() for k, v in g.items()}
def n(s): return re.sub(r'\s+', '', s)
MAP = {  # distinctive start of old inner markup -> kit id
 '<path d="m21 21-4.34-4.34': 'search', '<path d="M21 15v4a2': 'download', '<rect width="7" height="7" x="3" y="3"': 'grid',
 '<rect width="18" height="18" x="3" y="3" rx="2"/><path d="M12 3v18"': 'sidebar', '<path d="m5 12 7-7 7 7': 'arrow-up',
 '<rect width="20" height="14" x="2" y="3"': 'auto', '<circle cx="12" cy="12" r="4"': 'sun', '<path d="M12 3a6 6 0 0 0 9': 'moon',
 '<path d="m16 18 6-6-6-6': 'code', '<path d="M15.707 21.293': 'pen', '<path d="M21.42 10.922': 'cap', '<path d="M18 6 6 18': 'close',
 '<path d="M6 22a2 2 0 0 1-2-2V4': 'doc', '<path d="M13.4 2H6a2': 'edit',
}
PARENT = re.compile(r'class="([^"]*)"[^>]*>\s*$')
pat = re.compile(r'<svg\b([^>]*)>(.*?)</svg>', re.S)
tot = 0
for f in sorted((ROOT/'website').glob('*.html')):
    src = f.read_text(); out = []; last = 0; cnt = 0
    for m in pat.finditer(src):
        attrs, inner = m.groups()
        if 'viewBox="0 0 24 24"' not in attrs: continue
        pre = src[max(0, m.start()-160):m.start()]
        pm = PARENT.search(pre)
        if pm and 'ico' in pm.group(1).split(): continue
        inn = n(inner)
        kid = next((v for k, v in MAP.items() if inn.startswith(n(k))), None)
        if not kid: continue
        cls = re.search(r'class="([^"]*)"', attrs); cls = (cls.group(1) + ' ' if cls and cls.group(1) else '') + 'kit'
        w = re.search(r'\bwidth="(\d+)"', attrs); h = re.search(r'\bheight="(\d+)"', attrs)
        size = f' width="{w.group(1)}" height="{h.group(1)}"' if w and h else ''
        new = f'<svg class="{cls}" viewBox="0 0 24 24"{size} aria-hidden="true" focusable="false">{kit[kid]}</svg>'
        out.append(src[last:m.start()]); out.append(new); last = m.end(); cnt += 1
    out.append(src[last:]); s = ''.join(out)
    s = re.sub(r'(<span class="aud-ico") style="[^"]*"', r'\1', s)
    if '<link rel="stylesheet" href="css/icons.css">' not in s:
        s = s.replace('</head>', '  <link rel="stylesheet" href="css/icons.css">\n</head>', 1)
    f.write_text(s); tot += cnt; print(f.name, cnt)
print('total', tot)
