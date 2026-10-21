local _, ns = ...
local Bejeweled = ns.addon
local C = ns.C
local WINDOW_WIDTH, WINDOW_HEIGHT, BOARD_HEIGHT = C.WINDOW_WIDTH, C.WINDOW_HEIGHT, C.BOARD_HEIGHT

-- The main game window: draggable/resizable frame with logo, menu button, the
-- show/hide toggle button (keybinding target) and the fade-out mouse-over overlay.

local LOGO_AREA_HEIGHT = 59

-- Rescales board, summary, logo and icon to follow the window width.
local function onSizeChanged(self)
    local scale = self:GetWidth() / WINDOW_WIDTH
    local iconScale = 1
    local logoWidth, logoHeight = ns.Textures.Display("logo")
    if scale < 0.887 then
        if not self.menuButton.isSmall then
            self.menuButton.isSmall = true
            self.menuButton:SetWidth(26)
            self.menuButton:SetText("M")
        end
    elseif self.menuButton.isSmall then
        self.menuButton.isSmall = nil
        self.menuButton:SetWidth(50)
        self.menuButton:SetText("Menu")
    end
    if scale < 0.855 then
        iconScale = math.max(0.75, scale / 0.855 / (0.855 / scale))
    end
    local logoScale = math.min(logoWidth, self:GetWidth() - iconScale * 56 - self.menuButton:GetWidth()) / logoWidth
    Bejeweled.gameBoard:SetScale(scale)
    Bejeweled.summaryScreen:SetScale(scale)
    self:SetHeight((BOARD_HEIGHT + 4) * scale + 110)
    local levelBar = Bejeweled.levelBar
    if levelBar then
        if not ns.game.gameOver then
            levelBar:SetScore(levelBar.score or 0)
        else
            levelBar.bar:SetWidth(levelBar:GetWidth() - 4)
        end
    end
    self.logo:SetSize(logoWidth * logoScale, logoHeight * logoScale)
    self.icon:SetWidth(64 * iconScale)
    self.icon:SetHeight(64 * iconScale)
    Bejeweled.resizeUpdate = true
end

