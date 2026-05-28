(function () {
  try {
    if (window.__NIUMA_TRACE_OVERLAY__ && window.__NIUMA_TRACE_OVERLAY__.push) return;
    var ver = '';
    try {
      ver = (window.__NIUMA_TRACE_OVERLAY_VER__ != null ? String(window.__NIUMA_TRACE_OVERLAY_VER__) : '').trim();
    } catch (_) {}

    var MAX_LINES = 200;
    var root = document.getElementById('niuma-trace-overlay-root');
    if (!root) {
      root = document.createElement('div');
      root.id = 'niuma-trace-overlay-root';
      root.style.cssText =
        'position:fixed;z-index:2147483646;top:72px;right:12px;max-width:min(92vw,420px);' +
        'font:12px/1.4 ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;user-select:text;';
      document.documentElement.appendChild(root);
    }

    var panel = document.createElement('div');
    panel.style.cssText =
      'background:rgba(10,10,10,.78);color:#eaeaea;border:1px solid rgba(255,255,255,.14);' +
      'border-radius:10px;box-shadow:0 10px 30px rgba(0,0,0,.35);overflow:hidden;';
    root.appendChild(panel);

    var header = document.createElement('div');
    header.style.cssText =
      'display:flex;gap:8px;align-items:center;padding:8px 10px;background:rgba(0,0,0,.35);' +
      'border-bottom:1px solid rgba(255,255,255,.12);cursor:move;';
    panel.appendChild(header);

    var title = document.createElement('div');
    title.textContent = 'nmer · 智能操控调试';
    title.style.cssText = 'font-weight:600;flex:1;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;';
    header.appendChild(title);

    function mkBtn(text) {
      var b = document.createElement('button');
      b.textContent = text;
      b.style.cssText =
        'appearance:none;border:1px solid rgba(255,255,255,.18);background:rgba(255,255,255,.06);' +
        'color:#eaeaea;border-radius:8px;padding:4px 8px;font:12px/1.2 inherit;';
      return b;
    }

    var btnClear = mkBtn('清空');
    var btnHide = mkBtn('隐藏');
    header.appendChild(btnClear);
    header.appendChild(btnHide);

    var body = document.createElement('div');
    body.style.cssText = 'max-height:46vh;overflow:auto;padding:8px 10px;';
    panel.appendChild(body);

    function appendLine(line, kind) {
      try {
        var div = document.createElement('div');
        div.textContent = line;
        div.style.cssText =
          'white-space:pre-wrap;word-break:break-word;margin:0 0 6px 0;' +
          (kind === 'err'
            ? 'color:#ffb4b4;'
            : kind === 'warn'
              ? 'color:#ffe1a3;'
              : 'color:#eaeaea;');
        body.appendChild(div);
        while (body.childNodes.length > MAX_LINES) body.removeChild(body.firstChild);
        body.scrollTop = body.scrollHeight;
      } catch (_) {}
    }

    btnClear.addEventListener('click', function () {
      try {
        body.innerHTML = '';
      } catch (_) {}
    });
    btnHide.addEventListener('click', function () {
      try {
        panel.style.display = 'none';
      } catch (_) {}
    });

    // Drag
    var dragging = false;
    var startX = 0,
      startY = 0,
      startRight = 0,
      startTop = 0;
    header.addEventListener('mousedown', function (e) {
      if (!e || e.button !== 0) return;
      dragging = true;
      startX = e.clientX;
      startY = e.clientY;
      startRight = parseInt(root.style.right || '12', 10) || 12;
      startTop = parseInt(root.style.top || '72', 10) || 72;
      try {
        e.preventDefault();
      } catch (_) {}
    });
    window.addEventListener('mousemove', function (e) {
      if (!dragging) return;
      var dx = e.clientX - startX;
      var dy = e.clientY - startY;
      var nr = Math.max(0, startRight - dx);
      var nt = Math.max(0, startTop + dy);
      root.style.right = nr + 'px';
      root.style.top = nt + 'px';
    });
    window.addEventListener('mouseup', function () {
      dragging = false;
    });

    window.__NIUMA_TRACE_OVERLAY__ = {
      show: function () {
        try {
          panel.style.display = '';
        } catch (_) {}
      },
      push: function (msg, level) {
        var s = String(msg || '').trim();
        if (!s) return;
        appendLine(s, level || '');
      }
    };

    appendLine('已加载调试悬浮窗 v=' + (ver || 'unknown') + '（等待宿主/模型事件）', 'warn');
  } catch (_) {}
})();

