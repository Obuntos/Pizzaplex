"""Monta o visualizador do ataque (autocontido). Uso: python3 morte_visualizador.py <pasta .../morte> <saida.html>"""
import base64
import json
import os
import sys


def b64(p):
    return base64.b64encode(open(p, 'rb').read()).decode()


def main():
    base, html = sys.argv[1:3]
    meta = json.load(open(os.path.join(base, 'morte.json'), encoding='utf-8'))
    dados = {'meta': meta,
             'anim': {v: b64(os.path.join(base, 'animatronicos', v, 'matar.png')) for v in meta['animatronico']['versoes']},
             'hum': {s: b64(os.path.join(base, 'humano', s, 'morto_pelo_animatronico', 'completo.png')) for s in ('adulto_masculino', 'adulto_feminino')},
             'chao': {s: b64(os.path.join(base, 'humano', s, 'corpo_no_chao', 'completo.png')) for s in ('adulto_masculino', 'adulto_feminino')}}
    tpl = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'morte_visualizador_modelo.html'), encoding='utf-8').read()
    open(html, 'w', encoding='utf-8').write(tpl.replace('/*__DADOS__*/null', json.dumps(dados)))


if __name__ == '__main__':
    main()
