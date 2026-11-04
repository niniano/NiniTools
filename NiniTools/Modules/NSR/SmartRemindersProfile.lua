local ADDON_NAME, NT = ...
if not NT then return end

local M = {}
NT.NSRBridge = M

local ROGUE_PROFILE_NAME = "Nini Rogue M+ S2 - Safe Alpha"
local GENERIC_PROFILE_NAME = "Nini M+ Defensive Alert - Sonar"
local PROFILE_VERSION = "2.5.2"
local SONAR_KEY = "NiniTools - Sonar"
local SONAR_PATH = "Interface\\AddOns\\NiniTools\\Media\\Sounds\\Sonar.ogg"
local TARGET_EVENT = "EXBOSS_TRASH_OBSERVED_CAST_START"
local VOICE_EVENT = "EXBOSS_TRASH_CAST_START_VOICE_TRIGGERED"
local TARGET_OWNER = "NiniTools.NSR.SecretTargetVisual"
local OLD_TARGET_OWNER = "NiniSmartRemindersProfile.SecretTargetVisual.Cast"
local targetBridgeRegistered = false
local targetDebug = false
local targetVisualPool = {}
local targetVisualSerial = 0
local targetCastSeen = {}
local aoeCastSeen = {}
local bridgeRuntimeToken = 0
local AOE_DEFENSIVE_DELAY = 0.65
local statusText = "Naowh Smart Reminders 연결 대기"


-- Bundled Raid Bosses baseline for the same managed Rogue profile used by M+.
-- This is seeded once into Naowh Smart Reminders, then the user's Raid Bosses
-- checkboxes remain theirs: NiniTools does not erase or continually re-own them.
local ROGUE_RAID_PROFILE_DEFAULTS = {
    [3379] = { -- 님리사 웨이브콜러
        [1260837] = { enabled = true, mode = "defensive", preset = "p1" }, -- 심연의 비
    },
    [3470] = { -- 영혼살무사 네크잘리
        [1285681] = { enabled = true, mode = "defensive", preset = "p1" }, -- 영혼똬리 점화
        [1299673] = { enabled = true, mode = "defensive", preset = "p2" }, -- 기원: 그림자 망토
    },
    [3445] = { -- 매장된 파수꾼
        [1288232] = { enabled = true, mode = "defensive", preset = "p1" }, -- 불안정한 독기
    },
    [3497] = { -- 길 잃은 탐험가
        [1296092] = { enabled = true, mode = "defensive", preset = "p1" }, -- 강력한 후려치기
    },
    [3455] = { -- 악성의 바쉬니크
        [1282525] = { enabled = true, mode = "defensive", preset = "p1" }, -- 악성 촉매
        [1282117] = { enabled = true, mode = "defensive", preset = "p1" }, -- 적응성 감염
    },
    [3421] = { -- 쌍둥이 송곳니
        [1289192] = { enabled = true, mode = "defensive", preset = "p1" }, -- 부식의 폭우
        [1290516] = { enabled = true, mode = "defensive", preset = "p1" }, -- 걸신들린 탐식
    },
    [3429] = { -- 똬리의 제단
        [1283489] = { enabled = true, mode = "defensive", preset = "p1" }, -- 단두대
        [1299266] = { enabled = true, mode = "defensive", preset = "p1" }, -- 냉혹한 단두대 (UI Add Ability row)
    },
}
local ROGUE_RAID_PROFILE_SEED_VERSION = 2


-- Naowh EXBoss profile: curated generic AoE set.  When EXBoss is present it already
-- speaks the mechanic ("AOE") at cast start; NiniTools waits for that short clip to end
-- and then asks Smart Reminders to speak the Rogue defensive.  Spells without a safe
-- Ninjarobot defensive mapping intentionally have no Rogue preset here.
local AOE18 = {
    [270293] = 1762, [1297970] = 1762, [1305945] = 1762,
    [265966] = 1877, [1293475] = 1877, [1303486] = 1877,
    [373692] = 2521, [1305201] = 2521,
    [1250937] = 2859, [1271385] = 2859,
    [1234855] = 2923, [1299270] = 2923,
    [1238687] = 2825, [1246957] = 2825,
    [1294824] = 2813, [1302007] = 2813,
    [1294849] = 2993, [1306517] = 2993,
}

local AOE_ROGUE_PRESET = {
    [270293] = "p4", [1297970] = "p1", [1305945] = "p4",
    [265966] = "p1", [1293475] = "p4", [1303486] = "p4",
    [373692] = "p4", [1305201] = "p4",
    [1250937] = "p1",
    [1299270] = "p4", [1238687] = "p2", [1246957] = "p1",
    [1294849] = "p1",
}

