(() => {
  "use strict";
  const lab = window.TileLab;
  lab.registerModel({ id: "porta", label: "Porta normal", height: 104, footprint: Object.freeze({ width: 1, depth: 1 }), build(b, options) { lab.buildDoor(b, options, false); } });
})();
