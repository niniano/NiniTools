local _, NT = ...
local W = {}
NT.Waypoints = W

local defaults = {enabled=true, showName=true, glow=true, alwaysShow=false, scale=1}

-- WilduTools 1.9.45 > Better Super Tracked의 구형 표시값을 그대로 사용한다.
-- 당시 미리보기 이미지의 긴/부드러운 빛기둥은 OBJFX_LineGlow atlas를
-- 가로 300x32로 만든 뒤 90도 회전해서 표시하는 방식이었다.
local DISTANCE_TEXT_SIZE = 13
local LABEL_OFFSET_Y = -22
local GLOW_ATLAS = "OBJFX_LineGlow"
local GLOW_OFFSET_Y = 82
local GLOW_WIDTH = 300 -- 90도 회전 후 실제 세로 길이
local GLOW_HEIGHT = 32 -- 90도 회전 후 실제 폭
local TARGET_ICON_SIZE = 35

-- OBJFX_LineGlow가 사라진 클라이언트용 안전장치.
-- 정상적인 현재 클라이언트에서는 위 atlas가 우선 사용된다.
local FALLBACK_TEXTURE = "Interface\\AddOns\\NiniTools\\Media\\waypoint_beam.tga"
local FALLBACK_WIDTH = 64
local FALLBACK_HEIGHT = 190
local FALLBACK_OFFSET_Y = -6
local LABEL_R, LABEL_G, LABEL_B = 1, 210/255, 0

local PIN_TYPE = {
  QUEST = 0,
  USER_WAYPOINT = 1,
  CORPSE = 2,
  SCENARIO = 3,
  CONTENT = 4,
  MAP_PIN = 6,
  VIGNETTE = 7,
}

local POI_TYPE = {
  AREA_POI = 0,
  QUEST_OFFER = 1,
  TAXI_NODE = 2,
  DIG_SITE = 3,
  HOUSING_PLOT = 4,
}

local DEFAULT_PIN_ATLAS = "Waypoint-MapPin-Tracked"

function W:GetVisualSpec()
  return {
    pinAtlas=DEFAULT_PIN_ATLAS,
    glowAtlas=GLOW_ATLAS, glowOffsetY=GLOW_OFFSET_Y, glowWidth=GLOW_WIDTH, glowHeight=GLOW_HEIGHT,
    fallbackTexture=FALLBACK_TEXTURE, fallbackWidth=FALLBACK_WIDTH, fallbackHeight=FALLBACK_HEIGHT, fallbackOffsetY=FALLBACK_OFFSET_Y,
    labelOffsetY=LABEL_OFFSET_Y, targetIconSize=TARGET_ICON_SIZE,
  }
end
local QUEST_OFFER_ATLAS
local AREA_POI_EVENT_RING_ATLAS = "worldquest-questmarker-epic-supertracked"
local AREA_POI_EVENT_GLOW_ATLAS = "UI-QuestPoi-OuterGlow"
local AREA_POI_EVENT_OVERLAY_SCALE = 0.72

local QC = Enum and Enum.QuestClassification or {}
local function CreateQuestIconStyle(prefix, turnInAtlas)
  return {
    ring = prefix .. "-QuestNumber-SuperTracked",
    outerGlow = prefix .. "-OuterGlow",
    turnIn = turnInAtlas,
  }
end

local DEFAULT_QUEST_ICON_STYLE = CreateQuestIconStyle("UI-QuestPoi", "UI-QuestIcon-TurnIn-Normal")
local QUEST_ICON_STYLE = {
  [QC.Important or -101] = CreateQuestIconStyle("UI-QuestPoiImportant", "UI-QuestPoiImportant-QuestBangTurnIn"),
  [QC.Legendary or -102] = CreateQuestIconStyle("UI-QuestPoiLegendary", "UI-QuestPoiLegendary-QuestBangTurnIn"),
  [QC.Campaign or -103] = CreateQuestIconStyle("UI-QuestPoiCampaign", "UI-QuestPoiCampaign-QuestBangTurnIn"),
  [QC.Calling or -104] = CreateQuestIconStyle("UI-QuestPoiCampaign", "UI-DailyQuestPoiCampaign-QuestBangTurnIn"),
  [QC.Meta or -105] = CreateQuestIconStyle("UI-QuestPoiWrapper", "UI-QuestPoiWrapper-QuestBangTurnIn"),
  [QC.Recurring or -106] = CreateQuestIconStyle("UI-QuestPoiRecurring", "UI-QuestPoiRecurring-QuestBangTurnIn"),
}

