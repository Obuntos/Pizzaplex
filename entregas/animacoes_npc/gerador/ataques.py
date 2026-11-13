"""Ataques do Orelhitas ao adulto: um por versao, cada um com o proprio corpo no chao.

  normal       Orelhitas ............ enforca: ergue pelo pescoco, a vitima esperneia, fica mole e cai
  toy          Toy Orelhitas ........ arranca o braco: puxa ate arrancar, olha o braco e larga no chao
  quebrado     Orelhitas Quebrado ... abre a barriga: segura pelo ombro e rasga a barriga; a vitima cai de barriga aberta
  toyquebrado  Toy Orelhitas Quebrado come o rosto: segura a cabeca e morde; o corpo cai sem rosto

Tudo e calculado aqui, quadro a quadro: a pose do humano e, a partir das juntas DELE, onde ficam as maos do
animatronico (convertidas para os canais do Orelhitas_Poses e desenhadas pelo matar.js). Assim as maos ficam
sempre em cima do pescoco, do braco, da barriga ou da cabeca, em qualquer direcao.

Unidades: humano em "unidades do molde" (1 = 1,375 px do jogo); animatronico em unidades do Orelhitas
(1 = 1,2 px do jogo na horizontal e 1 px na vertical).
"""
import math
import numpy as np

import motor as M
import personagem as P
from motor import v3
from personagem import pose_base, mistura

TAU = 2 * math.pi
FPS = 12
QW, QH, QX, QY = 112, 110, 56, 80        # quadro do humano e ponto dos pes
C = 1.375 / 1.2                          # 1 unidade do humano em unidades horizontais do animatronico
ZH = 1.375                               # 1 unidade do humano em unidades verticais do animatronico
# esqueleto do Orelhitas (endocoelho.js)
WX, WZ, SX_, SZ_, ALC = 15.6, 27.0, 12.2, 46.6, 21.2
KLEAN = ((SZ_ - 23.1) / 30) ** 2
REPOUSO = dict(arms=[2.6, 2.6], armLift=[-3.0, -3.0], armOut=[1.4, 1.4], handGrip=[0.3, 0.3])
SANGUE = [(66, 8, 16), (110, 16, 28), (158, 34, 46)]


# ------------------------------------------------------------------ curvas de cada versao

def _sm(u):
    u = min(max(u, 0.0), 1.0)
    return u * u * (3 - 2 * u)


CURVAS = {
    'normal': _sm,
    'toy': lambda u: (1.12 * _sm(u / .62) if u < .62 else 1.12 - .12 * _sm((u - .62) / .38)) if u > 0 else 0.0,
    'quebrado': lambda u: math.ceil(_sm(u) * 3 - 1e-6) / 3,
    'toyquebrado': lambda u: math.ceil(_sm(u) * 4 - 1e-6) / 4,
}


def _lerp_dict(a, b, t):
    out = dict(a)
    for k, vb in b.items():
        va = a.get(k, vb)
        if isinstance(vb, list):
            out[k] = [x + (y - x) * t for x, y in zip(va, vb)]
        elif isinstance(vb, (int, float)) and not isinstance(vb, bool):
            out[k] = va + (vb - va) * t
        else:
            out[k] = vb if t >= .5 else va
    return out


def chaves(keys, n, curva, ciclico=False):
    """keys: [(quadro, pose_humano, canais_animatronico, peso_maos)] -> n quadros."""
    ks = list(keys)
    if ciclico:
        ks = ks + [(n, ks[0][1], ks[0][2], ks[0][3])]
    out = []
    for i in range(n):
        for (f0, h0, a0, w0), (f1, h1, a1, w1) in zip(ks, ks[1:]):
            if f0 <= i <= f1:
                u = curva((i - f0) / max(1e-9, f1 - f0))
                uc = min(max(u, 0), 1)
                if isinstance(w0, tuple) or isinstance(w1, tuple):
                    m0 = w0 if isinstance(w0, tuple) else (None, 0.0)
                    m1 = w1 if isinstance(w1, tuple) else (None, 0.0)
                    if m0[0] == m1[0]:
                        w = (m1[0], m0[1] + (m1[1] - m0[1]) * uc)
                    else:
                        w = (m1[0], m1[1] * uc) if m1[0] else (m0[0], m0[1] * (1 - uc))
                else:
                    w = w0 + (w1 - w0) * uc
                out.append((mistura(h0, h1, u), _lerp_dict(a0, a1, u), w))
                break
        else:
            f, h, a, w = ks[-1]
            out.append((h, a, w))
    return out