ns.RegisterBuilder("MainWindow", function()
    local window = CreateFrame("Frame", "BejeweledReduxWindow", UIParent, "BackdropTemplate")
    window:SetWidth(WINDOW_WIDTH)
    window:SetHeight(WINDOW_HEIGHT)
    window:SetPoint("CENTER")
    window:EnableMouse(true)
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:SetPropagateKeyboardInput(true)
    window:Hide()
    Bejeweled.window = window

    -- Mouse-leave fading (Features/Sound.lua) checks the cursor against this slightly larger area.
    window.mouseBounds = CreateFrame("Frame", nil, window)
    window.mouseBounds:SetPoint("TOPLEFT", -20, 20)
    window.mouseBounds:SetPoint("BOTTOMRIGHT", 20, -20)

    local backdrop = ns.makeBackdrop()
    backdrop.edgeFile = ns.Textures.Path("windowBorder")
    backdrop.bgFile = ns.Textures.Path("windowBackground")
    backdrop.edgeSize = 32
    backdrop.tileSize = 64
    backdrop.insets.right = 3
    window:SetBackdrop(backdrop)
    window:SetBackdropColor(0.7, 0.7, 0.7, 1)

    window:SetMovable(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", function(self)
        if not ns.db.profile.lockWindow then
            self:StartMoving()
        end
    end)
    window:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
    window:SetScript("OnHide", function()
        Bejeweled.isShown = nil
        ns.game.isActive = nil
        ns.game.activeTime = 0
    end)
    window:SetScript("OnShow", function(self)
        Bejeweled.isShown = true
        self:SetAlpha(ns.db.profile.gameAlpha)
        local sound = Bejeweled.sound
        if self:IsMouseOver() then
            sound.waitMouseOver = nil
            sound.mouseOver = true
        else
            sound.waitMouseOver = true
            sound.mouseOver = nil
        end
        self.mouseOverScreen:Hide()
        sound:Show()
        if Bejeweled.summaryScreen:GetAlpha() == 1 then
            ns.setPaused(false)
        end
    end)

    local closeButton = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    closeButton:SetToplevel(true)
    closeButton:SetPoint("TOPRIGHT", window, "TOPRIGHT", 2, 2)
    closeButton:SetSize(32, 32)
    closeButton:SetScript("OnClick", function()
        if not Bejeweled.popup:IsVisible() then
            window:Hide()
        end
    end)

    local menuButton = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    menuButton:SetToplevel(true)
    menuButton:SetPoint("TOPRIGHT", -12, -30)
    menuButton:SetText("Menu")
    menuButton:SetSize(50, 26)
    menuButton:SetScript("OnClick", function()
        local menuWindow = Bejeweled.menuWindow
        if
            Bejeweled.aboutScreen:IsVisible()
            or Bejeweled.featsOfSkillScreen:IsVisible()
            or (Bejeweled.optionsScreen and Bejeweled.optionsScreen:IsVisible())
        then
            menuWindow.keepScreen = true
        end
        menuWindow:SetShown(not menuWindow:IsShown())
    end)
    window.menuButton = menuButton

    local icon = window:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ns.Textures.Path("windowIcon"))
    icon:SetPoint("TOPLEFT", -12, 4)
    icon:SetSize(64, 64)
    window.icon = icon

    local logoWidth, logoHeight = ns.Textures.Display("logo")
    local logoFrame = CreateFrame("Frame", nil, window)
    logoFrame:SetPoint("TOPLEFT", window)
    logoFrame:SetPoint("TOPRIGHT", window, -8, 0)
    -- The title area keeps the original logo height; taller pack logos hang up over the window edge.
    logoFrame:SetHeight(LOGO_AREA_HEIGHT)
    local logo = logoFrame:CreateTexture(nil, "ARTWORK")
    ns.Textures.Apply(logo, "logo", "logo")
    logo:SetPoint("BOTTOM", 0, 0)
    logo:SetSize(logoWidth, logoHeight)
    window.logo = logo

    -- Bottom-right grip: drag to resize (height follows width), right-click to reset.
    local resizeGrip = CreateFrame("Frame", nil, window)
    resizeGrip:SetPoint("BOTTOMRIGHT", 0, 0)
    resizeGrip:SetSize(32, 32)
    resizeGrip:SetFrameLevel(window:GetFrameLevel() + 3)
    resizeGrip:EnableMouse(true)
    resizeGrip:SetScript("OnMouseDown", function(_, button)
        if ns.db.profile.lockWindow then
            return
        end
        if button == "RightButton" then
            window:SetWidth(WINDOW_WIDTH)
            window:SetHeight(BOARD_HEIGHT + 4 + 110)
        else
            window:StartSizing("RIGHT")
            window.resizing = true
        end
    end)
    resizeGrip:SetScript("OnMouseUp", function()
        window:StopMovingOrSizing()
        window.resizing = nil
    end)
    window:SetResizable(true)
    window:SetResizeBounds(WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2, WINDOW_WIDTH * 1.5, WINDOW_HEIGHT * 1.5)
    window:SetScript("OnSizeChanged", onSizeChanged)

    -- Named click target for the show/hide keybinding (SetOverrideBindingClick), and a
    -- 1x1 toggle hot spot in the bottom-right screen corner.
    local showHideButton = CreateFrame("Button", "BejeweledReduxShowHideButton", UIParent)
    showHideButton:SetSize(1, 1)
    showHideButton:SetPoint("BOTTOMRIGHT")
    showHideButton:SetScript("OnClick", function()
        window:SetShown(not window:IsShown())
    end)
    window.showHideButton = showHideButton

    -- Covers the window while it is faded out; hovering fades it back in.
    local mouseOverScreen = CreateFrame("Frame", nil, window)
    mouseOverScreen:SetPoint("TOPLEFT")
    mouseOverScreen:SetPoint("BOTTOMRIGHT")
    mouseOverScreen:EnableMouse(true)
    mouseOverScreen:SetScript("OnMouseDown", function(self)
        if window.hiding then
            window.hiding = nil
            Bejeweled.const.windowGameOverFadeOut.timeToFade = -1
            Bejeweled.sound.mouseOver = true
            Bejeweled.sound:Show()
            self:Hide()
        end
    end)
    mouseOverScreen:SetScript("OnEnter", function(self)
        if window.hiding then
            return
        end
        self:Hide()
        Bejeweled.const.windowFadeIn.fadeTimer = 0
        UIFrameFade(window, Bejeweled.const.windowFadeIn)
        Bejeweled.sound.mouseOver = true
        Bejeweled.sound:Show()
        if Bejeweled.mousePaused == true then
            if Bejeweled.summaryScreen:GetAlpha() == 1 then
                ns.setPaused(false)
            end
            Bejeweled.mousePaused = nil
        end
    end)
    mouseOverScreen:SetFrameLevel(window:GetFrameLevel() + 80)
    window.mouseOverScreen = mouseOverScreen
end)
