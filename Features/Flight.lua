local _, ns = ...
local Bejeweled = ns.addon
local C = ns.C
local MENU_WIDTH, MENU_HEIGHT = C.MENU_WIDTH, C.MENU_HEIGHT
local MODE_FLIGHT = C.MODE_FLIGHT

-- Flight-path integration: learns how long each taxi route takes, shows the time on flight-master
-- tooltips, and runs the flight timer that drives Flight-mode games (game length = remaining flight).
-- Routes are keyed "Origin>Destination" by taxi node name; a multi-hop flight is keyed by its first
-- origin and final destination. Learned times live in ns.db.global.flightTimes[key] (seconds).

ns.Flight = {}

local events = {}
LibStub("AceEvent-3.0"):Embed(events)

local function currentNodeName()
    for i = 1, NumTaxiNodes() do
        if TaxiNodeGetType(i) == "CURRENT" then
            return TaxiNodeName(i)
        end
    end
end

local function routeKeyTo(slot)
    local origin, destination = currentNodeName(), TaxiNodeName(slot)
    if origin and destination then
        return origin .. ">" .. destination
    end
end

-- Hides the "use flight time" controls of the timed-mode menu once the flight is over or too short.
local function hideTimedFlightOptions()
    local timedWindow = Bejeweled.timedWindow
    if timedWindow:IsVisible() then
        timedWindow:SetHeight(MENU_HEIGHT - 80)
        timedWindow.flightCheckbox:Hide()
        timedWindow.flightCheckboxCaption:Hide()
        timedWindow.flightCheckbox:SetChecked(false)
        timedWindow.timerRemainingCaption:Hide()
        timedWindow.timeRemainingValue:Hide()
    end
end

