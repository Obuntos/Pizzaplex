(() => {
  "use strict";
  const M = window.Mini;
  const W = 640, H = 420, PX = 3, TAU = M.TAU, RAD = M.RAD;
  const KNOBS = [{ key: "freq", x: 292 }, { key: "amp", x: 372 }, { key: "phase", x: 452 }];
  const SLIDERS = [{ key: "low", x: 526 }, { key: "high", x: 574 }];
  const CONTROLS = [...KNOBS, ...SLIDERS];
  const KNOB_Y = 310, KNOB_R = 27, TRACK_Y0 = 262, TRACK_Y1 = 350, THUMB_H = 18;
  const SOUND = { x: 578, y: 46, r: 17 };
  const SCOPE = { x: 266, y: 82, w: 320, h: 156 };
  const SPK = { x: 134, y: 228, r: 90 };
  const SOLVE = .88, HOLD = 1;
  const STAR_AT = [.3, .45, .6, .75, SOLVE];
  const K = { navy: "#151a3a", ink: "#0a0c1e", cream: "#efe4c8", creamDark: "#b8a36f", gold: "#f0d56a", goldDark: "#8a6f12", maroon: "#8c2f46", maroonDark: "#5a1c2e", blue: "#3a64b8", line: "#14151a" };

  const wave = (p, x) => {
    const c = 1.5 + 3 * p.freq, A = .2 + .8 * p.amp, ph = p.phase * TAU;
    return A * (Math.sin(TAU * c * x + ph) + .45 * p.low * Math.sin(TAU * 2 * c * x + 2 * ph) + .45 * p.high * Math.sin(TAU * 3 * c * x + 3 * ph));
  };
  const similarity = (a, b) => {
    const N = 256;
    let e = 0, r = 0;
    for (let i = 0; i < N; i++) { const x = i / N, u = wave(a, x), w = wave(b, x); e += (u - w) * (u - w); r += w * w; }
    return M.clamp(1 - Math.sqrt(e / N) / (Math.max(.25, Math.sqrt(r / N)) * 2));
  };
  const randomSet = () => ({
    freq: M.rand(.1, .9), amp: M.rand(.2, .95), phase: Math.random(),
    low: Math.random() < .6 ? M.rand(.25, 1) : 0, high: Math.random() < .6 ? M.rand(.25, 1) : 0
  });
  const snap = v => Math.round(v * 100) / 100;

  M.register({
    id: "roupa", number: "03", name: "Roupa", note: "Afinar a caixa de voz", short: "Caixa de voz",
    keys: "Girar os botões com o mouse em volta deles ou com o rolo - zíperes: arrastar - setas escolhem e ajustam - M som",
    tip: "<b>Roupa:</b> a caixa de voz costurada no traje saiu de sintonia. Ajuste os botões e os zíperes até a linha verde cobrir a pontilhada. As orelhinhas se levantam quando a voz afina.",
    create(root) {
      const canvas = document.createElement("canvas");
      canvas.className = "game-canvas";
      canvas.setAttribute("aria-label", "Caixa de voz costurada no traje, com alto-falante, visualizador de onda, três botões e dois zíperes");
      root.appendChild(canvas);
      const v = M.pixel(canvas, W, H, PX, "costume"), ctx = v.ctx;
      const over = M.overlay(root);

      let cur, tgt, score = 0, hold = 0, solved = false, rounds = 0, t = 0, level = 0, sel = 0, drag = null, keyUsed = false, ears = 1;
      const sound = {
        ac: null, osc: null, gain: null, on: false,
        ready() {
          if (!this.ac) { const AC = window.AudioContext || window.webkitAudioContext; if (!AC) return false; this.ac = new AC(); }
          if (this.ac.state === "suspended") this.ac.resume();
          return true;
        },
        start() {
          if (!this.on || this.osc || !this.ready()) return;
          this.gain = this.ac.createGain(); this.gain.gain.value = 0;
          this.osc = this.ac.createOscillator(); this.osc.connect(this.gain); this.gain.connect(this.ac.destination); this.osc.start();
          this.update();
        },
        stop() {
          if (!this.osc) return;
          try { this.osc.stop(); } catch (e) {}
          this.osc.disconnect(); this.gain.disconnect(); this.osc = null; this.gain = null;
        },
        update() {
          if (!this.osc || !cur) return;
          const ac = this.ac;
          this.osc.setPeriodicWave(ac.createPeriodicWave(new Float32Array(4), new Float32Array([0, 1, .45 * cur.low, .45 * cur.high])));
          this.osc.frequency.setTargetAtTime(110 + 330 * cur.freq, ac.currentTime, .04);
          this.gain.gain.setTargetAtTime(.015 + .05 * cur.amp, ac.currentTime, .05);
        },
        chime() {
          if (!this.on || !this.ready()) return;
          [392, 523.25, 659.25].forEach((f, i) => {
            const o = this.ac.createOscillator(), g = this.ac.createGain(), s = this.ac.currentTime + i * .13;
            o.type = "sine"; o.frequency.value = f; o.connect(g); g.connect(this.ac.destination);
            g.gain.setValueAtTime(0, s); g.gain.linearRampToValueAtTime(.12, s + .02); g.gain.exponentialRampToValueAtTime(.001, s + .35);
            o.start(s); o.stop(s + .4);
          });
        }
      };
      const toggleSound = () => { sound.on = !sound.on; if (sound.on) sound.start(); else sound.stop(); };

      const set = (key, value, quiet) => { cur[key] = M.clamp(snap(value)); if (!quiet) sound.update(); };
      const newRound = () => {
        do { tgt = randomSet(); cur = { freq: M.rand(.1, .9), amp: M.rand(.2, .9), phase: Math.random(), low: 0, high: 0 }; } while (similarity(cur, tgt) > .6);
        Object.keys(cur).forEach(k => set(k, cur[k], true));
        sound.update();
        score = similarity(cur, tgt); hold = 0; solved = false;
      };
      const reset = () => { rounds = 0; sel = 0; keyUsed = false; over.hide(); newRound(); };

      const update = dt => {
        t += dt;
        if (drag && drag.type === "knob") {
          const now = cur[drag.key], gap = drag.target - now;
          if (Math.abs(gap) < .01) { if (gap) set(drag.key, drag.target); }
          else set(drag.key, now + gap * (1 - Math.exp(-dt * 30)));
        }
        score = similarity(cur, tgt);
        if (!solved) {
          if (score >= SOLVE) hold += dt; else hold = Math.max(0, hold - dt * 2);
          if (hold >= HOLD) {
            solved = true; rounds++; sound.chime();
            over.show("Voz afinada", "Sintonias feitas: " + rounds, "Outra", () => { over.hide(); newRound(); }, "soft");
          }
        }
        level = M.mix(level, solved ? 1 : score > .8 ? .5 : .1 + score * .2, 1 - Math.exp(-dt * 5));
        ears = M.mix(ears, solved ? 0 : 1 - M.clamp((score - .4) / (SOLVE - .4)), 1 - Math.exp(-dt * 4));
        M.hud.set([
          ["Sinal", Math.round(score * 100) + "%"],
          ["Sintonias feitas", String(rounds)],
          ["Estado", solved ? "Voz estável" : hold > 0 ? "Segurando" : "Fora de sintonia"]
        ], { label: "Sinal", value: score, tone: score >= SOLVE ? "good" : score > .6 ? "warn" : "bad" });
      };

      // ---------- desenho ----------
      const gradient = (x0, y0, x1, y1, stops) => { const g = ctx.createLinearGradient(x0, y0, x1, y1); stops.forEach(([o, c]) => g.addColorStop(o, c)); return g; };
      const star = (cx, cy, ro, ri) => {
        ctx.beginPath();
        for (let k = 0; k < 10; k++) { const r = k % 2 ? ri : ro, a = -Math.PI / 2 + k * Math.PI / 5; ctx[k ? "lineTo" : "moveTo"](cx + Math.cos(a) * r, cy + Math.sin(a) * r); }
        ctx.closePath();
      };
      const stitchRect = (x, y, w, h, r, color = K.cream) => { ctx.beginPath(); ctx.roundRect(x, y, w, h, r); ctx.setLineDash([8, 7]); ctx.strokeStyle = color; ctx.lineWidth = 3; ctx.stroke(); ctx.setLineDash([]); };
      const rivet = (x, y, r = 5) => {
        ctx.beginPath(); ctx.arc(x, y, r, 0, TAU); ctx.fillStyle = "#a9b0bf"; ctx.fill(); ctx.lineWidth = 3; ctx.strokeStyle = K.line; ctx.stroke();
        ctx.beginPath(); ctx.arc(x - r * .3, y - r * .3, r * .38, 0, TAU); ctx.fillStyle = "#f8f9fd"; ctx.fill();
      };

      const casing = () => {
        const bg = ctx.createRadialGradient(320, 210, 60, 320, 210, 420);
        bg.addColorStop(0, "#1b2148"); bg.addColorStop(1, "#0a0c1e");
        ctx.fillStyle = bg; ctx.fillRect(-40, -40, W + 80, H + 80);
        ctx.beginPath(); ctx.roundRect(14, 8, 612, 404, 26); ctx.fillStyle = gradient(0, 8, 0, 412, [[0, "#8a90a0"], [.5, "#5d6170"], [1, "#30333d"]]); ctx.fill(); ctx.lineWidth = 5; ctx.strokeStyle = K.line; ctx.stroke();
        ctx.beginPath(); ctx.roundRect(28, 22, 584, 376, 18); ctx.fillStyle = gradient(0, 22, 0, 398, [[0, "#4a78cf"], [.5, "#3a64b8"], [1, "#2f4f9e"]]); ctx.fill();
        ctx.save(); ctx.beginPath(); ctx.roundRect(28, 22, 584, 376, 18); ctx.clip();
        ctx.strokeStyle = "rgba(191,220,255,.12)"; ctx.lineWidth = 3;
        for (let i = -400; i < 640; i += 30) { ctx.beginPath(); ctx.moveTo(i, 22); ctx.lineTo(i + 376, 398); ctx.stroke(); ctx.beginPath(); ctx.moveTo(i + 376, 22); ctx.lineTo(i, 398); ctx.stroke(); }
        ctx.restore();
        ctx.beginPath(); ctx.roundRect(28, 22, 584, 376, 18); ctx.lineWidth = 4; ctx.strokeStyle = K.navy; ctx.stroke();
        stitchRect(39, 33, 562, 354, 12);
        for (const [x, y] of [[21, 15], [619, 15], [21, 405], [619, 405]]) rivet(x, y);
      };

      // estrelas bordadas: acendem conforme o sinal se aproxima do alvo
      const stars = () => {
        for (let k = 0; k < 5; k++) {
          const x = 320 + (k - 2) * 38, y = 50, lit = solved || score >= STAR_AT[k], pulse = solved ? 1 + .12 * Math.sin(t * 6 + k) : 1;
          star(x, y, 13 * pulse, 5.6 * pulse);
          ctx.fillStyle = lit ? gradient(x, y - 13, x, y + 13, [[0, "#f7e394"], [.5, "#f0d56a"], [1, "#c9a227"]]) : "#232a5a"; ctx.fill();
          ctx.lineWidth = 3; ctx.strokeStyle = lit ? K.goldDark : K.navy; ctx.lineJoin = "round"; ctx.stroke();
        }
      };

      const soundButton = () => {
        const { x, y, r } = SOUND;
        ctx.beginPath(); ctx.arc(x, y, r, 0, TAU); ctx.fillStyle = gradient(x, y - r, x, y + r, [[0, "#fff6dc"], [1, "#d2bf8f"]]); ctx.fill(); ctx.lineWidth = 3; ctx.strokeStyle = K.navy; ctx.stroke();
        ctx.fillStyle = K.navy;
        ctx.beginPath(); ctx.moveTo(x - 8, y - 3); ctx.lineTo(x - 4, y - 3); ctx.lineTo(x + 1, y - 8); ctx.lineTo(x + 1, y + 8); ctx.lineTo(x - 4, y + 3); ctx.lineTo(x - 8, y + 3); ctx.closePath(); ctx.fill();
        ctx.strokeStyle = sound.on ? K.navy : K.maroon; ctx.lineWidth = 3;
        if (sound.on) { ctx.beginPath(); ctx.arc(x + 1, y, 6, -.9, .9); ctx.stroke(); ctx.beginPath(); ctx.arc(x + 1, y, 11, -.9, .9); ctx.stroke(); }
        else { ctx.beginPath(); ctx.moveTo(x + 4, y - 5); ctx.lineTo(x + 12, y + 5); ctx.moveTo(x + 12, y - 5); ctx.lineTo(x + 4, y + 5); ctx.stroke(); }
      };

      // alto-falante com orelhinhas: elas caem quando a voz está fora de sintonia e se erguem quando afina
      const speaker = () => {
        const { x: cx, y: cy, r } = SPK;
        const beat = Math.sin(t * (18 + cur.freq * 30)) * level * (.5 + .5 * cur.amp);
        const wig = solved ? Math.sin(t * 9) * .05 : 0;
        for (const side of [-1, 1]) {
          ctx.save(); ctx.translate(cx + side * 30, cy - r + 12); ctx.rotate(side * (ears * .55 + wig));
          ctx.beginPath(); ctx.ellipse(0, -44, 16, 46, 0, 0, TAU); ctx.fillStyle = gradient(0, -90, 0, 2, [[0, "#a8405a"], [1, "#5a1c2e"]]); ctx.fill(); ctx.lineWidth = 4; ctx.strokeStyle = K.navy; ctx.stroke();
          ctx.beginPath(); ctx.ellipse(0, -44, 8.5, 36, 0, 0, TAU); ctx.fillStyle = gradient(0, -80, 0, -8, [[0, "#e08aa0"], [1, "#c25a73"]]); ctx.fill();
          ctx.beginPath(); ctx.ellipse(0, -44, 12.5, 41, 0, 0, TAU); ctx.setLineDash([6, 6]); ctx.strokeStyle = K.cream; ctx.lineWidth = 3; ctx.stroke(); ctx.setLineDash([]);
          ctx.restore();
        }
        ctx.save(); ctx.translate(cx, cy);
        ctx.beginPath(); ctx.ellipse(3, 8, r + 2, r + 2, 0, 0, TAU); ctx.fillStyle = "rgba(10,12,30,.45)"; ctx.fill();
        // aro de aço e tecido bordado
        ctx.beginPath(); ctx.arc(0, 0, r, 0, TAU); ctx.fillStyle = gradient(-r, -r, r, r, [[0, "#c3cad8"], [.5, "#8a90a0"], [1, "#474c5a"]]); ctx.fill(); ctx.lineWidth = 5; ctx.strokeStyle = K.line; ctx.stroke();
        for (let k = 0; k < 8; k++) { const a = k * TAU / 8 + .39; rivet(Math.cos(a) * (r - 7), Math.sin(a) * (r - 7), 3.4); }
        ctx.beginPath(); ctx.arc(0, 0, r - 15, 0, TAU); ctx.fillStyle = gradient(-r, -r, r, r, [[0, "#a8405a"], [1, "#5a1c2e"]]); ctx.fill(); ctx.lineWidth = 3; ctx.strokeStyle = K.navy; ctx.stroke();
        ctx.beginPath(); ctx.arc(0, 0, r - 21, 0, TAU); ctx.setLineDash([7, 6]); ctx.strokeStyle = K.cream; ctx.lineWidth = 3; ctx.stroke(); ctx.setLineDash([]);
        // grade pontilhada: os furos pulsam com a voz
        ctx.beginPath(); ctx.arc(0, 0, r - 27, 0, TAU); ctx.fillStyle = "#10132b"; ctx.fill();
        ctx.save(); ctx.beginPath(); ctx.arc(0, 0, r - 28, 0, TAU); ctx.clip();
        let row = 0;
        for (let yy = -60; yy <= 60; yy += 8, row++) for (let xx = -60 + (row % 2) * 4.5; xx <= 60; xx += 9) {
          const d = Math.hypot(xx, yy);
          if (d > r - 31) continue;
          const rr = 1.6 + 1.7 * level * (.5 + .5 * Math.sin(d * .15 - t * (5 + cur.freq * 9))) + beat * .5 * (1 - d / 60);
          ctx.globalAlpha = .45 + .55 * level; ctx.beginPath(); ctx.arc(xx, yy, Math.max(1.2, rr), 0, TAU); ctx.fillStyle = K.cream; ctx.fill();
        }
        ctx.globalAlpha = 1; ctx.restore();
        if (level > .3) for (let k = 0; k < 3; k++) {
          const f = (t * .8 + k / 3) % 1;
          ctx.beginPath(); ctx.arc(0, 0, 14 + f * (r - 40), 0, TAU); ctx.strokeStyle = "rgba(157,255,189," + (.6 * level * (1 - f)) + ")"; ctx.lineWidth = 3; ctx.stroke();
        }
        const cap = 14 * (1 + .08 * beat);
        ctx.beginPath(); ctx.arc(0, 0, cap, 0, TAU); ctx.fillStyle = gradient(-cap, -cap, cap, cap, [[0, "#f7e394"], [.5, "#c9a227"], [1, "#8a6f12"]]); ctx.fill(); ctx.lineWidth = 3; ctx.strokeStyle = K.line; ctx.stroke();
        ctx.beginPath(); ctx.arc(-cap * .3, -cap * .3, cap * .3, 0, TAU); ctx.fillStyle = "#fff6dc"; ctx.fill();
        ctx.restore();
      };

      // visualizador: somente a linha pontilhada (alvo) e a verde (sinal)
      const scope = () => {
        const { x, y, w, h } = SCOPE;
        ctx.beginPath(); ctx.roundRect(x - 13, y - 13, w + 26, h + 26, 17); ctx.fillStyle = gradient(0, y - 13, 0, y + h + 13, [[0, "#c3cad8"], [.5, "#6c7283"], [1, "#30333d"]]); ctx.fill(); ctx.lineWidth = 4; ctx.strokeStyle = K.line; ctx.stroke();
        ctx.beginPath(); ctx.roundRect(x - 5, y - 5, w + 10, h + 10, 11); ctx.fillStyle = K.ink; ctx.fill();
        ctx.save(); ctx.beginPath(); ctx.roundRect(x, y, w, h, 8); ctx.clip();
        ctx.fillStyle = gradient(0, y, 0, y + h, [[0, "#0d2417"], [1, "#050d08"]]); ctx.fillRect(x, y, w, h);
        const vg = ctx.createRadialGradient(x + w / 2, y + h / 2, h * .35, x + w / 2, y + h / 2, w * .62); vg.addColorStop(0, "rgba(0,0,0,0)"); vg.addColorStop(1, "rgba(0,0,0,.55)");
        ctx.fillStyle = vg; ctx.fillRect(x, y, w, h);
        ctx.strokeStyle = "rgba(109,255,156,.09)"; ctx.lineWidth = 3;
        for (let i = 1; i < 8; i++) { ctx.beginPath(); ctx.moveTo(x + w * i / 8, y); ctx.lineTo(x + w * i / 8, y + h); ctx.stroke(); }
        for (let i = 1; i < 4; i++) { ctx.beginPath(); ctx.moveTo(x, y + h * i / 4); ctx.lineTo(x + w, y + h * i / 4); ctx.stroke(); }
        const path = (p, jitter) => {
          ctx.beginPath();
          for (let i = 0; i <= 120; i++) {
            const u = i / 120, k = M.clamp(wave(p, u) * .32 + (jitter ? Math.sin(i * 12.9 + t * 40) * jitter : 0), -.48, .48);
            ctx[i ? "lineTo" : "moveTo"](x + u * w, y + h / 2 - k * h);
          }
        };
        ctx.lineJoin = "round";
        ctx.setLineDash([12, 9]); path(tgt, 0); ctx.strokeStyle = "#f2c96a"; ctx.lineWidth = 3; ctx.stroke(); ctx.setLineDash([]);
        path(cur, (1 - score) * .035); ctx.strokeStyle = "rgba(109,255,156,.22)"; ctx.lineWidth = 13; ctx.stroke();
        ctx.strokeStyle = solved ? "#b8ffcf" : "#6dff9c"; ctx.lineWidth = 6; ctx.stroke();
        const sweep = x + ((t * .35) % 1) * w;
        ctx.fillStyle = "rgba(109,255,156,.07)"; ctx.fillRect(sweep - 30, y, 30, h);
        ctx.fillStyle = "rgba(0,0,0,.14)";
        for (let yy = y; yy < y + h; yy += 6) ctx.fillRect(x, yy, w, 3);
        ctx.fillStyle = "rgba(255,255,255,.06)"; ctx.beginPath(); ctx.moveTo(x + 8, y + 6); ctx.lineTo(x + 130, y + 6); ctx.lineTo(x + 60, y + h - 6); ctx.lineTo(x + 8, y + h - 6); ctx.closePath(); ctx.fill();
        ctx.restore();
        for (const [sx, sy] of [[x - 7, y - 7], [x + w + 7, y - 7], [x - 7, y + h + 7], [x + w + 7, y + h + 7]]) rivet(sx, sy, 3.6);
      };

      // botão de costura: o ponteiro aponta para o mouse; pontinhos de linha mostram quanto foi girado
      const knob = (def, i) => {
        const val = cur[def.key], cx = def.x, cy = KNOB_Y;
        for (let k = 0; k <= 10; k++) {
          const a = (-135 + k * 27) * RAD;
          ctx.beginPath(); ctx.arc(cx + Math.sin(a) * (KNOB_R + 9), cy - Math.cos(a) * (KNOB_R + 9), 2.2, 0, TAU);
          ctx.fillStyle = k / 10 <= val + .001 ? K.gold : "#8aa8e0"; ctx.fill();
        }
        ctx.beginPath(); ctx.arc(cx + 1.5, cy + 3, KNOB_R + 1, 0, TAU); ctx.fillStyle = "rgba(10,12,30,.45)"; ctx.fill();
        ctx.beginPath(); ctx.arc(cx, cy, KNOB_R, 0, TAU); ctx.fillStyle = gradient(cx - KNOB_R, cy - KNOB_R, cx + KNOB_R, cy + KNOB_R, [[0, "#fff6dc"], [.55, "#e2d3ab"], [1, "#b8a36f"]]); ctx.fill(); ctx.lineWidth = 3; ctx.strokeStyle = K.navy; ctx.stroke();
        ctx.beginPath(); ctx.arc(cx, cy, KNOB_R - 6, 0, TAU); ctx.strokeStyle = K.creamDark; ctx.lineWidth = 3; ctx.stroke();
        ctx.strokeStyle = K.maroon; ctx.lineWidth = 3;
        ctx.beginPath(); ctx.moveTo(cx - 5, cy - 5); ctx.lineTo(cx + 5, cy + 5); ctx.moveTo(cx + 5, cy - 5); ctx.lineTo(cx - 5, cy + 5); ctx.stroke();
        for (const [dx, dy] of [[-5, -5], [5, -5], [-5, 5], [5, 5]]) { ctx.beginPath(); ctx.arc(cx + dx, cy + dy, 2.6, 0, TAU); ctx.fillStyle = K.navy; ctx.fill(); }
        const a = (-135 + val * 270) * RAD;
        ctx.beginPath(); ctx.moveTo(cx + Math.sin(a) * 12, cy - Math.cos(a) * 12); ctx.lineTo(cx + Math.sin(a) * (KNOB_R - 4), cy - Math.cos(a) * (KNOB_R - 4));
        ctx.strokeStyle = K.navy; ctx.lineWidth = 6; ctx.lineCap = "round"; ctx.stroke(); ctx.lineCap = "butt";
        if (keyUsed && sel === i) { ctx.beginPath(); ctx.arc(cx, cy, KNOB_R + 16, 0, TAU); ctx.strokeStyle = K.cream; ctx.lineWidth = 3; ctx.setLineDash([6, 6]); ctx.stroke(); ctx.setLineDash([]); }
      };

      // zíper: o puxador tem forma de orelhinha; abaixo dele os dentes se encaixam
      const slider = (def, i) => {
        const val = cur[def.key], cx = def.x, y0 = TRACK_Y0, y1 = TRACK_Y1;
        const ty = y1 - THUMB_H - val * (y1 - y0 - THUMB_H);
        ctx.beginPath(); ctx.roundRect(cx - 15, y0 - 8, 30, y1 - y0 + 16, 7); ctx.fillStyle = gradient(cx - 15, 0, cx + 15, 0, [[0, "#e2d3ab"], [.5, "#fff6dc"], [1, "#d2bf8f"]]); ctx.fill(); ctx.lineWidth = 3; ctx.strokeStyle = K.navy; ctx.stroke();
        ctx.fillStyle = K.navy; ctx.fillRect(cx - 3, y0 - 4, 6, y1 - y0 + 8);
        for (let yy = y0, n = 0; yy < y1 + 2; yy += 7, n++) {
          const closed = yy > ty + THUMB_H;
          const lx = closed ? cx - 7 + (n % 2) * 2 : cx - 11, rx = closed ? cx - 1 - (n % 2) * 2 + 4 : cx + 5;
          ctx.fillStyle = "#a9b0bf"; ctx.fillRect(lx, yy, 6, 4); ctx.fillRect(rx, yy + (closed ? 3.5 : 0), 6, 4);
          ctx.fillStyle = K.line; ctx.fillRect(lx, yy + 4, 6, 1.5);
        }
        ctx.beginPath(); ctx.roundRect(cx - 13, ty, 26, THUMB_H, 5); ctx.fillStyle = gradient(0, ty, 0, ty + THUMB_H, [[0, "#e4e8f0"], [.5, "#a9b0bf"], [1, "#6c7283"]]); ctx.fill(); ctx.lineWidth = 3; ctx.strokeStyle = K.line; ctx.stroke();
        rivet(cx, ty + THUMB_H / 2, 3);
        ctx.beginPath(); ctx.ellipse(cx, ty + THUMB_H + 6, 6.5, 11, 0, 0, TAU); ctx.fillStyle = gradient(0, ty + THUMB_H - 4, 0, ty + THUMB_H + 18, [[0, "#c25a73"], [1, "#5a1c2e"]]); ctx.fill(); ctx.lineWidth = 3; ctx.strokeStyle = K.navy; ctx.stroke();
        ctx.beginPath(); ctx.ellipse(cx, ty + THUMB_H + 7, 2.4, 6, 0, 0, TAU); ctx.fillStyle = "#e08aa0"; ctx.fill();
        if (keyUsed && sel === KNOBS.length + i) { ctx.beginPath(); ctx.roundRect(cx - 24, y0 - 14, 48, y1 - y0 + 34, 8); ctx.strokeStyle = K.cream; ctx.lineWidth = 3; ctx.setLineDash([6, 6]); ctx.stroke(); ctx.setLineDash([]); }
      };

      // bordados sem palavras: o que cada controle faz
      const icons = () => {
        const y = 374;
        ctx.lineCap = "round"; ctx.lineWidth = 3; ctx.strokeStyle = K.cream;
        const sine = (cx, cycles, amp, phase = 0, w = 34) => { ctx.beginPath(); for (let i = 0; i <= 24; i++) { const u = i / 24; ctx[i ? "lineTo" : "moveTo"](cx - w / 2 + u * w, y - Math.sin(u * TAU * cycles + phase) * amp); } ctx.stroke(); };
        sine(KNOBS[0].x, 3.5, 4);
        sine(KNOBS[1].x, 1.5, 8);
        sine(KNOBS[2].x, 1.5, 5); ctx.save(); ctx.setLineDash([4, 4]); ctx.strokeStyle = "#8aa8e0"; sine(KNOBS[2].x, 1.5, 5, 1.7); ctx.restore();
        ctx.beginPath(); ctx.arc(SLIDERS[0].x, y, 6, 0, TAU); ctx.fillStyle = K.cream; ctx.fill();
        const hx = SLIDERS[1].x; ctx.beginPath(); ctx.arc(hx, y, 2.2, 0, TAU); ctx.fillStyle = K.cream; ctx.fill();
        ctx.beginPath(); for (const [dx, dy] of [[0, -8], [0, 8], [-8, 0], [8, 0]]) { ctx.moveTo(hx + dx * .55, y + dy * .55); ctx.lineTo(hx + dx, y + dy); } ctx.stroke();
        ctx.lineCap = "butt";
      };

      const draw = () => {
        v.begin();
        casing(); stars(); soundButton(); speaker(); scope();
        KNOBS.forEach(knob); SLIDERS.forEach(slider); icons();
        v.finish();
      };

      // ---------- entrada ----------
      const knobAt = p => KNOBS.findIndex(k => Math.hypot(p.x - k.x, p.y - KNOB_Y) < KNOB_R + 8);
      const sliderAt = p => SLIDERS.findIndex(s => Math.abs(p.x - s.x) < 22 && p.y > TRACK_Y0 - 10 && p.y < TRACK_Y1 + 24);
      const sliderValue = y => M.clamp((TRACK_Y1 - THUMB_H / 2 - y) / (TRACK_Y1 - TRACK_Y0 - THUMB_H));
      const onSound = p => Math.hypot(p.x - SOUND.x, p.y - SOUND.y) < SOUND.r + 3;
      // O ponteiro do botão aponta para o mouse: 0 graus é para cima, o arco útil vai de -135 a +135 graus.
      // Fora do arco (a abertura embaixo do botão) o valor trava no batente mais próximo.
      const aimKnob = p => {
        const dx = p.x - drag.cx, dy = p.y - KNOB_Y;
        if (Math.hypot(dx, dy) < 7) return;
        const deg = Math.atan2(dx, -dy) / RAD;
        drag.target = Math.abs(deg) <= 135 ? (deg + 135) / 270 : deg > 0 ? 1 : 0;
      };
      canvas.addEventListener("pointerdown", ev => {
        const p = v.point(ev);
        keyUsed = false;
        if (onSound(p)) { toggleSound(); return; }
        const k = knobAt(p);
        if (k >= 0) { sel = k; drag = { type: "knob", id: ev.pointerId, key: KNOBS[k].key, cx: KNOBS[k].x, target: cur[KNOBS[k].key] }; aimKnob(p); canvas.setPointerCapture(ev.pointerId); canvas.classList.add("is-grabbing"); return; }
        const s = sliderAt(p);
        if (s >= 0) { sel = KNOBS.length + s; drag = { type: "slider", id: ev.pointerId, key: SLIDERS[s].key }; set(drag.key, sliderValue(p.y)); canvas.setPointerCapture(ev.pointerId); canvas.classList.add("is-grabbing"); }
      });
      canvas.addEventListener("pointermove", ev => {
        const p = v.point(ev);
        if (!drag) { canvas.style.cursor = onSound(p) ? "pointer" : knobAt(p) >= 0 ? "grab" : sliderAt(p) >= 0 ? "ns-resize" : ""; return; }
        if (ev.pointerId !== drag.id) return;
        if (drag.type === "knob") aimKnob(p);
        else set(drag.key, sliderValue(p.y));
      });
      const release = () => { drag = null; canvas.classList.remove("is-grabbing"); };
      canvas.addEventListener("pointerup", release);
      canvas.addEventListener("pointercancel", release);
      canvas.addEventListener("wheel", ev => {
        const p = v.point(ev), k = knobAt(p), s = sliderAt(p);
        if (k < 0 && s < 0) return;
        ev.preventDefault();
        const key = k >= 0 ? KNOBS[k].key : SLIDERS[s].key;
        set(key, cur[key] - Math.sign(ev.deltaY) * (k >= 0 ? .02 : .03));
      }, { passive: false });

      reset();
      return {
        reset,
        activate() { v.resize(); sound.start(); },
        deactivate() { sound.stop(); drag = null; },
        update,
        draw,
        state: () => ({ cur, tgt, score, solved, set, similarity, ears }),
        keydown(ev) {
          const key = ev.key.length === 1 ? ev.key.toLowerCase() : ev.key;
          if (key === "ArrowLeft") { keyUsed = true; sel = (sel + CONTROLS.length - 1) % CONTROLS.length; return true; }
          if (key === "ArrowRight") { keyUsed = true; sel = (sel + 1) % CONTROLS.length; return true; }
          if (key === "ArrowUp" || key === "ArrowDown") { keyUsed = true; const id = CONTROLS[sel].key; set(id, cur[id] + (key === "ArrowUp" ? 1 : -1) * (ev.shiftKey ? .05 : .01)); return true; }
          if (key === "m") { toggleSound(); return true; }
          return false;
        },
        keyup() {}
      };
    }
  });
})();
