local _, ns = ...
local Bejeweled = ns.addon
local C = ns.C
local MENU_WIDTH, MENU_HEIGHT = C.MENU_WIDTH, C.MENU_HEIGHT
local MODE_CLASSIC, MODE_TIMED, MODE_FLIGHT = C.MODE_CLASSIC, C.MODE_TIMED, C.MODE_FLIGHT

-- In-window menus: main menu, game type, classic (continue / new) and timed (duration, flight time).

local function hideIfPresent(frame)
    if frame then
        frame:Hide()
    end
end

-- Shows the status-bar button as a "close screen" button while a sub-screen is open.
local function showCloseScreenButton()
    local button = Bejeweled.levelBarButton
    if button:GetID() == 0 then
        button:SetID(1)
    end
    button:Show()
end

local function createMenuFrame(name, height, levelOffset, title, titleX)
    local menu = CreateFrame("Frame", name, Bejeweled.window, "BackdropTemplate")
    menu:SetWidth(MENU_WIDTH)
    menu:SetHeight(height)
    menu:SetPoint("CENTER")
    menu:EnableMouse(true)
    menu:Hide()
    menu:SetFrameLevel(Bejeweled.window:GetFrameLevel() + levelOffset)
    local backdrop = ns.makeBackdrop()
    backdrop.edgeFile = "Interface\\Glues\\Common\\TextPanel-Border"
    backdrop.bgFile = C.IMAGE_PATH .. "windowBackground"
    backdrop.edgeSize = 32
    backdrop.tileSize = 128
    backdrop.insets.top = 3
    menu:SetBackdrop(backdrop)
    menu:SetBackdropColor(0.6, 0.6, 0.6, 1)
    menu:SetBackdropBorderColor(1, 0.8, 0.45)
    menu:SetMovable(true)
    local closeButton = CreateFrame("Button", nil, menu, "UIPanelCloseButton")
    closeButton:SetToplevel(true)
    closeButton:SetPoint("TOPRIGHT", menu, "TOPRIGHT", 0, 2)
    closeButton:SetSize(38, 38)
    local label = menu:CreateFontString(nil, "OVERLAY")
    label:SetFont(STANDARD_TEXT_FONT, 16, "OUTLINE")
    label:SetTextColor(1, 1, 1)
    label:SetPoint("TOP", titleX, -8)
    label:SetText(title)
    return menu
end

