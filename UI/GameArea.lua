local _, ns = ...
local Bejeweled = ns.addon
local C = ns.C
local BOARD_WIDTH, BOARD_HEIGHT = C.BOARD_WIDTH, C.BOARD_HEIGHT
local GEM_WIDTH, GEM_HEIGHT = C.GEM_WIDTH, C.GEM_HEIGHT

-- The playing field and status bar: tiled board background, foreground (status text,
-- hint, floating text), level/score bar with its "New Game" overlay button, the
-- "Paused" text, the PopCap splash and the 8x8 gem frames.

local function statusBarBackdrop()
    local backdrop = ns.makeBackdrop()
    backdrop.edgeFile = "Interface\\Buttons\\UI-SliderBar-Border"
    backdrop.edgeSize = 8
    backdrop.bgFile = ns.Textures.Path("windowBackground")
    backdrop.tileSize = 64
    backdrop.insets.left = 2
    backdrop.insets.right = 2
    return backdrop
end

local function borderBackdrop()
    local backdrop = ns.makeBackdrop()
    backdrop.edgeFile = ns.Textures.Path("levelBorder")
    backdrop.edgeSize = 32
    backdrop.insets.left = 2
    backdrop.insets.right = 2
    return backdrop
end

-- Shows a large art-piece caption (Bejeweled.const.largeText[key]) over the board.
local function statusTextSetText(self, key)
    local info = Bejeweled.const.largeText[key]
    if info then
        self.text:SetSize(info[1], info[2])
        self.text:SetTexCoord(ns.Textures.Coords("artPieces", key))
        self.background:SetVertexColor(info[3], info[4], info[5])
    end
    self:SetAlpha(1)
    self.background:SetAlpha(1)
end

