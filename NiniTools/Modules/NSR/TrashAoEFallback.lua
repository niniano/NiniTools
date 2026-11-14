local ADDON_NAME, NT = ...
if not NT or type(NT.NSRBridge) ~= "table" then return end

local Bridge = NT.NSRBridge
local F = {}
Bridge.FallbackAoE = F

local TARGET_SAMPLE_DELAY = 0.10
local FIRST_TOLERANCE = 2.00
local SCHEDULE_TOLERANCE = 2.00
local TIE_TOLERANCE = 0.05
local COMBAT_SCAN_INTERVAL = 0.10
local MAX_NAMEPLATES = 40

local debugEnabled = false
local states = {}
local stageByInstance = {}
local scanTicker
local challengeStopped = false

local function Stages(...)
    local t = {}
    for i = 1, select("#", ...) do t[select(i, ...)] = true end
    return t
end

local function ZoneNames(...)
    local t = {}
    for i = 1, select("#", ...) do t[select(i, ...)] = true end
    return t
end

-- This is intentionally small: only the 18 Naowh EXBoss-profile AoE mechanics and the
-- sibling casts needed to tell those mechanics apart when EXBoss itself is not installed.
-- first/cd/opening/targetAPI values are copied from EXBoss v26.9.15.1537 TrashCDData.
local DATA = {
    [1762] = { -- King's Rest
        [134739] = {
            stages = Stages(2), level = 91, power = 1, lieutenant = false, family = false,
            zoneNames = ZoneNames(
                "Hall of Honored Dead", "Die Halle der Geehrten Toten", "Cámara de los Muertos Honorables",
                "Salón de los Muertos Reverenciados", "Hall des Morts honorés", "Sala dei Morti Onorevoli",
                "명예로운 죽음의 회당", "Salão dos Mortos Honoráveis", "Зал почитаемых усопших",
                "荣耀亡者大厅", "先王之堂"),
            spells = {
                [270293] = { kind = "cast", first = 2.0, cd = { 8.1 }, targetAPI = false, aoe = true },
            },
        },
        [137484] = {
            stages = Stages(2), level = 91, power = 1, lieutenant = false, family = false,
            zoneNames = ZoneNames(
                "Sepulcher of the Dahazi", "Das Grabmal der Dahazi", "Sepulcro de los Dahazi",
                "Sépulcre des Dahazi", "Sepolcro dei Dahazi", "다하지의 무덤", "Sepulcro dos Dahazi",
                "Склеп Дахази", "达哈基圣墓", "達哈茲之墓"),
            spells = {
                [1297918] = { kind = "cast", first = 8.4, cd = { 21.8 }, opening = 1, targetAPI = true },
                [1297970] = { kind = "cast", first = 15.7, cd = { 23.0 }, opening = 2, targetAPI = false, aoe = true },
            },
        },
        [134158] = {
            stages = Stages(1), level = 91, power = 1, lieutenant = false, family = false,
            spells = {
                [1305945] = { kind = "cast", first = 7.2, cd = { 20.3 }, opening = 1, targetAPI = false, aoe = true },
                [269928]  = { kind = "channel", first = 11.7, cd = { 18.3 }, opening = 2, targetAPI = false },
                [269976]  = { kind = "cast", first = 18.0, cd = { 23.3 }, opening = 3, targetAPI = false },
            },
        },
    },

    [1877] = { -- Temple of Sethraliss
        [134991] = {
            stages = Stages(1), level = 91, power = 1, lieutenant = true, family = false,
            spells = {
                [1291468] = { kind = "cast", first = 4.7, cd = { 18.9 }, targetAPI = true },
                [265966]  = { kind = "cast", first = 17.9, cd = { 26.4 }, targetAPI = false, aoe = true },
            },
        },
        [136076] = {
            stages = Stages(3), level = 91, power = 0, lieutenant = true, family = false,
            spells = {
                [1293475] = { kind = "cast", first = 5.7,  cd = { 26.1 }, targetAPI = false, aoe = true },
                [1293650] = { kind = "cast", first = 11.7, cd = { 11.8, 19.1 }, targetAPI = false },
                [1293464] = { kind = "cast", first = 20.3, cd = { 5.8, 9.4, 8.2 }, targetAPI = false },
            },
        },
        [135007] = {
            stages = Stages(4), level = 91, power = 1, lieutenant = true, family = false,
            spells = {
                [1303443] = { kind = "cast", first = 3.0,  cd = { 21.8 }, targetAPI = true },
                [1303486] = { kind = "cast", first = 10.2, cd = { 23.2 }, targetAPI = false, aoe = true },
            },
        },
    },

    [2521] = { -- Ruby Life Pools
        [190034] = {
            stages = Stages(2), level = 91, power = 0,
            spells = {
                [1305955] = { kind = "cast", first = 3.8, cd = { 14.2 } },
                [384139]  = { kind = "cast", first = 5.2, cd = nil, targetAPI = false },
                [373692]  = { kind = "cast", first = 7.1, cd = { 22.0 }, targetAPI = false, aoe = true },
                [373614]  = { kind = "cast", first = nil, cd = nil },
            },
        },
        [188244] = {
            stages = Stages(1), level = 91, power = 1,
            spells = {
                [372730]  = { kind = "cast", first = 6.8, cd = { 18.2 }, targetAPI = true },
                [1305201] = { kind = "cast", first = 9.8, cd = { 23.2 }, targetAPI = false, aoe = true },
            },
        },
    },

    [2859] = { -- The Blinding Vale
        [249756] = {
            stages = Stages(4), level = 91, power = 1, lieutenant = true, family = true,
            spells = {
                [1250100] = { kind = "cast", first = 5.2,  cd = { 24.7 }, opening = 1, targetAPI = true },
                [1250199] = { kind = "cast", first = 7.9,  cd = { 24.1 }, opening = 2, targetAPI = false },
                [1250937] = { kind = "cast", first = 16.4, cd = { 24.7 }, opening = 3, targetAPI = false, aoe = true },
            },
        },
        [254850] = {
            stages = Stages(1, 2, 3, 4), level = 91, power = 1, lieutenant = true, family = false,
            spells = {
                [1271385] = { kind = "cast", first = 5.5,  cd = { 24.8 }, aoe = true },
                [1263636] = { kind = "cast", first = 15.5, cd = { 27.0 }, channel = 3.0 },
            },
        },
    },

    [2923] = { -- Voidscar Arena
        [244260] = {
            stages = Stages(1), mapIDs = { [2572] = true }, level = 91, power = 1, lieutenant = true,
            spells = {
                [1234855] = { kind = "channel", first = 20.4, cd = { 10.6 }, targetAPI = false, aoe = true },
            },
        },
        [267546] = {
            stages = Stages(1), mapIDs = { [2574] = true }, level = 91, power = 0, lieutenant = false,
            spells = {
                [1311747] = { kind = "cast", first = 10.8, cd = { 30.8 }, targetAPI = false },
                [1299270] = { kind = "cast", first = 20.3, cd = { 20.8 }, channel = 9.0, targetAPI = false, aoe = true },
            },
        },
    },

    [2825] = { -- Den of Nalorakk
        [245855] = {
            stages = Stages(1), level = 91, power = 1, lieutenant = false,
            spells = {
                [1238760] = { kind = "cast", first = 4.5, cd = { 22.8 }, targetAPI = false },
                [1238687] = { kind = "cast", first = 8.1, cd = { 19.0 }, channel = 5.0, targetAPI = false, aoe = true },
            },
        },
        [245146] = {
            stages = Stages(3), level = 91, power = 1, lieutenant = true,
            spells = {
                [1246957] = { kind = "cast", first = 5.0,  cd = { 20.0 }, opening = 1, targetAPI = false, aoe = true },
                [1246986] = { kind = "cast", first = 11.5, cd = { 21.1 }, opening = 2, targetAPI = false },
            },
        },
    },

    [2813] = { -- Murder Row
        [235322] = {
            stages = Stages(4), requireStage = true, level = 91, power = 1, lieutenant = true,
            spells = {
                [1294824] = { kind = "cast", first = 5.8,  cd = { 19.2 }, opening = 1, channel = 8.0, aoe = true },
                [1215961] = { kind = "cast", first = 22.2, cd = { 24.4 }, opening = 2, channel = 4.0 },
            },
        },
        [236905] = {
            stages = Stages(3), requireStage = true, level = 91, power = 1, lieutenant = true,
            spells = {
                [1302007] = { kind = "cast", first = 5.5,  cd = { 19.9 }, opening = 1, channel = 1.2, aoe = true },
                [1216954] = { kind = "cast", first = 10.4, cd = { 16.9 }, opening = 2, channel = 2.5 },
            },
        },
    },

    [2993] = { -- Altar of Fangs
        [262011] = {
            stages = Stages(2), requireStage = true, level = 91, power = 1, family = false,
            spells = {
                [1294845] = { kind = "cast", first = 7.0,  cd = { 25.0 }, targetAPI = true },
                [1294849] = { kind = "cast", first = 12.7, cd = { 20.0 }, channel = 5.0, targetAPI = false, aoe = true },
            },
        },
        [270306] = {
            stages = Stages(1, 3), requireStage = true, level = 91, power = 1, family = false,
            spells = {
                [1306911] = { kind = "cast", first = 6.0,  cd = { 20.0 }, targetAPI = true },
                [1306517] = { kind = "cast", first = 12.0, cd = { 18.0 }, channel = 2.0, targetAPI = false, aoe = true },
            },
        },
    },
}

