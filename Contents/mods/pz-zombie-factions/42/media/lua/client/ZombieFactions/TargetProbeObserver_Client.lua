require "ZombieFactions/Assignment"
require "ZombieFactions/ClientCombatController"
local CombatController = ZombieFactions.ClientCombatController

local MODULE = "ZombieFactions"
local GRANT_COMMAND = "TargetProbeInstruction"
local RELEASE_COMMAND = "TargetProbeRelease"
local REACQUIRE_COMMAND = "TargetProbeReacquire"
local DECLINE_COMMAND = "TargetProbeDecline"

-- Grants are issued within a second or two of a spawn, so this window overlaps the
-- period when a newly created zombie is still reaching the client. At 90 ticks it
-- expired in roughly 1.5 seconds and lost grants to ordinary replication delay. The
-- decline below makes a timeout recoverable; a longer window makes it rarer.
local RESOLVE_RETRY_TICKS = 300
local RESOLVE_SCAN_INTERVAL_TICKS = 5
local PATH_REFRESH_INTERVAL_TICKS = 300
local PATH_REFRESH_MOVEMENT = 0.75
local CLIENT_TICKS_PER_SECOND = 60
local MAX_TRACK_TICKS = 60 * CLIENT_TICKS_PER_SECOND
local MIN_SAFE_TARGET_DISTANCE = 0.10
local ENGAGEMENT_DISTANCE = 1.20
local CONTACT_DISTANCE = 0.50
local MELEE_COMMITMENT_DISTANCE = 0.65
local APPROACH_SLOT_COUNT = 24
local APPROACH_INNER_RADIUS = 0.25
local APPROACH_OUTER_RADIUS = 0.40
local NO_PROGRESS_BASE_TICKS = 5 * CLIENT_TICKS_PER_SECOND
local NO_PROGRESS_STAGGER_TICKS = 2 * CLIENT_TICKS_PER_SECOND
local PROGRESS_DISTANCE = 0.35
local SPEED = ZombieFactions.SpeedType
local SPRINT_VARIABLE = "ZombieFactionsSprint"
local SPRINT_PLAYED_VARIABLE = "ZombieFactionsSprintPlayed"
local SPRINT_LOG_INTERVAL_TICKS = 2 * CLIENT_TICKS_PER_SECOND
local TRAVEL_SAMPLE_MAX_GAP_SECONDS = 0.5
local TRAVEL_PRUNE_INTERVAL_PASSES = 50
-- Sprint is dropped this far out so the last stretch is walked.
--
-- The v0.0.42 run validated the approach at 2.50: melee authorisation began
-- happening at an average pair distance of 0.51-0.54 tiles, comfortably inside
-- the commitment band the pair had previously been skipping straight past.
-- Because the brake fires on the first pass at or inside this distance and a
-- converging pair closes ~0.68 tiles per pass, the observed brake landed at
-- 2.08-2.33 rather than at the constant itself. Shortened to 2.00 on operator
-- judgement that the deceleration runway looked longer than it needed to be.
--
-- The v0.0.43 run at 2.00 measured the brake landing at 1.66, melee authorisation
-- at 0.50, and zero overshoots, so braking is working. Shortened again to 1.75 on
-- the same judgement, which should put the observed brake near 1.4. Note that
-- authorisation is already arriving at the bottom of the 0.50-0.65 commitment
-- band, so there is less headroom left than the clean counters suggest: if
-- sprintMeleeAuths falls or sprintOvershoots rises, this has gone too far.
local SPRINT_BRAKE_DISTANCE = 1.75

local pending = {}
local tracked = {}

print("[ZombieFactions] Client target observer loaded v0.0.54")

local function print(message)
    CombatController.detail(message)
end

local function safeCall(default, fn)
    local ok, value = pcall(fn)
    if ok and value ~= nil then return value end
    return default
end

local function zombieOnlineId(zombie)
    return tonumber(safeCall(-1, function()
        return zombie:getOnlineID()
    end)) or -1
end

local function ownerUsername(zombie)
    local ownerPlayer = safeCall(nil, function()
        return zombie:getOwnerPlayer()
    end)
    if not ownerPlayer then return "none" end

    return tostring(safeCall("unknown", function()
        return ownerPlayer:getUsername()
    end))
end

local function isRemoteZombie(zombie)
    return safeCall(false, function()
        return zombie:isRemoteZombie()
    end) == true
end

local function isDead(zombie)
    return safeCall(true, function()
        return zombie:isDead()
    end) == true
end

local function currentTarget(zombie)
    return safeCall(nil, function()
        return zombie:getTarget()
    end)
end

local function targetOnlineId(target)
    if not target then return -1 end
    local isZombie = safeCall(false, function()
        return target:isZombie()
    end) == true
    if not isZombie then return -1 end
    return tonumber(safeCall(-1, function()
        return target:getOnlineID()
    end)) or -1
end

local function zombieState(zombie)
    return tostring(safeCall("unknown", function()
        return zombie:getRealState()
    end))
end

local function zombieSpeedType(zombie)
    return tonumber(safeCall(-1, function()
        return zombie:getSpeedType()
    end)) or -1
end

local function zombieWalkType(zombie)
    return tostring(safeCall("", function()
        return zombie:getWalkType()
    end) or "")
end

local function variableBool(zombie, name)
    return safeCall(false, function()
        return zombie:getVariableBoolean(name)
    end) == true
end

