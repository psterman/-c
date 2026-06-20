#!/usr/bin/env python3
"""Patch SearchCenter.html after PR2 chunk extraction."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HTML = ROOT / "html" / "SearchCenter.html"

DELETE_RANGES = sorted(
    [
        (5403, 5433),
        (5435, 5470),
        (5471, 5499),
        (5501, 5505),
        (6514, 6533),
        (6616, 8615),
        (9233, 9442),
        (9731, 10330),
        (2155, 2176),
        (2651, 4150),
        (4168, 4177),
        (4251, 4255),
        (4652, 4876),
    ],
    reverse=True,
)

STUB_BLOCK = r"""
/* --- PR2 lazy chunks: web-embed / cli (see assets/js/sc-*.js) --- */
function scStubDismissWebEmbed(dispose = true) {
  try { postToAhk({ type: "webLlmDismiss", dispose: !!dispose }); } catch (_) {}
}
function scStubNoop() {}

const SC_CHUNK_STUBS = [
  "isWebEmbedActive", "isWebEmbedCategory", "dismissWebEmbedHost", "cancelWebEmbedRectTimers",
  "syncWebEmbedLayout", "syncWebEmbedToolbarVisibility", "renderWebLlmToolbar", "renderWebEmbedTabBar",
  "renderWebModeNavBody", "syncWebModeNavAiRows", "scheduleWebEmbedContentRect", "postWebEmbedContentRect",
  "renderWebExternalHint", "openWebEmbedSetupFromNav", "scWebEmbedPrepareWebMode", "scWebEmbedInvalidateContentRect",
  "isWebEmbedDebugPanelOpen", "initWebLlmToolbar", "validateWebEmbedCatalog",
  "normalizeCliEngineId", "getActiveCliEngine", "sendComposeToCli", "scheduleSyncCliWorkspace",
  "syncCliWorkspace", "renderCliEngineTabs", "renderCliQuickCmds", "setCliTerminalFocusLock",
  "handleTtydHostMessage", "ensureCliControlsInited", "getCliEnginesForTabs", "isKnownCliEngineId"
];
SC_CHUNK_STUBS.forEach((name) => {
  if (typeof globalThis[name] !== "function") {
    if (name === "isWebEmbedActive" || name === "isWebEmbedCategory" || name === "isWebEmbedDebugPanelOpen" || name === "isKnownCliEngineId") {
      globalThis[name] = () => false;
    } else if (name === "handleTtydHostMessage") {
      globalThis[name] = () => false;
    } else if (name === "dismissWebEmbedHost") {
      globalThis[name] = scStubDismissWebEmbed;
    } else if (name === "normalizeCliEngineId") {
      globalThis[name] = (v) => {
        const s = String(v || "").trim().toLowerCase();
        return s || "codex_cli";
      };
    } else if (name === "getActiveCliEngine") {
      globalThis[name] = () => normalizeCliEngineId(state.activeCliEngine);
    } else if (name === "getCliEnginesForTabs") {
      globalThis[name] = () => [];
    } else if (name === "ensureCliControlsInited") {
      globalThis[name] = scStubNoop;
    } else {
      globalThis[name] = scStubNoop;
    }
  }
});

function ensureScChunkThen(fn) {
  const mode = String(fn.__scChunk || "");
  if (!mode || !globalThis.ScChunkLoader) {
    fn();
    return;
  }
  ScChunkLoader.ensureScChunk(mode).then(fn).catch((e) => {
    console.error("[SearchCenter] chunk load failed:", mode, e);
    fn();
  });
}

