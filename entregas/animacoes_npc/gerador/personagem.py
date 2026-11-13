"""Tipos de corpo, cabeca/rosto e montagem de um quadro a partir de uma pose."""
import math
import os
import numpy as np
from PIL import Image

import motor as M
from motor import v3, W, H

TIPOS = {
    'adulto_masculino': dict(modelo='humano', neck_u=28.0, sh_u=25.6, sh_r=7.0, arm_r=1.45, ua=4.6, fa=4.3,
                             hand_r=1.8, chest_w=6.3, hip_w=5.5, prof=4.0, hip_u=15.6, leg_off=2.5,
                             leg_r=2.45, thigh=6.9, shin=7.0, ankle_u=1.7, foot_r=1.5, foot_len=1.7,
                             escala=1.375),
    'adulto_feminino': dict(modelo='humana', neck_u=28.0, sh_u=25.6, sh_r=6.7, arm_r=1.4, ua=4.6, fa=4.3,
                            hand_r=1.7, chest_w=5.9, hip_w=5.9, prof=3.9, hip_u=15.6, leg_off=2.5,
                            leg_r=2.4, thigh=6.9, shin=7.0, ankle_u=1.7, foot_r=1.45, foot_len=1.7,
                            escala=1.375),
    'adolescente_masculino': dict(modelo='adolescente', neck_u=24.6, sh_u=22.6, sh_r=6.6, arm_r=1.35, ua=4.2,
                                  fa=3.9, hand_r=1.65, chest_w=5.7, hip_w=5.0, prof=3.6, hip_u=13.6,
                                  leg_off=2.2, leg_r=2.25, thigh=5.9, shin=6.0, ankle_u=1.6, foot_r=1.4,
                                  foot_len=1.6, escala=1.375),
    'adolescente_feminino': dict(modelo='adolescente_feminina', neck_u=24.6, sh_u=22.6, sh_r=6.4, arm_r=1.3,
                                 ua=4.2, fa=3.9, hand_r=1.6, chest_w=5.4, hip_w=5.4, prof=3.5, hip_u=13.6,
                                 leg_off=2.2, leg_r=2.2, thigh=5.9, shin=6.0, ankle_u=1.6, foot_r=1.35,
                                 foot_len=1.6, escala=1.375),
    'crianca': dict(modelo='crianca', neck_u=24.8, sh_u=22.8, sh_r=6.2, arm_r=1.45, ua=4.0, fa=3.7,
                    hand_r=1.8, chest_w=6.0, hip_w=5.4, prof=3.8, hip_u=14.6, leg_off=2.4, leg_r=2.4,
                    thigh=6.4, shin=6.4, ankle_u=1.7, foot_r=1.5, foot_len=1.6, escala=1.25),
}

DARK = (62, 40, 34)
LIP = (150, 66, 62)
TEAR = (120, 182, 238)
TEAR2 = (200, 232, 255)


def _row(img, d, col=0):
    return img.crop((col * 48, d * 60, col * 48 + 48, d * 60 + 60))


def _arr(img):
    return np.asarray(img.convert('RGBA')).copy()


def _blobs(alpha):
    """Componentes conexas simples (4-viz) de uma mascara."""
    h, w = alpha.shape
    lab = np.zeros((h, w), int)
    n = 0
    out = []
    for y in range(h):
        for x in range(w):
            if alpha[y, x] and not lab[y, x]:
                n += 1
                st = [(y, x)]
                lab[y, x] = n
                pts = []
                while st:
                    cy, cx = st.pop()
                    pts.append((cy, cx))
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
                        yy, xx = cy + dy, cx + dx
                        if 0 <= yy < h and 0 <= xx < w and alpha[yy, xx] and not lab[yy, xx]:
                            lab[yy, xx] = n
                            st.append((yy, xx))
                ys = [p[0] for p in pts]
                xs = [p[1] for p in pts]
                out.append((min(xs), min(ys), max(xs), max(ys), len(pts)))
    return out


