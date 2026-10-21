local _, ns = ...
local Bejeweled = ns.addon
local C = ns.C

-- Pooled visual effects (big stars, explosions, shards, lightwaves, lightning, floating score
-- text, the hint arrow) and the gem frame builder. These become methods of Bejeweled.animator
-- (see Animation/Animator.lua), which drives them every frame.

local GEM_WIDTH, GEM_HEIGHT = C.GEM_WIDTH, C.GEM_HEIGHT
local GEM_HALF_WIDTH, GEM_HALF_HEIGHT = C.GEM_HALF_WIDTH, C.GEM_HALF_HEIGHT
local SHARD_WIDTH, SHARD_HEIGHT = C.SHARD_WIDTH, C.SHARD_HEIGHT
local SHARD_HALF_WIDTH, SHARD_HALF_HEIGHT = C.SHARD_HALF_WIDTH, C.SHARD_HALF_HEIGHT
local BIG_STAR_WIDTH, BIG_STAR_HEIGHT = C.BIG_STAR_WIDTH, C.BIG_STAR_HEIGHT
local EXPLOSION_WIDTH, EXPLOSION_HEIGHT = C.EXPLOSION_WIDTH, C.EXPLOSION_HEIGHT
local SHARDS_PER_GEM, HALF_SHARDS_PER_GEM = C.SHARDS_PER_GEM, C.HALF_SHARDS_PER_GEM
local SHARD_FRAMES = C.SHARD_FRAMES
local GEM_COLOR_NAMES, GEM_RGB_COLORS = C.GEM_COLOR_NAMES, C.GEM_RGB_COLORS
local GEM_HYPERCUBE = C.GEM_HYPERCUBE
local FX_BIG_STAR, FX_EXPLOSION, FX_SHARD, FX_DESTROY = C.FX_BIG_STAR, C.FX_EXPLOSION, C.FX_SHARD, C.FX_DESTROY
local FX_HYPERCUBE, FX_HINT, FX_LIGHTWAVE, FX_LIGHTNING = C.FX_HYPERCUBE, C.FX_HINT, C.FX_LIGHTWAVE, C.FX_LIGHTNING
local HYPERCUBE_TEXCOORDS, EXPLOSION_TEXCOORDS = C.HYPERCUBE_TEXCOORDS, C.EXPLOSION_TEXCOORDS
local SHARD_TEXCOORDS, SHINE_TEXCOORDS = C.SHARD_TEXCOORDS, C.SHINE_TEXCOORDS

local LIGHTNING_THICKNESS = 48
local LIGHTNING_CORE_THICKNESS = 32

local random = math.random
local tinsert, tremove = table.insert, table.remove
local unpack = unpack

-- Push obj onto the animation stack once.
function ns.animatorAdd(self, obj)
    if not obj.animated then
        tinsert(self.animationStack, obj)
        obj.animated = true
    end
end

-- Rotate a square texture around (centerX, centerY) in texcoord space; angle in whole degrees.
local function animatorRotateTexture(self, texture, angle, centerX, centerY)
    if angle <= 0 then
        angle = 360 + angle
    end
    local sinA = self.tableSin[angle]
    local cosA = self.tableCos[angle]
    texture:SetTexCoord(
        centerX - sinA,
        centerY + cosA,
        centerX + cosA,
        centerY + sinA,
        centerX - cosA,
        centerY - sinA,
        centerX + sinA,
        centerY - cosA
    )
end

-- A frame with a centered .texture (ARTWORK, or OVERLAY) and an additive .highlight.
local function animatorCreateImage(self, x, y, width, height, parent, overlay)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", x, -y)
    frame:SetSize(width, height)
    frame:Show()
    frame.texture = frame:CreateTexture(nil, overlay and "OVERLAY" or "ARTWORK")
    frame.texture:SetSize(width, height)
    frame.texture:SetPoint("CENTER")
    frame.texture:Show()
    frame.highlight = frame:CreateTexture(nil, "OVERLAY")
    frame.highlight:SetSize(width, height)
    frame.highlight:SetBlendMode("ADD")
    frame.highlight:SetPoint("CENTER")
    frame.highlight:Show()
    frame.x = x
    frame.y = y
    return frame
