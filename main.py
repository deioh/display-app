"""
display-app — FastHTML kiosk-style clinic queue display.

Shows a live queue board (dept/doctor + ticket) on the left, extracted from a
public-view page (Meteor SPA) via headless Playwright, while a local video
loops on the right.

The board page renders client-side JavaScript, so it can't be scraped with a
plain HTTP fetch. This app keeps a Playwright Chromium page open on the target
URL, samples the queue rows every REFRESH_SECS, drops the middle column
(window/room), and the board re-renders via HTMX polling.

Configuration:
  PAGE_URL          — the public-view page to read the queue from
  VIDEO_FILE        — filename of your video inside public/
  VIDEO_WIDTH       — width of the video pane (CSS, e.g. "45vw")
  BOARD_WIDTH       — width of the queue-board pane (CSS, e.g. "55vw")
  REFRESH_SECS      — how often the board is re-sampled (seconds)
  VIDEO_BG_COLOR    — background color behind the video
  VIDEO_FIT         — object-fit for the video ("contain" or "cover")
  PLAYWRIGHT_HEADLESS — "0" to run Chromium with a visible window (debug)
  PORT              — listen port (default 5001)

Run:
  python main.py
  # Open http://localhost:5001
"""

import os
import threading
import time
import logging

# Load .env file BEFORE reading environment variables
from dotenv import load_dotenv
load_dotenv()

from fasthtml.common import *
from playwright.sync_api import sync_playwright, Error as PlaywrightError

# --------------------------------------------------------------------------- #
# Configuration (environment overrides with sensible defaults)
# --------------------------------------------------------------------------- #

PAGE_URL           = os.environ.get("PAGE_URL",
    "http://192.168.1.2:9096/public-view-classic-transactional-multi/NpHhv55WqRRA8SwkK/z94jSwaCz9tyEArLi")
VIDEO_FILE         = os.environ.get("VIDEO_FILE", "video.mp4")
VIDEO_WIDTH        = os.environ.get("VIDEO_WIDTH", "45vw")
VIDEO_BG_COLOR     = os.environ.get("VIDEO_BG_COLOR", "#000")
VIDEO_FIT          = os.environ.get("VIDEO_FIT", "contain")
REFRESH_SECS       = int(os.environ.get("REFRESH_SECS", "5"))
BOARD_WIDTH        = os.environ.get("BOARD_WIDTH", "55vw")
PLAYWRIGHT_HEADLESS = os.environ.get("PLAYWRIGHT_HEADLESS", "1") != "0"
PORT               = int(os.environ.get("PORT", "5001"))

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
log = logging.getLogger("display-app")

# --------------------------------------------------------------------------- #
# Queue extraction logic
# --------------------------------------------------------------------------- #

# Extract queue rows: DEPARTMENT/DOCTOR | WINDOW/ROOM | TICKET (3-cell rows)
EXTRACT_JS = """() => {
  const rows = [...document.querySelectorAll('div')].filter(d => {
    const kids = d.children;
    if (kids.length !== 3) return false;
    const r = d.getBoundingClientRect();
    return r.width > 500 && r.height > 40;
  });
  const seen = new Set(), out = [];
  for (const row of rows) {
    const cells = [...row.children].map(c => c.innerText.trim());
    if (cells.some(c => !c)) continue;
    const key = cells.join('|');
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(cells);          // [dept/doctor, window/room, ticket]
  }
  return out;
}"""

_board_lock = threading.Lock()
_board: list = []                 # latest extracted rows, including header

# Fallback mock board data for when Playwright can't reach the page
_mock_board = [
    ["Department / Doctor", "Window / Room", "Ticket"],
    ["Internal Medicine / Dr. Smith", "Room 2", "A103"],
    ["Cardiology / Dr. Jones", "Room 1", "A104"],
    ["Pediatrics / Dr. Wong", "Room 3", "A105"],
    ["Dermatology / Dr. Lee", "Room 4", "--"],
    ["Orthopedics / Dr. Chen", "Room 5", "A106"],
]


def board_worker():
    """Background thread: keep the source page loaded in headless Chromium
    and sample the rows every REFRESH_SECS. Falls back to mock data if the
    page is unreachable."""
    global _board
    # Start with mock data so the dashboard renders immediately
    with _board_lock:
        _board = list(_mock_board)

    try:
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=PLAYWRIGHT_HEADLESS)
            page = browser.new_page(viewport={"width": 1920, "height": 1080})
            log.info("Navigating to %s ...", PAGE_URL)
            page.goto(PAGE_URL, wait_until="networkidle", timeout=60000)
            log.info("Page loaded. Starting extraction loop (every %ds).", REFRESH_SECS)

            while True:
                try:
                    rows = page.evaluate(EXTRACT_JS)
                    # If we get header + at least one row, use it
                    if len(rows) >= 2:
                        with _board_lock:
                            _board = rows
                    else:
                        log.warning("Extraction returned %d rows — keeping last known data.", len(rows))
                except PlaywrightError as e:
                    log.warning("Playwright error during extraction: %s", e)
                except Exception as e:
                    log.warning("Extraction error: %s", e)
                time.sleep(REFRESH_SECS)

    except Exception as e:
        log.error("Failed to start Playwright browser: %s", e)
        log.error("Falling back to mock board data. Set PAGE_URL correctly and ensure "
                  "Playwright Chromium is installed (`python -m playwright install chromium`).")
        # _board stays at mock data; the dashboard still renders


