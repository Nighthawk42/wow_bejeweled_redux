local _, ns = ...
local Bejeweled = ns.addon
local C = ns.C
local BOARD_WIDTH, BOARD_HEIGHT = C.BOARD_WIDTH, C.BOARD_HEIGHT

-- About screen: three tabs (how to play, why PopCap made the addon, credits).

local CONTENT_WIDTH = BOARD_WIDTH + 6 - 24

local function createTab(aboutScreen, id, region, ...)
    local tab = CreateFrame("Frame", nil, aboutScreen)
    tab:SetPoint(...)
    tab:SetWidth(133)
    tab:SetHeight(34)
    tab.texture = tab:CreateTexture(nil, "ARTWORK")
    tab.texture:SetPoint("TOPLEFT")
    tab.texture:SetWidth(133)
    tab.texture:SetHeight(34)
    tab.texture:SetTexture(ns.Textures.Path("tabs"))
    tab.texture:SetTexCoord(ns.Textures.Coords("tabs", region))
    if id > 1 then
        tab.texture:SetVertexColor(0.5, 0.5, 0.5)
        tab:SetFrameLevel(Bejeweled.window:GetFrameLevel() + 24)
    end
    tab:EnableMouse(true)
    tab:SetID(id)
    tab:SetScript("OnMouseDown", function(self)
        ns.onTabClick(self)
    end)
    aboutScreen["tab" .. id] = tab
end

local function createTabContent(aboutScreen, height)
    local content = CreateFrame("Frame", nil, aboutScreen)
    content:SetPoint("TOP", 0, -10)
    content:SetWidth(CONTENT_WIDTH)
    content:SetHeight(height)
    return content
end

local function createPanel(parent, backdrop)
    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetBackdrop(backdrop)
    panel:SetBackdropColor(0.2, 0.2, 0.2, 1)
    panel:SetBackdropBorderColor(1, 1, 1)
    return panel
end

local function createArt(panel, artName, width, height)
    local art = Bejeweled.const.largeText[artName]
    local texture = panel:CreateTexture(nil, "ARTWORK")
    ns.Textures.Apply(texture, "artPieces", artName)
    texture:SetSize(width or art[1], height or art[2])
    return texture
end

local function createTutorialTab(aboutScreen, backdrop)
    local content = createTabContent(aboutScreen, BOARD_HEIGHT + 6 - 68)
    aboutScreen.tab1Content = content
    local panels = {
        { "Tutorial_1", "|cFFFF9922Swap adjacent gems to make sets of 3!", 160 },
        { "Tutorial_2", "|cFFFF99224 gems will create a |cFF0070DD[Power Gem]|r!", 140 },
        { "Tutorial_3", "|cFFFF99225 gems will create a |cFFA335EE[Hyper Cube]|r!", 140 },
    }
    for index, info in ipairs(panels) do
        local panel = createPanel(content, backdrop)
        panel:SetPoint("TOPLEFT", 5, -5 - (index - 1) * 118)
        panel:SetWidth(376)
        panel:SetHeight(118)
        local texture = createArt(panel, info[1])
        texture:SetPoint("CENTER", -85, 0)
        local caption = Bejeweled:CreateCaption(0, 0, info[2], panel, 14, 1, 0.85, 0.1)
        caption:ClearAllPoints()
        caption:SetPoint("CENTER", 85, 0)
        caption:SetWidth(info[3])
    end
end

