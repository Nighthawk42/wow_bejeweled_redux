local _, ns = ...
local Bejeweled = ns.addon
local C = ns.C

-- Board logic: spawning gems, finding and marking matches, special gems (power gems and
-- hypercubes), hint search, level up and the board wipe.

local BOARD_ROWS, BOARD_COLS = C.BOARD_ROWS, C.BOARD_COLS
local GEM_HALF_WIDTH, GEM_HALF_HEIGHT = C.GEM_HALF_WIDTH, C.GEM_HALF_HEIGHT
local NUM_GEM_COLORS, GEM_HYPERCUBE = C.NUM_GEM_COLORS, C.GEM_HYPERCUBE
local GEM_COLOR_NAMES = C.GEM_COLOR_NAMES
local GEM_SPIN_TEXCOORDS = C.GEM_SPIN_TEXCOORDS
local NEIGHBOR_OFFSETS = C.NEIGHBOR_OFFSETS
local MATCH_VERTICAL, MATCH_HORIZONTAL = C.MATCH_VERTICAL, C.MATCH_HORIZONTAL
local MODE_CLASSIC, MODE_POINT_MULTIPLIER = C.MODE_CLASSIC, C.MODE_POINT_MULTIPLIER
local random, floor = math.random, math.floor

local function hasColor(row, col, color)
    return row >= 1 and row <= BOARD_ROWS and col >= 1 and col <= BOARD_COLS and ns.board[row][col].contents == color
end

-- Would placing color at (row, col) complete a run of three with the gems already there?
local function wouldMatch(row, col, color)
    return (hasColor(row, col - 1, color) and hasColor(row, col - 2, color))
        or (hasColor(row, col + 1, color) and hasColor(row, col + 2, color))
        or (hasColor(row - 1, col, color) and hasColor(row - 2, col, color))
        or (hasColor(row + 1, col, color) and hasColor(row + 2, col, color))
        or (hasColor(row, col - 1, color) and hasColor(row, col + 1, color))
        or (hasColor(row - 1, col, color) and hasColor(row + 1, col, color))
end

-- avoidMatches: pick a color that does not complete a run (used for fresh boards).
-- Without it the call is a refill after a clear, which counts toward totalGemsMatched.
-- keepExisting: recolor only, without resetting the gem frame.
function ns.spawnRandomGem(col, row, avoidMatches, keepExisting)
    local gem = ns.board[row][col]
    if not keepExisting then
        ns.resetGem(gem, col, row)
    end
    gem.contents = 0
    local color = random(1, NUM_GEM_COLORS)
    if avoidMatches then
        for _ = 1, NUM_GEM_COLORS do
            if not wouldMatch(row, col, color) then
                break
            end
            color = color % NUM_GEM_COLORS + 1
        end
    end
    gem.contents = color
    gem.texture:SetTexture(ns.Textures.Path("gem", GEM_COLOR_NAMES[color]))
    gem.texture:SetTexCoord(unpack(GEM_SPIN_TEXCOORDS[1]))
    gem.highlight:SetTexture(ns.Textures.Path("shine", GEM_COLOR_NAMES[color]))
    gem.highlight:SetTexCoord(0, 0, 0, 0)
    if not avoidMatches then
        local stats = ns.db.char.stats
        stats.totalGemsMatched = stats.totalGemsMatched + 1
    end
end

function ns.refreshGemTexture(gem)
    local contents = gem.contents
    if contents and contents > 0 and contents <= NUM_GEM_COLORS then
        local colorName = GEM_COLOR_NAMES[contents]
        gem.texture:SetTexture(ns.Textures.Path("gem", colorName))
        gem.texture:SetTexCoord(unpack(GEM_SPIN_TEXCOORDS[1]))
        gem.highlight:SetTexture(ns.Textures.Path("shine", colorName))
        gem.highlight:SetTexCoord(0, 0, 0, 0)
        gem.glow:SetTexture(ns.Textures.Path("glow", colorName))
        gem.glow:SetTexCoord(0, 1, 0, 1)
    elseif contents == GEM_HYPERCUBE then
        Bejeweled.animator:CreateHyperGem(gem)
    else
        gem.texture:SetTexCoord(0, 0, 0, 0)
        gem.glow:SetTexCoord(0, 0, 0, 0)
    end
