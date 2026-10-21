local _, ns = ...
local Bejeweled = ns.addon
local C = ns.C
local BOARD_WIDTH, BOARD_HEIGHT = C.BOARD_WIDTH, C.BOARD_HEIGHT

-- Settings: one AceConfig table shown in two places, the Blizzard Settings panel and the
-- in-window options screen (Bejeweled.optionsScreen), which renders the same table into
-- an AceGUI container over the board. Also applies the window alphas and the toggle keybinding.

local APP_NAME = "BejeweledRedux"
local AceGUI = LibStub("AceGUI-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

local toggleButton
local events = {}
LibStub("AceEvent-3.0"):Embed(events)

local function applyAlpha()
    local profile = ns.db.profile
    local fadeIn, fadeOut = Bejeweled.const.windowFadeIn, Bejeweled.const.windowFadeOut
    fadeIn.startAlpha = profile.mouseoffAlpha
    fadeIn.endAlpha = profile.gameAlpha
    fadeOut.startAlpha = profile.gameAlpha
    fadeOut.endAlpha = profile.mouseoffAlpha
end

-- Override bindings cannot change in combat; retry once combat ends.
local function applyKeybinding()
    if InCombatLockdown() then
        events:RegisterEvent("PLAYER_REGEN_ENABLED", function()
            events:UnregisterEvent("PLAYER_REGEN_ENABLED")
            applyKeybinding()
        end)
        return
    end
    ClearOverrideBindings(toggleButton)
    local key = ns.db.profile.keybinding
    if key and key ~= "" then
        SetOverrideBindingClick(toggleButton, false, key, toggleButton:GetName())
    end
end

local function onProfileChanged()
    applyAlpha()
    Bejeweled.window:SetAlpha(ns.db.profile.gameAlpha)
    applyKeybinding()
    ns.Broker.Refresh()
end

local function hideHint()
    local hintObj = Bejeweled.animator.hintObj
    hintObj.fxType = C.FX_DONE
    hintObj:SetAlpha(0)
    hintObj:Hide()
    hintObj.wasShown = nil
    hintObj.oldAlpha = 0
end

local function getSetting(info)
    return ns.db.profile[info[#info]]
end

local function setSetting(info, value)
    ns.db.profile[info[#info]] = value
end

local function toggle(name, order, width)
    return { type = "toggle", name = name, order = order, width = width or "full" }
end

local function trigger(name, desc, order)
    return { type = "toggle", name = name, desc = desc .. " Off by default.", order = order, width = "full" }
end

local function buildOptions()
    return {
        type = "group",
        name = "Bejeweled Redux",
        childGroups = "tab",
        get = getSetting,
        set = setSetting,
        args = {
            general = {
                type = "group",
                name = "General",
                order = 1,
                args = {
                    keybinding = {
                        type = "keybinding",
                        name = "Show/Hide Key",
                        desc = "Key that shows or hides the game window.",
                        order = 1,
                        width = "full",
                        get = function()
                            return ns.db.profile.keybinding or ""
                        end,
                        set = function(_, value)
                            ns.db.profile.keybinding = value ~= "" and value or nil
                            applyKeybinding()
                        end,
                    },
                    gameAlpha = {
                        type = "range",
                        name = "Game Transparency",
                        order = 2,
                        width = "full",
                        min = 0.2,
                        max = 1,
                        step = 0.005,
                        bigStep = 0.05,
                        isPercent = true,
                        set = function(_, value)
                            ns.db.profile.gameAlpha = value
                            applyAlpha()
                            Bejeweled.window:SetAlpha(value)
                        end,
                    },
                    mouseoffAlpha = {
                        type = "range",
                        name = "Mouse-off Transparency",
                        desc = "Window transparency while the cursor is away from it.",
                        order = 3,
                        width = "full",
                        min = 0,
                        max = 1,
                        step = 0.005,
                        bigStep = 0.05,
                        isPercent = true,
                        set = function(_, value)
                            ns.db.profile.mouseoffAlpha = value
                            applyAlpha()
                        end,
                    },
                    sounds = {
                        type = "select",
                        name = "Sounds",
                        order = 4,
                        values = { normal = "Normal", quiet = "Quiet", off = "Off" },
                        sorting = { "normal", "quiet", "off" },
                        get = function()
                            local profile = ns.db.profile
                            if not profile.enableSounds then
                                return "off"
                            end
                            return profile.quietSounds and "quiet" or "normal"
                        end,
                        set = function(_, value)
                            ns.db.profile.enableSounds = value ~= "off"
                            ns.db.profile.quietSounds = value == "quiet"
                        end,
                    },
                    showMinimap = {
                        type = "toggle",
                        name = "Show Minimap Icon",
                        order = 5,
                        width = "full",
                        get = function()
                            return not ns.db.profile.minimap.hide
                        end,
                        set = function(_, value)
                            ns.db.profile.minimap.hide = not value
                            ns.Broker.Refresh()
                        end,
                    },
                    lockWindow = toggle("Lock Window", 6),
                    disableHints = {
                        type = "toggle",
                        name = "Disable Auto-Hint Arrows",
                        order = 7,
                        width = "full",
                        set = function(_, value)
                            ns.db.profile.disableHints = value
                            local game = ns.game
                            if value then
                                hideHint()
                            elseif game.gameMode and not game.gameOver then
                                Bejeweled.animator:Add(Bejeweled.animator:CreateHint(ns.findHintGem()))
                            end
                        end,
                    },
                    texturePack = {
                        type = "select",
                        name = "Texture Pack",
                        desc = "Art used for gems, effects and windows. Packs are separate addons. Takes effect after /reload.",
                        order = 8,
                        values = function()
                            local values = {}
                            for _, name in ipairs(ns.Textures.GetPackNames()) do
                                values[name] = name
                            end
                            return values
                        end,
                        set = function(_, value)
                            ns.db.profile.texturePack = value
                            if value ~= ns.Textures.activePack then
                                Bejeweled:Print("Texture pack '" .. value .. "' will be used after /reload.")
                            end
                        end,
                    },
                },
            },
            scores = {
                type = "group",
                name = "Scores",
                order = 2,
                args = {
                    publishSkillGains = toggle("Display skill gains in Chat Interface", 1),
                    verboseSkills = {
                        type = "toggle",
                        name = "Show full skill-up text",
                        order = 2,
                        width = "full",
                        disabled = function()
                            return not ns.db.profile.publishSkillGains
                        end,
                    },
                    publishRankGains = toggle("Publish Bejeweling rank-ups to Guild Channel", 3),
                    publishScores = toggle("Publish Scores", 4),
                    defaultPublish = {
                        type = "select",
                        name = "Publish Channel",
                        desc = "Where your best scores are announced when you publish them.",
                        order = 5,
                        values = { GUILD = "Guild", PARTY = "Party", RAID = "Raid" },
                        sorting = { "GUILD", "PARTY", "RAID" },
                    },
                    hideDuplicates = toggle("One score per person on High Score lists", 6),
                },
            },
            flight = {
                type = "group",
                name = "Flight",
                order = 3,
                args = {
                    newGameFlight = toggle("New Game on Flight Start", 1),
                    showFlightTooltips = toggle("Show Flight Times on Flight Window Tooltips", 2),
                    openFlightStart = trigger("Open on Flight Start", "Open the game window when a flight starts.", 3),
                    closeFlightEnd = trigger("Close on Flight End", "Close the game window when a flight ends.", 4),
                },
            },
            triggers = {
                type = "group",
                name = "Triggers",
                order = 4,
                args = {
                    intro = {
                        type = "description",
                        name = "Open or close the game window automatically. All of these are off by default.",
                        order = 0,
                    },
                    openLogin = trigger("Open on Log-In", "Open the game window when you log in.", 1),
                    openOnDeath = trigger("Open on Death", "Open the game window when you die.", 2),
                    closeReadyCheck = trigger("Close on Ready Check", "Close the game window on a ready check.", 3),
                    closeCombat = trigger("Close on Enter Combat", "Close the game window when you enter combat.", 4),
                },
            },
            profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(ns.db),
        },
    }
end

-- The in-window screen renders the options into an AceGUI container while shown.
local function embedOptions(panel)
    local container = AceGUI:Create("SimpleGroup")
    container:SetLayout("Fill")
    container.noAutoHeight = true
    local frame = container.frame
    frame:SetParent(panel)
    frame:SetFrameStrata(panel:GetFrameStrata())
    frame:SetFrameLevel(panel:GetFrameLevel() + 1)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", 8, -8)
    frame:SetPoint("BOTTOMRIGHT", -8, 8)
    frame:Show()
    AceConfigDialog:Open(APP_NAME, container)
    return container
end

local function releaseOptions(container)
    container.frame:SetFrameStrata("FULLSCREEN_DIALOG") -- SimpleGroup's own strata, for the next user
    AceGUI:Release(container)
end

local function createOptionsScreen()
    local window = Bejeweled.window
    local screen = CreateFrame("Frame", nil, Bejeweled.gameBoard, "BackdropTemplate")
    screen:SetPoint("TOP", 0, -3)
    screen:SetSize(BOARD_WIDTH + 6, BOARD_HEIGHT + 6)
    screen:EnableMouse(true)
    local backdrop = ns.makeBackdrop()
    backdrop.bgFile = ns.Textures.Path("windowBackground")
    backdrop.tileSize = 128
    backdrop.edgeFile = "Interface\\Glues\\Common\\TextPanel-Border"
    backdrop.edgeSize = 32
    screen:SetBackdrop(backdrop)
    screen:SetBackdropColor(0.7, 0.7, 0.7, 1)
    screen:SetBackdropBorderColor(1, 0.8, 0.45)
    screen:SetFrameLevel(window:GetFrameLevel() + 25)
    screen:Hide()

    local title = Bejeweled:CreateCaption(0, 0, "Options", screen, 20, 1, 0.85, 0.1, true)
    title:ClearAllPoints()
    title:SetPoint("TOP", 0, -10)
    title:Show()

    local panel = CreateFrame("Frame", nil, screen, "BackdropTemplate")
    panel:SetPoint("TOP", 0, -36)
    panel:SetSize(BOARD_WIDTH + 6 - 24, BOARD_HEIGHT + 6 - 48)
    panel:SetBackdrop(backdrop)
    panel:SetBackdropColor(0.2, 0.2, 0.2, 1)
    panel:SetBackdropBorderColor(1, 1, 1)
    panel:SetFrameLevel(window:GetFrameLevel() + 26)

    -- The original targeted the global "BejeweledGame", which resolved to the foreground frame.
    local function setBoardAlpha(alpha)
        if Bejeweled.foreground then
            Bejeweled.foreground:SetAlpha(alpha)
        end
        Bejeweled.summaryScreen:SetAlpha(alpha)
        Bejeweled.animator.hintObj:SetAlpha(alpha)
    end

    screen:SetScript("OnShow", function(self)
        ns.setPaused(true)
        setBoardAlpha(0)
        self.container = embedOptions(panel)
    end)
    screen:SetScript("OnHide", function(self)
        setBoardAlpha(1)
        if self.container then
            releaseOptions(self.container)
            self.container = nil
        end
    end)
    Bejeweled.optionsScreen = screen
end

-- Same steps as the main menu's Options button.
function ns.OpenOptions()
    if not Bejeweled.window:IsShown() then
        Bejeweled.window:Show()
    end
    Bejeweled.menuWindow:Hide()
    Bejeweled.aboutScreen:Hide()
    Bejeweled.featsOfSkillScreen:Hide()
    Bejeweled.optionsScreen:Show()
    if Bejeweled.levelBarButton:GetID() == 0 then
        Bejeweled.levelBarButton:SetID(1)
    end
    Bejeweled.levelBarButton:Show()
end

ns.RegisterBuilder("Options", function()
    LibStub("AceConfig-3.0"):RegisterOptionsTable(APP_NAME, buildOptions())
    AceConfigDialog:AddToBlizOptions(APP_NAME, "Bejeweled Redux")

    applyAlpha()
    Bejeweled.window:SetAlpha(ns.db.profile.gameAlpha)

    toggleButton = CreateFrame("Button", "BejeweledReduxToggleButton", UIParent)
    toggleButton:Hide()
    toggleButton:RegisterForClicks("AnyUp")
    toggleButton:SetScript("OnClick", function()
        ns.Broker.ToggleWindow()
    end)

    ns.db.RegisterCallback(events, "OnProfileChanged", onProfileChanged)
    ns.db.RegisterCallback(events, "OnProfileCopied", onProfileChanged)
    ns.db.RegisterCallback(events, "OnProfileReset", onProfileChanged)

    createOptionsScreen()
end)

ns.RegisterEnabler("Options", applyKeybinding)