local function isCrawling(zombie)
    return safeCall(false, function()
        return zombie:isCrawling()
    end) == true
end

-- Sprint locomotion is only ever requested for a zombie the engine already
-- classifies as a sprinter and which is upright. The mod never changes speed
-- type, walk type, running state, or any shipped movement value; it only sets
-- the one condition its own animation node matches on.
local function isSprintEligible(zombie)
    return zombieSpeedType(zombie) == SPEED.SPRINTER and not isCrawling(zombie)
end

local function setSprintIntent(record, active)
    local subject = record.subject
    if not subject then return end

    if active then
        if record.sprintActive then return end
        local ok = safeCall(false, function()
            subject:setVariable(SPRINT_VARIABLE, true)
            return true
        end)
        if not ok then
            CombatController.increment("sprintVariableErrors")
            return
        end
        record.sprintActive = true
        record.sprintLogCountdown = 0
        CombatController.increment("sprintActivations")
        return
    end

    if not record.sprintActive then return end
    local ok = safeCall(false, function()
        subject:setVariable(SPRINT_VARIABLE, false)
        subject:setVariable(SPRINT_PLAYED_VARIABLE, false)
        return true
    end)
    if not ok then CombatController.increment("sprintVariableErrors") end
    record.sprintActive = false
    CombatController.increment("sprintClears")
end

-- Ground truth for "did it actually go faster": planar tiles covered per second,
-- bucketed by speed class so a shambler in the same run is a directly comparable
-- control.
--
-- Sampling is keyed on the zombie rather than on a grant, and measures only while
-- the engine reports the zombie as moving. Both are deliberate. The v0.0.40 run
-- produced no control at all because it sampled the granted attacker only, and a
-- defender that never pursues never holds a grant; sampling both sides of every
-- tracked pair means any moving shambler contributes a baseline. Gating on actual
-- movement keeps the figure comparable, since a stationary zombie would otherwise
-- drag its bucket toward zero for reasons that have nothing to do with speed.
local travelSamples = {}

local function sampleZombieTravel(zombie, stepTicks)
    if not zombie then return end
    local onlineId = zombieOnlineId(zombie)
    if onlineId == -1 then return end

    local pass = CombatController.passSequence
    local prior = travelSamples[onlineId]
    if prior and prior.pass == pass then return end

    local moving = variableBool(zombie, "bMoving")
    local x = safeCall(nil, function() return zombie:getX() end)
    local y = safeCall(nil, function() return zombie:getY() end)
    if not moving or x == nil or y == nil then
        travelSamples[onlineId] = nil
        return
    end

    if prior then
        local elapsed = (pass - prior.pass) * stepTicks / CLIENT_TICKS_PER_SECOND
        -- Only consecutive observations describe a real displacement; a longer gap
        -- means the zombie was untracked or stationary in between.
        if elapsed > 0 and elapsed <= TRAVEL_SAMPLE_MAX_GAP_SECONDS then
            local dx = x - prior.x
            local dy = y - prior.y
            local bucket = isSprintEligible(zombie) and "sprint" or "shambler"
            CombatController.increment(bucket .. "TravelTiles", math.sqrt(dx * dx + dy * dy))
            CombatController.increment(bucket .. "TravelSeconds", elapsed)
            CombatController.increment(bucket .. "TravelSamples")
        end
    end

    travelSamples[onlineId] = {x = x, y = y, pass = pass}
end

local function pruneTravelSamples()
    local pass = CombatController.passSequence
    if pass % TRAVEL_PRUNE_INTERVAL_PASSES ~= 0 then return end
    for onlineId, entry in pairs(travelSamples) do
        if pass - entry.pass > TRAVEL_PRUNE_INTERVAL_PASSES then
            travelSamples[onlineId] = nil
        end
    end
end

-- The animation node sets its own variable once per loop of the clip. Counting
-- loops against the time sprint intent was held gives a rate that reads the same
-- way regardless of how often we sample: roughly one to two loops per second means
-- the node is playing, and zero means it never won selection. The v0.0.40 build
-- counted raw hits and misses instead, which made a healthy node look like it was
-- failing five times out of six purely because we polled faster than it looped.
local function sampleSprintNode(record)
    local subject = record.subject
    if variableBool(subject, SPRINT_PLAYED_VARIABLE) then
        CombatController.increment("sprintNodeLoops")
        safeCall(false, function()
            subject:setVariable(SPRINT_PLAYED_VARIABLE, false)
            return true
        end)
        return true
    end
    return false
end

local function isAttacking(zombie, target)
    if not zombie or not target then return false end
    return safeCall(false, function()
        return zombie:isZombieAttacking(target)
    end) == true
end

local function distanceBetween(a, b)
    if not a or not b then return math.huge end
    local dx = a:getX() - b:getX()
    local dy = a:getY() - b:getY()
    return math.sqrt(dx * dx + dy * dy)
end

local function isZombieTarget(target)
    if not target then return false end
    return safeCall(false, function()
        return target:isZombie()
    end) == true
end

local function isTraversalState(state)
    state = string.lower(tostring(state or ""))
    return string.find(state, "climb", 1, true) ~= nil
        or string.find(state, "fence", 1, true) ~= nil
        or string.find(state, "window", 1, true) ~= nil
        or string.find(state, "vault", 1, true) ~= nil
end

