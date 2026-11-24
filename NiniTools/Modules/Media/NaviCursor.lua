local _, NT = ...
if not NT then return end

-- Alive-only Navi cursor integrated into NiniTools.
-- No death state, no AFK test, no secure state driver.
-- 2.3.0: ring/glow/scale settings used by the unified Sound & Navi UI.
-- 2.8.12: 날아간 자리에 남는 꼬리(궤적) · 죽으면 다른 모습(분홍 요정 · 커서 가운데) ·
--         Navi 둘레 시전바 링 · (포에버) 원거리 자동 사격 링. 모두 켜고 끄기 가능 · 기본 켬.
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

-- 2.8.21: 가운데 요정을 「내 직업 요정」으로 (사용자 11/23 · 요정은 그대로 · 날개 · 머리 · 꼬리 한 곳만 직업 옷)
--   그림은 니니툴이 직접 그린 것 (Media/NaviClassCosplay/<직업>.tga · 128px 흰색 · 압축 안 함 · 컬러는 NaviClassColor)
local FAIRY_TEX = "Interface\\AddOns\\NiniTools\\Media\\Aura87.tga"
local CLASS_FAIRY = { WARRIOR=1, PALADIN=1, HUNTER=1, ROGUE=1, PRIEST=1, DEATHKNIGHT=1, SHAMAN=1, MAGE=1, WARLOCK=1, MONK=1, DRUID=1, DEMONHUNTER=1, EVOKER=1 }
NT.NAVI_FAIRY_CHOICES = { { value = "fairy", text = "요정 (기본)" }, { value = "cosplay", text = "직업 요정 · 코스프레" }, { value = "color", text = "직업 요정 · 컬러" } }
-- 예전 테스트 값(시안 8~11)은 코스프레로
local OLD_STYLE = { class = "cosplay", class9 = "cosplay", class10 = "cosplay", class11 = "cosplay" }
function NT.NaviFairyTexture(style)
  local db = getDB()
  style = style or (db and db.naviFairyStyle) or "fairy"
  if db and OLD_STYLE[style] then style = OLD_STYLE[style]; db.naviFairyStyle = style end
  if style == "cosplay" or style == "color" then
    local cls = select(2, UnitClass("player"))
    if db then db.naviFairyTestClass = nil end   -- 시험판에서 고른 직업은 지움 (정식판은 내 직업만)
    if cls and CLASS_FAIRY[cls] then
      local dir = (style == "color") and "NaviClassColor" or "NaviClassCosplay"
      return "Interface\\AddOns\\NiniTools\\Media\\" .. dir .. "\\" .. cls .. ".tga"
    end
  end
  return FAIRY_TEX
