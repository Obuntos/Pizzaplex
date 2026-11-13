"""Biblioteca de animacoes. Cada animacao devolve dict(inicio, loop, fim, fps)
com listas de poses (dicts completos de personagem.pose_base)."""
import math
import os
import numpy as np
from PIL import Image

import motor as M
from motor import v3
from personagem import pose_base, mistura, suave, rest_hand

TAU = 2 * math.pi
OBJ = {}


# ------------------------------------------------------------------ util

def carregar_objetos(src):
    def load(nome, escala, crop=None):
        out = {}
        for v in ('frente', 'direita', 'costas', 'esquerda'):
            im = Image.open(os.path.join(src, 'objetos', nome, v + '.png')).convert('RGBA')
            if crop:
                im = im.crop(crop)
            im = im.crop(im.getbbox())
            w, h = im.size
            nw, nh = max(1, round(w * escala)), max(1, round(h * escala))
            # reducao sem borrar: pre-multiplica, reduz, limiariza alfa
            a = np.asarray(im).astype(float)
            a[..., :3] *= a[..., 3:4] / 255
            im2 = Image.fromarray(a.astype(np.uint8)).resize((nw, nh), Image.BOX)
            al = im.split()[3].resize((nw, nh), Image.BOX)
            b = np.asarray(im2).astype(float)
            al = np.asarray(al).astype(float)
            b[..., :3] = np.clip(b[..., :3] * 255 / np.maximum(al[..., None], 1), 0, 255)
            b[..., 3] = np.where(al > 100, 255, 0)
            out[v] = b.astype(np.uint8)
        return out
    OBJ['pizza'] = load('fatia_pizza', 0.46)
    OBJ['bolo'] = load('fatia_bolo', 0.8)
    OBJ['presente'] = load('presente_pequeno', 0.56)
    OBJ['balao'] = load('balao', 0.62, crop=(0, 0, 25, 26))


def P(T, **kw):
    p = pose_base(T)
    p.update(kw)
    return p


def amostra(keys, t, ciclico):
    """keys: lista de (tempo 0..1, pose)."""
    ks = list(keys)
    if ciclico:
        ks = ks + [(1.0 + ks[0][0], ks[0][1])]
    if t <= ks[0][0]:
        return ks[0][1]
    for (t0, p0), (t1, p1) in zip(ks, ks[1:]):
        if t0 <= t <= t1:
            u = (t - t0) / max(1e-9, t1 - t0)
            return mistura(p0, p1, suave(u))
    return ks[-1][1]


def fase(keys, n, ciclico=False):
    if ciclico:
        return [amostra(keys, i / n, True) for i in range(n)]
    return [amostra(keys, (i + 1) / n, False) for i in range(n)]


def com(p, **kw):
    q = dict(p)
    q.update(kw)
    return q


def anim(inicio, loop, fim, fps=10):
    return dict(inicio=inicio, loop=loop, fim=fim, fps=fps)


def face_u(T, y, f, du=0.0):
    """u de um ponto do rosto, compensando a projecao na vista de frente."""
    return T.u_de_y(y) + M.K * f * 0.6 + du


def fala(i, padrao=('neutro', 'aberta', 'neutro', 'o', 'aberta', 'neutro')):
    return padrao[i % len(padrao)]


# ------------------------------------------------------------------ objetos

def prop_sprite(nome, alvo, zoff=0.0, vista=None, ancora=None):
    return dict(t='sprite', img=OBJ[nome], at=alvo, zoff=zoff, vista=vista, ancora=ancora)


def mao(J, s, avanco=0.6, T=None):
    return J['W' + s] + J['Hd' + s] * avanco


def fatia_pizza(J, T, p):
    c = mao(J, 'R', 1.0) + v3(0, 0, 0.6)
    return [prop_sprite('pizza', c, zoff=-0.6)] if p['a1'] < 0.5 else []


def prato_bolo(J, T, p):
    out = []
    c = mao(J, 'L', 0.9) + v3(0.5, 1.0, 1.3)
    out.append(dict(t='disc', c=c, r=3.6, r2=3.0, rgb=(236, 236, 228), g='prato'))
    if p['a1'] < 0.5:
        out.append(prop_sprite('bolo', c + v3(0, 0, 1.6), zoff=0.4))
    # garfo na mao direita
    w = mao(J, 'R', 0.5)
    dvec = J['HdR']
    out.append(dict(t='cap', a=w, b=w + dvec * 3.2, r=0.38, rgb=(180, 185, 190), g='garfo'))
    if p['a2'] > 0.5:
        out.append(dict(t='cap', a=w + dvec * 3.2, b=w + dvec * 3.4, r=0.8, rgb=(250, 240, 245), g='garfo2'))
    return out


def caixa_presente(J, T, p):
    c = (J['WL'] + J['WR']) / 2 + v3(0, 0.3, 0.2)
    return [prop_sprite('presente', c, zoff=-1.6)]


def balao(J, T, p):
    w = mao(J, 'R', 0.4)
    sway = p['a1']
    top = w + v3(3.2 + sway, -5.5 - abs(sway), 18.5 + 0.6 * sway)
    return [dict(t='cap', a=w, b=top, r=0.3, rgb=(225, 225, 215), g='fio', zoff=-40),
            prop_sprite('balao', top, zoff=-40, ancora='base')]


def ajusta_balao(T):
    # ancora do balao na base (no)
    for v, img in OBJ['balao'].items():
        pass


# ------------------------------------------------------------------ caminhada / corrida

def passo(T, ph, stride=None, lift=None, bob=0.7, braco=True):
    stride = stride if stride is not None else (2.6 if T.nome == 'crianca' else 2.8)
    lift = lift if lift is not None else 1.6
    c = math.cos(TAU * ph)
    s = math.sin(TAU * ph)
    fL = v3(-T.leg_off, stride * c, T.ankle_u + max(0.0, -s) * lift)
    fR = v3(T.leg_off, -stride * c, T.ankle_u + max(0.0, s) * lift)
    pel = v3(0, 0, bob * (1 - abs(c)) - bob * 0.8)
    out = dict(fL=fL, fR=fR, pelvis=pel, pdL=v3(0, 1, -0.15 * max(0, -s)), pdR=v3(0, 1, -0.15 * max(0, s)))
    if braco:
        hl = rest_hand(T, 'L')
        hr = rest_hand(T, 'R')
        out['hL'] = hl + v3(0, -1.6 * c, 0.3 * abs(c))
        out['hR'] = hr + v3(0, 1.6 * c, 0.3 * abs(c))
    return out


def corrida(T, ph, braco=True, alc=1.0):
    c = math.cos(TAU * ph)
    s = math.sin(TAU * ph)
    st = 3.6 * alc
    fL = v3(-T.leg_off * 0.9, st * c, T.ankle_u + max(0.0, -s) * 3.4 * alc + 0.2)
    fR = v3(T.leg_off * 0.9, -st * c, T.ankle_u + max(0.0, s) * 3.4 * alc + 0.2)
    pel = v3(0, 0.6 * alc, (1.3 * (1 - abs(c)) - 1.2) * alc)
    out = dict(fL=fL, fR=fR, pelvis=pel, lean=13 * alc,
               pdL=v3(0, 1, -0.3 * max(0, -s)), pdR=v3(0, 1, -0.3 * max(0, s)))
    if braco:
        sh = T.sh_u
        out['hL'] = v3(-T.sh_r - 0.3, -2.4 * c * alc + 1.2, sh - T.arm * 0.62 + 1.2 * max(0, -c))
        out['hR'] = v3(T.sh_r + 0.3, 2.4 * c * alc + 1.2, sh - T.arm * 0.62 + 1.2 * max(0, c))
        out['eL'] = v3(-0.3, -1, -0.3)
        out['eR'] = v3(0.3, -1, -0.3)
    return out


# ================================================================== ANIMACOES