end

function ns.createGemFrame(x, y, parent, color)
    local frame = Bejeweled.animator:CreateImage(x, y, GEM_WIDTH, GEM_HEIGHT, parent)
    frame.texture:SetTexture(ns.Textures.Path("gem", GEM_COLOR_NAMES[color]))
    frame.texture:SetTexCoord(0, 0, 0, 0)
    frame.highlight:SetTexture(ns.Textures.Path("shine", GEM_COLOR_NAMES[color]))
    frame.highlight:SetTexCoord(0, 0, 0, 0)
    frame.selector = frame:CreateTexture(nil, "OVERLAY")
    frame.selector:SetTexture(ns.Textures.Path("selector"))
    frame.selector:SetSize(GEM_WIDTH, GEM_HEIGHT)
    frame.selector:SetPoint("CENTER")
    frame.selector:Hide()
    frame.glow = frame:CreateTexture(nil, "OVERLAY")
    frame.glow:SetSize(GEM_WIDTH, GEM_HEIGHT)
    frame.glow:SetPoint("TOPLEFT", frame.texture)
    frame.glow:SetPoint("BOTTOMRIGHT", frame.texture)
    frame.glow:SetAlpha(0)
    frame.glowLevel = 0
    frame.fxType = nil
    frame.fxFrame = 1
    return frame
end

local function animatorCreateHyperGem(self, gem)
    gem.texture:SetTexture(ns.Textures.Path("hypergem"))
    gem.texture:SetTexCoord(unpack(HYPERCUBE_TEXCOORDS[1]))
    gem.highlight:SetTexture(ns.Textures.Path("shine", "white"))
    gem.highlight:SetTexCoord(0, 0, 0, 0)
    gem.glow:SetTexCoord(0, 0, 0, 0)
    gem.fxType = FX_HYPERCUBE
    gem.fxFrame = 1
    gem.contents = GEM_HYPERCUBE
end

-- Power-gem star overlay: two counter-rotating layers that cross-fade.
local function animatorCreateBigStar(self, x, y, parentGem)
    local star = tremove(self.bigStarQueue, 1)
    if not star then
        star = self:CreateImage(x, y, GEM_WIDTH, GEM_HEIGHT, parentGem, true)
        star.texture:SetTexture(ns.Textures.Path("bigstar"))
        star.texture:SetSize(BIG_STAR_WIDTH, BIG_STAR_HEIGHT)
        star.highlight:SetTexture(ns.Textures.Path("bigstar"))
        star.highlight:SetSize(BIG_STAR_WIDTH, BIG_STAR_HEIGHT)
    end
    star:ClearAllPoints()
    star:SetPoint("TOPLEFT", parentGem, "TOPLEFT")
    star.fxType = FX_BIG_STAR
    star.fxFrame = 1
    star.fxFrame2 = 1
    star.fxAlpha = 100
    star.fxAlphaStep = -3
    star:SetAlpha(1)
    star:Show()
    star.parent = parentGem
    return star
end

local function animatorCreateExplosion(self, x, y, gem)
    local explosion = tremove(self.explosionQueue, 1)
    if not explosion then
        explosion = self:CreateImage(x, y, GEM_WIDTH, GEM_HEIGHT, Bejeweled.gameBoard)
        explosion.texture:SetTexture(ns.Textures.Path("explosion"))
        explosion.texture:SetSize(EXPLOSION_WIDTH, EXPLOSION_HEIGHT)
    end
    explosion.x = gem.x
    explosion.y = gem.y
    explosion:ClearAllPoints()
    explosion:SetPoint("TOPLEFT", Bejeweled.gameBoard, "TOPLEFT", explosion.x, -explosion.y)
    explosion.texture:SetTexCoord(unpack(EXPLOSION_TEXCOORDS[1]))
    explosion:Show()
    explosion.fxType = FX_EXPLOSION
    explosion.fxFrame = 1
    Bejeweled.sound:Play("Explosion")
    return explosion
end