local function isNativeCombatOrReactionState(state)
    state = string.lower(tostring(state or ""))
    return string.find(state, "attack", 1, true) ~= nil
        or string.find(state, "lunge", 1, true) ~= nil
        or string.find(state, "hitreaction", 1, true) ~= nil
        or string.find(state, "stagger", 1, true) ~= nil
        or string.find(state, "fall", 1, true) ~= nil
        or string.find(state, "knock", 1, true) ~= nil
        or string.find(state, "death", 1, true) ~= nil
end

local function safetyReason(subject, candidate)
    local subjectState = zombieState(subject)
    if isTraversalState(subjectState) then
        return "subject-traversal:" .. subjectState
    end
    if isNativeCombatOrReactionState(subjectState) then
        return "subject-native-state:" .. subjectState
    end
    local candidateState = zombieState(candidate)
    if isTraversalState(candidateState) then
        return "candidate-traversal:" .. candidateState
    end
    if isNativeCombatOrReactionState(candidateState) then
        return "candidate-native-state:" .. candidateState
    end
    if distanceBetween(subject, candidate) < MIN_SAFE_TARGET_DISTANCE then
        return "close-overlap"
    end
    return nil
end

local function applySafetyInterlock(record)
    local reason = safetyReason(record.subject, record.candidate)
    if reason then
        setSprintIntent(record, false)
        local cleared = false
        if isZombieTarget(currentTarget(record.subject)) then
            cleared = pcall(function() record.subject:setTarget(nil) end)
        end
        if record.safetyReason ~= reason then
            CombatController.increment("safetySuspends")
            print(string.format(
                "[ZombieFactions][%s][OWNER_PROBE] phase=safety-suspend reason=%s subject=%d candidate=%d subjectState=%s candidateState=%s distance=%.3f targetCleared=%s",
                record.runId,
                reason,
                record.subjectId,
                record.candidateId,
                zombieState(record.subject),
                zombieState(record.candidate),
                distanceBetween(record.subject, record.candidate),
                tostring(cleared)
            ))
        end
        record.safetyReason = reason
        record.controlMode = "suspended"
        record.pathRefreshCountdown = PATH_REFRESH_INTERVAL_TICKS
        return true
    end

    if record.safetyReason then
        print(string.format(
            "[ZombieFactions][%s][OWNER_PROBE] phase=safety-resume previousReason=%s subject=%d candidate=%d distance=%.3f",
            record.runId,
            record.safetyReason,
            record.subjectId,
            record.candidateId,
            distanceBetween(record.subject, record.candidate)
        ))
        record.safetyReason = nil
        CombatController.increment("safetyResumes")
        record.controlMode = nil
        record.pathRefreshCountdown = 0
    end
    return false
end

local function findZombieByOnlineId(onlineId)
    return CombatController.findZombie(onlineId)
end

local function noteProgress(record, state, attacking, distance)
    if attacking or (state ~= "idle" and state ~= "unknown") then
        record.aiProgressObserved = true
    end

    if record.initialDistance ~= math.huge and distance ~= math.huge and distance < record.initialDistance - 0.15 then
        record.movementObserved = true
    end
end

local function printSnapshot(record, phase, force)
    if not CombatController.verbose then return end
    local subject = record.subject
    local candidate = record.candidate
    local target = currentTarget(subject)
    local targetId = targetOnlineId(target)
    local state = zombieState(subject)
    local attacking = isAttacking(subject, candidate)
    local subjectDead = isDead(subject)
    local candidateDead = isDead(candidate)
    local owner = ownerUsername(subject)
    local remote = isRemoteZombie(subject)
    local resolvedFaction = ZombieFactions.getZombieFaction(subject)
    local distance = distanceBetween(subject, candidate)

    noteProgress(record, state, attacking, distance)

    local signature = table.concat({
        tostring(targetId),
        state,
        tostring(attacking),
        tostring(subjectDead),
        tostring(candidateDead),
        owner,
        tostring(remote),
        tostring(resolvedFaction),
        tostring(record.aiProgressObserved),
        tostring(record.movementObserved),
        tostring(record.controlMode or "none"),
    }, "|")

    if force or signature ~= record.lastSignature then
        print(string.format(
            "[ZombieFactions][%s][CLIENT_OBSERVER] phase=%s subject=%d owner=%s remote=%s expectedFaction=%s resolvedFaction=%s target=%d expectedTarget=%d retained=%s state=%s attacking=%s distance=%.2f controlMode=%s pursuitCommands=%d engagements=%d aiProgress=%s movement=%s subjectDead=%s candidateDead=%s",
            record.runId,
            phase,
            record.subjectId,
            owner,
            tostring(remote),
            tostring(record.expectedFaction),
            tostring(resolvedFaction),
            targetId,
            record.candidateId,
            tostring(target == candidate),
            state,
            tostring(attacking),
            distance,
            tostring(record.controlMode or "none"),
            record.pursuitCommands or 0,
            record.engagements or 0,
            tostring(record.aiProgressObserved),
            tostring(record.movementObserved),
            tostring(subjectDead),
            tostring(candidateDead)
        ))
        record.lastSignature = signature
    end
end

local function approachCoordinates(record)
    local candidate = record.candidate
    return candidate:getX() + record.approachOffsetX,
        candidate:getY() + record.approachOffsetY,
        candidate:getZ()
end

local function pathToCandidateLocation(record)
    local x, y, z = approachCoordinates(record)
    return pcall(function()
        record.subject:pathToLocationF(x, y, z)
    end)
