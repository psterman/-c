(function () {
  try {
    var LS_KEY = 'niuma_trace_overlay_hidden_v1';
    if (window.__NIUMA_TRACE_OVERLAY__ && window.__NIUMA_TRACE_OVERLAY__.push) return;

    var ver = '';
    try {
      ver = (window.__NIUMA_TRACE_OVERLAY_VER__ != null ? String(window.__NIUMA_TRACE_OVERLAY_VER__) : '').trim();
    } catch (_) {}

    var MAX_LINES = 200;
    var hidden = false;
    var unread = 0;
    try {
      hidden = localStorage.getItem(LS_KEY) === '1';
    } catch (_) {}

    var root = document.getElementById('niuma-trace-overlay-root');
    if (!root) {
      root = document.createElement('div');
      root.id = 'niuma-trace-overlay-root';
      root.style.cssText =
        'position:fixed;z-index:2147483646;top:8px;right:8px;max-width:min(88vw,380px);' +
        'font:12px/1.4 ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;user-select:text;' +
        'pointer-events:none;';
      document.documentElement.appendChild(root);
    }

    var panel = document.createElement('div');
    panel.style.cssText =
      'pointer-events:auto;background:rgba(10,10,10,.82);color:#eaeaea;border:1px solid rgba(255,255,255,.14);' +
      'border-radius:10px;box-shadow:0 8px 24px rgba(0,0,0,.35);overflow:hidden;';
    root.appendChild(panel);

    var header = document.createElement('div');
    header.style.cssText =
      'display:flex;gap:6px;align-items:center;padding:6px 8px;background:rgba(0,0,0,.35);' +
      'border-bottom:1px solid rgba(255,255,255,.12);cursor:move;';
    panel.appendChild(header);

    var title = document.createElement('div');
    title.textContent = 'nmer · 智能操控调试';
    title.style.cssText = 'font-weight:600;flex:1;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;font-size:11px;';
    header.appendChild(title);

    function mkBtn(text) {
      var b = document.createElement('button');
      b.textContent = text;
      b.type = 'button';
      b.style.cssText =
        'appearance:none;border:1px solid rgba(255,255,255,.18);background:rgba(255,255,255,.06);' +
        'color:#eaeaea;border-radius:6px;padding:3px 7px;font:11px/1.2 inherit;cursor:pointer;';
      return b;
    }

    var btnClear = mkBtn('清空');
    var btnToggle = mkBtn(hidden ? '显示' : '隐藏');
    header.appendChild(btnClear);
    header.appendChild(btnToggle);

    var body = document.createElement('div');
    body.style.cssText = 'max-height:32vh;overflow:auto;padding:6px 8px;';
    panel.appendChild(body);

    var pill = document.createElement('button');
    pill.type = 'button';
    pill.title = '点击展开调试面板';
    pill.style.cssText =
      'display:none;pointer-events:auto;position:fixed;z-index:2147483646;bottom:12px;right:12px;' +
      'appearance:none;border:1px solid rgba(255,255,255,.2);background:rgba(10,10,10,.88);color:#eaeaea;' +
      'border-radius:999px;padding:6px 12px;font:11px/1.2 ui-monospace,Consolas,monospace;cursor:pointer;' +
      'box-shadow:0 4px 16px rgba(0,0,0,.35);';
    pill.textContent = '调试';
    document.documentElement.appendChild(pill);

    function saveHidden(v) {
      hidden = !!v;
      try {
        localStorage.setItem(LS_KEY, hidden ? '1' : '0');
      } catch (_) {}
    }

    function refreshPill() {
      if (!hidden) {
        pill.style.display = 'none';
        return;
      }
      pill.style.display = 'block';
      pill.textContent = unread > 0 ? '调试 +' + unread : '调试';
    }

    function setPanelVisible(show) {
      panel.style.display = show ? '' : 'none';
      btnToggle.textContent = show ? '隐藏' : '显示';
      if (show) {
        unread = 0;
        refreshPill();
      }
    }

    function appendLine(line, kind) {
      try {
        var div = document.createElement('div');
        div.textContent = line;
        div.style.cssText =
          'white-space:pre-wrap;word-break:break-word;margin:0 0 4px 0;font-size:11px;' +
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

    function showPanel() {
      saveHidden(false);
      setPanelVisible(true);
    }

    function hidePanel() {
      saveHidden(true);
      setPanelVisible(false);
      refreshPill();
    }

    btnClear.addEventListener('click', function (e) {
      try {
        e.stopPropagation();
        body.innerHTML = '';
        unread = 0;
        refreshPill();
      } catch (_) {}
    });

    btnToggle.addEventListener('click', function (e) {
      try {
        e.stopPropagation();
        if (hidden) showPanel();
        else hidePanel();
      } catch (_) {}
    });

    pill.addEventListener('click', function (e) {
      try {
        e.stopPropagation();
        showPanel();
      } catch (_) {}
    });

    var dragging = false;
    var startX = 0,
      startY = 0,
      startRight = 0,
      startTop = 0;
    header.addEventListener('mousedown', function (e) {
      if (!e || e.button !== 0) return;
      if (e.target && e.target.tagName === 'BUTTON') return;
      dragging = true;
      startX = e.clientX;
      startY = e.clientY;
      startRight = parseInt(root.style.right || '8', 10) || 8;
      startTop = parseInt(root.style.top || '8', 10) || 8;
      try {
        e.preventDefault();
      } catch (_) {}
    });
    window.addEventListener('mousemove', function (e) {
      if (!dragging) return;
      var dx = e.clientX - startX;
      var dy = e.clientY - startY;
      root.style.right = Math.max(0, startRight - dx) + 'px';
      root.style.top = Math.max(0, startTop + dy) + 'px';
    });
    window.addEventListener('mouseup', function () {
      dragging = false;
    });

    window.__NIUMA_TRACE_OVERLAY__ = {
      hidden: hidden,
      show: showPanel,
      hide: hidePanel,
      toggle: function () {
        if (hidden) showPanel();
        else hidePanel();
      },
      push: function (msg, level) {
        var s = String(msg || '').trim();
        if (!s) return;
        appendLine(s, level || '');
        if (hidden) {
          unread += 1;
          refreshPill();
        } else {
          setPanelVisible(true);
        }
      }
    };

    setPanelVisible(!hidden);
    refreshPill();
    appendLine('已加载调试悬浮窗 v=' + (ver || 'unknown') + '（点「隐藏」收起；右下角「调试」可再打开）', 'warn');
  } catch (_) {}
})();
