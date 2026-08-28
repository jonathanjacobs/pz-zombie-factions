if isClient() then return end

require "ZombieFactions/Assignment"

local MODULE = "ZombieFactions"
local SPAWN_COMMAND = "SpawnTestHorde"
local TARGET_PROBE_COMMAND = "TargetProbeInstruction"
local VANILLA = ZombieFactions.Faction.VANILLA
local TEST_RED = ZombieFactions.Faction.TEST_RED
local TEST_BLUE = ZombieFactions.Faction.TEST_BLUE
local HOSTILE = ZombieFactions.Relationship.HOSTILE

local VALIDATION_DELAY_TICKS = 30
local VALIDATION_SAMPLE_LIMIT = 10
local TARGET_PROBE_DELAY_TICKS = 30
local TARGET_PROBE_SAMPLE_TICKS = 15
local TARGET_PROBE_DURATION_TICKS = 180
local TARGET_PROBE_RADIUS = 12

ZombieFactions.TestHarnessSequence = ZombieFactions.TestHarnessSequence or 0
ZombieFactions.PendingAssignmentValidations = ZombieFactions.PendingAssignmentValidations or {}
ZombieFactions.PendingTargetProbes = ZombieFactions.PendingTargetProbes or {}
ZombieFactions.ActiveTargetProbes = ZombieFactions.ActiveTargetProbes or {}

print("[ZombieFactions] Server test harness loaded v0.0.7")

local function reply(player, ok, message, data)
    if not player then return end
    local payload = data or {}
    payload.ok = ok
    payload.message = message
    payload.requester = player:getUsername()
    sendServerCommand(MODULE, "SpawnTestHordeResult", payload)
end

local function hasCreateHordePermission(player)
    if not player then return false end
    local ok, permitted = pcall(function()
        return checkPermissions(player, Capability.CreateHorde)
    end)
    return ok and permitted == true
end

local function boundedInteger(value, minimum, maximum, fallback)
    local n = tonumber(value)
    if not n then return fallback end
    n = math.floor(n)
    if n < minimum then return minimum end
    if n > maximum then return maximum end
    return n
end

local function boundedNumber(value, minimum, maximum, fallback)
    local n = tonumber(value)
    if not n then return fallback end
    if n < minimum then return minimum end
    if n > maximum then return maximum end
    return n
end

local function isAllowedDiagnosticFaction(factionId)
    return factionId == VANILLA or factionId == TEST_RED or factionId == TEST_BLUE
end

local function configureRelationships(factionId, toVanilla, fromVanilla, symmetric)
    if factionId == VANILLA then return true end
    if symmetric then fromVanilla = toVanilla end

    local ok, err = ZombieFactions.setRelationship(factionId, VANILLA, toVanilla)
    if not ok then return false, err end

    ok, err = ZombieFactions.setRelationship(VANILLA, factionId, fromVanilla)
    if not ok then return false, err end
    return true
end

local function nextTestRunId()
    ZombieFactions.TestHarnessSequence = ZombieFactions.TestHarnessSequence + 1
    return string.format("SPIKE001-%04d", ZombieFactions.TestHarnessSequence)
end

local function zombieOnlineId(zombie)
    if not zombie then return -1 end
    local ok, value = pcall(function()
        return zombie:getOnlineID()
    end)
    if ok and value ~= nil then return tonumber(value) or -1 end
    return -1
end

local function ownerUsername(zombie)
    if not zombie then return "none" end
    local ok, ownerPlayer = pcall(function()
        return zombie:getOwnerPlayer()
    end)
    if not ok or not ownerPlayer then return "none" end

    local okName, username = pcall(function()
        return ownerPlayer:getUsername()
    end)
    if okName and username then return tostring(username) end
    return "unknown"
end

local function zombieState(zombie)
    if not zombie then return "missing" end
    local ok, state = pcall(function()
        return zombie:getRealState()
    end)
    if ok and state then return tostring(state) end
    return "unknown"
end

local function isDead(zombie)
    if not zombie then return true end
    local ok, dead = pcall(function()
        return zombie:isDead()
    end)
    return ok and dead == true
end

