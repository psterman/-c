import React, { useEffect, useMemo, useRef, useState } from "react";
import { createRoot } from "react-dom/client";
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

function HolePage() {
  const [holeVisible, setHoleVisible] = useState(false);
  const [dragging, setDragging] = useState(false);
  const [dropPulse, setDropPulse] = useState(false);
  const [payloadType, setPayloadType] = useState("none");
  const [proximity, setProximity] = useState(0);
  const [hint, setHint] = useState("拖动文本或文件到洞口");

  const holeRef = useRef(null);
  const dragCounterRef = useRef(0);

  const cards = useMemo(
    () => Array.from({ length: 12 }).map((_, i) => ({ id: i, tilt: -14 + ((i % 6) * 6), lift: (i % 4) * 6 })),
    []
  );

  const applyPhaseHint = (type, phase) => {
    if (phase === "idle") return "拖动文本或文件到洞口";
    if (phase === "drop") return type === "text" ? "文本已流转" : "文件已流转";
    return type === "text" ? "靠近洞口，松开流转文本" : "靠近洞口，松开流转文件";
  };

  const resetState = (hide = true) => {
    setDragging(false);
    setProximity(0);
    setTimeout(() => {
      setPayloadType("none");
      setHint(applyPhaseHint("none", "idle"));
      if (hide) setHoleVisible(false);
    }, 900);
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
    const influenceRadius = Math.max(rect.width, rect.height) * 0.85;
    setProximity(clamp01(1 - dist / influenceRadius));
  };

  useEffect(() => {
    // AHK -> Wails -> WebView2 bridge API
    window.HoleOverlay = {
      show: (payload = "file") => {
        const type = payload === "text" ? "text" : "file";
        setHoleVisible(true);
        setDragging(false);
        setPayloadType(type);
        setProximity(0);
        setHint(applyPhaseHint(type, "drag"));
      },
      update: ({ payload = "file", proximity: p, x, y } = {}) => {
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
        resetState(true);
      },
      hide: () => {
        setDropPulse(false);
        setDragging(false);
        setProximity(0);
        setPayloadType("none");
        setHint(applyPhaseHint("none", "idle"));
        setHoleVisible(false);
      },
    };

    return () => {
      if (window.HoleOverlay) delete window.HoleOverlay;
    };
  }, []);

  useEffect(() => {
    // Browser fallback drag behavior for local testing
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
      if (dragCounterRef.current === 0) {
        setDragging(false);
        setProximity(0);
        setPayloadType("none");
        setHint(applyPhaseHint("none", "idle"));
        setHoleVisible(false);
      }
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

  const onDragOver = (event) => {
    event.preventDefault();
    event.dataTransfer.dropEffect = "copy";

    const nextType = detectPayloadType(event.dataTransfer);
    if (nextType === "none") {
      setDragging(false);
      setPayloadType("none");
      setProximity(0);
      setHint(applyPhaseHint("none", "idle"));
      return;
    }

    setHoleVisible(true);
    setDragging(true);
    setPayloadType(nextType);
    updateProximityFromPointer(event.clientX, event.clientY);
    setHint(applyPhaseHint(nextType, "drag"));
  };

  const onDragLeave = (event) => {
    event.preventDefault();
    if (!event.currentTarget.contains(event.relatedTarget)) {
      setDragging(false);
      setPayloadType("none");
      setProximity(0);
      setHint(applyPhaseHint("none", "idle"));
    }
  };

  const onDrop = async (event) => {
    event.preventDefault();

    const text = event.dataTransfer?.getData("text/plain")?.trim();
    const file = event.dataTransfer?.files?.[0];

    setDropPulse(true);

    if (text) {
      setPayloadType("text");
      setHint(applyPhaseHint("text", "drop"));
    } else if (file?.path || file?.name) {
      setPayloadType("file");
      setHint(`文件已流转: ${file.name}`);
      try {
        const sender = window?.go?.main?.App?.SendToAI;
        if (typeof sender === "function" && file.path) await sender(file.path);
      } catch (error) {
        console.error("SendToAI failed:", error);
      }
    } else {
      setHint("未检测到可流转内容");
    }

    setTimeout(() => setDropPulse(false), 620);
    resetState();
  };

  return (
    <main
      className={`flow-scene ${holeVisible ? "hole-visible" : "hole-hidden"} ${dragging ? "dragging" : ""} ${dropPulse ? "drop-pulse" : ""} payload-${payloadType}`}
      style={{ "--proximity": proximity.toFixed(3) }}
      onDragEnter={onDragOver}
      onDragOver={onDragOver}
      onDragLeave={onDragLeave}
      onDrop={onDrop}
    >
      <section className="card-cloud" aria-hidden="true">
        {cards.map((card, idx) => (
          <article
            key={card.id}
            className={`cloud-card ${idx === 7 ? "hero" : ""}`}
            style={{
              "--tilt": `${card.tilt}deg`,
              "--lift": `${card.lift}px`,
              "--x": `${(idx % 4) * 24 - 36}%`,
              "--y": `${Math.floor(idx / 4) * 22}%`,
            }}
          >
            <div className="line l1" />
            <div className="line l2" />
            <div className="line l3" />
          </article>
        ))}
      </section>

      <div className="fog" aria-hidden="true" />

      <section ref={holeRef} className="flow-hole" role="img" aria-label="流转洞">
        <div className="base-hole" />
        <div className="color-aura" />
        <div className="color-ring" />
        <div className="inner-well" />
      </section>

      <p className="hint">{hint}</p>
    </main>
  );
}

createRoot(document.getElementById("root")).render(<HolePage />);
