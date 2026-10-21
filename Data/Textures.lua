local _, ns = ...

-- Texture database: every image the addon draws, with its size and the regions cut from it.
-- Texture packs (see art/README.md) supply their own files for these entries and may override
-- entries whose layout they change.
--
-- Entry fields:
--   file     file name in the pack's image folder; "%s" is replaced by the gem color name
--   size     { width, height } of the image in pixels
--   regions  named rectangles { x, y, w, h } in pixels; rotated = true marks a region stored
--            turned 90 degrees in the image
--   grid     animation frames { w, h, cols, rows } in pixels, numbered row by row from 1; a pack may
--            use fewer frames than the default (one frame turns the animation off)
--   display  on-screen { width, height } where the code sizes the texture from the entry
-- Coordinates may be fractional where the original art isn't on a whole-pixel grid.
-- Gem colors: yellow, white, blue, red, purple, orange, green.

ns.DefaultTextures = {
    path = "Interface\\AddOns\\BejeweledRedux\\images\\",
    font = "Contb___.ttf",
    textures = {
        -- Gems and effects
        gem = { file = "gem_%s.tga", size = { 256, 256 }, grid = { 50, 50, 5, 5 } }, -- 20 spin frames, 1 = resting
        shine = { file = "shine_%s.tga", size = { 128, 128 }, grid = { 42.67, 42.67, 3, 3 } },
        glow = { file = "highlight_%s.tga", size = { 32, 32 } },
        hypergem = { file = "hypergem.blp", size = { 512, 256 }, grid = { 51.2, 51.2, 10, 5 } }, -- frames 1-40 used
        explosion = { file = "explosion.tga", size = { 256, 256 }, grid = { 50, 50, 5, 5 } },
        gemshards = { file = "gemshards.tga", size = { 128, 128 }, grid = { 32, 32, 4, 4 } },
        bigstar = { file = "bigstar.tga", size = { 128, 128 } }, -- rotated around its center
        selector = { file = "selector.tga", size = { 64, 64 } },
        hintArrow = { file = "hintArrow.tga", size = { 64, 64 } },
        lightning = { file = "lightning.tga", size = { 128, 128 } }, -- stretched along the bolt
        lightningbright = { file = "lightningbright.tga", size = { 128, 128 } },

        -- Board and status text
        -- Board background; more variants ("tile2", "tile3", ...) are picked at random per cell.
        board = { file = "board.tga", size = { 128, 128 }, regions = { tile = { 6, 6, 100, 100 } } },
        artPieces = {
            file = "artPieces.tga",
            size = { 512, 256 },
            regions = {
                ["Go"] = { 0, 0, 134.7, 75.8 },
                ["3"] = { 326.1, 201, 35.3, 55 },
                ["2"] = { 245.2, 88.1, 39.4, 54.5 },
                ["1"] = { 220.2, 88.1, 24.6, 54.5 },
                ["Time's up"] = { 135.2, 41, 154.1, 39.4 },
                ["No more moves"] = { 135.2, 0, 294.4, 40.4 },
                ["Level up"] = { 0, 87.3, 219.6, 55.3 },
                ["Multiplier up"] = { 0, 202.2, 312.8, 53.8 },
                ["Strip"] = { 0, 81.9, 318.5, 4.1 }, -- background band behind the status text
                ["Popcap"] = { 366.1, 41.2, 69.1, 69.1 },
                ["Tutorial_1"] = { 362.5, 173.3, 149.5, 82.7 },
                ["Tutorial_2"] = { 436.2, 0, 75.8, 151.6, rotated = true },
                ["Tutorial_3"] = { 285.2, 111.1, 150.5, 61.4 },
                ["Bejeweled"] = { 0, 143.1, 284.2, 58.1 }, -- the original logo; the title bar uses "logo"
            },
        },
        splash = { file = "bejeweled_splash.tga", size = { 256, 256 } },

        -- Window and screens
        logo = {
            file = "logo.tga",
            size = { 512, 128 },
            regions = { logo = { 0, 0, 284, 58 } },
            display = { 285, 59 },
        },
        icon = { file = "bejeweled_icon.tga", size = { 32, 32 } }, -- minimap button
        windowIcon = { file = "windowIcon.blp", size = { 64, 64 } },
        windowBackground = { file = "windowBackground.blp", size = { 64, 64 } }, -- tiled
        windowBorder = { file = "windowBorder.blp", size = { 256, 32 } }, -- backdrop edge: 8 pieces L R T B TL TR BL BR
        levelBorder = { file = "levelBorder.blp", size = { 256, 32 } }, -- backdrop edge, same layout
        barArt = { file = "barArt.tga", size = { 32, 32 } },
        tabs = {
            file = "tabs.tga",
            size = { 256, 256 },
            regions = {
                skills = { 0, 0, 86, 31 },
                stats = { 86, 0, 45, 31 },
                scores = { 131, 0, 90, 31 },
                achievements = { 0, 32, 102, 31 },
                howToPlay = { 0, 64.3, 111.4, 31.1 },
                whyPopCap = { 112.4, 64.3, 111.5, 31.1 },
                credits = { 0, 96.4, 111.4, 31.1 },
            },
        },
        rankIcons = { file = "rankIcons.tga", size = { 128, 16 }, grid = { 16, 16, 8, 1 } }, -- frame = rank
        achievementplates = {
            file = "achievementplates.tga",
            size = { 512, 128 },
            regions = { earned = { 0, 0, 401, 60 }, unearned = { 0, 60, 401, 60 } },
        },
    },
}