local ROGUE_DATA = {
    enabled = true,
    showIcon = true,
    showText = true,
    showBar = false,
    soundOn = false,
    soundKey = "none",
    fallbackOn = false,
    coveredSkip = true,
    leadTime = 0.8,
    lingerSec = 3,
    voiceOn = true,
    voiceVol = 100,
    bossSource = "bigwigs",
    presets = {
        ["259"] = {
            p1 = {
                name = "Feint",
                list = { 1966 },
            },
            p2 = {
                name = "Cloak of Shadows",
                list = { 31224 },
            },
            p3 = {
                name = "Evasion",
                list = { 5277 },
            },
            p4 = {
                name = "Feint > Cloak",
                list = { 1966, 31224 },
            },
            p5 = {
                name = "Feint > Evasion",
                list = { 1966, 5277 },
            },
            p6 = {
                name = "Cloak > Evasion",
                list = { 31224, 5277 },
            },
            p7 = {
                name = "Feint > Cloak > Evasion",
                list = { 1966, 31224, 5277 },
            },
        },
        ["260"] = {
            p1 = {
                name = "Feint",
                list = { 1966 },
            },
            p2 = {
                name = "Cloak of Shadows",
                list = { 31224 },
            },
            p3 = {
                name = "Evasion",
                list = { 5277 },
            },
            p4 = {
                name = "Feint > Cloak",
                list = { 1966, 31224 },
            },
            p5 = {
                name = "Feint > Evasion",
                list = { 1966, 5277 },
            },
            p6 = {
                name = "Cloak > Evasion",
                list = { 31224, 5277 },
            },
            p7 = {
                name = "Feint > Cloak > Evasion",
                list = { 1966, 31224, 5277 },
            },
        },
        ["261"] = {
            p1 = {
                name = "Feint",
                list = { 1966 },
            },
            p2 = {
                name = "Cloak of Shadows",
                list = { 31224 },
            },
            p3 = {
                name = "Evasion",
                list = { 5277 },
            },
            p4 = {
                name = "Feint > Cloak",
                list = { 1966, 31224 },
            },
            p5 = {
                name = "Feint > Evasion",
                list = { 1966, 5277 },
            },
            p6 = {
                name = "Cloak > Evasion",
                list = { 31224, 5277 },
            },
            p7 = {
                name = "Feint > Cloak > Evasion",
                list = { 1966, 31224, 5277 },
            },
        },
    },
    activePreset = {
        ["259"] = "p7",
        ["260"] = "p7",
        ["261"] = "p7",
    },
    integrationRules = {
        ["259"] = {
            nini_2993_1294849 = {
                name = "Rattling Writhe: Rattle",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 1294849,
                    mapID = 2993,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1294849,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_2993_1295055 = {
                name = "Ascendant Serpent: Virulent Whirl",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1295055,
                    mapID = 2993,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1295055,
                },
                niniTrashClass = "predictive",
                niniEventType = "其他",
                niniTargetAPIExists = false,
            },
            nini_2993_1308864 = {
                name = "Ascendant Serpent: Infest",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1308864,
                    mapID = 2993,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1308864,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_2825_1238687 = {
                name = "Spirit of Hunger: Feast of Misery",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1238687,
                    mapID = 2825,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1238687,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_2825_1240280 = {
                name = "Avatar of Determination: Pulverize",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 1240280,
                    mapID = 2825,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1240280,
                },
                niniTrashClass = "predictive",
                niniEventType = "其他",
                niniTargetAPIExists = false,
            },
            nini_2825_1241463 = {
                name = "Avatar of Determination: Glacial Tomb",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1241463,
                    mapID = 2825,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1241463,
                },
                niniTrashClass = "predictive",
                niniEventType = "特殊",
                niniTargetAPIExists = false,
            },
            nini_2825_1246957 = {
                name = "Grizzled Warbringer: Primal Echo",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 1246957,
                    mapID = 2825,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1246957,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_2825_1246986 = {
                name = "Grizzled Warbringer: Poison Spear Volley",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1246986,
                    mapID = 2825,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1246986,
                },
                niniTrashClass = "predictive",
                niniEventType = "其他",
                niniTargetAPIExists = false,
            },
            nini_2825_1296722 = {
                name = "Loa Speaker Nanea: Earthquake",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1296722,
                    mapID = 2825,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1296722,
                },
                niniTrashClass = "predictive",
                niniEventType = "特殊",
                niniTargetAPIExists = false,
            },
            nini_1762_270293 = {
                name = "Purification Construct: Purification Strike + Purifying Flame",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 270293,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 270293,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_1762_270502 = {
                name = "Honored Raptor / Skeletal Hunting Raptor: Hunting Leap",
                enabled = true,
                preset = "p5",
                trigger = {
                    type = "exboss",
                    spellID = 270502,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 270502,
                },
                niniTrashClass = "predictive",
                niniEventType = "其他",
                niniTargetAPIExists = false,
            },
            nini_1762_270514 = {
                name = "Ghostly Brute: Seismic Upheaval",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 270514,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 270514,
                },
                niniTrashClass = "predictive",
                niniEventType = "其他",
                niniTargetAPIExists = false,
            },
            nini_1762_270889 = {
                name = "King Rahu'ai: Overload",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 270889,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 270889,
                },
                niniTrashClass = "predictive",
                niniEventType = "其他",
                niniTargetAPIExists = false,
            },
            nini_1762_1297970 = {
                name = "King A'akul: Blood Drain",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 1297970,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1297970,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_1762_1305945 = {
                name = "Shadow-Borne Champion: Necrotic Energy + Shadow Whirlwind",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1305945,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1305945,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_2813_1297691 = {
                name = "Shivan Punisher: Whirlwind",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 1297691,
                    mapID = 2813,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1297691,
                },
                niniTrashClass = "predictive",
                niniEventType = "其他",
                niniTargetAPIExists = false,
            },
            nini_2521_373692 = {
                name = "Blazebound Destroyer: Inferno",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 373692,
                    mapID = 2521,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 373692,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_2521_384823 = {
                name = "Blazebound Firestorm: Inferno",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 384823,
                    mapID = 2521,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 384823,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_2521_1305201 = {
                name = "Primal Juggernaut: Excavating Blast",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1305201,
                    mapID = 2521,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1305201,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_1877_265966 = {
                name = "Sandfury Stonefist: Ground Pound",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 265966,
                    mapID = 1877,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 265966,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_1877_272655 = {
                name = "Sand-Sworn Rider: Scouring Sand",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 272655,
                    mapID = 1877,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 272655,
                },
                niniTrashClass = "predictive",
                niniEventType = "其他",
                niniTargetAPIExists = false,
            },
            nini_1877_1291622 = {
                name = "Storm Serpent: Lingering Storm + Storm Catalyst",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1291622,
                    mapID = 1877,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1291622,
                },
                niniTrashClass = "predictive",
                niniEventType = "其他",
                niniTargetAPIExists = false,
            },
            nini_1877_1293475 = {
                name = "Agitated Nimbus: Release Charge",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1293475,
                    mapID = 1877,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1293475,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_1877_1293650 = {
                name = "Agitated Nimbus: Call Lightning",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1293650,
                    mapID = 1877,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1293650,
                },
                niniTrashClass = "predictive",
                niniEventType = "其他",
                niniTargetAPIExists = false,
            },
            nini_1877_1303486 = {
                name = "Orb Watcher: Caustic Stomp",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1303486,
                    mapID = 1877,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1303486,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_2859_1242138 = {
                name = "Luminous Thornmaw: Solar Breath",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1242138,
                    mapID = 2859,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1242138,
                },
                niniTrashClass = "predictive",
                niniEventType = "其他",
                niniTargetAPIExists = false,
            },
            nini_2859_1250937 = {
                name = "Potatoad Matriarch: Toxic Spew",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 1250937,
                    mapID = 2859,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1250937,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_2859_1255205 = {
                name = "Virid Grovekeeper: Uproot",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1255205,
                    mapID = 2859,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1255205,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_2923_1252406 = {
                name = "Devouring Brutalizer: Dreadbellow",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1252406,
                    mapID = 2923,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1252406,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_2923_1298900 = {
                name = "Brutal Overseer: Brutal Slams",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 1298900,
                    mapID = 2923,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1298900,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_2923_1298908 = {
                name = "Aegyra the Unyielding: Champion's Spear",
                enabled = true,
                preset = "p3",
                trigger = {
                    type = "exboss",
                    spellID = 1298908,
                    mapID = 2923,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1298908,
                },
                niniTrashClass = "predictive",
                niniEventType = "特殊",
                niniTargetAPIExists = false,
            },
            nini_2923_1298924 = {
                name = "Aegyra the Unyielding: Savage Smash",
                enabled = true,
                preset = "p5",
                trigger = {
                    type = "exboss",
                    spellID = 1298924,
                    mapID = 2923,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1298924,
                },
                niniTrashClass = "predictive",
                niniEventType = "其他",
                niniTargetAPIExists = false,
            },
            nini_2923_1299145 = {
                name = "Aegyra the Unyielding: Aftershock",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1299145,
                    mapID = 2923,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1299145,
                },
                niniTrashClass = "predictive",
                niniEventType = "特殊",
                niniTargetAPIExists = false,
            },
            nini_2923_1299270 = {
                name = "Raj'kess the Spellstorm: Thundering Storm",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1299270,
                    mapID = 2923,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1299270,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_2923_1299938 = {
                name = "Voidtouched Magi: Shadowbolt Volley",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 1299938,
                    mapID = 2923,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1299938,
                },
                niniTrashClass = "predictive",
                niniEventType = "其他",
                niniTargetAPIExists = false,
            },
        },
        ["260"] = {
            nini_2993_1294849 = {
                name = "Rattling Writhe: Rattle",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 1294849,
                    mapID = 2993,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1294849,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_2993_1295055 = {
                name = "Ascendant Serpent: Virulent Whirl",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1295055,
                    mapID = 2993,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1295055,
                },
                niniTrashClass = "predictive",
                niniEventType = "其他",
                niniTargetAPIExists = false,
            },
            nini_2993_1308864 = {
                name = "Ascendant Serpent: Infest",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1308864,
                    mapID = 2993,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1308864,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_2825_1238687 = {
                name = "Spirit of Hunger: Feast of Misery",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1238687,
                    mapID = 2825,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1238687,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_2825_1240280 = {
                name = "Avatar of Determination: Pulverize",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 1240280,
                    mapID = 2825,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1240280,
                },
                niniTrashClass = "predictive",
                niniEventType = "其他",
                niniTargetAPIExists = false,
            },
            nini_2825_1241463 = {
                name = "Avatar of Determination: Glacial Tomb",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1241463,
                    mapID = 2825,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1241463,
                },
                niniTrashClass = "predictive",
                niniEventType = "特殊",
                niniTargetAPIExists = false,
            },
            nini_2825_1246957 = {
                name = "Grizzled Warbringer: Primal Echo",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 1246957,
                    mapID = 2825,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1246957,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_2825_1246986 = {
                name = "Grizzled Warbringer: Poison Spear Volley",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1246986,
                    mapID = 2825,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1246986,
                },
                niniTrashClass = "predictive",
                niniEventType = "其他",
                niniTargetAPIExists = false,
            },
            nini_2825_1296722 = {
                name = "Loa Speaker Nanea: Earthquake",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1296722,
                    mapID = 2825,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1296722,
                },
                niniTrashClass = "predictive",
                niniEventType = "特殊",
                niniTargetAPIExists = false,
            },
            nini_1762_270293 = {
                name = "Purification Construct: Purification Strike + Purifying Flame",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 270293,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 270293,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_1762_270502 = {
                name = "Honored Raptor / Skeletal Hunting Raptor: Hunting Leap",
                enabled = true,
                preset = "p5",
                trigger = {
                    type = "exboss",
                    spellID = 270502,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 270502,
                },
                niniTrashClass = "predictive",
                niniEventType = "其他",
                niniTargetAPIExists = false,
            },
            nini_1762_270514 = {
                name = "Ghostly Brute: Seismic Upheaval",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 270514,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 270514,
                },
                niniTrashClass = "predictive",
                niniEventType = "其他",
                niniTargetAPIExists = false,
            },
            nini_1762_270889 = {
                name = "King Rahu'ai: Overload",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 270889,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 270889,
                },
                niniTrashClass = "predictive",
                niniEventType = "其他",
                niniTargetAPIExists = false,
            },
            nini_1762_1297970 = {
                name = "King A'akul: Blood Drain",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 1297970,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1297970,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_1762_1305945 = {
                name = "Shadow-Borne Champion: Necrotic Energy + Shadow Whirlwind",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1305945,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1305945,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_2813_1297691 = {
                name = "Shivan Punisher: Whirlwind",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 1297691,
                    mapID = 2813,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1297691,
                },
                niniTrashClass = "predictive",
                niniEventType = "其他",
                niniTargetAPIExists = false,
            },
            nini_2521_373692 = {
                name = "Blazebound Destroyer: Inferno",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 373692,
                    mapID = 2521,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 373692,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_2521_384823 = {
                name = "Blazebound Firestorm: Inferno",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 384823,
                    mapID = 2521,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 384823,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_2521_1305201 = {
                name = "Primal Juggernaut: Excavating Blast",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1305201,
                    mapID = 2521,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1305201,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_1877_265966 = {
                name = "Sandfury Stonefist: Ground Pound",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 265966,
                    mapID = 1877,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 265966,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_1877_272655 = {
                name = "Sand-Sworn Rider: Scouring Sand",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 272655,
                    mapID = 1877,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 272655,
                },
                niniTrashClass = "predictive",
                niniEventType = "其他",
                niniTargetAPIExists = false,
            },
            nini_1877_1291622 = {
                name = "Storm Serpent: Lingering Storm + Storm Catalyst",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1291622,
                    mapID = 1877,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1291622,
                },
                niniTrashClass = "predictive",
                niniEventType = "其他",
                niniTargetAPIExists = false,
            },
            nini_1877_1293475 = {
                name = "Agitated Nimbus: Release Charge",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1293475,
                    mapID = 1877,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1293475,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_1877_1293650 = {
                name = "Agitated Nimbus: Call Lightning",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1293650,
                    mapID = 1877,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1293650,
                },
                niniTrashClass = "predictive",
                niniEventType = "其他",
                niniTargetAPIExists = false,
            },
            nini_1877_1303486 = {
                name = "Orb Watcher: Caustic Stomp",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1303486,
                    mapID = 1877,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1303486,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_2859_1242138 = {
                name = "Luminous Thornmaw: Solar Breath",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1242138,
                    mapID = 2859,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1242138,
                },
                niniTrashClass = "predictive",
                niniEventType = "其他",
                niniTargetAPIExists = false,
            },
            nini_2859_1250937 = {
                name = "Potatoad Matriarch: Toxic Spew",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 1250937,
                    mapID = 2859,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1250937,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_2859_1255205 = {
                name = "Virid Grovekeeper: Uproot",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1255205,
                    mapID = 2859,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1255205,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_2923_1252406 = {
                name = "Devouring Brutalizer: Dreadbellow",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1252406,
                    mapID = 2923,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1252406,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_2923_1298900 = {
                name = "Brutal Overseer: Brutal Slams",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 1298900,
                    mapID = 2923,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1298900,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_2923_1298908 = {
                name = "Aegyra the Unyielding: Champion's Spear",
                enabled = true,
                preset = "p3",
                trigger = {
                    type = "exboss",
                    spellID = 1298908,
                    mapID = 2923,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1298908,
                },
                niniTrashClass = "predictive",
                niniEventType = "特殊",
                niniTargetAPIExists = false,
            },
            nini_2923_1298924 = {
                name = "Aegyra the Unyielding: Savage Smash",
                enabled = true,
                preset = "p5",
                trigger = {
                    type = "exboss",
                    spellID = 1298924,
                    mapID = 2923,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1298924,
                },
                niniTrashClass = "predictive",
                niniEventType = "其他",
                niniTargetAPIExists = false,
            },
            nini_2923_1299145 = {
                name = "Aegyra the Unyielding: Aftershock",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1299145,
                    mapID = 2923,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1299145,
                },
                niniTrashClass = "predictive",
                niniEventType = "特殊",
                niniTargetAPIExists = false,
            },
            nini_2923_1299270 = {
                name = "Raj'kess the Spellstorm: Thundering Storm",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1299270,
                    mapID = 2923,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1299270,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_2923_1299938 = {
                name = "Voidtouched Magi: Shadowbolt Volley",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 1299938,
                    mapID = 2923,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1299938,
                },
                niniTrashClass = "predictive",
                niniEventType = "其他",
                niniTargetAPIExists = false,
            },
        },
        ["261"] = {
            nini_2993_1294849 = {
                name = "Rattling Writhe: Rattle",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 1294849,
                    mapID = 2993,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1294849,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_2993_1295055 = {
                name = "Ascendant Serpent: Virulent Whirl",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1295055,
                    mapID = 2993,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1295055,
                },
                niniTrashClass = "predictive",
                niniEventType = "其他",
                niniTargetAPIExists = false,
            },
            nini_2993_1308864 = {
                name = "Ascendant Serpent: Infest",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1308864,
                    mapID = 2993,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1308864,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_2825_1238687 = {
                name = "Spirit of Hunger: Feast of Misery",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1238687,
                    mapID = 2825,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1238687,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_2825_1240280 = {
                name = "Avatar of Determination: Pulverize",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 1240280,
                    mapID = 2825,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1240280,
                },
                niniTrashClass = "predictive",
                niniEventType = "其他",
                niniTargetAPIExists = false,
            },
            nini_2825_1241463 = {
                name = "Avatar of Determination: Glacial Tomb",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1241463,
                    mapID = 2825,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1241463,
                },
                niniTrashClass = "predictive",
                niniEventType = "特殊",
                niniTargetAPIExists = false,
            },
            nini_2825_1246957 = {
                name = "Grizzled Warbringer: Primal Echo",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 1246957,
                    mapID = 2825,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1246957,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_2825_1246986 = {
                name = "Grizzled Warbringer: Poison Spear Volley",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1246986,
                    mapID = 2825,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1246986,
                },
                niniTrashClass = "predictive",
                niniEventType = "其他",
                niniTargetAPIExists = false,
            },
            nini_2825_1296722 = {
                name = "Loa Speaker Nanea: Earthquake",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1296722,
                    mapID = 2825,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1296722,
                },
                niniTrashClass = "predictive",
                niniEventType = "特殊",
                niniTargetAPIExists = false,
            },
            nini_1762_270293 = {
                name = "Purification Construct: Purification Strike + Purifying Flame",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 270293,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 270293,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_1762_270502 = {
                name = "Honored Raptor / Skeletal Hunting Raptor: Hunting Leap",
                enabled = true,
                preset = "p5",
                trigger = {
                    type = "exboss",
                    spellID = 270502,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 270502,
                },
                niniTrashClass = "predictive",
                niniEventType = "其他",
                niniTargetAPIExists = false,
            },
            nini_1762_270514 = {
                name = "Ghostly Brute: Seismic Upheaval",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 270514,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 270514,
                },
                niniTrashClass = "predictive",
                niniEventType = "其他",
                niniTargetAPIExists = false,
            },
            nini_1762_270889 = {
                name = "King Rahu'ai: Overload",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 270889,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 270889,
                },
                niniTrashClass = "predictive",
                niniEventType = "其他",
                niniTargetAPIExists = false,
            },
            nini_1762_1297970 = {
                name = "King A'akul: Blood Drain",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 1297970,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1297970,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_1762_1305945 = {
                name = "Shadow-Borne Champion: Necrotic Energy + Shadow Whirlwind",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1305945,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1305945,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_2813_1297691 = {
                name = "Shivan Punisher: Whirlwind",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 1297691,
                    mapID = 2813,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1297691,
                },
                niniTrashClass = "predictive",
                niniEventType = "其他",
                niniTargetAPIExists = false,
            },
            nini_2521_373692 = {
                name = "Blazebound Destroyer: Inferno",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 373692,
                    mapID = 2521,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 373692,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_2521_384823 = {
                name = "Blazebound Firestorm: Inferno",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 384823,
                    mapID = 2521,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 384823,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_2521_1305201 = {
                name = "Primal Juggernaut: Excavating Blast",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1305201,
                    mapID = 2521,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1305201,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_1877_265966 = {
                name = "Sandfury Stonefist: Ground Pound",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 265966,
                    mapID = 1877,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 265966,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_1877_272655 = {
                name = "Sand-Sworn Rider: Scouring Sand",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 272655,
                    mapID = 1877,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 272655,
                },
                niniTrashClass = "predictive",
                niniEventType = "其他",
                niniTargetAPIExists = false,
            },
            nini_1877_1291622 = {
                name = "Storm Serpent: Lingering Storm + Storm Catalyst",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1291622,
                    mapID = 1877,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1291622,
                },
                niniTrashClass = "predictive",
                niniEventType = "其他",
                niniTargetAPIExists = false,
            },
            nini_1877_1293475 = {
                name = "Agitated Nimbus: Release Charge",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1293475,
                    mapID = 1877,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1293475,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_1877_1293650 = {
                name = "Agitated Nimbus: Call Lightning",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1293650,
                    mapID = 1877,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1293650,
                },
                niniTrashClass = "predictive",
                niniEventType = "其他",
                niniTargetAPIExists = false,
            },
            nini_1877_1303486 = {
                name = "Orb Watcher: Caustic Stomp",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1303486,
                    mapID = 1877,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1303486,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_2859_1242138 = {
                name = "Luminous Thornmaw: Solar Breath",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1242138,
                    mapID = 2859,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1242138,
                },
                niniTrashClass = "predictive",
                niniEventType = "其他",
                niniTargetAPIExists = false,
            },
            nini_2859_1250937 = {
                name = "Potatoad Matriarch: Toxic Spew",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 1250937,
                    mapID = 2859,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1250937,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_2859_1255205 = {
                name = "Virid Grovekeeper: Uproot",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1255205,
                    mapID = 2859,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1255205,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_2923_1252406 = {
                name = "Devouring Brutalizer: Dreadbellow",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1252406,
                    mapID = 2923,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1252406,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_2923_1298900 = {
                name = "Brutal Overseer: Brutal Slams",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 1298900,
                    mapID = 2923,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1298900,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_2923_1298908 = {
                name = "Aegyra the Unyielding: Champion's Spear",
                enabled = true,
                preset = "p3",
                trigger = {
                    type = "exboss",
                    spellID = 1298908,
                    mapID = 2923,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1298908,
                },
                niniTrashClass = "predictive",
                niniEventType = "特殊",
                niniTargetAPIExists = false,
            },
            nini_2923_1298924 = {
                name = "Aegyra the Unyielding: Savage Smash",
                enabled = true,
                preset = "p5",
                trigger = {
                    type = "exboss",
                    spellID = 1298924,
                    mapID = 2923,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1298924,
                },
                niniTrashClass = "predictive",
                niniEventType = "其他",
                niniTargetAPIExists = false,
            },
            nini_2923_1299145 = {
                name = "Aegyra the Unyielding: Aftershock",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1299145,
                    mapID = 2923,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1299145,
                },
                niniTrashClass = "predictive",
                niniEventType = "特殊",
                niniTargetAPIExists = false,
            },
            nini_2923_1299270 = {
                name = "Raj'kess the Spellstorm: Thundering Storm",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1299270,
                    mapID = 2923,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1299270,
                },
                niniTrashClass = "predictive",
                niniEventType = "治疗",
                niniTargetAPIExists = false,
            },
            nini_2923_1299938 = {
                name = "Voidtouched Magi: Shadowbolt Volley",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 1299938,
                    mapID = 2923,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1299938,
                },
                niniTrashClass = "predictive",
                niniEventType = "其他",
                niniTargetAPIExists = false,
            },
        },
    },
    niniTargetRules = {
        ["259"] = {
            ["1294567"] = {
                name = "Twinfang Harrower: Paralyzing Shots",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1294567,
                    mapID = 2993,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1294567,
                },
                niniTrashClass = "targeted",
                niniEventType = "点名",
                niniTargetAPIExists = false,
            },
            ["1306911"] = {
                name = "Ritual Chieftain: Unstable Totem",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1306911,
                    mapID = 2993,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1306911,
                },
                niniTrashClass = "targeted",
                niniEventType = "坦克",
                niniTargetAPIExists = true,
            },
            ["270003"] = {
                name = "Animated Guardian: Suppression Slam",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 270003,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 270003,
                },
                niniTrashClass = "targeted",
                niniEventType = "其他",
                niniTargetAPIExists = true,
            },
            ["270927"] = {
                name = "King Timalji: Bladestorm",
                enabled = true,
                preset = "p5",
                trigger = {
                    type = "exboss",
                    spellID = 270927,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 270927,
                },
                niniTrashClass = "targeted",
                niniEventType = "其他",
                niniTargetAPIExists = true,
            },
            ["272388"] = {
                name = "Shadow of Zul: Shadow Barrage",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 272388,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 272388,
                },
                niniTrashClass = "targeted",
                niniEventType = "其他",
                niniTargetAPIExists = true,
            },
            ["1296719"] = {
                name = "King Rahu'ai: Forked Lightning",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1296719,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1296719,
                },
                niniTrashClass = "targeted",
                niniEventType = "其他",
                niniTargetAPIExists = true,
            },
            ["1298304"] = {
                name = "Shadow of Zul: Dark Revelation",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1298304,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1298304,
                },
                niniTrashClass = "targeted",
                niniEventType = "点名",
                niniTargetAPIExists = false,
            },
            ["1305982"] = {
                name = "Queen Patlaa: Shadow Volley",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1305982,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1305982,
                },
                niniTrashClass = "targeted",
                niniEventType = "其他",
                niniTargetAPIExists = true,
            },
            ["1306049"] = {
                name = "King Timalji: Erupting Slam",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 1306049,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1306049,
                },
                niniTrashClass = "targeted",
                niniEventType = "点名",
                niniTargetAPIExists = true,
            },
            ["1309385"] = {
                name = "Shadow of Zul: Absorbed in Darkness + Erupting Darkness",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1309385,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1309385,
                },
                niniTrashClass = "targeted",
                niniEventType = "特殊",
                niniTargetAPIExists = true,
            },
            ["1217633"] = {
                name = "Massive Felwyrm: Corroding Spittle",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1217633,
                    mapID = 2813,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1217633,
                },
                niniTrashClass = "targeted",
                niniEventType = "治疗",
                niniTargetAPIExists = true,
            },
            ["1217973"] = {
                name = "Corrupted Warlock: Curse of Doom",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1217973,
                    mapID = 2813,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1217973,
                },
                niniTrashClass = "targeted",
                niniEventType = "治疗",
                niniTargetAPIExists = true,
            },
            ["1258537"] = {
                name = "Massive Felwyrm: Massive Fel Detonation",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1258537,
                    mapID = 2813,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1258537,
                },
                niniTrashClass = "targeted",
                niniEventType = "特殊",
                niniTargetAPIExists = true,
            },
            ["1297682"] = {
                name = "Corrupted Warlock: Drain Life",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1297682,
                    mapID = 2813,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1297682,
                },
                niniTrashClass = "targeted",
                niniEventType = "点名",
                niniTargetAPIExists = true,
            },
            ["372047"] = {
                name = "Defier Draghar: Molten Steel + Steel Barrage",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 372047,
                    mapID = 2521,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 372047,
                },
                niniTrashClass = "targeted",
                niniEventType = "坦克",
                niniTargetAPIExists = true,
            },
            ["391723"] = {
                name = "Flamegullet: Flame Breath",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 391723,
                    mapID = 2521,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 391723,
                },
                niniTrashClass = "targeted",
                niniEventType = "其他",
                niniTargetAPIExists = true,
            },
            ["392640"] = {
                name = "Thunderhead: Electrical Discharge",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 392640,
                    mapID = 2521,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 392640,
                },
                niniTrashClass = "targeted",
                niniEventType = "点名",
                niniTargetAPIExists = false,
            },
            ["1306366"] = {
                name = "High Channeler Ryvati / Tempest Channeler: Lightning Torrent",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1306366,
                    mapID = 2521,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1306366,
                },
                niniTrashClass = "targeted",
                niniEventType = "点名",
                niniTargetAPIExists = nil,
            },
            ["1303443"] = {
                name = "Orb Watcher: Venom Shrapnel",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1303443,
                    mapID = 1877,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1303443,
                },
                niniTrashClass = "targeted",
                niniEventType = "坦克",
                niniTargetAPIExists = true,
            },
            ["1237855"] = {
                name = "Virid Grovekeeper: Ruptured Earth",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1237855,
                    mapID = 2859,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1237855,
                },
                niniTrashClass = "targeted",
                niniEventType = "坦克",
                niniTargetAPIExists = true,
            },
            ["1238368"] = {
                name = "Overgrown Hydra: Lightmaw Beams",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1238368,
                    mapID = 2859,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1238368,
                },
                niniTrashClass = "targeted",
                niniEventType = "点名",
                niniTargetAPIExists = false,
            },
            ["1239856"] = {
                name = "Watchful Harrower: Sky Strike",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1239856,
                    mapID = 2923,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1239856,
                },
                niniTrashClass = "targeted",
                niniEventType = "治疗",
                niniTargetAPIExists = true,
            },
            ["1299913"] = {
                name = "Voidtouched Magi: Null Eruption",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1299913,
                    mapID = 2923,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1299913,
                },
                niniTrashClass = "targeted",
                niniEventType = "点名",
                niniTargetAPIExists = true,
            },
            ["1300138"] = {
                name = "Watchful Harrower: Void Beam",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1300138,
                    mapID = 2923,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1300138,
                },
                niniTrashClass = "targeted",
                niniEventType = "点名",
                niniTargetAPIExists = true,
            },
            ["1310309"] = {
                name = "Brutal Overseer: Macestorm",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 1310309,
                    mapID = 2923,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1310309,
                },
                niniTrashClass = "targeted",
                niniEventType = "点名",
                niniTargetAPIExists = false,
            },
        },
        ["260"] = {
            ["1294567"] = {
                name = "Twinfang Harrower: Paralyzing Shots",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1294567,
                    mapID = 2993,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1294567,
                },
                niniTrashClass = "targeted",
                niniEventType = "点名",
                niniTargetAPIExists = false,
            },
            ["1306911"] = {
                name = "Ritual Chieftain: Unstable Totem",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1306911,
                    mapID = 2993,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1306911,
                },
                niniTrashClass = "targeted",
                niniEventType = "坦克",
                niniTargetAPIExists = true,
            },
            ["270003"] = {
                name = "Animated Guardian: Suppression Slam",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 270003,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 270003,
                },
                niniTrashClass = "targeted",
                niniEventType = "其他",
                niniTargetAPIExists = true,
            },
            ["270927"] = {
                name = "King Timalji: Bladestorm",
                enabled = true,
                preset = "p5",
                trigger = {
                    type = "exboss",
                    spellID = 270927,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 270927,
                },
                niniTrashClass = "targeted",
                niniEventType = "其他",
                niniTargetAPIExists = true,
            },
            ["272388"] = {
                name = "Shadow of Zul: Shadow Barrage",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 272388,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 272388,
                },
                niniTrashClass = "targeted",
                niniEventType = "其他",
                niniTargetAPIExists = true,
            },
            ["1296719"] = {
                name = "King Rahu'ai: Forked Lightning",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1296719,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1296719,
                },
                niniTrashClass = "targeted",
                niniEventType = "其他",
                niniTargetAPIExists = true,
            },
            ["1298304"] = {
                name = "Shadow of Zul: Dark Revelation",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1298304,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1298304,
                },
                niniTrashClass = "targeted",
                niniEventType = "点名",
                niniTargetAPIExists = false,
            },
            ["1305982"] = {
                name = "Queen Patlaa: Shadow Volley",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1305982,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1305982,
                },
                niniTrashClass = "targeted",
                niniEventType = "其他",
                niniTargetAPIExists = true,
            },
            ["1306049"] = {
                name = "King Timalji: Erupting Slam",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 1306049,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1306049,
                },
                niniTrashClass = "targeted",
                niniEventType = "点名",
                niniTargetAPIExists = true,
            },
            ["1309385"] = {
                name = "Shadow of Zul: Absorbed in Darkness + Erupting Darkness",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1309385,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1309385,
                },
                niniTrashClass = "targeted",
                niniEventType = "特殊",
                niniTargetAPIExists = true,
            },
            ["1217633"] = {
                name = "Massive Felwyrm: Corroding Spittle",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1217633,
                    mapID = 2813,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1217633,
                },
                niniTrashClass = "targeted",
                niniEventType = "治疗",
                niniTargetAPIExists = true,
            },
            ["1217973"] = {
                name = "Corrupted Warlock: Curse of Doom",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1217973,
                    mapID = 2813,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1217973,
                },
                niniTrashClass = "targeted",
                niniEventType = "治疗",
                niniTargetAPIExists = true,
            },
            ["1258537"] = {
                name = "Massive Felwyrm: Massive Fel Detonation",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1258537,
                    mapID = 2813,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1258537,
                },
                niniTrashClass = "targeted",
                niniEventType = "特殊",
                niniTargetAPIExists = true,
            },
            ["1297682"] = {
                name = "Corrupted Warlock: Drain Life",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1297682,
                    mapID = 2813,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1297682,
                },
                niniTrashClass = "targeted",
                niniEventType = "点名",
                niniTargetAPIExists = true,
            },
            ["372047"] = {
                name = "Defier Draghar: Molten Steel + Steel Barrage",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 372047,
                    mapID = 2521,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 372047,
                },
                niniTrashClass = "targeted",
                niniEventType = "坦克",
                niniTargetAPIExists = true,
            },
            ["391723"] = {
                name = "Flamegullet: Flame Breath",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 391723,
                    mapID = 2521,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 391723,
                },
                niniTrashClass = "targeted",
                niniEventType = "其他",
                niniTargetAPIExists = true,
            },
            ["392640"] = {
                name = "Thunderhead: Electrical Discharge",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 392640,
                    mapID = 2521,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 392640,
                },
                niniTrashClass = "targeted",
                niniEventType = "点名",
                niniTargetAPIExists = false,
            },
            ["1306366"] = {
                name = "High Channeler Ryvati / Tempest Channeler: Lightning Torrent",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1306366,
                    mapID = 2521,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1306366,
                },
                niniTrashClass = "targeted",
                niniEventType = "点名",
                niniTargetAPIExists = nil,
            },
            ["1303443"] = {
                name = "Orb Watcher: Venom Shrapnel",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1303443,
                    mapID = 1877,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1303443,
                },
                niniTrashClass = "targeted",
                niniEventType = "坦克",
                niniTargetAPIExists = true,
            },
            ["1237855"] = {
                name = "Virid Grovekeeper: Ruptured Earth",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1237855,
                    mapID = 2859,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1237855,
                },
                niniTrashClass = "targeted",
                niniEventType = "坦克",
                niniTargetAPIExists = true,
            },
            ["1238368"] = {
                name = "Overgrown Hydra: Lightmaw Beams",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1238368,
                    mapID = 2859,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1238368,
                },
                niniTrashClass = "targeted",
                niniEventType = "点名",
                niniTargetAPIExists = false,
            },
            ["1239856"] = {
                name = "Watchful Harrower: Sky Strike",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1239856,
                    mapID = 2923,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1239856,
                },
                niniTrashClass = "targeted",
                niniEventType = "治疗",
                niniTargetAPIExists = true,
            },
            ["1299913"] = {
                name = "Voidtouched Magi: Null Eruption",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1299913,
                    mapID = 2923,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1299913,
                },
                niniTrashClass = "targeted",
                niniEventType = "点名",
                niniTargetAPIExists = true,
            },
            ["1300138"] = {
                name = "Watchful Harrower: Void Beam",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1300138,
                    mapID = 2923,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1300138,
                },
                niniTrashClass = "targeted",
                niniEventType = "点名",
                niniTargetAPIExists = true,
            },
            ["1310309"] = {
                name = "Brutal Overseer: Macestorm",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 1310309,
                    mapID = 2923,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1310309,
                },
                niniTrashClass = "targeted",
                niniEventType = "点名",
                niniTargetAPIExists = false,
            },
        },
        ["261"] = {
            ["1294567"] = {
                name = "Twinfang Harrower: Paralyzing Shots",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1294567,
                    mapID = 2993,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1294567,
                },
                niniTrashClass = "targeted",
                niniEventType = "点名",
                niniTargetAPIExists = false,
            },
            ["1306911"] = {
                name = "Ritual Chieftain: Unstable Totem",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1306911,
                    mapID = 2993,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1306911,
                },
                niniTrashClass = "targeted",
                niniEventType = "坦克",
                niniTargetAPIExists = true,
            },
            ["270003"] = {
                name = "Animated Guardian: Suppression Slam",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 270003,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 270003,
                },
                niniTrashClass = "targeted",
                niniEventType = "其他",
                niniTargetAPIExists = true,
            },
            ["270927"] = {
                name = "King Timalji: Bladestorm",
                enabled = true,
                preset = "p5",
                trigger = {
                    type = "exboss",
                    spellID = 270927,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 270927,
                },
                niniTrashClass = "targeted",
                niniEventType = "其他",
                niniTargetAPIExists = true,
            },
            ["272388"] = {
                name = "Shadow of Zul: Shadow Barrage",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 272388,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 272388,
                },
                niniTrashClass = "targeted",
                niniEventType = "其他",
                niniTargetAPIExists = true,
            },
            ["1296719"] = {
                name = "King Rahu'ai: Forked Lightning",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1296719,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1296719,
                },
                niniTrashClass = "targeted",
                niniEventType = "其他",
                niniTargetAPIExists = true,
            },
            ["1298304"] = {
                name = "Shadow of Zul: Dark Revelation",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1298304,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1298304,
                },
                niniTrashClass = "targeted",
                niniEventType = "点名",
                niniTargetAPIExists = false,
            },
            ["1305982"] = {
                name = "Queen Patlaa: Shadow Volley",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1305982,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1305982,
                },
                niniTrashClass = "targeted",
                niniEventType = "其他",
                niniTargetAPIExists = true,
            },
            ["1306049"] = {
                name = "King Timalji: Erupting Slam",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 1306049,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1306049,
                },
                niniTrashClass = "targeted",
                niniEventType = "点名",
                niniTargetAPIExists = true,
            },
            ["1309385"] = {
                name = "Shadow of Zul: Absorbed in Darkness + Erupting Darkness",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1309385,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1309385,
                },
                niniTrashClass = "targeted",
                niniEventType = "特殊",
                niniTargetAPIExists = true,
            },
            ["1217633"] = {
                name = "Massive Felwyrm: Corroding Spittle",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1217633,
                    mapID = 2813,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1217633,
                },
                niniTrashClass = "targeted",
                niniEventType = "治疗",
                niniTargetAPIExists = true,
            },
            ["1217973"] = {
                name = "Corrupted Warlock: Curse of Doom",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1217973,
                    mapID = 2813,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1217973,
                },
                niniTrashClass = "targeted",
                niniEventType = "治疗",
                niniTargetAPIExists = true,
            },
            ["1258537"] = {
                name = "Massive Felwyrm: Massive Fel Detonation",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1258537,
                    mapID = 2813,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1258537,
                },
                niniTrashClass = "targeted",
                niniEventType = "特殊",
                niniTargetAPIExists = true,
            },
            ["1297682"] = {
                name = "Corrupted Warlock: Drain Life",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1297682,
                    mapID = 2813,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1297682,
                },
                niniTrashClass = "targeted",
                niniEventType = "点名",
                niniTargetAPIExists = true,
            },
            ["372047"] = {
                name = "Defier Draghar: Molten Steel + Steel Barrage",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 372047,
                    mapID = 2521,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 372047,
                },
                niniTrashClass = "targeted",
                niniEventType = "坦克",
                niniTargetAPIExists = true,
            },
            ["391723"] = {
                name = "Flamegullet: Flame Breath",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 391723,
                    mapID = 2521,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 391723,
                },
                niniTrashClass = "targeted",
                niniEventType = "其他",
                niniTargetAPIExists = true,
            },
            ["392640"] = {
                name = "Thunderhead: Electrical Discharge",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 392640,
                    mapID = 2521,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 392640,
                },
                niniTrashClass = "targeted",
                niniEventType = "点名",
                niniTargetAPIExists = false,
            },
            ["1306366"] = {
                name = "High Channeler Ryvati / Tempest Channeler: Lightning Torrent",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1306366,
                    mapID = 2521,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1306366,
                },
                niniTrashClass = "targeted",
                niniEventType = "点名",
                niniTargetAPIExists = nil,
            },
            ["1303443"] = {
                name = "Orb Watcher: Venom Shrapnel",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1303443,
                    mapID = 1877,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1303443,
                },
                niniTrashClass = "targeted",
                niniEventType = "坦克",
                niniTargetAPIExists = true,
            },
            ["1237855"] = {
                name = "Virid Grovekeeper: Ruptured Earth",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1237855,
                    mapID = 2859,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1237855,
                },
                niniTrashClass = "targeted",
                niniEventType = "坦克",
                niniTargetAPIExists = true,
            },
            ["1238368"] = {
                name = "Overgrown Hydra: Lightmaw Beams",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1238368,
                    mapID = 2859,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1238368,
                },
                niniTrashClass = "targeted",
                niniEventType = "点名",
                niniTargetAPIExists = false,
            },
            ["1239856"] = {
                name = "Watchful Harrower: Sky Strike",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1239856,
                    mapID = 2923,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1239856,
                },
                niniTrashClass = "targeted",
                niniEventType = "治疗",
                niniTargetAPIExists = true,
            },
            ["1299913"] = {
                name = "Voidtouched Magi: Null Eruption",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1299913,
                    mapID = 2923,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1299913,
                },
                niniTrashClass = "targeted",
                niniEventType = "点名",
                niniTargetAPIExists = true,
            },
            ["1300138"] = {
                name = "Watchful Harrower: Void Beam",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1300138,
                    mapID = 2923,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1300138,
                },
                niniTrashClass = "targeted",
                niniEventType = "点名",
                niniTargetAPIExists = true,
            },
            ["1310309"] = {
                name = "Brutal Overseer: Macestorm",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 1310309,
                    mapID = 2923,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1310309,
                },
                niniTrashClass = "targeted",
                niniEventType = "点名",
                niniTargetAPIExists = false,
            },
        },
    },
    niniDeferredTrashRules = {
        ["259"] = {
            ["1309947"] = {
                name = "The Winter Squall: Harsh Winter",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1309947,
                    mapID = 2825,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1309947,
                },
                niniTrashClass = "deferred",
                niniEventType = "其他",
                niniTargetAPIExists = nil,
            },
            ["269972"] = {
                name = "Risen Hexer: Hex Volley",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 269972,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 269972,
                },
                niniTrashClass = "deferred",
                niniEventType = "其他",
                niniTargetAPIExists = nil,
            },
            ["1294815"] = {
                name = "Risen Hexer: Shadowfrost Bolt",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1294815,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1294815,
                },
                niniTrashClass = "deferred",
                niniEventType = "其他",
                niniTargetAPIExists = nil,
            },
            ["1216954"] = {
                name = "Felmaster Lucsei: Eye Beam",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 1216954,
                    mapID = 2813,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1216954,
                },
                niniTrashClass = "deferred",
                niniEventType = "其他",
                niniTargetAPIExists = nil,
            },
            ["1294770"] = {
                name = "Shivan Punisher: Demonic Frenzy",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1294770,
                    mapID = 2813,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1294770,
                },
                niniTrashClass = "deferred",
                niniEventType = "其他",
                niniTargetAPIExists = nil,
            },
            ["1294824"] = {
                name = "Defiled Golem: Defiled Detonation + Defiled Slam",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1294824,
                    mapID = 2813,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1294824,
                },
                niniTrashClass = "deferred",
                niniEventType = "治疗",
                niniTargetAPIExists = nil,
            },
            ["1302007"] = {
                name = "Felmaster Lucsei: Blade Dance",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1302007,
                    mapID = 2813,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1302007,
                },
                niniTrashClass = "deferred",
                niniEventType = "治疗",
                niniTargetAPIExists = nil,
            },
            ["373017"] = {
                name = "Blazebound Firestorm: Blaze Volley",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 373017,
                    mapID = 2521,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 373017,
                },
                niniTrashClass = "deferred",
                niniEventType = "其他",
                niniTargetAPIExists = nil,
            },
            ["373087"] = {
                name = "Blazebound Firestorm: Burnout",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 373087,
                    mapID = 2521,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 373087,
                },
                niniTrashClass = "deferred",
                niniEventType = "其他",
                niniTargetAPIExists = nil,
            },
            ["1310363"] = {
                name = "High Channeler Ryvati: Tempest Stormshield",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1310363,
                    mapID = 2521,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1310363,
                },
                niniTrashClass = "deferred",
                niniEventType = "其他",
                niniTargetAPIExists = nil,
            },
            ["1308113"] = {
                name = "Sandswept Hunter: Arrow Barrage + Sandburst Arrow",
                enabled = true,
                preset = "p5",
                trigger = {
                    type = "exboss",
                    spellID = 1308113,
                    mapID = 1877,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1308113,
                },
                niniTrashClass = "deferred",
                niniEventType = "特殊",
                niniTargetAPIExists = nil,
            },
            ["1263636"] = {
                name = "Sporeblight Belcher: Spouting Floret",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1263636,
                    mapID = 2859,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1263636,
                },
                niniTrashClass = "deferred",
                niniEventType = "其他",
                niniTargetAPIExists = nil,
            },
            ["1271385"] = {
                name = "Sporeblight Belcher: Belch Spores",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1271385,
                    mapID = 2859,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1271385,
                },
                niniTrashClass = "deferred",
                niniEventType = "治疗",
                niniTargetAPIExists = nil,
            },
        },
        ["260"] = {
            ["1309947"] = {
                name = "The Winter Squall: Harsh Winter",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1309947,
                    mapID = 2825,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1309947,
                },
                niniTrashClass = "deferred",
                niniEventType = "其他",
                niniTargetAPIExists = nil,
            },
            ["269972"] = {
                name = "Risen Hexer: Hex Volley",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 269972,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 269972,
                },
                niniTrashClass = "deferred",
                niniEventType = "其他",
                niniTargetAPIExists = nil,
            },
            ["1294815"] = {
                name = "Risen Hexer: Shadowfrost Bolt",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1294815,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1294815,
                },
                niniTrashClass = "deferred",
                niniEventType = "其他",
                niniTargetAPIExists = nil,
            },
            ["1216954"] = {
                name = "Felmaster Lucsei: Eye Beam",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 1216954,
                    mapID = 2813,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1216954,
                },
                niniTrashClass = "deferred",
                niniEventType = "其他",
                niniTargetAPIExists = nil,
            },
            ["1294770"] = {
                name = "Shivan Punisher: Demonic Frenzy",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1294770,
                    mapID = 2813,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1294770,
                },
                niniTrashClass = "deferred",
                niniEventType = "其他",
                niniTargetAPIExists = nil,
            },
            ["1294824"] = {
                name = "Defiled Golem: Defiled Detonation + Defiled Slam",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1294824,
                    mapID = 2813,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1294824,
                },
                niniTrashClass = "deferred",
                niniEventType = "治疗",
                niniTargetAPIExists = nil,
            },
            ["1302007"] = {
                name = "Felmaster Lucsei: Blade Dance",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1302007,
                    mapID = 2813,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1302007,
                },
                niniTrashClass = "deferred",
                niniEventType = "治疗",
                niniTargetAPIExists = nil,
            },
            ["373017"] = {
                name = "Blazebound Firestorm: Blaze Volley",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 373017,
                    mapID = 2521,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 373017,
                },
                niniTrashClass = "deferred",
                niniEventType = "其他",
                niniTargetAPIExists = nil,
            },
            ["373087"] = {
                name = "Blazebound Firestorm: Burnout",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 373087,
                    mapID = 2521,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 373087,
                },
                niniTrashClass = "deferred",
                niniEventType = "其他",
                niniTargetAPIExists = nil,
            },
            ["1310363"] = {
                name = "High Channeler Ryvati: Tempest Stormshield",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1310363,
                    mapID = 2521,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1310363,
                },
                niniTrashClass = "deferred",
                niniEventType = "其他",
                niniTargetAPIExists = nil,
            },
            ["1308113"] = {
                name = "Sandswept Hunter: Arrow Barrage + Sandburst Arrow",
                enabled = true,
                preset = "p5",
                trigger = {
                    type = "exboss",
                    spellID = 1308113,
                    mapID = 1877,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1308113,
                },
                niniTrashClass = "deferred",
                niniEventType = "特殊",
                niniTargetAPIExists = nil,
            },
            ["1263636"] = {
                name = "Sporeblight Belcher: Spouting Floret",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1263636,
                    mapID = 2859,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1263636,
                },
                niniTrashClass = "deferred",
                niniEventType = "其他",
                niniTargetAPIExists = nil,
            },
            ["1271385"] = {
                name = "Sporeblight Belcher: Belch Spores",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1271385,
                    mapID = 2859,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1271385,
                },
                niniTrashClass = "deferred",
                niniEventType = "治疗",
                niniTargetAPIExists = nil,
            },
        },
        ["261"] = {
            ["1309947"] = {
                name = "The Winter Squall: Harsh Winter",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1309947,
                    mapID = 2825,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1309947,
                },
                niniTrashClass = "deferred",
                niniEventType = "其他",
                niniTargetAPIExists = nil,
            },
            ["269972"] = {
                name = "Risen Hexer: Hex Volley",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 269972,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 269972,
                },
                niniTrashClass = "deferred",
                niniEventType = "其他",
                niniTargetAPIExists = nil,
            },
            ["1294815"] = {
                name = "Risen Hexer: Shadowfrost Bolt",
                enabled = true,
                preset = "p2",
                trigger = {
                    type = "exboss",
                    spellID = 1294815,
                    mapID = 1762,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1294815,
                },
                niniTrashClass = "deferred",
                niniEventType = "其他",
                niniTargetAPIExists = nil,
            },
            ["1216954"] = {
                name = "Felmaster Lucsei: Eye Beam",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 1216954,
                    mapID = 2813,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1216954,
                },
                niniTrashClass = "deferred",
                niniEventType = "其他",
                niniTargetAPIExists = nil,
            },
            ["1294770"] = {
                name = "Shivan Punisher: Demonic Frenzy",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1294770,
                    mapID = 2813,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1294770,
                },
                niniTrashClass = "deferred",
                niniEventType = "其他",
                niniTargetAPIExists = nil,
            },
            ["1294824"] = {
                name = "Defiled Golem: Defiled Detonation + Defiled Slam",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1294824,
                    mapID = 2813,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1294824,
                },
                niniTrashClass = "deferred",
                niniEventType = "治疗",
                niniTargetAPIExists = nil,
            },
            ["1302007"] = {
                name = "Felmaster Lucsei: Blade Dance",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1302007,
                    mapID = 2813,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1302007,
                },
                niniTrashClass = "deferred",
                niniEventType = "治疗",
                niniTargetAPIExists = nil,
            },
            ["373017"] = {
                name = "Blazebound Firestorm: Blaze Volley",
                enabled = true,
                preset = "p1",
                trigger = {
                    type = "exboss",
                    spellID = 373017,
                    mapID = 2521,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 373017,
                },
                niniTrashClass = "deferred",
                niniEventType = "其他",
                niniTargetAPIExists = nil,
            },
            ["373087"] = {
                name = "Blazebound Firestorm: Burnout",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 373087,
                    mapID = 2521,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 373087,
                },
                niniTrashClass = "deferred",
                niniEventType = "其他",
                niniTargetAPIExists = nil,
            },
            ["1310363"] = {
                name = "High Channeler Ryvati: Tempest Stormshield",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1310363,
                    mapID = 2521,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1310363,
                },
                niniTrashClass = "deferred",
                niniEventType = "其他",
                niniTargetAPIExists = nil,
            },
            ["1308113"] = {
                name = "Sandswept Hunter: Arrow Barrage + Sandburst Arrow",
                enabled = true,
                preset = "p5",
                trigger = {
                    type = "exboss",
                    spellID = 1308113,
                    mapID = 1877,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1308113,
                },
                niniTrashClass = "deferred",
                niniEventType = "特殊",
                niniTargetAPIExists = nil,
            },
            ["1263636"] = {
                name = "Sporeblight Belcher: Spouting Floret",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1263636,
                    mapID = 2859,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1263636,
                },
                niniTrashClass = "deferred",
                niniEventType = "其他",
                niniTargetAPIExists = nil,
            },
            ["1271385"] = {
                name = "Sporeblight Belcher: Belch Spores",
                enabled = true,
                preset = "p4",
                trigger = {
                    type = "exboss",
                    spellID = 1271385,
                    mapID = 2859,
                    timeleft = 0.8,
                },
                display = {
                    type = "icon",
                    text = "",
                    dur = 3,
                    sound = "none",
                    tts = true,
                    spellID = 1271385,
                },
                niniTrashClass = "deferred",
                niniEventType = "治疗",
                niniTargetAPIExists = nil,
            },
        },
    },
    abilityBindings = {
        ["259"] = {
            ["3456"] = {
                [1296050] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1296069] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1296220] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1307573] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1307894] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
            },
            ["3457"] = {
                [1299053] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1299080] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1299130] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1300083] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1310547] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                    leadTime = 0.8,
                },
                [1310974] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                    leadTime = 0.8,
                },
            },
            ["3458"] = {
                [1300876] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1300886] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
            },
            ["3207"] = {
                [1234681] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1235118] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
            },
            ["3208"] = {
                [1235548] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1235623] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1235656] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
            },
            ["3209"] = {
                [1242860] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1242887] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1243569] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1262253] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1297793] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
            },
            ["2139"] = {
                [265773] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [265781] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1311988] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1312104] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
            },
            ["2140"] = {
                [266951] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [267494] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1305810] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1310761] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
            },
            ["2142"] = {
                [267618] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [267639] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1311956] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1312146] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
            },
            ["2143"] = {
                [269230] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [269369] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1302945] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1303115] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1303267] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1303327] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1303374] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
            },
            ["3102"] = {
                [474478] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [474483] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [474765] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [474768] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1214355] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1214357] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1217099] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1219631] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
            },
            ["3103"] = {
                [474197] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1214637] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1214650] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1214663] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1295453] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1295455] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
            },
            ["3105"] = {
                [474457] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1217384] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1218203] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1224478] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
            },
            ["2606"] = {
                [372863] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [372864] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
            },
            ["2609"] = {
                [372851] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [373680] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [373686] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [373688] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [383925] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [384024] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [396044] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [397077] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1307297] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1307308] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
            },
            ["2623"] = {
                [381516] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [381517] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [381518] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [381525] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [381862] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [381864] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
            },
            ["2124"] = {
                [1288049] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1288092] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1288457] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1289059] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1310712] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1311805] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1311808] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1314051] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
            },
            ["2125"] = {
                [1289109] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1291734] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1293048] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1297034] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                    leadTime = 0.8,
                },
                [1298329] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
            },
            ["2126"] = {
                [266512] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1290531] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1309525] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
            },
            ["3199"] = {
                [1235640] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p6",
                },
                [1235642] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1235865] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p3",
                },
            },
            ["3200"] = {
                [1236709] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1236731] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1236746] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
            },
            ["3201"] = {
                [1239824] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                    leadTime = 0.8,
                },
                [1239825] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                    leadTime = 0.8,
                },
                [1239919] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1240098] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                    leadTime = 0.8,
                },
                [1240152] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                    leadTime = 0.8,
                },
                [1240210] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1240257] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1241058] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
            },
            ["3202"] = {
                [1246753] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1247052] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
            },
            ["3285"] = {
                [1222098] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1222103] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1296963] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1296967] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1300259] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
            },
            ["3286"] = {
                [1226120] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1262497] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1300351] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
            },
            ["3287"] = {
                [1227264] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1263982] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                    leadTime = 0.8,
                },
                [1264188] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                    leadTime = 0.8,
                },
                [1282770] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                    leadTime = 0.8,
                },
                [1287450] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                    leadTime = 0.8,
                },
                [1300372] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
            },
        },
        ["260"] = {
            ["3456"] = {
                [1296050] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1296069] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1296220] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1307573] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1307894] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
            },
            ["3457"] = {
                [1299053] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1299080] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1299130] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1300083] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1310547] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                    leadTime = 0.8,
                },
                [1310974] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                    leadTime = 0.8,
                },
            },
            ["3458"] = {
                [1300876] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1300886] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
            },
            ["3207"] = {
                [1234681] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1235118] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
            },
            ["3208"] = {
                [1235548] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1235623] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1235656] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
            },
            ["3209"] = {
                [1242860] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1242887] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1243569] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1262253] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1297793] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
            },
            ["2139"] = {
                [265773] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [265781] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1311988] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1312104] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
            },
            ["2140"] = {
                [266951] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [267494] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1305810] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1310761] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
            },
            ["2142"] = {
                [267618] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [267639] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1311956] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1312146] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
            },
            ["2143"] = {
                [269230] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [269369] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1302945] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1303115] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1303267] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1303327] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1303374] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
            },
            ["3102"] = {
                [474478] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [474483] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [474765] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [474768] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1214355] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1214357] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1217099] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1219631] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
            },
            ["3103"] = {
                [474197] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1214637] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1214650] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1214663] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1295453] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1295455] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
            },
            ["3105"] = {
                [474457] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1217384] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1218203] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1224478] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
            },
            ["2606"] = {
                [372863] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [372864] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
            },
            ["2609"] = {
                [372851] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [373680] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [373686] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [373688] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [383925] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [384024] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [396044] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [397077] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1307297] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1307308] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
            },
            ["2623"] = {
                [381516] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [381517] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [381518] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [381525] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [381862] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [381864] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
            },
            ["2124"] = {
                [1288049] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1288092] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1288457] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1289059] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1310712] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1311805] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1311808] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1314051] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
            },
            ["2125"] = {
                [1289109] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1291734] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1293048] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1297034] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                    leadTime = 0.8,
                },
                [1298329] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
            },
            ["2126"] = {
                [266512] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1290531] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1309525] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
            },
            ["3199"] = {
                [1235640] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p6",
                },
                [1235642] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1235865] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p3",
                },
            },
            ["3200"] = {
                [1236709] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1236731] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1236746] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
            },
            ["3201"] = {
                [1239824] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                    leadTime = 0.8,
                },
                [1239825] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                    leadTime = 0.8,
                },
                [1239919] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1240098] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                    leadTime = 0.8,
                },
                [1240152] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                    leadTime = 0.8,
                },
                [1240210] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1240257] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1241058] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
            },
            ["3202"] = {
                [1246753] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1247052] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
            },
            ["3285"] = {
                [1222098] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1222103] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1296963] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1296967] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1300259] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
            },
            ["3286"] = {
                [1226120] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1262497] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1300351] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
            },
            ["3287"] = {
                [1227264] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1263982] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                    leadTime = 0.8,
                },
                [1264188] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                    leadTime = 0.8,
                },
                [1282770] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                    leadTime = 0.8,
                },
                [1287450] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                    leadTime = 0.8,
                },
                [1300372] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
            },
        },
        ["261"] = {
            ["3456"] = {
                [1296050] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1296069] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1296220] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1307573] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1307894] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
            },
            ["3457"] = {
                [1299053] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1299080] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1299130] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1300083] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1310547] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                    leadTime = 0.8,
                },
                [1310974] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                    leadTime = 0.8,
                },
            },
            ["3458"] = {
                [1300876] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1300886] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
            },
            ["3207"] = {
                [1234681] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1235118] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
            },
            ["3208"] = {
                [1235548] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1235623] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1235656] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
            },
            ["3209"] = {
                [1242860] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1242887] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1243569] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1262253] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1297793] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
            },
            ["2139"] = {
                [265773] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [265781] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1311988] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1312104] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
            },
            ["2140"] = {
                [266951] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [267494] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1305810] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1310761] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
            },
            ["2142"] = {
                [267618] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [267639] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1311956] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1312146] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
            },
            ["2143"] = {
                [269230] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [269369] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1302945] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1303115] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1303267] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1303327] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1303374] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
            },
            ["3102"] = {
                [474478] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [474483] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [474765] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [474768] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1214355] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1214357] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1217099] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1219631] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
            },
            ["3103"] = {
                [474197] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1214637] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1214650] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1214663] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1295453] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1295455] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
            },
            ["3105"] = {
                [474457] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1217384] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1218203] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1224478] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
            },
            ["2606"] = {
                [372863] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [372864] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
            },
            ["2609"] = {
                [372851] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [373680] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [373686] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [373688] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [383925] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [384024] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [396044] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [397077] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1307297] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1307308] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
            },
            ["2623"] = {
                [381516] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [381517] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [381518] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [381525] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [381862] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [381864] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
            },
            ["2124"] = {
                [1288049] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1288092] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1288457] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1289059] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1310712] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1311805] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1311808] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1314051] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
            },
            ["2125"] = {
                [1289109] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1291734] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1293048] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1297034] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                    leadTime = 0.8,
                },
                [1298329] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
            },
            ["2126"] = {
                [266512] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1290531] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1309525] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
            },
            ["3199"] = {
                [1235640] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p6",
                },
                [1235642] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1235865] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p3",
                },
            },
            ["3200"] = {
                [1236709] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1236731] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1236746] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
            },
            ["3201"] = {
                [1239824] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                    leadTime = 0.8,
                },
                [1239825] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                    leadTime = 0.8,
                },
                [1239919] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1240098] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                    leadTime = 0.8,
                },
                [1240152] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                    leadTime = 0.8,
                },
                [1240210] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1240257] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1241058] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
            },
            ["3202"] = {
                [1246753] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1247052] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
            },
            ["3285"] = {
                [1222098] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1222103] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1296963] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1296967] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                },
                [1300259] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
            },
            ["3286"] = {
                [1226120] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1262497] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
                [1300351] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p1",
                },
            },
            ["3287"] = {
                [1227264] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
                [1263982] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                    leadTime = 0.8,
                },
                [1264188] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                    leadTime = 0.8,
                },
                [1282770] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                    leadTime = 0.8,
                },
                [1287450] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p2",
                    leadTime = 0.8,
                },
                [1300372] = {
                    enabled = true,
                    mode = "defensive",
                    preset = "p4",
                },
            },
        },
    },
    bindingsBySpec = true,
    niniProfileVersion = "0.1.10-reaction-08",
    niniTrashPolicyVersion = 7,
    niniBossPolicyVersion = 2,
    niniProfileNote = "Rogue defensive profile from Ninjarobot MIDnight S2. v0.1.10 uses a 0.8s reaction window for boss and predictive-trash reminders, including former cloak-miss exceptions. Trash keeps secret-safe target visuals and per-cast dedupe; Boss keeps the Sentinel of Winter primary-timeline-key timing fix.",
}


