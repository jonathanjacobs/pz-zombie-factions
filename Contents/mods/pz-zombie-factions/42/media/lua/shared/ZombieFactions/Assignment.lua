require "ZombieFactions/Registry"

ZombieFactions = ZombieFactions or {}

local FACTION_KEY = "ZombieFactions_FactionId"
local TEST_RUN_KEY = "ZombieFactions_TestRun"
local VANILLA = ZombieFactions.Faction.VANILLA

function ZombieFactions.assignZombieFaction(zombie, factionId, testRunId)
    if not zombie then
        return false, "missing zombie"
    end

    if not ZombieFactions.getFactionDefinition(factionId) then
        return false, "unknown faction"
    end

    local modData = zombie:getModData()
    if not modData then
        return false, "zombie has no modData"
    end

    modData[FACTION_KEY] = factionId
    if testRunId then
        modData[TEST_RUN_KEY] = testRunId
    else
        modData[TEST_RUN_KEY] = nil
    end

    if isServer() and zombie.transmitModData then
        pcall(function()
            zombie:transmitModData()
        end)
    end

    return true
end

function ZombieFactions.getZombieFaction(zombie)
    if not zombie then
        return VANILLA
    end

    local modData = zombie:getModData()
    if not modData then
        return VANILLA
    end

    local factionId = modData[FACTION_KEY]
    if type(factionId) == "string" and ZombieFactions.getFactionDefinition(factionId) then
        return factionId
    end

    return VANILLA
end

function ZombieFactions.getZombieTestRun(zombie)
    if not zombie then
        return nil
    end

    local modData = zombie:getModData()
    if not modData then
        return nil
    end

    return modData[TEST_RUN_KEY]
end
