(function () {
  try {
    var hintId = parseInt(__NIUMA_ID__, 10) || 0;

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

    function resolveFromTextarea(ta) {
      if (!ta) return null;
      var p = ta.parentElement;
      if (p) {
        var ce = p.querySelector(
          '[data-slate-editor="true"],[data-lexical-editor="true"],[contenteditable="true"],[contenteditable=""]'
        );
        if (ce && vis(ce)) return ce;
      }
      var n = ta.nextElementSibling;
      if (n && (n.isContentEditable || n.getAttribute('contenteditable') != null) && vis(n)) return n;
      return ta;
    }

    function findEditor() {
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
        } catch (e1) {}
      }
      var nodes = document.querySelectorAll(
        'textarea[placeholder*="发消息"],textarea[placeholder*="DeepSeek"],textarea[placeholder*="发送消息"],[aria-placeholder*="发消息"],[aria-placeholder*="DeepSeek"],[data-slate-editor="true"],[contenteditable="true"],[contenteditable=""],textarea,[role="textbox"]'
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

    var editor = findEditor();
    if (!editor) return JSON.stringify({ ok: false, error: 'editor_not_found', inputOk: false, sendOk: false });
    try {
      editor.scrollIntoView({ block: 'center', inline: 'nearest' });
      editor.click && editor.click();
      editor.focus && editor.focus({ preventScroll: true });
    } catch (e3) {}
    return JSON.stringify({ ok: true, focused: true, tag: (editor.tagName || '').toLowerCase() });
  } catch (err) {
    return JSON.stringify({ ok: false, error: String((err && err.message) || err) });
  }
})();
