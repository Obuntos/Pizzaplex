(() => {
  "use strict";
  const lab = window.TileLab;
  lab.registerModel({ id: "porta-dupla", label: "Porta dupla", height: 104, footprint: Object.freeze({ width: 2, depth: 1 }), build(b, options) { lab.buildDoor(b, options, true); } });
})();
