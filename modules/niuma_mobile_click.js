(function () {
  try {
    var id = __NIUMA_ID__;
    var el = document.querySelector('[data-niuma-label-id="' + id + '"]');
    if (!el) return JSON.stringify({ ok: false, error: 'element_not_found' });

    function vis(n) {
      if (!n || n.nodeType !== 1) return false;
      try {
        var st = window.getComputedStyle(n);
        if (!st || st.display === 'none' || st.visibility === 'hidden') return false;
        var r = n.getBoundingClientRect();
        return r.width >= 2 && r.height >= 2;
      } catch (e) {
        return false;
      }
    }

    function isAttachOrFileTarget(n) {
      if (!n || n.nodeType !== 1) return false;
      var tag = (n.tagName || '').toLowerCase();
      var typ = String((n.getAttribute('type') || '')).toLowerCase();
      if (tag === 'input' && typ === 'file') return true;
      var blob =
        String(n.getAttribute('aria-label') || '') +
        ' ' +
        String(n.getAttribute('title') || '') +
        ' ' +
        String(n.innerText || n.textContent || '') +
        ' ' +
        String(n.getAttribute('accept') || '');
      if (/附件|上传|attach|paperclip|clip|image|photo|gallery|file|打开文件/i.test(blob)) return true;
      return false;
    }

    function validateClickTarget(target, labeledEl, cx, cy) {
      if (!target) return { ok: false, error: 'no_target' };
      if (isAttachOrFileTarget(target)) return { ok: false, error: 'unsafe_click_attach_zone' };
      var host = '';
      try {
        host = String((location.hostname || '')).toLowerCase();
      } catch (_) {}
      var vw = window.innerWidth || 400;
      var sendLike = false;
      var blob =
        String(target.getAttribute('aria-label') || '') +
        ' ' +
        String(target.getAttribute('title') || '') +
        ' ' +
        String(target.innerText || target.textContent || '');
      if (/发送|send|submit|提交/i.test(blob)) sendLike = true;
      var vh = window.innerHeight || 600;
      if (
        (/deepseek\.com|doubao\.com|gemini\.google/.test(host) &&
          cx < vw * 0.28 &&
          cy > vh * 0.7 &&
          !sendLike)
      ) {
        try {
          console.error('[SECURITY_GUARD] blocked attach-zone click at (' + cx + ',' + cy + ')');
        } catch (_) {}
        return { ok: false, error: 'unsafe_click_attach_zone' };
      }
      try {
        var hit = document.elementFromPoint(cx, cy);
        if (hit && isAttachOrFileTarget(hit) && !target.contains(hit))
          return { ok: false, error: 'unsafe_click_attach_zone' };
      } catch (eH) {}
      return { ok: true };
    }

    function resolveClickTarget(root) {
      if (!root) return root;
      var tag = (root.tagName || '').toLowerCase();
      var host = '';
      try {
        host = String((location.hostname || '')).toLowerCase();
      } catch (_) {}
      if (/doubao\.com/.test(host) && tag === 'textarea') {
        var p = root.parentElement;
        if (p) {
          var ce = p.querySelector(
            '[data-slate-editor="true"],[data-lexical-editor="true"],[contenteditable="true"],[contenteditable=""]'
          );
          if (ce && vis(ce)) return ce;
        }
      }
      if (tag === 'button' || tag === 'a' || tag === 'summary') return root;
      if (root.getAttribute && root.getAttribute('role') === 'button') return root;
      var sel =
        'textarea[name="q"],input[name="q"],input[type="search"],textarea[type="search"],' +
        '[role="searchbox"],textarea,input:not([type="hidden"]):not([type="submit"]):not([type="button"])';
      var inner, nodes, i, n;
      try {
        inner = root.querySelector && root.querySelector(sel);
      } catch (e0) {
        inner = null;
      }
      if (inner && vis(inner)) return inner;
      try {
        nodes = root.querySelectorAll(sel);
      } catch (e1) {
        nodes = [];
      }
      for (i = 0; i < nodes.length; i++) {
        n = nodes[i];
        if (vis(n)) return n;
      }
      return root;
    }

    try {
      el.scrollIntoView({ block: 'center', inline: 'nearest' });
    } catch (e2) {}

    var target = resolveClickTarget(el);
    var r = target.getBoundingClientRect();
    var cx = r.left + r.width / 2;
    var cy = r.top + r.height / 2;

    var hit = null;
    try {
      hit = document.elementFromPoint(cx, cy);
    } catch (e3) {
      hit = null;
    }
    if (hit && target !== hit && !target.contains(hit)) {
      var htag = (hit.tagName || '').toLowerCase();
      if (htag === 'input' || htag === 'textarea' || hit.isContentEditable) target = hit;
      else if (hit.closest && target.contains && !target.contains(hit)) {
        /* keep target */
      }
    }

    r = target.getBoundingClientRect();
    cx = r.left + r.width / 2;
    cy = r.top + r.height / 2;
    var vClick = validateClickTarget(target, el, cx, cy);
    if (!vClick.ok) return JSON.stringify({ ok: false, error: vClick.error || 'unsafe_click' });
    var o = { bubbles: true, cancelable: true, view: window, clientX: cx, clientY: cy };

    try {
      target.dispatchEvent(
        new PointerEvent('pointerdown', Object.assign({}, o, { pointerId: 1, pointerType: 'touch', isPrimary: true }))
      );
    } catch (e4) {}
    try {
      target.dispatchEvent(
        new TouchEvent('touchstart', {
          bubbles: true,
          cancelable: true,
          touches: [],
          targetTouches: [],
          changedTouches: []
        })
      );
    } catch (e5) {}
    try {
      target.dispatchEvent(new MouseEvent('mousedown', o));
      target.dispatchEvent(new MouseEvent('mouseup', o));
      target.dispatchEvent(new MouseEvent('click', o));
    } catch (e6) {
      try {
        target.click();
      } catch (e7) {}
    }
    try {
      target.dispatchEvent(
        new PointerEvent('pointerup', Object.assign({}, o, { pointerId: 1, pointerType: 'touch', isPrimary: true }))
      );
    } catch (e8) {}
    try {
      target.dispatchEvent(
        new TouchEvent('touchend', {
          bubbles: true,
          cancelable: true,
          touches: [],
          targetTouches: [],
          changedTouches: []
        })
      );
    } catch (e9) {}
    try {
      if (target.focus) target.focus({ preventScroll: true });
    } catch (e10) {
      try {
        target.focus && target.focus();
      } catch (e11) {}
    }

    return JSON.stringify({ ok: true, tag: (target.tagName || '').toLowerCase() });
  } catch (err) {
    return JSON.stringify({ ok: false, error: String((err && err.message) || err) });
  }
})();