end

local function squareCoordinate(square, getter)
    return tonumber(safeCall(math.huge, function()
        return getter(square)
    end)) or math.huge
end

local function engagementAreaClear(record)
    local subject = record.subject
    local candidate = record.candidate
    local subjectSquare = safeCall(nil, function() return subject:getCurrentSquare() end)
    local candidateSquare = safeCall(nil, function() return candidate:getCurrentSquare() end)
    if not subjectSquare or not candidateSquare then return false, "missing-square" end

    local subjectX = squareCoordinate(subjectSquare, function(square) return square:getX() end)
    local subjectY = squareCoordinate(subjectSquare, function(square) return square:getY() end)
    local subjectZ = squareCoordinate(subjectSquare, function(square) return square:getZ() end)
    local candidateX = squareCoordinate(candidateSquare, function(square) return square:getX() end)
    local candidateY = squareCoordinate(candidateSquare, function(square) return square:getY() end)
    local candidateZ = squareCoordinate(candidateSquare, function(square) return square:getZ() end)
    local squarePairKey = table.concat({
        tostring(subjectX), tostring(subjectY), tostring(subjectZ),
        tostring(candidateX), tostring(candidateY), tostring(candidateZ),
    }, ":")
    if record.obstacleSquarePairKey == squarePairKey then
        CombatController.increment("obstacleCacheHits")
        return record.obstacleAreaClear == true, record.obstacleAreaReason or "cached"
    end

    CombatController.increment("obstacleChecks")
    record.obstacleSquarePairKey = squarePairKey
    if subjectZ ~= candidateZ then
        record.obstacleAreaClear = false
        record.obstacleAreaReason = "different-floor"
        return false, record.obstacleAreaReason
    end
    if math.abs(subjectX - candidateX) > 1 or math.abs(subjectY - candidateY) > 1 then
        record.obstacleAreaClear = false
        record.obstacleAreaReason = "not-adjacent"
        return false, record.obstacleAreaReason
    end
    if subjectSquare == candidateSquare then
        record.obstacleAreaClear = true
        record.obstacleAreaReason = "same-square"
        return true, record.obstacleAreaReason
    end

    local wall = safeCall(true, function() return subjectSquare:isWallTo(candidateSquare) end)
        or safeCall(true, function() return candidateSquare:isWallTo(subjectSquare) end)
    if wall then
        record.obstacleAreaClear = false
        record.obstacleAreaReason = "wall"
        return false, record.obstacleAreaReason
    end
    local window = safeCall(true, function() return subjectSquare:isWindowTo(candidateSquare) end)
        or safeCall(true, function() return candidateSquare:isWindowTo(subjectSquare) end)
    if window then
        record.obstacleAreaClear = false
        record.obstacleAreaReason = "window"
        return false, record.obstacleAreaReason
    end
    local door = safeCall(true, function() return subjectSquare:isDoorBlockedTo(candidateSquare) end)
        or safeCall(true, function() return candidateSquare:isDoorBlockedTo(subjectSquare) end)
    if door then
        record.obstacleAreaClear = false
        record.obstacleAreaReason = "door"
        return false, record.obstacleAreaReason
    end
    local hoppable = safeCall(true, function() return subjectSquare:isHoppableTo(candidateSquare) end)
        or safeCall(true, function() return candidateSquare:isHoppableTo(subjectSquare) end)
    if hoppable then
        record.obstacleAreaClear = false
        record.obstacleAreaReason = "hoppable"
        return false, record.obstacleAreaReason
    end
    record.obstacleAreaClear = true
    record.obstacleAreaReason = "clear"
    return true, record.obstacleAreaReason
end

local function clearZombieTarget(subject)
    local target = currentTarget(subject)
    if not target then return true, "already-clear" end
    if not isZombieTarget(target) then return false, "player-target-present" end

    local ok, err = pcall(function() subject:setTarget(nil) end)
    if not ok then return false, tostring(err) end
    return currentTarget(subject) == nil, "zombie-target-cleared"
end

local function cancelCoordinatePath(subject)
    if not subject then return false, "subject-unavailable" end
    return pcall(function()
        local behavior = subject:getPathFindBehavior2()
        if behavior then behavior:cancel() end
        subject:setPath2(nil)
        subject:setPathFindIndex(-1)
    end)
end

local function candidateMovedFromPath(record)
    if record.lastPathX == nil or record.lastPathY == nil or record.lastPathZ == nil then return true end
    local x, y, z = approachCoordinates(record)
    local dx = x - record.lastPathX
    local dy = y - record.lastPathY
    return z ~= record.lastPathZ
        or dx * dx + dy * dy >= PATH_REFRESH_MOVEMENT * PATH_REFRESH_MOVEMENT
end

