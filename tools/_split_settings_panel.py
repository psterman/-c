# -*- coding: utf-8 -*-
import re
import shutil
from pathlib import Path

root = Path(__file__).resolve().parent.parent
src = root / "html" / "SettingsPanel.html"
text = src.read_text(encoding="utf-8")
settings = root / "html" / "settings"
settings.mkdir(exist_ok=True)

legacy = settings / "SettingsPanel.legacy.html"
if not legacy.exists():
    shutil.copy2(src, legacy)

m = re.search(r"<style>(.*?)</style>", text, re.S)
css = m.group(1) if m else ""
(settings / "settings-shared.css").write_text(css.strip() + "\n", encoding="utf-8")

m = re.search(r"<script>\s*\n\s*if \(typeof BasePanel", text)
start = m.start() + len("<script>")
m2 = re.search(r"</script>\s*</body>", text[m.start() :])
end = m.start() + m2.start()
js = text[start:end]

patches = """
// --- settings iframe bridge (governance) ---
const __SETTINGS_SCOPE__ = window.__SETTINGS_SCOPE__ || null;
const __SETTINGS_CHILD__ = !!__SETTINGS_SCOPE__;
function __settingsPostToHost(payload) {
  if (__SETTINGS_CHILD__ && window.parent && window.parent !== window) {
    window.parent.postMessage({ channel: "nmer-settings-child", payload }, "*");
    return;
  }
  if (window.chrome?.webview) window.chrome.webview.postMessage(payload);
}
"""
old_bp = """window.BasePanel = {
        PROTO_VERSION: 1,
        postToAhk(obj) {
          if (!window.chrome?.webview) return;
          const src = (obj && typeof obj === 'object' && !Array.isArray(obj)) ? obj : {};
          const p = Object.assign({ v: 1, timestamp: Date.now() }, src);
          if (p.action === undefined && p.type !== undefined) p.action = p.type;
          window.chrome.webview.postMessage(p);
        }
      };"""
new_bp = """window.BasePanel = {
        PROTO_VERSION: 1,
        postToAhk(obj) {
          const src = (obj && typeof obj === 'object' && !Array.isArray(obj)) ? obj : {};
          const p = Object.assign({ v: 1, timestamp: Date.now() }, src);
          if (p.action === undefined && p.type !== undefined) p.action = p.type;
          __settingsPostToHost(p);
        }
      };"""
js = js.replace(old_bp, new_bp)
js = patches + js

scope_nav = """
        if (__SETTINGS_SCOPE__ && Array.isArray(__SETTINGS_SCOPE__.tabs)) {
          const allowed = new Set(__SETTINGS_SCOPE__.tabs);
          if (!allowed.has(state.activeTab)) state.activeTab = __SETTINGS_SCOPE__.tabs[0];
        }
"""
js = js.replace("        if (shouldNavigate) {", scope_nav + "        if (shouldNavigate) {")

js = js.replace(
    'document.querySelectorAll(".tab-btn").forEach(btn => btn.addEventListener("click", () => {',
    'function __settingsBindTabButtons() {\n      document.querySelectorAll("#sidebar .tab-btn, #child-subnav .tab-btn").forEach(btn => btn.addEventListener("click", () => {',
)
js = js.replace(
    '    }));\n    const panelRoot = document.getElementById("panel");',
    "    }));\n    }\n    __settingsBindTabButtons();\n    const panelRoot = document.getElementById(\"panel\");",
)

child_boot = """
    if (__SETTINGS_CHILD__) {
      window.addEventListener("message", (e) => {
        const d = e.data;
        if (!d || d.channel !== "nmer-settings-host") return;
        if (d.type === "initSlice") handleHostMessage({ type: "initData", payload: d.payload || {}, navigateToStartTab: !!d.navigateToStartTab });
        else if (d.type === "hostForward") handleHostMessage(d.message || d);
        else if (d.type === "setActiveTab" && d.tab) {
          state.activeTab = d.tab;
          document.querySelectorAll("#child-subnav .tab-btn").forEach(b => b.classList.toggle("active", b.dataset.tab === d.tab));
          render();
        }
      });
      if (__SETTINGS_SCOPE__?.defaultTab) state.activeTab = __SETTINGS_SCOPE__.defaultTab;
      render();
      setStatus("子页已加载", "ok");
    } else if (window.chrome && window.chrome.webview) {
"""
js = js.replace("    if (window.chrome && window.chrome.webview) {", child_boot)

