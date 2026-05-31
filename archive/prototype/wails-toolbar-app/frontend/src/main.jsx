import "./style.css";

const state = {
  input: "",
  actions: [],
  selected: 0,
  dragging: false,
  dropTarget: "ocr",
  voiceStatus: "idle",
  voiceHint: "点击麦克风开始；识别中再按 CapsLock 结束",
};

let composing = false;
let shellReady = false;
let fetchTimer = null;
let statusTimer = null;
let sizeTimer = null;

const root = document.getElementById("root");
let dragCounter = 0;
let leaveTimer = null;

window.nmerVoice = {
  setInputText(text) {
    state.input = String(text || "");
    const input = document.getElementById("command-input");
    if (input) {
      input.value = state.input;
      input.focus();
      input.setSelectionRange(state.input.length, state.input.length);
    }
    scheduleFetchActions();
    updateResults();
    syncWindowSize();
  },
  setStatus(text, status = "ready") {
    state.voiceHint = String(text || "");
    state.voiceStatus = String(status || "idle");
    updateVoiceHint();
    syncWindowSize();
    if (status === "listening" || status === "loading") {
      startStatusPolling();
    } else {
      stopStatusPolling();
    }
  },
};

function esc(text) {
  return String(text)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function ensureShell() {
  if (shellReady) return;
  root.innerHTML = `
    <main class="toolbar-shell">
      <section class="raycast-palette" aria-label="命令栏">
        <header class="palette-header">
          <input
            id="command-input"
            class="palette-search"
            type="text"
            lang="zh-CN"
            autocomplete="off"
            spellcheck="false"
            placeholder="搜索命令…"
          />
          <button type="button" id="voice-btn" class="palette-voice" title="语音输入（Whisper）" aria-label="语音输入">🎤</button>
        </header>
        <p id="voice-hint" class="palette-status"></p>
        <div id="results" class="palette-results"></div>
      </section>
    </main>
  `;
  shellReady = true;
  bindUIOnce();
  updateVoiceHint();
  if (window.NMER_USE_NATIVE_INPUT) {
    document.body.classList.add("native-input-mode");
  }
}

function updateVoiceHint() {
  const el = document.getElementById("voice-hint");
  if (!el) return;
  const show = state.voiceStatus !== "idle";
  el.className = `palette-status ${show ? "show" : ""} ${esc(state.voiceStatus)}`;
  el.textContent = show ? (state.voiceHint || "") : "";
  const btn = document.getElementById("voice-btn");
  if (btn) {
    const rec = state.voiceStatus === "listening" || state.voiceStatus === "recording";
    btn.classList.toggle("recording", rec);
    btn.title = rec ? "正在录音，点击或按 CapsLock 结束" : "语音输入（Whisper）";
  }
}

function updateResults() {
  const box = document.getElementById("results");
  if (!box) return;
  const hasInput = state.input.trim().length > 0;
  const rows = hasInput ? state.actions : [];
  box.className = `palette-results ${hasInput ? "show" : ""}`;
  const palette = document.querySelector(".raycast-palette");
  palette?.classList.toggle("expanded", hasInput && rows.length > 0);
  box.innerHTML = rows
    .map((item, idx) => {
      const active = idx === state.selected ? "active" : "";
      const matched = item.matched ? "matched" : "";
      return `
        <button class="result-item ${active} ${matched}" type="button" data-action-index="${idx}">
          <span class="result-title">${esc(item.label || "")}</span>
          <span class="result-desc">${esc(item.desc || "")}</span>
        </button>
      `;
    })
    .join("");

  box.querySelectorAll("[data-action-index]").forEach((node) => {
    node.addEventListener("click", async (e) => {
      const idx = Number(e.currentTarget?.dataset?.actionIndex ?? -1);
      if (idx >= 0 && idx < state.actions.length) {
        state.selected = idx;
        await executeSelected();
      }
    });
  });
}

function scheduleFetchActions() {
  if (composing) return;
  if (fetchTimer) clearTimeout(fetchTimer);
  fetchTimer = setTimeout(fetchActions, 120);
}

async function fetchActions() {
  if (composing) return;
  try {
    const remote = await window?.go?.main?.App?.GetQuickActions?.(state.input);
    if (Array.isArray(remote)) {
      state.actions = remote;
      if (state.selected >= state.actions.length) {
        state.selected = Math.max(0, state.actions.length - 1);
      }
      updateResults();
      syncWindowSize();
    }
  } catch (_) {}
}

async function executeSelected() {
  const item = state.actions[state.selected];
  if (!item) return;
  try {
    await window?.go?.main?.App?.ExecuteAction?.(item.id, state.input);
  } catch (_) {}
}

async function refreshVoiceStatus() {
  try {
    const st = await window?.go?.main?.App?.GetVoiceStatus?.();
    if (st && typeof st === "object") {
      window.nmerVoice.setStatus(st.message || st.Message, st.status || st.Status || "idle");
    }
  } catch (_) {}
}

function startStatusPolling() {
  stopStatusPolling();
  statusTimer = setInterval(refreshVoiceStatus, 400);
}

function stopStatusPolling() {
  if (statusTimer) {
    clearInterval(statusTimer);
    statusTimer = null;
  }
}

async function onVoiceClick() {
  try {
    await window?.go?.main?.App?.ToggleVoiceInput?.();
    await refreshVoiceStatus();
    startStatusPolling();
  } catch (_) {
    window.nmerVoice.setStatus("无法连接语音服务，请确认牛马脚本已运行", "error");
  }
}

function bindUIOnce() {
  const input = document.getElementById("command-input");
  const voiceBtn = document.getElementById("voice-btn");
  if (!input) return;

  input.value = state.input;
  input.focus();
  input.setSelectionRange(input.value.length, input.value.length);

  const notifyImeReady = () => {
    try {
      window?.go?.main?.App?.SetInputImeReady?.();
    } catch (_) {}
  };

  input.addEventListener("focus", notifyImeReady);
  input.addEventListener("compositionstart", () => {
    composing = true;
    notifyImeReady();
  });
  input.addEventListener("compositionend", (e) => {
    composing = false;
    state.input = e.target.value;
    state.selected = 0;
    scheduleFetchActions();
  });
  input.addEventListener("input", (e) => {
    state.input = e.target.value;
    state.selected = 0;
    scheduleFetchActions();
  });

  input.addEventListener("keydown", async (e) => {
    if (composing) return;
    if (e.key === "ArrowDown") {
      e.preventDefault();
      if (state.actions.length) {
        state.selected = (state.selected + 1) % state.actions.length;
        updateResults();
      }
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      if (state.actions.length) {
        state.selected = (state.selected - 1 + state.actions.length) % state.actions.length;
        updateResults();
      }
    } else if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      await executeSelected();
    } else if (e.key === "Escape") {
      e.preventDefault();
      try {
        await window?.go?.main?.App?.MinimizeWindow?.();
      } catch (_) {}
    }
  });

  voiceBtn?.addEventListener("click", onVoiceClick);
}