local function Print(msg)
    if debugEnabled then print("|cff66ff99[NiniSR-FB]|r " .. tostring(msg)) end
end

local function CorePrint(msg)
    print("|cff66ff99[NiniSR-FB]|r " .. tostring(msg))
end

local function IsPlain(v)
    if type(_G.issecretvalue) == "function" then
        local ok, secret = pcall(_G.issecretvalue, v)
        if ok and secret == true then return false end
    end
    return true
end

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a = pcall(fn, ...)
    if not ok or not IsPlain(a) then return nil end
    return a
end

local function SafeLevel(unit)
    local v = SafeCall(UnitLevel, unit)
    return type(v) == "number" and v > 0 and v or nil
end

local function SafePowerType(unit)
    local v = SafeCall(UnitPowerType, unit)
    return type(v) == "number" and v or nil
end

local function SafeClassification(unit)
    local v = SafeCall(UnitClassification, unit)
    return type(v) == "string" and v or nil
end

local function SafeLieutenant(unit)
    local v = SafeCall(UnitIsLieutenant, unit)
    return type(v) == "boolean" and v or nil
end

local function SafeFamilyPresence(unit)
    if type(UnitCreatureFamily) ~= "function" then return nil end
    local ok, present = pcall(function() return UnitCreatureFamily(unit) ~= nil end)
    return ok and type(present) == "boolean" and present or nil
