require "ZombieFactions/Assignment"

local MODULE = "ZombieFactions"
local COMMAND = "TargetProbeInstruction"

local RESOLVE_RETRY_TICKS = 90
local RESOLVE_SCAN_INTERVAL_TICKS = 5
local PHASE_B_DELAY_TICKS = 30
local PHASE_C_DELAY_TICKS = 60
local OBSERVE_DURATION_TICKS = 240

local pending = {}
local tracked = {}

print("[ZombieFactions] Client target observer loaded v0.0.7")

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

local function findZombieByOnlineId(onlineId)
    local zombies = getCell():getZombieList()
    if not zombies then return nil end

    for i = 0, zombies:size() - 1 do
        local zombie = zombies:get(i)
        if zombie and zombieOnlineId(zombie) == onlineId then
            return zombie
        end
    end
    return nil
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
    }, "|")

    if force or signature ~= record.lastSignature then
        print(string.format(
            "[ZombieFactions][%s][CLIENT_OBSERVER] phase=%s subject=%d owner=%s remote=%s expectedFaction=%s resolvedFaction=%s target=%d expectedTarget=%d retained=%s state=%s attacking=%s distance=%.2f aiProgress=%s movement=%s subjectDead=%s candidateDead=%s",
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
            tostring(record.aiProgressObserved),
            tostring(record.movementObserved),
            tostring(subjectDead),
            tostring(candidateDead)
        ))
        record.lastSignature = signature
    end
end

local function forceTargetPath(record, phase, useSpottedOld)
    local subject = record.subject
    local candidate = record.candidate

    local spottedOk, spottedErr = nil, nil
    if useSpottedOld then
        -- Do not call spotted()/spottedNew() with an IsoZombie target in this probe.
        -- B42 has a documented player-only assumption in spottedNew that can throw
        -- for zombie targets when sight is obstructed by a vehicle. The older path
        -- is used only as a bounded diagnostic to test whether perception state is
        -- the missing gate before target/path processing.
        spottedOk, spottedErr = pcall(function()
            subject:spottedOld(candidate, true)
        end)
    end

    local setOk, setErr = pcall(function()
        subject:setTarget(candidate)
    end)

    local pathOk, pathErr = false, nil
    if setOk then
        pathOk, pathErr = pcall(function()
            subject:pathToCharacter(candidate)
        end)
    end

    print(string.format(
        "[ZombieFactions][%s][OWNER_PROBE] phase=%s subject=%d owner=%s remote=%s candidate=%d distance=%.2f spottedOld=%s setTarget=%s pathToCharacter=%s retained=%s state=%s attacking=%s",
        record.runId,
        phase,
        record.subjectId,
        ownerUsername(subject),
        tostring(isRemoteZombie(subject)),
        record.candidateId,
        distanceBetween(subject, candidate),
        useSpottedOld and tostring(spottedOk) or "not-called",
        tostring(setOk),
        tostring(pathOk),
        tostring(currentTarget(subject) == candidate),
        zombieState(subject),
        tostring(isAttacking(subject, candidate))
    ))

    if useSpottedOld and not spottedOk then
        print(string.format("[ZombieFactions][%s][OWNER_PROBE] spottedOld error=%s", record.runId, tostring(spottedErr)))
    end
    if not setOk then
        print(string.format("[ZombieFactions][%s][OWNER_PROBE] setTarget error=%s", record.runId, tostring(setErr)))
    end
    if not pathOk then
        print(string.format("[ZombieFactions][%s][OWNER_PROBE] pathToCharacter error=%s", record.runId, tostring(pathErr)))
    end
end

local function runLocationPathControl(record)
    local subject = record.subject
    local candidate = record.candidate

    local clearOk, clearErr = pcall(function()
        subject:setTarget(nil)
    end)
    local pathOk, pathErr = pcall(function()
        subject:pathToLocationF(candidate:getX(), candidate:getY(), candidate:getZ())
    end)

    print(string.format(
        "[ZombieFactions][%s][OWNER_PROBE] phase=owner-location-path subject=%d owner=%s remote=%s candidate=%d distance=%.2f clearTarget=%s pathToLocationF=%s target=%d state=%s attacking=%s",
        record.runId,
        record.subjectId,
        ownerUsername(subject),
        tostring(isRemoteZombie(subject)),
        record.candidateId,
        distanceBetween(subject, candidate),
        tostring(clearOk),
        tostring(pathOk),
        targetOnlineId(currentTarget(subject)),
        zombieState(subject),
        tostring(isAttacking(subject, candidate))
    ))

    if not clearOk then
        print(string.format("[ZombieFactions][%s][OWNER_PROBE] clearTarget error=%s", record.runId, tostring(clearErr)))
    end
    if not pathOk then
        print(string.format("[ZombieFactions][%s][OWNER_PROBE] pathToLocationF error=%s", record.runId, tostring(pathErr)))
    end
