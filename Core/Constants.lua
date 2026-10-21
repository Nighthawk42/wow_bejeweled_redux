local _, ns = ...

-- Shared constants. Each file pulls what it needs into locals:
--   local C = ns.C
--   local GEM_WIDTH, GEM_HEIGHT = C.GEM_WIDTH, C.GEM_HEIGHT
local C = {}
ns.C = C

C.ADDON_PATH = "Interface\\AddOns\\BejeweledRedux\\"
C.SOUND_PATH = C.ADDON_PATH .. "sounds\\"

C.COMM_PREFIX = "BejeweledHS1"

-- Gem colors, indexed by gem.contents (1..7). 8/9 are white (power gem, hypercube).
C.GEM_YELLOW, C.GEM_WHITE, C.GEM_BLUE, C.GEM_RED, C.GEM_PURPLE, C.GEM_ORANGE, C.GEM_GREEN = 1, 2, 3, 4, 5, 6, 7
C.GEM_HYPERCUBE = 9
C.NUM_GEM_COLORS = 7
C.GEM_COLOR_NAMES = { "yellow", "white", "blue", "red", "purple", "orange", "green" }
C.GEM_RGB_COLORS = {
    { 1, 1, 0 },
    { 1, 1, 1 },
    { 0.2, 0.4, 1 },
    { 1, 0, 0 },
    { 0.8, 0, 0.8 },
    { 1, 0.6, 0.2 },
    { 0, 1, 0 },
    { 1, 1, 1 },
    { 1, 1, 1 },
}
C.FAVORITE_COLOR_LABELS = {
    "|cFFFFFF00Yellow|r",
    "White",
    "|cFF2255FFBlue|r",
    "|cFFFF0000Red|r",
    "|cFFEE00EEPurple|r",
    "|cFFFF9922Orange|r",
    "|cFF00FF00Green|r",
}

-- Animation frame texture coordinates ({ left, right, top, bottom }), filled at login from the
-- active texture pack (Core/Textures.lua). Code may keep references to these tables.
C.GEM_SPIN_TEXCOORDS = {} -- gem spin; frame 1 is the resting gem
C.EXPLOSION_TEXCOORDS = {}
C.HYPERCUBE_TEXCOORDS = {}
C.SHARD_TEXCOORDS = {}
C.SHINE_TEXCOORDS = {}

-- Mouse-over shine sweep: alpha per frame, and which neighbour each keyframe spills onto.
C.FX_SHINE_ALPHA = { 0, 0.43, 0.66, 0.8, 0.66, 0.43 }
C.FX_SHINE_KEYFRAME = { 1, 5, 3, 7, 2, 6, 4, 8, 9 }
C.FX_SHINE_GRIDX = { 0, 0, -1, 1, -1, 1, -1, 1, -8 }
C.FX_SHINE_GRIDY = { -1, 1, 0, 0, -1, 1, 1, -1, -8 }

-- Sizes
C.GEM_WIDTH, C.GEM_HEIGHT = 50, 50
C.GEM_HALF_WIDTH, C.GEM_HALF_HEIGHT = C.GEM_WIDTH / 2, C.GEM_HEIGHT / 2
C.SHARD_WIDTH, C.SHARD_HEIGHT = 24, 24
C.SHARD_HALF_WIDTH, C.SHARD_HALF_HEIGHT = C.SHARD_WIDTH / 2, C.SHARD_HEIGHT / 2
C.BIG_STAR_WIDTH, C.BIG_STAR_HEIGHT = 90, 90
C.EXPLOSION_WIDTH, C.EXPLOSION_HEIGHT = 150, 150
C.BOARD_WIDTH, C.BOARD_HEIGHT = 400, 400
C.WINDOW_WIDTH = C.BOARD_WIDTH + 32 + 16
C.WINDOW_HEIGHT = C.BOARD_HEIGHT + 110
C.MENU_WIDTH, C.MENU_HEIGHT = 160, 216
C.BOARD_COLS, C.BOARD_ROWS = 8, 8
C.SHARDS_PER_GEM = 10
C.HALF_SHARDS_PER_GEM = C.SHARDS_PER_GEM / 2

-- Effect types (gem.fxType and pooled effect objects). nil means no effect.
C.FX_NONE = nil
C.FX_DONE = -1
C.FX_SPIN = 1
C.FX_BIG_STAR = 3
C.FX_EXPLOSION = 4
C.FX_SHARD = 5
C.FX_DESTROY = 6
C.FX_SHINE = 7
C.FX_SHINE_NEIGHBOR = 8
C.FX_HYPERCUBE = 9
C.FX_FLOAT_TEXT = 10
C.FX_HINT = 12
C.FX_LIGHTWAVE = 13
C.FX_LIGHTNING = 14
C.FX_DROP_IN = 52

-- Effect lengths, in animation frames (one frame = C.FRAME_TIME seconds).
C.SPIN_FRAMES = 20
C.BIG_STAR_ROT_DEGREES = 360
C.EXPLOSION_FRAMES = 16
C.SHARD_FRAMES = 12
C.DESTROY_FRAMES = 4
C.SHINE_FRAMES = #C.FX_SHINE_ALPHA
C.SHINE_NEIGHBOR_FRAMES = #C.FX_SHINE_ALPHA
C.HYPERCUBE_FRAMES = 40
C.FLOAT_TEXT_FADE_FRAMES = 10
C.LIGHTNING_FRAMES = 15
C.HINT_DELAY_SECONDS = 25
C.GLOW_FRAMES = 40 -- glow pulse period
C.MAX_GLOW_LEVEL = 7 -- glow stack cap from nearby hypercubes/power gems
C.FRAME_TIME = 0.025

-- Gem motion (gem.moving)
C.MOVE_SWAP = 50
C.MOVE_FALL = 51
C.MOVE_FLY_OFF = 53
C.SWAP_DISTANCE = C.GEM_HEIGHT
C.GRAVITY = 20
C.SWAP_SPEED = 150
C.FALL_ACCEL = 60
C.FLOAT_TEXT_SPEED = 10
C.FADE_START_VELOCITY = C.GRAVITY / 2

-- animator.animationStatus
C.ANIM_IDLE = 0
C.ANIM_EXPLODING = 1
C.ANIM_COLLAPSING = 2
C.ANIM_DROPPING = 4
C.ANIM_SETTLED = 5
C.ANIM_LEVEL_TRANSITION = 6

-- Match axis passed to markGemDestroyed
C.MATCH_VERTICAL = 1
C.MATCH_HORIZONTAL = 2

-- Game modes
C.MODE_CLASSIC = 1
C.MODE_TIMED = 2
C.MODE_FLIGHT = 3
C.COMBO_POINTS = { 10, 20, 30, 40, 60, 80, 110, 160, 210 }
C.MODE_POINT_MULTIPLIER = { [C.MODE_CLASSIC] = 1, [C.MODE_TIMED] = 15, [C.MODE_FLIGHT] = 15 }

-- Swap directions { dx, dx, dy, dy }: left, right, up, down, then two half-steps.
C.NEIGHBOR_OFFSETS = {
    { -1, -1, 0, 0 },
    { 1, 1, 0, 0 },
    { 0, 0, -1, -1 },
    { 0, 0, 1, 1 },
    { -1, 0.5, 0, 0 },
    { 0, 0, -1, 0.5 },
}

-- Frame levels relative to the game area (filled in when the window is built).
C.FRAME_LEVEL_GEM_OFFSET = 2
C.FRAME_LEVEL_SWAP_OFFSET = 3