local HOUSING_ATLAS_MAP = {}
if Enum and Enum.HousingPlotOwnerType then
  HOUSING_ATLAS_MAP[Enum.HousingPlotOwnerType.None] = "housing-map-plot-unoccupied"
  HOUSING_ATLAS_MAP[Enum.HousingPlotOwnerType.Self] = "housing-map-plot-player-house"
  HOUSING_ATLAS_MAP[Enum.HousingPlotOwnerType.Friend] = "housing-map-plot-occupied-friend"
  HOUSING_ATLAS_MAP[Enum.HousingPlotOwnerType.Stranger] = "housing-map-plot-occupied"
end

function W:GetDB()
  local db = NT:GetDB()
  if type(db.waypoints) ~= "table" then db.waypoints = {} end
  for k,v in pairs(defaults) do
    if db.waypoints[k] == nil then db.waypoints[k] = v end
  end
  return db.waypoints
end

local function inCombat()
  return InCombatLockdown and InCombatLockdown()
end

local function saveNativeStyle(self, tracker)
  if self.nativeStyle or not tracker then return end
  local s = {}
  if tracker.Arrow and tracker.Arrow.GetScale then s.arrowScale = tracker.Arrow:GetScale() end
  if tracker.Icon then
    if tracker.Icon.GetScale then s.iconScale = tracker.Icon:GetScale() end
    if tracker.Icon.GetAtlas then s.iconAtlas = tracker.Icon:GetAtlas() end
    if tracker.Icon.GetSize then s.iconWidth, s.iconHeight = tracker.Icon:GetSize() end
  end
  if tracker.DistanceText then
    if tracker.DistanceText.GetScale then s.distanceScale = tracker.DistanceText:GetScale() end
    if tracker.DistanceText.GetFont then
      s.distanceFont, s.distanceSize, s.distanceFlags = tracker.DistanceText:GetFont()
    end
  end
  s.getTargetAlphaBaseValue = tracker.GetTargetAlphaBaseValue
  self.nativeStyle = s
end

local function restoreNativeStyle(self, tracker)
  local s = self.nativeStyle
  if not s or not tracker then return end
  if tracker.Arrow and s.arrowScale then tracker.Arrow:SetScale(s.arrowScale) end
  if tracker.Icon then
    if s.iconAtlas and tracker.Icon.SetAtlas then tracker.Icon:SetAtlas(s.iconAtlas, true) end
    if s.iconWidth and s.iconHeight then tracker.Icon:SetSize(s.iconWidth, s.iconHeight) end
    if s.iconScale then tracker.Icon:SetScale(s.iconScale) end
  end
  if tracker.DistanceText then
    if s.distanceScale then tracker.DistanceText:SetScale(s.distanceScale) end
    if s.distanceFont and s.distanceSize then
      tracker.DistanceText:SetFont(s.distanceFont, s.distanceSize, s.distanceFlags or "")
    end
  end
  if s.getTargetAlphaBaseValue then tracker.GetTargetAlphaBaseValue = s.getTargetAlphaBaseValue end
end

local function ResolveTaxiNodeAtlas(nodeID)
  if not nodeID or not C_TaxiMap or not C_TaxiMap.GetTaxiNodesForMap or not C_Map then return nil end
  local mapID = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  if not mapID then return nil end
  for _, info in ipairs(C_TaxiMap.GetTaxiNodesForMap(mapID) or {}) do
    if info.nodeID == nodeID and info.atlasName then
      if info.textureKit then return ("%s-%s"):format(info.textureKit, info.atlasName) end
      return info.atlasName
    end
  end
  return nil
end

