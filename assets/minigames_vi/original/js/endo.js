(() => {
  "use strict";
  const M = window.Mini;
  const W = 640, H = 420, PX = 3, TAU = M.TAU, RAD = M.RAD;
  const S = .84, SS = .75, R = 36 * S, SAFE = 52, TOL = 3, HOLD = .5, FLOOR = 380, TICK = 6, DROP_COST = 4;
  const FX = 320, FY = 196, U = 9.0;   // centro do crânio e "pixel" do modelo
  const SOCKETS = [-1, 1].map(side => ({ x: Math.round(FX + side * 5.86 * U), y: Math.round(FY - 3.02 * U) }));
  const HOMES = [{ x: 225, y: 380 }, { x: 415, y: 380 }];
  const TARGETS = [-165, -135, -105, -75, -45, -15, 15, 45, 75, 105, 135, 165];
  const C = { line: "#14151a", light: "#e4e8f0", base: "#a9b0bf", shade: "#6c7283", metal: "#30333d", gold: "#c9a227", goldLight: "#f0d56a", socket: "#0d0e13" };

  M.register({
    id: "endo", number: "01", name: "Endo", note: "Instalar os olhos", short: "Olhos de bola",
    keys: "Arrastar o olho da bandeja até a órbita - arrastar em volta dele ou setas / A D para girar - W S troca de olho - E encaixa - M som",
    tip: "<b>Endo:</b> a cabeça de aço está sem os olhos. Arraste cada olho até uma órbita e gire devagar, ouvindo os cliques: o “tec” é a posição certa. Girar rápido solta o encaixe, o olho cai, custa " + DROP_COST + " segundos e abala o outro olho.",
    create(root) {
      const canvas = document.createElement("canvas");
      canvas.className = "game-canvas";
      canvas.setAttribute("aria-label", "Cabeça do endo com duas órbitas vazias e dois olhos na bandeja");
      root.appendChild(canvas);
      const v = M.pixel(canvas, W, H, PX), ctx = v.ctx;
      const over = M.overlay(root);
      let look = null;
      // Sem marca visual da posição certa: o jogador escuta. Ao girar, cliques leves ("tisc"); na posição certa, um "tec".
      const sfx = {
        ac: null, on: true, last: 0, noise: null,
        ready() {
          if (!this.on) return false;
          if (!this.ac) {
            const AC = window.AudioContext || window.webkitAudioContext; if (!AC) return false;
            this.ac = new AC();
            const n = Math.floor(this.ac.sampleRate * .03), b = this.ac.createBuffer(1, n, this.ac.sampleRate), d = b.getChannelData(0);
            for (let i = 0; i < n; i++) d[i] = Math.random() * 2 - 1;
            this.noise = b;
          }
          if (this.ac.state === "suspended") this.ac.resume();
          return true;
        },
        tick() {
          if (!this.ready()) return;
          const ac = this.ac, now = ac.currentTime;
          if (now - this.last < .03) return;
          this.last = now;
          const src = ac.createBufferSource(), hp = ac.createBiquadFilter(), g = ac.createGain();
          src.buffer = this.noise; src.playbackRate.value = .9 + Math.random() * .4;
          hp.type = "highpass"; hp.frequency.value = 3200 + Math.random() * 900;
          g.gain.setValueAtTime(.05, now); g.gain.exponentialRampToValueAtTime(.001, now + .022);
          src.connect(hp); hp.connect(g); g.connect(ac.destination); src.start(now); src.stop(now + .03);
        },
        click(at, freq, vol, len = .07) {
          const ac = this.ac, o = ac.createOscillator(), g = ac.createGain(), th = ac.createOscillator(), tg = ac.createGain();
          o.type = "triangle"; o.frequency.setValueAtTime(freq, at); o.frequency.exponentialRampToValueAtTime(freq * .4, at + len * .7);
          g.gain.setValueAtTime(vol, at); g.gain.exponentialRampToValueAtTime(.001, at + len);
          th.type = "sine"; th.frequency.value = 210; tg.gain.setValueAtTime(vol * .75, at); tg.gain.exponentialRampToValueAtTime(.001, at + len * .9);
          o.connect(g); g.connect(ac.destination); th.connect(tg); tg.connect(ac.destination);
          o.start(at); o.stop(at + len + .02); th.start(at); th.stop(at + len + .02);
        },
        tec() { if (this.ready()) this.click(this.ac.currentTime, 1900, .16); },
        latch() { if (!this.ready()) return; const n = this.ac.currentTime; this.click(n, 1900, .16); this.click(n + .075, 1250, .14, .09); }
      };
      let eyes = [], sockets = [], active = -1, phase = "intro", time = 0, falls = 0, shake = 0, t = 0, drag = null, keyDir = 0, keyHold = 0, pings = [];
      let best = M.store.get("endo");

      // Olhar mecânico: servos de velocidade constante que param seco em posições fixas, com um leve tremor enquanto andam.
      // Raramente os dois olhos param no centro (olhando para quem joga) e a pupila dilata.
      const GAZE_X = [-1, -.6, -.2, .2, .6, 1], GAZE_Y = [-.8, -.3, 0, .3, .8];
      const lookInit = () => { look = { mode: "scan", wait: .6, next: M.rand(8, 12), stare: 0, tx: 0, ty: 0, pupil: 1, eyes: [{ x: 0, y: 0, mv: false, v: 7.5 }, { x: 0, y: 0, mv: false, v: 6 }] }; };
      const gazeStep = dt => {
        const L = look;
        if (L.mode === "stare") {
          L.stare -= dt; L.tx = 0; L.ty = 0;
          if (L.stare <= 0) { L.mode = "scan"; L.wait = .5; L.next = M.rand(14, 28); }
        } else {
          L.next -= dt; L.wait -= dt;
          if (L.next <= 0) { L.mode = "stare"; L.stare = M.rand(2, 3.2); }
          else if (L.wait <= 0) {
            let nx, ny;
            do { nx = M.pick(GAZE_X); ny = M.pick(GAZE_Y); } while (nx === L.tx && ny === L.ty);
            L.tx = nx; L.ty = ny; L.wait = Math.random() < .3 ? M.rand(.15, .35) : M.rand(.7, 2.2);
          }
        }
        let centered = true;
        for (const g of L.eyes) {
          const dx = L.tx - g.x, dy = L.ty - g.y, step = g.v * dt;
          g.mv = Math.abs(dx) > 1e-3 || Math.abs(dy) > 1e-3;
          g.x = Math.abs(dx) <= step ? L.tx : g.x + Math.sign(dx) * step;
          g.y = Math.abs(dy) <= step * .8 ? L.ty : g.y + Math.sign(dy) * step * .8;
          if (Math.abs(g.x) > .02 || Math.abs(g.y) > .02) centered = false;
        }
        const goal = L.mode === "stare" && centered ? 1.8 : 1;
        L.pupil += (goal - L.pupil) * (1 - Math.exp(-dt * (goal > L.pupil ? 6 : 9)));
        eyes.forEach((e, i) => { const g = L.eyes[i]; e.gx = g.x; e.gy = g.y; e.gm = g.mv; e.gp = L.pupil; });
      };

      const reset = () => {
        lookInit();
        const first = M.pick(TARGETS);
        let second = M.pick(TARGETS);
        while (Math.abs(M.wrap(second - first)) < 50) second = M.pick(TARGETS);
        sockets = SOCKETS.map((s, i) => ({ x: s.x, y: s.y, target: i ? second : first, eye: -1, locked: false }));
        eyes = HOMES.map(h => ({ state: "tray", x: h.x, y: h.y, home: h, angle: M.rand(-180, 180), prev: 0, speed: 0, tension: 0, hold: 0, lit: 0, socket: -1, fall: null }));
        eyes.forEach(e => { e.prev = e.angle; });
        active = -1; phase = "intro"; time = 0; falls = 0; shake = 0; drag = null; keyDir = 0; keyHold = 0; pings = [];
        over.show("Instalar os olhos", "Gire devagar e escute: o “tec” é a posição certa. Girar rápido derruba o olho.", "Começar", () => { phase = "play"; over.hide(); });
      };
      const ping = (x, y, color) => pings.push({ x, y, color, age: 0 });
      const place = (i, j) => {
        const e = eyes[i], s = sockets[j];
        e.state = "socket"; e.socket = j; s.eye = i; e.x = s.x; e.y = s.y;
        if (Math.abs(M.wrap(e.angle - s.target)) < 60) e.angle = s.target + M.rand(80, 160) * (Math.random() < .5 ? -1 : 1);
        e.prev = e.angle; e.speed = 0; e.tension = 0; e.hold = 0; e.inWin = false; e.tickAcc = 0; e.snap = 0; active = i;
        ping(s.x, s.y, "#bec9b5");
      };
      const emptySocket = (x, y, r) => {
        let hit = -1, d0 = r;
        sockets.forEach((s, j) => { const d = Math.hypot(x - s.x, y - s.y); if (s.eye < 0 && d < d0) { d0 = d; hit = j; } });
        return hit;
      };
      const choose = dir => {
        const list = eyes.map((e, i) => i).filter(i => eyes[i].state === "socket" && !eyes[i].locked);
        if (!list.length) return;
        const at = list.indexOf(active);
        active = list[(at + dir + list.length * 2) % list.length];
      };
      const lock = e => {
        const s = sockets[e.socket];
        e.angle = s.target; e.prev = e.angle; e.locked = true; s.locked = true; e.hold = 0; e.tension = 0; drag = null;
        sfx.latch(); ping(e.x, e.y, "#8fd19e");
        const next = eyes.findIndex(o => o.state === "socket" && !o.locked);
        active = next;
        if (sockets.every(o => o.locked)) {
          phase = "won";
          if (!best || time < best.time) { best = { time, falls }; M.store.set("endo", best); }
          over.show("Olhos instalados", "Tempo " + M.fmt(time) + " com " + falls + (falls === 1 ? " queda" : " quedas") + " (+" + DROP_COST + " s cada).", "Jogar de novo", reset, "soft");
        }
      };
      const drop = e => {
        sockets[e.socket].eye = -1; e.socket = -1; e.state = "fall";
        e.fall = { y: 0, vy: -90, dx: 0, vx: M.rand(-30, 30), rot: 0, vr: M.rand(-260, 260), age: 0 };
        falls++; time += DROP_COST; shake = 1; drag = null; keyHold = 0;
        eyes.forEach(o => { if (o !== e && o.state === "socket" && !o.locked) o.tension = Math.min(.9, o.tension + .4); }); active = eyes.findIndex(o => o.state === "socket" && !o.locked);
        ping(e.x, e.y, "#e0605a");
      };
      const fallStep = (e, dt) => {
        const f = e.fall;
        f.age += dt; f.vy += 1000 * dt; f.y += f.vy * dt; f.dx += f.vx * dt; f.rot += f.vr * dt;
        const floor = FLOOR - e.y;
        if (f.y > floor) { f.y = floor; f.vy = -f.vy * .42; f.vx *= .7; f.vr *= .6; }
        if (f.age > 1.8) {
          e.x = M.clamp(e.x + f.dx, 120, 520); e.y = FLOOR; e.angle = M.rand(-180, 180); e.prev = e.angle; e.fall = null; e.state = "return";
        }
      };

      const update = dt => {
        t += dt;
        shake = Math.max(0, shake - dt * 1.8);
        pings = pings.filter(p => (p.age += dt) < .7);
        if (phase === "play") time += dt;
        if (phase === "won") gazeStep(dt);
        for (let i = 0; i < eyes.length; i++) {
          const e = eyes[i];
          if (e.snap > 0) e.snap = Math.max(0, e.snap - dt);
          if (phase === "won" && e.state === "socket") e.lit = Math.min(1, e.lit + dt * 1.2);
          if (e.state === "fall") { fallStep(e, dt); continue; }
          if (e.state === "return") {
            const k = 1 - Math.exp(-dt * 10);
            e.x = M.mix(e.x, e.home.x, k); e.y = M.mix(e.y, e.home.y, k);
            if (Math.hypot(e.x - e.home.x, e.y - e.home.y) < 1) { e.x = e.home.x; e.y = e.home.y; e.state = "tray"; }
            continue;
          }
          if (e.state !== "socket" || e.locked) continue;
          const s = sockets[e.socket];
          if (i === active && phase === "play" && keyDir) {
            keyHold += dt;
            e.angle += keyDir * Math.min(22 + 25 * keyHold, 42) * dt;
          }
          const dA = Math.abs(M.wrap(e.angle - e.prev));
          if (phase === "play" && i === active) { e.tickAcc = (e.tickAcc || 0) + dA; for (let n = 0; n < 3 && e.tickAcc >= TICK; n++) { e.tickAcc -= TICK; sfx.tick(); } e.tickAcc = Math.min(e.tickAcc, TICK); }
          const inst = dA / Math.max(dt, 1e-4);
          e.speed = M.mix(e.speed, dt > 0 ? inst : 0, 1 - Math.exp(-dt * 14));
          e.prev = e.angle;
          if (phase !== "play") continue;
          if (e.speed > SAFE) e.tension += Math.min(.7, (e.speed / SAFE - 1) * 2 * dt);
          else e.tension = Math.max(0, e.tension - dt * .22);
          const err = Math.abs(M.wrap(e.angle - s.target)), inWin = err <= TOL;
          if (inWin && !e.inWin) { sfx.tec(); e.snap = .14; }
          e.inWin = inWin;
          if (err <= TOL && e.speed < SAFE * .6) e.hold += dt;
          else e.hold = Math.max(0, e.hold - dt * 1.5);
          if (e.tension >= 1) drop(e);
          else if (e.hold >= HOLD) lock(e);
        }
        const e = eyes[active];
        const tension = e && e.state === "socket" && !e.locked ? e.tension : 0;
        const away = eyes.filter(o => o.state === "tray" || o.state === "held" || o.state === "return" || o.state === "fall").length;
        M.hud.set([
          ["Olho ativo", e && e.state === "socket" ? "Órbita " + (e.socket + 1) : "-"],
          ["Na bandeja", String(away)],
          ["Instalados", sockets.filter(o => o.locked).length + " de " + sockets.length],
          ["Quedas", String(falls)],
          ["Tempo", M.fmt(time)],
          ["Melhor", best ? M.fmt(best.time) + " / " + best.falls + (best.falls === 1 ? " queda" : " quedas") : "-"]
        ], { label: "Tensão do encaixe", value: tension, tone: tension < .5 ? "good" : tension < .8 ? "warn" : "bad" });
      };

      const gradient = (x0, y0, x1, y1, stops) => {
        const g = ctx.createLinearGradient(x0, y0, x1, y1);
        stops.forEach(([o, c]) => g.addColorStop(o, c));
        return g;
      };
      // ---------- rosto: mesma geometria e mesmas cores do Endo Coelho (vista de frente) ----------
      // Unidade U = 1 "pixel" do modelo; o centro do crânio fica em (FX, FY). De frente, x = r e y = .15 f - z.
      const mixv = M.mix;
      const P = { line: "#14151a", light: "#e4e8f0", base: "#a9b0bf", deep: "#4a4f5d", metal: "#30333d", metalLight: "#5d6170", rivet: "#8a90a0", rivetLight: "#e6e9f2", mouth: "#08090c", ear: "#b3bac8", earLight: "#e4e7ee", earShade: "#6c7283", gun: "#3b3f4b", black: "#16171c" };
      const SHELL = ["#c3cad8", "#818899", "#474c5a"];
      const sp = (val, e) => Math.sign(val) * Math.abs(val) ** e;
      const Th = (r, f, z) => ({ x: FX + r * U, y: FY + (.15 * f - z) * U });
      const hull = pts => {
        const q = [...pts].sort((a, b) => a.x - b.x || a.y - b.y), cross = (o, a, b) => (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x), lo = [], up = [];
        for (const k of q) { while (lo.length >= 2 && cross(lo[lo.length - 2], lo[lo.length - 1], k) <= 0) lo.pop(); lo.push(k); }
        for (const k of [...q].reverse()) { while (up.length >= 2 && cross(up[up.length - 2], up[up.length - 1], k) <= 0) up.pop(); up.push(k); }
        return lo.slice(0, -1).concat(up.slice(0, -1));
      };
      const RAD3 = { r: 10.6, f: 10, z: 10.4 };
      const E = (phi, lam, out = 0) => Th((RAD3.r + out) * Math.cos(lam) * Math.sin(phi), (RAD3.f + out) * Math.cos(lam) * Math.cos(phi), (RAD3.z + out) * Math.sin(lam));
      // sombreamento em três faixas duras (claro, base, sombra), como o "material" do modelo
      const bands = (pts, colors = SHELL) => {
        let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
        for (const q of pts) { x0 = Math.min(x0, q.x); x1 = Math.max(x1, q.x); y0 = Math.min(y0, q.y); y1 = Math.max(y1, q.y); }
        const w = x1 - x0, g = ctx.createLinearGradient(x0, y0, x1 + w * .1, y1);
        g.addColorStop(0, colors[0]); g.addColorStop(.23, colors[0]); g.addColorStop(.23, colors[1]); g.addColorStop(.82, colors[1]); g.addColorStop(.82, colors[2]); g.addColorStop(1, colors[2]);
        return g;
      };
      const poly = (pts, fill, lw = 0) => {
        ctx.beginPath(); pts.forEach((q, i) => ctx[i ? "lineTo" : "moveTo"](q.x, q.y)); ctx.closePath();
        ctx.fillStyle = fill; ctx.fill();
        if (lw) { ctx.strokeStyle = P.line; ctx.lineWidth = lw; ctx.lineJoin = "round"; ctx.stroke(); }
      };
      const line = (pts, color, lw, alpha = 1) => {
        if (pts.length < 2) return;
        ctx.save(); ctx.globalAlpha = alpha; ctx.beginPath(); pts.forEach((q, i) => ctx[i ? "lineTo" : "moveTo"](q.x, q.y));
        ctx.strokeStyle = color; ctx.lineWidth = lw; ctx.lineCap = "round"; ctx.lineJoin = "round"; ctx.stroke(); ctx.restore();
      };
      const blob = (at, rx, ry, fill, lw = 0) => {
        ctx.beginPath(); ctx.ellipse(at.x, at.y, rx, ry, 0, 0, TAU); ctx.fillStyle = fill; ctx.fill();
        if (lw) { ctx.strokeStyle = P.line; ctx.lineWidth = lw; ctx.stroke(); }
      };
      const rivet = (at, r = .5) => {
        blob(at, r * U, r * U, P.rivet, 3);
        ctx.globalAlpha = .9; blob({ x: at.x - r * U * .3, y: at.y - r * U * .3 }, r * U * .38, r * U * .38, P.rivetLight); ctx.globalAlpha = 1;
      };

      // orelhas de coelho: armação de arame (duas hastes, travessas e um suporte de servo na base)
      const ear = side => {
        const lean = .2, sl = Math.sin(lean), cl = Math.cos(lean), L = 12.8;
        const base = { r: side * 5, f: -1.4, z: 7.6 }, d = { r: side * sl, f: -.1, z: cl }, uu = { r: cl * side, z: -sl };
        const wd = t => (t < .3 ? mixv(2.9, 3.5, t / .3) : mixv(3.5, 3.1, (t - .3) / .7)) * (t > .86 ? Math.sqrt(Math.max(.05, 1 - ((t - .86) / .14) ** 2 * .9)) : 1);
        const left = [], right = [];
        for (let i = 0; i <= 12; i++) {
          const t = i / 12, w = wd(t) * 1.02;
          for (const [list, sg] of [[left, -1], [right, 1]]) { const ww = w * sg; list.push(Th(base.r + d.r * L * t + uu.r * ww, base.f + d.f * L * t, base.z + d.z * L * t + uu.z * ww)); }
        }
        const loop = left.concat(right.slice().reverse());
        ctx.save(); ctx.lineCap = "round"; ctx.lineJoin = "round";
        ctx.beginPath(); loop.forEach((q, i) => ctx[i ? "lineTo" : "moveTo"](q.x, q.y)); ctx.closePath();
        ctx.fillStyle = "rgba(16,18,26,.38)"; ctx.fill();
        ctx.strokeStyle = P.line; ctx.lineWidth = 13; ctx.stroke();
        ctx.strokeStyle = bands(loop, [P.earLight, P.ear, P.earShade]); ctx.lineWidth = 6; ctx.stroke();
        for (const t of [.2, .42, .64, .84]) {
          const i = Math.round(t * 12), A = left[i], B = right[i];
          ctx.beginPath(); ctx.moveTo(A.x, A.y); ctx.lineTo(B.x, B.y); ctx.strokeStyle = P.line; ctx.lineWidth = 9; ctx.stroke();
          ctx.strokeStyle = P.base; ctx.lineWidth = 4; ctx.stroke();
        }
        ctx.restore();
        const mount = Th(base.r + d.r * .6, base.f, base.z + 1);
        blob(mount, 3 * U, 2.5 * U, bands([{ x: mount.x - 3 * U, y: mount.y - 2.5 * U }, { x: mount.x + 3 * U, y: mount.y + 2.5 * U }], [P.metalLight, P.gun, P.black]), 4);
        rivet(mount, .45);
      };

      const head = () => {
        const open = 1, jawF = -open * .9, jawZ = -open * 3.1, zero = 0;
        [-1, 1].forEach(ear);

        // crânio: elipsoide de aço, sombreado em faixas
        const cranium = []; for (let i = 0; i < 30; i++) for (let j = 0; j <= 13; j++) cranium.push(E(i / 30 * TAU, -Math.PI / 2 + j / 13 * Math.PI));
        const skull = hull(cranium);
        poly(skull, bands(skull), 6);
        ctx.save(); ctx.beginPath(); skull.forEach((q, i) => ctx[i ? "lineTo" : "moveTo"](q.x, q.y)); ctx.closePath(); ctx.clip();
        ctx.globalAlpha = .42; blob(Th(-4.6, 3, 6.6), 3.8 * U, 2.2 * U, "#ffffff"); ctx.globalAlpha = 1;
        // emenda vertical no meio da testa
        const seam = []; for (let lam = 84; lam >= -4; lam -= 5) seam.push(E(0, lam * RAD, .1));
        line(seam, P.line, 4);
        // dois anéis de aço com parafusos, como as juntas de chapa do crânio
        for (const lam of [66, 34]) {
          const ring = []; for (let k = 0; k <= 36; k++) { const phi = -Math.PI + k / 36 * TAU; if (Math.cos(phi) > -.05) ring.push(E(phi, lam * RAD, .1)); }
          line(ring, P.line, 9, .95); line(ring.map(q => ({ x: q.x, y: q.y + 6 })), "rgba(255,255,255,.35)", 3);
          if (lam === 66) for (const phi of [-1.2, -.6, .6, 1.2]) rivet(E(phi, lam * RAD, .15), .45);
        }
        // arcos escuros acima dos olhos e dois parafusos entre eles
        for (const sd of [-1, 1]) { const arc = []; for (let k = 0; k <= 14; k++) arc.push(E(mixv(sd * .14, sd * .95, k / 14), 58 * RAD, .08)); line(arc, P.deep, 5, .6); }
        for (const sd of [-1, 1]) rivet(E(sd * .1, 22 * RAD, .1), .42);
        ctx.restore();

        // focinho de coelho: seções que afunilam da cara até a ponta
        const ft = t => t < .78 ? 1 : Math.sqrt(Math.max(.02, 1 - ((t - .78) / .22) ** 1.4 * .9));
        const loft = (f0, f1, fn, n = 9, m = 16) => {
          const pts = [];
          for (let i = 0; i <= n; i++) {
            const t = i / n, q = fn(t), k = ft(t), f = mixv(f0, f1, t);
            for (let j = 0; j < m; j++) { const a = j / m * TAU; pts.push(Th(sp(Math.cos(a), .72) * q.w * k, f, (q.z0 + q.z1) / 2 + sp(Math.sin(a), .72) * (q.z1 - q.z0) / 2 * k)); }
          }
          return hull(pts);
        };
        const muz = t => ({ w: mixv(5.6, 3.3, t ** .8), z1: -1.4 - t * 1.4, z0: -9.4 + t * 1.1 });
        const jaw = t => ({ w: mixv(5.3, 3.3, t), z1: -9.4 + jawZ - t * .2, z0: -12.6 + jawZ + t * .5 });
        const inner = t => ({ w: mixv(4.7, 3, t), z1: -8 - open * .6, z0: -10.4 - open * 2.2 + t * .8 });

        // 1) cavidade da boca: preta, um pouco mais clara no fundo
        const cav = loft(5, 11.2, inner);
        let cy0 = 1e9, cy1 = -1e9; for (const q of cav) { cy0 = Math.min(cy0, q.y); cy1 = Math.max(cy1, q.y); }
        const cg = ctx.createLinearGradient(0, cy0, 0, cy1); cg.addColorStop(0, "#08090c"); cg.addColorStop(1, "#14151a");
        poly(cav, cg, 0);
        // 2) atuadores da mandíbula: dois pistões nos cantos da boca (a parte de cima fica sob o focinho)
        for (const o of [-1, 1]) {
          const top = Th(o * 4.3, 6.5, -8.4), bot = Th(o * 4.3, 6.5, -12.6 + jawZ * .3);
          line([top, bot], P.line, 9); line([top, bot], P.metalLight, 4.5);
          line([{ x: top.x - 1.2, y: top.y }, { x: bot.x - 1.2, y: bot.y }], P.rivetLight, 1.5, .8);
          blob(bot, .5 * U, .35 * U, P.metal, 3);
        }
        // 3) mandíbula: placa larga com lábio inferior claro, emenda no meio e rebites
        const jw = loft(4.2 + jawF, 11 + jawF, jaw); poly(jw, bands(jw), 5);
        const jf = 8 + jawF, jt = -9.5 + jawZ;
        line([Th(-3.9, jf, jt - .45), Th(3.9, jf, jt - .45)], "#c3cad8", 3.4, .85);
        line([Th(0, jf, jt - .5), Th(0, jf, jt - 3.2)], P.line, 3);
        for (const o of [-1, 1]) rivet(Th(o * 3.3, jf, jt - 1.9), .38);
        // 4) focinho por cima
        const mz = loft(4, 12.4, muz); poly(mz, bands(mz), 5);
        const top = []; for (let i = 0; i <= 8; i++) { const t = i / 8, q = muz(t); top.push(Th(0, mixv(4, 12.4, t), q.z1 + .15)); }
        line(top, P.line, 3.4);
        ctx.globalAlpha = .45; blob(Th(-2, 8, -2.4), 2.4 * U, 1 * U, "#ffffff"); ctx.globalAlpha = 1;
        blob(Th(0, 11.9, -3.1), 2.1 * U, 1.15 * U, P.metal, 3);
        // lábio superior partido e dois dentes de placa com a ponta arredondada
        line(Array.from({ length: 6 }, (_, i) => Th(0, 12.1 - i * .12, -3.8 - i * .95)), P.line, 3.4);
        for (const o of [-1, 1]) {
          const f = 10.2, xa = Th(o * .15, f, 0).x, xb = Th(o * 2.1, f, 0).x, x0 = Math.min(xa, xb), w = Math.abs(xb - xa);
          const yt = Th(0, f, -8.2).y, yb = Th(0, f, -12 + jawZ * .12).y;
          const tg = ctx.createLinearGradient(x0, yt, x0 + w, yb);
          tg.addColorStop(0, P.light); tg.addColorStop(.55, P.light); tg.addColorStop(.55, P.base); tg.addColorStop(1, P.base);
          ctx.beginPath(); ctx.roundRect(x0, yt, w, yb - yt, [0, 0, 6, 6]); ctx.fillStyle = tg; ctx.fill();
          ctx.strokeStyle = P.line; ctx.lineWidth = 3.4; ctx.lineJoin = "round"; ctx.stroke();
        }
        // 5) dobradiças da mandíbula nas laterais
        for (const o of [-1, 1]) {
          const h = Th(o * 5.3, 6.5, -9.9 + jawZ * .45);
          blob(h, .62 * U, .62 * U, bands([{ x: h.x - .62 * U, y: h.y - .62 * U }, { x: h.x + .62 * U, y: h.y + .62 * U }], [P.metalLight, P.gun, P.black]), 4);
          rivet(h, .32);
        }
      };
      const tray = () => {
        ctx.beginPath(); ctx.roundRect(110, 350, 420, 64, 10); ctx.fillStyle = "#1a2327"; ctx.fill(); ctx.lineWidth = 5; ctx.strokeStyle = "#3c4d54"; ctx.stroke();
        ctx.beginPath(); ctx.roundRect(122, 360, 396, 44, 8); ctx.fillStyle = "#12191c"; ctx.fill();
        for (const h of HOMES) {
          ctx.beginPath(); ctx.ellipse(h.x, h.y + 18, 38, 12, 0, 0, TAU); ctx.fillStyle = "#0d0e13"; ctx.fill(); ctx.lineWidth = 3; ctx.strokeStyle = "#30333d"; ctx.stroke();
        }
      };

      const socket = (s, j) => {
        const e = s.eye >= 0 ? eyes[s.eye] : null;
        ctx.save(); ctx.translate(s.x, s.y); ctx.scale(SS, SS);
        ctx.beginPath(); ctx.arc(0, 0, 55, 0, TAU); ctx.fillStyle = gradient(-40, -50, 40, 50, [[0, "#3b3f4b"], [1, "#14151a"]]); ctx.fill(); ctx.lineWidth = 4; ctx.strokeStyle = C.line; ctx.stroke();
        ctx.beginPath(); ctx.arc(0, 0, 47, 0, TAU); ctx.fillStyle = C.socket; ctx.fill(); ctx.lineWidth = 3; ctx.strokeStyle = C.metal; ctx.stroke();
        ctx.strokeStyle = "#5d6170"; ctx.lineWidth = 3;
        for (let k = 0; k < 12; k++) { const a = k * 30 * RAD; ctx.beginPath(); ctx.moveTo(Math.cos(a) * 47, Math.sin(a) * 47); ctx.lineTo(Math.cos(a) * 51, Math.sin(a) * 51); ctx.stroke(); }
        const lx = Math.cos(-135 * RAD) * 66, ly = Math.sin(-135 * RAD) * 66;
        const led = s.locked ? "#58e08a" : e && e.snap > 0 ? "#dfe4e0" : "#3a3f4b";
        ctx.beginPath(); ctx.arc(lx, ly, 5, 0, TAU); ctx.fillStyle = led; ctx.fill(); ctx.lineWidth = 3; ctx.strokeStyle = C.line; ctx.stroke();
        ctx.restore();
      };

      const ball = (e, scale) => {
        const r = 36, a = e.angle * RAD, lit = e.lit;
        ctx.save(); ctx.scale(scale, scale);
        if (lit > 0) {
          const halo = ctx.createRadialGradient(0, 0, r * .6, 0, 0, r * 2.1);
          halo.addColorStop(0, "rgba(134,160,255," + (.5 * lit) + ")"); halo.addColorStop(1, "rgba(134,160,255,0)");
          ctx.fillStyle = halo; ctx.beginPath(); ctx.arc(0, 0, r * 2.1, 0, TAU); ctx.fill();
        }
        const sclera = ctx.createRadialGradient(-r * .3, -r * .35, r * .1, 0, 0, r);
        sclera.addColorStop(0, "#f8f9fd"); sclera.addColorStop(.55, "#eef0f8"); sclera.addColorStop(1, "#9ea3b1");
        ctx.beginPath(); ctx.arc(0, 0, r, 0, TAU); ctx.fillStyle = sclera; ctx.fill();
        if (e.tension > 0) { ctx.fillStyle = "rgba(224,96,90," + (e.tension * .35) + ")"; ctx.fill(); }
        const mag = r * .36 * (1 - lit * .85);
        const buzz = e.gm && lit > .5 ? (Math.random() - .5) * 2.6 : 0;
        const ix = Math.cos(a) * mag + (e.gx || 0) * r * .3 * lit + buzz, iy = Math.sin(a) * mag + (e.gy || 0) * r * .24 * lit;
        const ir = r * (.5 + .22 * lit);
        ctx.save(); ctx.beginPath(); ctx.arc(0, 0, r - 1.5, 0, TAU); ctx.clip();
        ctx.beginPath(); ctx.arc(ix, iy, ir, 0, TAU); ctx.fillStyle = "#1b1c25"; ctx.fill();
        ctx.beginPath(); ctx.arc(ix, iy, ir * .78, 0, TAU); ctx.fillStyle = "#2e303c"; ctx.fill();
        if (lit > 0) {
          ctx.globalAlpha = lit;
          ctx.beginPath(); ctx.arc(ix, iy, ir, 0, TAU); ctx.fillStyle = "#1f2b7c"; ctx.fill();
          ctx.beginPath(); ctx.arc(ix, iy, ir * .78, 0, TAU); ctx.fillStyle = "#4c66dc"; ctx.fill();
          ctx.beginPath(); ctx.arc(ix - 3, iy - 4, ir * .35, 0, TAU); ctx.fillStyle = "#86a0ff"; ctx.fill();
          ctx.globalAlpha = 1;
        }
        ctx.beginPath(); ctx.arc(ix, iy, ir * .38 * (1 + ((e.gp || 1) - 1) * lit), 0, TAU); ctx.fillStyle = "#07080d"; ctx.fill();
        ctx.beginPath(); ctx.arc(ix - ir * .3, iy - ir * .3, ir * .16, 0, TAU); ctx.fillStyle = "#ffffff"; ctx.fill();
        ctx.restore();
        ctx.beginPath(); ctx.arc(0, 0, r, 0, TAU); ctx.lineWidth = 3; ctx.strokeStyle = C.line; ctx.stroke();
        ctx.rotate(a);
        ctx.beginPath(); ctx.moveTo(r - 5, -7); ctx.lineTo(r + 8, -5); ctx.lineTo(r + 8, 5); ctx.lineTo(r - 5, 7); ctx.closePath();
        ctx.fillStyle = e.locked ? "#8fd19e" : "#8a90a0"; ctx.fill(); ctx.lineWidth = 3; ctx.strokeStyle = C.line; ctx.stroke();
        ctx.restore();
      };

      const handle = e => {
        ctx.save(); ctx.translate(e.x, e.y); ctx.scale(S, S);
        ctx.setLineDash([9, 12]); ctx.beginPath(); ctx.arc(0, 0, 70, 0, TAU); ctx.strokeStyle = "rgba(190,201,181,.6)"; ctx.lineWidth = 3; ctx.stroke(); ctx.setLineDash([]);
        const a = e.angle * RAD;
        ctx.beginPath(); ctx.arc(Math.cos(a) * 70, Math.sin(a) * 70, 7, 0, TAU); ctx.fillStyle = "#dfe4e0"; ctx.fill(); ctx.lineWidth = 3; ctx.strokeStyle = C.line; ctx.stroke();
        if (e.tension > .02) {
          ctx.beginPath(); ctx.arc(0, 0, 80, -Math.PI / 2, -Math.PI / 2 + TAU * Math.min(1, e.tension));
          ctx.strokeStyle = e.tension < .5 ? "#8fd19e" : e.tension < .8 ? "#d3af76" : "#e0605a"; ctx.lineWidth = 6; ctx.lineCap = "butt"; ctx.stroke();
        }
        ctx.restore();
      };

      const eyeAt = e => {
        ctx.save(); ctx.translate(e.x, e.y);
        if (e.state === "socket" && e === eyes[active] && e.tension > .4 && !e.locked) ctx.translate((Math.random() - .5) * e.tension * 5, (Math.random() - .5) * e.tension * 5);
        if (e.state === "fall") { ctx.translate(e.fall.dx, e.fall.y); }
        ball(e.state === "fall" ? { ...e, angle: e.angle + e.fall.rot } : e, S * (1 - .06 * Math.min(1, (e.snap || 0) / .14)));
        ctx.restore();
      };

      const draw = () => {
        v.begin();
        const bg = ctx.createRadialGradient(320, 250, 40, 320, 250, 330);
        bg.addColorStop(0, "#2f4047"); bg.addColorStop(1, "#1f2b30");
        ctx.fillStyle = bg; ctx.fillRect(-40, -40, W + 80, H + 80);
        ctx.save();
        if (shake > 0) ctx.translate((Math.random() - .5) * 10 * shake, (Math.random() - .5) * 10 * shake);
        head();
        sockets.forEach(socket);
        tray();
        const order = eyes.map((e, i) => i).sort((a, b) => (eyes[a].state === "held") - (eyes[b].state === "held"));
        for (const i of order) {
          const e = eyes[i];
          if (e.state === "held") {
            ctx.beginPath(); ctx.ellipse(e.x + 8, e.y + R + 6, R * .9, 8, 0, 0, TAU); ctx.fillStyle = "rgba(0,0,0,.35)"; ctx.fill();
          }
          eyeAt(e);
        }
        const cur = eyes[active];
        if (phase === "play" && cur && cur.state === "socket" && !cur.locked) handle(cur);
        for (const p of pings) {
          ctx.beginPath(); ctx.arc(p.x, p.y, 36 + p.age * 80, 0, TAU);
          ctx.strokeStyle = p.color; ctx.globalAlpha = 1 - p.age / .7; ctx.lineWidth = 4; ctx.stroke(); ctx.globalAlpha = 1;
        }
        ctx.restore();
        v.finish();
      };

      canvas.addEventListener("pointerdown", ev => {
        sfx.ready();
        if (phase !== "play") return;
        const p = v.point(ev);
        const grab = eyes.findIndex(e => e.state === "tray" && Math.hypot(p.x - e.x, p.y - e.y) < R + 10);
        if (grab >= 0) {
          const e = eyes[grab];
          e.state = "held"; drag = { mode: "move", i: grab, id: ev.pointerId, dx: e.x - p.x, dy: e.y - p.y };
          canvas.setPointerCapture(ev.pointerId); canvas.classList.add("is-grabbing");
          return;
        }
        const hit = eyes.findIndex(e => e.state === "socket" && !e.locked && Math.hypot(p.x - e.x, p.y - e.y) < R + 12);
        if (hit >= 0) active = hit;
        const e = eyes[active];
        if (!e || e.state !== "socket" || e.locked) return;
        const dx = p.x - e.x, dy = p.y - e.y, d = Math.hypot(dx, dy);
        if (d < 12 || d > 130) return;
        drag = { mode: "rot", id: ev.pointerId, last: Math.atan2(dy, dx) };
        canvas.setPointerCapture(ev.pointerId); canvas.classList.add("is-grabbing");
      });
      canvas.addEventListener("pointermove", ev => {
        if (!drag || ev.pointerId !== drag.id) return;
        const p = v.point(ev);
        if (drag.mode === "move") {
          const e = eyes[drag.i];
          e.x = M.clamp(p.x + drag.dx, R, W - R); e.y = M.clamp(p.y + drag.dy, R, H - R);
          return;
        }
        const e = eyes[active];
        if (!e || e.state !== "socket" || e.locked) return;
        const dx = p.x - e.x, dy = p.y - e.y;
        if (Math.hypot(dx, dy) < 10) return;
        const cur = Math.atan2(dy, dx);
        e.angle += M.wrap((cur - drag.last) / RAD);
        drag.last = cur;
      });
      const release = ev => {
        if (!drag || (ev && ev.pointerId !== drag.id)) return;
        const d = drag; drag = null; canvas.classList.remove("is-grabbing");
        if (d.mode !== "move") return;
        const e = eyes[d.i];
        if (e.state !== "held") return;
        const j = emptySocket(e.x, e.y, 62);
        if (j >= 0 && phase === "play") place(d.i, j); else e.state = "return";
      };
      canvas.addEventListener("pointerup", release);
      canvas.addEventListener("pointercancel", release);
      canvas.addEventListener("wheel", ev => {
        const e = eyes[active];
        if (phase !== "play" || !e || e.state !== "socket" || e.locked) return;
        ev.preventDefault();
        e.angle += Math.sign(ev.deltaY) * 2.5;
      }, { passive: false });

      reset();
      return {
        reset,
        activate() { v.resize(); },
        deactivate() { keyDir = 0; drag = null; eyes.forEach(e => { if (e.state === "held") e.state = "return"; }); },
        update,
        draw,
        state: () => ({ eyes, sockets, active, phase, falls, look }),
        keydown(ev) {
          const key = ev.key.length === 1 ? ev.key.toLowerCase() : ev.key;
          sfx.ready();
          if (key === "m") { sfx.on = !sfx.on; return true; }
          if (key === "ArrowLeft" || key === "a") { keyDir = -1; return true; }
          if (key === "ArrowRight" || key === "d") { keyDir = 1; return true; }
          if (key === "ArrowUp" || key === "w") { choose(-1); return true; }
          if (key === "ArrowDown" || key === "s") { choose(1); return true; }
          if (key === "e" && phase === "play") {
            const i = eyes.findIndex(o => o.state === "tray"), j = sockets.findIndex(o => o.eye < 0);
            if (i >= 0 && j >= 0) place(i, j);
            return true;
          }
          return false;
        },
        keyup(ev) {
          const key = ev.key.length === 1 ? ev.key.toLowerCase() : ev.key;
          if (["ArrowLeft", "a", "ArrowRight", "d"].includes(key)) { keyDir = 0; keyHold = 0; }
        }
      };
    }
  });
})();
