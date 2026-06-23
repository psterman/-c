use std::collections::HashMap;
use std::sync::mpsc;
use std::sync::{Mutex, OnceLock};
use std::thread;

macro_rules! w {
    ($s:expr) => {{
        let v: Vec<u16> = $s.encode_utf16().chain(std::iter::once(0)).collect();
        v.as_ptr()
    }};
}

use crate::send_guard;
use winapi::shared::minwindef::{UINT, WPARAM, LPARAM, LRESULT};
use winapi::shared::windef::HWND;
use winapi::um::winuser::{
    self, RegisterHotKey, UnregisterHotKey, CreateWindowExW, DefWindowProcW,
    TranslateMessage, DispatchMessageW,
    MSG, WNDCLASSEXW, WM_HOTKEY, WM_DESTROY, CS_HREDRAW, CS_VREDRAW,
    MOD_NOREPEAT, SetWindowsHookExW, UnhookWindowsHookEx, CallNextHookEx,
    WH_KEYBOARD_LL, KBDLLHOOKSTRUCT, WM_KEYDOWN, WM_SYSKEYDOWN,
    RegisterRawInputDevices, RAWINPUTDEVICE, RIDEV_INPUTSINK, WM_INPUT,
    GetRawInputData, RAWINPUT, RID_INPUT, WM_APPCOMMAND,
    GET_APPCOMMAND_LPARAM, APPCOMMAND_VOLUME_UP,
    APPCOMMAND_VOLUME_DOWN, APPCOMMAND_VOLUME_MUTE, APPCOMMAND_MEDIA_NEXTTRACK,
    APPCOMMAND_MEDIA_PREVIOUSTRACK, APPCOMMAND_MEDIA_PLAY_PAUSE,
    APPCOMMAND_MEDIA_STOP, APPCOMMAND_BROWSER_BACKWARD, APPCOMMAND_BROWSER_FORWARD,
    APPCOMMAND_BROWSER_REFRESH, APPCOMMAND_LAUNCH_MAIL, APPCOMMAND_LAUNCH_APP1,
    APPCOMMAND_LAUNCH_APP2,
};

struct WndCtx {
    tx: mpsc::Sender<String>,
    names: HashMap<u32, String>,
    next_id: u32,
}

static RECORDING_SENDER: OnceLock<Mutex<Option<mpsc::Sender<String>>>> = OnceLock::new();
static RECORDING_HOOK: OnceLock<Mutex<isize>> = OnceLock::new();
static ACTIVE_BINDINGS: OnceLock<Mutex<Vec<String>>> = OnceLock::new();
static ACTIVE_SENDER: OnceLock<Mutex<Option<mpsc::Sender<String>>>> = OnceLock::new();

enum Cmd {
    BindAll(Vec<String>),
    StartRecording,
    StopRecording,
    Shutdown,
}

fn recording_sender() -> &'static Mutex<Option<mpsc::Sender<String>>> {
    RECORDING_SENDER.get_or_init(|| Mutex::new(None))
}

fn recording_hook() -> &'static Mutex<isize> {
    RECORDING_HOOK.get_or_init(|| Mutex::new(0))
}

fn active_bindings() -> &'static Mutex<Vec<String>> {
    ACTIVE_BINDINGS.get_or_init(|| Mutex::new(Vec::new()))
}

fn active_sender() -> &'static Mutex<Option<mpsc::Sender<String>>> {
    ACTIVE_SENDER.get_or_init(|| Mutex::new(None))
}

fn key_to_vk(name: &str) -> Option<UINT> {
    match name {
        "Volume_Up" => Some(0xAF),
        "Volume_Down" => Some(0xAE),
        "Volume_Mute" => Some(0xAD),
        "Media_Next" => Some(0xB0),
        "Media_Prev" => Some(0xB1),
        "Media_Play_Pause" => Some(0xB3),
        "Media_Stop" => Some(0xB2),
        "RAlt" => Some(0xA5),
        "RControl" => Some(0xA3),
        "AppsKey" => Some(0x5D),
        "Browser_Back" => Some(0xA6),
        "Browser_Forward" => Some(0xA7),
        "Browser_Refresh" => Some(0xA8),
        "Launch_Mail" => Some(0xB4),
        "Launch_App1" => Some(0xB6),
        "Launch_App2" => Some(0xB7),
        "F13" => Some(0x7C), "F14" => Some(0x7D),
        "F15" => Some(0x7E), "F16" => Some(0x7F),
        "F17" => Some(0x80), "F18" => Some(0x81),
        "F19" => Some(0x82), "F20" => Some(0x83),
        "CapsLock" => Some(0x14),
        "F1" => Some(0x70), "F2" => Some(0x71), "F3" => Some(0x72), "F4" => Some(0x73),
        "F5" => Some(0x74), "F6" => Some(0x75), "F7" => Some(0x76), "F8" => Some(0x77),
        "F9" => Some(0x78), "F10" => Some(0x79), "F11" => Some(0x7A), "F12" => Some(0x7B),
        _ => None,
    }
}

