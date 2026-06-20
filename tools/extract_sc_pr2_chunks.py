#!/usr/bin/env python3
"""One-shot extractor for SearchCenter PR2 chunks (web-embed / cli JS+CSS)."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HTML = ROOT / "html" / "SearchCenter.html"
OUT_JS = ROOT / "assets" / "js"
OUT_CSS = ROOT / "assets" / "css"

WEB_JS_RANGES = [(6616, 8615), (9233, 9442)]
CLI_JS_RANGES = [
    (5403, 5433),
    (5435, 5470),
    (5471, 5499),
    (5501, 5505),
    (6514, 6533),
    (9731, 10330),
]

WEB_CSS_RANGES = [(2651, 4150), (3740, 4143), (4014, 4035)]
CLI_CSS_RANGES = [(2155, 2176), (4168, 4177), (4251, 4255), (4652, 4876)]

WEB_FOOTER = r"""
function scWebEmbedPrepareWebMode() {
  _scWebEmbedLastRectKey = "";
  _scWebEmbedLastLayoutKey = "";
  _scWebEmbedHostBootstrapped = false;
  const viewport = document.getElementById("web-embed-scroll-viewport");
  if (viewport) viewport.scrollLeft = 0;
}

function scWebEmbedInvalidateContentRect() {
  _scWebEmbedLastRectKey = "";
}

function isWebEmbedDebugPanelOpen() {
  return !!(_scWebEmbedDebugState && _scWebEmbedDebugState.open);
}

if (typeof globalThis !== "undefined") {
  globalThis.ScWebEmbed = globalThis.ScWebEmbed || { loaded: true };
  globalThis.ScWebEmbed.loaded = true;
}
"""

CLI_FOOTER = r"""
let _scCliControlsInited = false;
function ensureCliControlsInited() {
  if (_scCliControlsInited) return;
  _scCliControlsInited = true;
  initCliTerminalControls();
}

if (typeof globalThis !== "undefined") {
  globalThis.ScCli = globalThis.ScCli || { loaded: true };
  globalThis.ScCli.loaded = true;
  globalThis.ScCli.ensureControlsInited = ensureCliControlsInited;
}
"""


def pick_lines(lines: list[str], ranges: list[tuple[int, int]]) -> str:
    out: list[str] = []
    for start, end in ranges:
        out.extend(lines[start - 1 : end])
        out.append("")
    return "".join(out)


def wrap_js(name: str, body: str, footer: str) -> str:
    header = f"/* SearchCenter {name} chunk — lazy-loaded via ScChunkLoader */\n"
    return header + body + "\n" + footer


def main() -> None:
    lines = HTML.read_text(encoding="utf-8").splitlines(keepends=True)

    web_js = pick_lines(lines, WEB_JS_RANGES)
    cli_js = pick_lines(lines, CLI_JS_RANGES)
    web_css = pick_lines(lines, WEB_CSS_RANGES)
    cli_css = pick_lines(lines, CLI_CSS_RANGES)

    OUT_JS.mkdir(parents=True, exist_ok=True)
    OUT_CSS.mkdir(parents=True, exist_ok=True)

    (OUT_JS / "sc-web-embed.js").write_text(wrap_js("web-embed", web_js, WEB_FOOTER), encoding="utf-8")
    (OUT_JS / "sc-cli.js").write_text(wrap_js("cli", cli_js, CLI_FOOTER), encoding="utf-8")
    (OUT_CSS / "sc-web-embed.css").write_text(
        "/* SearchCenter web-embed chunk styles */\n" + web_css, encoding="utf-8"
    )
    (OUT_CSS / "sc-cli.css").write_text(
        "/* SearchCenter cli chunk styles */\n" + cli_css, encoding="utf-8"
    )

    print("Wrote:")
    for p in [
        OUT_JS / "sc-web-embed.js",
        OUT_JS / "sc-cli.js",
        OUT_CSS / "sc-web-embed.css",
        OUT_CSS / "sc-cli.css",
    ]:
        print(f"  {p.relative_to(ROOT)} ({p.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