(settings / "settings-app.js").write_text(js, encoding="utf-8")

modals = re.search(r'<div id="studioLlmAddModal".*?</div>\s*</div>\s*</div>', text, re.S)
modals_html = modals.group(0) if modals else ""

groups = {
    "SettingsGeneral.html": (["general", "appearance"], "通用与外观"),
    "SettingsPrompts.html": (["prompts"], "提示词"),
    "SettingsHotkeys.html": (["hotkeys"], "快捷键"),
    "SettingsSystem.html": (["advanced", "storage", "screenshot"], "系统"),
    "SettingsWorkspace.html": (["search", "customize"], "工作区"),
}
labels = {
    "general": "通用设置",
    "appearance": "外观设置",
    "prompts": "提示词设置",
    "hotkeys": "快捷键设置",
    "advanced": "高级设置",
    "storage": "存储与缓存",
    "screenshot": "截图设置",
    "search": "搜索设置",
    "customize": "智能定制",
}

child_tpl = """<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{title}</title>
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
  <link rel="stylesheet" href="settings-shared.css">
  <script src="https://cdn.jsdelivr.net/npm/sortablejs@1.15.2/Sortable.min.js"></script>
  <script src="https://app.local/assets/js/BasePanel.js"></script>
  <script src="https://app.local/assets/nm-bottom-dock.js"></script>
  <script src="settings-bridge-child.js"></script>
</head>
<body>
  <div id="app" class="settings-child">
    <nav id="child-subnav">{subnav}</nav>
    <section id="content">
      <div id="header"><div class="inline">[ {title} ]</div><div class="inline"><div id="status">等待连接...</div></div></div>
      <div id="panel"></div>
      <div id="footer"><button id="btn-cancel" class="btn">取消</button><button id="btn-save" class="btn primary">保存</button></div>
    </section>
  </div>
  {modals}
  <script src="https://app.local/assets/js/NmModal.js"></script>
  <script>window.__SETTINGS_SCOPE__ = {{ tabs: {tabs_json}, defaultTab: "{default_tab}" }};</script>
  <script src="settings-app.js"></script>
</body>
</html>
"""

for fname, (tabs, title) in groups.items():
    subnav = "".join(
        f'<button type="button" class="tab-btn" data-tab="{t}">{labels[t]}</button>' for t in tabs
    )
    html = child_tpl.format(
        title=title,
        subnav=subnav,
        modals=modals_html,
        tabs_json=str(tabs).replace("'", '"'),
        default_tab=tabs[0],
    )
    (settings / fname).write_text(html, encoding="utf-8")

(settings / "settings-bridge-child.js").write_text(
    """(function () {
  window.postToParent = function (type, payload) {
    window.parent.postMessage({ channel: "nmer-settings-child-action", type: type, payload: payload || {} }, "*");
  };
})();
""",
    encoding="utf-8",
)

