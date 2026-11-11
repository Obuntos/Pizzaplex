(() => {
  "use strict";
  const lab = window.TileLab, count = 3, rise = 6;
  lab.stair = Object.freeze({ count, rise, width: .8, totalHeight: count * rise, center: level => .5 - (level - .5) / count, heightAt: v => Math.max(0, Math.min(count, Math.ceil((.5 - v) * count))) * rise });
})();