const RECORD_KEYS: &[&str] = &[
    "Volume_Up", "Volume_Down", "Volume_Mute",
    "Media_Next", "Media_Prev", "Media_Play_Pause", "Media_Stop",
    "Browser_Back", "Browser_Forward", "Browser_Refresh",
    "Launch_App1", "Launch_App2", "Launch_Mail",
    "RAlt", "RControl", "AppsKey",
    "F13", "F14", "F15", "F16", "F17", "F18", "F19", "F20",
];

pub struct HotkeyManager {
    cmd_tx: mpsc::Sender<Cmd>,
    event_rx: mpsc::Receiver<String>,
}

impl HotkeyManager {
    pub fn new() -> Self {
        let (cmd_tx, cmd_rx) = mpsc::channel::<Cmd>();
        let (event_tx, event_rx) = mpsc::channel::<String>();
        thread::spawn(move || hotkey_thread(cmd_rx, event_tx));
        Self { cmd_tx, event_rx }
    }

    pub fn bind_all(&self, bindings: &[String]) {
        self.cmd_tx.send(Cmd::BindAll(bindings.to_vec())).ok();
    }

    pub fn start_recording(&self) {
        self.cmd_tx.send(Cmd::StartRecording).ok();
    }

    pub fn stop_recording(&self) {
        self.cmd_tx.send(Cmd::StopRecording).ok();
    }

    pub fn try_recv(&self) -> Option<String> {
        self.event_rx.try_recv().ok()
    }
}

impl Drop for HotkeyManager {
    fn drop(&mut self) {
        self.cmd_tx.send(Cmd::Shutdown).ok();
    }
}

fn hotkey_thread(cmd_rx: mpsc::Receiver<Cmd>, event_tx: mpsc::Sender<String>) {
    let _class_name = unsafe { winapi::um::winuser::RegisterClassExW(&WNDCLASSEXW {
        cbSize: std::mem::size_of::<WNDCLASSEXW>() as UINT,
        style: CS_HREDRAW | CS_VREDRAW,
        lpfnWndProc: Some(wnd_proc),
        hInstance: std::ptr::null_mut(),
        lpszClassName: w!("VoicePilotHotkey"),
        cbClsExtra: 0,
        cbWndExtra: 0,
        hIcon: std::ptr::null_mut(),
        hCursor: std::ptr::null_mut(),
        hbrBackground: std::ptr::null_mut(),
        lpszMenuName: std::ptr::null(),
        hIconSm: std::ptr::null_mut(),
    }) };

    let hwnd = unsafe {
        CreateWindowExW(
            0,
            w!("VoicePilotHotkey"),
            w!("VP"),
            0, 0, 0, 0, 0,
            winuser::HWND_MESSAGE,
            std::ptr::null_mut(),
            std::ptr::null_mut(),
            std::ptr::null_mut(),
        )
    };
    if hwnd.is_null() {
        return;
    }

    let mut ctx = Box::new(WndCtx {
        tx: event_tx.clone(),
        names: HashMap::new(),
        next_id: 1,
    });
    let ctx_ptr: *mut WndCtx = &mut *ctx;

    *active_sender().lock().unwrap() = Some(event_tx.clone());

    let mut recording_mode = false;

    unsafe fn register(ctx: *mut WndCtx, hwnd: HWND, name: &str) -> Option<u32> {
        let vk = key_to_vk(name)?;
        let id = (*ctx).next_id;
        let ok = RegisterHotKey(hwnd, id as i32, MOD_NOREPEAT as u32, vk) != 0;
        if ok {
            (*ctx).names.insert(id, name.to_string());
            (*ctx).next_id += 1;
            Some(id)
        } else {
            None
        }
    }

    unsafe fn unregister_all(ctx: *mut WndCtx, hwnd: HWND) {
        for &id in (*ctx).names.keys() {
            UnregisterHotKey(hwnd, id as i32);
        }
        (*ctx).names.clear();
    }

    unsafe fn register_list(ctx: *mut WndCtx, hwnd: HWND, keys: &[String]) {
        unregister_all(ctx, hwnd);
        for name in keys {
            register(ctx, hwnd, name);
        }
    }

    unsafe {
        winuser::SetWindowLongPtrW(hwnd, winuser::GWLP_USERDATA, ctx_ptr as isize);
    }

    let mut msg: MSG = unsafe { std::mem::zeroed() };
    loop {
        while let Ok(cmd) = cmd_rx.try_recv() {
            match cmd {
                Cmd::BindAll(bindings) => {
                    *active_bindings().lock().unwrap() = bindings.clone();
                    unsafe { install_keyboard_hook(); }
                    if !recording_mode {
                        unsafe { register_list(ctx_ptr, hwnd, &bindings); }
                    }
                }
                Cmd::StartRecording => {
                    recording_mode = true;
                    *recording_sender().lock().unwrap() = Some(event_tx.clone());
                    unsafe { install_raw_input(hwnd); }
                    unsafe { install_keyboard_hook(); }
                }
                Cmd::StopRecording => {
                    recording_mode = false;
                    *recording_sender().lock().unwrap() = None;
                    unsafe { remove_raw_input(); }
                    unsafe { remove_keyboard_hook(); }
                }
                Cmd::Shutdown => {
                    unsafe {
                        unregister_all(ctx_ptr, hwnd);
                        remove_raw_input();
                        remove_keyboard_hook();
                        winuser::DestroyWindow(hwnd);
                    }
                    return;
                }
            }
        }

        let has_msg = unsafe { winuser::PeekMessageW(&mut msg, hwnd, 0, 0, winuser::PM_REMOVE) != 0 };
        if has_msg {
            if msg.message == winuser::WM_QUIT {
                break;
            }
            unsafe {
                TranslateMessage(&msg);
                DispatchMessageW(&msg);
            }
        } else {
            std::thread::sleep(std::time::Duration::from_millis(10));
        }
    }
}

