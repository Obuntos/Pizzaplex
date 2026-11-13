"""Gera a animacao "Orelhitas matando o adulto" nas 4 versoes + o corpo no chao.

Uso: python3 gerar_morte.py <pasta_do_zip_dos_moldes> <raiz_do_projeto> <pasta Orelhitas_Poses> <pasta_saida>

Saida:
  morte/animatronicos/<versao>/matar.png         quadros 160x130 (chao em 80,92), 57 colunas x 8 direcoes
  morte/humano/<adulto_x>/morto_pelo_animatronico/{corpo,cabeca,frente,completo}.png   quadros 112x88 (pes em 56,61)
  morte/humano/<adulto_x>/corpo_no_chao/{corpo,cabeca,frente,completo}.png              1 coluna x 8 direcoes
  morte/morte.json                               intervalos, fps, escalas e onde fica o humano em relacao ao animatronico
"""
import base64
import io
import json
import math
import os
import subprocess
import sys

from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
import personagem as P   # noqa: E402
import morte as MO       # noqa: E402

VERSOES = [('normal', 'Orelhitas'), ('toy', 'Toy Orelhitas'), ('quebrado', 'Orelhitas Quebrado'),
           ('toyquebrado', 'Toy Orelhitas Quebrado')]
SEXOS = ['adulto_masculino', 'adulto_feminino']
CAMADAS = ['corpo', 'cabeca', 'frente']
AW, AH, AX, AY = 160, 130, 80, 92


def animatronicos(orelhitas, saida, n):
    pasta_js = os.path.join(AQUI, 'orelhitas')
    subprocess.run([sys.executable, os.path.join(pasta_js, 'fazer_harness.py'), orelhitas], check=True)
    tempos = ','.join(str(round(i / MO.FPS, 5)) for i in range(n))
    for v, _ in VERSOES:
        tmp = os.path.join(saida, f'_{v}.json')
        subprocess.run(['node', os.path.join(pasta_js, 'render.js'), os.path.join(orelhitas, v, 'harness.html'),
                        'matar', tempos, tmp], check=True)
        fr = json.load(open(tmp))['frames']
        os.remove(tmp)
        folha = Image.new('RGBA', (AW * n, AH * 8))
        for d, linha in enumerate(fr):
            for i, u in enumerate(linha):
                folha.paste(Image.open(io.BytesIO(base64.b64decode(u.split(',')[1]))), (i * AW, d * AH))
        pasta = os.path.join(saida, 'animatronicos', v)
        os.makedirs(pasta, exist_ok=True)
        folha.save(os.path.join(pasta, 'matar.png'), optimize=True)
        print('animatronico', v, flush=True)


def humano(src, repo, saida):
    P.tela(MO.QW, MO.QH, MO.QX, MO.QY + 1.4)
    for sx in SEXOS:
        T = P.Tipo(sx, src, repo)
        MO.preparar(T)
        ini, loop, fim = MO.quadros(T)
        for nome, poses in (('morto_pelo_animatronico', ini + loop + fim), ('corpo_no_chao', [MO.morto(T)])):
            folhas = {c: Image.new('RGBA', (MO.QW * len(poses), MO.QH * 8)) for c in CAMADAS + ['completo']}
            for d in range(8):
                for i, p in enumerate(poses):
                    cam = P.montar(T, p, d)
                    for c in CAMADAS:
                        folhas[c].paste(Image.fromarray(cam[c]), (i * MO.QW, d * MO.QH))
                    folhas['completo'].paste(P.compor(cam), (i * MO.QW, d * MO.QH))
            pasta = os.path.join(saida, 'humano', sx, nome)
            os.makedirs(pasta, exist_ok=True)
            for c, im in folhas.items():
                if c == 'completo' or im.getbbox() is not None:
                    im.save(os.path.join(pasta, c + '.png'), optimize=True)
            print('humano', sx, nome, flush=True)
    return len(ini), len(loop), len(fim)


def main():
    src, repo, orelhitas, saida = sys.argv[1:5]
    saida = os.path.join(saida, 'morte')
    os.makedirs(saida, exist_ok=True)
    ni, nl, nf = humano(src, repo, saida)
    n = ni + nl + nf
    animatronicos(orelhitas, saida, n)
    desloc = []
    for d in range(8):
        a = d * math.pi / 4
        # pes do humano em relacao ao chao do animatronico, em pixels do jogo
        desloc.append([round(math.sin(a) * MO.DIST * 1.2, 2), round(math.cos(a) * MO.DIST * .5, 2)])
    meta = {
        'fps': MO.FPS, 'quadros': n,
        'inicio': [0, ni], 'loop': [ni, ni + nl], 'fim': [ni + nl, n],
        'direcoes': ['frente', 'frente_direita', 'direita', 'costas_direita', 'costas', 'costas_esquerda', 'esquerda', 'frente_esquerda'],
        'animatronico': {'quadro': [AW, AH], 'chao': [AX, AY], 'escala_jogo': [1.2, 1.0],
                         'versoes': {v: t for v, t in VERSOES}},
        'humano': {'quadro': [MO.QW, MO.QH], 'pes': [MO.QX, MO.QY], 'escala_jogo': [1.375, 1.375],
                   'linha': 'direcao do humano = (direcao do animatronico + 4) % 8 (ele fica de frente para o animatronico)',
                   'camadas': CAMADAS},
        'humano_em_relacao_ao_animatronico': {
            'explicacao': 'para a direcao d do animatronico, os pes do humano ficam em chao_animatronico + deslocamento[d] (pixels do jogo)',
            'deslocamento': desloc,
            'ordem': 'se deslocamento[d][1] > 0.5 o humano e desenhado por cima; senao o animatronico vai por cima'},
    }
    json.dump(meta, open(os.path.join(saida, 'morte.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)


if __name__ == '__main__':
    main()
