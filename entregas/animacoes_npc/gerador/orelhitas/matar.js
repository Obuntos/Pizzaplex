(() => {
  "use strict";
  // ATAQUE · o animatrônico recebe, quadro a quadro, os canais calculados em Python (gerador/ataques.py),
  // onde as mãos dele são postas exatamente sobre o corpo da vítima. Aqui só:
  //   - a pose de base (o "parado possuído" da própria versão), por baixo dos canais do quadro;
  //   - o esqueleto livre (sem os empurrões de braço das vistas de perfil, que tirariam as mãos do lugar).
  const lab = window.Animatronicos;
  const skinId = document.body.dataset.skin;
  const base = (() => { const p = lab.performances.possessed(.05, skinId, { from: "possessed" }); const m = lab.motion(p); delete m.nota; return m; })();
  window.QUADROS = window.QUADROS || [];
  lab.performances.matar = time => {
    const q = window.QUADROS[Math.max(0, Math.min(window.QUADROS.length - 1, Math.round(time * 12)))] || {};
    return { ...base, ...q, keepArms: true };
  };
  lab.filters.matar = pose => { pose.keepArms = true; return pose; };
  const skin = lab.skins.get(skinId), proto = skin.Renderer.prototype, original = proto.buildRig;
  proto.buildRig = function (actor) {
    if (actor.animation !== "matar" || skinId === "toyquebrado") return original.call(this, actor);
    return lab.freeRig(lab.pose(actor), { ...lab.dims, ...this.skin.dims });
  };
})();
