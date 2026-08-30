require "ZombieFactions/Assignment"

ZombieFactions = ZombieFactions or {}

local REL = ZombieFactions.Relationship

local function isZombie(value)
    if not value then return false end
    local ok, result = pcall(function()
        return value:isZombie()
    end)
    return ok and result == true
end

-- Relationship eligibility only. Callers remain responsible for contextual
-- checks such as liveness, distance, line of sight, ownership, and authority.
-- Non-zombie actors fail closed until player-faction identity is implemented.
function ZombieFactions.canTarget(attacker, candidate)
    if not attacker then
        return false, nil, nil, nil, "missing-attacker"
    end
    if not candidate then
        return false, nil, nil, nil, "missing-candidate"
    end
    if not isZombie(attacker) then
        return false, nil, nil, nil, "attacker-not-zombie"
    end
    if not isZombie(candidate) then
        return false, nil, nil, nil, "candidate-not-zombie"
    end
    if attacker == candidate then
        return false, nil, nil, nil, "self"
    end

    local sourceFaction = ZombieFactions.getZombieFaction(attacker)
    local targetFaction = ZombieFactions.getZombieFaction(candidate)
    local relationship = ZombieFactions.getRelationship(sourceFaction, targetFaction)

    if relationship == REL.HOSTILE then
        return true, sourceFaction, targetFaction, relationship, "hostile"
    end
    if relationship == REL.FRIENDLY then
        return false, sourceFaction, targetFaction, relationship, "friendly"
    end
    if relationship == REL.NEUTRAL then
        return false, sourceFaction, targetFaction, relationship, "neutral"
    end

    return false, sourceFaction, targetFaction, relationship, "relationship-unset"
end
