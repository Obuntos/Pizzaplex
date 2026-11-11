(() => {
  "use strict";
  const play = window.PlexPlay, lab = window.DummyLab;
  play.CargoRenderer = class {
    constructor() {
      this.renderer = new window.TileLab.Renderer(window.TileLab.models.get("caixa"));
      lab.cargoLayer = { draw: (context, actor, project) => {
        const at = project(0, 5.4, actor.carryHeight || 15.8);
        const image = this.renderer.get(-.5 - actor.facing / 2, { open: !!actor.cargoOpen, filled: actor.cargoFilled !== false });
        const scale = 1 / play.characterScale; context.imageSmoothingEnabled = false;
        context.drawImage(image, at.x - 96 * scale, at.y - 144 * scale, image.width * scale, image.height * scale);
      } };
    }
    prepare() {
      for (let facing = 0; facing < 8; facing++) this.renderer.get(-.5 - facing / 2, { open: false, filled: true });
    }
  };
})();
