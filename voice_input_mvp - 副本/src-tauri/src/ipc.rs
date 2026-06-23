use std::sync::Arc;

use tauri::Emitter;

use crate::config::{
    self, canonical_trigger, is_allowed_trigger, new_mapping_id, MappingEntry, VoiceConfig,
};
use crate::AppState;

#[derive(Debug, Clone)]
pub enum RecordMode {
    Trigger,
    Target,
}

#[derive(Debug, Clone)]
pub struct RecordingTarget {
    pub mapping_id: String,
    pub mode: RecordMode,
}

fn normalize_record_key(key: &str) -> String {
    canonical_trigger(key)
}

#[derive(Clone, serde::Serialize)]
struct RuntimePayload {
    #[serde(rename = "type")]
    msg_type: String,
    bindings: String,
    #[serde(rename = "lastAction")]
    last_action: String,
    #[serde(rename = "lastMappingId")]
    last_mapping_id: String,
    #[serde(rename = "mappingCount")]
    mapping_count: u32,
    #[serde(rename = "enabledCount")]
    enabled_count: u32,
    #[serde(rename = "timerActive")]
    timer_active: bool,
    paused: bool,
}

pub fn push_runtime(
    state: &AppState,
    window: &tauri::WebviewWindow,
    last_action: &str,
    last_mapping_id: &str,
) {
    let cfg = state.cfg.lock();
    let pool = state.machine_pool.lock();
    let paused = *state.paused.lock();
    let enabled_count = cfg.mappings.iter().filter(|m| m.enabled).count() as u32;
    let payload = RuntimePayload {
        msg_type: "mvp_runtime".into(),
        bindings: cfg.bindings().join(", "),
        last_action: last_action.into(),
        last_mapping_id: last_mapping_id.into(),
        mapping_count: cfg.mappings.len() as u32,
        enabled_count,
        timer_active: pool.any_timer_active(),
        paused,
    };
    window.emit("to_js", &payload).ok();
}

fn sync_config_ui(state: &AppState, window: &tauri::WebviewWindow) {
    let cfg = state.cfg.lock().clone();
    if let Ok(json) = serde_json::to_string(&cfg) {
        window
            .eval(&format!(
                "window.__vp_bridge__('mvp_init', {{config:{}}})",
                json
            ))
            .ok();
    }
}

fn persist_and_rebind(state: &AppState, window: &tauri::WebviewWindow, last_action: &str) {
    let cfg = state.cfg.lock().clone();
    config::save_config(&cfg);
    config::apply_config(state, &cfg);
    sync_config_ui(state, window);
    push_runtime(state, window, last_action, "");
}

#[tauri::command]
pub fn cmd_ready(state: tauri::State<Arc<AppState>>, window: tauri::WebviewWindow) {
    let cfg = state.cfg.lock().clone();
    let json = serde_json::to_string(&cfg).unwrap();
    window
        .eval(&format!(
            "window.__vp_bridge__('mvp_init', {{config:{}}})",
            json
        ))
        .ok();
    push_runtime(&state, &window, "config_push", "");
}

#[tauri::command]
pub fn cmd_save(state: tauri::State<Arc<AppState>>, window: tauri::WebviewWindow, json: String) {
    if let Ok(mut cfg) = serde_json::from_str::<VoiceConfig>(&json) {
        cfg.migrate();
        cfg.normalize();
        config::save_config(&cfg);
        config::apply_config(&state, &cfg);
        *state.cfg.lock() = cfg.clone();
        sync_config_ui(&state, &window);
        state.machine_pool.lock().reset_all();
        push_runtime(&state, &window, "saved", "");
        let ack = serde_json::json!({"type":"mvp_saved","ok":true});
        window.emit("to_js", &ack).ok();
    }
}

#[tauri::command]
pub fn cmd_start_recording(
    state: tauri::State<Arc<AppState>>,
    mapping_id: String,
    mode: String,
) {
    state.machine_pool.lock().reset_all();
    let record_mode = if mode == "target" {
        RecordMode::Target
    } else {
        RecordMode::Trigger
    };
    *state.recording_target.lock() = Some(RecordingTarget {
        mapping_id,
        mode: record_mode,
    });
    *state.recording.lock() = true;
    if let Some(ref mgr) = *state.hotkey_mgr.lock() {
        mgr.start_recording();
    }
}

