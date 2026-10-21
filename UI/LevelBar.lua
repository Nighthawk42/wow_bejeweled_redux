local _, ns = ...
local Bejeweled = ns.addon
local C = ns.C

-- Level/score bar methods (mixed into Bejeweled.levelBar by UI/GameArea.lua) and its timer.
-- Classic: the bar fills toward the next level and the data text shows the score.
-- Timed/flight: the level text shows points per second and the bar counts the time down.

local MODE_CLASSIC, MODE_FLIGHT = C.MODE_CLASSIC, C.MODE_FLIGHT
local floor = math.floor

local methods = {}
ns.levelBarMethods = methods

-- Classic score-track skills: { rank required, score, game flag, skill id key }.
local SCORE_TRACK = {
    { 2, 10000, "scoreTrack1", "SKILL_SCORE10K" },
    { 3, 25000, "scoreTrack2", "SKILL_SCORE25K" },
    { 5, 50000, "scoreTrack3", "SKILL_SCORE50K" },
    { 6, 75000, "scoreTrack4", "SKILL_SCORE75K" },
}

local function checkClassicScoreSkills(score)
    local game = ns.game
    local const = Bejeweled.const
    local skill = ns.db.char.skill
    for _, track in ipairs(SCORE_TRACK) do
        local rank, threshold, flag, skillKey = track[1], track[2], track[3], track[4]
        if skill.rank >= rank and score >= threshold and not game[flag] then
            game[flag] = true
            Bejeweled.skillBar:CheckSkill(const.SKILLTYPE_CLASSIC, const[skillKey])
        end
    end
    if not skill["gainAchieve" .. const.SKILL_ACHIEVE4A] and score >= 75000 then
        Bejeweled.skillBar:CheckSkill(const.SKILLTYPE_ACHIEVEMENT, const.SKILL_ACHIEVE4A)
    end
end

-- Announces the level up (classic) or multiplier up (timed/flight) once the bar is full;
-- the animator wipes the board when the current cascade ends.
local function announceLevelUp()
    local game = ns.game
    local animator = Bejeweled.animator
    local statusText = Bejeweled.gameStatusText
    if game.gameMode == MODE_CLASSIC then
        statusText:SetText("Level up")
    else
        statusText:SetText("Multiplier up")
        local multiplierText
        if math.fmod(game.level, 2) == 0 then
            multiplierText = game.level .. "x"
        else
            multiplierText = string.format("%.1fx", 1 + game.level * 0.5)
        end
        for x = 25, 325, 100 do
            local floatText = animator:CreateFloatingText(x, 135, multiplierText, 2)
            floatText.fxType = C.FX_FLOAT_TEXT
            floatText:Show()
            animator:Add(floatText)
            floatText = animator:CreateFloatingText(x, 250, multiplierText, 3, true)
            floatText:SetTextColor(1, 1, 1)
            floatText.fxType = C.FX_FLOAT_TEXT
            floatText:Show()
            animator:Add(floatText)
        end
    end
    Bejeweled.sound:Play("LevelUp")
    statusText:Show()
    statusText.background:Show()
    animator.hintObj:Hide()
    animator.hintObj.fxType = C.FX_DONE
    game.leveledUp = true
    ns.keepSpecialsOnLevel = true
end

function methods:SetScore(score)
    if not self.maxScore then
        return
    end
    local game = ns.game
    self.score = score
    game.score = score
    if game.gameMode == MODE_CLASSIC then
        checkClassicScoreSkills(score)
    end
    if score >= self.maxScore and not game.leveledUp then
        announceLevelUp()
    end
    self:UpdateBar()
end

local function formatClock(minutes, seconds)
    if seconds < 10 then
        seconds = "0" .. seconds
    end
    return string.format("%d:%s", minutes, seconds)
end

function methods:UpdateBar()
    local barWidth = self:GetWidth() - 4
    if self.mode == MODE_CLASSIC then
        if self.lastScore ~= self.score then
            self.lastScore = self.score
            Bejeweled.dataText:SetText(Bejeweled:NumberWithCommas(self.score))
        end
        if ns.game.leveledUp then
            self.bar:SetWidth(barWidth)
        else
            self.bar:SetWidth((self.score - self.minScore + 0.5) / (self.maxScore - self.minScore) * barWidth)
        end
        return
    end

    local timer = self.timer
    if self.score > 0 then
        Bejeweled.levelText:SetFormattedText("%.2f", self.score / timer.timeElapsed)
    else
        Bejeweled.levelText:SetFormattedText("%.2f", 0)
    end
    if self.mode == MODE_FLIGHT and Bejeweled.flightOptionWindow.learning then
        -- Unknown flight length: count the time up.
        if timer.timeLeft == -1 then
            self.text:SetText("Timing")
        elseif timer.timeElapsed == 0 then
            self.text:SetText(formatClock(0, 0))
        else
            local minutes = floor((timer.timeElapsed + 1) / 60)
            self.text:SetText(formatClock(minutes, floor(timer.timeElapsed + 1 - minutes * 60)))
        end
        self.bar:SetWidth(barWidth)
    elseif timer.timeLeft == -1 then
        self.text:SetText("Timing")
    elseif timer.timeLeft == timer.timeStart then
        local minutes = floor(timer.timeLeft / 60)
        self.text:SetText(formatClock(minutes, floor(timer.timeLeft - minutes * 60)))
        self.bar:SetWidth(barWidth)
    elseif timer.timeLeft == 0 then
        self.text:SetText(formatClock(0, 0))
        self.bar:SetWidth(0.01)
    else
        local minutes = floor((timer.timeLeft + 1) / 60)
        self.text:SetText(formatClock(minutes, floor(timer.timeLeft + 1 - minutes * 60)))
        self.bar:SetWidth((timer.timeLeft + 0.1) / timer.timeStart * self:GetWidth() - 4)
    end
