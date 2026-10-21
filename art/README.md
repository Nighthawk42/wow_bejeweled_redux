# Bejeweled Redux Art and Texture Packs

This folder holds editable copies of the addon's art, and this page explains how to make your own texture pack. You need an image editor that saves PNG with transparency, such as GIMP, Krita, Paint.NET or Photoshop, and nothing else.

Nothing in `art/` is loaded by the game: the addon draws its built-in art from `images/` (TGA and BLP), or from an installed texture pack. Release downloads don't include `art/`.

| Folder | Contents |
|---|---|
| `art/*.png` | PNG copies of every image in `images/`, at original size. Start here |
| `art/guides/` | Each image with the regions and animation frames the game cuts from it drawn on top |
| `art/2x/`, `art/4x/` | Upscaled spares the game doesn't use; the upscales it does use are in `packs/BejeweledRedux_2x` and `packs/BejeweledRedux_4x` |
| `art/custom/` | New art: the concept sheets and the sources of the Concept pack |
| `../packs/` | The three released packs. Copy one as a starting point for your own |

## How the Game Uses an Image

Most images are **sheets**: several pictures packed into one file, which the game cuts apart using fixed positions. For example, `gem_red.png` holds the 20 frames of the red gem's spin in a 5×5 grid, and `artPieces.png` holds "GO!", "LEVEL UP!", the countdown digits and more. Open an image's guide in `art/guides/` to see exactly which parts are used.

The positions are stored in the **texture database**, [`Data/Textures.lua`](../Data/Textures.lua), as pixels relative to each image's size. Because they're relative, you can make an image bigger, at 2× or 4×, and nothing else has to change, as long as everything stays in the same place.

## The Images

The file names your pack must use (`%s` is the gem color: `yellow`, `white`, `blue`, `red`, `purple`, `orange`, `green`):

| Entry | File | Original size | What it is |
|---|---|---|---|
| `gem` | `gem_%s` | 256×256 | Gem spin, 5×5 grid of 50 px frames (1–20 used; frame 1 is the resting gem) |
| `shine` | `shine_%s` | 128×128 | Mouse-over shine sweep, 3×3 frames |
| `glow` | `highlight_%s` | 32×32 | Glow around gems near specials |
| `hypergem` | `hypergem` | 512×256 | Hypercube spin, 10×5 frames (1–40 used) |
| `explosion` | `explosion` | 256×256 | Explosion, 5×5 frames |
| `gemshards` | `gemshards` | 128×128 | Gem shards, 4×4 frames |
| `bigstar` | `bigstar` | 128×128 | Power-gem star (rotated by the game) |
| `selector` | `selector` | 64×64 | Selected-gem outline |
| `hintArrow` | `hintArrow` | 64×64 | Hint arrow |
| `lightning`, `lightningbright` | same | 128×128 | Hypercube lightning bolt (stretched along the bolt) |
| `board` | `board` | 128×128 | Board background tile |
| `artPieces` | `artPieces` | 512×256 | "GO!", "LEVEL UP!", countdown digits, tutorial pictures and more |
| `splash` | `bejeweled_splash` | 256×256 | Splash screen |
| `logo` | `logo` | 512×128 | Title-bar logo |
| `icon` | `bejeweled_icon` | 32×32 | Minimap button |
| `windowIcon` | `windowIcon` | 64×64 | Icon in the window's top-left corner |
| `windowBackground` | `windowBackground` | 64×64 | Window background, tiled |
| `windowBorder`, `levelBorder` | same | 256×32 | Window and level-box borders (8 pieces, see below) |
| `barArt` | `barArt` | 32×32 | Progress-bar fill (tinted by the game) |
| `tabs` | `tabs` | 256×256 | Tab buttons |
| `rankIcons` | `rankIcons` | 128×16 | Skill rank icons, 8 in a row |
| `achievementplates` | `achievementplates` | 512×128 | Achievement plates, earned and not earned |

## Making a Texture Pack

### 1. Copy a pack

Copy one of the folders in `packs/` and rename it, for example to `BejeweledRedux_MyPack`. A pack looks like this:

```
BejeweledRedux_MyPack/
    BejeweledRedux_MyPack.toc
    pack.lua
    images/
        gem_red.png
        ...
```

Then delete the images you don't plan to change, and copy in the ones you do from `art/` (original size) or from one of the packs (2× or 4×).

### 2. Edit the images

Open an image together with its guide from `art/guides/`, and keep to these rules:

