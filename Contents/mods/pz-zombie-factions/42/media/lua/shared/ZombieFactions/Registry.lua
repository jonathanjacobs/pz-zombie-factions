require "ZombieFactions/Constants"

ZombieFactions = ZombieFactions or {}
ZombieFactions.Registry = ZombieFactions.Registry or {}
ZombieFactions.Relationships = ZombieFactions.Relationships or {}

local Registry = ZombieFactions.Registry
local Relationships = ZombieFactions.Relationships
local REL = ZombieFactions.Relationship
local VANILLA = ZombieFactions.Faction.VANILLA

Registry[VANILLA] = Registry[VANILLA] or {
    id = VANILLA,
    name = "Vanilla",
    builtin = true,
}

Relationships[VANILLA] = Relationships[VANILLA] or {
    [VANILLA] = REL.FRIENDLY,
}

local function isValidRelationship(value)
    return value == REL.FRIENDLY or value == REL.NEUTRAL or value == REL.HOSTILE
end

function ZombieFactions.registerFaction(id, name)
    if type(id) ~= "string" or id == "" then
        return false, "invalid faction id"
    end
    if Registry[id] then
        return false, "faction already registered"
    end

    Registry[id] = {
        id = id,
        name = name or id,
        builtin = false,
    }
    Relationships[id] = Relationships[id] or {
        [id] = REL.FRIENDLY,
    }
    return true
end

function ZombieFactions.getFactionDefinition(id)
    return Registry[id]
end

function ZombieFactions.setRelationship(sourceId, targetId, relationship)
    if not Registry[sourceId] then
        return false, "unknown source faction"
    end
    if type(targetId) ~= "string" or targetId == "" then
        return false, "invalid target identity"
    end
    if not isValidRelationship(relationship) then
        return false, "invalid relationship"
    end

    Relationships[sourceId] = Relationships[sourceId] or {}
    Relationships[sourceId][targetId] = relationship
    return true
end

function ZombieFactions.getRelationship(sourceId, targetId)
    if sourceId == targetId then
        return REL.FRIENDLY
    end

    local row = Relationships[sourceId]
    if row and row[targetId] then
        return row[targetId]
    end

    return nil
end
