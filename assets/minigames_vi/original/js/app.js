(() => {
  "use strict";
  const M = window.Mini;
  const stage = document.querySelector("#stage");
  const list = document.querySelector("#games");
  const hudBox = document.querySelector("#hud");
  const meterBox = document.querySelector("#meter");
  const tipBox = document.querySelector("#tip");
  const footKeys = document.querySelector("#foot-keys");
  let lastHud = "";

  M.hud = {
    set(rows, meter) {
      const html = rows.map(r => "<div><dt>" + r[0] + "</dt><dd>" + r[1] + "</dd></div>").join("");
      const key = html + (meter ? meter.label + Math.round(meter.value * 100) + meter.tone : "");
      if (key === lastHud) return;
      lastHud = key;
      hudBox.innerHTML = html;
      if (meter) {
        meterBox.hidden = false;
        meterBox.dataset.tone = meter.tone;
        meterBox.querySelector("span").textContent = meter.label;
        meterBox.querySelector("i").style.width = Math.round(M.clamp(meter.value) * 100) + "%";
      } else meterBox.hidden = true;
    }
  };

  const instances = new Map();
  let current = null;

  for (const def of M.games) {
    const root = document.createElement("section");
    root.className = "game";
    root.dataset.game = def.id;
    root.hidden = true;
    stage.appendChild(root);
    const button = document.createElement("button");
    button.dataset.game = def.id;
    button.setAttribute("aria-pressed", "false");
    button.innerHTML = def.number + " " + def.name + "<small>" + def.note + "</small>";
    list.appendChild(button);
    instances.set(def.id, { def, root, api: def.create(root) });
  }

  const select = id => {
    const next = instances.get(id);
    if (!next || next === current) return;
    if (current) { current.api.deactivate(); current.root.hidden = true; }
    current = next;
    current.root.hidden = false;
    lastHud = "";
    document.querySelector("#game-name").textContent = current.def.name;
    document.querySelector("#game-number").textContent = current.def.number;
    document.querySelector("#game-note").textContent = current.def.short;
    tipBox.innerHTML = current.def.tip;
    footKeys.textContent = current.def.keys;
    for (const b of list.children) b.setAttribute("aria-pressed", String(b.dataset.game === id));
    current.api.activate();
    try { history.replaceState(null, "", "#" + id); } catch (e) {}
  };

  list.addEventListener("click", ev => { const b = ev.target.closest("[data-game]"); if (b) select(b.dataset.game); });
  document.querySelector("#reset").addEventListener("click", () => current.api.reset());

  window.addEventListener("keydown", ev => {
    if (ev.altKey || ev.ctrlKey || ev.metaKey) return;
    const tag = ev.target.tagName;
    if (["INPUT", "SELECT", "TEXTAREA"].includes(tag)) return;
    const index = Number(ev.key) - 1;
    if (!ev.repeat && index >= 0 && index < M.games.length) { select(M.games[index].id); return; }
    if (ev.target.closest && ev.target.closest("[role=slider]")) return;
    if (current.api.keydown(ev)) ev.preventDefault();
  });
  window.addEventListener("keyup", ev => current.api.keyup(ev));
  window.addEventListener("blur", () => current.api.keyup({ key: "ArrowLeft" }));

  let last = 0;
  document.addEventListener("visibilitychange", () => { last = 0; });
  const loop = now => {
    const dt = last ? Math.min((now - last) / 1000, .1) : 0;
    last = now;
    current.api.update(dt);
    current.api.draw();
    requestAnimationFrame(loop);
  };

  const wanted = location.hash.slice(1);
  select(instances.has(wanted) ? wanted : M.games[0].id);
  window.Mini.preview = { select, instances, get current() { return current; } };
  requestAnimationFrame(loop);
})();