def bater_palmas(T):
    R = P(T)
    ch = T.sh_u - 3.0
    fwd = T.arm * 0.62

    def abre(k=1.0, **kw):
        return P(T, **{**dict(hL=v3(-3.4 * k, fwd, ch), hR=v3(3.4 * k, fwd, ch), eL=v3(-1, -0.3, -1), eR=v3(1, -0.3, -1),
                 hdL=v3(0.5, 0.3, 0.8), hdR=v3(-0.5, 0.3, 0.8), eyes='feliz', mouth='aberta'), **kw})

    def fecha(**kw):
        return P(T, **{**dict(hL=v3(-0.95, fwd + 0.4, ch + 0.4), hR=v3(0.95, fwd + 0.4, ch + 0.4),
                 eL=v3(-1, -0.3, -1), eR=v3(1, -0.3, -1),
                 hdL=v3(0.5, 0.3, 0.8), hdR=v3(-0.5, 0.3, 0.8), eyes='riso', mouth='riso',
                 pelvis=v3(0, 0, -0.4)), **kw})
    ini = fase([(0, R), (0.6, abre(1.4, eyes='neutro', mouth='neutro')), (1, abre())], 4)
    loop = fase([(0, abre()), (0.25, fecha()), (0.5, abre(head=v3(0, 0, 0.0))), (0.75, fecha())], 8, True)
    fim = fase([(0, abre()), (0.5, abre(1.4, eyes='neutro', mouth='neutro')), (1, R)], 4)
    return anim(ini, loop, fim, 12)


def apontar_rindo(T):
    R = P(T)

    def ap(k, **kw):
        base = dict(hR=v3(T.sh_r * 0.4, T.arm * 0.95, T.sh_u + 0.6), eR=v3(0.4, 0, -1),
                    hdR=v3(0, 1, 0.1),
                    hL=v3(-2.6, 3.0, T.hip_u + 3.2), eL=v3(-1, -0.2, 0), hdL=v3(0.6, 0.6, 0))
        base.update(kw)
        p = P(T, **base)
        return mistura(R, p, k)
    ini = fase([(0, R), (0.5, ap(0.7, eyes='neutro')), (1, ap(1, eyes='riso', mouth='riso'))], 5)
    loop = []
    n = 12
    for i in range(n):
        t = i / n
        sh = math.sin(TAU * 3 * t)
        loop.append(ap(1, lean=7 + 4 * math.sin(TAU * t), shrug=0.6 * max(0, sh),
                       pelvis=v3(0, 0, -0.3 * abs(sh)), head=v3(0, 0, 0.5 * max(0, sh)),
                       eyes='riso', mouth='riso' if i % 2 == 0 else 'aberta',
                       hR=v3(T.sh_r * 0.4, T.arm * 0.95, T.sh_u + 0.6 + 0.6 * sh)))
    fim = fase([(0, loop[0]), (0.5, ap(0.6, eyes='feliz', mouth='aberta')), (1, R)], 5)
    return anim(ini, loop, fim, 12)


def conversar(T, var):
    R = P(T)
    n = 12
    loop = []
    if var == 1:      # gesticula com a mao direita
        for i in range(n):
            t = i / n
            g = 0.5 - 0.5 * math.cos(TAU * t)
            loop.append(P(T, hR=v3(T.sh_r - 0.5 + 1.8 * g, T.arm * 0.55 + 1.2 * g, T.sh_u - 4.5 + 2.5 * g),
                          eR=v3(1, -0.5, -1), hdR=v3(0.2, 1, 0.4 * g), mouth=fala(i),
                          head=v3(0, 0, 0.4 * math.sin(TAU * 2 * t)), roll=1.5 * math.sin(TAU * t)))
    elif var == 2:    # as duas maos abrindo, explicando
        for i in range(n):
            t = i / n
            g = 0.5 - 0.5 * math.cos(TAU * t)
            g2 = 0.5 - 0.5 * math.cos(TAU * (t + 0.25))
            loop.append(P(T, hL=v3(-1.8 - 2.6 * g, T.arm * 0.6, T.sh_u - 3.8 + 1.0 * g2),
                          hR=v3(1.8 + 2.6 * g, T.arm * 0.6, T.sh_u - 3.8 + 1.0 * g2),
                          eL=v3(-1, -0.4, -1), eR=v3(1, -0.4, -1), hdL=v3(-0.3, 1, 0.3), hdR=v3(0.3, 1, 0.3),
                          mouth=fala(i, ('aberta', 'neutro', 'o', 'neutro')), lean=2 + 2 * g))
    elif var == 3:    # bracos cruzados, acenando com a cabeca
        for i in range(n):
            t = i / n
            nod = max(0, math.sin(TAU * 2 * t))
            loop.append(P(T, hL=v3(2.3, 2.9, T.sh_u - 4.3), hR=v3(-2.3, 3.4, T.sh_u - 5.0),
                          eL=v3(-1, -0.2, -0.4), eR=v3(1, -0.2, -0.4), hdL=v3(1, 0, 0), hdR=v3(-1, 0, 0),
                          head=v3(0, 0.3 * nod, -0.9 * nod), mouth=fala(i, ('neutro', 'neutro', 'aberta', 'neutro', 'o', 'neutro')),
                          roll=-2.0, pelvis=v3(0.4, 0, 0)))
    else:             # mao na cintura, outra mao gesticulando e olhando para os lados
        for i in range(n):
            t = i / n
            g = max(0, math.sin(TAU * t))
            loop.append(P(T, hL=v3(-T.sh_r - 1.6, -0.2, T.hip_u + 1.2), eL=v3(-1, -0.3, 0.3), hdL=v3(1, 0.3, 0),
                          hR=v3(T.sh_r - 1.0 + 1.0 * g, T.arm * 0.5 + 1.0 * g, T.sh_u - 5 + 4.0 * g),
                          eR=v3(1, -0.4, -1), hdR=v3(0, 0.4, 1),
                          hturn=(1 if 0.25 <= t < 0.5 else 0), roll=2.5, pelvis=v3(-0.5, 0, 0),
                          mouth=fala(i, ('aberta', 'neutro', 'aberta', 'o', 'neutro', 'neutro'))))
    l0 = loop[0]
    ini = fase([(0, R), (1, com(l0, mouth='neutro'))], 4)
    fim = fase([(0, com(l0, mouth='neutro')), (1, R)], 4)
    return anim(ini, loop, fim, 9)


def jogar_fliperama(T):
    R = P(T)
    u = T.hip_u + 4.6
    f = T.arm * 0.78

    def jg(jx=0.0, jy=0.0, bt=0.0, **kw):
        base = dict(hL=v3(-2.6 + jx, f + jy, u + 0.4), hR=v3(2.8, f + 0.3, u - bt),
                    eL=v3(-1, -0.3, -0.6), eR=v3(1, -0.3, -0.6), hdL=v3(0, 0.3, -1), hdR=v3(0, 0.6, -0.8),
                    lean=8, fL=v3(-T.leg_off - 0.6, 0.3, T.ankle_u), fR=v3(T.leg_off + 0.6, -0.4, T.ankle_u))
        base.update(kw)
        return P(T, **base)
    loop = []
    n = 12
    for i in range(n):
        t = i / n
        jx = 0.9 * math.cos(TAU * 2 * t)
        jy = 0.6 * math.sin(TAU * 2 * t)
        bt = 0.9 if i % 3 == 0 else 0.0
        loop.append(jg(jx, jy, bt, roll=1.5 * math.sin(TAU * t), mouth='o' if 5 <= i <= 7 else 'neutro',
                       eyes='assustado' if 5 <= i <= 7 else 'neutro'))
    ini = fase([(0, R), (1, loop[0])], 4)
    fim = fase([(0, loop[0]), (1, R)], 4)
    return anim(ini, loop, fim, 12)


