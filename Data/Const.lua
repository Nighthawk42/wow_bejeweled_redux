local _, ns = ...
local Bejeweled = ns.addon

-- Skill/achievement tables, large-text atlas coordinates and window fade presets.
Bejeweled.const = {}
Bejeweled.const.channels = { "GUILD", "PARTY", "RAID" }
Bejeweled.const.channelNames = { CHAT_MSG_GUILD, CHAT_MSG_PARTY, CHAT_MSG_RAID }
Bejeweled.const.dropInfo = {}
Bejeweled.const.skillDataNames =
    { "Match Gems", "Gem Cascades", "Gem Combos", "Classic", "Timed", "Fun Achievements", "Game Achievements" }
Bejeweled.const.skillDataRanks = { "Apprentice", "Journeyman", "Expert", "Artisan", "Master", "Grand Master" }
Bejeweled.const.skillData = {
    [1] = {
        [1] = { "Match 3 Gems", 0, 10, 20, 50 },
        [2] = { "Match 4 Gems (Create a |cFF0070DD[Power Gem]|r)", 50, 105, 150, 215 },
        [3] = { "Match 5 Gems (Create a |cFFA335EE[Hyper Cube]|r)", 150, 275, 380, 445 },
    },
    [2] = {
        [1] = { "Cause a x2 Cascade", 0, 25, 55, 75 },
        [2] = { "Cause a x3 Cascade", 40, 100, 160, 225 },
        [3] = { "Cause a x4 Cascade", 80, 125, 195, 280 },
        [4] = { "Cause a x5 Cascade", 125, 190, 265, 335 },
    },
    [3] = {
        [1] = { "Clear 10 Gems in one move", 115, 225, 300, 375 },
        [2] = { "Clear 15 Gems in one move", 150, 260, 345, 500 },
        [3] = { "Clear 20 Gems in one move", 225, 325, 420, 501 },
        [4] = { "Clear 25 Gems in one move", 300, 380, 500, 501 },
    },
    [4] = {
        [1] = { "Score 10,000 Points", 75, 150, 225, 300 },
        [2] = { "Survive to Level 10", 75, 150, 230, 325 },
        [3] = { "Survive 100 Moves", 60, 150, 230, 325 },
        [4] = { "Score 25,000 Points", 150, 280, 375, 500 },
        [5] = { "Survive to Level 15", 150, 280, 385, 500 },
        [6] = { "Score 50,000 Points", 225, 300, 420, 500 },
        [7] = { "Survive 250 Moves", 265, 375, 500, 501 },
        [8] = { "Score 75,000 Points", 300, 500, 501, 502 },
    },
    [5] = {
        [1] = { "Achieve a PPS of 250+ at end of game", 75, 150, 225, 300 },
        [2] = { "Achieve a PPS of 300+ at end of game", 150, 225, 375, 500 },
        [3] = { "Achieve a PPS of 350+ at end of game", 225, 300, 500, 501 },
    },
    [6] = {
        [1] = {
            "Die from falling damage",
            0,
            0,
            0,
            0,
            "Not Only Gems Fall",
            "Interface\\Icons\\spell_shadow_twistedfaith",
        },
        [2] = {
            "Join a Battleground Queue",
            0,
            0,
            0,
            0,
            "Queue Queue More",
            "Interface\\Icons\\achievement_bg_killxenemies_generalsroom",
        },
        [3] = { "Loot a rare item", 75, 75, 75, 75, "Blue Your Chance", "Interface\\Icons\\spell_frost_wizardmark" },
        [4] = { "Kill a critter", 75, 75, 75, 75, "Annoyed Grunt", "Interface\\Icons\\inv_jewelcrafting_crimsonhare" },
        [5] = { "Get resurrected", 75, 75, 75, 75, "i can haz rez?", "Interface\\Icons\\spell_holy_guardianspirit" },
        [6] = { "Loot an epic item", 150, 150, 150, 150, "Purple Reign", "Interface\\Icons\\inv_enchant_voidcrystal" },
        [7] = {
            "Say yes to a ready check",
            150,
            150,
            150,
            150,
            "Jewel of Denial",
            "Interface\\Icons\\spell_misc_emotionsad",
        },
        [8] = {
            "Die from combat damage",
            150,
            150,
            150,
            150,
            "Rest In Pieces",
            "Interface\\Icons\\spell_shadow_chilltouch",
        },
        [9] = {
            "Kill an elite monster",
            225,
            225,
            225,
            225,
            "ur so leet",
            "Interface\\Icons\\spell_shadow_deathscream",
        },
        [10] = {
            "Enter a raid instance",
            225,
            225,
            225,
            225,
            "Multitasking Mayhem",
            "Interface\\Icons\\achievement_dungeon_coablackdragonflight_normal",
        },
        [11] = {
            "Gain a new reputation level",
            225,
            225,
            225,
            225,
            "Mr. Friendly",
            "Interface\\Icons\\inv_misc_head_dragon_bronze",
        },
        [12] = {
            "Get an honorable kill",
            300,
            300,
            300,
            300,
            "Guilty, Your Honor",
            "Interface\\Icons\\ability_dualwieldspecialization",
        },
        [13] = {
            "Kill a rare spawn monster",
            300,
            300,
            300,
            300,
            "Rare For Art Thou?",
            "Interface\\Icons\\achievement_zone_stormpeaks_03",
        },
        [14] = {
            "Gain a new level on any character",
            375,
            375,
            375,
            375,
            "Movin' On Up",
            "Interface\\Icons\\achievement_level_80",
        },
        [15] = {
            "Win an Arena match",
            375,
            375,
            375,
            375,
            "Two Gems Enter, One Gem Leaves",
            "Interface\\Icons\\ability_warrior_offensivestance",
        },
    },
    [7] = {
        [1] = {
            "Beat another player's high score (Classic)",
            0,
            0,
            0,
            0,
            "Pain In The Classic",
            "Interface\\Icons\\achievement_pvp_p_14",
        },
        [2] = { "Clear 1,000 Gems", 75, 75, 75, 75, "Gem Collector", "Interface\\Icons\\inv_misc_coin_17" },
        [3] = {
            "Play 100 games between all characters",
            75,
            75,
            75,
            75,
            "Too Much Time On Your Hands",
            "Interface\\Icons\\inv_misc_map02",
        },
        [4] = {
            "Get a |cFF002AFF[Power Gem]|r total of 100+",
            150,
            150,
            150,
            150,
            "I've Got The Power!",
            "Interface\\Icons\\inv_misc_gem_03",
        },
        [5] = {
            "Beat another player's high score (Timed)",
            150,
            150,
            150,
            150,
            "What Time Do You Have?",
            "Interface\\Icons\\achievement_featsofstrength_gladiator_07",
        },
        [6] = {
            "75,000 points in a single game",
            225,
            225,
            225,
            225,
            "A True Master",
            "Interface\\Icons\\ability_mage_brainfreeze",
        },
        [7] = {
            "Play 1,000 games between all characters",
            225,
            225,
            225,
            225,
            "Truly Addicted",
            "Interface\\Icons\\achievement_bg_masterofallbgs",
        },
        [8] = {
            "Get a |cFFB300B3[Hyper Cube]|r total of 50+",
            300,
            300,
            300,
            300,
            "Hyperactive",
            "Interface\\Icons\\spell_holy_summonlightwell",
        },
        [9] = {
            "Compete with 10+ Friends",
            300,
            300,
            300,
            300,
            "Keep Your Friends Close",
            "Interface\\Icons\\achievement_reputation_08",
        },
        [10] = {
            "Complete all Achievements",
            375,
            375,
            375,
            375,
            "Master of All You Survey",
            "Interface\\Icons\\inv_misc_celebrationcake_01",
        },
        [11] = {
            "Compete with 10+ Guildies",
            375,
            375,
            375,
            375,
            "All In The Family",
            "Interface\\Icons\\achievement_reputation_02",
        },
    },
}
Bejeweled.const.skillDataColors = { { 1, 0.5, 0.25 }, { 1, 1, 0 }, { 0.25, 0.75, 0.25 }, { 0.3, 0.3, 0.3 } }
Bejeweled.const.SKILLTYPE_MATCH = 1
Bejeweled.const.SKILL_MATCH3 = 1
Bejeweled.const.SKILL_MATCH4 = 2
Bejeweled.const.SKILL_MATCH5 = 3
Bejeweled.const.SKILLTYPE_COMBO = 2
Bejeweled.const.SKILL_COMBO2 = 1
Bejeweled.const.SKILL_COMBO3 = 2
Bejeweled.const.SKILL_COMBO4 = 3
Bejeweled.const.SKILL_COMBO5 = 4
Bejeweled.const.SKILLTYPE_GEMCOMBO = 3
Bejeweled.const.SKILL_CLEAR10 = 1
Bejeweled.const.SKILL_CLEAR15 = 2
Bejeweled.const.SKILL_CLEAR20 = 3
Bejeweled.const.SKILL_CLEAR25 = 4
Bejeweled.const.SKILLTYPE_CLASSIC = 4
Bejeweled.const.SKILL_SCORE10K = 1
Bejeweled.const.SKILL_SCORE25K = 4
Bejeweled.const.SKILL_LEVEL10 = 2
Bejeweled.const.SKILL_MOVE100 = 3
Bejeweled.const.SKILL_LEVEL15 = 5
Bejeweled.const.SKILL_SCORE50K = 6
Bejeweled.const.SKILL_MOVE250 = 7
Bejeweled.const.SKILL_SCORE75K = 8
Bejeweled.const.SKILLTYPE_TIMED = 5
Bejeweled.const.SKILL_PPS350 = 1
Bejeweled.const.SKILL_PPS300 = 2
Bejeweled.const.SKILL_PPS250 = 3
Bejeweled.const.SKILLTYPE_FUN = 6
Bejeweled.const.SKILL_FUNRANK1A = 1
Bejeweled.const.SKILL_FUNRANK1B = 2
Bejeweled.const.SKILL_FUNRANK2A = 3
Bejeweled.const.SKILL_FUNRANK2B = 4
Bejeweled.const.SKILL_FUNRANK2C = 5
Bejeweled.const.SKILL_FUNRANK3A = 6
Bejeweled.const.SKILL_FUNRANK3B = 7
Bejeweled.const.SKILL_FUNRANK3C = 8
Bejeweled.const.SKILL_FUNRANK4A = 9
Bejeweled.const.SKILL_FUNRANK4B = 10
Bejeweled.const.SKILL_FUNRANK4C = 11
Bejeweled.const.SKILL_FUNRANK5A = 12
Bejeweled.const.SKILL_FUNRANK5B = 13
Bejeweled.const.SKILL_FUNRANK6A = 14
Bejeweled.const.SKILL_FUNRANK6B = 15
Bejeweled.const.SKILLTYPE_ACHIEVEMENT = 7
Bejeweled.const.SKILL_ACHIEVE1A = 1
Bejeweled.const.SKILL_ACHIEVE2A = 2
Bejeweled.const.SKILL_ACHIEVE2B = 3
Bejeweled.const.SKILL_ACHIEVE3A = 4
Bejeweled.const.SKILL_ACHIEVE3B = 5
Bejeweled.const.SKILL_ACHIEVE4A = 6
Bejeweled.const.SKILL_ACHIEVE4B = 7
Bejeweled.const.SKILL_ACHIEVE5A = 8
Bejeweled.const.SKILL_ACHIEVE5B = 9
Bejeweled.const.SKILL_ACHIEVE6A = 10
Bejeweled.const.SKILL_ACHIEVE6B = 11
Bejeweled.const.largeText = {
    ["Go"] = { 135, 76, 0, 0.263, 0, 0.296, 224 / 255, 142 / 255, 254 / 255 },
    ["3"] = { 36, 55, 0.637, 0.706, 0.785, 1, 225 / 255, 32 / 255, 38 / 255 },
    ["2"] = { 40, 55, 0.479, 0.556, 0.344, 0.557, 192 / 255, 189 / 255, 24 / 255 },
    ["1"] = { 25, 55, 0.43, 0.478, 0.344, 0.557, 54 / 255, 255 / 255, 54 / 255 },
    ["Time's up"] = { 155, 40, 0.264, 0.565, 0.16, 0.314, 223 / 255, 0, 0 },
    ["No more moves"] = { 295, 41, 0.264, 0.839, 0, 0.158, 223 / 255, 0, 0 },
    ["Level up"] = { 220, 56, 0, 0.429, 0.341, 0.557, 102 / 255, 197 / 255, 254 / 255 },
    ["Bejeweled"] = { 285, 59, 0, 0.555, 0.559, 0.786, 1, 1, 1 },
    ["Multiplier up"] = { 313, 54, 0, 0.611, 0.79, 1, 102 / 255, 197 / 255, 254 / 255 },
    ["Strip"] = { 448, 82, 0, 0.622, 0.32, 0.336, 1, 1, 1 },
    ["Popcap"] = { 100, 100, 0.715, 0.85, 0.161, 0.431, 1, 1, 1 },
    ["Tutorial_1"] = { 150, 83, 0.708, 1, 0.677, 1, 1, 1, 1 },
    ["Tutorial_2"] = { 152, 76, 1, 0, 0.852, 0, 1, 0.592, 0.852, 0.592, 1, 1, 1 },
    ["Tutorial_3"] = { 151, 62, 0.557, 0.851, 0.434, 0.674, 1, 1, 1 },
}
Bejeweled.const.windowFadeOut = { mode = "OUT", timeToFade = 0.5, startAlpha = 1, endAlpha = 0.3 }
Bejeweled.const.windowFadeIn = { mode = "IN", timeToFade = 0.15, startAlpha = 0.3, endAlpha = 1 }
Bejeweled.const.windowGameOverFadeOut = {
    mode = "OUT",
    timeToFade = 5,
    startAlpha = 1,
    endAlpha = 0,
    finishedFunc = function()
        if Bejeweled.const.windowGameOverFadeOut.timeToFade == -1 then
            Bejeweled.const.windowGameOverFadeOut.timeToFade = 5
            Bejeweled.window:Show()
            Bejeweled.window:SetAlpha(ns.db.profile.gameAlpha)
        else
            Bejeweled.window:Hide()
        end
        Bejeweled.window.hiding = nil
    end,
}