local function enterPursuit(record, reason, forceRefresh)
    local subject = record.subject
    local candidate = record.candidate
    local cleared, clearReason = clearZombieTarget(subject)
    if not cleared then
        setSprintIntent(record, false)
        if record.controlMode ~= "blocked-player-target" then
            print(string.format(
                "[ZombieFactions][%s][OWNER_PROBE] phase=control-blocked reason=%s subject=%d candidate=%d state=%s",
                record.runId,
                clearReason,
                record.subjectId,
                record.candidateId,
                zombieState(subject)
            ))
        end
        record.controlMode = "blocked-player-target"
        return false
    end

    local previousMode = record.controlMode
    local desiredMode = reason == "contact-close" and "contact-closing" or "pursuit"
    record.controlMode = desiredMode
    -- Re-checked every pass rather than once, so a zombie that stops being an
    -- upright sprinter mid-approach drops the request immediately.
    record.sprintEligible = isSprintEligible(subject)

    -- Brake well outside the engagement band so the final approach is walked.
    -- Previously sprint was only dropped once enterEngagement ran at contact
    -- distance, meaning a sprinter ran at full speed right up to the point it was
    -- supposed to have already stopped. Walking that last stretch leaves the
    -- shared engagement, commitment and contact distances behaving for a sprinter
    -- exactly as they already do for a shambler, so nothing shared needs widening
    -- and non-sprinters are untouched.
    local approachDistance = distanceBetween(subject, candidate)
    local braking = approachDistance <= SPRINT_BRAKE_DISTANCE
    if record.sprintEligible and braking and record.sprintActive then
        CombatController.increment("sprintBrakes")
        CombatController.increment("sprintBrakeDistanceSum", approachDistance)
    end
    setSprintIntent(record, record.sprintEligible and not braking)
    if forceRefresh
        or previousMode ~= desiredMode
        or candidateMovedFromPath(record)
        or record.pathRefreshCountdown <= 0
    then
        local pathX, pathY, pathZ = approachCoordinates(record)
        local pathOk, pathErr = pathToCandidateLocation(record)
        record.pathRefreshCountdown = PATH_REFRESH_INTERVAL_TICKS
        record.lastPathX = pathX
        record.lastPathY = pathY
        record.lastPathZ = pathZ
        record.pursuitCommands = (record.pursuitCommands or 0) + 1
        CombatController.increment("pursuitCommands")
        print(string.format(
            "[ZombieFactions][%s][OWNER_PROBE] phase=coordinate-pursuit reason=%s subject=%d candidate=%d distance=%.2f targetClear=%s pathToLocationF=%s state=%s command=%d",
            record.runId,
            tostring(reason or "maintain"),
            record.subjectId,
            record.candidateId,
            distanceBetween(subject, candidate),
            tostring(currentTarget(subject) == nil),
            tostring(pathOk),
            zombieState(subject),
            record.pursuitCommands
        ))
        if not pathOk then
            print(string.format("[ZombieFactions][%s][OWNER_PROBE] coordinate pursuit error=%s", record.runId, tostring(pathErr)))
        end
        return pathOk
    end
    return true
end

local function enterEngagement(record, areaReason)
    local subject = record.subject
    local candidate = record.candidate
    -- Sprinting stops at contact so the attack presentation starts from a
    -- settled pose, matching how the shipped sprint ends when a target is
    -- reached.
    setSprintIntent(record, false)
    local cleared, clearReason = clearZombieTarget(subject)
    if not cleared then
        record.controlMode = "blocked-player-target"
        return false
    end

    local cancelOk, cancelErr = cancelCoordinatePath(subject)
    if not cancelOk then
        print(string.format(
            "[ZombieFactions][%s][OWNER_PROBE] phase=melee-engagement-failed subject=%d candidate=%d distance=%.2f pathCancel=false error=%s",
            record.runId,
            record.subjectId,
            record.candidateId,
            distanceBetween(subject, candidate),
            tostring(cancelErr)
        ))
        record.controlMode = nil
        return false
    end

    if currentTarget(subject) ~= nil then
        record.controlMode = nil
        return false
    end

    local wasEngaged = record.controlMode == "engagement"
    record.controlMode = "engagement"
    pcall(function() subject:faceThisObject(candidate) end)
    if not wasEngaged then
        record.engagements = (record.engagements or 0) + 1
        CombatController.increment("engagements")
        print(string.format(
            "[ZombieFactions][%s][OWNER_PROBE] phase=melee-engagement subject=%d candidate=%d distance=%.2f area=%s pathCancelled=true nativeTargetClear=%s clearReason=%s state=%s engagement=%d",
            record.runId,
            record.subjectId,
            record.candidateId,
            distanceBetween(subject, candidate),
            tostring(areaReason),
            tostring(currentTarget(subject) == nil),
            tostring(clearReason),
            zombieState(subject),
            record.engagements
        ))
    end
    return true
end

local function requestReacquire(record)
    if record.reacquireRequested then return end
    local player = getPlayer()
    if not player or ownerUsername(record.subject) ~= player:getUsername() then return end

    record.reacquireRequested = true
    setSprintIntent(record, false)
    if isZombieTarget(currentTarget(record.subject)) then
        pcall(function() record.subject:setTarget(nil) end)
    end
    cancelCoordinatePath(record.subject)
    sendClientCommand(player, MODULE, REACQUIRE_COMMAND, {
        runId = record.runId,
        subjectId = record.subjectId,
        candidateId = record.candidateId,
    })
    CombatController.increment("stuckReacquires")
end

local function updateProgress(record, distance, stepTicks, meleeCommitted)
    local existingTarget = currentTarget(record.subject)
    if existingTarget and not isZombieTarget(existingTarget) then
        record.bestDistance = distance
        record.noProgressTicks = 0
        return
    end
    if meleeCommitted then
        record.bestDistance = distance
        record.noProgressTicks = 0
        return
    end
    if isAttacking(record.subject, record.candidate) then
        record.bestDistance = distance
        record.noProgressTicks = 0
        return
    end

    if distance + PROGRESS_DISTANCE < record.bestDistance then
        record.bestDistance = distance
        record.noProgressTicks = 0
        return
    end

    record.noProgressTicks = record.noProgressTicks + stepTicks
    if record.noProgressTicks >= record.noProgressLimit then
        requestReacquire(record)
    end
