ZombieFactions = ZombieFactions or {}

ZombieFactions.Relationship = {
    FRIENDLY = "FRIENDLY",
    NEUTRAL = "NEUTRAL",
    HOSTILE = "HOSTILE",
}

ZombieFactions.Faction = {
    VANILLA = "zf:vanilla",
    TEST_RED = "zf:test-red",
    TEST_BLUE = "zf:test-blue",
}

ZombieFactions.PlayerTarget = {
    UNFACTIONED = "pf:unfactioned",
}

-- Shipped zombie speed selectors. SANDBOX is a mod-local "leave it alone"
-- sentinel, not an engine value. RANDOM is a randomization instruction the
-- engine resolves into one of the other speeds, not a fourth gait.
ZombieFactions.SpeedType = {
    SANDBOX = 0,
    SPRINTER = 1,
    FAST_SHAMBLER = 2,
    SHAMBLER = 3,
    RANDOM = 4,
}
