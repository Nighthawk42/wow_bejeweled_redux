local _, ns = ...
local Bejeweled = ns.addon
local C = ns.C

-- Shared widget helpers.

function Bejeweled:CreateCaption(x, y, text, parent, fontSize, red, green, blue, gameFont, noOutline)
    local fontString = parent:CreateFontString(nil, "OVERLAY")
    if gameFont then
        fontString:SetFont(ns.Textures.Font(), fontSize or 10, "OUTLINE")
    else
        fontString:SetFont(STANDARD_TEXT_FONT, fontSize or 10, noOutline and "" or "OUTLINE")
    end
    fontString:SetTextColor(red or 1, green or 1, blue or 1)
    fontString:SetPoint("TOPLEFT", x, -y)
    fontString:SetText(text)
    fontString:Show()
    return fontString
end