-- The single hint arrow. It stays hidden until FX_HINT has waited HINT_DELAY_SECONDS.
local function animatorCreateHint(self, gem)
    local hint = self.hintObj
    if not hint then
        hint = self:CreateImage(0, 0, 64, 64, Bejeweled.foreground, true)
        hint.texture:SetTexture(ns.Textures.Path("hintArrow"))
        self.hintObj = hint
    end
    if gem then
        hint.x = gem.x + 2
        hint.y = gem.y - GEM_HALF_HEIGHT
        hint:ClearAllPoints()
        hint:SetPoint("TOPLEFT", hint.x, -hint.y)
        hint.fxType = FX_HINT
        hint.fxFrame = 0
    end
    hint:SetAlpha(1)
    hint:Hide()
    hint.bounceY = 0
    hint.bounceDir = 1
    return hint
end

-- Ambient shine passing over a gem. A negative fxFrame delays the start (staggered by row).
local function animatorCreateLightwave(self, gem, delay)
    local wave = tremove(self.lightwaveQueue, 1)
    if not wave then
        wave = self:CreateImage(0, 0, GEM_WIDTH, GEM_HEIGHT, gem, true)
    end
    wave:ClearAllPoints()
    wave:SetParent(gem)
    wave.texture:SetTexture(gem.highlight:GetTexture())
    wave:SetAllPoints(gem.texture)
    wave:Show()
    wave.texture:SetTexCoord(unpack(SHINE_TEXCOORDS[2]))
    wave:SetAlpha(0)
    wave.fxType = FX_LIGHTWAVE
    wave.fxFrame = -(delay * 2) - 1
    gem.lightWaveObj = wave
    return wave
end

-- Hypercube bolt from (x1, y1) to (x2, y2), in game-board coordinates (y grows downward).
-- The object is a container frame so Show/Hide/SetAlpha affect both lines; .highlight is the
-- bright core that flickers.
local function animatorCreateLightning(self, x1, y1, x2, y2, color)
    local bolt = tremove(self.lightningQueue, 1)
    if not bolt then
        local foreground = Bejeweled.foreground
        bolt = CreateFrame("Frame", nil, foreground)
        bolt:SetAllPoints(foreground)
        bolt.line = bolt:CreateLine(nil, "ARTWORK")
        bolt.line:SetTexture(ns.Textures.Path("lightning"))
        bolt.line:SetThickness(LIGHTNING_THICKNESS)
        bolt.highlight = bolt:CreateLine(nil, "OVERLAY")
        bolt.highlight:SetTexture(ns.Textures.Path("lightningbright"))
        bolt.highlight:SetBlendMode("ADD")
        bolt.highlight:SetThickness(LIGHTNING_CORE_THICKNESS)
    end
    local board = Bejeweled.gameBoard
    for _, line in ipairs({ bolt.line, bolt.highlight }) do
        line:ClearAllPoints()
        line:SetStartPoint("TOPLEFT", board, x1, -y1)
        line:SetEndPoint("TOPLEFT", board, x2, -y2)
    end
    bolt.line:SetVertexColor(unpack(GEM_RGB_COLORS[color]))
    bolt.fxType = FX_LIGHTNING
    bolt.fxFrame = 1
    bolt:SetAlpha(1)
    bolt:Show()
    bolt.highlight:Show()
    return bolt
end

local function animatorCreateShard(self, offX, offY, gem, color)
    local shard = tremove(self.shardQueue, 1)
    if not shard then
        shard = self:CreateImage(offX, offY, SHARD_WIDTH, SHARD_HEIGHT, Bejeweled.gameBoard, true)
        shard.texture:SetTexture(ns.Textures.Path("gemshards"))
    end
    shard.x = gem.x + offX
    shard.y = gem.y + offY
    shard:ClearAllPoints()
    shard:SetPoint("TOPLEFT", shard.x, -shard.y)
    shard.texture:SetTexCoord(unpack(SHARD_TEXCOORDS[1]))
    shard.texture:SetVertexColor(unpack(GEM_RGB_COLORS[color]))
    shard:SetAlpha(1)
    shard.yVel = 0
    shard.xVel = 0
    shard:Show()
    shard.fxType = FX_SHARD
    shard.fxFrame = random(1, SHARD_FRAMES)
    return shard
