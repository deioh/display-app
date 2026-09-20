# display-app

A single-page kiosk-style display built with [FastHTML](https://fastht.ml/): shows a webpage (e.g. an internal/LAN dashboard) on the left while a local video loops on the right.

```
+----------------------------------------------+------------------+
|                                             |                  |
|              iframe (your URL)              |    video (loops) |
|                                             |                  |
+----------------------------------------------+------------------+
```

## Requirements

- Python 3.10+
- `pip install python-fasthtml`

## Setup

1. Edit `main.py`:
   - `PAGE_URL` — the page to display on the left (line 3)
   - `VIDEO_FILE` — file name of your video inside `public/` (line 4)
   - `VIDEO_WIDTH` — width of the video pane, e.g. `"45vw"` (line 5)
   - `VIDEO_FIT` — `contain` shows the full video with bars, `cover` crops to fill (line 7)
2. Drop your video into `public/` (e.g. `public/video.mp4`).

## Run

```sh
python main.py
```

Open http://localhost:5001. The video autoplays muted and loops (muted autoplay is required by browser policy).

## Notes

- Static files in `public/` are served at the root, e.g. `public/video.mp4` → `/video.mp4` (FastHTML convention).
- The video is intentionally muted so autoplay works; the iframe page's own audio is unaffected.