(() => {
  // Desenha quadros numa tela comum 160x130 (chão em 80, 92) em duas camadas:
  //   longe = o braço do lado oposto à câmera (vai ATRÁS da vítima) · resto = todo o resto.
  const lab = window.Animatronicos;
  const skinId = document.body.dataset.skin, skin = lab.skins.get(skinId);
  const proto = skin.Renderer.prototype, braco = proto.arm;
  let pular = false;
  proto.arm = function (ctx, rig, limb) {
    if (pular && lab.depth(limb.root, rig.angle) < -.1) return;
    return braco.call(this, ctx, rig, limb);
  };
  const quadro = (d, t, anim, semLonge) => {
    pular = semLonge;
    const native = new skin.Renderer(skin);
    const actor = { skin: skinId, x: 0, y: 0, facing: d, animation: anim, from: null, reaction: 'neutral', phase: 0, strength: 0, time: t, transition: null, transitionClock: .4 };
    lab.march.novo(actor);
    const c = native.draw(actor);
    const o = document.createElement('canvas'); o.width = 160; o.height = 130;
    o.getContext('2d').drawImage(c, c.width === 160 ? 0 : 80 - lab.size.x, 0);
    pular = false;
    return o;
  };
  window.renderiza = (anim, tempos, dirs) => dirs.map(d => tempos.map(t => {
    const cheio = quadro(d, t, anim, false), resto = quadro(d, t, anim, true);
    // braço de lá = o que aparece no quadro cheio e não aparece sem ele
    const a = cheio.getContext('2d').getImageData(0, 0, 160, 130), b = resto.getContext('2d').getImageData(0, 0, 160, 130);
    const l = new ImageData(160, 130);
    for (let i = 0; i < a.data.length; i += 4) {
      const dif = Math.abs(a.data[i] - b.data[i]) + Math.abs(a.data[i + 1] - b.data[i + 1]) + Math.abs(a.data[i + 2] - b.data[i + 2]) + Math.abs(a.data[i + 3] - b.data[i + 3]);
      if (dif > 6) for (let k = 0; k < 4; k++) l.data[i + k] = a.data[i + k];
    }
    const lc = document.createElement('canvas'); lc.width = 160; lc.height = 130; lc.getContext('2d').putImageData(l, 0, 0);
    return { resto: resto.toDataURL('image/png'), longe: lc.toDataURL('image/png') };
  }));
  window.info = () => ({ skin: skinId, size: lab.size });
})();