local function ResolveHousingPlotAtlas(plotDataID)
  if not plotDataID or not C_HousingNeighborhood or not C_HousingNeighborhood.GetNeighborhoodMapData then return nil end
  for _, plotInfo in ipairs(C_HousingNeighborhood.GetNeighborhoodMapData() or {}) do
    if plotInfo.plotDataID == plotDataID then return HOUSING_ATLAS_MAP[plotInfo.ownerType] end
  end
  return nil
end

local function DetermineIconAtlas(pinType, poiType, poiID, poiInfo, vignetteInfo, questData)
  if pinType == PIN_TYPE.USER_WAYPOINT or pinType == PIN_TYPE.CONTENT then
    return DEFAULT_PIN_ATLAS
  end

  if pinType == PIN_TYPE.CORPSE then return "Navigation-Tombstone-Icon" end

  if pinType == PIN_TYPE.MAP_PIN then
    if poiType == POI_TYPE.QUEST_OFFER then
      return questData and QUEST_OFFER_ATLAS and QUEST_OFFER_ATLAS[questData.questClassification] or "QuestNormal"
    elseif poiType == POI_TYPE.TAXI_NODE then
      return ResolveTaxiNodeAtlas(poiID) or "TaxiNode_Neutral"
    elseif poiType == POI_TYPE.DIG_SITE then
      return "ArchBlob"
    elseif poiType == POI_TYPE.HOUSING_PLOT then
      return ResolveHousingPlotAtlas(poiID) or "housing-map-plot-unoccupied"
    elseif poiInfo and poiInfo.isCurrentEvent and poiInfo.atlasName then
      return AREA_POI_EVENT_RING_ATLAS, poiInfo.atlasName, AREA_POI_EVENT_GLOW_ATLAS, AREA_POI_EVENT_OVERLAY_SCALE
    elseif poiInfo and poiInfo.atlasName then
      return poiInfo.atlasName
    end
  end

  if pinType == PIN_TYPE.VIGNETTE then
    return vignetteInfo and vignetteInfo.atlasName or "VignetteKill"
  end

  if pinType == PIN_TYPE.QUEST and questData then
    local style = QUEST_ICON_STYLE[questData.questClassification] or DEFAULT_QUEST_ICON_STYLE
    if questData.questComplete then return style.ring, style.turnIn, style.outerGlow end
    if questData.questIsWorldQuest and questData.questTagInfo and QuestUtil and QuestUtil.GetWorldQuestAtlasInfo then
      return style.ring, QuestUtil.GetWorldQuestAtlasInfo(questData.questId, questData.questTagInfo) or "Worldquest-icon", style.outerGlow
    end
    return style.ring, "Quest-In-Progress-Icon-Brown", style.outerGlow
  end

  return nil
end

-- QUEST_OFFER 전용 아이콘 분류. Enum이 없는 클라이언트에서도 로드되도록 뒤에서 만든다.
QUEST_OFFER_ATLAS = {
  [QC.Recurring or -201] = "quest-recurring-available",
  [QC.Legendary or -202] = "quest-legendary-available",
  [QC.Important or -203] = "quest-important-available",
  [QC.Campaign or -204] = "Quest-Campaign-Available",
  [QC.Meta or -205] = "quest-wrapper-available",
}