def comer_pizza(T):
    R = P(T)
    du = 0.0
    peito = dict(hR=v3(T.sh_r * 0.35, T.arm * 0.6, T.sh_u - 4.5), eR=v3(1, -0.6, -0.8), hdR=v3(-0.2, 0.6, 0.8))
    boca = dict(hR=v3(1.2, 4.2, face_u(T, T.mouth_y, 4.2) - 0.6), eR=v3(1, -0.2, -1), hdR=v3(-0.3, 0.5, 0.8),
                head=v3(0, 0.4, -0.5), lean=3, overR='face')
    pe = P(T, props=fatia_pizza, **peito)
    bo = P(T, props=fatia_pizza, mouth='aberta', **boca)
    baixo = P(T, props=fatia_pizza, hR=rest_hand(T, 'R') + v3(-0.5, 1.2, 1.0), hdR=v3(0, 0.8, 0.4))
    ini = fase([(0, com(baixo, props=fatia_pizza)), (1, pe)], 4)
    loop = []
    keys = [(0, pe), (0.25, bo), (0.36, com(bo, mouth='mastiga')), (0.6, com(pe, mouth='mastiga')),
            (0.8, com(pe, mouth='neutro'))]
    for i, p in enumerate(fase(keys, 12, True)):
        if i >= 5:
            p = com(p, mouth='mastiga' if i % 2 else 'neutro')
        loop.append(p)
    vazio = dict(a1=1.0)
    fim = fase([(0, pe), (0.3, bo), (0.42, com(bo, mouth='mastiga', **vazio)),
                (0.75, com(pe, mouth='mastiga', **vazio)), (1, com(R, mouth='neutro', props=fatia_pizza, **vazio))], 7)
    for i in (3, 5):
        fim[i] = com(fim[i], mouth='neutro')
    return anim(ini, loop, fim, 10)


def comer_bolo(T):
    R = P(T)
    plate = dict(hL=v3(-1.2, T.arm * 0.72, T.sh_u - 5.2), eL=v3(-1, -0.4, -0.8), hdL=v3(0.4, 0.8, 0))
    fork_plate = dict(hR=v3(0.9, T.arm * 0.78, T.sh_u - 4.6), eR=v3(1, -0.4, -0.8), hdR=v3(-0.4, 0.4, -0.8))
    fork_mouth = dict(hR=v3(1.4, 3.6, face_u(T, T.mouth_y, 3.6) - 2.0), eR=v3(1, -0.2, -1),
                      hdR=v3(-0.3, 0.6, 0.6), head=v3(0, 0.3, -0.4), overR='face')
    a = P(T, props=prato_bolo, **plate, **fork_plate)
    b = P(T, props=prato_bolo, a2=1.0, **plate, **fork_plate)
    c = P(T, props=prato_bolo, a2=1.0, mouth='aberta', **plate, **fork_mouth)
    d = P(T, props=prato_bolo, a2=0.0, mouth='mastiga', **plate, **fork_mouth)
    baixo = P(T, props=prato_bolo, hL=rest_hand(T, 'L') + v3(0.5, 1.6, 1.4), hR=rest_hand(T, 'R') + v3(-0.3, 1.0, 1.0),
              hdL=v3(0.4, 0.8, 0), hdR=v3(0, 0.6, 0.6))
    ini = fase([(0, baixo), (1, a)], 4)
    loop = fase([(0, a), (0.18, b), (0.42, c), (0.52, d), (0.75, com(a, mouth='mastiga')), (0.9, com(a, mouth='neutro'))],
                12, True)
    fim = fase([(0, a), (0.5, com(a, a1=1.0)), (1, com(baixo, a1=1.0))], 5)
    return anim(ini, loop, fim, 10)


def rindo(T, crianca=False):
    R = P(T)
    if crianca:
        maos = dict(hL=v3(-2.6, 3.2, T.hip_u + 3.0), hR=v3(2.6, 3.2, T.hip_u + 3.0),
                    eL=v3(-1, -0.3, 0), eR=v3(1, -0.3, 0), hdL=v3(0.6, 0.5, 0), hdR=v3(-0.6, 0.5, 0))
    else:
        maos = dict(hL=v3(-2.6, 3.0, T.hip_u + 3.4), eL=v3(-1, -0.3, 0), hdL=v3(0.6, 0.5, 0),
                    hR=v3(1.4, 3.8, face_u(T, T.mouth_y, 3.8) - 1.2), eR=v3(1, -0.2, -1), hdR=v3(-0.3, 0.6, 0.6),
                    overR='face')
    pose = P(T, eyes='riso', mouth='riso', **maos)
    ini = fase([(0, R), (0.5, mistura(R, pose, 0.6)), (1, pose)], 4)
    loop = []
    n = 12
    for i in range(n):
        t = i / n
        sh = math.sin(TAU * 3 * t)
        lean = (6 + 8 * (0.5 - 0.5 * math.cos(TAU * t))) if crianca else (-3 + 5 * (0.5 - 0.5 * math.cos(TAU * t)))
        loop.append(com(pose, lean=lean, shrug=0.5 * max(0, sh), pelvis=v3(0, 0, -0.35 * abs(sh)),
                        head=v3(0, 0, 0.5 * max(0, sh)), mouth='riso' if i % 2 == 0 else 'aberta',
                        eyes='riso'))
    fim = fase([(0, loop[0]), (0.5, mistura(R, com(pose, eyes='feliz', mouth='aberta'), 0.5)), (1, R)], 4)
    return anim(ini, loop, fim, 12)


# ------------------------------------------------------------------ criancas

def correr(T, pegador=False):
    R = P(T)
    loop = []
    n = 8
    for i in range(n):
        ph = i / n
        c = corrida(T, ph)
        kw = dict(eyes='riso' if not pegador else 'neutro', mouth='riso' if not pegador else 'aberta')
        if pegador:
            c['hR'] = v3(T.sh_r * 0.5, T.arm * 0.95, T.sh_u + 0.6 + 0.5 * math.sin(TAU * ph * 2))
            c['eR'] = v3(0.4, 0, -1)
            c['hdR'] = v3(0, 1, 0.2)
        elif i in (2, 3):
            kw['hturn'] = 1 if i == 2 else -1  # olha para tras de leve
        loop.append(P(T, **c, **kw))
    # comeco: acelera a partir de parado
    ini = []
    for i in range(4):
        k = (i + 1) / 5
        c = corrida(T, (i / 4) * 0.5 + 0.5, alc=k)
        kw = {}
        if pegador:
            kw = dict(hR=mistura(R, loop[0], k)['hR'], eR=v3(0.4, 0, -1), hdR=v3(0, 1, 0.2))
        ini.append(com(P(T, **{**c, **kw}), eyes=loop[0]['eyes'], mouth=loop[0]['mouth']))
    fim = []
    for i in range(5):
        k = 1 - (i + 1) / 6
        c = corrida(T, (i / 5) * 0.5, alc=k)
        p = P(T, **c, eyes=loop[0]['eyes'], mouth='aberta')
        if pegador and i == 3:
            p['hR'] = v3(T.sh_r * 0.4, T.arm * 1.05, T.sh_u)  # tocou!
            p['hdR'] = v3(0, 1, 0)
            p['mouth'] = 'riso'
            p['eyes'] = 'riso'
        fim.append(p)
    fim.append(com(R, mouth='aberta', shrug=0.4))
    return anim(ini, loop, fim, 12)


