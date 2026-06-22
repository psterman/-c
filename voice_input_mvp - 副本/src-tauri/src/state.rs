use std::time::{Duration, Instant};

/// State machine result: what action to perform after a trigger.
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
        cfg: &super::config::VoiceConfig,
        trigger_key: &str,
        now: Instant,
    ) -> Action {
        let debounce_ms = cfg.debounce_ms as u64;
        let reset_ms = cfg.interval_ms as u64;
        let normalized_trigger = match trigger_key {
            "Volume_Up" | "Volume_Down" | "Volume_Mute" |
            "AudioVolumeUp" | "AudioVolumeDown" | "AudioVolumeMute" => "AutoTrigger",
            other => other,
        };

        if normalized_trigger == "AutoTrigger" {
            self.last_trigger = Some(now);
            self.last_tick = Some(now);
            self.count = 0;
            self.enter_timer_active = false;
            return Action::SendKey { key: cfg.output_for_trigger(normalized_trigger) };
        }

        if let Some(last) = self.last_trigger {
            if now.duration_since(last) < Duration::from_millis(debounce_ms) {
                return Action::None;
            }
        }
        self.last_trigger = Some(now);

        let delta_ms = self.last_tick
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
            return Action::ScheduleEnter { delay_ms: cfg.enter_delay_ms };
        }

        if self.count >= 3 {
            self.count = 1;
        }

        Action::SendKey { key: cfg.output_for_trigger(normalized_trigger) }
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