end

-- Destroy a gem by force (power-gem blast or hypercube). A power gem is only marked to explode
-- (and scored unless noScore); any other gem is cleared and bursts into shards flying along
-- (dirX, dirY). A zero direction clears the gem without shards.
local function animatorCreateShardSpawn(self, x, y, gem, color, dirX, dirY, noScore)
    local game = ns.game
    if gem.bigStar and not gem.explode then
        gem.explode = 1
        gem.fxType = FX_DESTROY
        self:Add(gem)
        if not noScore then
            game.explosions = game.explosions + 1
            ns.awardMatchScore(1, gem, color, nil, nil, game.explosions)
        end
    elseif gem.contents ~= 0 then
        if gem.contents == GEM_HYPERCUBE then
            color = GEM_HYPERCUBE
            ns.awardMatchScore(1, gem, color, nil, true, 0)
        end
        gem.contents = 0
        ns.refreshGemTexture(gem)
        if dirX ~= 0 or dirY ~= 0 then
            local sign
            for shardIndex = 1, SHARDS_PER_GEM do
                sign = shardIndex > HALF_SHARDS_PER_GEM and 1 or -1
                local yVelBase = dirY * random(4, 7)
                if dirY == 0 then
                    yVelBase = sign * random(1, 5)
                end
                if dirX < 0 then
                    sign = -1
                elseif dirX > 0 then
                    sign = 1
                end
                local xSpeed = random(4, 7)
                if dirX == 0 then
                    xSpeed = 2
                end
                local shard = self:CreateShard(
                    x + GEM_HALF_WIDTH - SHARD_HALF_WIDTH + (12 - random(1, 24)),
                    y + GEM_HALF_HEIGHT - SHARD_HALF_HEIGHT + (12 - random(1, 24)),
                    gem,
                    color
                )
                shard.yVel = yVelBase + dirY * random(1, 5)
                if dirX == 0 then
                    if dirY == -1 then
                        shard.xVel = sign * 3 / random(1, 5)
                    else
                        shard.xVel = sign * random(0, 5)
                    end
                else
                    shard.xVel = sign * xSpeed + sign * random(1, xSpeed)
                end
                tinsert(self.animationStack, shard)
            end
        end
    end
end

-- Score caption. It starts hidden as FX_DESTROY and pops up (FX_FLOAT_TEXT) during the explode phase.
local function animatorCreateFloatingText(self, x, y, text, color, notScore)
    local foreground = Bejeweled.foreground
    local caption = tremove(self.floatingTextQueue, 1)
    if caption then
        caption:SetText(text)
    else
        caption = Bejeweled:CreateCaption(x, y, text, foreground, 30, 1, 1, 1, true)
    end
    caption.x = x
    caption.y = y
    if notScore then
        caption:SetTextColor(1, 0.4, 1)
    else
        caption:SetTextColor(unpack(GEM_RGB_COLORS[color] or GEM_RGB_COLORS[GEM_HYPERCUBE]))
    end
    caption:ClearAllPoints()
    caption:SetPoint("TOPLEFT", foreground, "TOPLEFT", x, -y)
    caption:SetAlpha(1)
    caption:Hide()
    caption.score = text
    caption.notScore = notScore
    caption.comboSound = nil
    caption.fxType = FX_DESTROY
    caption.fxFrame = 0
    return caption
end

ns.animatorMethods = {
    Add = ns.animatorAdd,
    RotateTexture = animatorRotateTexture,
    CreateImage = animatorCreateImage,
    CreateHyperGem = animatorCreateHyperGem,
    CreateBigStar = animatorCreateBigStar,
    CreateExplosion = animatorCreateExplosion,
    CreateHint = animatorCreateHint,
    CreateLightwave = animatorCreateLightwave,
    CreateLightning = animatorCreateLightning,
    CreateShard = animatorCreateShard,
    CreateShardSpawn = animatorCreateShardSpawn,
    CreateFloatingText = animatorCreateFloatingText,
}