local function distanceSquared(a, b)
    if not a or not b then return math.huge end
    local dx = a:getX() - b:getX()
    local dy = a:getY() - b:getY()
    return dx * dx + dy * dy
end

local function currentTarget(zombie)
    if not zombie then return nil end
    local ok, target = pcall(function()
        return zombie:getTarget()
    end)
    if ok then return target end
    return nil
end

local function targetOnlineId(target)
    if not target then return -1 end
    local okIsZombie, targetIsZombie = pcall(function()
        return target:isZombie()
    end)
    if not okIsZombie or not targetIsZombie then return -1 end

    local okId, id = pcall(function()
        return target:getOnlineID()
    end)
    if okId and id ~= nil then return tonumber(id) or -1 end
    return -1
end

local function isZombieAttackingTarget(zombie, target)
    if not zombie or not target then return false end
    local ok, attacking = pcall(function()
        return zombie:isZombieAttacking(target)
    end)
    return ok and attacking == true
end

local function spawnOne(args, x, y, z)
    local outfit = args.outfit
    if outfit == "" then outfit = nil end

    local spawned = addZombiesInOutfit(
        x,
        y,
        z,
        1,
        outfit,
        tonumber(args.femaleChance),
        args.crawler == true,
        args.isFallOnFront == true,
        args.isFakeDead == true,
        args.knockedDown == true,
        args.isInvulnerable == true,
        args.isSitting == true,
        boundedNumber(args.health, 0, 2, 1),
        args.isRecordingAnims == true,
        boundedNumber(args.heightOffset, 0, 10, 0),
        args.isRagdolling == true,
        args.onFire == true
    )

    if not spawned or spawned:size() == 0 then return nil end
    return spawned:get(0)
end

local function queueAssignmentValidation(zombie, expectedFaction, expectedRun)
    ZombieFactions.PendingAssignmentValidations[#ZombieFactions.PendingAssignmentValidations + 1] = {
        zombie = zombie,
        expectedFaction = expectedFaction,
        expectedRun = expectedRun,
        ticks = VALIDATION_DELAY_TICKS,
    }
end

local function findNearestVanillaZombie(subject, radius)
    if not subject then return nil, math.huge end

    -- SPIKE-001 only: one bounded candidate scan. This is not production targeting.
    local zombies = getCell():getZombieList()
    if not zombies then return nil, math.huge end

    local maxDist2 = radius * radius
    local best = nil
    local bestDist2 = maxDist2 + 1

    for i = 0, zombies:size() - 1 do
        local candidate = zombies:get(i)
        if candidate and candidate ~= subject and not isDead(candidate) then
            if ZombieFactions.getZombieFaction(candidate) == VANILLA then
                local dist2 = distanceSquared(subject, candidate)
                if dist2 <= maxDist2 and dist2 < bestDist2 then
                    best = candidate
                    bestDist2 = dist2
                end
            end
        end
    end

    return best, bestDist2
end

local function beginOwnerTargetProbe(record)
    local subject = record.subject
    if not subject or isDead(subject) then
        print(string.format("[ZombieFactions][%s][TARGET_PROBE] subject unavailable before probe", record.runId))
        return
    end

    local candidate, dist2 = findNearestVanillaZombie(subject, TARGET_PROBE_RADIUS)
    if not candidate then
        print(string.format(
            "[ZombieFactions][%s][TARGET_PROBE] no zf:vanilla candidate within %d tiles subject=%d",
            record.runId,
            TARGET_PROBE_RADIUS,
            zombieOnlineId(subject)
        ))
        return
    end

    local subjectId = zombieOnlineId(subject)
    local candidateId = zombieOnlineId(candidate)
    local owner = ownerUsername(subject)

    print(string.format(
        "[ZombieFactions][%s][TARGET_PROBE] phase=dispatch subject=%d faction=%s owner=%s candidate=%d candidateFaction=%s distance=%.2f requester=%s",
        record.runId,
        subjectId,
        ZombieFactions.getZombieFaction(subject),
        owner,
        candidateId,
        ZombieFactions.getZombieFaction(candidate),
        math.sqrt(dist2),
        tostring(record.requester)
    ))

    sendServerCommand(MODULE, TARGET_PROBE_COMMAND, {
        requester = record.requester,
        runId = record.runId,
        subjectId = subjectId,
        candidateId = candidateId,
        factionId = ZombieFactions.getZombieFaction(subject),
        owner = owner,
    })

    ZombieFactions.ActiveTargetProbes[#ZombieFactions.ActiveTargetProbes + 1] = {
        runId = record.runId,
        subject = subject,
        candidate = candidate,
        subjectId = subjectId,
        candidateId = candidateId,
        remaining = TARGET_PROBE_DURATION_TICKS,
        sampleCountdown = 0,
        lastSignature = nil,
    }