end

local function beginOwnerProbe(record)
    local replaced = tracked[record.subjectId]
    if replaced then
        print(string.format(
            "[ZombieFactions][%s][ACQUISITION_PROBE] phase=replace-grant subject=%d oldCandidate=%d newCandidate=%d oldGrant=%d newGrant=%d",
            record.runId,
            record.subjectId,
            replaced.candidateId,
            record.candidateId,
            replaced.grantCount or 0,
            record.grantCount or 0
        ))
    end
    if replaced then setSprintIntent(replaced, false) end
    tracked[record.subjectId] = record
    CombatController.clearMeleeAuthorization(record.subjectId)
    record.sprintActive = false
    record.sprintEligible = false
    record.sprintLogCountdown = 0
    record.lastPassDistance = nil
    record.pathRefreshCountdown = 0
    if record.persistent then
        record.remaining = 0
    else
        record.remaining = math.min(
            MAX_TRACK_TICKS,
            (record.expiresInSeconds or 60) * CLIENT_TICKS_PER_SECOND
        )
    end
    record.lastSignature = nil
    record.aiProgressObserved = false
    record.movementObserved = false
    record.controlMode = nil
    record.pursuitCommands = 0
    record.engagements = 0
    record.reacquireRequested = false
    record.meleeCommitted = false
    record.safetyReason = nil
    record.obstacleSquarePairKey = nil
    record.obstacleAreaClear = nil
    record.obstacleAreaReason = nil
    record.lastPathX = nil
    record.lastPathY = nil
    record.lastPathZ = nil
    record.initialDistance = distanceBetween(record.subject, record.candidate)
    record.bestDistance = record.initialDistance
    record.noProgressTicks = 0
    record.noProgressLimit = NO_PROGRESS_BASE_TICKS
        + (math.abs(record.subjectId) % (NO_PROGRESS_STAGGER_TICKS + 1))
    local approachSeed = math.abs(
        record.subjectId * 31
        + record.candidateId * 17
        + (record.mobId or 0) * 13
        + (record.mobMemberIndex or 1) * 7
    )
    local approachSlot = approachSeed % APPROACH_SLOT_COUNT
    local approachAngle = (approachSlot / APPROACH_SLOT_COUNT) * math.pi * 2
    local approachRadius = math.floor(approachSeed / APPROACH_SLOT_COUNT) % 2 == 0
        and APPROACH_INNER_RADIUS
        or APPROACH_OUTER_RADIUS
    record.approachOffsetX = math.cos(approachAngle) * approachRadius
    record.approachOffsetY = math.sin(approachAngle) * approachRadius

    printSnapshot(record, "begin", true)
end

local function resolvePending(record)
    local subject = findZombieByOnlineId(record.subjectId)
    local candidate = findZombieByOnlineId(record.candidateId)
    if not subject or not candidate then return false end

    local player = getPlayer()
    local localUsername = player and player:getUsername() or "none"
    local owner = ownerUsername(subject)

    if owner ~= localUsername then
        return false
    end

    record.subject = subject
    record.candidate = candidate

    print(string.format(
        "[ZombieFactions][%s][OWNER_PROBE] resolved subject=%d candidate=%d localPlayer=%s owner=%s remote=%s serverOwner=%s",
        record.runId,
        record.subjectId,
        record.candidateId,
        tostring(localUsername),
        owner,
        tostring(isRemoteZombie(subject)),
        tostring(record.serverOwner)
    ))

    beginOwnerProbe(record)
    return true
end

