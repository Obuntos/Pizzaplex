"""Motor de poses: esqueleto 3D simples -> pixel art 48x60 nas 8 direcoes.

Usa as camadas de cabeca/olhos/boca dos moldes (pizzaplex_base_corpos_objetos)
e desenha corpo, bracos, pernas e objetos de mao a partir de um esqueleto,
com a paleta de pele tirada do proprio molde.
"""
import math
import numpy as np
from PIL import Image

W, H = 48, 60
CX = 24.0          # x do eixo do corpo
GROUND = 56.4      # y de tela do chao (u = 0)
K = 0.42           # quanto a profundidade (para a camera) desce na tela
LIGHT = np.array([-0.55, -0.62, 0.56])
LIGHT = LIGHT / np.linalg.norm(LIGHT)
OUT = np.array([106, 76, 56], dtype=float)

DIRECOES = ['frente', 'frente_direita', 'direita', 'costas_direita',
            'costas', 'costas_esquerda', 'esquerda', 'frente_esquerda']

PY, PX = np.mgrid[0:H, 0:W].astype(float)
PX += 0.5
PY += 0.5


def eixos(d):
    """Vetores do mundo (X tela-direita, U cima, Z para a camera)."""
    phi = math.radians(45 * d)
    f = np.array([math.sin(phi), 0.0, math.cos(phi)])
    r = np.array([-f[2], 0.0, f[0]])
    return r, f


def v3(*a):
    return np.array(a, dtype=float)


# ---------------------------------------------------------------- geometria

def ik(A, T, l1, l2, pole, stretch=1.0):
    A = np.asarray(A, float)
    T = np.asarray(T, float)
    d = T - A
    L = float(np.linalg.norm(d))
    if L < 1e-6:
        d = v3(0, 0, -1)
        L = 1e-6
    n = d / L
    tot = l1 + l2
    if L > tot:
        s = min(L / tot, stretch)
        l1 *= s
        l2 *= s
        tot = l1 + l2
        if L > tot:
            L = tot * 0.999
            T = A + n * L
    L = max(L, abs(l1 - l2) + 0.05)
    ca = (l1 * l1 + L * L - l2 * l2) / (2 * l1 * L)
    ca = max(-1.0, min(1.0, ca))
    sa = math.sqrt(1 - ca * ca)
    p = np.asarray(pole, float)
    p = p - np.dot(p, n) * n
    pn = np.linalg.norm(p)
    if pn < 1e-6:
        p = np.cross(n, v3(1, 0, 0))
        pn = np.linalg.norm(p)
        if pn < 1e-6:
            p = np.cross(n, v3(0, 1, 0))
            pn = np.linalg.norm(p)
    p = p / pn
    E = A + n * l1 * ca + p * l1 * sa
    return E, A + n * L


def rot_axis(v, axis, ang):
    """Rodrigues: gira v em torno de axis (unitario) por ang (rad)."""
    axis = np.asarray(axis, float)
    axis = axis / np.linalg.norm(axis)
    v = np.asarray(v, float)
    c, s = math.cos(ang), math.sin(ang)
    return v * c + np.cross(axis, v) * s + axis * np.dot(axis, v) * (1 - c)


# ---------------------------------------------------------------- render

