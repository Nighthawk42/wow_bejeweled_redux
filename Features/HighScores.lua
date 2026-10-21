local _, ns = ...
local Bejeweled = ns.addon
local C = ns.C

-- Friend and guild high-score lists, and the addon-message protocol that keeps them in sync.
-- Each list (friends/guild x classic/timed) holds up to 10 { name, rank, value } rows, best first;
-- "PopCap Games" rows are placeholders. Names are stored as Ambiguate(fullName, "none").
--
-- Protocol (AceComm prefix C.COMM_PREFIX, AceSerializer payload, PROTOCOL_VERSION):
--   { v, op = "score", mode = "classic"|"timed", value, rank }      a new or re-published best score
--   { v, op = "sync?", scores = { classic, timed }, rank }           login request; carries the sender's bests
--   { v, op = "sync", scope = "guild"|"friends", scores, rank }      whispered reply with the responder's bests
-- GUILD traffic feeds the guild list; whispers and group traffic only count when the sender is a friend
-- (friends list) or a guildmate (guild list).

local HighScores = {}
ns.HighScores = HighScores

local PROTOCOL_VERSION = 1
local POPCAP = "PopCap Games"
local MAX_ENTRIES = 10
local MAX_RANK = 6
local MAX_VALUE = { classic = 10000000, timed = 10000 }
local FILLER_STEP = { classic = 100, timed = 0.2 }
local FILLER_TOP = { classic = 1000, timed = 2.8 }
local MODES = { "classic", "timed" }
local LISTS = { "friends", "guild" }

local SYNC_DELAY = 8 -- seconds after login before asking for scores
local REPLY_COOLDOWN = 60 -- per requester
local PUBLISH_DELAY = 3 -- coalesces score broadcasts
local SCRUB_DELAY = 5
local LOCKDOWN_RETRY = 30

local events = {}
LibStub("AceEvent-3.0"):Embed(events)

local lastReply = {}
local outbox = {}
local pendingPublish = {}
local publishTimer, scrubTimer, retryTimer
local guildRoster
local friendsLoaded = false

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

local function NormalizeName(name)
    if type(name) ~= "string" or name == "" or IsSecret(name) then
        return nil
    end
    return Ambiguate(name, "none")
end

local function PlayerName()
    return UnitName("player")
end

local function IsSelf(name)
    if name == PlayerName() then
        return true
    end
    local realm = GetNormalizedRealmName()
    return realm ~= nil and name == PlayerName() .. "-" .. realm
end

local function IsRealPlayer(name)
    return name ~= POPCAP and not IsSelf(name)
end

local function GetLists(listKey)
    return ns.db.char.scoreList[listKey]
end

local function PlayerRank()
    local rank = ns.db.char.skill.rank or 1
    return math.max(1, math.min(MAX_RANK, rank))
end

-- Best score this character has achieved, from the stats or anything submitted through this module.
local function OwnBest(modeKey)
    local scoreList = ns.db.char.scoreList
    scoreList.best = scoreList.best or {}
    local stats = ns.db.char.stats[modeKey]
    return math.max(stats and stats.score or 0, scoreList.best[modeKey] or 0)
end

local function ValidValue(modeKey, value)
    if type(value) ~= "number" or value ~= value or value < 0 or value > MAX_VALUE[modeKey] then
        return false
    end
    return modeKey ~= "classic" or value == math.floor(value)
end

local function ValidRank(rank)
    return type(rank) == "number" and rank >= 1 and rank <= MAX_RANK and rank == math.floor(rank)
end

-- Friends and guild

function HighScores.IsFriend(name)
    name = NormalizeName(name)
    if not name then
        return false
    end
    for i = 1, C_FriendList.GetNumFriends() or 0 do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info and NormalizeName(info.name) == name then
            return true
        end
    end
    return false
end

-- Set of normalized guild member names, or nil while the roster is unavailable.
local function BuildGuildRoster()
    if not IsInGuild() then
        return nil
    end
    local clubId = C_Club.GetGuildClubId()
    if not clubId then
        return nil
    end
    local roster, count = {}, 0
    for _, memberId in ipairs(C_Club.GetClubMembers(clubId) or {}) do
        local info = C_Club.GetMemberInfo(clubId, memberId)
        local name = info and NormalizeName(info.name)
        if name then
            roster[name] = true
            count = count + 1
        end
    end
    return count > 0 and roster or nil