class Tipo:
    def __init__(self, nome, src, repo):
        self.nome = nome
        p = dict(TIPOS[nome])
        self.__dict__.update(p)
        base = os.path.join(src, 'corpos', nome)
        ramp, top = M.paleta_de(os.path.join(base, 'andar_corpo.png'))
        self.pele = M.Pele(ramp, top, suave=(nome == 'crianca'))
        cab = Image.open(os.path.join(base, 'andar_cabeca.png'))
        olh = Image.open(os.path.join(base, 'andar_olhos.png'))
        bo = Image.open(os.path.join(base, 'andar_boca.png'))
        self.cab = [_arr(_row(cab, d)) for d in range(8)]
        self.olhos = {'neutro': [_arr(_row(olh, d)) for d in range(8)]}
        self.boca = {'neutro': [_arr(_row(bo, d)) for d in range(8)]}
        rp = os.path.join(repo, 'assets', 'personagens', self.modelo)
        for e in ('feliz', 'triste', 'assustado', 'cansado'):
            f = os.path.join(rp, e + '_olhos.png')
            if os.path.exists(f):
                self.olhos[e] = [_arr(_row(Image.open(f), d)) for d in range(8)]
            f = os.path.join(rp, e + '_boca.png')
            if os.path.exists(f):
                self.boca[e] = [_arr(_row(Image.open(f), d)) for d in range(8)]
        self._olhos_proc()
        self._bocas_proc()
        # geometria da cabeca (vista de frente)
        a = self.cab[0][..., 3] > 100
        ys, xs = np.nonzero(a)
        self.head_top = ys.min()
        self.head_bot = ys.max()
        self.head_cy = (ys.min() + ys.max() + 1) / 2
        self.head_rx = (xs.max() - xs.min() + 1) / 2
        oa = self.olhos['neutro'][0][..., 3] > 100
        oy = np.nonzero(oa)[0]
        self.eye_y = (oy.min() + oy.max() + 1) / 2
        ba = self.boca['neutro'][0][..., 3] > 60
        by = np.nonzero(ba)[0]
        self.mouth_y = (by.min() + by.max() + 1) / 2 if len(by) else self.eye_y + 4
        self.arm = self.ua + self.fa

    # landmarks (coordenadas de tela convertidas para u)
    def u_de_y(self, y):
        return M.GROUND - y

    @property
    def eye_u(self):
        return self.u_de_y(self.eye_y)

    @property
    def mouth_u(self):
        return self.u_de_y(self.mouth_y)

    @property
    def head_cu(self):
        return self.u_de_y(self.head_cy)

    # ---------------------------------------------------------- rostos
    def _olhos_proc(self):
        fel, fech = [], []
        for d in range(8):
            base = self.olhos['neutro'][d]
            a1 = np.zeros_like(base)
            a2 = np.zeros_like(base)
            for (x0, y0, x1, y1, n) in _blobs(base[..., 3] > 90):
                if n < 3:
                    continue
                ym = (y0 + y1) // 2 + 1
                w = x1 - x0 + 1
                for x in range(x0, x1 + 1):
                    edge = (x == x0 or x == x1) and w > 2
                    yy = ym if edge else ym - 1
                    a1[yy, x] = (*DARK, 255)
                    a2[ym + 1, x] = (*DARK, 255)
            fel.append(a1)
            fech.append(a2)
        self.olhos['riso'] = fel
        self.olhos['fechado'] = fech

    def _bocas_proc(self):
        tipos = {'aberta': [], 'riso': [], 'mastiga': [], 'o': []}
        for d in range(8):
            base = self.boca['neutro'][d]
            a = base[..., 3] > 50
            for k in tipos:
                tipos[k].append(np.zeros_like(base))
            if not a.any():
                continue
            ys, xs = np.nonzero(a)
            x0, x1 = xs.min(), xs.max()
            y0 = ys.min()
            cx = (x0 + x1) / 2
            w = x1 - x0 + 1
            lado = d in (2, 6)

            def put(img, x, y, c):
                if 0 <= x < W and 0 <= y < H:
                    img[y, x] = (*c, 255)
            # aberta: pequena oval
            ww = 2 if lado else max(2, min(3, w))
            xs0 = int(round(cx - ww / 2 + 0.5))
            for x in range(xs0, xs0 + ww):
                put(tipos['aberta'][d], x, y0, DARK)
                put(tipos['aberta'][d], x, y0 + 1, LIP)
            # riso: D aberto
            ww = 3 if lado else max(4, w + 1)
            xs0 = int(round(cx - ww / 2 + 0.5))
            for x in range(xs0, xs0 + ww):
                put(tipos['riso'][d], x, y0, DARK)
            for x in range(xs0 + (1 if ww > 3 else 0), xs0 + ww - (1 if ww > 3 else 0)):
                put(tipos['riso'][d], x, y0 + 1, LIP)
            for x in range(xs0 + 1, xs0 + ww - 1):
                put(tipos['riso'][d], x, y0 + 2, DARK)
            # mastiga: boca fechada, levemente deslocada
            ww = 2 if lado else max(2, w - 1)
            xs0 = int(round(cx - ww / 2 + 0.5))
            for x in range(xs0, xs0 + ww):
                put(tipos['mastiga'][d], x, y0 + 1, DARK)
            # o: boquinha redonda
            xs0 = int(round(cx - 1 + 0.5))
            for x in range(xs0, xs0 + 2):
                put(tipos['o'][d], x, y0, DARK)
                put(tipos['o'][d], x, y0 + 1, DARK)
        self.boca.update(tipos)

    def lagrimas(self, d, fase):
        img = np.zeros((H, W, 4), np.uint8)
        base = self.olhos['neutro'][d]
        for (x0, y0, x1, y1, n) in _blobs(base[..., 3] > 90):
            if n < 3:
                continue
            for k in range(2):
                ph = (fase + k * 0.5 + (x0 % 3) * 0.13) % 1.0
                y = int(y1 + 1 + ph * 9)
                x = (x0 + x1) // 2 + (1 if k else 0)
                if 0 <= y < H - 1 and 0 <= x < W:
                    img[y, x] = (*TEAR2, 255)
                    img[y + 1, x] = (*TEAR, 255)
        return img