class Quadro:
    """Acumula primitivas de um quadro e rasteriza com z-buffer."""

    def __init__(self):
        self.z = np.full((H, W), -1e9)
        self.rgb = np.zeros((H, W, 3))
        self.grp = np.full((H, W), -1, dtype=int)
        self.over = np.zeros((H, W), dtype=bool)
        self.grupos = {}

    def gid(self, g):
        if g not in self.grupos:
            self.grupos[g] = len(self.grupos)
        return self.grupos[g]

    def _put(self, inside, z, rgb, g, over):
        win = inside & (z > self.z)
        if not win.any():
            return
        self.z[win] = z[win]
        self.rgb[win] = rgb[win] if rgb.ndim == 3 else rgb
        self.grp[win] = self.gid(g)
        self.over[win] = over

    def capsula(self, a, b, ra, rb, cor, g, over=False, zbulge=1.0):
        ax, ay, az = a
        bx, by, bz = b
        dx, dy = bx - ax, by - ay
        L2 = dx * dx + dy * dy
        if L2 > 1e-9:
            t = np.clip(((PX - ax) * dx + (PY - ay) * dy) / L2, 0, 1)
        else:
            t = np.zeros_like(PX)
        cx = ax + t * dx
        cy = ay + t * dy
        r = ra + (rb - ra) * t
        ox = PX - cx
        oy = PY - cy
        d2 = ox * ox + oy * oy
        inside = d2 <= r * r
        if not inside.any():
            return
        rr = np.maximum(r, 1e-3)
        nz = np.sqrt(np.clip(1 - d2 / (rr * rr), 0, 1))
        z = az + t * (bz - az) + nz * rr * zbulge
        n = np.stack([ox / rr, oy / rr, nz], -1)
        self._put(inside, z, cor(n), g, over)

    def caixa_arred(self, a, b, wa, wb, c, prof, cor, g, over=False):
        """Caixa arredondada (tronco) entre a e b na tela."""
        ax, ay, az = a
        bx, by, bz = b
        dx, dy = bx - ax, by - ay
        L = math.hypot(dx, dy)
        if L < 1e-6:
            dx, dy, L = 0.0, -1e-3, 1e-3
        ux, uy = dx / L, dy / L
        nx, ny = -uy, ux
        s = (PX - ax) * ux + (PY - ay) * uy
        p = (PX - ax) * nx + (PY - ay) * ny
        tt = np.clip(s / L, 0, 1)
        w = wa + (wb - wa) * tt
        cc = np.minimum(c, np.minimum(w, L / 2) - 0.01)
        qx = np.abs(p) - (w - cc)
        qy = np.abs(s - L / 2) - (L / 2 - cc)
        dist = np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - cc
        inside = dist <= 0
        if not inside.any():
            return
        e = np.clip((s - L / 2) / (L / 2 + 1e-6), -1, 1)
        lx = np.clip(p / np.maximum(w, 1e-3), -1, 1)
        nxs = nx * lx + ux * (e ** 5) * 0.7
        nys = ny * lx + uy * (e ** 5) * 0.7
        nn = np.clip(nxs * nxs + nys * nys, 0, 0.98)
        nz = np.sqrt(1 - nn)
        z = az + tt * (bz - az) + nz * prof
        n = np.stack([nxs, nys, nz], -1)
        self._put(inside, z, cor(n), g, over)

    def poligono(self, pts, rgb, g, over=False, shade=1.0):
        pts = np.asarray(pts, float)
        xs, ys, zs = pts[:, 0], pts[:, 1], pts[:, 2]
        n = len(pts)
        inside = np.zeros((H, W), dtype=bool)
        j = n - 1
        for i in range(n):
            xi, yi, xj, yj = xs[i], ys[i], xs[j], ys[j]
            cond = ((yi > PY) != (yj > PY))
            with np.errstate(divide='ignore', invalid='ignore'):
                xint = (xj - xi) * (PY - yi) / (yj - yi + 1e-12) + xi
            inside ^= cond & (PX < xint)
            j = i
        if not inside.any():
            return
        z = np.full((H, W), zs.mean() + 0.01)
        col = np.clip(np.asarray(rgb, float) * shade, 0, 255)
        self._put(inside, z, np.broadcast_to(col, (H, W, 3)).copy(), g, over)

    def sprite(self, img, x0, y0, z, g, over=False):
        a = np.asarray(img).astype(float)
        h, w = a.shape[:2]
        x0 = int(round(x0))
        y0 = int(round(y0))
        inside = np.zeros((H, W), dtype=bool)
        rgb = np.zeros((H, W, 3))
        X0, Y0 = max(0, x0), max(0, y0)
        X1, Y1 = min(W, x0 + w), min(H, y0 + h)
        if X0 >= X1 or Y0 >= Y1:
            return
        sub = a[Y0 - y0:Y1 - y0, X0 - x0:X1 - x0]
        inside[Y0:Y1, X0:X1] = sub[..., 3] > 110
        rgb[Y0:Y1, X0:X1] = sub[..., :3]
        self._put(inside, np.full((H, W), float(z)), rgb, g, over)


def _sh(a, dy, dx, fill):
    out = np.full_like(a, fill)
    h, w = a.shape[:2]
    ys = slice(max(0, dy), h + min(0, dy))
    yd = slice(max(0, -dy), h + min(0, -dy))
    xs = slice(max(0, dx), w + min(0, dx))
    xd = slice(max(0, -dx), w + min(0, -dx))
    out[ys, xs] = a[yd, xd]
    return out


