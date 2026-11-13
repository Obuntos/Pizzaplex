"""Humano adulto sendo morto pelo Orelhitas + corpo no chao.

Mesma linha do tempo do matar.js (12 quadros/s): comeco 15 quadros, loop 18, fim 24.
Tela maior que a do molde (o corpo caido nao cabe em 48x60): 112 x 88, com os pes em (56, 61).
"""
import math
import numpy as np

import motor as M
import personagem as P
from motor import v3
from personagem import pose_base, mistura, suave

TAU = 2 * math.pi
QW, QH, QX, QY = 112, 88, 56, 61          # quadro e ponto dos pes
N_INI, N_LOOP, N_FIM = 15, 18, 24
FPS = 12
DIST = 20.0                               # distancia do humano a frente do animatronico (unidades dele)


def preparar(T):
    """Coloca o tipo na tela grande (chamar depois de P.tela(...))."""
    T.ampliar(QW, QH, QX - 24, QY - 55)


def _P(T, **kw):
    p = pose_base(T)
    p.update(kw)
    return p


def _queda(T, ang, dobra, **kw):
    """Corpo girando para tras em torno dos pes (ang em graus, 90 = deitado de costas)."""
    p = _P(T, **kw)
    if ang > 0.5:
        p['corpo_rot'] = (v3(1, 0, 0), ang, v3(0, 0, T.ankle_u))
        p['chao'] = True
        p['cabeca_rot'] = P._cabeca_deitada
    p['pelvis'] = p['pelvis'] + v3(0, -1.2 * dobra, -3.5 * dobra)
    p['kL'] = v3(0, 1, .3)
    p['kR'] = v3(0, 1, .3)
    return p


def morto(T):
    """Pose final: de costas no chao, bracos abertos, pernas um pouco afastadas."""
    return _queda(T, 90, 0.0,
                  hL=v3(-T.sh_r - 5.5, 1.5, T.sh_u - 1.5), hR=v3(T.sh_r + 4.5, -0.5, T.sh_u - 4.0),
                  eL=v3(-1, 0, -0.3), eR=v3(1, 0, -0.3), hdL=v3(-1, 0.3, 0), hdR=v3(1, 0, -0.3),
                  fL=v3(-T.leg_off - 1.6, 0.6, T.ankle_u), fR=v3(T.leg_off + 1.0, -0.4, T.ankle_u + 0.4),
                  pdL=v3(-.5, 1, 0), pdR=v3(.4, 1, 0))


