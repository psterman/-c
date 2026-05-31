import React, { useEffect, useRef, useState } from "react";
import { createRoot } from "react-dom/client";
import { EventsOn } from "../wailsjs/runtime/runtime";
import "./hole.css";

function detectPayloadType(dataTransfer) {
  if (!dataTransfer) return "none";

  const types = Array.from(dataTransfer.types || []);
  const hasFilesType = types.includes("Files") || types.includes("application/x-moz-file");
  const hasTextType = types.includes("text/plain") || types.includes("text/uri-list") || types.includes("Text");

  if (hasFilesType) return "file";
  if (hasTextType) return "text";
  const file = dataTransfer.files?.[0];
  if (file) return "file";
  return "none";
}

function clamp01(v) {
  return Math.max(0, Math.min(1, v));
}

async function inspectDataTransfer(dataTransfer) {
  const types = Array.from(dataTransfer?.types || []);
  const text = (
    dataTransfer?.getData("text/plain")
    || dataTransfer?.getData("Text")
    || dataTransfer?.getData("text/uri-list")
    || ""
  ).trim();

  const files = Array.from(dataTransfer?.files || []).map((f) => ({
    name: f.name || "",
    type: f.type || "",
    size: Number(f.size || 0),
    path: f.path || "",
  }));

  let hasDirectory = false;
  try {
    const items = Array.from(dataTransfer?.items || []);
    hasDirectory = items.some((it) => {
      try {
        const entry = it.webkitGetAsEntry?.();
        return !!entry?.isDirectory;
      } catch (_) {
        return false;
      }
    });
  } catch (_) {}

  let kind = "none";
  if (text) kind = "text";
  if (files.length > 0) kind = hasDirectory ? "folder" : "file";

  return { kind, text, files, hasDirectory, sourceTypes: types };
}

