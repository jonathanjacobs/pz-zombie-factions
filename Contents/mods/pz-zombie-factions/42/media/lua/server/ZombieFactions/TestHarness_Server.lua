if isClient() then return end

require "ZombieFactions/TargetPolicy"

local MODULE = "ZombieFactions"
local SPAWN_COMMAND = "SpawnTestHorde"
local TARGET_PROBE_COMMAND = "TargetProbeInstruction"
local TARGET_RELEASE_COMMAND = "TargetProbeRelease"
local TARGET_REACQUIRE_COMMAND = "TargetProbeReacquire"
local DAMAGE_PROBE_COMMAND = "TargetProbeAttack"
local DAMAGE_APPLY_COMMAND = "TargetProbeApplyDamage"
local DAMAGE_ACK_COMMAND = "TargetProbeDamageAck"
local DAMAGE_RESULT_COMMAND = "TargetProbeDamageResult"
local VANILLA = ZombieFactions.Faction.VANILLA
local TEST_RED = ZombieFactions.Faction.TEST_RED
local TEST_BLUE = ZombieFactions.Faction.TEST_BLUE
local FRIENDLY = ZombieFactions.Relationship.FRIENDLY
local NEUTRAL = ZombieFactions.Relationship.NEUTRAL
local HOSTILE = ZombieFactions.Relationship.HOSTILE
local PROFILE_STANDING_BITE = "STANDING_BITE"
local PROFILE_CRAWLER_LUNGE = "CRAWLER_LUNGE"
local PROFILE_STANDING_STOMP = "STANDING_STOMP"

local VALIDATION_DELAY_TICKS = 30
local VALIDATION_SAMPLE_LIMIT = 10
local SERVER_TICKS_PER_SECOND = 10
local TARGET_PROBE_DELAY_TICKS = 3 * SERVER_TICKS_PER_SECOND
local TARGET_PROBE_SAMPLE_TICKS = 15
local TARGET_PROBE_PERSISTENT = true
local TARGET_PROBE_RADIUS = 12
local TARGET_PROBE_RELEASE_RADIUS = 18
local TARGET_PROBE_SCAN_INTERVAL_TICKS = SERVER_TICKS_PER_SECOND
local TARGET_PROBE_REACQUIRE_DELAY_TICKS = 3
local TARGET_PROBE_SCAN_BUDGET_PER_TICK = 4
local MOB_MAINTENANCE_INTERVAL_TICKS = SERVER_TICKS_PER_SECOND
local MOB_RECRUITMENT_RADIUS_FALLBACK = 20
local MOB_WAKE_GRANT_BUDGET_PER_TICK = 8
local TARGET_LOAD_PENALTY = 9
local TARGET_AVOID_PENALTY = 10000
local DISCOVERY_BUCKET_SIZE = TARGET_PROBE_RADIUS
local DISCOVERY_INDEX_REFRESH_TICKS = 5
local DAMAGE_PROBE_AMOUNT = 0.25
local CLIENT_COLLISION_DISTANCE_DEFAULT = 0.80
local SERVER_VALIDATION_DISTANCE_DEFAULT = 1.60
local COMBAT_DISTANCE_MIN = 0.25
local COMBAT_DISTANCE_MAX = 2.00
local DAMAGE_PROBE_COOLDOWN_TICKS = 10
local DAMAGE_PROBE_ACK_TIMEOUT_TICKS = 120
local DAMAGE_PROBE_HEALTH_EPSILON = 0.01
local PERFORMANCE_SUMMARY_TICKS = 5 * SERVER_TICKS_PER_SECOND
local SERVER_VERBOSE_DIAGNOSTICS = true

local function combatDistanceOption(name, fallback)
    local options = SandboxVars and SandboxVars.ZombieFactions
    local value = options and tonumber(options[name]) or fallback
    if not value or value ~= value then return fallback end
    return math.max(COMBAT_DISTANCE_MIN, math.min(COMBAT_DISTANCE_MAX, value))
end

local function configuredClientCollisionDistance()
    return combatDistanceOption("ClientCollisionDistance", CLIENT_COLLISION_DISTANCE_DEFAULT)
end

local function configuredServerValidationDistance()
    return combatDistanceOption("ServerValidationDistance", SERVER_VALIDATION_DISTANCE_DEFAULT)
end

ZombieFactions.TestHarnessSequence = ZombieFactions.TestHarnessSequence or 0
ZombieFactions.PendingAssignmentValidations = ZombieFactions.PendingAssignmentValidations or {}
ZombieFactions.PendingTargetProbes = ZombieFactions.PendingTargetProbes or {}
ZombieFactions.ActiveTargetProbes = ZombieFactions.ActiveTargetProbes or {}
ZombieFactions.DamageProbeSequence = ZombieFactions.DamageProbeSequence or 0
ZombieFactions.TargetProbeDiscoveryIndex = nil
ZombieFactions.TargetProbeDiscoveryIndexTicks = 0
ZombieFactions.TargetProbeDiscoveryIndexSequence = ZombieFactions.TargetProbeDiscoveryIndexSequence or 0
ZombieFactions.TargetProbeMobSequence = ZombieFactions.TargetProbeMobSequence or 0
ZombieFactions.TargetProbeMobs = ZombieFactions.TargetProbeMobs or {}
ZombieFactions.TargetProbeMobBySubjectId = ZombieFactions.TargetProbeMobBySubjectId or {}
ZombieFactions.PendingMobWakeups = ZombieFactions.PendingMobWakeups or {}
ZombieFactions.MobWakeupBySubjectId = ZombieFactions.MobWakeupBySubjectId or {}

local alwaysPrint = print
alwaysPrint(string.format(
    "[ZombieFactions] Server test harness loaded v0.0.38 clientCollisionDistance=%.2f serverValidationDistance=%.2f",
    configuredClientCollisionDistance(),
    configuredServerValidationDistance()
))

local function print(message)
    if SERVER_VERBOSE_DIAGNOSTICS then alwaysPrint(message) end
end

local performanceCounters = {}
local performanceSummaryCountdown = PERFORMANCE_SUMMARY_TICKS
local mobMaintenanceCountdown = MOB_MAINTENANCE_INTERVAL_TICKS

local function countPerformance(name, amount)
    performanceCounters[name] = (performanceCounters[name] or 0) + (tonumber(amount) or 1)
end

local function performanceValue(name)
    return performanceCounters[name] or 0
end

local function setPerformanceMax(name, value)
    value = tonumber(value)
    if not value then return end
    performanceCounters[name] = math.max(performanceCounters[name] or 0, value)
end

local function performanceAverage(totalName, sampleName)
    local samples = performanceValue(sampleName)
    if samples <= 0 then return 0 end
    return performanceValue(totalName) / samples
end

local function printPerformanceSummary()
    local pendingCount = #ZombieFactions.PendingTargetProbes
    local activeCount = #ZombieFactions.ActiveTargetProbes
    local wakeCount = #ZombieFactions.PendingMobWakeups
    local mobCount = 0
    local mobMembers = 0
    for _, mob in pairs(ZombieFactions.TargetProbeMobs) do
        mobCount = mobCount + 1
        mobMembers = mobMembers + #mob.members
    end
    local dormantCount = math.max(0, mobMembers - activeCount - pendingCount - wakeCount)
    if pendingCount == 0 and activeCount == 0 and mobCount == 0 then
        performanceCounters = {}
        return
    end
    alwaysPrint(string.format(
        "[ZombieFactions][SERVER_PERF] clientCollisionDistance=%.2f serverValidationDistance=%.2f mobs=%d mobMembers=%d dormant=%d pendingLeaders=%d pendingWakeups=%d active=%d scans=%d leaderScans=%d memberSelections=%d memberRetargets=%d recruits=%d departures=%d terminations=%d leaderChanges=%d reactiveWakeups=%d sharedAssignments=%d distributedAssignments=%d loadBalancedSelections=%d stuckReacquires=%d grants=%d releases=%d damageRequests=%d damageDispatched=%d damageRejected=%d damageDistanceRejected=%d damageConfigMismatch=%d damageProfileRejected=%d damageAccepted=%d damageDispatchedServerDistanceAvg=%.3f damageDispatchedClientDistanceAvg=%.3f damageDistanceRejectedServerDistanceAvg=%.3f damageDistanceRejectedServerDistanceMax=%.3f damageDistanceRejectedClientDistanceAvg=%.3f",
        configuredClientCollisionDistance(),
        configuredServerValidationDistance(),
        mobCount,
        mobMembers,
        dormantCount,
        pendingCount,
        wakeCount,
        activeCount,
        performanceValue("scans"),
        performanceValue("leaderScans"),
        performanceValue("memberSelections"),
        performanceValue("memberRetargets"),
        performanceValue("mobRecruits"),
        performanceValue("mobDepartures"),
        performanceValue("mobTerminations"),
        performanceValue("leaderChanges"),
        performanceValue("reactiveWakeups"),
        performanceValue("sharedAssignments"),
        performanceValue("distributedAssignments"),
        performanceValue("loadBalancedSelections"),
        performanceValue("stuckReacquires"),
        performanceValue("grants"),
        performanceValue("releases"),
        performanceValue("damageRequests"),
        performanceValue("damageDispatched"),
        performanceValue("damageRejected"),
        performanceValue("damageDistanceRejected"),
        performanceValue("damageConfigMismatch"),
        performanceValue("damageProfileRejected"),
        performanceValue("damageAccepted"),
        performanceAverage("damageDispatchedServerDistanceTotal", "damageDispatchedDistanceSamples"),
        performanceAverage("damageDispatchedClientDistanceTotal", "damageDispatchedClientDistanceSamples"),
        performanceAverage("damageDistanceRejectedServerDistanceTotal", "damageDistanceRejectedDistanceSamples"),
        performanceValue("damageDistanceRejectedServerDistanceMax"),
        performanceAverage("damageDistanceRejectedClientDistanceTotal", "damageDistanceRejectedClientDistanceSamples")
    ))
    performanceCounters = {}
end

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

