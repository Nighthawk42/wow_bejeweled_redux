local _, ns = ...
local Bejeweled = ns.addon
local C = ns.C

-- The bordered board frame inside the main window. Screens (summary, feats, about,
-- options) and the game area are parented to it so they scale with the window.

ns.RegisterBuilder("GameBoard", function()
    local window = Bejeweled.window
    local boardAnchor = CreateFrame("Frame", nil, window)
    boardAnchor:SetPoint("TOPLEFT", 20, -60)
    boardAnchor:SetPoint("TOPRIGHT", -20, -60)
    boardAnchor:SetHeight(C.BOARD_HEIGHT + 12)
    Bejeweled.boardAnchor = boardAnchor

    local gameBoard = CreateFrame("Frame", "BejeweledReduxGameBoard", boardAnchor, "BackdropTemplate")
    gameBoard:SetPoint("TOP")
    gameBoard:SetWidth(C.BOARD_WIDTH + 14)
    gameBoard:SetHeight(C.BOARD_HEIGHT + 12)
    local backdrop = ns.makeBackdrop()
    backdrop.edgeFile = "Interface\\Glues\\Common\\TextPanel-Border"
    backdrop.edgeSize = 32
    gameBoard:SetBackdrop(backdrop)
    gameBoard:SetBackdropColor(0, 0, 0, 0)
    gameBoard:SetFrameLevel(window:GetFrameLevel() + 2)
    Bejeweled.gameBoard = gameBoard
end)