def sentar_chao(T, maos, olhos='assustado', boca='neutro', tremor=True, extra=None):
    R = P(T)
    du = -(T.hip_u - 3.3)
    pes = dict(fL=v3(-T.leg_off - 0.6, 6.2, T.ankle_u), fR=v3(T.leg_off + 0.6, 6.2, T.ankle_u),
               kL=v3(-0.2, 0.5, 1), kR=v3(0.2, 0.5, 1), pelvis=v3(0, -0.5, du), lean=10)
    agach = P(T, pelvis=v3(0, -1.0, du * 0.5), fL=v3(-T.leg_off, 2.5, T.ankle_u), fR=v3(T.leg_off, 2.5, T.ankle_u),
              kL=v3(0, 1, 0.5), kR=v3(0, 1, 0.5), lean=18,
              hL=rest_hand(T, 'L') + v3(0, 2.5, du * 0.5 + 1), hR=rest_hand(T, 'R') + v3(0, 2.5, du * 0.5 + 1),
              eyes=olhos)
    sent = P(T, eyes=olhos, mouth=boca, **pes)
    final = com(sent, **maos(du))
    if extra:
        final.update(extra)
    ini = fase([(0, R), (0.4, agach), (0.7, com(sent, hL=agach['hL'] + v3(0, 0, du * 0.5), hR=agach['hR'] + v3(0, 0, du * 0.5))),
                (1, final)], 6)
    loop = []
    n = 8
    for i in range(n):
        t = i / n
        j = math.sin(TAU * 4 * t) if tremor else 0
        rock = math.sin(TAU * t)
        q = com(final, pelvis=final['pelvis'] + v3(0.25 * j, 0, 0), lean=final['lean'] + 4 * rock,
                head=final['head'] + v3(0.3 * j, 0, 0.2 * j))
        loop.append(q)
    fim = fase([(0, final), (0.3, com(sent, eyes='neutro')), (0.65, com(agach, eyes='neutro')), (1, R)], 6)
    return anim(ini, loop, fim, 10), final


def sentada_mao_boca(T):
    def maos(du):
        y = face_u(T, T.mouth_y, 4.0, du) - 1.8
        return dict(hL=v3(-1.0, 3.8, y - 0.4), hR=v3(1.0, 4.4, y + 0.6), eL=v3(-1, -0.3, -1), eR=v3(1, -0.3, -1),
                    hdL=v3(0.2, 0.3, 1), hdR=v3(-0.2, 0.3, 1), overL='face', overR='face',
                    head=v3(0, 0.6, -1.4), shrug=1.0, stretch=1.3)
    a, _ = sentar_chao(T, maos)
    return a


def sentada_maos_orelhas(T):
    def maos(du):
        y = face_u(T, T.eye_y, 0, du) - 1.6
        rr = T.head_rx - 1.2
        return dict(hL=v3(-rr, 0.6, y), hR=v3(rr, 0.6, y), eL=v3(-1, -0.2, -0.6), eR=v3(1, -0.2, -0.6),
                    hdL=v3(0, 0, 1), hdR=v3(0, 0, 1), overL='always', overR='always',
                    head=v3(0, 0.4, -1.4), shrug=1.2, stretch=1.35)
    a, _ = sentar_chao(T, maos, olhos='fechado', boca='neutro')
    return a


def sentada_tampando_olhos(T):
    def maos(du):
        y = face_u(T, T.eye_y, 5.4, du) - 1.6
        return dict(hL=v3(-3.4, 5.4, y), hR=v3(3.4, 5.4, y), eL=v3(-1, -0.3, -1), eR=v3(1, -0.3, -1),
                    hdL=v3(0.1, 0.2, 1), hdR=v3(-0.1, 0.2, 1), overL='face', overR='face',
                    head=v3(0, 0.6, -1.4), shrug=1.0, stretch=1.35)
    a, final = sentar_chao(T, maos, olhos='assustado')
    for fasen in ('inicio', 'loop', 'fim'):
        for i, p in enumerate(a[fasen]):
            if p['overL'] == 'face' and (fasen == 'loop' or i >= 4 or (fasen == 'fim' and i < 1)):
                a[fasen][i] = com(p, eyes='fechado')
    # espiadinha: a mao esquerda desce um pouco no meio do loop
    for i in (4, 5):
        p = a['loop'][i]
        a['loop'][i] = com(p, hL=p['hL'] + v3(-0.4, 0, -2.6), eyes='assustado')
    return a


def deitada_encolhida(T):
    R = P(T)
    curl = dict(lean=30, pelvis=v3(0, 0, 0),
                fL=v3(-T.leg_off, 4.6, T.hip_u - 4.6), fR=v3(T.leg_off, 4.0, T.hip_u - 5.4),
                kL=v3(0, 1, 0.6), kR=v3(0, 1, 0.6),
                hL=v3(-2.4, 6.0, T.hip_u + 1.2), hR=v3(2.4, 6.4, T.hip_u + 0.4),
                eL=v3(-1, -0.4, 0), eR=v3(1, -0.4, 0), hdL=v3(1, 0.3, -0.3), hdR=v3(-1, 0.3, -0.3),
                head=v3(0, 0.5, -1.0), eyes='fechado', mouth='neutro')
    deit = P(T, deitar=1.0, **curl)
    agach = P(T, pelvis=v3(0, -1.0, -(T.hip_u - 7)), fL=v3(-T.leg_off, 3.0, T.ankle_u), fR=v3(T.leg_off, 3.0, T.ankle_u),
              kL=v3(0, 1, 0.5), kR=v3(0, 1, 0.5), lean=22,
              hL=v3(-2.4, 5.5, 6.0), hR=v3(2.4, 5.5, 6.0), eL=v3(-1, -0.4, 0), eR=v3(1, -0.4, 0),
              eyes='assustado')
    meio = P(T, deitar=0.5, **curl)
    ini = fase([(0, R), (0.4, agach), (0.75, meio), (1, deit)], 6)
    loop = []
    n = 8
    for i in range(n):
        t = i / n
        br = math.sin(TAU * t)
        j = math.sin(TAU * 4 * t)
        loop.append(com(deit, shrug=0.5 * br, head=deit['head'] + v3(0, 0, 0.25 * j),
                        pelvis=v3(0, 0, 0.15 * j), eyes='fechado' if i % 4 else 'triste'))
    fim = fase([(0, deit), (0.3, com(meio, eyes='assustado')), (0.65, com(agach, eyes='neutro')), (1, R)], 6)
    return anim(ini, loop, fim, 9)


def chorando_tampando_olhos(T):
    R = P(T)
    y = face_u(T, T.eye_y, 5.4) - 2.2
    tampa = P(T, hL=v3(-3.4, 5.4, y), hR=v3(3.4, 5.4, y), eL=v3(-1, -0.4, -1), eR=v3(1, -0.4, -1),
              hdL=v3(0.1, 0.2, 1), hdR=v3(-0.1, 0.2, 1), overL='face', overR='face',
              head=v3(0, 0.6, -1.8), lean=8, shrug=1.0, stretch=1.45, eyes='fechado', mouth='aberta')
    ini = fase([(0, R), (0.5, mistura(R, com(tampa, eyes='triste', mouth='neutro'), 0.55)), (1, tampa)], 4)
    loop = []
    n = 10
    for i in range(n):
        t = i / n
        sob = max(0, math.sin(TAU * 2 * t))
        loop.append(com(tampa, shrug=1.0 + 1.0 * sob, head=tampa['head'] + v3(0, 0, -0.6 * sob),
                        pelvis=v3(0, 0, -0.3 * sob), tears=t, mouth='aberta' if sob > 0.3 else 'neutro',
                        lean=8 + 3 * sob))
    limpa = P(T, hR=v3(2.6, 4.0, face_u(T, T.eye_y, 4.0) - 2.4), eR=v3(1, -0.4, -1), hdR=v3(-0.5, 0.2, 1),
              overR='face', head=v3(0, 0.3, -0.8), lean=4, stretch=1.4, eyes='triste', mouth='neutro')
    fim = fase([(0, tampa), (0.4, limpa), (0.7, com(limpa, hR=limpa['hR'] + v3(-1.2, 0, 0.3))), (1, com(R, eyes='triste'))], 6)
    for k, p in enumerate(fim[:3]):
        fim[k] = com(p, tears=0.9 + 0.1 * k)
    return anim(ini, loop, fim, 10)


