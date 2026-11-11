(() => {
  "use strict";
  const lab = window.TileLab, stair = lab.stair;
  lab.registerModel({ id: "escada-madeira", label: "Escada de madeira", height: stair.totalHeight, footprint: Object.freeze({ width: 1, depth: 1 }), build(b) { for (let level = 1; level <= stair.count; level++) b.box({ v: stair.center(level), w: stair.width, d: 1 / stair.count, h: level * stair.rise, material: lab.materials.wood, outline: .65 }); } });
})();