local function DeepCopy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, inner in pairs(v) do out[k] = DeepCopy(inner) end
    return out
end

local function CurrentSpecID()
    if type(GetSpecialization) ~= "function" or type(GetSpecializationInfo) ~= "function" then return 0 end
    local idx = GetSpecialization()
    if not idx then return 0 end
    return tonumber((GetSpecializationInfo(idx))) or 0
end

local function CurrentClass()
    local _, classFile = UnitClass("player")
    return classFile or "UNKNOWN"
end

local function IsRogueSpec(specID)
    return specID == 259 or specID == 260 or specID == 261
end

local function RegisterSonar()
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if not LSM or type(LSM.Register) ~= "function" then return false end
    local ok = pcall(LSM.Register, LSM, "sound", SONAR_KEY, SONAR_PATH)
    if not ok then return false end
    if type(LSM.Fetch) == "function" then
        local fetched, path = pcall(LSM.Fetch, LSM, "sound", SONAR_KEY, true)
        if fetched and path then return true end
    end
    return false
end

local function PlayBundledSonar()
    if type(PlaySoundFile) ~= "function" then return false end
    local ok, played = pcall(PlaySoundFile, SONAR_PATH, "Master")
    return ok and played ~= false
end

local function NSR()
    local ns = _G.NaowhUITankReminder
    if type(ns) ~= "table" or type(ns.EnsureProfile) ~= "function" then return nil end
    return ns
