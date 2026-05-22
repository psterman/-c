(function (global) {
  'use strict';

  var LAUNCHER_ITEMS = [
    { id: 'hole_manual', title: '黑洞手动', sceneId: 'hole_manual', cmdId: '', internal: true, emoji: '◎', gradient: 'linear-gradient(145deg,#0b4d3f,#1f8a6b)' },
    { id: 'niuma', title: '牛马 Chat', sceneId: 'ai', cmdId: 'ch_r', emoji: '🤖', gradient: 'linear-gradient(145deg,#1a3a5c,#2d6cdf)' },
    { id: 'search', title: '搜索中心', sceneId: 'search', cmdId: 'sc_activate_search', emoji: '🔍', gradient: 'linear-gradient(145deg,#12352a,#2d8f6a)' },
    { id: 'clipboard', title: '剪贴板', sceneId: 'clipboard', cmdId: 'qa_clipboard', emoji: '📋', gradient: 'linear-gradient(145deg,#1e3d2f,#3cb878)' },
    { id: 'prompts', title: '提示词', sceneId: 'prompts', cmdId: 'ch_b', emoji: '💡', gradient: 'linear-gradient(145deg,#4a3a12,#c98a1a)' },
    { id: 'scratchpad', title: '草稿本', sceneId: 'scratchpad', cmdId: 'hub_capsule', emoji: '📝', gradient: 'linear-gradient(145deg,#3d2e14,#b86b22)' },
    { id: 'screenshot', title: '截图', sceneId: 'screenshot', cmdId: 'ch_t', emoji: '📸', gradient: 'linear-gradient(145deg,#12384a,#2aa8c9)' },
    { id: 'settings', title: '设置', sceneId: 'settings', cmdId: 'qa_config', emoji: '⚙️', gradient: 'linear-gradient(145deg,#2a2f38,#5c6778)' },
    { id: 'hotkeys', title: '快捷键', sceneId: 'hotkeys', cmdId: 'sys_show_vk', emoji: '⌨️', gradient: 'linear-gradient(145deg,#4a2f14,#d97706)' },
    { id: 'cursor', title: 'Cursor', sceneId: 'cursor', cmdId: 'cursor_open', img: 'lib/images/cursor.png', gradient: 'linear-gradient(145deg,#1a3350,#3b82f6)' },
    { id: 'cloud', title: '牛马云', sceneId: 'cloudplayer', cmdId: 'open_cloudplayer', always: true, emoji: '☁️', gradient: 'linear-gradient(145deg,#1a2f45,#38bdf8)' }
  ];

  function normalizeSceneId(v) {
    var s = String(v || '').trim().toLowerCase();
    return s === 'notepad' ? 'scratchpad' : s;
  }

  function mount(opts) {
    opts = opts || {};
    var host = opts.host;
    if (!host) return null;
    var post = typeof opts.post === 'function' ? opts.post : function () {};
    var badge = String(opts.badge || '').trim();
    var grid = host.querySelector('.hole-scene-grid');
    if (!grid) {
      grid = document.createElement('div');
      grid.className = 'hole-scene-grid';
      grid.setAttribute('role', 'grid');
      host.appendChild(grid);
    }
    if (badge) {
      var tag = host.querySelector('.hole-scene-badge');
      if (!tag) {
        tag = document.createElement('div');
        tag.className = 'hole-scene-badge';
        host.appendChild(tag);
      }
      tag.textContent = badge;
    }

    function buildGrid(sceneToolbarLayout) {
      grid.innerHTML = '';
      var layout = Array.isArray(sceneToolbarLayout) ? sceneToolbarLayout : [];
      var byScene = {};
      layout.forEach(function (row) {
        var sid = normalizeSceneId(row && row.sceneId);
        if (sid) byScene[sid] = row;
      });
      var tiles = [];
      LAUNCHER_ITEMS.forEach(function (it, idx) {
        var sid = normalizeSceneId(it.sceneId);
        var row = byScene[sid];
        var visible = it.internal || it.always || !row || row.visible_in_bar !== false;
        if (!visible) return;
        var ord = row && Number.isFinite(Number(row.order_bar)) ? Number(row.order_bar) : (it.internal ? -2 : 100 + idx);
        tiles.push({ it: it, ord: ord, idx: idx });
      });
      tiles.sort(function (a, b) {
        return a.ord !== b.ord ? a.ord - b.ord : a.idx - b.idx;
      });
      if (!tiles.length) {
        var empty = document.createElement('div');
        empty.className = 'hole-scene-empty';
        empty.textContent = '请在快捷键绑定器勾选「进悬浮栏」的场景';
        grid.appendChild(empty);
        return;
      }
      tiles.forEach(function (pack, i) {
        var it = pack.it;
        var btn = document.createElement('button');
        btn.type = 'button';
        btn.className = 'hole-scene-tile';
        btn.style.animationDelay = (i * 10) + 'ms';
        btn.title = it.title;
        btn.setAttribute('aria-label', it.title);
        var icon = document.createElement('div');
        icon.className = 'hole-scene-icon';
        icon.style.background = it.gradient || 'linear-gradient(145deg,#333,#555)';
        if (it.img) {
          var im = document.createElement('img');
          im.src = it.img;
          im.alt = '';
          icon.appendChild(im);
        } else if (it.emoji) {
          icon.textContent = it.emoji;
        }
        var lab = document.createElement('span');
        lab.className = 'hole-scene-label';
        lab.textContent = it.title;
        btn.appendChild(icon);
        btn.appendChild(lab);
        btn.addEventListener('click', function (ev) {
          try { ev.preventDefault(); ev.stopPropagation(); } catch (_) {}
          if (it.internal || it.sceneId === 'hole_manual') {
            post({ type: 'panel_open_manual', sceneId: 'hole_manual', internal: true });
            return;
          }
          post({
            type: 'panel_scene_pick',
            sceneId: it.sceneId,
            cmdId: it.cmdId || '',
            internal: false
          });
        });
        grid.appendChild(btn);
      });
    }

    return {
      buildGrid: buildGrid,
      show: function () { host.classList.add('visible'); },
      hide: function () { host.classList.remove('visible'); },
      setPreview: function (text) {
        var sub = host.querySelector('.hole-scene-sub');
        if (!sub) return;
        var t = String(text || '').trim();
        sub.textContent = t
          ? ('已捕获 ' + (t.length > 28 ? t.slice(0, 28) + '…' : t))
          : '选择场景';
      }
    };
  }

  global.HoleSceneLauncher = { mount: mount, ITEMS: LAUNCHER_ITEMS };
})(window);
