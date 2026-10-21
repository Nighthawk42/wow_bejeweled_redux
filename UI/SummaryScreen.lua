local _, ns = ...
local Bejeweled = ns.addon
local C = ns.C
local BOARD_WIDTH, BOARD_HEIGHT = C.BOARD_WIDTH, C.BOARD_HEIGHT

-- Game-over summary: final score / PPS, time, level, cascade and combo, plus the
-- Publish / See High Scores / Brag! buttons and the brag channel picker.

local PUBLISH_CHANNELS = { GUILD = true, PARTY = true, RAID = true }

local function trySendChat(message, chatType, target)
    if C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then
        return false
    end
    return (pcall(C_ChatInfo.SendChatMessage, message, chatType, nil, target))
end

local function checkAchievement(skillId)
    if not ns.db.char.skill["gainAchieve" .. skillId] then
        Bejeweled.skillBar:CheckSkill(Bejeweled.const.SKILLTYPE_ACHIEVEMENT, skillId)
    end
end

local function showHighScores()
    Bejeweled.menuWindow.buttonSkills:GetScript("OnClick")(Bejeweled.menuWindow.buttonSkills)
    ns.onTabClick(Bejeweled.featsOfSkillScreen.tab3)
end

function ns.summaryFillData(screen)
    local game = ns.game
    local const = Bejeweled.const
    local playerName = UnitName("player")
    local elapsed = Bejeweled.levelBar.timer.timeElapsed
    local beatOther
    if game.gameMode == C.MODE_CLASSIC then
        local stats = ns.db.char.stats.classic
        local finalScore = game.score
        screen.scoreCaption:SetText("Final Score")
        screen.scoreValue:SetText(Bejeweled:NumberWithCommas(finalScore))
        screen.bragString = "[Bejeweled Redux]: "
            .. playerName
            .. " just scored "
            .. screen.scoreValue:GetText()
            .. " points in Classic mode! Get Bejeweled Redux to beat their score!"
        if finalScore > stats.score then
            stats.score = finalScore
        end
        beatOther = ns.HighScores.SubmitScore("classic", finalScore)
        if beatOther then
            checkAchievement(const.SKILL_ACHIEVE1A)
        end
    else
        local stats = ns.db.char.stats.timed
        local pps = game.score / elapsed
        screen.scoreCaption:SetText("Points per Second")
        screen.scoreValue:SetFormattedText("%.2f", pps)
        screen.bragString = "[Bejeweled Redux]: "
            .. playerName
            .. " just scored "
            .. screen.scoreValue:GetText()
            .. " points per second in a Timed mode! Get Bejeweled Redux to beat their score!"
        if pps > stats.score then
            stats.score = pps
        end
        if pps >= 250 then
            Bejeweled.skillBar:CheckSkill(const.SKILLTYPE_TIMED, const.SKILL_PPS250)
        end
        if pps >= 300 then
            Bejeweled.skillBar:CheckSkill(const.SKILLTYPE_TIMED, const.SKILL_PPS300)
        end
        if pps >= 350 then
            Bejeweled.skillBar:CheckSkill(const.SKILLTYPE_TIMED, const.SKILL_PPS350)
        end
        beatOther = ns.HighScores.SubmitScore("timed", pps)
        if beatOther then
            checkAchievement(const.SKILL_ACHIEVE3B)
        end
    end
    Bejeweled.skillBar:CheckCompetitors()
    screen.publishButton.hasResult = true
    screen.publishButton:Enable()
    screen.publishButton:Show()
    screen.seeScoresButton:Enable()
    screen.bragButton:Enable()
    screen.bragButton:Show()
    screen.timeValue:SetText(Bejeweled:TotalTime(math.floor(elapsed)))
    screen.levelValue:SetText(game.level)
    screen.cascadeValue:SetText(game.largestCascade)
    screen.comboValue:SetText(game.largestCombo)
    local levelBar = Bejeweled.levelBar
    levelBar.bar:SetVertexColor(1, 0, 0)
    levelBar.bar:SetWidth(levelBar:GetWidth() - 4)
    levelBar.text:SetText("")
    Bejeweled.levelBarButton:SetID(2)
    Bejeweled.levelBarButton:Show()
    Bejeweled.levelBarButton.text:SetText("New game")
    game.gameMode = nil
    Bejeweled.gameStatusText:Hide()
    if not ns.db.global.firstGame then
        ns.db.global.firstGame = true
        Bejeweled.popup.text:SetText(Bejeweled.popup.text.tip3)
        Bejeweled.popup:Hide()
        Bejeweled.popup:Show()
    end
