"""Gera os 4 ataques do Orelhitas ao adulto + o corpo de cada um no chao + o visualizador.

Uso: python3 gerar_ataques.py <pasta_dos_moldes> <raiz_do_projeto> <pasta Orelhitas_Poses> <pasta_saida>
"""
import base64
import io
import json
import os
import subprocess
import sys

from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
import personagem as P   # noqa: E402
import ataques as AT     # noqa: E402

SEXOS = ['adulto_masculino', 'adulto_feminino']
CAMADAS = ['corpo', 'cabeca', 'objeto', 'frente']
AW, AH, AX, AY = 160, 130, 80, 92
DIRS = ['frente', 'frente_direita', 'direita', 'costas_direita', 'costas', 'costas_esquerda', 'esquerda', 'frente_esquerda']


def folha_humano(T, poses, pasta):
    folhas = {c: Image.new('RGBA', (AT.QW * len(poses), AT.QH * 8)) for c in CAMADAS + ['completo']}
    for d in range(8):
        for i, p in enumerate(poses):
            cam = P.montar(T, p, d)
            for c in CAMADAS:
                folhas[c].paste(Image.fromarray(cam[c]), (i * AT.QW, d * AT.QH))
            folhas['completo'].paste(P.compor(cam), (i * AT.QW, d * AT.QH))
    os.makedirs(pasta, exist_ok=True)
    salvas = []
    for c, im in folhas.items():
        if c == 'completo' or im.getbbox() is not None:
            im.save(os.path.join(pasta, c + '.png'), optimize=True)
            if c != 'completo':
                salvas.append(c)
    return salvas


def folha_animatronico(orelhitas, versao, canais, pasta):
    tmp_q = os.path.join(pasta, '_quadros.json')
    tmp_o = os.path.join(pasta, '_saida.json')
    os.makedirs(pasta, exist_ok=True)
    json.dump(canais, open(tmp_q, 'w'))
    subprocess.run(['node', os.path.join(AQUI, 'orelhitas', 'render.js'), os.path.join(orelhitas, versao, 'harness.html'), tmp_q, tmp_o], check=True)
    fr = json.load(open(tmp_o))['frames']
    n = len(fr[0])
    for camada in ('resto', 'longe'):
        folha = Image.new('RGBA', (AW * n, AH * 8))
        for d, linha in enumerate(fr):
            for i, q in enumerate(linha):
                folha.paste(Image.open(io.BytesIO(base64.b64decode(q[camada].split(',')[1]))), (i * AW, d * AH))
        folha.save(os.path.join(pasta, camada + '.png'), optimize=True)
    completo = Image.alpha_composite(Image.open(os.path.join(pasta, 'longe.png')), Image.open(os.path.join(pasta, 'resto.png')))
    completo.save(os.path.join(pasta, 'completo.png'), optimize=True)
    json.dump(canais, open(os.path.join(pasta, 'canais.json'), 'w'))
    os.remove(tmp_q)
    os.remove(tmp_o)


def main():
    src, repo, orelhitas, saida = sys.argv[1:5]
    saida = os.path.join(saida, 'ataques')
    subprocess.run([sys.executable, os.path.join(AQUI, 'orelhitas', 'fazer_harness.py'), orelhitas], check=True)
    P.tela(AT.QW, AT.QH, AT.QX, AT.QY + 1.4)
    tipos = {}
    for sx in SEXOS:
        T = P.Tipo(sx, src, repo)
        T.ampliar(AT.QW, AT.QH, AT.QX - 24, AT.QY - 55)
        tipos[sx] = T
    meta = {'fps': AT.FPS, 'direcoes': DIRS,
            'animatronico': {'quadro': [AW, AH], 'chao': [AX, AY], 'escala_jogo': [1.2, 1.0],
                             'camadas': {'longe': 'braco do lado oposto a camera: vai ATRAS da vitima', 'resto': 'todo o resto'}},
            'humano': {'quadro': [AT.QW, AT.QH], 'pes': [AT.QX, AT.QY], 'escala_jogo': [1.375, 1.375], 'camadas': CAMADAS,
                       'linha': 'direcao do humano = (direcao do animatronico + 4) % 8'},
            'ordem': ('para a direcao d: se deslocamento[d][1] > 3 (vitima mais perto da camera): longe, resto, humano; '
                      'se < -3 (vitima mais longe): humano, longe, resto; senao (de lado): longe, humano, resto'),
            'ataques': {}}
    for versao, (nome, acao, _) in AT.ATAQUES.items():
        info = {'nome': nome, 'acao': acao}
        for sx in SEXOS:
            T = tipos[sx]
            cena, poses, canais, (ni, nl, nf), morto = AT.montar_ataque(T, versao)
            camadas = folha_humano(T, poses, os.path.join(saida, versao, 'humano', sx, 'ataque'))
            folha_humano(T, [morto], os.path.join(saida, versao, 'humano', sx, 'corpo_no_chao'))
            print(versao, sx, flush=True)
            if sx == SEXOS[0]:
                # as maos do animatronico sao calculadas sobre o adulto masculino (no feminino a diferenca e < 1 px)
                folha_animatronico(orelhitas, versao, canais, os.path.join(saida, versao, 'animatronico'))
                print(versao, 'animatronico', flush=True)
                n = ni + nl + nf
                info.update({'quadros': n, 'inicio': [0, ni], 'loop': [ni, ni + nl], 'fim': [ni + nl, n],
                             'deslocamento': cena.deslocamentos(), 'camadas_humano': camadas})
        meta['ataques'][versao] = info
    json.dump(meta, open(os.path.join(saida, 'ataques.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)


if __name__ == '__main__':
    main()
