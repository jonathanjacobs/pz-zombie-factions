ZombieFactions = ZombieFactions or {}

local existing = ZombieFactions.ClientCombatController
if existing then return end

local UPDATE_INTERVAL_TICKS = 6
local SUMMARY_INTERVAL_TICKS = 300
local IMPACT_REQUEST_BUDGET_PER_PASS = 4

local controller = {
    callbacks = {},
    callbackOrder = {},
    counters = {},
    gauges = {},
    meleeAuthorizations = {},
    passSequence = 0,
    impactRequestBudget = 0,
    updateCountdown = 0,
    summaryCountdown = SUMMARY_INTERVAL_TICKS,
    verbose = false,
    zombieIndex = nil,
}

local function rebuildCallbackOrder()
    local order = {}
    for name, entry in pairs(controller.callbacks) do
        order[#order + 1] = {name = name, priority = entry.priority}
    end
    table.sort(order, function(a, b)
        if a.priority == b.priority then return a.name < b.name end
        return a.priority < b.priority
    end)
    controller.callbackOrder = order
end

function controller.register(name, callback, priority)
    name = tostring(name)
    controller.callbacks[name] = {
        callback = callback,
        priority = tonumber(priority) or 100,
    }
    rebuildCallbackOrder()
end

function controller.increment(name, amount)
    name = tostring(name)
    controller.counters[name] = (controller.counters[name] or 0) + (tonumber(amount) or 1)
end

function controller.setGauge(name, value)
    controller.gauges[tostring(name)] = tonumber(value) or 0
end

function controller.detail(message)
    if controller.verbose then print(message) end
end

function controller.setVerbose(enabled)
    controller.verbose = enabled == true
end

-- Read from the sandbox rather than hardcoded. This was a source constant that had
-- been left enabled for weeks without anyone noticing, and per-event output here is
-- heavy enough to push the client log past the size at which the game empties it in
-- place. Refreshed once per summary interval, since SandboxVars is not reliably
-- populated at file load time.
local function refreshVerbose()
    local options = SandboxVars and SandboxVars.ZombieFactions
    if options == nil then return end
    controller.verbose = options.VerboseDiagnosticsClient == true
end

function controller.authorizeMelee(subjectId, candidateId)
    subjectId = tonumber(subjectId)
    candidateId = tonumber(candidateId)
    if subjectId == nil or candidateId == nil then return end
    controller.meleeAuthorizations[subjectId] = {
        candidateId = candidateId,
        passSequence = controller.passSequence,
    }
end

function controller.clearMeleeAuthorization(subjectId)
    subjectId = tonumber(subjectId)
    if subjectId == nil then return end
    controller.meleeAuthorizations[subjectId] = nil
end

function controller.isMeleeAuthorized(subjectId, candidateId)
    local authorization = controller.meleeAuthorizations[tonumber(subjectId)]
    return authorization ~= nil
        and authorization.candidateId == tonumber(candidateId)
        and authorization.passSequence == controller.passSequence
end

function controller.tryConsumeImpactRequestBudget()
    if controller.impactRequestBudget <= 0 then return false end
    controller.impactRequestBudget = controller.impactRequestBudget - 1
    return true
end

function controller.findZombie(onlineId)
    if controller.zombieIndex == nil then
        local index = {}
        local zombies = getCell():getZombieList()
        if zombies then
            for i = 0, zombies:size() - 1 do
                local zombie = zombies:get(i)
                if zombie then
                    local ok, id = pcall(function() return zombie:getOnlineID() end)
                    if ok and id ~= nil then index[tonumber(id)] = zombie end
                end
            end
        end
        controller.zombieIndex = index
        controller.increment("zombieIndexBuilds")
    end
    return controller.zombieIndex[tonumber(onlineId)]
end

local function metric(name)
    return controller.counters[name] or 0
end

local function gauge(name)
    return controller.gauges[name] or 0
end

local function tilesPerSecond(bucket)
    local seconds = metric(bucket .. "TravelSeconds")
    if seconds <= 0 then return 0 end
    return metric(bucket .. "TravelTiles") / seconds
end

local function average(sumName, countName)
    local count = metric(countName)
    if count <= 0 then return 0 end
    return metric(sumName) / count
end

local function printSummary()
    local trackedTargets = gauge("trackedTargets")
    local trackedImpacts = gauge("trackedImpacts")
    -- Grants waiting to resolve count as activity. Without this a client holding only
    -- unresolved grants prints nothing, which is the state worth seeing most.
    if trackedTargets == 0 and trackedImpacts == 0 and gauge("pendingGrants") == 0 then
        controller.counters = {}
        return
    end

    -- Reported separately from the intent counters below. Measured travel is the
    -- only evidence that a sprint request changed movement; the shambler figure
    -- is the control it has to beat in the same run. Node loops are reported as a
    -- rate rather than a hit ratio, because the poll interval is faster than the
    -- animation loop and a raw ratio therefore understates a healthy node.
    local intentSeconds = metric("sprintIntentSeconds")
    print(string.format(
        "[ZombieFactions][SPRINT_PERF] sprintActivations=%d sprintClears=%d sprintVariableErrors=%d sprintIntentSeconds=%.1f sprintNodeLoops=%d sprintNodeLoopsPerSecond=%.2f sprintTilesPerSecond=%.3f sprintTravelSamples=%d shamblerTilesPerSecond=%.3f shamblerTravelSamples=%d sprintBrakes=%d sprintBrakeDistanceAvg=%.2f sprintMeleeAuths=%d sprintMeleeAuthDistanceAvg=%.2f sprintOvershoots=%d",
        metric("sprintActivations"),
        metric("sprintClears"),
        metric("sprintVariableErrors"),
        intentSeconds,
        metric("sprintNodeLoops"),
        intentSeconds > 0 and metric("sprintNodeLoops") / intentSeconds or 0,
        tilesPerSecond("sprint"),
        metric("sprintTravelSamples"),
        tilesPerSecond("shambler"),
        metric("shamblerTravelSamples"),
        metric("sprintBrakes"),
        average("sprintBrakeDistanceSum", "sprintBrakes"),
        metric("sprintMeleeAuths"),
        average("sprintMeleeAuthDistanceSum", "sprintMeleeAuths"),
        metric("sprintOvershoots")
    ))

    print(string.format(
        "[ZombieFactions][PERF] trackedTargets=%d trackedImpacts=%d clientCollisionDistance=%.2f serverValidationDistance=%.2f controllerPasses=%d zombieIndexBuilds=%d pursuitCommands=%d engagements=%d meleeCommitments=%d targetReattachments=%d reattachBackoffs=%d nativeZombieTargetsCleared=%d stuckReacquires=%d obstacleChecks=%d obstacleCacheHits=%d attackPresentationsArmed=%d attackPresentationsSuppressed=%d attackPresentationsExpired=%d crawlerLungesArmed=%d crawlerLungeImpacts=%d stompsArmed=%d stompImpacts=%d sittingStompsArmed=%d sittingStompImpacts=%d attackSoundsPlayed=%d attackSoundsSuppressed=%d stompSoundsPlayed=%d stompSoundsSuppressed=%d crawlerHitReactionsArmed=%d crawlerBiteReactionsArmed=%d sittingDefendersAlerted=%d sittingDefendersStood=%d sittingGetupsExpired=%d sittingGetupLocksArmed=%d sittingGetupAttackPauses=%d sittingGetupLocksReleased=%d sittingGetupLocksExpired=%d attackProfileChanges=%d biteBumpsArmed=%d biteBumpsSuppressed=%d biteBumpsExpired=%d biteCollisions=%d biteSoundsPlayed=%d biteSoundsSuppressed=%d hitReactionsArmed=%d hitReactionsSuppressed=%d hitReactionsExpired=%d presentationCues=%d presentationStarts=%d presentationSuppressed=%d presentationRetired=%d customAttackStarts=%d customAttackHits=%d customAttackCancels=%d invalidAttackBumpsRecovered=%d impactRequests=%d impactExactTarget=%d impactAuthorizedWithoutExact=%d impactNoAuthorization=%d impactBudgetDeferred=%d impactOutOfRange=%d impactUnsafe=%d safetySuspends=%d safetyResumes=%d releases=%d pendingGrants=%d grantResolveTimeouts=%d approachRetryOffsets=%d",
        trackedTargets,
        trackedImpacts,
        gauge("clientCollisionDistance"),
        gauge("serverValidationDistance"),
        metric("controllerPasses"),
        metric("zombieIndexBuilds"),
        metric("pursuitCommands"),
        metric("engagements"),
        metric("meleeCommitments"),
        metric("targetReattachments"),
        metric("reattachBackoffs"),
        metric("nativeZombieTargetsCleared"),
        metric("stuckReacquires"),
        metric("obstacleChecks"),
        metric("obstacleCacheHits"),
        metric("attackPresentationsArmed"),
        metric("attackPresentationsSuppressed"),
        metric("attackPresentationsExpired"),
        metric("crawlerLungesArmed"),
        metric("crawlerLungeImpacts"),
        metric("stompsArmed"),
        metric("stompImpacts"),
        metric("sittingStompsArmed"),
        metric("sittingStompImpacts"),
        metric("attackSoundsPlayed"),
        metric("attackSoundsSuppressed"),
        metric("stompSoundsPlayed"),
        metric("stompSoundsSuppressed"),
        metric("crawlerHitReactionsArmed"),
        metric("crawlerBiteReactionsArmed"),
        metric("sittingDefendersAlerted"),
        metric("sittingDefendersStood"),
        metric("sittingGetupsExpired"),
        metric("sittingGetupLocksArmed"),
        metric("sittingGetupAttackPauses"),
        metric("sittingGetupLocksReleased"),
        metric("sittingGetupLocksExpired"),
        metric("attackProfileChanges"),
        metric("biteBumpsArmed"),
        metric("biteBumpsSuppressed"),
        metric("biteBumpsExpired"),
        metric("biteCollisions"),
        metric("biteSoundsPlayed"),
        metric("biteSoundsSuppressed"),
        metric("hitReactionsArmed"),
        metric("hitReactionsSuppressed"),
        metric("hitReactionsExpired"),
        metric("presentationCues"),
        metric("presentationStarts"),
        metric("presentationSuppressed"),
        metric("presentationRetired"),
        metric("customAttackStarts"),
        metric("customAttackHits"),
        metric("customAttackCancels"),
        metric("invalidAttackBumpsRecovered"),
        metric("impactRequests"),
        metric("impactExactTarget"),
        metric("impactAuthorizedWithoutExact"),
        metric("impactNoAuthorization"),
        metric("impactBudgetDeferred"),
        metric("impactOutOfRange"),
        metric("impactUnsafe"),
        metric("safetySuspends"),
        metric("safetyResumes"),
        metric("releases"),
        gauge("pendingGrants"),
        metric("grantResolveTimeouts"),
        metric("approachRetryOffsets")
    ))
    controller.counters = {}
end

local function onTick()
    controller.updateCountdown = controller.updateCountdown - 1
    controller.summaryCountdown = controller.summaryCountdown - 1

    if controller.updateCountdown <= 0 then
        controller.updateCountdown = UPDATE_INTERVAL_TICKS
        controller.zombieIndex = nil
        controller.passSequence = controller.passSequence + 1
        controller.impactRequestBudget = IMPACT_REQUEST_BUDGET_PER_PASS
        controller.increment("controllerPasses")
        for i = 1, #controller.callbackOrder do
            local ordered = controller.callbackOrder[i]
            local entry = controller.callbacks[ordered.name]
            local ok, err = pcall(entry.callback, UPDATE_INTERVAL_TICKS)
            if not ok then
                print(string.format("[ZombieFactions][PERF] controller=%s error=%s", tostring(ordered.name), tostring(err)))
            end
        end
    end

    if controller.summaryCountdown <= 0 then
        controller.summaryCountdown = SUMMARY_INTERVAL_TICKS
        refreshVerbose()
        printSummary()
    end
end

ZombieFactions.ClientCombatController = controller
Events.OnTick.Add(onTick)
