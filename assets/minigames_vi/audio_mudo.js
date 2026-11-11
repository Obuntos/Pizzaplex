(() => {
  "use strict";
  for (const name of ["AudioContext", "webkitAudioContext"]) {
    Object.defineProperty(window, name, { value: undefined, writable: false, configurable: false });
  }
  if (window.AudioNode && window.AudioDestinationNode) {
    const connect = AudioNode.prototype.connect;
    AudioNode.prototype.connect = function (target, ...rest) {
      if (target instanceof AudioDestinationNode) return target;
      return connect.call(this, target, ...rest);
    };
  }
  if (window.HTMLMediaElement) {
    const play = HTMLMediaElement.prototype.play;
    HTMLMediaElement.prototype.play = function (...args) {
      this.muted = true;
      this.volume = 0;
      return play.apply(this, args);
    };
  }
})();
