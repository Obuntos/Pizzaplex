"""Cria harness.html em cada versao do Orelhitas_Poses (scripts originais, sem o app, + matar.js + exporta.js).

Uso: python3 fazer_harness.py <pasta Orelhitas_Poses>
"""
import os
import re
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
base = sys.argv[1]
for v in ['normal', 'toy', 'quebrado', 'toyquebrado']:
    idx = open(os.path.join(base, v, 'index.html'), encoding='utf-8').read()
    skin = re.search(r'data-skin="([^"]+)"', idx).group(1)
    srcs = [s for s in re.findall(r'src="(js/[^"]+)"', idx) if 'visualizacao/app.js' not in s]
    tags = '\n'.join(f'<script src="{s}"></script>' for s in srcs)
    extra = '\n'.join(f'<script src="file://{os.path.join(AQUI, n)}"></script>' for n in ('matar.js', 'exporta.js'))
    html = f'<!doctype html><html><head><meta charset="utf-8"></head><body data-skin="{skin}">\n{tags}\n{extra}\n</body></html>'
    open(os.path.join(base, v, 'harness.html'), 'w', encoding='utf-8').write(html)
