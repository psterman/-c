import "./style.css";

const state = {
  input: "",
  actions: [],
  selected: 0,
  dragging: false,
  dropTarget: "ocr",
  focused: false,
};

const root = document.getElementById("root");
let dragCounter = 0;
let leaveTimer = null;

function esc(text) {
  return String(text)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function render() {
  const hasInput = state.input.trim().length > 0;
  const rows = hasInput ? state.actions : [];
  const itemsHTML = rows
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

  root.innerHTML = `
    <main class="toolbar-shell">
      <div class="input-wrap compact only-input">
        <input id="command-input" type="text" value="${esc(state.input)}" placeholder="输入命令，↑↓ 选择，Enter 执行，Esc 收起" autocomplete="off" />
      </div>
      <div class="results ${hasInput ? "show" : ""}">
        ${itemsHTML}
      </div>
    </main>
  `;

  bindUI();
  syncWindowSize();
}

async function fetchActions() {
  try {
    const remote = await window?.go?.main?.App?.GetQuickActions?.(state.input);
    if (Array.isArray(remote)) {
      state.actions = remote;
      if (state.selected >= state.actions.length) {
        state.selected = Math.max(0, state.actions.length - 1);
      }
      render();
      return;
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

function bindUI() {
  const input = document.getElementById("command-input");
  if (input) {
    input.focus();
    input.setSelectionRange(input.value.length, input.value.length);
    input.addEventListener("input", (e) => {
      state.input = e.target.value;
      state.selected = 0;
      fetchActions();
    });
    input.addEventListener("focus", () => {
      state.focused = true;
      render();
    });
    input.addEventListener("blur", () => {
      state.focused = false;
      render();
    });

    input.addEventListener("keydown", async (e) => {
      if (e.key === "ArrowDown") {
        e.preventDefault();
        if (state.actions.length) {
          state.selected = (state.selected + 1) % state.actions.length;
          render();
        }
      } else if (e.key === "ArrowUp") {
        e.preventDefault();
        if (state.actions.length) {
          state.selected = (state.selected - 1 + state.actions.length) % state.actions.length;
          render();
        }
      } else if (e.key === "Enter") {
        e.preventDefault();
        await executeSelected();
      } else if (e.key === "Escape") {
        e.preventDefault();
        try {
          await window?.go?.main?.App?.MinimizeWindow?.();
        } catch (_) {}
      }
    });
  }

  document.querySelectorAll("[data-action-index]").forEach((node) => {
    node.addEventListener("click", async (e) => {
      const idx = Number(e.currentTarget?.dataset?.actionIndex ?? -1);
      if (idx >= 0 && idx < state.actions.length) {
        state.selected = idx;
        await executeSelected();
      }
    });
  });
}

async function syncWindowSize() {
  try {
    const expanded = state.input.trim().length > 0;
    const itemCount = expanded ? state.actions.length : 0;
    await window?.go?.main?.App?.SetPaletteExpanded?.(expanded, itemCount);
  } catch (_) {}
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
    render();
  }
});

window.addEventListener("dragover", (e) => {
  e.preventDefault();
  clearLeaveTimer();
  if (!state.dragging) {
    state.dragging = true;
    render();
  }
});

window.addEventListener("dragleave", (e) => {
  e.preventDefault();
  dragCounter = Math.max(0, dragCounter - 1);
  if (dragCounter === 0) {
    leaveTimer = setTimeout(() => {
      if (dragCounter === 0) {
        state.dragging = false;
        render();
      }
    }, 90);
  }
});

window.addEventListener("drop", async (e) => {
  e.preventDefault();
  dragCounter = 0;
  clearLeaveTimer();
  state.dragging = false;
  render();

  const file = e.dataTransfer?.files?.[0];
  if (!file) return;

  try {
    await window?.go?.main?.App?.ProcessFile?.(file.path || file.name, state.dropTarget || "ocr");
  } catch (_) {}
});

window.addEventListener("blur", async () => {
  try {
    await window?.go?.main?.App?.MinimizeWindow?.();
  } catch (_) {}
});

fetchActions();
render();
