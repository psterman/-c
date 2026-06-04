/**
 * Command Palette 动作 Tab — 四标签协议流式解析器
 * PLAN | STATUS | QUESTION | REPLY — 禁止嵌套，Emergency Cut，replan 检测
 */
(function (root) {
  var TAGS = ["PLAN", "STATUS", "QUESTION", "REPLY"];
  var START_RE = /::(PLAN|STATUS|QUESTION|REPLY)_START::/g;
  var END_RE = /::(PLAN|STATUS|QUESTION|REPLY)_END::/g;

  function splitTitleBody(text, defaultTitle) {
    var raw = String(text || "").trim();
    if (!raw) return { title: defaultTitle || "", content: "" };
    var nl = raw.indexOf("\n");
    if (nl < 0) return { title: raw, content: "" };
    return {
      title: raw.slice(0, nl).trim() || defaultTitle || "",
      content: raw.slice(nl + 1).trim()
    };
  }

  function parsePlanSteps(body) {
    return String(body || "")
      .split("|")
      .map(function (s) {
        return s.replace(/^\s*步骤\s*\d+\s*[:：]\s*/i, "").trim();
      })
      .filter(Boolean);
  }

  function StreamTagParser(onBlockUpdate) {
    this.onBlockUpdate = typeof onBlockUpdate === "function" ? onBlockUpdate : function () {};
    this.openType = null;
    this.scanBuf = "";
    this.seq = 0;
    this.planCount = 0;
    this._debounceTimer = 0;
    this._lastOpenSeq = 0;
  }

  StreamTagParser.prototype.reset = function () {
    this.openType = null;
    this.scanBuf = "";
    this.seq = 0;
    this.planCount = 0;
    if (this._debounceTimer) {
      clearTimeout(this._debounceTimer);
      this._debounceTimer = 0;
    }
  };

  StreamTagParser.prototype._emit = function (type, closed, body, extra) {
    var tb = splitTitleBody(body, "");
    var block = {
      type: type,
      closed: !!closed,
      seq: this.seq,
      body: String(body || "").trim(),
      title: tb.title,
      content: tb.content,
      log: tb.content,
      parseWarn: extra && extra.parseWarn ? extra.parseWarn : "",
      forcedClose: !!(extra && extra.forcedClose),
      replan: false
    };
    if (type === "plan") {
      block.steps = parsePlanSteps(block.body);
      if (closed) {
        this.planCount += 1;
        block.replan = this.planCount > 1;
      }
    }
    if (type === "status") {
      block.title = tb.title || "[执行中]";
      block.log = tb.content || block.body;
    }
    this.onBlockUpdate(block);
  };

  StreamTagParser.prototype._emitPartial = function () {
    var self = this;
    if (!self.openType) return;
    var body = self.scanBuf;
    var seq = self._lastOpenSeq;
    if (self._debounceTimer) clearTimeout(self._debounceTimer);
    self._debounceTimer = setTimeout(function () {
      self._debounceTimer = 0;
      if (!self.openType || self._lastOpenSeq !== seq) return;
      self._emit(self.openType, false, body, null);
    }, 50);
  };

  StreamTagParser.prototype._forceCloseOpen = function (reason) {
    if (!this.openType) return;
    this._emit(this.openType, true, this.scanBuf, {
      parseWarn: reason || "nested_cut",
      forcedClose: true
    });
    this.openType = null;
    this.scanBuf = "";
  };

  StreamTagParser.prototype._findEarliest = function (re, buf) {
    re.lastIndex = 0;
    var m = re.exec(buf);
    if (!m) return null;
    return { tag: m[1], index: m.index, len: m[0].length };
  };

  StreamTagParser.prototype._processBuffer = function () {
    var guard = 0;
    while (this.scanBuf.length && guard++ < 64) {
      if (this.openType) {
        var endRe = new RegExp("::" + this.openType.toUpperCase() + "_END::");
        var em = endRe.exec(this.scanBuf);
        if (em) {
          var body = this.scanBuf.slice(0, em.index);
          this.scanBuf = this.scanBuf.slice(em.index + em[0].length);
          this._emit(this.openType, true, body, null);
          this.openType = null;
          continue;
        }
        var otherStart = this._findEarliest(START_RE, this.scanBuf);
        if (otherStart && otherStart.tag.toLowerCase() !== this.openType) {
          var emergencyBody = this.scanBuf.slice(0, otherStart.index);
          this.scanBuf = this.scanBuf.slice(otherStart.index);
          this._emit(this.openType, true, emergencyBody, {
            parseWarn: "nested_cut",
            forcedClose: true
          });
          this.openType = null;
          continue;
        }
        this._emitPartial();
        return;
      }

      var sm = this._findEarliest(START_RE, this.scanBuf);
      if (!sm) {
        var tail = this.scanBuf;
        this.scanBuf = "";
        if (tail.trim()) {
          this.seq++;
          this.onBlockUpdate({
            type: "orphan",
            closed: true,
            seq: this.seq,
            body: tail.trim(),
            title: "",
            content: tail.trim(),
            parseWarn: "orphan_text"
          });
        }
        return;
      }
      var before = this.scanBuf.slice(0, sm.index);
      if (before.trim()) {
        this.seq++;
        this.onBlockUpdate({
          type: "orphan",
          closed: true,
          seq: this.seq,
          body: before.trim(),
          title: "",
          content: before.trim(),
          parseWarn: "orphan_text"
        });
      }
      this.scanBuf = this.scanBuf.slice(sm.index + sm.len);
      this.openType = sm.tag.toLowerCase();
      this.seq++;
      this._lastOpenSeq = this.seq;
      continue;
    }
  };

  StreamTagParser.prototype.onChunk = function (textChunk) {
    this.scanBuf += String(textChunk || "");
    this._processBuffer();
  };

  StreamTagParser.prototype.flush = function () {
    if (this.openType) {
      this._forceCloseOpen("stream_end");
    }
    this._processBuffer();
  };

  root.StreamTagParser = StreamTagParser;
  root.parsePlanSteps = parsePlanSteps;
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
