// node render.js <harness.html> <animacao> <t0,t1,...> <saida.json>   (precisa do playwright)
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
(async () => {
  const [harness, anim, ts, out] = process.argv.slice(2);
  const b = await chromium.launch(); const p = await b.newPage();
  const errs = []; p.on('pageerror', e => errs.push(e.message));
  await p.goto('file://' + path.resolve(harness));
  await p.waitForFunction(() => window.renderiza);
  const tempos = ts.split(',').map(Number);
  const r = await p.evaluate(([a, t]) => ({ info: info(), frames: renderiza(a, t, [0, 1, 2, 3, 4, 5, 6, 7]) }), [anim, tempos]);
  fs.writeFileSync(out, JSON.stringify(r));
  if (errs.length) { console.error(errs.slice(0, 5)); process.exit(1); }
  await b.close();
})();
