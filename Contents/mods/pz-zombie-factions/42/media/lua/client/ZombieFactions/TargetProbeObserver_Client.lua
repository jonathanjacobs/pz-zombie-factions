require "ZombieFactions/Assignment"
require "ZombieFactions/ClientCombatController"
local CombatController = ZombieFactions.ClientCombatController

local MODULE = "ZombieFactions"
local GRANT_COMMAND = "TargetProbeInstruction"
local RELEASE_COMMAND = "TargetProbeRelease"
local REACQUIRE_COMMAND = "TargetProbeReacquire"

local RESOLVE_RETRY_TICKS = 90
local RESOLVE_SCAN_INTERVAL_TICKS = 5
local PATH_REFRESH_INTERVAL_TICKS = 300
local PATH_REFRESH_MOVEMENT = 0.75
local CLIENT_TICKS_PER_SECOND = 60
local MAX_TRACK_TICKS = 60 * CLIENT_TICKS_PER_SECOND
local MIN_SAFE_TARGET_DISTANCE = 0.10
local ENGAGEMENT_DISTANCE = 1.20
local DISENGAGEMENT_DISTANCE = 1.35
local MELEE_COMMITMENT_DISTANCE = 0.90
local APPROACH_SLOT_COUNT = 24
local APPROACH_INNER_RADIUS = 0.65
local APPROACH_OUTER_RADIUS = 0.90
local TARGET_REATTACH_BACKOFF_TICKS = 30
local TARGET_REATTACH_FAILURE_BACKOFF_TICKS = 60
local NO_PROGRESS_BASE_TICKS = 5 * CLIENT_TICKS_PER_SECOND
local NO_PROGRESS_STAGGER_TICKS = 2 * CLIENT_TICKS_PER_SECOND
local PROGRESS_DISTANCE = 0.35

local pending = {}
local tracked = {}

print("[ZombieFactions] Client target observer loaded v0.0.24")

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

local function safetyReason(subject, candidate)
    local subjectState = zombieState(subject)
    if isTraversalState(subjectState) then
        return "subject-traversal:" .. subjectState
    end
    local candidateState = zombieState(candidate)
    if isTraversalState(candidateState) then
        return "candidate-traversal:" .. candidateState
    end
    if string.find(string.lower(subjectState), "lunge", 1, true) ~= nil
        and currentTarget(subject) == candidate
    then
        local vectorDistance = tonumber(safeCall(-1, function()
            return subject:getVariableFloat("distancetotarget", -1)
        end)) or -1
        if vectorDistance >= 0 and vectorDistance < 0.001 then
            return "zero-target-vector"
        end
    end
    if distanceBetween(subject, candidate) < MIN_SAFE_TARGET_DISTANCE then
        return "close-overlap"
    end
    return nil
end

local function applySafetyInterlock(record)
    local reason = safetyReason(record.subject, record.candidate)
    if reason then
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
    record.controlMode = "pursuit"
    record.reattachCountdown = 0
    if forceRefresh
        or previousMode ~= "pursuit"
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
    local existing = currentTarget(subject)
    if existing and existing ~= candidate then
        if not isZombieTarget(existing) then
            record.controlMode = "blocked-player-target"
            return false
        end
        pcall(function() subject:setTarget(nil) end)
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

    local setOk, setErr = pcall(function() subject:setTarget(candidate) end)
    local retained = setOk and currentTarget(subject) == candidate
    record.reattachCountdown = retained
        and TARGET_REATTACH_BACKOFF_TICKS
        or TARGET_REATTACH_FAILURE_BACKOFF_TICKS
    if retained then
        record.controlMode = "engagement"
        local wasAttached = record.hadTarget == true
        record.hadTarget = true
        if not wasAttached then
            record.engagements = (record.engagements or 0) + 1
            CombatController.increment("engagements")
            print(string.format(
                "[ZombieFactions][%s][OWNER_PROBE] phase=melee-engagement subject=%d candidate=%d distance=%.2f area=%s pathCancelled=true retained=true state=%s engagement=%d",
                record.runId,
                record.subjectId,
                record.candidateId,
                distanceBetween(subject, candidate),
                tostring(areaReason),
                zombieState(subject),
                record.engagements
            ))
        else
            CombatController.increment("targetReattachments")
        end
        return true
    end

    record.controlMode = nil
    print(string.format(
        "[ZombieFactions][%s][OWNER_PROBE] phase=melee-engagement-failed subject=%d candidate=%d distance=%.2f setTarget=%s error=%s",
        record.runId,
        record.subjectId,
        record.candidateId,
        distanceBetween(subject, candidate),
        tostring(setOk),
        tostring(setErr)
    ))
    return false