end

-- Special gems are created on the gem the player swapped, unless force is set.
local function isSwappedGem(gem)
    local selected = ns.game.selectedJewel
    return selected and (selected == gem or selected.swapJewel == gem)
end

function ns.tryCreatePowerGem(gem, force)
    if not (isSwappedGem(gem) or force) then
        return nil
    end
    if not gem.explode then
        local animator = Bejeweled.animator
        gem.bigStarSpawn = animator:CreateBigStar(0, 0, gem)
        gem.bigStarSpawn:Hide()
        animator:Add(gem.bigStarSpawn)
        local stats = ns.db.char.stats
        stats.totalPowerGems = stats.totalPowerGems + 1
        local const = Bejeweled.const
        if not ns.db.char.skill["gainAchieve" .. const.SKILL_ACHIEVE3A] and stats.totalPowerGems >= 100 then
            Bejeweled.skillBar:CheckSkill(const.SKILLTYPE_ACHIEVEMENT, const.SKILL_ACHIEVE3A)
        end
    end
    return true
end

function ns.tryCreateHyperCube(gem, force)
    if not (isSwappedGem(gem) or force) or gem.bigStar then
        return nil
    end
    gem.hyperGemSpawn = true
    gem.fxType = C.FX_DESTROY
    Bejeweled.animator:Add(gem)
    local stats = ns.db.char.stats
    stats.totalHyperGems = stats.totalHyperGems + 1
    ns.awardMatchScore(0, gem, GEM_HYPERCUBE, nil, nil, 0, nil, nil, true)
    local const = Bejeweled.const
    if not ns.db.char.skill["gainAchieve" .. const.SKILL_ACHIEVE5A] and stats.totalHyperGems >= 50 then
        Bejeweled.skillBar:CheckSkill(const.SKILLTYPE_ACHIEVEMENT, const.SKILL_ACHIEVE5A)
    end
    return true
end

-- Returns 1 if the gem is a power gem (it will explode), else 0.
function ns.markGemDestroyed(gem, axis)
    if axis == MATCH_HORIZONTAL then
        gem.markX = true
    else
        gem.markY = true
    end
    if gem.bigStar then
        gem.explode = 1
        ns.game.explosions = ns.game.explosions + 1
    end
    gem.fxType = C.FX_DESTROY
    gem.fxFrame = 1
    gem.highlight:SetAlpha(0)
    Bejeweled.animator:Add(gem)
    return gem.explode or 0
end

-- Tries every adjacent swap; returns a gem that is part of a valid move, or nil when
-- no moves are left. A hypercube always counts as a move.
function ns.findHintGem()
    local board = ns.board
    for row = 1, BOARD_ROWS do
        for col = 1, BOARD_COLS do
            for dir = 1, 4 do
                local swapCol = col + NEIGHBOR_OFFSETS[dir][1]
                local swapRow = row + NEIGHBOR_OFFSETS[dir][3]
                if swapCol > 0 and swapCol <= BOARD_COLS and swapRow > 0 and swapRow <= BOARD_ROWS then
                    local hintGem = board[row][col]
                    local found = hintGem.contents == GEM_HYPERCUBE
                    if board[swapRow][swapCol].contents ~= 0 then
                        board[row][col] = board[swapRow][swapCol]
                        board[swapRow][swapCol] = hintGem
                        local color = board[row][col].contents
                        local left, right, top, bottom = col, col, row, row
                        while
                            left > 1
                            and board[row][left - 1].contents ~= 0
                            and board[row][left - 1].contents == color
                        do
                            left = left - 1
                        end
                        while
                            right < BOARD_COLS
                            and board[row][right + 1].contents ~= 0
                            and board[row][right + 1].contents == color
                        do
                            right = right + 1
                        end
                        while top > 1 and board[top - 1][col].contents ~= 0 and board[top - 1][col].contents == color do
                            top = top - 1
                        end
                        while
                            bottom < BOARD_ROWS
                            and board[bottom + 1][col].contents ~= 0
                            and board[bottom + 1][col].contents == color
                        do
                            bottom = bottom + 1
                        end
                        hintGem = board[row][col]
                        board[row][col] = board[swapRow][swapCol]
                        board[swapRow][swapCol] = hintGem
                        if right - left >= 2 or bottom - top >= 2 then
                            found = true
                        end
                    end
                    if found then
                        return hintGem
                    end
                end
            end
        end
    end