# ------------------------------------------------------------------ conversoes

class Cena:
    def __init__(self, T, dist, offr):
        self.T, self.dist, self.offr = T, dist, offr

    def para_anim(self, p):
        r, f, u = p
        return (self.offr + r * C, self.dist - f * C, u * ZH)

    def para_humano(self, a):
        r, f, z = a
        return v3((r - self.offr) / C, (self.dist - f) / C, z / ZH)

    def deslocamentos(self):
        out = []
        for d in range(8):
            a = d * math.pi / 4
            out.append([round((math.cos(a) * self.offr + math.sin(a) * self.dist) * 1.2, 2),
                        round((-math.sin(a) * self.offr + math.cos(a) * self.dist) * .5, 2)])
        return out


def canais_maos(alvos, tilt):
    """alvos (2 pontos do animatronico) -> arms/armLift/armOut. O indice 0 fica do lado r negativo."""
    alvos = sorted(alvos, key=lambda q: q[0])
    k = tilt * KLEAN
    arms, lift, out = [], [], []
    for i, (r, f, z) in enumerate(alvos):
        side = -1 if i == 0 else 1
        out.append(side * r - WX)
        arms.append(f - k)
        lift.append(z - WZ)
    return dict(arms=arms, armLift=lift, armOut=out)


def misturar_maos(a, b, w):
    return {k: [x + (y - x) * w for x, y in zip(a[k], b[k])] for k in ('arms', 'armLift', 'armOut')}


# ------------------------------------------------------------------ poses do humano

def H(T, **kw):
    p = pose_base(T)
    p.update(kw)
    return p


def susto(T):
    return H(T, lean=-9, pelvis=v3(0, -0.8, -0.3), fR=v3(T.leg_off, -2.6, T.ankle_u),
             hL=v3(-2.4, 4.2, T.sh_u + 2.0), hR=v3(2.4, 4.2, T.sh_u + 2.6), eL=v3(-1, -.3, -1), eR=v3(1, -.3, -1),
             hdL=v3(0, .4, 1), hdR=v3(0, .4, 1))


def caido(T, ang, extra_rot=None, **kw):
    """Corpo girando para tras em torno dos pes (90 = de costas no chao)."""
    p = H(T, **kw)
    rots = []
    if ang > .5:
        rots.append((v3(1, 0, 0), ang, v3(0, 0, T.ankle_u)))
    if extra_rot:
        rots.append(extra_rot)
    if rots:
        p['corpo_rot'] = rots
        p['chao'] = True
        p['cabeca_rot'] = P._cabeca_deitada
    p['kL'] = v3(0, 1, .3)
    p['kR'] = v3(0, 1, .3)
    return p


def queda(T, i, n, pose_ini, morto, **kw):
    """Quadro i de n de uma queda de costas que termina na pose morto."""
    u = (i + 1) / n
    ang = 90 * u * u
    if u >= 1:
        return morto
    q = mistura(pose_ini, morto, _sm(u))
    q = dict(q)
    q.update(kw)
    q['corpo_rot'] = [(v3(1, 0, 0), ang, v3(0, 0, T.ankle_u))] if ang > .5 else None
    q['chao'] = ang > .5
    q['cabeca_rot'] = P._cabeca_deitada if ang > .5 else None
    q['pelvis'] = q['pelvis'] + v3(0, -1.0 * (1 - u), -3.0 * math.sin(math.pi * u) * .8)
    return q


def morto_base(T, **kw):
    base = dict(hL=v3(-T.sh_r - 5.5, 1.5, T.sh_u - 1.5), hR=v3(T.sh_r + 4.5, -0.5, T.sh_u - 4.0),
                eL=v3(-1, 0, -0.3), eR=v3(1, 0, -0.3), hdL=v3(-1, 0.3, 0), hdR=v3(1, 0, -0.3),
                fL=v3(-T.leg_off - 1.6, 0.6, T.ankle_u), fR=v3(T.leg_off + 1.0, -0.4, T.ankle_u + 0.4),
                pdL=v3(-.5, 1, 0), pdR=v3(.4, 1, 0))
    base.update(kw)
    return caido(T, 90, **base)


