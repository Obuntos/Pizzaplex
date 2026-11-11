(() => {
  "use strict";
  const lab = window.TileLab;
  lab.registerModel({
    id: "palco", label: "Bloco de palco", height: 18,
    footprint: Object.freeze({ width: 1, depth: 1 }),
    build(b, options) {
      const m = lab.materials;
      b.box({ h: 17, material: m.stage, outline: .7 });
    b.box({ z: 17, h: 1, material: m.stage, outline: .65 });
    }
  });
})();