end

-- Detonates a hypercube: shatters it and sends lightning to the first gem of the color it
-- was swapped with; the animator chains the rest of that color from there.
function ns.triggerHyperCube(hyperGem)
    local animator = Bejeweled.animator
    local board = ns.board
    local targetColor = hyperGem.hyperGemContents
    animator:CreateShardSpawn(0, 0, hyperGem, targetColor, 0, 0)
    ns.awardMatchScore(1, hyperGem, targetColor, nil, true, -1, true)
    hyperGem.hyperGemTrigger = nil
    hyperGem.contents = 0
    hyperGem.fxType = C.FX_DONE
    if hyperGem.bigStar then
        hyperGem.bigStar.explode = 1
        hyperGem.fxType = C.FX_DESTROY
        animator:Add(hyperGem)
        hyperGem.fxFrame = 1
        hyperGem.highlight:SetAlpha(0)
    end
    local targetGem
    for row = 1, BOARD_ROWS do
        for col = 1, BOARD_COLS do
            if board[row][col].contents == targetColor then
                targetGem = board[row][col]
                break
            end
        end
        if targetGem then
            break
        end
    end
    if targetGem then
        targetGem.hyperGemTrigger = true
        targetGem.hyperGemContents = targetColor
        targetGem.fxType = C.FX_DESTROY
        animator:Add(targetGem)
        animator:Add(
            animator:CreateLightning(
                hyperGem.x + GEM_HALF_WIDTH,
                hyperGem.y + GEM_HALF_HEIGHT,
                targetGem.x + GEM_HALF_WIDTH,
                targetGem.y + GEM_HALF_HEIGHT,
                targetColor
            )
        )
    end
    hyperGem.hyperGemContents = nil
end