end

-- Custom chat channels the player has joined (server channels like General/Trade are skipped).
local function getCustomChannels()
    local names = {}
    local list = { GetChannelList() }
    for i = 1, #list, 3 do
        local name = list[i + 1]
        local info = name and C_ChatInfo.GetChannelInfoFromIdentifier(name)
        if info and info.channelType ~= Enum.PermanentChatChannelType.Zone then
            table.insert(names, name)
        end
    end
    return names
end

local function createCaptionAt(text, parent, size, r, g, b, y)
    local caption = Bejeweled:CreateCaption(0, 0, text, parent, size, r, g, b)
    caption:ClearAllPoints()
    caption:SetPoint("TOP", 0, y)
    return caption
end

local function createButton(parent, text, width, ...)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetPoint(...)
    button:SetText(text)
    button:SetWidth(width)
    button:SetHeight(28)
    return button
end

local function createBragScreen(summary, backdrop)
    local bragScreen = CreateFrame("Frame", nil, summary, "BackdropTemplate")
    bragScreen:SetPoint("CENTER")
    bragScreen:SetWidth(340)
    bragScreen:SetHeight(200)
    bragScreen:EnableMouse(true)
    bragScreen:SetFrameLevel(bragScreen:GetFrameLevel() + 3)
    bragScreen:SetBackdrop(backdrop)
    bragScreen:SetBackdropColor(0.7, 0.7, 0.7, 1)
    bragScreen:SetBackdropBorderColor(1, 0.8, 0.45)
    bragScreen:Hide()
    summary.bragScreen = bragScreen

    local text = Bejeweled:CreateCaption(0, 0, "What channel would you like to brag to?", bragScreen, 17, 1, 0.82, 0)
    text:ClearAllPoints()
    text:SetPoint("TOP", 0, -36)
    text:SetWidth(290)

    local dropdown = CreateFrame("DropdownButton", nil, bragScreen, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("TOP", 0, -88)
    dropdown:SetWidth(240)
    local function isSelected(value)
        return ns.db.profile.defaultPublish == value
    end
    local function setSelected(value)
        ns.db.profile.defaultPublish = value
    end
    dropdown:SetupMenu(function(_, root)
        local const = Bejeweled.const
        for i = 1, #const.channels do
            root:CreateRadio(const.channelNames[i], isSelected, setSelected, const.channels[i])
        end
        for _, name in ipairs(getCustomChannels()) do
            root:CreateRadio(name, isSelected, setSelected, name)
        end
    end)
    bragScreen:SetScript("OnShow", function()
        -- Fall back to guild if the saved channel was left since the last brag.
        local current = ns.db.profile.defaultPublish
        if not PUBLISH_CHANNELS[current] and GetChannelName(current) == 0 then
            ns.db.profile.defaultPublish = Bejeweled.const.channels[1]
        end
        dropdown:GenerateMenu()
    end)

    local function restoreSummaryButtons()
        summary.publishButton:Enable()
        summary.seeScoresButton:Enable()
        summary.bragButton:Enable()
    end

    local button = createButton(bragScreen, "Brag!", 120, "BOTTOMLEFT", 16, 16)
    button:SetScript("OnClick", function()
        local channel = ns.db.profile.defaultPublish
        local channelId = GetChannelName(channel)
        local sent
        if channelId > 0 then
            sent = trySendChat(summary.bragString, "CHANNEL", channelId)
        else
            sent = trySendChat(summary.bragString, channel)
        end
        if not sent then
            Bejeweled:Print("Chat is unavailable right now; brag not sent.")
            return
        end
        summary.bragString = nil
        bragScreen:Hide()
        summary.bragButton:Hide()
        restoreSummaryButtons()
    end)

    button = createButton(bragScreen, "Back", 120, "BOTTOMRIGHT", -16, 16)
    button:SetScript("OnClick", function()
        bragScreen:Hide()
        restoreSummaryButtons()
    end)
end

ns.RegisterBuilder("SummaryScreen", function()
    local mainWindow = Bejeweled.window
    local summary = CreateFrame("Frame", nil, Bejeweled.gameBoard:GetParent(), "BackdropTemplate")
    summary:SetPoint("TOP", 0, -3)
    summary:SetWidth(BOARD_WIDTH + 6)
    summary:SetHeight(BOARD_HEIGHT + 6)
    local backdrop = ns.makeBackdrop()
    backdrop.bgFile = ns.Textures.Path("windowBackground")
    backdrop.tileSize = 128
    backdrop.edgeFile = "Interface\\Glues\\Common\\TextPanel-Border"
    backdrop.edgeSize = 32
    summary:SetBackdrop(backdrop)
    summary:SetBackdropColor(0.7, 0.7, 0.7, 1)
    summary:SetBackdropBorderColor(1, 0.8, 0.45)
    summary:SetFrameLevel(mainWindow:GetFrameLevel() + 20)
    summary:Hide()
    summary.FillData = function(self)
        ns.summaryFillData(self)
    end
    Bejeweled.summaryScreen = summary

    local title = Bejeweled:CreateCaption(0, 0, "Game Over!", summary, 20, 1, 0.85, 0.1, true)
    title:ClearAllPoints()
    title:SetPoint("TOP", 0, -10)
    title:Show()

    local innerPanel = CreateFrame("Frame", nil, summary, "BackdropTemplate")
    innerPanel:SetPoint("TOP", 0, -36)
    innerPanel:SetWidth(BOARD_WIDTH + 6 - 24)
    innerPanel:SetHeight(BOARD_HEIGHT + 6 - 48)
    innerPanel:SetBackdrop(backdrop)
    innerPanel:SetBackdropColor(0.2, 0.2, 0.2, 1)
    innerPanel:SetBackdropBorderColor(1, 1, 1)
    innerPanel:SetFrameLevel(mainWindow:GetFrameLevel() + 21)
    innerPanel:Show()

    -- Caption/value pairs: { field prefix, caption, caption color, sample value }
    local rows = {
        { "score", "Final Score", { 1, 1, 0 }, "0" },
        { "time", "Time", { 1, 1, 0 }, "1 min 3 sec" },
        { "level", "Level", { 1, 0.7, 0 }, "15" },
        { "cascade", "Largest Cascade", { 1, 0.7, 0 }, "5" },
        { "combo", "Largest Combo", { 1, 0.7, 0 }, "12" },
    }
    local offset = 2
    for _, row in ipairs(rows) do
        local r, g, b = unpack(row[3])
        summary[row[1] .. "Caption"] = createCaptionAt(row[2], innerPanel, 14, r, g, b, -20 - offset)
        offset = offset + 20
        summary[row[1] .. "Value"] = createCaptionAt(row[4], innerPanel, 20, 1, 1, 1, -20 - offset)
        offset = offset + 42
    end

    local button = createButton(innerPanel, "Publish Scores", 120, "BOTTOMLEFT", 8, 10)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Manually (re-)send your score to guild chat and online friends.", 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    button:SetScript("OnClick", function(self)
        if self.hasResult then
            local channel = ns.db.profile.defaultPublish
            ns.HighScores.Publish(PUBLISH_CHANNELS[channel] and channel or "GUILD")
            showHighScores()
        end
        Bejeweled.popup:Hide()
    end)
    summary.publishButton = button

    button = createButton(innerPanel, "See High Scores", 128, "BOTTOM", 0, 10)
    button:SetScript("OnClick", function()
        showHighScores()
        Bejeweled.popup:Hide()
    end)
    summary.seeScoresButton = button

    button = createButton(innerPanel, "Brag!", 120, "BOTTOMRIGHT", -8, 10)
    button:SetScript("OnClick", function()
        summary.bragScreen:Show()
        summary.publishButton:Disable()
        summary.seeScoresButton:Disable()
        summary.bragButton:Disable()
    end)
    summary.bragButton = button

    createBragScreen(summary, backdrop)
end)