# ------------------------------------------------------------------ objetos de ferida

def _poca(c, r, r2=None):
    return dict(t='disc', c=v3(c[0], c[1], 0.15), r=r, r2=r2 or r * .8, a1=v3(1, 0, 0), a2=v3(0, 1, 0),
                rgb=SANGUE[1], g='poca', zoff=-60)


def props_ataque(J, T, p):
    out = []
    Rv, Fv, Uv = J['axes']
    if p.get('barriga', 0) > 0:
        s = p['barriga']
        c = J['P'] + Uv * 3.6 + Fv * (T.prof * 0.95)
        out.append(dict(t='disc', c=c, r=2.4 * s + .6, r2=3.2 * s + .6, a1=Rv, a2=Uv, rgb=SANGUE[2], g='barriga1'))
        out.append(dict(t='disc', c=c + Fv * .2, r=1.7 * s + .3, r2=2.4 * s + .3, a1=Rv, a2=Uv, rgb=SANGUE[0], g='barriga2'))
    for k, gotas in enumerate(p.get('gotas') or []):
        out.append(dict(t='cap', a=gotas, b=gotas + v3(0, 0, .3), r=.55, rgb=SANGUE[2], g='gota%d' % k))
    if p.get('peca') is not None:
        a, b = p['peca']                      # ombro arrancado -> punho (em unidades do humano)
        d = b - a
        L = np.linalg.norm(d) + 1e-9
        d = d / L
        mid = a + d * (L * .52)
        pele = tuple(int(x) for x in T.pele.ramp[4])
        out.append(dict(t='cap', a=a, b=mid, r=T.arm_r * 1.05, r2=T.arm_r, rgb=pele, g='peca1'))
        out.append(dict(t='cap', a=mid, b=b, r=T.arm_r, r2=T.arm_r * .95, rgb=pele, g='peca2'))
        out.append(dict(t='cap', a=b, b=b + d * T.hand_r * .6, r=T.hand_r * .85, r2=T.hand_r, rgb=pele, g='peca3'))
        out.append(dict(t='cap', a=a - d * .2, b=a + d * .25, r=T.arm_r * 1.1, rgb=SANGUE[2], g='peca_ferida'))
    for c, r in p.get('pocas') or []:
        if isinstance(c, str):              # poca embaixo de uma junta (ou da cabeca)
            if c == 'CAB':
                q = J['N'] + J['head_off'] + Uv * (T.head_cu - T.neck_u)
            else:
                q = J[c]
            c = (q[0], q[1])
        out.append(_poca(c, r))
    return out


def _com_props(p, **kw):
    q = dict(p)
    q.update(kw)
    q['props'] = props_ataque
    return q


# ------------------------------------------------------------------ 1. ORELHITAS: enforcar

