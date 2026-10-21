local _, ns = ...
local Bejeweled = ns.addon
local C = ns.C
local BOARD_WIDTH, BOARD_HEIGHT = C.BOARD_WIDTH, C.BOARD_HEIGHT

-- Feats of Skill screen: four tabs (skill rank + feat list, personal statistics, friend/guild
-- high scores, achievements). Also owns Bejeweled.skillBar, whose CheckSkill awards skill points.

local POINTS_PER_RANK = 75
-- The original capped skill at 375 (rank 5) for players without Wrath of the Lich King;
-- every Retail account has it, so the full 450 / Grand Master applies.
local MAX_SKILL = 450
local MAX_RANK = 6
local COMPETITOR_GOAL = 10
local CONTENT_WIDTH = BOARD_WIDTH + 6 - 24
local FRIEND_COLOR = "|cFF00FFFF"
local GUILD_COLOR = "|cFF00FF00"
local POPCAP = "PopCap Games"

local featsScreen

local function printSkill(message)
    local color = ChatTypeInfo["SKILL"]
    Bejeweled:Print(message, color.r, color.g, color.b)
end

local function setRankTexCoord(texture, rank)
    if rank > 0 then
        texture:SetTexCoord(unpack(ns.Textures.Frames("rankIcons")[rank]))
    else
        texture:SetTexCoord(0, 0, 0, 0)
    end
end

local function refreshSkillBar()
    local skill = ns.db.char.skill
    local skillBar = Bejeweled.skillBar
    skillBar.text:SetFormattedText("%d / %d", skill.skillPoints, skill.rank * POINTS_PER_RANK)
    skillBar.bar:SetWidth(
        (skillBar:GetWidth() - 4) * ((skill.skillPoints - (skill.rank - 1) * POINTS_PER_RANK) / POINTS_PER_RANK) + 1
    )
    setRankTexCoord(skillBar.leftIcon, skill.rank)
    setRankTexCoord(skillBar.rightIcon, skill.rank + 1)
end

local function announceRank(rankName)
    if not (ns.db.profile.publishRankGains and IsInGuild()) then
        return
    end
    if C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then
        return
    end
    local article = rankName:find("^[AEIOU]") and "an" or "a"
    pcall(
        C_ChatInfo.SendChatMessage,
        "[Bejeweled Redux]: I have become " .. article .. " " .. rankName .. " in Bejeweling Skill!",
        "GUILD"
    )
end

local function allOtherAchievementsDone(skill, skillData, const)
    for i = 1, #skillData[const.SKILLTYPE_FUN] do
        if not skill["gainFun" .. i] and ns.Achievements.IsAvailable(i) then
            return false
        end
    end
    for i = 1, #skillData[const.SKILLTYPE_ACHIEVEMENT] do
        if i ~= const.SKILL_ACHIEVE6A and not skill["gainAchieve" .. i] then
            return false
        end
    end
    return true
end

