(() => {
  "use strict";
  const lab = window.TileLab;
  lab.registerModel({
    id: "caixa", label: "Caixa de peças", height: 11.3,
    footprint: Object.freeze({ width: 1, depth: 1 }),
    build(builder, options) {
      if (options.open) lab.CaixaGeometry.open(builder, options);
      else lab.CaixaGeometry.closed(builder);
    }
  });
})();
