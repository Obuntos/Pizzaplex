(() => {
  "use strict";
  const lab = window.TileLab;
  lab.registerModel({
    id: "cadeira", label: "Cadeira", height: 37,
    footprint: Object.freeze({ width: 1, depth: 1 }),
    build(b, options) {
      const m = lab.materials;
      for (const u of [-.19, .19]) {
        b.box({ u, v: .17, w: .055, d: .055, h: 19, material: m.trim, outline: .5 });
        b.box({ u, v: -.17, w: .055, d: .055, h: 37, material: m.trim, outline: .5 });
      }
      b.box({ w: .48, d: .44, z: 17, h: 2, material: m.trim, outline: .55 });
      b.box({ w: .46, d: .42, z: 19, h: 1.7, material: m.red, outline: .55 });
      b.box({ v: -.15, w: .44, d: .04, z: 27, h: 10, material: m.metal, outline: .65 });
      b.box({ v: -.115, w: .4, d: .03, z: 27.5, h: 9, material: m.red, outline: .45 });
    }
  });
})();
