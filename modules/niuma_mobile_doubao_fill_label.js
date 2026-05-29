(function () {
  try {
    var hintId = parseInt(__NIUMA_ID__, 10) || 0;
    var value = String(__NIUMA_TEXT__ || '').trim();
    if (!value) return JSON.stringify({ ok: false, error: 'empty_text', inputOk: false, sendOk: false });

    function vis(n) {
      if (!n || n.nodeType !== 1) return false;
      try {
        var st = window.getComputedStyle(n);
        if (!st || st.display === 'none' || st.visibility === 'hidden' || st.pointerEvents === 'none') return false;
        var r = n.getBoundingClientRect();
        return r.width >= 4 && r.height >= 4;
      } catch (e) {
        return false;
      }
    }

    function textOk(exp, got) {
      if (!exp || !got) return false;
      if (got.indexOf(exp) >= 0) return true;
      return exp.length >= 4 && got.indexOf(exp.slice(0, 4)) >= 0;
    }

    function readNode(n) {
      if (!n) return '';
      var tag = (n.tagName || '').toLowerCase();
      if (tag === 'textarea' || tag === 'input') return String(n.value || '').trim();
      var parts = [];
      var subs, i, t;
      try {
        subs = n.querySelectorAll('[data-slate-string="true"],[data-lexical-text="true"],p,span');
        for (i = 0; i < subs.length; i++) {
          t = String(subs[i].innerText || subs[i].textContent || '').trim();
          if (t && !/^发消息/.test(t)) parts.push(t);
        }
      } catch (eS) {}
      if (parts.length) return parts.join('');
      var raw = String(n.innerText || n.textContent || '').trim();
      if (/^发消息/.test(raw)) return '';
      return raw;
    }

    function fireInput(n, data) {
      try {
        n.dispatchEvent(
          new InputEvent('input', { bubbles: true, cancelable: true, inputType: 'insertText', data: data || value })
        );
      } catch (e1) {
        try {
          n.dispatchEvent(new Event('input', { bubbles: true }));
        } catch (e2) {}
      }
    }

    function setNativeValue(el, text) {
      var tag = (el.tagName || '').toLowerCase();
      if (tag === 'textarea' || tag === 'input') {
        try {
          var proto = tag === 'textarea' ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
          var desc = Object.getOwnPropertyDescriptor(proto, 'value');
          if (desc && desc.set) desc.set.call(el, text);
          else el.value = text;
        } catch (eV) {
          el.value = text;
        }
        fireInput(el, text);
        return readNode(el);
      }
      if (el.isContentEditable) {
        try {
          el.focus && el.focus();
          document.execCommand && document.execCommand('selectAll', false, null);
          document.execCommand && document.execCommand('insertText', false, text);
          fireInput(el, text);
        } catch (eC) {
          el.textContent = text;
          fireInput(el, text);
        }
        return readNode(el);
      }
      return '';
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
      return ta;
    }

    function findDoubaoEditor() {
      if (hintId > 0) {
        try {
          var hint = document.querySelector('[data-niuma-label-id="' + hintId + '"]');
          if (hint) {
            var tag = (hint.tagName || '').toLowerCase();
            if (tag === 'textarea') return resolveFromTextarea(hint);
            if (hint.isContentEditable || tag === 'input') return hint;
          }
        } catch (e0) {}
      }
      var nodes = document.querySelectorAll(
        'textarea[placeholder*="发消息"],textarea[placeholder*="DeepSeek"],textarea[placeholder*="发送消息"],[aria-placeholder*="发消息"],[aria-placeholder*="DeepSeek"],[data-slate-editor="true"],[contenteditable="true"],[contenteditable=""]'
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

    function dispatchEnter(target) {
      var keys = ['keydown', 'keypress', 'keyup'];
      var i, ev;
      for (i = 0; i < keys.length; i++) {
        try {
          (target || document).dispatchEvent(
            new KeyboardEvent(keys[i], {
              key: 'Enter',
              code: 'Enter',
              keyCode: 13,
              which: 13,
              bubbles: true,
              cancelable: true
            })
          );
        } catch (eK) {}
      }
    }

    var editor = findDoubaoEditor();
    if (!editor) return JSON.stringify({ ok: false, error: 'editor_not_found', inputOk: false, sendOk: false });

    try {
      editor.scrollIntoView({ block: 'center', inline: 'nearest' });
      editor.click && editor.click();
      editor.focus && editor.focus();
    } catch (eF) {}

    var methods = ['label_fill'];
    var got = '';
    if (window.__NIUMA_REACT_INPUT__ && window.__NIUMA_REACT_INPUT__.fillElement) {
      try {
        var ri = window.__NIUMA_REACT_INPUT__.fillElement(editor, value);
        if (ri && ri.methods) methods = methods.concat(ri.methods);
        got = (ri && ri.editorText) || readNode(editor) || got;
      } catch (eR) {}
    }
    if (!textOk(value, got)) {
      got = setNativeValue(editor, value) || got;
    }

    var inputOk = textOk(value, got);
    var sendOk = false;
    var sendClicked = false;
    if (inputOk) {
      dispatchEnter(editor);
      methods.push('enter_key');
      sendClicked = true;
      sendOk = readNode(editor).length < got.length * 0.45;
    }

    return JSON.stringify({
      ok: inputOk,
      inputOk: inputOk,
      sendOk: sendOk,
      sendClicked: sendClicked,
      chatSubmit: true,
      methods: methods.join(','),
      editorText: (got || readNode(editor)).slice(0, 120),
      editorTag: (editor.tagName || '').toLowerCase(),
      error: inputOk ? (sendOk || sendClicked ? '' : 'send_not_confirmed') : 'input_not_verified'
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
