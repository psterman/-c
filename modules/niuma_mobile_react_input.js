(function () {
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

  function isEditableNode(n) {
    if (!n || n.nodeType !== 1) return false;
    var tag = (n.tagName || '').toLowerCase();
    return tag === 'textarea' || tag === 'input' || n.isContentEditable || n.getAttribute('role') === 'textbox';
  }

  function resolveEditable(root) {
    if (!root) return null;
    if (isEditableNode(root)) {
      var tag0 = (root.tagName || '').toLowerCase();
      if (tag0 === 'textarea' || tag0 === 'input') {
        var host0 = '';
        try {
          host0 = String((location.hostname || '')).toLowerCase();
        } catch (_) {}
        if (/doubao\.com|chat\.deepseek|kimi\.moonshot/i.test(host0)) {
          var p0 = root.parentElement;
          if (p0) {
            var ce0 = p0.querySelector(
              '[data-slate-editor="true"],[data-lexical-editor="true"],[contenteditable="true"],[contenteditable=""]'
            );
            if (ce0 && vis(ce0)) return ce0;
          }
          var sib0 = root.nextElementSibling;
          if (sib0 && isEditableNode(sib0) && vis(sib0)) return sib0;
        }
      }
      return root;
    }
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
        if (t && !/^发消息/.test(t)) chunks.push(t);
      }
    } catch (eS) {}
    if (chunks.length) return chunks.join('');
    var raw = String(node.innerText || node.textContent || '').trim();
    if (/^发消息/.test(raw)) return '';
    return raw;
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

  function fireInput(node, data) {
    try {
      node.dispatchEvent(
        new InputEvent('input', {
          bubbles: true,
          cancelable: true,
          inputType: 'insertText',
          data: data || ''
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

  function reactCompliantInputControl(el, text) {
    var value = String(text || '');
    try {
      if (el.focus) el.focus({ preventScroll: true });
      else el.focus && el.focus();
    } catch (eF) {}
    var tag = (el.tagName || '').toLowerCase();
    var proto =
      tag === 'textarea'
        ? window.HTMLTextAreaElement && HTMLTextAreaElement.prototype
        : window.HTMLInputElement && HTMLInputElement.prototype;
    if (proto) {
      try {
        var desc = Object.getOwnPropertyDescriptor(proto, 'value');
        if (desc && desc.set) {
          desc.set.call(el, value);
        } else {
          el.value = value;
        }
      } catch (e2) {
        el.value = value;
      }
    } else {
      el.value = value;
    }
    fireInput(el, value);
    var got = String(el.value || '').trim();
    return { inputOk: textMatches(value, got), editorText: got, methods: ['nativeSetter'] };
  }

  function reactCompliantContentEditable(el, text) {
    var value = String(text || '').trim();
    var methods = [];
    try {
      if (el.focus) el.focus({ preventScroll: true });
      else el.focus && el.focus();
    } catch (eF) {}
    try {
      var sel = window.getSelection && window.getSelection();
      var range = document.createRange && document.createRange();
      if (sel && range) {
        range.selectNodeContents(el);
        sel.removeAllRanges();
        sel.addRange(range);
      }
    } catch (eR) {}

    function tryPaste() {
      try {
        var dt = new DataTransfer();
        dt.setData('text/plain', value);
        el.dispatchEvent(
          new ClipboardEvent('paste', { bubbles: true, cancelable: true, clipboardData: dt })
        );
        notifyEditorChanged(el, value);
        methods.push('paste');
        return textMatches(value, readEditorTextDeep(el).trim());
      } catch (eP) {
        return false;
      }
    }

    function tryExec() {
      try {
        if (document.execCommand) {
          document.execCommand('selectAll', false, null);
          document.execCommand('insertText', false, value);
          notifyEditorChanged(el, value);
          methods.push('exec');
          return textMatches(value, readEditorTextDeep(el).trim());
        }
      } catch (eE) {}
      return false;
    }

    function tryTypeChars() {
      var i, ch;
      for (i = 0; i < value.length; i++) {
        ch = value.charAt(i);
        try {
          if (document.execCommand) document.execCommand('insertText', false, ch);
        } catch (eC) {}
        try {
          el.dispatchEvent(
            new InputEvent('beforeinput', {
              bubbles: true,
              cancelable: true,
              inputType: 'insertText',
              data: ch
            })
          );
          el.dispatchEvent(
            new InputEvent('input', { bubbles: true, cancelable: true, inputType: 'insertText', data: ch })
          );
        } catch (eK) {}
      }
      methods.push('type');
      return textMatches(value, readEditorTextDeep(el).trim());
    }

    var inputOk = false;
    if (tryPaste()) inputOk = true;
    else if (tryExec()) inputOk = true;
    else if (tryTypeChars()) inputOk = true;
    else {
      try {
        el.textContent = value;
        notifyEditorChanged(el, value);
        methods.push('textContent');
      } catch (e7) {
        try {
          el.innerText = value;
          notifyEditorChanged(el, value);
          methods.push('innerText');
        } catch (e8) {}
      }
      inputOk = textMatches(value, readEditorTextDeep(el).trim());
    }
    return {
      inputOk: inputOk,
      editorText: readEditorTextDeep(el).trim(),
      methods: methods
    };
  }

  function fillElement(el, text) {
    if (!el || !vis(el)) {
      return { ok: false, inputOk: false, error: 'element_not_visible', editorText: '', methods: [] };
    }
    var target = resolveEditable(el) || el;
    if (!target) {
      return { ok: false, inputOk: false, error: 'not_editable', editorText: '', methods: [] };
    }
    var tag = (target.tagName || '').toLowerCase();
    var res;
    if (tag === 'input' || tag === 'textarea') {
      res = reactCompliantInputControl(target, text);
    } else if (target.isContentEditable || target.getAttribute('role') === 'textbox') {
      res = reactCompliantContentEditable(target, text);
    } else {
      return { ok: false, inputOk: false, error: 'not_input', editorText: '', methods: [] };
    }
    return {
      ok: !!res.inputOk,
      inputOk: !!res.inputOk,
      editorText: String(res.editorText || '').slice(0, 120),
      methods: res.methods || [],
      error: res.inputOk ? '' : 'input_not_verified'
    };
  }

  function fillByLabelId(id, text) {
    var hintId = parseInt(id, 10) || 0;
    var el = null;
    if (hintId > 0) {
      try {
        el = document.querySelector('[data-niuma-label-id="' + hintId + '"]');
      } catch (e1) {
        el = null;
      }
    }
    if (!el) {
      return { ok: false, inputOk: false, error: 'element_not_found', editorText: '', methods: [] };
    }
    return fillElement(el, text);
  }

  window.__NIUMA_REACT_INPUT__ = {
    vis: vis,
    resolveEditable: resolveEditable,
    readEditorTextDeep: readEditorTextDeep,
    textMatches: textMatches,
    reactCompliantInputControl: reactCompliantInputControl,
    reactCompliantContentEditable: reactCompliantContentEditable,
    fillElement: fillElement,
    fillByLabelId: fillByLabelId
  };
})();