def render_board():
    """Render the current board state as FastHTML elements."""
    with _board_lock:
        rows = list(_board)

    if not rows:
        return Div(P("Loading board..."),
                   cls="queue",
                   style="padding: 2rem; text-align: center; color: #94a3b8;")

    header = rows[0]
    items = []
    for r in rows[1:]:
        # Defensive: ensure we have at least 3 cells
        while len(r) < 3:
            r.append("")
        dept = r[0] or "—"
        ticket = r[2]
        empty = " empty" if ticket in ("--", "-", "") else ""
        items.append(Div(cls="brow",
                         style="display: flex; flex: 1; align-items: stretch;")
                     (Span(dept), Span(ticket, cls=f"ticket{empty}")))

    # Ensure header has at least 3 cells
    while len(header) < 3:
        header.append("")

    return (
        Div(cls="bhead"
            )(Span(header[0], cls="h-dept"),
              Span(header[2], cls="h-ticket")),
        *items,
    )


# --------------------------------------------------------------------------- #
# FastHTML app
# --------------------------------------------------------------------------- #

app, rt = fast_app(static_path="public", pico=False, port=PORT, live=True,
                   hdrs=Link(rel="stylesheet", href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap"))

CSS = f"""/* ===== Layout ===== */
html, body {{ margin: 0; padding: 0; height: 100%; overflow: hidden; }}
#wrapper {{ display: flex; width: 100vw; height: 100vh; }}
#frame {{ flex: 1 1 auto; border: 0; display: flex; flex-direction: column; }}

/* ===== Video pane ===== */
video {{
  width: {VIDEO_WIDTH};
  height: 100vh;
  object-fit: {VIDEO_FIT};
  background: {VIDEO_BG_COLOR};
  object-position: center;
}}

/* ===== Board pane ===== */
#board-container {{
  width: {BOARD_WIDTH};
  height: 100vh;
  overflow: hidden;
  background: #0f172a;
  color: #fff;
  font-family: 'Inter', 'Segoe UI', Arial, sans-serif;
  display: flex;
  flex-direction: column;
}}
.queue {{ flex: 1; display: flex; flex-direction: column; overflow: hidden; }}

/* ===== Board header ===== */
.bhead {{
  display: flex;
  background: #1e293b;
  font-size: 2.2rem;
  font-weight: 700;
  letter-spacing: .05em;
  color: #94a3b8;
  text-transform: uppercase;
  flex-shrink: 0;
}}
.bhead span {{ flex: 1; padding: 2rem 2.5rem; }}

/* ===== Board rows ===== */
.brow {{
  display: flex;
  flex: 1;
  align-items: stretch;
  font-size: 3.2rem;
  border-top: 2px solid #1e293b;
  flex-shrink: 0;
}}
.brow:nth-child(odd) {{ background: #111c2e; }}
.brow span {{
  flex: 1;
  display: flex;
  align-items: center;
  padding: 0 2.5rem;
}}

/* ===== Ticket ===== */
.ticket {{
  justify-content: flex-start;
  font-weight: 700;
}}
.ticket.empty {{ color: #475569; }}
.ticket:empty {{ color: #475569; }}

/* ===== Loading state ===== */
.loading-fallback {{
  padding: 2rem;
  text-align: center;
  color: #94a3b8;
  font-size: 1.5rem;
}}
"""


@rt("/board")
def board():
    """HTMX endpoint — returns the rendered board rows."""
    return (*render_board(),)


@rt("/")
def get():
    """Main dashboard page."""
    return (
        Style(CSS),
        Title("Queue Display"),
        Div(id="wrapper")(
            Div(id="frame")(
                Div(id="board-container")(
                    Div(id="board",
                        hx_get="/board",
                        hx_trigger=f"every {REFRESH_SECS}s",
                        hx_swap="innerHTML",
                        cls="queue"
                        )(
                        *render_board()
                    ),
                ),
            ),
            # Video with fallback content if file is missing
            Video(src=f"/{VIDEO_FILE}",
                  autoplay=True, muted=True, loop=True,
                  playsinline=True,
                  poster="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='320' height='180' viewBox='0 0 320 180'%3E%3Crect width='320' height='180' fill='%230f172a'/%3E%3Ctext x='50%25' y='50%25' fill='%23475569' font-family='Arial' font-size='20' text-anchor='middle' dominant-baseline='middle'%3ENo video file%3C/text%3E%3C/svg%3E",
                  type="video/mp4"),
        ),
    )


# Start background board extraction
threading.Thread(target=board_worker, daemon=True).start()

# Run the app
if __name__ == "__main__":
    log.info("Starting display-app on port %d", PORT)
    log.info("PAGE_URL: %s", PAGE_URL)
    log.info("VIDEO_FILE: %s", VIDEO_FILE)
    serve()
