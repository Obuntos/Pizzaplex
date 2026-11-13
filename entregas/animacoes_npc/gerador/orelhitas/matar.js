(() => {
  "use strict";
  // MATAR · o animatrônico agarra o adulto pelos ombros, sacode e morde, e solta o corpo no chão.
  // Linha do tempo (segundos, 12 quadros/s), igual nas quatro versões para casar com o humano:
  //   começo 0–1,25  (olhos escurecem, a cabeça trava na vítima, um passo à frente, braços sobem e agarram)
  //   loop   1,25–2,75 (sacode a vítima erguida e morde)
  //   fim    2,75–4,75 (solta, a vítima cai, olha para o corpo e volta à postura)
  // Cada versão mantém a própria postura de "possuído" e o próprio jeito de mexer:
  //   Orelhitas: preciso · Toy: rápido, passa do ponto · Quebrado: aos trancos, braço direito fraco ·
  //   Toy quebrado: aos trancos, mandíbula em etapas, perna esquerda rígida (não dá o passo).
  const lab = window.Animatronicos;
  const skinId = document.body.dataset.skin;
  const T = (v0, ...keys) => lab.trilho(v0, keys);
  const ESTILO = {
    carcacacoelho: { mov: "firme", rap: "seco", forte: "assenta", treme: .5, fraco: 1, atraso: 0, pe: 1 },
    brinquedocoelho: { mov: "passa", rap: "seco", forte: "passa", treme: .7, fraco: 1, atraso: 0, pe: 1 },
    orelhitasquebrado: { mov: "tranco3", rap: "tranco2", forte: "tranco3", treme: 1, fraco: .75, atraso: .1, pe: 1 },
    toyquebrado: { mov: "tranco4", rap: "tranco2", forte: "tranco3", treme: 1.1, fraco: .85, atraso: .08, pe: 1 }
  }[skinId];
  const S = ESTILO, I = 1.25, L = 2.75, F = 4.75;
  // postura de base: a do "parado possuído" da própria versão, já tomada
  const base = (() => {
    const p = lab.performances.possessed(.05, skinId, { from: "possessed" });
    const m = lab.motion(p); delete m.nota; return m;
  })();
  const A0 = base.arms, L0 = base.armLift, O0 = base.armOut;
  // Braços: alcance à frente (arms), altura (armLift), abertura (armOut). Índice 1 = lado direito dele.
  const braco = i => {
    const fr = i ? S.fraco : 1, at = i ? 0 : S.atraso;
    const sac = []; for (let k = 0; k < 6; k++) sac.push([I + .02 + k * .25, 14 + (k % 2 ? -1.2 : 1.2) * S.treme, .11, S.rap]);
    const sobe = []; for (let k = 0; k < 6; k++) sobe.push([I + .02 + k * .25, (9 + 4 * fr) + (k % 2 ? 0 : 1.2 * S.treme), .11, S.rap]);
    return {
      arms: T(A0[i], [.35 + at, 9, .3, S.mov], [.8 + at, 17, .18, S.forte], [1.05, 14, .14, S.rap], ...sac, [L, 14, .05], [L + .05, 9, .35, "cede"], [L + 1.2, A0[i], .45, S.mov]),
      armLift: T(L0[i], [.35 + at, 4 * fr, .3, S.mov], [.8 + at, 10 * fr, .18, S.forte], [1.05, 9, .14, S.rap], ...sobe, [L, 11, .05], [L + .05, -2, .4, "cede"], [L + 1.2, L0[i], .45, S.mov]),
      armOut: T(O0[i], [.35 + at, -2, .3, S.mov], [.8 + at, -4, .18, S.forte], [1.05, -6.6, .14, S.rap], [L + .05, -2, .35], [L + 1.2, O0[i], .45, S.mov]),
      handGrip: T(base.handGrip[i], [.6, 0, .1, "seco"], [1.05, 1, .08, "seco"], [L + .02, 0, .08, "seco"], [L + 1.2, base.handGrip[i], .3])
    };
  };
  const b0 = braco(0), b1 = braco(1);
  const mord = []; for (let k = 0; k < 4; k++) mord.push([I + .1 + k * .37, 1.9, .07, S.rap], [I + .28 + k * .37, .7, .08, S.rap]);
  const cab = []; for (let k = 0; k < 4; k++) cab.push([I + .1 + k * .37, 1.2, .07, S.rap], [I + .28 + k * .37, .2, .08, S.mov]);
  const tremor = []; for (let k = 0; k < 6; k++) tremor.push([I + .02 + k * .25, (k % 2 ? -.06 : .06) * S.treme, .1, S.rap]);
  const cena = lab.cena({
    ...base,
    eyeBlack: T(base.eyeBlack || 0, [.05, 1, .08, "seco"]),
    lid: 0, pupil: T(1, [.05, .7, .1, "seco"]),
    headTurn: T(base.headTurn, [.15, 0, .12, S.rap], [L + .5, 0, .2]),
    headTilt: T(base.headTilt, [.15, -.04, .12, S.rap], ...tremor, [L + .6, .22, .3, S.mov], [F - .6, base.headTilt, .4, S.mov]),
    headLift: T(base.headLift, [.15, 0, .15, S.mov], [.8, 1.2, .15, S.forte], ...cab, [L + .6, -2.2, .3, S.mov], [F - .6, base.headLift, .4, S.mov]),
    gaze: T(base.gaze, [.08, 0, .06, "seco"]), gazeY: T(base.gazeY || 0, [L + .55, .6, .1, "seco"], [F - .6, base.gazeY || 0, .2]),
    jaw: T(base.jaw, [.8, 1.9, .12, S.rap], [1.05, .7, .1, S.rap], ...mord, [L + .1, 1.1, .2], [F - .8, base.jaw, .3]),
    tilt: T(base.tilt, [.35, Math.min(base.tilt, 1), .3, S.mov], [.8, 2.4, .18, S.forte], [L + .1, 1.6, .3], [L + .6, 3.2, .3, S.mov], [F - .6, base.tilt, .45, S.mov]),
    bob: T(base.bob, [.35, base.bob - 1, .3, S.mov], [L + .6, base.bob - 1.6, .3], [F - .6, base.bob, .4]),
    footTravel: [base.footTravel[0], T(base.footTravel[1], [.3, 6, .3, S.mov], [L + 1.3, base.footTravel[1], .35, S.mov])],
    footLift: [base.footLift[0], T(0, [.3, 2.2, .15], [.45, 0, .15], [L + 1.3, 2, .15], [L + 1.45, 0, .15])],
    gesture: T(base.gesture, [.35, .35, .3], [L + 1.2, base.gesture, .4]),
    arms: [b0.arms, b1.arms], armLift: [b0.armLift, b1.armLift], armOut: [b0.armOut, b1.armOut], handGrip: [b0.handGrip, b1.handGrip],
    handTurn: base.handTurn
  }, 0);
  lab.performances.matar = time => ({ ...cena(time), keepArms: true });
  lab.filters.matar = pose => { pose.keepArms = true; return pose; };
  lab.MATAR = { inicio: I, loop: L, fim: F, fps: 12 };
})();
