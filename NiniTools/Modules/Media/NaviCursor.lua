local _, NT = ...
if not NT then return end

-- Alive-only Navi cursor integrated into NiniTools.
-- No death state, no AFK test, no secure state driver.
-- 2.3.0: ring/glow/scale settings used by the unified Sound & Navi UI.
-- 2.8.12: 날아간 자리에 남는 꼬리(궤적) · 죽으면 다른 모습(분홍 요정 · 커서 가운데) ·
--         Navi 둘레 시전바 링 · (포에버) 자동공격 링. 모두 켜고 끄기 가능 · 기본 켬.
--         그림(NaviRing · NaviSpark)은 니니툴이 직접 만든 것. 다른 애드온 · 위크오라 코드나 그림은 쓰지 않음.
--
-- 출처 · 고마운 분:
--   Navi 커서의 모양 · 위치 · 색 · 모델 번호(살아 있을 때 166890 · 죽었을 때 166351)와 둘레 링 아이디어는
--   Untrue 님의 「UntrueUI - Navi Cursor」 위크오라를 참고했다 (포에버판 https://wago.io/p7q_rWVGh).
--   꼬리(궤적)는 그 위크오라와 함께 쓰는 Lumen 애드온의 꼬리에서 아이디어만 얻었다.
--   Navi 는 닌텐도 「젤다의 전설」 캐릭터 이름이다. 니니툴은 닌텐도 · Untrue · Lumen 과 관계없다.

local driver = CreateFrame("Frame")
local mouseFrame = CreateFrame("Frame", nil, UIParent)
mouseFrame:SetSize(1, 1)
mouseFrame:SetFrameStrata("MEDIUM")
mouseFrame:Show()

local function clamp(v,lo,hi)
  v=tonumber(v) or lo
  if v<lo then return lo end
  if v>hi then return hi end
  return v
end

local function getDB()
  if NT.BindModuleDB then NT:BindModuleDB() end
  local db = NiniToolsDB and NiniToolsDB.modules and NiniToolsDB.modules.media
  if type(db)~="table" then return nil end
  if db.naviCursorEnabled==nil then db.naviCursorEnabled=true end
  db.naviCursorRingEnabled=true   -- 2.7.1: 링 · 반짝임은 항상 켬 (예전에 꺼 둔 값도 켬)
  db.naviCursorGlowEnabled=true
  if db.naviCursorScale==nil then db.naviCursorScale=100 end
  -- 2.8.14: 가운데 파란 빛 밝기. 2.8.15: 기본 100% 로 (2.8.14 의 60% 기본값은 한 번만 100% 로 되돌림)
  if db.naviGlowAlphaV~=2 then
    if db.naviGlowAlpha==nil or db.naviGlowAlpha==60 then db.naviGlowAlpha=100 end
    db.naviGlowAlphaV=2
  end
  if db.naviGlowAlpha==nil then db.naviGlowAlpha=100 end
  if db.naviTrail==nil then db.naviTrail=true end
  if db.naviDeadForm==nil then db.naviDeadForm=true end
  if db.naviCastRing==nil then db.naviCastRing=true end
  db.naviCursorScale=math.floor(clamp(db.naviCursorScale,70,140)+0.5)
  return db
end

local function CreateTextureRegion(name, width, height, x, y, textureOrAtlas, color, alpha)
  local region = CreateFrame("Frame", nil, mouseFrame)
  region.name = name
  region.baseWidth = width
  region.baseHeight = height
  region.baseX = x
  region.baseY = y
  region.baseAlpha = alpha or 1

  region:SetSize(width, height)
  region:SetPoint("CENTER", mouseFrame, "CENTER", x, y)

  local tex = region:CreateTexture(nil, "ARTWORK")
  tex:SetAllPoints(region)

  local isAtlas = false
  if type(textureOrAtlas)=="string" then
    if C_Texture and C_Texture.GetAtlasInfo then
      local ok, info = pcall(C_Texture.GetAtlasInfo, textureOrAtlas)
      isAtlas = ok and info and true or false
    elseif GetAtlasInfo then
      local ok, info = pcall(GetAtlasInfo, textureOrAtlas)
      isAtlas = ok and info and true or false
    end
  end

  if isAtlas and tex.SetAtlas then
    pcall(tex.SetAtlas, tex, textureOrAtlas)
  else
    local ok = pcall(tex.SetTexture, tex, textureOrAtlas, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    if not ok then pcall(tex.SetTexture, tex, textureOrAtlas) end
  end

  tex:SetBlendMode("ADD")
  tex:SetDesaturated(false)

  local r,g,b,a = unpack(color)
  tex:SetVertexColor(r,g,b,a)

  region.texture = tex
  region:SetAlpha(region.baseAlpha)
  return region
end

local background = CreateTextureRegion(
  "Navi Background 15",
  30, 30,
  56.817220306396, 48.241638183594,
  "Interface\\AddOns\\NiniTools\\Media\\Aura87.tga",
  {1,1,1,1},
  0.6
)

local modelRegion = CreateFrame("Frame", nil, mouseFrame)
modelRegion.baseWidth = 76.449096679688
modelRegion.baseHeight = 79.665534973145
modelRegion.baseX = 54.671766662597
modelRegion.baseY = 40.196268919083
modelRegion.baseAlpha = 0.5
modelRegion:SetSize(modelRegion.baseWidth, modelRegion.baseHeight)
modelRegion:SetPoint("CENTER", mouseFrame, "CENTER", modelRegion.baseX, modelRegion.baseY)
modelRegion:SetAlpha(modelRegion.baseAlpha)

local model = CreateFrame("PlayerModel", nil, modelRegion)
model:SetAllPoints(modelRegion)
if model.SetKeepModelOnHide then pcall(model.SetKeepModelOnHide, model, true) end

-- 2.8.12: 살아 있을 때 / 죽었을 때 모습
local FORMS = {
  alive = { model = 166890, pos = { -5.05, 0, -1.9 }, modelAlpha = 0.5, shift = false,
    orb = { 0.4627451300621, 0.54901963472366, 1, 0.65000000596046 }, circle = { 0, 0.26274511218071, 1, 1 },
    trail = { 0.04, 0.14, 1 } },
  dead = { model = 166351, pos = { -10.9, 0, -2 }, modelAlpha = 1, shift = true,
    orb = { 1, 0.88235300779343, 0.89803928136826, 0.51 }, circle = { 0.90196084976196, 0.54901963472366, 0.61960786581039, 1 },
    trail = { 1, 0.55, 0.72 } },
}
local form = FORMS.alive

local function ConfigureModel()
  pcall(model.SetModel, model, form.model)
  if model.SetPortraitZoom then pcall(model.SetPortraitZoom, model, 0) end
  if model.ClearTransform then pcall(model.ClearTransform, model) end
  if model.SetPosition then pcall(model.SetPosition, model, form.pos[1], form.pos[2], form.pos[3]) end
  if model.SetFacing then pcall(model.SetFacing, model, 0) end
  if model.SetAnimation then pcall(model.SetAnimation, model, 0) end
end
ConfigureModel()

local orb = CreateTextureRegion(
  "Navi Glow Alive 5",
  60, 60,
  53.602864837646, 43.95361328125,
  "Artifacts-Anim-Orb",
  {0.4627451300621,0.54901963472366,1,0.65000000596046},
  1
)

local circle = CreateTextureRegion(
  "Navi Glow Alive 2 2",
  55, 55,
  53.602864837646, 45.025573730469,
  "BonusChest-CircleGlow",
  {0,0.26274511218071,1,1},
  1
)

-- 2.8.13: 가운데 반짝임 = 게임에 들어 있는 「물건 창조」 주문 효과 모델 (spells/conjureitem.m2, 165816).
--   빛 알갱이가 가운데로 빨려 들며 반짝인다. 위치 · 크기는 포에버 Navi 위크오라와 같게.
--   그 아래 작은 하늘색 빛(BonusChest-CircleGlow 30)으로 가운데를 더 밝게. 죽은 모습에서는 숨김.
local sparkRegion = CreateFrame("Frame", nil, mouseFrame)
sparkRegion.baseWidth, sparkRegion.baseHeight = 127.18748474121, 117.53843688965
sparkRegion.baseX, sparkRegion.baseY = 53.603881835938, 33.76904296875
sparkRegion:SetSize(sparkRegion.baseWidth, sparkRegion.baseHeight)
sparkRegion:SetPoint("CENTER", mouseFrame, "CENTER", sparkRegion.baseX, sparkRegion.baseY)
local sparkModel = CreateFrame("PlayerModel", nil, sparkRegion)
sparkModel:SetAllPoints(sparkRegion)
if sparkModel.SetKeepModelOnHide then pcall(sparkModel.SetKeepModelOnHide, sparkModel, true) end
local function ConfigureSpark()
  pcall(sparkModel.SetModel, sparkModel, 165816)
  if sparkModel.SetPortraitZoom then pcall(sparkModel.SetPortraitZoom, sparkModel, 0) end
  if sparkModel.ClearTransform then pcall(sparkModel.ClearTransform, sparkModel) end
  if sparkModel.SetPosition then pcall(sparkModel.SetPosition, sparkModel, -3.45, 0, -1.05) end
  if sparkModel.SetFacing then pcall(sparkModel.SetFacing, sparkModel, 0) end
end
ConfigureSpark()
do
  local configureNavi = ConfigureModel
  ConfigureModel = function() configureNavi(); ConfigureSpark() end
end

local coreGlow = CreateTextureRegion("Navi Glow Alive 19", 30, 30, 52, 41, "BonusChest-CircleGlow", {0,0.72156864404678,1,1}, 1)
-- 2.8.15: 본섭은 같은 주문 효과가 작게 그려져 요정 머리 쪽에 뭉친 빛이 됨
--   → 본섭만 효과 틀을 2배로 키워 포에버 빛줄기 크기로 (요정은 그대로) · 가운데 하늘색 빛은 본섭에서 뺌
local RETAIL_SPARK_SCALE = 2
if not NT.FOREVER then
  sparkRegion.baseWidth = sparkRegion.baseWidth * RETAIL_SPARK_SCALE
  sparkRegion.baseHeight = sparkRegion.baseHeight * RETAIL_SPARK_SCALE
  sparkRegion:SetSize(sparkRegion.baseWidth, sparkRegion.baseHeight)
end
local sparkleRegions = { sparkRegion, coreGlow }


background:SetFrameLevel(mouseFrame:GetFrameLevel()+1)
modelRegion:SetFrameLevel(mouseFrame:GetFrameLevel()+2)
orb:SetFrameLevel(mouseFrame:GetFrameLevel()+3)
circle:SetFrameLevel(mouseFrame:GetFrameLevel()+4)
coreGlow:SetFrameLevel(mouseFrame:GetFrameLevel()+5)
sparkRegion:SetFrameLevel(mouseFrame:GetFrameLevel()+6)

local pulseRegions = {background,orb,circle}
local born = GetTime()
local wasShown = false
local lastScale = nil

-- 2.8.13: 가운데 파란 빛(배경 · 구슬 · 하늘색 빛) 밝기 배율. 바깥 고리 · 요정 모델 · 반짝임은 그대로.
local function GlowMul(db)
  return clamp((db and tonumber(db.naviGlowAlpha)) or 100,20,100)/100
end

local function GetScale(db)
  return clamp((db and db.naviCursorScale) or 100,70,140)/100
end

-- 죽은 모습은 커서 한가운데 (살아 있을 때는 커서 오른쪽 위)
local function Shift()
  if form.shift then return -modelRegion.baseX, -modelRegion.baseY end
  return 0, 0
end

local function ApplyAnchor(region, scale)
  local sx, sy = Shift()
  region:ClearAllPoints()
  region:SetPoint("CENTER", mouseFrame, "CENTER", (region.baseX+sx)*scale, (region.baseY+sy)*scale)
end

local function ApplyGeometry(db, force)
  local scale=GetScale(db)
  if not force and lastScale==scale then return scale end
  lastScale=scale
  ApplyAnchor(background,scale)
  ApplyAnchor(orb,scale)
  ApplyAnchor(circle,scale)
  ApplyAnchor(modelRegion,scale)
  for _,r in ipairs(sparkleRegions) do ApplyAnchor(r,scale) end
  if NT.NaviRingsLayout then NT.NaviRingsLayout(scale) end
  return scale
end

local function ApplyPulse(region, factor, scale)
  region:SetSize(region.baseWidth*scale*factor, region.baseHeight*scale*factor)
end

local function ApplyVisibility(show,db)
  local ringOn = db and db.naviCursorRingEnabled~=false
  local glowOn = db and db.naviCursorGlowEnabled~=false
  background:SetShown(show and glowOn)
  modelRegion:SetShown(show)
  orb:SetShown(show and glowOn)
  circle:SetShown(show and ringOn)
  for _,r in ipairs(sparkleRegions) do
    local on = (r ~= coreGlow) or NT.FOREVER
    r:SetShown(on and show and glowOn and not form.shift)
  end
end

-- ---------------------------------------------------------------------------
-- 2.8.12: 꼬리(궤적). 움직일 때만 불꽃 점을 남기고, 점은 0.7초 동안 작아지며 사라진다.
-- 점은 천천히 흩어지며(드리프트) 더해지는 빛(ADD)으로 겹쳐 굵은 빛줄기처럼 보인다.
-- 점 40개를 돌려 쓰므로 프레임마다 새로 만드는 것 없음 (모자라면 가장 오래된 점부터 다시 씀).
-- 멈춰 있고 남은 점이 없으면 아무것도 안 함.
-- ---------------------------------------------------------------------------
local TRAIL_N, TRAIL_LIFE, TRAIL_SIZE, TRAIL_GAP, TRAIL_ALPHA, TRAIL_DRIFT = 40, 0.7, 44, 12, 0.85, 14
local DOT = "Interface\\AddOns\\NiniTools\\Media\\NaviSpark.tga"
local trailFrame = CreateFrame("Frame", nil, UIParent)
trailFrame:SetAllPoints(UIParent)
trailFrame:SetFrameStrata("MEDIUM")
trailFrame:SetFrameLevel(math.max(0, mouseFrame:GetFrameLevel()))
local trail, trailHead, trailAlive = {}, 0, 0
local lastEmitX, lastEmitY, lastTick
for i = 1, TRAIL_N do
  local t = trailFrame:CreateTexture(nil, "ARTWORK")
  t:SetTexture(DOT)
  t:SetBlendMode("ADD")
  t:Hide()
  trail[i] = { tex = t, age = TRAIL_LIFE }
end

local function ClearTrail()
  for i = 1, TRAIL_N do trail[i].age = TRAIL_LIFE; trail[i].tex:Hide() end
  trailAlive, lastEmitX, lastEmitY = 0, nil, nil
end

local function UpdateTrail(px, py, scale, on)
  local now = GetTime()
  local dt = lastTick and math.min(0.1, now - lastTick) or 0
  lastTick = now
  if on then
    if not lastEmitX then lastEmitX, lastEmitY = px, py end
    local dx, dy = px - lastEmitX, py - lastEmitY
    if dx * dx + dy * dy >= (TRAIL_GAP * scale) ^ 2 then
      trailHead = trailHead % TRAIL_N + 1
      local d = trail[trailHead]
      if d.age >= TRAIL_LIFE then trailAlive = trailAlive + 1 end
      d.age = 0
      d.size = TRAIL_SIZE * scale * (0.85 + 0.3 * math.random())
      d.x, d.y = px, py
      local ang = math.random() * 6.2832
      local sp = TRAIL_DRIFT * scale * (0.3 + 0.7 * math.random())
      d.vx, d.vy = math.cos(ang) * sp, math.sin(ang) * sp
      local c = form.trail
      d.tex:SetVertexColor(c[1], c[2], c[3], 1)
      d.tex:ClearAllPoints()
      d.tex:SetPoint("CENTER", UIParent, "BOTTOMLEFT", px, py)
      d.tex:Show()
      lastEmitX, lastEmitY = px, py
    end
  end
  if trailAlive <= 0 then return end
  for i = 1, TRAIL_N do
    local d = trail[i]
    if d.age < TRAIL_LIFE then
      d.age = d.age + dt
      if d.age >= TRAIL_LIFE then
        d.tex:Hide(); trailAlive = trailAlive - 1
      else
        local a = 1 - d.age / TRAIL_LIFE
        d.tex:SetAlpha(a * TRAIL_ALPHA)
        local sz = d.size * (0.25 + 0.75 * a)
        d.tex:SetSize(sz, sz)
        if d.vx and dt > 0 then
          d.x, d.y = d.x + d.vx * dt, d.y + d.vy * dt
          d.tex:ClearAllPoints()
          d.tex:SetPoint("CENTER", UIParent, "BOTTOMLEFT", d.x, d.y)
        end
      end
    end
  end
end

-- ---------------------------------------------------------------------------
-- 2.8.12: Navi 둘레 링. 안쪽 = 시전바 (채널은 줄어듦), 바깥쪽 = 자동공격 · 원거리 자동 사격 (포에버만).
-- 쿨다운 틀의 원형 채우기에 니니툴 링 그림을 씌운다. 끝나면 스스로 숨는다.
-- ---------------------------------------------------------------------------
local RING = "Interface\\AddOns\\NiniTools\\Media\\NaviRing.tga"
local function MakeRing(size, r, g, b)
  local holder = CreateFrame("Frame", nil, mouseFrame)
  holder.baseSize = size
  holder:SetSize(size, size)
  holder:SetFrameLevel(mouseFrame:GetFrameLevel() + 5)
  holder.bg = holder:CreateTexture(nil, "BACKGROUND")
  holder.bg:SetAllPoints()
  holder.bg:SetTexture(RING)
  holder.bg:SetVertexColor(0, 0, 0, 0.5)
  local cd = CreateFrame("Cooldown", nil, holder)
  cd:SetAllPoints()
  if cd.SetSwipeTexture then pcall(cd.SetSwipeTexture, cd, RING) end
  if cd.SetSwipeColor then pcall(cd.SetSwipeColor, cd, r, g, b, 1) end
  if cd.SetDrawEdge then pcall(cd.SetDrawEdge, cd, false) end
  if cd.SetDrawBling then pcall(cd.SetDrawBling, cd, false) end
  if cd.SetHideCountdownNumbers then pcall(cd.SetHideCountdownNumbers, cd, true) end
  if cd.SetUseCircularEdge then pcall(cd.SetUseCircularEdge, cd, true) end
  cd:SetScript("OnCooldownDone", function() holder:Hide() end)
  holder.cd = cd
  holder.color = { r, g, b }
  holder:Hide()
  function holder:Run(startSec, durSec, shrinking, cr, cg, cb)
    if not durSec or durSec <= 0 then self:Hide(); return end
    if cr and self.cd.SetSwipeColor then pcall(self.cd.SetSwipeColor, self.cd, cr, cg, cb, 1) end
    if self.cd.SetReverse then pcall(self.cd.SetReverse, self.cd, not shrinking) end
    self:Show()
    pcall(self.cd.SetCooldown, self.cd, startSec, durSec)
  end
  function holder:Stop()
    if self.cd.Clear then pcall(self.cd.Clear, self.cd) end
    self:Hide()
  end
  return holder
end

local castRing = MakeRing(50, 0, 0.6588, 1)
local swingRing = MakeRing(62, 0, 1, 0.8118)
local RANGED_COLOR = { 0.6078, 0.9216, 1 }

NT.NaviRingsLayout = function(scale)
  scale = scale or 1
  local sx, sy = Shift()
  for _, ring in ipairs({ castRing, swingRing }) do
    ring:SetSize(ring.baseSize * scale, ring.baseSize * scale)
    ring:ClearAllPoints()
    ring:SetPoint("CENTER", mouseFrame, "CENTER", (modelRegion.baseX + sx) * scale, (modelRegion.baseY + sy) * scale + 4 * scale)
  end
end

local function ringsOn()
  local db = getDB()
  return db and db.naviCursorEnabled ~= false and db.naviCastRing ~= false
end

local function RefreshCast()
  if not ringsOn() then castRing:Stop(); return end
  local now = GetTime()
  local ok, name, _, _, startMS, endMS = pcall(UnitCastingInfo, "player")
  if ok and name and type(startMS) == "number" and type(endMS) == "number" then
    castRing:Run(startMS / 1000, (endMS - startMS) / 1000, false)
    return
  end
  ok, name, _, _, startMS, endMS = pcall(UnitChannelInfo, "player")
  if ok and name and type(startMS) == "number" and type(endMS) == "number" then
    castRing:Run(startMS / 1000, (endMS - startMS) / 1000, true)
    return
  end
  castRing:Stop()
end

local castEvents = CreateFrame("Frame")
for _, ev in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
  "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP" }) do
  if castEvents.RegisterUnitEvent then pcall(castEvents.RegisterUnitEvent, castEvents, ev, "player")
  else pcall(castEvents.RegisterEvent, castEvents, ev) end
