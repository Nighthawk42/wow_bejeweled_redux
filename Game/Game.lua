local _, ns = ...
local Bejeweled = ns.addon
local C = ns.C

-- Game flow: starting (or resuming) a game, pausing, saving the classic board, and game over.

local BOARD_ROWS, BOARD_COLS = C.BOARD_ROWS, C.BOARD_COLS
local MODE_CLASSIC, MODE_TIMED, MODE_FLIGHT = C.MODE_CLASSIC, C.MODE_TIMED, C.MODE_FLIGHT
local GEM_HYPERCUBE = C.GEM_HYPERCUBE

-- db.char.savedState: [1..8][1..8] = gem contents (+10 for a power gem),
-- [9] = { score, pointsToLevelUp, level, moves, largestCascade, largestCombo, timeElapsed, pointMultiplier }.
function ns.saveGameState()
    local char = ns.db.char
    local savedState = char.savedState
    if not savedState then
        savedState = {}
        for row = 1, BOARD_ROWS + 1 do
            savedState[row] = {}
        end
        char.savedState = savedState
    end
    local board = ns.board
    for row = 1, BOARD_ROWS do
        for col = 1, BOARD_COLS do
            local gem = board[row][col]
            savedState[row][col] = gem.bigStar and gem.contents + 10 or gem.contents
        end
    end
    local game = ns.game
    local data = savedState[BOARD_ROWS + 1]
    data[1] = game.score
    data[2] = game.pointsToLevelUp
    data[3] = game.level
    data[4] = game.moves
    data[5] = game.largestCascade
    data[6] = game.largestCombo
    data[7] = Bejeweled.levelBar.timer.timeElapsed
    data[8] = game.pointMultiplier
end

local function isValidCell(value)
    if type(value) ~= "number" or value ~= math.floor(value) then
        return false
    end
    local contents = value > 10 and value - 10 or value
    return (contents >= 1 and contents <= C.NUM_GEM_COLORS) or contents == GEM_HYPERCUBE
end

-- Returns the saved classic game if it is complete and well-formed, else nil.
local function getValidSavedState()
    local saved = ns.db.char.savedState
    if type(saved) ~= "table" then
        return nil
    end
    for row = 1, BOARD_ROWS do
        if type(saved[row]) ~= "table" then
            return nil
        end
        for col = 1, BOARD_COLS do
            if not isValidCell(saved[row][col]) then
                return nil
            end
        end
    end
    local data = saved[BOARD_ROWS + 1]
    if type(data) ~= "table" then
        return nil
    end
    for i = 1, 7 do
        if type(data[i]) ~= "number" or data[i] < 0 then
            return nil
        end
    end
    if data[3] < 1 or (data[8] ~= nil and type(data[8]) ~= "number") then
        return nil
    end
    return saved
end

local function recycleAnimations()
    local animator = Bejeweled.animator
    local stack = animator.animationStack
    for i = #stack, 1, -1 do
        local obj = stack[i]
        local fxType = obj.fxType
        if fxType == C.FX_BIG_STAR then
            table.insert(animator.bigStarQueue, obj)
            obj:ClearAllPoints()
            obj:SetAlpha(0)
            if obj.parent then
                obj.parent.bigStar = nil
            end
            obj.parent = nil
            obj:Hide()
        elseif fxType == C.FX_EXPLOSION then
            table.insert(animator.explosionQueue, obj)
            obj:Hide()
        elseif fxType == C.FX_FLOAT_TEXT then
            table.insert(animator.floatingTextQueue, obj)
            obj:Hide()
        elseif fxType == C.FX_SHARD then
            table.insert(animator.shardQueue, obj)
            obj:Hide()
        elseif fxType == C.FX_LIGHTWAVE then
            table.insert(animator.lightwaveQueue, obj)
            obj:GetParent().lightWaveObj = nil
            obj:Hide()
        elseif fxType == C.FX_LIGHTNING then
            table.insert(animator.lightningQueue, obj)
            obj.highlight:Hide()
            obj:Hide()
        end
        stack[i] = nil
        obj.animated = nil
    end
end

