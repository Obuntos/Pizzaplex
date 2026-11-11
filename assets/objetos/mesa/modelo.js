(() => {
  "use strict";
  const lab = window.TileLab;
  lab.registerModel({
    id: "mesa", label: "Mesa", height: 29,
    footprint: Object.freeze({ width: 1, depth: 1 }),
    build(b, options) {
      const m = lab.materials;
      for (const u of [-.27, .27]) for (const v of [-.27, .27]) b.box({ u, v, w: .065, d: .065, h: 26, material: m.trim, outline: .55 });
    b.box({ w: .72, d: .72, z: 26, h: 3, material: m.yellow, outline: .7 });
    }
  });
})();
