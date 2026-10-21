local _, ns = ...
local Bejeweled = ns.addon
local C = ns.C

-- Match scoring: points per match (combo table, special-gem bonuses, mode multiplier,
-- level factor), match/combo skill checks, and the floating score and skill texts.

local GEM_WIDTH, GEM_HEIGHT, GEM_HALF_WIDTH = C.GEM_WIDTH, C.GEM_HEIGHT, C.GEM_HALF_WIDTH
local COMBO_POINTS = C.COMBO_POINTS
local MODE_POINT_MULTIPLIER = C.MODE_POINT_MULTIPLIER

-- explosions: number of power gems set off by this match (-1 for a hypercube trigger).
-- horizontal: the run goes along a row (text centered across it, else down a column).
-- centerOnGem: put the text on the gem itself (cross matches).
-- suppressText: no score text; used for hypercube creation (awards the 5-match skill).
function ns.awardMatchScore(
    matchLen,
    gem,
    textColor,
    isPower,
    isHyper,
    explosions,
    horizontal,
    centerOnGem,
    suppressText
)
    local game = ns.game
    if game.gameOver then
        return
    end
    local const = Bejeweled.const
    local skillBar = Bejeweled.skillBar
    local animator = Bejeweled.animator
    local skill = ns.db.char.skill
    local points = 0
    local skillGained = 0
    local oldRank = skill.rank
    if matchLen >= 3 then
        skillGained = skillGained + skillBar:CheckSkill(const.SKILLTYPE_MATCH, const.SKILL_MATCH3)
        game.combo = game.combo + 1
        local combo = game.combo
        if combo >= 2 then
            skillGained = skillGained + skillBar:CheckSkill(const.SKILLTYPE_COMBO, const.SKILL_COMBO2)
        end
        if combo >= 3 then
            skillGained = skillGained + skillBar:CheckSkill(const.SKILLTYPE_COMBO, const.SKILL_COMBO3)
        end
        if combo >= 4 then
            skillGained = skillGained + skillBar:CheckSkill(const.SKILLTYPE_COMBO, const.SKILL_COMBO4)
        end
        if combo >= 5 then
            skillGained = skillGained + skillBar:CheckSkill(const.SKILLTYPE_COMBO, const.SKILL_COMBO5)
        end
        points = COMBO_POINTS[math.min(combo, #COMBO_POINTS)]
    end
    if matchLen == 4 then
        points = points + 10
    elseif matchLen >= 5 then
        points = points + 20
    end
    if isPower then
        skillGained = skillGained + skillBar:CheckSkill(const.SKILLTYPE_MATCH, const.SKILL_MATCH4)
        points = points + 25
    end
    if isHyper then
        if explosions == 0 then
            points = points + 75
            Bejeweled.sound:Play("HyperDestroy")
        else
            points = points + 20
            Bejeweled.sound:Play("ElectroExplode")
        end
    end
    if explosions == 1 then
        points = points + 25
    elseif explosions > 1 then
        points = points + 10 * (explosions + 2)
    end
    points = points * MODE_POINT_MULTIPLIER[game.gameMode] * ((game.level + 1) / 2)

    local textX, textY = gem.x, gem.y
    if centerOnGem then
        textX = gem.x + GEM_HALF_WIDTH
    elseif horizontal == true then
        textX = textX + GEM_WIDTH * (matchLen / 2)
    else
        textY = textY + GEM_HEIGHT * (matchLen / 2)
        textX = textX + GEM_HALF_WIDTH
    end

    if suppressText then
        skillGained = skillGained + skillBar:CheckSkill(const.SKILLTYPE_MATCH, const.SKILL_MATCH5)
    else
        local floatText = animator:CreateFloatingText(textX, textY, math.floor(points), textColor)
        if matchLen >= 3 then
            floatText.comboSound = game.combo
        end
        animator:Add(floatText)
    end
    if oldRank ~= skill.rank then
        animator:Add(
            animator:CreateFloatingText(
                textX - 20,
                textY - 20,
                "RANK UP: " .. const.skillDataRanks[skill.rank],
                7,
                true
            )
        )
    end
    -- One "+1 Skill" per point, each nudged 1px right so they stack visibly.
    for skillX = textX + 1, textX + skillGained do
        animator:Add(animator:CreateFloatingText(skillX, textY + 20, "+1 Skill", 3, true))
    end
end
