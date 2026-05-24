(function (global) {
  'use strict';

  var rafId = 0;
  var stars = [];
  var canvas = null;
  var ctx = null;
  var running = false;
  var VIEW = 450;
  var CLIP_R = 225;
  var WELL_R = 208;
  var RING_WIDTH = 4;
  var RING_INNER = CLIP_R - RING_WIDTH;
  var RING_COLORS = ['#4285f4', '#34a853', '#fbbc05', '#ea4335', '#4285f4'];

  function ringColorAt(t) {
    var x = ((t % 1) + 1) % 1;
    var n = RING_COLORS.length - 1;
    var seg = x * n;
    var i = Math.floor(seg);
    var f = seg - i;
    var a = RING_COLORS[i];
    var b = RING_COLORS[i + 1];
    function parse(hex) {
      return [
        parseInt(hex.slice(1, 3), 16),
        parseInt(hex.slice(3, 5), 16),
        parseInt(hex.slice(5, 7), 16)
      ];
    }
    var ca = parse(a);
    var cb = parse(b);
    return 'rgb(' +
      Math.round(ca[0] + (cb[0] - ca[0]) * f) + ',' +
      Math.round(ca[1] + (cb[1] - ca[1]) * f) + ',' +
      Math.round(ca[2] + (cb[2] - ca[2]) * f) + ')';
  }

  function initCanvas() {
    canvas = document.getElementById('launcherGalaxyCanvas');
    if (!canvas) return false;
    ctx = canvas.getContext('2d', { alpha: true });
    var dpr = window.devicePixelRatio || 1;
    canvas.width = VIEW * dpr;
    canvas.height = VIEW * dpr;
    canvas.style.width = VIEW + 'px';
    canvas.style.height = VIEW + 'px';
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
        x: Math.random() * VIEW,
        y: Math.random() * VIEW,
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

  /** 实心圆环扇形铺满 [RING_INNER, CLIP_R]，避免描边留白导致圆环外黑边 */
  function drawColorRing(time) {
    var cx = VIEW / 2;
    var cy = VIEW / 2;
    var spin = (time * 0.00025) % (Math.PI * 2);
    var segments = 240;
    ctx.save();
    for (var i = 0; i < segments; i++) {
      var t0 = i / segments;
      var t1 = (i + 1) / segments;
      var a0 = spin + t0 * Math.PI * 2;
      var a1 = spin + t1 * Math.PI * 2;
      ctx.beginPath();
      ctx.arc(cx, cy, CLIP_R, a0, a1, false);
      ctx.arc(cx, cy, RING_INNER, a1, a0, true);
      ctx.closePath();
      ctx.fillStyle = ringColorAt(t0);
      ctx.fill();
    }
    ctx.restore();
  }

  function render(time) {
    if (!running || !ctx) return;
    var cx = VIEW / 2;
    var cy = VIEW / 2;
    ctx.clearRect(0, 0, VIEW, VIEW);
    drawColorRing(time);
    ctx.save();
    ctx.beginPath();
    ctx.arc(cx, cy, WELL_R, 0, Math.PI * 2);
    ctx.fillStyle = '#000000';
    ctx.fill();
    ctx.clip();
    stars.forEach(function (s) {
      var t = time * s.twinkleSpeed + s.phase;
      var noise = Math.sin(t) * Math.cos(t * 0.7);
      var alpha = s.baseAlpha + noise * 0.35;
      ctx.globalAlpha = Math.max(0.1, Math.min(1, alpha));
      if (s.type === 'bright') {
        var spikeLen = s.size * 5 * alpha;
        ctx.strokeStyle = s.color;
        ctx.lineWidth = 0.5;
        ctx.beginPath();
        ctx.moveTo(s.x - spikeLen, s.y);
        ctx.lineTo(s.x + spikeLen, s.y);
        ctx.moveTo(s.x, s.y - spikeLen);
        ctx.lineTo(s.x, s.y + spikeLen);
        ctx.stroke();
        ctx.fillStyle = '#fff';
        ctx.beginPath();
        ctx.arc(s.x, s.y, s.size, 0, Math.PI * 2);
        ctx.fill();
      } else {
        ctx.fillStyle = s.color;
        ctx.beginPath();
        ctx.arc(s.x, s.y, s.size, 0, Math.PI * 2);
        ctx.fill();
      }
    });
    ctx.restore();
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