end

local BASE_SETTING_KEYS = {
    "enabled", "showIcon", "showText", "showBar", "soundOn", "soundKey", "fallbackOn",
    "coveredSkip", "leadTime", "lingerSec", "voiceOn", "voiceVol", "bossSource",
}

local function SeedSettings(root, source)
    for _, key in ipairs(BASE_SETTING_KEYS) do
        if root[key] == nil and source[key] ~= nil then root[key] = DeepCopy(source[key]) end
    end
end

local function ManagedReplace(root, source, keys)
    for _, key in ipairs(keys) do root[key] = DeepCopy(source[key]) end
end

local ROGUE_MANAGED = {
    "presets", "activePreset", "integrationRules", "niniTargetRules",
    "niniDeferredTrashRules", "bindingsBySpec",
}

-- NiniTools owns the M+ baseline, but Raid Bosses -> Add Ability writes into the
-- same abilityBindings table.  Do not wipe user-authored rows on login/reload.
-- Managed rows win when keys collide; unknown/user-added rows are preserved.
local function MergeAbilityBindingsPreservingExtras(root, source)
    local existing = type(root.abilityBindings) == "table" and root.abilityBindings or {}
    local merged = DeepCopy((source and source.abilityBindings) or {})

    for specKey, encounters in pairs(existing) do
        if type(encounters) == "table" then
            if type(merged[specKey]) ~= "table" then merged[specKey] = {} end
            for encKey, abilities in pairs(encounters) do
                if type(abilities) == "table" then
                    if type(merged[specKey][encKey]) ~= "table" then merged[specKey][encKey] = {} end
                    for sid, binding in pairs(abilities) do
                        if merged[specKey][encKey][sid] == nil then
                            merged[specKey][encKey][sid] = DeepCopy(binding)
                        end
                    end
                end
            end
        end
    end

    root.abilityBindings = merged