local function createElements(self, tracker)
  if self.highlightFrame and self.label then return true end
  if inCombat() then return false end

  -- WilduTools와 동일하게 SuperTrackedFrame의 자식으로 만든다.
  local highlightFrame = CreateFrame("Frame", nil, tracker)
  highlightFrame:SetSize(1, 1)
  highlightFrame:SetPoint("CENTER")
  highlightFrame:SetFrameStrata("BACKGROUND")
  highlightFrame:SetFrameLevel(math.max(0, tracker:GetFrameLevel() - 1))

  local texture = highlightFrame:CreateTexture(nil, "BACKGROUND")

  -- WilduTools 1.9.45의 구현을 그대로 재현한다.
  -- 최신 WilduTools의 AftLevelup-CloudyLineRight + bounce 방식이 아니라,
  -- 예전 Better Waypoints 미리보기와 같은 OBJFX_LineGlow 고정 빛기둥이다.
  local atlasAvailable = true
  if C_Texture and C_Texture.GetAtlasInfo then
    atlasAvailable = C_Texture.GetAtlasInfo(GLOW_ATLAS) ~= nil
  end

  if atlasAvailable then
    texture:SetAtlas(GLOW_ATLAS)
    texture:SetPoint("TOP", tracker.Icon, "TOP", 0, GLOW_OFFSET_Y)
    texture:SetSize(GLOW_WIDTH, GLOW_HEIGHT)
    texture:SetRotation(math.pi / 2)
    texture:SetAlpha(1)
    highlightFrame.usesLegacyGlowAtlas = true
  else
    -- 혹시 Blizzard가 OBJFX_LineGlow 자체를 제거한 경우에만 자체 텍스처로 대체.
    texture:SetTexture(FALLBACK_TEXTURE)
    texture:SetBlendMode("ADD")
    texture:SetPoint("BOTTOM", tracker.Icon, "TOP", 0, FALLBACK_OFFSET_Y)
    texture:SetSize(FALLBACK_WIDTH, FALLBACK_HEIGHT)
    texture:SetAlpha(1)
    highlightFrame.usesLegacyGlowAtlas = false
  end

  highlightFrame.texture = texture

  local label = tracker:CreateFontString(nil, "OVERLAY", "Game12Font_o1")
  label:SetTextColor(LABEL_R, LABEL_G, LABEL_B)
  label:SetPoint("TOP", tracker.Icon, "BOTTOM", 0, LABEL_OFFSET_Y)
  label:SetWidth(280)
  label:SetJustifyH("CENTER")

  self.highlightFrame = highlightFrame
  self.label = label
  return true
end

local function SetIconOverlay(self, tracker, atlas, effectiveScale)
  local overlay = self.iconOverlay
  if not overlay then
    if not atlas or inCombat() then return end
    overlay = tracker:CreateTexture(nil, "OVERLAY", nil, 2)
    overlay:SetPoint("CENTER", tracker.Icon, "CENTER", 0, 0)
    self.iconOverlay = overlay
  end
  if atlas then
    overlay:SetAtlas(atlas, true)
    overlay:SetScale(effectiveScale or 1)
    overlay:Show()
  else
    overlay:Hide()
  end
end

local function SetIconOuterGlow(self, tracker, atlas, effectiveScale)
  local outerGlow = self.iconOuterGlow
  if not outerGlow then
    if not atlas or inCombat() then return end
    local outerGlowFrame = CreateFrame("Frame", nil, tracker)
    outerGlowFrame:SetSize(1, 1)
    outerGlowFrame:SetPoint("CENTER", tracker.Icon, "CENTER", 0, 0)
    outerGlowFrame:SetFrameStrata("BACKGROUND")
    outerGlowFrame:SetFrameLevel(0)
    outerGlow = outerGlowFrame:CreateTexture(nil, "BACKGROUND", nil, -8)
    outerGlow:SetPoint("CENTER")
    self.outerGlowFrame = outerGlowFrame
    self.iconOuterGlow = outerGlow
  end
  if atlas then
    outerGlow:SetAtlas(atlas, true)
    outerGlow:SetScale(effectiveScale or 1)
    outerGlow:Show()
    if self.outerGlowFrame then self.outerGlowFrame:Show() end
  else
    outerGlow:Hide()
    if self.outerGlowFrame then self.outerGlowFrame:Hide() end
  end
end

