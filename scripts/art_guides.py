"""Draw the regions and animation frames from the texture database onto the art.

Usage:
    pip install pillow lupa
    python scripts/art_guides.py            # guides for art/*.png
    python scripts/art_guides.py art/2x     # guides for another folder of same-layout art

Reads Data/Textures.lua, the same database the addon uses, and writes
<art folder>/guides/<entry>_guide.png for every entry with regions or a frame grid.
Because coordinates are proportional to each entry's size, guides also line up on
upscaled art that keeps the layout.
"""
import os
import sys

from lupa import lua51
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SAMPLE_COLOR = {"gem": "red", "shine": "white", "glow": "white"}  # per-color entries: draw one
MIN_GUIDE_SIZE = 512  # small images are enlarged so labels stay readable
COLORS = ["#ff3b3b", "#3bff6b", "#3bb4ff", "#ffd23b", "#ff3bf0", "#3bfff2"]


def load_database():
    lua = lua51.LuaRuntime()
    with open(os.path.join(ROOT, "Data", "Textures.lua"), encoding="utf-8") as f:
        chunk = lua.execute("return function(...) " + f.read() + "\nend")
    ns = lua.table()
    chunk("BejeweledRedux", ns)
    return ns.DefaultTextures


def lua_list(table):
    return [table[i] for i in range(1, len(table) + 1)]


def regions_of(entry):
    """[(label, (x, y, w, h)), ...] in the entry's pixel space."""
    regions = []
    if entry.grid is not None:
        width, height, cols, rows = lua_list(entry.grid)
        for row in range(int(rows)):
            for col in range(int(cols)):
                regions.append((str(len(regions) + 1), (col * width, row * height, width, height)))
    if entry.regions is not None:
        for name, rect in sorted(entry.regions.items()):
            label = name + (" (rotated)" if rect.rotated else "")
            regions.append((label, tuple(lua_list(rect)[:4])))
    return regions


def checkerboard(size, square):
    board = Image.new("RGBA", size, (40, 40, 40, 255))
    draw = ImageDraw.Draw(board)
    for y in range(0, size[1], square):
        for x in range(0, size[0], square):
            if (x // square + y // square) % 2:
                draw.rectangle([x, y, x + square - 1, y + square - 1], fill=(60, 60, 60, 255))
    return board


def draw_guide(image_path, entry, regions, out_path):
    src = Image.open(image_path).convert("RGBA")
    scale = max(1, -(-MIN_GUIDE_SIZE // max(src.size)))
    size = (src.width * scale, src.height * scale)
    guide = Image.alpha_composite(checkerboard(size, 8 * scale), src.resize(size, Image.NEAREST))
    overlay = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    font = ImageFont.load_default()
    # Database rects are in the entry's declared pixel space; map them onto this image.
    fx, fy = size[0] / entry.size[1], size[1] / entry.size[2]
    for i, (label, (x, y, w, h)) in enumerate(regions):
        color = COLORS[i % len(COLORS)]
        box = [x * fx, y * fy, (x + w) * fx - 1, (y + h) * fy - 1]
        draw.rectangle(box, outline=color, width=max(1, scale))
        text_box = draw.textbbox((box[0] + 2, box[1] + 1), label, font=font)
        draw.rectangle(text_box, fill=(0, 0, 0, 170))
        draw.text((box[0] + 2, box[1] + 1), label, fill=color, font=font)
    Image.alpha_composite(guide, overlay).save(out_path)
    return size


def main():
    art_dir = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(ROOT, "art")
    out_dir = os.path.join(art_dir, "guides")
    os.makedirs(out_dir, exist_ok=True)
    database = load_database()
    for key, entry in sorted(database.textures.items()):
        regions = regions_of(entry)
        if not regions:
            continue
        name = os.path.splitext(entry.file.replace("%s", SAMPLE_COLOR.get(key, "%s")))[0]
        image_path = os.path.join(art_dir, name + ".png")
        if not os.path.exists(image_path):
            print(f"skip {key}: {image_path} not found")
            continue
        out_path = os.path.join(out_dir, f"{key}_guide.png")
        size = draw_guide(image_path, entry, regions, out_path)
        print(f"{key}_guide.png  {size[0]}x{size[1]}  {len(regions)} regions")


if __name__ == "__main__":
    main()
