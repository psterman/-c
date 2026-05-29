(function () {
  try {
    var id = __NIUMA_ID__;
    var txt = __NIUMA_TEXT__;
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

    function resolveEditable(root) {
      if (!root) return null;
      var tag = (root.tagName || '').toLowerCase();
      if (
        tag === 'input' ||
        tag === 'textarea' ||
        tag === 'select' ||
        root.isContentEditable
      )
        return root;
      var sel =
        'textarea[name="q"],input[name="q"],input[name="query"],' +
        'textarea[name="query"],input[type="search"],textarea[type="search"],' +
        '[role="searchbox"],[contenteditable="true"],[contenteditable=""],' +
        'textarea,input:not([type="hidden"]):not([type="submit"]):not([type="button"]):not([type="image"])';
      var nodes, i, n, best;
      try {
        nodes = root.querySelectorAll(sel);
      } catch (e0) {
        nodes = [];
      }
      for (i = 0; i < nodes.length; i++) {
        n = nodes[i];
        if (!vis(n)) continue;
        if (!best) best = n;
        var nt = (n.tagName || '').toLowerCase();
        var nm = String(n.getAttribute('name') || '').toLowerCase();
        if (nm === 'q' || nm === 'query' || n.getAttribute('role') === 'searchbox') return n;
        if (nt === 'textarea' || (nt === 'input' && (n.getAttribute('type') || 'text') === 'text'))
          best = n;
      }
      if (best) return best;
      var p = root.parentElement;
      var depth = 0;
      while (p && depth < 4) {
        try {
          nodes = p.querySelectorAll(sel);
        } catch (e1) {
          nodes = [];
        }
        for (i = 0; i < nodes.length; i++) {
          if (vis(nodes[i])) return nodes[i];
        }
        p = p.parentElement;
        depth++;
      }
      return root;
    }

    function setNativeValue(node, value) {
      var tag = (node.tagName || '').toLowerCase();
      var proto =
        tag === 'textarea'
          ? window.HTMLTextAreaElement && HTMLTextAreaElement.prototype
          : window.HTMLInputElement && HTMLInputElement.prototype;
      if (proto) {
        try {
          var desc = Object.getOwnPropertyDescriptor(proto, 'value');
          if (desc && desc.set) {
            desc.set.call(node, value);
            return;
          }
        } catch (e2) {}
      }
      node.value = value;
    }

    function fireInput(node, value) {
      try {
        node.dispatchEvent(
          new InputEvent('input', {
            bubbles: true,
            cancelable: true,
            inputType: 'insertText',
            data: value
          })
        );
      } catch (e3) {
        try {
          node.dispatchEvent(new Event('input', { bubbles: true }));
        } catch (e4) {}
      }
      try {
        node.dispatchEvent(new Event('change', { bubbles: true }));
      } catch (e5) {}
    }

    function setContentEditableText(node, value) {
      try {
        if (node.focus) node.focus({ preventScroll: true });
      } catch (eF) {
        try {
          node.focus && node.focus();
        } catch (eF2) {}
      }
      try {
        var sel = window.getSelection && window.getSelection();
        var range = document.createRange && document.createRange();
        if (sel && range) {
          range.selectNodeContents(node);
          sel.removeAllRanges();
          sel.addRange(range);
        }
      } catch (eR) {}
      try {
        if (document.execCommand) {
          document.execCommand('insertText', false, value);
          fireInput(node, value);
          return;
        }
      } catch (eExec) {}
      try {
        node.textContent = value;
      } catch (e14) {
        node.innerText = value;
      }
      fireInput(node, value);
    }

    function isChatHost() {
      try {
        var host = String((location.hostname || '')).toLowerCase();
        return /doubao\.com|chat\.deepseek|kimi\.moonshot|tongyi\.aliyun|yuanbao\.tencent|chatgpt\.com|claude\.ai/i.test(host);
      } catch (e) {
        return false;
      }
    }

    function deferChatSubmit(node) {
      setTimeout(function () {
        try {
          submitSearch(node);
        } catch (eKey) {}
      }, 160);
    }

    function isSearchField(node) {
      if (!node) return false;
      try {
        var host = String((location && location.hostname) || '').toLowerCase();
        if (/doubao\.com|chat\.deepseek|kimi\.moonshot|tongyi\.aliyun|yuanbao\.tencent|chatgpt\.com|claude\.ai/i.test(host))
          return false;
      } catch (_) {}
      var tag = (node.tagName || '').toLowerCase();
      var ty = String(node.getAttribute('type') || '').toLowerCase();
      var nm = String(node.getAttribute('name') || '').toLowerCase();
      var id = String(node.getAttribute('id') || '').toLowerCase();
      var cls = String(node.getAttribute('class') || '').toLowerCase();
      var role = String(node.getAttribute('role') || '').toLowerCase();
      var al = String(node.getAttribute('aria-label') || '').toLowerCase();
      var ph = String(node.getAttribute('placeholder') || '').toLowerCase();
      var t = String(node.textContent || '').toLowerCase();
      if (nm === 'q' || nm === 'query' || nm === 'wd' || nm === 'word' || ty === 'search' || role === 'searchbox')
        return true;
      if (id === 'kw' || id === 'index-kw' || /s_ipt|search.*input|input.*search|searchbox|index-kw|wd/.test(cls))
        return true;
      if (/search|搜索|query|百度|关键词|keyword|搜一下/i.test(al + ' ' + ph + ' ' + t))
        return true;
      try {
        var form = node.form || node.closest('form');
        var action = String((form && form.getAttribute && form.getAttribute('action')) || '').toLowerCase();
        if (/\/s(\?|$)|baidu|search/.test(action)) return true;
      } catch (_) {}
      try {
        var host = String((location && location.hostname) || '').toLowerCase();
        if (/\.baidu\./.test(host) && tag === 'input' && (nm === 'wd' || id === 'kw')) return true;
      } catch (_) {}
      return false;
    }

    /** 仅派发键盘事件；禁止 form.submit/requestSubmit（会同步导航，导致 WebView 脚本 job 永不回调） */
    function submitSearch(node) {
      var keys = ['keydown', 'keypress', 'keyup'];
      var i, ev;
      for (i = 0; i < keys.length; i++) {
        try {
          ev = new KeyboardEvent(keys[i], {
            key: 'Enter',
            code: 'Enter',
            keyCode: 13,
            which: 13,
            bubbles: true,
            cancelable: true
          });
          node.dispatchEvent(ev);
        } catch (e8) {}
      }
    }

    function deferSearchSubmit(node, query) {
      var q = String(query || '').trim();
      if (!q) return;
      setTimeout(function () {
        try {
          var host = (location.hostname || '').toLowerCase();
          var path = location.pathname || '';
          if (/\.google\./i.test(host) && path.indexOf('/search') < 0) {
            location.assign(
              'https://www.google.com/search?q=' + encodeURIComponent(q) + '&oq=' + encodeURIComponent(q)
            );
            return;
          }
          if (/\.baidu\./i.test(host) && path.indexOf('/s') !== 0) {
            location.assign('https://www.baidu.com/s?wd=' + encodeURIComponent(q));
            return;
          }
        } catch (eNav) {}
        try {
          submitSearch(node);
        } catch (eKey) {}
      }, 120);
    }

    try {
      el.scrollIntoView({ block: 'center', inline: 'nearest' });
    } catch (e9) {}
    if (!isChatHost()) window.__NIUMA_VP_THROTTLE__ = true;

    var target = resolveEditable(el);
    if (!target) return JSON.stringify({ ok: false, error: 'not_input' });

    var r = target.getBoundingClientRect();
    var cx = r.left + r.width / 2;
    var cy = r.top + r.height / 2;
    var o = { bubbles: true, cancelable: true, view: window, clientX: cx, clientY: cy };
    try {
      target.dispatchEvent(new MouseEvent('mousedown', o));
      target.dispatchEvent(new MouseEvent('mouseup', o));
      target.dispatchEvent(new MouseEvent('click', o));
    } catch (e10) {
      try {
        target.click && target.click();
      } catch (e11) {}
    }
    try {
      if (target.focus) target.focus({ preventScroll: true });
    } catch (e12) {
      try {
        target.focus && target.focus();
      } catch (e13) {}
    }

    var ttag = (target.tagName || '').toLowerCase();
    var qtxt = String(txt || '').trim();
    if (isChatHost() && qtxt && window.__NIUMA_REACT_INPUT__) {
      var riChat = window.__NIUMA_REACT_INPUT__.fillElement(target, qtxt);
      var gotReact = (riChat && riChat.editorText) || readTargetText(target).trim();
      var inputOkReact = !!(riChat && riChat.inputOk);
      deferChatSubmit(target);
      return JSON.stringify({
        ok: inputOkReact,
        inputOk: inputOkReact,
        submitted: false,
        deferred: true,
        chatSubmit: true,
        editorText: gotReact.slice(0, 120),
        methods: (riChat && riChat.methods ? riChat.methods.join(',') : 'react') || 'react',
        tag: ttag,
        error: inputOkReact ? '' : 'input_not_verified'
      });
    }
    if (ttag === 'input' || ttag === 'textarea' || ttag === 'select') {
      setNativeValue(target, txt);
      fireInput(target, txt);
    } else if (target.isContentEditable) {
      setContentEditableText(target, txt);
    } else {
      return JSON.stringify({ ok: false, error: 'not_input' });
    }

    var qtxt2 = String(txt || '').trim();
    function readTargetText(node) {
      if (!node) return '';
      var tg = (node.tagName || '').toLowerCase();
      if (tg === 'input' || tg === 'textarea') return String(node.value || '');
      return String(node.innerText || node.textContent || '');
    }
    function chatTextOk(expected, got) {
      var a = String(expected || '').trim();
      var b = String(got || '').trim();
      if (!a || !b) return false;
      if (b.indexOf(a) >= 0) return true;
      return a.length >= 4 && b.indexOf(a.slice(0, 4)) >= 0;
    }
    if (isChatHost() && qtxt2) {
      var gotTxt = readTargetText(target).trim();
      var inputOk = chatTextOk(qtxt2, gotTxt);
      deferChatSubmit(target);
      return JSON.stringify({
        ok: inputOk,
        inputOk: inputOk,
        submitted: false,
        deferred: true,
        chatSubmit: true,
        editorText: gotTxt.slice(0, 120),
        tag: ttag,
        error: inputOk ? '' : 'input_not_verified'
      });
    }
    if (isSearchField(target) && qtxt2) {
      deferSearchSubmit(target, qtxt2);
    }

    return JSON.stringify({
      ok: true,
      submitted: !!(isSearchField(target) && qtxt2),
      deferred: true,
      tag: ttag
    });
  } catch (err) {
    return JSON.stringify({ ok: false, error: String((err && err.message) || err) });
  }
})();
