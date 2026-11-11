(() => {
  "use strict";
  const lab = window.TileLab;
  lab.registerModel({
    id: "suporte-manutencao", label: "Suporte de manutenção", height: 60,
    footprint: Object.freeze({ width: 1, depth: 1 }),
    build(b) {
      const m = lab.materials;
      b.box({ w: .53, d: .36, h: 2, material: m.trim, outline: .55 });
      b.box({ v: -.16, w: .09, d: .08, z: 2, h: 58, material: m.metal, outline: .55 });
      b.box({ v: -.16, w: .31, d: .075, z: 40, h: 3, material: m.trim, outline: .4 });
      b.box({ v: -.16, w: .36, d: .065, z: 57, h: 3, material: m.metal, outline: .4 });
    }
  });
})();
