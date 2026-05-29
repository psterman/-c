(function () {
  try {
    var hintId = __NIUMA_ID__;
    var txt = __NIUMA_TEXT__;
    var sendOnly = __NIUMA_SEND_ONLY__;
    var value = String(txt || '').trim();
    if (!sendOnly && !value) return JSON.stringify({ ok: false, error: 'empty_text' });

    function vis(n) {
      if (!n || n.nodeType !== 1) return false;
      try {
        var st = window.getComputedStyle(n);
        if (!st || st.display === 'none' || st.visibility === 'hidden' || st.opacity === '0') return false;
        var r = n.getBoundingClientRect();
        return r.width >= 2 && r.height >= 2;
      } catch (e) {
        return false;
      }
    }

    function clickNode(target) {
      if (!target) return;
      try {
        target.scrollIntoView({ block: 'center', inline: 'nearest' });
      } catch (e10) {}
      var r = target.getBoundingClientRect();
      var cx = r.left + r.width / 2;
      var cy = r.top + r.height / 2;
      var o = { bubbles: true, cancelable: true, view: window, clientX: cx, clientY: cy };
      try {
        target.dispatchEvent(
          new PointerEvent('pointerdown', Object.assign({}, o, { pointerId: 1, pointerType: 'touch', isPrimary: true }))
        );
      } catch (e11) {}
      try {
        target.dispatchEvent(new MouseEvent('mousedown', o));
        target.dispatchEvent(new MouseEvent('mouseup', o));
        target.dispatchEvent(new MouseEvent('click', o));
      } catch (e12) {
        try {
          target.click && target.click();
        } catch (e13) {}
      }
      try {
        target.dispatchEvent(
          new PointerEvent('pointerup', Object.assign({}, o, { pointerId: 1, pointerType: 'touch', isPrimary: true }))
        );
      } catch (e14) {}
    }

    function isEditableNode(n) {
      if (!n || n.nodeType !== 1) return false;
      var tag = (n.tagName || '').toLowerCase();
      return tag === 'textarea' || tag === 'input' || n.isContentEditable || n.getAttribute('role') === 'textbox';
    }

    function resolveEditable(root) {
      if (!root) return null;
      if (isEditableNode(root)) return root;
      var sel =
        '[contenteditable="true"],[contenteditable=""],textarea,[role="textbox"],' +
        'input:not([type="hidden"]):not([type="submit"]):not([type="button"])';
      var nodes, i, n, best, bestY;
      try {
        nodes = root.querySelectorAll(sel);
      } catch (e0) {
        nodes = [];
      }
      best = null;
      bestY = -1;
      for (i = 0; i < nodes.length; i++) {
        n = nodes[i];
        if (!vis(n)) continue;
        var ry = n.getBoundingClientRect().top;
        if (ry > bestY) {
          best = n;
          bestY = ry;
        }
      }
      return best;
    }

    function pickBottomEditor(nodes) {
      var best = null;
      var bestY = -1;
      var i, n, ry;
      for (i = 0; i < nodes.length; i++) {
        n = nodes[i];
        if (!vis(n)) continue;
        ry = n.getBoundingClientRect().top;
        if (ry > window.innerHeight * 0.35 && ry > bestY) {
          best = n;
          bestY = ry;
        }
      }
      return best;
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
          if (slate && vis(slate)) return slate;
        }
        var n = hint.nextElementSibling;
        if (n && (n.isContentEditable || n.getAttribute('contenteditable') != null) && vis(n)) return n;
      }
      return resolveEditable(hint) || hint;
    }

    function findEditor() {
      var hint = null;
      if (hintId > 0) {
        try {
          hint = document.querySelector('[data-niuma-label-id="' + hintId + '"]');
        } catch (e1) {
          hint = null;
        }
        if (hint) {
          clickNode(hint);
          var ed0 = pickRealDoubaoEditor(hint);
          if (ed0) return ed0;
        }
      }
      try {
        var ae = document.activeElement;
        if (ae && isEditableNode(ae) && vis(ae)) return ae;
      } catch (eA) {}

      var sels = [
        '[aria-placeholder*="发消息"]',
        '[aria-placeholder*="DeepSeek"]',
        '[aria-placeholder*="Gemini"]',
        '[aria-placeholder*="Ask Gemini"]',
        '[aria-placeholder*="问问 Gemini"]',
        '[data-placeholder*="发消息"]',
        '[data-placeholder*="DeepSeek"]',
        '[data-placeholder*="Gemini"]',
        '[placeholder*="发消息"]',
        '[placeholder*="DeepSeek"]',
        '[placeholder*="问 Gemini"]',
        '[placeholder*="Ask Gemini"]',
        '[placeholder*="发送消息"]',
        '[data-slate-editor="true"]',
        '[data-lexical-editor="true"]',
        '[contenteditable="true"]',
        '[contenteditable=""]',
        'textarea',
        '[role="textbox"]'
      ];
      var j, nodes2, picked;
      for (j = 0; j < sels.length; j++) {
        try {
          nodes2 = document.querySelectorAll(sels[j]);
        } catch (e2) {
          nodes2 = [];
        }
        picked = pickBottomEditor(nodes2);
        if (picked) {
          clickNode(picked);
          return picked;
        }
      }
      if (hint) {
        clickNode(hint);
        try {
          var ae2 = document.activeElement;
          if (ae2 && isEditableNode(ae2) && vis(ae2)) return ae2;
        } catch (eA2) {}
      }
      return null;
    }

    function readEditorTextDeep(node) {
      if (!node) return '';
      var tag = (node.tagName || '').toLowerCase();
      if (tag === 'input' || tag === 'textarea') return String(node.value || '');
      var chunks = [];
      var i, sub, t;
      try {
        sub = node.querySelectorAll(
          '[data-slate-string="true"],[data-lexical-text="true"],p,span,div[data-text="true"]'
        );
        for (i = 0; i < sub.length; i++) {
          t = String(sub[i].innerText || sub[i].textContent || '').trim();
          if (t && t !== '发消息...' && t.indexOf('发消息') !== 0) chunks.push(t);
        }
      } catch (eS) {}
      if (chunks.length) return chunks.join('');
      var raw = String(node.innerText || node.textContent || '').trim();
      if (raw === '发消息...' || raw === '发消息' || /^发消息[\.…]*$/.test(raw)) return '';
      return raw;
    }

    function fireInput(node, data) {
      try {
        node.dispatchEvent(
          new InputEvent('input', {
            bubbles: true,
            cancelable: true,
            inputType: 'insertText',
            data: data || value
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

    function notifyEditorChanged(node, text) {
      try {
        node.dispatchEvent(
          new InputEvent('beforeinput', {
            bubbles: true,
            cancelable: true,
            inputType: 'insertText',
            data: text
          })
        );
      } catch (eB) {}
      fireInput(node, text);
      try {
        node.dispatchEvent(new CompositionEvent('compositionend', { bubbles: true, data: text }));
      } catch (eC) {}
    }

    function pasteText(node, text) {
      try {
        if (node.focus) node.focus({ preventScroll: true });
        else node.focus && node.focus();
      } catch (eF) {}
      try {
        var dt = new DataTransfer();
        dt.setData('text/plain', text);
        var evt = new ClipboardEvent('paste', { bubbles: true, cancelable: true, clipboardData: dt });
        node.dispatchEvent(evt);
        notifyEditorChanged(node, text);
        return true;
      } catch (eP) {
        return false;
      }
    }

    function insertViaExec(node, text) {
      try {
        if (node.focus) node.focus({ preventScroll: true });
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
          document.execCommand('selectAll', false, null);
          document.execCommand('insertText', false, text);
          notifyEditorChanged(node, text);
          return true;
        }
      } catch (eExec) {}
      return false;
    }

    function typeChars(node, text) {
      try {
        if (node.focus) node.focus({ preventScroll: true });
      } catch (eF) {}
      var i, ch;
      for (i = 0; i < text.length; i++) {
        ch = text.charAt(i);
        try {
          if (document.execCommand) document.execCommand('insertText', false, ch);
        } catch (eC) {}
        try {
          node.dispatchEvent(
            new InputEvent('beforeinput', {
              bubbles: true,
              cancelable: true,
              inputType: 'insertText',
              data: ch
            })
          );
          node.dispatchEvent(
            new InputEvent('input', { bubbles: true, cancelable: true, inputType: 'insertText', data: ch })
          );
        } catch (eK) {}
      }
    }

    function tryFillEditor(editor, text) {
      var methods = [];
      if (window.__NIUMA_REACT_INPUT__ && window.__NIUMA_REACT_INPUT__.fillElement) {
        try {
          var ri = window.__NIUMA_REACT_INPUT__.fillElement(editor, text);
          if (ri && ri.inputOk) {
            return {
              got: ri.editorText || readEditorTextDeep(editor).trim(),
              methods: (ri.methods || []).concat(['react']),
              inputOk: true
            };
          }
          if (ri && ri.methods && ri.methods.length) methods = methods.concat(ri.methods);
        } catch (eR) {}
      }
      pasteText(editor, text);
      methods.push('paste');
      var got = readEditorTextDeep(editor).trim();
      if (textMatches(text, got)) return { got: got, methods: methods, inputOk: true };
      insertViaExec(editor, text);
      methods.push('exec');
      got = readEditorTextDeep(editor).trim();
      if (textMatches(text, got)) return { got: got, methods: methods, inputOk: true };
      typeChars(editor, text);
      methods.push('type');
      got = readEditorTextDeep(editor).trim();
      if (textMatches(text, got)) return { got: got, methods: methods, inputOk: true };
      try {
        editor.textContent = text;
        notifyEditorChanged(editor, text);
        methods.push('textContent');
      } catch (e7) {
        try {
          editor.innerText = text;
          notifyEditorChanged(editor, text);
          methods.push('innerText');
        } catch (e8) {}
      }
      got = readEditorTextDeep(editor).trim();
      return { got: got, methods: methods, inputOk: textMatches(text, got) };
    }

    function dismissAbnormalAttachments() {
      var removed = 0;
      try {
        var all = document.querySelectorAll('button,[role="button"],a,div,span');
        var i, n, tx, root, closeBtn, j;
        for (i = 0; i < all.length; i++) {
          n = all[i];
          tx = String(n.innerText || n.textContent || '').trim();
          if (!/异常文件|请删除|取到文字|ser\.in|无法读取/i.test(tx)) continue;
          root = n.closest('div,li,section,article') || n.parentElement;
          if (!root) continue;
          closeBtn = root.querySelector(
            'button[aria-label*="删"],button[aria-label*="关闭"],button[aria-label*="remove"],[class*="close"],[class*="delete"],svg'
          );
          if (closeBtn) {
            clickNode(closeBtn.closest('button,[role="button"]') || closeBtn);
            removed++;
            continue;
          }
          var btns = root.querySelectorAll('button,[role="button"]');
          for (j = 0; j < btns.length; j++) {
            if (!String(btns[j].innerText || btns[j].textContent || '').trim()) {
              clickNode(btns[j]);
              removed++;
              break;
            }
          }
        }
      } catch (eD) {}
      return removed;
    }

    function scoreSendBtn(btn, editor) {
      if (!btn || !vis(btn)) return -1;
      var tag = (btn.tagName || '').toLowerCase();
      if (tag !== 'button' && tag !== 'a' && btn.getAttribute('role') !== 'button') return -1;
      if (btn.disabled || btn.getAttribute('aria-disabled') === 'true') return -1;
      var aria = String(btn.getAttribute('aria-label') || '').toLowerCase();
      var title = String(btn.getAttribute('title') || '').toLowerCase();
      var dt = String(btn.getAttribute('data-testid') || '').toLowerCase();
      var cls = String(btn.getAttribute('class') || '').toLowerCase();
      var t = String(btn.innerText || btn.textContent || '').trim().toLowerCase();
      var blob = aria + ' ' + title + ' ' + dt + ' ' + cls + ' ' + t;
      if (/搜索|写作|更多|发现|语音|麦克风|mic|voice|附件|上传|添加|发消息|plus|attach|paperclip|clip|image|photo|gallery|compass|file|取到文字|异常/.test(blob))
        return -1;
      var score = 0;
      if (/发送|send|submit|提交|post message|post/i.test(blob)) score += 80;
      if (btn.querySelector && btn.querySelector('svg')) score += 15;
      var r = btn.getBoundingClientRect();
      if (r.left < window.innerWidth * 0.22) score -= 120;
      if (r.top > window.innerHeight * 0.45) score += 25;
      if (r.left > window.innerWidth * 0.72) score += 55;
      if (r.left > window.innerWidth * 0.62 && r.left <= window.innerWidth * 0.78) score += 25;
      if (editor) {
        var er = editor.getBoundingClientRect();
        if (Math.abs(r.top - er.top) < 120 && r.left >= er.left - 20) score += 30;
      }
      if (r.width >= 28 && r.width <= 96 && r.height >= 28 && r.height <= 96) score += 10;
      return score;
    }

    function findSendButton(editor) {
      var sels = [
        '[aria-label*="发送"]',
        '[aria-label*="send"]',
        '[aria-label*="Send"]',
        '[data-testid*="send"]',
        'button[aria-label*="Send message"]',
        'button[aria-label*="发送消息"]'
      ];
      var si, nodes, ni, btn, best, bestScore, sc;
      best = null;
      bestScore = 0;
      for (si = 0; si < sels.length; si++) {
        try {
          nodes = document.querySelectorAll(sels[si]);
        } catch (eS) {
          nodes = [];
        }
        for (ni = 0; ni < nodes.length; ni++) {
          btn = nodes[ni];
          sc = scoreSendBtn(btn, editor);
          if (sc > bestScore) {
            bestScore = sc;
            best = btn;
          }
        }
      }
      if (bestScore >= 25) return best;
      try {
        nodes = document.querySelectorAll('button,[role="button"]');
      } catch (e9) {
        nodes = [];
      }
      for (ni = 0; ni < nodes.length; ni++) {
        btn = nodes[ni];
        sc = scoreSendBtn(btn, editor);
        if (sc > bestScore) {
          bestScore = sc;
          best = btn;
        }
      }
      return bestScore >= 35 ? best : null;
    }

    function textMatches(expected, got) {
      var a = String(expected || '').trim();
      var b = String(got || '').trim();
      if (!a || !b) return false;
      if (b.indexOf(a) >= 0) return true;
      if (a.length >= 4 && b.indexOf(a.slice(0, 4)) >= 0) return true;
      if (a.length >= 6 && b.indexOf(a.slice(0, 6)) >= 0) return true;
      return b.length >= a.length * 0.45;
    }

    if (window.__NIUMA_REACT_INPUT__ && window.__NIUMA_REACT_INPUT__.fillByLabelId && hintId > 0) {
      try {
        var byId = window.__NIUMA_REACT_INPUT__.fillByLabelId(hintId, value);
        if (byId && byId.inputOk) {
          var edId = findEditor();
          var gotId = byId.editorText || readEditorTextDeep(edId || document.activeElement).trim();
          var sendBtnId = edId ? findSendButton(edId) : null;
          var sendOkId = false;
          var sendClickedId = false;
          if (sendBtnId) {
            clickNode(sendBtnId);
            sendClickedId = true;
            sendOkId = readEditorTextDeep(edId).trim().length < gotId.length * 0.35;
          }
          return JSON.stringify({
            ok: true,
            inputOk: true,
            sendOk: sendOkId,
            sendClicked: sendClickedId,
            chatSubmit: !!(sendOkId || sendClickedId),
            editorText: gotId.slice(0, 120),
            methods: (byId.methods || []).join(','),
            error: sendOkId || sendClickedId ? '' : 'send_button_not_found'
          });
        }
      } catch (eId) {}
    }

    dismissAbnormalAttachments();

    var editor = findEditor();
    if (!editor)
      return JSON.stringify({ ok: false, error: 'editor_not_found', inputOk: false, sendOk: false });

    if (sendOnly) {
      var sendBtnOnly = findSendButton(editor);
      if (!sendBtnOnly) {
        return JSON.stringify({
          ok: false,
          error: 'send_button_not_found',
          inputOk: true,
          sendOk: false,
          sendClicked: false,
          chatSubmit: false,
          methods: 'send_only'
        });
      }
      var gotBefore = readEditorTextDeep(editor).trim();
      clickNode(sendBtnOnly);
      var gotAfter = readEditorTextDeep(editor).trim();
      var sendOkOnly =
        gotAfter.length === 0 ||
        (gotBefore.length > 0 && gotAfter.length < gotBefore.length * 0.35);
      return JSON.stringify({
        ok: sendOkOnly,
        inputOk: true,
        sendOk: sendOkOnly,
        sendClicked: true,
        chatSubmit: !!sendOkOnly,
        editorText: gotAfter.slice(0, 120),
        methods: 'send_only',
        error: sendOkOnly ? '' : 'send_not_cleared'
      });
    }

    clickNode(editor);
    var fill = tryFillEditor(editor, value);
    var got = fill.got || '';
    var inputOk = !!fill.inputOk;

    var sendBtn = findSendButton(editor);
    dismissAbnormalAttachments();
    if (!sendBtn) sendBtn = findSendButton(editor);
    var sendOk = false;
    var sendClicked = false;
    if (sendBtn && inputOk) {
      var beforeSend = got;
      clickNode(sendBtn);
      sendClicked = true;
      var afterSend = readEditorTextDeep(editor).trim();
      sendOk =
        afterSend.length === 0 ||
        (beforeSend.length > 0 && afterSend.length < beforeSend.length * 0.35);
    } else if (inputOk) {
      try {
        var keys = ['keydown', 'keypress', 'keyup'];
        var ki, ev;
        for (ki = 0; ki < keys.length; ki++) {
          ev = new KeyboardEvent(keys[ki], {
            key: 'Enter',
            code: 'Enter',
            keyCode: 13,
            which: 13,
            bubbles: true,
            cancelable: true
          });
          editor.dispatchEvent(ev);
        }
      } catch (e15) {}
    }

    return JSON.stringify({
      ok: inputOk,
      inputOk: inputOk,
      sendOk: sendOk,
      sendClicked: sendClicked,
      chatSubmit: !!(sendOk || sendClicked),
      deferred: false,
      editorText: got.slice(0, 120),
      methods: (fill.methods || []).join(','),
      editorTag: (editor.tagName || '').toLowerCase(),
      error: inputOk ? (sendOk || sendClicked ? '' : 'send_button_not_found') : 'input_not_verified'
    });
  } catch (err) {
    return JSON.stringify({
      ok: false,
      error: String((err && err.message) || err),
      inputOk: false,
      sendOk: false
    });
  }
})();