-- Scans for runs of three or more. A run that crosses another run of the same color
-- (L/T shape) is scored as one match centered on the crossing gem. Marks the gems
-- destroyed, creates power gems (4-runs, short crosses) and hypercubes (5+), awards
-- score and updates cascade stats. Returns true if anything matched.
function ns.findMatches()
    local board, game = ns.board, ns.game
    local stats = ns.db.char.stats
    local anyMatch
    for row = 1, BOARD_ROWS do
        for col = 1, BOARD_COLS do
            local color = board[row][col].contents
            if color ~= 0 and color ~= GEM_HYPERCUBE then
                local cascadeCount = 0
                local runLength = 0
                local explodeCount, powerGemMade, hyperCubeMade, hyperMaxPos
                local crossCol, crossRow, crossIsLong

                -- Vertical run down from (row, col), with a horizontal cross.
                if row < BOARD_ROWS then
                    local leftCount, rightCount
                    for scanRow = row, BOARD_ROWS do
                        local cellGem = board[scanRow][col]
                        if cellGem.contents == color and not cellGem.markY then
                            runLength = runLength + 1
                        else
                            break
                        end
                        if not crossCol then
                            leftCount, rightCount = 0, 0
                            for rightCol = col + 1, BOARD_COLS do
                                if board[scanRow][rightCol].contents ~= color then
                                    break
                                end
                                rightCount = rightCount + 1
                            end
                            for leftCol = col - 1, 1, -1 do
                                if board[scanRow][leftCol].contents ~= color then
                                    break
                                end
                                leftCount = leftCount + 1
                            end
                            if rightCount + leftCount > 1 then
                                crossRow = scanRow
                                crossCol = col
                            end
                        end
                    end
                    if runLength > 2 then
                        anyMatch = true
                        explodeCount = 0
                        for markRow = row, row + runLength - 1 do
                            explodeCount = explodeCount + ns.markGemDestroyed(board[markRow][col], MATCH_VERTICAL)
                        end
                        if crossCol then
                            for markCol = crossCol - leftCount, crossCol + rightCount do
                                explodeCount = explodeCount
                                    + ns.markGemDestroyed(board[crossRow][markCol], MATCH_HORIZONTAL)
                            end
                            if runLength > 4 or leftCount + rightCount > 3 then
                                crossIsLong = true
                            end
                            runLength = runLength + leftCount + rightCount
                        end
                        powerGemMade, hyperCubeMade = nil, nil
                        if runLength == 4 or (crossCol and not crossIsLong) then
                            if crossCol then
                                powerGemMade = ns.tryCreatePowerGem(board[crossRow][crossCol], true)
                            else
                                for runRow = row, row + runLength - 1 do
                                    powerGemMade = ns.tryCreatePowerGem(board[runRow][col]) or powerGemMade
                                end
                            end
                            if not powerGemMade then
                                powerGemMade = ns.tryCreatePowerGem(board[random(row, row + runLength - 1)][col], true)
                            end
                        elseif runLength >= 5 then
                            hyperMaxPos = crossIsLong and row or (row + runLength - 1)
                            if crossCol then
                                hyperCubeMade = ns.tryCreateHyperCube(board[crossRow][crossCol], true)
                            else
                                for runRow = row, row + runLength - 1 do
                                    hyperCubeMade = ns.tryCreateHyperCube(board[runRow][col]) or hyperCubeMade
                                end
                            end
                            if not hyperCubeMade then
                                ns.tryCreateHyperCube(board[random(row, hyperMaxPos)][col], true)
                            end
                        end
                        if crossCol then
                            ns.awardMatchScore(
                                runLength,
                                board[crossRow][crossCol],
                                color,
                                true,
                                nil,
                                explodeCount,
                                nil,
                                true
                            )
                        else
                            ns.awardMatchScore(runLength, board[row][col], color, powerGemMade, nil, explodeCount)
                        end
                        cascadeCount = cascadeCount + runLength
                    end
                end

                -- Horizontal run right from (row, col), with a vertical cross.
                runLength = 0
                if col < BOARD_COLS then
                    crossCol, crossRow, crossIsLong = nil, nil, nil
                    local aboveCount, belowCount
                    for scanCol = col, BOARD_COLS do
                        local cellGem = board[row][scanCol]
                        if cellGem.contents == color and not cellGem.markX then
                            runLength = runLength + 1
                        else
                            break
                        end
                        if not crossRow then
                            belowCount, aboveCount = 0, 0
                            for belowRow = row + 1, BOARD_ROWS do
                                if board[belowRow][scanCol].contents ~= color then
                                    break
                                end
                                belowCount = belowCount + 1
                            end
                            for aboveRow = row - 1, 1, -1 do
                                if board[aboveRow][scanCol].contents ~= color then
                                    break
                                end
                                aboveCount = aboveCount + 1
                            end
                            if aboveCount + belowCount > 1 then
                                crossCol = scanCol
                                crossRow = row
                            end
                        end
                    end
                    if runLength > 2 then
                        anyMatch = true
                        explodeCount = 0
                        for markCol = col, col + runLength - 1 do
                            explodeCount = explodeCount + ns.markGemDestroyed(board[row][markCol], MATCH_HORIZONTAL)
                        end
                        if crossRow then
                            for markRow = crossRow - aboveCount, crossRow + belowCount do
                                explodeCount = explodeCount
                                    + ns.markGemDestroyed(board[markRow][crossCol], MATCH_VERTICAL)
                            end
                            if runLength > 4 or aboveCount + belowCount > 3 then
                                crossIsLong = true
                            end
                            runLength = runLength + aboveCount + belowCount
                        end
                        powerGemMade, hyperCubeMade = nil, nil
                        if runLength == 4 or (crossRow and not crossIsLong) then
                            if crossRow then
                                powerGemMade = ns.tryCreatePowerGem(board[crossRow][crossCol], true)
                            else
                                for runCol = col, col + runLength - 1 do
                                    powerGemMade = ns.tryCreatePowerGem(board[row][runCol]) or powerGemMade
                                end
                            end
                            if not powerGemMade then
                                powerGemMade = ns.tryCreatePowerGem(board[row][random(col, col + runLength - 1)], true)
                            end
                        elseif runLength >= 5 then
                            hyperMaxPos = crossIsLong and col or (col + runLength - 1)
                            if crossRow then
                                hyperCubeMade = ns.tryCreateHyperCube(board[crossRow][crossCol], true)
                            else
                                for runCol = col, col + runLength - 1 do
                                    hyperCubeMade = ns.tryCreateHyperCube(board[row][runCol]) or hyperCubeMade
                                end
                            end
                            if not hyperCubeMade then
                                ns.tryCreateHyperCube(board[row][random(col, hyperMaxPos)], true)
                            end
                        end
                        if crossRow then
                            ns.awardMatchScore(
                                runLength,
                                board[crossRow][crossCol],
                                color,
                                true,
                                nil,
                                explodeCount,
                                nil,
                                true
                            )
                        else
                            ns.awardMatchScore(runLength, board[row][col], color, powerGemMade, nil, explodeCount, true)
                        end
                        cascadeCount = cascadeCount + runLength
                    end
                end

                if cascadeCount > game.largestCascade then
                    game.largestCascade = cascadeCount
                end
                if cascadeCount > stats.largestCascade then
                    stats.largestCascade = cascadeCount
                end
                if cascadeCount > 2 then
                    stats.gemMatch[color] = stats.gemMatch[color] + 1
                end
            end
        end
    end
    return anyMatch