end
castEvents:SetScript("OnEvent", function(_, _, unit)
  if unit and unit ~= "player" then return end
  RefreshCast()
end)

-- 자동공격 (포에버만: 본섭 12.x 는 전투 기록 이벤트를 애드온이 못 읽음)
if NT.FOREVER then
  local swingEvents = CreateFrame("Frame")
  local playerGUID
  local AUTO_SHOT = { [75] = true, [5019] = true }   -- 자동 사격 · 마법봉 쏘기
  pcall(swingEvents.RegisterEvent, swingEvents, "COMBAT_LOG_EVENT_UNFILTERED")
  pcall(swingEvents.RegisterEvent, swingEvents, "PLAYER_REGEN_ENABLED")
  if swingEvents.RegisterUnitEvent then pcall(swingEvents.RegisterUnitEvent, swingEvents, "UNIT_SPELLCAST_SUCCEEDED", "player")
  else pcall(swingEvents.RegisterEvent, swingEvents, "UNIT_SPELLCAST_SUCCEEDED") end
  swingEvents:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_REGEN_ENABLED" then swingRing:Stop(); return end
    if not ringsOn() then return end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
      local unit, _, spellID = ...
      if unit == "player" and AUTO_SHOT[spellID] and UnitRangedDamage then
        local speed = UnitRangedDamage("player")
        if type(speed) == "number" and speed > 0 then
          swingRing:Run(GetTime(), speed, true, RANGED_COLOR[1], RANGED_COLOR[2], RANGED_COLOR[3])
        end
      end
      return
    end
    if not CombatLogGetCurrentEventInfo then return end
    local _, sub, _, sourceGUID = CombatLogGetCurrentEventInfo()
    if sub ~= "SWING_DAMAGE" and sub ~= "SWING_MISSED" then return end
    playerGUID = playerGUID or UnitGUID("player")
    if sourceGUID ~= playerGUID then return end
    local offhand
    if sub == "SWING_DAMAGE" then offhand = select(21, CombatLogGetCurrentEventInfo())
    else offhand = select(13, CombatLogGetCurrentEventInfo()) end
    if offhand then return end   -- 주무기 기준
    local speed = UnitAttackSpeed and UnitAttackSpeed("player")
    if type(speed) == "number" and speed > 0 then
      local c = swingRing.color
      swingRing:Run(GetTime(), speed, true, c[1], c[2], c[3])
    end
  end)
