local _, ns = ...
local C = ns.C

-- Shared game state: the 8x8 gem grid, the current game's fields, and gem reset.
-- board[row][col] holds gem frames (created by UI/GameArea.lua); gem.contents is
-- 0 (empty), 1..7 (color) or 9 (hypercube).

local GEM_WIDTH, GEM_HEIGHT = C.GEM_WIDTH, C.GEM_HEIGHT
local GEM_SPIN_TEXCOORDS = C.GEM_SPIN_TEXCOORDS

ns.board = {}
for row = 1, C.BOARD_ROWS do
    ns.board[row] = {}
end

ns.game = {
    round = 1,
    score = 0,
    paused = false,
    moveAllowed = nil,
    activeTime = 0,
}

-- Games played across all characters (filled from db.global.played at login), for the
-- 100/1000 games achievements.
ns.totalGamesAllChars = 0

-- Carry power gems and hypercubes over into the next board (set on level up, or when
-- resuming a classic game past level 1).
ns.keepSpecialsOnLevel = nil

function ns.resetGem(gem, gridX, gridY)
    for key, value in pairs(gem) do
        if type(value) == "number" then
            gem[key] = nil
        end
    end
    gem.markX = nil
    gem.markY = nil
    gem.spawnHyper = nil
    gem.adj = nil
    gem.swapJewel = nil
    gem.x = (gridX - 1) * GEM_WIDTH
    gem.y = (gridY - 1) * GEM_HEIGHT
    gem.gridX = gridX
    gem.gridY = gridY
    gem.texture:SetTexCoord(unpack(GEM_SPIN_TEXCOORDS[1]))
    gem.texture:SetWidth(GEM_WIDTH)
    gem.texture:SetHeight(GEM_HEIGHT)
    gem.fxType = C.FX_NONE
    gem.fxFrame = 1
    gem:Show()
    gem:SetAlpha(1)
    gem:ClearAllPoints()
    gem:SetWidth(GEM_WIDTH)
    gem:SetHeight(GEM_HEIGHT)
    gem:SetPoint("TOPLEFT", gem.x, -gem.y)
    gem.selector:Hide()
    gem.glowLevel = 0
end