-- Restores the saved classic board and score; the gems appear in place, without a drop-in.
local function restoreSavedGame(saved)
    local game, board, animator = ns.game, ns.board, Bejeweled.animator
    animator.spawningLevel = nil
    animator.animationStatus = C.ANIM_IDLE
    for row = 1, BOARD_ROWS do
        for col = 1, BOARD_COLS do
            local gem = board[row][col]
            local value = saved[row][col]
            if value < GEM_HYPERCUBE then
                gem.contents = value
            elseif value == GEM_HYPERCUBE then
                animator:CreateHyperGem(gem)
                animator:Add(gem)
            else
                gem.contents = value - 10
                gem.bigStar = animator:CreateBigStar(0, 0, gem)
                animator:Add(gem.bigStar)
            end
            ns.refreshGemTexture(gem)
        end
    end
    local data = saved[BOARD_ROWS + 1]
    game.score = data[1]
    game.pointsToLevelUp = data[2]
    game.level = data[3]
    game.moves = data[4]
    game.largestCascade = data[5]
    game.largestCombo = data[6]
    game.pointMultiplier = data[8]
    local levelBar = Bejeweled.levelBar
    levelBar.timer.timeElapsed = data[7]
    animator.countdownState = 0
    levelBar.score = game.score
    levelBar.maxScore = game.pointsToLevelUp
    Bejeweled.levelText:SetText(game.level)
    levelBar:UpdateBar()
end

-- mode: C.MODE_*; modeArg: game length in seconds (timed/flight);
-- resumeSaved: continue the saved classic game.
function ns.startNewGame(mode, modeArg, resumeSaved)
    local game, board = ns.game, ns.board
    local char = ns.db.char
    local animator = Bejeweled.animator
    game.gameOver = false
    game.paused = false
    game.score = 0
    game.combo = 0
    game.level = 1
    game.selectedJewel = nil
    game.pointsToLevelUp = 500 * C.MODE_POINT_MULTIPLIER[mode]
    game.gameMode = mode
    game.explosions = 0
    game.bigStarSpawn = 0
    game.hyperSpawn = 0
    game.moves = 0
    game.gemsCleared = 0

    local splash = Bejeweled.window.splash
    if splash.firstGame == true then
        splash.firstGame = nil
        splash:Hide()
    end

    recycleAnimations()
    for row = 1, BOARD_ROWS do
        for col = 1, BOARD_COLS do
            local gem = board[row][col]
            ns.resetGem(gem, col, row)
            gem.wasHyper = nil
            -- Empty cells are filled by the animator's drop-in, which avoids starting matches.
            gem.contents = 0
        end
    end

    if mode == MODE_CLASSIC then
        game.statDB = char.stats.classic
        if game.statDB.highestLevel == 0 then
            game.statDB.highestLevel = 1
        end
        char.classicInProgress = true
    else
        char.classicInProgress = false
        game.statDB = char.stats.timed
    end
    game.largestCascade = 0
    game.largestCombo = 0
    game.leveledUp = nil
    game.levelingUp = nil
    Bejeweled.pausedText:Hide()
    Bejeweled.flightOptionWindow.learning = nil
    Bejeweled.levelBar:SetMode(mode, modeArg)
    animator.newGameStart = true
    animator.countdownState = 4
    game.moveAllowed = nil
    if mode == MODE_TIMED then
        Bejeweled.levelBar:StopTimer()
    elseif mode == MODE_FLIGHT then
        animator.countdownState = 0
    end
    Bejeweled.gameStatusText:Hide()
    Bejeweled.gameStatusText.background:Hide()
    Bejeweled.summaryScreen:Hide()
    Bejeweled.summaryScreen.bragScreen:Hide()
    Bejeweled.aboutScreen:Hide()
    Bejeweled.featsOfSkillScreen:Hide()
    Bejeweled.optionsScreen:Hide()
    local levelBarButton = Bejeweled.levelBarButton
    levelBarButton:Hide()
    levelBarButton:SetID(0)
    levelBarButton.text:SetText("Return to Game")
    animator.spawningLevel = true
    animator.animationStatus = C.ANIM_DROPPING
    animator.spawnedJewels = nil
    animator.hintObj:Hide()
    animator.hintObj:ClearAllPoints()

    if resumeSaved then
        local saved = getValidSavedState()
        if saved then
            restoreSavedGame(saved)
        else
            char.savedState = nil
        end
    end
    ns.keepSpecialsOnLevel = game.level > 1 or nil
    ns.setPaused(false)
end

