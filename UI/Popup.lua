local _, ns = ...
local Bejeweled = ns.addon
local C = ns.C
local MENU_WIDTH, MENU_HEIGHT = C.MENU_WIDTH, C.MENU_HEIGHT

-- Tip popup shown over the window (power gem / hyper cube / first game / skill tab tips).
-- Set popup.text, optionally popup.parent (anchor above it), then Show(). Tips that contain
-- a colour code get a single OK button; the others offer Feats of Skill / Options.

ns.RegisterBuilder("Popup", function()
    local popup = CreateFrame("Frame", "BejeweledPopup", Bejeweled.window, "BackdropTemplate")
    popup:SetWidth(MENU_WIDTH + 60)
    popup:SetHeight(MENU_HEIGHT / 1.2)
    popup:SetPoint("CENTER")
    popup:EnableMouse(true)
    popup:Hide()
    popup:SetFrameLevel(Bejeweled.window:GetFrameLevel() + 23)
    Bejeweled.popup = popup

    local backdrop = ns.makeBackdrop()
    backdrop.edgeFile = "Interface\\Glues\\Common\\TextPanel-Border"
    backdrop.bgFile = C.IMAGE_PATH .. "windowBackground"
    backdrop.edgeSize = 32
    backdrop.tileSize = 128
    backdrop.insets.top = 3
    popup:SetBackdrop(backdrop)
    popup:SetBackdropColor(0.6, 0.6, 0.6, 1)
    popup:SetBackdropBorderColor(1, 0.8, 0.45)
    popup:SetMovable(true)

    local closeButton = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
    closeButton:SetToplevel(true)
    closeButton:SetPoint("TOPRIGHT", popup, "TOPRIGHT", 0, 2)
    closeButton:SetSize(38, 38)

    local text = popup:CreateFontString(nil, "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
    text:SetTextColor(1, 1, 1)
    text:SetPoint("TOP", 0, -28)
    text:SetWidth(MENU_WIDTH + 40)
    text:SetText("X")
    text.tip1 =
        "Create a |cFF0070DD[Power Gem]|r by merging 4 gems of the same color. These new gems will explode when matched, scoring extra points!"
    text.tip2 =
        "Create a |cFFA335EE[Hyper Cube]|r by merging 5 gems of the same color. Swap it with a gem to clear all gems of that color onscreen!"
    text.tip3 =
        "Now that you've played a game, check out the Options menu to adjust the settings of Bejeweled, or check out the Feats of Skill area to check out your friend's and guild's high scores, your personal stats, and your Bejeweling Skill progress!"
    text.tip4 =
        "|cFFFFFFFF|rThis is the Skill Tab. Listed are the moves in the game that will up your Bejeweling skill. This follows other tradeskills in WoW: as you go up in skill old actions will stop giving you points and new actions will show up!"
    popup.text = text

    local caption = popup:CreateFontString(nil, "OVERLAY")
    caption:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
    caption:SetTextColor(1, 1, 1)
    caption:SetPoint("TOP", 0, -8)
    caption:SetWidth(MENU_WIDTH + 40)
    caption:SetText("")
    popup.caption = caption

    popup:SetScript("OnShow", function(self)
        self.caption:SetText("")
        self:ClearAllPoints()
        if self.parent then
            self:SetPoint("BOTTOM", self.parent, "TOP")
            self.parent = nil
        else
            self:SetPoint("CENTER")
        end
        Bejeweled.window.menuButton:Disable()
        local isTip = string.find(self.text:GetText(), "|cFF", 1, true) ~= nil
        self:SetHeight(self.text:GetHeight() + (isTip and 50 or 86) + 20)
        self.button1:SetShown(isTip)
        self.button2:SetShown(not isTip)
        self.button3:SetShown(not isTip)
    end)
    popup:SetScript("OnHide", function()
        Bejeweled.window.menuButton:Enable()
    end)

    local okButton = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    okButton:SetPoint("BOTTOM", 0, 10)
    okButton:SetText(OKAY)
    okButton:SetSize(MENU_WIDTH - 20, 28)
    okButton:SetScript("OnClick", function()
        popup:Hide()
    end)
    popup.button1 = okButton

    local skillsButton = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    skillsButton:SetPoint("BOTTOM", 0, 15)
    skillsButton:SetText("Feats of Skill")
    skillsButton:SetSize(MENU_WIDTH - 20, 28)
    skillsButton:SetScript("OnClick", function()
        popup:Hide()
        Bejeweled.menuWindow.buttonSkills:Click()
    end)
    popup.button2 = skillsButton

    local optionsButton = CreateFrame("Button", nil, skillsButton, "UIPanelButtonTemplate")
    optionsButton:SetPoint("BOTTOM", skillsButton, "TOP", 0, 5)
    optionsButton:SetText("Options")
    optionsButton:SetSize(MENU_WIDTH - 20, 28)
    optionsButton:SetScript("OnClick", function()
        popup:Hide()
        Bejeweled.menuWindow.buttonOptions:Click()
    end)
    popup.button3 = optionsButton
end)
