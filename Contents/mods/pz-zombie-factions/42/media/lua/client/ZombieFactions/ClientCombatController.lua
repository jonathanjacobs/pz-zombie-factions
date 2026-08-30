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

local function printSummary()
    local trackedTargets = gauge("trackedTargets")
    local trackedImpacts = gauge("trackedImpacts")
    if trackedTargets == 0 and trackedImpacts == 0 then
        controller.counters = {}
        return
    end

    print(string.format(
        "[ZombieFactions][PERF] trackedTargets=%d trackedImpacts=%d controllerPasses=%d zombieIndexBuilds=%d pursuitCommands=%d engagements=%d meleeCommitments=%d targetReattachments=%d reattachBackoffs=%d stuckReacquires=%d obstacleChecks=%d obstacleCacheHits=%d customAttackStarts=%d customAttackHits=%d customAttackCancels=%d invalidAttackBumpsRecovered=%d impactRequests=%d impactExactTarget=%d impactAuthorizedWithoutExact=%d impactNoAuthorization=%d impactBudgetDeferred=%d impactOutOfRange=%d impactUnsafe=%d safetySuspends=%d safetyResumes=%d releases=%d",
        trackedTargets,
        trackedImpacts,
        metric("controllerPasses"),
        metric("zombieIndexBuilds"),
        metric("pursuitCommands"),
        metric("engagements"),
        metric("meleeCommitments"),
        metric("targetReattachments"),
        metric("reattachBackoffs"),
        metric("stuckReacquires"),
        metric("obstacleChecks"),
        metric("obstacleCacheHits"),
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
        metric("releases")
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
        printSummary()
    end
end

ZombieFactions.ClientCombatController = controller
Events.OnTick.Add(onTick)
