local _, ns = ...
local Bejeweled = ns.addon
local C = ns.C

-- Launcher: LibDataBroker object shown as a minimap icon (LibDBIcon) and in the addon
-- compartment. Left-click toggles the game window, right-click opens the options screen.

local ICON_NAME = "BejeweledRedux"
local LibDBIcon = LibStub("LibDBIcon-1.0")

local Broker = {}
ns.Broker = Broker

-- Shows the window faded and paused unless the cursor is already over it (it un-fades on hover).
function Broker.ToggleWindow()
    local window = Bejeweled.window
    if window:IsVisible() then
        if not Bejeweled.popup:IsVisible() then
            window:Hide()
        end
        return
    end
    window:SetAlpha(ns.db.profile.mouseoffAlpha)
    if not window:IsMouseOver() then
        window.mouseOverScreen:Show()
        Bejeweled.sound.mouseOver = nil
        Bejeweled.sound:Hide()
        if Bejeweled.paused ~= true then
            Bejeweled.mousePaused = true
            ns.setPaused(true)
        end
    end
    window:Show()
end

local function onClick(_, button)
    if button == "RightButton" then
        ns.OpenOptions()
    else
        Broker.ToggleWindow()
    end
end

local function fillTooltip(tooltip)
    local key = ns.db.profile.keybinding
    tooltip:SetText("|cFFFFFFFFBejeweled|r" .. (key and key ~= "" and (" (" .. key .. ")") or ""))
    tooltip:AddLine("Left-click to show/hide game.")
    tooltip:AddLine("Right-click for options.")
end

function Broker.Refresh()
    LibDBIcon:Refresh(ICON_NAME, ns.db.profile.minimap)
end

ns.RegisterBuilder("Broker", function()
    local dataObject = LibStub("LibDataBroker-1.1"):NewDataObject(ICON_NAME, {
        type = "launcher",
        text = "Bejeweled Redux",
        icon = ns.Textures.Path("icon"),
        OnClick = onClick,
        OnTooltipShow = fillTooltip,
    })
    LibDBIcon:Register(ICON_NAME, dataObject, ns.db.profile.minimap)
end)

-- Addon compartment entry (declared in Bejeweled.toc).
function BejeweledRedux_OnAddonCompartmentClick(_, buttonName)
    onClick(nil, buttonName)
end

function BejeweledRedux_OnAddonCompartmentEnter(_, menuButtonFrame)
    GameTooltip:SetOwner(menuButtonFrame, "ANCHOR_LEFT")
    fillTooltip(GameTooltip)
    GameTooltip:Show()
end

function BejeweledRedux_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end
