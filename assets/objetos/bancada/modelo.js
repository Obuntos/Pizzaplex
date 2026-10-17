(() => {
  "use strict";
  const lab = window.TileLab;
  lab.registerModel({
    id: "bancada", label: "Bancada de manutenção", height: 31,
    footprint: Object.freeze({ width: 2, depth: 1 }),
    build(b, options) {
      const m = lab.materials;
      for (const u of [-.79, .79]) for (const v of [-.29, .29]) b.box({ u, v, w: .09, d: .08, h: 28, material: m.metal, outline: .55 });
    for (const v of [-.29, .29]) b.box({ v, w: 1.62, d: .05, z: 9, h: 2.5, material: m.trim, outline: .5 });
    for (const u of [-.79, .79]) b.box({ u, w: .05, d: .6, z: 9, h: 2.5, material: m.trim, outline: .5 });
    b.box({ w: 1.87, d: .83, z: 28, h: 3, material: m.wood, outline: .75 });
    }
  });
})();