end

function HighScores.IsGuildmate(name)
    name = NormalizeName(name)
    if not name or not IsInGuild() then
        return false
    end
    guildRoster = guildRoster or BuildGuildRoster()
    if guildRoster then
        return guildRoster[name] == true
    end
    return C_GuildInfo.MemberExistsByName(name) == true
end

-- List maintenance

local function FillerValue(list, modeKey)
    local step = FILLER_STEP[modeKey]
    local lowest = FILLER_TOP[modeKey] + step
    for _, entry in ipairs(list) do
        if entry.value < lowest then
            lowest = entry.value
        end
    end
    return math.max(0, lowest - step)
end

local function PadList(list, modeKey)
    while #list < MAX_ENTRIES do
        table.insert(list, { name = POPCAP, rank = 1, value = FillerValue(list, modeKey) })
    end
end

-- Inserts an entry in score order. Returns placed, beatOtherPlayer.
local function MergeEntry(list, modeKey, name, rank, value)
    for _, entry in ipairs(list) do
        if entry.name == name and entry.value == value then
            return false, false
        end
    end
    if ns.db.profile.hideDuplicates then
        for i, entry in ipairs(list) do
            if entry.name == name then
                if entry.value >= value then
                    return false, false
                end
                table.remove(list, i)
                break
            end
        end
    end
    local position
    for i, entry in ipairs(list) do
        if value > entry.value then
            position = i
            break
        end
    end
    if not position then
        if #list >= MAX_ENTRIES then
            PadList(list, modeKey)
            return false, false
        end
        position = #list + 1
    end
    local beatOther = false
    for i = position, #list do
        if IsRealPlayer(list[i].name) then
            beatOther = true
            break
        end
    end
    table.insert(list, position, { name = name, rank = rank, value = value })
    while #list > MAX_ENTRIES do
        table.remove(list)
    end
    PadList(list, modeKey)
    return true, beatOther
end

local function MergeScores(listKey, name, rank, scores)
    local lists = GetLists(listKey)
    for _, modeKey in ipairs(MODES) do
        local value = scores[modeKey]
        if ValidValue(modeKey, value) and value > 0 then
            MergeEntry(lists[modeKey], modeKey, name, rank, value)
        end
    end
end

local function RemoveDuplicates(list)
    local seen = {}
    local i = 1
    while i <= #list do
        local name = list[i].name
        if name ~= POPCAP and seen[name] then
            table.remove(list, i)
        else
            seen[name] = true
            i = i + 1
        end
    end
end

-- Drops entries of people no longer in the friends list / guild.
local function ScrubList(listKey, isMember)
    local lists = GetLists(listKey)
    for _, modeKey in ipairs(MODES) do
        local list = lists[modeKey]
        if ns.db.profile.hideDuplicates then
            RemoveDuplicates(list)
        end
        local i = 1
        while i <= #list do
            local name = list[i].name
            if IsRealPlayer(name) and not isMember(name) then
                table.remove(list, i)
            else
                i = i + 1
            end
        end
        PadList(list, modeKey)
    end
end

local function ScrubLists()
    scrubTimer = nil
    if friendsLoaded then
        ScrubList("friends", HighScores.IsFriend)
    end
    guildRoster = BuildGuildRoster()
    if guildRoster then
        ScrubList("guild", function(name)
            return guildRoster[name] == true
        end)
    elseif not IsInGuild() and not GetGuildInfo("player") then
        -- Left (or never joined) a guild: nobody else belongs on the guild list.
        ScrubList("guild", function()
            return false
        end)
    end
end

local function ScheduleScrub()
    if not scrubTimer then
        scrubTimer = C_Timer.NewTimer(SCRUB_DELAY, ScrubLists)
    end
end

-- Sending

local function IsLocked()
    return C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()
end

local function Transmit(item)
    if item.distribution == "GUILD" and not IsInGuild() then
        return
    end
    Bejeweled:SendCommMessage(C.COMM_PREFIX, Bejeweled:Serialize(item.message), item.distribution, item.target, item.priority)
end