end

local function sampleActiveProbe(record, final)
    local subject = record.subject
    local candidate = record.candidate
    local subjectDead = isDead(subject)
    local candidateDead = isDead(candidate)
    local target = currentTarget(subject)
    local targetId = targetOnlineId(target)
    local retained = target == candidate
    local state = zombieState(subject)
    local attacking = isZombieAttackingTarget(subject, candidate)
    local dist = math.sqrt(distanceSquared(subject, candidate))
    local signature = table.concat({
        tostring(subjectDead),
        tostring(candidateDead),
        tostring(targetId),
        tostring(retained),
        state,
        tostring(attacking),
        ownerUsername(subject),
    }, "|")

    if final or signature ~= record.lastSignature then
        print(string.format(
            "[ZombieFactions][%s][SERVER_OBSERVER] phase=%s subject=%d owner=%s target=%d expectedTarget=%d retained=%s state=%s attacking=%s distance=%.2f subjectDead=%s candidateDead=%s",
            record.runId,
            final and "final" or "observe",
            record.subjectId,
            ownerUsername(subject),
            targetId,
            record.candidateId,
            tostring(retained),
            state,
            tostring(attacking),
            dist,
            tostring(subjectDead),
            tostring(candidateDead)
        ))
        record.lastSignature = signature
    end
end

local function onTick()
    for i = #ZombieFactions.PendingAssignmentValidations, 1, -1 do
        local record = ZombieFactions.PendingAssignmentValidations[i]
        record.ticks = record.ticks - 1
        if record.ticks <= 0 then
            local resolvedFaction = ZombieFactions.getZombieFaction(record.zombie)
            local resolvedRun = ZombieFactions.getZombieTestRun(record.zombie)
            local ok = resolvedFaction == record.expectedFaction and resolvedRun == record.expectedRun
            print(string.format(
                "[ZombieFactions][%s][ASSIGN] phase=deferred onlineID=%d expectedFaction=%s resolvedFaction=%s resolvedRun=%s owner=%s ok=%s",
                tostring(record.expectedRun),
                zombieOnlineId(record.zombie),
                tostring(record.expectedFaction),
                tostring(resolvedFaction),
                tostring(resolvedRun),
                ownerUsername(record.zombie),
                tostring(ok)
            ))
            table.remove(ZombieFactions.PendingAssignmentValidations, i)
        end
    end

    for i = #ZombieFactions.PendingTargetProbes, 1, -1 do
        local record = ZombieFactions.PendingTargetProbes[i]
        record.ticks = record.ticks - 1
        if record.ticks <= 0 then
            beginOwnerTargetProbe(record)
            table.remove(ZombieFactions.PendingTargetProbes, i)
        end
    end

    for i = #ZombieFactions.ActiveTargetProbes, 1, -1 do
        local record = ZombieFactions.ActiveTargetProbes[i]
        record.remaining = record.remaining - 1
        record.sampleCountdown = record.sampleCountdown - 1

        if record.sampleCountdown <= 0 then
            record.sampleCountdown = TARGET_PROBE_SAMPLE_TICKS
            sampleActiveProbe(record, false)
        end

        if record.remaining <= 0 or isDead(record.subject) or isDead(record.candidate) then
            sampleActiveProbe(record, true)
            table.remove(ZombieFactions.ActiveTargetProbes, i)
        end
    end
end