# ---------------------------------------------------------------- pose

def rest_hand(T, lado):
    s = 1 if lado == 'R' else -1
    return v3(s * (T.sh_r + 0.7), 0.6, T.sh_u - T.arm + 0.6)


def pose_base(T):
    return dict(
        pelvis=v3(0, 0, 0), lean=0.0, roll=0.0, yaw=0.0, shrug=0.0,
        hL=rest_hand(T, 'L'), hR=rest_hand(T, 'R'),
        eL=v3(-0.4, -1, 0), eR=v3(0.4, -1, 0),
        fL=v3(-T.leg_off, 0, T.ankle_u), fR=v3(T.leg_off, 0, T.ankle_u),
        kL=v3(0, 1, 0), kR=v3(0, 1, 0),
        pdL=v3(0, 1, 0), pdR=v3(0, 1, 0),
        hdL=None, hdR=None,
        head=v3(0, 0, 0), hturn=0, eyes='neutro', mouth='neutro', tears=-1.0,
        stretch=1.12, overL='', overR='', props=None,
        corpo_rot=None, chao=False, cabeca_rot=None, deitar=0.0,
        a1=0.0, a2=0.0, a3=0.0, a4=0.0,
    )


def lerp(a, b, t):
    if isinstance(a, np.ndarray) and isinstance(b, np.ndarray):
        return a + (b - a) * t
    if isinstance(a, int) and isinstance(b, int):
        return b if t >= 0.5 else a
    if isinstance(a, (int, float)) and isinstance(b, (int, float)) and not isinstance(a, bool):
        return a + (b - a) * t
    return b if t >= 0.5 else a


def mistura(p0, p1, t):
    out = {}
    for k in p0:
        out[k] = lerp(p0[k], p1.get(k, p0[k]), t)
    for k in p1:
        if k not in out:
            out[k] = p1[k]
    return out


