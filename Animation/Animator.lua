local _, ns = ...
local Bejeweled = ns.addon
local C = ns.C

-- The animator: an invisible frame whose OnUpdate steps every gem and effect in fixed
-- C.FRAME_TIME (0.025 s) frames, and drives the board state machine
-- (idle -> exploding -> collapsing -> dropping -> settled -> cascade or idle).

local BOARD_ROWS, BOARD_COLS = C.BOARD_ROWS, C.BOARD_COLS
local GEM_WIDTH, GEM_HEIGHT, GEM_HALF_HEIGHT = C.GEM_WIDTH, C.GEM_HEIGHT, C.GEM_HALF_HEIGHT
local GEM_HYPERCUBE = C.GEM_HYPERCUBE
local MODE_CLASSIC = C.MODE_CLASSIC

local FX_DONE, FX_SPIN, FX_BIG_STAR, FX_EXPLOSION = C.FX_DONE, C.FX_SPIN, C.FX_BIG_STAR, C.FX_EXPLOSION
local FX_SHARD, FX_DESTROY, FX_SHINE, FX_SHINE_NEIGHBOR = C.FX_SHARD, C.FX_DESTROY, C.FX_SHINE, C.FX_SHINE_NEIGHBOR
local FX_HYPERCUBE, FX_FLOAT_TEXT, FX_HINT = C.FX_HYPERCUBE, C.FX_FLOAT_TEXT, C.FX_HINT
local FX_LIGHTWAVE, FX_LIGHTNING, FX_DROP_IN = C.FX_LIGHTWAVE, C.FX_LIGHTNING, C.FX_DROP_IN

local SPIN_FRAMES, BIG_STAR_ROT_DEGREES = C.SPIN_FRAMES, C.BIG_STAR_ROT_DEGREES
local EXPLOSION_FRAMES, SHARD_FRAMES, DESTROY_FRAMES = C.EXPLOSION_FRAMES, C.SHARD_FRAMES, C.DESTROY_FRAMES
local SHINE_FRAMES, SHINE_NEIGHBOR_FRAMES = C.SHINE_FRAMES, C.SHINE_NEIGHBOR_FRAMES
local HYPERCUBE_FRAMES, FLOAT_TEXT_FADE_FRAMES = C.HYPERCUBE_FRAMES, C.FLOAT_TEXT_FADE_FRAMES
local LIGHTNING_FRAMES, HINT_DELAY_SECONDS = C.LIGHTNING_FRAMES, C.HINT_DELAY_SECONDS
local GLOW_FRAMES, MAX_GLOW_LEVEL = C.GLOW_FRAMES, C.MAX_GLOW_LEVEL

local MOVE_SWAP, MOVE_FALL, MOVE_FLY_OFF = C.MOVE_SWAP, C.MOVE_FALL, C.MOVE_FLY_OFF
local SWAP_DISTANCE, GRAVITY, SWAP_SPEED = C.SWAP_DISTANCE, C.GRAVITY, C.SWAP_SPEED
local FALL_ACCEL, FLOAT_TEXT_SPEED, FADE_START_VELOCITY = C.FALL_ACCEL, C.FLOAT_TEXT_SPEED, C.FADE_START_VELOCITY

local ANIM_IDLE, ANIM_EXPLODING, ANIM_COLLAPSING = C.ANIM_IDLE, C.ANIM_EXPLODING, C.ANIM_COLLAPSING
local ANIM_DROPPING, ANIM_SETTLED, ANIM_LEVEL_TRANSITION = C.ANIM_DROPPING, C.ANIM_SETTLED, C.ANIM_LEVEL_TRANSITION

local GEM_SPIN_TEXCOORDS, EXPLOSION_TEXCOORDS = C.GEM_SPIN_TEXCOORDS, C.EXPLOSION_TEXCOORDS
local HYPERCUBE_TEXCOORDS, SHARD_TEXCOORDS, SHINE_TEXCOORDS = C.HYPERCUBE_TEXCOORDS, C.SHARD_TEXCOORDS, C.SHINE_TEXCOORDS
local FX_SHINE_ALPHA, FX_SHINE_KEYFRAME = C.FX_SHINE_ALPHA, C.FX_SHINE_KEYFRAME
local FX_SHINE_GRIDX, FX_SHINE_GRIDY = C.FX_SHINE_GRIDX, C.FX_SHINE_GRIDY

local LIGHTWAVE_INTERVAL = 25

local random, floor, abs, min, fmod = math.random, math.floor, math.abs, math.min, math.fmod
local tinsert, tremove = table.insert, table.remove
local unpack = unpack

-- Place one carried-over special on a random cell (6 random tries, then a linear scan from
-- the last try). accept(gem) returns true when the gem took it.
local function placeOnRandomGem(board, accept)
    local col, row
    for try = 1, 6 do
        col = random(1, BOARD_COLS)
        row = random(1, BOARD_ROWS)
        if accept(board[row][col]) then
            return
        end
        if try == 6 then
            for _ = 1, BOARD_COLS * BOARD_ROWS do
                col = col + 1
                if col > BOARD_COLS then
                    col = 1
                    row = row + 1
                    if row > BOARD_ROWS then
                        row = 1
                    end
                end
                if accept(board[row][col]) then
                    return
                end
            end
        end
    end
end