local function updateIcon(self, tracker, superTrackerIconScale)
  if not C_SuperTrack or not C_SuperTrack.IsSuperTrackingAnything or not C_SuperTrack.IsSuperTrackingAnything() then return end

  local pinType = C_SuperTrack.GetHighestPrioritySuperTrackingType and C_SuperTrack.GetHighestPrioritySuperTrackingType()
  local poiType, poiID
  if C_SuperTrack.GetSuperTrackedMapPin then poiType, poiID = C_SuperTrack.GetSuperTrackedMapPin() end

  local poiInfo
  if poiID and poiType == POI_TYPE.AREA_POI and C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIInfo then
    poiInfo = C_AreaPoiInfo.GetAreaPOIInfo(nil, poiID)
  end

  local vignetteID = C_SuperTrack.GetSuperTrackedVignette and C_SuperTrack.GetSuperTrackedVignette()
  local vignetteInfo
  if vignetteID and C_VignetteInfo and C_VignetteInfo.GetVignetteInfo then
    vignetteInfo = C_VignetteInfo.GetVignetteInfo(vignetteID)
  end

  local questId = C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID()
  if not questId and poiType == POI_TYPE.QUEST_OFFER then questId = poiID end

  local questData
  if questId then
    questData = {
      questId = questId,
      questClassification = C_QuestInfoSystem and C_QuestInfoSystem.GetQuestClassification and C_QuestInfoSystem.GetQuestClassification(questId),
      questComplete = C_QuestLog and C_QuestLog.ReadyForTurnIn and C_QuestLog.ReadyForTurnIn(questId),
      questIsWorldQuest = C_TaskQuest and C_TaskQuest.GetQuestInfoByQuestID and C_TaskQuest.GetQuestInfoByQuestID(questId) ~= nil,
      questTagInfo = C_QuestLog and C_QuestLog.GetQuestTagInfo and C_QuestLog.GetQuestTagInfo(questId),
    }
  end

  local iconAtlas, overlayAtlas, outerGlowAtlas, overlayScale = DetermineIconAtlas(pinType, poiType, poiID, poiInfo, vignetteInfo, questData)
  if not iconAtlas then
    SetIconOuterGlow(self, tracker, nil)
    SetIconOverlay(self, tracker, nil)
    tracker.Icon:SetScale(superTrackerIconScale)
    return
  end

  tracker.Icon:SetAtlas(iconAtlas, true)
  local effectiveScale = superTrackerIconScale
  if tracker.Icon:GetWidth() > 0 then
    effectiveScale = superTrackerIconScale * (TARGET_ICON_SIZE / tracker.Icon:GetWidth())
  end
  tracker.Icon:SetScale(effectiveScale)

  SetIconOuterGlow(self, tracker, outerGlowAtlas, effectiveScale)
  SetIconOverlay(self, tracker, overlayAtlas, effectiveScale * (overlayScale or 1))
end

local navStateToTargetAlpha = {}
if Enum and Enum.NavigationState then
  navStateToTargetAlpha[Enum.NavigationState.Invalid] = 0.0
  navStateToTargetAlpha[Enum.NavigationState.Occluded] = 0.6
  navStateToTargetAlpha[Enum.NavigationState.InRange] = 1.0
  navStateToTargetAlpha[Enum.NavigationState.Disabled] = 0.0
end

local function applyAlphaBehavior(self, tracker, alwaysShow)
  if alwaysShow then
    tracker.GetTargetAlphaBaseValue = function(frame)
      return frame.__niniIsSuperTrackingAnything and 1 or 0
    end
    return
  end

  tracker.GetTargetAlphaBaseValue = function(frame)
    if not frame.__niniIsSuperTrackingAnything then return 0 end
    if not C_Navigation or not C_Navigation.GetTargetState then return 1 end

    local state = C_Navigation.GetTargetState()
    local alpha = navStateToTargetAlpha[state]

    -- WilduTools의 변경점: 위치가 화면 좌표로 잡히지 않거나 화면 가장자리에
    -- 고정된 경우에도 표식이 흐려지지 않게 한다.
    if Enum and Enum.NavigationState and state == Enum.NavigationState.Invalid
      and C_Navigation.HasValidScreenPosition and not C_Navigation.HasValidScreenPosition() then
      alpha = 1.0
    end
    if alpha and alpha > 0 and frame.isClamped then return 1 end
    return alpha or 1
  end
end