def suave(t):
    return t * t * (3 - 2 * t)


# ---------------------------------------------------------------- montagem

def esqueleto(T, p):
    J = {}
    P = v3(0, 0, T.hip_u) + p['pelvis']
    lean = math.radians(p['lean'])
    roll = math.radians(p['roll'])
    yaw = math.radians(p['yaw'])
    up = v3(0, 0, 1)
    R = v3(1, 0, 0)
    F = v3(0, 1, 0)
    # torcao, inclinacao para frente e lateral
    R = M.rot_axis(R, up, -yaw)
    F = M.rot_axis(F, up, -yaw)
    up = M.rot_axis(up, R, -lean)
    F = M.rot_axis(F, R, -lean)
    up = M.rot_axis(up, F, roll)
    R = M.rot_axis(R, F, roll)
    J['P'] = P
    J['axes'] = (R, F, up)
    J['N'] = P + up * (T.neck_u - T.hip_u)
    J['B'] = P - up * 1.6
    sh = P + up * (T.sh_u - T.hip_u + p['shrug'])
    J['SL'] = sh - R * T.sh_r
    J['SR'] = sh + R * T.sh_r
    J['HL'] = P - R * T.leg_off
    J['HR'] = P + R * T.leg_off
    for s in 'LR':
        E, Wr = M.ik(J['S' + s], p['h' + s], T.ua, T.fa, p['e' + s], p['stretch'])
        J['E' + s] = E
        J['W' + s] = Wr
        hd = p['hd' + s]
        if hd is None:
            hd = Wr - E
        hd = np.asarray(hd, float)
        J['Hd' + s] = hd / (np.linalg.norm(hd) + 1e-9)
        K_, A_ = M.ik(J['H' + s], p['f' + s], T.thigh, T.shin, p['k' + s], 1.0)
        J['K' + s] = K_
        J['A' + s] = A_
        pd = np.asarray(p['pd' + s], float)
        J['Pd' + s] = pd / (np.linalg.norm(pd) + 1e-9)
    J['head_off'] = np.asarray(p['head'], float)
    # rotacao de corpo inteiro (deitar)
    if p['corpo_rot'] is not None:
        axis, ang, piv = p['corpo_rot']
        ang = math.radians(ang)
        piv = np.asarray(piv, float)
        for k in list(J):
            if k in ('axes', 'head_off'):
                continue
            v = J[k]
            if k.startswith('Hd') or k.startswith('Pd'):
                J[k] = M.rot_axis(v, axis, ang)
            else:
                J[k] = piv + M.rot_axis(v - piv, axis, ang)
        J['axes'] = tuple(M.rot_axis(a, axis, ang) for a in J['axes'])
        J['head_off'] = M.rot_axis(J['head_off'], axis, ang)
    if p['chao']:
        low = min(J[k][2] - r for k, r in (('AL', T.foot_r), ('AR', T.foot_r), ('KL', T.leg_r), ('KR', T.leg_r),
                                           ('P', T.hip_w * 0.6), ('B', T.hip_w * 0.6), ('N', T.chest_w * 0.6),
                                           ('EL', T.arm_r), ('ER', T.arm_r), ('WL', T.hand_r), ('WR', T.hand_r)))
        for k in list(J):
            if k in ('axes', 'head_off') or k.startswith('Hd') or k.startswith('Pd'):
                continue
            J[k] = J[k] - v3(0, 0, low)
    return J


class Projetor:
    def __init__(self, d, dx=0.0, dy=0.0):
        self.d = d
        self.dx = dx
        self.dy = dy
        self.R, self.F = M.eixos(d)

    def world(self, p):
        r, f, u = p
        X = r * self.R[0] + f * self.F[0]
        Z = r * self.R[2] + f * self.F[2]
        return X, u, Z

    def tela(self, p):
        X, U, Z = self.world(p)
        return (M.CX + self.dx + X, M.GROUND + self.dy - U + M.K * Z, Z)

    def vec_tela(self, v):
        X, U, Z = self.world(v)
        return np.array([X, -U + M.K * Z]), Z