-- Time is measured from takeoff with GetTime(), so it stays correct while the UI is hidden.
function ns.flightTimerOnUpdate(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed < 0.1 then
        return
    end
    self.elapsed = 0
    self.timeElapsed = GetTime() - self.takeoffTime
    self.timeRemaining = self.flightTime - self.timeElapsed
    local menu = Bejeweled.flightOptionWindow
    local timedWindow = Bejeweled.timedWindow
    if not menu.learning and self.timeRemaining < 60 and not timedWindow.flightCheckbox.disabled then
        timedWindow.flightCheckbox.disabled = true
        timedWindow.flightCheckbox:Hide()
        timedWindow.flightCheckboxCaption:Show()
    end
    -- Past the learned time the "use flight time" option goes away, but the timer keeps
    -- running until the actual landing.
    if self.timeRemaining <= 0 and not menu.learning and not self.overrun then
        self.overrun = true
        hideTimedFlightOptions()
    end
    if timedWindow:IsVisible() then
        if menu.learning then
            timedWindow.timeRemainingValue:SetText(Bejeweled:TotalTime(math.floor(self.timeElapsed)))
        else
            timedWindow.timeRemainingValue:SetText(Bejeweled:TotalTime(math.floor(self.timeRemaining)))
        end
    end
    ns.Flight.CheckLanding()
end

-- Stores the measured duration of the flight that just landed. A time within 5 s of the stored one
-- is averaged in; anything further off replaces it.
function Bejeweled:UpdateFlightTimes()
    local menu = Bejeweled.flightOptionWindow
    local key, takeoffTime = menu.routeKey, menu.timer.takeoffTime
    menu.routeKey = nil
    if not (key and takeoffTime) then
        return
    end
    local measured = math.floor(GetTime() - takeoffTime + 0.5)
    if measured < 5 then
        return
    end
    local flightTimes = ns.db.global.flightTimes
    local stored = flightTimes[key]
    if not stored or math.abs(measured - stored) > 5 then
        flightTimes[key] = measured
    else
        flightTimes[key] = (stored + measured) / 2
    end
end

function ns.Flight.IsOnFlight()
    return UnitOnTaxi("player")
end

-- Seconds left on the current flight, or nil when not flying or the route is still being learned.
function ns.Flight.GetRemainingTime()
    local menu = Bejeweled.flightOptionWindow
    local timer = menu and menu.timer
    if not (timer and timer.timeElapsed) or menu.learning or timer.learning then
        return nil
    end
    return math.max(0, timer.timeRemaining)
end

local function onTakeTaxiNode(slot)
    local menu = Bejeweled.flightOptionWindow
    local key = routeKeyTo(slot)
    local known = key and ns.db.global.flightTimes[key]
    menu.routeKey = key
    menu.flightTime = known and math.floor(known) or 0
    menu.learning = not known
    events:RegisterEvent("UNIT_FLAGS")
end

function events:UNIT_FLAGS(_, unit)
    if unit ~= "player" or not UnitOnTaxi("player") then
        return
    end
    self:UnregisterEvent("UNIT_FLAGS")
    Bejeweled.flightOptionWindow:Show()
    if ns.db.profile.openFlightStart then
        Bejeweled.window:Show()
        ns.setPaused(false)
    end
end

-- Ends the flight once the player is off the taxi. Called from the flight timer's OnUpdate and on
-- PLAYER_CONTROL_GAINED: when that event fires on landing, UnitOnTaxi can still be true for a
-- moment, so the timer keeps checking until it clears.
function ns.Flight.CheckLanding()
    local menu = Bejeweled.flightOptionWindow
    local timer = menu.timer
    if not timer.timeElapsed or UnitOnTaxi("player") then
        return
    end
    local window = Bejeweled.window
    timer:Hide()
    hideTimedFlightOptions()
    Bejeweled:UpdateFlightTimes()
    events:UnregisterEvent("PLAYER_CONTROL_GAINED")
    local levelTimer = Bejeweled.levelBar.timer
    if ns.game.gameMode == MODE_FLIGHT and not ns.game.gameOver and levelTimer.timeElapsed then
        if math.abs(timer.timeElapsed - levelTimer.timeElapsed) > 1 then
            levelTimer.timeElapsed = timer.timeElapsed
        end
        levelTimer:Hide()
        ns.endGame()
    end
    timer.elapsed = nil
    timer.timeElapsed = nil
    timer.takeoffTime = nil
    timer.overrun = nil
    menu.learning = nil
    if ns.db.profile.closeFlightEnd and window:IsShown() and not Bejeweled.popup:IsVisible() then
        Bejeweled.const.windowGameOverFadeOut.fadeTimer = 0
        UIFrameFade(window, Bejeweled.const.windowGameOverFadeOut)
        window.mouseOverScreen:Show()
        window.hiding = true
    end
end

function events:PLAYER_CONTROL_GAINED()
    ns.Flight.CheckLanding()
end

local function addFlightTimeLine(slot)
    if not ns.db.profile.showFlightTooltips then
        return
    end
    local key = routeKeyTo(slot)
    local seconds = key and ns.db.global.flightTimes[key]
    if seconds then
        seconds = math.floor(seconds + 0.5)
        GameTooltip:AddLine(string.format("Bejeweled: %d:%02d flight", seconds / 60, seconds % 60), 1, 1, 0)
        GameTooltip:Show()
    end
end

local function onTaxiNodeButtonEnter(button)
    local slot = button:GetID()
    if TaxiNodeGetType(slot) == "REACHABLE" then
        addFlightTimeLine(slot)
    end
end

local function onFlightPointPinEnter(pin)
    local node = pin.taxiNodeData
    if node and node.state == Enum.FlightPathState.Reachable then
        addFlightTimeLine(node.slotIndex)
    end
end

local function createFlightOptionMenu()
    local menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    menu:SetWidth(MENU_WIDTH)
    menu:SetHeight(MENU_HEIGHT)
    menu:SetToplevel(true)
    menu:SetFrameStrata("HIGH")
    menu:SetPoint("CENTER")
    menu:EnableMouse(true)
    menu:Hide()
    local backdrop = ns.makeBackdrop()
    backdrop.edgeFile = "Interface\\Glues\\Common\\TextPanel-Border"
    backdrop.bgFile = ns.Textures.Path("windowBackground")
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
    closeButton:SetWidth(38)
    closeButton:SetHeight(38)

    local function addLabel(size, y, text)
        local label = menu:CreateFontString(nil, "OVERLAY")
        label:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE")
        label:SetTextColor(1, 1, 1)
        label:SetPoint("TOP", 0, y)
        label:SetText(text)
        return label
    end
    addLabel(16, -8, "Flight Path"):SetPoint("TOP", -10, -8)
    menu.timerRemainingCaption = addLabel(12, -38, "Remaining path time")
    menu.timeRemainingValue = addLabel(18, -54, "0 min 0 sec")
    local note = addLabel(12, -80, "Games shorter than 60 seconds don't count.")
    note:SetWidth(MENU_WIDTH - 16)
    note:SetHeight(40)
    note:SetJustifyV("TOP")
    note:SetJustifyH("CENTER")

    -- Shown once at takeoff to start the flight timer; it hides itself right away unless it starts
    -- a Flight-mode game, which also hides it.
    menu:SetScript("OnShow", function(self)
        local timer = self.timer
        if not timer.elapsed then
            self.buttonGo:Enable()
            timer.elapsed = 0
            timer.timeElapsed = 0
            timer.takeoffTime = GetTime()
            timer.flightTime = self.flightTime or 0
            timer.timeRemaining = timer.flightTime
            timer.learning = self.learning
            timer:Show()
            local timedWindow = Bejeweled.timedWindow
            timedWindow.timeRemainingValue:SetFormattedText(
                "%d min %d sec",
                Bejeweled:SecondsConvert(timer.flightTime)
            )
            if timedWindow:IsVisible() then
                timedWindow:SetHeight(MENU_HEIGHT - 30)
                timedWindow.flightCheckbox:Show()
                timedWindow.flightCheckboxCaption:Hide()
                timedWindow.flightCheckbox:SetChecked(false)
                timedWindow.flightCheckbox:Enable()
                timedWindow.flightCheckbox.disabled = nil
                timedWindow.timerRemainingCaption:Show()
                timedWindow.timeRemainingValue:Show()
            end
            if self.learning then
                timedWindow.timerRemainingCaption:SetText("Recording flight time")
            else
                timedWindow.timerRemainingCaption:SetText("Remaining flight time")
            end
            events:RegisterEvent("PLAYER_CONTROL_GAINED")
            local profile = ns.db.profile
            if profile.newGameFlight and (Bejeweled.window:IsVisible() or profile.openFlightStart) then
                self.buttonGo:OnClickScript()
            else
                self:Hide()
            end
        end
        timer.windowElapsed = 0
    end)

    local goButton = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate")
    goButton:SetPoint("TOP", 2, -120)
    goButton:SetText("Start")
    goButton:SetWidth(MENU_WIDTH - 20)
    goButton:SetHeight(28)
    goButton.OnClickScript = function()
        local flightMenu = Bejeweled.flightOptionWindow
        if flightMenu.timer.learning then
            ns.startNewGame(MODE_FLIGHT, flightMenu.timer.timeElapsed)
            flightMenu.learning = true
        else
            ns.startNewGame(MODE_FLIGHT, flightMenu.timer.timeRemaining)
        end
        flightMenu:Hide()
        Bejeweled.timedWindow:Hide()
        Bejeweled.gameModeWindow:Hide()
        Bejeweled.menuWindow:Hide()
        Bejeweled.featsOfSkillScreen:Hide()
        Bejeweled.window:Show()
    end
    goButton:SetScript("OnClick", goButton.OnClickScript)
    menu.buttonGo = goButton

    local timer = CreateFrame("Frame", nil, UIParent)
    timer:SetPoint("TOP")
    timer:SetWidth(1)
    timer:SetHeight(1)
    timer:Hide()
    timer.timeRemaining = 0
    timer.flightTime = 0
    timer:SetScript("OnUpdate", ns.flightTimerOnUpdate)
    menu.timer = timer

    Bejeweled.flightOptionWindow = menu
end

ns.RegisterBuilder("FlightMenu", createFlightOptionMenu)

ns.RegisterEnabler("Flight", function()
    hooksecurefunc("TakeTaxiNode", onTakeTaxiNode)
    -- Legacy taxi map (still used in a few zones) and the modern flight map.
    if TaxiNodeOnButtonEnter then
        hooksecurefunc("TaxiNodeOnButtonEnter", onTaxiNodeButtonEnter)
    end
    -- Pins copy the mixin's OnMouseEnter when created, which happens only after this addon loads.
    EventUtil.ContinueOnAddOnLoaded("Blizzard_FlightMap", function()
        hooksecurefunc(FlightMap_FlightPointPinMixin, "OnMouseEnter", onFlightPointPinEnter)
    end)
end)
