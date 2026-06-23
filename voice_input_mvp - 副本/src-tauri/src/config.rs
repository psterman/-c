use notify::{Event, EventKind, RecursiveMode, Watcher};
use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fs;
use std::path::PathBuf;
use std::sync::Arc;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use crate::AppState;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "lowercase")]
pub enum TriggerMode {
    #[default]
    Tap,
    Hold,
    Toggle,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MappingEntry {
    pub id: String,
    #[serde(default)]
    pub label: String,
    #[serde(default = "default_group")]
    pub group: String,
    #[serde(rename = "triggerKey", default)]
    pub trigger_key: String,
    #[serde(rename = "targetKey", default)]
    pub target_key: String,
    #[serde(default)]
    pub enabled: bool,
    #[serde(default)]
    pub order: u32,
    #[serde(rename = "triggerMode", default)]
    pub trigger_mode: TriggerMode,
    #[serde(rename = "triggerSource", default)]
    pub trigger_source: Option<TriggerSource>,
}

fn default_group() -> String {
    "默认".into()
}

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
    #[serde(default)]
    pub mappings: Vec<MappingEntry>,
    /// 已删除映射，仅在设置页回收站展示
    #[serde(default)]
    pub trash: Vec<MappingEntry>,
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
    #[serde(default)]
    pub scenes: Option<Vec<SceneConfig>>,
    // --- migrate-only (read, never serialize) ---
    #[serde(default, rename = "recordKey", skip_serializing)]
    pub record_key: String,
    #[serde(default, rename = "targetKey", skip_serializing)]
    pub target_key: String,
    #[serde(default, rename = "triggerSource", skip_serializing)]
    pub trigger_source: Option<TriggerSource>,
    #[serde(default, skip_serializing)]
    pub actions: Option<ActionConfig>,
}

fn default_version() -> u32 {
    3
}
fn default_interval_ms() -> u32 {
    1200
}
fn default_enter_delay_ms() -> u32 {
    5000
}
fn default_true() -> bool {
    true
}
fn default_debounce_ms() -> u32 {
    80
}
fn default_key_press_duration_ms() -> u32 {
    250
}

pub fn new_mapping_id() -> String {
    let ms = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis())
        .unwrap_or(0);
    format!("m-{ms}")
}

pub fn canonical_trigger(key: &str) -> String {
    match key {
        "Volume_Up" | "Volume_Down" | "Volume_Mute" | "AudioVolumeUp" | "AudioVolumeDown"
        | "AudioVolumeMute" => "AutoTrigger".into(),
        other => other.to_string(),
    }
}

pub fn is_allowed_trigger(key: &str) -> bool {
    !canonical_trigger(key).trim().is_empty()
}

pub fn physical_bindings(trigger_key: &str) -> Vec<String> {
    let c = canonical_trigger(trigger_key);
    if c == "AutoTrigger" {
        return vec!["Volume_Up".into(), "Volume_Down".into()];
    }
    if c == "Volume_Up" || c == "Volume_Down" || c == "Volume_Mute" {
        return vec![c];
    }
    vec![c]
}

impl Default for VoiceConfig {
    fn default() -> Self {
        let id = new_mapping_id();
        Self {
            version: 3,
            mappings: vec![MappingEntry {
                id,
                label: "AutoTrigger → RAlt".into(),
                group: default_group(),
                trigger_key: "AutoTrigger".into(),
                target_key: "RAlt".into(),
                enabled: true,
                order: 0,
                trigger_mode: TriggerMode::Tap,
                trigger_source: None,
            }],
            trash: vec![],
            interval_ms: default_interval_ms(),
            enter_delay_ms: default_enter_delay_ms(),
            cancel_enabled: true,
            auto_enter_enabled: true,
            debounce_ms: default_debounce_ms(),
            key_press_duration_ms: default_key_press_duration_ms(),
            scenes: None,
            record_key: String::new(),
            target_key: String::new(),
            trigger_source: None,
            actions: None,
        }
    }
}

impl MappingEntry {
    pub fn display_label(&self) -> String {
        if !self.label.is_empty() {
            return self.label.clone();
        }
        format!("{} → {}", self.trigger_key, self.target_key)
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ConflictKind {
    CanonicalTrigger,
    PhysicalKey,
}

#[derive(Debug, Clone)]
pub struct Conflict {
    pub kind: ConflictKind,
    pub other_id: String,
    pub detail: String,
}

#[derive(Debug, Clone, serde::Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ConflictReport {
    pub mapping_id: String,
    pub other_id: String,
    pub kind: String,
    pub detail: String,
}

impl ConflictKind {
    fn as_str(&self) -> &'static str {
        match self {
            ConflictKind::CanonicalTrigger => "canonical",
            ConflictKind::PhysicalKey => "physical",
        }
    }
}

