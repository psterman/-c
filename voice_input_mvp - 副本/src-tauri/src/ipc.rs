use std::sync::Arc;
use tauri::Emitter;

use crate::AppState;
use crate::config;
fn normalize_record_key(key: &str) -> String {
    match key.trim() {
        "AudioVolumeUp" | "VolumeUp" | "Volume_Up" => "AutoTrigger".into(),
        "AudioVolumeDown" | "VolumeDown" | "Volume_Down" => "AutoTrigger".into(),
        "AudioVolumeMute" | "VolumeMute" | "Volume_Mute" => "AutoTrigger".into(),
        "MediaTrackNext" | "Media_Next" => "Media_Next".into(),
        "MediaTrackPrevious" | "Media_Prev" => "Media_Prev".into(),
        "MediaPlayPause" | "Media_Play_Pause" => "Media_Play_Pause".into(),
        "MediaStop" | "Media_Stop" => "Media_Stop".into(),
        other if other.is_empty() => "RAlt".into(),
        other => other.into(),
    }
}

#[derive(Clone, serde::Serialize)]
struct RuntimePayload {
    #[serde(rename = "type")]
    msg_type: String,
    #[serde(rename = "activeSceneId")]
    active_scene_id: String,
    #[serde(rename = "activeSceneLabel")]
    active_scene_label: String,
    bindings: String,
    #[serde(rename = "lastAction")]
    last_action: String,
    #[serde(rename = "sourceLabel")]
    source_label: String,
    #[serde(rename = "sourceGrouping")]
    source_grouping: String,
    #[serde(rename = "timerActive")]
    timer_active: bool,
    paused: bool,
}

pub fn push_runtime(state: &AppState, window: &tauri::WebviewWindow, last_action: &str) {
    let cfg = state.cfg.lock();
    let machine = state.machine.lock();
    let info = machine.runtime_info();
    let paused = *state.paused.lock();
    let scene = cfg.scenes.as_ref().and_then(|scenes| scenes.iter().find(|s| s.enabled)).cloned();
    let source = cfg.trigger_source.clone();
    let payload = RuntimePayload {
        msg_type: "mvp_runtime".into(),
        active_scene_id: scene.as_ref().map(|s| s.id.clone()).unwrap_or_else(|| "global".into()),
        active_scene_label: scene.as_ref().map(|s| s.label.clone()).unwrap_or_else(|| "全局".into()),
        bindings: cfg.bindings().join(", "),
        last_action: last_action.into(),
        source_label: source.as_ref().map(|s| s.label.clone()).unwrap_or_else(|| cfg.record_key.clone()),
        source_grouping: source.as_ref().map(|s| s.grouping.clone()).unwrap_or_else(|| "exact".into()),
        timer_active: info.timer_active,
        paused,
    };
    window.emit("to_js", &payload).ok();
}

#[tauri::command]
pub fn cmd_ready(state: tauri::State<Arc<AppState>>, window: tauri::WebviewWindow) {
    let cfg = state.cfg.lock().clone();
    let json = serde_json::to_string(&cfg).unwrap();
    window.eval(&format!("window.__vp_bridge__('mvp_init', {{config:{}}})", json)).ok();
    push_runtime(&state, &window, "config_push");
}

#[tauri::command]
pub fn cmd_save(state: tauri::State<Arc<AppState>>, window: tauri::WebviewWindow, json: String) {
    if let Ok(mut cfg) = serde_json::from_str::<config::VoiceConfig>(&json) {
        cfg.normalize();
        config::save_config(&cfg);
        if let Some(ref mgr) = *state.hotkey_mgr.lock() {
            mgr.bind_all(&cfg.bindings());
        }
        *state.cfg.lock() = cfg;
        state.machine.lock().reset();
        push_runtime(&state, &window, "saved");
        let ack = serde_json::json!({"type":"mvp_saved","ok":true});
        window.emit("to_js", &ack).ok();
    }
}

#[tauri::command]
pub fn cmd_start_recording(state: tauri::State<Arc<AppState>>) {
    state.machine.lock().reset();
    *state.recording.lock() = true;
    if let Some(ref mgr) = *state.hotkey_mgr.lock() {
        mgr.start_recording();
    }
}

#[tauri::command]
pub fn cmd_stop_recording(state: tauri::State<Arc<AppState>>) {
    *state.recording.lock() = false;
    if let Some(ref mgr) = *state.hotkey_mgr.lock() {
        mgr.stop_recording();
    }
}

#[tauri::command]
pub fn cmd_pause(state: tauri::State<Arc<AppState>>, window: tauri::WebviewWindow) {
    state.machine.lock().reset();
    *state.recording.lock() = false;
    *state.paused.lock() = true;
    let ack = serde_json::json!({"type":"mvp_paused","ok":true});
    window.emit("to_js", &ack).ok();
    push_runtime(&state, &window, "paused");
}

#[tauri::command]
pub fn cmd_resume(state: tauri::State<Arc<AppState>>, window: tauri::WebviewWindow) {
    *state.paused.lock() = false;
    let ack = serde_json::json!({"type":"mvp_resumed","ok":true});
    window.emit("to_js", &ack).ok();
    push_runtime(&state, &window, "resumed");
}

#[tauri::command]
pub fn cmd_capture_source(
    state: tauri::State<Arc<AppState>>,
    window: tauri::WebviewWindow,
    raw_events: Vec<config::RawEvent>,
) {
    let source = config::TriggerSource {
        id: "source_captured".into(),
        label: raw_events.first().map(|r| r.label.clone()).filter(|s| !s.is_empty()).unwrap_or_else(|| "已录制触发源".into()),
        mode: "single_press".into(),
        grouping: "exact".into(),
        raw_events,
    };
    let mut cfg = state.cfg.lock();
    cfg.trigger_source = Some(source.clone());
    cfg.record_key = source.label.clone();
    cfg.normalize();
    config::save_config(&cfg);
    if let Some(ref mgr) = *state.hotkey_mgr.lock() {
        mgr.bind_all(&cfg.bindings());
    }
    let payload = serde_json::json!({"type":"mvp_source_captured","source":source});
    window.emit("to_js", &payload).ok();
    push_runtime(&state, &window, "runtime_refresh");
}

#[tauri::command]
pub fn cmd_request_runtime(state: tauri::State<Arc<AppState>>, window: tauri::WebviewWindow) {
    push_runtime(&state, &window, "runtime_refresh");
}

#[tauri::command]
pub fn cmd_frontend_keydown(
    state: tauri::State<Arc<AppState>>,
    window: tauri::WebviewWindow,
    key: String,
) {
    if !*state.recording.lock() {
        return;
    }
    if key.trim().is_empty() {
        return;
    }

    let captured = normalize_record_key(&key);
    {
        let mut cfg = state.cfg.lock();
        cfg.record_key = if captured == "AutoTrigger" { "AutoTrigger".into() } else { captured.clone() };
        cfg.normalize();
        config::save_config(&cfg);
        if let Some(ref mgr) = *state.hotkey_mgr.lock() {
            mgr.stop_recording();
            mgr.bind_all(&cfg.bindings());
        }
    }
    *state.recording.lock() = false;
    let ack = serde_json::json!({"type":"mvp_key_captured","key":captured});
    window.emit("to_js", &ack).ok();
    push_runtime(&state, &window, "recorded");
}

