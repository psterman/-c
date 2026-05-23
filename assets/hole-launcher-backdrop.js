(function (global) {
  'use strict';

  var rafId = 0;
  var stars = [];
  var canvas = null;
  var ctx = null;
  var running = false;

  function initCanvas() {
    canvas = document.getElementById('launcherGalaxyCanvas');
    if (!canvas) return false;
    ctx = canvas.getContext('2d', { alpha: false });
    var dpr = window.devicePixelRatio || 1;
    var size = 520;
    canvas.width = size * dpr;
    canvas.height = size * dpr;
    canvas.style.width = size + 'px';
    canvas.style.height = size + 'px';
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    stars = [];
    for (var i = 0; i < 320; i++) {
      var rand = Math.random();
      var type = 'fine';
      var sizeStar = 0.2 + Math.random() * 0.4;
      var color = '#ffffff';
      if (rand > 0.95) {
        type = 'bright';
        sizeStar = 0.8 + Math.random() * 0.5;
        var c = Math.random();
        color = c > 0.8 ? '#dbebff' : (c > 0.6 ? '#fff5e6' : '#ffffff');
      } else if (rand > 0.8) {
        type = 'medium';
        sizeStar = 0.4 + Math.random() * 0.3;
      }
      stars.push({
        x: Math.random() * size,
        y: Math.random() * size,
        size: sizeStar,
        type: type,
        twinkleSpeed: 0.12 + Math.random() * 0.2,
        phase: Math.random() * Math.PI * 2,
        baseAlpha: type === 'fine' ? 0.2 : 0.5,
        color: color
      });
    }
    return true;
  }

  function render(time) {
    if (!running || !ctx) return;
    var w = 520;
    var h = 520;
    ctx.fillStyle = '#000000';
    ctx.fillRect(0, 0, w, h);
    stars.forEach(function (s) {
      var t = time * s.twinkleSpeed + s.phase;
      var noise = Math.sin(t) * Math.cos(t * 0.7);
      var alpha = s.baseAlpha + noise * 0.35;
      ctx.globalAlpha = Math.max(0.1, Math.min(1, alpha));
      if (s.type === 'bright') {
        var cx = s.x;
        var cy = s.y;
        ctx.strokeStyle = s.color;
        ctx.lineWidth = 0.5;
        var spikeLen = s.size * 5 * alpha;
        ctx.beginPath();
        ctx.moveTo(cx - spikeLen, cy);
        ctx.lineTo(cx + spikeLen, cy);
        ctx.moveTo(cx, cy - spikeLen);
        ctx.lineTo(cx, cy + spikeLen);
        ctx.stroke();
        ctx.fillStyle = '#fff';
        ctx.beginPath();
        ctx.arc(cx, cy, s.size, 0, Math.PI * 2);
        ctx.fill();
      } else {
        ctx.fillStyle = s.color;
        ctx.beginPath();
        ctx.arc(s.x, s.y, s.size, 0, Math.PI * 2);
        ctx.fill();
      }
    });
    ctx.globalAlpha = 1;
    rafId = requestAnimationFrame(render);
  }

  function start() {
    if (!initCanvas()) return;
    running = true;
    if (!rafId) rafId = requestAnimationFrame(render);
  }

  function stop() {
    running = false;
    if (rafId) {
      cancelAnimationFrame(rafId);
      rafId = 0;
    }
  }

  global.HoleLauncherBackdrop = { start: start, stop: stop };
})(window);