local function onServerCommand(module, command, args)
    if module ~= MODULE then return end
    args = args or {}

    local player = getPlayer()
    if not player or tostring(args.targetOwner or args.owner) ~= player:getUsername() then
        return
    end

    if command == RELEASE_COMMAND then
        local subjectId = tonumber(args.subjectId)
        local candidateId = tonumber(args.candidateId)
        if subjectId == nil or candidateId == nil then return end

        for i = #pending, 1, -1 do
            if pending[i].subjectId == subjectId and pending[i].candidateId == candidateId then
                table.remove(pending, i)
            end
        end
        local record = tracked[subjectId]
        if record and record.candidateId == candidateId then
            setSprintIntent(record, false)
            if isZombieTarget(currentTarget(record.subject)) then
                pcall(function() record.subject:setTarget(nil) end)
            end
            cancelCoordinatePath(record.subject)
            CombatController.clearMeleeAuthorization(subjectId)
            tracked[subjectId] = nil
            CombatController.increment("releases")
        end
        print(string.format(
            "[ZombieFactions][%s][ACQUISITION_PROBE] phase=release-instruction reason=%s subject=%d candidate=%d",
            tostring(args.runId or "SPIKE001"),
            tostring(args.reason or "released"),
            subjectId,
            candidateId
        ))
        return
    end

    if command ~= GRANT_COMMAND then return end

    -- IsoZombie online IDs are Java shorts and may legitimately be negative.
    local subjectId = tonumber(args.subjectId)
    local candidateId = tonumber(args.candidateId)
    if subjectId == nil or candidateId == nil then
        print("[ZombieFactions] target-probe instruction rejected: invalid zombie online IDs")
        return
    end

    for i = #pending, 1, -1 do
        if pending[i].subjectId == subjectId then table.remove(pending, i) end
    end

    pending[#pending + 1] = {
        runId = tostring(args.runId or "SPIKE001"),
        subjectId = subjectId,
        candidateId = candidateId,
        expectedFaction = tostring(args.factionId or "unknown"),
        candidateFaction = tostring(args.candidateFactionId or "unknown"),
        relationship = tostring(args.relationship or "unknown"),
        serverOwner = tostring(args.owner or "none"),
        persistent = args.persistent == true,
        expiresInTicks = tonumber(args.expiresInTicks) or MAX_TRACK_TICKS,
        expiresInSeconds = tonumber(args.expiresInSeconds) or 60,
        grantCount = tonumber(args.grantCount) or 1,
        grantReason = tostring(args.grantReason or "acquired"),
        mobId = tonumber(args.mobId) or 0,
        mobLeaderId = tonumber(args.mobLeaderId) or subjectId,
        mobMemberIndex = tonumber(args.mobMemberIndex) or 1,
        clientCollisionDistance = tonumber(args.clientCollisionDistance) or 0.80,
        serverValidationDistance = tonumber(args.serverValidationDistance) or 1.60,
        ticks = RESOLVE_RETRY_TICKS,
        scanCountdown = 0,
    }

    print(string.format(
        "[ZombieFactions][%s][ACQUISITION_PROBE] phase=instruction grant=%d reason=%s subject=%d candidate=%d sourceFaction=%s targetFaction=%s relationship=%s serverOwner=%s clientCollisionDistance=%.2f serverValidationDistance=%.2f expiresInTicks=%d",
        tostring(args.runId or "SPIKE001"),
        tonumber(args.grantCount) or 1,
        tostring(args.grantReason or "acquired"),
        subjectId,
        candidateId,
        tostring(args.factionId or "unknown"),
        tostring(args.candidateFactionId or "unknown"),
        tostring(args.relationship or "unknown"),
        tostring(args.owner or "none"),
        tonumber(args.clientCollisionDistance) or 0.80,
        tonumber(args.serverValidationDistance) or 1.60,
        tonumber(args.expiresInTicks) or MAX_TRACK_TICKS
    ))
end

local function updateTargetRecord(record, stepTicks)
    local zombie = record.subject
    local candidate = record.candidate
    CombatController.clearMeleeAuthorization(record.subjectId)
    if isDead(zombie) or isDead(candidate) then return end
    local distance = distanceBetween(zombie, candidate)
    if record.reacquireRequested then return end
    if applySafetyInterlock(record) then
        record.meleeCommitted = false
        updateProgress(record, distance, stepTicks, false)
        printSnapshot(record, "safety-suspended", false)
        return
    end

    local existingTarget = currentTarget(zombie)
    if existingTarget ~= nil then
        if not isZombieTarget(existingTarget) then
            -- A player target restores ordinary vanilla behavior, including the
            -- shipped sprint. Our request must be gone before that happens.
            setSprintIntent(record, false)
            record.controlMode = "blocked-player-target"
            record.meleeCommitted = false
            updateProgress(record, distance, stepTicks, false)
            printSnapshot(record, "player-target-preserved", false)
            return
        end
        local cleared = clearZombieTarget(zombie)
        if not cleared then
            setSprintIntent(record, false)
            record.controlMode = "native-target-clear-failed"
            record.meleeCommitted = false
            return
        end
        CombatController.increment("nativeZombieTargetsCleared")
    end

    local areaClear = false
    local areaReason = "outside-melee-envelope"

    if distance <= ENGAGEMENT_DISTANCE then
        areaClear, areaReason = engagementAreaClear(record)
        if areaClear and distance <= CONTACT_DISTANCE then
            enterEngagement(record, areaReason)
        else
            local pursuitReason = areaClear
                and "contact-close"
                or "approach:" .. tostring(areaReason)
            enterPursuit(record, pursuitReason, false)
        end
    else
        enterPursuit(record, "approach:" .. tostring(areaReason), false)
    end
    local meleeCommitted = distance <= MELEE_COMMITMENT_DISTANCE
        and areaClear
        and (record.controlMode == "contact-closing" or record.controlMode == "engagement")
        and currentTarget(zombie) == nil
    if meleeCommitted then
        CombatController.authorizeMelee(record.subjectId, record.candidateId)
        if not record.meleeCommitted then
            CombatController.increment("meleeCommitments")
            -- Distance at the first authorisation of each engagement. If braking
            -- works this should sit inside the commitment band rather than the
            -- pair skipping past it.
            if record.sprintEligible then
                CombatController.increment("sprintMeleeAuths")
                CombatController.increment("sprintMeleeAuthDistanceSum", distance)
            end
        end
    end

    -- Direct measure of the overshoot that made two sprinters circle each other:
    -- the pair was inside the engagement band and then got further apart.
    --
    -- Gated on sprint actually being active, not merely on the subject being a
    -- sprinter. The v0.0.42 run showed why: one window recorded ten overshoots
    -- with zero sprint intent held, because a braked sprinter still counts as
    -- eligible and ordinary jostling at melee range separates a pair all the
    -- time. That measured normal close-quarters movement rather than the
    -- high-speed circling this counter exists to detect.
    if record.sprintActive
        and record.lastPassDistance ~= nil
        and distance <= ENGAGEMENT_DISTANCE
        and distance > record.lastPassDistance
    then
        CombatController.increment("sprintOvershoots")
    end
    record.lastPassDistance = distance
    record.meleeCommitted = meleeCommitted

    -- Both sides, so a defender that never pursues still supplies a control figure.
    sampleZombieTravel(zombie, stepTicks)
    sampleZombieTravel(candidate, stepTicks)

    if record.sprintActive then
        CombatController.increment("sprintIntentSeconds", stepTicks / CLIENT_TICKS_PER_SECOND)
        local nodePlaying = sampleSprintNode(record)
        record.sprintLogCountdown = (record.sprintLogCountdown or 0) - stepTicks
        if record.sprintLogCountdown <= 0 then
            record.sprintLogCountdown = SPRINT_LOG_INTERVAL_TICKS
            print(string.format(
                "[ZombieFactions][%s][SPRINT_PROBE] subject=%d candidate=%d controlMode=%s speedType=%d walkType=%s sprintNodePlaying=%s bMoving=%s intrees=%s state=%s distance=%.2f",
                record.runId,
                record.subjectId,
                record.candidateId,
                tostring(record.controlMode or "none"),
                zombieSpeedType(zombie),
                zombieWalkType(zombie),
                tostring(nodePlaying),
                tostring(variableBool(zombie, "bMoving")),
                tostring(variableBool(zombie, "intrees")),
                zombieState(zombie),
                distance
            ))
        end
    end

    updateProgress(record, distance, stepTicks, meleeCommitted and record.controlMode == "engagement")
    printSnapshot(record, "observe", false)
