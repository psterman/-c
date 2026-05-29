(function () {
  'use strict';

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

  function findSentInChat(expected) {
    if (!expected) return false;
    var needle = expected.length >= 6 ? expected.slice(0, 6) : expected.length >= 4 ? expected.slice(0, 4) : expected;
    var roots = [];
    try {
      var main = document.querySelector(
        'main,[role="main"],[class*="chat-layout"],[class*="conversation"],[class*="chat-container"]'
      );
      if (main) roots.push(main);
    } catch (eM) {}
    if (!roots.length) roots.push(document.body);
    var ri, root, nodes, i, blob, el, rh, cls;
    for (ri = 0; ri < roots.length; ri++) {
      root = roots[ri];
      if (!root) continue;
      try {
        nodes = root.querySelectorAll(
          '[class*="message"],[class*="bubble"],[class*="chat-item"],[class*="user"],[data-testid*="message"],[role="article"],p,span,div'
        );
      } catch (eQ) {
        nodes = [];
      }
      for (i = 0; i < nodes.length; i++) {
        el = nodes[i];
        if (!el || !vis(el)) continue;
        cls = String(el.className || '') + ' ' + String(el.getAttribute('data-role') || '');
        rh = String(el.getAttribute('role') || '');
        blob = String(el.innerText || el.textContent || '').trim();
        if (!blob || blob.length < needle.length) continue;
        if (/^发消息|给\s*DeepSeek|使用快速模式|DeepThink|联网搜索/.test(blob) && blob.indexOf(needle) < 0) continue;
        if (/^豆包\s*新对话|AI\s*创作|手机版/.test(blob) && blob.indexOf(needle) < 0) continue;
        if (/assistant|ai-message|bot-message/i.test(cls) && blob.indexOf(needle) < 0) continue;
        if (blob.indexOf(needle) >= 0) return true;
        if (expected.length >= 8 && blob.indexOf(expected.slice(0, 8)) >= 0) return true;
      }
    }
    return false;
  }

  function isMessageAlreadySent(expectedText) {
    return findSentInChat(String(expectedText || '').trim());
  }

  window.__NIUMA_THREAD_CHECK__ = {
    findSentInChat: findSentInChat,
    isMessageAlreadySent: isMessageAlreadySent
  };

  try {
    var expected = String(__NIUMA_TEXT__ || '').trim();
    if (expected) {
      var already = isMessageAlreadySent(expected);
      return JSON.stringify({
        ok: true,
        alreadySent: already,
        sentInThread: already,
        matchedBy: already ? 'thread' : '',
        lastUserSnippet: ''
      });
    }
  } catch (err) {
    return JSON.stringify({
      ok: false,
      alreadySent: false,
      error: String((err && err.message) || err)
    });
  }
})();