function HolePage() {
  const [holeVisible, setHoleVisible] = useState(true);
  const [dragging, setDragging] = useState(false);
  const [dropPulse, setDropPulse] = useState(false);
  const [payloadType, setPayloadType] = useState("none");
  const [proximity, setProximity] = useState(0);
  const [hint, setHint] = useState("拖文字或文件靠近洞口");
  const [position, setPosition] = useState({ x: 0, y: 0 });
  const [snapshotBg, setSnapshotBg] = useState("");
  const [snapshotVisible, setSnapshotVisible] = useState(false);
  const [renderLocked, setRenderLocked] = useState(false);
  const [themeMode, setThemeMode] = useState("auto");

  const holeRef = useRef(null);
  const dragCounterRef = useRef(0);
  const movingRef = useRef(false);
  const moveOriginRef = useRef({ pointerX: 0, pointerY: 0, startX: 0, startY: 0 });

  const applyPhaseHint = (type, phase) => {
    if (phase === "idle") return "拖文字或文件靠近洞口";
    if (phase === "drop") return type === "text" ? "文本已流转" : "文件已流转";
    return type === "text" ? "松开以流转文本" : "松开以流转文件";
  };

  const resetState = (hide = false) => {
    setDragging(false);
    setProximity(0);
    setTimeout(() => {
      setPayloadType("none");
      setHint(applyPhaseHint("none", "idle"));
      setSnapshotVisible(false);
      setRenderLocked(false);
      setSnapshotBg("");
      if (hide) setHoleVisible(false);
    }, 560);
  };

  const updateProximityFromPointer = (clientX, clientY) => {
    const node = holeRef.current;
    if (!node || typeof clientX !== "number" || typeof clientY !== "number") return;

    const rect = node.getBoundingClientRect();
    const cx = rect.left + rect.width / 2;
    const cy = rect.top + rect.height / 2;
    const dx = clientX - cx;
    const dy = clientY - cy;
    const dist = Math.sqrt(dx * dx + dy * dy);
    const influenceRadius = Math.max(rect.width, rect.height) * 1.2;
    setProximity(clamp01(1 - dist / influenceRadius));
  };

  const beginMove = (event) => {
    if (event.button !== 0) return;
    movingRef.current = true;
    moveOriginRef.current = {
      pointerX: event.clientX,
      pointerY: event.clientY,
      startX: position.x,
      startY: position.y,
    };
    window.addEventListener("pointermove", handleMove);
    window.addEventListener("pointerup", endMove);
  };

  const handleMove = (event) => {
    if (!movingRef.current) return;
    const dx = event.clientX - moveOriginRef.current.pointerX;
    const dy = event.clientY - moveOriginRef.current.pointerY;

    const nextX = Math.max(12, Math.min(window.innerWidth - 172, moveOriginRef.current.startX + dx));
    const nextY = Math.max(12, Math.min(window.innerHeight - 220, moveOriginRef.current.startY + dy));
    setPosition({ x: nextX, y: nextY });
  };

  const endMove = () => {
    movingRef.current = false;
    window.removeEventListener("pointermove", handleMove);
    window.removeEventListener("pointerup", endMove);
  };

  const closeHole = () => {
    endMove();
    setDropPulse(false);
    setDragging(false);
    setProximity(0);
    setPayloadType("none");
    setHint(applyPhaseHint("none", "idle"));
    setHoleVisible(false);
    postHostMessage({ type: "hole_close" });
  };

  const postHostMessage = (payload) => {
    try {
      if (window?.chrome?.webview?.postMessage) {
        window.chrome.webview.postMessage(payload);
      }
    } catch (_) {}
  };

  useEffect(() => {
    const root = document.documentElement;
    if (!root) return;
    const mode = String(themeMode || "auto").toLowerCase();
    if (mode === "dark" || mode === "light") root.setAttribute("data-theme", mode);
    else root.removeAttribute("data-theme");
  }, [themeMode]);

  useEffect(() => {
    const offNativeDrop = EventsOn("native_drop_detected", (eventPayload) => {
      const payload = Array.isArray(eventPayload) ? eventPayload[0] : eventPayload;
      const kind = payload?.kind === "text" ? "text" : (payload?.kind === "file" ? "file" : "none");
      if (kind === "none") return;

      setHoleVisible(true);
      setDragging(false);
      setPayloadType(kind);
      setDropPulse(true);
      setHint(applyPhaseHint(kind, "drop"));
      setTimeout(() => setDropPulse(false), 620);
      resetState(false);
    });

    window.HoleOverlay = {
      setTheme: (o) => {
        let mode = "auto";
        if (typeof o === "string") mode = o;
        else if (o && typeof o.themeMode === "string") mode = o.themeMode;
        else if (o && typeof o.theme === "string") mode = o.theme;
        mode = String(mode || "auto").toLowerCase();
        if (mode !== "dark" && mode !== "light" && mode !== "auto") mode = "auto";
        setThemeMode(mode);
      },
      show: (payload = "file") => {
        window.__gdhoUserInteracting = true;
        const type = payload === "text" ? "text" : "file";
        setHoleVisible(true);
        setDragging(false);
        setPayloadType(type);
        setProximity(0);
        setHint(applyPhaseHint(type, "drag"));
        try {
          window.requestAnimationFrame(() => postHostMessage({ type: "hole_drop_ack" }));
        } catch (_) {}
      },
      update: ({ payload = "file", proximity: p, x, y } = {}) => {
        window.__gdhoUserInteracting = true;
        const type = payload === "text" ? "text" : "file";
        setHoleVisible(true);
        setDragging(true);
        setPayloadType(type);
        setHint(applyPhaseHint(type, "drag"));

        if (typeof p === "number") {
          setProximity(clamp01(p));
        } else {
          updateProximityFromPointer(x, y);
        }
      },
      drop: ({ payload = "file" } = {}) => {
        const type = payload === "text" ? "text" : "file";
        setPayloadType(type);
        setDragging(false);
        setDropPulse(true);
        setHint(applyPhaseHint(type, "drop"));
        setTimeout(() => setDropPulse(false), 620);
        resetState(false);
      },
      hide: () => {
        window.__gdhoUserInteracting = false;
        setDropPulse(false);
        setDragging(false);
        setProximity(0);
        setPayloadType("none");
        setHint(applyPhaseHint("none", "idle"));
        setHoleVisible(false);
      },
      moveTo: ({ x, y } = {}) => {
        if (typeof x === "number" && typeof y === "number") {
          setPosition({
            x: Math.max(12, Math.min(window.innerWidth - 172, x)),
            y: Math.max(12, Math.min(window.innerHeight - 220, y)),
          });
        }
      },
      setProximity: (p) => {
        setProximity(clamp01(Number(p) || 0));
      },
      setSleepMode: (enabled) => {
        const sleeping = !!enabled;
        window.__gdhoUserInteracting = !sleeping;
        if (sleeping) {
          setDropPulse(false);
          setDragging(false);
          setProximity(0);
        }
        document.documentElement.classList.toggle("gdho-sleep", sleeping);
      },
    };

    return () => {
      if (typeof offNativeDrop === "function") offNativeDrop();
      if (typeof offNativeIntent === "function") offNativeIntent();
      endMove();
      if (window.HoleOverlay) delete window.HoleOverlay;
    };
  }, []);

  const onHoleDrop = (event) => {
    event.preventDefault();

    setDropPulse(true);
    setTimeout(() => setDropPulse(false), 620);

    inspectDataTransfer(event.dataTransfer).then((payload) => {
      if (payload.kind === "text" && payload.text) {
        setPayloadType("text");
        setHint(applyPhaseHint("text", "drop"));
      } else if (payload.kind === "file" || payload.kind === "folder") {
        setPayloadType("file");
        setHint(applyPhaseHint("file", "drop"));
      }
      postHostMessage({ type: "hole_drop", payload });
      resetState(false);
    });
  };

  useEffect(() => {
    const onWindowDragEnter = (event) => {
      const type = detectPayloadType(event.dataTransfer);
      if (type === "none") return;
      event.preventDefault();
      dragCounterRef.current += 1;
      setHoleVisible(true);
      setPayloadType(type);
      setHint(applyPhaseHint(type, "drag"));
    };

    const onWindowDragOver = (event) => {
      const type = detectPayloadType(event.dataTransfer);
      if (type === "none") return;
      event.preventDefault();
      event.dataTransfer.dropEffect = "copy";
      setHoleVisible(true);
      setDragging(true);
      setPayloadType(type);
      updateProximityFromPointer(event.clientX, event.clientY);
    };

    const onWindowDragLeave = () => {
      dragCounterRef.current = Math.max(0, dragCounterRef.current - 1);
      if (dragCounterRef.current === 0) resetState(false);
    };

    const onWindowDrop = () => {
      dragCounterRef.current = 0;
    };

    window.addEventListener("dragenter", onWindowDragEnter);
    window.addEventListener("dragover", onWindowDragOver);
    window.addEventListener("dragleave", onWindowDragLeave);
    window.addEventListener("drop", onWindowDrop);

    return () => {
      window.removeEventListener("dragenter", onWindowDragEnter);
      window.removeEventListener("dragover", onWindowDragOver);
      window.removeEventListener("dragleave", onWindowDragLeave);
      window.removeEventListener("drop", onWindowDrop);
    };
  }, []);

  return (
    <main className="hole-stage">
      <section
        ref={holeRef}
        className={`floating-hole ${holeVisible ? "" : "hidden"} ${dragging ? "dragging" : ""} ${dropPulse ? "drop-pulse" : ""} ${renderLocked ? "render-locked" : ""} payload-${payloadType}`}
        style={{ "--proximity": proximity.toFixed(3), left: `${position.x}px`, top: `${position.y}px` }}
        onDragEnter={(e) => {
          e.preventDefault();
          const type = detectPayloadType(e.dataTransfer);
          if (type === "none") return;
          setDragging(true);
          setPayloadType(type);
        }}
        onDragOver={(e) => {
          e.preventDefault();
          const type = detectPayloadType(e.dataTransfer);
          if (type === "none") return;
          setDragging(true);
          setPayloadType(type);
          updateProximityFromPointer(e.clientX, e.clientY);
        }}
        onDragLeave={() => {
          setDragging(false);
          setProximity(0);
        }}
        onDrop={onHoleDrop}
      >
        <div className={`snapshot-bg ${snapshotVisible ? "show" : ""}`} style={snapshotBg ? { backgroundImage: `url(${snapshotBg})` } : undefined} />
        <button type="button" className="hole-grip" onPointerDown={beginMove} title="按住拖动位置" aria-label="拖动洞位置" />
        <button
          type="button"
          className="hole-close"
          onClick={closeHole}
          title="关闭洞"
          aria-label="关闭洞"
        >
          ×
        </button>
        <div className="hole-core" aria-label="流转洞" role="img">
          <div className="base-hole" />
          <div className="color-aura" />
          <div className="color-ring" />
          <div className="inner-well" />
        </div>
        {(dragging && proximity > 0.18) ? <p className="hint">{hint}</p> : null}
      </section>
    </main>
  );
}

createRoot(document.getElementById("root")).render(<HolePage />);

    const offNativeIntent = EventsOn("native_drag_intent", async (eventPayload) => {
      const p = Array.isArray(eventPayload) ? eventPayload[0] : eventPayload;
      const x = Number(p?.dropX || 0);
      const y = Number(p?.dropY || 0);
      setRenderLocked(true);
      setSnapshotVisible(true);
      try {
        const cap = await window?.go?.main?.App?.CaptureArea?.(Math.max(0, x - 110), Math.max(0, y - 90), 220, 220);
        if (cap?.ok && cap?.base64) {
          setSnapshotBg(String(cap.base64));
        }
      } catch (_) {}
      try {
        await window?.go?.main?.App?.FadeInWindow?.(140);
      } catch (_) {}
      setTimeout(() => setSnapshotVisible(false), 200);
      setTimeout(() => setRenderLocked(false), 220);
    });