end

local function SafeTargetAPI(unit)
    local v = SafeCall(UnitShouldDisplaySpellTargetName, unit)
    return type(v) == "boolean" and v or nil
end

local function CurrentInstanceID()
    if type(GetInstanceInfo) ~= "function" then return nil end
    local _, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()
    if instanceType ~= "party" then return nil end
    return tonumber(instanceID)
end

local function CurrentPlacementMapID()
    if C_Map and type(C_Map.GetBestMapForUnit) == "function" then
        local ok, id = pcall(C_Map.GetBestMapForUnit, "player")
        if ok and IsPlain(id) then return tonumber(id) end
    end
    return nil
end

local function CurrentZoneText()
    if type(GetMinimapZoneText) ~= "function" then return nil end
    local ok, text = pcall(GetMinimapZoneText)
    if not ok or not IsPlain(text) or type(text) ~= "string" then return nil end
    text = text:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
    return text ~= "" and text or nil
end

local function IsEXBossLoaded()
    if type(_G.ExBoss) == "table" then return true end
    if C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function" then
        local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, "EXBoss")
        if ok and loaded == true then return true end
    end
    return false
end

function F:IsActive()
    local instanceID = CurrentInstanceID()
    return not challengeStopped
        and Bridge and type(Bridge.DisplayFallbackSonar) == "function"
        and instanceID ~= nil and DATA[instanceID] ~= nil and not IsEXBossLoaded()