-- Classic and flight games dim the board while paused; timed games hide it.
function ns.setPaused(paused)
    local game = ns.game
    local animator = Bejeweled.animator
    local mode = game.gameMode
    local dimOnly = mode == MODE_CLASSIC or mode == MODE_FLIGHT
    paused = paused == true
    Bejeweled.paused = paused

    for row = 1, BOARD_ROWS do
        for col = 1, BOARD_COLS do
            local gem = ns.board[row][col]
            if not dimOnly then
                gem:SetShown(not paused)
            elseif paused then
                if not gem.oldAlphaJewel then
                    gem.oldAlphaJewel = gem:GetAlpha()
                    gem:SetAlpha(gem.oldAlphaJewel / 2)
                end
            else
                -- Gems at rest are always fully opaque.
                gem:SetAlpha(1)
                gem.oldAlphaJewel = nil
            end
        end
    end

    -- The flight game keeps animating while paused (the flight goes on).
    if mode == MODE_FLIGHT then
        animator:Show()
    else
        animator:SetShown(not paused)
        if mode == MODE_TIMED then
            Bejeweled.pausedText:SetShown(paused)
        end
    end

    local stack = animator.animationStack
    for i = 0, #stack do
        local obj = i == 0 and animator.hintObj or stack[i]
        if obj then
            if paused then
                if obj:IsShown() then
                    obj.wasShown = true
                    if not dimOnly then
                        obj:Hide()
                    elseif not obj.oldAlpha then
                        obj.oldAlpha = obj:GetAlpha()
                        if not obj.contents then
                            obj:SetAlpha(obj.oldAlpha / 2)
                        end
                    end
                end
            elseif obj.wasShown then
                obj.wasShown = nil
                if dimOnly then
                    if not obj.contents then
                        obj:SetAlpha(1)
                    end
                    obj.oldAlpha = nil
                else
                    obj:Show()
                end
            end
        end
    end

    local timer = Bejeweled.levelBar.timer
    if paused and mode ~= MODE_FLIGHT then
        timer:Hide()
    else
        timer:SetShown(not game.gameOver and game.gameMode ~= nil)
    end
end

-- isNext: clear the gem queued while the board was busy, instead of the selected one.
function ns.deselectGem(isNext)
    local game = ns.game
    local gem
    if isNext then
        gem = game.nextSelectedJewel
        game.nextSelectedJewel = nil
    else
        gem = game.selectedJewel
        game.selectedJewel = nil
    end
    if gem then
        if gem.fxType ~= C.FX_HYPERCUBE then
            gem.fxEnd = true
        end
        gem.selector:Hide()
        gem.mouseX = nil
        gem.mouseY = nil
    end
end

-- Game over: stops input and the timer, clears the saved classic game, counts the game,
-- and wipes the board. The animator shows the summary once the wipe is done.
function ns.endGame()
    local game = ns.game
    local char = ns.db.char
    local animator = Bejeweled.animator
    local statusText = Bejeweled.gameStatusText
    local const = Bejeweled.const
    animator.hintObj:Hide()
    animator.hintObj.fxType = C.FX_DONE
    game.gameOver = true
    game.moveAllowed = nil
    game.lastGameMode = game.gameMode
    Bejeweled.levelBar:StopTimer()
    if game.gameMode == MODE_CLASSIC then
        statusText:SetText("No more moves")
        Bejeweled.sound:Play("NoMoreMoves")
        char.savedState = nil
        char.classicInProgress = false
    else
        statusText:SetText("Time's up")
        Bejeweled.sound:Play("TimesUp")
    end
    char.skill.games = char.skill.games + 1
    ns.db.global.played[ns.CharacterKey()] = char.skill.games
    ns.totalGamesAllChars = ns.totalGamesAllChars + 1
    if not char.skill["gainAchieve" .. const.SKILL_ACHIEVE2B] and ns.totalGamesAllChars >= 100 then
        Bejeweled.skillBar:CheckSkill(const.SKILLTYPE_ACHIEVEMENT, const.SKILL_ACHIEVE2B)
    end
    if not char.skill["gainAchieve" .. const.SKILL_ACHIEVE4B] and ns.totalGamesAllChars >= 1000 then
        Bejeweled.skillBar:CheckSkill(const.SKILLTYPE_ACHIEVEMENT, const.SKILL_ACHIEVE4B)
    end
    statusText:Show()
    statusText.background:Show()
    ns.deselectGem()
    ns.deselectGem(true)
    animator.animationStatus = C.ANIM_LEVEL_TRANSITION
    ns.blowAwayAllGems()
    Bejeweled.sound:Play("WipeBoard")
end