- **Keep everything in the same place.** Each frame, word or piece must stay inside the box its guide shows. Redraw, recolor or repaint freely within those boxes.
- **Resize evenly.** If you make an image bigger, scale the width and the height by the same factor (2×, 4×, ...).
- **Use power-of-two sizes** (32, 64, 128, ..., 2048). Older clients have historically required them.
- **Keep transparency.** Everything except `windowBackground` uses an alpha channel. Save as PNG with transparency, 8 bits per channel.
- **Animations.** For gems, explosions, hypercubes, shards and shines, each frame is one step of the animation. You can also use fewer frames, even a single one; the game repeats them to fill the animation, so one frame means no animation.
- **Borders** (`windowBorder`, `levelBorder`) are 8 square pieces in a row: left edge, right edge, top edge, bottom edge, then the top-left, top-right, bottom-left and bottom-right corners. The top and bottom edges are stored turned 90° (drawn vertically, outside edge on the left), and every edge piece repeats along its length, so it must tile seamlessly from its top to its bottom.
- **Board tiles**: the `board` tile is drawn on every board cell. To mix several tile designs, give the pack its own `board` entry with regions `tile`, `tile2`, `tile3`, and so on (see step 3); each cell picks one at random.

### 3. Write `BejeweledRedux_MyPack.toc` and `pack.lua`

The `.toc` file must have the same name as the folder:

```
## Interface: 120100, 50504, 20506, 11509, 38002, 16001
## Title: Bejeweled Redux - My Pack
## Notes: What your pack changes.
## Author: Your name
## Version: 1.0.0
## Dependencies: BejeweledRedux

pack.lua
```

`pack.lua` registers the pack:

```lua
BejeweledRedux_RegisterTexturePack({
    name = "My Pack",                                       -- shown in Options
    path = "Interface\\AddOns\\BejeweledRedux_MyPack\\images\\", -- your folder name here
    extension = ".png",
    textures = {
        gem = true,          -- I supply gem_<color>.png, same layout
        windowBorder = true, -- I supply windowBorder.png
    },
})
```

- **`textures`** lists what your pack replaces. `true` means "my file, same layout". Anything not listed keeps the built-in art.
- **Leave `textures` out** only if your pack supplies every image in the table above, like the HD packs do.
- **A different layout** needs the full entry instead of `true`. For example, a taller logo:

  ```lua
  logo = {
      file = "logo.png",
      size = { 1024, 512 },                    -- the image's size in pixels
      regions = { logo = { 0, 0, 1024, 445 } }, -- x, y, width, height of the logo inside it
      display = { 240, 104 },                  -- size on screen; taller logos hang over the window top
  },
  ```

  The fields are the same as in [`Data/Textures.lua`](../Data/Textures.lua): `size` is the image size, `regions` are named boxes `{ x, y, w, h }`, `grid = { w, h, cols, rows }` describes animation frames, and `display` is the on-screen size.
- **`font = "MyFont.ttf"`** (optional) replaces the score font with a font in your `images` folder.

### 4. Try it in the game

1. Copy your pack folder into `World of Warcraft/_retail_/Interface/AddOns/`, next to `BejeweledRedux`.
2. Restart the game client fully. New addon folders and new image files are only picked up at startup.
3. Open **Options → General → Texture Pack**, choose your pack, and type `/reload`.
4. While you work, `/reload` usually picks up changes to existing images. If a change doesn't show, restart the client.

### Troubleshooting

| What you see | Likely cause |
|---|---|
| Your pack isn't listed in Options | The folder and `.toc` names differ, `## Dependencies` is missing, or the client wasn't restarted |
| A green or empty square | A file name or `extension` doesn't match, or the file was added without restarting the client |
| A picture is cut off or shows a neighbour | The layout moved: compare with the guide, or give the pack its own entry with the new positions |
| A chat message about an invalid entry | A `textures` entry is missing `file` or `size` |
| Blank art on a Classic client | PNG may not load there yet; TGA works on every client |

### 5. Share it

Zip the pack folder (the folder itself, not just its contents) and share the zip. Players extract it into `Interface/AddOns/` the same way.

## Changing the Built-in Art

To change the art that ships inside the addon itself rather than making a pack, export the image as a 32-bit TGA with alpha under its file name in `images/`. Update the entry's `size` in `Data/Textures.lua` if the resolution changed, and its `regions` or `grid` if the layout changed.

## Tools

These scripts are optional (`pip install pillow lupa`):

- `python scripts/art_guides.py [folder]` redraws the guides from the texture database into `<folder>/guides/`, for `art/` (the default) or any folder of art with the same layout. If you run it on your own pack's `images` folder, delete the `guides` folder it creates before sharing the pack.
- `python scripts/blp_to_png.py <file.blp> ... --out <folder>` converts Blizzard BLP images to PNG with their transparency intact.

## How the Released Packs Were Made

- **HD (2x)** and **Ultra HD (4x)**: the original art upscaled with an AI upscaler (Upscayl), same layout.
- **Concept**: new art based on the concept sheets in `art/custom/`. Gem sprites were cleaned up and turned into 3D models with Meshy (an AI service), then rendered spinning in Blender; the logo, window border, icon and background were generated with Meshy's image tools and cut into the formats above. The sources are in `art/custom/meshy_gems/` and `art/custom/meshy_ui/`. None of this is needed to make a pack: any image editor works.
