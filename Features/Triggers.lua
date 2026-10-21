local _, ns = ...
local Bejeweled = ns.addon

-- Optional automatic open/close of the game window (all off by default): open at login or on death,
-- close on a ready check or when entering combat. Flight start/end triggers live in Features/Flight.lua.

local events = {}
LibStub("AceEvent-3.0"):Embed(events)

local function hideUnlessPopup()
    if not Bejeweled.popup:IsVisible() then
        Bejeweled.window:Hide()
    end
end

function events:PLAYER_ENTERING_WORLD()
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    if ns.db.profile.openLogin then
        Bejeweled.window:Show()
    end
end

function events:PLAYER_DEAD()
    if ns.db.profile.openOnDeath then
        Bejeweled.window:Show()
    end
end

function events:READY_CHECK()
    if ns.db.profile.closeReadyCheck then
        hideUnlessPopup()
    end
end

function events:PLAYER_REGEN_DISABLED()
    if ns.db.profile.closeCombat then
        hideUnlessPopup()
    end
end

ns.RegisterEnabler("Triggers", function()
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_DEAD")
    events:RegisterEvent("READY_CHECK")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
end)