-- Awards skill for a feat. Feat types 1-5 give +1 (less likely once the feat is past its
-- thresholds), fun feats +3, achievements +5. Returns 1 if anything was gained, else 0.
local function checkSkill(_, skillType, skillIndex, forced)
    local const = Bejeweled.const
    local skill = ns.db.char.skill
    local skillData = const.skillData
    local feat = skillData[skillType][skillIndex]
    local skillPoints = skill.skillPoints
    local atMaxSkill = skillPoints == MAX_SKILL
    local isSpecial = skillType >= const.SKILLTYPE_FUN
    if
        not (
            ((skillPoints >= feat[2] or forced) and skillPoints < MAX_SKILL)
            or (isSpecial and skillPoints >= feat[2])
        )
    then
        return 0
    end
    local tier = 0
    if not isSpecial then
        while tier < 3 and skillPoints >= feat[3 + tier] do
            tier = tier + 1
        end
    end
    if tier >= 3 and not forced then
        return 0
    end
    local gained = forced or tier == 0 or math.random(1, 100) <= 100 - tier * 33
    if not gained then
        return 0
    end

    local floatingText, completedMsg, skillGain
    if not isSpecial then
        skill.skillPoints = skill.skillPoints + 1
    elseif feat[2] <= skillPoints and feat[2] < MAX_SKILL - 1 then
        completedMsg = '[Bejeweled Redux] You just completed "' .. feat[1] .. '."'
        if skillType == const.SKILLTYPE_FUN then
            skillGain = 3
            skill["gainFun" .. skillIndex] = true
            if skillIndex == const.SKILL_FUNRANK6A then
                ns.db.global.gainFun14 = true
            end
        else
            skillGain = 5
            skill["gainAchieve" .. skillIndex] = true
        end
        skill.skillPoints = skill.skillPoints + skillGain
        floatingText = Bejeweled.animator:CreateFloatingText(50, 0, "+" .. skillGain .. " Skill", 3, true)
        if
            not skill["gainAchieve" .. const.SKILL_ACHIEVE6A]
            and allOtherAchievementsDone(skill, skillData, const)
        then
            Bejeweled.skillBar:CheckSkill(const.SKILLTYPE_ACHIEVEMENT, const.SKILL_ACHIEVE6A)
        end
    else
        gained = false
    end

    if floatingText then
        floatingText.fxType = C.FX_FLOAT_TEXT
        floatingText:Show()
        ns.animatorAdd(Bejeweled.animator, floatingText)
    end
    if forced then
        skill.skillPoints = skill.skillPoints + 4
    end
    if skill.skillPoints > MAX_SKILL then
        skill.skillPoints = MAX_SKILL
    end

    if gained and (skillGain or not atMaxSkill) then
        if ns.db.profile.publishSkillGains then
            if skillGain then
                printSkill(atMaxSkill and completedMsg or (completedMsg .. " +" .. skillGain .. " Skill!"))
            else
                if ns.db.profile.verboseSkills then
                    printSkill('[Bejeweled Redux] You just completed "' .. feat[1] .. '."')
                end
                printSkill("Your skill in Bejeweling has increased to " .. skill.skillPoints .. ".")
            end
        end
        if skill.skillPoints >= skill.rank * POINTS_PER_RANK and skill.rank < MAX_RANK then
            skill.rank = skill.rank + 1
            local rankName = const.skillDataRanks[skill.rank]
            if ns.db.profile.publishSkillGains then
                printSkill("Your Bejeweling skill is now of the " .. rankName .. " rank.")
            end
            announceRank(rankName)
        end
    end
    featsScreen.tab1Content:UpdateSkillScreen()
    featsScreen.tab4Content:UpdateSkillScreen()
    return gained and 1 or 0
end

-- "Compete with 10+ Friends/Guildies": counts other players in the local high-score lists.
local function checkCompetitors(skillBar)
    local const = Bejeweled.const
    local skill = ns.db.char.skill
    local checks = {
        { "friends", const.SKILL_ACHIEVE5B },
        { "guild", const.SKILL_ACHIEVE6B },
    }
    for _, check in ipairs(checks) do
        local skillId = check[2]
        if not skill["gainAchieve" .. skillId] and ns.HighScores.CountCompetitors(check[1]) >= COMPETITOR_GOAL then
            skillBar:CheckSkill(const.SKILLTYPE_ACHIEVEMENT, skillId)
        end
    end
end

local function showSkillTip(content)
    if not ns.db.global.firstSkillShow and content:IsVisible() then
        ns.db.global.firstSkillShow = true
        local popup = Bejeweled.popup
        popup.text:SetText(popup.text.tip4)
        popup:Hide()
        popup:SetFrameLevel(featsScreen.tab1Content:GetFrameLevel() + 5)
        popup:Show()
        popup.caption:SetText("Bejeweling Skill")
    end
end

function ns.onTabClick(tab)
    local parent = tab:GetParent()
    for tabIndex = 1, 4 do
        local otherTab = parent["tab" .. tabIndex]
        if otherTab then
            local content = parent["tab" .. tabIndex .. "Content"]
            content:Hide()
            if tab:GetID() == tabIndex then
                otherTab:SetFrameLevel(parent:GetFrameLevel() + 1)
                otherTab.texture:SetVertexColor(1, 1, 1)
                content:Show()
            else
                otherTab:SetFrameLevel(parent:GetFrameLevel() - 1)
                otherTab.texture:SetVertexColor(0.5, 0.5, 0.5)
            end
        end
    end
end

local function fillScoreRows(frame, prefix, list, formatValue)
    local playerName = UnitName("player")
    for i = 1, 10 do
        local entry = list[i]
        local rankIcon = frame[prefix .. "Rank" .. i]
        local nameText = frame[prefix .. "Name" .. i]
        local scoreText = frame[prefix .. "Score" .. i]
        if entry then
            local name = Ambiguate(entry.name, "none")
            local rank = tonumber(entry.rank) or 0
            if entry.name == POPCAP then
                name = "|cFFFFFFFF" .. name
                rank = 0
            elseif name ~= playerName then
                if ns.HighScores.IsFriend(entry.name) then
                    name = FRIEND_COLOR .. name
                elseif ns.HighScores.IsGuildmate(entry.name) then
                    name = GUILD_COLOR .. name
                end
            end
            setRankTexCoord(rankIcon, rank)
            nameText:SetText(name)
            scoreText:SetText((i == 1 and "|cFF00FF00" or "") .. formatValue(entry.value))
        else
            setRankTexCoord(rankIcon, 0)
            nameText:SetText("")
            scoreText:SetText("")
        end
    end
