"""Monta visualizador.html (autocontido) a partir da pasta de saida.

Uso: python3 visualizador.py <pasta_saida> <arquivo_html>
"""
import base64
import json
import os
import sys

CAMADAS = ['corpo', 'cabeca', 'olhos', 'boca', 'objeto', 'frente']


def b64(path):
    with open(path, 'rb') as f:
        return base64.b64encode(f.read()).decode()


def main():
    out, html = sys.argv[1:3]
    meta = json.load(open(os.path.join(out, 'animacoes.json'), encoding='utf-8'))
    dados = {'formato': meta['formato'], 'grupos': {}}
    for g, tipos in meta['grupos'].items():
        dados['grupos'][g] = {}
        for t, anims in tipos.items():
            dados['grupos'][g][t] = {}
            for n, m in anims.items():
                pasta = os.path.join(out, g, t, n)
                img = {c: b64(os.path.join(pasta, c + '.png')) for c in m['camadas'] + ['completo']}
                dados['grupos'][g][t][n] = dict(m, img=img)
    tpl = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'visualizador_modelo.html'), encoding='utf-8').read()
    with open(html, 'w', encoding='utf-8') as f:
        f.write(tpl.replace('/*__DADOS__*/null', json.dumps(dados, ensure_ascii=False)))


if __name__ == '__main__':
    main()
