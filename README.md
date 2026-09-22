# Queue Display Kiosk Controller

A Windows kiosk application built with **AutoIt** that manages hospital queue displays. It orchestrates Chrome browser windows to show multiple web pages side-by-side, with optional local video overlays.

## Features

- 🖥️ **Multiple Display Modes**
  - `dual_url` — Two queue URLs side-by-side (50%/50%)
  - `single_url` — One URL fills the entire screen
  - `video_left` — Local video (40%) + URL (60%)
  - `video_right` — URL (60%) + local video (40%)
- ⚡ **AutoHotkey-style hotkeys** for control during operation
- 🔄 **Crash recovery** — automatically restarts browser windows if they crash
- 🔇 **Mute toggle** — F9 to mute/unmute audio
- 🚀 **Kiosk-ready** — auto-starts in fullscreen, hides controls

## Project Structure

```
queue_kiosk/
├── launcher.au3        ← Main AutoIt script (kiosk controller)
├── config.ini          ← Your settings (NOT in git — see .gitignore)
├── config.ini.example  ← Template configuration
├── run_display.bat     ← Windows batch launcher
├── README.md           ← This file
├── requirements.txt    ← Python deps (for web backend only)
├── main.py             ← Flask/FastHTML backend (legacy)
├── video_queue_dashboard.html ← Standalone HTML dashboard
├── examples/           ← Reference implementations
└── lib/                ← Future helper modules
```

## Prerequisites

1. **Windows** (tested on Windows 10/11)
2. **Google Chrome** installed
3. **AutoIt** (optional — for compiling; you can also run `.au3` directly)
   - Download: https://www.autoitscript.com/site/autoit/downloads/

## Setup

### Step 1: Install dependencies
```bash
pip install -r requirements.txt
python -m playwright install chromium  # Only needed for Python backend
```

### Step 2: Configure
```bash
cp config.ini.example config.ini
# Edit config.ini with your clinic's URLs and settings:
notepad config.ini
```

### Step 3: Add video (optional)
Place your looping video in the project root as `video.mp4`, or set `VideoFile=` in `config.ini`.

### Step 4: Run
- **Testing:** Double-click `launcher.au3` in Explorer
- **Compiled:** Compile with AutoIt3Wrapper then run the `.exe`
- **Batch launcher:** Double-click `run_display.bat`

## Usage

Once running:

| Hotkey | Action |
|--------|--------|
| **F5** | Restart all browser windows |
| **F6** | Cycle display modes |
| **F8** | Exit kiosk app |
| **F9** | Mute/unmute audio |

## Configuration Reference

See `config.ini.example` for all available settings:

```ini
[Settings]
ChromeExe=    # Leave blank to auto-detect Chrome
VideoFile=video.mp4
DefaultMode=dual_url    # dual_url | single_url | video_left | video_right
RefreshSecs=5

[URLs]
URL1=https://your-clinic.com/queue-1
URL2=https://your-clinic.com/queue-2
```

## Kiosk Deployment (Windows)

### Auto-start on boot:
1. Press `Win + R`, type `shell:startup`
2. Copy `launcher.exe` (compiled) or a `launcher.au3` shortcut into the Startup folder
3. Enable Tablet Mode (optional): Settings → System → Tablet Mode → On

### Lock down Windows (recommended for public kiosks):
- Create a dedicated kiosk user account
- Use Group Policy to disable Task Manager, Alt+Tab, etc.
- Set Chrome to auto-launch in fullscreen mode

## Troubleshooting

| Problem | Solution |
|--------|----------|
| Chrome doesn't open | Check `ChromeExe` path in `config.ini` |
| Blank windows | Verify URLs are correct and public-facing |
| Audio doesn't play | Modern browsers block autoplay — ensure first user interaction, or use muted autoplay + user gesture |
| Windows not positioned correctly | Check screen resolution matches the target display |

## License

MIT — built for Bernardino General Hospital II queue display system.