-- ANIM_DROPPING: refill every empty cell with a new gem placed above the board, once per drop.
local function animatorHandleJewelDropping(self)
    if self.spawnedJewels then
        return
    end
    self.spawnedJewels = true
    local board, game = ns.board, ns.game
    game.gemsCleared = game.gemsCleared or 0
    local gem, dropGap
    for col = 1, BOARD_COLS do
        self.columnOffset[col] = GEM_HEIGHT
        if self.spawningLevel then
            self.columnOffset[col] = GEM_HEIGHT + random(1, 400)
        end
        for row = BOARD_ROWS, 1, -1 do
            if board[row][col].contents == 0 then
                gem = board[row][col]
                if not self.spawningLevel then
                    game.gemsCleared = game.gemsCleared + 1
                end
                tinsert(self.newJewel, gem)
                if self.spawningLevel and ns.keepSpecialsOnLevel then
                    if gem.wasHyper then
                        gem.wasHyper = nil
                        game.hyperSpawn = (game.hyperSpawn or 0) + 1
                    end
                    if gem.bigStar then
                        game.bigStarSpawn = (game.bigStarSpawn or 0) + 1
                        gem.bigStar:Hide()
                        gem.bigStar.fxEnd = nil
                        gem.bigStar.explode = nil
                        gem.bigStar.fxType = FX_DONE
                        tinsert(self.bigStarQueue, gem.bigStar)
                        gem.bigStar = nil
                        gem.explode = nil
                    end
                end
                ns.spawnRandomGem(col, row, self.spawningLevel)
                dropGap = random(30, 50)
                if self.spawningLevel then
                    dropGap = dropGap * 2
                end
                gem.y = -self.columnOffset[col] - GEM_HALF_HEIGHT - dropGap
                gem.maxYOffset = self.columnOffset[col] + (GEM_HEIGHT * (gem.gridY - 1)) + GEM_HALF_HEIGHT + dropGap
                self.columnOffset[col] = self.columnOffset[col] + GEM_HEIGHT + dropGap
                gem.yOffset = 0
                if self.spawningLevel then
                    gem.yVel = 0
                else
                    gem.yVel = gem.yVel or 0
                end
                gem.moving = MOVE_FALL
                gem.fxType = FX_DROP_IN
                gem.fxFrame = 1
                self:Add(gem)
                gem:SetSize(GEM_WIDTH, GEM_HEIGHT)
                ns.refreshGemTexture(gem)
                gem:SetAlpha(1)
                if gem.lightWaveObj then
                    gem.lightWaveObj:Hide()
                end
                gem:ClearAllPoints()
                gem:SetPoint("TOPLEFT", gem.x, -gem.y)
            end
        end
    end

    -- Make sure the refilled board has a move: re-roll the new gems, and after 50 failed
    -- tries plant an exploding power gem on one of them. Without new gems nothing can change.
    local newJewel = self.newJewel
    if (game.gameMode ~= MODE_CLASSIC or game.level == 1) and #newJewel > 0 then
        for attempt = 1, 200 do
            if ns.findHintGem() then
                break
            end
            for i = 1, #newJewel do
                newJewel[i].contents = 0
            end
            for i = 1, #newJewel do
                ns.spawnRandomGem(newJewel[i].gridX, newJewel[i].gridY, true, true)
            end
            if attempt == 50 then
                local first = newJewel[1]
                local star = self:CreateBigStar(0, 0, first)
                first.explode = 1
                first.fxType = FX_DESTROY
                first.bigStar = star
                first.forcedExplode = 1
                self:Add(star)
                self.forceBlow = true
            end
        end
    end

    if self.spawningLevel then
        if (game.bigStarSpawn or 0) > 0 then
            for _ = 1, game.bigStarSpawn do
                placeOnRandomGem(board, function(target)
                    if target.bigStar then
                        return false
                    end
                    target.bigStar = self:CreateBigStar(0, 0, target)
                    target.bigStar:Hide()
                    self:Add(target.bigStar)
                    return true
                end)
            end
            game.bigStarSpawn = 0
        end
        if (game.hyperSpawn or 0) > 0 then
            for _ = 1, game.hyperSpawn do
                placeOnRandomGem(board, function(target)
                    if target.bigStar or target.spawnHyper then
                        return false
                    end
                    target.spawnHyper = true
                    return true
                end)
            end
            game.hyperSpawn = 0
        end
        self.spawningLevel = nil
        if not self.newGameStart then
            ns.levelUp()
        end
    end

    local const = Bejeweled.const
    if not ns.db.char.skill["gainAchieve" .. const.SKILL_ACHIEVE2A] and ns.db.char.stats.totalGemsMatched >= 1000 then
        Bejeweled.skillBar:CheckSkill(const.SKILLTYPE_ACHIEVEMENT, const.SKILL_ACHIEVE2A)
    end
end

-- ANIM_COLLAPSING: pull the nearest gem above down into every empty cell.
local function animatorHandleJewelFalling(self)
    local board, game = ns.board, ns.game
    for row = BOARD_ROWS, 1, -1 do
        for col = 1, BOARD_COLS do
            if board[row][col].contents == 0 then
                for srcRow = row - 1, 1, -1 do
                    local src = board[srcRow][col]
                    if src.contents ~= 0 then
                        local gem = board[row][col]
                        gem.contents = src.contents
                        if src.bigStar then
                            gem.bigStar = src.bigStar
                            src.bigStar = nil
                            gem.bigStar:ClearAllPoints()
                            gem.bigStar:SetPoint("TOPLEFT", gem, "TOPLEFT")
                            gem.bigStar.parent = gem
                        end
                        src.contents = 0
                        gem.maxYOffset = gem.y - src.y
                        gem.y = src.y
                        gem.needsOffset = nil
                        gem.yOffset = src.yOffset or 0
                        gem.yVel = src.yVel or 0
                        gem.moving = MOVE_FALL
                        gem.fxType = nil
                        gem.fxFrame = 1
                        if gem.contents == GEM_HYPERCUBE then
                            gem.fxType = FX_HYPERCUBE
                        end
                        if src == game.nextSelectedJewel then
                            ns.deselectGem(true)
                            game.nextSelectedJewel = gem
                            gem.selector:Show()
                            if gem.fxType ~= FX_HYPERCUBE then
                                gem.fxType = FX_SPIN
                                gem.fxEnd = nil
                                gem.fxFrame = 1
                            end
                            gem.highlight:SetAlpha(0)
                        end
                        self:Add(gem)
                        ns.refreshGemTexture(gem)
                        ns.refreshGemTexture(src)
                        gem:ClearAllPoints()
                        gem:SetPoint("TOPLEFT", gem.x, -gem.y)
                        break
                    end
                end
            end
        end
    end
