# Legacy AHK Build

This folder keeps the AutoHotkey-based version separate from the main Tauri app.

- `launch_voice_input_manager.ahk`: old standalone launcher and UI
- `html/`: AHK UI assets used by the legacy launcher
- `lib/ahk/`: bundled AHK helper libraries

The main supported launcher for this project is still:

- `Start-VoicePilot.vbs` -> `run_voice_pilot.ps1` -> Tauri app

Use this folder only if you need to inspect or compare the older AHK flow.