local function FlushOutbox()
    if IsLocked() then
        return false
    end
    local queued = outbox
    outbox = {}
    for _, item in ipairs(queued) do
        Transmit(item)
    end
    return true
end

local function ScheduleRetry()
    if retryTimer then
        return
    end
    retryTimer = C_Timer.NewTicker(LOCKDOWN_RETRY, function()
        if FlushOutbox() then
            retryTimer:Cancel()
            retryTimer = nil
        end
    end)
end

local function Send(message, distribution, target, priority)
    message.v = PROTOCOL_VERSION
    local item = { message = message, distribution = distribution, target = target, priority = priority or "NORMAL" }
    if not IsLocked() then
        Transmit(item)
        return
    end
    -- Keep only the latest message per destination and kind while locked down.
    local key = distribution .. ":" .. (target or "") .. ":" .. message.op .. ":" .. (message.mode or "")
    item.key = key
    for i, queued in ipairs(outbox) do
        if queued.key == key then
            outbox[i] = item
            return
        end
    end
    table.insert(outbox, item)
    ScheduleRetry()
end

local function ForEachOnlineFriend(func)
    for i = 1, C_FriendList.GetNumFriends() or 0 do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info and info.connected and info.name and not IsSecret(info.name) then
            func(info.name)
        end
    end
end

local function OwnScores()
    return { classic = OwnBest("classic"), timed = OwnBest("timed") }
end

local function FlushPublish()
    publishTimer = nil
    local rank = PlayerRank()
    for _, modeKey in ipairs(MODES) do
        local value = pendingPublish[modeKey]
        if value then
            pendingPublish[modeKey] = nil
            local function message()
                return { op = "score", mode = modeKey, value = value, rank = rank }
            end
            Send(message(), "GUILD", nil, "NORMAL")
            ForEachOnlineFriend(function(friend)
                Send(message(), "WHISPER", friend, "BULK")
            end)
        end
    end
end

local function RequestSync()
    local function message()
        return { op = "sync?", scores = OwnScores(), rank = PlayerRank() }
    end
    if IsInGuild() then
        Send(message(), "GUILD", nil, "BULK")
    end
    ForEachOnlineFriend(function(friend)
        Send(message(), "WHISPER", friend, "BULK")
    end)
end

local function ReplySync(sender, scope)
    local now = GetTime()
    if lastReply[sender] and now - lastReply[sender] < REPLY_COOLDOWN then
        return
    end
    lastReply[sender] = now
    C_Timer.After(1 + math.random() * 4, function()
        Send({ op = "sync", scope = scope, scores = OwnScores(), rank = PlayerRank() }, "WHISPER", sender, "BULK")
    end)
end

-- Receiving

-- Which list a score from this sender belongs in, or nil.
local function ListForSender(distribution, name, scope)
    if distribution == "GUILD" then
        return "guild"
    end
    if scope == "guild" then
        return HighScores.IsGuildmate(name) and "guild" or nil
    end
    if scope == "friends" or distribution == "WHISPER" then
        return HighScores.IsFriend(name) and "friends" or nil
    end
    if HighScores.IsGuildmate(name) then
        return "guild"
    end
    return HighScores.IsFriend(name) and "friends" or nil
end

local function ValidScores(scores)
    if type(scores) ~= "table" then
        return nil
    end
    local valid = {}
    for _, modeKey in ipairs(MODES) do
        if ValidValue(modeKey, scores[modeKey]) then
            valid[modeKey] = scores[modeKey]
        end
    end
    return valid
end