unsafe fn install_keyboard_hook() {
    let mut hook = recording_hook().lock().unwrap();
    if *hook != 0 {
        return;
    }
    let handle = SetWindowsHookExW(WH_KEYBOARD_LL, Some(keyboard_proc), std::ptr::null_mut(), 0);
    *hook = handle as isize;
}

unsafe fn install_raw_input(hwnd: HWND) {
    let rid = RAWINPUTDEVICE {
        usUsagePage: 0x01,
        usUsage: 0x06,
        dwFlags: RIDEV_INPUTSINK,
        hwndTarget: hwnd,
    };
    RegisterRawInputDevices(&rid, 1, std::mem::size_of::<RAWINPUTDEVICE>() as u32);
}

unsafe fn remove_raw_input() {
    let rid = RAWINPUTDEVICE {
        usUsagePage: 0x01,
        usUsage: 0x06,
        dwFlags: 0,
        hwndTarget: std::ptr::null_mut(),
    };
    RegisterRawInputDevices(&rid, 1, std::mem::size_of::<RAWINPUTDEVICE>() as u32);
}

unsafe fn remove_keyboard_hook() {
    let mut hook = recording_hook().lock().unwrap();
    if *hook != 0 {
        UnhookWindowsHookEx(*hook as *mut _);
        *hook = 0;
    }
}

const LLKHF_INJECTED: u32 = 0x10;

unsafe extern "system" fn keyboard_proc(code: i32, wparam: WPARAM, lparam: LPARAM) -> LRESULT {
    if send_guard::is_active() {
        return CallNextHookEx(std::ptr::null_mut(), code, wparam, lparam);
    }
    if code >= 0 && (wparam == WM_KEYDOWN as usize || wparam == WM_SYSKEYDOWN as usize) {
        let kb = *(lparam as *const KBDLLHOOKSTRUCT);
        if kb.flags & LLKHF_INJECTED != 0 {
            return CallNextHookEx(std::ptr::null_mut(), code, wparam, lparam);
        }
        if let Some(name) = vk_to_name(kb.vkCode as u32) {
            let should_swallow = active_bindings().lock().unwrap().iter().any(|v| v == &name);
            if let Some(sender) = recording_sender().lock().unwrap().as_ref() {
                sender.send(name.clone()).ok();
            } else if should_swallow {
                if let Some(sender) = active_sender().lock().unwrap().as_ref() {
                    sender.send(name.clone()).ok();
                }
            }
            if should_swallow {
                return 1;
            }
        }
    }
    CallNextHookEx(std::ptr::null_mut(), code, wparam, lparam)
}

fn vk_to_name(vk: u32) -> Option<String> {
    match vk {
        0xAE => Some("Volume_Down".into()),
        0xAF => Some("Volume_Up".into()),
        0xAD => Some("Volume_Mute".into()),
        0xB0 => Some("Media_Next".into()),
        0xB1 => Some("Media_Prev".into()),
        0xB2 => Some("Media_Stop".into()),
        0xB3 => Some("Media_Play_Pause".into()),
        0xA5 => Some("RAlt".into()),
        0xA3 => Some("RControl".into()),
        0x5D => Some("AppsKey".into()),
        0xA6 => Some("Browser_Back".into()),
        0xA7 => Some("Browser_Forward".into()),
        0xA8 => Some("Browser_Refresh".into()),
        0xB4 => Some("Launch_Mail".into()),
        0xB6 => Some("Launch_App1".into()),
        0xB7 => Some("Launch_App2".into()),
        0x7C..=0x83 => Some(format!("F{}", vk - 0x7C + 13)),
        0x14 => Some("CapsLock".into()),
        0x70..=0x7B => Some(format!("F{}", vk - 0x70 + 1)),
        _ => None,
    }
}

