/**
 * Simple themed modal helpers for WebView2/Browser.
 * Exposes: window.nmAlert(message, detail?), window.nmConfirm(message, detail?, opts?), window.nmPrompt(message, defaultValue?, opts?)
 *
 * Uses CSS variables when available:
 *  --bg / --bg-elevate / --panel / --surface
 *  --text / --muted
 *  --accent / --orange
 */
(function (g) {
  'use strict';

  function esc(str) {
    return String(str == null ? '' : str);
  }

  function ensureDom() {
    if (document.getElementById('nmModalOverlay')) return;

    var style = document.createElement('style');
    style.id = 'nmModalStyle';
    style.textContent =
      '#nmModalOverlay{position:fixed;inset:0;z-index:2147483000;display:none;align-items:center;justify-content:center;padding:16px;background:rgba(0,0,0,.55);backdrop-filter:blur(8px);-webkit-backdrop-filter:blur(8px)}' +
      '#nmModalOverlay.open{display:flex}' +
      '#nmModalPanel{width:min(520px,calc(100vw - 28px));border-radius:14px;border:1px solid rgba(255,255,255,.10);' +
      'background:var(--bg-elevate,var(--panel,var(--surface,#16283d)));box-shadow:0 18px 42px rgba(0,0,0,.35);' +
      'color:var(--text,#e7ebef);font-family:var(--font-ui,system-ui,sans-serif)}' +
      '#nmModalHead{padding:14px 16px 8px;font-weight:800;font-size:14px;letter-spacing:.01em}' +
      '#nmModalBody{padding:0 16px 12px;color:var(--muted,#93a0ad);white-space:pre-wrap;line-height:1.5;font-size:12px}' +
      '#nmModalInputWrap{padding:0 16px 12px}' +
      '#nmModalInput{width:100%;padding:10px 12px;border-radius:10px;border:1px solid rgba(255,255,255,.12);' +
      'background:rgba(0,0,0,.18);color:var(--text,#e7ebef);outline:none}' +
      '#nmModalInput:focus{border-color:rgba(255,179,71,.55);box-shadow:0 0 0 1px rgba(255,179,71,.18)}' +
      '#nmModalActions{display:flex;justify-content:flex-end;gap:8px;padding:10px 16px 14px;border-top:1px solid rgba(255,255,255,.08)}' +
      '.nmBtn{height:30px;padding:0 12px;border-radius:10px;border:1px solid rgba(255,255,255,.12);background:rgba(255,255,255,.04);color:var(--text,#e7ebef);cursor:pointer;font-size:12px}' +
      '.nmBtn:hover{background:rgba(255,255,255,.08)}' +
      '.nmBtnPrimary{border-color:rgba(255,179,71,.28);background:rgba(255,102,0,.16);color:#ffb347}' +
      '.nmBtnPrimary:hover{background:rgba(255,102,0,.24)}' +
      '.nmBtnDanger{border-color:rgba(255,71,71,.28);background:rgba(255,71,71,.14);color:#ffb0b0}' +
      '.nmBtnDanger:hover{background:rgba(255,71,71,.22)}';
    document.head.appendChild(style);

    var ov = document.createElement('div');
    ov.id = 'nmModalOverlay';
    ov.setAttribute('aria-hidden', 'true');
    ov.innerHTML =
      '<div id="nmModalPanel" role="dialog" aria-modal="true" aria-labelledby="nmModalTitle">' +
      '  <div id="nmModalHead"><span id="nmModalTitle"></span></div>' +
      '  <div id="nmModalBody" hidden></div>' +
      '  <div id="nmModalInputWrap" hidden><input id="nmModalInput" type="text" autocomplete="off" /></div>' +
      '  <div id="nmModalActions">' +
      '    <button type="button" class="nmBtn" id="nmModalCancel">取消</button>' +
      '    <button type="button" class="nmBtn nmBtnPrimary" id="nmModalOk">确定</button>' +
      '  </div>' +
      '</div>';
    document.body.appendChild(ov);
  }

  var activeResolve = null;

  function openModal(spec) {
    ensureDom();
    spec = spec || {};

    var ov = document.getElementById('nmModalOverlay');
    var title = document.getElementById('nmModalTitle');
    var body = document.getElementById('nmModalBody');
    var inputWrap = document.getElementById('nmModalInputWrap');
    var input = document.getElementById('nmModalInput');
    var ok = document.getElementById('nmModalOk');
    var cancel = document.getElementById('nmModalCancel');

    if (!ov || !title || !body || !ok || !cancel || !inputWrap || !input) {
      return Promise.resolve(spec.mode === 'prompt' ? null : spec.mode === 'confirm' ? false : true);
    }

    if (activeResolve) {
      try { activeResolve(spec.mode === 'prompt' ? null : spec.mode === 'confirm' ? false : true); } catch (_) {}
      activeResolve = null;
    }

    title.textContent = esc(spec.title || spec.message || '');

    var detail = esc(spec.detail || '');
    if (detail.trim()) {
      body.textContent = detail;
      body.hidden = false;
    } else {
      body.textContent = '';
      body.hidden = true;
    }

    ok.textContent = esc(spec.okLabel || '确定');
    cancel.textContent = esc(spec.cancelLabel || '取消');
    ok.classList.remove('nmBtnPrimary', 'nmBtnDanger');
    ok.classList.add(spec.danger ? 'nmBtnDanger' : 'nmBtnPrimary');
    cancel.hidden = spec.mode === 'alert';

    inputWrap.hidden = spec.mode !== 'prompt';
    input.value = spec.mode === 'prompt' ? esc(spec.defaultValue || '') : '';

    function close(val) {
      ov.classList.remove('open');
      ov.setAttribute('aria-hidden', 'true');
      document.removeEventListener('keydown', onKeydown, true);
      ov.removeEventListener('click', onBackdropClick, true);
      ok.removeEventListener('click', onOk, true);
      cancel.removeEventListener('click', onCancel, true);
      activeResolve = null;
      try { (spec.restoreFocus && spec.restoreFocus.focus) ? spec.restoreFocus.focus() : null; } catch (_) {}
      return val;
    }

    function onOk(e) {
      e && e.preventDefault && e.preventDefault();
      var v = spec.mode === 'prompt' ? String(input.value || '') : true;
      if (activeResolve) activeResolve(close(v));
    }
    function onCancel(e) {
      e && e.preventDefault && e.preventDefault();
      var v2 = spec.mode === 'prompt' ? null : false;
      if (activeResolve) activeResolve(close(v2));
    }
    function onBackdropClick(e) {
      if (e && e.target === ov) onCancel(e);
    }
    function onKeydown(e) {
      if (!e) return;
      if (e.key === 'Escape') return onCancel(e);
      if (e.key === 'Enter') {
        if (spec.mode === 'prompt') return onOk(e);
        if (spec.mode === 'confirm' || spec.mode === 'alert') return onOk(e);
      }
    }

    ov.classList.add('open');
    ov.setAttribute('aria-hidden', 'false');
    document.addEventListener('keydown', onKeydown, true);
    ov.addEventListener('click', onBackdropClick, true);
    ok.addEventListener('click', onOk, true);
    cancel.addEventListener('click', onCancel, true);

    try { (spec.mode === 'prompt' ? input : ok).focus(); } catch (_) {}

    return new Promise(function (resolve) {
      activeResolve = resolve;
    });
  }

  function nmConfirm(message, detail, opts) {
    opts = opts || {};
    try {
      return openModal({
        mode: 'confirm',
        message: message,
        detail: detail,
        okLabel: opts.okLabel,
        cancelLabel: opts.cancelLabel,
        danger: !!opts.danger,
        restoreFocus: document.activeElement
      }).then(function (v) { return !!v; });
    } catch (e) {
      try { return Promise.resolve(!!window.confirm(detail ? esc(message) + '\n\n' + esc(detail) : esc(message))); } catch (_) {}
      return Promise.resolve(false);
    }
  }

  function nmAlert(message, detail, opts) {
    opts = opts || {};
    try {
      return openModal({
        mode: 'alert',
        message: message,
        detail: detail,
        okLabel: opts.okLabel || '知道了',
        restoreFocus: document.activeElement
      }).then(function () { return true; });
    } catch (e) {
      try { window.alert(detail ? esc(message) + '\n\n' + esc(detail) : esc(message)); } catch (_) {}
      return Promise.resolve(true);
    }
  }

  function nmPrompt(message, defaultValue, opts) {
    opts = opts || {};
    try {
      return openModal({
        mode: 'prompt',
        message: message,
        detail: opts.detail,
        okLabel: opts.okLabel,
        cancelLabel: opts.cancelLabel,
        defaultValue: defaultValue,
        restoreFocus: document.activeElement
      }).then(function (v) {
        if (v == null) return null;
        return String(v);
      });
    } catch (e) {
      try { return Promise.resolve(window.prompt(esc(message), esc(defaultValue || ''))); } catch (_) {}
      return Promise.resolve(null);
    }
  }

  g.nmConfirm = g.nmConfirm || nmConfirm;
  g.nmAlert = g.nmAlert || nmAlert;
  g.nmPrompt = g.nmPrompt || nmPrompt;
})(typeof globalThis !== 'undefined' ? globalThis : window);

