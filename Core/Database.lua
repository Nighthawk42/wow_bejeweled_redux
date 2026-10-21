local _, ns = ...

-- Saved variables (AceDB, SavedVariables: BejeweledReduxDB).
--   ns.db.profile  settings (per profile, shareable between characters)
--   ns.db.char     per-character progress: stats, skill, high-score lists, saved game
--   ns.db.global   account-wide data: learned flight times, games played per character, tip flags

local function defaultScoreList()
    local list = { classic = {}, timed = {} }
    for i = 1, 10 do
        list.classic[i] = { name = "PopCap Games", rank = 1, value = 1100 - i * 100 }
        list.timed[i] = { name = "PopCap Games", rank = 1, value = 3 - i * 0.2 }
    end
    return list
end

local defaults = {
    profile = {
        gameAlpha = 1,
        mouseoffAlpha = 0.3,
        lockWindow = false,
        enableSounds = true,
        quietSounds = false,
        disableHints = false,
        hideDuplicates = false,
        verboseSkills = false,
        publishScores = true,
        publishSkillGains = true,
        publishRankGains = true,
        defaultPublish = "GUILD",
        keybinding = nil,
        minimap = { hide = false },
        texturePack = "Default",
        -- Flight integration
        newGameFlight = true,
        showFlightTooltips = true,
        -- Optional open/close triggers (all opt-in)
        openFlightStart = false,
        closeFlightEnd = false,
        openOnDeath = false,
        openLogin = false,
        closeReadyCheck = false,
        closeCombat = false,
    },
    char = {
        stats = {
            classic = { score = 0, played = 0, highestLevel = 0 },
            timed = { score = 0, played = 0, mostMoves = 0 },
            largestCascade = 0,
            largestCombo = 0,
            played = 0,
            combatPause = 0,
            totalGemsMatched = 0,
            totalPowerGems = 0,
            totalHyperGems = 0,
            gemMatch = { 0, 0, 0, 0, 0, 0, 0, 0 },
        },
        skill = { rank = 1, skillPoints = 0, timedGames = 0, games = 0 },
        -- scoreList is created in InitDatabase, not here: AceDB would resurrect default
        -- entries into slots emptied by table.remove.
        classicInProgress = false,
        savedState = nil,
    },
    global = {
        flightTimes = {},
        played = {},
        -- First-time tips: true once the tip has been shown.
        firstGame = false,
        firstPowerGem = false,
        firstHyperCube = false,
        firstSkillShow = false,
        legalDisplayed = false,
    },
}

function ns.CharacterKey()
    return UnitName("player") .. "-" .. GetRealmName()
end

function ns.InitDatabase()
    ns.db = LibStub("AceDB-3.0"):New("BejeweledReduxDB", defaults, true)
    local char = ns.db.char
    if not char.scoreList then
        char.scoreList = { friends = defaultScoreList(), guild = defaultScoreList() }
    end
end

-- /bej reset: wipe this character's progress and the current profile's settings.
function ns.ResetCharacterData()
    ns.db:ResetProfile()
    wipe(ns.db.char)
    ns.db:RegisterDefaults(defaults)
    ns.db.char.scoreList = { friends = defaultScoreList(), guild = defaultScoreList() }
end