end

local function CursorOnUpdate()
  local db=getDB()
  if not db or db.naviCursorEnabled==false then
    driver:SetScript("OnUpdate",nil)
    ApplyVisibility(false,db)
    ClearTrail(); castRing:Stop(); swingRing:Stop()
    wasShown=false
    return
  end

  if not wasShown then
    wasShown=true
    ConfigureModel()
    ApplyVisibility(true,db)
    born=GetTime()
  end

  local scale=ApplyGeometry(db,false)
  local x,y=GetCursorPosition()
  local invScale=1/UIParent:GetEffectiveScale()
  mouseFrame:ClearAllPoints()
  mouseFrame:SetPoint("CENTER",UIParent,"BOTTOMLEFT",x*invScale,y*invScale)
  if db.naviTrail~=false or trailAlive>0 then
    local sx,sy=Shift()
    UpdateTrail(x*invScale+(modelRegion.baseX+sx)*scale,y*invScale+(modelRegion.baseY+sy)*scale,scale,db.naviTrail~=false)
  end

  local age=GetTime()-born
  if age<0.25 then
    local p=math.max(0,math.min(1,age/0.25))
    local f=math.max(0.001,p)

    background:SetSize(background.baseWidth*scale*f,background.baseHeight*scale*f)
    orb:SetSize(orb.baseWidth*scale*f,orb.baseHeight*scale*f)
    circle:SetSize(circle.baseWidth*scale*f,circle.baseHeight*scale*f)
    modelRegion:SetSize(modelRegion.baseWidth*scale*f,modelRegion.baseHeight*scale*f)

    local gm=GlowMul(db)
    coreGlow:SetAlpha(coreGlow.baseAlpha*p*gm)
    sparkRegion:SetAlpha(p)
    sparkRegion:SetSize(sparkRegion.baseWidth*scale*f,sparkRegion.baseHeight*scale*f)
    background:SetAlpha(background.baseAlpha*p*gm)
    orb:SetAlpha(orb.baseAlpha*p*gm)
    circle:SetAlpha(circle.baseAlpha*p)
    modelRegion:SetAlpha(modelRegion.baseAlpha*p)
  else
    local gm=GlowMul(db)
    background:SetAlpha(background.baseAlpha*gm)
    orb:SetAlpha(orb.baseAlpha*gm)
    circle:SetAlpha(circle.baseAlpha)
    modelRegion:SetAlpha(modelRegion.baseAlpha)
    modelRegion:SetSize(modelRegion.baseWidth*scale,modelRegion.baseHeight*scale)

    local progress=((age-0.25)%0.75)/0.75
    local angle=(progress*2*math.pi)-(math.pi/2)
    local factor=1+(((math.sin(angle)+1)/2)*0.05)
    for _,region in ipairs(pulseRegions) do ApplyPulse(region,factor,scale) end

    coreGlow:SetAlpha(coreGlow.baseAlpha*gm)
    ApplyPulse(coreGlow,factor,scale)
    sparkRegion:SetAlpha(1)
    sparkRegion:SetSize(sparkRegion.baseWidth*scale,sparkRegion.baseHeight*scale)
  end
