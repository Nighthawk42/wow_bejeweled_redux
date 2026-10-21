local _, ns = ...
local C = ns.C

-- Texture lookup and texture packs. Every image the addon draws is an entry in the texture
-- database (Data/Textures.lua). A texture pack is a separate addon that supplies its own files
-- for some or all entries:
--
--   BejeweledRedux_RegisterTexturePack({
--       name = "HD",                                           -- shown in Options
--       path = "Interface\\AddOns\\BejeweledRedux_HD\\images\\",
--       extension = ".png",  -- optional: file type of this pack's images (default: as listed)
--       textures = {         -- optional: omit to supply every entry
--           gem = true,      -- this pack's file, default layout
--           logo = { file = "logo.png", size = { 1024, 256 }, regions = { logo = { 0, 0, 600, 200 } },
--                    display = { 285, 80 } },                 -- this pack's file and layout
--       },
--       font = "MyFont.ttf", -- optional
--   })
--
-- The active pack is chosen in Options and applied at login, before the interface is built.

local Textures = {}
ns.Textures = Textures

local packs = {} -- name -> definition, in registration order
local packOrder = {}
local active = {} -- key -> { path, file, size, regions, grid, display }
local activeFont

local function copyEntry(entry)
    local copy = {}
    for k, v in pairs(entry) do
        copy[k] = v
    end
    return copy
end

local function withExtension(file, extension)
    if not extension then
        return file
    end
    return (file:gsub("%.%w+$", "")) .. extension
end

local function validEntry(entry)
    return type(entry) == "table"
        and type(entry.file) == "string"
        and type(entry.size) == "table"
        and type(entry.size[1]) == "number"
        and type(entry.size[2]) == "number"
end

function BejeweledRedux_RegisterTexturePack(definition)
    if type(definition) ~= "table" or type(definition.name) ~= "string" or type(definition.path) ~= "string" then
        error("BejeweledRedux_RegisterTexturePack: a pack needs a name and a path", 2)
    end
    if definition.name == "Default" or packs[definition.name] then
        error("BejeweledRedux_RegisterTexturePack: a pack named '" .. definition.name .. "' already exists", 2)
    end
    packs[definition.name] = definition
    table.insert(packOrder, definition.name)
end

-- Names of the available packs, "Default" first.
function Textures.GetPackNames()
    local names = { "Default" }
    for _, name in ipairs(packOrder) do
        table.insert(names, name)
    end
    return names
end

-- Turns pixel rects into texture coordinates for the tables the animation code reads. A pack may
-- give an animation fewer frames than the default art (one frame = no animation); its frames are
-- repeated to fill the length the animation code expects.
local function fillFrames(target, key)
    local frames = Textures.Frames(key)
    local defaultGrid = ns.DefaultTextures.textures[key].grid
    wipe(target)
    for i = 1, math.max(#frames, defaultGrid[3] * defaultGrid[4]) do
        target[i] = frames[(i - 1) % #frames + 1]
    end
end

-- Resolves every entry for the named pack (unknown names fall back to Default).
function Textures.Activate(packName)
    local default = ns.DefaultTextures
    local pack = packs[packName]
    wipe(active)
    for key, entry in pairs(default.textures) do
        local resolved = copyEntry(entry)
        resolved.path = default.path
        active[key] = resolved
    end
    activeFont = default.path .. default.font

    if pack then
        for key, entry in pairs(active) do
            local override = pack.textures == nil or pack.textures[key]
            if override == true then
                entry.path = pack.path
                entry.file = withExtension(entry.file, pack.extension)
            elseif type(override) == "table" then
                if validEntry(override) then
                    local resolved = copyEntry(override)
                    resolved.path = pack.path
                    active[key] = resolved
                else
                    ns.addon:Print("Texture pack '" .. pack.name .. "': ignoring invalid entry '" .. key .. "'.")
                end
            end
        end
        if type(pack.font) == "string" then
            activeFont = pack.path .. pack.font
        end
    end

    fillFrames(C.GEM_SPIN_TEXCOORDS, "gem")
    fillFrames(C.EXPLOSION_TEXCOORDS, "explosion")
    fillFrames(C.HYPERCUBE_TEXCOORDS, "hypergem")
    fillFrames(C.SHARD_TEXCOORDS, "gemshards")
    fillFrames(C.SHINE_TEXCOORDS, "shine")
    Textures.activePack = pack and packName or "Default"
end

-- Full file path of an entry. colorName fills "%s" in per-color files (gem, shine, glow).
function Textures.Path(key, colorName)
    local entry = active[key]
    local file = entry.file
    if colorName then
        file = file:format(colorName)
    end
    return entry.path .. file
end

function Textures.Font()
    return activeFont
end

local function toCoords(entry, rect)
    local width, height = entry.size[1], entry.size[2]
    local left, right = rect[1] / width, (rect[1] + rect[3]) / width
    local top, bottom = rect[2] / height, (rect[2] + rect[4]) / height
    if rect.rotated then
        -- Stored turned 90 degrees: corners in SetTexCoord's UL, LL, UR, LR order.
        return { right, top, left, top, right, bottom, left, bottom }
    end
    return { left, right, top, bottom }
end

-- Texture coordinates of a named region: left, right, top, bottom (8 values when rotated).
function Textures.Coords(key, regionName)
    local entry = active[key]
    return unpack(toCoords(entry, entry.regions[regionName]))
end

-- Texture coordinates of every frame of a grid entry, as an array of { left, right, top, bottom }.
function Textures.Frames(key)
    local entry = active[key]
    local frameWidth, frameHeight, cols, rows = unpack(entry.grid)
    local frames = {}
    for row = 0, rows - 1 do
        for col = 0, cols - 1 do
            table.insert(frames, toCoords(entry, { col * frameWidth, row * frameHeight, frameWidth, frameHeight }))
        end
    end
    return frames
end

-- Region names that start with prefix, sorted: "tile", "tile2", "tile3", ...
function Textures.Variants(key, prefix)
    local names = {}
    for name in pairs(active[key].regions or {}) do
        if name:sub(1, #prefix) == prefix then
            table.insert(names, name)
        end
    end
    table.sort(names)
    return names
end

-- On-screen size of an entry that defines one.
function Textures.Display(key)
    local display = active[key].display
    return display[1], display[2]
end

-- Sets a texture's file and, if given, its region.
function Textures.Apply(texture, key, regionName)
    texture:SetTexture(Textures.Path(key))
    if regionName then
        texture:SetTexCoord(Textures.Coords(key, regionName))
    end
end