impl VoiceConfig {
    pub fn migrate(&mut self) {
        if self.version >= 3 && !self.mappings.is_empty() {
            self.normalize();
            return;
        }

        if self.mappings.is_empty() {
            let trigger = if self.record_key.is_empty() {
                "AutoTrigger".into()
            } else {
                canonical_trigger(&self.record_key)
            };
            let target = if self.target_key.is_empty() {
                "RAlt".into()
            } else {
                self.target_key.clone()
            };
            self.mappings.push(MappingEntry {
                id: new_mapping_id(),
                label: format!("{trigger} → {target}"),
                group: default_group(),
                trigger_key: trigger,
                target_key: target,
                enabled: true,
                order: 0,
                trigger_mode: TriggerMode::Tap,
                trigger_source: self.trigger_source.clone(),
            });
        }

        self.version = 3;
        self.record_key.clear();
        self.target_key.clear();
        self.trigger_source = None;
        self.actions = None;
        self.normalize();
    }

    pub fn normalize(&mut self) {
        if self.interval_ms < 200 {
            self.interval_ms = 200;
        }
        if self.enter_delay_ms < 1000 {
            self.enter_delay_ms = 1000;
        }
        if self.mappings.is_empty() {
            *self = VoiceConfig::default();
        }
        for (i, m) in self.mappings.iter_mut().enumerate() {
            if m.id.is_empty() {
                m.id = new_mapping_id();
            }
            m.trigger_key = canonical_trigger(&m.trigger_key);
            if m.group.is_empty() {
                m.group = default_group();
            }
            m.order = i as u32;
            if m.target_key.is_empty() {
                m.target_key = "RAlt".into();
            }
        }
        self.mappings.sort_by_key(|m| m.order);
    }

    pub fn mapping_ids(&self) -> HashSet<String> {
        self.mappings.iter().map(|m| m.id.clone()).collect()
    }

    pub fn active_mappings(&self) -> Vec<&MappingEntry> {
        let mut out: Vec<_> = self.mappings.iter().filter(|m| m.enabled).collect();
        out.sort_by_key(|m| m.order);
        out
    }

    pub fn find_mapping_by_id(&self, id: &str) -> Option<&MappingEntry> {
        self.mappings.iter().find(|m| m.id == id)
    }

    pub fn find_mapping_by_physical(&self, physical_key: &str) -> Option<&MappingEntry> {
        let canonical = canonical_trigger(physical_key);
        for m in self.active_mappings() {
            if canonical_trigger(&m.trigger_key) == canonical {
                return Some(m);
            }
            for pb in physical_bindings(&m.trigger_key) {
                if pb == physical_key || pb == canonical {
                    return Some(m);
                }
            }
        }
        None
    }

    pub fn bindings(&self) -> Vec<String> {
        let mut out = Vec::new();
        for m in self.active_mappings() {
            if let Some(src) = &m.trigger_source {
                for raw in &src.raw_events {
                    if !raw.hotkey.is_empty() && !out.contains(&raw.hotkey) {
                        out.push(raw.hotkey.clone());
                    }
                }
                if !out.is_empty() {
                    continue;
                }
            }
            for pb in physical_bindings(&m.trigger_key) {
                if !out.contains(&pb) {
                    out.push(pb);
                }
            }
        }
        out
    }

    pub fn conflicts_on_enable(&self, id: &str) -> Vec<Conflict> {
        let Some(entry) = self.find_mapping_by_id(id) else {
            return vec![];
        };
        let canonical = canonical_trigger(&entry.trigger_key);
        let physical: HashSet<String> = physical_bindings(&entry.trigger_key).into_iter().collect();
        let mut conflicts = Vec::new();

        for other in self.mappings.iter().filter(|m| m.enabled && m.id != id) {
            let other_canonical = canonical_trigger(&other.trigger_key);
            if other_canonical == canonical {
                conflicts.push(Conflict {
                    kind: ConflictKind::CanonicalTrigger,
                    other_id: other.id.clone(),
                    detail: format!("{other_canonical} 已被「{}」占用", other.display_label()),
                });
            }
            for pb in physical_bindings(&other.trigger_key) {
                if physical.contains(&pb) {
                    conflicts.push(Conflict {
                        kind: ConflictKind::PhysicalKey,
                        other_id: other.id.clone(),
                        detail: format!("物理键 {pb} 已被「{}」占用", other.display_label()),
                    });
                    break;
                }
            }
        }
        conflicts
    }

    /// 启用映射；自动停用冲突项。返回被停用的 mapping id 列表。
    pub fn enable_mapping(&mut self, id: &str) -> Vec<String> {
        let conflicts = self.conflicts_on_enable(id);
        let mut disabled = Vec::new();
        for c in conflicts {
            if let Some(other) = self.mappings.iter_mut().find(|m| m.id == c.other_id) {
                if other.enabled {
                    other.enabled = false;
                    disabled.push(other.id.clone());
                }
            }
        }
        if let Some(entry) = self.mappings.iter_mut().find(|m| m.id == id) {
            entry.enabled = true;
        }
        disabled
    }

