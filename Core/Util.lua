local _, ns = ...
local Bejeweled = ns.addon

-- Small shared helpers: the standard backdrop table and number/time formatting.

function ns.makeBackdrop()
    return {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        tileSize = 16,
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        edgeSize = 16,
        insets = { top = 5, right = 5, left = 5, bottom = 5 },
    }
end

function Bejeweled:NumberWithCommas(number)
    local formatted = string.gsub(number, "(%d)(%d%d%d)$", "%1,%2")
    local count
    repeat
        formatted, count = string.gsub(formatted, "(%d)(%d%d%d),", "%1,%2,")
    until count == 0
    return formatted
end

-- Returns minutes, seconds (seconds rounded up).
function Bejeweled:SecondsConvert(seconds)
    local minutes = math.floor(seconds / 60)
    return minutes, math.ceil(seconds - minutes * 60)
end

-- Formats a duration as "N d N hr N min N s", omitting empty units.
function Bejeweled:TotalTime(seconds)
    seconds = math.floor(seconds)
    local parts = {}
    local units = { { 86400, " d" }, { 3600, " hr" }, { 60, " min" } }
    for _, unit in ipairs(units) do
        if seconds >= unit[1] then
            table.insert(parts, math.floor(seconds / unit[1]) .. unit[2])
            seconds = seconds % unit[1]
        end
    end
    if seconds > 0 or #parts == 0 then
        table.insert(parts, seconds .. " s")
    end
    return table.concat(parts, " ")
end

function Bejeweled:Print(msg, r, g, b)
    DEFAULT_CHAT_FRAME:AddMessage(msg, r, g, b)
end
