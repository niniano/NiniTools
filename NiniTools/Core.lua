local ADDON_NAME, NT = ...
NT = NT or {}
_G.NiniTools = NT

NT.VERSION = "2.6.9"
local function resolveClassAccent()
  local classFile
  if UnitClass then
    local ok,_,cf=pcall(UnitClass,"player")
    if ok then classFile=cf end
  end
  local c=classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
  if c then return {c.r,c.g,c.b},classFile end
  return {0,207/255,1},classFile or "UNKNOWN"
end

NT.ACCENT,NT.CLASS_FILE = resolveClassAccent()

-- 2.5.2: unified NiniTools N branding. Keep a distinct asset for each UI role.
NT.BRAND_ICON_ON_DARK = "Interface\\AddOns\\NiniTools\\Media\\NiniTools.tga"
NT.BRAND_ICON_ON_LIGHT = "Interface\\AddOns\\NiniTools\\Media\\NiniTools.tga"
NT.BRAND_ICON_ROUND = "Interface\\AddOns\\NiniTools\\Media\\NiniTools_Round.tga"
NT.BRAND_ICON_MINIMAP = "Interface\\AddOns\\NiniTools\\Media\\NiniTools_Minimap.tga"
NT.BRAND_WORDMARK = "Interface\\AddOns\\NiniTools\\Media\\NiniTools_Wordmark.tga"
function NT:GetBrandIcon(backgroundIsDark)
  if backgroundIsDark==false then return self.BRAND_ICON_ON_LIGHT end
  return self.BRAND_ICON_ON_DARK
end
function NT:GetBrandRoundIcon()
  return self.BRAND_ICON_ROUND
end
function NT:GetBrandMinimapIcon()
  return self.BRAND_ICON_MINIMAP
end
function NT:GetBrandWordmark()
  return self.BRAND_WORDMARK
end

-- 2.5.4: one font resolver for every NiniTools text.
-- Body = NaowhKR (SharedMedia), numbers = GothamNarrowUltraKR. Font files are NOT shipped
-- (commercial merge, personal use only). Without them: EllesmereUI font -> STANDARD_TEXT_FONT.
-- Resolved lazily at draw time, because SharedMedia packs may load after NiniTools.
NT.FONT_CANDIDATES = {
  body = {"NaowhKR","Naowh KR","NaowhAsia","Naowh Asia"},
  num  = {"GothamNarrowUltraKR","Gotham Narrow Ultra KR","GothamNarrowUltraAsia","GothamNarrowUltra"},
}
local function ntLSM()
  if not LibStub then return nil end
  local ok,lsm=pcall(LibStub.GetLibrary,LibStub,"LibSharedMedia-3.0",true)
  if ok and lsm and type(lsm.Fetch)=="function" then return lsm end
end
local function ntFetch(lsm,name)
  if not lsm or type(name)~="string" or name=="" then return nil end
  local ok,p=pcall(lsm.Fetch,lsm,"font",name,true)
  if ok and type(p)=="string" and p~="" then return p end
end
local function ntFontPrefs()
  local db=_G.NiniToolsDB
  if type(db)~="table" then return nil end
  if type(db.fontPrefs)~="table" then db.fontPrefs={} end
  return db.fontPrefs
end
NT.GetFontPrefs=ntFontPrefs
-- returns path, sourceLabel
function NT:ResolveFont(kind)
  kind=(kind=="num") and "num" or "body"
  local lsm=ntLSM()
  local prefs=ntFontPrefs()
  local want=prefs and prefs[kind]
  local p=ntFetch(lsm,want)
  if p then return p,"설정: "..want end
  for _,name in ipairs(self.FONT_CANDIDATES[kind]) do
    p=ntFetch(lsm,name)
    if p then return p,"SharedMedia: "..name end
  end
  if kind=="num" then
    local bp,bs=self:ResolveFont("body")
    return bp,bs.." (숫자도 본문 글꼴)"
  end
  local EUI=_G.EllesmereUI
  if EUI then
    for _,fn in ipairs({"GetFontPath","GetFont"}) do
      if type(EUI[fn])=="function" then
        local ok,ep=pcall(EUI[fn])
        if ok and type(ep)=="string" and ep~="" then return ep,"EllesmereUI" end
      end
    end
  end
  return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF","게임 기본 (STANDARD_TEXT_FONT)"