local function createBackgroundTiles(gameArea)
    local tileSize = BOARD_WIDTH / 4
    local variants = ns.Textures.Variants("board", "tile")
    for tileRow = 0, 3 do
        for tileCol = 0, 3 do
            local tile = CreateFrame("Frame", nil, gameArea)
            tile:SetPoint("TOPLEFT", tileCol * 100, -(tileRow * 100))
            tile:SetSize(tileSize, tileSize)
            tile.texture = tile:CreateTexture(nil, "BACKGROUND")
            tile.texture:SetSize(tileSize, tileSize)
            tile.texture:SetPoint("CENTER")
            tile.texture:SetTexture(ns.Textures.Path("board"))
            tile.texture:SetTexCoord(ns.Textures.Coords("board", variants[math.random(#variants)]))
            tile:SetAlpha(0.8)
            tile:SetFrameLevel(gameArea:GetFrameLevel())
        end
    end
end

local function createStatusText(foreground, gameBoard)
    local statusText = CreateFrame("Frame", nil, foreground)
    statusText:SetPoint("CENTER")
    statusText:SetSize(1, 1)
    statusText:Hide()
    statusText.text = statusText:CreateTexture(nil, "OVERLAY")
    statusText.text:SetTexture(ns.Textures.Path("artPieces"))
    statusText.text:SetSize(1, 1)
    statusText.text:SetPoint("CENTER")
    statusText.text:SetTexCoord(0, 0, 0, 0)
    statusText.background = statusText:CreateTexture(nil, "ARTWORK")
    statusText.background:SetPoint("CENTER")
    statusText.background:SetPoint("LEFT", gameBoard, "LEFT", 8, 0)
    statusText.background:SetPoint("RIGHT", gameBoard, "RIGHT", -8, 0)
    statusText.background:SetHeight(84)
    statusText.background:SetTexture(ns.Textures.Path("artPieces"))
    statusText.background:SetTexCoord(ns.Textures.Coords("artPieces", "Strip"))
    statusText.background:Hide()
    statusText.SetText = statusTextSetText
    Bejeweled.gameStatusText = statusText
end

local function createLevelBar(statusBar, dataBorder, window)
    local levelBar = CreateFrame("Frame", nil, statusBar, "BackdropTemplate")
    levelBar:SetPoint("LEFT", dataBorder, "RIGHT", -18, 0)
    levelBar:SetPoint("BOTTOMRIGHT", statusBar, "BOTTOMRIGHT", 0, 0)
    levelBar:SetHeight(32)
    levelBar:SetBackdrop(statusBarBackdrop())
    levelBar:SetBackdropColor(0.1, 0.1, 0.1, 0)
    levelBar:SetFrameLevel(statusBar:GetFrameLevel() + 2)
    Bejeweled.levelBar = levelBar

    local background = CreateFrame("Frame", nil, statusBar, "BackdropTemplate")
    background:SetPoint("LEFT", dataBorder, "RIGHT", -18, 0)
    background:SetPoint("BOTTOMRIGHT", statusBar, "BOTTOMRIGHT", 0, 0)
    background:SetHeight(32)
    background:SetBackdrop(statusBarBackdrop())
    background:SetBackdropColor(0.1, 0.1, 0.1)
    background:SetBackdropBorderColor(0, 0, 0, 0)
    background:SetFrameLevel(statusBar:GetFrameLevel() + 1)

    local bar = background:CreateTexture(nil, "OVERLAY")
    bar:SetTexture(ns.Textures.Path("barArt"))
    bar:SetVertexColor(0, 0.2, 1)
    bar:SetPoint("TOPLEFT", 2, -5)
    bar:SetHeight(32)
    bar:SetWidth(0.01)
    levelBar.bar = bar

    levelBar.text = Bejeweled:CreateCaption(0, 0, "", levelBar, 12, 1, 1, 1, true)
    levelBar.text:ClearAllPoints()
    levelBar.text:SetPoint("CENTER", 0, 1)
    Mixin(levelBar, ns.levelBarMethods)

    levelBar.timer = CreateFrame("Frame", nil, window)
    levelBar.timer:SetSize(1, 1)
    levelBar.timer:SetPoint("TOP")
    levelBar.timer:Hide()
    levelBar.timer:SetScript("OnUpdate", ns.levelTimerOnUpdate)
end

-- Red bar over the status bar. ID 1 = "close the open screen", ID 2 = "start a new game".
local function createLevelBarButton(statusBar, window)
    local button = CreateFrame("Frame", nil, window, "BackdropTemplate")
    button:SetPoint("TOPLEFT", statusBar, "TOPLEFT", 50, 0)
    button:SetPoint("BOTTOMRIGHT", statusBar, "BOTTOMRIGHT")
    button:EnableMouse(true)
    button:Hide()
    button:SetID(2)
    button:SetScript("OnShow", function()
        Bejeweled.statusBar:SetAlpha(0)
    end)
    button:SetScript("OnHide", function()
        Bejeweled.statusBar:SetAlpha(1)
    end)
    button:SetScript("OnEnter", function(self)
        self.bar:SetVertexColor(1, 0, 0)
    end)
    button:SetScript("OnLeave", function(self)
        self.bar:SetVertexColor(0.6, 0, 0)
    end)
    button:SetScript("OnMouseDown", function(self)
        local menuWindow = Bejeweled.menuWindow
        -- Show+Hide runs the menu's OnHide, which unpauses and closes open screens.
        menuWindow.keepScreen = nil
        menuWindow:Show()
        menuWindow:Hide()
        if self:GetID() == 1 then
            Bejeweled.featsOfSkillScreen:Hide()
            if Bejeweled.optionsScreen then
                Bejeweled.optionsScreen:Hide()
            end
            Bejeweled.aboutScreen:Hide()
            self:SetID(0)
            self:Hide()
        elseif self:GetID() == 2 then
            local lastMode = ns.game.lastGameMode
            if lastMode == C.MODE_TIMED then
                Bejeweled.timedWindow:Show()
            elseif lastMode == C.MODE_CLASSIC then
                ns.startNewGame(lastMode, 0)
                self:SetID(0)
                self:Hide()
            else
                Bejeweled.gameModeWindow:Show()
            end
        end
    end)
    button:SetBackdrop(statusBarBackdrop())
    button:SetBackdropColor(0.1, 0.1, 0.1, 0)
    button:SetFrameLevel(statusBar:GetFrameLevel() + 4)
    Bejeweled.levelBarButton = button

    local background = CreateFrame("Frame", nil, button, "BackdropTemplate")
    background:SetPoint("TOPLEFT")
    background:SetPoint("BOTTOMRIGHT")
    background:SetBackdrop(statusBarBackdrop())
    background:SetBackdropColor(0.1, 0.1, 0.1)
    background:SetBackdropBorderColor(0, 0, 0, 0)
    background:SetFrameLevel(statusBar:GetFrameLevel() + 3)

    local bar = background:CreateTexture(nil, "OVERLAY")
    bar:SetTexture(ns.Textures.Path("barArt"))
    bar:SetVertexColor(0.6, 0, 0)
    bar:SetPoint("TOPLEFT", 2, -5)
    bar:SetPoint("BOTTOMRIGHT", -2, -5)
    button.bar = bar

    button.text = Bejeweled:CreateCaption(0, 0, "New Game", button, 12, 1, 0.85, 0)
    button.text:ClearAllPoints()
    button.text:SetPoint("CENTER", 0, 1)

    local iconFrame = CreateFrame("Frame", nil, button, "BackdropTemplate")
    iconFrame:SetPoint("TOPRIGHT", button, "TOPLEFT", 20, 0)
    iconFrame:SetSize(70, 32)
    iconFrame.art = iconFrame:CreateTexture(nil, "ARTWORK")
    iconFrame.art:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
    iconFrame.art:SetPoint("CENTER", -1, 0)
    iconFrame.art:SetSize(28, 28)
    iconFrame.art:SetTexCoord(0, 0.49, 0, 0.49)
    iconFrame:SetBackdrop(borderBackdrop())
    iconFrame:SetBackdropColor(0, 0, 0, 0)
end

local function createStatusBar(window)
    local statusBar = CreateFrame("Frame", nil, window)
    statusBar:SetPoint("BOTTOMLEFT", -10, 10)
    statusBar:SetPoint("BOTTOMRIGHT", -32, 10)
    statusBar:SetHeight(32)
    statusBar:SetFrameLevel(window:GetFrameLevel() + 2)
    Bejeweled.statusBar = statusBar

    local levelBorder = CreateFrame("Frame", nil, statusBar, "BackdropTemplate")
    levelBorder:SetPoint("BOTTOMLEFT", 0, 0)
    levelBorder:SetSize(86, 32)
    levelBorder:SetBackdrop(borderBackdrop())
    levelBorder:SetBackdropColor(0, 0, 0, 0)
    Bejeweled.levelBorder = levelBorder

    local levelText = Bejeweled:CreateCaption(0, 0, "", levelBorder, 12, 1, 1, 1, true)
    levelText:ClearAllPoints()
    levelText:SetPoint("TOPLEFT", 16, 0)
    levelText:SetPoint("BOTTOMRIGHT", -46, 1)
    levelText:SetJustifyH("RIGHT")
    Bejeweled.levelText = levelText

    local levelTextCaption = Bejeweled:CreateCaption(0, 0, "", levelBorder, 11, 1, 1, 1, true)
    levelTextCaption:SetWidth(1)
    levelTextCaption:ClearAllPoints()
    levelTextCaption:SetJustifyH("LEFT")
    levelTextCaption:SetPoint("TOPLEFT", levelText, "TOPRIGHT", -5, 0)
    levelTextCaption:SetPoint("BOTTOMRIGHT", -16, 1)
    Bejeweled.levelTextCaption = levelTextCaption

    local dataBorder = CreateFrame("Frame", nil, statusBar, "BackdropTemplate")
    dataBorder:SetPoint("BOTTOMLEFT", levelBorder, "BOTTOMRIGHT", -40, 0)
    dataBorder:SetSize(128, 32)
    dataBorder:SetBackdrop(borderBackdrop())
    dataBorder:SetBackdropColor(0, 0, 0, 0)
    Bejeweled.dataBorder = dataBorder

    Bejeweled.dataText = Bejeweled:CreateCaption(0, 0, "", dataBorder, 10, 1, 1, 1, true)
    Bejeweled.dataText:ClearAllPoints()
    Bejeweled.dataText:SetPoint("CENTER", 0, 1)

    createLevelBar(statusBar, dataBorder, window)
    createLevelBarButton(statusBar, window)
end

-- After the splash: start the first-ever game, or resume a saved classic game, or open the menu.
local function onSplashFaded(splash)
    splash:Hide()
    local wasPaused = Bejeweled.paused
    Bejeweled.window.menuButton:Enable()
    if splash.firstGame then
        ns.startNewGame(C.MODE_CLASSIC, 120)
    elseif not ns.game.gameMode then
        local char = ns.db.char
        if char.classicInProgress and char.savedState then
            ns.startNewGame(C.MODE_CLASSIC, 120, true)
            ns.setPaused(false)
            if wasPaused then
                ns.setPaused(true)
            end
        else
            char.classicInProgress = false
            Bejeweled.menuWindow:Show()
        end
    end
end

-- Counts only while the window is visible (OnUpdate); started by setting splash.elapsed = 0.
local function createSplash(gameBoard, window)
    local splash = CreateFrame("Frame", nil, gameBoard)
    splash:SetPoint("TOPLEFT")
    splash:SetPoint("BOTTOMRIGHT")
    splash.art = splash:CreateTexture(nil, "ARTWORK")
    splash.art:SetPoint("TOPLEFT", gameBoard, "TOPLEFT", 12, -7)
    splash.art:SetPoint("BOTTOMRIGHT", gameBoard, "BOTTOMRIGHT", -7, 10)
    splash.art:SetTexture(ns.Textures.Path("splash"))
    splash.text =
        Bejeweled:CreateCaption(0, 0, "(c) 2000, 2008 PopCap Games Inc. All right reserved", splash, 12, 1, 1, 1)
    splash.text:ClearAllPoints()
    splash.text:SetPoint("BOTTOMLEFT", splash, "BOTTOMLEFT", 14, 14)
    splash:SetScript("OnHide", function()
        local const = Bejeweled.const
        if ns.totalGamesAllChars > 1000 and not ns.db.char.skill["gainAchieve" .. const.SKILL_ACHIEVE4B] then
            Bejeweled.skillBar:CheckSkill(const.SKILLTYPE_ACHIEVEMENT, const.SKILL_ACHIEVE4B)
        end
    end)
    splash:SetScript("OnUpdate", function(self, elapsed)
        if not self.elapsed then
            return
        end
        self.elapsed = self.elapsed + math.min(elapsed, 0.1)
        if self.elapsed >= Bejeweled.splashDisplayTime then
            self.elapsed = nil
            UIFrameFade(self, {
                mode = "OUT",
                timeToFade = 1,
                startAlpha = 1,
                endAlpha = 0,
                finishedFunc = onSplashFaded,
                finishedArg1 = self,
            })
        end
    end)
    splash:SetFrameLevel(window:GetFrameLevel() + 5)
    window.splash = splash
    window.menuButton:Disable()
end

local function createGems(gameArea)
    for row = 1, C.BOARD_ROWS do
        for col = 1, C.BOARD_COLS do
            local gem = ns.createGemFrame((col - 1) * GEM_WIDTH, (row - 1) * GEM_HEIGHT, gameArea, 1)
            gem:EnableMouse(true)
            gem:RegisterForDrag("LeftButton")
            gem:SetScript("OnEnter", ns.onGemEnter)
            gem:SetScript("OnLeave", ns.onGemLeave)
            gem:SetScript("OnMouseDown", ns.onGemMouseDown)
            gem:SetScript("OnDragStart", ns.onGemDragStart)
            gem:SetFrameLevel(ns.frameLevelGem)
            gem.gridX = col
            gem.gridY = row
            ns.board[row][col] = gem
        end
    end
end

ns.RegisterBuilder("GameArea", function()
    local window = Bejeweled.window
    local gameBoard = Bejeweled.gameBoard

    local gameArea = CreateFrame("Frame", nil, gameBoard)
    gameArea:SetSize(BOARD_WIDTH, BOARD_HEIGHT)
    gameArea:SetPoint("TOPLEFT", 8, -4)
    gameArea:EnableMouse(true)
    gameArea:SetFrameLevel(window:GetFrameLevel() + 1)
    Bejeweled.gameArea = gameArea
    createBackgroundTiles(gameArea)

    local foreground = CreateFrame("Frame", nil, gameBoard)
    foreground:SetSize(BOARD_WIDTH + 14, BOARD_HEIGHT + 12)
    foreground:SetPoint("TOPLEFT", 0, 0)
    Bejeweled.foreground = foreground
    createStatusText(foreground, gameBoard)

    createStatusBar(window)

    local pausedText = CreateFrame("Frame", nil, gameBoard)
    pausedText:SetPoint("CENTER")
    pausedText:SetSize(64, 64)
    pausedText.text = Bejeweled:CreateCaption(0, 0, "Paused", pausedText, 40, 1, 0.85, 0, true)
    pausedText.text:ClearAllPoints()
    pausedText.text:SetPoint("CENTER", 0, 1)
    pausedText:SetScale(3)
    pausedText:Hide()
    Bejeweled.pausedText = pausedText

    createSplash(gameBoard, window)

    ns.frameLevelGem = gameArea:GetFrameLevel() + C.FRAME_LEVEL_GEM_OFFSET
    ns.frameLevelSwap = gameArea:GetFrameLevel() + C.FRAME_LEVEL_SWAP_OFFSET
    createGems(gameArea)
    Bejeweled.animator:CreateHint()
end)
