(() => {
  "use strict";
  const lab = window.TileLab;
  lab.wallPrism = (b, z, top, material, neighbors = [0, 0, 0, 0]) => {
    if (top <= z) return;
    const add = (points, normal, strokeEdges) => {
      const n = lab.rotate(normal[0], normal[1], b.rotation);
      if (!normal[2] && n.u + n.v < .0001) return;
      const world = points.map(([u, v, height]) => b.point({ u, v, z: height }));
      b.faces.push({ points: world, depth: world.reduce((sum, p) => sum + (p.u + p.v) * 32 + p.z, 0) / 4, color: normal[2] ? material.top : n.u > .5 ? material.side : material.front, line: material.line, outline: .6, strokeEdges, order: b.sequence++ });
    };
    const [up, right, down, left] = neighbors;
    add([[-.5, -.5, top], [.5, -.5, top], [.5, .5, top], [-.5, .5, top]], [0, 0, 1], [up < top, right < top, down < top, left < top]);
    for (const [index, normal] of [[0, [0, -1, 0]], [1, [1, 0, 0]], [2, [0, 1, 0]], [3, [-1, 0, 0]]]) {
      const low = Math.max(z, neighbors[index]); if (low >= top) continue;
      if (index === 1) add([[.5, -.5, low], [.5, .5, low], [.5, .5, top], [.5, -.5, top]], normal, [true, down < top, true, up < top]);
      if (index === 2) add([[.5, .5, low], [-.5, .5, low], [-.5, .5, top], [.5, .5, top]], normal, [true, left < top, true, right < top]);
      if (index === 0) add([[-.5, -.5, low], [.5, -.5, low], [.5, -.5, top], [-.5, -.5, top]], normal, [true, right < top, true, left < top]);
      if (index === 3) add([[-.5, .5, low], [-.5, -.5, low], [-.5, -.5, top], [-.5, .5, top]], normal, [true, up < top, true, down < top]);
    }
  };
})();
