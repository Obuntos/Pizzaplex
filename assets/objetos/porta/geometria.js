(() => {
  "use strict";
  const lab = window.TileLab;
  lab.buildDoor = (b, options, double = false) => {
    const m = lab.materials, height = options.height ?? 104, full = height >= 104, width = double ? 2 : 1, clear = double ? 1.72 : .76, leaf = double ? clear / 2 : clear;
    for (const side of [-1, 1]) {
      b.box({ u: side * (width / 2 - .06), w: .12, d: 1, h: full ? 98 : height - 1, material: m.plaster, outline: .6 });
      if (!full) b.box({ u: side * (width / 2 - .06), w: .12, d: 1, z: height - 1, h: 1, material: m.trim, outline: .5 });
    }
    if (full) { b.box({ z: 98, w: width, d: 1, h: 5, material: m.plaster }); b.box({ z: 103, w: width, d: 1, h: 1, material: m.trim }); }
    if (height <= 6) return;
    const sides = double ? [-1, 1] : [-1], amount = options.openAmount ?? Number(options.open), leafHeight = Math.min(96, height - 1);
    for (const side of sides) b.group({ u: side * clear / 2, angle: side * Math.PI / 2 * amount }, () => {
      const u = -side * leaf / 2;
      b.box({ u, w: leaf - .012, d: .065, z: 1, h: leafHeight, material: m.wood });
      for (const v of [-.036, .036]) {
        if (height >= 79) b.box({ u, v, w: double ? .29 : .28, d: .007, z: 61, h: 17, material: m.glass, outline: .55 });
        if (height >= 47) b.box({ u: -side * (leaf - .1), v, w: .055, d: .015, z: 43, h: 2.2, material: m.trim, outline: .4 });
      }
    });
  };
})();
