(() => {
  "use strict";
  let last = 0, won = false, restaurado = !window.ipc;
  const current = () => window.Mini?.preview?.current?.api;
  const send = (action, state) => {
    if (window.ipc) ipc.postMessage(JSON.stringify({ action, game: PlexMiniConfig.game, state }));
  };
  const snapshot = () => current()?.exportState?.();
  const iniciar = () => {
    if (snapshot()?.phase === "intro") Mini.preview.current.root.querySelector(".overlay button")?.click();
  };
  const update = now => {
    if (!restaurado) { requestAnimationFrame(update); return; }
    iniciar();
    const state = snapshot();
    if (state && now - last >= 400) { last = now; send("estado", state); }
    if (state?.phase === "won" && !won) { won = true; send("concluido", state); }
    if (state?.phase !== "won") won = false;
    requestAnimationFrame(update);
  };
  window.PlexBridge = {
    restaurar(state) { current()?.restoreState?.(state); restaurado = true; iniciar(); },
    sair() { current()?.deactivate?.(); send("sair", snapshot()); }
  };
  window.addEventListener("keydown", event => {
    if (event.key !== "Escape") return;
    event.preventDefault(); event.stopImmediatePropagation(); PlexBridge.sair();
  }, true);
  send("pronto", snapshot());
  requestAnimationFrame(update);
})();