def contorno(q, interno=True):
    """Gera RGBA final com contorno externo suave e linhas internas."""
    mask = q.z > -1e8
    rgb = q.rgb.copy()
    if interno:
        sil = np.zeros_like(mask)
        edge = np.zeros_like(mask)
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            m2 = _sh(mask, dy, dx, False)
            z2 = _sh(q.z, dy, dx, -1e9)
            g2 = _sh(q.grp, dy, dx, -1)
            sil |= mask & ~m2
            edge |= mask & m2 & (g2 != q.grp) & ((z2 > q.z + 0.9) | ((np.abs(z2 - q.z) <= 0.9) & (q.grp > g2)))
        rgb[sil] = rgb[sil] * 0.72 + OUT * 0.28
        rgb[edge] = rgb[edge] * 0.45 + OUT * 0.55
    alpha = np.where(mask, 255.0, 0.0)
    owner_over = q.over.copy()
    # anel externo
    ring4 = np.zeros_like(mask)
    ring_over = np.zeros_like(mask)
    ring_z = np.full((H, W), -1e9)
    for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        m2 = _sh(mask, dy, dx, False)
        o2 = _sh(q.over, dy, dx, False)
        z2 = _sh(q.z, dy, dx, -1e9)
        new = ~mask & m2 & (z2 > ring_z)
        ring_z[new] = z2[new]
        ring_over[new] = o2[new]
        ring4 |= ~mask & m2
    ringd = np.zeros_like(mask)
    for dy, dx in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
        m2 = _sh(mask, dy, dx, False)
        o2 = _sh(q.over, dy, dx, False)
        z2 = _sh(q.z, dy, dx, -1e9)
        new = ~mask & ~ring4 & m2 & (z2 > ring_z)
        ring_z[new] = z2[new]
        ring_over[new] = o2[new]
        ringd |= ~mask & ~ring4 & m2
    rgb[ring4 | ringd] = OUT
    alpha[ring4] = 150
    alpha[ringd] = 55
    owner_over[ring4 | ringd] = ring_over[ring4 | ringd]
    zz = np.where(mask, q.z, ring_z)
    out = np.dstack([np.clip(rgb, 0, 255), alpha]).astype(np.uint8)
    return out, owner_over, zz


# ---------------------------------------------------------------- paleta

def paleta_de(img_path):
    im = np.asarray(Image.open(img_path).convert('RGBA')).reshape(-1, 4)
    op = im[im[:, 3] == 255][:, :3].astype(float)
    lum = op @ np.array([0.3, 0.55, 0.15])
    order = np.argsort(lum)
    op = op[order]
    pcts = [2, 7, 16, 30, 55, 90, 99.3]
    ramp = [op[min(len(op) - 1, int(len(op) * p / 100))] for p in pcts]
    # cores mais frequentes para quantizar
    cols, cnt = np.unique(op.astype(int), axis=0, return_counts=True)
    top = cols[np.argsort(-cnt)[:14]].astype(float)
    return np.array(ramp), top


class Pele:
    def __init__(self, ramp, top, suave):
        self.ramp = ramp
        self.top = top
        self.suave = suave

    def cor(self, longe=0.0, claro=0.0):
        ramp, top, suave = self.ramp, self.top, self.suave

        def f(n):
            lam = 0.5 + 0.5 * (n @ LIGHT)
            pos = 1.55 + lam * 4.4 - longe * 1.7 + claro
            pos = np.clip(pos, 0, len(ramp) - 1)
            if suave:
                i0 = np.floor(pos).astype(int)
                i1 = np.minimum(i0 + 1, len(ramp) - 1)
                fr = (pos - i0)[..., None]
                return ramp[i0] * (1 - fr) + ramp[i1] * fr
            c = ramp[np.round(pos).astype(int)]
            # quantiza para cores do molde
            d = ((c[..., None, :] - top[None, None]) ** 2).sum(-1)
            return top[np.argmin(d, -1)]
        return f


def cor_plana(rgb, amb=0.62):
    rgb = np.asarray(rgb, float)

    def f(n):
        lam = np.clip(n @ LIGHT, 0, 1)
        k = amb + (1.25 - amb) * lam
        return np.clip(rgb * k[..., None], 0, 255)
    return f
