(function () {
  'use strict';
  var MAX = 56, PRE = 80, MAXTXT = 72;
  var SEL =
    'a[href],button,input,textarea,select,summary,[contenteditable="true"],[contenteditable=""],' +
    '[role="button"],[role="link"],[role="tab"],[role="menuitem"],[role="searchbox"],[onclick],[ontouchstart],[data-action]';
  var ICON_WORDS = {
    search: 'icon-search',
    cart: 'btn-cart',
    close: 'btn-close',
    menu: 'btn-menu',
    submit: 'btn-submit',
    back: 'btn-back',
    share: 'btn-share',
    login: 'btn-login',
    delete: 'btn-delete',
    more: 'btn-more'
  };
  var ICON_ZH = {
    搜索: 'icon-search',
    购物车: 'btn-cart',
    关闭: 'btn-close',
    菜单: 'btn-menu',
    提交: 'btn-submit',
    返回: 'btn-back',
    分享: 'btn-share',
    登录: 'btn-login',
    删除: 'btn-delete',
    更多: 'btn-more'
  };
  window.__NIUMA_LABEL_DEBUG__ = window.__NIUMA_LABEL_DEBUG__ !== false;
  if (window.__NIUMA_VP_THROTTLE__ === undefined) window.__NIUMA_VP_THROTTLE__ = false;

  function vpRect() {
    var vv = window.visualViewport;
    var de = document.documentElement;
    var w = (vv && vv.width) || window.innerWidth || de.clientWidth || 0;
    var h = (vv && vv.height) || window.innerHeight || de.clientHeight || 0;
    var l = (vv && vv.offsetLeft) || 0;
    var t = (vv && vv.offsetTop) || 0;
    return { left: l, top: t, right: l + w, bottom: t + h, width: w, height: h };
  }

  function vis(el) {
    if (!el || el.nodeType !== 1) return false;
    var st = window.getComputedStyle(el);
    if (!st || st.display === 'none' || st.visibility === 'hidden') return false;
    if (parseFloat(st.opacity) < 0.05) return false;
    var r = el.getBoundingClientRect();
    if (r.width < 2 || r.height < 2) return false;
    return true;
  }

  function inter(r, vp) {
    return !(r.right < vp.left - PRE || r.left > vp.right + PRE || r.bottom < vp.top - PRE || r.top > vp.bottom + PRE);
  }

  function centerBoost(r, vp) {
    var cx = (r.left + r.right) / 2, cy = (r.top + r.bottom) / 2;
    var mx = vp.left + vp.width * 0.3, my = vp.top + vp.height * 0.3;
    var Mx = vp.left + vp.width * 0.7, My = vp.top + vp.height * 0.7;
    return (cx >= mx && cx <= Mx && cy >= my && cy <= My) ? 1.5 : 1;
  }

  function trimT(s) {
    s = String(s || '').replace(/\s+/g, ' ').trim();
    return s.length > MAXTXT ? s.substring(0, MAXTXT) : s;
  }

  function countInteractive(anc) {
    var n = 0, i, list;
    try {
      list = anc.querySelectorAll(SEL);
      for (i = 0; i < list.length; i++) if (vis(list[i])) n++;
    } catch (e) {}
    return n;
  }

  function siblingPolluted(el) {
    var p = el.parentElement;
    if (!p) return false;
    return countInteractive(p) >= 2;
  }

  function childText(el) {
    var i, c, t, img;
    for (i = 0; i < el.childNodes.length; i++) {
      c = el.childNodes[i];
      if (c.nodeType === 3) {
        t = trimT(c.textContent);
        if (t) return t;
      } else if (c.nodeType === 1) {
        if (c.tagName === 'IMG') {
          t = trimT(c.getAttribute('alt'));
          if (t) return t;
        } else {
          t = trimT(c.innerText || c.textContent);
          if (t && c.children.length < 4) return t;
        }
      }
    }
    return '';
  }

  function isInteractiveEl(el) {
    if (!el || el.nodeType !== 1) return false;
    return isCand(el);
  }

  function clickableAncestor(el) {
    var p = el;
    var depth = 0;
    while (p && depth < 6) {
      if (isInteractiveEl(p)) return p;
      p = p.parentElement;
      depth++;
    }
    return null;
  }

  function classTokenHint(className) {
    if (!className) return '';
    var parts = String(className).toLowerCase().split(/\s+/);
    var i, tok, w;
    for (i = 0; i < parts.length; i++) {
      tok = parts[i];
      if (!tok || tok.length < 3) continue;
      if (/[_][0-9a-f]{4,}$/i.test(tok) || /^[a-z]{1,2}$/.test(tok)) continue;
      if (/^(flex|grid|inline|block|absolute|relative|fixed|sticky|items-|justify-|content-|p-\d|px-|py-|m-\d|mx-|my-|w-|h-|text-|bg-|border-|rounded|gap-|space-|font-|leading-|tracking-|z-|top-|left-|right-|bottom-|min-|max-|overflow)/.test(tok))
        continue;
      for (w in ICON_WORDS) {
        if (tok === w || tok.indexOf(w) === 0 || tok.indexOf('-' + w + '-') >= 0) return ICON_WORDS[w];
      }
    }
    return '';
  }

  function textKeywordHint(s) {
    s = String(s || '').toLowerCase();
    var k;
    for (k in ICON_WORDS) {
      if (s.indexOf(k) >= 0) return ICON_WORDS[k];
    }
    var zk;
    for (zk in ICON_ZH) {
      if (s.indexOf(zk) >= 0) return ICON_ZH[zk];
    }
    return '';
  }

  function iconHintOf(el) {
    if (!el || el.nodeType !== 1) return '';
    var tag = (el.tagName || '').toLowerCase();
    var ty = (el.getAttribute('type') || '').toLowerCase();
    var role = (el.getAttribute('role') || '').toLowerCase();
    var al = trimT(el.getAttribute('aria-label'));
    var ti = trimT(el.getAttribute('title'));
    var ph = trimT(el.getAttribute('placeholder'));
    var blob = (al + ' ' + ti + ' ' + ph).toLowerCase();
    var h = textKeywordHint(blob);
    if (h) return h;
    if (ty === 'search' || role === 'searchbox') return 'icon-search';
    if (ty === 'submit') return 'btn-submit';
    if (tag === 'button' && /百度一下|搜索/.test(blob + trimT(el.innerText))) return 'btn-search';
    h = classTokenHint(el.getAttribute('class') || '');
    if (h) return h;
    if (tag === 'svg' || tag === 'use') {
      var ref = el.getAttribute('href') || el.getAttribute('xlink:href') || '';
      if (/search/i.test(ref)) return 'icon-search';
      if (/cart/i.test(ref)) return 'btn-cart';
      if (/close/i.test(ref)) return 'btn-close';
      if (/menu/i.test(ref)) return 'btn-menu';
    }
    if (tag === 'img') {
      var alt = trimT(el.getAttribute('alt'));
      h = textKeywordHint(alt);
      if (h) return h;
    }
    return '';
  }

  function iconHintForLabelTarget(el) {
    var hint = iconHintOf(el);
    if (hint) return hint;
    var anc = clickableAncestor(el);
    if (anc && anc !== el) return iconHintOf(anc);
    return '';
  }

  function extractText(el, id, iconHint) {
    var t = trimT(el.innerText || el.textContent);
    if (t) return t;
    t = trimT(el.getAttribute('aria-label'));
    if (t) return t;
    var lb = el.getAttribute('aria-labelledby');
    if (lb) {
      try {
        var ref = document.getElementById(lb);
        if (ref) {
          t = trimT(ref.innerText || ref.textContent);
          if (t) return t;
        }
      } catch (e2) {}
    }
    t = trimT(el.getAttribute('title') || el.getAttribute('placeholder') || el.getAttribute('alt'));
    if (t) return t;
    t = childText(el);
    if (t) return t;
    var base = siblingPolluted(el) ? '(无文本#' + id + ')' : '(无文本#' + id + ')';
    if (iconHint) return base + ' [IconHint:' + iconHint + ']';
    return base;
  }

  function hintOf(el) {
    var tag = (el.tagName || '').toLowerCase();
    var ty = (el.getAttribute('type') || '').toLowerCase();
    var role = (el.getAttribute('role') || '').toLowerCase();
    var h = tag;
    if (ty) h += '[' + ty + ']';
    if (role) h += '[role=' + role + ']';
    return h;
  }

  function isCand(el) {
    if (!el || el === document.body || el === document.documentElement) return false;
    if (!vis(el)) return false;
    var tag = (el.tagName || '').toLowerCase();
    if (tag === 'svg' || tag === 'use' || tag === 'path') return false;
    if (tag === 'a' && !el.getAttribute('href')) {
      if (!el.getAttribute('onclick') && !el.getAttribute('ontouchstart') && el.getAttribute('role') !== 'button') {
        try {
          if (window.getComputedStyle(el).cursor !== 'pointer') return false;
        } catch (e0) {
          return false;
        }
      }
    }
    if (el.matches && el.matches(SEL)) return true;
    try {
      var st = window.getComputedStyle(el);
      if (st && st.cursor === 'pointer' && tag !== 'html' && tag !== 'body') {
        var r = el.getBoundingClientRect();
        if (r.width < 400 || r.height < 120) return true;
      }
    } catch (e1) {}
    return false;
  }

  function typeBoost(el) {
    var tag = (el.tagName || '').toLowerCase();
    var role = (el.getAttribute('role') || '').toLowerCase();
    if (tag === 'input' || tag === 'textarea' || tag === 'select' || tag === 'button' || tag === 'a') return 2;
    if (role === 'button' || role === 'link') return 2;
    return 1;
  }

  var SEARCH_SEL =
    '#kw,#index-kw,#index-form input,#form input[name="word"],input[name="word"],input[name="q"],textarea[name="q"],' +
    'input[name="query"],textarea[name="query"],input[type="search"],textarea[type="search"],' +
    'input[type="text"][class*="search"],input[class*="s_ipt"],textarea[name="word"],[role="searchbox"],' +
    '[aria-label*="搜索"],[aria-label*="Search"],[placeholder*="搜索"],[placeholder*="Search"]';

  function isSearchControl(el) {
    if (!el || el.nodeType !== 1) return false;
    try {
      if (el.matches && el.matches(SEARCH_SEL)) return true;
    } catch (e0) {}
    var tag = (el.tagName || '').toLowerCase();
    if (tag !== 'input' && tag !== 'textarea') return false;
    var ph = String(el.getAttribute('placeholder') || '');
    var al = String(el.getAttribute('aria-label') || '');
    var nm = String(el.getAttribute('name') || '').toLowerCase();
    if (/搜索|百度|query|word|kw/i.test(ph + al + nm)) return true;
    return false;
  }

  function preferActElement(el) {
    if (!el || el.nodeType !== 1) return el;
    var tag = (el.tagName || '').toLowerCase();
    if (tag === 'input' || tag === 'textarea' || tag === 'select' || el.getAttribute('role') === 'searchbox')
      return el;
    var sel =
      'textarea[name="q"],input[name="q"],textarea[name="query"],input[name="query"],' +
      'input[type="search"],textarea[type="search"],[role="searchbox"],textarea,' +
      'input:not([type="hidden"]):not([type="submit"]):not([type="button"]):not([type="image"])';
    var inner, nodes, i, n, best;
    try {
      inner = el.querySelector(sel);
    } catch (e0) {
      inner = null;
    }
    if (inner && vis(inner)) {
      var nm = String(inner.getAttribute('name') || '').toLowerCase();
      if (nm === 'q' || nm === 'query' || inner.getAttribute('role') === 'searchbox') return inner;
      best = inner;
    }
    try {
      nodes = el.querySelectorAll(sel);
    } catch (e1) {
      nodes = [];
    }
    for (i = 0; i < nodes.length; i++) {
      n = nodes[i];
      if (!vis(n)) continue;
      nm = String(n.getAttribute('name') || '').toLowerCase();
      if (nm === 'q' || nm === 'query' || n.getAttribute('role') === 'searchbox') return n;
      if (!best) best = n;
    }
    return best || el;
  }

  function collectForcedSearch(vp, seen) {
    var forced = [], nodes, i, el, r, pos, w;
    try {
      nodes = document.querySelectorAll(SEARCH_SEL);
    } catch (e1) {
      nodes = [];
    }
    for (i = 0; i < nodes.length; i++) {
      el = nodes[i];
      if (!vis(el) || seen.has(el)) continue;
      if (!isCand(el) && !isSearchControl(el)) continue;
      seen.add(el);
      r = el.getBoundingClientRect();
      if (!inter(r, vp)) continue;
      try {
        pos = window.getComputedStyle(el).position;
      } catch (e2) {
        pos = '';
      }
      w = 1e12;
      forced.push({ el: el, rect: r, pos: pos, weight: w, forcedSearch: true });
    }
    return forced;
  }

  function clearLabels() {
    var root = document.getElementById('niuma-mobile-label-root');
    if (root) root.remove();
    var old = document.querySelectorAll('[data-niuma-label-id]');
    var i;
    for (i = 0; i < old.length; i++) {
      old[i].removeAttribute('data-niuma-label-id');
      old[i].classList.remove('niuma-label-target');
      old[i].style.outline = '';
      old[i].style.outlineOffset = '';
    }
  }

  function ensureVpThrottle() {
    if (window.__NIUMA_VP_LISTENER__) return;
    window.__NIUMA_VP_LISTENER__ = true;
    var lastH = 0, stable = 0, timer = null;
    function onVp() {
      if (!window.__NIUMA_VP_THROTTLE__) return;
      clearTimeout(timer);
      timer = setTimeout(function () {
        var h = (window.visualViewport && window.visualViewport.height) || window.innerHeight;
        if (Math.abs(h - lastH) < 8) stable++;
        else stable = 0;
        lastH = h;
        if (stable >= 2) window.__NIUMA_VP_THROTTLE__ = false;
      }, 200);
    }
    try {
      if (window.visualViewport) {
        window.visualViewport.addEventListener('resize', onVp);
        window.visualViewport.addEventListener('scroll', onVp);
      }
    } catch (e) {}
  }

  function drawBadge(root, el, id, rect, pos) {
    if (!window.__NIUMA_LABEL_DEBUG__) return;
    var badge = document.createElement('div');
    badge.className = 'niuma-label-badge';
    badge.textContent = String(id);
    badge.style.cssText = 'position:fixed;z-index:2147483647;pointer-events:none;min-width:16px;height:16px;line-height:16px;padding:0 4px;font-size:11px;font-weight:700;color:#fff;background:#22c55e;border-radius:4px;box-shadow:0 1px 4px rgba(0,0,0,.35);';
    var left = rect.left, top = rect.top;
    if (pos === 'fixed' || pos === 'sticky') {
      badge.style.position = 'fixed';
    }
    badge.style.left = Math.max(0, left) + 'px';
    badge.style.top = Math.max(0, top) + 'px';
    root.appendChild(badge);
  }

  try {
    if (window.__NIUMA_VP_THROTTLE__) {
      return JSON.stringify({ ok: true, skipped: true, reason: 'viewport_throttle', items: [] });
    }
    ensureVpThrottle();
    clearLabels();
    var vp = vpRect();
    var seen = new Set();
    var pool = [];
    var all = document.querySelectorAll(SEL);
    var i, el, r, pos, w;
    for (i = 0; i < all.length; i++) {
      el = all[i];
      if (!isCand(el) || seen.has(el)) continue;
      seen.add(el);
      r = el.getBoundingClientRect();
      if (!inter(r, vp)) continue;
      try {
        pos = window.getComputedStyle(el).position;
      } catch (e3) {
        pos = '';
      }
      w = r.width * r.height * typeBoost(el) * centerBoost(r, vp);
      pool.push({ el: el, rect: r, pos: pos, weight: w });
    }
    var cursorEls = document.querySelectorAll('div,span,li,p,img');
    for (i = 0; i < cursorEls.length && pool.length < 200; i++) {
      el = cursorEls[i];
      if (seen.has(el) || !vis(el)) continue;
      try {
        if (window.getComputedStyle(el).cursor !== 'pointer') continue;
      } catch (e4) {
        continue;
      }
      if (!isCand(el)) continue;
      seen.add(el);
      r = el.getBoundingClientRect();
      if (!inter(r, vp)) continue;
      try {
        pos = window.getComputedStyle(el).position;
      } catch (e5) {
        pos = '';
      }
      w = r.width * r.height * typeBoost(el) * centerBoost(r, vp);
      pool.push({ el: el, rect: r, pos: pos, weight: w });
    }
    var forcedSearch = collectForcedSearch(vp, seen);
    if (forcedSearch.length) {
      pool = forcedSearch.concat(pool);
    }
    pool.sort(function (a, b) {
      var af = a.forcedSearch ? 1 : 0;
      var bf = b.forcedSearch ? 1 : 0;
      if (af !== bf) return bf - af;
      return b.weight - a.weight;
    });
    var truncated = pool.length > MAX;
    var totalCandidates = pool.length;
    if (truncated) pool = pool.slice(0, MAX);
    var deduped = [];
    var elSeen = new Set();
    for (i = 0; i < pool.length; i++) {
      el = preferActElement(pool[i].el);
      if (elSeen.has(el)) continue;
      elSeen.add(el);
      pool[i].el = el;
      deduped.push(pool[i]);
    }
    pool = deduped;
    var root = null;
    if (window.__NIUMA_LABEL_DEBUG__) {
      root = document.createElement('div');
      root.id = 'niuma-mobile-label-root';
      root.style.cssText = 'position:fixed;left:0;top:0;width:100%;height:100%;pointer-events:none;z-index:2147483646;';
      (document.body || document.documentElement).appendChild(root);
    }
    var items = [];
    var id, iconHint, txt;
    for (i = 0; i < pool.length; i++) {
      id = i + 1;
      el = preferActElement(pool[i].el);
      pool[i].el = el;
      r = pool[i].rect;
      pos = pool[i].pos;
      el.setAttribute('data-niuma-label-id', String(id));
      el.classList.add('niuma-label-target');
      el.style.setProperty('outline', '2px solid #22c55e', 'important');
      el.style.setProperty('outline-offset', '1px', 'important');
      if (root) drawBadge(root, el, id, r, pos);
      iconHint = iconHintForLabelTarget(el);
      txt = extractText(el, id, iconHint);
      var tagLower = (el.tagName || '').toLowerCase();
      var inputVal = '';
      if (tagLower === 'input' || tagLower === 'textarea') {
        try {
          inputVal = trimT(String(el.value || ''));
        } catch (ev) {}
      }
      items.push({
        id: id,
        tag: tagLower,
        type: (el.getAttribute('type') || '').toLowerCase(),
        text: txt,
        value: inputVal.slice(0, 120),
        role: (el.getAttribute('role') || '').toLowerCase(),
        fixed: pos === 'fixed' || pos === 'sticky',
        hint: hintOf(el),
        hasOutline: true
      });
    }
    return JSON.stringify({
      ok: true,
      items: items,
      truncated: truncated,
      totalCandidates: totalCandidates
    });
  } catch (err) {
    return JSON.stringify({ ok: false, error: String(err && err.message || err), items: [] });
  }
})();
