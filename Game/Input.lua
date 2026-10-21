local _, ns = ...
local Bejeweled = ns.addon
local C = ns.C

-- Gem mouse input: hover shine, click to select or swap, drag to swap with a neighbour.

local BOARD_ROWS, BOARD_COLS = C.BOARD_ROWS, C.BOARD_COLS
local FX_SPIN, FX_HYPERCUBE, FX_DESTROY = C.FX_SPIN, C.FX_HYPERCUBE, C.FX_DESTROY

-- Gems busy with another effect keep it instead of the hover shine.
local function canShine(gem)
    local fxType = gem.fxType
    return fxType ~= FX_SPIN
        and fxType ~= FX_HYPERCUBE
        and fxType ~= C.FX_DROP_IN
        and fxType ~= FX_DESTROY
        and fxType ~= C.FX_DONE
end

function Bejeweled:UpdateMouseOver(gem)
    if canShine(gem) then
        Bejeweled.animator:Add(gem)
        gem.fxType = C.FX_SHINE
        gem.fxFrame = C.SHINE_FRAMES
        gem.nextGlow = 0
        gem.fxEnd = nil
        gem.adj = nil
        gem.highlight:SetTexCoord(unpack(C.SHINE_TEXCOORDS[1]))
        gem.highlight:SetAlpha(0)
    end
end

function ns.onGemEnter(gem)
    if not ns.game.moveAllowed then
        -- Replayed by the animator once the board settles.
        ns.game.currentMouseOver = gem
        return
    end
    Bejeweled:UpdateMouseOver(gem)
end

function ns.onGemLeave(gem)
    if not ns.game.moveAllowed then
        ns.game.currentMouseOver = nil
        return
    end
    if canShine(gem) and not gem.moving then
        gem.fxEnd = true
        local adj = gem.adj
        if adj and adj.fxType == C.FX_SHINE_NEIGHBOR and adj.fxFrame <= C.SHINE_NEIGHBOR_FRAMES then
            -- Play the neighbour's shine backwards from where it is.
            adj.fxFrame = C.SHINE_NEIGHBOR_FRAMES - adj.fxFrame + 1
        end
        gem.adj = nil
    end
end

local function showHint()
    if not ns.db.profile.disableHints then
        local animator = Bejeweled.animator
        animator:Add(animator:CreateHint(ns.findHintGem()))
    end
end

-- Starts the swap tween of gem toward other.
local function startSwap(gem, other)
    gem.moving = C.MOVE_SWAP
    gem.xOffset = 0
    gem.yOffset = 0
    gem.xMove = math.abs(other.gridX - gem.gridX)
    gem.yMove = math.abs(other.gridY - gem.gridY)
    gem.xDir = other.gridX - gem.gridX
    gem.yDir = other.gridY - gem.gridY
    gem.swapJewel = other
end

local function swapContents(a, b)
    a.contents, b.contents = b.contents, a.contents
    a.bigStar, b.bigStar = b.bigStar, a.bigStar
end

local function countMove()
    local game = ns.game
    game.moves = game.moves + 1
    if game.statDB.mostMoves and game.moves > game.statDB.mostMoves then
        game.statDB.mostMoves = game.moves
    end
    if game.gameMode == C.MODE_CLASSIC then
        local const = Bejeweled.const
        if game.moves == 100 then
            Bejeweled.skillBar:CheckSkill(const.SKILLTYPE_CLASSIC, const.SKILL_MOVE100)
        end
        if game.moves == 250 then
            Bejeweled.skillBar:CheckSkill(const.SKILLTYPE_CLASSIC, const.SKILL_MOVE250)
        end
    end
end