def _meia_largura(proj, eixo_tela, Rv, Fv, hw, hd):
    n = np.array([-eixo_tela[1], eixo_tela[0]])
    nn = np.linalg.norm(n)
    if nn < 1e-6:
        n = np.array([1.0, 0.0])
    else:
        n = n / nn
    rs, _ = proj.vec_tela(Rv)
    fs, _ = proj.vec_tela(Fv)
    return math.sqrt((hw * np.dot(rs, n)) ** 2 + (hd * np.dot(fs, n)) ** 2)


def montar(T, p, d, fase=0.0):
    """Retorna dict de camadas RGBA (numpy) para a pose p na direcao d."""
    if p['deitar'] > 0:
        p = dict(p)
        R_, F_ = M.eixos(d)
        s = 1.0 if R_[2] <= 1e-6 else -1.0
        piv = v3(0, 0, T.hip_u) + p['pelvis']
        p['corpo_rot'] = (v3(0, 1, 0), s * 90.0 * p['deitar'], piv)
        p['chao'] = True
        p['cabeca_rot'] = _cabeca_deitada
    J = esqueleto(T, p)
    dx = 0.0
    if p['deitar'] > 0:
        chave = (T.nome, d, round(p['deitar'], 2))
        if chave not in _CENTRO:
            pr0 = Projetor(d)
            xs = []
            for k, v in J.items():
                if k in ('axes', 'head_off') or k.startswith('Hd') or k.startswith('Pd'):
                    continue
                xs.append(pr0.tela(v)[0])
            xs = [min(xs) - 3, max(xs) + 3]
            N0 = (M.CX, M.GROUND - T.neck_u)
            Ns = pr0.tela(J['N'] + J['head_off'])
            row, rot = p['cabeca_rot'](J, pr0, d)
            img = _gira(T.cab[row], N0, rot) if False else None
            # extensao da cabeca girada (a partir da caixa da cabeca de frente)
            a = T.cab[row][..., 3] > 40
            ys_, xs_ = np.nonzero(a)
            pts = np.stack([xs_ - N0[0], ys_ - N0[1]], 1).astype(float)
            for _ in range(rot % 4):
                pts = np.stack([pts[:, 1], -pts[:, 0]], 1)
            xs += [Ns[0] + pts[:, 0].min(), Ns[0] + pts[:, 0].max() + 1]
            maxy = Ns[1] + pts[:, 1].max() + 1
            dy = min(0.0, M.GROUND + 0.6 - maxy)
            _CENTRO[chave] = (round(24 - (min(xs) + max(xs)) / 2), round(dy))
        dx, dy = _CENTRO[chave]
    else:
        dy = 0
    pr = Projetor(d, dx, dy)
    S = pr.tela
    Rv, Fv, Uv = J['axes']
    q = M.Quadro()
    facing_z = M.eixos(d)[1][2]
    torso_z = (S(J['P'])[2] + S(J['N'])[2]) / 2

    def longe(*pts):
        z = np.mean([S(x)[2] for x in pts])
        return float(np.clip((torso_z - z - 0.6) / 2.2, 0, 1))

    def over_ok(flag):
        if flag == 'always':
            return True
        if flag == 'face':
            return facing_z > -0.3
        return False

    # tronco
    a = S(J['B'])
    b = S(J['N'])
    ax2 = np.array([b[0] - a[0], b[1] - a[1]])
    wa = _meia_largura(pr, ax2, Rv, Fv, T.hip_w, T.prof)
    wb = _meia_largura(pr, ax2, Rv, Fv, T.chest_w, T.prof)
    q.caixa_arred(a, b, wa, wb, 2.4, T.prof * 0.8, T.pele.cor(0), 'tronco')
    # pernas
    for s in 'LR':
        lg = longe(J['K' + s], J['A' + s])
        cor = T.pele.cor(lg)
        g = 'perna' + s
        q.capsula(S(J['H' + s]), S(J['K' + s]), T.leg_r, T.leg_r * 0.95, cor, g)
        q.capsula(S(J['K' + s]), S(J['A' + s]), T.leg_r * 0.95, T.leg_r * 0.85, cor, g)
        ft = J['A' + s] + J['Pd' + s] * T.foot_len - Uv * 0.3
        q.capsula(S(J['A' + s]), S(ft), T.foot_r, T.foot_r, cor, g)
    # bracos
    for s in 'LR':
        lg = longe(J['E' + s], J['W' + s])
        cor = T.pele.cor(lg)
        flag = p['over' + s]
        ov = over_ok(flag)
        g = 'braco' + s
        q.capsula(S(J['S' + s]), S(J['E' + s]), T.arm_r * 1.05, T.arm_r, cor, g, over=ov)
        q.capsula(S(J['E' + s]), S(J['W' + s]), T.arm_r, T.arm_r * 0.95, cor, g, over=ov)
        hr = T.hand_r * (1.3 if flag == 'face' else 1.0)
        hp = J['W' + s] + J['Hd' + s] * hr * 0.55
        q.capsula(S(J['W' + s]), S(hp), hr * 0.85, hr, T.pele.cor(lg * 0.8, 0.15), g, over=ov)

    body_rgba, body_over, body_z = M.contorno(q)

    # objetos
    qo = M.Quadro()
    tem_obj = False
    prim = p['props'](J, T, p) if callable(p['props']) else (p['props'] or [])
    for it in prim:
        tem_obj = True
        _desenhar_prop(qo, it, pr, S, d, T)
    if tem_obj:
        obj_rgba, _, obj_z = M.contorno(qo, interno=True)
    else:
        obj_rgba = np.zeros((H, W, 4), np.uint8)
        obj_z = np.full((H, W), -1e9)

    # cabeca
    N0 = (M.CX, M.GROUND - T.neck_u)
    Ns = S(J['N'] + J['head_off'])
    off = (int(round(Ns[0] - N0[0])), int(round(Ns[1] - N0[1])))
    head_z = Ns[2]
    hrow = (d + p['hturn']) % 8
    rot = 0
    if p['cabeca_rot'] is not None:
        hrow, rot = p['cabeca_rot'](J, pr, d)
    eyes = T.olhos.get(p['eyes'], T.olhos['neutro'])[hrow]
    mouth = T.boca.get(p['mouth'], T.boca['neutro'])[hrow]
    camadas = {}
    for nome, img in (('cabeca', T.cab[hrow]), ('olhos', eyes), ('boca', mouth)):
        camadas[nome] = _desloca(_gira(img, N0, rot), off)
    head_mask = camadas['cabeca'][..., 3] > 40

    # separa camadas
    alpha_b = body_rgba[..., 3] > 0
    alpha_o = obj_rgba[..., 3] > 0
    frente_m = alpha_b & body_over
    na_frente_obj = alpha_b & alpha_o & (body_z > obj_z) & ~(head_mask & (body_z < head_z))
    frente_m |= na_frente_obj
    # pixels do corpo a frente da cabeca (ex.: maos muito a frente)
    frente_m |= alpha_b & head_mask & (body_z > head_z + 5.5)
    corpo = body_rgba.copy()
    corpo[frente_m] = 0
    frente = np.zeros_like(body_rgba)
    frente[frente_m] = body_rgba[frente_m]
    obj = obj_rgba.copy()
    esconde = alpha_o & head_mask & (obj_z < head_z)
    obj[esconde] = 0
    if p['tears'] >= 0 and facing_z > -0.3:
        lg = _desloca(_gira(T.lagrimas(hrow, p['tears']), N0, rot), off)
        m = lg[..., 3] > 0
        frente[m] = lg[m]
    camadas['corpo'] = corpo
    camadas['objeto'] = obj
    camadas['frente'] = frente
    return camadas


