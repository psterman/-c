(function () {
  try {
    var selector = __NIUMA_SELECTOR__;
    var roleHint = String(__NIUMA_ROLEHINT__ || '').toLowerCase();

    function trimS(v) {
      return String(v == null ? '' : v).trim();
    }

    function assignDynamicLabelId(el) {
      if (!el || el.nodeType !== 1) return 0;
      var existing = parseInt(el.getAttribute('data-niuma-label-id') || '0', 10) || 0;
      if (existing > 0) return existing;
      if (!window.__NIUMA_DYNAMIC_LABEL_COUNTER__) {
        window.__NIUMA_DYNAMIC_LABEL_COUNTER__ = 8000;
      }
      window.__NIUMA_DYNAMIC_LABEL_COUNTER__ += 1;
      var id = window.__NIUMA_DYNAMIC_LABEL_COUNTER__;
      try {
        el.setAttribute('data-niuma-label-id', String(id));
      } catch (_) {
        return 0;
      }
      return id;
    }

    function vis(el) {
      if (!el || !el.getBoundingClientRect) return false;
      var r = el.getBoundingClientRect();
      if (!r || r.width < 2 || r.height < 2) return false;
      var cs = null;
      try {
        cs = window.getComputedStyle(el);
      } catch (_) {}
      if (cs && (cs.display === 'none' || cs.visibility === 'hidden' || cs.pointerEvents === 'none')) return false;
      return true;
    }

    function textOf(el) {
      if (!el) return '';
      var t = '';
      try {
        t = trimS(el.innerText || el.textContent || '');
      } catch (_) {}
      if (!t) {
        try {
          t =
            trimS(el.getAttribute('aria-label')) ||
            trimS(el.getAttribute('placeholder')) ||
            trimS(el.getAttribute('title'));
        } catch (_) {}
      }
      return t.toLowerCase().slice(0, 96);
    }

    function scoreRole(el, role) {
      if (!el) return -1e9;
      var tag = String((el.tagName || '')).toLowerCase();
      var typ = String((el.getAttribute('type') || '')).toLowerCase();
      var txt = textOf(el);
      var roleAttr = String((el.getAttribute('role') || '')).toLowerCase();
      var s = 0;
      if (role === 'search_input') {
        if (tag === 'textarea') s += 60;
        if (tag === 'input') s += 40;
        if (typ === 'search' || typ === 'text') s += 20;
        if (roleAttr === 'searchbox') s += 50;
        if (/搜索|query|search|关键词/.test(txt)) s += 35;
      } else if (role === 'search_submit') {
        if (tag === 'button') s += 50;
        if (tag === 'input' && (typ === 'submit' || typ === 'button')) s += 45;
        if (tag === 'a') s += 10;
        if (/百度一下|搜索|submit|查找/.test(txt)) s += 40;
      } else {
        if (tag === 'button' || tag === 'a' || tag === 'input' || tag === 'textarea') s += 10;
      }
      return s;
    }

    function pickByRoleHint(role) {
      if (!role) return null;
      var cands = document.querySelectorAll('input,textarea,button,a,[role="button"],[role="searchbox"]');
      var best = null;
      var bestScore = -1e9;
      for (var i = 0; i < cands.length; i++) {
        var el = cands[i];
        if (!vis(el)) continue;
        var sc = scoreRole(el, role);
        if (sc > bestScore) {
          bestScore = sc;
          best = el;
        }
      }
      return bestScore > 15 ? best : null;
    }

    var picked = null;
    var selectorUsed = '';
    var repaired = false;

    if (selector && String(selector).trim()) {
      try {
        picked = document.querySelector(String(selector));
        if (picked && !vis(picked)) picked = null;
        if (picked) selectorUsed = String(selector);
      } catch (_) {
        picked = null;
      }
    }

    // selector 未命中时，按 roleHint 做动态补救
    if (!picked && roleHint) {
      var byRole = pickByRoleHint(roleHint);
      if (byRole) {
        picked = byRole;
        repaired = true;
      }
    }

    if (!picked) {
      return JSON.stringify({ ok: false, error: 'resolve_not_found', selectorUsed: '', roleHint: roleHint || '' });
    }

    var id = assignDynamicLabelId(picked);
    if (id < 1) {
      return JSON.stringify({ ok: false, error: 'resolve_assign_id_failed', selectorUsed: selectorUsed, roleHint: roleHint || '' });
    }

    // 自动产出一个可回写缓存的 selector（优先稳定属性）
    if (!selectorUsed) {
      var tagL = String((picked.tagName || '')).toLowerCase();
      var nm = trimS(picked.getAttribute('name')).toLowerCase();
      var ar = trimS(picked.getAttribute('aria-label')).toLowerCase();
      var ph = trimS(picked.getAttribute('placeholder')).toLowerCase();
      if (nm) selectorUsed = tagL + '[name="' + nm.replace(/"/g, '\\"') + '"]';
      else if (ar) selectorUsed = tagL + '[aria-label="' + ar.replace(/"/g, '\\"') + '"]';
      else if (ph) selectorUsed = tagL + '[placeholder="' + ph.replace(/"/g, '\\"') + '"]';
      else {
        var rid = trimS(picked.getAttribute('id')).toLowerCase();
        if (rid && !/^[0-9]+$/.test(rid) && rid.length <= 32) selectorUsed = '#' + rid;
      }
    }

    return JSON.stringify({
      ok: true,
      id: id,
      selectorUsed: selectorUsed || '',
      roleHint: roleHint || '',
      repaired: !!repaired
    });
  } catch (err) {
    return JSON.stringify({ ok: false, error: String((err && err.message) || err) });
  }
})();