end

function methods:SetMinMaxScore(minScore, maxScore)
    self.minScore = minScore
    self.maxScore = maxScore
end

function methods:AddScore(points)
    return self:SetScore(self.score + points)
end

-- Resets the bar for a new game and lays out the level/data texts for the mode.
function methods:SetMode(mode, timeSeconds)
    local levelText, caption, dataText = Bejeweled.levelText, Bejeweled.levelTextCaption, Bejeweled.dataText
    self.mode = mode
    levelText:SetText("1")
    self.text:SetText("")
    if mode == MODE_CLASSIC then
        self:SetTimer()
        self:SetMinMaxScore(0, 500)
        self:SetScore(0)
        self.bar:SetVertexColor(0, 0.5, 1)
        Bejeweled.dataBorder:SetWidth(128)
        Bejeweled.levelBorder:SetWidth(94)
        caption:SetText("|cFF11AAFFlvl|r")
        dataText:SetText("0")
        dataText:SetFont(C.FONT, 12, "OUTLINE")
        levelText:ClearAllPoints()
        levelText:SetPoint("TOPRIGHT", -16, 0)
        levelText:SetPoint("BOTTOMLEFT", 48, 1)
        levelText:SetJustifyH("LEFT")
        caption:ClearAllPoints()
        caption:SetPoint("TOPRIGHT", levelText, "TOPLEFT", 5, 0)
        caption:SetWidth(20)
        caption:SetHeight(30)
    else
        self:SetTimer(timeSeconds)
        self:SetMinMaxScore(0, 500 * C.MODE_POINT_MULTIPLIER[mode])
        self:SetScore(0)
        self.bar:SetVertexColor(0, 1, 0)
        Bejeweled.dataBorder:SetWidth(76)
        Bejeweled.levelBorder:SetWidth(130)
        caption:SetText(" |cFF00FF00pps|r")
        dataText:SetText("1|cFF00FF00x")
        dataText:SetFont(C.FONT, 10, "OUTLINE")
        levelText:ClearAllPoints()
        levelText:SetPoint("TOPLEFT", 16, 0)
        levelText:SetPoint("BOTTOMRIGHT", -48, 1)
        levelText:SetJustifyH("RIGHT")
        caption:ClearAllPoints()
        caption:SetPoint("TOPLEFT", levelText, "TOPRIGHT", -5, 0)
        caption:SetPoint("BOTTOMRIGHT", -20, 1)
        if mode == MODE_FLIGHT and Bejeweled.flightOptionWindow.learning then
            self.timer.timeElapsed = timeSeconds
            self.timer.legJourney = timeSeconds
        end
    end
end

function methods:SetTimer(seconds)
    local timer = self.timer
    timer.timeLeft = seconds or 0
    timer.timeStart = seconds or 0
    timer.timeElapsed = 0
    self:StartTimer()
end

function methods:StartTimer()
    self.timer.elapsed = 0
    self.timer:Show()
end

function methods:StopTimer()
    self.timer:Hide()
end

-- OnUpdate of levelBar.timer: play time stats in 0.1 s steps, the timed-mode countdown,
-- and keeping a flight game in sync with the flight timer.
function ns.levelTimerOnUpdate(self, elapsed)
    if Bejeweled.animator.newGameStart then
        return
    end
    -- After a long hitch, count a single step instead of the whole gap.
    if elapsed > 1 then
        elapsed = 0.1
    end
    self.elapsed = self.elapsed + elapsed
    if self.elapsed < 0.1 then
        return
    end
    local game = ns.game
    local stats = ns.db.char.stats
    game.statDB.played = game.statDB.played + self.elapsed
    stats.played = stats.played + self.elapsed
    self.timeLeft = self.timeLeft - self.elapsed
    self.timeElapsed = self.timeElapsed + self.elapsed
    self.elapsed = 0

    local levelBar = Bejeweled.levelBar
    if levelBar.mode == MODE_CLASSIC then
        return
    end
    if levelBar.mode == MODE_FLIGHT then
        local flightWindow = Bejeweled.flightOptionWindow
        if self.timeLeft <= 0 then
            -- The flight outlasted its known time: switch to learning it.
            self.timeLeft = -1
            flightWindow.learning = true
            if not flightWindow.timer:IsShown() then
                flightWindow.timer:Show()
            end
        else
            local flightTimer = flightWindow.timer
            if flightTimer.learning ~= true and math.abs(self.timeLeft - flightTimer.timeRemaining) > 0.6 then
                self.timeLeft = flightTimer.timeRemaining
                self.timeElapsed = flightTimer.timeElapsed
            end
        end
    elseif self.timeLeft <= 0 then
        self.timeLeft = 0
        self.timeElapsed = self.timeStart
        self:Hide()
        ns.endGame()
    end
    levelBar:UpdateBar()
end