local function createWhyTab(aboutScreen, backdrop)
    local content = createTabContent(aboutScreen, BOARD_HEIGHT + 6 - 86)
    content:Hide()
    aboutScreen.tab2Content = content
    local panel = createPanel(content, backdrop)
    panel:SetPoint("TOPLEFT", 10, -10)
    panel:SetPoint("BOTTOMRIGHT", -10, -20)

    local art = Bejeweled.const.largeText["Popcap"]
    local logo = createArt(panel, "Popcap", art[1] - 20, art[2] - 20)
    logo:SetPoint("TOP", 0, -10)

    local text = Bejeweled:CreateCaption(0, 0, "", panel, 14, 1, 0.85, 0.1)
    text:ClearAllPoints()
    text:SetPoint("TOPLEFT", 12, -92)
    text:SetWidth(336)
    text:SetJustifyH("LEFT")
    text:SetText(
        "Why'd we do it? Many PopCap employees are also hardcore "
            .. "WoW players, who alt-tab during long flights or queues "
            .. "to kill time with Bejeweled.\n\n"
            .. "So when we learned we could actually implement Bejeweled "
            .. "through an Add-On, we were intrigued. Soon the PopCap 'guild' "
            .. "was figuring out ways to make the mod even cooler and more "
            .. "comprehensive. And lots of work later...\n\n"
            .. "Now, we hope other WoW players will enjoy our 'game within a "
            .. "game.' Happy Bejeweling!"
    )

    text = panel:CreateFontString(nil, "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    text:SetTextColor(1, 1, 1)
    text:SetPoint("BOTTOM", 0, 12)
    text:SetText("Latest Version at:\nhttps://github.com/Nighthawk42/wow_bejeweled_redux")

    text = panel:CreateFontString(nil, "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    text:SetTextColor(1, 1, 1)
    text:SetPoint("TOPRIGHT", -12, -12)
    text:SetText("Version " .. Bejeweled.version)
end

local function createCreditsTab(aboutScreen, backdrop)
    local content = createTabContent(aboutScreen, BOARD_HEIGHT + 6 - 68)
    content:Hide()
    aboutScreen.tab3Content = content
    local panel = createPanel(content, backdrop)
    panel:SetPoint("TOPLEFT", 10, -10)
    panel:SetPoint("BOTTOMRIGHT", -10, -10)

    local text = Bejeweled:CreateCaption(0, 0, "Bejeweled Redux for WoW", panel, 16, 1, 0.85, 0.1)
    text:ClearAllPoints()
    text:SetPoint("TOPLEFT", 12, -12)
    text:SetWidth(336)
    text:SetJustifyH("CENTER")

    text = Bejeweled:CreateCaption(0, 0, "", panel, 14, 1, 0.85, 0.1)
    text:ClearAllPoints()
    text:SetPoint("TOPLEFT", 12, -42)
    text:SetWidth(336)
    text:SetJustifyH("CENTER")
    text:SetText(
        "Programmer: |cFFFFFFFFMichael Fromwiller|r\n"
            .. "Artist: |cFFFFFFFFTysen Henderson|r\n"
            .. "Producer: |cFFFFFFFFT. Carl Kwoh|r\n"
            .. "PopCap QA: |cFFFFFFFFShawn Conard, Ryan Newitt,\nJonathan Green|r\n\n"
            .. "Maintained by:\n|cFFFFFFFFKadecgos, Nighthawk42, and Contributors|r\n\n"
            .. "Original Bejeweled:\n|cFFFFFFFFJason Kapalka, Brian Fiete, John Vechey|r\n\n"
    )

    text = Bejeweled:CreateCaption(0, 0, "", panel, 13, 1, 0.85, 0.1)
    text:ClearAllPoints()
    text:SetPoint("TOPLEFT", 17, -215)
    text:SetWidth(326)
    text:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    text:SetJustifyH("LEFT")
    text:SetText(
        "Special Thanks:\n"
            .. '|cFFFFFFFFMorphieus "Lothaer" (Spinebreaker-A), Eleya (Eredar-A), Anthony Coleman, Ben Lyon, and Jeff Weinstein.|r\n\n'
            .. "Beta Testers:\n"
            .. "|cFFFFFFFFNaiad (Ysera-H), Nie (Ysera-H), BraveOne (Aerie Peak-A), Brutall (Ysera-H), AvaCam (Gurubashi-H), Kepec (Kael'thas-A), Eldurin (Dalaran-A), Fnear (Cenarius-A), Jonsnow (Kael'thas EU-A), Ed|r"
    )
end

ns.RegisterBuilder("AboutScreen", function()
    local aboutScreen = CreateFrame("Frame", nil, Bejeweled.gameBoard, "BackdropTemplate")
    aboutScreen:SetPoint("TOP", 0, -3 - 22)
    aboutScreen:SetWidth(BOARD_WIDTH + 6)
    aboutScreen:SetHeight(BOARD_HEIGHT + 6 - 22)
    aboutScreen:EnableMouse(true)
    local backdrop = ns.makeBackdrop()
    backdrop.bgFile = ns.Textures.Path("windowBackground")
    backdrop.tileSize = 128
    backdrop.edgeFile = "Interface\\Glues\\Common\\TextPanel-Border"
    backdrop.edgeSize = 32
    aboutScreen:SetBackdrop(backdrop)
    aboutScreen:SetBackdropColor(0.43, 0.43, 0.43, 1)
    aboutScreen:SetBackdropBorderColor(1, 0.8, 0.45)
    aboutScreen:SetFrameLevel(Bejeweled.window:GetFrameLevel() + 25)
    aboutScreen:Hide()
    aboutScreen:SetScript("OnShow", function(self)
        ns.setPaused(true)
        self.tab1:Show()
        self.tab2:Show()
        self.tab3:Show()
        Bejeweled.foreground:SetAlpha(0)
        Bejeweled.summaryScreen:SetAlpha(0)
        Bejeweled.animator.hintObj:SetAlpha(0)
    end)
    aboutScreen:SetScript("OnHide", function()
        Bejeweled.foreground:SetAlpha(1)
        Bejeweled.summaryScreen:SetAlpha(1)
        Bejeweled.animator.hintObj:SetAlpha(1)
    end)
    Bejeweled.aboutScreen = aboutScreen

    createTab(aboutScreen, 1, "howToPlay", "BOTTOMLEFT", aboutScreen, "TOPLEFT", 5, -14)
    createTab(
        aboutScreen,
        2,
        "whyPopCap",
        "BOTTOMLEFT",
        aboutScreen,
        "TOPLEFT",
        139,
        -14
    )
    createTab(aboutScreen, 3, "credits", "BOTTOMRIGHT", aboutScreen, "TOPRIGHT", -2, -14)

    createTutorialTab(aboutScreen, backdrop)
    createWhyTab(aboutScreen, backdrop)
    createCreditsTab(aboutScreen, backdrop)
end)