def quadros(T):
    """Lista de poses do humano (comeco + loop + fim). O humano olha PARA o animatronico."""
    R = _P(T)
    ombro = T.sh_u
    # comeco: susto (recua, bracos de defesa) -> empurra -> e agarrado e puxado
    susto = _P(T, lean=-9, pelvis=v3(0, -0.8, -0.3), fR=v3(T.leg_off, -2.6, T.ankle_u),
               hL=v3(-2.4, 4.2, ombro + 2.0), hR=v3(2.4, 4.2, ombro + 2.6), eL=v3(-1, -.3, -1), eR=v3(1, -.3, -1),
               hdL=v3(0, .4, 1), hdR=v3(0, .4, 1))
    empurra = _P(T, lean=-4, pelvis=v3(0, -0.6, -0.2), fR=v3(T.leg_off, -2.0, T.ankle_u),
                 hL=v3(-2.8, 6.4, ombro - 0.5), hR=v3(2.8, 6.4, ombro - 0.5), eL=v3(-1, -.4, -.6), eR=v3(1, -.4, -.6),
                 hdL=v3(0, 1, .4), hdR=v3(0, 1, .4))
    agarrado = _P(T, lean=7, pelvis=v3(0, 0.6, 0.6), fL=v3(-T.leg_off, 0.4, T.ankle_u + 0.4),
                  fR=v3(T.leg_off, -0.6, T.ankle_u + 0.2),
                  hL=v3(-T.sh_r - 0.6, 2.4, ombro + 1.2), hR=v3(T.sh_r + 0.6, 2.4, ombro + 1.2),
                  eL=v3(-1, -.5, -.4), eR=v3(1, -.5, -.4), hdL=v3(.3, 1, .6), hdR=v3(-.3, 1, .6))
    ini = []
    keys = [(0, R), (0.22, susto), (0.5, susto), (0.72, empurra), (1.0, agarrado)]
    for i in range(N_INI):
        t = (i + 1) / N_INI
        ini.append(_amostra(keys, t))
    # loop: erguido pelos ombros e sacudido; as pernas chutam, as maos seguram os pulsos dele
    loop = []
    for i in range(N_LOOP):
        t = i / N_LOOP
        sac = math.sin(TAU * 3 * t)            # 3 sacudidas por volta (casam com o animatronico)
        lift = 2.9 + 0.5 * max(0, sac)
        ch = math.sin(TAU * 2 * t)
        loop.append(_P(T, lean=6 + 3 * sac, roll=4 * math.sin(TAU * 3 * t + .8), pelvis=v3(0, 0.6, lift),
                       fL=v3(-T.leg_off, 1.6 * ch + 0.4, T.ankle_u + lift + 1.0 + max(0, ch) * 1.6),
                       fR=v3(T.leg_off, -1.6 * ch + 0.4, T.ankle_u + lift + 1.0 + max(0, -ch) * 1.6),
                       pdL=v3(0, .5, -1), pdR=v3(0, .5, -1),
                       hL=v3(-T.sh_r - 0.6, 2.4 + 0.5 * sac, ombro + lift + 1.0), hR=v3(T.sh_r + 0.6, 2.4 - 0.5 * sac, ombro + lift + 1.0),
                       eL=v3(-1, -.5, -.4), eR=v3(1, -.5, -.4), hdL=v3(.3, 1, .6), hdR=v3(-.3, 1, .6),
                       head=v3(0.3 * sac, -0.5, -0.4)))
    # fim: solto -> os joelhos cedem -> cai de costas -> quica -> parado no chao
    solto = _P(T, lean=2, pelvis=v3(0, 0, -0.5), hL=v3(-T.sh_r - 1, 1.2, ombro - 4), hR=v3(T.sh_r + 1, 1.2, ombro - 4),
               eL=v3(-1, -.3, -.3), eR=v3(1, -.3, -.3))
    cede = _queda(T, 0, 1.0, lean=-6, hL=v3(-T.sh_r - 2, 0.5, ombro - 3), hR=v3(T.sh_r + 2, 0.5, ombro - 3),
                  eL=v3(-1, -.3, -.3), eR=v3(1, -.3, -.3), fL=v3(-T.leg_off, 1.2, T.ankle_u), fR=v3(T.leg_off, 1.0, T.ankle_u))
    fim = []
    dead = morto(T)
    for i in range(N_FIM):
        if i < 3:
            fim.append(mistura(loop[0], solto, suave((i + 1) / 3)))
        elif i < 6:
            fim.append(mistura(solto, cede, suave((i - 2) / 3)))
        elif i < 13:
            u = (i - 5) / 7.0
            ang = 90 * u * u                    # acelera ao cair
            q = _queda(T, ang, 1.0 - u * 0.8, lean=-6 - 10 * u,
                       hL=v3(-T.sh_r - 2 - 3 * u, 0.5 + u, ombro - 3 + 2 * u), hR=v3(T.sh_r + 2 + 3 * u, 0.5, ombro - 3 + 1.5 * u),
                       eL=v3(-1, -.3, -.3), eR=v3(1, -.3, -.3),
                       fL=v3(-T.leg_off - u, 1.2 - u, T.ankle_u), fR=v3(T.leg_off + u * .6, 1.0 - u, T.ankle_u))
            fim.append(q)
        elif i < 16:
            ang = [84, 88, 90][i - 13]           # quica de leve ao bater no chao
            q = mistura(fim[-1], dead, 0.6 if i == 13 else 1.0)
            q = dict(q)
            q['corpo_rot'] = (v3(1, 0, 0), ang, v3(0, 0, T.ankle_u))
            fim.append(q)
        else:
            q = dict(dead)
            if i == 19:                          # ultimo espasmo da mao
                q['hR'] = q['hR'] + v3(0, 0, 1.2)
            fim.append(q)
    return ini, loop, fim


def _amostra(keys, t):
    for (t0, p0), (t1, p1) in zip(keys, keys[1:]):
        if t0 <= t <= t1:
            return mistura(p0, p1, suave((t - t0) / max(1e-9, t1 - t0)))
    return keys[-1][1]