local function createMenuButton(parent, text, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetText(text)
    button:SetSize(MENU_WIDTH - 20, 28)
    button:SetScript("OnClick", onClick)
    return button
end

local function createLabel(parent, fontSize, y, text)
    local label = parent:CreateFontString(nil, "OVERLAY")
    label:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
    label:SetTextColor(1, 1, 1)
    label:SetPoint("TOP", 0, y)
    label:SetText(text)
    return label
end

local function createMainMenu()
    local menu = createMenuFrame("BejeweledReduxMenu", MENU_HEIGHT - 20, 30, "Menu", 0)
    menu:SetScript("OnShow", function(self)
        ns.setPaused(true)
        if not ns.game.gameOver and ns.game.gameMode then
            self.buttonResume:Show()
            self.buttonNewGame:ClearAllPoints()
            self.buttonNewGame:SetPoint("BOTTOM", self.buttonResume, "BOTTOM", 0, -32)
            self:SetHeight(MENU_HEIGHT - 20)
        else
            self.buttonResume:Hide()
            self.buttonNewGame:ClearAllPoints()
            self.buttonNewGame:SetPoint("TOP", self, "TOP", 2, -30)
            self:SetHeight(MENU_HEIGHT - 32 - 18)
        end
        Bejeweled.timedWindow:Hide()
        Bejeweled.gameModeWindow:Hide()
    end)
    menu:SetScript("OnHide", function(self)
        if self.keepScreen then
            self.keepScreen = nil
        else
            ns.setPaused(false)
            Bejeweled.aboutScreen:Hide()
            Bejeweled.featsOfSkillScreen:Hide()
            hideIfPresent(Bejeweled.optionsScreen)
        end
    end)

    local resume = createMenuButton(menu, "Resume", function()
        menu.keepScreen = nil
        menu:Hide()
        Bejeweled.levelBarButton:Hide()
    end)
    resume:SetPoint("TOP", 2, -30)
    menu.buttonResume = resume

    local newGame = createMenuButton(menu, "New Game", function()
        menu.keepScreen = true
        menu:Hide()
        Bejeweled.gameModeWindow:Show()
    end)
    newGame:SetPoint("BOTTOM", resume, "BOTTOM", 0, -32)
    menu.buttonNewGame = newGame

    local skills = createMenuButton(menu, "Feats of Skill", function()
        menu:Hide()
        Bejeweled.aboutScreen:Hide()
        hideIfPresent(Bejeweled.optionsScreen)
        Bejeweled.featsOfSkillScreen:Show()
        showCloseScreenButton()
    end)
    skills:SetPoint("TOP", newGame, "BOTTOM", 0, -4)
    menu.buttonSkills = skills

    local options = createMenuButton(menu, "Options", function()
        ns.OpenOptions()
    end)
    options:SetPoint("TOP", skills, "BOTTOM", 0, -4)
    menu.buttonOptions = options

    local about = createMenuButton(menu, "About", function()
        menu:Hide()
        ns.onTabClick(Bejeweled.aboutScreen.tab2, true)
        Bejeweled.featsOfSkillScreen:Hide()
        hideIfPresent(Bejeweled.optionsScreen)
        Bejeweled.aboutScreen:Show()
        showCloseScreenButton()
    end)
    about:SetPoint("TOP", options, "BOTTOM", 0, -4)
    menu.buttonAbout = about

    Bejeweled.menuWindow = menu
end

local function createTimedMenu()
    local menu = createMenuFrame("BejeweledReduxTimedMenu", MENU_HEIGHT - 30, 33, "Timed Mode", -10)

    local function setFlightWidgetsShown(shown)
        menu:SetHeight(shown and (MENU_HEIGHT - 30) or (MENU_HEIGHT - 80))
        menu.flightCheckbox:SetShown(shown)
        menu.timerRemainingCaption:SetShown(shown)
        menu.timeRemainingValue:SetShown(shown)
    end

    menu:SetScript("OnShow", function(self)
        ns.setPaused(true)
        self.flightCheckbox.disabled = nil
        self.flightCheckbox:Enable()
        self.flightCheckbox:SetChecked(false)
        self.flightCheckboxCaption:Hide()
        setFlightWidgetsShown(ns.Flight.IsOnFlight())
    end)
    menu:SetScript("OnHide", function(self)
        if self.newGame then
            self.newGame = nil
            ns.setPaused(false)
            if ns.game.gameMode == MODE_TIMED then
                Bejeweled.levelBar:StopTimer()
            elseif ns.game.gameMode == MODE_FLIGHT then
                Bejeweled.animator.countdownState = 0
                ns.game.moveAllowed = nil
            end
        else
            Bejeweled.gameModeWindow:Show()
        end
    end)

    createLabel(menu, 10, -28, "Time")
    local sliderValue = createLabel(menu, 10, -70, "1 Minute")

    local slider = CreateFrame("Slider", nil, menu, "UISliderTemplateWithLabels")
    slider:SetSize(144, 17)
    slider.Text:SetText("")
    slider.Low:SetText("")
    slider.High:SetText("")
    slider:SetMinMaxValues(2, 10)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    slider:SetPoint("TOP", 0, -50)
    slider:SetScript("OnValueChanged", function(self)
        sliderValue:SetText(self:GetValue() .. " Minute(s)")
    end)
    slider:SetValue(5)
    menu.timeSlider = slider

    local flightCheckbox = CreateFrame("CheckButton", nil, menu, "UICheckButtonTemplate")
    flightCheckbox:SetSize(21, 21)
    flightCheckbox:SetPoint("TOPLEFT", 14, -88)
    flightCheckbox.Text:SetFont(STANDARD_TEXT_FONT, 11, "")
    flightCheckbox.Text:SetShadowOffset(1, -1)
    flightCheckbox.Text:SetText("|cFFFF9922Use flightpath time")
    menu.flightCheckbox = flightCheckbox

    menu.flightCheckboxCaption = createLabel(menu, 11, -87, "|cFFFF9922Flight time is too\nshort for a timed game.")
    menu.timerRemainingCaption = createLabel(menu, 10, -118, "Remaining flight time")
    menu.timeRemainingValue = createLabel(menu, 10, -134, "0s")

    local go = createMenuButton(menu, "Go!", function()
        if flightCheckbox:IsVisible() and flightCheckbox:GetChecked() then
            Bejeweled.flightOptionWindow.buttonGo:OnClickScript()
        else
            ns.startNewGame(MODE_TIMED, slider:GetValue() * 60)
        end
        menu.newGame = true
        menu:Hide()
    end)
    go:SetPoint("BOTTOM", 1, 10)

    Bejeweled.timedWindow = menu
end

local function createGameModeMenu()
    local menu = createMenuFrame("BejeweledReduxGameModeMenu", MENU_HEIGHT - 100, 33, "Game Type", -10)
    menu:SetScript("OnShow", function()
        ns.setPaused(true)
    end)
    menu:SetScript("OnHide", function(self)
        if self.gameMode then
            self.gameMode = nil
            ns.setPaused(false)
        else
            Bejeweled.menuWindow:Show()
        end
    end)

    local classic = createMenuButton(menu, "Classic", function()
        menu.gameMode = true
        menu:Hide()
        Bejeweled.classicModeWindow:Show()
    end)
    classic:SetPoint("TOP", 2, -30)
    menu.buttonNormal = classic

    local timed = createMenuButton(menu, "Timed", function()
        menu.gameMode = true
        menu:Hide()
        Bejeweled.timedWindow:Show()
    end)
    timed:SetPoint("BOTTOM", classic, "BOTTOM", 0, -36)
    menu.buttonTimed = timed

    Bejeweled.gameModeWindow = menu
end

local function createClassicMenu()
    local menu = createMenuFrame("BejeweledReduxClassicMenu", MENU_HEIGHT - 100, 33, "Classic Mode", -10)
    -- Without a saved game there is nothing to choose: start right away.
    menu:SetScript("OnShow", function(self)
        local savedState = ns.db.char.savedState
        if savedState and savedState[1][1] ~= 0 then
            ns.setPaused(true)
        else
            self.gameMode = true
            self:Hide()
            ns.startNewGame(MODE_CLASSIC, 0)
        end
    end)
    menu:SetScript("OnHide", function(self)
        if self.gameMode then
            self.gameMode = nil
            ns.setPaused(false)
        else
            Bejeweled.gameModeWindow:Show()
        end
    end)

    local continueButton = createMenuButton(menu, "Continue", function()
        ns.startNewGame(MODE_CLASSIC, 0, true)
        menu.gameMode = true
        menu:Hide()
    end)
    continueButton:SetPoint("TOP", 2, -30)
    menu.buttonContinue = continueButton

    local newGame = createMenuButton(menu, "New Game", function()
        ns.startNewGame(MODE_CLASSIC, 0)
        menu.gameMode = true
        menu:Hide()
    end)
    newGame:SetPoint("BOTTOM", continueButton, "BOTTOM", 0, -36)
    menu.buttonNew = newGame

    Bejeweled.classicModeWindow = menu
end

ns.RegisterBuilder("Menus", function()
    createMainMenu()
    createTimedMenu()
    createGameModeMenu()
    createClassicMenu()
end)