end

-- 3-2-1-Go countdown at the start of a game.
local function animatorHandleNewGameCountdown(self)
    local statusText = Bejeweled.gameStatusText
    self.countdown = (self.countdown or 0) - self.elapsed
    if self.countdown >= 0 then
        return
    end
    if self.hintObj then
        self.hintObj.fxFrame = 0
    end
    self.countdown = 1
    self.countdownState = (self.countdownState or 4) - 1
    if self.countdownState > 0 then
        if self.countdownState == 3 then
            Bejeweled.sound:Play("GetReady")
        end
        statusText:SetText(tostring(self.countdownState))
        statusText:Show()
        statusText.background:Show()
        return
    end
    self.countdownState = nil
    self.countdown = nil
    self.newGameStart = nil
    statusText:SetText("Go")
    Bejeweled.sound:Play("Go")
    if not ns.db.profile.disableHints then
        self:Add(self:CreateHint(ns.findHintGem()))
    end
    if ns.game.gameMode ~= MODE_CLASSIC then
        Bejeweled.levelBar:StartTimer()
    end
    local fadeInfo = {
        mode = "OUT",
        timeToFade = 3,
        startAlpha = 1,
        endAlpha = 0,
        finishedFunc = function()
            statusText:SetAlpha(1)
            statusText.background:SetAlpha(1)
            statusText:Hide()
            statusText.background:Hide()
        end,
    }
    UIFrameFade(statusText, fadeInfo)
    UIFrameFade(statusText.background, fadeInfo)
    ns.game.moveAllowed = true
end

-- Called when nothing is animating any more: advance to the next status.
local function animatorHandleStatusChange(self, status)
    local game = ns.game
    self.animationStatus = status + 1
    if self.animationStatus == ANIM_DROPPING then
        self.spawnedJewels = nil
    end
    if self.animationStatus == ANIM_SETTLED and self.newGameStart then
        self.animationStatus = ANIM_IDLE
    end
    if self.animationStatus ~= ANIM_SETTLED and self.animationStatus <= ANIM_LEVEL_TRANSITION then
        return
    end

    if ns.findMatches() or self.forceBlow == true then
        self.animationStatus = ANIM_EXPLODING
        self.forceBlow = nil
        return
    end

    local const = Bejeweled.const
    local gemsCleared = game.gemsCleared or 0
    if gemsCleared >= 10 then
        Bejeweled.skillBar:CheckSkill(const.SKILLTYPE_GEMCOMBO, const.SKILL_CLEAR10)
    end
    if gemsCleared >= 15 then
        Bejeweled.skillBar:CheckSkill(const.SKILLTYPE_GEMCOMBO, const.SKILL_CLEAR15)
    end
    if gemsCleared >= 20 then
        Bejeweled.skillBar:CheckSkill(const.SKILLTYPE_GEMCOMBO, const.SKILL_CLEAR20)
    end
    if gemsCleared >= 25 then
        Bejeweled.skillBar:CheckSkill(const.SKILLTYPE_GEMCOMBO, const.SKILL_CLEAR25)
    end
    game.gemsCleared = 0

    if game.leveledUp then
        game.leveledUp = nil
        game.levelingUp = true
        self.animationStatus = ANIM_LEVEL_TRANSITION
        self.spawningLevel = true
        ns.blowAwayAllGems()
        return
    end

    -- The level-up / game-over wipe has finished.
    if self.animationStatus > ANIM_LEVEL_TRANSITION then
        if game.gameOver then
            Bejeweled.summaryScreen:FillData()
            Bejeweled.summaryScreen:Show()
            self.animationStatus = ANIM_IDLE
        else
            self.animationStatus = ANIM_DROPPING
        end
        self.spawnedJewels = nil
        return
    end

    local statusText = Bejeweled.gameStatusText
    if not game.gameOver then
        if game.levelingUp then
            UIFrameFadeOut(statusText, 2)
            UIFrameFadeOut(statusText.background, 2)
        else
            statusText:Hide()
            statusText.background:Hide()
        end
    end
    game.levelingUp = nil
    self.animationStatus = ANIM_IDLE
    if not game.gameOver then
        game.moveAllowed = true
    end
    if game.combo > game.largestCombo then
        game.largestCombo = game.combo
    end
    local stats = ns.db.char.stats
    if game.combo > stats.largestCombo then
        stats.largestCombo = game.combo
    end
    if game.nextSelectedJewel then
        game.selectedJewel = game.nextSelectedJewel
        game.nextSelectedJewel = nil
        if game.selectedJewel.fxType ~= FX_HYPERCUBE then
            game.selectedJewel.fxType = FX_SPIN
            game.selectedJewel.fxEnd = nil
            game.selectedJewel.fxFrame = 1
        end
        self:Add(game.selectedJewel)
    end
    game.combo = 0
    game.explosions = 0
    local hintGem = ns.findHintGem()
    if not hintGem then
        ns.endGame()
    else
        if not ns.db.profile.disableHints then
            self:Add(self:CreateHint(hintGem))
        end
        if game.gameMode == MODE_CLASSIC then
            ns.saveGameState()
        end
    end
    if game.currentMouseOver then
        Bejeweled:UpdateMouseOver(game.currentMouseOver)
        game.currentMouseOver = nil
    end