end

local function SetDriverActive(active)
  if active then
    driver:SetScript("OnUpdate",CursorOnUpdate)
  else
    driver:SetScript("OnUpdate",nil)
  end
end

-- 2.8.12: 죽음 · 부활에 따라 모습 바꾸기
local function ApplyFormColors()
  orb.texture:SetVertexColor(form.orb[1], form.orb[2], form.orb[3], form.orb[4])
  circle.texture:SetVertexColor(form.circle[1], form.circle[2], form.circle[3], form.circle[4])
  modelRegion.baseAlpha = form.modelAlpha
end

local function RefreshForm()
  local db = getDB()
  local dead = false
  if db and db.naviDeadForm ~= false then
    local ok, v = pcall(UnitIsDeadOrGhost, "player")
    dead = ok and v == true
  end
  local want = dead and FORMS.dead or FORMS.alive
  if want == form then return end
  form = want
  ApplyFormColors()
  ConfigureModel()
  ApplyGeometry(db, true)
  if wasShown then ApplyVisibility(true, db) end
  ClearTrail()
  castRing:Stop(); swingRing:Stop()
  born = GetTime()
end

function NT:IsNaviCursorEnabled()
  local db=getDB()
  return db and db.naviCursorEnabled~=false or false
end

function NT:SetNaviCursorEnabled(enabled)
  local db=getDB()
  if not db then return false end
  db.naviCursorEnabled=enabled and true or false
  if db.naviCursorEnabled then
    born=GetTime()
    ConfigureModel()
    ApplyGeometry(db,true)
    ApplyVisibility(true,db)
    wasShown=true
    SetDriverActive(true)
  else
    SetDriverActive(false)
    ApplyVisibility(false,db)
    ClearTrail(); castRing:Stop(); swingRing:Stop()   -- 2.8.12: 끌 때 남은 꼬리 점 · 링도 바로 지움
    wasShown=false
  end
  return true