end
-- 컬러 코스프레: 색을 살리려고 BLEND · 불투명 · 크게 · 글로우 위 (흰 요정은 예전처럼 ADD · 0.6 · 30)
--   직업별 보정: 그림마다 요정이 차지하는 넓이가 달라서 (도적이 가장 작음) 넓이 기준으로 맞춤
local COLOR_CLASS_FIX = { ROGUE=1.18, MONK=1.08, DEMONHUNTER=1.06, EVOKER=1.06, DEATHKNIGHT=1.05, WARLOCK=1.05, PRIEST=0.94, PALADIN=0.96, DRUID=0.96 }
-- 컬러 그림마다 요정 무게중심(128px 안) · 기본 요정(Aura87)과 같은 자리로 맞추려고 (사용자 11/24: 컬러는 오른쪽으로 치우침)
local COLOR_CENTER = { WARRIOR={68.5,66.0}, PALADIN={67.1,69.6}, HUNTER={72.1,65.1}, ROGUE={77.0,65.6}, PRIEST={74.6,64.9}, DEATHKNIGHT={68.3,68.4}, SHAMAN={72.0,67.6}, MAGE={73.3,66.9}, WARLOCK={75.1,68.6}, MONK={77.0,67.8}, DRUID={67.4,69.6}, DEMONHUNTER={71.4,70.3}, EVOKER={63.1,69.4} }
local FAIRY_X, FAIRY_Y = 56.817220306396, 48.241638183594        -- 기본 요정 자리
local FAIRY_SEEN_X = FAIRY_X + (58.3 - 64) / 128 * 30             -- 기본 요정이 실제로 보이는 가운데
local FAIRY_SEEN_Y = FAIRY_Y - (66.9 - 64) / 128 * 30
-- 모든 요정: 3D 빛 덩어리와 파란 구슬은 끔 (요정 모양이 하얗게 날아감 · 인게임 11/24) · 요정은 그 위(+5) · 진하게
function NT.NaviFairyLook(path, fairyOnTop)
  local db = getDB()
  path = path or NT.NaviFairyTexture()
  local style = db and db.naviFairyStyle or "fairy"
  if path == FAIRY_TEX or style == "fairy" then
    -- 기본 요정도 가운데 빛 끔 (사용자 11/24: 「가운데 빛은 모두 끄기」 · 인게임에서 기본 요정도 하얗게 묻힘)
    return { color = false, blend = "ADD", alpha = 0.9, size = 30, level = 5, dim = 0, x = FAIRY_X, y = FAIRY_Y }
  end
  if style ~= "color" then
    return { color = false, blend = "ADD", alpha = 0.9, size = 30, level = 5, dim = 0, x = FAIRY_X, y = FAIRY_Y }
  end
  local cls = path:match("NaviClassColor\\(%u+)%.tga$")
  local size = 30 * 1.4 * (COLOR_CLASS_FIX[cls] or 1)
  local c = COLOR_CENTER[cls] or { 64, 64 }
  return { color = true, blend = "BLEND", alpha = 1, size = size, level = 6, dim = 0,
           x = FAIRY_SEEN_X - (c[1] - 64) / 128 * size, y = FAIRY_SEEN_Y + (c[2] - 64) / 128 * size }
end

