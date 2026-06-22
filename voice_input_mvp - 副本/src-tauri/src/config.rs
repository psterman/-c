use notify::{Event, EventKind, RecursiveMode, Watcher};
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;
use std::sync::Arc;
use std::time::Duration;

use crate::AppState;

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct RawEvent {
    #[serde(default)]
    pub device: String,
    #[serde(default)]
    pub key: String,
    #[serde(default)]
    pub code: String,
    #[serde(default)]
    pub location: u32,
    #[serde(default, rename = "type")]
    pub event_type: String,
    #[serde(default)]
    pub hotkey: String,
    #[serde(default)]
    pub label: String,
    #[serde(default)]
    pub button: Option<u32>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct TriggerSource {
    #[serde(default)]
    pub id: String,
    #[serde(default)]
    pub label: String,
    #[serde(default)]
    pub mode: String,
    #[serde(default)]
    pub grouping: String,
    #[serde(default, rename = "rawEvents")]
    pub raw_events: Vec<RawEvent>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct ActionConfig {
    #[serde(default)]
    pub start: String,
    #[serde(default)]
    pub cancel: String,
    #[serde(default)]
    pub send: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct SceneConfig {
    #[serde(default)]
    pub id: String,
    #[serde(default)]
    pub label: String,
    #[serde(default)]
    pub enabled: bool,
    #[serde(default, rename = "overrideMode")]
    pub override_mode: String,
    #[serde(default, rename = "cancelWindowMs")]
    pub cancel_window_ms: u32,
    #[serde(default, rename = "sendDelayMs")]
    pub send_delay_ms: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VoiceConfig {
    #[serde(default = "default_version")]
    pub version: u32,
    #[serde(default = "default_record_key")]
    #[serde(rename = "recordKey")]
    pub record_key: String,
    #[serde(default = "default_interval_ms")]
    #[serde(rename = "intervalMs")]
    pub interval_ms: u32,
    #[serde(default = "default_enter_delay_ms")]
    #[serde(rename = "enterDelayMs")]
    pub enter_delay_ms: u32,
    #[serde(default = "default_true")]
    #[serde(rename = "cancelEnabled")]
    pub cancel_enabled: bool,
    #[serde(default = "default_true")]
    #[serde(rename = "autoEnterEnabled")]
    pub auto_enter_enabled: bool,
    #[serde(default = "default_debounce_ms")]
    #[serde(rename = "debounceMs")]
    pub debounce_ms: u32,
    #[serde(default = "default_key_press_duration_ms")]
    #[serde(rename = "keyPressDurationMs")]
    pub key_press_duration_ms: u32,
    #[serde(default = "default_target_key")]
    #[serde(rename = "targetKey")]
    pub target_key: String,
    #[serde(default, rename = "triggerSource")]
    pub trigger_source: Option<TriggerSource>,
    #[serde(default)]
    pub actions: Option<ActionConfig>,
    #[serde(default)]
    pub scenes: Option<Vec<SceneConfig>>,
}

fn default_version() -> u32 { 2 }
fn default_record_key() -> String { "RAlt".into() }
fn default_interval_ms() -> u32 { 1200 }
fn default_enter_delay_ms() -> u32 { 5000 }
fn default_true() -> bool { true }
fn default_debounce_ms() -> u32 { 80 }
fn default_key_press_duration_ms() -> u32 { 50 }
fn default_target_key() -> String { "RAlt".into() }

impl Default for VoiceConfig {
    fn default() -> Self {
        Self {
            version: default_version(),
            record_key: default_record_key(),
            interval_ms: default_interval_ms(),
            enter_delay_ms: default_enter_delay_ms(),
            cancel_enabled: true,
            auto_enter_enabled: true,
            debounce_ms: default_debounce_ms(),
            key_press_duration_ms: default_key_press_duration_ms(),
            target_key: default_target_key(),
            trigger_source: None,
            actions: None,
            scenes: None,
        }
    }
}

impl VoiceConfig {
    pub fn normalize(&mut self) {
        if self.interval_ms < 200 { self.interval_ms = 200; }
        if self.enter_delay_ms < 1000 { self.enter_delay_ms = 1000; }
        if self.record_key.is_empty() { self.record_key = "AutoTrigger".into(); }
        if self.target_key.is_empty() { self.target_key = "RAlt".into(); }
        if self.version == 0 { self.version = 2; }
    }

    pub fn output_for_trigger(&self, trigger_key: &str) -> String {
        if let Some(actions) = &self.actions {
            if !actions.start.is_empty() && (trigger_key == "AutoTrigger" || trigger_key == self.record_key) {
                return actions.start.clone();
            }
        }
        match self.record_key.as_str() {
            "AutoTrigger" => self.target_key.clone(),
            "RAlt" => "RAlt".into(),
            other => other.to_string(),
        }
    }

    pub fn bindings(&self) -> Vec<String> {
        if let Some(src) = &self.trigger_source {
            let mut out = Vec::new();
            for raw in &src.raw_events {
                if !raw.hotkey.is_empty() && !out.iter().any(|v| v == &raw.hotkey) {
                    out.push(raw.hotkey.clone());
                }
            }
            if !out.is_empty() {
                return out;
            }
        }
        match self.record_key.as_str() {
            "AutoTrigger" => vec!["Volume_Up".into(), "Volume_Down".into()],
            "Volume_Up" | "Volume_Down" | "Volume_Mute" => vec!["Volume_Up".into(), "Volume_Down".into()],
            other => vec![other.to_string()],
        }
    }
}

pub fn config_path() -> PathBuf {
    let exe_dir = std::env::current_exe()
        .ok()
        .and_then(|p| p.parent().map(|p| p.to_path_buf()))
        .unwrap_or_else(|| PathBuf::from("."));
    let candidates = vec![
        exe_dir.join("voice_input_settings.json"),
        PathBuf::from("voice_input_settings.json"),
        PathBuf::from("../voice_input_settings.json"),
    ];
    for p in &candidates {
        if p.exists() {
            return p.clone();
        }
    }
    candidates[0].clone()
}

pub fn load_config() -> VoiceConfig {
    let path = config_path();
    match fs::read_to_string(&path) {
        Ok(raw) => serde_json::from_str::<VoiceConfig>(&raw).unwrap_or_default(),
        Err(_) => {
            let cfg = VoiceConfig::default();
            let json = serde_json::to_string_pretty(&cfg).unwrap();
            fs::write(&path, json).ok();
            cfg
        }
    }
}

pub fn save_config(cfg: &VoiceConfig) {
    let path = config_path();
    let json = serde_json::to_string_pretty(cfg).unwrap();
    fs::write(&path, json).ok();
}

pub fn start_watcher(state: Arc<AppState>, window: tauri::WebviewWindow) {
    let path = config_path();
    std::thread::spawn(move || {
        let (tx, rx) = std::sync::mpsc::channel();
        let mut watcher = notify::recommended_watcher(move |res: Result<Event, notify::Error>| {
            if let Ok(event) = res {
                if matches!(event.kind, EventKind::Modify(_)) {
                    tx.send(()).ok();
                }
            }
        }).ok();

        if let Some(w) = &mut watcher {
            if let Some(parent) = path.parent() {
                w.watch(parent, RecursiveMode::NonRecursive).ok();
            }
            loop {
                if rx.recv_timeout(Duration::from_millis(500)).is_ok() {
                    let new_cfg = load_config();
                    let mut cfg = state.cfg.lock();
                    *cfg = new_cfg.clone();
                    if let Some(ref mgr) = *state.hotkey_mgr.lock() {
                        mgr.bind_all(&new_cfg.bindings());
                    }
                    let json = serde_json::to_string(&new_cfg).unwrap();
                    window.eval(&format!("window.__vp_bridge__('mvp_init', {{config:{}}})", json)).ok();
                }
            }
        }
    });
}