def enforcar(T, curva):
    cena = Cena(T, 13.5, 0.0)

    def no_pescoco(J):
        Rv, Fv, Uv = J['axes']
        n = J['N'] + J['head_off'] + Uv * 1.4 + Fv * 1.0
        return [n - Rv * 2.8, n + Rv * 2.8]

    def ergue(L, **kw):
        base = dict(pelvis=v3(0, .3, L), fL=v3(-T.leg_off, .6, T.ankle_u + L - 1.2), fR=v3(T.leg_off, -.2, T.ankle_u + L - .8),
                    pdL=v3(0, .5, -1), pdR=v3(0, .5, -1), lean=3,
                    hL=v3(-2.3, 2.6, T.neck_u + L + 0.6), hR=v3(2.3, 2.6, T.neck_u + L + 0.6),
                    eL=v3(-1, -.4, -.5), eR=v3(1, -.4, -.5), hdL=v3(.4, 1, .3), hdR=v3(-.4, 1, .3), stretch=1.25)
        base.update(kw)
        return H(T, **base)
    R = H(T)
    A0 = dict(REPOUSO, eyeBlack=0, tilt=0, jaw=.5, footTravel=[0, 0])
    Asobe = dict(eyeBlack=1, tilt=1, jaw=1.4, footTravel=[0, 4], arms=[11, 11], armLift=[14, 14], armOut=[-5, -5], handGrip=[0, 0])
    Apega = dict(Asobe, handGrip=[1, 1], jaw=.9)
    ini = chaves([(0, R, A0, 0), (4, susto(T), Asobe, 0), (8, ergue(0, lean=6), Apega, 1), (13, ergue(8), dict(Apega, tilt=.4), 1)],
                 14, curva)
    loop = []
    for i in range(16):
        t = i / 16
        ch = math.sin(TAU * 2 * t)
        L = 14 + .6 * math.sin(TAU * t)
        h = ergue(L, roll=3 * math.sin(TAU * t), lean=2 + 2 * math.sin(TAU * 2 * t + 1),
                  fL=v3(-T.leg_off, 1.6 * ch + .5, T.ankle_u + L - .6 + max(0, ch) * 2.2),
                  fR=v3(T.leg_off, -1.6 * ch + .5, T.ankle_u + L - .6 + max(0, -ch) * 2.2),
                  head=v3(.3 * math.sin(TAU * 3 * t), 0, .3 * math.sin(TAU * 4 * t)))
        a = dict(Apega, tilt=-.6 + .3 * math.sin(TAU * t), jaw=1.0 + .5 * max(0, math.sin(TAU * 2 * t)),
                 headTilt=.05 * math.sin(TAU * 2 * t))
        loop.append((h, a, 1))
    morto = morto_base(T, hL=v3(-T.sh_r - 4.5, 2.5, T.sh_u - 2.0), hR=v3(T.sh_r + 5.0, 1.0, T.sh_u - 3.0), hturn=1)
    mole = ergue(14, lean=-2, hL=v3(-T.sh_r - .6, .8, T.sh_u + 14 - T.arm + .8), hR=v3(T.sh_r + .6, .6, T.sh_u + 14 - T.arm + .6),
                 eL=v3(-.4, -1, 0), eR=v3(.4, -1, 0), hdL=None, hdR=None,
                 fL=v3(-T.leg_off + .4, .3, T.ankle_u + 14 - .2), fR=v3(T.leg_off - .4, .4, T.ankle_u + 14 - .1),
                 head=v3(0, .8, -1.4))
    fim = chaves([(0, loop[0][0], loop[0][1], 1), (5, mole, dict(Apega, tilt=-.3, jaw=.6), 1)], 6, curva)
    cai = H(T, lean=4, pelvis=v3(0, .2, -3.5), hL=v3(-T.sh_r - 1.5, .5, T.sh_u - 6), hR=v3(T.sh_r + 1.5, .5, T.sh_u - 6),
            fL=v3(-T.leg_off, 1.2, T.ankle_u), fR=v3(T.leg_off, 1.0, T.ankle_u), head=v3(0, .8, -1.2),
            kL=v3(0, 1, .3), kR=v3(0, 1, .3))
    Asolta = dict(REPOUSO, tilt=1.5, jaw=.6, headLift=-2, headTilt=.15, footTravel=[0, 4], gazeY=.5)
    for i in range(3):                              # solta: cai em pe e os joelhos cedem
        u = (i + 1) / 3
        fim.append((mistura(mole, cai, u * u), _lerp_dict(fim[-1][1], Asolta, u), 1 - u))
    for i in range(8):
        fim.append((queda(T, i, 8, cai, morto), dict(Asolta, footTravel=[0, 4 * (1 - (i + 1) / 8)]), 0))
    while len(fim) < 24:
        fim.append((morto, dict(Asolta, footTravel=[0, 0]), 0))
    return cena, ini, loop, fim, no_pescoco, morto


# ------------------------------------------------------------------ 2. TOY: arrancar o braco

