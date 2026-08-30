require "DebugUIs/ISSpawnHordeUI"
require "ZombieFactions/Constants"

local MODULE = "ZombieFactions"
local VANILLA = ZombieFactions.Faction.VANILLA
local TEST_RED = ZombieFactions.Faction.TEST_RED
local TEST_BLUE = ZombieFactions.Faction.TEST_BLUE
local REL = ZombieFactions.Relationship

local originalCreateChildren = ISSpawnHordeUI.createChildren
local originalOnSpawn = ISSpawnHordeUI.onSpawn

print("[ZombieFactions] Client Horde Spawner extension loaded v0.0.30")

local function addRelationshipOptions(combo)
    combo:addOptionWithData("FRIENDLY", REL.FRIENDLY)
    combo:addOptionWithData("NEUTRAL", REL.NEUTRAL)
    combo:addOptionWithData("HOSTILE", REL.HOSTILE)
end

local function selectedData(combo)
    local option = combo and combo.options and combo.options[combo.selected]
    return option and option.data or nil
end

local function addHarnessBottomButtons(self, spacing, buttonHeight)
    -- Do not depend on the vanilla bottom-button anchor lifecycle. The original
    -- buttons remain untouched; these diagnostic controls are created after the
    -- final extended window height is known, so their coordinates are stable.
    local x = 11
    local gap = spacing
    local buttonWidth = math.floor((self:getWidth() - (x * 2) - gap) / 2)
    local bottomY = self:getHeight() - spacing - buttonHeight - 1
    local upperY = bottomY - buttonHeight - spacing
    local rightX = x + buttonWidth + gap

    self.zfRemoveZombiesButton = ISButton:new(
        x, upperY, buttonWidth, buttonHeight,
        getText("IGUI_SpawnHorde_RemoveZombies"),
        self, ISSpawnHordeUI.onRemoveZombies
    )
    self.zfRemoveZombiesButton:initialise()
    self.zfRemoveZombiesButton:instantiate()
    self.zfRemoveZombiesButton.borderColor = {r=1, g=1, b=1, a=0.1}
    self.zfRemoveZombiesButton:setTooltip("Tip: Hold down Shift to remove all loaded zombies.")
    self:addChild(self.zfRemoveZombiesButton)

    self.zfRemoveBodiesButton = ISButton:new(
        rightX, upperY, buttonWidth, buttonHeight,
        getText("IGUI_SpawnHorde_RemoveBodies"),
        self, ISSpawnHordeUI.onRemoveBodies
    )
    self.zfRemoveBodiesButton:initialise()
    self.zfRemoveBodiesButton:instantiate()
    self.zfRemoveBodiesButton.borderColor = {r=1, g=1, b=1, a=0.1}
    self:addChild(self.zfRemoveBodiesButton)

    self.zfSpawnButton = ISButton:new(
        x, bottomY, buttonWidth, buttonHeight,
        getText("IGUI_StashDebug_Spawn"),
        self, ISSpawnHordeUI.onSpawn
    )
    self.zfSpawnButton:initialise()
    self.zfSpawnButton:instantiate()
    self.zfSpawnButton.borderColor = {r=1, g=1, b=1, a=0.1}
    self:addChild(self.zfSpawnButton)

    self.zfCloseButton = ISButton:new(
        rightX, bottomY, buttonWidth, buttonHeight,
        getText("IGUI_DebugMenu_Close"),
        self, ISSpawnHordeUI.close
    )
    self.zfCloseButton:initialise()
    self.zfCloseButton:instantiate()
    self.zfCloseButton:enableCancelColor()
    self:addChild(self.zfCloseButton)

    print(string.format(
        "[ZombieFactions][UI] windowHeight=%d harnessSpawnY=%d harnessRemoveY=%d buttonWidth=%d",
        math.floor(self:getHeight()),
        math.floor(bottomY),
        math.floor(upperY),
        math.floor(buttonWidth)
    ))
end

function ISSpawnHordeUI:createChildren()
    originalCreateChildren(self)

    local fontHeight = getTextManager():getFontHeight(UIFont.Small)
    local rowHeight = fontHeight + 6
    local spacing = 10
    local extraHeight = (rowHeight + spacing) * 5
    local x = 11
    local y = self.healthSlider:getBottom() + spacing

    -- Extend the vanilla window for the five diagnostic rows. The test harness
    -- creates its own bottom controls after this resize instead of trying to
    -- reposition the vanilla anchorBottom controls.
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
    self.zfSymmetric = ISTickBox:new(x, y, 330, rowHeight, "", self, nil)
    self.zfSymmetric:initialise()
    self:addChild(self.zfSymmetric)
    self.zfSymmetric:addOption("Symmetric: mirror first relationship both ways")
    self.zfSymmetric.selected[1] = true

    y = y + rowHeight + spacing
    self.zfTargetProbe = ISTickBox:new(x, y, 340, rowHeight, "", self, nil)
    self.zfTargetProbe:initialise()
    self:addChild(self.zfTargetProbe)
    self.zfTargetProbe:addOption("SPIKE: test bounded faction acquisition/reacquisition")
    self.zfTargetProbe.selected[1] = false

    addHarnessBottomButtons(self, spacing, rowHeight)
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
        targetProbe = self.zfTargetProbe.selected[1] == true,
    }
end

function ISSpawnHordeUI:onSpawn()
    local factionId = selectedData(self.zfFaction) or VANILLA

    if factionId == VANILLA and self.zfTargetProbe.selected[1] ~= true then
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
            "[ZombieFactions][%s] %s: spawned %s/%s as %s assignmentImmediate=%s/%s deferredSamples=%s targetProbeQueued=%s targetProbeMembers=%s targetProbeLeaderActions=%s recruitmentRadius=%s",
            tostring(args.runId or "SPIKE001"),
            tostring(args.message or "spawn complete"),
            tostring(args.spawned or "?"),
            tostring(args.requested or "?"),
            tostring(args.factionId or "?"),
            tostring(args.assignmentImmediate or "?"),
            tostring(args.spawned or "?"),
            tostring(args.validationSampled or "?"),
            tostring(args.targetProbeQueued == true),
            tostring(args.targetProbeSubjects or 0),
            tostring(args.targetProbeLeaderActions or 0),
            tostring(args.mobRecruitmentRadius or "?")
        ))
    else
        print("[ZombieFactions] faction horde spawn rejected: " .. tostring(args.message or "unknown error"))
    end
end

Events.OnServerCommand.Add(onServerCommand)
