(() => {
  "use strict";
  const lab = window.TileLab;
  lab.CaixaGeometry = Object.freeze({
    closed(b) {
      const m = lab.materials;
      b.box({ w: .36, d: .30, h: 11, material: m.wood, outline: .5 });
      b.box({ w: .045, d: .30, z: 11, h: .3, material: m.plaster, outline: .18 });
    },
    open(b, options) {
      const m = lab.materials;
      const angle = b.rotation + b.groups.reduce((sum, group) => sum + (group.angle || 0), 0);
      const face = (vertices, color, outline = .35) => {
        const points = vertices.map(([u, v, z]) => b.point({ u, v, z }));
        const depth = points.reduce((sum, p) => sum + (p.u + p.v) * 32 + p.z, 0) / points.length;
        b.faces.push({ points, color, depth, outline, line: m.wood.line, order: b.sequence++ });
      };
      for (const inner of [false, true]) {
        const u = inner ? .15 : .18, v = inner ? .12 : .15, bottom = inner ? 2 : 0;
        const walls = [
          { normal: [1, 0], vertices: [[u, -v, bottom], [u, v, bottom], [u, v, 11], [u, -v, 11]] },
          { normal: [-1, 0], vertices: [[-u, v, bottom], [-u, -v, bottom], [-u, -v, 11], [-u, v, 11]] },
          { normal: [0, 1], vertices: [[u, v, bottom], [-u, v, bottom], [-u, v, 11], [u, v, 11]] },
          { normal: [0, -1], vertices: [[-u, -v, bottom], [u, -v, bottom], [u, -v, 11], [-u, -v, 11]] }
        ];
        for (const wall of walls) {
          const sign = inner ? -1 : 1, normal = lab.rotate(wall.normal[0] * sign, wall.normal[1] * sign, angle);
          if (normal.u + normal.v < .0001) continue;
          face(wall.vertices, normal.u > .5 ? m.wood.side : m.wood.front, inner ? .15 : .45);
        }
      }
      face([[-.18, -.15, 11], [.18, -.15, 11], [.15, -.12, 11], [-.15, -.12, 11]], m.wood.top, .15);
      face([[.18, -.15, 11], [.18, .15, 11], [.15, .12, 11], [.15, -.12, 11]], m.wood.top, .15);
      face([[.18, .15, 11], [-.18, .15, 11], [-.15, .12, 11], [.15, .12, 11]], m.wood.top, .15);
      face([[-.18, .15, 11], [-.18, -.15, 11], [-.15, -.12, 11], [-.15, .12, 11]], m.wood.top, .15);
      face([[-.15, -.12, 2], [.15, -.12, 2], [.15, .12, 2], [-.15, .12, 2]], m.wood.side, 0);
      if (options.filled !== false) lab.CaixaGeometry.parts(b);
    },
    parts(b) {
      const m = lab.materials;
      b.box({ u: -.06, w: .10, d: .14, z: 2.5, h: 6, material: m.metal, outline: .3 });
      b.box({ u: .07, v: .03, w: .07, d: .10, z: 2.5, h: 5, material: m.metal, outline: .25 });
    }
  });
})();