end
function NT:BodyFont() return (self:ResolveFont("body")) end
function NT:NumberFont() return (self:ResolveFont("num")) end
-- /nt font [list | body <이름> | num <이름> | auto]
function NT:FontSlash(arg, rawArg)
  arg=arg or ""
  local prefs=ntFontPrefs()
  local lsm=ntLSM()
  local cmd,rest=arg:match("^(%S*)%s*(.-)$")
  local rawRest=(rawArg or ""):match("^%S*%s*(.-)%s*$") or rest
  if cmd=="auto" or cmd=="자동" then
    if prefs then prefs.body=nil; prefs.num=nil end
    self:Print("글꼴: 자동 (NaowhKR / GothamNarrowUltraKR 찾기). /reload 후 모든 창에 적용됩니다.")
  elseif (cmd=="body" or cmd=="num" or cmd=="본문" or cmd=="숫자") and rawRest~="" then
    local kind=(cmd=="num" or cmd=="숫자") and "num" or "body"
    if not ntFetch(lsm,rawRest) then
      self:Print("SharedMedia에 '"..rawRest.."' 글꼴이 없습니다. /nt font list 로 이름을 확인하세요.")
      return
    end
    if prefs then prefs[kind]=rawRest end
    self:Print((kind=="num" and "숫자" or "본문").." 글꼴 = "..rawRest..". /reload 후 모든 창에 적용됩니다.")
  elseif cmd=="list" or cmd=="목록" then
    if not lsm or type(lsm.List)~="function" then self:Print("SharedMedia(LibSharedMedia)가 없습니다."); return end
    local hits={}
    for _,name in ipairs(lsm:List("font") or {}) do
      local l=name:lower()
      if l:find("naowh") or l:find("gotham") or l:find("kr") or l:find("asia") then hits[#hits+1]=name end
    end
    self:Print("SharedMedia 글꼴 (naowh/gotham/kr/asia): "..(#hits>0 and table.concat(hits,", ") or "없음"))
  end
  local bp,bs=self:ResolveFont("body")
  local np,ns=self:ResolveFont("num")
  self:Print("본문: "..bs.." · "..tostring(bp))
  self:Print("숫자: "..ns.." · "..tostring(np))
end

-- Shared alert palette for important-cast markers and enemy-count warnings.
-- Bright scarlet -> orange, faster flash so the important-mob cue reads immediately.
NT.ALERT_STYLE = NT.ALERT_STYLE or {
  -- Strong scarlet <-> bright orange contrast; deliberately faster than the old RC flash.
  period = 0.50,
  low = {1.00, 0.05, 0.015},
  high = {1.00, 0.82, 0.025},
  alphaMin = 0.86,
  glowAlphaMin = 0.28,
  glowAlphaMax = 0.92,
}

-- Important-cast marker visual presets (2.5.5 R2).  One "!" only: the icon itself
-- grows and shrinks.  No glow copy or ripple copy behind it (those read as a second,
-- differently sized "!").  The three styles differ by how the single icon moves:
--   DEFAULT  기본형 · 천천히 숨쉬듯 조금 커졌다 작아짐
--   (2.5.6) 세 스타일 모두 색은 빨강→주황→노랑→주황→빨강 1.6초 주기
--   PULSE    펄스형 · 두근-두근 두 번 뛰는 박동
--   EMPHASIS 강조형 · 큰 아이콘이 크게 부풀었다 돌아옴
--   (2.6.0) PREMIUM 고급형 · 크기 그대로 · 크게 튀어나왔다가 제자리, 끝나면 작아지며 사라짐 · 새 기본값
--   (2.6.1) 고급형 그림을 다시 그림: 오른쪽으로 살짝 기운 넓은 몸통 · 입체 결 · 흰 광택(색 안 입힘)
--           색은 주황↔핫핑크 (빨간 체력바가 겹친 쐐기 이름표 위에서도 잘 보이게)
--   (2.6.2) 새 「!」 그림을 바탕으로 세 가지 움직임만 남김. 예전 빨강·노랑 그림 스타일은 없앰.
--           기본형 = 튀어나오기 · 펄스형 = 두근두근 · 강조형 = 크게 부풀기 (셋 다 주황↔핫핑크 · 광택 · 튀어나오며 등장)
--   (2.6.6) 그림(모양)과 움직임(스타일)을 나눔. 그림 = 클래식(예전 모양 · 외곽선 · 기본) / 기울임(2.6.1 그림).
--           「!」 외곽선을 따라 아주 얇은 흰 테두리(기본 켬). 색은 그대로 주황↔핫핑크.
NT.IMPORTANT_CAST_STYLE_ORDER = {"PREMIUM","PULSE","EMPHASIS"}
local PREMIUM_TEX="Interface\\AddOns\\NiniTools\\Media\\ImportantAlert_Premium.tga"
local PREMIUM_GLOSS="Interface\\AddOns\\NiniTools\\Media\\ImportantAlert_Premium_Gloss.tga"
local CLASSIC_TEX="Interface\\AddOns\\NiniTools\\Media\\ImportantAlert_White.tga"
NT.IMPORTANT_CAST_SHAPE_ORDER = {"CLASSIC","SLANT"}
NT.IMPORTANT_CAST_SHAPES = {
  -- bottomPad = 그림 아래 빈칸 비율 (체력바 위에 점이 닿게 맞출 때 씀)
  -- rim = 글자 바깥을 따라 그린 흰 테두리 (그림과 같은 칸 · 같은 크기로 겹침)
  CLASSIC = { label="클래식", desc="예전 모양 · 외곽선", texture=CLASSIC_TEX, gloss=nil, bottomPad=0.05,
              rim="Interface\\AddOns\\NiniTools\\Media\\ImportantAlert_Rim.tga" },
  SLANT   = { label="기울임", desc="입체 결 · 광택", texture=PREMIUM_TEX, gloss=PREMIUM_GLOSS, bottomPad=0.13,
              rim="Interface\\AddOns\\NiniTools\\Media\\ImportantAlert_Premium_Rim.tga" },
}
NT.IMPORTANT_CAST_STYLES = {
  PREMIUM = {
    label="기본형", desc="제자리 고정", motion="static", pop="zoom",
    texture=PREMIUM_TEX, gloss=PREMIUM_GLOSS,
    iconSize=72, scaleAmp=0, period=1.00,
    low={1.00,0.55,0.05}, high={1.00,0.16,0.60}, colorPeriod=0.60,
  },
  PULSE = {
    label="펄스형", desc="두근두근", motion="heartbeat", pop="zoom",
    texture=PREMIUM_TEX, gloss=PREMIUM_GLOSS,
    iconSize=72, scaleAmp=0.14, period=0.90,
    low={1.00,0.55,0.05}, high={1.00,0.16,0.60}, colorPeriod=0.90,
  },
  EMPHASIS = {
    label="강조형", desc="크게 부풀기", motion="swell", pop="zoom",
    texture=PREMIUM_TEX, gloss=PREMIUM_GLOSS,
    iconSize=80, scaleAmp=0.18, period=1.00,
    low={1.00,0.55,0.05}, high={1.00,0.16,0.60}, colorPeriod=1.00,
  },
}
for _,st in pairs(NT.IMPORTANT_CAST_STYLES) do st.rimAlpha=0.60 end   -- 흰 외곽선 불투명도 60%
-- 예전 이름(DEFAULT = 옛 기본형)으로 저장된 설정은 새 기본형으로 읽는다.
NT.IMPORTANT_CAST_STYLE_ALIASES = { DEFAULT="PREMIUM" }

local function nt_clamp01(x) if x<0 then return 0 elseif x>1 then return 1 end return x end
local function nt_smooth(x) x=nt_clamp01(x) return x*x*(3-2*x) end
local function nt_easeOutCubic(x) x=nt_clamp01(x) local y=1-x return 1-y*y*y end
local function nt_easeOutBack(x) x=nt_clamp01(x) local c1=1.40 local c3=c1+1 local y=x-1 return 1+c3*y*y*y+c1*y*y end
local function nt_bump(x,c,w)
  -- smooth single beat centred in [c, c+w]: 0 -> 1 -> 0 with zero slope at both ends
  if x<c or x>c+w then return 0 end
  local s=math.sin(math.pi*(x-c)/w)
  return s*s
end

-- One frame of the important-cast marker.  elapsed = seconds since the cast started,
-- fading = seconds since the cast ended (nil while casting).  Shared by the nameplate
-- marker and the settings preview so both always look the same.
function NT:ImportantCastFrame(preset,now,elapsed,fading)
  preset=preset or self.IMPORTANT_CAST_STYLES.PREMIUM
  now=tonumber(now) or (GetTime and GetTime() or 0)
  local period=tonumber(preset.period) or 1.20
  local ph=(now%period)/period
  local motion=preset.motion or "breathe"
  local amp=tonumber(preset.scaleAmp) or 0.08
  local wave=0.5-0.5*math.cos(2*math.pi*ph)        -- 0..1, 끊김 없는 숨쉬기 곡선
  local t, grow = wave, wave
  if motion=="heartbeat" then
    local beat=nt_bump(ph,0.00,0.30)+0.55*nt_bump(ph,0.32,0.30)
    grow=beat
    t=0.15+0.70*beat
  elseif motion=="static" then
    grow=0
  elseif motion=="swell" then
    -- 빨리 부풀고 천천히 돌아온다 (같은 곡선이라 끊김 없음)
    grow=nt_smooth(ph<0.35 and ph/0.35 or (1-ph)/0.65)
    t=grow
  end
  -- 2.5.6: 색은 크기와 따로 빨강→주황→노랑→주황→빨강으로 천천히 돈다 (흰 느낌표 그림에 색을 입힘)
  local cp=tonumber(preset.colorPeriod)
  if cp and cp>0 then t=0.5-0.5*math.cos(2*math.pi*((now%cp)/cp)) end
  local lo,hi=preset.low or {1,0.08,0.03},preset.high or {1,0.92,0.12}
  local r,g,b=lo[1]+(hi[1]-lo[1])*t, lo[2]+(hi[2]-lo[2])*t, lo[3]+(hi[3]-lo[3])*t
  local alpha, popScale = 1, 1
  elapsed=tonumber(elapsed)
  local zoom=preset.pop=="zoom"
  if zoom and elapsed and elapsed<0.14 then
    -- 2.6.0 고급형: 2.2배 크기로 반투명하게 나타나 0.14초 만에 제자리로 내려앉음
    local e=nt_easeOutCubic(elapsed/0.14)
    popScale=2.2-1.2*e
    alpha=0.30+0.70*e
  elseif not zoom and elapsed and elapsed<0.22 then
    popScale=0.60+0.40*nt_easeOutBack(elapsed/0.22)   -- 작게 시작해서 살짝 튀며 제자리
    alpha=nt_smooth(elapsed/0.16)
  end
  fading=tonumber(fading)
  local fadeLen=zoom and 0.15 or 0.18
  if fading then
    local p=nt_smooth(fading/fadeLen)
    alpha=alpha*(1-p)
    popScale=popScale*(1-(zoom and 0.50 or 0.12)*p)   -- 고급형은 절반 크기로 작아지며 사라짐
  end
  return {
    r=r,g=g,b=b,
    iconAlpha=1,
    iconScale=(1+amp*grow)*popScale,
    -- 2.6.6 흰 테두리: 글자 바깥을 따라 아주 얇게 · 글자와 같은 크기로 겹침 · 불투명도 60% 고정
    glowAlpha=preset.rim and (tonumber(preset.rimAlpha) or 0.6) or 0,
    glowScale=(1+amp*grow)*popScale,
    gr=1, gg=1, gb=1,
    ringScale=nil, ringAlpha=0,        -- 파동 복사본도 쓰지 않음
    alpha=alpha,
    done=fading~=nil and fading>=fadeLen,
  }
end

-- 2.6.6: GetImportantCastStyle(움직임, 그림, 흰 테두리) → 그림·테두리를 입힌 복사본 (같은 조합은 재사용)
NT._importantCastStyleCache = NT._importantCastStyleCache or {}
function NT:GetImportantCastStyle(id,shape,rim)
  id=type(id)=="string" and id:upper() or "PREMIUM"
  id=(self.IMPORTANT_CAST_STYLE_ALIASES and self.IMPORTANT_CAST_STYLE_ALIASES[id]) or id
  if not self.IMPORTANT_CAST_STYLES[id] then id="PREMIUM" end
  shape=type(shape)=="string" and shape:upper() or "CLASSIC"
  if not self.IMPORTANT_CAST_SHAPES[shape] then shape="CLASSIC" end
  rim=(rim~=false)
  local key=id.."|"..shape.."|"..(rim and "1" or "0")
  local cached=self._importantCastStyleCache[key]
  if cached then return cached,id,shape end
  local base,sh=self.IMPORTANT_CAST_STYLES[id],self.IMPORTANT_CAST_SHAPES[shape]
  local out={}
  for k,v in pairs(base) do out[k]=v end
  out.texture,out.gloss,out.bottomPad,out.shape=sh.texture,sh.gloss,sh.bottomPad,shape
  out.rim=rim and sh.rim or nil
  self._importantCastStyleCache[key]=out
  return out,id,shape
end

function NT:GetAlertPulse(now)
  local style=self.ALERT_STYLE
  local period=tonumber(style.period) or 1.40
  now=tonumber(now) or (GetTime and GetTime() or 0)
  local phase=((now % period)/period)*2*math.pi
  return (math.sin(phase-(math.pi/2))+1)*0.5
end

function NT:GetAlertColor(now)
  local style=self.ALERT_STYLE
  local t=self:GetAlertPulse(now)
  local lo,hi=style.low,style.high
  return lo[1]+(hi[1]-lo[1])*t, lo[2]+(hi[2]-lo[2])*t, lo[3]+(hi[3]-lo[3])*t, t
end

local defaults = {
  minimapHide = false,
  minimapAngle = 225,
  lastPage = "GOLD",
  goldBackup = {},
}

local function copyDefaultValue(value)
  if type(value)~="table" then return value end
  local copy={}
  for k,v in pairs(value) do copy[k]=copyDefaultValue(v) end
  return copy
end

local function mergeDefaults(dst, src)
  dst = type(dst)=="table" and dst or {}
  for k,v in pairs(src) do
    if dst[k]==nil then dst[k]=copyDefaultValue(v) end
  end
  return dst
end

function NT:GetDB()
  self:BindModuleDB()
  NiniToolsDB = mergeDefaults(NiniToolsDB, defaults)
  return NiniToolsDB
end

function NT:Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff00cfffNiniTools|r "..tostring(msg))
end

function NT:IsAddonLoaded(name)
  if C_AddOns and C_AddOns.IsAddOnLoaded then
    return C_AddOns.IsAddOnLoaded(name)
  end
  if IsAddOnLoaded then return IsAddOnLoaded(name) end
  return false
end

function NT:CallSlash(key, text)
  local f = SlashCmdList and SlashCmdList[key]
  if type(f)=="function" then
    local ok, err = pcall(f, text or "")
    if not ok then self:Print("실행 오류: "..tostring(err)) end
    return ok
  end
  self:Print("모듈 명령을 찾지 못했습니다: "..tostring(key))
  return false
end

function NT:GetKickDB()
  return type(RogueDefensivesDB)=="table" and RogueDefensivesDB or nil
end

function NT:GetGoldDB()
  return type(NiniGoldDB)=="table" and NiniGoldDB or nil
end

local function copyGoldRecord(rec)
  if type(rec)~="table" then return nil end
  return {
    name=rec.name,
    realm=rec.realm,
    class=rec.class,
    gold=tonumber(rec.gold) or 0,
    goldVerified=rec.goldVerified and true or false,
    lastSeen=tonumber(rec.lastSeen) or 0,
  }
end

function NT:SyncGoldBackup()
  local ndb=self:GetDB()
  ndb.goldBackup=type(ndb.goldBackup)=="table" and ndb.goldBackup or {}

  local gdb=self:GetGoldDB()
  if not gdb then return end
  gdb.characters=type(gdb.characters)=="table" and gdb.characters or {}

  -- 검증된 라이브 스냅샷이 최우선.
  -- 이전 버전에서 만들어진 "0골드 + 최신 lastSeen" 레코드는 검증되지 않았다면
  -- 백업의 정상 금액을 덮어쓰지 못하게 한다.
  for key,rec in pairs(ndb.goldBackup) do
    local live=gdb.characters[key]
    local backupGold=tonumber(rec.gold) or 0
    local backupSeen=tonumber(rec.lastSeen) or 0
    local liveGold=type(live)=="table" and (tonumber(live.gold) or 0) or 0
    local liveSeen=type(live)=="table" and (tonumber(live.lastSeen) or 0) or -1
    local liveVerified=type(live)=="table" and live.goldVerified==true

    if not live
      or (not liveVerified and liveGold==0 and backupGold>0)
      or (not liveVerified and backupSeen>liveSeen) then
      gdb.characters[key]=copyGoldRecord(rec)
    end
  end

  for key,rec in pairs(gdb.characters) do
    local backup=ndb.goldBackup[key]
    local liveGold=tonumber(rec.gold) or 0
    local liveSeen=tonumber(rec.lastSeen) or 0
    local liveVerified=rec.goldVerified==true
    local backupGold=type(backup)=="table" and (tonumber(backup.gold) or 0) or 0
    local backupSeen=type(backup)=="table" and (tonumber(backup.lastSeen) or 0) or -1

    if not backup
      or liveVerified
      or (liveGold>0 and (backupGold==0 or liveSeen>=backupSeen)) then
      ndb.goldBackup[key]=copyGoldRecord(rec)
    end
  end
end

_G.NiniTools_GoldSnapshotChanged=function()
  if type(_G.NiniTools)=="table" and type(_G.NiniTools.SyncGoldBackup)=="function" then
    _G.NiniTools:SyncGoldBackup()
  end
  if type(_G.NiniTools_RefreshVisiblePage)=="function" then
    pcall(_G.NiniTools_RefreshVisiblePage)
  end
end

function NT:Comma(n)
  n = math.floor(math.abs(tonumber(n) or 0))
  local s = tostring(n)
  while true do
    local out, count = s:gsub("^(%-?%d+)(%d%d%d)", "%1,%2")
    s = out
    if count == 0 then break end
  end
  return s
end

function NT:MoneyShort(copper, signed)
  copper = tonumber(copper) or 0
  local sign = ""
  if signed then sign = copper > 0 and "+" or (copper < 0 and "-" or "") end
  local g = math.floor(math.abs(copper) / 10000)
  local s = math.floor((math.abs(copper) % 10000) / 100)
  local c = math.floor(math.abs(copper) % 100)
  if g > 0 then return sign..self:Comma(g).."골" end
  if s > 0 then return sign..s.."실" end
  return sign..c.."코"
end

-- 2.0.19: 설정창 안에서 오늘 장부를 보여주기 위한 조회 헬퍼.
-- 기록 자체는 기존 NiniGold 저장구조(NiniGoldDB.days[날짜].entries)를 그대로 읽는다.
NT.GOLD_KIND_LABEL = {
  trade_in="거래 받음", trade_out="거래 보냄",
  vendor_in="상점 판매", vendor_out="상점 구매",
  auction="경매장", mail="우편", repair="수리",
  other_in="기타 수입", other_out="기타 지출",
}

function NT:GetGoldKindLabel(kind)
  return self.GOLD_KIND_LABEL[kind or ""] or "기타"
end

function NT:GetRecentGoldEntries(days, charKey)
  local out = {}
  local db = self:GetGoldDB()
  if not db then return out end
  days = math.max(1, math.min(90, tonumber(days) or 7))

  -- Calendar-day window: today + previous (days-1) days.
  local now = time()
  local today = date("*t", now)
  local todayStart = time({year=today.year, month=today.month, day=today.day, hour=0, min=0, sec=0})
  local cutoff = todayStart - (days - 1) * 86400

  for dayKey, day in pairs(db.days or {}) do
    local list = type(day)=="table" and day.entries or nil
    if type(list)=="table" then
      for _, e in ipairs(list) do
        if type(e)=="table" and (not charKey or e.char==charKey) then
          local ts = tonumber(e.t)
          if ts and ts >= cutoff then
            out[#out+1] = e
          end
        end
      end
    end
  end

  table.sort(out, function(a,b)
    return (tonumber(a.t) or 0) > (tonumber(b.t) or 0)
  end)
  return out
end

function NT:GetGoldRangeSummary(days, charKey)
  local out={income=0,expense=0,repair=0,net=0,count=0}
  for _,e in ipairs(self:GetRecentGoldEntries(days,charKey)) do
    local amount=tonumber(e.amount) or 0
    if amount>0 then out.income=out.income+amount
    elseif amount<0 then out.expense=out.expense+math.abs(amount) end
    if e.kind=="repair" then out.repair=out.repair+math.abs(amount) end
    out.net=out.net+amount
    out.count=out.count+1
  end
  return out
end

function NT:GetGoldSummary()
  self:SyncGoldBackup()
  local db = self:GetGoldDB()
  local out = {
    tracked = 0,
    todayNet = 0, todayIncome=0, todayExpense=0,
    weekNet = 0, weekIncome=0, weekExpense=0,
    monthNet = 0, monthIncome=0, monthExpense=0,
    lifetimeNet = 0,
    repairToday = 0,
    characters = {},
  }
  if not db then return out end

  for key,c in pairs(db.characters or {}) do
    local gold = tonumber(c.gold) or 0
    out.tracked = out.tracked + gold
    out.characters[#out.characters+1] = {
      key=key,
      name=c.name or tostring(key):match("^[^-]+%-(.+)$") or key,
      realm=c.realm or "", class=c.class, gold=gold,
      goldVerified=c.goldVerified==true, lastSeen=tonumber(c.lastSeen) or 0,
    }
  end
  table.sort(out.characters, function(a,b)
    if a.gold==b.gold then return tostring(a.name)<tostring(b.name) end
    return a.gold>b.gold
  end)

  local bank=db.warband
  out.warbandGold=type(bank)=="table" and tonumber(bank.money) or nil
  out.warbandUpdated=type(bank)=="table" and tonumber(bank.updated) or nil
  out.totalWithBank=out.tracked+(out.warbandGold or 0)

  local today=self:GetGoldRangeSummary(1)
  out.todayNet=today.net
  out.todayIncome=today.income
  out.todayExpense=today.expense
  out.repairToday=today.repair

  local week=self:GetGoldRangeSummary(7)
  out.weekNet=week.net
  out.weekIncome=week.income
  out.weekExpense=week.expense

  local mk = date("%Y-%m")
  local m = db.stats and db.stats.months and db.stats.months[mk]
  local l = db.stats and db.stats.lifetime
  out.monthNet = tonumber(m and m.net) or 0
  out.monthIncome = tonumber(m and m.income) or 0
  out.monthExpense = tonumber(m and m.expense) or 0
  out.lifetimeNet = tonumber(l and l.net) or 0
  return out
end

function NT:GetMediaStatus()
  local status = {
    bigwigs = self:IsAddonLoaded("BigWigs"),
    gtfoLoaded = self:IsAddonLoaded("GTFO"),
    gtfoReady = false,
    gtfoVersion = "-",
    gtfoHigh = false,
    gtfoLow = false,
    gtfoFail = false,
    gtfoFriendly = false,
    gtfoOverride = false,
    gtfoVolume = 0,
    gtfoChannel = "?",
    gtfoRestricted = false,
    countdown = false,
    victory = false,
    bubbleSize = nil,
  }

  if type(_G.NiniMedia_GetGTFOStatus) == "function" then
    local ok, gs = pcall(_G.NiniMedia_GetGTFOStatus)
    if ok and type(gs) == "table" then
      status.gtfoLoaded = gs.loaded and true or false
      status.gtfoReady = gs.ready and true or false
      status.gtfoVersion = tostring(gs.version or "-")
      status.gtfoHigh = gs.high and true or false
      status.gtfoLow = gs.low and true or false
      status.gtfoFail = gs.fail and true or false
      status.gtfoFriendly = gs.friendly and true or false
      status.gtfoOverride = gs.override and true or false
      status.gtfoVolume = tonumber(gs.volume) or 0
      status.gtfoChannel = tostring(gs.channel or "?")
      status.gtfoRestricted = gs.restricted and true or false
    end
  end

  if type(BigWigsAPI)=="table" and type(BigWigsAPI.HasCountdown)=="function" then
    local ok,result=pcall(BigWigsAPI.HasCountdown,BigWigsAPI,"뜌미")
    status.countdown=ok and result and true or false
  end

  local LSM=(type(LibStub)=="table" or type(LibStub)=="function") and LibStub("LibSharedMedia-3.0",true)
  if LSM then
    local SOUND=LSM.MediaType and LSM.MediaType.SOUND or "sound"
    status.victory=LSM:Fetch(SOUND,"뜌미 승리",true)~=nil
  end

  if type(_G.NiniMedia_GetBubbleFontSize)=="function" then
    local ok,size=pcall(_G.NiniMedia_GetBubbleFontSize)
    if ok then status.bubbleSize=tonumber(size) end
  elseif ChatBubbleFont and ChatBubbleFont.GetFont then
    local ok,_,size=pcall(ChatBubbleFont.GetFont,ChatBubbleFont)
    if ok then status.bubbleSize=tonumber(size) end
  end
  return status
end

function NT:TestVictorySound()
  if not LibStub then return self:Print("SharedMedia를 찾지 못했습니다.") end
  local LSM = LibStub("LibSharedMedia-3.0", true)
  if not LSM then return self:Print("SharedMedia를 찾지 못했습니다.") end
  local SOUND = LSM.MediaType and LSM.MediaType.SOUND or "sound"
  local path = LSM:Fetch(SOUND, "뜌미 승리", true)
  if path and PlaySoundFile then
    local ok = pcall(PlaySoundFile, path, "Master")
    self:Print(ok and "뜌미 승리 소리 테스트" or "승리 소리 재생 실패")
  else
    self:Print("뜌미 승리 소리가 등록되지 않았습니다.")
  end
end

local eventFrame = NT.EventDispatcher:CreateProxy("Core")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(_, event, arg)
  if event=="ADDON_LOADED" and arg==ADDON_NAME then
    NT:GetDB()
    NT:SyncGoldBackup()
  elseif event=="PLAYER_LOGIN" then
    NT:GetDB()
    NT:SyncGoldBackup()
    if C_Timer and C_Timer.After then
      C_Timer.After(1, function()
        if NT.CreateMinimapButton then NT:CreateMinimapButton() end
      end)
    end
  end
end)
