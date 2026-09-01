require "ZombieFactions/ClientCombatController"
local CombatController = ZombieFactions.ClientCombatController

local MODULE = "ZombieFactions"
local TARGET_COMMAND = "TargetProbeInstruction"
local RELEASE_COMMAND = "TargetProbeRelease"
local IMPACT_COMMAND = "TargetProbeAttack"
local APPLY_COMMAND = "TargetProbeApplyDamage"
local ACK_COMMAND = "TargetProbeDamageAck"
local RESULT_COMMAND = "TargetProbeDamageResult"

local CLIENT_COLLISION_DISTANCE_DEFAULT = 0.80
local SERVER_VALIDATION_DISTANCE_DEFAULT = 1.60
local COMBAT_DISTANCE_MIN = 0.25
local COMBAT_DISTANCE_MAX = 2.00
local RESOLVE_TICKS = 120
local REQUEST_COOLDOWN_TICKS = 60
local CLIENT_TICKS_PER_SECOND = 60
local TRACK_TICKS = 60 * CLIENT_TICKS_PER_SECOND
local PROCESSED_OWNER_HIT_LIMIT = 256
local MIN_SAFE_TARGET_DISTANCE = 0.10
local BITE_BUMP_TYPE = "Bite"
local STOMP_BUMP_TYPE = "ZombieFactionsStomp"
local CRAWLER_BITE_REACTION_BUMP_TYPE = "ZombieFactionsCrawlerBiteReact"
local CRAWLER_ATTACK_REACTION = "ZombieFactionsCrawlerAttack"
local CRAWLER_HIT_REACTION = "ZombieFactionsCrawlerHit"
local ATTACK_PRESENTATION_TICKS = 150
local HIT_REACTION_TICKS = 90
local SITTING_GETUP_TICKS = 180
local SITTING_GETUP_STABLE_TICKS = 30
local PROFILE_STANDING_BITE = "STANDING_BITE"
local PROFILE_CRAWLER_LUNGE = "CRAWLER_LUNGE"
local PROFILE_STANDING_STOMP = "STANDING_STOMP"
local HIT_REACTION_BUMP_TYPES = {
    "ZombieFactionsHitShoulderLeft",
    "ZombieFactionsHitShoulderRight",
    "ZombieFactionsHitChestLeft",
    "ZombieFactionsHitChestRight",
}

local pending = {}
local tracked = {}
local pendingOwnerHits = {}
local processedOwnerHits = {}
local processedOwnerHitOrder = {}
local activeHitReactions = {}

print("[ZombieFactions] Client impact probe loaded v0.0.37")

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

local function boundedCombatDistance(value, fallback)
    local distanceValue = tonumber(value)
    if not distanceValue or distanceValue ~= distanceValue then return fallback end
    return math.max(COMBAT_DISTANCE_MIN, math.min(COMBAT_DISTANCE_MAX, distanceValue))
end

local function isDead(zombie)
    if not zombie then return true end
    return safeCall(false, function() return zombie:isDead() end) == true
end

local function isCrawler(zombie)
    if not zombie or zombie.isCrawling == nil then return false end
    return safeCall(false, function() return zombie:isCrawling() end) == true
end

local function isSitting(zombie)
    if not zombie or zombie.isSitAgainstWall == nil then return false end
    return safeCall(false, function() return zombie:isSitAgainstWall() end) == true
end

local function attackProfile(subject, candidate)
    if isCrawler(subject) then return PROFILE_CRAWLER_LUNGE end
    if isCrawler(candidate) or isSitting(candidate) then return PROFILE_STANDING_STOMP end
    return PROFILE_STANDING_BITE
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

local function isSittingGetupState(state)
    state = string.lower(tostring(state or ""))
    return string.find(state, "getup", 1, true) ~= nil
        or (string.find(state, "get", 1, true) ~= nil
            and string.find(state, "sit", 1, true) ~= nil)
end

local function currentTarget(zombie)
    return safeCall(nil, function() return zombie:getTarget() end)
end