end


local function SeedRaidProfileOnce(root)
    if type(root) ~= "table" then return end
    local current = tonumber(root.niniRaidProfileSeedVersion) or 0
    if current >= ROGUE_RAID_PROFILE_SEED_VERSION then return end

    if type(root.abilityBindings) ~= "table" then root.abilityBindings = {} end
    if type(root.bossPreset) ~= "table" then root.bossPreset = {} end

    for _, specID in ipairs({259, 260, 261}) do
        local specKey = tostring(specID)
        if type(root.abilityBindings[specKey]) ~= "table" then root.abilityBindings[specKey] = {} end
        for encID, abilities in pairs(ROGUE_RAID_PROFILE_DEFAULTS) do
            local encKey = tostring(encID)
            if type(root.abilityBindings[specKey][encKey]) ~= "table" then
                root.abilityBindings[specKey][encKey] = {}
            end
            for spellID, binding in pairs(abilities) do
                if root.abilityBindings[specKey][encKey][spellID] == nil then
                    root.abilityBindings[specKey][encKey][spellID] = DeepCopy(binding)
                end
            end
            local bossKey = specKey .. ":" .. encKey
            if root.bossPreset[bossKey] == nil then root.bossPreset[bossKey] = "p1" end
        end
    end

    root.niniRaidProfileSeedVersion = ROGUE_RAID_PROFILE_SEED_VERSION