end

local function StateFor(unit)
    local s = states[unit]
    if not s then
        s = { unit = unit, spellNext = {}, spellSeq = {}, inCombat = false, seenOutOfCombat = false }
        states[unit] = s
    end
    return s
end

local function ResetCombatState(s, keepSeen)
    s.inCombat = false
    s.engagedAt = nil
    s.order = 0
    s.lockedNPC = nil
    s.spellNext = {}
    s.spellSeq = {}
    s.lastKind = nil
    s.lastBarID = nil
    s.lastStartAt = nil
    s.lastEventKey = nil
    s.pendingToken = (tonumber(s.pendingToken) or 0) + 1
    if keepSeen then s.seenOutOfCombat = true else s.seenOutOfCombat = false end
end

local function ClearStates()
    -- Invalidate pending C_Timer.After callbacks before dropping unit state references.
    for _, s in pairs(states) do
        if type(s) == "table" then ResetCombatState(s, false) end
    end
    wipe(states)
end

local function SyncCombat(unit)
    if type(unit) ~= "string" or not unit:match("^nameplate%d+$") then return nil end
    if type(UnitExists) == "function" and UnitExists(unit) ~= true then return nil end
    local s = StateFor(unit)
    local combat = SafeCall(UnitAffectingCombat, unit) == true
    if combat and not s.inCombat then
        s.inCombat = true
        if s.seenOutOfCombat then
            s.engagedAt = GetTime()
            s.order = 0
            s.lockedNPC = nil
            s.spellNext = {}
            s.spellSeq = {}
            Print(string.format("%s combat start %.3f", unit, s.engagedAt))
        else
            -- Nameplate first appeared after combat already began. Timing-only rules fail closed.
            s.engagedAt = nil
            Print(unit .. " joined mid-combat; timing anchor unavailable")
        end
    elseif not combat and s.inCombat then
        ResetCombatState(s, true)
        Print(unit .. " combat end/reset")
    elseif not combat then
        s.seenOutOfCombat = true
    end
    return s
end

local function Snapshot(unit)
    return {
        level = SafeLevel(unit),
        power = SafePowerType(unit),
        classification = SafeClassification(unit),
        lieutenant = SafeLieutenant(unit),
        family = SafeFamilyPresence(unit),
        stage = stageByInstance[CurrentInstanceID()],
        placementMapID = CurrentPlacementMapID(),
        zoneText = CurrentZoneText(),
    }
end

local function MobIdentityMatches(mob, obs)
    if mob.requireStage and not obs.stage then return false end
    if mob.stages and obs.stage and mob.stages[obs.stage] ~= true then return false end
    if mob.mapIDs and obs.placementMapID and mob.mapIDs[obs.placementMapID] ~= true then return false end
    if mob.zoneNames and obs.zoneText and mob.zoneNames[obs.zoneText] ~= true then return false end
    if mob.level and obs.level and obs.level ~= mob.level and obs.level ~= (mob.level - 60) then return false end
    if mob.power ~= nil and obs.power ~= nil and obs.power ~= mob.power then return false end
    if mob.lieutenant ~= nil and obs.lieutenant ~= nil and obs.lieutenant ~= mob.lieutenant then return false end
    if mob.family ~= nil and obs.family ~= nil and obs.family ~= mob.family then return false end
    if obs.classification and obs.classification ~= "elite" then return false end
    return true