end

function NT:IsNaviCursorRingEnabled()
  local db=getDB()
  return db and db.naviCursorRingEnabled~=false or false
end

function NT:SetNaviCursorRingEnabled(enabled)
  local db=getDB()
  if not db then return false end
  db.naviCursorRingEnabled=enabled and true or false
  ApplyVisibility(db.naviCursorEnabled~=false,db)
  return true
end

function NT:IsNaviCursorGlowEnabled()
  local db=getDB()
  return db and db.naviCursorGlowEnabled~=false or false
end

function NT:SetNaviCursorGlowEnabled(enabled)
  local db=getDB()
  if not db then return false end
  db.naviCursorGlowEnabled=enabled and true or false
  ApplyVisibility(db.naviCursorEnabled~=false,db)
  return true
end

function NT:GetNaviCursorScale()
  local db=getDB()
  return db and (tonumber(db.naviCursorScale) or 100) or 100
end

function NT:GetNaviGlowAlpha()
  local db=getDB()
  return db and math.floor(GlowMul(db)*100+0.5) or 100
end

function NT:SetNaviGlowAlpha(value)
  local db=getDB()
  if not db then return false end
  db.naviGlowAlpha=math.floor(clamp(value,20,100)+0.5)
  return true
end

function NT:SetNaviCursorScale(value)
  local db=getDB()
  if not db then return false end
  db.naviCursorScale=math.floor(clamp(value,70,140)+0.5)
  ApplyGeometry(db,true)
  born=GetTime()
  return true
