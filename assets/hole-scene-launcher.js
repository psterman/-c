(function (global) {
  'use strict';

  var STYLE_ID = 'hole-scene-launcher-style';
  var ICON_APP = 'https://app.local/assets/icons/app/';
  var LOGO_URL = 'https://app.local/assets/牛马.png';

  /* 与 assets/nm-bottom-dock.js 悬浮栏图标同源 */
  var LAUNCHER_ITEMS = [
    {
      id: 'hole_manual',
      title: '黑洞手动',
      sceneId: 'hole_manual',
      cmdId: '',
      internal: true,
      accent: 'orbit',
      icon: '<circle cx="12" cy="12" r="7"></circle><circle cx="12" cy="12" r="2.5"></circle><path d="M12 5v1.5M12 17.5v1.5M5 12h1.5M17.5 12H19"></path>'
    },
    { id: 'niuma', title: '牛马 Chat', sceneId: 'ai', cmdId: 'ch_r', isLogo: true, img: LOGO_URL },
    {
      id: 'search',
      title: '搜索中心',
      sceneId: 'search',
      cmdId: 'sc_activate_search',
      icon: '<circle cx="11" cy="11" r="8"></circle><path d="m21 21-4.35-4.35"></path>'
    },
    {
      id: 'clipboard',
      title: '剪贴板',
      sceneId: 'clipboard',
      cmdId: 'qa_clipboard',
      icon: '<rect x="8" y="2" width="8" height="4" rx="1"></rect><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"></path>'
    },
    {
      id: 'prompts',
      title: '提示词',
      sceneId: 'prompts',
      cmdId: 'ch_b',
      icon: '<path d="M12 3c4.97 0 9 3.58 9 8 0 1.8-.67 3.47-1.8 4.82L20 21l-5.02-1.67A10.53 10.53 0 0 1 12 20c-4.97 0-9-8-9-8s4.03-9 9-9Z"></path>'
    },
    {
      id: 'scratchpad',
      title: '草稿本',
      sceneId: 'scratchpad',
      cmdId: 'hub_capsule',
      icon: '<path d="M6 3h11a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2z"></path><path d="M8 7h8"></path><path d="M8 11h8"></path><path d="M8 15h5"></path>'
    },
    {
      id: 'screenshot',
      title: '截图',
      sceneId: 'screenshot',
      cmdId: 'ch_t',
      icon: '<path d="M4 7h4l2-2h4l2 2h4v12H4z"></path><circle cx="12" cy="13" r="3.5"></circle>'
    },
    {
      id: 'settings',
      title: '设置',
      sceneId: 'settings',
      cmdId: 'qa_config',
      icon: '<circle cx="12" cy="12" r="3"></circle><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"></path>'
    },
    {
      id: 'hotkeys',
      title: '快捷键',
      sceneId: 'hotkeys',
      cmdId: 'sys_show_vk',
      icon: '<rect x="2.5" y="5" width="19" height="14" rx="2.5"></rect><path d="M6 9h1M9 9h1M12 9h1M15 9h1M18 9h1M6 12h1M9 12h1M12 12h1M15 12h1M18 12h1M7 15h10"></path>'
    },
    {
      id: 'cursor',
      title: 'Cursor',
      sceneId: 'cursor',
      cmdId: 'cursor_open',
      img: ICON_APP + 'cursor.png',
      fallbackIcon: '<path d="M5 3l14 8-6 1.2-1.2 6z" fill="currentColor" stroke="none" opacity=".92"></path>'
    },
    {
      id: 'cloud',
      title: '牛马云',
      sceneId: 'cloudplayer',
      cmdId: 'open_cloudplayer',
      always: true,
      icon: '<path d="M17.5 19H9a7 7 0 1 1 6.71-9h1.79a4.5 4.5 0 1 1 0 9Z"></path>'
    }
  ];

  function ensureLauncherIconStyle() {
    var style = document.getElementById(STYLE_ID);
    if (!style) {
      style = document.createElement('style');
      style.id = STYLE_ID;
      document.head.appendChild(style);
    }
    /* 无圆角底：橙色线稿 + 星晕光斑，与悬浮栏 #ff6600 一致 */
    style.textContent = '' +
      ':root{--hole-icon:#ff6600;--hole-icon-hover:#ff8533;--hole-icon-glow:rgba(255,102,0,.42);}' +
      '.hole-scene-icon,.launcher-icon{' +
      'position:relative;width:44px;height:44px;display:flex;align-items:center;justify-content:center;' +
      'background:transparent;border:none;border-radius:0;box-shadow:none;backdrop-filter:none;' +
      'color:var(--hole-icon);' +
      'transition:transform .2s cubic-bezier(.22,1,.36,1),color .2s ease;}' +
      '.hole-scene-icon::before,.launcher-icon::before{' +
      'content:"";position:absolute;inset:2px;border-radius:50%;pointer-events:none;' +
      'background:radial-gradient(circle,var(--hole-icon-glow) 0%,transparent 70%);' +
      'opacity:0;transition:opacity .22s ease;}' +
      '.hole-scene-tile:hover .hole-scene-icon::before,.launcher-tile:hover .launcher-icon::before,' +
      '.hole-scene-tile:hover .launcher-icon::before,.launcher-tile:hover .hole-scene-icon::before{opacity:.5;}' +
      '.hole-scene-tile:hover .hole-scene-icon,.launcher-tile:hover .launcher-icon,' +
      '.hole-scene-tile:hover .launcher-icon,.launcher-tile:hover .hole-scene-icon{' +
      'color:var(--hole-icon-hover);transform:scale(1.07) translateY(-1px);}' +
      '.hole-scene-icon svg,.launcher-icon svg{' +
      'position:relative;z-index:1;width:26px;height:26px;stroke:currentColor;fill:none;' +
      'stroke-width:2;stroke-linecap:round;stroke-linejoin:round;pointer-events:none;' +
      'filter:drop-shadow(0 1px 2px rgba(0,0,0,.82)) drop-shadow(0 0 10px rgba(255,102,0,.32));}' +
      '.hole-scene-icon img,.launcher-icon img{' +
      'position:relative;z-index:1;width:28px;height:28px;object-fit:contain;pointer-events:none;display:block;' +
      'filter:drop-shadow(0 1px 3px rgba(0,0,0,.78)) drop-shadow(0 0 8px rgba(255,102,0,.22));}' +
      '.hole-scene-icon.is-logo img,.launcher-icon.is-logo img{width:32px;height:32px;}' +
      '.hole-scene-label,.launcher-label{' +
      'text-shadow:0 1px 3px rgba(0,0,0,.75),0 0 12px rgba(0,0,0,.35);}' +
      '.hole-scene-tile:hover .hole-scene-label,.launcher-tile:hover .launcher-label{color:rgba(255,200,150,.98);}' +
      '.hole-scene-sub,.hole-scene-badge{display:none!important;}';
  }

  function renderLauncherIcon(iconEl, it) {
    if (!iconEl || !it) return;
    ensureLauncherIconStyle();
    iconEl.textContent = '';
    iconEl.className = iconEl.className.replace(/\b(is-logo|is-raster)\b/g, '').trim();
    if (!/\b(hole-scene-icon|launcher-icon)\b/.test(iconEl.className)) {
      iconEl.classList.add('hole-scene-icon');
    }
    iconEl.style.background = '';
    iconEl.style.backgroundImage = '';
    iconEl.style.border = '';
    iconEl.style.boxShadow = '';
    if (it.isLogo) {
      iconEl.classList.add('is-logo');
      var logo = document.createElement('img');
      logo.src = it.img || LOGO_URL;
      logo.alt = '';
      iconEl.appendChild(logo);
      return;
    }
    if (it.img) {
      iconEl.classList.add('is-raster');
      var im = document.createElement('img');
      im.src = it.img;
      im.alt = '';
      iconEl.appendChild(im);
      if (it.fallbackIcon) {
        im.addEventListener('error', function () {
          iconEl.textContent = '';
          var svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
          svg.setAttribute('viewBox', '0 0 24 24');
          svg.innerHTML = it.fallbackIcon;
          iconEl.appendChild(svg);
        }, { once: true });
      }
      return;
    }
    if (it.icon) {
      var svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
      svg.setAttribute('viewBox', '0 0 24 24');
      svg.innerHTML = it.icon;
      iconEl.appendChild(svg);
    }
  }

  function normalizeSceneId(v) {
    var s = String(v || '').trim().toLowerCase();
    return s === 'notepad' ? 'scratchpad' : s;
  }

  function mount(opts) {
    opts = opts || {};
    var host = opts.host;
    if (!host) return null;
    ensureLauncherIconStyle();
    var mountRoot = opts.mountTarget || host;
    var post = typeof opts.post === 'function' ? opts.post : function () {};
    var badge = String(opts.badge || '').trim();
    var grid = mountRoot.querySelector('.hole-scene-grid');
    if (!grid) {
      grid = document.createElement('div');
      grid.className = 'hole-scene-grid';
      grid.setAttribute('role', 'grid');
      mountRoot.appendChild(grid);
    }
    if (badge) {
      var badgeHost = host;
      var tag = badgeHost.querySelector('.hole-scene-badge');
      if (!tag) {
        tag = document.createElement('div');
        tag.className = 'hole-scene-badge';
        badgeHost.appendChild(tag);
      }
      tag.textContent = badge;
      tag.style.display = 'none';
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
        renderLauncherIcon(icon, it);
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
      setPreview: function () {
        /* 启动层不展示「选择场景 / 已捕获」等文案 */
      }
    };
  }

  global.HoleSceneLauncher = {
    mount: mount,
    ITEMS: LAUNCHER_ITEMS,
    ensureStyle: ensureLauncherIconStyle,
    renderIcon: renderLauncherIcon
  };
})(window);
