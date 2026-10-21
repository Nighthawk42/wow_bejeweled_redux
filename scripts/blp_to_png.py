"""Convert BLP2 textures to PNG, including palettized BLPs with an alpha layer.

Usage: python scripts/blp_to_png.py <file.blp> [...] --out <dir>   (needs Pillow)

Pillow's BLP reader returns zero alpha for palettized BLP2 files with 1/4/8-bit alpha,
so those are decoded here. Other BLP2 encodings (DXT, uncompressed) go through Pillow.
"""
import argparse
import os
import struct

from PIL import Image

HEADER = struct.Struct("<4sIBBBBII16I16I")


def decode_palettized(data, width, height, alpha_depth, offset):
    palette = [struct.unpack_from("<BBBB", data, 148 + 4 * i) for i in range(256)]  # B, G, R, A
    count = width * height
    indices = data[offset:offset + count]
    alpha_data = data[offset + count:]
    pixels = bytearray(count * 4)
    for i, index in enumerate(indices):
        b, g, r, _ = palette[index]
        if alpha_depth == 8:
            a = alpha_data[i]
        elif alpha_depth == 4:
            a = ((alpha_data[i // 2] >> (4 * (i % 2))) & 0x0F) * 17
        elif alpha_depth == 1:
            a = 255 if (alpha_data[i // 8] >> (i % 8)) & 1 else 0
        else:
            a = 255
        pixels[4 * i:4 * i + 4] = bytes((r, g, b, a))
    return Image.frombytes("RGBA", (width, height), bytes(pixels))


def blp_to_image(path):
    data = open(path, "rb").read()
    magic, _, compression, alpha_depth, _, _, width, height, *mips = HEADER.unpack_from(data)
    if magic != b"BLP2":
        raise ValueError(f"{path}: not a BLP2 file")
    if compression == 1:  # palettized
        return decode_palettized(data, width, height, alpha_depth, mips[0])
    return Image.open(path).convert("RGBA")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("files", nargs="+")
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    os.makedirs(args.out, exist_ok=True)
    for path in args.files:
        image = blp_to_image(path)
        name = os.path.splitext(os.path.basename(path))[0] + ".png"
        image.save(os.path.join(args.out, name), optimize=True)
        print(f"{name}: {image.size}, alpha {image.getchannel('A').getextrema()}")


if __name__ == "__main__":
    main()
