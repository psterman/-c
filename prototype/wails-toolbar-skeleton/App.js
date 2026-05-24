const QUICK_ACTIONS = [
  { id: "ocr", label: "文字识别", keywords: ["ocr", "识别", "提取"] },
  { id: "summarize", label: "归类总结", keywords: ["总结", "归类", "摘要"] },
  { id: "ask-ai", label: "发送给AI", keywords: ["ai", "问", "提问"] },
  { id: "translate", label: "翻译", keywords: ["翻译", "translate", "译"] },
  { id: "search", label: "快速搜索", keywords: ["搜索", "search", "查找"] },
  { id: "script", label: "生成脚本", keywords: ["脚本", "代码", "生成"] },
];

const state = {
  input: "",
  isDragActive: false,
  selectedDrop: "",
  isInputFocused: false,
  voiceStatus: "idle",
  voiceHint: "",
};

window.nmerVoice = {
  setInputText(text) {
    state.input = String(text || "");
    render();
    const input = document.getElementById("command-input");
    if (input) {
      input.focus();
      input.setSelectionRange(state.input.length, state.input.length);
    }
  },
  setStatus(text, status = "ready") {
    state.voiceHint = String(text || "");
    state.voiceStatus = String(status || "ready");
    render();
  },
};

let dragCounter = 0;
let dragLeaveTimer = null;
let isBound = false;

function getQuickActions(input) {
  const text = input.trim().toLowerCase();
  if (!text) return QUICK_ACTIONS.slice(0, 4).map(a => ({ ...a, matched: false }));

  const ranked = QUICK_ACTIONS
    .map((action) => {
      const source = [action.label, ...action.keywords].join(" ").toLowerCase();
      const matched = source.includes(text);
      return { ...action, matched, score: matched ? 2 : 0 };
    })
    .filter((a) => a.matched)
    .sort((a, b) => b.score - a.score);

  return ranked.length ? ranked.slice(0, 8) : QUICK_ACTIONS.slice(0, 4).map(a => ({ ...a, matched: false }));
}

function render() {
  const app = document.getElementById("app");
  const actions = getQuickActions(state.input);
  const hasInput = state.input.trim().length > 0;

  app.innerHTML = `
    <section class="panel ${state.isDragActive ? "drag-active" : ""} ${state.isInputFocused ? "input-focused" : ""}">
      <label class="title">NMER COMMAND BAR</label>
      <div class="input-wrap">
        <input id="command-input" type="text" placeholder="输入命令，例如 OCR / 总结 / AI" value="${escapeHTML(state.input)}" />
      </div>

      <div class="actions ${hasInput ? "show" : ""}">
        ${actions
          .map(
            (a) => `<button class="action-btn ${a.matched ? "matched" : ""}" data-action="${a.id}">${a.label}</button>`
          )
          .join("")}
      </div>

      <div class="drop-zone ${state.isDragActive ? "expanded" : ""}">
        <button class="drop-card ${state.selectedDrop === "summarize" ? "selected" : ""}" data-drop="summarize">
          <span>左侧</span><strong>归类总结</strong>
        </button>
        <button class="drop-card ${state.selectedDrop === "ocr" ? "selected" : ""}" data-drop="ocr">
          <span>中间</span><strong>文字识别</strong>
        </button>
        <button class="drop-card ${state.selectedDrop === "ask-ai" ? "selected" : ""}" data-drop="ask-ai">
          <span>右侧</span><strong>发送给 AI 询问</strong>
        </button>
      </div>

      <p class="hint voice-hint ${state.voiceStatus !== "idle" ? "show" : ""}">${escapeHTML(state.voiceHint || "双击 CapsLock 打开；录音中再按 CapsLock 或再次双击结束识别")}</p>
      <p class="hint">拖拽文件到窗口可展开投递区（当前为前端演示）</p>
    </section>
  `;

  bindEvents();
}

function bindEvents() {
  const input = document.getElementById("command-input");
  input?.addEventListener("input", (e) => {
    state.input = e.target.value;
    render();
  });
  input?.addEventListener("focus", () => {
    state.isInputFocused = true;
    render();
  });
  input?.addEventListener("blur", () => {
    state.isInputFocused = false;
    render();
  });

  document.querySelectorAll("[data-drop]").forEach((el) => {
    el.addEventListener("click", () => {
      state.selectedDrop = el.getAttribute("data-drop") || "";
      render();
    });
  });

  if (!isBound) {
    window.addEventListener("dragenter", onDragEnter);
    window.addEventListener("dragover", onDragOver);
    window.addEventListener("dragleave", onDragLeave);
    window.addEventListener("drop", onDrop);
    isBound = true;
  }
}

function onDragEnter(e) {
  e.preventDefault();
  dragCounter += 1;
  clearDragLeaveTimer();
  if (!state.isDragActive) {
    state.isDragActive = true;
    render();
  }
}

function onDragOver(e) {
  e.preventDefault();
  clearDragLeaveTimer();
  if (!state.isDragActive) {
    state.isDragActive = true;
    render();
  }
}

function onDragLeave(e) {
  e.preventDefault();
  dragCounter = Math.max(0, dragCounter - 1);
  if (dragCounter === 0) {
    // Short delay prevents flicker when cursor moves over child nodes.
    dragLeaveTimer = setTimeout(() => {
      if (dragCounter === 0) {
        state.isDragActive = false;
        render();
      }
    }, 90);
  }
}

function onDrop(e) {
  e.preventDefault();
  dragCounter = 0;
  clearDragLeaveTimer();
  state.isDragActive = false;
  const fileName = e.dataTransfer?.files?.[0]?.name;
  if (fileName) {
    state.input = `已接收: ${fileName}`;
  }
  render();
}

function clearDragLeaveTimer() {
  if (dragLeaveTimer) {
    clearTimeout(dragLeaveTimer);
    dragLeaveTimer = null;
  }
}

function escapeHTML(str) {
  return str
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

render();