end

local function requestReacquire(record)
    if record.reacquireRequested then return end
    local player = getPlayer()
    if not player or ownerUsername(record.subject) ~= player:getUsername() then return end

    record.reacquireRequested = true
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
    tracked[record.subjectId] = record
    CombatController.clearMeleeAuthorization(record.subjectId)
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
    record.hadTarget = false
    record.controlMode = nil
    record.pursuitCommands = 0
    record.engagements = 0
    record.reattachCountdown = 0
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
        ticks = RESOLVE_RETRY_TICKS,
        scanCountdown = 0,
    }

    print(string.format(
        "[ZombieFactions][%s][ACQUISITION_PROBE] phase=instruction grant=%d reason=%s subject=%d candidate=%d sourceFaction=%s targetFaction=%s relationship=%s serverOwner=%s expiresInTicks=%d",
        tostring(args.runId or "SPIKE001"),
        tonumber(args.grantCount) or 1,
        tostring(args.grantReason or "acquired"),
        subjectId,
        candidateId,
        tostring(args.factionId or "unknown"),
        tostring(args.candidateFactionId or "unknown"),
        tostring(args.relationship or "unknown"),
        tostring(args.owner or "none"),
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

    local retained = currentTarget(zombie) == candidate
    local areaClear = false
    local areaReason = "outside-melee-envelope"

    if retained then
        if distance <= DISENGAGEMENT_DISTANCE then
            areaClear, areaReason = engagementAreaClear(record)
        end
        if distance <= DISENGAGEMENT_DISTANCE and areaClear then
            record.controlMode = "engagement"
            record.hadTarget = true
        else
            record.aiProgressObserved = false
            record.movementObserved = false
            record.initialDistance = distance
            enterPursuit(record, "disengage:" .. tostring(areaReason), true)
        end
    elseif distance <= ENGAGEMENT_DISTANCE then
        areaClear, areaReason = engagementAreaClear(record)
        if areaClear then
            if record.reattachCountdown <= 0 then
                enterEngagement(record, areaReason)
            else
                if record.controlMode ~= "engagement-backoff" then
                    cancelCoordinatePath(zombie)
                end
                record.controlMode = "engagement-backoff"
                CombatController.increment("reattachBackoffs")
            end
        else
            enterPursuit(record, "approach:" .. tostring(areaReason), false)
        end
    else
        enterPursuit(record, "approach:" .. tostring(areaReason), false)
    end
    local meleeCommitted = distance <= MELEE_COMMITMENT_DISTANCE and areaClear
    if meleeCommitted then
        CombatController.authorizeMelee(record.subjectId, record.candidateId)
        if not record.meleeCommitted then
            CombatController.increment("meleeCommitments")
        end
    end
    record.meleeCommitted = meleeCommitted
    updateProgress(record, distance, stepTicks, meleeCommitted)
    printSnapshot(record, "observe", false)
end

local function onControllerUpdate(stepTicks)
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
                table.remove(pending, i)
            end
        end
    end

    for subjectId, record in pairs(tracked) do
        if not record.persistent then record.remaining = record.remaining - stepTicks end
        record.pathRefreshCountdown = math.max(0, record.pathRefreshCountdown - stepTicks)
        record.reattachCountdown = math.max(0, (record.reattachCountdown or 0) - stepTicks)

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
end

Events.OnServerCommand.Add(onServerCommand)
CombatController.register("targeting", onControllerUpdate, 10)
