"""Generate the concept UI pieces with Meshy image endpoints (one run per piece)."""
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
MESHY = [sys.executable, os.path.expanduser("~/.claude/skills/meshy/scripts/meshy.py")]

JOBS = {
    "logo": ("image-to-image", {
        "ai_model": "gpt-image-2",
        "prompt": "Recreate this game logo as a clean, high-resolution asset: the same ornate dark stone and gold "
                  "banner with dragon heads and small gems, and the same glowing gold-to-blue-to-purple 'BEJEWELED' "
                  "lettering, spelled exactly B-E-J-E-W-E-L-E-D. Replace the 'match 3 puzzle' plaque underneath with "
                  "a smaller matching plaque that reads exactly 'REDUX'. Wide horizontal layout, centered, "
                  "no background, nothing else in the image.",
        "reference_image_urls": ["@ref_logo.png"],
        "aspect_ratio": "16:9",
        "remove_background": True,
    }),
    "frame": ("image-to-image", {
        "ai_model": "nano-banana-2",
        "prompt": "Clean game UI window frame in this exact style: dark weathered stone bars with a thin gold inner "
                  "trim and a round gold bolt medallion on each of the four corners. Perfectly square and symmetric, "
                  "straight even sides of the same thickness all the way around, no dragon, no top gem, no bottom "
                  "ornament, no runes. Front view, completely empty transparent center, no background.",
        "reference_image_urls": ["@ref_frame.png"],
        "aspect_ratio": "1:1",
        "remove_background": True,
    }),
    "medallion": ("image-to-image", {
        "ai_model": "nano-banana-2",
        "prompt": "Clean, high-resolution game icon of this exact round medallion: glowing blue swirl in a dark stone "
                  "ring with gold accents and the small gems top and bottom. Front view, centered, sharp edges, "
                  "no background, no text.",
        "reference_image_urls": ["@ref_medallion.png"],
        "aspect_ratio": "1:1",
        "remove_background": True,
    }),
    "background": ("text-to-image", {
        "ai_model": "nano-banana-2",
        "prompt": "Seamless tileable texture of dark weathered slate stone, flat top-down view, even lighting, subtle "
                  "cracks and grain, muted grey-blue tone, no border, no objects, no text, fantasy game UI panel "
                  "background.",
        "aspect_ratio": "1:1",
    }),
}

os.chdir(HERE)
for name in sys.argv[1:] or JOBS:
    endpoint, body = JOBS[name]
    print("===", name, flush=True)
    result = subprocess.run(MESHY + ["run", endpoint, json.dumps(body), "--out", f"./gen_{name}"],
                            capture_output=True, text=True)
    lines = [l for l in (result.stdout + result.stderr).splitlines() if "IN_PROGRESS" not in l and "PENDING" not in l]
    print("\n".join(lines[-6:]), flush=True)