local function ApplyFairyTexture()
  local tex = background and background.texture
  if not tex then return end
  local path = NT.NaviFairyTexture()
  local ok = pcall(tex.SetTexture, tex, path, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  if not ok then pcall(tex.SetTexture, tex, path) end
  local look = NT.NaviFairyLook(path, background.fairyOnTop)
  background.colorMode = look.color
  pcall(tex.SetBlendMode, tex, look.blend)
  background.baseWidth, background.baseHeight = look.size, look.size
  background.baseX, background.baseY = look.x, look.y
  background.baseAlpha = look.alpha
  background:SetAlpha(background.baseAlpha)
  background:SetFrameLevel(mouseFrame:GetFrameLevel() + look.level)
  background.dim = look.dim or 1
  if NT.ApplyNaviCenterDim then NT.ApplyNaviCenterDim() end
  if NT.NaviReanchor then NT.NaviReanchor() end
end  -- 크기는 매 프레임 pulse 가 baseWidth 로 다시 잡음

NT.ApplyNaviFairyTexture = function() ApplyFairyTexture() end

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
  -- 2.8.16: 죽은 모습도 평소 자리(커서 오른쪽 위)에 · 2.8.12~15 는 커서 한가운데로 옮겼음 (dead = 반짝임 숨김 표시)
  -- 2.8.19: 포에버 위크오라 죽은 모습을 다시 확인 (사용자 11/22) — 겹치는 순서가 달랐다.
  --   위크오라: 신성 보호막 모델 → 흰 공(65) → 분홍 원(50 · BLEND = 덮는 색) → 요정 그림 → 분홍 가운데 빛(30)
  --   분홍 원이 밝은 모델 · 공 위를 덮어 가운데가 안 하얘지고, 모델의 바깥쪽만 링처럼 보이고, 요정은 맨 위에 보인다.
  --   니니툴은 요정 그림이 맨 아래 · 분홍 원이 ADD 라 가운데가 하얗게 번져 요정이 안 보였음.
  dead = { model = 166351, pos = { -10.9, 0, -2 }, modelAlpha = 0.9, shift = false, dead = true,
    orb = { 1, 0.88235300779343, 0.89803928136826, 0.51 }, orbSize = 65, circleSize = 50, circleBlend = "BLEND", fairyOnTop = true, spiral = true, circle = { 0.90196084976196, 0.54901963472366, 0.61960786581039, 1 },
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
-- 2.8.16: 가운데 반짝임 효과를 게임 안에서 고른다 (사운드 & Navi → Navi). 본섭 · 포에버 모두.
--   모두 게임에 들어 있는 주문 효과 모델 (FileDataID · wowdev 공개 파일 목록 기준). 위치 · 크기는 물건 창조와 같게.
--   기본: 포에버 = 물건 창조 빛줄기 (잘 나옴) · 본섭 = 끄기 (2.8.12 모습).
--   시험 뒤 남긴 것만: 끄기 · 반짝반짝 · 비전 양손 모으기 · 비전 반짝이 (+ 포에버 빛줄기)
local SPARK_CONJURE = 165816   -- spells/conjureitem.m2
local SPARK_DEFAULT = NT.FOREVER and SPARK_CONJURE or 0
NT.NAVI_SPARK_CHOICES = {}
if NT.FOREVER then
  NT.NAVI_SPARK_CHOICES[#NT.NAVI_SPARK_CHOICES + 1] = { id = SPARK_CONJURE, name = "빛줄기 (기본)" }
end
for _, c in ipairs({
  { id = 0,       name = NT.FOREVER and "끄기" or "끄기 (기본)" },
  { id = 5876234, name = "반짝반짝" },                       -- spells/11fx_sparklysparkles01.m2
  { id = 5054341, name = "비전 양손 모으기" },               -- spells/10gfx_arcane_precasthands.m2
  { id = 6907664, name = "비전 반짝이", retailOnly = true }, -- spells/11fx_arcanesparkles01.m2 · 포에버는 텍스처가 없어 체크무늬 (11/20 영상)
}) do
  if not (NT.FOREVER and c.retailOnly) then NT.NAVI_SPARK_CHOICES[#NT.NAVI_SPARK_CHOICES + 1] = c end
end
local SPARK_OK = {}
for _, c in ipairs(NT.NAVI_SPARK_CHOICES) do SPARK_OK[c.id] = true end
local function SparkModelID()
  local db = getDB()
  local id = db and tonumber(db.naviSparkModel)
  if id and SPARK_OK[id] then return id end
  return SPARK_DEFAULT   -- 저장 없음 · 목록에서 빠진 예전 값 (2.8.16 시험판) → 기본으로
end
NT.NaviSparkModelID = SparkModelID

local function ConfigureSpark()
  local id = SparkModelID()
  if id == 0 then return end
  pcall(sparkModel.SetModel, sparkModel, id)
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

-- 2.8.16: 요정 뒤에 아주 약하게 (10% · 사용자 11/20) · 2.8.13 은 요정 위에 100% 로 그려져 요정 가운데를 파랗게 덮었음
-- 2.8.19: 죽은 모습 가운데 분홍 빛 (위크오라 「Navi Glow Dead 6」 · 요정 위)
local deadCore = CreateTextureRegion("Navi Glow Dead 6", 30, 30, 53.602864837646, 45.025573730469, "BonusChest-CircleGlow", {1,0.78431379795074,0.8666667342186,0.65000000596046}, 1)
deadCore:Hide()
local coreGlow = CreateTextureRegion("Navi Glow Alive 19", 30, 30, 52, 41, "BonusChest-CircleGlow", {0,0.72156864404678,1,1}, 0.10)
-- 2.8.15: 본섭만 1.3배였음 → 2.8.16: 포에버와 같은 100% 로 (본섭용 효과는 위 목록에서 고르기)
local RETAIL_SPARK_SCALE = 1
if not NT.FOREVER then
  local pivotY = modelRegion.baseY
  sparkRegion.baseWidth = sparkRegion.baseWidth * RETAIL_SPARK_SCALE
  sparkRegion.baseHeight = sparkRegion.baseHeight * RETAIL_SPARK_SCALE
  sparkRegion.baseY = pivotY - (pivotY - sparkRegion.baseY) * RETAIL_SPARK_SCALE
  sparkRegion:SetSize(sparkRegion.baseWidth, sparkRegion.baseHeight)
  sparkRegion:ClearAllPoints()
  sparkRegion:SetPoint("CENTER", mouseFrame, "CENTER", sparkRegion.baseX, sparkRegion.baseY)
end
local sparkleRegions = { sparkRegion, coreGlow }
-- 2.8.16: 반짝임 효과 자리 고정 = 기본 자리에서 아래로 6px (사용자가 포에버 창에서 맞춰 본 값)
-- 2.8.18: 본섭은 원래 자리가 맞았음 (사용자) → 아래로 내리는 건 포에버만
local SPARK_FIX_X, SPARK_FIX_Y = 0, (NT.FOREVER and -6 or 0)
sparkRegion.baseX, sparkRegion.baseY = sparkRegion.baseX + SPARK_FIX_X, sparkRegion.baseY + SPARK_FIX_Y

background:SetFrameLevel(mouseFrame:GetFrameLevel()+1)
modelRegion:SetFrameLevel(mouseFrame:GetFrameLevel()+2)
orb:SetFrameLevel(mouseFrame:GetFrameLevel()+3)
circle:SetFrameLevel(mouseFrame:GetFrameLevel()+4)
coreGlow:SetFrameLevel(mouseFrame:GetFrameLevel()+1)   -- 2.8.16: 요정(+2) 뒤
deadCore:SetFrameLevel(mouseFrame:GetFrameLevel()+5)
sparkRegion:SetFrameLevel(mouseFrame:GetFrameLevel()+6)

local pulseRegions = {background,orb,circle}
local born = GetTime()
local wasShown = false
local lastScale = nil

local function GetScale(db)
  return clamp((db and db.naviCursorScale) or 100,70,140)/100
end

-- 2.8.19: 죽으면 요정이 커서 둘레를 8자로 날아다님 (위크오라 「Spiral」 애니메이션: 6초 한 바퀴 · 폭 100)
local SPIRAL_SEC, SPIRAL_R = 6, 100
local deadBorn = 0
local spiralT, spiralX, spiralY = -1, 0, 0
local function Spiral()   -- 2.8.21: 한 프레임에 한 번만 계산 (링 · 요정 · 공 · 모델이 같이 씀)
  local now = GetTime()
  if now ~= spiralT then
    local p = ((now - deadBorn) % SPIRAL_SEC) / SPIRAL_SEC
    local a = (p + 0.25) * 2 * math.pi
    local c = math.cos(a)
    spiralT, spiralX, spiralY = now, c * SPIRAL_R * math.cos(a * 2), math.abs(c) * SPIRAL_R * math.sin(a * 2)
  end
  return spiralX, spiralY
end

-- 죽은 모습은 커서 한가운데 (살아 있을 때는 커서 오른쪽 위)
local function Shift()
  if form.shift then return -modelRegion.baseX, -modelRegion.baseY end
  if form.spiral then return Spiral() end
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
  ApplyAnchor(deadCore,scale)
  for _,r in ipairs(sparkleRegions) do ApplyAnchor(r,scale) end
  if NT.NaviRingsLayout then NT.NaviRingsLayout(scale) end
  return scale
end
NT.NaviReanchor = function() local db=getDB(); if db then ApplyGeometry(db,true) end end

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
  deadCore:SetShown(show and glowOn and form.dead and true or false)
  for _,r in ipairs(sparkleRegions) do
    r:SetShown(show and glowOn and not form.dead and not (r == sparkRegion and SparkModelID() == 0))   -- 하늘색 빛은 효과 끄기여도 보임
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
-- 2.8.12: Navi 둘레 링. 안쪽 = 시전바 (채널은 줄어듦), 바깥쪽 = 원거리 자동 사격 (포에버만 · 2.8.20 부터 근접 없음).
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

-- 2.8.20: 포에버도 전투 중 숫자가 「비밀 값」으로 옴 → 비교 · 계산하면 오류. 평범한 숫자만 씀
local function plainNum(v)
  if type(v) ~= "number" then return nil end
  if type(issecretvalue) == "function" then
    local ok, secret = pcall(issecretvalue, v)
    if not ok or secret then return nil end
  end
  return v
end

local function RefreshCast()
  if not ringsOn() then castRing:Stop(); return end
  local now = GetTime()
  local ok, name, _, _, startMS, endMS = pcall(UnitCastingInfo, "player")
  startMS, endMS = plainNum(startMS), plainNum(endMS)
  if ok and name and startMS and endMS then
    castRing:Run(startMS / 1000, (endMS - startMS) / 1000, false)
    return
  end
  ok, name, _, _, startMS, endMS = pcall(UnitChannelInfo, "player")
  startMS, endMS = plainNum(startMS), plainNum(endMS)
  if ok and name and startMS and endMS then
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

-- 원거리 자동 사격 (포에버만)
-- 2.8.20: 포에버도 전투 기록 등록이 막히고(ADDON_ACTION_FORBIDDEN) 공격 속도도 전투 중엔 비밀 값 → 근접 링은 뺌
--   원거리: 자동 사격 · 마법봉 쏘기 시전 성공 때 원거리 속도 (비밀 값이면 그냥 안 그림)
if NT.FOREVER then
  local swingEvents = CreateFrame("Frame")
  local AUTO_SHOT = { [75] = true, [5019] = true }   -- 자동 사격 · 마법봉 쏘기
  pcall(swingEvents.RegisterEvent, swingEvents, "PLAYER_REGEN_ENABLED")
  if swingEvents.RegisterUnitEvent then pcall(swingEvents.RegisterUnitEvent, swingEvents, "UNIT_SPELLCAST_SUCCEEDED", "player")
  else pcall(swingEvents.RegisterEvent, swingEvents, "UNIT_SPELLCAST_SUCCEEDED") end
  swingEvents:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_REGEN_ENABLED" then swingRing:Stop(); return end
    if not ringsOn() then return end
    local unit, _, spellID = ...
    spellID = plainNum(spellID)
    if unit == "player" and spellID and AUTO_SHOT[spellID] and UnitRangedDamage then
      local ok, speed = pcall(UnitRangedDamage, "player")
      speed = ok and plainNum(speed)
      if speed and speed > 0 then
        swingRing:Run(GetTime(), speed, true, RANGED_COLOR[1], RANGED_COLOR[2], RANGED_COLOR[3])
      end
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
    ApplyFairyTexture()
    ApplyVisibility(true,db)
    born=GetTime()
  end

  local scale=ApplyGeometry(db,form.spiral and true or false)   -- 2.8.19: 죽은 모습은 매 프레임 자리 옮김 (날아다님)
  local x,y=GetCursorPosition()
  local invScale=1/UIParent:GetEffectiveScale()
  local ax,ay=x*invScale,y*invScale
  -- 2.8.21: 죽은 모습은 마우스를 따라가지 않고 화면 가운데(0,0) 자리에 고정해서 8자로 난다 (사용자 11/23)
  if form.spiral then ax,ay=UIParent:GetWidth()/2,UIParent:GetHeight()/2 end
  mouseFrame:ClearAllPoints()
  mouseFrame:SetPoint("CENTER",UIParent,"BOTTOMLEFT",ax,ay)
  if db.naviTrail~=false or trailAlive>0 then
    local sx,sy=Shift()
    UpdateTrail(ax+(modelRegion.baseX+sx)*scale,ay+(modelRegion.baseY+sy)*scale,scale,db.naviTrail~=false)
  end

  local age=GetTime()-born
  if age<0.25 then
    local p=math.max(0,math.min(1,age/0.25))
    local f=math.max(0.001,p)

    background:SetSize(background.baseWidth*scale*f,background.baseHeight*scale*f)
    orb:SetSize(orb.baseWidth*scale*f,orb.baseHeight*scale*f)
    circle:SetSize(circle.baseWidth*scale*f,circle.baseHeight*scale*f)
    modelRegion:SetSize(modelRegion.baseWidth*scale*f,modelRegion.baseHeight*scale*f)

    coreGlow:SetAlpha(coreGlow.baseAlpha*p)
    deadCore:SetAlpha(deadCore.baseAlpha*p)
    sparkRegion:SetAlpha(p)
    sparkRegion:SetSize(sparkRegion.baseWidth*scale*f,sparkRegion.baseHeight*scale*f)
    background:SetAlpha(background.baseAlpha*p)
    orb:SetAlpha(orb.baseAlpha*p)
    circle:SetAlpha(circle.baseAlpha*p)
    modelRegion:SetAlpha(modelRegion.baseAlpha*p)
  else
    background:SetAlpha(background.baseAlpha)
    orb:SetAlpha(orb.baseAlpha)
    circle:SetAlpha(circle.baseAlpha)
    modelRegion:SetAlpha(modelRegion.baseAlpha)
    modelRegion:SetSize(modelRegion.baseWidth*scale,modelRegion.baseHeight*scale)

    local progress=((age-0.25)%0.75)/0.75
    local angle=(progress*2*math.pi)-(math.pi/2)
    local factor=1+(((math.sin(angle)+1)/2)*0.05)
    for _,region in ipairs(pulseRegions) do ApplyPulse(region,factor,scale) end

    coreGlow:SetAlpha(coreGlow.baseAlpha)
    ApplyPulse(coreGlow,factor,scale)
    deadCore:SetAlpha(deadCore.baseAlpha)
    ApplyPulse(deadCore,factor,scale)
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
local ORB_SIZE, CIRCLE_SIZE = orb.baseWidth, circle.baseWidth
local function ApplyFormColors()
  orb.texture:SetVertexColor(form.orb[1], form.orb[2], form.orb[3], form.orb[4])
  circle.texture:SetVertexColor(form.circle[1], form.circle[2], form.circle[3], form.circle[4])
  modelRegion.baseAlpha = form.modelAlpha * (background.dim or 1)
  orb.baseAlpha = background.dim or 1
  -- 2.8.19: 죽은 모습 겹치는 순서 · 크기 · 분홍 원 덮는 색 (위크오라와 같게)
  orb.baseWidth, orb.baseHeight = form.orbSize or ORB_SIZE, form.orbSize or ORB_SIZE
  circle.baseWidth, circle.baseHeight = form.circleSize or CIRCLE_SIZE, form.circleSize or CIRCLE_SIZE
  circle.texture:SetBlendMode(form.circleBlend or "ADD")
  background.fairyOnTop = form.fairyOnTop and true or false
  local lk = NT.NaviFairyLook and NT.NaviFairyLook(nil, form.fairyOnTop)
  background:SetFrameLevel(mouseFrame:GetFrameLevel() + ((lk and lk.level) or (form.fairyOnTop and 5 or 1)))
end
NT.ApplyNaviCenterDim = function()
  modelRegion.baseAlpha = form.modelAlpha * (background.dim or 1)
  orb.baseAlpha = background.dim or 1
  modelRegion:SetAlpha(modelRegion.baseAlpha); orb:SetAlpha(orb.baseAlpha)
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
  if form.spiral then deadBorn = GetTime() end
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
    ApplyFairyTexture()
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

-- 진단용 (자가진단 · 시험): 남은 꼬리 점 수, 죽은 모습 여부, 시전 링 · 원거리 자동 사격 링 보임
function NT:NaviCursorState()
  return trailAlive, form == FORMS.dead, castRing:IsShown() and true or false, swingRing:IsShown() and true or false
end

-- 2.8.16: 가운데 반짝임 효과 고르기 (본섭 · 포에버)
function NT:SetNaviSparkModel(id)
  local db=getDB()
  if not db then return false end
  db.naviSparkModel=tonumber(id) or 0
  ConfigureSpark()
  ApplyVisibility(wasShown,db)
  return true
end

-- 2.8.21: 가운데 요정 = 요정 / 내 직업 요정
function NT:SetNaviFairyStyle(v)
  local db=getDB()
  if not db then return false end
  db.naviFairyStyle=(v=="cosplay" or v=="color") and v or "fairy"
  ApplyFairyTexture()
  return true
end

function NT:ResetNaviCursor()
  local db=getDB()
  born=GetTime()
  ConfigureModel()
  ApplyFairyTexture()
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
  ApplyFairyTexture()   -- 2.8.21: /reload · 재접속 뒤에도 고른 요정 (wasShown=true 로 OnUpdate 첫 줄을 건너뛰므로)
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
