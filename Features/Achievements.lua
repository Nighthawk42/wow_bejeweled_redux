local _, ns = ...
local Bejeweled = ns.addon

-- "Fun" achievements: things that happen in the world while a Bejeweled game is open (dying, looting,
-- killing a rare, ...). Only unearned achievements get a watcher, and watchers only fire while a game
-- is active and the window is visible. The combat log is closed to addons in Midnight, so kills and
-- deaths come from PARTY_KILL and the death recap. Many payloads turn secret inside instances, PvP
-- and encounters; secret values are skipped.

ns.Achievements = {}

local CREATURE_TYPE_CRITTER = 8
local MAX_UNIT_CACHE = 200

local events = {}
LibStub("AceEvent-3.0"):Embed(events)

local watchers = {} -- event -> { { id = funIndex, func = handler }, ... }
local unitCache, unitCacheSize = {}, 0 -- GUID -> { creatureType, classification }
local loaded

local function isEarned(id)
    return ns.db.char.skill["gainFun" .. id]
end

local function award(skillId)
    Bejeweled.skillBar:CheckSkill(Bejeweled.const.SKILLTYPE_FUN, skillId)
end

local function isPlaying()
    return ns.game and ns.game.gameMode and Bejeweled.window:IsVisible()
end

local function dispatch(event, ...)
    local list = watchers[event]
    if not list then
        return
    end
    if isPlaying() then
        for _, watcher in ipairs(list) do
            if not isEarned(watcher.id) then
                watcher.func(...)
            end
        end
    end
    -- Awards can also land later (death recap, item data), so prune by the saved flag.
    for i = #list, 1, -1 do
        if isEarned(list[i].id) then
            table.remove(list, i)
        end
    end
    if #list == 0 then
        watchers[event] = nil
        events:UnregisterEvent(event)
    end
end

local function watch(event, id, func)
    if isEarned(id) then
        return
    end
    if not watchers[event] then
        watchers[event] = {}
        events:RegisterEvent(event, dispatch)
    end
    table.insert(watchers[event], { id = id, func = func })
end

local function anySecret(...)
    for i = 1, select("#", ...) do
        if issecretvalue(select(i, ...)) then
            return true
        end
    end
    return false
end

-- Kill achievements need to know what died; PARTY_KILL only gives a GUID, so remember units the
-- player has targeted or moused over.
local function cacheUnit(unit)
    local guid = UnitGUID(unit)
    if not guid or issecretvalue(guid) or unitCache[guid] then
        return
    end
    local _, creatureType = UnitCreatureType(unit)
    local classification = UnitClassification(unit)
    if anySecret(creatureType, classification) then
        return
    end
    if unitCacheSize >= MAX_UNIT_CACHE then
        wipe(unitCache)
        unitCacheSize = 0
    end
    unitCache[guid] = { creatureType = creatureType, classification = classification }
    unitCacheSize = unitCacheSize + 1
end

local function onPlayerKill(func)
    return function(attackerGUID, targetGUID)
        if anySecret(attackerGUID, targetGUID) or attackerGUID ~= UnitGUID("player") then
            return
        end
        local info = unitCache[targetGUID]
        if info then
            func(info)
        end
    end
end

-- Killing blow of the player's latest death, from the death recap (filled shortly after PLAYER_DEAD).
local function onDeath(func)
    return function()
        C_Timer.After(1, function()
            if not C_DeathRecap.HasRecapEvents() then
                return
            end
            local killingBlow = C_DeathRecap.GetRecapEvents()[1]
            if not killingBlow or anySecret(killingBlow.event, killingBlow.environmentalType) then
                return
            end
            func(killingBlow)
        end)
    end
end

local lootSelfPatterns
local function toPattern(globalString)
    local pattern = globalString:gsub("[%^%$%(%)%.%[%]%*%+%-%?]", "%%%0")
    pattern = pattern:gsub("%%s", "(.+)"):gsub("%%d", "%%d+")
    return "^" .. pattern
end

local function isOwnLoot(text, guid)
    if guid and not issecretvalue(guid) and guid ~= "" then
        return guid == UnitGUID("player")
    end
    if not lootSelfPatterns then
        lootSelfPatterns = {}
        for _, globalString in ipairs({ LOOT_ITEM_SELF, LOOT_ITEM_SELF_MULTIPLE }) do
            table.insert(lootSelfPatterns, toPattern(globalString))
        end
    end
    for _, pattern in ipairs(lootSelfPatterns) do
        if text:find(pattern) then
            return true
        end
    end
    return false
end

local function onLootQuality(quality, skillId)
    return function(text, _, _, _, _, _, _, _, _, _, _, guid)
        if anySecret(text, guid) or not isOwnLoot(text, guid) then
            return
        end
        local link = text:match("|Hitem:.-|h.-|h")
        if not link then
            return
        end
        local item = Item:CreateFromItemLink(link)
        if item:IsItemEmpty() then
            return
        end
        item:ContinueOnItemLoad(function()
            if item:GetItemQuality() == quality then
                award(skillId)
            end
        end)
    end
end