end

-- Add glow to the 5x5 area around (gridX, gridY): +2 for the inner ring, +1 for the outer.
local function glowAround(board, gridX, gridY, glowAlphaUnit)
    for dy = -2, 2 do
        local row = gridY + dy
        if row > 0 and row <= BOARD_ROWS then
            for dx = -2, 2 do
                local col = gridX + dx
                if col > 0 and col <= BOARD_COLS then
                    local nearGem = board[row][col]
                    if abs(dy) == 2 or abs(dx) == 2 then
                        nearGem.glowLevel = min(nearGem.glowLevel + 1, MAX_GLOW_LEVEL)
                    else
                        nearGem.glowLevel = min(nearGem.glowLevel + 2, MAX_GLOW_LEVEL)
                    end
                    if nearGem.fxType == FX_SPIN or nearGem.y < -5 then
                        nearGem.glow:SetAlpha(0)
                    else
                        nearGem.glow:SetAlpha(nearGem.glowLevel * glowAlphaUnit)
                    end
                end
            end
        end
    end
end

local function showFirstTimeTip(flag, tip, obj)
    local global = ns.db.global
    if not global[flag] then
        global[flag] = true
        local popup = Bejeweled.popup
        popup.text:SetText(popup.text[tip])
        popup.parent = obj
        popup:Hide()
        popup:Show()
    end
end

-- Knock a gem loose so it falls back into place after a power-gem blast.
local function loosenGem(self, gem, straightUp)
    if straightUp then
        gem.yVel = -20
    else
        gem.yVel = gem.yVel or -10
    end
    gem.moving = MOVE_FALL
    gem.yOffset = gem.yOffset or 0
    self:Add(gem)
end

-- Power gem detonation: explosion, shatter the 3x3 area, and toss the gems above it.
local function explodeBigStar(self, board, game, obj)
    obj.fxType = nil
    obj.bigStar:Hide()
    obj.bigStar.fxEnd = true
    obj.bigStar = nil
    obj.explode = nil
    local forced = obj.forcedExplode
    obj.forcedExplode = nil
    tinsert(self.animationStack, self:CreateExplosion(0, 0, obj))
    for dy = -1, 1 do
        local row = obj.gridY + dy
        if row > 0 and row <= BOARD_ROWS then
            for dx = -1, 1 do
                local col = obj.gridX + dx
                if col > 0 and col <= BOARD_COLS then
                    local target = board[row][col]
                    self:CreateShardSpawn(0, 0, target, target.contents, dx, dy, forced)
                    loosenGem(self, target, dx == 0)
                    if forced then
                        game.gemsCleared = game.gemsCleared - 1
                    end
                    if dy == -1 then
                        for aboveRow = obj.gridY - 1, 1, -1 do
                            loosenGem(self, board[aboveRow][col], dx == 0)
                        end
                    end
                end
            end
        end
    end
end

-- Finish a falling gem's motion once it reaches its slot.
local function landGem(obj, offsetY)
    obj.moving = nil
    obj.y = obj.y + offsetY
    obj.fxFrame = 1
    obj.yVel = nil
    if obj.fxType ~= FX_DROP_IN and obj.fxType ~= FX_HYPERCUBE and not obj.explode then
        obj.fxType = FX_DONE
    end
    Bejeweled.sound:Play("GemClick")
end