end

local function formatClassic(value)
    return Bejeweled:NumberWithCommas(value)
end

local function formatTimed(value)
    return string.format("%.2f", value)
end

function ns.populateScores(frame, listType)
    if IsInGuild() then
        C_GuildInfo.GuildRoster()
    end
    fillScoreRows(frame, "classic", ns.HighScores.GetList(listType, "classic"), formatClassic)
    fillScoreRows(frame, "timed", ns.HighScores.GetList(listType, "timed"), formatTimed)
    Bejeweled.skillBar:CheckCompetitors()
end

local function buildBackdrop(bgFile, tileSize, edgeFile, edgeSize, insetX)
    local backdrop = ns.makeBackdrop()
    backdrop.bgFile = bgFile
    backdrop.tileSize = tileSize
    backdrop.edgeFile = edgeFile
    backdrop.edgeSize = edgeSize
    if insetX then
        backdrop.insets.left = insetX
        backdrop.insets.right = insetX
    end
    return backdrop
end

local function createPanel(parent, backdrop, height, ...)
    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetPoint(...)
    panel:SetWidth(CONTENT_WIDTH)
    panel:SetHeight(height)
    panel:SetBackdrop(backdrop)
    panel:SetBackdropColor(0.2, 0.2, 0.2, 1)
    panel:SetBackdropBorderColor(1, 1, 1)
    panel:Show()
    return panel
end

local function createTabContent(height)
    local content = CreateFrame("Frame", nil, featsScreen)
    content:SetPoint("TOP", 0, -10)
    content:SetWidth(CONTENT_WIDTH)
    content:SetHeight(height or BOARD_HEIGHT + 6 - 68)
    content:Hide()
    return content
end