local function OnCommReceived(prefix, text, distribution, sender)
    if prefix ~= C.COMM_PREFIX or type(text) ~= "string" then
        return
    end
    local name = NormalizeName(sender)
    if not name or IsSelf(name) then
        return
    end
    local ok, message = Bejeweled:Deserialize(text)
    if not ok or type(message) ~= "table" or message.v ~= PROTOCOL_VERSION then
        return
    end
    local op, rank = message.op, message.rank
    if op == "score" then
        local modeKey = message.mode
        if (modeKey == "classic" or modeKey == "timed") and ValidRank(rank) then
            local listKey = ListForSender(distribution, name)
            if listKey then
                MergeScores(listKey, name, rank, ValidScores({ [modeKey] = message.value }))
            end
        end
    elseif op == "sync?" then
        local scope = distribution == "GUILD" and "guild" or "friends"
        if distribution == "GUILD" or distribution == "WHISPER" then
            ReplySync(sender, scope)
        end
        local scores = ValidScores(message.scores)
        if scores and ValidRank(rank) then
            local listKey = ListForSender(distribution, name, scope)
            if listKey then
                MergeScores(listKey, name, rank, scores)
            end
        end
    elseif op == "sync" and distribution == "WHISPER" then
        local scope = message.scope
        local scores = ValidScores(message.scores)
        if (scope == "guild" or scope == "friends") and scores and ValidRank(rank) then
            local listKey = ListForSender(distribution, name, scope)
            if listKey == scope then
                MergeScores(listKey, name, rank, scores)
            end
        end
    end
end

-- Public API

function HighScores.SubmitScore(modeKey, value)
    if not ValidValue(modeKey, value) then
        return false
    end
    local scoreList = ns.db.char.scoreList
    scoreList.best = scoreList.best or {}
    local previousBest = math.max(scoreList.best[modeKey] or 0, ns.db.char.stats[modeKey].score or 0)
    local name, rank = PlayerName(), PlayerRank()
    local beatOther = false
    for _, listKey in ipairs(LISTS) do
        local _, beat = MergeEntry(scoreList[listKey][modeKey], modeKey, name, rank, value)
        beatOther = beatOther or beat
    end
    -- The caller may already have stored this score as the new best in stats.
    if value > (scoreList.best[modeKey] or 0) then
        scoreList.best[modeKey] = value
    end
    if value >= previousBest and value > 0 and ns.db.profile.publishScores then
        pendingPublish[modeKey] = value
        if not publishTimer then
            publishTimer = C_Timer.NewTimer(PUBLISH_DELAY, FlushPublish)
        end
    end
    return beatOther
end

function HighScores.GetList(listKey, modeKey)
    return GetLists(listKey)[modeKey]
end

function HighScores.CountCompetitors(listKey)
    local seen, count = {}, 0
    local lists = GetLists(listKey)
    for _, modeKey in ipairs(MODES) do
        for _, entry in ipairs(lists[modeKey]) do
            if IsRealPlayer(entry.name) and not seen[entry.name] then
                seen[entry.name] = true
                count = count + 1
            end
        end
    end
    return count
end

function HighScores.Publish(channel)
    local distribution
    if channel == "GUILD" then
        distribution = IsInGuild() and "GUILD"
    elseif channel == "RAID" then
        if IsInRaid(LE_PARTY_CATEGORY_HOME) then
            distribution = "RAID"
        elseif IsInRaid(LE_PARTY_CATEGORY_INSTANCE) then
            distribution = "INSTANCE_CHAT"
        end
    elseif channel == "PARTY" then
        if IsInGroup(LE_PARTY_CATEGORY_HOME) then
            distribution = "PARTY"
        elseif IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
            distribution = "INSTANCE_CHAT"
        end
    end
    if not distribution then
        return
    end
    local rank = PlayerRank()
    for _, modeKey in ipairs(MODES) do
        local value = OwnBest(modeKey)
        if value > 0 then
            Send({ op = "score", mode = modeKey, value = value, rank = rank }, distribution, nil, "NORMAL")
        end
    end
end

ns.RegisterEnabler("HighScores", function()
    Bejeweled:RegisterComm(C.COMM_PREFIX, OnCommReceived)
    events:RegisterEvent("FRIENDLIST_UPDATE", function()
        friendsLoaded = true
        ScheduleScrub()
    end)
    events:RegisterEvent("GUILD_ROSTER_UPDATE", function()
        guildRoster = nil
        ScheduleScrub()
    end)
    events:RegisterEvent("PLAYER_GUILD_UPDATE", function()
        guildRoster = nil
        ScheduleScrub()
    end)
    events:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED", function()
        -- Fires before a restriction starts and after it ends; the next tick sees the new state.
        C_Timer.After(0, FlushOutbox)
    end)
    C_FriendList.ShowFriends()
    if IsInGuild() then
        C_GuildInfo.GuildRoster()
    end
    C_Timer.After(SYNC_DELAY, RequestSync)
end)