end

-- Launches every gem off the board (game over or level up).
function ns.blowAwayAllGems()
    local animator = Bejeweled.animator
    for row = 1, BOARD_ROWS do
        for col = 1, BOARD_COLS do
            local gem = ns.board[row][col]
            if gem.fxType ~= C.FX_HYPERCUBE then
                gem.fxType = C.FX_SPIN
            else
                gem.wasHyper = true
                gem.contents = 0
                gem.hyperGemContents = nil
            end
            gem.moving = C.MOVE_FLY_OFF
            gem.yVel = 4 - random(1, 5) / 2
            gem.xVel = (random(1, 11) - 6) / 2
            animator:Add(gem)
        end
    end
end

-- Raises the level: new point multiplier and target score, level/multiplier display,
-- highest-level stat and the level 10/15 skills.
function ns.levelUp()
    local game = ns.game
    game.pointMultiplier = MODE_POINT_MULTIPLIER[game.gameMode] + game.level * 0.5
    game.pointsToLevelUp = game.score + game.pointsToLevelUp + floor((500 + 150 * game.level) * game.pointMultiplier)
    Bejeweled.levelBar:SetMinMaxScore(game.score, game.pointsToLevelUp)
    if game.gameMode == MODE_CLASSIC then
        Bejeweled.levelText:SetText(game.level + 1)
    elseif math.fmod(game.level, 2) == 0 then
        Bejeweled.dataText:SetFormattedText("%d|cFF00FF00x", game.level)
    else
        Bejeweled.dataText:SetFormattedText("%.1f|cFF00FF00x", 1 + game.level * 0.5)
    end
    game.level = game.level + 1
    if game.statDB.highestLevel and game.level > game.statDB.highestLevel then
        game.statDB.highestLevel = game.level
    end
    if game.gameMode == MODE_CLASSIC then
        local const = Bejeweled.const
        if game.level == 10 then
            Bejeweled.skillBar:CheckSkill(const.SKILLTYPE_CLASSIC, const.SKILL_LEVEL10)
        end
        if game.level == 15 then
            Bejeweled.skillBar:CheckSkill(const.SKILLTYPE_CLASSIC, const.SKILL_LEVEL15)
        end
    end
    Bejeweled.levelBar:UpdateBar()
end