local function registerWatchers()
    local const = Bejeweled.const

    -- 1: die from falling damage
    -- TODO(in-game): confirm death recap fields (event, environmentalType) are filled and not secret.
    watch("PLAYER_DEAD", 1, onDeath(function(killingBlow)
        if killingBlow.event == "ENVIRONMENTAL_DAMAGE" and killingBlow.environmentalType
            and killingBlow.environmentalType:upper() == "FALLING" then
            award(const.SKILL_FUNRANK1A)
        end
    end))

    -- 2: join a battleground queue
    watch("UPDATE_BATTLEFIELD_STATUS", 2, function()
        for i = 1, GetMaxBattlefieldID() do
            if GetBattlefieldStatus(i) == "queued" then
                award(const.SKILL_FUNRANK1B)
                return
            end
        end
    end)

    -- 3 / 6: loot a rare / epic item
    watch("CHAT_MSG_LOOT", 3, onLootQuality(Enum.ItemQuality.Rare, const.SKILL_FUNRANK2A))
    watch("CHAT_MSG_LOOT", 6, onLootQuality(Enum.ItemQuality.Epic, const.SKILL_FUNRANK3A))

    -- 4: kill a critter
    -- TODO(in-game): verify PARTY_KILL fires for solo kills and its GUIDs are readable in the open world.
    watch("PARTY_KILL", 4, onPlayerKill(function(info)
        if info.creatureType == CREATURE_TYPE_CRITTER then
            award(const.SKILL_FUNRANK2B)
        end
    end))

    -- 5: get resurrected
    watch("RESURRECT_REQUEST", 5, function()
        award(const.SKILL_FUNRANK2C)
    end)

    -- 7: say yes to a ready check
    watch("READY_CHECK_CONFIRM", 7, function(unit, isReady)
        if not anySecret(unit, isReady) and isReady and UnitIsUnit(unit, "player") then
            award(const.SKILL_FUNRANK3B)
        end
    end)

    -- 8: die from combat damage
    -- TODO(in-game): confirm death recap event names for melee, ranged and spell killing blows.
    watch("PLAYER_DEAD", 8, onDeath(function(killingBlow)
        local event = killingBlow.event
        if event == "SWING_DAMAGE" or event == "RANGE_DAMAGE" or (event and event:find("^SPELL")) then
            award(const.SKILL_FUNRANK3C)
        end
    end))

    -- 9: kill an elite
    watch("PARTY_KILL", 9, onPlayerKill(function(info)
        local classification = info.classification
        if classification == "elite" or classification == "rareelite" or classification == "worldboss" then
            award(const.SKILL_FUNRANK4A)
        end
    end))

    -- 10: enter a raid instance
    watch("RAID_INSTANCE_WELCOME", 10, function()
        award(const.SKILL_FUNRANK4B)
    end)

    -- 11: gain a new reputation level
    -- TODO(in-game): check that FACTION_STANDING_CHANGED fires only on a standing change, not every gain.
    watch("FACTION_STANDING_CHANGED", 11, function()
        award(const.SKILL_FUNRANK4C)
    end)

    -- 12: gain honor from a kill
    -- TODO(in-game): confirm CHAT_MSG_COMBAT_HONOR_GAIN / PLAYER_PVP_KILLS_CHANGED fire on an honorable kill.
    watch("CHAT_MSG_COMBAT_HONOR_GAIN", 12, function()
        award(const.SKILL_FUNRANK5A)
    end)
    watch("PLAYER_PVP_KILLS_CHANGED", 12, function(unit)
        if unit == "player" then
            award(const.SKILL_FUNRANK5A)
        end
    end)

    -- 13: kill a rare
    watch("PARTY_KILL", 13, onPlayerKill(function(info)
        if info.classification == "rare" or info.classification == "rareelite" then
            award(const.SKILL_FUNRANK5B)
        end
    end))

    -- 14: level up (account-wide)
    watch("PLAYER_LEVEL_UP", 14, function()
        award(const.SKILL_FUNRANK6A)
        if isEarned(14) then
            ns.db.global.gainFun14 = true
        end
    end)

    -- 15: win an arena match (same outcome test as Blizzard's PvP match results)
    watch("PVP_MATCH_COMPLETE", 15, function(winner)
        if issecretvalue(winner) or not C_PvP.IsMatchConsideredArena() or C_PvP.IsInBrawl() then
            return
        end
        if winner == GetBattlefieldArenaFaction() then
            award(const.SKILL_FUNRANK6B)
        end
    end)
end

local function onUnitSeen(event)
    if event == "PLAYER_TARGET_CHANGED" then
        cacheUnit("target")
    else
        cacheUnit("mouseover")
    end
end

-- Records this character's games for the account-wide game-count achievements and registers the
-- watchers. Safe to call more than once.
function ns.Achievements.Load()
    if loaded then
        return
    end
    loaded = true

    local skill, global = ns.db.char.skill, ns.db.global
    if skill.gainFun14 then
        global.gainFun14 = true
    end
    if global.gainFun14 then
        skill.gainFun14 = true
    end

    global.played[ns.CharacterKey()] = skill.games
    local total = 0
    for _, games in pairs(global.played) do
        total = total + games
    end
    ns.totalGamesAllChars = total

    registerWatchers()
    if watchers.PARTY_KILL then
        events:RegisterEvent("PLAYER_TARGET_CHANGED", onUnitSeen)
        events:RegisterEvent("UPDATE_MOUSEOVER_UNIT", onUnitSeen)
    end
end

ns.RegisterEnabler("Achievements", ns.Achievements.Load)
