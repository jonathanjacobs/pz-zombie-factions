local MODULE = "ZombieFactions"
local TARGET_COMMAND = "TargetProbeInstruction"
local IMPACT_COMMAND = "TargetProbeAttack"
local RESULT_COMMAND = "TargetProbeDamageResult"

local MAX_DISTANCE = 1.25
local RESOLVE_TICKS = 120
local REQUEST_COOLDOWN_TICKS = 30
local TRACK_TICKS = 900

local pending = {}
local tracked = {}

print("[ZombieFactions] Client impact probe loaded v0.0.8")

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

local function distance(a, b)
    if not a or not b then return math.huge end
    local dx = a:getX() - b:getX()
    local dy = a:getY() - b:getY()
    return math.sqrt(dx * dx + dy * dy)
end

local function findZombie(id)
    local zombies = getCell():getZombieList()
    if not zombies then return nil end
    for i = 0, zombies:size() - 1 do
        local zombie = zombies:get(i)
        if zombie and onlineId(zombie) == id then return zombie end
    end
    return nil
end

local function resolve(record)
    local subject = findZombie(record.subjectId)
    local candidate = findZombie(record.candidateId)
    if not subject or not candidate then return false end

    local player = getPlayer()
    if not player or ownerUsername(subject) ~= player:getUsername() then return false end

    record.subject = subject
    record.candidate = candidate
    record.remaining = TRACK_TICKS
    record.cooldown = 0
    record.lastAttacking = false
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

local function onServerCommand(module, command, args)
    if module ~= MODULE then return end
    args = args or {}

    local player = getPlayer()
    if not player or tostring(args.requester) ~= player:getUsername() then return end

    if command == TARGET_COMMAND then
        local subjectId = tonumber(args.subjectId)
        local candidateId = tonumber(args.candidateId)
        if subjectId == nil or candidateId == nil then return end
        pending[#pending + 1] = {
            runId = tostring(args.runId or "SPIKE001"),
            subjectId = subjectId,
            candidateId = candidateId,
            ticks = RESOLVE_TICKS,
        }
    elseif command == RESULT_COMMAND then
        print(string.format(
            "[ZombieFactions][%s][IMPACT_RESULT] ok=%s hit=%s beforeHealth=%s afterHealth=%s candidateDead=%s message=%s",
            tostring(args.runId or "SPIKE001"),
            tostring(args.ok == true),
            tostring(args.damageHits),
            tostring(args.beforeHealth),
            tostring(args.afterHealth),
            tostring(args.candidateDead == true),
            tostring(args.message or "")
        ))
    end
end

local function onTick()
    for i = #pending, 1, -1 do
        local record = pending[i]
        record.ticks = record.ticks - 1
        if resolve(record) or record.ticks <= 0 then
            table.remove(pending, i)
        end
    end

    for subjectId, record in pairs(tracked) do
        record.remaining = record.remaining - 1
        if record.cooldown > 0 then record.cooldown = record.cooldown - 1 end
        if record.remaining <= 0 or not record.subject or not record.candidate then
            tracked[subjectId] = nil
        end
    end
end

local function onZombieUpdate(zombie)
    if not zombie then return end
    local record = tracked[onlineId(zombie)]
    if not record or record.subject ~= zombie then return end

    local attacking = safeCall(false, function()
        return record.subject:isZombieAttacking(record.candidate)
    end) == true

    local rising = attacking and not record.lastAttacking
    record.lastAttacking = attacking
    if not rising or record.cooldown > 0 then return end

    local dist = distance(record.subject, record.candidate)
    if dist > MAX_DISTANCE then return end

    local player = getPlayer()
    if not player or ownerUsername(record.subject) ~= player:getUsername() then return end

    record.cooldown = REQUEST_COOLDOWN_TICKS
    sendClientCommand(player, MODULE, IMPACT_COMMAND, {
        runId = record.runId,
        subjectId = record.subjectId,
        candidateId = record.candidateId,
    })

    print(string.format(
        "[ZombieFactions][%s][IMPACT_PROBE] request subject=%d candidate=%d distance=%.2f clientCandidateHealth=%.3f",
        record.runId,
        record.subjectId,
        record.candidateId,
        dist,
        health(record.candidate)
    ))
end

Events.OnServerCommand.Add(onServerCommand)
Events.OnTick.Add(onTick)
Events.OnZombieUpdate.Add(onZombieUpdate)
