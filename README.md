# display-app

A kiosk-style clinic queue display built with [FastHTML](https://fastht.ml/) and Playwright.

Shows a live queue board (dept/doctor + ticket) on the left, extracted from a public-view page that renders client-side JavaScript (Meteor SPA), while a local video loops on the right.

```
+------------------------------------------------------+------------------+
|                                                      |                  |
|   Queue board (dept/doctor + ticket, readable size)  |   video (loops)  |
|                                                      |                  |
+------------------------------------------------------+------------------+
```

## How it works

The source page (`PAGE_URL`) is a Meteor SPA — its content renders with JavaScript, so it can't be scraped with a plain HTTP fetch. The app keeps a headless Chromium (Playwright) page open on that URL, samples the queue rows every `REFRESH_SECS` seconds, and discards the middle column (window/room). The board re-renders via HTMX polling.

**Queue extraction logic:**
- The source page renders 3-cell `<div>` rows: Department/Doctor | Window/Room | Ticket
- The extraction script finds all such rows with sufficient width/height, deduplicates them, and drops the middle column (Window/Room) for display.

## Quick start

```bash
# 1. Install dependencies
python -m pip install -r requirements.txt

# 2. Install Playwright's Chromium browser
python -m playwright install chromium

# 3. Add a video file
#    Drop any MP4 into public/ named video.mp4, or generate a test one:
python make_test_video.py

# 4. Configure (optional)
#    Set environment variables — see "Configuration" below

# 5. Run
python main.py

# Open http://localhost:5001
```

## Configuration

All settings are environment variables with sensible defaults:

| Variable | Default | Description |
|---|---|---|
| `PAGE_URL` | `http://192.168.1.2:9096/...` | The public-view page to scrape |
| `VIDEO_FILE` | `video.mp4` | Filename of your video in `public/` |
| `VIDEO_WIDTH` | `45vw` | Width of the video pane |
| `BOARD_WIDTH` | `55vw` | Width of the queue board pane |
| `VIDEO_BG_COLOR` | `#000` | Background color behind the video |
| `VIDEO_FIT` | `contain` | `contain` (full video) or `cover` (crop) |
| `REFRESH_SECS` | `5` | How often the board is re-sampled (seconds) |
| `PLAYWRIGHT_HEADLESS` | `1` | Set to `0` to see the browser window (debugging) |
| `PORT` | `5001` | Listen port |

Example `.env` file:

```bash
PAGE_URL=http://your-clinic-ip:9096/public-view-classic-transactional-multi/your-key
VIDEO_FILE=my_video.mp4
REFRESH_SECS=10
PORT=5001
```

Load with `python -m dotenv run python main.py` or use any env-loading method.

## Testing extraction

To verify the queue extraction logic against your page:

```bash
python _extract_test.py
```

This runs Playwright, navigates to `PAGE_URL`, extracts the rows, and saves them to `_extract_output.json`. You can also pass a specific URL:

```bash
python _extract_test.py http://your-page-url
```

## Generating a test video

No video? Generate a simple placeholder:

```bash
python make_test_video.py
```

Requires `ffmpeg` on `PATH`. If not found, it creates a text file with manual instructions.

Manual ffmpeg command:

```bash
ffmpeg -f lavfi -i "color=c=#0f172a:s=640x360:d=3:r=24" \
  -c:v libx264 -pix_fmt yuv420p -movflags +faststart public/video.mp4
```

## Files

| File | Purpose |
|---|---|
| `main.py` | FastHTML app — serves dashboard, runs Playwright extraction |
| `_extract_test.py` | Standalone test for the queue row extraction logic |
| `make_test_video.py` | Generates a test video.mp4 placeholder |
| `requirements.txt` | Python dependencies |
| `public/` | Static files served by FastHTML (video, images, etc.) |

## Troubleshooting

**Black screen / no video:**
- Ensure `public/video.mp4` exists (see `make_test_video.py`)
- Check browser console for errors
- The video must be muted (`muted=True`) — browsers block autoplay with sound

**Empty queue board / "Loading board...":**
- Verify `PAGE_URL` is correct and accessible
- Set `PLAYWRIGHT_HEADLESS=0` to debug visually
- Run `python _extract_test.py` to check extraction output

**Playwright can't launch Chromium:**
```bash
python -m playwright install chromium
python -m playwright install-deps  # Linux only — installs system libs
```

**Page loads but extraction finds no rows:**
- The extraction looks for 3-cell `<div>` rows with width > 500px and height > 40px
- Inspect the source page in a browser and check DevTools if the DOM structure differs
- Adjust `EXTRACT_JS` in `main.py` if your page has a different layout