    pub fn disable_mapping(&mut self, id: &str) {
        if let Some(entry) = self.mappings.iter_mut().find(|m| m.id == id) {
            entry.enabled = false;
        }
    }

    /// 汇总所有「若启用将冲突」的映射对（与 `conflicts_on_enable` 对齐，去重）。
    pub fn conflict_report(&self) -> Vec<ConflictReport> {
        let mut seen = HashSet::new();
        let mut out = Vec::new();
        for m in &self.mappings {
            for c in self.conflicts_on_enable(&m.id) {
                let (a, b) = if m.id < c.other_id {
                    (m.id.as_str(), c.other_id.as_str())
                } else {
                    (c.other_id.as_str(), m.id.as_str())
                };
                let key = format!("{a}|{b}|{}", c.kind.as_str());
                if seen.insert(key) {
                    out.push(ConflictReport {
                        mapping_id: m.id.clone(),
                        other_id: c.other_id.clone(),
                        kind: c.kind.as_str().into(),
                        detail: c.detail.clone(),
                    });
                }
            }
        }
        out
    }

    pub fn conflicts_for_mapping(&self, id: &str) -> Vec<ConflictReport> {
        self.conflicts_on_enable(id)
            .into_iter()
            .map(|c| ConflictReport {
                mapping_id: id.to_string(),
                other_id: c.other_id,
                kind: c.kind.as_str().into(),
                detail: c.detail,
            })
            .collect()
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
    let mut cfg = match fs::read_to_string(&path) {
        Ok(raw) => serde_json::from_str::<VoiceConfig>(&raw).unwrap_or_default(),
        Err(_) => VoiceConfig::default(),
    };
    cfg.migrate();
    cfg
}

pub fn save_config(cfg: &VoiceConfig) {
    let path = config_path();
    let json = serde_json::to_string_pretty(cfg).unwrap();
    fs::write(&path, json).ok();
}

pub fn apply_config(state: &AppState, cfg: &VoiceConfig) {
    if let Some(ref mgr) = *state.hotkey_mgr.lock() {
        mgr.bind_all(&cfg.bindings());
    }
    state.machine_pool.lock().prune(&cfg.mapping_ids());
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
        })
        .ok();

        if let Some(w) = &mut watcher {
            if let Some(parent) = path.parent() {
                w.watch(parent, RecursiveMode::NonRecursive).ok();
            }
            loop {
                if rx.recv_timeout(Duration::from_millis(500)).is_ok() {
                    let mut new_cfg = load_config();
                    new_cfg.migrate();
                    apply_config(&state, &new_cfg);
                    *state.cfg.lock() = new_cfg.clone();
                    let conflicts = new_cfg.conflict_report();
                    let payload = serde_json::json!({
                        "config": new_cfg,
                        "conflicts": conflicts,
                    });
                    let json = serde_json::to_string(&payload).unwrap();
                    window
                        .eval(&format!(
                            "window.__vp_bridge__('mvp_init', {json})"
                        ))
                        .ok();
                }
            }
        }
    });
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn migrate_v2_to_v3() {
        let mut cfg = VoiceConfig {
            version: 2,
            record_key: "AutoTrigger".into(),
            target_key: "F2".into(),
            mappings: vec![],
            ..Default::default()
        };
        cfg.migrate();
        assert_eq!(cfg.version, 3);
        assert_eq!(cfg.mappings.len(), 1);
        assert_eq!(cfg.mappings[0].trigger_key, "AutoTrigger");
        assert_eq!(cfg.mappings[0].target_key, "F2");
    }

    #[test]
    fn physical_conflict_autotrigger_vs_volume_down() {
        let mut cfg = VoiceConfig::default();
        cfg.mappings.push(MappingEntry {
            id: "a".into(),
            label: String::new(),
            group: "默认".into(),
            trigger_key: "Volume_Down".into(),
            target_key: "F2".into(),
            enabled: true,
            order: 1,
            trigger_mode: TriggerMode::Tap,
            trigger_source: None,
        });
        let conflicts = cfg.conflicts_on_enable(&cfg.mappings[0].id);
        assert!(conflicts.iter().any(|c| matches!(c.kind, ConflictKind::PhysicalKey)));
    }

    #[test]
    fn enable_disables_conflicts() {
        let mut cfg = VoiceConfig::default();
        let id_a = cfg.mappings[0].id.clone();
        cfg.mappings.push(MappingEntry {
            id: "b".into(),
            label: String::new(),
            group: "默认".into(),
            trigger_key: "AutoTrigger".into(),
            target_key: "F2".into(),
            enabled: false,
            order: 1,
            trigger_mode: TriggerMode::Tap,
            trigger_source: None,
        });
        cfg.enable_mapping("b");
        assert!(!cfg.mappings.iter().find(|m| m.id == id_a).unwrap().enabled);
        assert!(cfg.mappings.iter().find(|m| m.id == "b").unwrap().enabled);
    }
}