end

local function NextCD(s, sid, spell)
    if type(spell.cd) ~= "table" or #spell.cd == 0 then return nil end
    local idx = (tonumber(s.spellSeq[sid]) or 0) + 1
    if idx > #spell.cd then idx = 1 end
    s.spellSeq[sid] = idx
    return tonumber(spell.cd[idx])
end

local function PredictedAt(s, sid, spell)
    local nextAt = tonumber(s.spellNext[sid])
    if nextAt then return nextAt, false end
    if s.engagedAt and tonumber(spell.first) then return s.engagedAt + tonumber(spell.first), true end
    return nil, true
end

local function BuildCandidates(instanceID, s, obs, kind, at, order, targetAPI)
    local dungeon = DATA[instanceID]
    local out = {}
    for npcID, mob in pairs(dungeon or {}) do
        if (not s.lockedNPC or s.lockedNPC == npcID) and MobIdentityMatches(mob, obs) then
            for sid, spell in pairs(mob.spells or {}) do
                if spell.kind == kind then
                    local keep = true
                    local apiPenalty = 0
                    if spell.targetAPI ~= nil and targetAPI ~= nil then
                        if spell.targetAPI ~= targetAPI then keep = false end
                    elseif spell.targetAPI ~= nil and targetAPI == nil then
                        apiPenalty = 0.25
                    end

                    if keep and spell.opening and order and order <= 3 and order ~= spell.opening then
                        keep = false
                    end

                    local predicted, firstCycle = nil, true
                    local delta = nil
                    if keep then
                        predicted, firstCycle = PredictedAt(s, sid, spell)
                        if predicted then
                            delta = math.abs(at - predicted)
                            local tolerance = firstCycle and FIRST_TOLERANCE or SCHEDULE_TOLERANCE
                            if delta > tolerance then keep = false end
                        elseif not s.lockedNPC then
                            -- No combat anchor and no prior confirmed cycle: do not guess.
                            keep = false
                        end
                    end

                    if keep then
                        local score = (delta or 1.5) + apiPenalty
                        if spell.opening and order == spell.opening then score = score - 0.20 end
                        out[#out + 1] = {
                            npcID = npcID, spellID = sid, spell = spell, mob = mob,
                            score = score, delta = delta, predicted = predicted,
                        }
                    end
                end
            end
        end
    end
    table.sort(out, function(a, b)
        if a.score ~= b.score then return a.score < b.score end
        if a.npcID ~= b.npcID then return a.npcID < b.npcID end
        return a.spellID < b.spellID
    end)
    return out
end

local function CommitMatch(instanceID, unit, s, match, at, order, targetAPI)
    if not match then return end
    local sid, spell = match.spellID, match.spell
    s.lockedNPC = match.npcID
    local cd = NextCD(s, sid, spell)
    s.spellNext[sid] = cd and (at + cd) or nil
    Print(string.format("match unit=%s npc=%d spell=%d aoe=%s order=%s api=%s delta=%s next=%s",
        unit, match.npcID, sid, tostring(spell.aoe == true), tostring(order), tostring(targetAPI),
        match.delta and string.format("%.2f", match.delta) or "nil",
        s.spellNext[sid] and string.format("%.2f", s.spellNext[sid]) or "nil"))
    if spell.aoe == true and type(Bridge.DisplayFallbackSonar) == "function" then
        Bridge:DisplayFallbackSonar(sid, instanceID)
    end
end