local function createScrollList(parent, backdrop)
    local listFrame = createPanel(parent, backdrop, 21 * 15, "TOP", 0, -52)
    local scrollFrame = CreateFrame("ScrollFrame", nil, listFrame, "ScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -9)
    scrollFrame:SetPoint("BOTTOMRIGHT", -32, 9)
    scrollFrame.ScrollBar:SetHideIfUnscrollable(true)
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(CONTENT_WIDTH)
    scrollChild:SetHeight(21 * 15 * 3)
    scrollFrame:SetScrollChild(scrollChild)
    return scrollChild
end

local TAB_LAYOUT = {
    { width = 88, region = "skills" },
    { width = 48, region = "stats" },
    { width = 93, region = "scores" },
    { width = 104, region = "achievements" },
}

local function createTabs()
    local window = Bejeweled.window
    for tabIndex, layout in ipairs(TAB_LAYOUT) do
        local tab = CreateFrame("Frame", nil, featsScreen)
        local previous = featsScreen["tab" .. (tabIndex - 1)]
        if previous then
            tab:SetPoint("TOPLEFT", previous, "TOPRIGHT")
        else
            tab:SetPoint("BOTTOMLEFT", featsScreen, "TOPLEFT", 4, -14)
        end
        tab:SetWidth(layout.width)
        tab:SetHeight(32)
        tab:SetScale(1.2)
        tab.texture = tab:CreateTexture(nil, "ARTWORK")
        if previous then
            tab.texture:SetPoint("TOPLEFT", previous.texture, "TOPRIGHT")
        else
            tab.texture:SetPoint("TOPLEFT")
        end
        tab.texture:SetWidth(layout.width)
        tab.texture:SetHeight(30)
        tab.texture:SetTexture(ns.Textures.Path("tabs"))
        tab.texture:SetTexCoord(ns.Textures.Coords("tabs", layout.region))
        if previous then
            tab.texture:SetVertexColor(0.5, 0.5, 0.5)
            tab:SetFrameLevel(window:GetFrameLevel() + 24)
        end
        tab:EnableMouse(true)
        tab:SetID(tabIndex)
        tab:SetScript("OnMouseDown", ns.onTabClick)
        featsScreen["tab" .. tabIndex] = tab
    end
end

local function createSkillBar(content)
    local skillBar = CreateFrame("Frame", nil, content, "BackdropTemplate")
    skillBar:SetPoint("TOP", 0, -20)
    skillBar:SetWidth(CONTENT_WIDTH)
    skillBar:SetHeight(32)
    skillBar:SetBackdrop(
        buildBackdrop(ns.Textures.Path("windowBackground"), 64, "Interface\\Buttons\\UI-SliderBar-Border", 8, 2)
    )
    skillBar:SetBackdropColor(0.1, 0.1, 0.1, 0)
    skillBar:SetFrameLevel(content:GetFrameLevel() + 2)
    skillBar.CheckSkill = checkSkill
    skillBar.CheckCompetitors = checkCompetitors
    Bejeweled.skillBar = skillBar

    local barBackground = CreateFrame("Frame", nil, content, "BackdropTemplate")
    barBackground:SetPoint("TOP", 0, -20)
    barBackground:SetWidth(CONTENT_WIDTH)
    barBackground:SetHeight(32)
    barBackground:SetBackdrop(content.panelBackdrop)
    barBackground:SetBackdropColor(0.1, 0.1, 0.1)
    barBackground:SetBackdropBorderColor(0, 0, 0, 0)
    barBackground:SetFrameLevel(content:GetFrameLevel() + 1)

    local bar = barBackground:CreateTexture(nil, "OVERLAY")
    bar:SetTexture(ns.Textures.Path("barArt"))
    bar:SetVertexColor(0, 0.2, 1)
    bar:SetPoint("TOPLEFT", 2, -5)
    bar:SetHeight(32)
    skillBar.bar = bar

    skillBar.text = Bejeweled:CreateCaption(0, 0, "0 / 75", skillBar, 12, 1, 1, 1, true)
    skillBar.text:ClearAllPoints()
    skillBar.text:SetPoint("CENTER", 0, 1)

    for _, side in ipairs({ "left", "right" }) do
        local icon = skillBar:CreateTexture(nil, "OVERLAY")
        icon:SetTexture(ns.Textures.Path("rankIcons"))
        if side == "left" then
            icon:SetPoint("TOPLEFT", 3, -6)
        else
            icon:SetPoint("TOPRIGHT", -3, -6)
        end
        icon:SetWidth(20)
        icon:SetHeight(20)
        icon:SetTexCoord(0, 0, 0, 0)
        skillBar[side .. "Icon"] = icon
    end
end

local function onHeaderEnter(self)
    self.text:SetVertexColor(1, 1, 1)
end

local function onHeaderLeave(self)
    self.text:SetVertexColor(1, 0.82, 0)
end

-- Collapses or expands one feat section of the skills tab.
local function onHeaderClick(header)
    local content = featsScreen.tab1Content
    local section = header:GetID()
    local textSize = content.skillTextSize
    local count = #Bejeweled.const.skillData[section]
    local nextHeader = content["section" .. (section + 1) .. "Header"]
    if header.opened then
        header.opened = nil
        for itemIndex = 1, count do
            local item = content["section" .. section .. "Item" .. itemIndex]
            item:SetHeight(0.01)
            item.text:Hide()
            if item.hasData then
                content.scrollHeight = content.scrollHeight - textSize
            end
        end
        if nextHeader then
            nextHeader:ClearAllPoints()
            nextHeader:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
        end
        header.expander:SetTexture("Interface\\Buttons\\UI-PlusButton-UP")
    else
        header.opened = true
        local lastItem
        for itemIndex = 1, count do
            local item = content["section" .. section .. "Item" .. itemIndex]
            if not item.hasData then
                break
            end
            item:SetHeight(textSize + 1)
            item.text:Show()
            lastItem = item
            content.scrollHeight = content.scrollHeight + textSize
        end
        if nextHeader and lastItem then
            nextHeader:ClearAllPoints()
            nextHeader:SetPoint("TOPLEFT", lastItem, "BOTTOMLEFT", 0, -2)
        end
        header.expander:SetTexture("Interface\\Buttons\\UI-MinusButton-UP")
    end
    content.list:SetHeight(content.scrollHeight)
end

-- Rebuilds the feat list: only feats whose unlock threshold is reached, colored by tier;
-- feats 20+ points past their last threshold drop off.
local function updateSkillsTab(self)
    local const = Bejeweled.const
    local skill = ns.db.char.skill
    local skillPoints = skill.skillPoints
    local skillData = const.skillData
    local textSize = self.skillTextSize
    self.title:SetFormattedText("Bejeweling Skill Rank: %s", const.skillDataRanks[skill.rank])
    refreshSkillBar()

    local scrollHeight = 1
    for section = 1, 5 do
        local header = self["section" .. section .. "Header"]
        header.current = 1
        header:SetHeight(0.01)
        header:Hide()
        for itemIndex = 1, #skillData[section] do
            local item = self["section" .. section .. "Item" .. itemIndex]
            item.hasData = nil
            item.text:Hide()
            item:SetHeight(0.01)
        end
    end
    local lastItem, sectionOpened
    for section = 1, 5 do
        local header = self["section" .. section .. "Header"]
        if section > 1 and sectionOpened and lastItem then
            header:ClearAllPoints()
            header:SetPoint("TOPLEFT", lastItem, "BOTTOMLEFT", 0, -2)
        end
        sectionOpened = header.opened
        local foundFeat = false
        for featIndex = #skillData[section], 1, -1 do
            local feat = skillData[section][featIndex]
            if skillPoints >= feat[2] then
                local tier = 1
                while tier < 4 and skillPoints >= feat[2 + tier] do
                    tier = tier + 1
                end
                if not (tier == 4 and skillPoints >= feat[5] + 20) then
                    if not foundFeat then
                        foundFeat = true
                        lastItem = nil
                    end
                    local itemId = header.current
                    header.current = itemId + 1
                    local item = self["section" .. section .. "Item" .. itemId]
                    item.hasData = true
                    lastItem = item
                    scrollHeight = scrollHeight + textSize
                    item.text:SetText(feat[1])
                    item.text:SetVertexColor(unpack(const.skillDataColors[tier]))
                    if sectionOpened then
                        item:SetHeight(textSize + 1)
                        item.text:Show()
                    end
                end
            end
        end
        if foundFeat then
            header:SetHeight(textSize + 1)
            header:Show()
            scrollHeight = scrollHeight + textSize
        end
    end
    self.scrollHeight = scrollHeight
    self.list:SetHeight(scrollHeight)
    showSkillTip(self)
end

local function createSkillsTab()
    local content = createTabContent()
    content:Show()
    content.panelBackdrop = featsScreen.panelBackdrop
    featsScreen.tab1Content = content

    local title = Bejeweled:CreateCaption(0, 0, "Bejeweling Skill Rank: ________", content, 16, 1, 0.85, 0.1, true)
    title:ClearAllPoints()
    title:SetPoint("TOP", 0, -2)
    title:Show()
    content.title = title

    createSkillBar(content)

    local list = createScrollList(content, featsScreen.panelBackdrop)
    content.list = list
    local textSize = 13
    content.skillTextSize = textSize
    local prevRow
    for section = 1, 5 do
        local header = CreateFrame("Frame", nil, list)
        header:SetWidth(list:GetWidth())
        header:SetHeight(textSize + 1)
        header:SetScript("OnEnter", onHeaderEnter)
        header:SetScript("OnLeave", onHeaderLeave)
        header:SetScript("OnMouseDown", onHeaderClick)
        header:SetID(section)
        header:EnableMouse(true)
        header.expander = header:CreateTexture(nil, "ARTWORK")
        header.expander:SetWidth(14)
        header.expander:SetHeight(14)
        header.expander:SetPoint("TOPLEFT", 10, 0)
        header.expander:SetTexture("Interface\\Buttons\\UI-MinusButton-UP")
        header.opened = true
        if prevRow then
            header:SetPoint("TOPLEFT", prevRow, "BOTTOMLEFT", 0, -2)
        else
            header:SetPoint("TOPLEFT", 0, -2)
        end
        header.text =
            Bejeweled:CreateCaption(27, 0, Bejeweled.const.skillDataNames[section], header, textSize, 1, 0.82, 0)
        content["section" .. section .. "Header"] = header
        prevRow = header
        for itemIndex = 1, #Bejeweled.const.skillData[section] do
            local item = CreateFrame("Frame", nil, list)
            item:SetWidth(list:GetWidth())
            item:SetHeight(textSize + 1)
            item:SetPoint("TOPLEFT", prevRow, "BOTTOMLEFT", 0, -2)
            item.text = Bejeweled:CreateCaption(32, 0, "Item " .. itemIndex, item, textSize, 1, 1, 0)
            item.text:SetVertexColor(0.5, 0.5, 0.5)
            item.hasData = true
            content["section" .. section .. "Item" .. itemIndex] = item
            prevRow = item
        end
    end
    content.UpdateSkillScreen = updateSkillsTab
    content:SetScript("OnShow", updateSkillsTab)
end

-- Builds a caption column inside a stats panel; returns the value captions keyed by field.
local function createStatRows(content, panel, top, rows)
    local fontSize = 16
    for index, row in ipairs(rows) do
        local y = top + (index - 1) * 18
        Bejeweled:CreateCaption(10, y, row[2], panel, fontSize, 1, 0.85, 0.1)
        local value = Bejeweled:CreateCaption(10, y, "0", panel, fontSize, 1, 1, 1)
        value:ClearAllPoints()
        value:SetPoint("TOPRIGHT", -10, -y)
        content[row[1]] = value
    end
end

local function updateStatsTab(self)
    local stats = ns.db.char.stats
    self.scoreClassic:SetText(Bejeweled:NumberWithCommas(stats.classic.score))
    self.scoreTimed:SetFormattedText("%.2f", stats.timed.score)
    self.highestLevel:SetText(stats.classic.highestLevel)
    self.mostMoves:SetText(stats.timed.mostMoves)
    self.largestCascade:SetText(stats.largestCascade)
    self.largestCombo:SetText(stats.largestCombo)
    self.totalPlayed:SetText(Bejeweled:TotalTime(stats.played))
    self.classicPlayed:SetText(Bejeweled:TotalTime(stats.classic.played))
    self.timedPlayed:SetText(Bejeweled:TotalTime(stats.timed.played))
    self.combatPaused:SetText(stats.combatPause)
    self.totalGems:SetText(stats.totalGemsMatched)
    self.totalGames:SetText(ns.totalGamesAllChars)
    self.totalHyper:SetText(stats.totalHyperGems)
    self.totalPower:SetText(stats.totalPowerGems)
    local gemMatch = stats.gemMatch
    local favorite = 1
    for colorIndex = 2, #gemMatch do
        if gemMatch[colorIndex] > gemMatch[favorite] then
            favorite = colorIndex
        end
    end
    if favorite == 1 and gemMatch[1] == gemMatch[2] then
        self.favoriteColor:SetText("|cFFFFFFFF" .. NONE)
    else
        self.favoriteColor:SetText(C.FAVORITE_COLOR_LABELS[favorite])
    end
end

local function createStatsTab()
    local content = createTabContent()
    content:SetScript("OnShow", updateStatsTab)
    featsScreen.tab2Content = content
    local backdrop = featsScreen.panelBackdrop

    local caption = Bejeweled:CreateCaption(0, 0, "Personal Bests", content, 16, 1, 0.85, 0.1, true)
    caption:ClearAllPoints()
    caption:SetPoint("TOP", 0, -2)
    caption:Show()
    local panel = createPanel(content, backdrop, 6 * 20 + 6, "TOP", 0, -26)
    createStatRows(content, panel, 9, {
        { "scoreClassic", "Best Classic Mode Score |cFFFF9922(Points)" },
        { "scoreTimed", "Best Timed Mode Score |cFFFF9922(PPS)" },
        { "highestLevel", "Highest Level |cFFFF9922(Classic)" },
        { "mostMoves", "Most Moves |cFFFF9922(Timed)" },
        { "largestCascade", "Largest Cascade" },
        { "largestCombo", "Largest Combo" },
    })

    caption = Bejeweled:CreateCaption(0, 0, "Fun Statistics", content, 16, 1, 0.85, 0.1, true)
    caption:ClearAllPoints()
    caption:SetPoint("TOP", 0, -24 - 132)
    caption:Show()
    panel = createPanel(content, backdrop, 9 * 20 + 4, "TOP", 0, -36 - 20 - 122)
    createStatRows(content, panel, 11, {
        { "totalPlayed", "Total Time /Played" },
        { "classicPlayed", "Classic Mode /Played" },
        { "timedPlayed", "Timed Mode /Played" },
        { "combatPaused", "Times Entered Combat While Playing" },
        { "favoriteColor", "Favorite Color |cFFFF9922(Gem)" },
        { "totalGems", "Total Gems Matched" },
        { "totalGames", "Total Games Played" },
        { "totalHyper", "|cFFA335EE[Hyper Cube]|r Total" },
        { "totalPower", "|cFF0070DD[Power Gem]|r Total" },
    })
end

local function createRadio(content, x, label, id)
    local radio = CreateFrame("CheckButton", nil, content, "UIRadioButtonTemplate")
    radio:SetPoint("TOPLEFT", x, 0)
    radio.text:SetFont(ns.Textures.Font(), 12, "OUTLINE")
    radio.text:SetTextColor(1, 0.85, 0.1)
    radio.text:SetText(label)
    radio:SetHitRectInsets(0, -130, 0, 0)
    radio:SetID(id)
    radio:SetScript("OnClick", function(self)
        content.friends:SetChecked(false)
        content.guild:SetChecked(false)
        self:SetChecked(true)
        content:SetID(self:GetID())
        content:Hide()
        content:Show()
    end)
    return radio
end

local function createScoreTable(content, prefix, title, captionY, panelY)
    local caption = Bejeweled:CreateCaption(0, 0, title, content, 12, 1, 0.85, 0.1, true)
    caption:ClearAllPoints()
    caption:SetPoint("TOP", 0, captionY)
    caption:Show()
    local panel = createPanel(content, featsScreen.panelBackdrop, 150 + 6, "TOP", 0, panelY)
    for rank = 1, 10 do
        local y = rank * 14 - 7
        local widget = Bejeweled:CreateCaption(10, y, rank .. ".", panel, 12, 1, 0.53, 0.13)
        widget:ClearAllPoints()
        widget:SetPoint("TOPRIGHT", panel, "TOPLEFT", 38, -y)
        widget = panel:CreateTexture(nil, "ARTWORK")
        widget:SetTexture(ns.Textures.Path("rankIcons"))
        widget:SetTexCoord(0, 0, 0, 0)
        widget:SetWidth(10)
        widget:SetHeight(10)
        widget:SetPoint("TOPLEFT", 40, -(y + 1))
        content[prefix .. "Rank" .. rank] = widget
        content[prefix .. "Name" .. rank] = Bejeweled:CreateCaption(54, y, "", panel, 12, 1, 0.85, 0.1)
        widget = Bejeweled:CreateCaption(10, y, "", panel, 12, 1, 1, 1)
        widget:ClearAllPoints()
        widget:SetPoint("TOPRIGHT", -10, -y)
        content[prefix .. "Score" .. rank] = widget
    end
end

local function createScoresTab()
    local content = createTabContent()
    -- The frame ID selects the list: 3 = friends, 4 = guild (default, matching the checked radio).
    content:SetID(4)
    content:SetScript("OnShow", function(self)
        self:PopulateScores(self:GetID() == 3 and "friends" or "guild")
    end)
    content.PopulateScores = function(self, listType)
        ns.populateScores(self, listType)
    end
    featsScreen.tab3Content = content

    content.friends = createRadio(content, 10, "Show Friends Scores", 3)
    content.guild = createRadio(content, 200, "Show Guild Scores", 4)
    content.guild:SetChecked(true)

    createScoreTable(content, "classic", "Best Classic Mode Score |cFFFF9922(Points)", -22, -37)
    createScoreTable(content, "timed", "Best Timed Mode Score |cFFFF8822(PPS)", -193, -206)
end

local ACHIEVEMENT_TITLE = "Achievements must be completed with the addon shown\nand a game in progress.\n"
    .. "Achievements Unlocked: %d of %d\nAchievements Completed: %d"

local function isAchievementDone(skill, section, index)
    if section == Bejeweled.const.SKILLTYPE_FUN then
        return skill["gainFun" .. index] == true
    end
    return skill["gainAchieve" .. index] == true
end

-- Shows unlocked achievement plates: completed ones first (bright), then the locked chain.
local function updateAchievementsTab(self)
    local skill = ns.db.char.skill
    local skillPoints = skill.skillPoints
    local skillData = Bejeweled.const.skillData
    local scrollHeight = 1
    local lastCompleted, lastLocked, firstLocked
    local unlockedCount, totalCount, completedCount = 0, 0, 0
    for section = 6, #skillData do
        for itemIndex = 1, #skillData[section] do
            local plate = self["section" .. section .. "Item" .. itemIndex]
            plate.hasData = nil
            plate.text:Hide()
            plate.title:Hide()
            plate.texture:Hide()
            plate.icon:Hide()
            plate:SetHeight(0.01)
            totalCount = totalCount + 1
        end
    end
    for section = 6, #skillData do
        for itemIndex, feat in ipairs(skillData[section]) do
            if skillPoints >= feat[2] then
                unlockedCount = unlockedCount + 1
                local plate = self["section" .. section .. "Item" .. itemIndex]
                plate.hasData = true
                plate.text:SetText(feat[1])
                plate.title:SetText(feat[6])
                plate.icon:SetTexture(feat[7])
                scrollHeight = scrollHeight + 51
                if isAchievementDone(skill, section, itemIndex) then
                    completedCount = completedCount + 1
                    if lastCompleted then
                        plate:SetPoint("TOPLEFT", lastCompleted, "BOTTOMLEFT", 0, 0)
                    else
                        plate:SetPoint("TOPLEFT", 14, 0)
                    end
                    lastCompleted = plate
                    plate.title:SetVertexColor(1, 1, 1)
                    plate.text:SetVertexColor(0, 0, 0)
                    plate.texture:SetTexCoord(ns.Textures.Coords("achievementplates", "earned"))
                    plate.icon:SetVertexColor(1, 1, 1)
                else
                    if lastLocked then
                        plate:SetPoint("TOPLEFT", lastLocked, "BOTTOMLEFT", 0, 0)
                    else
                        firstLocked = plate
                    end
                    lastLocked = plate
                    plate.title:SetVertexColor(0.7, 0.7, 0.7)
                    plate.text:SetVertexColor(1, 1, 1)
                    plate.texture:SetTexCoord(ns.Textures.Coords("achievementplates", "unearned"))
                    plate.icon:SetVertexColor(0.5, 0.5, 0.5)
                end
                plate.text:Show()
                plate.title:Show()
                plate.texture:Show()
                plate.icon:Show()
                plate:SetHeight(59)
            end
        end
    end
    if firstLocked then
        if lastCompleted then
            firstLocked:SetPoint("TOPLEFT", lastCompleted, "BOTTOMLEFT", 0, 0)
        else
            firstLocked:SetPoint("TOPLEFT", 14, 0)
        end
    end
    self.title:SetFormattedText(ACHIEVEMENT_TITLE, unlockedCount, totalCount, completedCount)
    self.scrollHeight = scrollHeight
    self.list:SetHeight(scrollHeight)
    showSkillTip(self)
end

local function createAchievementsTab()
    local content = createTabContent()
    featsScreen.tab4Content = content

    local title = Bejeweled:CreateCaption(0, 0, "", content, 12, 1, 0.85, 0.1, true)
    title:ClearAllPoints()
    title:SetPoint("TOP", 0, 0)
    title:SetWidth(CONTENT_WIDTH)
    title:SetFormattedText(ACHIEVEMENT_TITLE, 2, 23, 2)
    title:Show()
    content.title = title

    local list = createScrollList(content, featsScreen.panelBackdrop)
    content.list = list
    local textSize = 13
    content.skillTextSize = textSize
    local prevRow
    local skillData = Bejeweled.const.skillData
    for section = 6, 7 do
        for itemIndex, feat in ipairs(skillData[section]) do
            local plate = CreateFrame("Frame", nil, list)
            plate:SetWidth(387)
            plate:SetHeight(59)
            plate:SetScale(0.87)
            if prevRow then
                plate:SetPoint("TOPLEFT", prevRow, "BOTTOMLEFT", 0, 0)
            else
                plate:SetPoint("TOPLEFT", 14, 0)
            end
            plate.title = Bejeweled:CreateCaption(54, 4, feat[6], plate, textSize, 1, 1, 1, nil, true)
            plate.title:SetWidth(280)
            plate.title:SetJustifyH("CENTER")
            plate.text = Bejeweled:CreateCaption(54, 22, feat[1], plate, textSize, 1, 1, 1, nil, true)
            plate.text:SetVertexColor(0, 0, 0)
            plate.text:SetWidth(280)
            plate.text:SetJustifyH("CENTER")
            plate.texture = plate:CreateTexture(nil, "ARTWORK")
            plate.texture:SetAllPoints(plate)
            plate.texture:SetTexture(ns.Textures.Path("achievementplates"))
            plate.texture:SetTexCoord(ns.Textures.Coords("achievementplates", "earned"))
            plate.icon = plate:CreateTexture(nil, "OVERLAY")
            plate.icon:SetPoint("TOPLEFT", 10, -10)
            plate.icon:SetWidth(32)
            plate.icon:SetHeight(32)
            plate.icon:SetTexture(feat[7])
            plate.icon:SetVertexColor(0.5, 0.5, 0.5)
            plate.hasData = true
            content["section" .. section .. "Item" .. itemIndex] = plate
            prevRow = plate
        end
    end
    content.UpdateSkillScreen = updateAchievementsTab
    content:SetScript("OnShow", updateAchievementsTab)
end

ns.RegisterBuilder("FeatsScreen", function()
    local window = Bejeweled.window
    featsScreen = CreateFrame("Frame", nil, Bejeweled.gameBoard, "BackdropTemplate")
    featsScreen:SetPoint("TOP", 0, -3 - 22)
    featsScreen:SetWidth(BOARD_WIDTH + 6)
    featsScreen:SetHeight(BOARD_HEIGHT + 6 - 22)
    featsScreen:EnableMouse(true)
    featsScreen:SetBackdrop(
        buildBackdrop(ns.Textures.Path("windowBackground"), 128, "Interface\\Glues\\Common\\TextPanel-Border", 32)
    )
    featsScreen:SetBackdropColor(0.43, 0.43, 0.43, 1)
    featsScreen:SetBackdropBorderColor(1, 0.8, 0.45)
    featsScreen:SetFrameLevel(window:GetFrameLevel() + 25)
    featsScreen:Hide()
    featsScreen:SetScript("OnShow", function(self)
        ns.setPaused(true)
        for tabIndex = 1, 4 do
            self["tab" .. tabIndex]:Show()
        end
        Bejeweled.foreground:SetAlpha(0)
        Bejeweled.summaryScreen:SetAlpha(0)
        Bejeweled.animator.hintObj:SetAlpha(0)
    end)
    featsScreen:SetScript("OnHide", function()
        Bejeweled.foreground:SetAlpha(1)
        Bejeweled.summaryScreen:SetAlpha(1)
        Bejeweled.animator.hintObj:SetAlpha(1)
    end)
    featsScreen.panelBackdrop =
        buildBackdrop(ns.Textures.Path("windowBackground"), 128, "Interface\\Glues\\Common\\TextPanel-Border", 32, 2)
    Bejeweled.featsOfSkillScreen = featsScreen

    createTabs()
    createSkillsTab()
    createStatsTab()
    createScoresTab()
    createAchievementsTab()
end)