_CENTRO = {}


ORDEM = ['corpo', 'cabeca', 'olhos', 'boca', 'objeto', 'frente']


def compor(camadas):
    im = Image.new('RGBA', (W, H))
    for n in ORDEM:
        im.alpha_composite(Image.fromarray(camadas[n]))
    return im


def _cabeca_deitada(J, pr, d):
    Rv, Fv, Uv = J['axes']
    fx, _, fz = pr.world(Fv)
    row = int(round(math.degrees(math.atan2(fx, fz)) / 45.0)) % 8
    vs, _ = pr.vec_tela(Uv)
    k = 0
    if np.linalg.norm(vs) > 0.45:
        if abs(vs[0]) > abs(vs[1]):
            k = 3 if vs[0] > 0 else 1
        else:
            k = 0 if vs[1] < 0 else 2
    return row, k


def _desloca(img, off):
    dx, dy = off
    out = np.zeros_like(img)
    h, w = img.shape[:2]
    xs0, xs1 = max(0, -dx), min(w, w - dx)
    ys0, ys1 = max(0, -dy), min(h, h - dy)
    if xs0 < xs1 and ys0 < ys1:
        out[ys0 + dy:ys1 + dy, xs0 + dx:xs1 + dx] = img[ys0:ys1, xs0:xs1]
    return out