end

local function onControllerUpdate(stepTicks)
    pruneTravelSamples()

    for i = #pending, 1, -1 do
        local record = pending[i]
        record.ticks = record.ticks - stepTicks
        record.scanCountdown = record.scanCountdown - stepTicks

        if record.scanCountdown <= 0 then
            record.scanCountdown = RESOLVE_SCAN_INTERVAL_TICKS
            if resolvePending(record) then
                table.remove(pending, i)
            elseif record.ticks <= 0 then
                print(string.format(
                    "[ZombieFactions][%s][OWNER_PROBE] resolve-timeout subject=%d candidate=%d localPlayer=%s serverOwner=%s",
                    record.runId,
                    record.subjectId,
                    record.candidateId,
                    getPlayer() and getPlayer():getUsername() or "none",
                    record.serverOwner
                ))
                -- Tell the server we are giving this up. Dropping it silently left the
                -- probe active on the server, so the subject counted as engaged and was
                -- never requeued: one transient failure removed that zombie from the run.
                local player = getPlayer()
                if player then
                    sendClientCommand(player, MODULE, DECLINE_COMMAND, {
                        runId = record.runId,
                        subjectId = record.subjectId,
                        candidateId = record.candidateId,
                        reason = "client-resolve-failed",
                    })
                end
                CombatController.increment("grantResolveTimeouts")
                table.remove(pending, i)
            end
        end
    end

    for subjectId, record in pairs(tracked) do
        if not record.persistent then record.remaining = record.remaining - stepTicks end
        record.pathRefreshCountdown = math.max(0, record.pathRefreshCountdown - stepTicks)

        local player = getPlayer()
        local localUsername = player and player:getUsername() or "none"
        local currentOwner = ownerUsername(record.subject)
        local currentSubjectId = zombieOnlineId(record.subject)
        local currentCandidateId = zombieOnlineId(record.candidate)
        local finalReason = nil
        if currentSubjectId ~= record.subjectId then
            finalReason = "subject-identity-changed"
        elseif currentCandidateId ~= record.candidateId then
            finalReason = "candidate-identity-changed"
        elseif not record.persistent and record.remaining <= 0 then
            finalReason = "expired"
        elseif isDead(record.subject) then
            finalReason = "subject-dead"
        elseif isDead(record.candidate) then
            finalReason = "candidate-dead"
        elseif currentOwner ~= localUsername or isRemoteZombie(record.subject) then
            finalReason = "owner-lost"
        end

        if finalReason then
            print(string.format(
                "[ZombieFactions][%s][ACQUISITION_PROBE] phase=client-release reason=%s subject=%d candidate=%d owner=%s localPlayer=%s grant=%d",
                record.runId,
                finalReason,
                record.subjectId,
                record.candidateId,
                currentOwner,
                localUsername,
                record.grantCount or 0
            ))
            printSnapshot(record, "final", true)
            setSprintIntent(record, false)
            if isZombieTarget(currentTarget(record.subject)) then
                pcall(function() record.subject:setTarget(nil) end)
            end
            cancelCoordinatePath(record.subject)
            CombatController.clearMeleeAuthorization(subjectId)
            tracked[subjectId] = nil
            CombatController.increment("releases")
        else
            updateTargetRecord(record, stepTicks)
        end
    end
    CombatController.setGauge("trackedTargets", (function()
        local count = 0
        for _ in pairs(tracked) do count = count + 1 end
        return count
    end)())
    -- Reported alongside trackedTargets so a grant stuck between arrival and resolution
    -- is visible without verbose diagnostics. A server active count that exceeds
    -- trackedTargets plus pendingGrants is a grant nobody is driving.
    CombatController.setGauge("pendingGrants", #pending)
end

Events.OnServerCommand.Add(onServerCommand)
CombatController.register("targeting", onControllerUpdate, 10)