#[tauri::command]
pub fn cmd_stop_recording(state: tauri::State<Arc<AppState>>) {
    *state.recording.lock() = false;
    *state.recording_target.lock() = None;
    if let Some(ref mgr) = *state.hotkey_mgr.lock() {
        mgr.stop_recording();
        let bindings = state.cfg.lock().bindings();
        mgr.bind_all(&bindings);
    }
}

#[tauri::command]
pub fn cmd_pause(state: tauri::State<Arc<AppState>>, window: tauri::WebviewWindow) {
    state.machine_pool.lock().reset_all();
    *state.recording.lock() = false;
    *state.recording_target.lock() = None;
    *state.paused.lock() = true;
    let ack = serde_json::json!({"type":"mvp_paused","ok":true});
    window.emit("to_js", &ack).ok();
    push_runtime(&state, &window, "paused", "");
}

#[tauri::command]
pub fn cmd_resume(state: tauri::State<Arc<AppState>>, window: tauri::WebviewWindow) {
    *state.paused.lock() = false;
    let ack = serde_json::json!({"type":"mvp_resumed","ok":true});
    window.emit("to_js", &ack).ok();
    push_runtime(&state, &window, "resumed", "");
}

#[tauri::command]
pub fn cmd_mapping_toggle(
    state: tauri::State<Arc<AppState>>,
    window: tauri::WebviewWindow,
    id: String,
    enabled: bool,
) {
    let mut disabled_ids = Vec::new();
    {
        let mut cfg = state.cfg.lock();
        if enabled {
            disabled_ids = cfg.enable_mapping(&id);
        } else {
            cfg.disable_mapping(&id);
        }
        cfg.normalize();
    }
    persist_and_rebind(&state, &window, "mapping_toggled");
    let ack = serde_json::json!({
        "type": "mvp_mapping_toggled",
        "ok": true,
        "id": id,
        "enabled": enabled,
        "autoDisabled": disabled_ids,
    });
    window.emit("to_js", &ack).ok();
}

#[tauri::command]
pub fn cmd_mapping_delete(
    state: tauri::State<Arc<AppState>>,
    window: tauri::WebviewWindow,
    id: String,
) {
    let mut cfg = state.cfg.lock();
    if cfg.mappings.len() <= 1 {
        let ack = serde_json::json!({"type":"mvp_mapping_delete","ok":false,"reason":"last_mapping"});
        window.emit("to_js", &ack).ok();
        return;
    }
    cfg.mappings.retain(|m| m.id != id);
    cfg.normalize();
    drop(cfg);
    persist_and_rebind(&state, &window, "mapping_deleted");
    let ack = serde_json::json!({"type":"mvp_mapping_delete","ok":true,"id":id});
    window.emit("to_js", &ack).ok();
}

#[tauri::command]
pub fn cmd_mapping_duplicate(
    state: tauri::State<Arc<AppState>>,
    window: tauri::WebviewWindow,
    id: String,
) {
    let mut new_id = String::new();
    {
        let mut cfg = state.cfg.lock();
        if let Some(src) = cfg.mappings.iter().find(|m| m.id == id).cloned() {
            new_id = new_mapping_id();
            let order = cfg.mappings.len() as u32;
            cfg.mappings.push(MappingEntry {
                id: new_id.clone(),
                label: format!("{}（副本）", src.display_label()),
                group: src.group,
                trigger_key: src.trigger_key,
                target_key: src.target_key,
                enabled: false,
                order,
                trigger_mode: src.trigger_mode,
                trigger_source: src.trigger_source,
            });
            cfg.normalize();
        }
    }
    persist_and_rebind(&state, &window, "mapping_duplicated");
    let ack = serde_json::json!({"type":"mvp_mapping_duplicated","ok":true,"id":new_id});
    window.emit("to_js", &ack).ok();
}

