(function () {
  try {
    var hintId = __NIUMA_ID__;
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
    function findDoubaoEditorGlobal() {
      var host = '';
      try {
        host = String((location.hostname || '')).toLowerCase();
      } catch (_) {}
      if (!/doubao\.com/.test(host)) return null;
      function resolveTa(ta) {
        if (!ta) return null;
        var p = ta.parentElement;
        var d = 0;
        while (p && d < 8) {
          var ce = p.querySelector(
            '[data-slate-editor="true"],[data-lexical-editor="true"],[contenteditable="true"],[contenteditable=""]'
          );
          if (ce && vis(ce)) return ce;
          p = p.parentElement;
          d++;
        }
        return null;
      }
      var nodes = document.querySelectorAll(
        'textarea[placeholder*="发消息"],[aria-placeholder*="发消息"],[data-slate-editor="true"],[contenteditable="true"],[contenteditable=""]'
      );
      var best = null;
      var bestY = -1;
      var i, n, y;
      for (i = 0; i < nodes.length; i++) {
        n = nodes[i];
        if (!vis(n)) continue;
        if ((n.tagName || '').toLowerCase() === 'textarea') n = resolveTa(n) || n;
        y = n.getBoundingClientRect().top;
        if (y > bestY) {
          bestY = y;
          best = n;
        }
      }
      return best;
    }

    function resolveTarget(root) {
      if (!root) return null;
      var doubaoEd = findDoubaoEditorGlobal();
      if (doubaoEd) return doubaoEd;
      if (root.isContentEditable || root.getAttribute('role') === 'textbox') return root;
      var tag = (root.tagName || '').toLowerCase();
      if (tag === 'textarea' || tag === 'input') {
        var p = root.parentElement;
        if (p) {
          var sib = p.querySelector(
            '[data-slate-editor="true"],[data-lexical-editor="true"],[contenteditable="true"],[contenteditable=""]'
          );
          if (sib && vis(sib)) return sib;
        }
      }
      var inner = root.querySelector(
        '[data-slate-editor="true"],[data-lexical-editor="true"],[contenteditable="true"],[contenteditable=""],textarea,[role="textbox"],input:not([type="hidden"])'
      );
      if (inner && vis(inner)) {
        var itag = (inner.tagName || '').toLowerCase();
        if (itag !== 'textarea' && itag !== 'input') return inner;
        if (tag === 'textarea' || tag === 'input') {
          var p2 = inner.parentElement || root.parentElement;
          if (p2) {
            var ce = p2.querySelector('[contenteditable="true"],[contenteditable=""]');
            if (ce && vis(ce)) return ce;
          }
          return inner;
        }
      }
      if (tag === 'textarea' || tag === 'input') return root;
      return inner && vis(inner) ? inner : root;
    }
    var el = null;
    if (hintId > 0) {
      try {
        el = document.querySelector('[data-niuma-label-id="' + hintId + '"]');
      } catch (e1) {
        el = null;
      }
    }
    if (!el || !vis(el)) {
      return JSON.stringify({ ok: false, error: 'element_not_found' });
    }
    var target = resolveTarget(el);
    if (!target) target = el;
    try {
      target.scrollIntoView({ block: 'center', inline: 'nearest' });
    } catch (e2) {}
    var r = target.getBoundingClientRect();
    var cx = r.left + r.width / 2;
    var cy = r.top + r.height / 2;
    return JSON.stringify({
      ok: true,
      cx: Math.round(cx),
      cy: Math.round(cy),
      vw: window.innerWidth || 0,
      vh: window.innerHeight || 0,
      w: Math.round(r.width),
      h: Math.round(r.height)
    });
  } catch (err) {
    return JSON.stringify({ ok: false, error: String((err && err.message) || err) });
  }
})();