local function handleSpawn(player, args)
    if not hasCreateHordePermission(player) then
        reply(player, false, "CreateHorde permission required")
        return
    end

    args = args or {}
    local factionId = tostring(args.factionId or VANILLA)
    if not isAllowedDiagnosticFaction(factionId) then
        reply(player, false, "unsupported diagnostic faction")
        return
    end

    local toVanilla = tostring(args.toVanilla or ZombieFactions.Relationship.FRIENDLY)
    local fromVanilla = tostring(args.fromVanilla or ZombieFactions.Relationship.FRIENDLY)
    local ok, err = configureRelationships(factionId, toVanilla, fromVanilla, args.symmetric == true)
    if not ok then
        reply(player, false, err or "invalid relationship")
        return
    end

    if args.targetProbe == true and toVanilla ~= HOSTILE then
        reply(player, false, "direct target probe requires spawned faction -> Vanilla = HOSTILE")
        return
    end

    local x = boundedInteger(args.x, -1000000, 1000000, math.floor(player:getX()))
    local y = boundedInteger(args.y, -1000000, 1000000, math.floor(player:getY()))
    local z = boundedInteger(args.z, 0, 32, math.floor(player:getZ()))
    local count = boundedInteger(args.count, 1, 500, 1)
    local radius = boundedInteger(args.radius, 0, 50, 0)

    if not getCell():getGridSquare(x, y, z) then
        reply(player, false, "selected square is not loaded")
        return
    end

    local runId = nextTestRunId()
    local spawnedCount = 0
    local immediateVerified = 0
    local validationSampled = 0
    local firstAssignedZombie = nil

    for _ = 1, count do
        local sx = radius > 0 and ZombRand(x - radius, x + radius + 1) or x
        local sy = radius > 0 and ZombRand(y - radius, y + radius + 1) or y
        local zombie = spawnOne(args, sx, sy, z)
        if zombie then
            local assigned = ZombieFactions.assignZombieFaction(zombie, factionId, runId)
            if assigned then
                spawnedCount = spawnedCount + 1
                firstAssignedZombie = firstAssignedZombie or zombie

                local resolvedFaction = ZombieFactions.getZombieFaction(zombie)
                local resolvedRun = ZombieFactions.getZombieTestRun(zombie)
                if resolvedFaction == factionId and resolvedRun == runId then
                    immediateVerified = immediateVerified + 1
                else
                    print(string.format(
                        "[ZombieFactions][%s][ASSIGN] phase=immediate onlineID=%d expectedFaction=%s resolvedFaction=%s resolvedRun=%s ok=false",
                        runId,
                        zombieOnlineId(zombie),
                        factionId,
                        tostring(resolvedFaction),
                        tostring(resolvedRun)
                    ))
                end

                if validationSampled < VALIDATION_SAMPLE_LIMIT then
                    validationSampled = validationSampled + 1
                    queueAssignmentValidation(zombie, factionId, runId)
                end
            end
        end
    end

    local effectiveFrom = args.symmetric == true and toVanilla or fromVanilla
    local probeQueued = args.targetProbe == true and firstAssignedZombie ~= nil

    if probeQueued then
        ZombieFactions.PendingTargetProbes[#ZombieFactions.PendingTargetProbes + 1] = {
            runId = runId,
            subject = firstAssignedZombie,
            requester = player:getUsername(),
            ticks = TARGET_PROBE_DELAY_TICKS,
        }
    end

    print(string.format(
        "[ZombieFactions][%s] spawned=%d requested=%d faction=%s %s->%s=%s %s->%s=%s assignmentImmediate=%d/%d deferredSamples=%d targetProbeQueued=%s",
        runId,
        spawnedCount,
        count,
        factionId,
        factionId,
        VANILLA,
        toVanilla,
        VANILLA,
        factionId,
        effectiveFrom,
        immediateVerified,
        spawnedCount,
        validationSampled,
        tostring(probeQueued)
    ))

    reply(player, true, "Faction test horde spawned", {
        runId = runId,
        spawned = spawnedCount,
        requested = count,
        factionId = factionId,
        toVanilla = toVanilla,
        fromVanilla = effectiveFrom,
        assignmentImmediate = immediateVerified,
        validationSampled = validationSampled,
        targetProbeQueued = probeQueued,
    })
end

local function onClientCommand(module, command, player, args)
    if module ~= MODULE or command ~= SPAWN_COMMAND then return end
    handleSpawn(player, args)
end

Events.OnClientCommand.Add(onClientCommand)
Events.OnTick.Add(onTick)