#[tauri::command]
pub fn cmd_mapping_reorder(
    state: tauri::State<Arc<AppState>>,
    window: tauri::WebviewWindow,
    ordered_ids: Vec<String>,
) {
    {
        let mut cfg = state.cfg.lock();
        for (i, oid) in ordered_ids.iter().enumerate() {
            if let Some(m) = cfg.mappings.iter_mut().find(|m| &m.id == oid) {
                m.order = i as u32;
            }
        }
        cfg.mappings.sort_by_key(|m| m.order);
    }
    persist_and_rebind(&state, &window, "mapping_reordered");
}

#[tauri::command]
pub fn cmd_mapping_set_group(
    state: tauri::State<Arc<AppState>>,
    window: tauri::WebviewWindow,
    id: String,
    group: String,
) {
    {
        let mut cfg = state.cfg.lock();
        if let Some(m) = cfg.mappings.iter_mut().find(|m| m.id == id) {
            m.group = if group.trim().is_empty() {
                "默认".into()
            } else {
                group
            };
        }
    }
    persist_and_rebind(&state, &window, "mapping_group_set");
}

#[tauri::command]
pub fn cmd_request_runtime(state: tauri::State<Arc<AppState>>, window: tauri::WebviewWindow) {
    push_runtime(&state, &window, "runtime_refresh", "");
}

#[tauri::command]
pub fn cmd_frontend_keydown(
    state: tauri::State<Arc<AppState>>,
    window: tauri::WebviewWindow,
    key: String,
    mapping_id: String,
    mode: String,
) {
    if !*state.recording.lock() {
        return;
    }
    if key.trim().is_empty() {
        return;
    }

    let is_target = mode == "target";
    if !is_target {
        let captured = normalize_record_key(&key);
        if !is_allowed_trigger(&captured) {
            let ack = serde_json::json!({
                "type": "mvp_record_rejected",
                "reason": "trigger_not_allowed",
                "key": captured,
            });
            window.emit("to_js", &ack).ok();
            return;
        }
        {
            let mut cfg = state.cfg.lock();
            if let Some(m) = cfg.mappings.iter_mut().find(|m| m.id == mapping_id) {
                m.trigger_key = captured.clone();
                m.label = format!("{} → {}", captured, m.target_key);
            }
            cfg.normalize();
        }
    } else {
        let mut cfg = state.cfg.lock();
        if let Some(m) = cfg.mappings.iter_mut().find(|m| m.id == mapping_id) {
            m.target_key = key.clone();
            m.label = format!("{} → {}", m.trigger_key, key);
        }
        cfg.normalize();
    }

    *state.recording.lock() = false;
    *state.recording_target.lock() = None;
    if let Some(ref mgr) = *state.hotkey_mgr.lock() {
        mgr.stop_recording();
    }
    persist_and_rebind(&state, &window, "recorded");

    let captured_key = if is_target {
        key
    } else {
        normalize_record_key(&key)
    };
    let ack = serde_json::json!({
        "type": "mvp_key_captured",
        "key": captured_key,
        "mappingId": mapping_id,
        "mode": mode,
    });
    window.emit("to_js", &ack).ok();
}

pub fn finish_hardware_capture(state: &AppState, window: &tauri::WebviewWindow, key: &str) {
    let target = state.recording_target.lock().clone();
    let Some(target) = target else {
        return;
    };

    if matches!(target.mode, RecordMode::Trigger) {
        let captured = normalize_record_key(key);
        if !is_allowed_trigger(&captured) {
            let ack = serde_json::json!({
                "type": "mvp_record_rejected",
                "reason": "trigger_not_allowed",
                "key": captured,
            });
            window.emit("to_js", &ack).ok();
            return;
        }
        {
            let mut cfg = state.cfg.lock();
            if let Some(m) = cfg.mappings.iter_mut().find(|m| m.id == target.mapping_id) {
                m.trigger_key = captured.clone();
                m.label = format!("{} → {}", captured, m.target_key);
            }
            cfg.normalize();
        }
    }

    *state.recording.lock() = false;
    *state.recording_target.lock() = None;
    if let Some(ref mgr) = *state.hotkey_mgr.lock() {
        mgr.stop_recording();
    }
    persist_and_rebind(state, window, "recorded");

    let ack = serde_json::json!({
        "type": "mvp_key_captured",
        "key": normalize_record_key(key),
        "mappingId": target.mapping_id,
        "mode": "trigger",
    });
    window.emit("to_js", &ack).ok();
}
