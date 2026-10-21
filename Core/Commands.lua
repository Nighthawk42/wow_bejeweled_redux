local _, ns = ...
local Bejeweled = ns.addon

-- Slash commands: /bejeweled and /bej.

local HELP = {
    "|cFFFFFF00Bejeweled|r commands (/bej or /bejeweled):",
    "  (none) or toggle - show/hide the game window",
    "  show / hide - show or hide the game window",
    "  options - open the options screen",
    "  reset - erase this character's progress and the current profile's settings",
}

local function reset()
    ns.ResetCharacterData()
    -- Re-show so the open screens pick up the wiped data, as the original did.
    if Bejeweled.window:IsVisible() then
        Bejeweled.window:Hide()
        Bejeweled.window:Show()
    end
    Bejeweled:Print("|cFFFFFF00Bejeweled:|r character data and settings reset. Type /reload to fully refresh.")
end

local commands = {
    [""] = function()
        ns.Broker.ToggleWindow()
    end,
    toggle = function()
        ns.Broker.ToggleWindow()
    end,
    show = function()
        if not Bejeweled.window:IsShown() then
            ns.Broker.ToggleWindow()
        end
    end,
    hide = function()
        Bejeweled.window:Hide()
    end,
    options = function()
        ns.OpenOptions()
    end,
    reset = reset,
    help = function()
        for _, line in ipairs(HELP) do
            Bejeweled:Print(line)
        end
    end,
}
commands.config = commands.options

local function handler(input)
    local command = (strtrim(input or ""):match("^(%S*)") or ""):lower()
    local func = commands[command] or commands.help
    func()
end

ns.RegisterEnabler("Commands", function()
    Bejeweled:RegisterChatCommand("bejeweled", handler)
    Bejeweled:RegisterChatCommand("bej", handler)
end)