local function ResolveCast(instanceID, unit, s, kind, at, order, token)
    if not F:IsActive() or s.pendingToken ~= token or not s.inCombat then return end
    local targetAPI = SafeTargetAPI(unit)
    local obs = Snapshot(unit)
    local candidates = BuildCandidates(instanceID, s, obs, kind, at, order, targetAPI)
    local best = candidates[1]
    if not best then
        Print(string.format("no-match unit=%s kind=%s order=%s api=%s stage=%s", unit, kind, tostring(order), tostring(targetAPI), tostring(obs.stage)))
        return
    end
    local second = candidates[2]
    if second and math.abs(second.score - best.score) <= TIE_TOLERANCE then
        Print(string.format("ambiguous unit=%s %d/%d score %.3f/%.3f", unit, best.spellID, second.spellID, best.score, second.score))
        return
    end
    CommitMatch(instanceID, unit, s, best, at, order, targetAPI)
end

local function NormalizeCastBarID(v)
    if not IsPlain(v) then return nil end
    local n = tonumber(v)
    return n and n >= 0 and n or nil
end

local function OnCastStart(event, unit, _castGUID, _spellID, castBarID)
    if not F:IsActive() then return end
    if type(unit) ~= "string" or not unit:match("^nameplate%d+$") then return end
    local instanceID = CurrentInstanceID()
    if not instanceID or not DATA[instanceID] then return end
    local s = SyncCombat(unit)
    if not s or not s.inCombat then return end

    local kind = event == "UNIT_SPELLCAST_CHANNEL_START" and "channel" or "cast"
    local now = GetTime()
    local barID = NormalizeCastBarID(castBarID)
    local continuation = kind == "channel" and s.lastKind == "cast"
        and barID and s.lastBarID and barID == (s.lastBarID + 1)
        and s.lastStartAt and (now - s.lastStartAt) <= 5.0

    local eventKey = kind .. ":" .. tostring(barID or "nil") .. ":" .. tostring(math.floor(now * 20))
    if s.lastEventKey == eventKey then return end
    s.lastEventKey = eventKey

    if continuation then
        s.lastKind, s.lastBarID, s.lastStartAt = kind, barID, now
        Print(string.format("%s cast->channel continuation bar=%s", unit, tostring(barID)))
        return
    end

    s.order = (tonumber(s.order) or 0) + 1
    local order = s.order
    s.lastKind, s.lastBarID, s.lastStartAt = kind, barID, now
    s.pendingToken = (tonumber(s.pendingToken) or 0) + 1
    local token = s.pendingToken

    -- Match EXBoss's target fingerprint behaviour: take a synchronous sample, then resolve
    -- after a 0.10 s re-sample window. ResolveCast reads the fresh value at that point.
    local syncAPI = SafeTargetAPI(unit)
    Print(string.format("start unit=%s kind=%s order=%d api0=%s stage=%s", unit, kind, order, tostring(syncAPI), tostring(stageByInstance[instanceID])))
    C_Timer.After(TARGET_SAMPLE_DELAY, function()
        ResolveCast(instanceID, unit, s, kind, now, order, token)
    end)
end

local function ScanCombat()
    if not F:IsActive() then return end
    for i = 1, MAX_NAMEPLATES do
        local unit = "nameplate" .. i
        if UnitExists(unit) then SyncCombat(unit) end
    end
end

local function StartTicker()
    if not F:IsActive() then return end
    if scanTicker or not C_Timer or type(C_Timer.NewTicker) ~= "function" then return end
    scanTicker = C_Timer.NewTicker(COMBAT_SCAN_INTERVAL, ScanCombat)
end

local function StopTicker()
    if not scanTicker then return end
    if type(scanTicker.Cancel)=="function" then pcall(scanTicker.Cancel,scanTicker) end
    scanTicker=nil
end

local frame = _G.NiniTools.EventDispatcher:CreateProxy("NSR.TrashFallback")
local HIGH_EVENTS={
    "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED",
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START",
}
local highEventsRegistered=false
local function SyncHighEvents()
    local want=F:IsActive() and true or false
    if want==highEventsRegistered then return end
    highEventsRegistered=want
    for _,event in ipairs(HIGH_EVENTS) do
        if want then frame:RegisterEvent(event) else frame:UnregisterEvent(event) end
    end
    if want then StartTicker() else StopTicker() end
