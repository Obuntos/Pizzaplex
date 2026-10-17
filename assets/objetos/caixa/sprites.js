(() => {
  "use strict";
  const lab = window.TileLab;
  lab.CaixaSprites = Object.freeze({
    states: Object.freeze([
      Object.freeze({ id: "fechada", label: "Fechada", options: Object.freeze({ open: false }) }),
      Object.freeze({ id: "aberta", label: "Aberta com peças", options: Object.freeze({ open: true, filled: true }) }),
      Object.freeze({ id: "aberta-vazia", label: "Aberta vazia", options: Object.freeze({ open: true, filled: false }) })
    ]),
    sheet(renderer) {
      const canvas = document.createElement("canvas");
      canvas.width = lab.frame.width * 4; canvas.height = lab.frame.height * this.states.length;
      const context = canvas.getContext("2d");
      this.states.forEach((state, row) => context.drawImage(renderer.sheet(state.options), 0, row * lab.frame.height));
      return canvas;
    }
  });
})();
