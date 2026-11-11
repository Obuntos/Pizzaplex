(() => {
  "use strict";
  const clamp = (v, a = 0, b = 1) => Math.min(b, Math.max(a, v));
  const mix = (a, b, k) => a + (b - a) * k;
  const wrap = a => { a = (a + 180) % 360; if (a < 0) a += 360; return a - 180; };
  const rand = (a, b) => a + Math.random() * (b - a);
  const pick = list => list[Math.floor(Math.random() * list.length)];
  const shuffle = list => {
    const out = [...list];
    for (let i = out.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [out[i], out[j]] = [out[j], out[i]]; }
    return out;
  };
  const store = {
    get(key) { try { return JSON.parse(localStorage.getItem("orelhitas-mini-" + key)); } catch (e) { return null; } },
    set(key, value) { try { localStorage.setItem("orelhitas-mini-" + key, JSON.stringify(value)); } catch (e) {} }
  };
  const fmt = s => {
    const whole = Math.floor(s);
    return Math.floor(whole / 60) + ":" + String(whole % 60).padStart(2, "0") + "." + Math.floor((s - whole) * 10);
  };

  const parse = list => list.split(" ").map(h => [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16)]);
  const PALETTES = {
    steel: parse("14151a 0d0e13 08090c 1a1a1f 30333d 3b3f4b 474c5a 4a4f5d 5d6170 6c7283 818899 8a90a0 9ea3b1 a9b0bf b3bac8 c3cad8 d6dbe6 e4e8f0 eef0f8 f8f9fd ffffff " +
      "12191c 1a2327 1c2a2f 1f2b30 26343a 2a3a40 2f4047 3c4d54 42535a 617a81 96adb3 b8ccd0 bec9b5 dfe4e0 ece8d6 d6d1b9 aaa58e " +
      "1f2b7c 2b56b8 4c66dc 86a0ff 4a7be0 1b3a86 9db9f5 6f1420 a31f2c d23a48 f08a93 e0605a 5a2a2a 3a1a1c 7d640f 8a6f12 c9a227 e8c340 f0d56a f7e394 d3af76 f2c96a " +
      "0b2c1f 0e3a29 1d6b4a 2c8a52 2f6b4a 58e08a 8fd19e 6dff9c 050d08 0d2417 2a3a30 4a2563 6a3787 5b2f78 1b1020 24122f"),
    costume: parse("0a0c1e 10132b 151a3a 1b2148 232a5a 2d3670 2f4f9e 3a64b8 4a78cf 5a96e8 74aef2 9cc8fa bfdcff 8aa8e0 " +
      "fff6dc efe4c8 e2d3ab d2bf8f b8a36f 8f7d52 6a5a3a 3f3422 2a2216 3a1220 5a1c2e 7a2740 8c2f46 a8405a c25a73 e08aa0 " +
      "e8873a f2a65a f2c96a e8c340 c9a227 8a6f12 f0d56a f7e394 d23a48 a31f2c e0605a " +
      "050d08 0a1a10 0d2417 0b2c1f 0e3a29 1d6b4a 2c8a52 58e08a 6dff9c 9dffbd b8ffcf d8ffe6 " +
      "14151a 1a1a1f 30333d 3b3f4b 474c5a 5d6170 6c7283 8a90a0 a9b0bf c3cad8 e4e8f0 f8f9fd ffffff"),
    purple: parse("12091a 1b1020 24122f 25142f 2c1d38 2f1f3b 3a1c4e 43324f 4a2563 5b2f78 5e4a70 6a3787 6d5a7d 7d6a8c 8b7a99 a896b8 b9aac6 cdb7dd d9cfe3 c4a8d8 d9c3e8 a88bc0 eadcf3 f3e6a8 " +
      "3a2a35 2e1f29 241a21 1d1419 0b2c1f 0e3a29 1d6b4a 2c8a52 2f6b4a 58e08a 8fd19e 6dff9c 9dffbd b8ffcf 050d08 0d2417 " +
      "e0605a 3a1a1c 5a2a2a 7d640f c9a227 e8c340 d3af76 f2c96a 3a2f0a ffffff")
  };
  const luts = {};
  const nearest = (kind, r, g, b) => {
    const palette = PALETTES[kind], lut = luts[kind] || (luts[kind] = new Int16Array(32768).fill(-1));
    const key = ((r >> 3) << 10) | ((g >> 3) << 5) | (b >> 3);
    let hit = lut[key];
    if (hit < 0) {
      const cr = (r & 248) + 4, cg = (g & 248) + 4, cb = (b & 248) + 4;
      let best = 1e12;
      for (let i = 0; i < palette.length; i++) {
        const p = palette[i], dr = p[0] - cr, dg = p[1] - cg, db = p[2] - cb, d = dr * dr * .3 + dg * dg * .59 + db * db * .11;
        if (d < best) { best = d; hit = i; }
      }
      lut[key] = hit;
    }
    return hit;
  };

  const GLYPHS = {
    A: "111101111101101", B: "110101110101110", C: "111100100100111", D: "110101101101110", E: "111100110100111", F: "111100110100100",
    G: "111100101101111", H: "101101111101101", I: "111010010010111", J: "001001001101111", K: "101101110101101", L: "100100100100111",
    M: "101111111101101", N: "110101101101101", O: "111101101101111", P: "111101111100100", Q: "111101101111001", R: "111101110101101",
    S: "111100111001111", T: "111010010010010", U: "101101101101111", V: "101101101101010", W: "101101111111101", X: "101101010101101",
    Y: "101101010010010", Z: "111001010100111", 0: "111101101101111", 1: "010110010010111", 2: "111001111100111", 3: "111001111001111",
    4: "101101111001001", 5: "111100111001111", 6: "111100111101111", 7: "111001001010010", 8: "111101111101111", 9: "111101111001111",
    "%": "101001010100101", ".": "000000000000010", "-": "000000111000000", ":": "000010000010000", "/": "001001010100100", ",": "000000000010100", " ": "000000000000000"
  };

  const pixel = (canvas, W, H, PX, kind = "steel") => {
    const v = { scale: 1, ox: 0, oy: 0, PX };
    const ctx = canvas.getContext("2d", { willReadFrequently: true });
    const desc = Object.getOwnPropertyDescriptor(CanvasRenderingContext2D.prototype, "lineWidth");
    Object.defineProperty(ctx, "lineWidth", { configurable: true, get() { return desc.get.call(ctx); }, set(x) { desc.set.call(ctx, Math.max(x, PX)); } });
    canvas.width = Math.ceil(W / PX); canvas.height = Math.ceil(H / PX);
    v.ctx = ctx;
    v.resize = () => {
      const b = canvas.getBoundingClientRect();
      v.scale = Math.max(.01, Math.min(b.width / W, b.height / H));
      v.ox = (b.width - W * v.scale) / 2;
      v.oy = (b.height - H * v.scale) / 2;
    };
    v.begin = () => {
      ctx.setTransform(1, 0, 0, 1, 0, 0);
      ctx.imageSmoothingEnabled = false;
      ctx.setTransform(1 / PX, 0, 0, 1 / PX, 0, 0);
    };
    v.finish = () => {
      const w = canvas.width, h = canvas.height;
      ctx.setTransform(1, 0, 0, 1, 0, 0);
      const img = ctx.getImageData(0, 0, w, h), d = img.data;
      for (let i = 0; i < d.length; i += 4) {
        const p = PALETTES[kind][nearest(kind, d[i], d[i + 1], d[i + 2])];
        d[i] = p[0]; d[i + 1] = p[1]; d[i + 2] = p[2]; d[i + 3] = 255;
      }
      ctx.putImageData(img, 0, 0);
    };
    v.text = (str, x, y, color, scale = 1, align = "left") => {
      const text = String(str).normalize("NFD").replace(/[\u0300-\u036f]/g, "").toUpperCase(), u = PX * scale;
      const width = text.length * 4 * u - u;
      let cx = align === "center" ? x - width / 2 : align === "right" ? x - width : x;
      cx = Math.round(cx / PX) * PX; y = Math.round(y / PX) * PX;
      ctx.fillStyle = color;
      for (const ch of text) {
        const g = GLYPHS[ch] || GLYPHS[" "];
        for (let i = 0; i < 15; i++) if (g[i] === "1") ctx.fillRect(cx + (i % 3) * u, y + Math.floor(i / 3) * u, u, u);
        cx += 4 * u;
      }
    };
    v.textWidth = (str, scale = 1) => String(str).length * 4 * PX * scale - PX * scale;
    v.point = e => {
      const b = canvas.getBoundingClientRect();
      return { x: (e.clientX - b.left - v.ox) / v.scale, y: (e.clientY - b.top - v.oy) / v.scale };
    };
    new ResizeObserver(v.resize).observe(canvas);
    v.resize();
    return v;
  };

  const overlay = root => {
    const box = document.createElement("div");
    box.className = "overlay";
    box.hidden = true;
    box.innerHTML = '<div class="card"><h3></h3><p></p><button type="button"></button></div>';
    root.appendChild(box);
    const title = box.querySelector("h3"), text = box.querySelector("p"), button = box.querySelector("button");
    let action = null;
    button.addEventListener("click", () => { if (action) action(); });
    return {
      show(head, body, label, fn, mode = "") {
        title.textContent = head; text.textContent = body; button.textContent = label;
        action = fn; box.className = "overlay " + mode; box.hidden = false;
        button.focus({ preventScroll: true });
      },
      hide() { box.hidden = true; },
      get visible() { return !box.hidden; }
    };
  };

  window.Mini = { clamp, mix, wrap, rand, pick, shuffle, store, fmt, pixel, overlay, TAU: Math.PI * 2, RAD: Math.PI / 180, games: [], register(game) { this.games.push(game); }, hud: { set() {} } };
})();