end

local function InstallRogueProfile()
    local ns = NSR(); if not ns then return false end
    local root = ns.EnsureProfile(ROGUE_PROFILE_NAME)
    SeedSettings(root, ROGUE_DATA)
    ManagedReplace(root, ROGUE_DATA, ROGUE_MANAGED)
    MergeAbilityBindingsPreservingExtras(root, ROGUE_DATA)
    SeedRaidProfileOnce(root)
    -- AoE18 Rogue callouts are fired from EXBoss's actual cast-start voice event instead
    -- of its predictive timer. Keeping these rows would produce an early 0.8 s callout
    -- and then a second callout after EXBoss says "AOE".
    for specKey, rules in pairs(root.integrationRules or {}) do
        if type(rules) == "table" then
            for uid, rule in pairs(rules) do
                local sid = tonumber(type(rule) == "table" and rule.trigger and rule.trigger.spellID or nil)
                if sid and AOE_ROGUE_PRESET[sid] then rules[uid] = nil end
            end
        end
    end
    root.niniProfileVersion = PROFILE_VERSION
    root.niniProfileMode = "rogue"
    root.niniProfileNote = "NiniTools managed Rogue M+ S2 + Raid S2 Safe Alpha profile. Raid defaults are seeded once; later manual Raid Bosses selections are preserved. Nek'zali Invoke is seeded to Cloak of Shadows; no automatic Evasion raid bindings are seeded."
    return true