end

-- 2.8.12: 꼬리 · 죽은 모습 · 링 켜고 끄기 (키: naviTrail · naviDeadForm · naviCastRing)
function NT:SetNaviCursorOption(key, enabled)
  local db=getDB()
  if not db then return false end
  db[key]=enabled and true or false
  if key=="naviTrail" and not db.naviTrail then ClearTrail() end
  if key=="naviDeadForm" then RefreshForm() end
  if key=="naviCastRing" then if db.naviCastRing then RefreshCast() else castRing:Stop(); swingRing:Stop() end end
  return true
end

-- 진단용 (자가진단 · 시험): 남은 꼬리 점 수, 죽은 모습 여부, 시전 링 · 자동공격 링 보임
function NT:NaviCursorState()
  return trailAlive, form == FORMS.dead, castRing:IsShown() and true or false, swingRing:IsShown() and true or false
end

function NT:ResetNaviCursor()
  local db=getDB()
  born=GetTime()
  ConfigureModel()
  ApplyGeometry(db,true)
  ApplyVisibility(db and db.naviCursorEnabled~=false,db)
  return true
end

local events=_G.NiniTools.EventDispatcher:CreateProxy("Media.NaviCursor")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
for _,ev in ipairs({"PLAYER_DEAD","PLAYER_ALIVE","PLAYER_UNGHOST"}) do pcall(events.RegisterEvent,events,ev) end
events:SetScript("OnEvent",function(_,event)
  if event~="PLAYER_ENTERING_WORLD" then RefreshForm(); return end
  RefreshForm()
  local db=getDB()
  if db and db.naviCursorEnabled~=false then
    ConfigureModel()
    ApplyGeometry(db,true)
    ApplyVisibility(true,db)
    born=GetTime()
    wasShown=true
    SetDriverActive(true)
  else
    wasShown=false
    SetDriverActive(false)
    ApplyVisibility(false,db)
    ClearTrail(); castRing:Stop(); swingRing:Stop()
  end
end)

SLASH_NINITOOLSNAVI1="/nnavi"
SlashCmdList.NINITOOLSNAVI=function(msg)
  msg=(msg or ""):lower():gsub("^%s+",""):gsub("%s+$","")
  if msg=="on" then
    NT:SetNaviCursorEnabled(true)
  elseif msg=="off" then
    NT:SetNaviCursorEnabled(false)
  elseif msg=="reset" then
    NT:ResetNaviCursor()
  else
    NT:Print("/nnavi on | off | reset")
    return
  end
  NT:Print("마우스 Navi "..(NT:IsNaviCursorEnabled() and "ON" or "OFF"))
end