def pular_bracos_cima(T):
    R = P(T)
    cima = dict(hL=v3(-T.sh_r - 4.2, 0.6, T.sh_u + 4.6), hR=v3(T.sh_r + 4.2, 0.6, T.sh_u + 4.6),
                eL=v3(-1, -0.3, -0.5), eR=v3(1, -0.3, -0.5), hdL=v3(-0.5, 0, 1), hdR=v3(0.5, 0, 1),
                overL='always', overR='always', stretch=1.2)
    baixo = dict(hL=rest_hand(T, 'L') + v3(-0.4, -1.6, 0.8), hR=rest_hand(T, 'R') + v3(0.4, -1.6, 0.8))
    agach = P(T, pelvis=v3(0, -0.6, -2.4), lean=12, fL=v3(-T.leg_off, 0, T.ankle_u), fR=v3(T.leg_off, 0, T.ankle_u),
              eyes='riso', mouth='riso', **baixo)

    def ar(h, **kw):
        return P(T, pelvis=v3(0, 0, h), fL=v3(-T.leg_off, -0.3, T.ankle_u + h + 0.6),
                 fR=v3(T.leg_off, -0.3, T.ankle_u + h + 0.6), pdL=v3(0, 1, -0.6), pdR=v3(0, 1, -0.6),
                 eyes='riso', mouth='riso', **cima, **kw)
    estica = P(T, pelvis=v3(0, 0, 0.5), eyes='riso', mouth='riso', **cima)
    pouso = P(T, pelvis=v3(0, -0.4, -1.8), lean=8, eyes='riso', mouth='aberta',
              fL=v3(-T.leg_off, 0, T.ankle_u), fR=v3(T.leg_off, 0, T.ankle_u),
              **{k: v for k, v in cima.items() if k not in ('hL', 'hR')},
              hL=v3(-T.sh_r - 3.4, 1.0, T.sh_u + 2.4), hR=v3(T.sh_r + 3.4, 1.0, T.sh_u + 2.4))
    ini = fase([(0, R), (1, agach)], 3)
    loop = fase([(0, agach), (0.2, estica), (0.4, ar(4.5)), (0.6, ar(3.5)), (0.78, estica), (0.9, pouso)], 10, True)
    fim = fase([(0, agach), (0.5, com(agach, pelvis=v3(0, -0.3, -1.0), lean=6)), (1, com(R, eyes='feliz', mouth='aberta'))], 4)
    return anim(ini, loop, fim, 12)


def andar_caixa(T):
    R = P(T)
    bw = OBJ['presente']['frente'].shape[1] / 2 + 0.2
    fwd = T.arm * 0.62
    u = T.sh_u - 5.2

    def segura(extra):
        return dict(hL=v3(-bw, fwd, u) + extra, hR=v3(bw, fwd, u) + extra, eL=v3(-1, -0.5, -0.4), eR=v3(1, -0.5, -0.4),
                    hdL=v3(0.6, 0.3, 0.2), hdR=v3(-0.6, 0.3, 0.2), props=caixa_presente, stretch=1.25)
    loop = []
    n = 12
    for i in range(n):
        ph = i / n
        w = passo(T, ph, braco=False)
        loop.append(P(T, **w, **segura(v3(0, 0, w['pelvis'][2] * 0.8)), eyes='feliz'))
    # pega do chao / deixa no chao
    chao_u = 4.6
    agach = P(T, pelvis=v3(0, -1.2, -(T.hip_u - 8.5)), lean=26, fL=v3(-T.leg_off, 1.2, T.ankle_u),
              fR=v3(T.leg_off, 1.2, T.ankle_u), kL=v3(0, 1, 0.4), kR=v3(0, 1, 0.4),
              **segura(v3(0, 1.8, chao_u - u)))
    pe = P(T, **segura(v3(0, 0, 0)), eyes='feliz')
    ini = fase([(0, agach), (0.5, com(agach, pelvis=agach['pelvis'] + v3(0, 0.5, 1.5), lean=20)), (1, pe)], 5)
    fim = fase([(0, pe), (0.5, com(agach, pelvis=agach['pelvis'] + v3(0, 0.5, 1.5), lean=20)), (0.75, agach),
                (1, com(R, props=lambda J, T_, p: caixa_chao(J, T_, p, (agach,))))], 6)
    # no ultimo quadro a caixa fica no chao
    return anim(ini, loop, fim, 12)


def caixa_chao(J, T, p, ref):
    bw = OBJ['presente']['frente'].shape[1] / 2 + 0.2
    c = v3(0, T.arm * 0.62 + 2.2, OBJ['presente']['frente'].shape[0] / 2 / 1.0 - 0.5)
    return [prop_sprite('presente', c, zoff=-1.6)]


def andar_balao(T):
    R = P(T)
    hold = v3(T.sh_r + 1.6, 1.4, T.sh_u - T.arm * 0.45)
    loop = []
    n = 12
    for i in range(n):
        ph = i / n
        w = passo(T, ph)
        loop.append(P(T, **{k: v for k, v in w.items() if k != 'hR'}, hR=hold + v3(0, 0, w['pelvis'][2] * 0.6),
                      eR=v3(1, -0.4, -0.6), hdR=v3(0, 0.2, 1), props=balao, a1=0.6 * math.sin(TAU * ph),
                      eyes='feliz'))
    parado = P(T, hR=hold, eR=v3(1, -0.4, -0.6), hdR=v3(0, 0.2, 1), props=balao, eyes='feliz')
    ini = []
    for i in range(4):
        k = (i + 1) / 5
        w = passo(T, 0.75 + i / 16, stride=2.6 * k, lift=1.6 * k)
        ini.append(com(parado, **{kk: v for kk, v in w.items() if kk != 'hR'}, a1=-0.3 * k))
    fim = []
    for i in range(4):
        k = 1 - (i + 1) / 5
        w = passo(T, i / 16, stride=2.6 * k, lift=1.6 * k)
        fim.append(com(parado, **{kk: v for kk, v in w.items() if kk != 'hR'}, a1=0.4 * k))
    fim.append(com(parado, a1=-0.2))
    return anim(ini, loop, fim, 12)


# ------------------------------------------------------------------ funcionarios

def _sentar_cadeira(T):
    seat = T.shin + T.ankle_u - 0.4
    du = seat + 1.6 - T.hip_u
    return dict(pelvis=v3(0, -2.0, du), fL=v3(-T.leg_off - 0.3, T.thigh - 1.2, T.ankle_u),
                fR=v3(T.leg_off + 0.3, T.thigh - 1.2, T.ankle_u), kL=v3(0, 1, 0.3), kR=v3(0, 1, 0.3)), du


def _transicao_sentar(T, sent, final, n_ini=6, n_fim=6):
    R = P(T)
    meio = P(T, pelvis=v3(0, -1.0, sent['pelvis'][2] * 0.55), lean=16,
             fL=v3(-T.leg_off, 2.0, T.ankle_u), fR=v3(T.leg_off, 2.0, T.ankle_u), kL=v3(0, 1, 0.3), kR=v3(0, 1, 0.3),
             hL=rest_hand(T, 'L') + v3(0, 1.5, sent['pelvis'][2] * 0.5), hR=rest_hand(T, 'R') + v3(0, 1.5, sent['pelvis'][2] * 0.5),
             props=final.get('props'))
    ini = fase([(0, R), (0.35, meio), (0.65, com(sent, props=final.get('props'))), (1, final)], n_ini)
    fim = fase([(0, final), (0.35, com(sent, props=final.get('props'))), (0.7, meio), (1, com(R, props=final.get('props')))], n_fim)
    return ini, fim