function measureContentHeight() {
  const palette = document.querySelector(".raycast-palette");
  if (!palette) return 76;
  let h = 10; /* toolbar-shell 透明边距（仅留阴影空间） */
  const header = palette.querySelector(".palette-header");
  h += header?.offsetHeight || 52;
  const status = document.getElementById("voice-hint");
  if (status?.classList.contains("show")) {
    h += status.offsetHeight || 24;
  }
  const results = document.getElementById("results");
  if (results?.classList.contains("show")) {
    const rows = Math.min(state.actions.length, 8);
    h += rows * 44 + 14;
  }
  return Math.min(480, Math.max(76, Math.ceil(h)));
}

async function syncWindowSize() {
  if (composing) return;
  if (sizeTimer) clearTimeout(sizeTimer);
  sizeTimer = setTimeout(async () => {
    if (composing) return;
    const height = measureContentHeight();
    try {
      await window?.go?.main?.App?.SetWindowContentHeight?.(height);
      return;
    } catch (_) {}
    try {
      const expanded = state.input.trim().length > 0;
      const itemCount = expanded ? state.actions.length : 0;
      const voiceExtra = state.voiceStatus !== "idle" ? 1 : 0;
      await window?.go?.main?.App?.SetPaletteExpanded?.(expanded, itemCount, voiceExtra);
    } catch (_) {}
  }, 60);
}

function clearLeaveTimer() {
  if (leaveTimer) {
    clearTimeout(leaveTimer);
    leaveTimer = null;
  }
}

window.addEventListener("dragenter", (e) => {
  e.preventDefault();
  dragCounter += 1;
  clearLeaveTimer();
  if (!state.dragging) {
    state.dragging = true;
    syncWindowSize();
  }
});

window.addEventListener("dragover", (e) => {
  e.preventDefault();
  clearLeaveTimer();
});

window.addEventListener("dragleave", (e) => {
  e.preventDefault();
  dragCounter = Math.max(0, dragCounter - 1);
  if (dragCounter === 0) {
    leaveTimer = setTimeout(() => {
      if (dragCounter === 0) state.dragging = false;
    }, 90);
  }
});

window.addEventListener("drop", async (e) => {
  e.preventDefault();
  dragCounter = 0;
  clearLeaveTimer();
  state.dragging = false;
  const file = e.dataTransfer?.files?.[0];
  if (!file) return;
  try {
    await window?.go?.main?.App?.ProcessFile?.(file.path || file.name, state.dropTarget || "ocr");
  } catch (_) {}
});

window.NMER_USE_NATIVE_INPUT = false;

ensureShell();
fetchActions();
refreshVoiceStatus();
requestAnimationFrame(() => syncWindowSize());
