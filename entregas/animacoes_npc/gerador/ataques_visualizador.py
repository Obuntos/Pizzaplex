"""Monta o visualizador dos ataques (autocontido). Uso: python3 ataques_visualizador.py <pasta .../ataques> <saida.html>"""
import base64
import json
import os
import sys


def b64(p):
    return base64.b64encode(open(p, 'rb').read()).decode()


def main():
    base, html = sys.argv[1:3]
    meta = json.load(open(os.path.join(base, 'ataques.json'), encoding='utf-8'))
    at = {}
    for v in meta['ataques']:
        sx = ('adulto_masculino', 'adulto_feminino')
        at[v] = {'longe': b64(os.path.join(base, v, 'animatronico', 'longe.png')),
                 'resto': b64(os.path.join(base, v, 'animatronico', 'resto.png')),
                 'hum': {s: b64(os.path.join(base, v, 'humano', s, 'ataque', 'completo.png')) for s in sx},
                 'chao': {s: b64(os.path.join(base, v, 'humano', s, 'corpo_no_chao', 'completo.png')) for s in sx}}
    tpl = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'ataques_visualizador_modelo.html'), encoding='utf-8').read()
    open(html, 'w', encoding='utf-8').write(tpl.replace('/*__DADOS__*/null', json.dumps({'meta': meta, 'at': at})))


if __name__ == '__main__':
    main()
