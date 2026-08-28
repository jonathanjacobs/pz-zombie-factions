require "ZombieFactions/Assignment"

local observed = {}

print("[ZombieFactions] Client target observer loaded v0.0.6")

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

local function targetInfo(target)
    if not target then
        return -1, "none", "none", math.huge
    end

    local isZombie = safeCall(false, function()
        return target:isZombie()
    end) == true

    if isZombie then
        local targetId = tonumber(safeCall(-1, function()
            return target:getOnlineID()
        end)) or -1
        local targetFaction = ZombieFactions.getZombieFaction(target)
        return targetId, "zombie", targetFaction, 0
    end

    local objectName = tostring(safeCall("unknown", function()
        return target:getObjectName()
    end))
    return -1, objectName, "n/a", 0
end

local function distanceToTarget(zombie, target)
    if not zombie or not target then return math.huge end
    local dx = zombie:getX() - target:getX()
    local dy = zombie:getY() - target:getY()
    return math.sqrt(dx * dx + dy * dy)
end

local function onZombieUpdate(zombie)
    if not zombie then return end

    -- OnZombieUpdate is high-frequency. Exit immediately for normal zombies so
    -- SPIKE instrumentation has negligible work unless this exact zombie was
    -- explicitly tagged by the Horde test harness.
    local runId = ZombieFactions.getZombieTestRun(zombie)
    if not runId then return end

    local onlineId = zombieOnlineId(zombie)
    local key = tostring(runId) .. ":" .. tostring(onlineId) .. ":" .. tostring(zombie)
    local target = safeCall(nil, function()
        return zombie:getTarget()
    end)
    local targetId, targetType, targetFaction = targetInfo(target)
    local state = tostring(safeCall("unknown", function()
        return zombie:getRealState()
    end))
    local attacking = false
    if target then
        attacking = safeCall(false, function()
            return zombie:isZombieAttacking(target)
        end) == true
    end
    local factionId = ZombieFactions.getZombieFaction(zombie)
    local owner = ownerUsername(zombie)
    local distance = distanceToTarget(zombie, target)

    local signature = table.concat({
        tostring(factionId),
        tostring(owner),
        tostring(targetId),
        tostring(targetType),
        tostring(targetFaction),
        tostring(state),
        tostring(attacking),
    }, "|")

    if observed[key] == signature then return end
    observed[key] = signature

    print(string.format(
        "[ZombieFactions][%s][CLIENT_OBSERVER] onlineID=%d faction=%s owner=%s target=%d targetType=%s targetFaction=%s state=%s attacking=%s distance=%s",
        tostring(runId),
        onlineId,
        tostring(factionId),
        owner,
        targetId,
        tostring(targetType),
        tostring(targetFaction),
        state,
        tostring(attacking),
        distance == math.huge and "n/a" or string.format("%.2f", distance)
    ))
end

Events.OnZombieUpdate.Add(onZombieUpdate)
