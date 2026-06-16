/**
 * Lucide 图标统一注册表（与 assets/icon-nodes.json 同源，供 WebView 面板共用）
 *
 * 和弦面板图标映射须与 modules/ChordPad.ahk → ChordPad_DefaultCatalog() 的 iconLucide 字段保持一致。
 * VirtualKeyboard 的 FA_TO_LUCIDE 为 FontAwesome 迁移表；和弦面板仅使用下方 CHORD_* 常量。
 */
(function (global) {
  'use strict';

  var ICON_NODES_URL = 'https://app.local/assets/icon-nodes.json';
  var FALLBACK = 'zap';

  /** @type {Readonly<Record<string, string>>} cmdId → Lucide 名称 */
  var CHORD_CMD_ICONS = Object.freeze({
    ch_c: 'inbox',
    ch_v: 'clipboard-list',
    ch_x: 'history',
    ch_e: 'circle-question-mark',
    ch_q: 'settings',
    ch_f: 'search',
    ch_r: 'git-branch',
    ch_o: 'sparkles',
  });

  /** @type {Readonly<Record<string, string>>} CapsLock 和弦动作字母 → Lucide 名称 */
  var CHORD_ACTION_ICONS = Object.freeze({
    C: 'inbox',
    V: 'clipboard-list',
    X: 'history',
    E: 'circle-question-mark',
    Q: 'settings',
    F: 'search',
    R: 'git-branch',
    O: 'sparkles',
  });

  /** 面板 UI 装饰图标（非命令） */
  var UI_ICONS = Object.freeze({
    grip: 'grip-horizontal',
    drag: 'move',
  });

  var state = {
    ready: false,
    failed: false,
    loading: null,
    nodes: {},
    names: null,
  };

  function normalizeName(name) {
    return String(name || '').trim().toLowerCase();
  }

  function escapeAttr(v) {
    return String(v == null ? '' : v)
      .replace(/&/g, '&amp;')
      .replace(/"/g, '&quot;')
      .replace(/</g, '&lt;');
  }

  function init() {
    if (state.ready) return Promise.resolve(true);
    if (state.loading) return state.loading;
    state.loading = fetch(ICON_NODES_URL, { cache: 'no-store' })
      .then(function (resp) {
        if (!resp.ok) throw new Error('icon_nodes_fetch_failed');
        return resp.json();
      })
      .then(function (nodes) {
        state.nodes = nodes && typeof nodes === 'object' ? nodes : {};
        state.names = new Set(Object.keys(state.nodes));
        state.ready = true;
        state.failed = false;
        return true;
      })
      .catch(function () {
        state.failed = true;
        state.ready = false;
        return false;
      })
      .finally(function () {
        state.loading = null;
      });
    return state.loading;
  }

  function hasIcon(name) {
    var key = normalizeName(name);
    return !!(key && state.nodes[key]);
  }

  function getNode(name) {
    var key = normalizeName(name);
    if (!key) return null;
    return state.nodes[key] || null;
  }

  function resolveIcon(slot) {
    var host = normalizeName(slot && slot.iconLucide);
    if (host) {
      if (!state.ready || hasIcon(host)) return host;
    }
    var act = String((slot && slot.action) || '').toUpperCase();
    if (CHORD_ACTION_ICONS[act]) return CHORD_ACTION_ICONS[act];
    var cmd = String((slot && slot.cmdId) || '');
    if (CHORD_CMD_ICONS[cmd]) return CHORD_CMD_ICONS[cmd];
    return FALLBACK;
  }

  function renderSvg(iconName, extraClass) {
    var key = normalizeName(iconName);
    if (!key || (state.ready && !hasIcon(key))) key = FALLBACK;
    var node = getNode(key) || getNode(FALLBACK);
    var cls = escapeAttr(extraClass || '');
    if (!node) {
      return (
        '<svg viewBox="0 0 24 24" class="' + cls + '" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' +
        '<path d="M13 2 3 14h9l-1 8 10-12h-9l1-8z"></path></svg>'
      );
    }
    var body = node
      .map(function (item) {
        var tag = String((item && item[0]) || '').trim();
        var attrs = item && item[1] && typeof item[1] === 'object' ? item[1] : {};
        if (!/^[a-z][a-z0-9-]*$/i.test(tag)) return '';
        var pairs = Object.keys(attrs)
          .map(function (k) {
            return escapeAttr(k) + '="' + escapeAttr(attrs[k]) + '"';
          })
          .join(' ');
        return '<' + tag + (pairs ? ' ' + pairs : '') + '></' + tag + '>';
      })
      .join('');
    return (
      '<svg viewBox="0 0 24 24" class="' + cls + '" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' +
      body +
      '</svg>'
    );
  }

  function mountInto(el, iconName, extraClass) {
    if (!el) return el;
    el.innerHTML = renderSvg(iconName, extraClass);
    return el.querySelector('svg') || el;
  }

  function createSvgElement(iconName, extraClass) {
    var wrap = document.createElement('div');
    wrap.innerHTML = renderSvg(iconName, extraClass);
    return wrap.firstElementChild;
  }

  global.LucideRegistry = {
    ICON_NODES_URL: ICON_NODES_URL,
    FALLBACK: FALLBACK,
    CHORD_CMD_ICONS: CHORD_CMD_ICONS,
    CHORD_ACTION_ICONS: CHORD_ACTION_ICONS,
    UI_ICONS: UI_ICONS,
    init: init,
    ready: function () {
      return state.ready;
    },
    failed: function () {
      return state.failed;
    },
    hasIcon: hasIcon,
    getNode: getNode,
    resolveIcon: resolveIcon,
    renderSvg: renderSvg,
    mountInto: mountInto,
    createSvgElement: createSvgElement,
  };
})(typeof window !== 'undefined' ? window : globalThis);
