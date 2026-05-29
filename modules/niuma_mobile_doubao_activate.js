(function () {
  try {
    var hintId = parseInt(__NIUMA_ID__, 10) || 0;

    function vis(n) {
      if (!n || n.nodeType !== 1) return false;
      try {
        var st = window.getComputedStyle(n);
        if (!st || st.display === 'none' || st.visibility === 'hidden' || st.pointerEvents === 'none') return false;
        var r = n.getBoundingClientRect();
        return r.width >= 4 && r.height >= 4;
      } catch (e) {
        return false;
      }
    }

    function isEditable(n) {
      if (!n) return false;
      var tag = (n.tagName || '').toLowerCase();
      return n.isContentEditable || tag === 'textarea' || tag === 'input' || n.getAttribute('role') === 'textbox';
    }

    function pickBottom(nodes) {
      var best = null;
      var bestY = -1;
      var i, n, y;
      for (i = 0; i < nodes.length; i++) {
        n = nodes[i];
        if (!vis(n) || !isEditable(n)) continue;
        y = n.getBoundingClientRect().top;
        if (y > bestY) {
          bestY = y;
          best = n;
        }
      }
      return best;
    }

    function resolveFromTextarea(ta) {
      if (!ta) return null;
      var p = ta.parentElement;
      var depth = 0;
      while (p && depth < 8) {
        var ce = p.querySelector(
          '[data-slate-editor="true"],[data-lexical-editor="true"],[contenteditable="true"],[contenteditable=""]'
        );
        if (ce && vis(ce)) return ce;
        p = p.parentElement;
        depth++;
      }
      var n = ta.nextElementSibling;
      if (n && isEditable(n) && vis(n)) return n;
      return null;
    }

    function findDoubaoEditor() {
      if (hintId > 0) {
        try {
          var hint = document.querySelector('[data-niuma-label-id="' + hintId + '"]');
          if (hint) {
            var tag = (hint.tagName || '').toLowerCase();
            if (tag === 'textarea' || tag === 'input') {
              var resolved = resolveFromTextarea(hint);
              if (resolved && vis(resolved)) return resolved;
            }
            if (hint.isContentEditable && vis(hint)) return hint;
          }
        } catch (e0) {}
      }
      var nodes = document.querySelectorAll(
        'textarea[placeholder*="发消息"],textarea[placeholder*="DeepSeek"],textarea[placeholder*="发送消息"],[aria-placeholder*="发消息"],[aria-placeholder*="DeepSeek"],[data-slate-editor="true"],[data-lexical-editor="true"],[contenteditable="true"],[contenteditable=""]'
      );
      var best = null;
      var bestY = -1;
      var i, n, y;
      for (i = 0; i < nodes.length; i++) {
        n = nodes[i];
        if (!vis(n)) continue;
        if ((n.tagName || '').toLowerCase() === 'textarea') n = resolveFromTextarea(n) || n;
        y = n.getBoundingClientRect().top;
        if (y > bestY) {
          bestY = y;
          best = n;
        }
      }
      return best;
    }

    function clickFocus(el) {
      if (!el) return false;
      try {
        el.scrollIntoView({ block: 'center', inline: 'nearest' });
      } catch (e2) {}
      var r = el.getBoundingClientRect();
      var cx = r.left + r.width / 2;
      var cy = r.top + r.height / 2;
      var hit = null;
      try {
        hit = document.elementFromPoint(cx, cy);
      } catch (e3) {
        hit = null;
      }
      var target = el;
      if (hit && isEditable(hit)) target = hit;
      else if (hit && hit.closest) {
        var up = hit.closest('[contenteditable="true"],[contenteditable=""],textarea,[role="textbox"]');
        if (up && vis(up)) target = up;
      }
      r = target.getBoundingClientRect();
      cx = r.left + r.width / 2;
      cy = r.top + r.height / 2;
      var o = { bubbles: true, cancelable: true, view: window, clientX: cx, clientY: cy };
      try {
        target.dispatchEvent(
          new PointerEvent('pointerdown', Object.assign({}, o, { pointerId: 1, pointerType: 'mouse', isPrimary: true }))
        );
        target.dispatchEvent(new MouseEvent('mousedown', o));
        target.dispatchEvent(new MouseEvent('mouseup', o));
        target.dispatchEvent(new MouseEvent('click', o));
      } catch (e4) {
        try {
          target.click && target.click();
        } catch (e5) {}
      }
      try {
        target.focus && target.focus({ preventScroll: true });
      } catch (e6) {
        try {
          target.focus && target.focus();
        } catch (e7) {}
      }
      try {
        if (document.activeElement !== target && target.focus) target.focus();
      } catch (e8) {}
      return target;
    }

    var editor = findDoubaoEditor();
    if (!editor) return JSON.stringify({ ok: false, error: 'editor_not_found', focused: false });

    var focused = clickFocus(editor);
    var ae = document.activeElement;
    var focusedOk = !!(ae && (ae === focused || focused.contains(ae) || ae.contains(focused)));

    return JSON.stringify({
      ok: true,
      focused: focusedOk,
      editorTag: (focused.tagName || '').toLowerCase(),
      activeTag: ae ? (ae.tagName || '').toLowerCase() : '',
      cx: Math.round(focused.getBoundingClientRect().left + focused.getBoundingClientRect().width / 2),
      cy: Math.round(focused.getBoundingClientRect().top + focused.getBoundingClientRect().height / 2)
    });
  } catch (err) {
    return JSON.stringify({ ok: false, error: String((err && err.message) || err), focused: false });
  }
})();