end

local function BuildGenericBossReminders()
    local out = {}
    local src = ROGUE_DATA.abilityBindings and ROGUE_DATA.abilityBindings["259"] or {}
    for enc, abilities in pairs(src) do
        local dst = {}
        for sid, binding in pairs(abilities) do
            if type(binding) == "table" and binding.enabled ~= false then
                local spellID = tonumber(sid)
                if spellID then
                    local lead = tonumber(binding.leadTime) or 0.8
                    dst["nini_generic_" .. tostring(spellID)] = {
                        name = "Nini Defensive " .. tostring(spellID),
                        enabled = true,
                        trigger = { type = "bwtimer", spellID = spellID, leadTime = lead },
                        target = { all = true },
                        display = {
                            type = "icon",
                            text = "생존기",
                            spellID = spellID,
                            color = { r = 1, g = 0.82, b = 0.20, a = 1 },
                            dur = 3,
                            sound = SONAR_KEY,
                            tts = false,
                        },
                        abilitySpellID = spellID,
                    }
                end
            end
        end
        out[tostring(enc)] = dst
    end
    return out
end

local function EnsureGenericSpec(specID)
    local ns = NSR(); if not ns or not specID or specID == 0 then return false end
    local root = ns.EnsureProfile(GENERIC_PROFILE_NAME)
    -- Generic uses Naowh's authored icon reminders for bosses and integration text+sound for trash.
    local genericDefaults = {
        enabled = true, showIcon = true, showText = true, showBar = false,
        soundOn = false, soundKey = "none", fallbackOn = false, coveredSkip = false,
        leadTime = 0.8, lingerSec = 3, voiceOn = false, voiceVol = 100, bossSource = "bigwigs",
    }
    SeedSettings(root, genericDefaults)

    local specKey = tostring(specID)
    root.integrationRules = type(root.integrationRules) == "table" and root.integrationRules or {}
    root.niniTargetRules = type(root.niniTargetRules) == "table" and root.niniTargetRules or {}
    root.niniDeferredTrashRules = type(root.niniDeferredTrashRules) == "table" and root.niniDeferredTrashRules or {}

    -- Trash is now event-driven: EXBoss users already get its mechanic voice, while
    -- EXBoss-absent users are handled by NiniTools' 18-AoE fallback detector.  Do not
    -- stamp the old Rogue predictive rules into non-Rogue profiles or they would create
    -- duplicate Sonar callouts whenever EXBoss is installed.
    root.integrationRules[specKey] = {}
    root.niniTargetRules[specKey] = {}
    root.niniDeferredTrashRules[specKey] = {}

    -- Make sure a generic spec never inherits stale defensive lists/bindings from an older beta.
    if type(root.presets) == "table" then root.presets[specKey] = nil end
    if type(root.activePreset) == "table" then root.activePreset[specKey] = nil end
    if type(root.abilityBindings) == "table" then root.abilityBindings[specKey] = nil end

    root.raidReminders = BuildGenericBossReminders()
    root.niniProfileVersion = PROFILE_VERSION
    root.niniProfileMode = "generic"
    root.niniProfileNote = "NiniTools generic M+ output profile. Trash AoE Sonar is supplied by the NiniTools fallback bridge only when EXBoss is absent."
    return true
end

local function IsEXBossLoaded()
    if type(_G.ExBoss) == "table" then return true end
    if C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function" then
        local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, "EXBoss")
        if ok and loaded == true then return true end
    end
    return false
end

local function ApplyProfileForCurrentSpec(forceSwitch)
    local ns = NSR(); if not ns then return false end
    local specID = CurrentSpecID()
    if specID == 0 then return false end

    InstallRogueProfile()
    if type(ns.SetSpecProfile) == "function" then
        ns.SetSpecProfile(259, ROGUE_PROFILE_NAME)
        ns.SetSpecProfile(260, ROGUE_PROFILE_NAME)
        ns.SetSpecProfile(261, ROGUE_PROFILE_NAME)
    end

    local wanted
    if IsRogueSpec(specID) then
        wanted = ROGUE_PROFILE_NAME
    else
        EnsureGenericSpec(specID)
        wanted = GENERIC_PROFILE_NAME
        if type(ns.SetSpecProfile) == "function" then ns.SetSpecProfile(specID, GENERIC_PROFILE_NAME) end
    end

    if type(ns.AutoSpecProfile) == "function" then ns.AutoSpecProfile(true) end
    local active = type(ns.ActiveProfileName) == "function" and ns.ActiveProfileName() or nil
    if (forceSwitch or active ~= wanted) and type(ns.SwitchProfile) == "function" then ns.SwitchProfile(wanted) end
    if type(ns.RefreshRuntime) == "function" then pcall(ns.RefreshRuntime) end

    local exboss = IsEXBossLoaded()
    local mode
    if IsRogueSpec(specID) then
        mode = exboss and "도적 EXBoss AOE → 생존기 TTS" or "도적 AoE18 fallback → Sonar"
    else
        mode = exboss and "타직업 EXBoss 음성" or "타직업 AoE18 fallback → Sonar"
    end
    statusText = string.format("연결됨 · %s · 프로필 %s", mode, wanted)
    return true
end

local function CurrentInstanceID()
    if type(GetInstanceInfo) ~= "function" then return nil end
    local _, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()
    if instanceType ~= "party" then return nil end
    return tonumber(instanceID)
end

local function ActiveNiniRoot()
    local ns = NSR(); if not ns or type(ns.ActiveProfileName) ~= "function" or type(ns.ProfileSettings) ~= "function" then return nil end
    local name = ns.ActiveProfileName()
    if name ~= ROGUE_PROFILE_NAME and name ~= GENERIC_PROFILE_NAME then return nil end
    local root = ns.ProfileSettings(name)
    if type(root) ~= "table" or root.enabled ~= true then return nil end
    return root, name
end

local function TargetRule(spellID)
    local root = ActiveNiniRoot()
    if not root then return nil end
    local specKey = tostring(CurrentSpecID())
    local bySpec = root.niniTargetRules and root.niniTargetRules[specKey]
    return type(bySpec) == "table" and bySpec[tostring(tonumber(spellID) or 0)] or nil
end

local function ObservedCastKey(info, sid)
    local runtime = type(info) == "table" and info.runtime or nil
    local runtimeKey = tostring(type(info) == "table" and info.runtimeKey or runtime or "?")
    local seq = type(runtime) == "table" and tonumber(runtime.activeCastSeq) or nil
    if seq then return runtimeKey .. ":seq:" .. tostring(seq) .. ":spell:" .. tostring(sid) end
    local startedAt = tonumber(type(info) == "table" and info.startedAt or nil) or 0
    if startedAt > 0 then return runtimeKey .. ":start:" .. string.format("%.3f", startedAt) .. ":spell:" .. tostring(sid) end
    local castBarID = tostring(type(info) == "table" and info.castBarID or "")
    if castBarID ~= "" then return runtimeKey .. ":bar:" .. castBarID .. ":spell:" .. tostring(sid) end
    return runtimeKey .. ":bucket:" .. tostring(math.floor(GetTime() * 2)) .. ":spell:" .. tostring(sid)
end

local function FirstObservedEventForCast(info, sid)
    local now = GetTime()
    for key, at in pairs(targetCastSeen) do if now - at > 20 then targetCastSeen[key] = nil end end
    local key = ObservedCastKey(info, sid)
    if targetCastSeen[key] then return false end
    targetCastSeen[key] = now
    return true
end

local function SecretPlayerIsSpellTarget(unit)
    local fn = _G.PlayerIsSpellTarget
    if type(fn) ~= "function" or type(unit) ~= "string" or unit == "" then return nil end
    local ok, value = pcall(fn, unit)
    if not ok then return nil end
    return value
end

local function CreateTargetVisual(index)
    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetSize(62, 62)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:EnableMouse(false)
    local x = (index - 1) * 72 - 180
    f:SetPoint("CENTER", UIParent, "CENTER", x, -145)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
    f:SetBackdropColor(0.02, 0.02, 0.02, 0.92)
    f:SetBackdropBorderColor(0.35, 1.0, 0.55, 0.95)
    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 4, -4); icon:SetPoint("BOTTOMRIGHT", -4, 4); icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.icon = icon
    local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    label:SetPoint("TOP", f, "BOTTOM", 0, -2); label:SetJustifyH("CENTER"); label:SetTextColor(0.6, 1.0, 0.7, 1)
    f.label = label
    local mechanic = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mechanic:SetPoint("TOP", label, "BOTTOM", 0, -1); mechanic:SetWidth(180); mechanic:SetJustifyH("CENTER"); mechanic:SetTextColor(0.82, 0.82, 0.82, 1)
    f.mechanic = mechanic
    f:Hide()
    return f
end

local function AcquireTargetVisual()
    for i = 1, 6 do
        local f = targetVisualPool[i]
        if not f then f = CreateTargetVisual(i); targetVisualPool[i] = f end
        if not f.niniBusy then
            f.niniBusy = true; targetVisualSerial = targetVisualSerial + 1; f.niniToken = targetVisualSerial
            return f
        end
    end
    local f = targetVisualPool[1]
    targetVisualSerial = targetVisualSerial + 1; f.niniBusy = true; f.niniToken = targetVisualSerial
    return f
end

local function ReleaseTargetVisual(f, token)
    if not f or f.niniToken ~= token then return end
    f.niniBusy = false; f:SetAlpha(0); f:Hide()
end

local function ResetBridgeRuntime()
    bridgeRuntimeToken = bridgeRuntimeToken + 1
    wipe(targetCastSeen)
    wipe(aoeCastSeen)
    for _, f in pairs(targetVisualPool) do
        if f then
            f.niniBusy = false
            f.niniToken = (tonumber(f.niniToken) or 0) + 1
            f:SetAlpha(0)
            f:Hide()
        end
    end
end

local function ResolveRogueTargetDefensive(rule)
    local ns = NSR()
    if not ns or type(ns.PresetList) ~= "function" or type(ns.PickFromList) ~= "function" then return nil end
    local presetKey = type(ns.IntegrationPreset) == "function" and ns.IntegrationPreset(rule) or rule.preset
    local list = ns.PresetList(CurrentSpecID(), presetKey)
    return ns.PickFromList(list)
end

