# Queue Display

One page shows your clinic's queue board on the left and a looping video on the right. The board updates itself the moment the queue changes, no reloading needed.

## Requirements

- Windows 10/11
- Python 3.13
- Google Chrome (for kiosk mode)

Install the Python packages:

```
pip install -r requirements.txt
python -m playwright install chromium
```

## Setup

Copy the example settings file to `.env`:

```
copy .env.example .env
```

Then open `.env` and set your values:

| Key | What it does |
|-----|--------------|
| `PAGE_URL` | The QMeUp public view URL for your queue |
| `VIDEO_FILE` | Video file name inside `public\` (e.g. `video.mp4`) |
| `VIDEO_WIDTH` | Width of the video pane, as a CSS value (e.g. `45vw`) |
| `BOARD_WIDTH` | Width of the queue board, as a CSS value (e.g. `55vw`) |
| `VIDEO_BG_COLOR` | Background color behind the video (e.g. `#000`) |
| `VIDEO_FIT` | How the video fills its pane: `contain` or `cover` |
| `REFRESH_SECS` | How often the server re-checks the queue page, in seconds. This is server-side sampling only; the display page itself never refreshes. |
| `PORT` | Port the app listens on (default `5001`) |

## Add a video

Drop your video file into the `public\` folder, for example `public\video.mp4`, and set `VIDEO_FILE=video.mp4` in `.env`.

## Run

From the `display-app` folder:

```
python main.py
```

Then open `http://127.0.0.1:5001` in a browser.

Or double-click `start_display.bat`. It kills any stale copy of the app, starts the server, waits for it to come up, then launches Chrome in kiosk (fullscreen) mode pointed at the display page.

## Start on boot

The app does not register itself. You switch autostart on yourself, one of two ways.

### Option A: Task Scheduler

1. Open Task Scheduler (search "Task Scheduler" in the Start menu).
2. Create Task.
3. General tab: give it a name, and check "Run whether user is logged on or not" if you want it to start before anyone signs in.
4. Triggers tab: New, set "Begin the task" to "At log on".
5. Actions tab: New, Action = "Start a program", Program/script = the full path to `start_display.bat`.
6. OK to save.

### Option B: Startup folder shortcut

1. Press `Win + R`, type `shell:startup`, press Enter.
2. Create a shortcut to `start_display.bat` in that folder.

## How updates work

The display page loads once and sits. It does NOT refresh itself. The server keeps the queue page open in the background, checks it every `REFRESH_SECS` seconds, and pushes the new board to the display only when the queue actually changes. If nothing changes, nothing is sent.

## Troubleshooting

| Problem | What to check |
|---------|---------------|
| Video area is blank or shows a placeholder | The video file is missing, or the name in `VIDEO_FILE` doesn't match a file in `public\`. |
| Board is blank | `PAGE_URL` is wrong, or the clinic network can't reach it. |
| Board shows sample/mock rows | The server can't open the queue page with Playwright. Check `PAGE_URL` and that this machine can reach it over the network. |

## License

MIT, built for Bernardino General Hospital II queue display system.