def arrancar(T, curva):
    cena = Cena(T, 17.0, 9.0)
    estado = {'peca': None}

    def no_braco(J):
        return [J['WL'] + J['HdL'] * .4, (J['WL'] * .45 + J['EL'] * .55)]

    alvo_braco = v3(-T.sh_r - 1.2, 8.6, T.sh_u - 1.0)

    def puxado(lean, st=1.15, **kw):
        base = dict(lean=lean, roll=6, pelvis=v3(.6, -.6, -.4), fL=v3(-T.leg_off, 1.4, T.ankle_u), fR=v3(T.leg_off + .6, -2.6, T.ankle_u),
                    hL=alvo_braco, eL=v3(-1, 0, -.6), hdL=v3(-.3, 1, 0),
                    hR=v3(-2.0, 4.6, T.sh_u - 1.6), eR=v3(1, -.4, -.4), hdR=v3(-.6, 1, 0), stretch=st)
        base.update(kw)
        return H(T, **base)
    R = H(T)
    A0 = dict(REPOUSO, eyeBlack=0, tilt=0, jaw=.5)
    Avai = dict(eyeBlack=1, tilt=1.2, jaw=1.2, footTravel=[0, 3], arms=[9, 9], armLift=[5, 5], armOut=[-3, -3], handGrip=[0, 0])
    Apega = dict(Avai, handGrip=[1, 1], tilt=-.5, jaw=.8)
    ini = chaves([(0, R, A0, 0), (4, susto(T), Avai, 0), (8, puxado(6, 1.1), Apega, 1), (13, puxado(-6, 1.2), dict(Apega, tilt=-1.5), 1)],
                 14, curva)
    loop = []
    for i in range(16):
        t = i / 16
        s = math.sin(TAU * 2 * t)
        h = puxado(-9 + 4 * s, 1.2 + .06 * max(0, s), roll=6 + 2 * s, head=v3(.2 * s, 0, .3 * math.sin(TAU * 4 * t)))
        a = dict(Apega, tilt=-1.8 - 1.0 * s, jaw=.9 + .5 * max(0, -s), headTilt=-.06 * s)
        loop.append((h, a, 1))
    # fim: puxao final, ARRANCA, a vitima cai sem o braco; o toy olha o braco e larga no chao
    morto = morto_base(T, sem='L', hR=v3(T.sh_r + 5.0, 1.0, T.sh_u - 3.0))
    fim = chaves([(0, loop[0][0], loop[0][1], 1), (3, puxado(-14, 1.38, roll=9), dict(Apega, tilt=-3.2, jaw=1.9), 1)], 4, curva)
    J = P.esqueleto(T, fim[-1][0])
    estado['peca0'] = (J['SL'] + (J['EL'] - J['SL']) * .08, J['WL'])
    solto = H(T, sem='L', lean=-14, roll=4, pelvis=v3(0, -1, -.6), fR=v3(T.leg_off, -2.6, T.ankle_u), hR=v3(T.sh_r + 2, -1, T.sh_u - 2))
    alto = (v3(-1.0, 8.5, 56.0), v3(3.0, 7.0, 52.0))             # o toy ergue o braco na altura da cara (unid. dele)
    chao_a = (v3(-4.0, 9.0, 1.4), v3(4.0, 10.5, 1.4))
    for i in range(20):
        n = len(fim)
        u_q = min(1, (i + 1) / 9)
        h = queda(T, min(i, 8), 9, solto, morto) if i < 9 else morto
        # onde esta o braco (unidades do animatronico): sobe com as maos, depois cai no chao
        p0a = cena.para_anim(estado['peca0'][1])
        p1a = cena.para_anim(estado['peca0'][0])
        if i < 8:
            u = _sm((i + 1) / 8)
            m0 = [p0a[k] + (alto[0][k] - p0a[k]) * u for k in range(3)]
            m1 = [p1a[k] + (alto[1][k] - p1a[k]) * u for k in range(3)]
            a = dict(Apega, tilt=-3 + 3 * u, jaw=1.4, headTilt=.12 * u, headLift=-1.2 * u, gazeY=.2)
            maos = canais_maos([m0, m1], a['tilt'])
        elif i < 13:
            m0, m1 = alto
            a = dict(Apega, tilt=0, jaw=1.6 if i % 2 else 1.0, headTilt=.12, headLift=-1.2, gazeY=.2)
            maos = canais_maos([m0, m1], 0)
        else:
            u = min(1, (i - 12) / 3)
            m0 = [alto[0][k] + (chao_a[0][k] - alto[0][k]) * u * u for k in range(3)]
            m1 = [alto[1][k] + (chao_a[1][k] - alto[1][k]) * u * u for k in range(3)]
            w = max(0, 1 - (i - 12) / 2)
            a = dict(REPOUSO, eyeBlack=1, tilt=1.2, jaw=.7, headTilt=.2, headLift=-2, gazeY=.6, footTravel=[0, 3 * (1 - u)])
            maos = misturar_maos(dict(REPOUSO), canais_maos([alto[0], alto[1]], 0), w)
            a['handGrip'] = [w, w]
        a.update(maos)
        peca = (cena.para_humano(m1), cena.para_humano(m0))
        gotas = []
        if i < 7:
            Jh = P.esqueleto(T, h)
            for k in range(3):
                gotas.append(Jh['SL'] + v3(-.6 - k * .5 * (i + 1) / 3, .4 * k, -.3 * (i + 1) * (k + 1) * .5))
        hp = _com_props(h, peca=peca, gotas=gotas,
                        pocas=[] if i < 10 else [('SL', 3.5 * min(1, (i - 9) / 5) + 1)])
        fim.append((hp, a, -1))
    poca_final = [('SL', 4.5)]
    ultimo_peca = fim[-1][0]['peca']
    meio = ((ultimo_peca[0][0] + ultimo_peca[1][0]) / 2, (ultimo_peca[0][1] + ultimo_peca[1][1]) / 2)
    morto = _com_props(morto, peca=ultimo_peca, pocas=poca_final + [(meio, 2.2)])
    fim[-1] = (morto, fim[-1][1], -1)
    return cena, ini, loop, fim, no_braco, morto


