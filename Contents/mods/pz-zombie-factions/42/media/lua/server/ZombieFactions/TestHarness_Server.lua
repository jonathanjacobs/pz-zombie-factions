if isClient() then return end

require "ZombieFactions/Assignment"

local MODULE = "ZombieFactions"
local COMMAND = "SpawnTestHorde"
local VANILLA = ZombieFactions.Faction.VANILLA
local TEST_RED = ZombieFactions.Faction.TEST_RED
local TEST_BLUE = ZombieFactions.Faction.TEST_BLUE

ZombieFactions.TestHarnessSequence = ZombieFactions.TestHarnessSequence or 0

print("[ZombieFactions] Server test harness loaded v0.0.5")

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
    if factionId == VANILLA then
        return true
    end

    if symmetric then
        fromVanilla = toVanilla
    end

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

local function spawnOne(args, x, y, z)
    local outfit = args.outfit
    if outfit == "" then outfit = nil end

    local femaleChance = tonumber(args.femaleChance)
    local spawned = addZombiesInOutfit(
        x,
        y,
        z,
        1,
        outfit,
        femaleChance,
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

    if not spawned or spawned:size() == 0 then
        return nil
    end
    return spawned:get(0)
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

    for _ = 1, count do
        local sx = radius > 0 and ZombRand(x - radius, x + radius + 1) or x
        local sy = radius > 0 and ZombRand(y - radius, y + radius + 1) or y
        local zombie = spawnOne(args, sx, sy, z)
        if zombie then
            local assigned = ZombieFactions.assignZombieFaction(zombie, factionId, runId)
            if assigned then
                spawnedCount = spawnedCount + 1
            end
        end
    end

    local effectiveFrom = args.symmetric == true and toVanilla or fromVanilla
    print(string.format(
        "[ZombieFactions][%s] spawned=%d requested=%d faction=%s %s->%s=%s %s->%s=%s",
        runId,
        spawnedCount,
        count,
        factionId,
        factionId,
        VANILLA,
        toVanilla,
        VANILLA,
        factionId,
        effectiveFrom
    ))

    reply(player, true, "Faction test horde spawned", {
        runId = runId,
        spawned = spawnedCount,
        requested = count,
        factionId = factionId,
        toVanilla = toVanilla,
        fromVanilla = effectiveFrom,
    })
end

local function onClientCommand(module, command, player, args)
    if module ~= MODULE or command ~= COMMAND then return end
    handleSpawn(player, args)
end

Events.OnClientCommand.Add(onClientCommand)
