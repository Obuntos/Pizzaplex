(() => {
  "use strict";
  const M = window.Mini;
  const W = 640, H = 420, PX = 3, TAU = M.TAU;

  // ---------- barriga de ovo: 4 fileiras x 2 colunas = 8 seções ----------
  const CX = 360, CY = 214, RX = 142, RY = 130, TOP = CY - RY, BOT = CY + RY;
  // pança larga: quase um barril arredondado, um pouco mais larga embaixo
  const hw = y => { const u = (y - CY) / RY; return Math.abs(u) >= 1 ? 0 : RX * Math.pow(1 - Math.pow(Math.abs(u), 2.1), 1 / 2.1) * (1 + .12 * u); };
  const EGG = (() => { const r = [], l = []; for (let y = TOP; y <= BOT; y += 3) { const h = hw(y); r.push([CX + h, y]); l.unshift([CX - h, y]); } return r.concat(l); })();
  const EDGE = (() => {
    const out = [];
    for (let dx = 0; dx <= RX + 14; dx += 4) { let t = null, b = null; for (let y = TOP; y <= BOT; y++) if (hw(y) >= dx) { if (t === null) t = y; b = y; } if (t !== null) out.push({ dx, t, b }); }
    return out;
  })();
  // as emendas entre fileiras são levemente curvas, como na barriga do modelo
  const seam = (k, dx) => k <= 0 ? -1e9 : k >= 4 ? 1e9 : TOP + k * RY / 2 + 10 * (1 - Math.min(1, (dx / RX) ** 2));
  const SECTIONS = [];
  for (let row = 0; row < 4; row++) for (const side of [-1, 1]) {
    const top = [], bot = [];
    for (const e of EDGE) {
      const yt = Math.max(seam(row, e.dx), e.t), yb = Math.min(seam(row + 1, e.dx), e.b);
      if (yb - yt < 1) continue;
      top.push([CX + side * (e.dx + 1), yt]); bot.unshift([CX + side * (e.dx + 1), yb]);
    }
    const pts = top.concat(bot), maxDx = Math.max(...pts.map(p => Math.abs(p[0] - CX)));
    SECTIONS.push({ row, side, pts, hx: CX + side * maxDx, mid: TOP + (row + .5) * RY / 2 });
  }
  const ANG = 1.38;

  // ---------- endo por dentro (mesmas peças do modelo) ----------
  // caixa torácica: 5 anéis de aço e 6 hastes; a metade da frente abre como duas portas
  const CAGE = { R: 66, E: 9, ys: [112, 152, 192, 232, 272] }, CAGE_TOP = 112, CAGE_BOT = 272, MAXA = 1.38, HALF_W = CAGE.R;
  const BOX = { x: CX - 34, y: 126, w: 68, h: 48 };          // caixa de bateria no peito
  const HIP = { x: CX - 58, y: 298, w: 116, h: 38 };         // bloco de servos do quadril
  const UP_X = [CX - 24, CX, CX + 24], LO_X = [CX - 32, CX, CX + 32];  // de onde saem os cabos de cima e de baixo
  const CAMS = {
    intro: { x: CX, y: CY, z: 1 }, tapes: { x: CX, y: CY, z: 1 }, close: { x: CX, y: CY, z: 1 }, won: { x: CX, y: CY, z: 1 },
    chest: { x: CX - 20, y: 200, z: 1.6 }, chestClose: { x: CX - 20, y: 200, z: 1.6 }, wires: { x: CX - 26, y: 200, z: 2.1 }
  };
  const COLORS = [
    { id: "red", base: "#a31f2c", dark: "#6f1420", light: "#d23a48" },
    { id: "blue", base: "#2b56b8", dark: "#1f2b7c", light: "#4c66dc" },
    { id: "yellow", base: "#c9a227", dark: "#7d640f", light: "#f0d56a" }
  ];
  const P = { line: "#14151a", tape: "#1a1a1f", tapeLight: "#474c5a", tapeDark: "#08090c", base: "#a9b0bf", light: "#e4e8f0", shade: "#6c7283", gun: "#3b3f4b", gunLight: "#666b7b", black: "#16171c" };
  const GUN = [P.gunLight, P.gun, P.black];
  const STEP_INDEX = { intro: 0, tapes: 0, chest: 1, wires: 2, chestClose: 3, close: 4, won: 5 };
  const TOTAL = 4 + 2 + 3 + 2 + 8;
  const PENALTY = 2;
  const STEP_NAMES = ["Fitas", "Abrir o tórax", "Fios", "Fechar o tórax", "Seções"];

  M.register({
    id: "plastico", number: "02", name: "Plástico", note: "Fechar a barriga", short: "Barriga de plástico",
    keys: "Arrastar - clicar numa seção fecha - setas escolhem, Enter age",
    tip: "<b>Plástico:</b> feche a barriga do endo. Fio de cor errada solta faísca e custa " + PENALTY + " segundos.",
    create(root) {
      const canvas = document.createElement("canvas");
      canvas.className = "game-canvas";
      canvas.setAttribute("aria-label", "Barriga de plástico dividida em oito seções, com uma fita preta por fileira, com a caixa de costelas do endo e fios soltos por dentro");
      root.appendChild(canvas);
      const v = M.pixel(canvas, W, H, PX), ctx = v.ctx;
      const over = M.overlay(root);
      let phase = "intro", time = 0, sparksN = 0, done = 0, shake = 0, t = 0, focus = 0, keyFocus = false, drag = null;
      let sections = [], tapes = [], halves = [], ends = [], joints = [], flying = [], parts = [], pings = [];
      const cam = { x: CX, y: CY, z: 1 };
      let best = M.store.get("plastico-barriga");

      // ---------- montagem ----------
      // uma fita preta por fileira: atravessa a linha do meio e prende as duas abas (esquerda e direita)
      const makeTape = i => {
        const y = SECTIONS[i * 2].mid + 4, tilt = i % 2 ? 4 : -4;
        return { i, A: { x: CX - 62, y: y - tilt }, B: { x: CX + 62, y: y + tilt }, pull: { x: 0, y: 0 }, free: null, state: "on" };
      };
      // side -1: cabo de cima (sai da caixa de bateria e pende); side +1: cabo de baixo (sai do quadril e sobe)
      const makeEnd = (c, side, ax, ay) => {
        const hx = ax + M.rand(-3, 3), hy = side < 0 ? ay + 52 + M.rand(-5, 5) : ay - 44 + M.rand(-5, 5);
        return { c, side, ax, ay, hx, hy, x: hx, y: hy, state: "loose", seed: Math.random() * TAU };
      };
      const reset = () => {
        sections = SECTIONS.map(s => ({ ...s, ang: 0, tgt: 0, closedOnce: false }));
        tapes = [0, 1, 2, 3].map(makeTape);
        halves = [{ side: -1, hx: CX - CAGE.R, ang: 0, tgt: 0, openedOnce: false, closedOnce: false }, { side: 1, hx: CX + CAGE.R, ang: 0, tgt: 0, openedOnce: false, closedOnce: false }];
        const U = M.shuffle([0, 1, 2]); let Lo = M.shuffle([0, 1, 2]);
        while (Lo.every((c, i) => c === U[i])) Lo = M.shuffle([0, 1, 2]);
        ends = []; joints = COLORS.map((c, i) => ({ c: i, x: 0, y: 0, joined: false }));
        for (let r = 0; r < 3; r++) { ends[U[r] * 2] = makeEnd(U[r], -1, UP_X[r], BOX.y + BOX.h - 2); ends[Lo[r] * 2 + 1] = makeEnd(Lo[r], 1, LO_X[r], HIP.y + 2); }
        flying = []; parts = []; pings = [];
        time = 0; sparksN = 0; done = 0; shake = 0; focus = 0; keyFocus = false; drag = null;
        Object.assign(cam, CAMS.intro);
        phase = "intro";
        over.show("Fechar a barriga", "Arranque as fitas, abra a caixa e ligue os fios.", "Começar", () => { phase = "tapes"; over.hide(); });
      };
      const ping = (x, y, color) => pings.push({ x, y, color, age: 0 });
      const burst = (x, y, color, n = 10) => {
        for (let i = 0; i < n; i++) { const a = Math.random() * TAU, s = M.rand(40, 150); parts.push({ x, y, vx: Math.cos(a) * s, vy: Math.sin(a) * s - 30, life: M.rand(.25, .5), age: 0, color }); }
      };
      const advance = () => {
        if (phase === "tapes" && tapes.every(x => x.state === "gone")) phase = "chest";
        else if (phase === "chest" && halves.every(h => h.tgt > 0)) phase = "wires";
        else if (phase === "wires" && joints.every(j => j.joined)) phase = "chestClose";
        else if (phase === "chestClose" && halves.every(h => h.tgt === 0)) phase = "close";
        else return;
        focus = 0;
      };
      const win = () => {
        phase = "won"; drag = null;
        const total = time;
        if (!best || total < best.time) { best = { time: total, sparks: sparksN }; M.store.set("plastico-barriga", best); }
        over.show("Barriga fechada", "Tempo " + M.fmt(total) + " com " + sparksN + (sparksN === 1 ? " faísca." : " faíscas."), "Jogar de novo", reset, "soft");
      };

      // ---------- ações ----------
      const stopDrag = () => { drag = null; canvas.classList.remove("is-grabbing"); };
      const peel = i => {
        const tp = tapes[i]; if (!tp || tp.state === "gone") return;
        const { free } = tapeEnds(tp), dir = tp.free === "B" ? 1 : -1;
        tp.state = "gone"; tp.pull = { x: 0, y: 0 }; sections[i * 2].tgt = 1; sections[i * 2 + 1].tgt = 1; done++;
        flying.push({ x: free.x, y: free.y, vx: dir * 120 + M.rand(-20, 20), vy: -90, rot: 0, vr: M.rand(-5, 5), age: 0 });
        ping(free.x, free.y, "#dfe4e0"); shake = Math.max(shake, .25);
        advance();
      };
      const settleHalf = h => {
        h.tgt = h.ang > .7 ? MAXA : 0;
        if (phase === "chest" && h.tgt > 0 && !h.openedOnce) { h.openedOnce = true; done++; ping(h.hx, 192, "#bec9b5"); }
        if (phase === "chestClose" && h.tgt === 0 && !h.closedOnce) { h.closedOnce = true; done++; ping(h.hx, 192, "#8fd19e"); shake = Math.max(shake, .3); }
        advance();
      };
      const join = (c, at) => {
        const a = ends[c * 2], b = ends[c * 2 + 1], j = joints[c];
        if (j.joined) return;
        const m = at || b;
        j.joined = true; j.x = m.x; j.y = m.y;
        a.state = b.state = "joined"; done++;
        ping(j.x, j.y, "#8fd19e"); burst(j.x, j.y, "#f2c96a", 8); shake = Math.max(shake, .15);
        advance();
      };
      const wrong = (e, o) => {
        sparksN++; time += PENALTY; shake = Math.max(shake, .5);
        const x = (e.x + o.x) / 2, y = (e.y + o.y) / 2;
        burst(x, y, "#f2c96a", 14); burst(x, y, "#e0605a", 8);
        e.state = "loose"; stopDrag();
      };
      const closeSection = i => {
        const s = sections[i];
        if (phase !== "close" || s.tgt === 0) return;
        s.tgt = 0; s.closedOnce = true; done++; shake = Math.max(shake, .3);
        ping(s.hx, s.mid, "#8fd19e");
      };

      // ---------- geometria ----------
      const secPts = s => { const c = Math.cos(s.ang * ANG); return s.pts.map(p => [s.hx + (p[0] - s.hx) * c, p[1]]); };
      const tapeEnds = tp => {
        const A = { x: tp.A.x + (tp.free === "A" ? tp.pull.x : 0), y: tp.A.y + (tp.free === "A" ? tp.pull.y : 0) };
        const B = { x: tp.B.x + (tp.free === "B" ? tp.pull.x : 0), y: tp.B.y + (tp.free === "B" ? tp.pull.y : 0) };
        return { A, B, free: tp.free === "B" ? B : A, fixed: tp.free === "B" ? A : B };
      };
      const tapeHit = (tp, p) => {
        const { A, B } = tapeEnds(tp), dx = B.x - A.x, dy = B.y - A.y, L = Math.hypot(dx, dy), ux = dx / L, uy = dy / L;
        const a = (p.x - A.x) * ux + (p.y - A.y) * uy, b = -(p.x - A.x) * uy + (p.y - A.y) * ux;
        return a > -8 && a < L + 8 && Math.abs(b) < 13;
      };
      const halfEdge = h => h.hx - h.side * HALF_W * Math.cos(h.ang);
      const toWorld = p => ({ x: cam.x + (p.x - cam.x) / cam.z, y: cam.y + (p.y - cam.y) / cam.z });
      // Qual porta está sob o mouse? Vale a mais próxima (esquerda e direita têm o mesmo direito de abrir primeiro),
      // então clicar nas hastes do meio pega a porta do lado em que o clique caiu.
      const doorAt = p => {
        if (p.y < CAGE_TOP - 12 || p.y > CAGE_BOT + 12) return -1;
        let pick = -1, best = 1e9, tie = 1e9;
        halves.forEach((h, i) => {
          const e = halfEdge(h), a = Math.min(h.hx, e), b = Math.max(h.hx, e);
          const d = p.x < a ? a - p.x : p.x > b ? p.x - b : 0, c = Math.abs(p.x - (a + b) / 2);
          if (d < best || (d === best && c < tie)) { best = d; tie = c; pick = i; }
        });
        return best <= 9 ? pick : -1;
      };
      const endHit = p => ends.findIndex(e => e.state === "loose" && Math.hypot(p.x - e.x, p.y - e.y) < 14);
      const secHit = (s, p) => { if (s.tgt === 0) return false; const q = secPts(s), xs = q.map(a => a[0]), ys = q.map(a => a[1]); return p.x >= Math.min(...xs) - 12 && p.x <= Math.max(...xs) + 12 && p.y >= Math.min(...ys) && p.y <= Math.max(...ys); };

      // ---------- alvos do teclado ----------
      const targets = () => {
        const out = [];
        if (phase === "tapes") tapes.forEach((tp, i) => { if (tp.state !== "gone") { const { A, B } = tapeEnds(tp); out.push({ x: (A.x + B.x) / 2, y: (A.y + B.y) / 2, press: () => peel(i) }); } });
        else if (phase === "chest" || phase === "chestClose") halves.forEach(h => { if (phase === "chest" ? h.tgt === 0 : h.tgt > 0) out.push({ x: h.hx - h.side * HALF_W / 2, y: 192, press: () => { h.ang = phase === "chest" ? MAXA : 0; settleHalf(h); } }); });
        else if (phase === "wires") joints.forEach((j, c) => { if (!j.joined) out.push({ x: ends[c * 2].x, y: ends[c * 2].y, press: () => join(c) }); });
        else if (phase === "close") sections.forEach((s, i) => { if (s.tgt > 0) out.push({ x: s.hx, y: s.mid, press: () => closeSection(i) }); });
        return out;
      };

      // ---------- atualização ----------
      const update = dt => {
        t += dt; shake = Math.max(0, shake - dt * 2.4);
        pings = pings.filter(p => (p.age += dt) < .6);
        if (phase !== "intro" && phase !== "won") time += dt;
        const g = CAMS[phase], kc = 1 - Math.exp(-dt * 4);
        cam.x += (g.x - cam.x) * kc; cam.y += (g.y - cam.y) * kc; cam.z += (g.z - cam.z) * kc;
        const k = 1 - Math.exp(-dt * 9);
        sections.forEach(s => { s.ang += (s.tgt - s.ang) * k; if (Math.abs(s.tgt - s.ang) < .004) s.ang = s.tgt; });
        halves.forEach((h, i) => {
          if (drag && drag.type === "half" && drag.i === i) return;
          h.ang += (h.tgt - h.ang) * k; if (Math.abs(h.tgt - h.ang) < .004) h.ang = h.tgt;
        });
        tapes.forEach(tp => {
          if (tp.state === "gone" || (drag && drag.type === "peel" && drag.i === tp.i)) return;
          tp.pull.x *= Math.exp(-dt * 14); tp.pull.y *= Math.exp(-dt * 14);
        });
        flying = flying.filter(f => { f.age += dt; f.vy += 700 * dt; f.x += f.vx * dt; f.y += f.vy * dt; f.rot += f.vr * dt; return f.age < 1.1; });
        parts = parts.filter(q => { q.age += dt; q.vy += 260 * dt; q.x += q.vx * dt; q.y += q.vy * dt; return q.age < q.life; });
        const kk = 1 - Math.exp(-dt * 16);
        ends.forEach(e => {
          if (e.state === "loose") { e.x += (e.hx - e.x) * kk; e.y += (e.hy - e.y) * kk; }
          else if (e.state === "joined") { const j = joints[e.c]; e.x += (j.x - e.x) * kk; e.y += (j.y - e.y) * kk; }
        });
        if (phase === "close" && sections.every(s => s.closedOnce) && sections.every(s => s.ang < .03)) win();

        const peeled = tapes.filter(x => x.state === "gone").length;
        const opened = halves.filter(h => h.openedOnce).length, closedH = halves.filter(h => h.closedOnce).length;
        const joined = joints.filter(j => j.joined).length, shut = sections.filter(s => s.closedOnce).length;
        const step = Math.min(4, STEP_INDEX[phase]);
        M.hud.set([
          ["Etapa", (step + 1) + " de 5 · " + STEP_NAMES[step]],
          ["Fitas tiradas", peeled + " de 4"],
          ["Tórax", phase === "chestClose" || phase === "close" || phase === "won" ? closedH + " de 2 fechadas" : opened + " de 2 abertas"],
          ["Fios ligados", joined + " de 3"],
          ["Seções fechadas", shut + " de 8"],
          ["Faíscas", String(sparksN)],
          ["Tempo", M.fmt(time)],
          ["Melhor", best ? M.fmt(best.time) + " / " + best.sparks + (best.sparks === 1 ? " faísca" : " faíscas") : "-"]
        ], { label: "Progresso", value: done / TOTAL, tone: "good" });
      };

      // ---------- desenho ----------
      const path = (pts, close = true) => { ctx.beginPath(); pts.forEach((p, i) => ctx[i ? "lineTo" : "moveTo"](p[0], p[1])); if (close) ctx.closePath(); };
      const gradient = (x0, y0, x1, y1, stops) => { const g = ctx.createLinearGradient(x0, y0, x1, y1); stops.forEach(([o, c]) => g.addColorStop(o, c)); return g; };
      // sombreamento em três faixas duras, como o "material" do modelo
      const banded = (x, y, w, h, c) => gradient(x, y, x + w * 1.1, y + h, [[0, c[0]], [.23, c[0]], [.23, c[1]], [.82, c[1]], [.82, c[2]], [1, c[2]]]);
      const rivet = (x, y, r = 3.5) => {
        ctx.beginPath(); ctx.arc(x, y, r, 0, TAU); ctx.fillStyle = "#8a90a0"; ctx.fill(); ctx.lineWidth = 3; ctx.strokeStyle = P.line; ctx.stroke();
        ctx.beginPath(); ctx.arc(x - r * .3, y - r * .3, r * .35, 0, TAU); ctx.fillStyle = "#e6e9f2"; ctx.fill();
      };
      const bar = (pts, outline, core, hi) => {
        ctx.lineCap = "round"; ctx.lineJoin = "round";
        path(pts, false); ctx.strokeStyle = P.line; ctx.lineWidth = outline; ctx.stroke();
        ctx.strokeStyle = core; ctx.lineWidth = outline - 5; ctx.stroke();
        if (hi) { path(pts.map(p => [p[0] - 1.3, p[1] - 1.6]), false); ctx.strokeStyle = hi; ctx.lineWidth = 1.8; ctx.stroke(); }
        ctx.lineCap = "butt";
      };
      const arc = (yh, a0, a1, n = 14) => { const pts = []; for (let k = 0; k <= n; k++) { const f = a0 + (a1 - a0) * k / n; pts.push([CX + CAGE.R * Math.sin(f), yh + CAGE.E * Math.cos(f)]); } return pts; };

      // cabo solto: sai de dentro da caixa de bateria (ou do quadril) e termina numa ponta descascada
      const wire = (c, ax, ay, ex, ey, taut, seed) => {
        const k = COLORS[c], sway = taut ? 0 : Math.sin(t * 2 + seed) * 2;
        const qx = ax + (ex - ax) * .2 + sway, qy = ay + (ey - ay) * .7;
        const run = (col, w, ox = 0, oy = 0) => { ctx.beginPath(); ctx.moveTo(ax + ox, ay + oy); ctx.quadraticCurveTo(qx + ox, qy + oy, ex + ox, ey + oy); ctx.strokeStyle = col; ctx.lineWidth = w; ctx.lineCap = "round"; ctx.stroke(); };
        run(P.line, 10); run(k.dark, 7); run(k.base, 5); run(k.light, 2, -1.2, -1.2);
        if (!taut) {
          const ux0 = ex - qx, uy0 = ey - qy, n = Math.hypot(ux0, uy0) || 1, ux = ux0 / n, uy = uy0 / n;
          ctx.beginPath(); ctx.moveTo(ex - ux * 8, ey - uy * 8); ctx.lineTo(ex + ux * 5, ey + uy * 5); ctx.strokeStyle = P.line; ctx.lineWidth = 9; ctx.stroke();
          ctx.beginPath(); ctx.moveTo(ex - ux * 7, ey - uy * 7); ctx.lineTo(ex + ux * 4, ey + uy * 4); ctx.strokeStyle = "#a9b0bf"; ctx.lineWidth = 5; ctx.stroke();
          ctx.beginPath(); ctx.moveTo(ex - ux * 7 - 1, ey - uy * 7); ctx.lineTo(ex + ux * 4 - 1, ey + uy * 4); ctx.strokeStyle = "#eef0f8"; ctx.lineWidth = 1.8; ctx.stroke();
        }
        ctx.lineCap = "butt";
      };

      const tapeBand = (B, F, wid, alpha = 1) => {
        const dx = F.x - B.x, dy = F.y - B.y, L = Math.hypot(dx, dy) || 1, ux = dx / L, uy = dy / L, nx = -uy * wid / 2, ny = ux * wid / 2;
        ctx.save(); ctx.globalAlpha = alpha;
        path([[B.x + nx, B.y + ny], [F.x + nx, F.y + ny], [F.x + ux * 3 + nx * .5, F.y + uy * 3 + ny * .5], [F.x - nx * .2, F.y - ny * .2], [F.x + ux * 3 - nx * .5, F.y + uy * 3 - ny * .5], [F.x - nx, F.y - ny], [B.x - nx, B.y - ny]]);
        ctx.fillStyle = P.tape; ctx.fill(); ctx.lineWidth = 3; ctx.strokeStyle = P.tapeDark; ctx.lineJoin = "round"; ctx.stroke();
        path([[B.x + nx * .9, B.y + ny * .9], [F.x + nx * .9, F.y + ny * .9], [F.x + nx * .2, F.y + ny * .2], [B.x + nx * .2, B.y + ny * .2]]);
        ctx.fillStyle = P.tapeLight; ctx.globalAlpha = alpha * .7; ctx.fill();
        ctx.restore();
      };

      // uma porta da caixa torácica: metade da frente dos anéis e das hastes, presa na lateral
      const door = h => {
        const c = Math.cos(h.ang), s = h.side, R = CAGE.R;
        const X = xr => h.hx - s * (s < 0 ? xr + R : R - xr) * c;      // xr: posição relativa ao centro da caixa
        const pt = (xr, y) => [X(xr), y];
        // anéis (metade da frente: curvam para baixo no meio)
        CAGE.ys.forEach(yh => {
          const pts = []; for (let k = 0; k <= 12; k++) { const f = s * (Math.PI / 2) * (1 - k / 12); pts.push(pt(R * Math.sin(f), yh + CAGE.E * Math.cos(f))); }
          bar(pts, 12, "#c3cad8", "#eef0f8");
        });
        // haste de fora e haste da borda livre (juntas, no meio, parecem uma haste só)
        for (const [xr, off] of [[s * R * .87, CAGE.E * .5], [s * 4, CAGE.E]]) {
          bar([pt(xr, CAGE_TOP + off), pt(xr, CAGE_BOT + off)], 11, xr === s * 4 ? "#b3bac8" : "#c3cad8", "#eef0f8");
          CAGE.ys.forEach(yh => rivet(X(xr), yh + off, 3));
        }
      };

      const interior = () => {
        path(EGG); ctx.fillStyle = gradient(0, TOP, 0, BOT, [[0, "#0d0e13"], [1, "#1a1a1f"]]); ctx.fill();
        ctx.save(); path(EGG); ctx.clip();
        const R = CAGE.R;
        // metade de trás da caixa: anéis e hastes escuros
        CAGE.ys.forEach(yh => bar(arc(yh, Math.PI / 2, Math.PI * 1.5), 10, "#545968"));
        for (const f of [Math.PI * 2 / 3, Math.PI, Math.PI * 4 / 3]) { const x = CX + R * Math.sin(f), o = CAGE.E * Math.cos(f); bar([[x, CAGE_TOP + o], [x, CAGE_BOT + o]], 9, "#545968"); }
        // coluna com vértebras
        bar([[CX, 98], [CX, HIP.y + 4]], 12, P.base, "rgba(255,255,255,.5)");
        for (let y = 120; y <= 290; y += 18) { ctx.beginPath(); ctx.ellipse(CX, y, 11, 4, 0, 0, TAU); ctx.fillStyle = P.gun; ctx.fill(); ctx.lineWidth = 3; ctx.strokeStyle = P.line; ctx.stroke(); }
        // cabos: as raízes ficam escondidas atrás da caixa de bateria e do quadril
        ends.forEach(e => wire(e.c, e.ax, e.ay, e.x, e.y, e.state === "joined", e.seed));
        // emenda: luva de metal onde os dois fios se encontram
        joints.forEach(j => {
          if (!j.joined) return;
          ctx.beginPath(); ctx.roundRect(j.x - 6, j.y - 10, 12, 20, 4); ctx.fillStyle = banded(j.x - 6, j.y - 10, 12, 20, [P.light, P.base, P.shade]); ctx.fill(); ctx.lineWidth = 3; ctx.strokeStyle = P.line; ctx.stroke();
          ctx.strokeStyle = "rgba(20,21,26,.55)"; ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(j.x - 6, j.y); ctx.lineTo(j.x + 6, j.y); ctx.stroke();
        });
        // quadril: bloco de servos escuros
        ctx.beginPath(); ctx.roundRect(HIP.x, HIP.y, HIP.w, HIP.h, 8); ctx.fillStyle = banded(HIP.x, HIP.y, HIP.w, HIP.h, GUN); ctx.fill(); ctx.lineWidth = 4; ctx.strokeStyle = P.line; ctx.stroke();
        for (const dx of [-38, 38]) { ctx.beginPath(); ctx.arc(CX + dx, HIP.y + HIP.h / 2 + 2, 11, 0, TAU); ctx.fillStyle = "#30333d"; ctx.fill(); ctx.lineWidth = 3; ctx.strokeStyle = P.line; ctx.stroke(); rivet(CX + dx, HIP.y + HIP.h / 2 + 2, 3.5); }
        rivet(HIP.x + 10, HIP.y + 9, 3); rivet(HIP.x + HIP.w - 10, HIP.y + 9, 3);
        // caixa de bateria no peito, com engrenagem e LED
        ctx.beginPath(); ctx.roundRect(BOX.x, BOX.y, BOX.w, BOX.h, 7); ctx.fillStyle = banded(BOX.x, BOX.y, BOX.w, BOX.h, GUN); ctx.fill(); ctx.lineWidth = 4; ctx.strokeStyle = P.line; ctx.stroke();
        const gx = CX, gy = BOX.y + 31;
        ctx.beginPath(); for (let k = 0; k < 24; k++) { const a = k / 24 * TAU, rr = k % 2 ? 9 : 13; ctx.lineTo(gx + Math.cos(a) * rr, gy + Math.sin(a) * rr); } ctx.closePath();
        ctx.fillStyle = "#30333d"; ctx.fill(); ctx.lineWidth = 2.5; ctx.strokeStyle = "#8a90a0"; ctx.stroke(); rivet(gx, gy, 3);
        const led = ctx.createRadialGradient(gx, BOX.y + 11, 1, gx, BOX.y + 11, 14); led.addColorStop(0, "rgba(255,179,71,.55)"); led.addColorStop(1, "rgba(255,179,71,0)");
        ctx.fillStyle = led; ctx.beginPath(); ctx.arc(gx, BOX.y + 11, 14, 0, TAU); ctx.fill();
        ctx.beginPath(); ctx.arc(gx, BOX.y + 11, 3.6, 0, TAU); ctx.fillStyle = "#ffb347"; ctx.fill(); ctx.lineWidth = 2.5; ctx.strokeStyle = P.line; ctx.stroke();
        rivet(BOX.x + 8, BOX.y + BOX.h - 8, 2.8); rivet(BOX.x + BOX.w - 8, BOX.y + BOX.h - 8, 2.8);
        // portas da frente da caixa torácica e dobradiças fixas
        halves.forEach(door);
        for (const x of [CX - R, CX + R]) CAGE.ys.forEach(yh => rivet(x, yh, 4.5));
        // pescoço e barra dos ombros
        bar([[CX, 46], [CX, 100]], 13, P.base, "rgba(255,255,255,.5)");
        ctx.beginPath(); ctx.arc(CX, 62, 9, 0, TAU); ctx.fillStyle = banded(CX - 9, 53, 18, 18, [P.light, P.base, P.shade]); ctx.fill(); ctx.lineWidth = 3; ctx.strokeStyle = P.line; ctx.stroke();
        bar([[CX - 90, 98], [CX + 90, 98]], 17, P.base, "#eef0f8");
        ctx.beginPath(); ctx.roundRect(CX - 16, 90, 32, 18, 5); ctx.fillStyle = banded(CX - 16, 90, 32, 18, [P.light, P.base, P.shade]); ctx.fill(); ctx.lineWidth = 3; ctx.strokeStyle = P.line; ctx.stroke(); rivet(CX, 99, 3);
        ctx.restore();
        path(EGG); ctx.lineWidth = 5; ctx.strokeStyle = "#6c7283"; ctx.stroke();
      };

      const shell = () => {
        const shade = ctx.createRadialGradient(CX - 40, 110, 12, CX + 6, 240, 250);
        shade.addColorStop(0, "#f8f9fd"); shade.addColorStop(.35, "#e4e8f0"); shade.addColorStop(.7, "#c3cad8"); shade.addColorStop(1, "#8a90a0");
        sections.forEach(s => {
          const pts = secPts(s), back = s.ang * ANG > 1.05;
          path(pts); ctx.fillStyle = back ? "#6c7283" : shade; ctx.fill();
          ctx.lineWidth = 3.5; ctx.strokeStyle = back ? P.line : "#3b3f4b"; ctx.lineJoin = "round"; ctx.stroke();
        });
      };

      const tapesDraw = () => {
        tapes.forEach(tp => {
          if (tp.state === "gone") return;
          const { A, B, free } = tapeEnds(tp);
          tapeBand(A, B, 16);
          if (tp.pull.x * tp.pull.x + tp.pull.y * tp.pull.y > 16) { ctx.beginPath(); ctx.arc(free.x, free.y, 5, 0, TAU); ctx.fillStyle = "#3b3f4b"; ctx.fill(); ctx.lineWidth = 3; ctx.strokeStyle = P.tapeDark; ctx.stroke(); }
        });
        flying.forEach(f => {
          const ux = Math.cos(f.rot) * 30, uy = Math.sin(f.rot) * 30;
          tapeBand({ x: f.x - ux * 1.5, y: f.y - uy * 1.5 }, { x: f.x + ux * 1.5, y: f.y + uy * 1.5 }, 16, Math.max(0, 1 - f.age / 1.1));
        });
      };

      const draw = () => {
        v.begin();
        const bg = ctx.createRadialGradient(320, 210, 40, 320, 210, 340);
        bg.addColorStop(0, "#2f4047"); bg.addColorStop(1, "#1f2b30");
        ctx.fillStyle = bg; ctx.fillRect(-40, -40, W + 80, H + 80);
        ctx.save();
        if (shake > 0) ctx.translate((Math.random() - .5) * 8 * shake, (Math.random() - .5) * 8 * shake);
        ctx.translate(cam.x, cam.y); ctx.scale(cam.z, cam.z); ctx.translate(-cam.x, -cam.y);
        interior(); shell(); tapesDraw();
        for (const p of pings) { ctx.beginPath(); ctx.arc(p.x, p.y, 8 + p.age * 70, 0, TAU); ctx.strokeStyle = p.color; ctx.globalAlpha = 1 - p.age / .6; ctx.lineWidth = 4; ctx.stroke(); ctx.globalAlpha = 1; }
        for (const q of parts) { ctx.globalAlpha = 1 - q.age / q.life; ctx.fillStyle = q.color; ctx.fillRect(q.x - 2, q.y - 2, 5, 5); ctx.globalAlpha = 1; }
        if (keyFocus) {
          const list = targets();
          if (list.length) { const tg = list[focus % list.length]; ctx.beginPath(); ctx.arc(tg.x, tg.y, 24, 0, TAU); ctx.setLineDash([7, 7]); ctx.strokeStyle = "#f2c96a"; ctx.lineWidth = 3; ctx.stroke(); ctx.setLineDash([]); }
        }
        ctx.restore();

        v.finish();
      };

      // ---------- entrada ----------
      canvas.addEventListener("pointerdown", ev => {
        if (over.visible || phase === "intro" || phase === "won") return;
        keyFocus = false;
        const p = toWorld(v.point(ev));
        if (phase === "tapes") {
          for (let i = tapes.length - 1; i >= 0; i--) if (tapes[i].state === "on" && tapeHit(tapes[i], p)) { const tp = tapes[i]; tp.free = Math.hypot(p.x - tp.A.x, p.y - tp.A.y) < Math.hypot(p.x - tp.B.x, p.y - tp.B.y) ? "A" : "B"; drag = { type: "peel", i, id: ev.pointerId, sx: p.x, sy: p.y }; break; }
        } else if (phase === "chest" || phase === "chestClose") {
          const i = doorAt(p); if (i >= 0) drag = { type: "half", i, id: ev.pointerId, off: halfEdge(halves[i]) - p.x };
        } else if (phase === "wires") {
          const i = endHit(p);
          if (i >= 0) { ends[i].state = "held"; drag = { type: "end", i, id: ev.pointerId, dx: ends[i].x - p.x, dy: ends[i].y - p.y }; }
        } else if (phase === "close") {
          const i = sections.findIndex(s => secHit(s, p));
          if (i >= 0) closeSection(i);
        }
        if (drag) { canvas.setPointerCapture(ev.pointerId); canvas.classList.add("is-grabbing"); }
      });
      canvas.addEventListener("pointermove", ev => {
        const p = toWorld(v.point(ev));
        if (!drag) {
          let hot = false;
          if (phase === "tapes") hot = tapes.some(tp => tp.state === "on" && tapeHit(tp, p));
          else if (phase === "chest" || phase === "chestClose") hot = doorAt(p) >= 0;
          else if (phase === "wires") hot = endHit(p) >= 0;
          else if (phase === "close") hot = sections.some(s => secHit(s, p));
          canvas.style.cursor = hot ? "grab" : "";
          return;
        }
        if (ev.pointerId !== drag.id) return;
        if (drag.type === "peel") {
          const tp = tapes[drag.i], dx = p.x - drag.sx, dy = p.y - drag.sy, d = Math.hypot(dx, dy), cap = Math.min(d, 78) / (d || 1);
          tp.pull = { x: dx * cap, y: dy * cap };
          if (d >= 46) { const i = tp.i; stopDrag(); peel(i); }
        } else if (drag.type === "half") {
          const h = halves[drag.i], c = M.clamp(h.side < 0 ? (p.x + drag.off - h.hx) / HALF_W : (h.hx - (p.x + drag.off)) / HALF_W);
          h.ang = Math.min(MAXA, Math.acos(c));
        } else if (drag.type === "end") {
          const e = ends[drag.i];
          e.x = M.clamp(p.x + drag.dx, CX - 60, CX + 60); e.y = M.clamp(p.y + drag.dy, BOX.y + BOX.h + 8, HIP.y - 6);
          const mate = ends[drag.i ^ 1];
          if (mate.state === "loose" && Math.hypot(e.x - mate.x, e.y - mate.y) < 18) { join(e.c, { x: mate.x, y: mate.y }); stopDrag(); return; }
        }
      });
      const release = ev => {
        if (!drag || (ev && ev.pointerId !== drag.id)) return;
        const d = drag; stopDrag();
        if (d.type === "half") settleHalf(halves[d.i]);
        else if (d.type === "end") {
          // passar perto de outro fio não faz nada: só soltar a ponta em cima de um fio de cor errada solta faísca
          const e = ends[d.i], mate = ends[d.i ^ 1];
          if (e.state !== "held") return;
          const other = ends.find(o => o !== e && o !== mate && o.state === "loose" && Math.hypot(e.x - o.x, e.y - o.y) < 16);
          if (other) wrong(e, other); else e.state = "loose";
        }
      };
      canvas.addEventListener("pointerup", release);
      canvas.addEventListener("pointercancel", release);

      reset();
      return {
        exportState: () => ({ schema: "zip-v1", game: "plastico", phase, sections, tapes, halves, ends, joints, done, time, sparksN, cam }),
        restoreState(s) {
          if (!s || s.schema !== "zip-v1" || s.game !== "plastico" || !Array.isArray(s.sections) || !Array.isArray(s.ends) || s.phase === "intro") return false;
          sections = s.sections; tapes = s.tapes; halves = s.halves; ends = s.ends; joints = s.joints;
          done = s.done || 0; time = s.time || 0; sparksN = s.sparksN || 0; phase = s.phase;
          if (s.cam) Object.assign(cam, s.cam);
          ends.forEach(e => { if (e.state === "held") e.state = "loose"; });
          flying = []; parts = []; pings = []; drag = null; focus = 0; keyFocus = false; shake = 0;
          over.hide(); return true;
        },
        reset,
        activate() { v.resize(); },
        deactivate() { drag = null; canvas.classList.remove("is-grabbing"); },
        update,
        draw,
        state: () => ({ phase, sections, tapes, halves, ends, joints, done, time, sparksN, cam, CAGE }),
        keydown(ev) {
          if (over.visible || phase === "intro" || phase === "won") return false;
          const key = ev.key, list = targets();
          if (key === "ArrowRight" || key === "ArrowDown") { keyFocus = true; if (list.length) focus = (focus + 1) % list.length; return true; }
          if (key === "ArrowLeft" || key === "ArrowUp") { keyFocus = true; if (list.length) focus = (focus - 1 + list.length) % list.length; return true; }
          if (key === "Enter" || key === " ") {
            keyFocus = true;
            if (!list.length) return true;
            const tg = list[focus % list.length];
            if (tg.press && !ev.repeat) { tg.press(); focus = Math.min(focus, Math.max(0, targets().length - 1)); }
            return true;
          }
          return false;
        },
        keyup() {}
      };
    }
  });
})();