def livro(J, T, p):
    c = (J['WL'] + J['WR']) / 2 + v3(0, 1.4, 1.2)
    s = v3(0, -0.5, 0.86)        # lombada
    n = v3(0, 0.86, 0.5)         # normal da pagina (para o rosto)
    r = v3(1, 0, 0)
    h = 3.0
    larg = 4.2
    ab = p['a2']                 # 0 fechado .. 1 aberto
    out = []
    ang = math.radians(90 * (1 - ab))
    for lado in (-1, 1):
        dirp = r * lado * math.cos(ang) + n * math.sin(ang)
        cap = [c + s * h - n * 0.2, c - s * h - n * 0.2,
               c - s * h + dirp * (larg + 0.3) - n * 0.2, c + s * h + dirp * (larg + 0.3) - n * 0.2]
        out.append(dict(t='poly', pts=cap, rgb=(64, 92, 150), g='capa%d' % lado))
        pag = [c + s * (h - 0.4), c - s * (h - 0.4), c - s * (h - 0.4) + dirp * larg, c + s * (h - 0.4) + dirp * larg]
        out.append(dict(t='poly', pts=[x + n * 0.15 for x in pag], rgb=(240, 234, 214), g='pag%d' % lado))
    if p['a1'] > 0:               # pagina virando
        th = math.radians(180 * p['a1'])
        dirp = r * math.cos(th) + n * math.sin(th) * 1.0
        pag = [c + s * (h - 0.5), c - s * (h - 0.5), c - s * (h - 0.5) + dirp * larg, c + s * (h - 0.5) + dirp * larg]
        out.append(dict(t='poly', pts=[x + n * 0.4 for x in pag], rgb=(252, 248, 232), g='virando'))
    return out


def estudar(T):
    sent, du = _sentar_cadeira(T)
    maos = dict(hL=v3(-2.8, T.arm * 0.62, T.sh_u + du - 4.2), hR=v3(2.8, T.arm * 0.62, T.sh_u + du - 4.2),
                eL=v3(-1, -0.4, -0.8), eR=v3(1, -0.4, -0.8), hdL=v3(0.5, 0.6, 0.3), hdR=v3(-0.5, 0.6, 0.3))
    base = P(T, **sent, **maos, props=livro, a2=1.0, lean=4, head=v3(0, 0.3, -0.6))
    loop = []
    n = 16
    for i in range(n):
        t = i / n
        q = com(base, head=base['head'] + v3(0, 0, -0.3 * max(0, math.sin(TAU * 2 * t))))
        if 10 <= i <= 13:
            k = (i - 9) / 5
            q = com(q, a1=k, hR=maos['hR'] + v3(-4.5 * k, 0.4, 0.8 * math.sin(math.pi * k)))
        if i == 7:
            q = com(q, eyes='fechado')
        loop.append(q)
    fechado = com(base, a2=0.0)
    ini, fim = _transicao_sentar(T, P(T, **sent), fechado)
    ini = ini + [com(base, a2=0.5), base]
    fim = [com(base, a2=0.5), fechado] + fim
    return anim(ini, loop, fim, 8)


def chave_fenda(J, T, p):
    w = mao(J, 'R', 0.5)
    d = J['HdR']
    ang = p['a1']
    return [dict(t='cap', a=w - d * 1.0, b=w + d * 1.3, r=0.9, rgb=(196, 56, 44), g='cabo'),
            dict(t='cap', a=w + d * 1.3, b=w + d * 4.4, r=0.42, rgb=(178, 184, 190), g='haste')] + _peca(J, T, p)


def martelo(J, T, p):
    w = mao(J, 'R', 0.4)
    d = J['HdR']
    side = np.cross(d, v3(1, 0, 0))
    if np.linalg.norm(side) < 1e-3:
        side = v3(0, 1, 0)
    side = side / np.linalg.norm(side)
    top = w + d * 4.6
    return [dict(t='cap', a=w - d * 0.8, b=top, r=0.55, rgb=(146, 98, 58), g='cabo'),
            dict(t='cap', a=top - side * 1.4, b=top + side * 1.4, r=1.0, rgb=(92, 96, 104), g='cabeca')] + _peca(J, T, p)


def fita(J, T, p):
    wl = mao(J, 'L', 0.6)
    wr = mao(J, 'R', 0.5)
    rc = wl + v3(0.4, 1.3, 1.6)
    out = [dict(t='disc', c=rc, r=2.4, a1=v3(1, 0, 0), a2=v3(0, 0, 1), rgb=(206, 208, 214), g='rolo'),
           dict(t='disc', c=rc + v3(0, 0.1, 0), r=1.0, a1=v3(1, 0, 0), a2=v3(0, 0, 1), rgb=(110, 102, 92), g='furo')]
    if p['a2'] > 0.05:
        a = rc + v3(0, 0.2, -2.0)
        b = wr if p['a3'] < 0.5 else a + (wr - a) * 1.0
        nn = v3(0, 0, 0.45)
        out.append(dict(t='poly', pts=[a - nn, b - nn, b + nn, a + nn], rgb=(214, 198, 150), g='tira'))
    return out + _peca(J, T, p)


def _peca(J, T, p):
    # pecinha do animatronico apoiada na bancada (referencia para as ferramentas)
    return []


def consertar(T, ferramenta):
    R = P(T)
    u = T.hip_u + 2.2
    f = T.arm * 0.82
    base = dict(lean=16, fL=v3(-T.leg_off - 0.5, -0.4, T.ankle_u), fR=v3(T.leg_off + 0.5, 0.2, T.ankle_u),
                hL=v3(-2.2, f, u), eL=v3(-1, -0.3, -0.5), hdL=v3(0.3, 1, -0.6),
                eR=v3(1, -0.3, -0.5), head=v3(0, 0.5, -0.4))
    loop = []
    if ferramenta == 'chave_fenda':
        props = chave_fenda
        n = 8
        for i in range(n):
            t = i / n
            tw = math.sin(TAU * 2 * t)
            hd = v3(0.35 * tw, 0.55, -0.8)
            loop.append(P(T, **base, hR=v3(1.6 + 0.3 * tw, f - 0.2, u + 2.6 + 0.2 * abs(tw)), hdR=hd, props=props,
                          mouth='neutro' if i % 4 else 'mastiga'))
        segura = loop[0]
    elif ferramenta == 'martelo':
        props = martelo
        alto = P(T, **base, hR=v3(2.4, f - 2.2, u + 6.0), hdR=v3(0, 0.6, 0.8), props=props, eyes='neutro')
        bate = P(T, **base, hR=v3(2.0, f + 0.2, u + 1.2), hdR=v3(0, 0.9, -0.5), props=props, eyes='fechado', mouth='mastiga')
        meio = mistura(alto, bate, 0.5)
        loop = fase([(0, bate), (0.12, com(bate, hR=bate['hR'] + v3(0, -0.3, 1.2))), (0.55, alto), (0.85, meio)], 8, True)
        segura = alto
    else:
        props = fita
        a0 = P(T, **{**base, **dict(hL=v3(-2.6, f, u + 1.6), hdL=v3(0.3, 1, 0), hR=v3(-1.0, f + 0.3, u + 1.4),
               hdR=v3(-0.5, 1, 0), props=props, a2=0.0)})
        a1 = com(a0, hR=v3(3.8, f, u + 1.0), a2=1.0)
        a2 = com(a1, hR=v3(3.4, f + 0.6, u + 0.2), a2=1.0, mouth='mastiga')
        a3 = com(a2, hR=v3(1.4, f + 0.8, u - 0.2), a2=0.0, eyes='fechado')
        loop = fase([(0, a0), (0.3, a1), (0.5, a2), (0.7, a3), (0.85, com(a3, eyes='neutro'))], 10, True)
        segura = a0
    ini = fase([(0, com(R, props=props)), (0.5, mistura(com(R, props=props), segura, 0.5)), (1, loop[0])], 4)
    fim = fase([(0, loop[0]), (0.5, mistura(com(R, props=props), segura, 0.5)), (1, com(R, props=props))], 4)
    return anim(ini, loop, fim, 10)


