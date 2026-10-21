local ADDON_NAME, ns = ...

local Bejeweled = LibStub("AceAddon-3.0"):NewAddon(
    ADDON_NAME,
    "AceEvent-3.0",
    "AceTimer-3.0",
    "AceConsole-3.0",
    "AceComm-3.0",
    "AceSerializer-3.0"
)
ns.addon = Bejeweled

Bejeweled.version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "dev"
Bejeweled.splashDisplayTime = 2

-- Files register setup steps: builders create frames, enablers register events and run login
-- logic. Both run at login (OnEnable), builders first, each in TOC load order. Building waits
-- for login so texture pack addons, which load after this one, have registered.
local builders, enablers = {}, {}

function ns.RegisterBuilder(name, func)
    table.insert(builders, { name = name, func = func })
end

function ns.RegisterEnabler(name, func)
    table.insert(enablers, { name = name, func = func })
end

-- Each step runs isolated so one failing system doesn't take the rest of the addon down.
local function runSteps(steps)
    for _, step in ipairs(steps) do
        xpcall(step.func, geterrorhandler())
    end
    wipe(steps)
end

function Bejeweled:OnInitialize()
    ns.InitDatabase()
end

function Bejeweled:OnEnable()
    ns.Textures.Activate(ns.db.profile.texturePack)
    runSteps(builders)
    runSteps(enablers)
end
