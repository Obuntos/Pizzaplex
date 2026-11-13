"""Gera as folhas de animacao, o JSON de metadados, o LEIA-ME e o visualizador.

Uso: python3 gerar.py <pasta_do_zip_extraido> <raiz_do_projeto> <pasta_saida> [filtro]
"""
import base64
import io
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import animacoes as A          # noqa: E402
import personagem as P         # noqa: E402
from motor import W, H, DIRECOES  # noqa: E402

CAMADAS = ['corpo', 'cabeca', 'objeto', 'frente']


def render_anim(T, a):
    frames = a['inicio'] + a['loop'] + a['fim']
    n = len(frames)
    sheets = {c: Image.new('RGBA', (W * n, H * 8)) for c in CAMADAS + ['completo']}
    for d in range(8):
        for i, pose in enumerate(frames):
            cam = P.montar(T, pose, d)
            for c in CAMADAS:
                sheets[c].paste(Image.fromarray(cam[c]), (i * W, d * H))
            sheets['completo'].paste(P.compor(cam), (i * W, d * H))
    return sheets, n


def main():
    src, repo, out = sys.argv[1:4]
    filtro = sys.argv[4] if len(sys.argv) > 4 else ''
    A.carregar_objetos(src)
    tipos = {}
    meta = {'formato': {'quadro': [W, H], 'pivo_pes': [24, 55], 'direcoes': DIRECOES,
                        'ordem_camadas': CAMADAS}, 'grupos': {}}
    for grupo, (lista_tipos, anims) in A.CATALOGO.items():
        meta['grupos'][grupo] = {}
        for tn in lista_tipos:
            if tn not in tipos:
                tipos[tn] = P.Tipo(tn, src, repo)
            T = tipos[tn]
            meta['grupos'][grupo][tn] = {}
            for nome, titulo, fn in anims:
                if filtro and filtro not in f'{grupo}/{tn}/{nome}':
                    continue
                a = fn(T)
                sheets, n = render_anim(T, a)
                pasta = os.path.join(out, grupo, tn, nome)
                os.makedirs(pasta, exist_ok=True)
                presentes = []
                for c, im in sheets.items():
                    if c != 'completo' and im.getbbox() is None:
                        continue
                    im.save(os.path.join(pasta, c + '.png'), optimize=True)
                    if c != 'completo':
                        presentes.append(c)
                ni, nl, nf = len(a['inicio']), len(a['loop']), len(a['fim'])
                meta['grupos'][grupo][tn][nome] = {
                    'titulo': titulo, 'quadros': n, 'fps': a['fps'],
                    'inicio': [0, ni], 'loop': [ni, ni + nl], 'fim': [ni + nl, n],
                    'camadas': presentes,
                }
                print(grupo, tn, nome, n, presentes, flush=True)
    with open(os.path.join(out, 'animacoes.json'), 'w', encoding='utf-8') as f:
        json.dump(meta, f, ensure_ascii=False, indent=1)


if __name__ == '__main__':
    main()
