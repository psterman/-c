import { useEffect, useMemo, useRef, useState } from "react";

const QUICK_ACTIONS = [
  { id: "ocr", label: "文字识别", keywords: ["ocr", "识别", "提取"] },
  { id: "summarize", label: "归类总结", keywords: ["总结", "归类", "摘要"] },
  { id: "ask-ai", label: "发送给AI", keywords: ["ai", "问", "提问"] },
  { id: "translate", label: "翻译", keywords: ["翻译", "translate", "译"] },
  { id: "search", label: "快速搜索", keywords: ["搜索", "search", "查找"] },
  { id: "script", label: "生成脚本", keywords: ["脚本", "代码", "生成"] },
];

function localQuickActions(input) {
  const text = input.trim().toLowerCase();
  if (!text) return QUICK_ACTIONS.slice(0, 4).map((a) => ({ ...a, matched: false }));

  const matched = QUICK_ACTIONS
    .map((action) => {
      const source = [action.label, ...action.keywords].join(" ").toLowerCase();
      const isHit = source.includes(text);
      return { ...action, matched: isHit, score: isHit ? 2 : 0 };
    })
    .filter((a) => a.matched)
    .sort((a, b) => b.score - a.score);

  return matched.length ? matched.slice(0, 8) : QUICK_ACTIONS.slice(0, 4).map((a) => ({ ...a, matched: false }));
}

export default function App() {
  const [input, setInput] = useState("");
  const [isInputFocused, setIsInputFocused] = useState(false);
  const [selectedDrop, setSelectedDrop] = useState("");
  const [isDragActive, setIsDragActive] = useState(false);
  const [actions, setActions] = useState(() => localQuickActions(""));
  const dragCounterRef = useRef(0);
  const leaveTimerRef = useRef(null);

  const hasInput = input.trim().length > 0;

  useEffect(() => {
    let mounted = true;
    const timer = setTimeout(async () => {
      try {
        // Wails bind call placeholder: window.go.main.App.GetQuickActions(input)
        const remote = await window?.go?.main?.App?.GetQuickActions?.(input);
        if (!mounted) return;
        if (Array.isArray(remote) && remote.length) {
          setActions(remote);
          return;
        }
      } catch (_) {
        // fallback to local matcher
      }
      if (mounted) setActions(localQuickActions(input));
    }, 80);

    return () => {
      mounted = false;
      clearTimeout(timer);
    };
  }, [input]);

  useEffect(() => {
    const clearLeaveTimer = () => {
      if (leaveTimerRef.current) {
        clearTimeout(leaveTimerRef.current);
        leaveTimerRef.current = null;
      }
    };

    const onDragEnter = (e) => {
      e.preventDefault();
      dragCounterRef.current += 1;
      clearLeaveTimer();
      setIsDragActive(true);
    };

    const onDragOver = (e) => {
      e.preventDefault();
      clearLeaveTimer();
      setIsDragActive((prev) => (prev ? prev : true));
    };

    const onDragLeave = (e) => {
      e.preventDefault();
      dragCounterRef.current = Math.max(0, dragCounterRef.current - 1);
      if (dragCounterRef.current === 0) {
        leaveTimerRef.current = setTimeout(() => {
          if (dragCounterRef.current === 0) setIsDragActive(false);
        }, 90);
      }
    };

    const onDrop = async (e) => {
      e.preventDefault();
      dragCounterRef.current = 0;
      clearLeaveTimer();
      setIsDragActive(false);

      const file = e.dataTransfer?.files?.[0];
      if (!file) return;

      setInput(`已接收: ${file.name}`);

      try {
        // Wails bind call placeholder: ProcessFile(path, actionType)
        await window?.go?.main?.App?.ProcessFile?.(file.path || file.name, selectedDrop || "ocr");
      } catch (_) {
        // demo skeleton: ignore backend error before Go binding is ready
      }
    };

    window.addEventListener("dragenter", onDragEnter);
    window.addEventListener("dragover", onDragOver);
    window.addEventListener("dragleave", onDragLeave);
    window.addEventListener("drop", onDrop);

    return () => {
      clearLeaveTimer();
      window.removeEventListener("dragenter", onDragEnter);
      window.removeEventListener("dragover", onDragOver);
      window.removeEventListener("dragleave", onDragLeave);
      window.removeEventListener("drop", onDrop);
    };
  }, [selectedDrop]);

  const actionButtons = useMemo(
    () =>
      actions.map((a) => (
        <button key={a.id} className={`action-btn ${a.matched ? "matched" : ""}`} type="button">
          {a.label}
        </button>
      )),
    [actions]
  );

  return (
    <main className="toolbar-shell">
      <section className={`panel ${isDragActive ? "drag-active" : ""} ${isInputFocused ? "input-focused" : ""}`}>
        <label className="title">NMER COMMAND BAR</label>
        <div className="input-wrap">
          <input
            type="text"
            placeholder="输入命令，例如 OCR / 总结 / AI"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onFocus={() => setIsInputFocused(true)}
            onBlur={() => setIsInputFocused(false)}
          />
        </div>

        <div className={`actions ${hasInput ? "show" : ""}`}>{actionButtons}</div>

        <div className={`drop-zone ${isDragActive ? "expanded" : ""}`}>
          <button className={`drop-card ${selectedDrop === "summarize" ? "selected" : ""}`} type="button" onClick={() => setSelectedDrop("summarize")}>
            <span>左侧</span>
            <strong>归类总结</strong>
          </button>
          <button className={`drop-card ${selectedDrop === "ocr" ? "selected" : ""}`} type="button" onClick={() => setSelectedDrop("ocr")}>
            <span>中间</span>
            <strong>文字识别</strong>
          </button>
          <button className={`drop-card ${selectedDrop === "ask-ai" ? "selected" : ""}`} type="button" onClick={() => setSelectedDrop("ask-ai")}>
            <span>右侧</span>
            <strong>发送给 AI 询问</strong>
          </button>
        </div>

        <p className="hint">拖拽文件到窗口可展开投递区（已预留 Go 调用位）</p>
      </section>
    </main>
  );
}
