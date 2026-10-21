"""Turn the generated concept UI pieces into pack textures (4x).

Backdrop edge strip: 8 square pieces left to right: left, right, top, bottom, TL, TR, BL, BR.
Per Blizzard's Backdrop.lua the top/bottom pieces are stored turned 90 degrees, every edge piece
repeats along its length (stored vertically), and the outer 1/128 of each piece is not sampled.
"""
import glob
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1]
PIECE = 128  # 32 px edge at 4x
os.makedirs(OUT, exist_ok=True)


def generated(name):
    return Image.open(glob.glob(os.path.join(HERE, f"gen_{name}", "*_image0.png"))[0]).convert("RGBA")


def tile_vertically(img, overlap):
    """Make img repeat seamlessly top-to-bottom by cross-fading its ends."""
    w, h = img.size
    body = img.crop((0, 0, w, h - overlap))
    tail = img.crop((0, h - overlap, w, h))
    head = body.crop((0, 0, w, overlap))
    mask = Image.linear_gradient("L").resize((w, overlap))  # 0 at top -> 255 at bottom
    blended = Image.composite(head, tail, mask)  # tail fades into head
    body.paste(blended, (0, 0))
    return body


def tile_both(img, overlap):
    img = tile_vertically(img, overlap)
    return tile_vertically(img.rotate(90, expand=True), overlap).rotate(-90, expand=True)


# --- Window border -------------------------------------------------------------------------
frame = generated("frame")
alpha = frame.getchannel("A")
# Left bar: columns where the bar is solid along its middle stretch.
mid = frame.crop((0, 330, 512, 700))
cols = [x for x in range(mid.width) if sum(mid.getchannel("A").crop((x, 0, x + 1, mid.height)).getdata()) > mid.height * 128]
bar_left, bar_right = cols[0], cols[-1] + 1
thickness = bar_right - bar_left
print("left bar columns", bar_left, bar_right, "thickness", thickness)
bar = frame.crop((bar_left, 330, bar_right, 330 + thickness + 40))
bar = tile_vertically(bar, 40)  # thickness x thickness, seamless vertically
left = bar.resize((PIECE, PIECE), Image.LANCZOS)
right = left.transpose(Image.FLIP_LEFT_RIGHT)
top = left  # stored top piece = left bar as-is (outer side left -> screen top)
bottom = left.rotate(180)

def corner(cx, cy):
    radius = 90
    box = frame.crop((cx - radius, cy - radius, cx + radius, cy + radius))
    return box.resize((PIECE, PIECE), Image.LANCZOS)

corners = [corner(147, 152), corner(877, 152), corner(140, 882), corner(885, 885)]
strip = Image.new("RGBA", (PIECE * 8, PIECE), (0, 0, 0, 0))
for i, piece in enumerate([left, right, top, bottom] + corners):
    strip.alpha_composite(piece, (i * PIECE, 0))
strip.save(os.path.join(OUT, "windowBorder.png"), optimize=True)

# --- Window icon ---------------------------------------------------------------------------
medallion = generated("medallion")
medallion = medallion.crop(medallion.getbbox())
side = max(medallion.size)
square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
square.alpha_composite(medallion, ((side - medallion.width) // 2, (side - medallion.height) // 2))
square.resize((256, 256), Image.LANCZOS).save(os.path.join(OUT, "windowIcon.png"), optimize=True)

# --- Background tile -----------------------------------------------------------------------
slate = generated("background").convert("RGB").crop((128, 128, 896, 896))
slate = tile_both(slate.convert("RGBA"), 96).convert("RGB")
slate.resize((256, 256), Image.LANCZOS).save(os.path.join(OUT, "windowBackground.png"), optimize=True)

# --- Logo ----------------------------------------------------------------------------------
logo = generated("logo")
logo = logo.crop(logo.getbbox())
canvas_w, canvas_h = 1024, 512
scale = min(canvas_w / logo.width, canvas_h / logo.height)
logo = logo.resize((round(logo.width * scale), round(logo.height * scale)), Image.LANCZOS)
canvas = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
canvas.alpha_composite(logo, (0, 0))
canvas.save(os.path.join(OUT, "logo.png"), optimize=True)
print("logo region", (0, 0, logo.width, logo.height), "on", (canvas_w, canvas_h))
