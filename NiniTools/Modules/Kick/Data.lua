local ADDON_NAME = ...
local RDE = _G.NiniKick or {}
_G.NiniKick = RDE

RDE.ACTIONS = {
    FEINT = {
        spellID = 1966,
        text = "교란",
        tts = "교란",
        color = { 0.20, 0.70, 1.00 },
    },
    CLOAK = {
        spellID = 31224,
        text = "그망",
        tts = "그망",
        color = { 0.65, 0.35, 1.00 },
    },
    CLOAK_PRE = {
        spellID = 31224,
        text = "선그망",
        tts = "선그망",
        color = { 0.85, 0.25, 1.00 },
        impactLead = 0.80,
    },
    EVASION = {
        spellID = 5277,
        text = "회피",
        tts = "회피",
        color = { 1.00, 0.58, 0.12 },
    },
    VANISH = {
        spellID = 1856,
        text = "소멸 해제",
        tts = "소멸",
        color = { 0.35, 1.00, 0.45 },
    },
}