-- Swaps the selected gem with its neighbour gem. Swapping a hypercube sets it off on the
-- other gem's color (two hypercubes: everything); otherwise a swap without a match bounces back.
local function swapWithSelected(gem)
    local game = ns.game
    local animator = Bejeweled.animator
    local selGem = game.selectedJewel
    local doubleHyper = selGem.fxType == FX_HYPERCUBE and gem.fxType == FX_HYPERCUBE
    local hyperSwap = doubleHyper
    animator:Add(selGem)
    animator:Add(gem)
    selGem.highlight:SetAlpha(0)
    gem.highlight:SetAlpha(0)
    selGem.mouseX, selGem.mouseY = nil, nil
    gem.mouseX, gem.mouseY = nil, nil

    if selGem.fxType ~= FX_HYPERCUBE then
        selGem.fxEnd = true
    elseif not doubleHyper then
        selGem.hyperGemContents = gem.contents
        hyperSwap = true
    end
    startSwap(selGem, gem)

    if gem.fxType ~= FX_HYPERCUBE then
        gem.fxType = C.FX_NONE
        gem.fxFrame = 1
    elseif not doubleHyper then
        gem.hyperGemContents = selGem.contents
        hyperSwap = true
    end
    startSwap(gem, selGem)

    gem.selector:Show()
    game.moveAllowed = nil
    animator.movingJewels = 2
    swapContents(selGem, gem)
    if doubleHyper then
        selGem.hyperGemContents = C.GEM_HYPERCUBE
        gem.hyperGemContents = C.GEM_HYPERCUBE
    end
    if not hyperSwap then
        if ns.findMatches() then
            countMove()
        else
            swapContents(selGem, gem)
            gem.invalidMove = 1
            selGem.invalidMove = 1
            Bejeweled.sound:Play("Invalid")
        end
    end
end

local function selectGem(gem)
    local game = ns.game
    game.selectedJewel = gem
    gem.mouseX, gem.mouseY = GetCursorPosition()
    gem.selector:Show()
    if gem.fxType ~= FX_HYPERCUBE then
        gem.fxType = FX_SPIN
        gem.fxEnd = nil
        gem.fxFrame = 1
    end
    gem.highlight:SetAlpha(0)
    Bejeweled.animator:Add(gem)
    Bejeweled.sound:Play("Select")
end

function ns.onGemMouseDown(gem)
    local game = ns.game
    if not game.gameMode or Bejeweled.paused == true then
        return
    end
    if not game.moveAllowed then
        -- Board busy: queue the click as the next selection (a second click cancels it).
        if not Bejeweled.animator.newGameStart then
            if game.nextSelectedJewel then
                ns.deselectGem(true)
            elseif gem.fxType ~= FX_DESTROY then
                game.nextSelectedJewel = gem
                gem.mouseX, gem.mouseY = GetCursorPosition()
                gem.selector:Show()
                gem.highlight:SetAlpha(0)
                Bejeweled.animator:Add(gem)
                Bejeweled.sound:Play("Select")
            end
        end
        return
    end
    showHint()
    local selected = game.selectedJewel
    if selected then
        local dx, dy = math.abs(gem.gridX - selected.gridX), math.abs(gem.gridY - selected.gridY)
        if dx + dy == 1 then
            swapWithSelected(gem)
        else
            ns.deselectGem()
        end
    else
        selectGem(gem)
    end
end

-- Dragging from a selected gem swaps it with the neighbour in the drag direction.
function ns.onGemDragStart(gem)
    if not gem.mouseX then
        return
    end
    showHint()
    local cursorX, cursorY = GetCursorPosition()
    local dx = cursorX - gem.mouseX
    local dy = cursorY - gem.mouseY
    local targetGem
    if dx ~= 0 or dy ~= 0 then
        if math.abs(dx) > math.abs(dy) then
            local targetCol = gem.gridX + (dx > 0 and 1 or -1)
            if targetCol > 0 and targetCol <= BOARD_COLS then
                targetGem = ns.board[gem.gridY][targetCol]
            end
        else
            -- Screen y grows upward, board rows grow downward.
            local targetRow = gem.gridY - (dy > 0 and 1 or -1)
            if targetRow > 0 and targetRow <= BOARD_ROWS then
                targetGem = ns.board[targetRow][gem.gridX]
            end
        end
    end
    if targetGem then
        ns.onGemMouseDown(targetGem)
    else
        if gem.fxType ~= FX_HYPERCUBE then
            gem.fxEnd = true
        end
        gem.selector:Hide()
        gem.mouseX = nil
        gem.mouseY = nil
        ns.game.selectedJewel = nil
    end
end