function W:Refresh()
  local db = self:GetDB()
  self:UpdateWatcher()

  local tracker = _G.SuperTrackedFrame
  if not tracker or not tracker.Icon or not C_SuperTrack or not C_SuperTrack.IsSuperTrackingAnything then
    return
  end

  saveNativeStyle(self, tracker)

  if not db.enabled then
    if self.highlightFrame then self.highlightFrame:Hide() end
    if self.label then self.label:Hide() end
    if self.iconOverlay then self.iconOverlay:Hide() end
    if self.outerGlowFrame then self.outerGlowFrame:Hide() end
    restoreNativeStyle(self, tracker)
    return
  end

  if C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("showInGameNavigation") == "0" then
    if self.highlightFrame then self.highlightFrame:Hide() end
    if self.label then self.label:Hide() end
    return
  end

  local userScale = math.max(.65, math.min(1.5, tonumber(db.scale) or 1))
  local superTrackerIconScale = 1.2 * userScale

  if tracker.Arrow then tracker.Arrow:SetScale(userScale) end
  tracker.Icon:SetScale(superTrackerIconScale)
  if tracker.DistanceText then
    tracker.DistanceText:SetScale(userScale)
    local font = tracker.DistanceText:GetFont()
    if font then tracker.DistanceText:SetFont(font, DISTANCE_TEXT_SIZE, "OUTLINE") end
  end

  tracker.__niniIsSuperTrackingAnything = C_SuperTrack.IsSuperTrackingAnything() and true or false
  applyAlphaBehavior(self, tracker, db.alwaysShow)

  if not tracker.__niniIsSuperTrackingAnything or not tracker:IsShown() then
    if self.highlightFrame then self.highlightFrame:Hide() end
    if self.label then self.label:Hide() end
    if self.iconOverlay then self.iconOverlay:Hide() end
    if self.outerGlowFrame then self.outerGlowFrame:Hide() end
    return
  end

  if not createElements(self, tracker) then return end

  self.label:ClearAllPoints()
  self.label:SetPoint("TOP", tracker.Icon, "BOTTOM", 0, LABEL_OFFSET_Y)
  self.label:SetScale(userScale)
  self.label:SetText(db.showName and C_SuperTrack.GetSuperTrackedItemName and (C_SuperTrack.GetSuperTrackedItemName() or "") or "")
  self.label:SetShown(db.showName)

  local h = self.highlightFrame
  h.texture:ClearAllPoints()
  if h.usesLegacyGlowAtlas then
    -- 중요: 구 WilduTools와 똑같이 Icon TOP에서 +82에 고정한다.
    -- 기존 NiniTools Refresh가 BOTTOM 기준으로 다시 덮어쓰던 문제도 제거.
    h.texture:SetPoint("TOP", tracker.Icon, "TOP", 0, GLOW_OFFSET_Y)
    h.texture:SetSize(GLOW_WIDTH, GLOW_HEIGHT)
    h.texture:SetRotation(math.pi / 2)
  else
    h.texture:SetPoint("BOTTOM", tracker.Icon, "TOP", 0, FALLBACK_OFFSET_Y)
    h.texture:SetSize(FALLBACK_WIDTH, FALLBACK_HEIGHT)
    h.texture:SetRotation(0)
  end

  if db.glow then
    h.texture:SetAlpha(1)
    h:Show()
  else
    h.texture:SetAlpha(0)
    h:Hide()
  end

  updateIcon(self, tracker, superTrackerIconScale)
end

local driver = CreateFrame("Frame")
local elapsed = 0
local function tick(_, dt)
  elapsed = elapsed + dt
  if elapsed < .10 then return end
  elapsed = 0
  W:Refresh()
end

local watcherOn
function W:UpdateWatcher()
  local on = self:GetDB().enabled and true or false
  if on == watcherOn then return end
  watcherOn = on
  driver:SetScript("OnUpdate", on and tick or nil)
  if not on then
    local tracker = _G.SuperTrackedFrame
    if self.highlightFrame then self.highlightFrame:Hide() end
    if self.label then self.label:Hide() end
    if self.iconOverlay then self.iconOverlay:Hide() end
    if self.outerGlowFrame then self.outerGlowFrame:Hide() end
    if tracker then restoreNativeStyle(self, tracker) end
  end
end

W:UpdateWatcher()
