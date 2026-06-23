use std::collections::{HashMap, HashSet};
use std::time::{Duration, Instant};

use crate::config::{canonical_trigger, MappingEntry, VoiceConfig};

#[derive(Debug, Clone)]
pub enum Action {
    SendKey { key: String },
    SendEsc,
    ScheduleEnter { delay_ms: u32 },
    SendEnter,
    None,
}

#[derive(Debug, Clone, serde::Serialize)]
pub struct RuntimeInfo {
    #[serde(rename = "count")]
    pub count: u32,
    #[serde(rename = "timerActive")]
    pub timer_active: bool,
    #[serde(rename = "lastAction")]
    pub last_action: String,
}

pub struct StateMachine {
    count: u32,
    last_tick: Option<Instant>,
    last_trigger: Option<Instant>,
    enter_timer_active: bool,
}

impl StateMachine {
    pub fn new() -> Self {
        Self {
            count: 0,
            last_tick: None,
            last_trigger: None,
            enter_timer_active: false,
        }
    }

    pub fn trigger(
        &mut self,
        cfg: &VoiceConfig,
        mapping: &MappingEntry,
        trigger_key: &str,
        now: Instant,
    ) -> Action {
        let debounce_ms = cfg.debounce_ms as u64;
        let reset_ms = cfg.interval_ms as u64;
        let normalized = canonical_trigger(trigger_key);
        let target = mapping.target_key.clone();

        if normalized == "AutoTrigger" {
            self.last_trigger = Some(now);
            self.last_tick = Some(now);
            self.count = 0;
            self.enter_timer_active = false;
            return Action::SendKey { key: target };
        }

        if let Some(last) = self.last_trigger {
            if now.duration_since(last) < Duration::from_millis(debounce_ms) {
                return Action::None;
            }
        }
        self.last_trigger = Some(now);

        let delta_ms = self
            .last_tick
            .map(|t| now.duration_since(t).as_millis() as u64)
            .unwrap_or(0);

        if cfg.cancel_enabled && self.last_tick.is_some() && delta_ms < reset_ms {
            self.enter_timer_active = false;
            self.count = 0;
            self.last_tick = Some(now);
            return Action::SendEsc;
        }

        self.count += 1;
        self.last_tick = Some(now);
        self.enter_timer_active = false;

        if cfg.auto_enter_enabled && self.count == 2 {
            self.enter_timer_active = true;
            return Action::ScheduleEnter {
                delay_ms: cfg.enter_delay_ms,
            };
        }

        if self.count >= 3 {
            self.count = 1;
        }

        Action::SendKey { key: target }
    }

    pub fn on_enter_timer(&mut self) -> Action {
        self.enter_timer_active = false;
        self.count = 0;
        self.last_tick = None;
        Action::SendEnter
    }

    pub fn reset(&mut self) {
        self.count = 0;
        self.last_tick = None;
        self.enter_timer_active = false;
    }

    pub fn runtime_info(&self) -> RuntimeInfo {
        RuntimeInfo {
            count: self.count,
            timer_active: self.enter_timer_active,
            last_action: String::new(),
        }
    }
}

pub struct StateMachinePool {
    machines: HashMap<String, StateMachine>,
}

impl StateMachinePool {
    pub fn new() -> Self {
        Self {
            machines: HashMap::new(),
        }
    }

    pub fn get_or_create(&mut self, mapping_id: &str) -> &mut StateMachine {
        self.machines
            .entry(mapping_id.to_string())
            .or_insert_with(StateMachine::new)
    }

    pub fn prune(&mut self, valid_ids: &HashSet<String>) {
        self.machines.retain(|id, _| valid_ids.contains(id));
    }

    pub fn reset_all(&mut self) {
        for sm in self.machines.values_mut() {
            sm.reset();
        }
    }

    pub fn any_timer_active(&self) -> bool {
        self.machines.values().any(|m| m.enter_timer_active)
    }
}