def panela(J, T, p):
    wl = mao(J, 'L', 0.6)
    fwd = v3(0, 1, 0)
    c = wl + v3(1.8, 4.2, 0.4)
    out = [dict(t='cap', a=wl - fwd * 0.4, b=c - fwd * 2.6, r=0.5, rgb=(54, 52, 56), g='cabo'),
           dict(t='disc', c=c, r=4.0, r2=3.4, rgb=(70, 70, 76), g='panela'),
           dict(t='disc', c=c + v3(0, 0.3, 0.5 + p['a3']), r=2.8, r2=2.3, rgb=(226, 160, 72), g='comida')]
    wr = mao(J, 'R', 0.4)
    d = J['HdR']
    out.append(dict(t='cap', a=wr - d * 0.6, b=wr + d * 3.4, r=0.42, rgb=(150, 104, 62), g='colher'))
    out.append(dict(t='cap', a=wr + d * 3.4, b=wr + d * 4.2, r=0.85, rgb=(176, 180, 186), g='ponta'))
    return out


def cozinhar(T):
    R = P(T)
    u = T.hip_u + 3.0
    f = T.arm * 0.7
    base = dict(lean=10, hL=v3(-3.2, f - 1.0, u), eL=v3(-1, -0.4, -0.5), hdL=v3(0, 1, 0),
                eR=v3(1, -0.4, -0.5), head=v3(0, 0.4, -0.4), props=panela)
    loop = []
    n = 12
    for i in range(n):
        t = i / n
        if i < 8:
            a = TAU * t * 1.5
            hR = v3(0.2 + 1.3 * math.cos(a), f + 2.8 + 1.0 * math.sin(a), u + 4.2)
            loop.append(P(T, **base, hR=hR, hdR=v3(-0.3, 0.4, -1)))
        else:
            k = math.sin(math.pi * (i - 7) / 5)
            q = P(T, **base, hR=v3(1.6, f + 0.8, u + 1.8), hdR=v3(-0.3, 0.4, -1), a3=2.2 * k, eyes='feliz')
            q['hL'] = base['hL'] + v3(0, -0.6 * k, 1.4 * k)
            loop.append(q)
    ini = fase([(0, com(R, props=panela)), (0.5, mistura(com(R, props=panela), loop[0], 0.5)), (1, loop[0])], 4)
    fim = fase([(0, loop[0]), (0.5, mistura(com(R, props=panela), loop[0], 0.5)), (1, com(R, props=panela))], 4)
    return anim(ini, loop, fim, 10)


def prato_esponja(J, T, p):
    wl = mao(J, 'L', 0.6)
    wr = mao(J, 'R', 0.6)
    c = wl + v3(1.6, 0.8, 0.6)
    tilt = v3(0, -0.45, 0.9)
    out = [dict(t='disc', c=c, r=3.8, a1=v3(1, 0, 0), a2=tilt, rgb=(238, 238, 232), g='prato'),
           dict(t='disc', c=c + v3(0, 0.1, 0), r=2.4, a1=v3(1, 0, 0), a2=tilt, rgb=(214, 220, 222), g='centro'),
           dict(t='cap', a=wr + v3(-0.5, 0.3, 0), b=wr + v3(0.5, 0.3, 0.2), r=1.05, rgb=(236, 206, 70), g='esponja')]
    if p['a1'] > 0:
        for k in range(3):
            ph = (p['a1'] + k * 0.33) % 1.0
            out.append(dict(t='cap', a=c + v3(-1.5 + k * 1.5, 0.6, 1.0 + ph * 3), b=c + v3(-1.5 + k * 1.5, 0.6, 1.0 + ph * 3),
                            r=0.55, rgb=(236, 246, 255), g='bolha%d' % k))
    return out


def lavar_pratos(T):
    R = P(T)
    u = T.hip_u + 3.4
    f = T.arm * 0.72
    base = dict(lean=12, hL=v3(-2.6, f, u), eL=v3(-1, -0.4, -0.5), hdL=v3(0.4, 1, 0),
                eR=v3(1, -0.4, -0.5), head=v3(0, 0.4, -0.5), props=prato_esponja)
    loop = []
    n = 12
    for i in range(n):
        t = i / n
        a = TAU * t * 2
        loop.append(P(T, **base, hR=v3(0.4 + 1.0 * math.cos(a), f + 1.4, u + 1.0 + 1.0 * math.sin(a)),
                      hdR=v3(-0.4, 1, 0), a1=t))
    ini = fase([(0, com(R, props=prato_esponja)), (0.5, mistura(com(R, props=prato_esponja), loop[0], 0.5)), (1, loop[0])], 4)
    fim = fase([(0, loop[0]), (0.5, mistura(com(R, props=prato_esponja), loop[0], 0.5)), (1, com(R, props=prato_esponja))], 4)
    return anim(ini, loop, fim, 10)


def caixa_papelao(J, T, p):
    c = v3(0, 8.2, 3.2)
    hx, hy, hz = 4.0, 3.0, 3.2
    cor = (192, 142, 86)
    esc = (112, 76, 46)

    def pt(x, y, z):
        return c + v3(x, y, z)
    out = []
    fc = [((-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1)),  # tras
          ((-1, 1, -1), (1, 1, -1), (1, 1, 1), (-1, 1, 1)),      # frente
          ((-1, -1, -1), (-1, 1, -1), (-1, 1, 1), (-1, -1, 1)),  # esq
          ((1, -1, -1), (1, 1, -1), (1, 1, 1), (1, -1, 1))]      # dir
    for k, f in enumerate(fc):
        out.append(dict(t='poly', pts=[pt(a * hx, b * hy, cc * hz) for a, b, cc in f], rgb=cor, g='lado%d' % k))
    ab = p['a2']   # abas: 0 fechada, 1 aberta
    topo = [pt(-hx, -hy, hz - 0.1), pt(hx, -hy, hz - 0.1), pt(hx, hy, hz - 0.1), pt(-hx, hy, hz - 0.1)]
    out.append(dict(t='poly', pts=topo, rgb=esc if ab > 0.3 else cor, g='topo'))
    if ab > 0.05:
        ang = math.radians(100 * ab)
        for lado in (-1, 1):  # abas laterais
            ax = lado * hx
            dvec = v3(lado * math.sin(ang), 0, math.cos(ang)) * hx * 0.9
            pts = [pt(ax, -hy, hz), pt(ax, hy, hz)]
            pts += [pts[1] - v3(lado * hx, 0, 0) * (1 - ab) * 0 + dvec, pts[0] + dvec]
            out.append(dict(t='poly', pts=pts, rgb=(206, 158, 100), g='aba%d' % lado))
    if p['a3'] > 0:   # item retirado
        w = (J['WL'] + J['WR']) / 2 + v3(0, 0.6, 0.6)
        out.append(dict(t='cap', a=w - v3(1.3, 0, 0), b=w + v3(1.3, 0, 0), r=1.5, rgb=(84, 140, 196), g='item'))
    return out


def desempacotar_caixa(T):
    R = P(T)
    agach = dict(pelvis=v3(0, -1.6, -(T.hip_u - 9.0)), lean=34, fL=v3(-T.leg_off - 0.4, 1.4, T.ankle_u),
                 fR=v3(T.leg_off + 0.4, 1.4, T.ankle_u), kL=v3(0, 1, 0.3), kR=v3(0, 1, 0.3),
                 eL=v3(-1, -0.4, -0.3), eR=v3(1, -0.4, -0.3), props=caixa_papelao, head=v3(0, 0.5, -0.4))
    topo_u = 6.6
    abre0 = P(T, **agach, hL=v3(-3.0, 7.6, topo_u + 0.2), hR=v3(3.0, 7.6, topo_u + 0.2), a2=0.0)
    abre1 = P(T, **agach, hL=v3(-4.6, 7.8, topo_u + 1.8), hR=v3(4.6, 7.8, topo_u + 1.8), a2=1.0)
    dentro = P(T, **agach, hL=v3(-1.6, 8.0, topo_u - 1.4), hR=v3(1.6, 8.0, topo_u - 1.4), a2=1.0)
    pega = com(dentro, a3=1.0)
    olha = P(T, **{k: v for k, v in agach.items() if k not in ('lean', 'pelvis')}, lean=14,
             pelvis=agach['pelvis'] + v3(0, 0.6, 1.4),
             hL=v3(-1.6, T.arm * 0.7, T.sh_u - 4.0 + agach['pelvis'][2] + 1.4),
             hR=v3(1.6, T.arm * 0.7, T.sh_u - 4.0 + agach['pelvis'][2] + 1.4), a2=1.0, a3=1.0, eyes='feliz')
    poe = P(T, **agach, hL=v3(-6.2, 4.4, 3.6), hR=v3(-3.0, 4.6, 3.6), a2=1.0, a3=1.0, yaw=-25)
    solta = com(poe, a3=0.0)
    ini = fase([(0, com(R, props=caixa_papelao)), (0.4, com(abre0, hL=abre0['hL'] + v3(0, 0, 2), hR=abre0['hR'] + v3(0, 0, 2))),
                (0.65, abre0), (1, abre1)], 6)
    loop = fase([(0, abre1), (0.15, dentro), (0.27, pega), (0.5, olha), (0.62, olha), (0.82, poe), (0.9, solta)], 14, True)
    fim = fase([(0, abre1), (0.4, abre0), (0.7, com(abre0, hL=abre0['hL'] + v3(0, 0, 2), hR=abre0['hR'] + v3(0, 0, 2))),
                (1, com(R, props=caixa_papelao))], 6)
    return anim(ini, loop, fim, 9)