local function animatorOnUpdate(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed < self.delay then
        return
    end
    if not Bejeweled.isShown then
        self.elapsed = 0
        return
    end
    local board, game = ns.board, ns.game
    local gameBoard = Bejeweled.gameBoard
    local gravityStep = GRAVITY * self.elapsed
    local swapStep = C.SWAP_SPEED * self.elapsed
    local fallStep = C.FALL_ACCEL * self.elapsed
    local floatStep = C.FLOAT_TEXT_SPEED * self.elapsed
    -- Level-up wipe runs faster in timed and flight mode; classic keeps normal speed.
    if game.levelingUp and game.gameMode ~= C.MODE_CLASSIC then
        gravityStep = gravityStep * 2.5
        fallStep = fallStep * 2
    end
    local stack = self.animationStack
    local frame, alpha, obj, neighbor, offsetX, offsetY
    local status = self.animationStatus
    local hyperHandled, bigStarHandled

    self.glowFrame = self.glowFrame + (elapsed * GLOW_FRAMES * self.glowFrameDir)
    if self.glowFrame >= GLOW_FRAMES then
        self.glowFrameDir = -1
        self.glowFrame = GLOW_FRAMES
    end
    if self.glowFrame <= 1 then
        self.glowFrameDir = 1
        self.glowFrame = 1
    end
    local glowAlphaUnit = (self.glowFrame / GLOW_FRAMES) * (1 / (C.MAX_GLOW_LEVEL + 4))

    if game.gameMode then
        self.lightwaveElapsed = (self.lightwaveElapsed or 0) + self.elapsed
        if self.lightwaveElapsed > LIGHTWAVE_INTERVAL then
            self.lightwaveElapsed = 0
            for row = 1, BOARD_ROWS do
                self:Add(self:CreateLightwave(board[row][1], row))
            end
        end
    end
    for row = 1, BOARD_ROWS do
        for col = 1, BOARD_COLS do
            obj = board[row][col]
            obj.glowLevel = 0
            obj.glow:SetAlpha(0)
        end
    end
    wipe(self.newJewel)

    local readyForStatusChange = (status ~= ANIM_IDLE)
    if status == ANIM_DROPPING then
        self:HandleJewelDropping()
    end
    if status == C.ANIM_COLLAPSING then
        status = status + 1
        self:HandleJewelFalling()
    end

    -- Objects added while walking the stack are processed from the next frame on.
    local stackIndex = 1
    for _ = 1, #stack do
        obj = stack[stackIndex]
        obj.movedOnce = nil
        if obj.fxType == C.FX_LIGHTWAVE then
            frame = obj.fxFrame + 1
            obj.fxFrame = frame
            local parentGem = obj:GetParent()
            if frame == 1 then
                if parentGem.gridX < BOARD_COLS then
                    self:Add(self:CreateLightwave(board[parentGem.gridY][parentGem.gridX + 1], 0))
                end
                obj.texture:SetTexCoord(unpack(SHINE_TEXCOORDS[2]))
            elseif frame == 10 then
                obj.fxType = FX_DONE
                tinsert(self.lightwaveQueue, obj)
                obj:Hide()
                parentGem.lightWaveObj = nil
            end
            if frame > 0 and parentGem.y >= 0 then
                obj:SetAlpha((10 - frame) / 10)
            else
                obj:SetAlpha(0)
            end
        end

        if status == ANIM_IDLE then
            if obj.fxType == FX_SPIN then
                frame = obj.fxFrame + 1
                if frame > C.SPIN_FRAMES then
                    frame = 1
                    if obj.fxEnd then
                        obj.fxEnd = nil
                        obj.fxType = nil
                        if not obj.moving then
                            obj.fxType = FX_DONE
                        end
                    end
                end
                obj.fxFrame = frame
                obj.texture:SetTexCoord(unpack(GEM_SPIN_TEXCOORDS[frame]))
            elseif obj.fxType == FX_SHINE then
                frame = obj.fxFrame + 1
                if frame > C.SHINE_FRAMES then
                    frame = 1
                    obj.nextGlow = obj.nextGlow + 1
                    if obj.nextGlow > 9 then
                        obj.nextGlow = 1
                    end
                    neighbor = obj.adj
                    if neighbor and neighbor.fxType == FX_SHINE_NEIGHBOR then
                        neighbor.fxEnd = true
                    end
                    local shineCol = obj.gridX + C.FX_SHINE_GRIDX[obj.nextGlow]
                    local shineRow = obj.gridY + C.FX_SHINE_GRIDY[obj.nextGlow]
                    if
                        shineCol >= 1
                        and shineCol <= BOARD_COLS
                        and shineRow >= 1
                        and shineRow <= BOARD_ROWS
                        and not obj.fxEnd
                    then
                        neighbor = board[shineRow][shineCol]
                        if fmod(obj.nextGlow, 2) == 1 then
                            neighbor.nextGlow = obj.nextGlow + 1
                        else
                            neighbor.nextGlow = obj.nextGlow - 1
                        end
                        local fx = neighbor.fxType
                        if
                            fx ~= FX_SHINE
                            and fx ~= FX_SPIN
                            and fx ~= FX_HYPERCUBE
                            and fx ~= FX_DROP_IN
                            and fx ~= FX_DONE
                            and not neighbor.moving
                        then
                            self:Add(neighbor)
                            neighbor.fxType = FX_SHINE_NEIGHBOR
                            neighbor.fxFrame = 1
                            neighbor.fxEnd = nil
                            neighbor.highlight:SetTexCoord(unpack(SHINE_TEXCOORDS[FX_SHINE_KEYFRAME[neighbor.nextGlow]]))
                            neighbor.highlight:SetAlpha(0)
                        end
                    else
                        neighbor = nil
                    end
                    obj.adj = neighbor
                    if obj.fxEnd then
                        -- fxType nil keeps the generic removal below from running a second time.
                        obj.fxEnd = nil
                        obj.fxType = nil
                        tremove(stack, stackIndex)
                        stackIndex = stackIndex - 1
                        obj.animated = nil
                        obj.highlight:SetTexCoord(0, 0, 0, 0)
                    else
                        obj.highlight:SetTexCoord(unpack(SHINE_TEXCOORDS[FX_SHINE_KEYFRAME[obj.nextGlow]]))
                    end
                end
                obj.fxFrame = frame
                obj.highlight:SetAlpha(FX_SHINE_ALPHA[frame])
            elseif obj.fxType == FX_SHINE_NEIGHBOR then
                frame = obj.fxFrame + 1
                if frame > C.SHINE_NEIGHBOR_FRAMES then
                    obj.fxEnd = true
                    frame = 1
                end
                if obj.fxEnd then
                    obj.fxEnd = nil
                    tremove(stack, stackIndex)
                    stackIndex = stackIndex - 1
                    obj.animated = nil
                    obj.highlight:SetTexCoord(0, 0, 0, 0)
                end
                obj.fxFrame = frame
                obj.highlight:SetAlpha(FX_SHINE_ALPHA[frame])
            end
        elseif status == ANIM_EXPLODING then
            if obj.fxType == FX_DESTROY then
                obj.markX = nil
                obj.markY = nil
                if obj.score then
                    obj:Show()
                    obj.fxType = FX_FLOAT_TEXT
                    if not obj.notScore then
                        Bejeweled.levelBar:AddScore(obj.score)
                    end
                    if obj.comboSound then
                        Bejeweled.sound:Play("Combo", obj.comboSound)
                        obj.comboSound = nil
                    end
                elseif obj.bigStarSpawn then
                    obj.fxType = nil
                    obj.bigStar = obj.bigStarSpawn
                    obj.bigStarSpawn = nil
                    obj.bigStar:Show()
                    Bejeweled.sound:Play("PowerCreate")
                    showFirstTimeTip("firstPowerGem", "tip1", obj)
                elseif obj.hyperGemSpawn then
                    obj.hyperGemSpawn = nil
                    self:CreateHyperGem(obj)
                    Bejeweled.sound:Play("HyperCreate")
                    showFirstTimeTip("firstHyperCube", "tip2", obj)
                elseif obj.hyperGemTrigger then
                    -- One hypercube chain step per frame, each after a one-frame delay.
                    if not hyperHandled then
                        hyperHandled = true
                        if obj.hyperGemDelay == 1 then
                            obj.hyperGemDelay = nil
                            ns.triggerHyperCube(obj)
                            if not obj.explode then
                                obj.fxEnd = nil
                                obj.fxType = FX_DONE
                                obj.contents = 0
                                ns.refreshGemTexture(obj)
                            end
                        else
                            obj.hyperGemDelay = (obj.hyperGemDelay or 0) + 1
                        end
                    end
                    readyForStatusChange = nil
                elseif obj.bigStar then
                    -- One power-gem explosion per frame, each after a one-frame delay.
                    if obj.explode then
                        if not bigStarHandled then
                            bigStarHandled = true
                            if obj.explodeDelay then
                                explodeBigStar(self, board, game, obj)
                            else
                                obj.explodeDelay = 1
                            end
                        end
                        readyForStatusChange = nil
                    end
                else
                    frame = obj.fxFrame + 1
                    if frame > DESTROY_FRAMES then
                        frame = 1
                        obj.fxEnd = nil
                        obj.fxType = FX_DONE
                        obj.contents = 0
                        ns.refreshGemTexture(obj)
                    else
                        readyForStatusChange = nil
                    end
                    obj.texture:SetWidth((DESTROY_FRAMES - frame + 1) / DESTROY_FRAMES * GEM_WIDTH)
                    obj.texture:SetHeight((DESTROY_FRAMES - frame + 1) / DESTROY_FRAMES * GEM_HEIGHT)
                    obj.fxFrame = frame
                end
            end
        elseif status == ANIM_DROPPING then
            if obj.moving == MOVE_FALL then
                obj.movedOnce = true
                obj.yVel = obj.yVel + fallStep
                offsetY = obj.yOffset + obj.yVel
                if offsetY >= obj.maxYOffset then
                    offsetY = obj.maxYOffset
                    obj.yOffset = 0
                    obj.maxYOffset = nil
                else
                    obj.yOffset = offsetY
                end
                readyForStatusChange = nil
                if obj.maxYOffset == nil then
                    landGem(obj, offsetY)
                    offsetY = 0
                end
                obj:ClearAllPoints()
                obj:SetPoint("TOPLEFT", obj.x, -(obj.y + offsetY))
            end
            -- Reveal a dropping gem as it crosses the top edge of the board.
            if obj.fxType == FX_DROP_IN then
                offsetY = obj.y + obj.yOffset
                if offsetY >= 0 then
                    obj.texture:SetTexCoord(unpack(GEM_SPIN_TEXCOORDS[1]))
                    obj.texture:ClearAllPoints()
                    obj.texture:SetPoint("CENTER")
                    obj.fxType = nil
                    if obj.explode == 1 then
                        obj.fxType = FX_DESTROY
                    end
                    if obj.spawnHyper then
                        obj.spawnHyper = nil
                        self:CreateHyperGem(obj)
                    end
                    obj.texture:SetHeight(GEM_HEIGHT)
                    if obj.bigStar then
                        obj.bigStar:Show()
                    end
                    if obj.lightWaveObj then
                        obj.lightWaveObj:Show()
                    end
                elseif offsetY >= -GEM_HEIGHT then
                    -- Reveal only the visible bottom part of the resting-gem frame.
                    local texLeft, texRight, texTop, texBottom = unpack(GEM_SPIN_TEXCOORDS[1])
                    offsetY = floor(offsetY + GEM_HEIGHT)
                    obj.texture:ClearAllPoints()
                    obj.texture:SetPoint("BOTTOM")
                    obj.texture:SetHeight(offsetY)
                    local visibleTop = texBottom - (texBottom - texTop) * offsetY / GEM_HEIGHT
                    obj.texture:SetTexCoord(texLeft, texRight, visibleTop, texBottom)
                    if obj.lightWaveObj then
                        obj.lightWaveObj:Hide()
                    end
                else
                    obj.texture:SetTexCoord(0, 0, 0, 0)
                    if obj.lightWaveObj then
                        obj.lightWaveObj:Hide()
                    end
                end
            end
        end

        -- Falling outside the drop phase (cascades, blast knock-ups).
        if obj.moving == MOVE_FALL and not obj.movedOnce then
            obj.movedOnce = true
            obj.yVel = obj.yVel + (abs(obj.yVel) * 0.1) + fallStep
            offsetY = obj.yOffset + obj.yVel
            if obj.maxYOffset then
                if offsetY >= obj.maxYOffset then
                    offsetY = obj.maxYOffset
                    obj.yOffset = 0
                    obj.maxYOffset = nil
                else
                    obj.yOffset = offsetY
                end
                if obj.maxYOffset == nil then
                    landGem(obj, offsetY)
                    offsetY = 0
                end
            else
                obj.yOffset = offsetY
            end
            obj:ClearAllPoints()
            obj:SetPoint("TOPLEFT", obj.x, -(obj.y + offsetY))
        end

        if obj.fxType == FX_HYPERCUBE then
            frame = obj.fxFrame + 1
            if frame > C.HYPERCUBE_FRAMES then
                frame = 1
                obj.fxEnd = nil
            end
            obj.fxFrame = frame
            obj.texture:SetTexCoord(unpack(C.HYPERCUBE_TEXCOORDS[frame]))
            glowAround(board, obj.gridX, obj.gridY, glowAlphaUnit)
        elseif obj.fxType == C.FX_BIG_STAR then
            frame = obj.fxFrame + 0.5
            local frame2 = obj.fxFrame2 - 2.5
            if frame > BIG_STAR_ROT_DEGREES then
                frame = frame - BIG_STAR_ROT_DEGREES
            end
            if frame2 <= 0 then
                frame2 = BIG_STAR_ROT_DEGREES + frame2
            end
            if obj.fxEnd then
                obj.fxEnd = nil
                obj.fxType = FX_DONE
                obj:Hide()
                tinsert(self.bigStarQueue, obj)
            end
            obj.fxFrame = frame
            obj.fxFrame2 = frame2
            self:RotateTexture(obj.texture, floor(frame), 0.5, 0.5)
            self:RotateTexture(obj.highlight, floor(frame2), 0.5, 0.5)
            alpha = obj.fxAlpha + obj.fxAlphaStep
            if alpha > 100 then
                obj.fxAlphaStep = -obj.fxAlphaStep
                alpha = 100
            elseif alpha < 0 then
                obj.fxAlphaStep = -obj.fxAlphaStep
                alpha = 0
            end
            obj.fxAlpha = alpha
            obj.texture:SetAlpha(alpha / 100)
            obj.highlight:SetAlpha((100 - alpha) / 100)
            glowAround(board, obj.parent.gridX, obj.parent.gridY, glowAlphaUnit)
        elseif obj.fxType == C.FX_SHARD then
            frame = obj.fxFrame + 1
            if frame > C.SHARD_FRAMES then
                frame = 1
                if obj.fxEnd then
                    obj.fxEnd = nil
                    obj.fxType = FX_DONE
                    obj:Hide()
                end
            end
            obj.x = obj.x + obj.xVel
            obj.y = obj.y + obj.yVel
            obj:ClearAllPoints()
            obj:SetPoint("TOPLEFT", obj.x, -obj.y)
            obj.yVel = obj.yVel + gravityStep
            if obj.xVel > 0 and obj.xVel < 8 then
                obj.xVel = obj.xVel + 0.1
            elseif obj.xVel < 0 and obj.xVel > -8 then
                obj.xVel = obj.xVel - 0.1
            end
            if obj.yVel >= GRAVITY then
                obj.fxType = FX_DONE
            elseif obj.yVel > FADE_START_VELOCITY then
                obj:SetAlpha(1 - ((obj.yVel - FADE_START_VELOCITY) / FADE_START_VELOCITY))
            end
            if obj.fxType == FX_DONE then
                obj.fxEnd = nil
                obj:Hide()
                tinsert(self.shardQueue, obj)
            end
            obj.fxFrame = frame
            obj.texture:SetTexCoord(unpack(C.SHARD_TEXCOORDS[frame]))
        elseif obj.fxType == C.FX_EXPLOSION then
            frame = obj.fxFrame + 1
            if frame > C.EXPLOSION_FRAMES then
                obj.fxType = FX_DONE
            end
            if obj.fxEnd then
                obj.fxEnd = nil
                obj.fxType = FX_DONE
            end
            if obj.fxType == FX_DONE then
                tinsert(self.explosionQueue, obj)
                obj:Hide()
            else
                obj.fxFrame = frame
                obj.texture:SetTexCoord(unpack(C.EXPLOSION_TEXCOORDS[frame]))
            end
        elseif obj.fxType == FX_LIGHTNING then
            frame = obj.fxFrame + 1
            if frame > LIGHTNING_FRAMES then
                obj.fxType = FX_DONE
            end
            if fmod(frame, 2) == 1 then
                obj.highlight:SetAlpha(0.2)
            else
                obj.highlight:SetAlpha(0.6)
            end
            if obj.fxEnd then
                obj.fxEnd = nil
                obj.fxType = FX_DONE
            end
            if obj.fxType == FX_DONE then
                tinsert(self.lightningQueue, obj)
                obj:Hide()
                obj.highlight:Hide()
            else
                obj.fxFrame = frame
            end
        elseif obj.fxType == FX_FLOAT_TEXT then
            frame = obj.fxFrame + floatStep
            if frame > FLOAT_TEXT_FADE_FRAMES then
                if frame > FLOAT_TEXT_FADE_FRAMES * 2 then
                    frame = 0
                    tinsert(self.floatingTextQueue, obj)
                    obj.fxType = FX_DONE
                    obj:Hide()
                else
                    obj:SetAlpha(1 - ((frame - FLOAT_TEXT_FADE_FRAMES) / FLOAT_TEXT_FADE_FRAMES))
                end
            end
            if obj.notScore then
                obj.y = obj.y + floatStep
            else
                obj.y = obj.y - floatStep
            end
            obj:ClearAllPoints()
            obj:SetPoint("TOPLEFT", gameBoard, "TOPLEFT", obj.x, -obj.y)
            obj.fxFrame = frame
        elseif obj.fxType == FX_HINT then
            obj.fxFrame = obj.fxFrame + self.elapsed
            if obj.fxFrame > HINT_DELAY_SECONDS then
                obj:Show()
                obj.bounceY = obj.bounceY + obj.bounceDir
                if obj.bounceDir == 1 then
                    if obj.bounceY >= 10 then
                        obj.bounceDir = -1
                        obj.bounceY = 10
                    end
                elseif obj.bounceY <= 0 then
                    obj.bounceDir = 1
                    obj.bounceY = 0
                end
                obj:ClearAllPoints()
                obj:SetPoint("TOPLEFT", obj.x, -obj.y + obj.bounceY)
            end
        end

        if obj.moving == MOVE_SWAP then
            offsetX = obj.xOffset + obj.xMove * swapStep
            offsetY = obj.yOffset + obj.yMove * swapStep
            local swapDone
            if offsetX >= SWAP_DISTANCE then
                offsetX = obj.xDir * SWAP_DISTANCE
                obj.xOffset = 0
                swapDone = true
            else
                obj.xOffset = offsetX
                offsetX = obj.xDir * offsetX
            end
            if offsetY >= SWAP_DISTANCE then
                offsetY = obj.yDir * SWAP_DISTANCE
                obj.yOffset = 0
                swapDone = true
            else
                obj.yOffset = offsetY
                offsetY = obj.yDir * offsetY
            end
            if swapDone then
                if obj.invalidMove == 1 then
                    -- No match: bounce back to the original cell.
                    obj.xDir = -obj.xDir
                    obj.x = obj.x + offsetX
                    obj.yDir = -obj.yDir
                    obj.y = obj.y + offsetY
                    obj.invalidMove = 2
                else
                    obj.moving = nil
                    if obj.invalidMove == 2 then
                        obj.invalidMove = nil
                        obj.x = obj.x + offsetX
                        obj.y = obj.y + offsetY
                    end
                    obj.xOffset = 0
                    obj.yOffset = 0
                    obj.xMove = 0
                    obj.yMove = 0
                    obj.xDir = 0
                    obj.yDir = 0
                    obj.selector:Hide()
                    if obj.bigStar then
                        obj.bigStar:ClearAllPoints()
                        obj.bigStar:SetPoint("TOPLEFT", obj, "TOPLEFT")
                    end
                    if obj.fxType ~= FX_DESTROY and obj.fxType ~= FX_HYPERCUBE and obj.fxType ~= FX_DROP_IN then
                        obj.fxType = FX_DONE
                    end
                    if obj.hyperGemContents then
                        -- Swapped with a hypercube: the cube is consumed and this gem's color detonates.
                        if obj.swapJewel and obj.swapJewel.contents == GEM_HYPERCUBE then
                            obj.swapJewel.fxType = FX_DONE
                            obj.swapJewel.contents = 0
                            ns.awardMatchScore(1, obj.swapJewel, obj.hyperGemContents, nil, true, 0, true)
                        end
                        obj.fxType = FX_DESTROY
                        obj.hyperGemTrigger = true
                        status = ANIM_EXPLODING
                        readyForStatusChange = nil
                    end
                    self.movingJewels = self.movingJewels - 1
                    obj.fxFrame = 1
                    ns.refreshGemTexture(obj)
                    if self.movingJewels == 0 then
                        game.selectedJewel = nil
                        self.animationStatus = ANIM_EXPLODING
                    end
                end
                offsetX = 0
                offsetY = 0
            end
            obj:ClearAllPoints()
            obj:SetPoint("TOPLEFT", obj.x + offsetX, -(obj.y + offsetY))
        elseif obj.moving == MOVE_FLY_OFF then
            obj.x = obj.x + obj.xVel
            obj.y = obj.y + obj.yVel
            obj:ClearAllPoints()
            obj:SetPoint("TOPLEFT", obj.x, -obj.y)
            obj.yVel = obj.yVel + gravityStep
            if obj.yVel >= GRAVITY then
                obj.fxType = FX_DONE
            elseif obj.yVel > FADE_START_VELOCITY then
                obj:SetAlpha(1 - ((obj.yVel - FADE_START_VELOCITY) / FADE_START_VELOCITY))
            end
            if obj.fxType == FX_DONE then
                obj.fxEnd = nil
                obj.contents = 0
                obj.x = (obj.gridX - 1) * GEM_WIDTH
                obj.y = (obj.gridY - 1) * GEM_HEIGHT
                obj.yVel = 0
                obj:SetAlpha(0)
            else
                readyForStatusChange = nil
            end
        end

        if obj.fxType == FX_DONE then
            tremove(stack, stackIndex)
            obj.animated = nil
            obj.fxType = nil
        else
            stackIndex = stackIndex + 1
        end
    end

    if self.newGameStart == true then
        self:HandleNewGameCountdown()
    end
    if readyForStatusChange == true then
        self:HandleAnimatorStatusChange(status)
    end
    self.elapsed = 0
end

local function createAnimator()
    local animator = CreateFrame("Frame", nil, UIParent)
    animator:SetSize(1, 1)
    animator:EnableMouse(false)
    animator:SetAlpha(0)
    animator.animationStack = {}
    animator.elapsed = 0
    animator.delay = C.FRAME_TIME
    animator.glowFrameDir = 1
    animator.glowFrame = 1
    animator.movingJewels = 0
    animator.animationStatus = ANIM_IDLE
    -- RotateTexture lookup: corner offsets for a square rotated about its center, per whole degree.
    animator.tableCos = {}
    animator.tableSin = {}
    for degrees = 0, 360 do
        local radians = -math.rad(degrees - 135)
        animator.tableSin[degrees] = math.sin(radians) * 0.71
        animator.tableCos[degrees] = math.cos(radians) * 0.71
    end
    animator.shardQueue = {}
    animator.lightwaveQueue = {}
    animator.lightningQueue = {}
    animator.explosionQueue = {}
    animator.bigStarQueue = {}
    animator.floatingTextQueue = {}
    animator.columnOffset = {}
    animator.newJewel = {}
    for name, method in pairs(ns.animatorMethods) do
        animator[name] = method
    end
    animator.HandleAnimatorStatusChange = animatorHandleStatusChange
    animator.HandleJewelDropping = animatorHandleJewelDropping
    animator.HandleJewelFalling = animatorHandleJewelFalling
    animator.HandleNewGameCountdown = animatorHandleNewGameCountdown
    animator:SetScript("OnUpdate", animatorOnUpdate)
    animator:Show()
    return animator
end

ns.RegisterBuilder("Animator", function()
    Bejeweled.animator = createAnimator()
end)
