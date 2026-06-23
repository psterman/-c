mod config;
mod state;
mod key_chord;
mod keyboard;
mod send_guard;
mod ipc;
mod backdrop;

#[cfg(target_os = "windows")]
mod hotkey_win;

use parking_lot::Mutex;
use std::sync::Arc;
use std::time::Instant;
use tauri::Manager;
use tokio::time::{sleep, Duration};

use crate::config::{load_config, VoiceConfig};
use crate::ipc::RecordingTarget;
use crate::state::StateMachinePool;

pub struct AppState {
    pub cfg: Mutex<VoiceConfig>,
    pub machine_pool: Mutex<StateMachinePool>,
    pub hotkey_mgr: Mutex<Option<hotkey_win::HotkeyManager>>,
    pub recording: Mutex<bool>,
    pub recording_target: Mutex<Option<RecordingTarget>>,
    pub paused: Mutex<bool>,
}

pub fn run() {
    let mut initial = load_config();
    initial.migrate();

    let app_state = Arc::new(AppState {
        cfg: Mutex::new(initial),
        machine_pool: Mutex::new(StateMachinePool::new()),
        hotkey_mgr: Mutex::new(None),
        recording: Mutex::new(false),
        recording_target: Mutex::new(None),
        paused: Mutex::new(false),
    });

    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .manage(app_state.clone())
        .setup(move |app| {
            let window = app.get_webview_window("main").unwrap();

            let backdrop_mode = backdrop::apply_native_backdrop(&window, None);

            let mgr = hotkey_win::HotkeyManager::new();
            let bindings = app_state.cfg.lock().bindings();
            mgr.bind_all(&bindings);
            *app_state.hotkey_mgr.lock() = Some(mgr);

            let json = ipc::mvp_init_json(&app_state, &backdrop_mode);
            window
                .eval(&format!(
                    "setTimeout(function(){{ window.__vp_bridge__('mvp_init', {json}) }}, 300)",
                ))
                .ok();

            config::start_watcher(app_state.clone(), window.clone());

            let state2 = app_state.clone();
            let win2 = window.clone();
            tauri::async_runtime::spawn(async move {
                loop {
                    sleep(Duration::from_millis(20)).await;

                    if crate::send_guard::is_active() {
                        continue;
                    }

                    let key_name = {
                        let mgr_opt = state2.hotkey_mgr.lock();
                        mgr_opt.as_ref().and_then(|mgr| mgr.try_recv())
                    };

                    let Some(key_name) = key_name else {
                        continue;
                    };

                    if *state2.paused.lock() {
                        continue;
                    }

                    if *state2.recording.lock() {
                        ipc::finish_hardware_capture(&state2, &win2, &key_name);
                        continue;
                    }

                    let now = Instant::now();
                    let (mapping_id, duration_ms, action) = {
                        let cfg = state2.cfg.lock();
                        let Some(mapping) = cfg.find_mapping_by_physical(&key_name) else {
                            continue;
                        };
                        let mapping_id = mapping.id.clone();
                        let duration_ms = cfg.key_press_duration_ms;
                        let action = state2
                            .machine_pool
                            .lock()
                            .get_or_create(&mapping_id)
                            .trigger(&cfg, mapping, &key_name, now);
                        (mapping_id, duration_ms, action)
                    };

                    match action {
                        state::Action::SendKey { key } => {
                            let sent = keyboard::send_chord(&key, duration_ms);
                            let label = if sent { key.as_str() } else { "send_failed" };
                            ipc::push_runtime(&state2, &win2, label, &mapping_id);
                        }
                        state::Action::SendEsc => {
                            keyboard::send_escape();
                            ipc::push_runtime(&state2, &win2, "esc", &mapping_id);
                        }
                        state::Action::ScheduleEnter { delay_ms } => {
                            let s3 = state2.clone();
                            let w3 = win2.clone();
                            let mid = mapping_id.clone();
                            let d = delay_ms;
                            tauri::async_runtime::spawn(async move {
                                sleep(Duration::from_millis(d as u64)).await;
                                let action = s3.machine_pool.lock().get_or_create(&mid).on_enter_timer();
                                if matches!(action, state::Action::SendEnter) {
                                    keyboard::send_enter();
                                    ipc::push_runtime(&s3, &w3, "enter", &mid);
                                }
                            });
                            ipc::push_runtime(&state2, &win2, "enter_scheduled", &mapping_id);
                        }
                        state::Action::SendEnter => {
                            keyboard::send_enter();
                            ipc::push_runtime(&state2, &win2, "enter", &mapping_id);
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
            ipc::cmd_request_runtime,
            ipc::cmd_frontend_keydown,
            ipc::cmd_mapping_toggle,
            ipc::cmd_mapping_delete,
            ipc::cmd_mapping_duplicate,
            ipc::cmd_mapping_reorder,
            ipc::cmd_mapping_set_group,
            ipc::cmd_mapping_conflicts,
            ipc::cmd_window_minimize,
            ipc::cmd_window_close,
            ipc::cmd_sync_theme_backdrop,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
