local _, ns = ...
local Bejeweled = ns.addon
local C = ns.C

-- Game sounds, queued by Bejeweled.sound:Play(name) and played on the next frame so that
-- simultaneous triggers of the same sound collapse into one. The same frame also runs the
-- mouse-leave check that fades and pauses the window; MainWindow hides it while faded.

local SOUND_FILES = {
    Invalid = "bad2.mp3",
    Explosion = "bombexplode.mp3",
    GetReady = "Get_ready.mp3",
    NoMoreMoves = "No_More_Moves.mp3",
    TimesUp = "Time_Up.mp3",
    Go = "Go.mp3",
    Select = "select.mp3",
    PowerCreate = "multishot.mp3",
    HyperCreate = "hypergem_creation.mp3",
    HyperDestroy = "hypergem_destroyed.mp3",
    GemClick = "gemongem2.mp3",
    WipeBoard = "explode2.mp3",
    ElectroExplode = "electro_explode.mp3",
}
-- Played in this order when several are queued in the same frame.
local SOUND_ORDER = {
    "Invalid",
    "Explosion",
    "GetReady",
    "NoMoreMoves",
    "TimesUp",
    "Go",
    "Select",
    "PowerCreate",
    "HyperCreate",
    "HyperDestroy",
    "GemClick",
    "WipeBoard",
    "ElectroExplode",
}
local MAX_COMBO_SOUND = 6
local GEM_CLICK_INTERVAL = 0.2
local MOUSE_CHECK_INTERVAL = 0.5

local function playFile(prefix, file)
    PlaySoundFile(C.SOUND_PATH .. prefix .. file, "Master")
end

local function comboFile(level)
    if level == 1 then
        return "gotset2.mp3"
    end
    return "combo" .. (level + 1) .. "2.mp3"
end

local function checkMouseLeave(sound)
    local window = Bejeweled.window
    if sound.mouseOver and not window.hiding and not window.mouseBounds:IsMouseOver() and not window.resizing then
        sound.waitMouseOver = nil
        Bejeweled.const.windowFadeOut.fadeTimer = 0
        UIFrameFade(window, Bejeweled.const.windowFadeOut)
        window.mouseOverScreen:Show()
        sound.mouseOver = nil
        sound:Hide()
        if Bejeweled.paused ~= true then
            Bejeweled.mousePaused = true
            ns.setPaused(true)
        end
    end
    if sound.waitMouseOver and window.mouseBounds:IsMouseOver() then
        window.mouseOverScreen:Hide()
        sound.waitMouseOver = nil
        sound.mouseOver = true
    end
end

local function playQueued(sound)
    sound.playSound = nil
    local prefix = ns.db.profile.quietSounds and "q_" or ""
    for _, name in ipairs(SOUND_ORDER) do
        if sound[name] then
            sound[name] = nil
            playFile(prefix, SOUND_FILES[name])
        end
    end
    if sound.LevelUp then
        sound.LevelUp = nil
        PlaySound(SOUNDKIT.UI_GARRISON_COMMAND_TABLE_FOLLOWER_LEVEL_UP, "Master")
    end
    -- Only the lowest queued combo level plays per frame; higher ones wait for later frames.
    if sound.Combo then
        for level = 1, MAX_COMBO_SOUND do
            if sound["Combo" .. level] then
                sound["Combo" .. level] = nil
                playFile(prefix, comboFile(level))
                return
            end
        end
        sound.Combo = nil
    end
end

local function onUpdate(self, elapsed)
    self.mouseOverElapsed = self.mouseOverElapsed + elapsed
    self.lastClick = self.lastClick + elapsed
    if self.mouseOverElapsed > MOUSE_CHECK_INTERVAL and ns.db.global.legalDisplayed then
        self.mouseOverElapsed = 0
        checkMouseLeave(self)
    end
    if self.playSound and ns.db.profile.enableSounds then
        playQueued(self)
    end
end

-- name: a SOUND_FILES key, "LevelUp", or "Combo" (with comboLevel, capped at 6).
local function play(self, name, comboLevel)
    if not ns.db.profile.enableSounds or not Bejeweled.window:IsVisible() then
        return
    end
    self.playSound = true
    if name == "Combo" then
        self["Combo" .. math.min(comboLevel or 1, MAX_COMBO_SOUND)] = true
        self.Combo = true
    elseif name == "GemClick" then
        if self.lastClick > GEM_CLICK_INTERVAL then
            self.GemClick = true
            self.lastClick = 0
        end
    else
        self[name] = true
    end
end

ns.RegisterBuilder("Sound", function()
    local sound = CreateFrame("Frame", nil, Bejeweled.window)
    sound:SetSize(1, 1)
    sound:SetPoint("TOP")
    sound.elapsed = 0
    sound.mouseOverElapsed = 0
    sound.mouseOver = true
    sound.lastClick = 0
    sound.Play = play
    sound:SetScript("OnUpdate", onUpdate)
    sound:Show()
    Bejeweled.sound = sound
end)
