require "ZombieFactions/ClientCombatController"
local CombatController = ZombieFactions.ClientCombatController

local MODULE = "ZombieFactions"
local TARGET_COMMAND = "TargetProbeInstruction"
local RELEASE_COMMAND = "TargetProbeRelease"
local IMPACT_COMMAND = "TargetProbeAttack"
local APPLY_COMMAND = "TargetProbeApplyDamage"
local ACK_COMMAND = "TargetProbeDamageAck"
local RESULT_COMMAND = "TargetProbeDamageResult"

local MAX_DISTANCE = 0.90
local RESOLVE_TICKS = 120
local REQUEST_COOLDOWN_TICKS = 60
local ATTACK_WINDUP_BASE_TICKS = 18
local ATTACK_WINDUP_STAGGER_TICKS = 12
local CLIENT_TICKS_PER_SECOND = 60
local TRACK_TICKS = 60 * CLIENT_TICKS_PER_SECOND
local PROCESSED_OWNER_HIT_LIMIT = 256
local MIN_SAFE_TARGET_DISTANCE = 0.10

local pending = {}
local tracked = {}
local pendingOwnerHits = {}
local processedOwnerHits = {}
local processedOwnerHitOrder = {}

print("[ZombieFactions] Client impact probe loaded v0.0.27")

local function print(message)
    CombatController.detail(message)
end

local function safeCall(default, fn)
    local ok, value = pcall(fn)
    if ok and value ~= nil then return value end
    return default
end

local function onlineId(zombie)
    return tonumber(safeCall(-1, function() return zombie:getOnlineID() end)) or -1
end

local function ownerUsername(zombie)
    local owner = safeCall(nil, function() return zombie:getOwnerPlayer() end)
    if not owner then return "none" end
    return tostring(safeCall("unknown", function() return owner:getUsername() end))
end

local function health(zombie)
    return tonumber(safeCall(-1, function() return zombie:getHealth() end)) or -1
end

local function isDead(zombie)
    if not zombie then return true end
    return safeCall(false, function() return zombie:isDead() end) == true
end

local function distance(a, b)
    if not a or not b then return math.huge end
    local dx = a:getX() - b:getX()
    local dy = a:getY() - b:getY()
    return math.sqrt(dx * dx + dy * dy)
end

local function zombieState(zombie)
    return tostring(safeCall("unknown", function() return zombie:getRealState() end))
end

local function isTraversalState(state)
    state = string.lower(tostring(state or ""))
    return string.find(state, "climb", 1, true) ~= nil
        or string.find(state, "fence", 1, true) ~= nil
        or string.find(state, "window", 1, true) ~= nil
        or string.find(state, "vault", 1, true) ~= nil
end

local function isUnsafeCombatPair(subject, candidate)
    return isTraversalState(zombieState(subject))
        or isTraversalState(zombieState(candidate))
        or distance(subject, candidate) < MIN_SAFE_TARGET_DISTANCE
end

local function findZombie(id)
    return CombatController.findZombie(id)
end

local function recoverInvalidAttackBump(zombie)
    if not zombie then return false end
    local bumpType = string.lower(tostring(safeCall("", function()
        return zombie:getBumpType()
    end)))
    if bumpType ~= "bite" and bumpType ~= "bitelow" then return false end

    local recovered = safeCall(false, function()
        zombie:setVariable("BumpAnimFinished", true)
        zombie:setBumpDone(true)
        zombie:setBumpType("")
        return true
    end) == true
    if recovered then
        CombatController.increment("invalidAttackBumpsRecovered")
    end
    return recovered
end

local function resolve(record)
    local subject = findZombie(record.subjectId)
    local candidate = findZombie(record.candidateId)
    if not subject or not candidate then return false end

    local player = getPlayer()
    if not player or ownerUsername(subject) ~= player:getUsername() then return false end

    record.subject = subject
    record.candidate = candidate
    if record.persistent then
        record.remaining = 0
    else
        record.remaining = math.min(
            TRACK_TICKS,
            (record.expiresInSeconds or 60) * CLIENT_TICKS_PER_SECOND
        )
    end
    record.cooldown = 0
    record.lastAttacking = false
    record.attackTicks = nil
    recoverInvalidAttackBump(subject)
    tracked[record.subjectId] = record

    print(string.format(
        "[ZombieFactions][%s][IMPACT_PROBE] tracking subject=%d candidate=%d owner=%s candidateHealth=%.3f",
        record.runId,
        record.subjectId,
        record.candidateId,
        ownerUsername(subject),
        health(candidate)
    ))
    return true
end