local function isZombieTarget(target)
    if not target then return false end
    return safeCall(false, function() return target:isZombie() end) == true
end

local function isUnsafeCombatPair(subject, candidate)
    return isTraversalState(zombieState(subject))
        or isTraversalState(zombieState(candidate))
        or isNativeCombatOrReactionState(zombieState(subject))
        or isNativeCombatOrReactionState(zombieState(candidate))
        or isSittingGetupState(zombieState(subject))
        or isSittingGetupState(zombieState(candidate))
        or distance(subject, candidate) < MIN_SAFE_TARGET_DISTANCE
end

local function findZombie(id)
    return CombatController.findZombie(id)
end

local function clearAttackPresentation(record, expired)
    if not record or not record.subject or not record.presentationProfile then return end
    local profile = record.presentationProfile
    safeCall(false, function()
        record.subject:setVariable("ZombieFactionsAttackImpact", "")
        record.subject:setVariable("ZombieFactionsAttackFinished", false)
        record.subject:setVariable("ZombieFactionsBitePhase", "")
        if profile == PROFILE_CRAWLER_LUNGE then
            if tostring(record.subject:getHitReaction() or "") == CRAWLER_ATTACK_REACTION then
                record.subject:setHitReaction("")
            end
        else
            local expectedBumpType = profile == PROFILE_STANDING_STOMP and STOMP_BUMP_TYPE
                or BITE_BUMP_TYPE
            if tostring(record.subject:getBumpType() or "") == expectedBumpType then
                record.subject:setVariable("BumpAnimFinished", true)
                record.subject:setBumpDone(true)
                record.subject:setBumpType("")
            end
        end
        return true
    end)
    record.presentationProfile = nil
    record.presentationTicks = nil
    record.presentationDefenderSitting = nil
    record.impactSent = nil
    if expired then
        CombatController.increment("attackPresentationsExpired")
        if profile == PROFILE_STANDING_BITE then
            CombatController.increment("biteBumpsExpired")
        end
    end
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
    record.presentationProfile = nil
    record.presentationTicks = nil
    record.impactSent = nil
    local previous = tracked[record.subjectId]
    if previous and previous ~= record then
        if previous.candidateId == record.candidateId then
            record.cooldown = previous.cooldown or record.cooldown
            record.defenderGetupLock = previous.defenderGetupLock
        end
        clearAttackPresentation(previous, false)
    end
    tracked[record.subjectId] = record
    CombatController.setGauge("clientCollisionDistance", record.clientCollisionDistance)
    CombatController.setGauge("serverValidationDistance", record.serverValidationDistance)

    print(string.format(
        "[ZombieFactions][%s][IMPACT_PROBE] tracking subject=%d candidate=%d owner=%s clientCollisionDistance=%.2f serverValidationDistance=%.2f candidateHealth=%.3f",
        record.runId,
        record.subjectId,
        record.candidateId,
        ownerUsername(subject),
        record.clientCollisionDistance,
        record.serverValidationDistance,
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

local function clearOwnerHitReaction(record)
    local zombie = record and record.zombie
    if not zombie then return end
    if record.kind == "sitting-getup" then return end
    if record.kind == "crawler-hit-reaction" then
        local hitReaction = tostring(safeCall("", function() return zombie:getHitReaction() end))
        if hitReaction ~= tostring(record.hitReaction or "") then return end
        safeCall(false, function()
            zombie:setHitReaction("")
            return true
        end)
        return
    end
    local bumpType = tostring(safeCall("", function() return zombie:getBumpType() end))
    if bumpType ~= tostring(record.bumpType or "") then return end
    safeCall(false, function()
        zombie:setVariable("BumpAnimFinished", true)
        zombie:setBumpDone(true)
        zombie:setBumpType("")
        return true
    end)
end

local function playOwnerHitReaction(candidate, profile, alertX, alertY)
    if not candidate or isDead(candidate)
        or isTraversalState(zombieState(candidate))
        or isNativeCombatOrReactionState(zombieState(candidate))
    then
        CombatController.increment("hitReactionsSuppressed")
        return false
    end

    local candidateId = onlineId(candidate)
    if isSitting(candidate) then
        if alertX == nil or alertY == nil then
            CombatController.increment("hitReactionsSuppressed")
            return false
        end
        local armed = safeCall(false, function()
            -- This is the same target-owner alert route used by native sound
            -- responses. It initializes the turn-alerted state, internal
            -- alerted flag, and network update without broadcasting a world
            -- sound to unrelated zombies.
            candidate:setTurnAlertedValues(
                math.floor(alertX),
                math.floor(alertY)
            )
            return true
        end) == true
        if not armed then
            CombatController.increment("hitReactionsSuppressed")
            return false
        end
        local existingWake = activeHitReactions[candidateId]
        if not existingWake or existingWake.kind ~= "sitting-getup" then
            activeHitReactions[candidateId] = {
                zombie = candidate,
                kind = "sitting-getup",
                remaining = SITTING_GETUP_TICKS,
            }
        end
        CombatController.increment("sittingDefendersAlerted")
        CombatController.increment("hitReactionsArmed")
        return true
    end

    if isCrawler(candidate) then
        local existing = tostring(safeCall("", function() return candidate:getHitReaction() end))
        if existing ~= "" then
            CombatController.increment("hitReactionsSuppressed")
            return false
        end
        local armed = safeCall(false, function()
            candidate:setHitReaction(CRAWLER_HIT_REACTION)
            return true
        end) == true
        if not armed then
            CombatController.increment("hitReactionsSuppressed")
            return false
        end
        activeHitReactions[candidateId] = {
            zombie = candidate,
            kind = "crawler-hit-reaction",
            hitReaction = CRAWLER_HIT_REACTION,
            remaining = HIT_REACTION_TICKS,
        }
        CombatController.increment("crawlerHitReactionsArmed")
        CombatController.increment("hitReactionsArmed")
        return true
    end

    local bumpType = tostring(safeCall("", function() return candidate:getBumpType() end))
    if bumpType ~= "" then
        CombatController.increment("hitReactionsSuppressed")
        return false
    end

    local reactionType = CRAWLER_BITE_REACTION_BUMP_TYPE
    if profile ~= PROFILE_CRAWLER_LUNGE then
        local fallbackIndex = (math.abs(candidateId) % #HIT_REACTION_BUMP_TYPES) + 1
        local reactionIndex = tonumber(safeCall(fallbackIndex, function()
            return ZombRand(#HIT_REACTION_BUMP_TYPES) + 1
        end)) or fallbackIndex
        reactionType = HIT_REACTION_BUMP_TYPES[reactionIndex] or HIT_REACTION_BUMP_TYPES[fallbackIndex]
    end
    local armed = safeCall(false, function()
        candidate:setVariable("BumpAnimFinished", false)
        candidate:setBumpDone(false)
        candidate:setBumpType(reactionType)
        return true
    end) == true
    if not armed then
        CombatController.increment("hitReactionsSuppressed")
        return false
    end

    activeHitReactions[candidateId] = {
        zombie = candidate,
        kind = "bump",
        bumpType = reactionType,
        remaining = HIT_REACTION_TICKS,
    }
    if profile == PROFILE_CRAWLER_LUNGE then
        CombatController.increment("crawlerBiteReactionsArmed")
    end
    CombatController.increment("hitReactionsArmed")
    return true
end

local function playAttackSound(subject, profile)
    local soundName = profile == PROFILE_STANDING_STOMP and "AttackStomp" or "ZombieBite"
    local played = safeCall(false, function()
        local emitter = subject:getEmitter()
        if not emitter then return false end
        emitter:playSound(soundName)
        return true
    end) == true
    CombatController.increment(played and "attackSoundsPlayed" or "attackSoundsSuppressed")
    if profile == PROFILE_STANDING_STOMP then
        CombatController.increment(played and "stompSoundsPlayed" or "stompSoundsSuppressed")
    else
        CombatController.increment(played and "biteSoundsPlayed" or "biteSoundsSuppressed")
    end
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

    if not dead then
        playOwnerHitReaction(candidate, record.attackProfile, record.alertX, record.alertY)
    end
    sendOwnerHitAck(record, true, "owner applied faction damage", beforeHealth, afterHealth, dead)
    return true
end

local function sameLevel(a, b)
    return math.abs(a:getZ() - b:getZ()) < 0.2
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
            attackProfile = tostring(args.attackProfile or PROFILE_STANDING_BITE),
            alertX = tonumber(args.alertX),
            alertY = tonumber(args.alertY),
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
            clearAttackPresentation(record, false)
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
            clientCollisionDistance = boundedCombatDistance(
                args.clientCollisionDistance,
                CLIENT_COLLISION_DISTANCE_DEFAULT
            ),
            serverValidationDistance = boundedCombatDistance(
                args.serverValidationDistance,
                SERVER_VALIDATION_DISTANCE_DEFAULT
            ),
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

local function armAttackPresentation(record, profile)
    if record.presentationProfile then return end
    if currentTarget(record.subject) ~= nil
        or isUnsafeCombatPair(record.subject, record.candidate)
    then
        CombatController.increment("attackPresentationsSuppressed")
        if profile == PROFILE_STANDING_BITE then CombatController.increment("biteBumpsSuppressed") end
        return
    end

    local armed = safeCall(false, function()
        record.subject:faceThisObject(record.candidate)
        record.subject:setVariable("ZombieFactionsAttackImpact", "")
        record.subject:setVariable("ZombieFactionsAttackFinished", false)
        if profile == PROFILE_CRAWLER_LUNGE then
            record.subject:setHitReaction(CRAWLER_ATTACK_REACTION)
        else
            record.subject:setVariable("BumpAnimFinished", false)
            record.subject:setBumpDone(false)
            if profile == PROFILE_STANDING_STOMP then
                record.subject:setBumpType(STOMP_BUMP_TYPE)
            else
                record.subject:setVariable("ZombieFactionsBitePhase", "start")
                record.subject:setBumpType(BITE_BUMP_TYPE)
            end
        end
        return true
    end) == true
    if not armed then
        CombatController.increment("attackPresentationsSuppressed")
        if profile == PROFILE_STANDING_BITE then CombatController.increment("biteBumpsSuppressed") end
        return
    end

    record.presentationProfile = profile
    record.presentationTicks = ATTACK_PRESENTATION_TICKS
    record.presentationDefenderSitting = isSitting(record.candidate)
    record.impactSent = false
    CombatController.increment("attackPresentationsArmed")
    CombatController.increment("customAttackStarts")
    if profile == PROFILE_STANDING_BITE then
        CombatController.increment("biteBumpsArmed")
    elseif profile == PROFILE_CRAWLER_LUNGE then
        CombatController.increment("crawlerLungesArmed")
    else
        CombatController.increment("stompsArmed")
        if record.presentationDefenderSitting then
            CombatController.increment("sittingStompsArmed")
        end
    end
end

local function dispatchImpact(record, evidence)
    local profile = record.presentationProfile or attackProfile(record.subject, record.candidate)
    local impactDistance = distance(record.subject, record.candidate)
    if record.impactSent
        or isDead(record.subject)
        or isDead(record.candidate)
        or attackProfile(record.subject, record.candidate) ~= profile
        or not CombatController.isMeleeAuthorized(record.subjectId, record.candidateId)
        or not sameLevel(record.subject, record.candidate)
        or impactDistance > record.clientCollisionDistance
        or isTraversalState(zombieState(record.subject))
        or isTraversalState(zombieState(record.candidate))
    then
        CombatController.increment("impactSuppressed")
        return false
    end

    local player = getPlayer()
    if not player or ownerUsername(record.subject) ~= player:getUsername() then return false end
    if not CombatController.tryConsumeImpactRequestBudget() then
        CombatController.increment("impactBudgetDeferred")
        return false
    end

    record.impactSent = true
    record.cooldown = REQUEST_COOLDOWN_TICKS
    if profile == PROFILE_STANDING_STOMP and record.presentationDefenderSitting then
        record.defenderGetupLock = {
            remaining = SITTING_GETUP_TICKS,
            stableStandingTicks = 0,
        }
        CombatController.increment("sittingGetupLocksArmed")
    end
    safeCall(false, function()
        record.subject:faceThisObject(record.candidate)
        record.subject:setVariable("ZombieFactionsAttackImpact", "")
        return true
    end)
    sendClientCommand(player, MODULE, IMPACT_COMMAND, {
        runId = record.runId,
        subjectId = record.subjectId,
        candidateId = record.candidateId,
        attackProfile = profile,
        impactEvidence = evidence,
        clientDistanceAtImpact = impactDistance,
        clientDistanceAtCollision = impactDistance,
        clientCollisionDistance = record.clientCollisionDistance,
        serverValidationDistance = record.serverValidationDistance,
    })
    playAttackSound(record.subject, profile)
    CombatController.increment("impactRequests")
    CombatController.increment("customAttackHits")
    if evidence == "character-collision" then CombatController.increment("biteCollisions") end
    if profile == PROFILE_CRAWLER_LUNGE then
        CombatController.increment("crawlerLungeImpacts")
    elseif profile == PROFILE_STANDING_STOMP then
        CombatController.increment("stompImpacts")
        if record.presentationDefenderSitting then
            CombatController.increment("sittingStompImpacts")
        end
    end
    print(string.format(
        "[ZombieFactions][%s][FACTION_IMPACT] request subject=%d candidate=%d profile=%s evidence=%s defenderSitting=%s clientDistanceAtImpact=%.2f clientCollisionDistance=%.2f serverValidationDistance=%.2f clientCandidateHealth=%.3f",
        record.runId,
        record.subjectId,
        record.candidateId,
        profile,
        tostring(evidence),
        tostring(record.presentationDefenderSitting == true),
        impactDistance,
        record.clientCollisionDistance,
        record.serverValidationDistance,
        health(record.candidate)
    ))
    return true
end

local function updateDefenderGetupLock(record, stepTicks)
    local lock = record.defenderGetupLock
    if not lock then return false end

    lock.remaining = lock.remaining - stepTicks
    local candidateState = zombieState(record.candidate)
    if not isSitting(record.candidate) and not isSittingGetupState(candidateState) then
        lock.stableStandingTicks = lock.stableStandingTicks + stepTicks
        if lock.stableStandingTicks >= SITTING_GETUP_STABLE_TICKS then
            record.defenderGetupLock = nil
            CombatController.increment("sittingGetupLocksReleased")
            return false
        end
    else
        lock.stableStandingTicks = 0
    end

    if lock.remaining <= 0 or isDead(record.candidate) then
        record.defenderGetupLock = nil
        CombatController.increment("sittingGetupLocksExpired")
        return false
    end
    return true
end

local function updateImpactRecord(record, stepTicks)
    local dist = distance(record.subject, record.candidate)
    local authorized = CombatController.isMeleeAuthorized(record.subjectId, record.candidateId)
    if not authorized then
        clearAttackPresentation(record, false)
        CombatController.increment("impactSuppressed")
        CombatController.increment("impactNoAuthorization")
        return
    end
    local nativeTarget = currentTarget(record.subject)
    if nativeTarget ~= nil then
        if nativeTarget == record.candidate then CombatController.increment("impactExactTarget") end
        if isZombieTarget(nativeTarget) then
            safeCall(false, function()
                record.subject:setTarget(nil)
                return true
            end)
        end
        clearAttackPresentation(record, false)
        CombatController.increment("impactSuppressed")
        CombatController.increment("impactUnsafe")
        return
    end
    CombatController.increment("impactAuthorizedWithoutExact")
    if dist > record.clientCollisionDistance then
        clearAttackPresentation(record, false)
        CombatController.increment("impactSuppressed")
        CombatController.increment("impactOutOfRange")
        return
    end

    local profile = attackProfile(record.subject, record.candidate)
    if record.presentationProfile and record.presentationProfile ~= profile then
        clearAttackPresentation(record, false)
        CombatController.increment("attackProfileChanges")
    end

    local defenderGetupLocked = updateDefenderGetupLock(record, stepTicks)

    if record.presentationProfile then
        local impactReady = tostring(safeCall("", function()
            return record.subject:getVariableString("ZombieFactionsAttackImpact")
        end)) == "ready"
        if impactReady and not record.impactSent and profile ~= PROFILE_STANDING_BITE then
            dispatchImpact(record, "animation-window")
        end
        local finished = safeCall(false, function()
            if profile == PROFILE_STANDING_BITE then
                return record.subject:getVariableBoolean("BumpAnimFinished")
            end
            return record.subject:getVariableBoolean("ZombieFactionsAttackFinished")
        end) == true
        if finished then clearAttackPresentation(record, false) end
        return
    end

    if defenderGetupLocked then
        CombatController.increment("sittingGetupAttackPauses")
        return
    end

    if isUnsafeCombatPair(record.subject, record.candidate) then
        CombatController.increment("impactSuppressed")
        CombatController.increment("impactUnsafe")
        return
    end
    if record.cooldown > 0 then return end
    armAttackPresentation(record, profile)
end

-- Standing bites retain real character collision as their impact evidence.
-- Crawler lunges and stomps use a mod-owned animation contact window because
-- crawling characters do not reliably produce the same collision callback.
local function onCharacterCollide(first, second)
    local firstId = onlineId(first)
    local secondId = onlineId(second)
    local record = tracked[firstId]
    if not record or record.candidateId ~= secondId then
        record = tracked[secondId]
        if not record or record.candidateId ~= firstId then return end
    end
    if not record.subject or not record.candidate
        or record.presentationProfile ~= PROFILE_STANDING_BITE
    then
        return
    end
    dispatchImpact(record, "character-collision")
end

local function onControllerUpdate(stepTicks)
    for candidateId, reaction in pairs(activeHitReactions) do
        reaction.remaining = reaction.remaining - stepTicks
        local stillActive = false
        if reaction.kind == "sitting-getup" then
            if not isSitting(reaction.zombie) then
                activeHitReactions[candidateId] = nil
                CombatController.increment("sittingDefendersStood")
            elseif reaction.remaining <= 0 or isDead(reaction.zombie) then
                activeHitReactions[candidateId] = nil
                CombatController.increment("sittingGetupsExpired")
                CombatController.increment("hitReactionsExpired")
            end
        elseif reaction.kind == "crawler-hit-reaction" then
            stillActive = tostring(safeCall("", function() return reaction.zombie:getHitReaction() end))
                == tostring(reaction.hitReaction or "")
        else
            stillActive = tostring(safeCall("", function() return reaction.zombie:getBumpType() end))
                == tostring(reaction.bumpType or "")
        end
        if reaction.kind == "sitting-getup" then
            -- The sitting branch owns its completion and timeout handling.
        elseif not stillActive then
            activeHitReactions[candidateId] = nil
        elseif reaction.remaining <= 0 or isDead(reaction.zombie) then
            clearOwnerHitReaction(reaction)
            activeHitReactions[candidateId] = nil
            CombatController.increment("hitReactionsExpired")
        end
    end

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
        if not record.persistent then record.remaining = record.remaining - stepTicks end
        if record.cooldown > 0 then record.cooldown = math.max(0, record.cooldown - stepTicks) end
        if record.presentationTicks and record.presentationTicks > 0 then
            record.presentationTicks = record.presentationTicks - stepTicks
            if record.presentationTicks <= 0 then clearAttackPresentation(record, true) end
        end
        local player = getPlayer()
        local localUsername = player and player:getUsername() or "none"
        if (not record.persistent and record.remaining <= 0)
            or not record.subject
            or not record.candidate
            or isDead(record.subject)
            or isDead(record.candidate)
            or ownerUsername(record.subject) ~= localUsername
        then
            clearAttackPresentation(record, false)
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
Events.OnCharacterCollide.Add(onCharacterCollide)
CombatController.register("impact", onControllerUpdate, 20)
