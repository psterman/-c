(function () {
  'use strict';

  function getSettleParams() {
    var host = '';
    try { host = (window.__NIUMA_SETTLE_HOST__ || location.hostname || '').toLowerCase(); } catch (_) {}
    var defaults = { networkQuietMs: 350, domQuietMs: 900, maxMs: 9000, pollMs: 60 };
    if (/\.(twitter|x)\./.test(host)) return { networkQuietMs: 450, domQuietMs: 1500, maxMs: 12000, pollMs: 60 };
    if (/\.(facebook|instagram|threads)\./.test(host)) return { networkQuietMs: 400, domQuietMs: 1400, maxMs: 11000, pollMs: 60 };
    if (/\.(youtube|tiktok|bilibili)\./.test(host)) return { networkQuietMs: 400, domQuietMs: 1200, maxMs: 10000, pollMs: 60 };
    if (/\.(github|stackoverflow|reddit)\./.test(host)) return { networkQuietMs: 350, domQuietMs: 1000, maxMs: 9000, pollMs: 60 };
    if (/\.(taobao|tmall|jd|pdd)\./.test(host)) return { networkQuietMs: 350, domQuietMs: 1100, maxMs: 10000, pollMs: 60 };
    return defaults;
  }

  var params = getSettleParams();
  var networkQuietMs = params.networkQuietMs;
  var domQuietMs = params.domQuietMs;
  var maxMs = params.maxMs;
  var pollMs = params.pollMs;

  function installNetHooks() {
    if (window.__NIUMA_ACTIVE_REQUESTS__ !== undefined) return;
    window.__NIUMA_ACTIVE_REQUESTS__ = 0;
    var ofetch = window.fetch;
    if (typeof ofetch === 'function') {
      window.fetch = function () {
        window.__NIUMA_ACTIVE_REQUESTS__++;
        try {
          return ofetch.apply(this, arguments).finally(function () {
            window.__NIUMA_ACTIVE_REQUESTS__ = Math.max(0, window.__NIUMA_ACTIVE_REQUESTS__ - 1);
          });
        } catch (e) {
          window.__NIUMA_ACTIVE_REQUESTS__ = Math.max(0, window.__NIUMA_ACTIVE_REQUESTS__ - 1);
          throw e;
        }
      };
    }
    var xSend = XMLHttpRequest.prototype.send;
    XMLHttpRequest.prototype.send = function () {
      window.__NIUMA_ACTIVE_REQUESTS__++;
      var done = function () {
        window.__NIUMA_ACTIVE_REQUESTS__ = Math.max(0, window.__NIUMA_ACTIVE_REQUESTS__ - 1);
      };
      this.addEventListener('loadend', done, { once: true });
      this.addEventListener('error', done, { once: true });
      this.addEventListener('abort', done, { once: true });
      return xSend.apply(this, arguments);
    };
  }

  installNetHooks();

  window.__NIUMA_START_SETTLE_FLOW__ = function (reqId) {
    var lastMutation = Date.now();
    var networkIdleStart = 0;
    var start = Date.now();
    var observer = null;
    var timer = 0;
    var done = false;

    function finish(source) {
      if (done) return;
      done = true;
      if (timer) clearInterval(timer);
      try {
        if (observer) observer.disconnect();
      } catch (_) {}
      try {
        window.chrome.webview.postMessage({
          type: 'niuma_settle_done',
          reqId: reqId,
          source: source || 'sensor'
        });
      } catch (_) {}
    }

    try {
      observer = new MutationObserver(function () {
        lastMutation = Date.now();
      });
      observer.observe(document.body || document.documentElement, {
        childList: true,
        subtree: true,
        attributes: true
      });
    } catch (_) {}

    timer = setInterval(function () {
      var now = Date.now();
      if (now - start > maxMs) {
        finish('timeout');
        return;
      }
      if (window.__NIUMA_ACTIVE_REQUESTS__ <= 0) {
        if (!networkIdleStart) networkIdleStart = now;
      } else {
        networkIdleStart = 0;
      }
      var netOk = networkIdleStart && now - networkIdleStart >= networkQuietMs;
      var domOk = now - lastMutation >= domQuietMs;
      if (netOk && domOk) finish('settled');
    }, pollMs);
  };
})();