# ------------------------------------------------------------------ 3. QUEBRADO: abrir a barriga

def barriga(T, curva):
    cena = Cena(T, 15.0, -10.0)

    def maos(J, cavar=0.0, abre=0.0):
        Rv, Fv, Uv = J['axes']
        b = J['P'] + Uv * 3.6 + Fv * (T.prof + .6 - cavar * 1.6)
        ombro = J['SR'] + Uv * 1.0 + Fv * .8
        if abre > 0:
            return [b - Rv * (1.2 + 2.6 * abre), b + Rv * (1.2 + 2.6 * abre)]
        return [b - Uv * cavar * 1.2, ombro]

    def curvado(lean, **kw):
        base = dict(lean=lean, pelvis=v3(0, -.4, -.6), fL=v3(-T.leg_off, .8, T.ankle_u), fR=v3(T.leg_off, -1.4, T.ankle_u),
                    hL=v3(-1.6, T.prof + 2.6, T.hip_u + 4.6), hR=v3(1.2, T.prof + 2.8, T.hip_u + 4.2),
                    eL=v3(-1, -.3, -.4), eR=v3(1, -.3, -.4), hdL=v3(.5, 1, -.2), hdR=v3(-.5, 1, -.2),
                    head=v3(0, .5, -.8), props=props_ataque)
        base.update(kw)
        return H(T, **base)
    R = H(T)
    A0 = dict(REPOUSO, eyeBlack=0, tilt=0, jaw=.6)
    Avai = dict(eyeBlack=1, tilt=1.5, jaw=1.3, footTravel=[0, 3], arms=[8, 8], armLift=[2, 2], armOut=[-3, -3], handGrip=[0, 0])
    Apega = dict(Avai, handGrip=[1, 1], tilt=2.0, jaw=1.0)
    ini = chaves([(0, R, A0, 0), (4, susto(T), Avai, 0), (8, curvado(4, barriga=0.0), Apega, 1),
                  (13, curvado(9, barriga=.45), dict(Apega, tilt=2.6), 1)], 14, curva)
    loop = []
    for i in range(16):
        t = i / 16
        cav = max(0.0, math.sin(TAU * 2 * t))
        h = curvado(9 + 4 * cav, barriga=.6 + .1 * cav, head=v3(0, .5, -.8 - .6 * cav),
                    gotas=[v3(.5 * k - .5, T.prof + 1.2, T.hip_u + 2 - (t * 6 + k * 2) % 6) for k in range(3)])
        a = dict(Apega, tilt=2.4 + .8 * cav, jaw=1.0 + .7 * cav, headTilt=.04 * cav)
        loop.append((h, a, ('cavar', cav)))
    morto = _com_props(morto_base(T, barriga=1.0, hL=v3(-2.0, 1.0, T.hip_u + 3.0), hR=v3(T.sh_r + 4.5, -.5, T.sh_u - 4.0)),
                       pocas=[('P', 5.0)])
    fim = chaves([(0, loop[0][0], loop[0][1], loop[0][2]), (4, curvado(5, barriga=1.0, head=v3(0, -.2, .6)), dict(Apega, tilt=2.8, jaw=1.8), ('abre', 1.0))],
                 5, curva)
    recua = curvado(-6, barriga=1.0, pelvis=v3(0, -1.2, -.8), fR=v3(T.leg_off, -3.0, T.ankle_u),
                    hL=v3(-1.4, T.prof + 2.2, T.hip_u + 4.0), hR=v3(1.4, T.prof + 2.2, T.hip_u + 4.0))
    Asolta = dict(REPOUSO, eyeBlack=1, tilt=2.2, jaw=1.2, headLift=-2, headTilt=.18, gazeY=.5, footTravel=[0, 3])
    for i in range(4):
        u = (i + 1) / 4
        fim.append((mistura(fim[-1][0] if i == 0 else fim[4][0], recua, _sm(u)), _lerp_dict(fim[4][1], Asolta, u), ('abre', 1 - u)))
    for i in range(9):
        q = queda(T, i, 9, recua, morto)
        q = _com_props(q, barriga=1.0, pocas=[] if i < 6 else [('P', 1.5 + 3.5 * (i - 5) / 3)])
        fim.append((q, dict(Asolta, footTravel=[0, 3 * (1 - (i + 1) / 9)]), 0))
    while len(fim) < 24:
        fim.append((morto, dict(Asolta, footTravel=[0, 0]), 0))
    return cena, ini, loop, fim, maos, morto