end

local function beginOwnerProbe(record)
    tracked[record.subjectId] = record
    record.phaseBTicks = PHASE_B_DELAY_TICKS
    record.phaseCTicks = PHASE_C_DELAY_TICKS
    record.remaining = OBSERVE_DURATION_TICKS
    record.lastSignature = nil
    record.phaseBDone = false
    record.phaseCDone = false
    record.aiProgressObserved = false
    record.movementObserved = false
    record.initialDistance = distanceBetween(record.subject, record.candidate)

    forceTargetPath(record, "owner-target-path", false)
    printSnapshot(record, "phase-a", true)
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
    if module ~= MODULE or command ~= COMMAND then return end
    args = args or {}

    local player = getPlayer()
    if not player or tostring(args.requester) ~= player:getUsername() then
        return
    end

    -- IsoZombie online IDs are Java shorts and may legitimately be negative.
    local subjectId = tonumber(args.subjectId)
    local candidateId = tonumber(args.candidateId)
    if subjectId == nil or candidateId == nil then
        print("[ZombieFactions] target-probe instruction rejected: invalid zombie online IDs")
        return
    end

    pending[#pending + 1] = {
        runId = tostring(args.runId or "SPIKE001"),
        subjectId = subjectId,
        candidateId = candidateId,
        expectedFaction = tostring(args.factionId or "unknown"),
        serverOwner = tostring(args.owner or "none"),
        ticks = RESOLVE_RETRY_TICKS,
        scanCountdown = 0,
    }

    print(string.format(
        "[ZombieFactions][%s][OWNER_PROBE] instruction subject=%d candidate=%d expectedFaction=%s serverOwner=%s",
        tostring(args.runId or "SPIKE001"),
        subjectId,
        candidateId,
        tostring(args.factionId or "unknown"),
        tostring(args.owner or "none")
    ))
end

local function onTick()
    for i = #pending, 1, -1 do
        local record = pending[i]
        record.ticks = record.ticks - 1
        record.scanCountdown = record.scanCountdown - 1

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
        record.remaining = record.remaining - 1

        if not record.phaseBDone then
            record.phaseBTicks = record.phaseBTicks - 1
            if record.phaseBTicks <= 0 then
                record.phaseBDone = true
                local retained = currentTarget(record.subject) == record.candidate
                local state = zombieState(record.subject)
                local attacking = isAttacking(record.subject, record.candidate)

                if record.aiProgressObserved or attacking or (retained and state ~= "idle") then
                    print(string.format(
                        "[ZombieFactions][%s][OWNER_PROBE] phase=owner-spottedOld-target-path skipped=true reason=phase-a-progress retained=%s state=%s attacking=%s aiProgress=%s movement=%s",
                        record.runId,
                        tostring(retained),
                        state,
                        tostring(attacking),
                        tostring(record.aiProgressObserved),
                        tostring(record.movementObserved)
                    ))
                else
                    forceTargetPath(record, "owner-spottedOld-target-path", true)
                    printSnapshot(record, "phase-b", true)
                end
            end
        end

        if not record.phaseCDone then
            record.phaseCTicks = record.phaseCTicks - 1
            if record.phaseCTicks <= 0 then
                record.phaseCDone = true
                local retained = currentTarget(record.subject) == record.candidate
                local state = zombieState(record.subject)
                local attacking = isAttacking(record.subject, record.candidate)

                if record.aiProgressObserved or record.movementObserved or attacking or (retained and state ~= "idle") then
                    print(string.format(
                        "[ZombieFactions][%s][OWNER_PROBE] phase=owner-location-path skipped=true reason=target-path-progress retained=%s state=%s attacking=%s aiProgress=%s movement=%s",
                        record.runId,
                        tostring(retained),
                        state,
                        tostring(attacking),
                        tostring(record.aiProgressObserved),
                        tostring(record.movementObserved)
                    ))
                else
                    runLocationPathControl(record)
                    printSnapshot(record, "phase-c", true)
                end
            end
        end

        if record.remaining <= 0 or isDead(record.subject) or isDead(record.candidate) then
            printSnapshot(record, "final", true)
            tracked[subjectId] = nil
        end
    end
end

local function onZombieUpdate(zombie)
    if not zombie then return end
    local record = tracked[zombieOnlineId(zombie)]
    if not record or record.subject ~= zombie then return end
    printSnapshot(record, "observe", false)
end

Events.OnServerCommand.Add(onServerCommand)
Events.OnTick.Add(onTick)
Events.OnZombieUpdate.Add(onZombieUpdate)
