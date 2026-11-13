(() => {
  const lab = window.Animatronicos;
  const skinId = document.body.dataset.skin, skin = lab.skins.get(skinId);
  window.renderiza = (anim, tempos, dirs, extra = {}) => {
    const out = [];
    for (const d of dirs) {
      const linha = [];
      for (const t of tempos) {
        const native = new skin.Renderer(skin);
        const actor = { skin: skinId, x: 0, y: 0, facing: d, animation: anim, from: extra.from ?? null, reaction: 'neutral', phase: 0, strength: 0, time: t, transition: null, transitionClock: .4 };
        lab.march.novo(actor);
        const c = native.draw(actor);
        // tela comum 160x130 com o chão em (80, 92), igual à do toy quebrado
        const o = document.createElement('canvas'); o.width = 160; o.height = 130;
        const dx = c.width === 160 ? 0 : 80 - lab.size.x;
        o.getContext('2d').drawImage(c, dx, 0);
        linha.push(o.toDataURL('image/png'));
      }
      out.push(linha);
    }
    return out;
  };
  window.info = () => ({ skin: skinId, anims: skin.animations, size: lab.size });
})();