(settings / "settings-bridge.js").write_text(
    """(function () {
  const SHELL_PAGES = {
    general: { file: "settings/SettingsGeneral.html", tabs: ["general", "appearance"] },
    prompts: { file: "settings/SettingsPrompts.html", tabs: ["prompts"] },
    hotkeys: { file: "settings/SettingsHotkeys.html", tabs: ["hotkeys"] },
    system: { file: "settings/SettingsSystem.html", tabs: ["advanced", "storage", "screenshot"] },
    workspace: { file: "settings/SettingsWorkspace.html", tabs: ["search", "customize"] }
  };
  const TAB_TO_SHELL = {};
  Object.entries(SHELL_PAGES).forEach(([shell, cfg]) => cfg.tabs.forEach(t => { TAB_TO_SHELL[t] = shell; }));

  let frame = null;
  let pendingInit = null;
  let activeShell = "general";

  function postToAhk(obj) {
    if (!window.chrome?.webview) return;
    const p = Object.assign({ v: 1, timestamp: Date.now() }, obj || {});
    if (p.action === undefined && p.type !== undefined) p.action = p.type;
    window.chrome.webview.postMessage(p);
  }

  function forwardToChild(msg) {
    if (!frame?.contentWindow) return;
    frame.contentWindow.postMessage({ channel: "nmer-settings-host", type: "hostForward", message: msg }, "*");
  }

  function pushInitToChild(navigate) {
    if (!pendingInit || !frame?.contentWindow) return;
    frame.contentWindow.postMessage({
      channel: "nmer-settings-host",
      type: "initSlice",
      payload: pendingInit,
      navigateToStartTab: navigate
    }, "*");
  }

  function loadShell(shellKey, innerTab) {
    const cfg = SHELL_PAGES[shellKey] || SHELL_PAGES.general;
    activeShell = shellKey;
    document.querySelectorAll("#sidebar .shell-tab").forEach(b => b.classList.toggle("active", b.dataset.shell === shellKey));
    frame.onload = function () {
      pushInitToChild(!!innerTab);
      if (innerTab) {
        frame.contentWindow.postMessage({ channel: "nmer-settings-host", type: "setActiveTab", tab: innerTab }, "*");
      }
    };
    frame.src = cfg.file;
  }

  window.NmerSettingsBridge = {
    init: function () {
      frame = document.getElementById("settings-frame");
      document.querySelectorAll("#sidebar .shell-tab").forEach(btn => {
        btn.addEventListener("click", () => {
          const shell = btn.dataset.shell;
          const firstTab = (SHELL_PAGES[shell] || SHELL_PAGES.general).tabs[0];
          loadShell(shell, firstTab);
        });
      });
      if (window.chrome?.webview) {
        window.chrome.webview.addEventListener("message", e => {
          const data = typeof e.data === "string" ? JSON.parse(e.data) : e.data;
          if (!data?.type) return;
          if (data.type === "initData") {
            pendingInit = data.payload || {};
            const tab = data.navigateToStartTab ? (pendingInit.defaultStartTab || "general") : null;
            const shell = TAB_TO_SHELL[tab] || "general";
            loadShell(shell, tab || (SHELL_PAGES[shell].tabs[0]));
            return;
          }
          forwardToChild(data);
        });
        postToAhk({ type: "ready" });
      }
      loadShell("general", "general");
    }
  };

  window.addEventListener("message", e => {
    const d = e.data;
    if (!d || d.channel !== "nmer-settings-child-action") return;
    postToAhk(Object.assign({ type: d.type }, d.payload || {}));
  });
})();
""",
    encoding="utf-8",
)

shell = """<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Settings Panel</title>
  <link rel="stylesheet" href="settings/settings-shared.css">
  <style>
    #app.settings-shell { display: grid; grid-template-columns: 200px 1fr; height: 100vh; }
    #settings-frame { border: 0; width: 100%; height: 100%; }
    #content.settings-shell-main { display: flex; flex-direction: column; min-height: 0; }
    #frame-wrap { flex: 1; min-height: 0; }
    .shell-tab { width: 100%; margin-bottom: 6px; }
    .settings-child #app { display: block; }
    .settings-child #child-subnav { display: flex; flex-wrap: wrap; gap: 6px; padding: 8px 12px; }
    .settings-child #sidebar { display: none; }
  </style>
  <script src="settings/settings-bridge.js"></script>
</head>
<body>
  <div id="app" class="settings-shell">
    <aside id="sidebar">
      <button type="button" class="tab-btn shell-tab active" data-shell="general">通用与外观</button>
      <button type="button" class="tab-btn shell-tab" data-shell="prompts">提示词</button>
      <button type="button" class="tab-btn shell-tab" data-shell="hotkeys">快捷键</button>
      <button type="button" class="tab-btn shell-tab" data-shell="system">系统</button>
      <button type="button" class="tab-btn shell-tab" data-shell="workspace">工作区</button>
    </aside>
    <section id="content" class="settings-shell-main">
      <div id="frame-wrap"><iframe id="settings-frame" title="设置子页"></iframe></div>
    </section>
  </div>
  <script>document.addEventListener("DOMContentLoaded", () => window.NmerSettingsBridge.init());</script>
</body>
</html>
"""
src.write_text(shell, encoding="utf-8")
print("settings split OK")
