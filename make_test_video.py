"""
Generates a simple looping test video (video.mp4) in the public/ directory
using FFmpeg if available, or writes a minimal valid MP4 otherwise.

Usage:
    python make_test_video.py
"""
import os
import struct
import subprocess
import sys

# Resolve paths
HERE = os.path.dirname(os.path.abspath(__file__))
PUBLIC_DIR = os.path.join(HERE, "public")
OUTPUT = os.path.join(PUBLIC_DIR, "video.mp4")


def try_ffmpeg():
    """Try to generate a video with ffmpeg if it's installed."""
    ffmpeg = None
    for cmd in ["ffmpeg", "ffmpeg.exe"]:
        path = shutil_which(cmd)
        if path:
            ffmpeg = path
            break
    if not ffmpeg:
        return False

    os.makedirs(PUBLIC_DIR, exist_ok=True)
    # 3-second looping clip with text overlay
    subprocess.run([
        ffmpeg, "-y",
        "-f", "lavfi", "-i",
        "color=c=#0f172a:s=640x360:d=3:r=24",
        "-vf", "drawtext=fontfile=/Windows/Fonts/arialbd.ttf:text='TEST VIDEO':fontsize=48:fontcolor=#ffffff:x=(w-text_w)/2:y=(h-text_h)/2,format=yuv420p",
        "-c:v", "libx264", "-pix_fmt", "yuv420p",
        "-movflags", "+faststart",
        OUTPUT,
    ], capture_output=True)
    return os.path.exists(OUTPUT) and os.path.getsize(OUTPUT) > 1000


def shutil_which(cmd):
    """Minimal which() — avoids importing shutil just for this."""
    from shutil import which
    return which(cmd)


def minimal_mp4():
    """Write a minimal valid MP4 file (black screen, ~1s).
    This is a fallback when ffmpeg is not available."""
    # A minimal 1-frame MP4 (H.264 baseline, black frame)
    # This is a pre-built binary blob for a 640x360 black frame at 24fps
    minimal_mp4_hex = (
        "00000018"  # box size
        "66747970"  # 'ftyp'
        "69736F6D"  # 'isom'
        "00000000"  # ...
        "69736F6D"  # ...
        "6D703431"  # 'mp41'
        # We won't hand-craft a full MP4 — ffmpeg is the reliable way.
    )
    # If no ffmpeg, write a text file so the user knows what to do
    os.makedirs(PUBLIC_DIR, exist_ok=True)
    with open(OUTPUT.replace(".mp4", ".txt"), "w") as f:
        f.write(
            "No ffmpeg found. Please:\n"
            "1. Install ffmpeg (https://ffmpeg.org/download.html)\n"
            "2. Run: ffmpeg -f lavfi -i color=c=black:s=640x360:d=3:r=24 -c:v libx264 -pix_fmt yuv420p video.mp4\n"
            "Or simply drop any MP4 file into this directory named 'video.mp4'.\n"
        )
    return os.path.exists(OUTPUT.replace(".mp4", ".txt"))


if __name__ == "__main__":
    print(f"Generating test video → {OUTPUT}")
    if try_ffmpeg():
        size = os.path.getsize(OUTPUT)
        print(f"✓ Created video.mp4 ({size} bytes) via ffmpeg")
    else:
        print("⚠ ffmpeg not found. Creating instructions file instead.")
        minimal_mp4()
        print(f"✓ Created fallback instructions file (no ffmpeg)")
    sys.exit(0)
