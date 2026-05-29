(function () {
  try {
    var expected = String(__NIUMA_TEXT__ || '').trim();
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

    function inChatViewport(n) {
      if (!n) return false;
      var r = n.getBoundingClientRect();
      var vh = window.innerHeight || 800;
      if (r.bottom < vh * 0.2) return false;
      if (r.width < 8 || r.height < 8) return false;
      return true;
    }

    function pickRealDoubaoEditor(hint) {
      if (!hint) return null;
      var tag = (hint.tagName || '').toLowerCase();
      if (tag === 'textarea' || tag === 'input') {
        var p = hint.parentElement;
        if (p) {
          var slate = p.querySelector(
            '[data-slate-editor="true"],[data-lexical-editor="true"],[contenteditable="true"],[contenteditable=""]'
          );
          if (slate && vis(slate) && inChatViewport(slate)) return slate;
        }
        var n = hint.nextElementSibling;
        if (n && (n.isContentEditable || n.getAttribute('contenteditable') != null) && vis(n) && inChatViewport(n))
          return n;
      }
      if (hint.isContentEditable && inChatViewport(hint)) return hint;
      if (tag === 'textarea' && inChatViewport(hint)) return hint;
      return null;
    }

    function findEditor() {
      if (hintId > 0) {
        try {
          var hint = document.querySelector('[data-niuma-label-id="' + hintId + '"]');
          var edHint = pickRealDoubaoEditor(hint);
          if (edHint) return edHint;
        } catch (e1) {}
      }
      try {
        var ae = document.activeElement;
        if (ae && inChatViewport(ae) && (ae.isContentEditable || /textarea|input/i.test(ae.tagName || ''))) return ae;
      } catch (eA) {}

      var nodes = document.querySelectorAll(
        '[aria-placeholder*="发消息"],[aria-placeholder*="DeepSeek"],[data-placeholder*="发消息"],[data-placeholder*="DeepSeek"],[placeholder*="发消息"],[placeholder*="DeepSeek"],[placeholder*="发送消息"],' +
          '[data-slate-editor="true"],[data-lexical-editor="true"],[contenteditable="true"],[contenteditable=""],textarea,[role="textbox"]'
      );
      var best = null;
      var bestY = -1;
      var i, n, y, tag, r;
      for (i = 0; i < nodes.length; i++) {
        n = nodes[i];
        if (!vis(n) || !inChatViewport(n)) continue;
        tag = (n.tagName || '').toLowerCase();
        if (tag === 'textarea' || tag === 'input') {
          var p = n.parentElement;
          if (p) {
            var slate = p.querySelector('[data-slate-editor="true"],[data-lexical-editor="true"],[contenteditable="true"]');
            if (slate && vis(slate) && inChatViewport(slate)) n = slate;
          }
        }
        r = n.getBoundingClientRect();
        y = r.top;
        if (y > bestY) {
          bestY = y;
          best = n;
        }
      }
      return best;
    }

    function readText(node) {
      if (!node) return '';
      var tag = (node.tagName || '').toLowerCase();
      if (tag === 'input' || tag === 'textarea') {
        var v = String(node.value || '').trim();
        if (v && !/^发消息|^给\s*DeepSeek/.test(v)) return v;
      }
      var parts = [];
      var subs, j, t;
      try {
        subs = node.querySelectorAll('[data-slate-string="true"],[data-lexical-text="true"],p,span');
        for (j = 0; j < subs.length; j++) {
          t = String(subs[j].innerText || subs[j].textContent || '').trim();
          if (t && !/^发消息|^给\s*DeepSeek/.test(t) && !/^(豆包|新对话|AI 创作|云盘|手机版)$/.test(t)) parts.push(t);
        }
      } catch (eS) {}
      if (parts.length) return parts.join('');
      var raw = String(node.innerText || node.textContent || '').trim();
      if (/^发消息|^给\s*DeepSeek/.test(raw)) return '';
      if (/豆包\s*新对话|AI\s*创作|OpenClaw|插件推荐|手机版|DeepSeek\s*发送|使用快速模式/.test(raw) && raw.indexOf(expected) < 0) return '';
      return raw;
    }

    function readEditorScoped(editor) {
      if (hintId > 0) {
        try {
          var hint = document.querySelector('[data-niuma-label-id="' + hintId + '"]');
          var edHint = pickRealDoubaoEditor(hint);
          if (edHint) {
            var hv = readText(edHint).trim();
            if (hv) return hv;
          }
        } catch (eH) {}
      }
      if (!editor) return '';
      var main = readText(editor).trim();
      if (main) return main;
      try {
        var ae = document.activeElement;
        if (ae && (editor.contains(ae) || ae === editor)) {
          var aeTxt = readText(ae).trim();
          if (aeTxt) return aeTxt;
        }
      } catch (eA) {}
      return '';
    }

    function dispatchEnter(target) {
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
          (target || document).dispatchEvent(ev);
        } catch (eK) {}
      }
      try {
        (target || document).dispatchEvent(
          new KeyboardEvent('keydown', {
            key: 'Enter',
            code: 'Enter',
            keyCode: 13,
            which: 13,
            bubbles: true,
            cancelable: true,
            ctrlKey: true
          })
        );
      } catch (eC) {}
    }

    function textOk(exp, got) {
      if (!exp || !got) return false;
      if (/豆包\s*新对话|AI\s*创作|OpenClaw|插件推荐/.test(got) && got.indexOf(exp) < 0) return false;
      if (got.indexOf(exp) >= 0) return true;
      if (exp.length >= 4 && got.indexOf(exp.slice(0, 4)) >= 0) return true;
      return exp.length >= 6 && got.indexOf(exp.slice(0, 6)) >= 0;
    }

    function findSentInChat(exp) {
      if (window.__NIUMA_THREAD_CHECK__ && window.__NIUMA_THREAD_CHECK__.findSentInChat)
        return window.__NIUMA_THREAD_CHECK__.findSentInChat(exp);
      return false;
    }

    function scoreSend(btn, editor) {
      if (!btn || !vis(btn)) return -1;
      var blob =
        String(btn.getAttribute('aria-label') || '') +
        ' ' +
        String(btn.getAttribute('title') || '') +
        ' ' +
        String(btn.innerText || btn.textContent || '');
      if (/搜索|写作|更多|发现|语音|附件|添加|发消息/.test(blob)) return -1;
      var score = /发送|send|submit/i.test(blob) ? 80 : 0;
      var r = btn.getBoundingClientRect();
      if (r.left < window.innerWidth * 0.22) score -= 100;
      if (r.left > window.innerWidth * 0.6) score += 35;
      if (editor) {
        var er = editor.getBoundingClientRect();
        if (Math.abs(r.top - er.top) < 120) score += 25;
      }
      return score;
    }

    function clickNode(t) {
      try {
        t.click && t.click();
      } catch (e) {}
    }

    var editor = findEditor();
    if (!editor) return JSON.stringify({ ok: false, error: 'editor_not_found', inputOk: false, sendOk: false });
    var got = readEditorScoped(editor);
    var sentInThread = findSentInChat(expected);
    var inputOk = textOk(expected, got);
    var editorEmpty = got.length < 2;
    var sendOk = false;
    var sendClicked = false;
    if (sentInThread) {
      sendOk = true;
      inputOk = true;
    } else if (editorEmpty && !inputOk) {
      sendOk = findSentInChat(expected);
      if (sendOk) inputOk = true;
    }
    if (inputOk && !sendOk) {
      var best = null;
      var bestSc = 0;
      var btns = document.querySelectorAll('button,[role="button"]');
      var bi, btn, sc;
      for (bi = 0; bi < btns.length; bi++) {
        btn = btns[bi];
        sc = scoreSend(btn, editor);
        if (sc > bestSc) {
          bestSc = sc;
          best = btn;
        }
      }
      if (best && bestSc >= 30) {
        clickNode(best);
        sendClicked = true;
        sendOk = readEditorScoped(editor).length < got.length * 0.4;
      }
      if (!sendOk) {
        dispatchEnter(editor);
        sendClicked = true;
        sendOk = readEditorScoped(editor).length < got.length * 0.4;
      }
    }
    return JSON.stringify({
      ok: sendOk || inputOk,
      inputOk: inputOk,
      sendOk: sendOk,
      sentInThread: sentInThread,
      sendClicked: sendClicked,
      chatSubmit: true,
      methods: (sentInThread ? 'verify_thread,' : 'verify_scoped,') + (sendClicked ? 'enter_key' : ''),
      editorText: got.slice(0, 120),
      error: sendOk ? '' : inputOk ? (sendClicked ? '' : 'send_not_confirmed') : 'input_not_verified'
    });
  } catch (err) {
    return JSON.stringify({ ok: false, error: String((err && err.message) || err), inputOk: false, sendOk: false });
  }
})();
