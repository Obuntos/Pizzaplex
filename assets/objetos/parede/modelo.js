(() => {
  "use strict";
  const lab = window.TileLab;
  lab.registerModel({
    id: "parede", label: "Parede", height: 104, footprint: Object.freeze({ width: 1, depth: 1 }),
    build(b, options) {
      const m = lab.materials, height = options.height ?? (options.cut ? 52 : 104), neighbors = options.neighbors || [0, 0, 0, 0];
      const bands = [[0, 14, m.trim], [14, 78, m.plaster], [78, 79.4, m.red], [79.4, 103, m.plaster]];
      for (const [z, top, material] of bands) lab.wallPrism(b, z, Math.min(top, height - 1), material, neighbors);
      lab.wallPrism(b, Math.max(0, height - 1), height, m.trim, neighbors);
    }
  });
})();
