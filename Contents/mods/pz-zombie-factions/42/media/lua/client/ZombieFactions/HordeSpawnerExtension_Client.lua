require "DebugUIs/ISSpawnHordeUI"
require "ZombieFactions/Constants"

local MODULE = "ZombieFactions"
local VANILLA = ZombieFactions.Faction.VANILLA
local TEST_RED = ZombieFactions.Faction.TEST_RED
local TEST_BLUE = ZombieFactions.Faction.TEST_BLUE
local REL = ZombieFactions.Relationship

local originalCreateChildren = ISSpawnHordeUI.createChildren
local originalOnSpawn = ISSpawnHordeUI.onSpawn

print("[ZombieFactions] Client Horde Spawner extension loaded v0.0.4")

local function addRelationshipOptions(combo)
    combo:addOptionWithData("FRIENDLY", REL.FRIENDLY)
    combo:addOptionWithData("NEUTRAL", REL.NEUTRAL)
    combo:addOptionWithData("HOSTILE", REL.HOSTILE)
end

local function selectedData(combo)
    local option = combo and combo.options and combo.options[combo.selected]
    return option and option.data or nil
end

local function placeVanillaBottomButtons(self, spacing, buttonHeight)
    local bottomY = self:getHeight() - spacing - buttonHeight - 1
    local upperY = bottomY - buttonHeight - spacing

    if self.add then self.add:setY(bottomY) end
    if self.closeButton2 then self.closeButton2:setY(bottomY) end
    if self.removezombies then self.removezombies:setY(upperY) end
    if self.clearbodies then self.clearbodies:setY(upperY) end

    print(string.format(
        "[ZombieFactions][UI] windowHeight=%d spawnY=%d removeY=%d",
        math.floor(self:getHeight()),
        math.floor(bottomY),
        math.floor(upperY)
    ))
end

function ISSpawnHordeUI:createChildren()
    originalCreateChildren(self)

    local fontHeight = getTextManager():getFontHeight(UIFont.Small)
    local rowHeight = fontHeight + 6
    local spacing = 10
    local extraHeight = (rowHeight + spacing) * 4
    local x = 11
    local y = self.healthSlider:getBottom() + spacing

    -- Extend the vanilla window for the four diagnostic rows.  Do not rely on
    -- anchorBottom to reposition existing controls after this late resize;
    -- explicitly place the vanilla bottom button rows once the final height is set.
    self:setHeight(self:getHeight() + extraHeight)

    self.zfFactionLabel = ISLabel:new(x, y, rowHeight, "Zombie faction:", 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(self.zfFactionLabel)

    self.zfFaction = ISComboBox:new(self.zfFactionLabel:getRight() + spacing, y, 180, rowHeight)
    self.zfFaction:initialise()
    self:addChild(self.zfFaction)
    self.zfFaction:addOptionWithData("Vanilla (zf:vanilla)", VANILLA)
    self.zfFaction:addOptionWithData("Test Red (zf:test-red)", TEST_RED)
    self.zfFaction:addOptionWithData("Test Blue (zf:test-blue)", TEST_BLUE)

    y = y + rowHeight + spacing
    self.zfToVanillaLabel = ISLabel:new(x, y, rowHeight, "Spawned faction -> Vanilla:", 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(self.zfToVanillaLabel)

    self.zfToVanilla = ISComboBox:new(self.zfToVanillaLabel:getRight() + spacing, y, 140, rowHeight)
    self.zfToVanilla:initialise()
    self:addChild(self.zfToVanilla)
    addRelationshipOptions(self.zfToVanilla)

    y = y + rowHeight + spacing
    self.zfFromVanillaLabel = ISLabel:new(x, y, rowHeight, "Vanilla -> spawned faction:", 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(self.zfFromVanillaLabel)

    self.zfFromVanilla = ISComboBox:new(self.zfFromVanillaLabel:getRight() + spacing, y, 140, rowHeight)
    self.zfFromVanilla:initialise()
    self:addChild(self.zfFromVanilla)
    addRelationshipOptions(self.zfFromVanilla)

    y = y + rowHeight + spacing
    self.zfSymmetric = ISTickBox:new(x, y, 300, rowHeight, "", self, nil)
    self.zfSymmetric:initialise()
    self:addChild(self.zfSymmetric)
    self.zfSymmetric:addOption("Symmetric: mirror first relationship both ways")
    self.zfSymmetric.selected[1] = true

    placeVanillaBottomButtons(self, spacing, rowHeight)
end

local function buildFactionSpawnArgs(self, factionId)
    local femaleChance = nil
    local outfit = self:getOutfit()
    if outfit and self.maleOutfits:contains(outfit) and not self.femaleOutfits:contains(outfit) then
        femaleChance = 0
    elseif outfit and self.femaleOutfits:contains(outfit) and not self.maleOutfits:contains(outfit) then
        femaleChance = 100
    end

    local selected = self.boolOptions.selected
    return {
        x = self.selectX,
        y = self.selectY,
        z = self.selectZ,
        count = self:getZombiesNumber(),
        radius = self:getRadius(),
        outfit = outfit or "",
        femaleChance = femaleChance,
        knockedDown = selected[1] == true,
        crawler = selected[2] == true,
        isFakeDead = selected[3] == true,
        isFallOnFront = selected[4] == true,
        isInvulnerable = selected[5] == true,
        isSitting = selected[6] == true,
        isRecordingAnims = selected[7] == true,
        isRagdolling = selected[8] == true,
        onFire = selected[9] == true,
        health = self.healthSlider:getCurrentValue(),
        heightOffset = self:getHeightOffset(),
        factionId = factionId,
        toVanilla = selectedData(self.zfToVanilla) or REL.FRIENDLY,
        fromVanilla = selectedData(self.zfFromVanilla) or REL.FRIENDLY,
        symmetric = self.zfSymmetric.selected[1] == true,
    }
end

function ISSpawnHordeUI:onSpawn()
    local factionId = selectedData(self.zfFaction) or VANILLA

    if factionId == VANILLA then
        return originalOnSpawn(self)
    end

    if not isClient() then
        print("[ZombieFactions] faction Horde Spawning harness currently requires multiplayer/server authority")
        return
    end

    local player = getPlayer()
    if not player then
        print("[ZombieFactions] cannot spawn faction test horde: no local player")
        return
    end

    sendClientCommand(player, MODULE, "SpawnTestHorde", buildFactionSpawnArgs(self, factionId))
end

local function onServerCommand(module, command, args)
    if module ~= MODULE or command ~= "SpawnTestHordeResult" then return end
    args = args or {}

    local player = getPlayer()
    if not player or args.requester ~= player:getUsername() then
        return
    end

    if args.ok then
        print(string.format(
            "[ZombieFactions][%s] %s: spawned %s/%s as %s",
            tostring(args.runId or "SPIKE001"),
            tostring(args.message or "spawn complete"),
            tostring(args.spawned or "?"),
            tostring(args.requested or "?"),
            tostring(args.factionId or "?")
        ))
    else
        print("[ZombieFactions] faction horde spawn rejected: " .. tostring(args.message or "unknown error"))
    end
end

Events.OnServerCommand.Add(onServerCommand)
