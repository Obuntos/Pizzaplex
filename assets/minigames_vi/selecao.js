(() => {
  "use strict";
  const register = Mini.register;
  Mini.register = function (definition) {
    if (definition.id === window.PlexMiniConfig.game) register.call(this, definition);
  };
})();
