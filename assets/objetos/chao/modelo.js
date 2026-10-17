(() => {
  "use strict";
  const lab = window.TileLab;
  lab.registerModel({
    id: "chao", label: "Chão", height: 0,
    footprint: Object.freeze({ width: 1, depth: 1 }),
    build(b, options) {
      const m = lab.materials;
      b.box({ z: -2, h: 2, material: lab.floorMaterial(options.color), outline: .65 });
    }
  });
})();