unsafe extern "system" fn wnd_proc(
    hwnd: HWND,
    msg: UINT,
    wparam: WPARAM,
    lparam: LPARAM,
) -> LRESULT {
    if msg == WM_INPUT {
        let mut size: u32 = 0;
        GetRawInputData(
            lparam as *mut _,
            RID_INPUT,
            std::ptr::null_mut(),
            &mut size,
            std::mem::size_of::<winapi::um::winuser::RAWINPUTHEADER>() as u32,
        );
        if size > 0 {
            let mut buf = vec![0u8; size as usize];
            if GetRawInputData(
                lparam as *mut _,
                RID_INPUT,
                buf.as_mut_ptr() as *mut _,
                &mut size,
                std::mem::size_of::<winapi::um::winuser::RAWINPUTHEADER>() as u32,
            ) == size
            {
                let raw = &*(buf.as_ptr() as *const RAWINPUT);
                if let Some(name) = raw_input_to_name(raw) {
                    if let Some(sender) = recording_sender().lock().unwrap().as_ref() {
                        sender.send(name).ok();
                    }
                }
            }
        }
        return 1;
    }

    if msg == WM_APPCOMMAND {
        let cmd = GET_APPCOMMAND_LPARAM(lparam as isize) as i32;
        if let Some(name) = appcommand_to_name(cmd) {
            let should_swallow = active_bindings().lock().unwrap().iter().any(|v| v == &name);
            if let Some(sender) = recording_sender().lock().unwrap().as_ref() {
                sender.send(name.clone()).ok();
            } else if should_swallow {
                if let Some(sender) = active_sender().lock().unwrap().as_ref() {
                    sender.send(name.clone()).ok();
                }
            }
            if should_swallow {
                return 1;
            }
        }
    }

    if msg == WM_HOTKEY {
        if send_guard::is_active() {
            return 1;
        }
        let id = wparam as u32;
        let ctx_ptr = winuser::GetWindowLongPtrW(hwnd, winuser::GWLP_USERDATA) as *mut WndCtx;
        if !ctx_ptr.is_null() {
            if let Some(name) = (*ctx_ptr).names.get(&id) {
                (*ctx_ptr).tx.send(name.clone()).ok();
            }
        }
        return 1;
    }

    if msg == WM_DESTROY {
        let ctx_ptr = winuser::GetWindowLongPtrW(hwnd, winuser::GWLP_USERDATA) as *mut WndCtx;
        if !ctx_ptr.is_null() {
            drop(Box::from_raw(ctx_ptr));
        }
        winuser::PostQuitMessage(0);
        return 0;
    }

    DefWindowProcW(hwnd, msg, wparam, lparam)
}
fn raw_input_to_name(raw: &RAWINPUT) -> Option<String> {
    unsafe {
        if raw.header.dwType == winapi::um::winuser::RIM_TYPEKEYBOARD {
            let kb = raw.data.keyboard();
            return vk_to_name(kb.VKey as u32);
        }
    }
    None
}

fn appcommand_to_name(cmd: i32) -> Option<String> {
    match cmd {
        val if val == APPCOMMAND_VOLUME_UP as i32 => Some("Volume_Up".into()),
        val if val == APPCOMMAND_VOLUME_DOWN as i32 => Some("Volume_Down".into()),
        val if val == APPCOMMAND_VOLUME_MUTE as i32 => Some("Volume_Mute".into()),
        val if val == APPCOMMAND_MEDIA_NEXTTRACK as i32 => Some("Media_Next".into()),
        val if val == APPCOMMAND_MEDIA_PREVIOUSTRACK as i32 => Some("Media_Prev".into()),
        val if val == APPCOMMAND_MEDIA_PLAY_PAUSE as i32 => Some("Media_Play_Pause".into()),
        val if val == APPCOMMAND_MEDIA_STOP as i32 => Some("Media_Stop".into()),
        val if val == APPCOMMAND_BROWSER_BACKWARD as i32 => Some("Browser_Back".into()),
        val if val == APPCOMMAND_BROWSER_FORWARD as i32 => Some("Browser_Forward".into()),
        val if val == APPCOMMAND_BROWSER_REFRESH as i32 => Some("Browser_Refresh".into()),
        val if val == APPCOMMAND_LAUNCH_MAIL as i32 => Some("Launch_Mail".into()),
        val if val == APPCOMMAND_LAUNCH_APP1 as i32 => Some("Launch_App1".into()),
        val if val == APPCOMMAND_LAUNCH_APP2 as i32 => Some("Launch_App2".into()),
        _ => None,
    }
}