local function sendOwnerHitAck(record, ok, message, beforeHealth, afterHealth, candidateDead)
    local player = getPlayer()
    if not player then return end

    local payload = {
        runId = record.runId,
        hitId = record.hitId,
        subjectId = record.subjectId,
        candidateId = record.candidateId,
        ok = ok == true,
        message = tostring(message or ""),
        beforeHealth = beforeHealth,
        afterHealth = afterHealth,
        candidateDead = candidateDead == true,
    }
    if not processedOwnerHits[record.hitId] then
        processedOwnerHitOrder[#processedOwnerHitOrder + 1] = record.hitId
    end
    processedOwnerHits[record.hitId] = payload
    while #processedOwnerHitOrder > PROCESSED_OWNER_HIT_LIMIT do
        local expiredHitId = table.remove(processedOwnerHitOrder, 1)
        processedOwnerHits[expiredHitId] = nil
    end
    sendClientCommand(player, MODULE, ACK_COMMAND, payload)

    print(string.format(
        "[ZombieFactions][%s][OWNER_DAMAGE] phase=ack hitId=%s ok=%s subject=%d candidate=%d beforeHealth=%s afterHealth=%s candidateDead=%s message=%s",
        record.runId,
        record.hitId,
        tostring(payload.ok),
        record.subjectId,
        record.candidateId,
        tostring(beforeHealth),
        tostring(afterHealth),
        tostring(payload.candidateDead),
        payload.message
    ))
end

local function applyOwnerHit(record)
    local cached = processedOwnerHits[record.hitId]
    if cached then
        local player = getPlayer()
        if player then sendClientCommand(player, MODULE, ACK_COMMAND, cached) end
        return true
    end

    local candidate = findZombie(record.candidateId)
    if not candidate then return false end

    local player = getPlayer()
    local username = player and player:getUsername() or "none"
    local currentOwner = ownerUsername(candidate)
    if not player or currentOwner ~= username then
        sendOwnerHitAck(
            record,
            false,
            "target owner changed before local damage",
            health(candidate),
            health(candidate),
            isDead(candidate)
        )
        return true
    end

    local amount = tonumber(record.amount)
    if not amount or amount <= 0 or amount > 1 then
        sendOwnerHitAck(record, false, "invalid owner damage amount", health(candidate), health(candidate), isDead(candidate))
        return true
    end

    local beforeHealth = health(candidate)
    local applied, applyErr = pcall(function()
        candidate:applyDamage(amount)
    end)
    local afterHealth = health(candidate)
    local dead = isDead(candidate) or afterHealth <= 0

    if not applied then
        sendOwnerHitAck(record, false, tostring(applyErr), beforeHealth, afterHealth, dead)
        return true
    end

    sendOwnerHitAck(record, true, "owner applied faction damage", beforeHealth, afterHealth, dead)
    return true
end

local function onServerCommand(module, command, args)
    if module ~= MODULE then return end
    args = args or {}

    local player = getPlayer()
    if not player then return end

    if command == APPLY_COMMAND then
        if tostring(args.targetOwner or "") ~= player:getUsername() then return end

        local hitId = tostring(args.hitId or "")
        local subjectId = tonumber(args.subjectId)
        local candidateId = tonumber(args.candidateId)
        local amount = tonumber(args.amount)
        if hitId == "" or subjectId == nil or candidateId == nil or amount == nil then return end

        local record = {
            runId = tostring(args.runId or "SPIKE001"),
            hitId = hitId,
            subjectId = subjectId,
            candidateId = candidateId,
            amount = amount,
            ticks = RESOLVE_TICKS,
        }
        if not applyOwnerHit(record) then
            pendingOwnerHits[#pendingOwnerHits + 1] = record
        end
        return
    end

    if command == RELEASE_COMMAND then
        if tostring(args.targetOwner or "") ~= player:getUsername() then return end
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
            recoverInvalidAttackBump(record.subject)
            tracked[subjectId] = nil
        end
        return
    end

    if command == TARGET_COMMAND then
        if tostring(args.targetOwner or args.owner) ~= player:getUsername() then return end
        local subjectId = tonumber(args.subjectId)
        local candidateId = tonumber(args.candidateId)
        if subjectId == nil or candidateId == nil then return end
        for i = #pending, 1, -1 do
            if pending[i].subjectId == subjectId then table.remove(pending, i) end
        end
        pending[#pending + 1] = {
            runId = tostring(args.runId or "SPIKE001"),
            subjectId = subjectId,
            candidateId = candidateId,
            expiresInTicks = tonumber(args.expiresInTicks) or TRACK_TICKS,
            expiresInSeconds = tonumber(args.expiresInSeconds) or 60,
            persistent = args.persistent == true,
            ticks = RESOLVE_TICKS,
        }
    elseif command == RESULT_COMMAND then
        if tostring(args.requester) ~= player:getUsername() then return end
        print(string.format(
            "[ZombieFactions][%s][IMPACT_RESULT] ok=%s hit=%s hitId=%s targetOwner=%s ownerBeforeHealth=%s ownerAfterHealth=%s serverBeforeHealth=%s serverAfterHealth=%s candidateDead=%s message=%s",
            tostring(args.runId or "SPIKE001"),
            tostring(args.ok == true),
            tostring(args.damageHits),
            tostring(args.hitId),
            tostring(args.targetOwner),
            tostring(args.ownerBeforeHealth),
            tostring(args.ownerAfterHealth),
            tostring(args.serverBeforeHealth),
            tostring(args.serverAfterHealth),
            tostring(args.candidateDead == true),
            tostring(args.message or "")
        ))
    end
end

local function resetAttackCycle(record, cancelled)
    if cancelled and record.attackTicks ~= nil then
        CombatController.increment("customAttackCancels")
    end
    record.attackTicks = nil
end

local function startAttackCycle(record)
    record.attackTicks = ATTACK_WINDUP_BASE_TICKS
        + (math.abs(record.subjectId) % (ATTACK_WINDUP_STAGGER_TICKS + 1))
    safeCall(false, function()
        record.subject:faceThisObject(record.candidate)
        return true
    end)
    CombatController.increment("customAttackStarts")
end

local function updateImpactRecord(record, stepTicks)
    local dist = distance(record.subject, record.candidate)
    local authorized = CombatController.isMeleeAuthorized(record.subjectId, record.candidateId)
    if not authorized then
        resetAttackCycle(record, true)
        CombatController.increment("impactSuppressed")
        CombatController.increment("impactNoAuthorization")
        return
    end
    local exactTarget = safeCall(nil, function()
        return record.subject:getTarget()
    end) == record.candidate
    if exactTarget then
        CombatController.increment("impactExactTarget")
    else
        CombatController.increment("impactAuthorizedWithoutExact")
    end
    if dist > MAX_DISTANCE then
        resetAttackCycle(record, true)
        CombatController.increment("impactSuppressed")
        CombatController.increment("impactOutOfRange")
        return
    end
    if isUnsafeCombatPair(record.subject, record.candidate) then
        resetAttackCycle(record, true)
        CombatController.increment("impactSuppressed")
        CombatController.increment("impactUnsafe")
        return
    end

    if record.cooldown > 0 then
        resetAttackCycle(record, false)
        return
    end

    if record.attackTicks == nil then
        startAttackCycle(record)
        return
    end

    safeCall(false, function()
        record.subject:faceThisObject(record.candidate)
        return true
    end)
    record.attackTicks = record.attackTicks - stepTicks
    if record.attackTicks > 0 then return end
    if not CombatController.tryConsumeImpactRequestBudget() then
        record.attackTicks = 0
        CombatController.increment("impactBudgetDeferred")
        return
    end

    local player = getPlayer()
    if not player or ownerUsername(record.subject) ~= player:getUsername() then return end

    record.cooldown = REQUEST_COOLDOWN_TICKS
    resetAttackCycle(record, false)
    sendClientCommand(player, MODULE, IMPACT_COMMAND, {
        runId = record.runId,
        subjectId = record.subjectId,
        candidateId = record.candidateId,
    })
    CombatController.increment("impactRequests")
    CombatController.increment("customAttackHits")

    print(string.format(
        "[ZombieFactions][%s][IMPACT_PROBE] request subject=%d candidate=%d distance=%.2f clientCandidateHealth=%.3f",
        record.runId,
        record.subjectId,
        record.candidateId,
        dist,
        health(record.candidate)
    ))
end

local function onControllerUpdate(stepTicks)
    for i = #pendingOwnerHits, 1, -1 do
        local record = pendingOwnerHits[i]
        record.ticks = record.ticks - stepTicks
        if applyOwnerHit(record) then
            table.remove(pendingOwnerHits, i)
        elseif record.ticks <= 0 then
            sendOwnerHitAck(record, false, "target zombie resolve timeout", nil, nil, false)
            table.remove(pendingOwnerHits, i)
        end
    end

    for i = #pending, 1, -1 do
        local record = pending[i]
        record.ticks = record.ticks - stepTicks
        if resolve(record) or record.ticks <= 0 then
            table.remove(pending, i)
        end
    end

    for subjectId, record in pairs(tracked) do
        recoverInvalidAttackBump(record.subject)
        if not record.persistent then record.remaining = record.remaining - stepTicks end
        if record.cooldown > 0 then record.cooldown = math.max(0, record.cooldown - stepTicks) end
        local player = getPlayer()
        local localUsername = player and player:getUsername() or "none"
        if (not record.persistent and record.remaining <= 0)
            or not record.subject
            or not record.candidate
            or isDead(record.subject)
            or isDead(record.candidate)
            or ownerUsername(record.subject) ~= localUsername
        then
            tracked[subjectId] = nil
        else
            updateImpactRecord(record, stepTicks)
        end
    end
    CombatController.setGauge("trackedImpacts", (function()
        local count = 0
        for _ in pairs(tracked) do count = count + 1 end
        return count
    end)())
end

Events.OnServerCommand.Add(onServerCommand)
CombatController.register("impact", onControllerUpdate, 20)
