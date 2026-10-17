(() => {
  "use strict";
  const lab = window.TileLab;
  lab.registerModel({
    id: "balcao", label: "Balcão", height: 31,
    footprint: Object.freeze({ width: 2, depth: 1 }),
    build(b, options) {
      const m = lab.materials;
      b.box({ w: 1.78, d: .75, h: 28, material: m.metal });
    b.box({ w: 1.9, d: .85, z: 28, h: 3, material: m.metal });
    for (const u of [-.435, .435]) {
      b.box({ u, v: .379, w: .8, d: .012, z: 3, h: 22, material: m.trim, outline: .55 });
      b.box({ u: u + .29, v: .396, w: .035, d: .01, z: 13, h: 5, material: m.metal, outline: .35 });
    }
    }
  });
})();