def nota(J, T, p):
    if p['a1'] < 0.5:
        return []
    w = mao(J, 'R', 0.9)
    return [dict(t='poly', pts=[w + v3(-1.6, 0, -0.2), w + v3(1.6, 0, -0.2), w + v3(1.6, 0.5, 1.1), w + v3(-1.6, 0.5, 1.1)],
                 rgb=(118, 172, 104), g='nota')]


def mexer_caixa(T):
    R = P(T)
    u = T.hip_u + 3.0
    f = T.arm * 0.78
    base = dict(lean=9, eL=v3(-1, -0.4, -0.6), eR=v3(1, -0.4, -0.6), hdL=v3(0, 0.6, -0.8), hdR=v3(0, 0.6, -0.8),
                head=v3(0, 0.3, -0.5), props=nota)
    loop = []
    n = 14
    for i in range(n):
        if i < 8:
            bl = 0.8 if i % 2 == 0 else 0.0
            br = 0.0 if i % 2 == 0 else 0.8
            loop.append(P(T, **base, hL=v3(-1.8 + 0.4 * (i % 3), f, u - bl), hR=v3(1.8 - 0.3 * (i % 2), f + 0.4, u - br)))
        else:
            k = math.sin(math.pi * (i - 7) / 7)
            loop.append(P(T, **base, hL=v3(-1.8, f, u), hR=v3(1.8 + 0.8 * k, f + 1.6 * k, u - 2.4 * k + 2.4 * k * (i >= 11)),
                          a1=1.0 if i >= 10 else 0.0, eyes='feliz' if i >= 10 else 'neutro',
                          mouth='aberta' if i in (11, 12) else 'neutro', hturn=0))
    ini = fase([(0, com(R, props=nota)), (0.5, mistura(com(R, props=nota), loop[0], 0.5)), (1, loop[0])], 4)
    fim = fase([(0, loop[0]), (0.5, mistura(com(R, props=nota), loop[0], 0.5)), (1, com(R, props=nota))], 4)
    return anim(ini, loop, fim, 10)


def sentado_ibm(T):
    sent, du = _sentar_cadeira(T)
    u = T.sh_u + du - 5.0
    f = T.arm * 0.85
    base = dict(**sent, lean=6, eL=v3(-1, -0.4, -0.5), eR=v3(1, -0.4, -0.5), hdL=v3(0, 0.6, -0.8),
                hdR=v3(0, 0.6, -0.8), head=v3(0, 0.3, 0))
    loop = []
    n = 12
    for i in range(n):
        if i < 9:
            bl = 0.7 if i % 2 == 0 else 0.0
            br = 0.0 if i % 2 == 0 else 0.7
            loop.append(P(T, **base, hL=v3(-2.0 + 0.3 * (i % 3), f, u - bl), hR=v3(2.0 - 0.3 * (i % 2), f, u - br)))
        else:
            loop.append(P(T, **{**base, **dict(hL=v3(-2.0, f, u), hR=v3(3.4, f - 0.6, u - 0.4),
                          head=v3(0, 0.6, -0.3), eyes='fechado' if i == 10 else 'neutro')}))
    ini, fim = _transicao_sentar(T, P(T, **sent), loop[0])
    return anim(ini, loop, fim, 10)


# ================================================================== catalogo

CATALOGO = {
    'adolescentes': (['adolescente_masculino', 'adolescente_feminino'], [
        ('jogar_fliperama', 'Jogando nos fliperamas', jogar_fliperama),
        ('bater_palmas', 'Batendo palmas', bater_palmas),
        ('apontar_rindo', 'Apontando e rindo', apontar_rindo),
        ('conversar_1', 'Conversando com outros 1', lambda T: conversar(T, 1)),
        ('conversar_2', 'Conversando com outros 2', lambda T: conversar(T, 2)),
        ('conversar_3', 'Conversando com outros 3', lambda T: conversar(T, 3)),
        ('conversar_4', 'Conversando com outros 4', lambda T: conversar(T, 4)),
        ('comer_pizza', 'Comendo pizza', comer_pizza),
        ('comer_bolo', 'Comendo bolo', comer_bolo),
    ]),
    'criancas': (['crianca'], [
        ('correr_fugindo', 'Correndo do pique-pega', lambda T: correr(T, False)),
        ('correr_pegador', 'Corredor que tenta pegar', lambda T: correr(T, True)),
        ('sentada_mao_boca', 'Sentada com a mao na boca', sentada_mao_boca),
        ('sentada_maos_orelhas', 'Sentada com as maos nas orelhas', sentada_maos_orelhas),
        ('sentada_tampando_olhos', 'Sentada tampando os olhos', sentada_tampando_olhos),
        ('deitada_encolhida', 'Deitada encolhida abracando as pernas', deitada_encolhida),
        ('em_pe_chorando', 'Em pe tampando os olhos, chorando', chorando_tampando_olhos),
        ('pular_bracos_cima', 'Pulando com os bracos para cima', pular_bracos_cima),
        ('rindo_mao_barriga', 'Com a mao na barriga rindo', lambda T: rindo(T, True)),
        ('bater_palmas', 'Batendo palmas', bater_palmas),
        ('andar_caixa_presente', 'Andando com caixa de presente', andar_caixa),
        ('andar_balao', 'Andando segurando um balao', andar_balao),
        ('comer_pizza', 'Comendo pizza', comer_pizza),
        ('comer_bolo', 'Comendo bolo', comer_bolo),
    ]),
    'adultos_npc': (['adulto_masculino', 'adulto_feminino'], [
        ('bater_palmas', 'Batendo palmas', bater_palmas),
        ('rindo', 'Rindo', lambda T: rindo(T, False)),
        ('comer_pizza', 'Comendo pizza', comer_pizza),
        ('comer_bolo', 'Comendo bolo', comer_bolo),
    ]),
    'funcionarios': (['adulto_masculino', 'adulto_feminino'], [
        ('estudar', 'Estudando (sentado, lendo)', estudar),
        ('consertar_chave_fenda', 'Consertando animatronico - chave de fenda', lambda T: consertar(T, 'chave_fenda')),
        ('consertar_martelo', 'Consertando animatronico - martelo', lambda T: consertar(T, 'martelo')),
        ('consertar_fita', 'Consertando animatronico - fita adesiva', lambda T: consertar(T, 'fita')),
        ('cozinhar', 'Cozinhando', cozinhar),
        ('lavar_pratos', 'Limpando os pratos', lavar_pratos),
        ('desempacotar_caixa', 'Desempacotando uma caixa', desempacotar_caixa),
        ('mexer_caixa', 'Mexendo no caixa', mexer_caixa),
        ('sentado_ibm', 'Sentado mexendo no IBM', sentado_ibm),
    ]),
}
