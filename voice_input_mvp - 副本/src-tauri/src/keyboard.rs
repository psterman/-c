use winapi::um::winuser::{
    SendInput, INPUT, INPUT_KEYBOARD, KEYBDINPUT,
    KEYEVENTF_EXTENDEDKEY, KEYEVENTF_KEYUP, KEYEVENTF_SCANCODE,
    VK_ESCAPE, VK_RETURN, VK_RMENU,
};

fn send_vk(vk: u16, extended: bool, keyup: bool) {
    unsafe {
        let mut input = INPUT {
            type_: INPUT_KEYBOARD,
            u: std::mem::zeroed(),
        };
        *input.u.ki_mut() = KEYBDINPUT {
            wVk: vk,
            wScan: 0,
            dwFlags: (if extended { KEYEVENTF_EXTENDEDKEY } else { 0 })
                | (if keyup { KEYEVENTF_KEYUP } else { 0 }),
            time: 0,
            dwExtraInfo: 0,
        };
        let _ = SendInput(1, &mut input, std::mem::size_of::<INPUT>() as i32);
    }
}

fn send_scancode(scan: u16, extended: bool, keyup: bool) {
    unsafe {
        let mut input = INPUT {
            type_: INPUT_KEYBOARD,
            u: std::mem::zeroed(),
        };
        *input.u.ki_mut() = KEYBDINPUT {
            wVk: 0,
            wScan: scan,
            dwFlags: KEYEVENTF_SCANCODE
                | (if extended { KEYEVENTF_EXTENDEDKEY } else { 0 })
                | (if keyup { KEYEVENTF_KEYUP } else { 0 }),
            time: 0,
            dwExtraInfo: 0,
        };
        let _ = SendInput(1, &mut input, std::mem::size_of::<INPUT>() as i32);
    }
}

/// Match AHK's `{vkA5sc138}` as closely as possible.
pub fn send_right_alt(duration_ms: u32) {
    let hold_ms = duration_ms.max(120) as u64;

    // First use the virtual key path Windows expects for right Alt.
    send_vk(VK_RMENU as u16, true, false);
    std::thread::sleep(std::time::Duration::from_millis(hold_ms));
    send_vk(VK_RMENU as u16, true, true);

    // Then send the extended scan code path to mirror AHK's sc138.
    send_scancode(0x38, true, false);
    std::thread::sleep(std::time::Duration::from_millis(30));
    send_scancode(0x38, true, true);
}

pub fn send_escape() {
    send_vk(VK_ESCAPE as u16, false, false);
    send_vk(VK_ESCAPE as u16, false, true);
}

pub fn send_enter() {
    send_vk(VK_RETURN as u16, false, false);
    send_vk(VK_RETURN as u16, false, true);
}
