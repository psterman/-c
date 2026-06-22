mod config;
mod state;
mod keyboard;
mod ipc;

#[cfg(target_os = "windows")]
mod hotkey_win;

use parking_lot::Mutex;
use std::sync::Arc;
use std::time::Instant;
use tauri::{Manager, Emitter};
use tokio::time::{sleep, Duration};

pub struct AppState {
    pub cfg: Mutex<config::VoiceConfig>,
    pub machine: Mutex<state::StateMachine>,
    pub hotkey_mgr: Mutex<Option<hotkey_win::HotkeyManager>>,
    pub recording: Mutex<bool>,
    pub paused: Mutex<bool>,
}

fn normalize_trigger_key_name(key: &str) -> String {
    match key {
        "AudioVolumeUp" | "VolumeUp" | "Volume_Up" => "AutoTrigger".to_string(),
        "AudioVolumeDown" | "VolumeDown" | "Volume_Down" => "AutoTrigger".to_string(),
        "AudioVolumeMute" | "VolumeMute" | "Volume_Mute" => "AutoTrigger".to_string(),
        other => other.to_string(),
    }
}
pub fn run() {
    let app_state = Arc::new(AppState {
        cfg: Mutex::new(config::load_config()),
        machine: Mutex::new(state::StateMachine::new()),
        hotkey_mgr: Mutex::new(None),
        recording: Mutex::new(false),
        paused: Mutex::new(false),
    });

    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .manage(app_state.clone())
        .setup(move |app| {
            let window = app.get_webview_window("main").unwrap();

            // Init hotkey manager
            let mgr = hotkey_win::HotkeyManager::new();
            let bindings = app_state.cfg.lock().bindings();
            mgr.bind_all(&bindings);
            *app_state.hotkey_mgr.lock() = Some(mgr);

            // Push initial config to JS after a short delay
            let cfg = app_state.cfg.lock().clone();
            let json = serde_json::to_string(&cfg).unwrap();
            window.eval(&format!(
                "setTimeout(function(){{ window.__vp_bridge__('mvp_init', {{config:{}}}) }}, 300)",
                json
            )).ok();

            // Start file watcher for config hot-reload
            config::start_watcher(app_state.clone(), window.clone());

            // Background task: poll hotkey events → state machine → actions
            let state2 = app_state.clone();
            let win2 = window.clone();
            tauri::async_runtime::spawn(async move {
                loop {
                    sleep(Duration::from_millis(20)).await;
                    let key_name = {
                        let mgr_opt = state2.hotkey_mgr.lock();
                        mgr_opt.as_ref().and_then(|mgr| mgr.try_recv())
                    };

                    let Some(key_name) = key_name else {
                        continue;
                    };

                    let is_recording = *state2.recording.lock();
                    let is_paused = *state2.paused.lock();
                    if is_paused {
                        continue;
                    }
                    if is_recording {
                        let normalized_key = normalize_trigger_key_name(&key_name);
                        {
                            let mut cfg = state2.cfg.lock();
                            cfg.record_key = normalized_key.clone();
                            cfg.normalize();
                            config::save_config(&cfg);
                            if let Some(ref mgr) = *state2.hotkey_mgr.lock() {
                                mgr.stop_recording();
                                mgr.bind_all(&cfg.bindings());
                            }
                        }
                        *state2.recording.lock() = false;
                        let json = serde_json::json!({
                            "type": "mvp_key_captured",
                            "key": normalized_key
                        });
                        let key_js = serde_json::to_string(&normalized_key).unwrap_or_else(|_| "AutoTrigger".into());
                        win2.eval(&format!("window.__vp_bridge__('mvp_key_captured', {{key:{}}})", key_js)).ok();
                        win2.emit("to_js", &json).ok();
                        ipc::push_runtime(&state2, &win2, "recorded");
                        continue;
                    }

                    let now = Instant::now();
                    let cfg = state2.cfg.lock().clone();
                    let action = state2.machine.lock().trigger(&cfg, &key_name, now);

                    match action {
                                                state::Action::SendKey { key } => {
                            if key == "RAlt" {
                                keyboard::send_right_alt(cfg.key_press_duration_ms);
                            }
                            ipc::push_runtime(&state2, &win2, &key);
                        }
                        state::Action::SendEsc => {
                            keyboard::send_escape();
                            ipc::push_runtime(&state2, &win2, "esc");
                        }
                        state::Action::ScheduleEnter { delay_ms } => {
                            let s3 = state2.clone();
                            let w3 = win2.clone();
                            let d = delay_ms;
                            tauri::async_runtime::spawn(async move {
                                sleep(Duration::from_millis(d as u64)).await;
                                let action = s3.machine.lock().on_enter_timer();
                                if matches!(action, state::Action::SendEnter) {
                                    keyboard::send_enter();
                                    ipc::push_runtime(&s3, &w3, "enter");
                                }
                            });
                            ipc::push_runtime(&state2, &win2, "enter_scheduled");
                        }
                        state::Action::SendEnter => {
                            keyboard::send_enter();
                            ipc::push_runtime(&state2, &win2, "enter");
                        }
                        state::Action::None => {}
                    }
                }
            });

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            ipc::cmd_ready,
            ipc::cmd_save,
            ipc::cmd_start_recording,
            ipc::cmd_stop_recording,
            ipc::cmd_pause,
            ipc::cmd_resume,
            ipc::cmd_capture_source,
            ipc::cmd_request_runtime,
            ipc::cmd_frontend_keydown,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}