def _gira(img, piv, k):
    k %= 4
    if k == 0:
        return img
    px, py = int(round(piv[0])), int(round(piv[1]))
    S_ = 140
    c = np.zeros((S_, S_, 4), np.uint8)
    ox, oy = S_ // 2 - px, S_ // 2 - py
    c[oy:oy + H, ox:ox + W] = img
    c = np.rot90(c, k).copy()
    return c[oy:oy + H, ox:ox + W]


# ---------------------------------------------------------------- objetos

def _desenhar_prop(q, it, pr, S, d, T):
    t = it['t']
    g = it.get('g', 'obj')
    if t == 'cap':
        zo = it.get('zoff', 0.0)
        a = S(it['a'])
        b = S(it['b'])
        q.capsula((a[0], a[1], a[2] + zo), (b[0], b[1], b[2] + zo), it['r'], it.get('r2', it['r']),
                  M.cor_plana(it['rgb']), g)
    elif t == 'poly':
        pts = [S(x) for x in it['pts']]
        shade = 1.0
        if len(it['pts']) >= 3:
            a, b, c = (pr.world(np.asarray(x)) for x in it['pts'][:3])
            n = np.cross(np.subtract(b, a), np.subtract(c, a))
            nn = np.linalg.norm(n)
            if nn > 1e-6:
                n = n / nn
                # normal no espaco de luz (x, cima, z)
                L = np.array([-0.5, 0.7, 0.5])
                L = L / np.linalg.norm(L)
                shade = 0.72 + 0.4 * abs(float(np.dot(n, L)))
        q.poligono(pts, it['rgb'], g, shade=shade * it.get('shade', 1.0))
    elif t == 'disc':
        c = np.asarray(it['c'], float)
        a1 = np.asarray(it.get('a1', (1, 0, 0)), float)
        a2 = np.asarray(it.get('a2', (0, 0.72, -0.69)), float)
        r1 = it['r']
        r2 = it.get('r2', r1)
        pts = [c + a1 * r1 * math.cos(k * math.pi / 8) + a2 * r2 * math.sin(k * math.pi / 8) for k in range(16)]
        _desenhar_prop(q, dict(t='poly', pts=pts, rgb=it['rgb'], g=g, shade=it.get('shade', 1.0)), pr, S, d, T)
    elif t == 'sprite':
        imgs = it['img']
        vis = it.get('vista')
        if vis is None:
            vis = ['frente', 'direita', 'direita', 'costas', 'costas', 'esquerda', 'esquerda', 'frente'][d]
        img = imgs[vis] if isinstance(imgs, dict) else imgs
        sx, sy, z = S(it['at'])
        anc = it.get('ancora')
        if anc is None:
            anc = (img.shape[1] / 2, img.shape[0] / 2)
        elif anc == 'base':
            anc = (img.shape[1] / 2, img.shape[0] - 1)
        ax, ay = anc
        q.sprite(img, sx - ax, sy - ay, z + it.get('zoff', 0), g)
