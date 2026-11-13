// node render.js <harness.html> <quadros.json> <saida.json>   (precisa do playwright)
// quadros.json: lista de canais por quadro (12 por segundo), gerada por ataques.py
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
(async () => {
  const [harness, qfile, out] = process.argv.slice(2);
  const quadros = JSON.parse(fs.readFileSync(qfile, 'utf8'));
  const b = await chromium.launch(); const p = await b.newPage();
  const errs = []; p.on('pageerror', e => errs.push(e.message));
  await p.addInitScript(q => { window.QUADROS = q; }, quadros);
  await p.goto('file://' + path.resolve(harness));
  await p.waitForFunction(() => window.renderiza);
  const tempos = quadros.map((_, i) => i / 12);
  const r = await p.evaluate(t => ({ info: info(), frames: renderiza('matar', t, [0, 1, 2, 3, 4, 5, 6, 7]) }), tempos);
  fs.writeFileSync(out, JSON.stringify(r));
  if (errs.length) { console.error(errs.slice(0, 5)); process.exit(1); }
  await b.close();
})();
