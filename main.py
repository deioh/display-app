from fasthtml.common import *

PAGE_URL = "http://192.168.1.2:9096/public-view-classic-transactional-multi/NpHhv55WqRRA8SwkK/z94jSwaCz9tyEArLi"
VIDEO_FILE = "video.mp4"
VIDEO_WIDTH = "45vw"          # width of the video pane
VIDEO_BG_COLOR = "#000"
VIDEO_FIT = "contain"         # contain = show full video; cover = crop to fill

app, rt = fast_app(
    static_path="public",
    pico=False,
)

CSS = f"""html, body {{ margin: 0; padding: 0; height: 100%; overflow: hidden; }}
#wrapper {{ display: flex; width: 100vw; height: 100vh; }}
#frame {{ flex: 1 1 auto; border: 0; }}
#frame iframe {{ width: 100%; height: 100%; border: 0; display: block; }}
video {{ width: {VIDEO_WIDTH}; height: 100vh; object-fit: {VIDEO_FIT}; background: {VIDEO_BG_COLOR}; }}"""

@rt("/")
def get():
    return (
        Style(CSS),
        Div(id="wrapper")(
            Div(id="frame")(Iframe(src=PAGE_URL)),
            Video(src=f"/{VIDEO_FILE}", autoplay=True, muted=True, loop=True, playsinline=True),
        ),
    )

serve()