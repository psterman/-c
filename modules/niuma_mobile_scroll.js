(function () {
  try {
    var id = __NIUMA_ID__;
    var direction = __NIUMA_DIRECTION__;
    if (!direction) direction = 'down';

    if (id > 0) {
      var el = document.querySelector('[data-niuma-label-id="' + id + '"]');
      if (!el) return JSON.stringify({ ok: false, error: 'element_not_found' });
      try {
        el.scrollIntoView({ block: 'center', inline: 'nearest', behavior: 'smooth' });
      } catch (e1) {
        try { el.scrollIntoView(true); } catch (e2) {}
      }
      return JSON.stringify({ ok: true, tag: (el.tagName || '').toLowerCase(), mode: 'element', elementId: id });
    }

    var behavior = 'smooth';
    var sy = window.scrollY || window.pageYOffset || document.documentElement.scrollTop || 0;
    if (direction === 'up') {
      window.scrollBy({ top: -Math.max(Math.round(window.innerHeight * 0.65), 200), left: 0, behavior: behavior });
    } else if (direction === 'down') {
      window.scrollBy({ top: Math.max(Math.round(window.innerHeight * 0.65), 200), left: 0, behavior: behavior });
    } else if (direction === 'top') {
      window.scrollTo({ top: 0, left: 0, behavior: behavior });
    } else if (direction === 'bottom') {
      var bh = Math.max(document.body ? document.body.scrollHeight : 0, document.documentElement ? document.documentElement.scrollHeight : 0);
      window.scrollTo({ top: bh, left: 0, behavior: behavior });
    } else {
      window.scrollBy({ top: Math.max(Math.round(window.innerHeight * 0.65), 200), left: 0, behavior: behavior });
    }
    return JSON.stringify({ ok: true, mode: direction, scrollY: window.scrollY || window.pageYOffset || document.documentElement.scrollTop || 0, prevScrollY: sy });
  } catch (err) {
    return JSON.stringify({ ok: false, error: String((err && err.message) || err) });
  }
})();