# ------------------------------------------------------------------ 4. TOY QUEBRADO: comer o rosto

def rosto(T, curva):
    cena = Cena(T, 12.5, 5.0)

    def na_cabeca(J):
        Rv, Fv, Uv = J['axes']
        c = J['N'] + J['head_off'] + Uv * (T.head_cu - T.neck_u)
        return [c - Rv * (T.head_rx * .8) - Uv * 1.5, c + Rv * (T.head_rx * .8) - Uv * 1.5]

    def preso(L, **kw):
        base = dict(pelvis=v3(0, .5, L), lean=5, fL=v3(-T.leg_off, .8, T.ankle_u + L * .7), fR=v3(T.leg_off, -.2, T.ankle_u + L * .5),
                    pdL=v3(0, .5, -1), pdR=v3(0, .5, -1),
                    hL=v3(-3.0, 6.4, T.sh_u + L - 1.0), hR=v3(3.0, 6.4, T.sh_u + L - .6),
                    eL=v3(-1, -.4, -.4), eR=v3(1, -.4, -.4), hdL=v3(0, 1, .3), hdR=v3(0, 1, .3), stretch=1.2)
        base.update(kw)
        return H(T, **base)
    R = H(T)
    A0 = dict(REPOUSO, eyeBlack=0, tilt=0, jaw=1.1)
    Avai = dict(eyeBlack=1, tilt=1, jaw=1.8, footTravel=[0, 3], arms=[9, 9], armLift=[18, 18], armOut=[-4, -4], handGrip=[0, 0])
    Apega = dict(Avai, handGrip=[1, 1], tilt=.6, jaw=1.4)
    ini = chaves([(0, R, A0, 0), (4, susto(T), Avai, 0), (8, preso(2), Apega, 1), (13, preso(5, ferida_rosto=.2), dict(Apega, jaw=2.1, headLift=-1.5), 1)],
                 14, curva)
    loop = []
    for i in range(16):
        t = i / 16
        mord = max(0.0, math.sin(TAU * 4 * t))
        ch = math.sin(TAU * 2 * t)
        h = preso(5 + .4 * mord, ferida_rosto=.6, head=v3(0, -.4 * mord, -.3 * mord),
                  fL=v3(-T.leg_off, 1.4 * ch + .6, T.ankle_u + 4 + max(0, ch) * 1.8),
                  fR=v3(T.leg_off, -1.4 * ch + .6, T.ankle_u + 3 + max(0, -ch) * 1.8),
                  props=props_ataque, gotas=[v3(.6 * k - .6, 2.5, T.neck_u + 5 - (t * 8 + k * 2.5) % 8) for k in range(3)])
        a = dict(Apega, jaw=2.1 - 1.6 * mord, headLift=-1.5 - 1.5 * mord, headTilt=.06 * mord, tilt=.6 + .5 * mord)
        loop.append((h, a, 1))
    morto = _com_props(morto_base(T, ferida_rosto=1.0), pocas=[('CAB', 5.0)])
    fim = chaves([(0, loop[0][0], loop[0][1], 1), (4, preso(6, ferida_rosto=1.0, head=v3(0, -.6, -.4)), dict(Apega, jaw=.4, headLift=-3, tilt=1.2), 1),
                  (7, preso(6.5, ferida_rosto=1.0, lean=0, head=v3(0, .6, -1.2), hL=v3(-3.4, 1, T.sh_u - 2), hR=v3(3.4, 1, T.sh_u - 2)),
                   dict(Apega, jaw=1.6, headLift=0, tilt=-.4), 1)], 8, curva)
    cai = H(T, ferida_rosto=1.0, lean=2, pelvis=v3(0, .2, -3.5), hL=v3(-T.sh_r - 1.5, .5, T.sh_u - 6), hR=v3(T.sh_r + 1.5, .5, T.sh_u - 6),
            fL=v3(-T.leg_off, 1.2, T.ankle_u), fR=v3(T.leg_off, 1.0, T.ankle_u), kL=v3(0, 1, .3), kR=v3(0, 1, .3))
    Asolta = dict(REPOUSO, eyeBlack=1, tilt=1.5, jaw=1.5, headLift=-2, headTilt=.2, gazeY=.5, footTravel=[0, 3])
    for i in range(3):
        u = (i + 1) / 3
        fim.append((mistura(fim[7][0], cai, u * u), _lerp_dict(fim[7][1], Asolta, u), 1 - u))
    for i in range(8):
        q = _com_props(queda(T, i, 8, cai, morto), ferida_rosto=1.0, pocas=[] if i < 5 else [('CAB', 2 + 3 * (i - 4) / 3)])
        fim.append((q, dict(Asolta, footTravel=[0, 3 * (1 - (i + 1) / 8)]), 0))
    while len(fim) < 24:
        fim.append((morto, dict(Asolta, footTravel=[0, 0]), 0))
    return cena, ini, loop, fim, na_cabeca, morto