end
for _, event in ipairs({
    "PLAYER_ENTERING_WORLD",
    "CHALLENGE_MODE_START", "CHALLENGE_MODE_RESET", "CHALLENGE_MODE_COMPLETED",
    "ENCOUNTER_END", "ADDON_LOADED",
}) do frame:RegisterEvent(event) end

frame:SetScript("OnEvent", function(_, event, ...)
    if event~="NAME_PLATE_UNIT_ADDED" and event~="NAME_PLATE_UNIT_REMOVED" and event~="UNIT_SPELLCAST_START" and event~="UNIT_SPELLCAST_CHANNEL_START" then
        if C_Timer and C_Timer.After then C_Timer.After(0,SyncHighEvents) else SyncHighEvents() end
    end
    if event == "PLAYER_ENTERING_WORLD" then
        ClearStates()
        challengeStopped = false
        local instanceID = CurrentInstanceID()
        if not instanceID then wipe(stageByInstance) end
        StartTicker()
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        local unit = ...
        if F:IsActive() then SyncCombat(unit) end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local unit = ...
        states[unit] = nil
    elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        OnCastStart(event, ...)
    elseif event == "CHALLENGE_MODE_START" then
        local instanceID = CurrentInstanceID()
        challengeStopped = false
        if instanceID and DATA[instanceID] then
            stageByInstance[instanceID] = 1
            ClearStates()
            if not IsEXBossLoaded() then CorePrint("쐐기 시작 · 1단계") end
        end
    elseif event == "ENCOUNTER_END" then
        local _encounterID, _encounterName, _difficultyID, _groupSize, success = ...
        if tonumber(success) == 1 and not challengeStopped then
            local instanceID = CurrentInstanceID()
            local stage = instanceID and stageByInstance[instanceID]
            if stage then
                stageByInstance[instanceID] = stage + 1
                ClearStates()
                if not IsEXBossLoaded() then CorePrint("boss defeated; stage=" .. tostring(stage + 1)) end
            end
        end
    elseif event == "CHALLENGE_MODE_RESET" or event == "CHALLENGE_MODE_COMPLETED" then
        local instanceID = CurrentInstanceID()
        local wasFallback = not challengeStopped and instanceID and DATA[instanceID] and not IsEXBossLoaded()
        challengeStopped = true
        if instanceID then stageByInstance[instanceID] = nil end
        ClearStates()
        if wasFallback then
            if event == "CHALLENGE_MODE_COMPLETED" then
                CorePrint("쐐기 완료 · 초기화")
            else
                CorePrint("쐐기 초기화 · 대체 알림 멈춤")
            end
        end
    elseif event == "ADDON_LOADED" then
        local name = ...
        if name == "EXBoss" then
            ClearStates()
            Print("EXBoss 가 켜져 있어 대체 알림을 쉽니다")
        elseif name == ADDON_NAME then
            StartTicker()
        end
    end
end)

function F:SetDebug(v)
    if v == nil then debugEnabled = not debugEnabled else debugEnabled = v == true end
    return debugEnabled
end

function F:IsDebug() return debugEnabled end

function F:GetStage()
    local instanceID = CurrentInstanceID()
    return instanceID and stageByInstance[instanceID] or nil
end

function F:PrintStatus()
    local instanceID = CurrentInstanceID()
    print(string.format("|cff66ff99[NiniSR-FB]|r active=%s exboss=%s instance=%s stage=%s tracked=%d",
        tostring(self:IsActive()), tostring(IsEXBossLoaded()), tostring(instanceID), tostring(self:GetStage()),
        (function() local n=0 for _ in pairs(states) do n=n+1 end return n end)()))
end

StartTicker()