"""

LOADER_SCRIPT = '<script src="https://app.local/assets/js/sc-chunk-loader.js"></script>\n'


def delete_ranges(lines: list[str], ranges: list[tuple[int, int]]) -> list[str]:
    for start, end in ranges:
        del lines[start - 1 : end]
    return lines


def patch_set_ui_mode(text: str) -> str:
    if "function setUIModeCore(" in text:
        return text
    text = text.replace(
        "function setUIMode(mode, persist, skipHostPost, skipCategoryReset) {",
        "function setUIMode(mode, persist, skipHostPost, skipCategoryReset) {\n"
        "  const m0 = normalizeUiMode(mode);\n"
        "  const chunk = m0 === \"web\" ? \"web\" : (m0 === \"cli\" ? \"cli\" : \"\");\n"
        "  if (chunk && globalThis.ScChunkLoader && !ScChunkLoader.isScChunkLoaded(chunk)) {\n"
        "    ScChunkLoader.ensureScChunk(chunk).then(() => setUIModeCore(m0, persist, skipHostPost, skipCategoryReset))\n"
        "      .catch((e) => { console.error(\"[SearchCenter] chunk\", chunk, e); setUIModeCore(m0, persist, skipHostPost, skipCategoryReset); });\n"
        "    return;\n"
        "  }\n"
        "  setUIModeCore(m0, persist, skipHostPost, skipCategoryReset);\n"
        "}\n\n"
        "function setUIModeCore(mode, persist, skipHostPost, skipCategoryReset) {",
        1,
    )
    text = text.replace(
        "  if (m !== \"web\")\n    dismissWebEmbedHost();\n"
        "  if (m === \"local\" || m === \"clipboard\" || m === \"fulltext\" || m === \"cli\") {\n"
        "    cancelWebEmbedRectTimers();\n"
        "  } else if (m === \"web\") {\n"
        "    _scWebEmbedLastRectKey = \"\";\n"
        "    _scWebEmbedLastLayoutKey = \"\";\n"
        "    _scWebEmbedHostBootstrapped = false;\n"
        "    const viewport = document.getElementById(\"web-embed-scroll-viewport\");\n"
        "    if (viewport) viewport.scrollLeft = 0;\n"
        "  }",
        "  if (m !== \"web\") {\n"
        "    dismissWebEmbedHost();\n"
        "    if (typeof cancelWebEmbedRectTimers === \"function\") cancelWebEmbedRectTimers();\n"
        "  } else if (typeof scWebEmbedPrepareWebMode === \"function\") {\n"
        "    scWebEmbedPrepareWebMode();\n"
        "  }",
        1,
    )
    text = text.replace(
        "  if (m === \"web\" && isWebEmbedCategory()) {\n"
        "    _scWebEmbedHostBootstrapped = false;\n"
        "    renderWebLlmToolbar();\n"
        "    scheduleWebEmbedContentRect();\n"
        "  }",
        "  if (m === \"web\" && isWebEmbedCategory()) {\n"
        "    if (typeof initWebLlmToolbar === \"function\") initWebLlmToolbar();\n"
        "    else renderWebLlmToolbar();\n"
        "    scheduleWebEmbedContentRect();\n"
        "  }",
        1,
    )
    text = text.replace(
        "  if (m === \"cli\") {\n"
        "    setCliTerminalFocusLock(true);",
        "  if (m === \"cli\") {\n"
        "    if (typeof ensureCliControlsInited === \"function\") ensureCliControlsInited();\n"
        "    setCliTerminalFocusLock(true);",
        1,
    )
    text = text.replace(
        "          _scWebEmbedLastRectKey = \"\";\n"
        "          postWebEmbedContentRect(true);",
        "          if (typeof scWebEmbedInvalidateContentRect === \"function\") scWebEmbedInvalidateContentRect();\n"
        "          postWebEmbedContentRect(true);",
        1,
    )
    return text


def patch_init_compose_stack(text: str) -> str:
    old = (
        "  const initMode = getUIMode();\n"
        "  setUIMode(initMode, false, true);\n"
    )
    new = (
        "  const initMode = getUIMode();\n"
        "  const bootChunk = initMode === \"web\" ? \"web\" : (initMode === \"cli\" ? \"cli\" : \"\");\n"
        "  const boot = () => {\n"
        "    setUIMode(initMode, false, true);\n"
        "    try { postToAhk({ type: \"setUiMode\", mode: initMode }); } catch (_) {}\n"
        "    renderModeBar();\n"
        "    syncModeSections();\n"
        "    syncComposeChrome();\n"
        "  };\n"
        "  if (bootChunk && globalThis.ScChunkLoader) {\n"
        "    ScChunkLoader.ensureScChunk(bootChunk).then(boot).catch((e) => { console.error(e); boot(); });\n"
        "  } else {\n"
        "    boot();\n"
        "  }\n"
    )
    if old in text:
        text = text.replace(old, new, 1)
        text = text.replace(
            "  try { postToAhk({ type: \"setUiMode\", mode: initMode }); } catch (_) {}\n"
            "  renderModeBar();\n"
            "  syncModeSections();\n"
            "  syncComposeChrome();\n",
            "",
            1,
        )
    return text


def main() -> None:
    lines = HTML.read_text(encoding="utf-8").splitlines(keepends=True)
    lines = delete_ranges(lines, DELETE_RANGES)
    text = "".join(lines)

    if LOADER_SCRIPT.strip() not in text:
        text = text.replace(
            '<script src="https://app.local/assets/js/NmModal.js"></script>\n<script>',
            '<script src="https://app.local/assets/js/NmModal.js"></script>\n'
            + LOADER_SCRIPT
            + "<script>",
            1,
        )

    marker = "const SC_ENGINE_MODE_KEY"
    if "PR2 lazy chunks" not in text:
        text = text.replace(marker, STUB_BLOCK + marker, 1)

    text = patch_set_ui_mode(text)
    text = patch_init_compose_stack(text)

    text = text.replace("initCliTerminalControls();\n", "", 1)
    text = text.replace(
        "  initWebLlmToolbar();\n  scSendReadyOnce();",
        "  if (getUIMode() === \"web\" && typeof initWebLlmToolbar === \"function\") initWebLlmToolbar();\n  scSendReadyOnce();",
        1,
    )
    text = text.replace(
        "      if (_scWebEmbedDebugState.open) requestWebEmbedDebugSnapshot();",
        "      if (typeof isWebEmbedDebugPanelOpen === \"function\" && isWebEmbedDebugPanelOpen()) requestWebEmbedDebugSnapshot();",
        1,
    )

    HTML.write_text(text, encoding="utf-8")
    print(f"Patched {HTML.relative_to(ROOT)} ({len(text.splitlines())} lines)")


if __name__ == "__main__":
    main()