local function ShowSecretTargetVisual(info, rule)
    local unit = tostring(info.unit or "")
    if unit == "" or not unit:match("^nameplate%d+$") then return end
    local gate = SecretPlayerIsSpellTarget(unit)
    if gate == nil then
        if targetDebug then print(string.format("|cffaaaaaa[NiniSR]|r secret target gate unavailable: %s (%d)", tostring(rule.name), tonumber(info.spellID) or 0)) end
        return
    end

    local root, activeName = ActiveNiniRoot()
    if not root then return end
    local isRogue = activeName == ROGUE_PROFILE_NAME and CurrentClass() == "ROGUE"
    local iconSpell, label
    if isRogue then
        local picked = ResolveRogueTargetDefensive(rule)
        if not picked then
            if targetDebug then print(string.format("|cffaaaaaa[NiniSR]|r target visual skipped; no ready defensive: %s (%d)", tostring(rule.name), tonumber(info.spellID) or 0)) end
            return
        end
        iconSpell = picked
        label = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(picked)) or tostring(picked)
    else
        iconSpell = tonumber(info.spellID) or tonumber(rule.trigger and rule.trigger.spellID)
        label = "생존기"
    end

    local f = AcquireTargetVisual()
    local token = f.niniToken
    local texture = iconSpell and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(iconSpell)
    f.icon:SetTexture(texture or 134400)
    f.label:SetText(label)
    f.mechanic:SetText(tostring(rule.name or ""))
    f:Show()
    if type(f.SetAlphaFromBoolean) == "function" then f:SetAlphaFromBoolean(gate, 1, 0) else f:SetAlpha(0) end

    local duration = tonumber(info.totalDuration) or 1.0
    duration = math.max(0.65, math.min(5.0, duration + 0.15))
    if targetDebug then
        print(string.format("|cffffff00[NiniSR]|r secret target visual armed: %s (%d) unit=%s -> %s", tostring(rule.name), tonumber(info.spellID) or 0, unit, tostring(label)))
    end
    C_Timer.After(duration, function() ReleaseTargetVisual(f, token) end)
end

function M:IsEXBossLoaded()
    return IsEXBossLoaded()
end

function M:DisplayFallbackSonar(spellID, instanceID)
    if IsEXBossLoaded() then return false end
    local ns = NSR(); if not ns or type(ns.DisplayIntegrationReminder) ~= "function" then return false end
    local root = ActiveNiniRoot(); if not root then return false end
    local sid = tonumber(spellID)
    local expectedMap = sid and AOE18[sid] or nil
    if not expectedMap or (instanceID and tonumber(instanceID) ~= expectedMap) then return false end
    local currentMap = CurrentInstanceID()
    if currentMap ~= expectedMap then return false end

    -- NiniTools ships Sonar.ogg itself. Prefer the SharedMedia key so Naowh Smart
    -- Reminders owns normal playback, but if SharedMedia is absent or the key could
    -- not be registered, play the bundled file directly instead of losing the alert.
    local sonarInLSM = RegisterSonar()
    local rule = {
        name = "Nini AoE fallback " .. tostring(sid),
        enabled = true,
        trigger = { type = "exboss", spellID = sid, mapID = expectedMap, timeleft = 0 },
        display = { type = "text", text = "생존기", dur = 3, sound = sonarInLSM and SONAR_KEY or "none", tts = false, spellID = sid },
    }
    ns.DisplayIntegrationReminder(rule, false)
    if not sonarInLSM then PlayBundledSonar() end
    return true
end

local function DisplayRogueAoEDefensive(spellID)
    if CurrentClass() ~= "ROGUE" or not IsRogueSpec(CurrentSpecID()) then return false end
    local preset = AOE_ROGUE_PRESET[tonumber(spellID)]
    if not preset then return false end
    local ns = NSR(); if not ns or type(ns.DisplayIntegrationReminder) ~= "function" then return false end
    local root, activeName = ActiveNiniRoot()
    if not root or activeName ~= ROGUE_PROFILE_NAME then return false end
    local sid = tonumber(spellID)
    local rule = {
        name = "Nini Rogue AoE " .. tostring(sid),
        enabled = true, preset = preset,
        trigger = { type = "exboss", spellID = sid, mapID = AOE18[sid] or 0, timeleft = 0 },
        display = { type = "icon", text = "", dur = 3, sound = "none", tts = true, spellID = sid },
    }
    ns.DisplayIntegrationReminder(rule, false)
    return true
end

local function FirstAoEObservedEventForCast(info, sid)
    local now = GetTime()
    for key, at in pairs(aoeCastSeen) do if now - at > 20 then aoeCastSeen[key] = nil end end
    local key = ObservedCastKey(info, sid)
    if aoeCastSeen[key] then return false end
    aoeCastSeen[key] = now
    return true
end

local function HandleVoiceTriggeredAoE(info, sid)
    local expectedMap = AOE18[sid]
    if not expectedMap or CurrentInstanceID() ~= expectedMap then return end
    if not FirstAoEObservedEventForCast(info, sid) then return end
    if not AOE_ROGUE_PRESET[sid] then return end
    -- EXBoss emits VOICE_EVENT only after its cast-start voice engine actually accepts
    -- the sound.  Waiting 0.65 s from this event makes the Rogue TTS follow the
    -- ~0.575 s Naowh "AOE" clip instead of overlapping it.
    local token = bridgeRuntimeToken
    C_Timer.After(AOE_DEFENSIVE_DELAY, function()
        if token ~= bridgeRuntimeToken then return end
        if CurrentInstanceID() ~= expectedMap or not IsEXBossLoaded() then return end
        DisplayRogueAoEDefensive(sid)
    end)
end

local function OnTrashVoiceTriggered(info)
    if type(info) ~= "table" then return end
    local sid = tonumber(info.spellID)
    if sid and AOE18[sid] then HandleVoiceTriggeredAoE(info, sid) end
end

local function OnTrashObservedCast(info)
    if type(info) ~= "table" then return end
    local sid = tonumber(info.spellID)
    local rule = sid and TargetRule(sid) or nil
    if not rule then return end
    local instanceID = CurrentInstanceID()
    if not instanceID or (rule.trigger.mapID ~= 0 and tonumber(rule.trigger.mapID) ~= instanceID) then return end
    if not FirstObservedEventForCast(info, sid) then return end
    ShowSecretTargetVisual(info, rule)
end

local function RegisterTargetBridge()
    if not (ExwindTools and type(ExwindTools.RegisterEvent) == "function") then return false end
    if type(ExwindTools.UnregisterEvent) == "function" then
        -- If the old standalone profile addon is still enabled, take ownership here so it
        -- cannot create a second copy of the same secret-target visual.
        pcall(ExwindTools.UnregisterEvent, ExwindTools, TARGET_EVENT, OLD_TARGET_OWNER)
        if targetBridgeRegistered then
            pcall(ExwindTools.UnregisterEvent, ExwindTools, TARGET_EVENT, TARGET_OWNER .. ".Cast")
            pcall(ExwindTools.UnregisterEvent, ExwindTools, VOICE_EVENT, TARGET_OWNER .. ".Voice")
        end
    end
    -- Observed cast-start is kept for the secret-safe personal-target visual.
    ExwindTools:RegisterEvent(TARGET_EVENT, TARGET_OWNER .. ".Cast", function(_, info) OnTrashObservedCast(info) end)
    -- Rogue AoE defensive TTS keys off the moment EXBoss actually starts its voice, not
    -- merely the observed cast, so "AOE -> defensive" remains serialized.
    ExwindTools:RegisterEvent(VOICE_EVENT, TARGET_OWNER .. ".Voice", function(_, info) OnTrashVoiceTriggered(info) end)
    targetBridgeRegistered = true
    return true
end

function M:Refresh(forceSwitch)
    RegisterSonar()
    if not NSR() then
        statusText = "Naowh Smart Reminders 미설치/비활성 · 생존기 알림 사용 불가"
        return false
    end
    local ok = ApplyProfileForCurrentSpec(forceSwitch ~= false)
    RegisterTargetBridge()
    return ok
end

function M:Reinstall()
    return self:Refresh(true)
end

function M:GetStatus()
    local A = NT.Adapters
    local owner, ownerDetail = "NiniTools 담당", "adapter unavailable"
    if A and type(A.DescribeNaowhReminderOwner)=="function" then
        owner, ownerDetail = A:DescribeNaowhReminderOwner()
    end
    local ns = NSR()
    if not ns then return string.format("%s · %s", tostring(owner), tostring(ownerDetail)) end
    local active = type(ns.ActiveProfileName) == "function" and ns.ActiveProfileName() or "?"
    local specID = CurrentSpecID()
    local exboss = IsEXBossLoaded()
    local mode
    if IsRogueSpec(specID) then
        mode = exboss and "도적: EXBoss AOE → 생존기 TTS" or "도적: AoE18 fallback → Sonar"
    else
        mode = exboss and "타직업: EXBoss 음성" or "타직업: AoE18 fallback → Sonar"
    end
    local old = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("NiniSmartRemindersProfile")) and " · 구형 Profile 애드온 감지" or ""
    return string.format("%s · %s · %s · %s%s", tostring(owner), tostring(ownerDetail), mode, tostring(active), old)
end

function M:OpenNaowh()
    local f = SlashCmdList and SlashCmdList.NAOWHUISMARTREM
    if type(f) == "function" then f(""); return true end
    return false
end

function M:TestSonar()
    RegisterSonar()
    return PlayBundledSonar()
end

function M:PrintStatus()
    print("|cff66ff99[NiniSR]|r " .. self:GetStatus())
    print(string.format("|cff66ff99[NiniSR]|r v%s bridge=%s exboss=%s PlayerIsSpellTarget=%s SecretVisualAPI=%s", PROFILE_VERSION,
        tostring(targetBridgeRegistered), tostring(IsEXBossLoaded()), tostring(type(_G.PlayerIsSpellTarget)=="function"),
        tostring(type(CreateFrame("Frame").SetAlphaFromBoolean)=="function")))
    if self.FallbackAoE and type(self.FallbackAoE.PrintStatus) == "function" then self.FallbackAoE:PrintStatus() end
end

local eventFrame = _G.NiniTools.EventDispatcher:CreateProxy("NSR.Bridge")
for _, event in ipairs({
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_SPECIALIZATION_CHANGED", "ADDON_LOADED",
    "CHALLENGE_MODE_START", "CHALLENGE_MODE_RESET", "CHALLENGE_MODE_COMPLETED",
}) do
    eventFrame:RegisterEvent(event)
end
eventFrame:SetScript("OnEvent", function(_, event, arg)
    if event == "CHALLENGE_MODE_START" or event == "CHALLENGE_MODE_RESET" or event == "CHALLENGE_MODE_COMPLETED" then
        ResetBridgeRuntime()
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then ResetBridgeRuntime() end
    if event == "PLAYER_SPECIALIZATION_CHANGED" and arg ~= "player" then return end
    if event == "ADDON_LOADED" then
        local name = tostring(arg or "")
        if name ~= ADDON_NAME and name ~= "NaowhSmartReminders" and name ~= "EXBoss" and name ~= "NiniSmartRemindersProfile" then return end
    end
    C_Timer.After(event == "PLAYER_LOGIN" and 2.5 or 0.6, function() M:Refresh(true) end)
end)

SLASH_NINISR1 = "/nininsr"
SlashCmdList.NINISR = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "status" then
        M:PrintStatus()
    elseif msg == "targetdebug" then
        targetDebug = not targetDebug
        print("|cff66ff99[NiniSR]|r target debug = " .. tostring(targetDebug))
    elseif msg == "fallbackdebug" then
        if M.FallbackAoE and type(M.FallbackAoE.SetDebug) == "function" then
            print("|cff66ff99[NiniSR]|r fallback debug = " .. tostring(M.FallbackAoE:SetDebug()))
        end
    elseif msg == "fallbackstatus" then
        if M.FallbackAoE and type(M.FallbackAoE.PrintStatus) == "function" then M.FallbackAoE:PrintStatus() end
    elseif msg == "reinstall" or msg == "reset" or msg == "use" then
        M:Reinstall(); M:PrintStatus()
    elseif msg == "sonar" or msg == "test" then
        M:TestSonar()
    elseif msg == "open" then
        M:OpenNaowh()
    else
        print("|cff66ff99[NiniSR]|r /nininsr status | reinstall | open | sonar | targetdebug | fallbackdebug | fallbackstatus")
    end
end