local function isAllowedRelationship(relationship)
    return relationship == FRIENDLY or relationship == NEUTRAL or relationship == HOSTILE
end

local function configureRelationships(factionId, toVanilla, fromVanilla, symmetric)
    if symmetric then fromVanilla = toVanilla end
    if not isAllowedRelationship(toVanilla) or not isAllowedRelationship(fromVanilla) then
        return false, "invalid relationship"
    end
    if factionId == VANILLA then return true end

    -- All inputs and both registered source factions are validated before the
    -- first write, so the two directional updates cannot partially apply.
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

local function ownerPlayer(zombie)
    if not zombie then return nil end
    local ok, player = pcall(function()
        return zombie:getOwnerPlayer()
    end)
    if not ok then return nil end
    return player
end

local function ownerUsername(zombie)
    local player = ownerPlayer(zombie)
    if not player then return "none" end

    local okName, username = pcall(function()
        return player:getUsername()
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

local function healthValue(zombie)
    if not zombie then return -1 end
    local ok, value = pcall(function()
        return zombie:getHealth()
    end)
    if ok and value ~= nil then return tonumber(value) or -1 end
    return -1
end

local function distanceSquared(a, b)
    if not a or not b then return math.huge end
    local dx = a:getX() - b:getX()
    local dy = a:getY() - b:getY()
    return dx * dx + dy * dy
end

local function sameLevel(a, b)
    if not a or not b then return false end
    return math.floor(a:getZ()) == math.floor(b:getZ())
end

local function isCrawler(zombie)
    if not zombie or zombie.isCrawling == nil then return false end
    local ok, crawling = pcall(function() return zombie:isCrawling() end)
    return ok and crawling == true
end

local function isSitting(zombie)
    if not zombie or zombie.isSitAgainstWall == nil then return false end
    local ok, sitting = pcall(function() return zombie:isSitAgainstWall() end)
    return ok and sitting == true
end

local function expectedAttackProfile(subject, candidate)
    if isCrawler(subject) then return PROFILE_CRAWLER_LUNGE end
    if isCrawler(candidate) or isSitting(candidate) then return PROFILE_STANDING_STOMP end
    return PROFILE_STANDING_BITE
end

local function expectedImpactEvidence(profile)
    if profile == PROFILE_STANDING_BITE then return "character-collision" end
    return "animation-window"
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

local function activePlayerOnlineIds()
    local ids = {}
    local ok, players = pcall(function()
        return getOnlinePlayers()
    end)
    if not ok or not players then return ids end

    for i = 0, players:size() - 1 do
        local player = players:get(i)
        local idOk, playerId = pcall(function()
            return player:getOnlineID()
        end)
        if idOk and playerId ~= nil then
            local numericId = tonumber(playerId)
            if numericId ~= nil then
                ids[numericId] = true
            end
        end
    end
    return ids
end

local function discoveryBucketKey(bucketX, bucketY, z)
    return tostring(bucketX) .. ":" .. tostring(bucketY) .. ":" .. tostring(z)
end

local function buildDiscoveryIndex()
    ZombieFactions.TargetProbeDiscoveryIndexSequence = ZombieFactions.TargetProbeDiscoveryIndexSequence + 1
    local index = {
        buckets = {},
        loaded = 0,
        playerOnlineIds = activePlayerOnlineIds(),
        generation = ZombieFactions.TargetProbeDiscoveryIndexSequence,
        bucketCount = 0,
    }
    local zombies = getCell():getZombieList()
    if not zombies then
        ZombieFactions.TargetProbeDiscoveryIndex = index
        ZombieFactions.TargetProbeDiscoveryIndexTicks = DISCOVERY_INDEX_REFRESH_TICKS
        return index
    end

    index.loaded = zombies:size()
    for i = 0, zombies:size() - 1 do
        local zombie = zombies:get(i)
        if zombie and not isDead(zombie) then
            local bucketX = math.floor(zombie:getX() / DISCOVERY_BUCKET_SIZE)
            local bucketY = math.floor(zombie:getY() / DISCOVERY_BUCKET_SIZE)
            local z = math.floor(zombie:getZ())
            local key = discoveryBucketKey(bucketX, bucketY, z)
            local bucket = index.buckets[key]
            if not bucket then
                bucket = {}
                index.buckets[key] = bucket
                index.bucketCount = index.bucketCount + 1
            end
            bucket[#bucket + 1] = zombie
        end
    end

    ZombieFactions.TargetProbeDiscoveryIndex = index
    ZombieFactions.TargetProbeDiscoveryIndexTicks = DISCOVERY_INDEX_REFRESH_TICKS
    return index
end

local function getDiscoveryIndex()
    if not ZombieFactions.TargetProbeDiscoveryIndex
        or ZombieFactions.TargetProbeDiscoveryIndexTicks <= 0
    then
        return buildDiscoveryIndex()
    end
    return ZombieFactions.TargetProbeDiscoveryIndex
end

local function buildTargetLoads()
    local loads = {}
    for i = 1, #ZombieFactions.ActiveTargetProbes do
        local record = ZombieFactions.ActiveTargetProbes[i]
        if record.candidateId ~= nil and not isDead(record.candidate) then
            loads[record.candidateId] = (loads[record.candidateId] or 0) + 1
        end
    end
    for i = 1, #ZombieFactions.PendingMobWakeups do
        local record = ZombieFactions.PendingMobWakeups[i]
        if record.candidateId ~= nil and not isDead(record.candidate) then
            loads[record.candidateId] = (loads[record.candidateId] or 0) + 1
        end
    end
    return loads
end

local function findNearestEligibleZombie(subject, radius, index, targetLoads, avoidCandidateId, requiredTargetFaction)
    local stats = {
        loaded = 0,
        inRadius = 0,
        eligible = 0,
        friendly = 0,
        neutral = 0,
        unset = 0,
        wrongLevel = 0,
        idCollision = 0,
        unaddressable = 0,
        unsupported = 0,
        targetFactionMismatch = 0,
    }
    if not subject then return nil, math.huge, nil, nil, nil, stats end

    index = index or getDiscoveryIndex()
    targetLoads = targetLoads or {}
    stats.loaded = index.loaded or 0

    local maxDist2 = radius * radius
    local playerOnlineIds = index.playerOnlineIds or {}
    local best = nil
    local bestDist2 = maxDist2 + 1
    local bestScore = math.huge
    local bestSourceFaction = nil
    local bestTargetFaction = nil
    local bestRelationship = nil
    local nearestDist2 = math.huge

    local subjectBucketX = math.floor(subject:getX() / DISCOVERY_BUCKET_SIZE)
    local subjectBucketY = math.floor(subject:getY() / DISCOVERY_BUCKET_SIZE)
    local subjectZ = math.floor(subject:getZ())
    local bucketRadius = math.ceil(radius / DISCOVERY_BUCKET_SIZE)

    for bucketX = subjectBucketX - bucketRadius, subjectBucketX + bucketRadius do
        for bucketY = subjectBucketY - bucketRadius, subjectBucketY + bucketRadius do
            local bucket = index.buckets[discoveryBucketKey(bucketX, bucketY, subjectZ)] or {}
            for i = 1, #bucket do
                local candidate = bucket[i]
                if candidate and candidate ~= subject and not isDead(candidate) then
                    local dist2 = distanceSquared(subject, candidate)
                    if dist2 <= maxDist2 then
                        stats.inRadius = stats.inRadius + 1
                        if not sameLevel(subject, candidate) then
                            stats.wrongLevel = stats.wrongLevel + 1
                        else
                            local candidateId = zombieOnlineId(candidate)
                            if candidateId == -1 then
                                stats.unaddressable = stats.unaddressable + 1
                            elseif playerOnlineIds[candidateId] == true then
                                stats.idCollision = stats.idCollision + 1
                            else
                                local allowed, sourceFaction, targetFaction, relationship, reason =
                                    ZombieFactions.canTarget(subject, candidate)
                                if allowed and (not requiredTargetFaction or targetFaction == requiredTargetFaction) then
                                    stats.eligible = stats.eligible + 1
                                    if dist2 < nearestDist2 then
                                        nearestDist2 = dist2
                                        stats.nearestId = candidateId
                                    end
                                    local targetLoad = targetLoads[candidateId] or 0
                                    local score = dist2 + targetLoad * TARGET_LOAD_PENALTY
                                    if candidateId == avoidCandidateId then
                                        score = score + TARGET_AVOID_PENALTY
                                    end
                                    if score < bestScore
                                        or (score == bestScore and dist2 < bestDist2)
                                    then
                                        best = candidate
                                        bestDist2 = dist2
                                        bestScore = score
                                        bestSourceFaction = sourceFaction
                                        bestTargetFaction = targetFaction
                                        bestRelationship = relationship
                                        stats.selectedLoad = targetLoad
                                        stats.selectedScore = score
                                    end
                                elseif allowed then
                                    stats.targetFactionMismatch = stats.targetFactionMismatch + 1
                                elseif reason == "friendly" then
                                    stats.friendly = stats.friendly + 1
                                elseif reason == "neutral" then
                                    stats.neutral = stats.neutral + 1
                                elseif reason == "relationship-unset" then
                                    stats.unset = stats.unset + 1
                                else
                                    stats.unsupported = stats.unsupported + 1
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return best, bestDist2, bestSourceFaction, bestTargetFaction, bestRelationship, stats
end

local function subjectHasProbe(subject)
    local subjectId = zombieOnlineId(subject)
    if subjectId == -1 then return false end
    for i = 1, #ZombieFactions.PendingTargetProbes do
        if ZombieFactions.PendingTargetProbes[i].subjectId == subjectId then return true end
    end
    for i = 1, #ZombieFactions.ActiveTargetProbes do
        if ZombieFactions.ActiveTargetProbes[i].subjectId == subjectId then return true end
    end
    return false
end

local function pendingProbeForSubjectId(subjectId)
    for i = 1, #ZombieFactions.PendingTargetProbes do
        local record = ZombieFactions.PendingTargetProbes[i]
        if record.subjectId == subjectId then return record end
    end
    return nil
end

local function pendingProbeForMobId(mobId)
    for i = 1, #ZombieFactions.PendingTargetProbes do
        local record = ZombieFactions.PendingTargetProbes[i]
        if record.mobId == mobId then return record end
    end
    return nil
end

local function zombieMobSize()
    local options = SandboxVars and SandboxVars.ZombieFactions
    local value = options and tonumber(options.ZombieMobSize) or 1
    if not value then return 1 end
    value = math.floor(value)
    if value < 0 then return 0 end
    return value
end

local function mobRecruitmentRadius()
    local zombieConfig = SandboxVars and SandboxVars.ZombieConfig
    local value = zombieConfig and tonumber(zombieConfig.RallyTravelDistance)
        or MOB_RECRUITMENT_RADIUS_FALLBACK
    if not value then return MOB_RECRUITMENT_RADIUS_FALLBACK end
    return math.max(1, math.min(50, math.floor(value)))
end

local function mobTargetRetentionRadius()
    return math.max(TARGET_PROBE_RELEASE_RADIUS, TARGET_PROBE_RADIUS + mobRecruitmentRadius())
end

local function nextMobId()
    ZombieFactions.TargetProbeMobSequence = ZombieFactions.TargetProbeMobSequence + 1
    return ZombieFactions.TargetProbeMobSequence
end

local queueTargetSubject
local activateMobMemberAgainstCurrent

local function stableMobBySubjectId(subjectId)
    local mobId = ZombieFactions.TargetProbeMobBySubjectId[subjectId]
    return mobId and ZombieFactions.TargetProbeMobs[mobId] or nil
end

local function memberIsValid(mob, member)
    return member
        and member.subject
        and not isDead(member.subject)
        and zombieOnlineId(member.subject) == member.subjectId
        and ZombieFactions.getZombieFaction(member.subject) == mob.factionId
end

local function mobHasRoom(mob)
    local configuredSize = zombieMobSize()
    return configuredSize == 0 or #mob.members < configuredSize
end

local function findMobMember(mob, subjectId)
    if not mob then return nil end
    for i = 1, #mob.members do
        if mob.members[i].subjectId == subjectId then return mob.members[i], i end
    end
    return nil
end

local function chooseMobLeader(mob, reason)
    if not mob or #mob.members == 0 then return nil end

    local centerX = 0
    local centerY = 0
    local validCount = 0
    local ownedCount = 0
    local currentMember = nil
    for i = 1, #mob.members do
        local member = mob.members[i]
        if memberIsValid(mob, member) then
            centerX = centerX + member.subject:getX()
            centerY = centerY + member.subject:getY()
            validCount = validCount + 1
            if ownerPlayer(member.subject) then ownedCount = ownedCount + 1 end
            if member.subjectId == mob.leaderId then currentMember = member end
        end
    end
    if validCount == 0 then return nil end
    centerX = centerX / validCount
    centerY = centerY / validCount
    if ownedCount == 0 and currentMember then return currentMember end

    local radius = mobRecruitmentRadius()
    local currentNearMob = currentMember and ownerPlayer(currentMember.subject) and validCount == 1
    if currentMember and ownerPlayer(currentMember.subject) and validCount > 1 then
        for i = 1, #mob.members do
            local other = mob.members[i]
            if other.subjectId ~= currentMember.subjectId
                and memberIsValid(mob, other)
                and sameLevel(currentMember.subject, other.subject)
                and distanceSquared(currentMember.subject, other.subject) <= radius * radius
            then
                currentNearMob = true
                break
            end
        end
    end
    if currentNearMob then return currentMember end

    local best = nil
    local bestDistance = math.huge
    local fallback = nil
    local fallbackDistance = math.huge
    for i = 1, #mob.members do
        local member = mob.members[i]
        if memberIsValid(mob, member)
            and (currentNearMob or member.subjectId ~= mob.leaderId or validCount == 1)
        then
            local dx = member.subject:getX() - centerX
            local dy = member.subject:getY() - centerY
            local dist2 = dx * dx + dy * dy
            if dist2 < fallbackDistance then
                fallback = member
                fallbackDistance = dist2
            end
            if ownerPlayer(member.subject) and dist2 < bestDistance then
                best = member
                bestDistance = dist2
            end
        end
    end

    local selected = best or fallback
    if selected and selected.subjectId ~= mob.leaderId then
        local previousLeaderId = mob.leaderId or -1
        mob.leaderId = selected.subjectId
        mob.leader = selected.subject
        countPerformance("leaderChanges")
        print(string.format(
            "[ZombieFactions][MOB] phase=leader-change mobId=%d previous=%d current=%d reason=%s members=%d",
            mob.id,
            previousLeaderId,
            selected.subjectId,
            tostring(reason or "availability"),
            #mob.members
        ))
    elseif selected then
        mob.leader = selected.subject
    end
    return selected
end

local function nearestRecruitableMob(subject, factionId)
    local radius2 = mobRecruitmentRadius() ^ 2
    local nearest = nil
    local nearestDistance = math.huge
    local subjectZ = math.floor(subject:getZ())
    for _, mob in pairs(ZombieFactions.TargetProbeMobs) do
        if mob.factionId == factionId and mobHasRoom(mob) then
            local leaderMember = chooseMobLeader(mob, "recruitment")
            if leaderMember and math.floor(leaderMember.subject:getZ()) == subjectZ then
                local dist2 = distanceSquared(subject, leaderMember.subject)
                if dist2 <= radius2 and dist2 < nearestDistance then
                    nearest = mob
                    nearestDistance = dist2
                end
            end
        end
    end
    return nearest
end

local function ensureStableMobMembership(subject, runId, requester)
    if not subject or isDead(subject) then return nil, nil, "subject-unavailable" end
    local subjectId = zombieOnlineId(subject)
    if subjectId == -1 then return nil, nil, "subject-unaddressable" end

    local existing = stableMobBySubjectId(subjectId)
    if existing then
        local member = findMobMember(existing, subjectId)
        if member and member.subject == subject and memberIsValid(existing, member) then
            return existing, member, nil
        end
        ZombieFactions.TargetProbeMobBySubjectId[subjectId] = nil
    end

    local factionId = ZombieFactions.getZombieFaction(subject)
    local mob = nearestRecruitableMob(subject, factionId)
    local created = false
    if not mob then
        local mobId = nextMobId()
        mob = {
            id = mobId,
            factionId = factionId,
            members = {},
            leader = subject,
            leaderId = subjectId,
            currentCandidate = nil,
            currentCandidateId = -1,
            targetFaction = nil,
            createdRunId = runId,
            requester = requester,
        }
        ZombieFactions.TargetProbeMobs[mobId] = mob
        created = true
    end

    local member = {
        subject = subject,
        subjectId = subjectId,
        runId = runId,
        requester = requester,
    }
    mob.members[#mob.members + 1] = member
    ZombieFactions.TargetProbeMobBySubjectId[subjectId] = mob.id
    countPerformance("mobRecruits")
    print(string.format(
        "[ZombieFactions][%s][MOB] phase=%s mobId=%d subject=%d faction=%s leader=%d members=%d configuredSize=%d recruitmentRadius=%d",
        tostring(runId),
        created and "created" or "recruited",
        mob.id,
        subjectId,
        tostring(factionId),
        mob.leaderId,
        #mob.members,
        zombieMobSize(),
        mobRecruitmentRadius()
    ))
    return mob, member, nil
end

local function mobHasActiveProbe(mob)
    if not mob then return false end
    for i = 1, #ZombieFactions.ActiveTargetProbes do
        if ZombieFactions.ActiveTargetProbes[i].mobId == mob.id then return true end
    end
    for i = 1, #ZombieFactions.PendingMobWakeups do
        if ZombieFactions.PendingMobWakeups[i].mobId == mob.id then return true end
    end
    return false
end

local function refreshPendingLeader(record)
    local mob = record and record.mob
    if not mob then return false end
    local leaderMember = chooseMobLeader(mob, "pending-refresh")
    if not leaderMember then return false end
    record.subject = leaderMember.subject
    record.subjectId = leaderMember.subjectId
    record.runId = leaderMember.runId or record.runId
    record.requester = leaderMember.requester or record.requester
    record.sourceFaction = mob.factionId
    mob.pendingLeaderId = leaderMember.subjectId
    return true
end

queueTargetSubject = function(subject, runId, requester, remaining, reason, delay, avoidCandidateId, preferredCandidate)
    local mob, _, membershipReason = ensureStableMobMembership(subject, runId, requester)
    if not mob then return false, membershipReason end
    local leaderMember = chooseMobLeader(mob, reason or "queue")
    if not leaderMember then return false, "mob-has-no-leader" end
    if mobHasActiveProbe(mob) then
        if not subjectHasProbe(subject)
            and activateMobMemberAgainstCurrent
            and activateMobMemberAgainstCurrent(mob, subject)
        then
            return true, "mob-active-member-joined"
        end
        return false, "mob-already-active"
    end
    local pending = pendingProbeForMobId(mob.id) or pendingProbeForSubjectId(leaderMember.subjectId)
    if pending then
        if preferredCandidate then
            pending.preferredCandidate = preferredCandidate
            pending.reason = reason or pending.reason
            pending.scanCountdown = math.min(pending.scanCountdown, delay or 0)
            return true, "mob-leader-woken"
        end
        return false, "mob-leader-already-queued"
    end
    if subjectHasProbe(leaderMember.subject) then return false, "mob-leader-already-active" end

    ZombieFactions.PendingTargetProbes[#ZombieFactions.PendingTargetProbes + 1] = {
        runId = leaderMember.runId or runId,
        requester = leaderMember.requester or requester,
        subject = leaderMember.subject,
        subjectId = leaderMember.subjectId,
        remaining = remaining or 0,
        persistent = TARGET_PROBE_PERSISTENT,
        scanCountdown = delay or TARGET_PROBE_DELAY_TICKS,
        scanAttempts = 0,
        reason = reason or "spawn",
        sourceFaction = mob.factionId,
        avoidCandidateId = avoidCandidateId,
        preferredCandidate = preferredCandidate,
        mob = mob,
        mobId = mob.id,
    }
    mob.pendingLeaderId = leaderMember.subjectId
    mob.state = "searching"
    return true, nil
end

local function maintainStableMobs()
    for mobId, mob in pairs(ZombieFactions.TargetProbeMobs) do
        for i = #mob.members, 1, -1 do
            local member = mob.members[i]
            if not memberIsValid(mob, member) then
                if ZombieFactions.TargetProbeMobBySubjectId[member.subjectId] == mobId then
                    ZombieFactions.TargetProbeMobBySubjectId[member.subjectId] = nil
                end
                table.remove(mob.members, i)
                countPerformance("mobDepartures")
            end
        end

        if #mob.members == 0 then
            ZombieFactions.TargetProbeMobs[mobId] = nil
            countPerformance("mobTerminations")
        else
            local leaderMember = chooseMobLeader(mob, "maintenance")
            if mob.currentCandidate and isDead(mob.currentCandidate) then
                mob.currentCandidate = nil
                mob.currentCandidateId = -1
            end
            if leaderMember and not mobHasActiveProbe(mob) then
                queueTargetSubject(
                    leaderMember.subject,
                    leaderMember.runId,
                    leaderMember.requester,
                    nil,
                    "mob-dormant-wake",
                    TARGET_PROBE_SCAN_INTERVAL_TICKS
                )
            elseif leaderMember and activateMobMemberAgainstCurrent then
                -- The mob already has an active prober elsewhere. That prober's
                -- own activity never revisits its idle mobmates, so sweep them
                -- here instead of leaving them dormant for the mob's lifetime.
                for i = 1, #mob.members do
                    local member = mob.members[i]
                    if memberIsValid(mob, member)
                        and ownerPlayer(member.subject)
                        and not ZombieFactions.MobWakeupBySubjectId[member.subjectId]
                        and not subjectHasProbe(member.subject)
                    then
                        activateMobMemberAgainstCurrent(mob, member.subject)
                    end
                end
            end
        end
    end
end

local function sendTargetGrant(record, reason)
    local player = ownerPlayer(record.subject)
    local owner = ownerUsername(record.subject)
    if not player or owner == "none" or owner == "unknown" then return false end

    record.clientCollisionDistance = record.clientCollisionDistance
        or configuredClientCollisionDistance()
    record.serverValidationDistance = record.serverValidationDistance
        or configuredServerValidationDistance()
    record.ownerAtGrant = owner
    record.grantCount = (record.grantCount or 0) + 1
    local payload = {
        requester = record.requester,
        targetOwner = owner,
        runId = record.runId,
        subjectId = record.subjectId,
        candidateId = record.candidateId,
        factionId = record.sourceFaction,
        candidateFactionId = record.targetFaction,
        relationship = record.relationship,
        owner = owner,
        persistent = record.persistent == true,
        grantCount = record.grantCount,
        grantReason = reason or "acquired",
        mobId = record.mobId,
        mobLeaderId = record.mobLeaderId,
        mobMemberIndex = record.mobMemberIndex,
        clientCollisionDistance = record.clientCollisionDistance,
        serverValidationDistance = record.serverValidationDistance,
    }
    if record.persistent ~= true then
        payload.expiresInTicks = record.remaining
        payload.expiresInSeconds = math.ceil(record.remaining / SERVER_TICKS_PER_SECOND)
    end
    sendServerCommand(player, MODULE, TARGET_PROBE_COMMAND, payload)
    countPerformance("grants")

    print(string.format(
        "[ZombieFactions][%s][ACQUISITION_PROBE] phase=grant reason=%s grant=%d subject=%d sourceFaction=%s owner=%s candidate=%d targetFaction=%s relationship=%s distance=%.2f clientCollisionDistance=%.2f serverValidationDistance=%.2f expiresInTicks=%d candidateHealth=%.3f requester=%s",
        record.runId,
        tostring(reason or "acquired"),
        record.grantCount,
        record.subjectId,
        tostring(record.sourceFaction),
        owner,
        record.candidateId,
        tostring(record.targetFaction),
        tostring(record.relationship),
        math.sqrt(distanceSquared(record.subject, record.candidate)),
        record.clientCollisionDistance,
        record.serverValidationDistance,
        record.remaining,
        healthValue(record.candidate),
        tostring(record.requester)
    ))
    return true
end


local function activateTargetProbe(record, candidate, sourceFaction, targetFaction, relationship, mobId, mobLeaderId, mobMemberIndex, reason)
    local subject = record.subject
    local subjectId = zombieOnlineId(subject)
    local candidateId = zombieOnlineId(candidate)
    if subjectId ~= record.subjectId or candidateId == -1 or not ownerPlayer(subject) then return nil end

    local active = {
        runId = record.runId,
        requester = record.requester,
        subject = subject,
        candidate = candidate,
        subjectId = subjectId,
        candidateId = candidateId,
        sourceFaction = sourceFaction,
        targetFaction = targetFaction,
        relationship = relationship,
        ownerAtGrant = "none",
        remaining = record.remaining,
        persistent = record.persistent == true,
        sampleCountdown = 0,
        lastSignature = nil,
        damageCooldown = 0,
        damageHits = 0,
        pendingDamage = nil,
        grantCount = 0,
        mobId = mobId,
        mobLeaderId = mobLeaderId,
        mobMemberIndex = mobMemberIndex,
        clientCollisionDistance = configuredClientCollisionDistance(),
        serverValidationDistance = configuredServerValidationDistance(),
    }
    ZombieFactions.ActiveTargetProbes[#ZombieFactions.ActiveTargetProbes + 1] = active
    sendTargetGrant(active, reason)
    return active
end

local function enqueueMobWakeup(mob, member, candidate, leaderId, memberIndex, reason)
    if not mob or not member or not candidate then return false end
    if ZombieFactions.MobWakeupBySubjectId[member.subjectId] then return false end
    if subjectHasProbe(member.subject) then return false end
    local candidateId = zombieOnlineId(candidate)
    if candidateId == -1 then return false end
    local wakeup = {
        mob = mob,
        mobId = mob.id,
        member = member,
        subjectId = member.subjectId,
        candidate = candidate,
        candidateId = candidateId,
        targetFaction = ZombieFactions.getZombieFaction(candidate),
        leaderId = leaderId,
        memberIndex = memberIndex,
        reason = reason or "mob-shared",
        retryCountdown = 0,
    }
    ZombieFactions.PendingMobWakeups[#ZombieFactions.PendingMobWakeups + 1] = wakeup
    ZombieFactions.MobWakeupBySubjectId[member.subjectId] = wakeup
    return true
end

local function selectMobMemberTarget(mob, member, targetLoads, avoidCandidateId)
    if not mob or not member or not mob.targetFaction then return nil end
    countPerformance("memberSelections")
    local candidate, dist2, sourceFaction, targetFaction, relationship, stats = findNearestEligibleZombie(
        member.subject,
        mobTargetRetentionRadius(),
        getDiscoveryIndex(),
        targetLoads,
        avoidCandidateId,
        mob.targetFaction
    )
    if candidate and stats.nearestId ~= nil and zombieOnlineId(candidate) ~= stats.nearestId then
        countPerformance("loadBalancedSelections")
    end
    return candidate, dist2, sourceFaction, targetFaction, relationship, stats
end

activateMobMemberAgainstCurrent = function(mob, subject)
    if not mob or not subject or isDead(subject) or not ownerPlayer(subject) then return false end
    local member, memberIndex = findMobMember(mob, zombieOnlineId(subject))
    local leaderMember = chooseMobLeader(mob, "active-recruit")
    if not member or not leaderMember then return false end
    local targetLoads = buildTargetLoads()
    local candidate = selectMobMemberTarget(mob, member, targetLoads)
    if not candidate then return false end
    local queued = enqueueMobWakeup(
        mob,
        member,
        candidate,
        leaderMember.subjectId,
        memberIndex,
        "mob-active-recruit"
    )
    if queued then
        local candidateId = zombieOnlineId(candidate)
        targetLoads[candidateId] = (targetLoads[candidateId] or 0) + 1
    end
    return queued
end

local function shareTargetWithMob(leaderRecord, candidate, mob, targetFaction, targetLoads)
    local memberCount = 1
    local leaderId = leaderRecord.subjectId
    local leaderCandidateId = zombieOnlineId(candidate)
    local unavailableSubjects = {}
    for i = 1, #ZombieFactions.PendingTargetProbes do
        unavailableSubjects[ZombieFactions.PendingTargetProbes[i].subjectId] = true
    end
    for i = 1, #ZombieFactions.ActiveTargetProbes do
        unavailableSubjects[ZombieFactions.ActiveTargetProbes[i].subjectId] = true
    end

    mob.currentCandidate = candidate
    mob.currentCandidateId = leaderCandidateId
    mob.targetFaction = targetFaction
    mob.pendingLeaderId = nil
    mob.state = "active"

    for i = 1, #mob.members do
        local member = mob.members[i]
        if member.subjectId ~= leaderId
            and memberIsValid(mob, member)
            and ownerPlayer(member.subject)
            and unavailableSubjects[member.subjectId] ~= true
        then
            local memberCandidate, _, _, memberTargetFaction =
                selectMobMemberTarget(mob, member, targetLoads)
            if memberCandidate and memberTargetFaction == targetFaction then
                local queued = enqueueMobWakeup(
                    mob,
                    member,
                    memberCandidate,
                    leaderId,
                    i,
                    "mob-distributed"
                )
                if queued then
                    local memberCandidateId = zombieOnlineId(memberCandidate)
                    targetLoads[memberCandidateId] = (targetLoads[memberCandidateId] or 0) + 1
                    unavailableSubjects[member.subjectId] = true
                    memberCount = memberCount + 1
                    if memberCandidateId ~= leaderCandidateId then
                        countPerformance("distributedAssignments")
                    end
                end
            end
        end
    end

    return memberCount
end

local function removeMobWakeupAt(index)
    local wakeup = ZombieFactions.PendingMobWakeups[index]
    if wakeup and ZombieFactions.MobWakeupBySubjectId[wakeup.subjectId] == wakeup then
        ZombieFactions.MobWakeupBySubjectId[wakeup.subjectId] = nil
    end
    table.remove(ZombieFactions.PendingMobWakeups, index)
end

local function processPendingMobWakeups()
    local budget = MOB_WAKE_GRANT_BUDGET_PER_TICK
    for i = #ZombieFactions.PendingMobWakeups, 1, -1 do
        local wakeup = ZombieFactions.PendingMobWakeups[i]
        wakeup.retryCountdown = (wakeup.retryCountdown or 0) - 1
        if wakeup.retryCountdown <= 0 and budget > 0 then
            budget = budget - 1
            local mob = ZombieFactions.TargetProbeMobs[wakeup.mobId]
            local member = mob and findMobMember(mob, wakeup.subjectId) or nil
            local candidateValid = zombieOnlineId(wakeup.candidate) == wakeup.candidateId
                and not isDead(wakeup.candidate)
            if not mob
                or mob ~= wakeup.mob
                or not member
                or not memberIsValid(mob, member)
                or mob.targetFaction ~= wakeup.targetFaction
                or not candidateValid
                or subjectHasProbe(member.subject)
            then
                removeMobWakeupAt(i)
            elseif not ownerPlayer(member.subject) then
                wakeup.retryCountdown = TARGET_PROBE_SCAN_INTERVAL_TICKS
            else
                local allowed, sourceFaction, targetFaction, relationship =
                    ZombieFactions.canTarget(member.subject, wakeup.candidate)
                if not allowed
                    or targetFaction ~= mob.targetFaction
                    or not sameLevel(member.subject, wakeup.candidate)
                    or distanceSquared(member.subject, wakeup.candidate) > mobTargetRetentionRadius() * mobTargetRetentionRadius()
                then
                    removeMobWakeupAt(i)
                else
                    local memberRecord = {
                        runId = member.runId or mob.createdRunId,
                        requester = member.requester or mob.requester,
                        subject = member.subject,
                        subjectId = member.subjectId,
                        remaining = 0,
                        persistent = TARGET_PROBE_PERSISTENT,
                    }
                    local active = activateTargetProbe(
                        memberRecord,
                        wakeup.candidate,
                        sourceFaction,
                        targetFaction,
                        relationship,
                        mob.id,
                        mob.leaderId,
                        wakeup.memberIndex,
                        wakeup.reason
                    )
                    if active then countPerformance("sharedAssignments") end
                    removeMobWakeupAt(i)
                end
            end
        end
    end
end

local function sendTargetRelease(record, reason)
    local player = ownerPlayer(record.subject)
    local owner = ownerUsername(record.subject)
    if not player or owner == "none" or owner == "unknown" then return false end

    sendServerCommand(player, MODULE, TARGET_RELEASE_COMMAND, {
        targetOwner = owner,
        runId = record.runId,
        subjectId = record.subjectId,
        candidateId = record.candidateId,
        reason = reason or "released",
    })
    countPerformance("releases")
    return true
end

local function beginOwnerTargetProbe(record, index, targetLoads)
    if record.mob and not refreshPendingLeader(record) then return "terminal" end
    local subject = record.subject
    if not subject or isDead(subject) then
        print(string.format("[ZombieFactions][%s][TARGET_PROBE] subject unavailable before probe", record.runId))
        return "terminal"
    end
    local currentSubjectId = zombieOnlineId(subject)
    if currentSubjectId ~= record.subjectId then
        print(string.format(
            "[ZombieFactions][%s][ACQUISITION_PROBE] phase=no-grant reason=subject-identity-changed expected=%d actual=%d",
            record.runId,
            record.subjectId,
            currentSubjectId
        ))
        return "terminal"
    end

    local candidate = record.preferredCandidate
    local dist2 = candidate and distanceSquared(subject, candidate) or math.huge
    local sourceFaction = nil
    local targetFaction = nil
    local relationship = nil
    local stats = nil
    if candidate and not isDead(candidate) and sameLevel(subject, candidate)
        and dist2 <= mobTargetRetentionRadius() * mobTargetRetentionRadius()
    then
        local allowed
        allowed, sourceFaction, targetFaction, relationship = ZombieFactions.canTarget(subject, candidate)
        if not allowed then candidate = nil end
    else
        candidate = nil
    end
    if candidate then
        local candidateId = zombieOnlineId(candidate)
        stats = {
            loaded = index.loaded or 0,
            inRadius = 1,
            eligible = 1,
            friendly = 0,
            neutral = 0,
            unset = 0,
            wrongLevel = 0,
            idCollision = 0,
            unaddressable = 0,
            unsupported = 0,
            nearestId = candidateId,
            selectedLoad = targetLoads[candidateId] or 0,
        }
    else
        candidate, dist2, sourceFaction, targetFaction, relationship, stats =
            findNearestEligibleZombie(subject, TARGET_PROBE_RADIUS, index, targetLoads, record.avoidCandidateId)
    end
    countPerformance("scans")
    countPerformance("leaderScans")
    record.scanAttempts = (record.scanAttempts or 0) + 1
    local selectedId = candidate and zombieOnlineId(candidate) or -1
    if candidate and stats.nearestId ~= nil and selectedId ~= stats.nearestId then
        countPerformance("loadBalancedSelections")
    end
    print(string.format(
        "[ZombieFactions][%s][ACQUISITION_PROBE] phase=scan attempt=%d reason=%s indexGeneration=%d indexBuckets=%d subject=%d sourceFaction=%s radius=%d loaded=%d inRadius=%d eligible=%d friendly=%d neutral=%d unset=%d wrongLevel=%d sharedTargetsAllowed=true idCollision=%d unaddressable=%d unsupported=%d selected=%d",
        record.runId,
        record.scanAttempts,
        tostring(record.reason),
        index.generation or 0,
        index.bucketCount or 0,
        zombieOnlineId(subject),
        tostring(ZombieFactions.getZombieFaction(subject)),
        TARGET_PROBE_RADIUS,
        stats.loaded,
        stats.inRadius,
        stats.eligible,
        stats.friendly,
        stats.neutral,
        stats.unset,
        stats.wrongLevel,
        stats.idCollision,
        stats.unaddressable,
        stats.unsupported,
        selectedId
    ))

    if not candidate then
        print(string.format(
            "[ZombieFactions][%s][ACQUISITION_PROBE] phase=no-eligible-candidate subject=%d radius=%d retryInTicks=%d remaining=%d dispatched=false",
            record.runId,
            zombieOnlineId(subject),
            TARGET_PROBE_RADIUS,
            TARGET_PROBE_SCAN_INTERVAL_TICKS,
            record.remaining
        ))
        return "retry"
    end

    local subjectId = zombieOnlineId(subject)
    local candidateId = zombieOnlineId(candidate)
    if subjectId == -1 or candidateId == -1 then
        print(string.format(
            "[ZombieFactions][%s][ACQUISITION_PROBE] phase=no-grant reason=%s",
            record.runId,
            subjectId == -1 and "subject-unaddressable" or "candidate-unaddressable"
        ))
        return "retry"
    end
    if not ownerPlayer(subject) then
        print(string.format(
            "[ZombieFactions][%s][ACQUISITION_PROBE] phase=waiting-owner subject=%d candidate=%d retryInTicks=%d remaining=%d",
            record.runId,
            subjectId,
            candidateId,
            TARGET_PROBE_SCAN_INTERVAL_TICKS,
            record.remaining
        ))
        return "retry"
    end

    local mob = record.mob or stableMobBySubjectId(subjectId)
    if not mob then return "terminal" end
    local active = activateTargetProbe(
        record,
        candidate,
        sourceFaction,
        targetFaction,
        relationship,
        mob.id,
        subjectId,
        1,
        record.reason == "spawn" and "acquired" or tostring(record.reason)
    )
    if not active then return "retry" end
    targetLoads[candidateId] = (targetLoads[candidateId] or 0) + 1
    local mobMembers = shareTargetWithMob(
        record,
        candidate,
        mob,
        targetFaction,
        targetLoads
    )
    print(string.format(
        "[ZombieFactions][%s][ACQUISITION_PROBE] phase=mob mobId=%d leader=%d members=%d configuredSize=%d candidate=%d",
        record.runId,
        mob.id,
        subjectId,
        mobMembers,
        zombieMobSize(),
        candidateId
    ))

    local reverseAllowed = ZombieFactions.canTarget(candidate, subject)
    if reverseAllowed then
        local queued, queueReason = queueTargetSubject(
            candidate,
            record.runId,
            record.requester,
            record.remaining,
            "member-targeted",
            TARGET_PROBE_REACQUIRE_DELAY_TICKS,
            nil,
            subject
        )
        if queued then countPerformance("reactiveWakeups") end
        print(string.format(
            "[ZombieFactions][%s][ACQUISITION_PROBE] phase=reciprocal subject=%d candidate=%d queued=%s reason=%s",
            record.runId,
            candidateId,
            subjectId,
            tostring(queued),
            tostring(queueReason or "hostile-reverse")
        ))
    end

    return "active"
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
    local candidateHealth = healthValue(candidate)
    local signature = table.concat({
        tostring(subjectDead),
        tostring(candidateDead),
        tostring(targetId),
        tostring(retained),
        state,
        tostring(attacking),
        ownerUsername(subject),
        string.format("%.3f", candidateHealth),
    }, "|")

    if final or signature ~= record.lastSignature then
        print(string.format(
            "[ZombieFactions][%s][SERVER_OBSERVER] phase=%s subject=%d owner=%s target=%d expectedTarget=%d retained=%s state=%s attacking=%s distance=%.2f candidateHealth=%.3f damageHits=%d subjectDead=%s candidateDead=%s",
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
            candidateHealth,
            record.damageHits or 0,
            tostring(subjectDead),
            tostring(candidateDead)
        ))
        record.lastSignature = signature
    end
end

local function findActiveProbe(runId, subjectId, candidateId)
    for i = 1, #ZombieFactions.ActiveTargetProbes do
        local record = ZombieFactions.ActiveTargetProbes[i]
        if record.runId == runId and record.subjectId == subjectId and record.candidateId == candidateId then
            return record
        end
    end
    return nil
end

local function sendDamageResult(record, ok, message, pending, serverBeforeHealth, serverAfterHealth, candidateDead)
    pending = pending or {}
    sendServerCommand(MODULE, DAMAGE_RESULT_COMMAND, {
        requester = record.requester,
        runId = record.runId,
        subjectId = record.subjectId,
        candidateId = record.candidateId,
        ok = ok,
        message = message,
        hitId = pending.hitId,
        targetOwner = pending.ownerAtDispatch,
        ownerBeforeHealth = pending.ownerBeforeHealth,
        ownerAfterHealth = pending.ownerAfterHealth,
        serverBeforeHealth = serverBeforeHealth,
        serverAfterHealth = serverAfterHealth,
        candidateDead = candidateDead == true,
        damageHits = record.damageHits or 0,
    })
end

local function nextDamageHitId(runId)
    ZombieFactions.DamageProbeSequence = ZombieFactions.DamageProbeSequence + 1
    return string.format("%s-HIT-%04d", runId, ZombieFactions.DamageProbeSequence)
end

local function handleDamageProbe(player, args)
    args = args or {}
    if not player then return end

    local runId = tostring(args.runId or "")
    local subjectId = tonumber(args.subjectId)
    local candidateId = tonumber(args.candidateId)
    if runId == "" or subjectId == nil or candidateId == nil then return end
    countPerformance("damageRequests")

    local record = findActiveProbe(runId, subjectId, candidateId)
    if not record then
        countPerformance("damageRejected")
        print(string.format("[ZombieFactions][%s][DAMAGE_PROBE] rejected reason=no-active-probe subject=%s candidate=%s", runId, tostring(subjectId), tostring(candidateId)))
        return
    end

    local username = player:getUsername()
    if username ~= record.ownerAtGrant or ownerUsername(record.subject) ~= username then
        countPerformance("damageRejected")
        print(string.format("[ZombieFactions][%s][DAMAGE_PROBE] rejected reason=owner-mismatch grantOwner=%s player=%s owner=%s", runId, tostring(record.ownerAtGrant), tostring(username), ownerUsername(record.subject)))
        return
    end

    if isDead(record.subject) or isDead(record.candidate) then
        return
    end

    if record.damageCooldown > 0 then
        return
    end

    if record.pendingDamage then
        return
    end

    local allowed, sourceFaction, candidateFaction, relationship, policyReason =
        ZombieFactions.canTarget(record.subject, record.candidate)
    if not allowed then
        countPerformance("damageRejected")
        print(string.format(
            "[ZombieFactions][%s][DAMAGE_PROBE] rejected reason=policy policyReason=%s sourceFaction=%s candidateFaction=%s relationship=%s",
            runId,
            tostring(policyReason),
            tostring(sourceFaction),
            tostring(candidateFaction),
            tostring(relationship)
        ))
        return
    end

    local profile = expectedAttackProfile(record.subject, record.candidate)
    local reportedProfile = tostring(args.attackProfile or "")
    local impactEvidence = tostring(args.impactEvidence or "")
    if reportedProfile ~= profile or impactEvidence ~= expectedImpactEvidence(profile) then
        countPerformance("damageRejected")
        countPerformance("damageProfileRejected")
        print(string.format(
            "[ZombieFactions][%s][DAMAGE_PROBE] rejected reason=attack-profile expectedProfile=%s reportedProfile=%s expectedEvidence=%s reportedEvidence=%s subjectCrawler=%s candidateCrawler=%s candidateSitting=%s",
            runId,
            profile,
            reportedProfile,
            expectedImpactEvidence(profile),
            impactEvidence,
            tostring(isCrawler(record.subject)),
            tostring(isCrawler(record.candidate)),
            tostring(isSitting(record.candidate))
        ))
        return
    end

    if not sameLevel(record.subject, record.candidate) then
        countPerformance("damageRejected")
        print(string.format(
            "[ZombieFactions][%s][DAMAGE_PROBE] rejected reason=z-level subjectZ=%.2f candidateZ=%.2f",
            runId,
            record.subject:getZ(),
            record.candidate:getZ()
        ))
        return
    end

    local distance = math.sqrt(distanceSquared(record.subject, record.candidate))
    local clientDistanceAtCollision = tonumber(args.clientDistanceAtImpact)
        or tonumber(args.clientDistanceAtCollision)
    local clientCollisionDistance = tonumber(args.clientCollisionDistance)
    local effectiveClientCollisionDistance = record.clientCollisionDistance
        or configuredClientCollisionDistance()
    local serverValidationDistance = record.serverValidationDistance
        or configuredServerValidationDistance()
    local reportedServerValidationDistance = tonumber(args.serverValidationDistance)
    if not clientCollisionDistance
        or not reportedServerValidationDistance
        or math.abs(clientCollisionDistance - effectiveClientCollisionDistance) > 0.001
        or math.abs(reportedServerValidationDistance - serverValidationDistance) > 0.001
    then
        countPerformance("damageConfigMismatch")
    end
    if distance > serverValidationDistance then
        countPerformance("damageRejected")
        countPerformance("damageDistanceRejected")
        countPerformance("damageDistanceRejectedServerDistanceTotal", distance)
        countPerformance("damageDistanceRejectedDistanceSamples")
        setPerformanceMax("damageDistanceRejectedServerDistanceMax", distance)
        if clientDistanceAtCollision and clientDistanceAtCollision >= 0 then
            countPerformance("damageDistanceRejectedClientDistanceTotal", clientDistanceAtCollision)
            countPerformance("damageDistanceRejectedClientDistanceSamples")
        end
        print(string.format(
            "[ZombieFactions][%s][DAMAGE_PROBE] rejected reason=distance serverDistance=%.2f clientDistanceAtCollision=%s clientCollisionDistance=%.2f serverValidationDistance=%.2f",
            runId,
            distance,
            tostring(clientDistanceAtCollision),
            effectiveClientCollisionDistance,
            serverValidationDistance
        ))
        return
    end

    local targetOwnerPlayer = ownerPlayer(record.candidate)
    local targetOwner = ownerUsername(record.candidate)
    if not targetOwnerPlayer or targetOwner == "none" or targetOwner == "unknown" then
        countPerformance("damageRejected")
        print(string.format(
            "[ZombieFactions][%s][DAMAGE_PROBE] rejected reason=target-owner-unavailable candidate=%d owner=%s",
            runId,
            record.candidateId,
            targetOwner
        ))
        return
    end

    local beforeHealth = healthValue(record.candidate)
    local hitId = nextDamageHitId(runId)
    record.pendingDamage = {
        hitId = hitId,
        ownerAtDispatch = targetOwner,
        serverBeforeHealth = beforeHealth,
        amount = DAMAGE_PROBE_AMOUNT,
        attackProfile = profile,
        remaining = DAMAGE_PROBE_ACK_TIMEOUT_TICKS,
    }
    record.damageCooldown = DAMAGE_PROBE_COOLDOWN_TICKS
    countPerformance("damageDispatched")
    countPerformance("damageDispatchedServerDistanceTotal", distance)
    countPerformance("damageDispatchedDistanceSamples")
    if clientDistanceAtCollision and clientDistanceAtCollision >= 0 then
        countPerformance("damageDispatchedClientDistanceTotal", clientDistanceAtCollision)
        countPerformance("damageDispatchedClientDistanceSamples")
    end

    print(string.format(
        "[ZombieFactions][%s][DAMAGE_PROBE] phase=dispatch hitId=%s subject=%d candidate=%d attackProfile=%s impactEvidence=%s targetOwner=%s serverDistance=%.2f clientDistanceAtImpact=%s clientCollisionDistance=%.2f serverValidationDistance=%.2f amount=%.3f serverBeforeHealth=%.3f",
        runId,
        hitId,
        record.subjectId,
        record.candidateId,
        profile,
        impactEvidence,
        targetOwner,
        distance,
        tostring(clientDistanceAtCollision),
        effectiveClientCollisionDistance,
        serverValidationDistance,
        DAMAGE_PROBE_AMOUNT,
        beforeHealth
    ))

    sendServerCommand(targetOwnerPlayer, MODULE, DAMAGE_APPLY_COMMAND, {
        requester = record.requester,
        targetOwner = targetOwner,
        runId = runId,
        hitId = hitId,
        subjectId = record.subjectId,
        candidateId = record.candidateId,
        amount = DAMAGE_PROBE_AMOUNT,
        attackProfile = profile,
        alertX = math.floor(record.subject:getX()),
        alertY = math.floor(record.subject:getY()),
    })
end


local function handleDamageAck(player, args)
    args = args or {}
    if not player then return end

    local runId = tostring(args.runId or "")
    local hitId = tostring(args.hitId or "")
    local subjectId = tonumber(args.subjectId)
    local candidateId = tonumber(args.candidateId)
    if runId == "" or hitId == "" or subjectId == nil or candidateId == nil then return end

    local record = findActiveProbe(runId, subjectId, candidateId)
    local pending = record and record.pendingDamage or nil
    if not record or not pending or pending.hitId ~= hitId then
        print(string.format(
            "[ZombieFactions][%s][OWNER_DAMAGE] phase=ack-rejected reason=no-matching-pending-hit hitId=%s subject=%s candidate=%s",
            runId,
            hitId,
            tostring(subjectId),
            tostring(candidateId)
        ))
        return
    end

    local username = player:getUsername()
    local currentOwner = ownerUsername(record.candidate)
    local reportedAfterHealth = tonumber(args.afterHealth)
    local ownerReleasedByLethalHit = currentOwner == "none"
        and args.candidateDead == true
        and reportedAfterHealth ~= nil
        and reportedAfterHealth <= 0
    if username ~= pending.ownerAtDispatch
        or (currentOwner ~= username and not ownerReleasedByLethalHit)
    then
        print(string.format(
            "[ZombieFactions][%s][OWNER_DAMAGE] phase=ack-rejected reason=target-owner-mismatch hitId=%s dispatchedOwner=%s player=%s currentOwner=%s",
            runId,
            hitId,
            tostring(pending.ownerAtDispatch),
            tostring(username),
            tostring(currentOwner)
        ))
        record.pendingDamage = nil
        sendDamageResult(record, false, "target owner changed before acknowledgement", pending, healthValue(record.candidate), healthValue(record.candidate), isDead(record.candidate))
        return
    end

    if args.ok ~= true then
        print(string.format(
            "[ZombieFactions][%s][OWNER_DAMAGE] phase=ack-rejected reason=owner-apply-failed hitId=%s message=%s",
            runId,
            hitId,
            tostring(args.message or "")
        ))
        record.pendingDamage = nil
        sendDamageResult(record, false, tostring(args.message or "owner damage failed"), pending, healthValue(record.candidate), healthValue(record.candidate), isDead(record.candidate))
        return
    end

    local ownerBeforeHealth = tonumber(args.beforeHealth)
    local ownerAfterHealth = reportedAfterHealth
    if not ownerBeforeHealth or not ownerAfterHealth
        or ownerBeforeHealth ~= ownerBeforeHealth or ownerAfterHealth ~= ownerAfterHealth
        or ownerBeforeHealth < 0 or ownerAfterHealth < 0
    then
        print(string.format("[ZombieFactions][%s][OWNER_DAMAGE] phase=ack-rejected reason=invalid-health hitId=%s", runId, hitId))
        record.pendingDamage = nil
        sendDamageResult(record, false, "owner returned invalid health", pending, healthValue(record.candidate), healthValue(record.candidate), isDead(record.candidate))
        return
    end

    local expectedAfter = math.max(0, ownerBeforeHealth - pending.amount)
    if math.abs(ownerAfterHealth - expectedAfter) > DAMAGE_PROBE_HEALTH_EPSILON then
        print(string.format(
            "[ZombieFactions][%s][OWNER_DAMAGE] phase=ack-rejected reason=unexpected-delta hitId=%s amount=%.3f ownerBeforeHealth=%.3f ownerAfterHealth=%.3f expectedAfterHealth=%.3f",
            runId,
            hitId,
            pending.amount,
            ownerBeforeHealth,
            ownerAfterHealth,
            expectedAfter
        ))
        record.pendingDamage = nil
        pending.ownerBeforeHealth = ownerBeforeHealth
        pending.ownerAfterHealth = ownerAfterHealth
        sendDamageResult(record, false, "owner returned unexpected health delta", pending, healthValue(record.candidate), healthValue(record.candidate), isDead(record.candidate))
        return
    end

    pending.ownerBeforeHealth = ownerBeforeHealth
    pending.ownerAfterHealth = ownerAfterHealth
    local serverBeforeHealth = healthValue(record.candidate)
    local synchronizedHealth = math.min(serverBeforeHealth, ownerAfterHealth)
    local synchronized, synchronizeErr = pcall(function()
        record.candidate:setHealth(synchronizedHealth)
    end)
    if not synchronized then
        print(string.format(
            "[ZombieFactions][%s][OWNER_DAMAGE] phase=ack-rejected reason=server-health-sync-error hitId=%s error=%s",
            runId,
            hitId,
            tostring(synchronizeErr)
        ))
        record.pendingDamage = nil
        sendDamageResult(record, false, tostring(synchronizeErr), pending, serverBeforeHealth, healthValue(record.candidate), isDead(record.candidate))
        return
    end

    local lethal = synchronizedHealth <= 0 or args.candidateDead == true
    local deathLifecycleInvoked = false
    local deathErr = nil
    if lethal then
        deathLifecycleInvoked, deathErr = pcall(function()
            record.candidate:setAttackedBy(record.subject)
            record.candidate:die()
        end)
    end

    record.damageHits = (record.damageHits or 0) + 1
    countPerformance("damageAccepted")
    record.pendingDamage = nil
    local serverAfterHealth = healthValue(record.candidate)
    local dead = isDead(record.candidate)

    print(string.format(
        "[ZombieFactions][%s][OWNER_DAMAGE] phase=accepted hit=%d hitId=%s subject=%d candidate=%d targetOwner=%s amount=%.3f ownerBeforeHealth=%.3f ownerAfterHealth=%.3f serverBeforeHealth=%.3f serverAfterHealth=%.3f lethal=%s deathLifecycleInvoked=%s",
        runId,
        record.damageHits,
        hitId,
        record.subjectId,
        record.candidateId,
        username,
        pending.amount,
        ownerBeforeHealth,
        ownerAfterHealth,
        serverBeforeHealth,
        serverAfterHealth,
        tostring(lethal),
        tostring(deathLifecycleInvoked)
    ))

    local ok = not lethal or deathLifecycleInvoked
    local message = lethal and "owner damage synchronized; server death lifecycle invoked" or "owner damage synchronized"
    if lethal and not deathLifecycleInvoked then
        message = "owner damage synchronized; death lifecycle failed: " .. tostring(deathErr)
    end
    if not dead and ZombieFactions.canTarget(record.candidate, record.subject) then
        local queued = queueTargetSubject(
            record.candidate,
            record.runId,
            record.requester,
            nil,
            "member-attacked",
            0,
            nil,
            record.subject
        )
        if queued then countPerformance("reactiveWakeups") end
    end
    sendDamageResult(record, ok, message, pending, serverBeforeHealth, serverAfterHealth, dead)
end

local function requeueActiveSubject(record, reason)
    if record.persistent ~= true and record.remaining <= 0 then return end
    local mob = stableMobBySubjectId(record.subjectId)
    if not mob then return end
    local leaderMember = chooseMobLeader(mob, reason)
    if not leaderMember then return end
    if (reason == "candidate-dead"
        or reason == "candidate-identity-changed"
        or reason == "policy-changed"
        or reason == "level-changed")
        and mob.currentCandidateId == record.candidateId
    then
        mob.currentCandidate = nil
        mob.currentCandidateId = -1
    end

    local member, memberIndex = findMobMember(mob, record.subjectId)
    if member and memberIsValid(mob, member) and ownerPlayer(member.subject) then
        mob.targetFaction = mob.targetFaction or record.targetFaction
        local targetLoads = buildTargetLoads()
        local replacement = selectMobMemberTarget(
            mob,
            member,
            targetLoads,
            reason == "client-no-progress" and record.candidateId or nil
        )
        if replacement then
            local queued = enqueueMobWakeup(
                mob,
                member,
                replacement,
                leaderMember.subjectId,
                memberIndex,
                "mob-member-retarget"
            )
            if queued then
                countPerformance("memberRetargets")
                print(string.format(
                    "[ZombieFactions][%s][ACQUISITION_PROBE] phase=member-retarget reason=%s subject=%d candidate=%d",
                    record.runId,
                    tostring(reason),
                    record.subjectId,
                    zombieOnlineId(replacement)
                ))
                return
            end
        end
    end

    local delay = record.mobLeaderId == record.subjectId and TARGET_PROBE_REACQUIRE_DELAY_TICKS
        or TARGET_PROBE_SCAN_INTERVAL_TICKS
    local queued, queueReason = queueTargetSubject(
        leaderMember.subject,
        leaderMember.runId or record.runId,
        leaderMember.requester or record.requester,
        record.remaining,
        reason,
        delay,
        reason == "client-no-progress" and record.candidateId or nil
    )
    print(string.format(
        "[ZombieFactions][%s][ACQUISITION_PROBE] phase=requeue reason=%s subject=%d queued=%s queueReason=%s remaining=%d",
        record.runId,
        tostring(reason),
        record.subjectId,
        tostring(queued),
        tostring(queueReason or "ready"),
        record.remaining
    ))
end

local function handleReacquireRequest(player, args)
    args = args or {}
    if not player then return end
    local runId = tostring(args.runId or "")
    local subjectId = tonumber(args.subjectId)
    local candidateId = tonumber(args.candidateId)
    if runId == "" or subjectId == nil or candidateId == nil then return end

    for i = #ZombieFactions.ActiveTargetProbes, 1, -1 do
        local record = ZombieFactions.ActiveTargetProbes[i]
        if record.runId == runId
            and record.subjectId == subjectId
            and record.candidateId == candidateId
        then
            local username = player:getUsername()
            if ownerUsername(record.subject) ~= username or record.ownerAtGrant ~= username then return end
            if record.pendingDamage then return end
            sendTargetRelease(record, "client-no-progress")
            table.remove(ZombieFactions.ActiveTargetProbes, i)
            countPerformance("stuckReacquires")
            requeueActiveSubject(record, "client-no-progress")
            return
        end
    end
end

local function onTick()
    performanceSummaryCountdown = performanceSummaryCountdown - 1
    if performanceSummaryCountdown <= 0 then
        performanceSummaryCountdown = PERFORMANCE_SUMMARY_TICKS
        printPerformanceSummary()
    end

    if ZombieFactions.TargetProbeDiscoveryIndexTicks > 0 then
        ZombieFactions.TargetProbeDiscoveryIndexTicks = ZombieFactions.TargetProbeDiscoveryIndexTicks - 1
    end

    mobMaintenanceCountdown = mobMaintenanceCountdown - 1
    if mobMaintenanceCountdown <= 0 then
        mobMaintenanceCountdown = MOB_MAINTENANCE_INTERVAL_TICKS
        maintainStableMobs()
    end
    processPendingMobWakeups()

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

    local scansRemaining = TARGET_PROBE_SCAN_BUDGET_PER_TICK
    local discoveryIndex = nil
    local targetLoads = nil
    for i = #ZombieFactions.PendingTargetProbes, 1, -1 do
        local record = ZombieFactions.PendingTargetProbes[i]
        if record.mob and not refreshPendingLeader(record) then
            record.mob.pendingLeaderId = nil
            table.remove(ZombieFactions.PendingTargetProbes, i)
        else
            if record.persistent ~= true then record.remaining = record.remaining - 1 end
            record.scanCountdown = record.scanCountdown - 1
            local currentSubjectId = zombieOnlineId(record.subject)
            if currentSubjectId ~= record.subjectId then
                print(string.format(
                    "[ZombieFactions][%s][ACQUISITION_PROBE] phase=pending-final subject=%d reason=subject-identity-changed expected=%d actual=%d scans=%d",
                    record.runId,
                    record.subjectId,
                    record.subjectId,
                    currentSubjectId,
                    record.scanAttempts or 0
                ))
                if record.mob then record.mob.pendingLeaderId = nil end
                table.remove(ZombieFactions.PendingTargetProbes, i)
            elseif (record.persistent ~= true and record.remaining <= 0) or isDead(record.subject) then
                print(string.format(
                    "[ZombieFactions][%s][ACQUISITION_PROBE] phase=pending-final subject=%d reason=%s scans=%d",
                    record.runId,
                    zombieOnlineId(record.subject),
                    record.persistent ~= true and record.remaining <= 0 and "expired" or "subject-dead",
                    record.scanAttempts or 0
                ))
                if record.mob then record.mob.pendingLeaderId = nil end
                table.remove(ZombieFactions.PendingTargetProbes, i)
            elseif record.scanCountdown <= 0 and scansRemaining > 0 then
                if not ownerPlayer(record.subject) then
                    record.scanCountdown = TARGET_PROBE_SCAN_INTERVAL_TICKS
                else
                    discoveryIndex = discoveryIndex or getDiscoveryIndex()
                    targetLoads = targetLoads or buildTargetLoads()
                    scansRemaining = scansRemaining - 1
                    local result = beginOwnerTargetProbe(record, discoveryIndex, targetLoads)
                    if result == "active" or result == "terminal" then
                        if record.mob then record.mob.pendingLeaderId = nil end
                        table.remove(ZombieFactions.PendingTargetProbes, i)
                    else
                        record.scanCountdown = TARGET_PROBE_SCAN_INTERVAL_TICKS
                    end
                end
            end
        end
    end

    for i = #ZombieFactions.ActiveTargetProbes, 1, -1 do
        local record = ZombieFactions.ActiveTargetProbes[i]
        local currentSubjectId = zombieOnlineId(record.subject)
        local currentCandidateId = zombieOnlineId(record.candidate)
        if currentSubjectId ~= record.subjectId then
            print(string.format(
                "[ZombieFactions][%s][ACQUISITION_PROBE] phase=release reason=subject-identity-changed subject=%d candidate=%d actualSubject=%d action=drop-without-instruction",
                record.runId,
                record.subjectId,
                record.candidateId,
                currentSubjectId
            ))
            table.remove(ZombieFactions.ActiveTargetProbes, i)
        elseif currentCandidateId ~= record.candidateId then
            print(string.format(
                "[ZombieFactions][%s][ACQUISITION_PROBE] phase=release reason=candidate-identity-changed subject=%d candidate=%d actualCandidate=%d action=release-and-requeue",
                record.runId,
                record.subjectId,
                record.candidateId,
                currentCandidateId
            ))
            sendTargetRelease(record, "candidate-identity-changed")
            table.remove(ZombieFactions.ActiveTargetProbes, i)
            requeueActiveSubject(record, "candidate-identity-changed")
        else
        if record.persistent ~= true then record.remaining = record.remaining - 1 end
        record.sampleCountdown = record.sampleCountdown - 1
        if record.damageCooldown > 0 then
            record.damageCooldown = record.damageCooldown - 1
        end

        local currentOwner = ownerUsername(record.subject)
        if currentOwner ~= record.ownerAtGrant then
            print(string.format(
                "[ZombieFactions][%s][ACQUISITION_PROBE] phase=owner-transition subject=%d previousOwner=%s currentOwner=%s action=%s",
                record.runId,
                record.subjectId,
                tostring(record.ownerAtGrant),
                tostring(currentOwner),
                currentOwner == "none" and "wait" or "regrant"
            ))
            record.ownerAtGrant = currentOwner
            if currentOwner ~= "none" and currentOwner ~= "unknown" then
                sendTargetGrant(record, "owner-change")
            end
        end

        if record.pendingDamage then
            record.pendingDamage.remaining = record.pendingDamage.remaining - 1
            local currentTargetOwner = ownerUsername(record.candidate)
            local waitingForLethalAck = currentTargetOwner == "none"
                and healthValue(record.candidate) <= 0
            if currentTargetOwner ~= record.pendingDamage.ownerAtDispatch and not waitingForLethalAck then
                local pending = record.pendingDamage
                record.pendingDamage = nil
                print(string.format(
                    "[ZombieFactions][%s][OWNER_DAMAGE] phase=cancelled reason=target-owner-changed hitId=%s dispatchedOwner=%s currentOwner=%s",
                    record.runId,
                    pending.hitId,
                    tostring(pending.ownerAtDispatch),
                    tostring(currentTargetOwner)
                ))
                sendDamageResult(record, false, "target owner changed while damage was pending", pending, healthValue(record.candidate), healthValue(record.candidate), isDead(record.candidate))
            elseif record.pendingDamage.remaining <= 0 then
                local pending = record.pendingDamage
                record.pendingDamage = nil
                print(string.format(
                    "[ZombieFactions][%s][OWNER_DAMAGE] phase=timeout hitId=%s targetOwner=%s",
                    record.runId,
                    pending.hitId,
                    tostring(pending.ownerAtDispatch)
                ))
                sendDamageResult(record, false, "owner damage acknowledgement timed out", pending, healthValue(record.candidate), healthValue(record.candidate), isDead(record.candidate))
            end
        end

        if record.sampleCountdown <= 0 then
            record.sampleCountdown = TARGET_PROBE_SAMPLE_TICKS
            sampleActiveProbe(record, false)
        end

        local finalReason = nil
        local reacquire = false
        if isDead(record.subject) then
            finalReason = "subject-dead"
        elseif record.persistent ~= true and record.remaining <= 0 and not record.pendingDamage then
            finalReason = "expired"
        elseif isDead(record.candidate) and not record.pendingDamage then
            finalReason = "candidate-dead"
            reacquire = true
        elseif not record.pendingDamage then
            local allowed = ZombieFactions.canTarget(record.subject, record.candidate)
            if not allowed then
                finalReason = "policy-changed"
                reacquire = true
            elseif not sameLevel(record.subject, record.candidate) then
                finalReason = "level-changed"
                reacquire = true
            elseif distanceSquared(record.subject, record.candidate) > mobTargetRetentionRadius() * mobTargetRetentionRadius() then
                finalReason = "out-of-range"
                reacquire = true
            end
        end

        if finalReason then
            print(string.format(
                "[ZombieFactions][%s][ACQUISITION_PROBE] phase=release reason=%s subject=%d candidate=%d grants=%d remaining=%d",
                record.runId,
                finalReason,
                record.subjectId,
                record.candidateId,
                record.grantCount or 0,
                record.remaining
            ))
            sendTargetRelease(record, finalReason)
            sampleActiveProbe(record, true)
            table.remove(ZombieFactions.ActiveTargetProbes, i)
            if reacquire then requeueActiveSubject(record, finalReason) end
        end
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
    local probeSubjects = {}

    for _ = 1, count do
        local sx = radius > 0 and ZombRand(x - radius, x + radius + 1) or x
        local sy = radius > 0 and ZombRand(y - radius, y + radius + 1) or y
        local zombie = spawnOne(args, sx, sy, z)
        if zombie then
            local assigned = ZombieFactions.assignZombieFaction(zombie, factionId, runId)
            if assigned then
                spawnedCount = spawnedCount + 1
                if args.targetProbe == true then
                    probeSubjects[#probeSubjects + 1] = zombie
                end

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
    local relationshipSummary = factionId == VANILLA
        and "relationships=unchanged"
        or string.format("%s->%s=%s %s->%s=%s", factionId, VANILLA, toVanilla, VANILLA, factionId, effectiveFrom)
    local probeQueuedCount = 0
    for i = 1, #probeSubjects do
        local queued = queueTargetSubject(
            probeSubjects[i],
            runId,
            player:getUsername(),
            nil,
            "spawn",
            TARGET_PROBE_DELAY_TICKS + ((i - 1) % TARGET_PROBE_SCAN_INTERVAL_TICKS)
        )
        if queued then probeQueuedCount = probeQueuedCount + 1 end
    end
    local probeQueued = #probeSubjects > 0

    alwaysPrint(string.format(
        "[ZombieFactions][%s] spawned=%d requested=%d faction=%s %s assignmentImmediate=%d/%d deferredSamples=%d targetProbeQueued=%s targetProbeMembers=%d targetProbeLeaderActions=%d zombieMobSize=%d recruitmentRadius=%d",
        runId,
        spawnedCount,
        count,
        factionId,
        relationshipSummary,
        immediateVerified,
        spawnedCount,
        validationSampled,
        tostring(probeQueued),
        #probeSubjects,
        probeQueuedCount,
        zombieMobSize(),
        mobRecruitmentRadius()
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
        targetProbeSubjects = #probeSubjects,
        targetProbeLeaderActions = probeQueuedCount,
        zombieMobSize = zombieMobSize(),
        mobRecruitmentRadius = mobRecruitmentRadius(),
    })
end

local function onClientCommand(module, command, player, args)
    if module ~= MODULE then return end
    if command == SPAWN_COMMAND then
        handleSpawn(player, args)
    elseif command == DAMAGE_PROBE_COMMAND then
        handleDamageProbe(player, args)
    elseif command == DAMAGE_ACK_COMMAND then
        handleDamageAck(player, args)
    elseif command == TARGET_REACQUIRE_COMMAND then
        handleReacquireRequest(player, args)
    end
end

Events.OnClientCommand.Add(onClientCommand)
Events.OnTick.Add(onTick)
