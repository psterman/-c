import { useState } from "react";

export default function App() {
  const [dragActive, setDragActive] = useState(false);

  const handleDragOver = (event) => {
    event.preventDefault();
    event.dataTransfer.dropEffect = "copy";
    if (!dragActive) setDragActive(true);
  };

  const handleDragLeave = (event) => {
    event.preventDefault();
    const next = event.relatedTarget;
    if (!event.currentTarget.contains(next)) {
      setDragActive(false);
    }
  };

  const handleDrop = async (event) => {
    event.preventDefault();
    setDragActive(false);

    const file = event.dataTransfer?.files?.[0];
    if (!file) return;

    const path = file.path || "";
    if (!path) return;

    try {
      const sender = window?.go?.main?.App?.SendToAI;
      if (typeof sender === "function") {
        await sender(path);
      } else {
        console.warn("SendToAI bridge is unavailable");
      }
    } catch (error) {
      console.error("SendToAI failed:", error);
    }
  };

  return (
    <>
      <main className="toolbar-shell" style={{ position: "relative", zIndex: 10 }}>
        <section className="panel raycast-single">
          <div className="input-wrap only-input">
            <input
              type="text"
              placeholder="输入命令，↑↓ 选择，Enter 执行，Esc 收起"
              autoFocus
              autoComplete="off"
            />
          </div>
        </section>
      </main>

      <aside className="float-hole-shell" aria-label="感应洞悬浮层">
        <section
          className={`float-hole${dragActive ? " drag-active" : ""}`}
          onDragEnter={handleDragOver}
          onDragOver={handleDragOver}
          onDragLeave={handleDragLeave}
          onDrop={handleDrop}
        >
          <div className="inner-glow" aria-hidden="true" />
          <div className="drop-text">
            <strong>{dragActive ? "松开以上传" : "拖入文件"}</strong>
            <span>支持文字 / 图片 / 文档</span>
          </div>
        </section>
      </aside>
    </>
  );
}