ATAQUES = {
    'normal': ('Orelhitas', 'enforca', enforcar),
    'toy': ('Toy Orelhitas', 'arranca o braço', arrancar),
    'quebrado': ('Orelhitas Quebrado', 'abre a barriga', barriga),
    'toyquebrado': ('Toy Orelhitas Quebrado', 'come o rosto', rosto),
}


def montar_ataque(T, versao):
    """-> (cena, poses do humano, canais do animatronico por quadro, (ni, nl, nf), pose do corpo no chao)."""
    _, _, fn = ATAQUES[versao]
    cena, ini, loop, fim, alvos_fn, morto = fn(T, CURVAS[versao])
    poses, canais = [], []
    for h, a, w in ini + loop + fim:
        if not callable(h.get('props')):
            h = _com_props(h)
        a = dict(a)
        modo = None
        if isinstance(w, tuple):
            modo, val = w
            w = 1.0
        if w >= 0:
            base_maos = {k: list(a.get(k, REPOUSO[k])) for k in ('arms', 'armLift', 'armOut')}
            if w > 0:
                J = P.esqueleto(T, h)
                if modo == 'cavar':
                    alvos = alvos_fn(J, cavar=val)
                elif modo == 'abre':
                    alvos = alvos_fn(J, abre=val)
                else:
                    alvos = alvos_fn(J)
                alvos_a = [cena.para_anim(q) for q in alvos]
                maos = canais_maos(alvos_a, a.get('tilt', 0))
                a.update(misturar_maos(base_maos, maos, min(1.0, w)))
            else:
                a.update(base_maos)
        poses.append(h)
        canais.append({k: (list(v) if isinstance(v, (list, tuple)) else v) for k, v in a.items()})
    return cena, poses, canais, (len(ini), len(loop), len(fim)), morto
