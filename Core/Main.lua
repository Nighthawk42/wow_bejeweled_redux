local _, ns = ...
local Bejeweled = ns.addon
local C = ns.C

-- Login glue: achievements and minimap setup, guild roster request, the one-time legal
-- notice (then the splash), and the "paused by combat" statistic.

-- PopCap notice shown on the very first login; OK starts the splash.
function Bejeweled:ShowLegal()
    local window = Bejeweled.window
    window:SetSize(C.WINDOW_WIDTH, C.WINDOW_HEIGHT)
    window:ClearAllPoints()
    window:SetPoint("CENTER")
    window:SetAlpha(1)
    window.splash.firstGame = true

    local legalPopup = CreateFrame("Frame", nil, window, "BackdropTemplate")
    legalPopup:SetSize(C.MENU_WIDTH * 2, C.MENU_HEIGHT + 32)
    legalPopup:SetToplevel(true)
    legalPopup:SetFrameStrata("HIGH")
    legalPopup:SetPoint("CENTER")
    legalPopup:EnableMouse(true)
    local backdrop = ns.makeBackdrop()
    backdrop.edgeFile = "Interface\\Glues\\Common\\TextPanel-Border"
    backdrop.bgFile = ns.Textures.Path("windowBackground")
    backdrop.edgeSize = 32
    backdrop.tileSize = 128
    backdrop.insets.top = 3
    legalPopup:SetBackdrop(backdrop)
    legalPopup:SetBackdropColor(0.6, 0.6, 0.6, 1)
    legalPopup:SetBackdropBorderColor(1, 0.8, 0.45)

    local legalText = legalPopup:CreateFontString(nil, "OVERLAY")
    legalText:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    legalText:SetTextColor(1, 1, 1)
    legalText:SetPoint("TOP", 0, -38)
    legalText:SetWidth(C.MENU_WIDTH * 1.8)
    legalText:SetText(
        "Bejeweled\n\n\n"
            .. "(c)2000, 2008 PopCap Games, Inc.  All rights reserved.  This application is "
            .. "being made available free of charge for your personal, non-commercial entertainment "
            .. 'use, and is provided "as is", without any warranties.  PopCap Games, Inc. will have '
            .. "no liability to you or anyone else if you choose to use it.  See readme.txt for details."
    )

    local okayButton = CreateFrame("Button", nil, legalPopup, "UIPanelButtonTemplate")
    okayButton:SetPoint("BOTTOM", 0, 16)
    okayButton:SetText(OKAY)
    okayButton:SetScript("OnClick", function()
        legalPopup:Hide()
        ns.db.global.legalDisplayed = true
        window.splash.elapsed = 0
    end)
    legalPopup.okayButton = okayButton
    Bejeweled.legalPopup = legalPopup
end

ns.RegisterEnabler("Main", function()
    if IsInGuild() then
        C_GuildInfo.GuildRoster()
    end
    ns.Achievements.Load()
    ns.Broker.Refresh()

    if not ns.db.global.legalDisplayed then
        Bejeweled.window:Show()
        Bejeweled:ShowLegal()
    else
        Bejeweled.window.splash.elapsed = 0
    end

    Bejeweled:RegisterEvent("PLAYER_REGEN_DISABLED", function()
        if Bejeweled.paused ~= true and ns.game.gameMode then
            local stats = ns.db.char.stats
            stats.combatPause = stats.combatPause + 1
        end
    end)
end)
