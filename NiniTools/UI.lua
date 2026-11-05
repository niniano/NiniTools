local ADDON_NAME, NT = ...
if not NT then return end

local UI = {}
NT.UI = UI

UI.pages = {}
UI.navButtons = {}
-- 2.3.0: five primary tabs only.  Maintenance lives behind the title-bar gear.
UI.pageOrder = {"GOLD","KICK","NSRT","QOL","MEDIA","CAL"}
UI.pageNames = {
  KICK="Interrupt & M+",
  GOLD="Gold History",
  NSRT="NSRT 개인 메모",
  MEDIA="사운드 & Navi",
  QOL="화면 & 편의",
  CAL="계정 달력",
  TOOLS="설정 & 진단",
}
UI.pageHints = {
  KICK="차단 · 쐐기 자동화 · 중요몹 표시 · 생존기 · 전투 표시",
  GOLD="현재 보유 골드 · 기간별 수입/지출 · 최근 거래 내역",
  NSRT="Lorrgs 등에서 복사한 메모를 전문화별 NSRT 개인 메모로 전달",
  MEDIA="GTFO · 효과음 · CallMe · 마우스 Navi",
  QOL="그래픽 · 목적지 · 말풍선 · 던전 검색 · 미니맵",
  CAL="캐릭별 달력 초대 모아보기 · 날짜 메모 · 각 캐릭 접속할 때 자동 동기화",
  TOOLS="버전 · 연동 상태 · 유지관리",
}

local function RGB(hex)
  hex=hex:gsub("#","")
  return tonumber(hex:sub(1,2),16)/255, tonumber(hex:sub(3,4),16)/255, tonumber(hex:sub(5,6),16)/255
end

local function clamp(v,lo,hi)
  v=tonumber(v) or lo
  if v<lo then return lo end
  if v>hi then return hi end
  return v
end

local BRAND_GOLD={RGB("F4B23A")}
local BRAND_LIGHT={RGB("E9EDF2")}

local C = {
  bg={RGB("0A0D11")},
  sidebar={RGB("0F1318")},
  panel={RGB("131920")},
  panel2={RGB("181F27")},
  border={RGB("242D36")},
  text={0.94,0.97,1},
  muted={0.49,0.58,0.66},
  accent={
    (NT.ACCENT and NT.ACCENT[1]) or 0,
    (NT.ACCENT and NT.ACCENT[2]) or 207/255,
    (NT.ACCENT and NT.ACCENT[3]) or 1
  },
  good={0.35,0.9,0.55},
  warn={1,0.72,0.25},
  bad={1,0.35,0.35},
}
UI.C = C -- 2.5.8: 계정 달력 화면이 같은 색을 쓴다

function UI:ColorText(text, color)
  local r,g,b=color[1],color[2],color[3]
  return string.format("|cff%02x%02x%02x%s|r", r*255,g*255,b*255,tostring(text))
end

function UI:Backdrop(frame, color, border)
  frame:SetBackdrop({
    bgFile="Interface\\Buttons\\WHITE8x8",
    edgeFile="Interface\\Buttons\\WHITE8x8",
    edgeSize=1,
  })
  frame:SetBackdropColor(color[1],color[2],color[3],0.96)
  frame:SetBackdropBorderColor(border[1],border[2],border[3],0.9)
end

function UI:GoldColor(amount)
  amount = tonumber(amount) or 0
  if amount > 0 then return C.good end
  if amount < 0 then return C.bad end
  return C.muted
end

function UI:MoneyInline(copper, signed)
  copper = tonumber(copper) or 0
  local sign = ""
  if signed then
    sign = copper > 0 and "+" or (copper < 0 and "-" or "")
  end
  local g = math.floor(math.abs(copper) / 10000)
  local s = math.floor((math.abs(copper) % 10000) / 100)
  local c = math.floor(math.abs(copper) % 100)
  return string.format("%s%s |TInterface\\MoneyFrame\\UI-GoldIcon:13:13:0:0|t %d |TInterface\\MoneyFrame\\UI-SilverIcon:13:13:0:0|t %d |TInterface\\MoneyFrame\\UI-CopperIcon:13:13:0:0|t", sign, NT:Comma(g), s, c)
end

function UI:SingleLine(fs)
  if not fs then return fs end
  if fs.SetWordWrap then fs:SetWordWrap(false) end
  if fs.SetNonSpaceWrap then fs:SetNonSpaceWrap(false) end
  if fs.SetMaxLines then fs:SetMaxLines(1) end
  return fs
end

function UI:Font(parent, size, text, color)
  size = size <= 9 and 12 or (size <= 11 and 14 or (size <= 13 and 15 or size))
  local fs=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
  local path = NT:BodyFont()
  if not pcall(fs.SetFont,fs,path,size,"OUTLINE") then pcall(fs.SetFont,fs,STANDARD_TEXT_FONT,size,"OUTLINE") end
  fs:SetText(text or "")
  local c=color or C.text
  fs:SetTextColor(c[1],c[2],c[3],1)
  return fs
end

function UI:SetAccentColor(r,g,b)
  C.accent[1],C.accent[2],C.accent[3]=r or C.accent[1],g or C.accent[2],b or C.accent[3]
end

function UI:GearButton(parent, tooltipText, fn)
  local b=CreateFrame("Button",nil,parent)
  b:SetSize(30,30)

  local icon=b:CreateTexture(nil,"ARTWORK")
  icon:SetSize(24,24)
  icon:SetPoint("CENTER")
  -- Brand-only settings button: transparent button surface + round N icon.
  icon:SetTexture((NT.GetBrandRoundIcon and NT:GetBrandRoundIcon()) or NT:GetBrandIcon(true))
  icon:SetTexCoord(0,1,0,1)
  icon:SetVertexColor(1,1,1,1)
  icon:SetAlpha(.90)
  b.icon=icon

  b:SetScript("OnEnter",function(self)
    self.icon:SetAlpha(1)
    if tooltipText and GameTooltip then
      GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
      GameTooltip:AddLine(tooltipText,1,1,1)
      GameTooltip:Show()
    end
  end)
  b:SetScript("OnLeave",function(self)
    self.icon:SetAlpha(.90)
    if GameTooltip then GameTooltip:Hide() end
  end)
  b:SetScript("OnClick",fn)
  return b
end

function UI:BuildSubNav(parent, items, defaultId)
  -- The page itself is the scroll child of NewPage().  Keep the sub-navigation
  -- on the viewport so it stays visible while the settings on the right move.
  -- This also avoids a second nested scrollbar for the kick page.
  local host=parent.viewport or parent
  local nav=CreateFrame("Frame",nil,host,"BackdropTemplate")
  nav:SetPoint("TOPLEFT",host,"TOPLEFT",8,-8)
  nav:SetPoint("BOTTOMLEFT",host,"BOTTOMLEFT",8,8)
  nav:SetWidth(158)
  self:Backdrop(nav,C.sidebar,C.border)
  nav:SetBackdropColor(C.sidebar[1],C.sidebar[2],C.sidebar[3],0.70)
  nav:SetBackdropBorderColor(C.border[1],C.border[2],C.border[3],0.55)
  if nav.SetFrameLevel then nav:SetFrameLevel(20) end
  -- Do not let wheel input over the fixed menu move the right-hand page.
  if nav.EnableMouseWheel then
    nav:EnableMouseWheel(true)
    nav:SetScript("OnMouseWheel",function() end)
  end
  parent.subNav=nav

  local body=CreateFrame("Frame",nil,parent)
  -- Anchor both body edges to the scroll child itself.  Using the fixed nav as
  -- a vertical anchor would pin the body's top while the page is scrolling.
  body:SetPoint("TOPLEFT",parent,"TOPLEFT",174,-8)
  body:SetPoint("BOTTOMRIGHT",-8,8)

  parent.subPages={}
  parent.subButtons={}
  parent.currentSub=nil

  local caption=self:Font(nav,8,"세부 설정",C.muted)
  caption:SetPoint("TOPLEFT",12,-13)

  for i,item in ipairs(items) do
    local id,label=item[1],item[2]
    local b=CreateFrame("Button",nil,nav)
    b:SetPoint("TOPLEFT",6,-34-(i-1)*38)
    b:SetSize(146,36)
    b.id=id

    b.bg=b:CreateTexture(nil,"BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetColorTexture(C.panel2[1],C.panel2[2],C.panel2[3],0)
    b.label=self:Font(b,10,label,C.muted)
    b.label:SetPoint("LEFT",13,0)

    b.bar=b:CreateTexture(nil,"ARTWORK")
    b.bar:SetColorTexture(C.accent[1],C.accent[2],C.accent[3],1)
    b.bar:SetPoint("TOPLEFT",2,-7)
    b.bar:SetPoint("BOTTOMLEFT",2,7)
    b.bar:SetWidth(2)
    b.bar:Hide()

    b:SetScript("OnClick",function(self) parent:ShowSub(self.id) end)
    b:SetScript("OnEnter",function(self)
      if parent.currentSub~=self.id then
        self.bg:SetColorTexture(C.panel2[1],C.panel2[2],C.panel2[3],0.42)
        self.label:SetTextColor(C.text[1],C.text[2],C.text[3],1)
      end
    end)
    b:SetScript("OnLeave",function() parent:RefreshSubNav() end)
    parent.subButtons[id]=b

    local pg=CreateFrame("Frame",nil,body)
    pg:SetAllPoints()
    pg:Hide()
    parent.subPages[id]=pg
  end

  function parent:RefreshSubNav()
    for id,b in pairs(self.subButtons) do
      local active=id==self.currentSub
      b.bar:SetShown(active)
      if active then
        b.bg:SetColorTexture(C.accent[1],C.accent[2],C.accent[3],0.10)
        b.label:SetTextColor(C.accent[1],C.accent[2],C.accent[3],1)
      else
        b.bg:SetColorTexture(C.panel2[1],C.panel2[2],C.panel2[3],0)
        b.label:SetTextColor(C.muted[1],C.muted[2],C.muted[3],1)
      end
    end
  end

  function parent:ShowSub(id)
    id=self.subPages[id] and id or defaultId or items[1][1]
    for sid,pg in pairs(self.subPages) do pg:SetShown(sid==id) end
    self.currentSub=id
    self.contentHeight=self.subHeights and self.subHeights[id]
    if self.Layout then self.Layout() end
    if self.ScrollToTop then self.ScrollToTop() end
    self:RefreshSubNav()
    local db=NT:GetDB()
  end

  return body,parent.subPages
end

function UI:Button(parent, text, width, height, fn)
  local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
  b:SetSize(width or 130,height or 30)
  self:Backdrop(b,C.panel2,C.border)
  b:SetBackdropColor(C.panel2[1],C.panel2[2],C.panel2[3],0.72)
  b:SetBackdropBorderColor(C.border[1],C.border[2],C.border[3],0.82)

  b.label=self:Font(b,11,text,C.text)
  b.label:SetPoint("CENTER")
  b:SetWidth(math.max(width or 130,b.label:GetStringWidth()+24))

  b:SetScript("OnEnter",function(self)
    self:SetBackdropColor(C.panel2[1]+.02,C.panel2[2]+.02,C.panel2[3]+.02,0.95)
    self:SetBackdropBorderColor(C.accent[1],C.accent[2],C.accent[3],0.95)
    self.label:SetTextColor(C.accent[1],C.accent[2],C.accent[3],1)
  end)
  b:SetScript("OnLeave",function(self)
    self:SetBackdropColor(C.panel2[1],C.panel2[2],C.panel2[3],0.72)
    self:SetBackdropBorderColor(C.border[1],C.border[2],C.border[3],0.82)
    self.label:SetTextColor(C.text[1],C.text[2],C.text[3],1)
  end)
  b:SetScript("OnClick",fn)
  return b
end

function UI:Toggle(parent, label, key, getDB, onChanged, y)
  local row=CreateFrame("Button",nil,parent)
  row:SetPoint("TOPLEFT",18,y)
  row:SetPoint("TOPRIGHT",-18,y)
  row:SetHeight(38)

  row.hover=row:CreateTexture(nil,"BACKGROUND")
  row.hover:SetAllPoints()
  row.hover:SetColorTexture(C.panel2[1],C.panel2[2],C.panel2[3],0)
  row.hover:Hide()

  row.text=self:Font(row,11,label,C.text)
  row.text:SetPoint("LEFT",4,0)

  row.divider=row:CreateTexture(nil,"BORDER")
  row.divider:SetColorTexture(C.border[1],C.border[2],C.border[3],0.48)
  row.divider:SetPoint("BOTTOMLEFT",4,0)
  row.divider:SetPoint("BOTTOMRIGHT",-4,0)
  row.divider:SetHeight(1)

  -- Rounded Smart-Reminders-style pill switch.
  row.switch=CreateFrame("Frame",nil,row)
  row.switch:SetSize(42,20)
  row.switch:SetPoint("RIGHT",-4,0)

  row.trackMid=row.switch:CreateTexture(nil,"BACKGROUND")
  row.trackMid:SetTexture("Interface\\Buttons\\WHITE8x8")
  row.trackMid:SetSize(24,18)
  row.trackMid:SetPoint("CENTER")

  row.trackLeft=row.switch:CreateTexture(nil,"BACKGROUND")
  row.trackLeft:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
  row.trackLeft:SetSize(18,18)
  row.trackLeft:SetPoint("LEFT",0,0)

  row.trackRight=row.switch:CreateTexture(nil,"BACKGROUND")
  row.trackRight:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
  row.trackRight:SetSize(18,18)
  row.trackRight:SetPoint("RIGHT",0,0)

  row.knob=row.switch:CreateTexture(nil,"ARTWORK")
  row.knob:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
  row.knob:SetSize(14,14)

  row.SetTrackColor=function(self,r,g,b,a)
    self.trackMid:SetVertexColor(r,g,b,a)
    self.trackLeft:SetVertexColor(r,g,b,a)
    self.trackRight:SetVertexColor(r,g,b,a)
  end

  row.GetValue=function()
    local db=getDB and getDB()
    return db and db[key]~=false
  end

  row.Refresh=function(self)
    local on=self.GetValue()
    self.knob:ClearAllPoints()
    if on then
      self.knob:SetPoint("RIGHT",-3,0)
      self:SetTrackColor(C.accent[1],C.accent[2],C.accent[3],0.92)
      self.knob:SetVertexColor(1,1,1,1)
      self.text:SetTextColor(C.text[1],C.text[2],C.text[3],1)
    else
      self.knob:SetPoint("LEFT",3,0)
      self:SetTrackColor(C.muted[1]*.55,C.muted[2]*.55,C.muted[3]*.55,0.92)
      self.knob:SetVertexColor(.78,.81,.84,1)
      self.text:SetTextColor(C.muted[1]+.22,C.muted[2]+.22,C.muted[3]+.22,1)
    end
  end

  row:SetScript("OnEnter",function(self)
    self.hover:Show()
    self.hover:SetColorTexture(C.panel2[1],C.panel2[2],C.panel2[3],0.46)
  end)
  row:SetScript("OnLeave",function(self) self.hover:Hide() end)

  row:SetScript("OnClick",function(self)
    local db=getDB and getDB()
    if not db then NT:Print("설정 DB가 아직 준비되지 않았습니다."); return end
    local nv=not (db[key]~=false)
    db[key]=nv
    if onChanged then onChanged(nv,db) end
    self:Refresh()
    UI:RefreshVisiblePage()
  end)
  row:Refresh()
  return row
end

-- 2.0.20: 예전 니니차단 창의 "− 값 +" 조절 행을 니니툴즈 스타일로 옮긴 것.
-- 2.0.23: 스크롤되는 선택 목록. 음원/보이스처럼 항목 수를 알 수 없을 때 쓴다.
-- getItems 는 {text=,value=,selected=} 배열을 돌려준다.
function UI:PickList(parent, y, height, rowCount, getItems, onPick, onPreview)
  local list=CreateFrame("Frame",nil,parent)
  list:SetPoint("TOPLEFT",18,y)
  list:SetPoint("TOPRIGHT",-18,y)
  list:SetHeight(height)
  list:EnableMouseWheel(true)
  list.offset=0
  list.rows={}

  for i=1,rowCount do
    local row=CreateFrame("Button",nil,list,"BackdropTemplate")
    row:SetPoint("TOPLEFT",0,-(i-1)*22)
    row:SetPoint("TOPRIGHT",0,-(i-1)*22)
    row:SetHeight(21)
    self:Backdrop(row,C.panel2,C.border)
    row:SetBackdropColor(0,0,0,0)
    row:SetBackdropBorderColor(0,0,0,0)
    row.label=self:Font(row,11,"",C.text)
    row.label:SetPoint("LEFT",6,0)
    row.label:SetPoint("RIGHT",-58,0)
    row.label:SetJustifyH("LEFT")
    local play=self:Button(row,"듣기",46,17,function()
      if row.itemValue~=nil and onPreview then onPreview(row.itemValue) end
    end)
    play:SetPoint("RIGHT",-4,0)
    row.play=play
    row:SetScript("OnClick",function(self)
      if self.itemValue==nil then return end
      onPick(self.itemValue)
      list:JumpToSelected()
      UI:RefreshVisiblePage()
    end)
    row:SetScript("OnEnter",function(self)
      if self.itemValue~=nil and not self.isSelected then
        self:SetBackdropColor(C.panel2[1],C.panel2[2],C.panel2[3],0.75)
      end
    end)
    row:SetScript("OnLeave",function(self)
      if not self.isSelected then self:SetBackdropColor(0,0,0,0) end
    end)
    list.rows[i]=row
  end

  list.empty=self:Font(list,11,"",C.muted)
  list.empty:SetPoint("TOPLEFT",6,-4)
  list.empty:SetPoint("RIGHT",-6,0)
  list.empty:SetJustifyH("LEFT")

  list:SetScript("OnMouseWheel",function(self,delta)
    local total=self.total or 0
    self.offset=clamp(self.offset-delta*3,0,math.max(0,total-rowCount))
    self:Render(true)
  end)

  -- 2.0.25: 선택된 항목으로 스크롤을 맞추는 시점을 명확히 나눴다.
  -- · 목록을 처음 열 때, 또는 새 항목을 고를 때 → 그 위치로 자동으로 맞춘다.
  -- · 휠로 직접 스크롤할 때, 또는 그냥 다시 그릴 때 → 지금 스크롤 위치를 그대로 둔다.
  -- (이전에는 매번 다시 그릴 때마다 선택 위치로 되돌아가서, 휠을 굴려도
  --  화면이 그 자리에서 튕겨 나오는 것처럼 안 움직이는 문제가 있었다.)
  list.JumpToSelected=function(self)
    local items=getItems() or {}
    for i,it in ipairs(items) do
      if it.selected then
        self.offset=clamp(i-1-math.floor(rowCount/2),0,math.max(0,#items-rowCount))
        return
      end
    end
  end

  list.Render=function(self, keepScroll)
    local items=getItems() or {}
    self.total=#items
    if not keepScroll and not self.opened then self:JumpToSelected() end
    self.opened=true
    self.offset=clamp(self.offset,0,math.max(0,#items-rowCount))
    for i=1,rowCount do
      local row=self.rows[i]
      local it=items[self.offset+i]
      if it then
        row.itemValue=it.value
        row.isSelected=it.selected and true or false
        row.label:SetText(it.text or "")
        if it.selected then
          row:SetBackdropColor(C.accent[1]*.20,C.accent[2]*.20,C.accent[3]*.20,1)
          row:SetBackdropBorderColor(C.accent[1],C.accent[2],C.accent[3],0.85)
          row.label:SetTextColor(C.accent[1],C.accent[2],C.accent[3],1)
        else
          row:SetBackdropColor(0,0,0,0)
          row:SetBackdropBorderColor(0,0,0,0)
          row.label:SetTextColor(C.text[1],C.text[2],C.text[3],1)
        end
        row:Show()
      else
        row.itemValue=nil
        row.isSelected=false
        row:Hide()
      end
    end
    self.empty:SetShown(#items==0)
    if #items==0 then self.empty:SetText("고를 수 있는 항목이 없습니다.") end
    return #items
  end

  list.Refresh=list.Render
  return list
end

function UI:AdjustRow(parent, label, y, getText, onStep)
  local row=CreateFrame("Frame",nil,parent)
  row:SetPoint("TOPLEFT",18,y)
  row:SetPoint("TOPRIGHT",-18,y)
  row:SetHeight(30)

  local name=self:Font(row,11,label,C.text)
  name:SetPoint("LEFT",4,0)

  local value=self:Font(row,11,"",C.accent)
  value:SetPoint("RIGHT",-96,0)
  value:SetJustifyH("RIGHT")
  row.value=value

  local minus=self:Button(row,"−",34,24,function() onStep(-1); UI:RefreshVisiblePage() end)
  minus:SetPoint("RIGHT",-48,0)
  local plus=self:Button(row,"+",34,24,function() onStep(1); UI:RefreshVisiblePage() end)
  plus:SetPoint("RIGHT",-4,0)

  row.Refresh=function(self) self.value:SetText(getText() or "") end
  return row
end

-- 2.3.0 RC2.1: proposal-parity slider row with draggable thumb.
function UI:SliderRow(parent, label, y, minValue, maxValue, step, getValue, onValue, formatValue, opts)
  local row=CreateFrame("Frame",nil,parent)
  row:SetPoint("TOPLEFT",18,y)
  row:SetPoint("TOPRIGHT",-18,y)
  row:SetHeight(34)

  local name=self:Font(row,11,label,C.text)
  name:SetPoint("LEFT",4,0)

  local value=self:Font(row,10,"",C.text)
  value:SetPoint("RIGHT",-4,0)
  value:SetWidth(58)
  value:SetJustifyH("RIGHT")
  row.value=value

  -- 2.6.3: opts.editable → 오른쪽 숫자를 직접 입력하는 칸 (Naowh Smart Reminders처럼). Enter로 적용.
  local box
  if type(opts)=="table" and opts.editable then
    value:Hide()
    local bg=CreateFrame("Frame",nil,row,"BackdropTemplate")
    bg:SetPoint("RIGHT",-4,0); bg:SetSize(58,24)
    self:Backdrop(bg,C.panel2,C.border)
    box=CreateFrame("EditBox",nil,bg)
    box:SetPoint("TOPLEFT",4,-2); box:SetPoint("BOTTOMRIGHT",-4,2)
    box:SetAutoFocus(false); box:SetFontObject(ChatFontNormal); box:SetJustifyH("CENTER"); box:SetMaxLetters(5)
    row.box=box
    value=bg   -- 슬라이더 오른쪽 끝을 입력 칸에 맞춘다
  end

  -- Use Blizzard's proven slider template here.  The custom bare Slider used
  -- before could lose the cursor/drag relationship inside scaled/scrolling UI.
  local slider=CreateFrame("Slider",nil,row,"OptionsSliderTemplate")
  slider:SetOrientation("HORIZONTAL")
  slider:SetPoint("LEFT",112,0)
  slider:SetPoint("RIGHT",value,"LEFT",-14,0)
  slider:SetHeight(18)
  slider:SetMinMaxValues(minValue,maxValue)
  slider:SetValueStep(step or 1)
  if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
  if slider.Low then slider.Low:SetText("") end
  if slider.High then slider.High:SetText("") end
  if slider.Text then slider.Text:SetText("") end

  local thumb=slider:CreateTexture(nil,"OVERLAY")
  thumb:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
  thumb:SetSize(16,16)
  thumb:SetVertexColor(.95,.97,1,1)
  slider:SetThumbTexture(thumb)
  row.slider=slider

  local thumbHalf=8
  local track=slider:CreateTexture(nil,"BACKGROUND")
  track:SetHeight(4)
  track:SetPoint("LEFT",thumbHalf,0)
  track:SetPoint("RIGHT",-thumbHalf,0)
  track:SetColorTexture(C.border[1]+.08,C.border[2]+.08,C.border[3]+.08,1)

  local fill=slider:CreateTexture(nil,"ARTWORK")
  fill:SetHeight(4)
  fill:SetPoint("LEFT",thumbHalf,0)
  fill:SetColorTexture(C.accent[1],C.accent[2],C.accent[3],1)
  row.fill=fill

  local stepValue=tonumber(step) or 1
  local function normalize(v)
    v=tonumber(v) or minValue
    v=math.max(minValue,math.min(maxValue,v))
    if stepValue>0 then
      v=minValue+math.floor(((v-minValue)/stepValue)+.5)*stepValue
      v=math.max(minValue,math.min(maxValue,v))
    end
    return v
  end

  local function redraw(v)
    v=normalize(v)
    local lo,hi=slider:GetMinMaxValues()
    local frac=(hi>lo) and ((v-lo)/(hi-lo)) or 0
    frac=math.max(0,math.min(1,frac))
    local usable=math.max(1,(slider:GetWidth() or 1)-(thumbHalf*2))
    fill:SetWidth(math.max(1,usable*frac))
    if box then
      if not box:HasFocus() then box:SetText(tostring(math.floor(v+.5))) end
    else
      value:SetText(formatValue and formatValue(v) or tostring(v))
    end
  end
  if box then
    box:SetScript("OnEnterPressed",function(self)
      local v=tonumber((self:GetText() or ""):match("^%s*(-?%d+)"))
      self:ClearFocus()
      if v then slider:SetValue(normalize(v)) end   -- OnValueChanged가 onValue를 부른다
      redraw(slider:GetValue() or minValue)
    end)
    box:SetScript("OnEscapePressed",function(self) self:ClearFocus(); redraw(slider:GetValue() or minValue) end)
    box:SetScript("OnEditFocusLost",function() redraw(slider:GetValue() or minValue) end)
  end

  -- Never rebuild the whole page while the thumb is moving.  The value callback
  -- updates the live feature directly; only the lightweight text/fill is redrawn.
  slider:HookScript("OnValueChanged",function(self,v)
    local snapped=normalize(v)
    redraw(snapped)
    if row._refreshing then return end
    onValue(snapped)
  end)
  slider:HookScript("OnSizeChanged",function() redraw(slider:GetValue() or minValue) end)

  -- Refresh section summaries only after the drag has ended.  HookScript keeps
  -- the Blizzard template's own mouse handling intact.
  slider:HookScript("OnMouseUp",function()
    C_Timer.After(0,function()
      if UI.frame and UI.frame:IsShown() then UI:RefreshVisiblePage() end
    end)
  end)

  row.Refresh=function(self)
    local v=normalize(getValue())
    self._refreshing=true
    self.slider:SetValue(v)
    self._refreshing=false
    redraw(v)
  end
  row:Refresh()
  return row
end

-- Popup is parented to the main window, not the scroll child, so it never gets clipped.
function UI:DropdownRow(parent, label, y, items, getValue, onPick)
  local row=CreateFrame("Frame",nil,parent)
  row:SetPoint("TOPLEFT",18,y)
  row:SetPoint("TOPRIGHT",-18,y)
  row:SetHeight(34)

  local name=self:Font(row,11,label,C.text)
  name:SetPoint("LEFT",4,0)

  local btn
  btn=self:Button(row,"",172,28,function()
    if not UI.frame then return end
    if row.popup and row.popup:IsShown() then row.popup:Hide(); return end
    if UI.activeDropdown and UI.activeDropdown~=row.popup then UI.activeDropdown:Hide() end
    if not row.popup then
      local popup=CreateFrame("Frame",nil,UI.frame,"BackdropTemplate")
      popup:SetFrameStrata("DIALOG")
      popup:SetFrameLevel((UI.frame:GetFrameLevel() or 1)+80)
      UI:Backdrop(popup,C.panel2,C.border)
      popup:SetWidth(172)
      popup:SetHeight(#items*30+8)
      popup.rows={}
      for i,item in ipairs(items) do
        local opt=CreateFrame("Button",nil,popup,"BackdropTemplate")
        opt:SetPoint("TOPLEFT",4,-4-(i-1)*30)
        opt:SetPoint("TOPRIGHT",-4,-4-(i-1)*30)
        opt:SetHeight(28)
        UI:Backdrop(opt,C.panel2,C.border)
        opt:SetBackdropColor(0,0,0,0)
        opt:SetBackdropBorderColor(0,0,0,0)
        opt.label=UI:Font(opt,10,item.text or tostring(item.value),C.text)
        opt.label:SetPoint("LEFT",8,0)
        opt.item=item
        opt:SetScript("OnEnter",function(self) self:SetBackdropColor(C.accent[1],C.accent[2],C.accent[3],0.12) end)
        opt:SetScript("OnLeave",function(self) self:SetBackdropColor(0,0,0,0) end)
        opt:SetScript("OnClick",function(self)
          onPick(self.item.value)
          popup:Hide()
          UI.activeDropdown=nil
          UI:RefreshVisiblePage()
        end)
        popup.rows[i]=opt
      end
      popup:SetScript("OnHide",function(self) if UI.activeDropdown==self then UI.activeDropdown=nil end end)
      row.popup=popup
    end
    row.popup:ClearAllPoints()
    row.popup:SetPoint("TOPRIGHT",btn,"BOTTOMRIGHT",0,-4)
    row.popup:Show()
    UI.activeDropdown=row.popup
  end)
  btn:SetPoint("RIGHT",-4,0)
  row.button=btn
  local arrow=self:Font(btn,10,"⌄",C.muted)
  arrow:SetPoint("RIGHT",-8,0)
  btn.label:ClearAllPoints(); btn.label:SetPoint("LEFT",10,0); btn.label:SetPoint("RIGHT",-26,0); btn.label:SetJustifyH("LEFT")

  row.Refresh=function(self)
    local cur=getValue()
    local text=tostring(cur or "")
    for _,item in ipairs(items) do if item.value==cur then text=item.text or text break end end
    self.button.label:SetText(text)
  end
  row:Refresh()
  return row
end

-- Large visual choice cards used where the appearance matters more than the label.
function UI:StyleCardRow(parent, label, y, items, isActive, onPick)
  local row=CreateFrame("Frame",nil,parent)
  row:SetPoint("TOPLEFT",18,y)
  row:SetPoint("TOPRIGHT",-18,y)
  row:SetHeight(78)

  local name=self:Font(row,11,label,C.text)
  name:SetPoint("TOPLEFT",4,-2)
  row.cards={}
  local startX=112
  for i,item in ipairs(items) do
    local card=CreateFrame("Button",nil,row,"BackdropTemplate")
    card:SetSize(item.width or 96,66)
    card:SetPoint("TOPLEFT",startX+(i-1)*104,0)
    UI:Backdrop(card,C.panel2,C.border)
    card.itemValue=item.value
    card.preset=item.preset

    local iconHolder=CreateFrame("Frame",nil,card)
    iconHolder:SetSize(28,28)
    iconHolder:SetPoint("TOP",0,-7)
    local ring=iconHolder:CreateTexture(nil,"BACKGROUND")
    ring:SetTexture("Interface\\AddOns\\NiniTools\\Media\\ImportantAlert_White.tga")
    ring:SetPoint("CENTER"); ring:SetSize(28,28); ring:SetBlendMode("ADD"); ring:Hide()
    local glow=iconHolder:CreateTexture(nil,"ARTWORK")
    glow:SetTexture("Interface\\AddOns\\NiniTools\\Media\\ImportantAlert_White.tga")
    glow:SetPoint("CENTER"); glow:SetSize(34,34); glow:SetBlendMode("ADD")
    local icon=iconHolder:CreateTexture(nil,"OVERLAY")
    icon:SetTexture("Interface\\AddOns\\NiniTools\\Media\\ImportantAlert_White.tga")
    icon:SetPoint("CENTER"); icon:SetSize(28,28)
    for _,tx in ipairs({ring,glow,icon}) do
      if tx.SetSnapToPixelGrid then pcall(tx.SetSnapToPixelGrid,tx,false) end
      if tx.SetTexelSnappingBias then pcall(tx.SetTexelSnappingBias,tx,0) end
    end
    card.iconHolder=iconHolder; card.icon=icon; card.glow=glow; card.ring=ring
    -- 2.6.6: 그림(클래식/기울임)·광택·흰 외곽선을 나중에 바꿀 수 있게 SetPreset으로 다시 입힌다
    local gl=iconHolder:CreateTexture(nil,"OVERLAY",nil,7)
    gl:SetPoint("CENTER"); gl:SetSize(28,28); gl:Hide()
    card.gloss=gl
    card.SetPreset=function(self,preset)
      self.preset=preset
      if not preset then return end
      local texPath=preset.texture or "Interface\\AddOns\\NiniTools\\Media\\ImportantAlert_White.tga"
      self.icon:SetTexture(texPath); self.ring:SetTexture(texPath)
      if preset.gloss then self.gloss:SetTexture(preset.gloss); self.gloss:Show() else self.gloss:Hide() end
      if preset.rim then self.glow:SetTexture(preset.rim); self.glow:SetBlendMode("BLEND"); self.glow:Show() else self.glow:Hide() end
    end
    card:SetPreset(item.preset)

    card.label=UI:Font(card,9,item.text or "",C.text)
    card.label:SetPoint("BOTTOM",0,6)
    local dot=card:CreateTexture(nil,"OVERLAY")
    dot:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    dot:SetSize(9,9); dot:SetPoint("TOPRIGHT",-6,-6)
    card.dot=dot

    card:SetScript("OnClick",function(self) onPick(self.itemValue); UI:RefreshVisiblePage() end)
    card:SetScript("OnEnter",function(self) self:SetBackdropBorderColor(C.accent[1],C.accent[2],C.accent[3],.95) end)
    card:SetScript("OnLeave",function() row:Refresh() end)
    row.cards[i]=card
  end

  row:SetScript("OnUpdate",function(self)
    local now=GetTime()
    for _,card in ipairs(self.cards) do
      local preset=card.preset
      if preset and NT.ImportantCastFrame then
        -- 2.5.5: 카드도 실제 이름표와 같은 움직임 (기본형 숨쉬기 · 펄스형 박동 · 강조형 파동)
        -- 2.6.0: 카드도 2.5초마다 튀어나옴 → 사라짐을 반복 (고급형 움직임이 보이게)
        local cyc=now%2.5
        local f=NT:ImportantCastFrame(preset,now,cyc,cyc>=2.2 and (cyc-2.2) or nil)
        card.icon:SetSize(28*f.iconScale,28*f.iconScale)
        if card.gloss:IsShown() then card.gloss:SetSize(28*f.iconScale,28*f.iconScale); card.gloss:SetAlpha(f.iconAlpha*(f.alpha or 1)) end
        card.icon:SetVertexColor(f.r,f.g,f.b,1)
        card.icon:SetAlpha(f.iconAlpha*(f.alpha or 1))
        if card.glow:IsShown() and (f.glowAlpha or 0)>0.01 then
          local hs=28*(f.glowScale or 1)
          card.glow:SetSize(hs,hs); card.glow:SetVertexColor(f.gr or 1,f.gg or 1,f.gb or 1,1); card.glow:SetAlpha(f.glowAlpha*(f.alpha or 1))
        else
          card.glow:SetAlpha(0)
        end
        if f.ringScale and f.ringAlpha>0.01 then
          card.ring:SetSize(28*f.ringScale,28*f.ringScale)
          card.ring:SetVertexColor(f.r,f.g,f.b,1)
          card.ring:SetAlpha(f.ringAlpha)
          card.ring:Show()
        else
          card.ring:Hide()
        end
      end
    end
  end)

  row.Refresh=function(self)
    for _,card in ipairs(self.cards) do
      local on=isActive(card.itemValue)
      card:SetBackdropColor(on and C.accent[1]*.16 or C.panel2[1],on and C.accent[2]*.16 or C.panel2[2],on and C.accent[3]*.16 or C.panel2[3],1)
      card:SetBackdropBorderColor(on and C.accent[1] or C.border[1],on and C.accent[2] or C.border[2],on and C.accent[3] or C.border[3],on and 1 or .82)
      card.dot:SetVertexColor(on and C.accent[1] or C.muted[1],on and C.accent[2] or C.muted[2],on and C.accent[3] or C.muted[3],1)
      card.label:SetTextColor(on and C.accent[1] or C.text[1],on and C.accent[2] or C.text[2],on and C.accent[3] or C.text[3],1)
    end
  end
  row:Refresh()
  return row
end

-- 2.0.20: 여러 개 중 하나를 고르는 작은 버튼 묶음 (담당 징표, 로테 인원, 내 순서).
function UI:ChoiceRow(parent, label, y, items, isActive, onPick)
  local row=CreateFrame("Frame",nil,parent)
  row:SetPoint("TOPLEFT",18,y)
  row:SetPoint("TOPRIGHT",-18,y)
  row:SetHeight(34)

  local name
  if label and label~="" then
    name=self:Font(row,11,label,C.text)
    name:SetPoint("LEFT",4,0)
  end

  row.buttons={}
  local x=(label and label~="") and 96 or 4
  for i,item in ipairs(items) do
    local b=self:Button(row,item.text or "",item.width or 54,26,function()
      onPick(item.value); UI:RefreshVisiblePage()
    end)
    b:SetPoint("LEFT",x,0)
    x=x+(b:GetWidth() or 54)+6
    b.itemValue=item.value

    -- Raid marker choices are much easier to scan as the actual marker icon
    -- instead of Korean text such as 별/동글/다이아.
    if item.marker then
      b.label:SetText("")
      local icon=b:CreateTexture(nil,"ARTWORK")
      icon:SetSize(18,18)
      icon:SetPoint("CENTER")
      -- SetRaidTargetIconTexture only applies texture coordinates; the texture sheet
      -- itself must be assigned first or the button stays blank on Retail.
      icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
      if type(SetRaidTargetIconTexture)=="function" then
        SetRaidTargetIconTexture(icon,item.marker)
      else
        local idx=math.max(1,math.min(8,tonumber(item.marker) or 1))-1
        local col=idx%4
        local rowIndex=math.floor(idx/4)
        icon:SetTexCoord(col/4,(col+1)/4,rowIndex/4,(rowIndex+1)/4)
      end
      b.markerIcon=icon
      if item.tooltip then
        b:HookScript("OnEnter",function(self)
          if not GameTooltip then return end
          GameTooltip:SetOwner(self,"ANCHOR_TOP")
          GameTooltip:AddLine(item.tooltip,1,1,1)
          GameTooltip:Show()
        end)
        b:HookScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
      end
    end

    row.buttons[i]=b
  end

  row.Refresh=function(self)
    for _,b in ipairs(self.buttons) do
      local on=isActive(b.itemValue)
      b:SetBackdropColor(on and C.accent[1]*.22 or C.panel2[1],
                         on and C.accent[2]*.22 or C.panel2[2],
                         on and C.accent[3]*.22 or C.panel2[3], on and 1 or 0.72)
      b:SetBackdropBorderColor(on and C.accent[1] or C.border[1],
                               on and C.accent[2] or C.border[2],
                               on and C.accent[3] or C.border[3], on and 0.95 or 0.82)
      b.label:SetTextColor(on and C.accent[1] or C.text[1],
                           on and C.accent[2] or C.text[2],
                           on and C.accent[3] or C.text[3], 1)
    end
  end
  return row
end

function UI:Section(parent, title, subtitle, y, h)
  local f=CreateFrame("Frame",nil,parent,"BackdropTemplate")
  f:SetPoint("TOPLEFT",16,y)
  f:SetPoint("TOPRIGHT",-16,y)
  f:SetHeight(h)
  self:Backdrop(f,C.panel,C.border)
  f:SetBackdropColor(C.panel[1],C.panel[2],C.panel[3],0.68)
  f:SetBackdropBorderColor(C.border[1],C.border[2],C.border[3],0.54)

  local t=self:Font(f,10,string.upper(title or ""),C.accent)
  t:SetPoint("TOPLEFT",14,-11)

  local line=f:CreateTexture(nil,"ARTWORK")
  line:SetColorTexture(C.border[1],C.border[2],C.border[3],0.72)
  line:SetPoint("TOPLEFT",14,-30)
  line:SetPoint("TOPRIGHT",-14,-30)
  line:SetHeight(1)

  if subtitle then
    local s=self:Font(f,8,subtitle,C.muted)
    s:SetPoint("TOPLEFT",14,-36)
    s:SetPoint("RIGHT",-16,0)
    s:SetJustifyH("LEFT")
  end
  return f
end

-- 2.3.0: compact accordion used by feature-heavy pages.  The header stays
-- readable when collapsed and carries a short live state summary.
function UI:PrepareAccordionPage(page)
  if page._accordionReady then return end
  page._accordionReady=true
  page.accordions={}
  page.accordionGap=6

  function page:LayoutAccordions()
    local y=-8
    for _,section in ipairs(self.accordions) do
      section:ClearAllPoints()
      section:SetPoint("TOPLEFT",16,y)
      section:SetPoint("TOPRIGHT",-16,y)
      local h=section.headerHeight+(section.expanded and section.bodyHeight or 0)
      section:SetHeight(h)
      section.body:SetShown(section.expanded)
      -- Expanded sections used to leave a large, heavy slab of panel background.
      -- Keep the header strong while letting the detail area breathe.
      section:SetBackdropColor(C.panel[1],C.panel[2],C.panel[3],section.expanded and 0.46 or 0.64)
      section:SetBackdropBorderColor(C.border[1],C.border[2],C.border[3],section.expanded and 0.50 or 0.58)
      if section.arrow then section.arrow:SetText(section.expanded and "▲" or "▼") end
      y=y-h-self.accordionGap
    end
    self.contentHeight=math.max(1,-y+8)
    if self.Layout then self:Layout() end
  end

  function page:SetAccordion(id)
    local target
    for _,section in ipairs(self.accordions) do
      if section.id==id then target=section break end
    end
    if not target then return end
    local open=not target.expanded
    -- Classic accordion behavior: one detailed section at a time.
    for _,section in ipairs(self.accordions) do section.expanded=false end
    target.expanded=open
    self:LayoutAccordions()
  end
end

function UI:AccordionSection(page,id,title,subtitle,bodyHeight,defaultOpen)
  self:PrepareAccordionPage(page)
  local f=CreateFrame("Frame",nil,page,"BackdropTemplate")
  f.id=id
  f.headerHeight=52
  f.bodyHeight=bodyHeight or 180
  f.expanded=defaultOpen and true or false
  self:Backdrop(f,C.panel,C.border)
  f:SetBackdropColor(C.panel[1],C.panel[2],C.panel[3],0.70)
  f:SetBackdropBorderColor(C.border[1],C.border[2],C.border[3],0.62)

  local header=CreateFrame("Button",nil,f)
  header:SetPoint("TOPLEFT",0,0); header:SetPoint("TOPRIGHT",0,0); header:SetHeight(f.headerHeight)
  f.header=header

  local hover=header:CreateTexture(nil,"BACKGROUND")
  hover:SetAllPoints()
  hover:SetColorTexture(C.accent[1],C.accent[2],C.accent[3],0)
  f.headerHover=hover

  f.title=self:Font(header,11,title or "",C.text)
  f.title:SetPoint("TOPLEFT",18,-9)
  f.subtitle=self:Font(header,8,subtitle or "",C.muted)
  f.subtitle:SetPoint("TOPLEFT",18,-29); f.subtitle:SetPoint("RIGHT",-230,0); f.subtitle:SetJustifyH("LEFT")

  f.state=CreateFrame("Frame",nil,header,"BackdropTemplate")
  f.state:SetHeight(24)
  f.state:SetPoint("RIGHT",-46,0)
  self:Backdrop(f.state,C.panel2,C.border)
  f.state:SetBackdropColor(C.panel2[1],C.panel2[2],C.panel2[3],0.92)
  f.stateLabel=self:Font(f.state,9,"",C.muted)
  f.stateLabel:SetPoint("CENTER",0,0)

  f.enabledState=CreateFrame("Frame",nil,header,"BackdropTemplate")
  f.enabledState:SetSize(54,24)
  f.enabledState:SetPoint("RIGHT",-46,0)
  self:Backdrop(f.enabledState,C.panel2,C.border)
  f.enabledStateLabel=self:Font(f.enabledState,9,"ON",C.accent)
  f.enabledStateLabel:SetPoint("CENTER",0,0)
  f.enabledState:Hide()

  f.arrow=self:Font(header,14,f.expanded and "▲" or "▼",C.accent)
  f.arrow:SetPoint("RIGHT",-18,0)

  local divider=f:CreateTexture(nil,"ARTWORK")
  divider:SetColorTexture(C.border[1],C.border[2],C.border[3],0.58)
  divider:SetPoint("TOPLEFT",0,-f.headerHeight); divider:SetPoint("TOPRIGHT",0,-f.headerHeight); divider:SetHeight(1)

  local body=CreateFrame("Frame",nil,f)
  body:SetPoint("TOPLEFT",0,-f.headerHeight)
  body:SetPoint("TOPRIGHT",0,-f.headerHeight)
  body:SetHeight(f.bodyHeight)
  f.body=body

  function f:SetState(text,tone)
    text=tostring(text or "")
    self.stateLabel:SetText(text)
    local widths={ON=54,OFF=54}
    local w=widths[text] or math.max(58,math.min(190,24+#text*7))
    self.state:SetWidth(w)
    self.state:ClearAllPoints()
    if self.enabledState:IsShown() then
      self.state:SetPoint("RIGHT",self.enabledState,"LEFT",-8,0)
    else
      self.state:SetPoint("RIGHT",-46,0)
    end
    local color=C.muted
    if tone=="good" then color=C.good elseif tone=="warn" then color=C.warn elseif tone=="bad" then color=C.bad elseif tone=="accent" then color=C.accent end
    self.stateLabel:SetTextColor(color[1],color[2],color[3],1)
    self.state:SetBackdropBorderColor(color[1],color[2],color[3],0.55)
  end

  function f:SetEnabledState(on)
    self.enabledState:Show()
    local color=on and C.accent or C.muted
    self.enabledStateLabel:SetText(on and "ON" or "OFF")
    self.enabledStateLabel:SetTextColor(color[1],color[2],color[3],1)
    self.enabledState:SetBackdropBorderColor(color[1],color[2],color[3],.70)
    self.state:ClearAllPoints()
    self.state:SetPoint("RIGHT",self.enabledState,"LEFT",-8,0)
  end

  header:SetScript("OnEnter",function() hover:SetColorTexture(C.accent[1],C.accent[2],C.accent[3],0.055) end)
  header:SetScript("OnLeave",function() hover:SetColorTexture(C.accent[1],C.accent[2],C.accent[3],0) end)
  header:SetScript("OnClick",function() page:SetAccordion(id) end)

  page.accordions[#page.accordions+1]=f
  page:LayoutAccordions()
  return f
end

function UI:Card(parent, title, value, hint, x, y, w, h)
  local f=CreateFrame("Frame",nil,parent,"BackdropTemplate")
  f:SetPoint("TOPLEFT",x,y); f:SetSize(w,h)
  self:Backdrop(f,C.panel,C.border)
  f:SetBackdropColor(C.panel[1],C.panel[2],C.panel[3],0.74)
  f:SetBackdropBorderColor(C.border[1],C.border[2],C.border[3],0.68)

  local top=f:CreateTexture(nil,"ARTWORK")
  top:SetColorTexture(C.accent[1],C.accent[2],C.accent[3],0.82)
  top:SetPoint("TOPLEFT",0,0); top:SetPoint("TOPRIGHT",0,0); top:SetHeight(2)

  f.title=self:Font(f,10,title,C.muted); f.title:SetPoint("TOPLEFT",14,-14)
  f.value=self:Font(f,18,value,C.text); f.value:SetPoint("TOPLEFT",14,-38)
  f.hint=self:Font(f,9,hint or "",C.muted); f.hint:SetPoint("BOTTOMLEFT",14,12); f.hint:SetPoint("RIGHT",-12,0); f.hint:SetJustifyH("LEFT")
  return f
end

function UI:BuildFrame()
  if self.frame then return self.frame end

  local BASE_W=1020
  local TITLE_H=34
  local NAV_H=40

  local f=CreateFrame("Frame","NiniToolsMainFrame",UIParent,"BackdropTemplate")
  local db=NT:GetDB()
  f:SetSize(clamp(db.windowWidth or BASE_W,1020,1600),clamp(db.windowHeight or 700,480,1100))
  f:SetPoint("CENTER")
  f:SetScale(1)
  f:SetFrameStrata("HIGH")
  f:SetClampedToScreen(true)
  f:SetMovable(true); f:EnableMouse(true)
  f:SetResizable(true)
  f:SetResizeBounds(1020,480,1600,1100)
  self:Backdrop(f,C.bg,C.border)
  f:SetBackdropColor(C.bg[1],C.bg[2],C.bg[3],0.985)
  f:Hide()
  self.frame=f

  f:SetScript("OnKeyDown",function(self,key)
    if InCombatLockdown and InCombatLockdown() then
      return
    end
    if key=="ESCAPE" then
      self:Hide()
      if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(false) end
    elseif self.SetPropagateKeyboardInput then
      self:SetPropagateKeyboardInput(true)
    end
  end)

  local titleBar=CreateFrame("Frame",nil,f,"BackdropTemplate")
  titleBar:SetPoint("TOPLEFT",0,0); titleBar:SetPoint("TOPRIGHT",0,0); titleBar:SetHeight(TITLE_H)
  self:Backdrop(titleBar,C.sidebar,C.border)
  titleBar:SetBackdropColor(C.sidebar[1],C.sidebar[2],C.sidebar[3],0.99)
  titleBar:SetBackdropBorderColor(C.border[1],C.border[2],C.border[3],0.70)
  titleBar:EnableMouse(true); titleBar:RegisterForDrag("LeftButton")

  titleBar:SetScript("OnDragStart",function() f:StartMoving() end)
  titleBar:SetScript("OnDragStop",function()
    f:StopMovingOrSizing()
  end)

  -- Brand wordmark: text only, transparent background.
  local brand=titleBar:CreateTexture(nil,"ARTWORK")
  brand:SetTexture((NT.GetBrandWordmark and NT:GetBrandWordmark()) or NT:GetBrandIcon(true))
  brand:SetSize(148,32)
  brand:SetPoint("LEFT",4,0)
  brand:SetTexCoord(0,1,0,1)
  brand:SetAlpha(1)
  self.brandWordmark=brand
  -- Version stays at the right; maintenance moved behind a gear button.
  local ver=self:Font(titleBar,8,"v"..NT.VERSION,C.muted)
  ver:SetPoint("RIGHT",-82,0)
  ver:SetJustifyH("RIGHT")

  local gear=self:GearButton(titleBar,"설정 & 진단",function() UI:ShowPage("TOOLS") end)
  gear:SetPoint("RIGHT",-40,0)
  gear:SetSize(28,28)
  self.gearButton=gear

  local close=CreateFrame("Button",nil,titleBar)
  close:SetSize(28,28); close:SetPoint("RIGHT",-6,0)
  close.label=self:Font(close,16,"×",C.muted); close.label:SetPoint("CENTER",0,1)
  close:SetScript("OnEnter",function(self) self.label:SetTextColor(C.accent[1],C.accent[2],C.accent[3],1) end)
  close:SetScript("OnLeave",function(self) self.label:SetTextColor(C.muted[1],C.muted[2],C.muted[3],1) end)
  close:SetScript("OnClick",function() f:Hide() end)

  -- Main navigation is horizontal, matching the layout direction the user prefers.
  local navBar=CreateFrame("Frame",nil,f,"BackdropTemplate")
  navBar:SetPoint("TOPLEFT",0,-TITLE_H)
  navBar:SetPoint("TOPRIGHT",0,-TITLE_H)
  navBar:SetHeight(NAV_H)
  self:Backdrop(navBar,C.sidebar,C.border)
  navBar:SetBackdropColor(C.sidebar[1],C.sidebar[2],C.sidebar[3],0.92)
  navBar:SetBackdropBorderColor(C.border[1],C.border[2],C.border[3],0.55)
  self.navBar=navBar

  local widths={GOLD=126,KICK=148,NSRT=150,QOL=132,MEDIA=146,CAL=120}
  local x=8
  for _,id in ipairs(self.pageOrder) do
    local b=CreateFrame("Button",nil,navBar)
    local w=widths[id] or 110
    b:SetPoint("TOPLEFT",x,0)
    b:SetSize(w,NAV_H)
    x=x+w+2
    b.id=id

    b.bg=b:CreateTexture(nil,"BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetColorTexture(C.panel2[1],C.panel2[2],C.panel2[3],0)

    b.label=self:Font(b,10,self.pageNames[id],C.muted)
    b.label:SetPoint("CENTER",0,1)

    b.bar=b:CreateTexture(nil,"ARTWORK")
    b.bar:SetColorTexture(C.accent[1],C.accent[2],C.accent[3],1)
    b.bar:SetPoint("BOTTOMLEFT",8,0)
    b.bar:SetPoint("BOTTOMRIGHT",-8,0)
    b.bar:SetHeight(2)
    b.bar:Hide()

    b:SetScript("OnClick",function(self) UI:ShowPage(self.id) end)
    b:SetScript("OnEnter",function(self)
      if UI.currentPage~=self.id then
        self.bg:SetColorTexture(C.panel2[1],C.panel2[2],C.panel2[3],0.34)
        self.label:SetTextColor(C.text[1],C.text[2],C.text[3],1)
      end
    end)
    b:SetScript("OnLeave",function() UI:RefreshNav() end)
    self.navButtons[id]=b
  end

  local content=CreateFrame("Frame",nil,f)
  content:SetPoint("TOPLEFT",0,-TITLE_H-NAV_H)
  content:SetPoint("BOTTOMRIGHT",0,30)
  self.content=content

  self.pageTitle=self:Font(content,16,"",C.text)
  self.pageTitle:SetPoint("TOPLEFT",18,-9)
  self.pageHint=self:Font(content,9,"",C.muted)
  self.pageHint:SetPoint("TOPLEFT",18,-31)

  local headerLine=content:CreateTexture(nil,"ARTWORK")
  headerLine:SetColorTexture(C.border[1],C.border[2],C.border[3],0.58)
  headerLine:SetPoint("TOPLEFT",16,-47)
  headerLine:SetPoint("TOPRIGHT",-16,-47)
  headerLine:SetHeight(1)

  self:BuildPages()
  local footer=self:Font(f,9,"우측 아래 드래그: 창 크기 · 마우스 휠: 스크롤",C.muted)
  footer:SetPoint("BOTTOMLEFT",16,9)
  local grip=CreateFrame("Button",nil,f)
  grip:SetSize(26,26)
  grip:SetPoint("BOTTOMRIGHT",-2,2)
  grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  grip:SetScript("OnMouseDown",function(_,button)
    if button=="LeftButton" then f:StartSizing("BOTTOMRIGHT") end
  end)
  local function saveSize()
    f:StopMovingOrSizing()
    local settings=NT:GetDB()
    settings.windowWidth=f:GetWidth()
    settings.windowHeight=f:GetHeight()
  end
  grip:SetScript("OnMouseUp",saveSize)
  grip:SetScript("OnHide",saveSize)
  f:SetScript("OnShow",function()
    local db=NT:GetDB()
    UI:ApplyWindowScale(db.windowScale or 1)
    if not (InCombatLockdown and InCombatLockdown()) then
      if f.EnableKeyboard then f:EnableKeyboard(true) end
      if f.SetPropagateKeyboardInput then f:SetPropagateKeyboardInput(true) end
    end
    local page=db.lastPage or "GOLD"
    if page=="TOOLS" then page="GOLD" end
    UI:ShowPage(page)
  end)
  f:SetScript("OnHide",function()
    -- SetPropagateKeyboardInput is protected during combat; do not call it from OnHide.
    -- 2.0.19: 전투 중 닫혔다면 전투가 끝난 뒤 아래 감시 프레임이 정리한다.
  end)

  -- 2.0.19: 전투 중에 창을 닫으면 키보드 후킹이 켜진 채 남는다.
  -- 전투가 끝나는 시점에 숨겨진 창의 키보드 상태를 되돌린다.
  local guard=_G.NiniTools.EventDispatcher:CreateProxy("UI.CombatGuard")
  guard:RegisterEvent("PLAYER_REGEN_ENABLED")
  guard:SetScript("OnEvent",function()
    if f:IsShown() then return end
    if f.SetPropagateKeyboardInput then f:SetPropagateKeyboardInput(true) end
    if f.EnableKeyboard then f:EnableKeyboard(false) end
  end)

  return f
end

function UI:ApplyWindowScale(value)
  local db=NT:GetDB()
  db.windowScale=clamp(value,0.65,1.5)
  local fit=math.min(UIParent:GetWidth()/self.frame:GetWidth(),UIParent:GetHeight()/self.frame:GetHeight())
  self.frame:SetScale(math.min(db.windowScale,fit))
  self.frame:ClearAllPoints()
  self.frame:SetPoint("CENTER")
  if self.scaleValue then
    local requested=math.floor(db.windowScale*100+.5)
    local actual=math.floor(self.frame:GetScale()*100+.5)
    self.scaleValue:SetText(requested==actual and (requested.."%") or (requested.."% (화면 맞춤 "..actual.."%)"))
  end
end

function UI:RefreshNav()
  for id,b in pairs(self.navButtons) do
    local active=id==self.currentPage
    b.bar:SetShown(active)
    if active then
      b.bg:SetColorTexture(C.accent[1],C.accent[2],C.accent[3],0.07)
      b.label:SetTextColor(C.accent[1],C.accent[2],C.accent[3],1)
    else
      b.bg:SetColorTexture(C.panel2[1],C.panel2[2],C.panel2[3],0)
      b.label:SetTextColor(C.muted[1],C.muted[2],C.muted[3],1)
    end
  end
end

function UI:NewPage(id)
  local view=CreateFrame("ScrollFrame",nil,self.content)
  view:SetPoint("TOPLEFT",0,-50)
  view:SetPoint("BOTTOMRIGHT",-32,0)
  view:EnableMouseWheel(true)
  local p=CreateFrame("Frame",nil,view)
  p:SetSize(984,700)
  view:SetScrollChild(p)
  p.viewport=view
  local bar=CreateFrame("Slider",nil,view,"BackdropTemplate")
  bar:SetPoint("TOPLEFT",view,"TOPRIGHT",8,-22)
  bar:SetPoint("BOTTOMLEFT",view,"BOTTOMRIGHT",8,22)
  bar:SetWidth(14)
  bar:SetOrientation("VERTICAL")
  self:Backdrop(bar,C.sidebar,C.border)
  bar:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
  bar:GetThumbTexture():SetSize(12,40)
  bar:GetThumbTexture():SetVertexColor(C.muted[1],C.muted[2],C.muted[3],1)
  bar:SetMinMaxValues(0,0)
  bar:SetValueStep(1)
  bar:SetValue(0)
  bar:SetScript("OnValueChanged",function(_,value) view:SetVerticalScroll(value) end)
  local function wheel(_,delta)
    local _,maximum=bar:GetMinMaxValues()
    bar:SetValue(clamp(bar:GetValue()-delta*48,0,maximum))
  end
  view:SetScript("OnMouseWheel",wheel)
  bar:EnableMouseWheel(true)
  bar:SetScript("OnMouseWheel",wheel)
  for _,direction in ipairs({1,-1}) do
    local b=CreateFrame("Button",nil,view)
    b:SetSize(24,22)
    b:SetPoint(direction==1 and "BOTTOM" or "TOP",bar,direction==1 and "TOP" or "BOTTOM")
    b.label=self:Font(b,16,direction==1 and "▲" or "▼",C.muted)
    b.label:SetPoint("CENTER")
    b:SetScript("OnClick",function() wheel(nil,direction) end)
  end
  local function layout()
    p:SetWidth(math.max(984,view:GetWidth()))
    p:SetHeight(math.max(p.contentHeight or 700,view:GetHeight()))
    local maximum=math.max(0,p:GetHeight()-view:GetHeight())
    bar:SetMinMaxValues(0,maximum)
    bar:SetValue(clamp(bar:GetValue(),0,maximum))
    view:SetVerticalScroll(bar:GetValue())
  end
  p.Layout=layout
  p.ScrollToTop=function() bar:SetValue(0) end
  p.ScrollBy=function(delta) wheel(nil,delta) end
  view:SetScript("OnSizeChanged",layout)
  view:SetScript("OnShow",layout)
  view:Hide()
  self.pages[id]=p
  return p
end

function UI:BuildPages()
  self:BuildKick()
  self:BuildGold()
  self:BuildNSRT()
  self:BuildMedia()
  self:BuildQOL()
  self:BuildTools()
  -- 2.5.8: 계정 달력 (Modules/Calendar/CalendarUI.lua)
  if type(self.BuildCalendar)=="function" then self:BuildCalendar() end
end

function UI:BuildNSRT()
  local p=self:NewPage("NSRT")
  p.contentHeight=505
  local NR=NT.NSRTImport
  local DIFF_LABEL={[14]="일반",[15]="영웅",[16]="신화"}

  local function currentSpecLabel()
    if type(GetSpecialization)~="function" or type(GetSpecializationInfo)~="function" then return "-" end
    local okIndex,specIndex=pcall(GetSpecialization)
    if not okIndex or not specIndex then return "-" end
    local okInfo,_,specName=pcall(GetSpecializationInfo,specIndex)
    if okInfo and type(specName)=="string" and specName~="" then return specName end
    return "-"
  end

  -- Main work area: paste once, inspect the automatic detection, then apply.
  local sec=self:Section(p,"NSRT 개인 메모","Lorrgs 등에서 복사한 메모를 붙여넣으면 보스 · 난이도 · 전문화를 자동 판별합니다.",-8,410)

  local conn=CreateFrame("Frame",nil,sec,"BackdropTemplate")
  conn:SetPoint("TOPRIGHT",-18,-9); conn:SetSize(112,22)
  self:Backdrop(conn,C.panel2,C.border)
  conn.label=self:Font(conn,8,"",C.muted); conn.label:SetPoint("CENTER")
  p.nsrtConnection=conn

  local pasteTitle=self:Font(sec,11,"메모 붙여넣기",C.text)
  pasteTitle:SetPoint("TOPLEFT",18,-56)
  local pasteHint=self:Font(sec,8,"Lorrgs · 공대 메모 · NSRT 형식 텍스트",C.muted)
  pasteHint:SetPoint("TOPRIGHT",-18,-58)

  local boxFrame=CreateFrame("Frame",nil,sec,"BackdropTemplate")
  boxFrame:SetPoint("TOPLEFT",18,-76); boxFrame:SetPoint("TOPRIGHT",-18,-76); boxFrame:SetHeight(216)
  self:Backdrop(boxFrame,C.panel2,C.border)
  boxFrame:SetBackdropColor(C.panel2[1],C.panel2[2],C.panel2[3],0.76)

  local scroll=CreateFrame("ScrollFrame",nil,boxFrame,"UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT",10,-10); scroll:SetPoint("BOTTOMRIGHT",-30,26)
  local edit=CreateFrame("EditBox",nil,scroll)
  edit:SetMultiLine(true); edit:SetAutoFocus(false); edit:SetFontObject(ChatFontNormal)
  edit:SetWidth(900); edit:SetHeight(176); edit:SetTextInsets(4,4,4,4)
  edit:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
  scroll:SetScrollChild(edit)
  p.nsrtPaste=edit

  local countText=self:Font(boxFrame,8,"0줄",C.muted)
  countText:SetPoint("BOTTOMRIGHT",-12,7)
  p.nsrtCountText=countText

  -- Primary action button: intentionally large because this page has one main action.
  local applyBtn=CreateFrame("Button",nil,sec,"BackdropTemplate")
  applyBtn:SetPoint("TOPLEFT",18,-306); applyBtn:SetSize(390,66)
  self:Backdrop(applyBtn,C.panel2,C.border)
  applyBtn.bg=applyBtn:CreateTexture(nil,"BACKGROUND")
  applyBtn.bg:SetAllPoints(); applyBtn.bg:SetColorTexture(C.accent[1],C.accent[2],C.accent[3],0.18)
  applyBtn.title=self:Font(applyBtn,14,"NSRT 개인 메모에 적용",C.text)
  applyBtn.title:SetPoint("CENTER",0,8)
  applyBtn.sub=self:Font(applyBtn,8,"붙여넣기 → 자동 판별 → 개인 메모 저장",C.muted)
  applyBtn.sub:SetPoint("CENTER",0,-16)
  applyBtn:SetScript("OnEnter",function(self)
    self:SetBackdropBorderColor(C.accent[1],C.accent[2],C.accent[3],1)
    self.bg:SetColorTexture(C.accent[1],C.accent[2],C.accent[3],0.28)
  end)
  applyBtn:SetScript("OnLeave",function(self)
    self:SetBackdropBorderColor(C.border[1],C.border[2],C.border[3],0.9)
    self.bg:SetColorTexture(C.accent[1],C.accent[2],C.accent[3],0.18)
  end)
  p.nsrtApplyButton=applyBtn

  -- Live detection card.  This does not write anything to NSRT; it only parses.
  local result=CreateFrame("Frame",nil,sec,"BackdropTemplate")
  result:SetPoint("TOPLEFT",424,-306); result:SetPoint("TOPRIGHT",-18,-306); result:SetHeight(66)
  self:Backdrop(result,C.panel2,C.border)
  result:SetBackdropColor(C.panel2[1],C.panel2[2],C.panel2[3],0.72)
  p.nsrtResultCard=result

  local resultTitle=self:Font(result,9,"판별 결과",C.text)
  resultTitle:SetPoint("TOPLEFT",12,-6)

  local labels={"보스","난이도","전문화","적용 상태"}
  local fields={}
  for i,label in ipairs(labels) do
    local x=12+(i-1)*132
    local l=self:Font(result,7,label,C.muted); l:SetPoint("TOPLEFT",x,-23)
    local v=self:Font(result,9,"-",C.text); v:SetPoint("TOPLEFT",x,-41); v:SetWidth(i==4 and 96 or 112); v:SetJustifyH("LEFT")
    fields[i]=v
    if i<4 then
      local line=result:CreateTexture(nil,"ARTWORK")
      line:SetColorTexture(C.border[1],C.border[2],C.border[3],0.48)
      line:SetPoint("TOPLEFT",x+120,-24); line:SetSize(1,32)
    end
  end
  p.nsrtFields=fields

  p.nsrtResultText=self:Font(sec,8,"",C.muted)
  p.nsrtResultText:SetPoint("TOPLEFT",424,-376)
  p.nsrtResultText:SetPoint("RIGHT",-18,0)
  p.nsrtResultText:SetJustifyH("LEFT")

  local refreshPreview
  refreshPreview=function(fromEdit)
    if not NR then return end
    local text=edit:GetText() or ""
    local _,lines=text:gsub("\n","\n")
    lines=(text=="" and 0 or lines+1)
    countText:SetText(tostring(lines).."줄")

    if fromEdit then
      p.nsrtResult=nil
      p.nsrtLastOK=nil
      p.nsrtAppliedText=nil
      p.nsrtLastApplied=nil
    end

    local status=NR:GetStatus() or ""
    local connected=(status=="NSRT 연결됨")
    conn.label:SetText(connected and "NSRT 연결됨" or "NSRT 미연결")
    local cc=connected and C.good or C.warn
    conn.label:SetTextColor(cc[1],cc[2],cc[3],1)
    conn:SetBackdropBorderColor(cc[1],cc[2],cc[3],0.55)

    local parsed,err=NR:ParsePaste(text)
    if parsed then
      fields[1]:SetText(parsed.name or "-")
      fields[2]:SetText(DIFF_LABEL[parsed.difficultyID] or tostring(parsed.difficultyID or "-"))
      fields[3]:SetText((parsed.spec and parsed.spec.label) or currentSpecLabel())
      if p.nsrtLastOK and p.nsrtAppliedText==text then
        fields[4]:SetText("적용 완료")
        fields[4]:SetTextColor(C.good[1],C.good[2],C.good[3],1)
      else
        fields[4]:SetText("적용 대기")
        fields[4]:SetTextColor(C.accent[1],C.accent[2],C.accent[3],1)
      end
      if p.nsrtResult and p.nsrtResult~="" then
        p.nsrtResultText:SetText(p.nsrtResult)
      else
        p.nsrtResultText:SetText(string.format("%d개 리마인더 줄 인식 · 원문 필드는 유지하고 전문화 tag만 정리합니다.",#(parsed.rawLines or {})))
      end
      applyBtn.title:SetTextColor(C.text[1],C.text[2],C.text[3],1)
      applyBtn.sub:SetTextColor(C.muted[1],C.muted[2],C.muted[3],1)
    else
      fields[1]:SetText("-"); fields[2]:SetText("-"); fields[3]:SetText("-")
      local last=p.nsrtLastApplied
      if text=="" and last then
        -- 2.6.7: 적용 성공 뒤 붙여넣기 칸은 비우고, 방금 적용한 결과는 그대로 보여 준다
        fields[1]:SetText(last.name or "-"); fields[2]:SetText(last.diff or "-"); fields[3]:SetText(last.spec or "-")
        fields[4]:SetText("적용 완료")
        fields[4]:SetTextColor(C.good[1],C.good[2],C.good[3],1)
        p.nsrtResultText:SetText((p.nsrtResult or "").."  |cff9aa4b2· 칸을 비웠어요 · 다음 메모를 바로 붙여넣으세요|r")
      elseif text=="" then
        fields[4]:SetText("붙여넣기 대기")
        fields[4]:SetTextColor(C.muted[1],C.muted[2],C.muted[3],1)
        p.nsrtResultText:SetText("메모를 붙여넣으면 이곳에 자동 판별 결과가 표시됩니다.")
      else
        fields[4]:SetText("확인 필요")
        fields[4]:SetTextColor(C.warn[1],C.warn[2],C.warn[3],1)
        p.nsrtResultText:SetText("|cffffaa55"..tostring(err or "형식을 확인해 주세요.").."|r")
      end
    end
  end

  edit:SetScript("OnTextChanged",function(self)
    local text=self:GetText() or ""
    local _,lines=text:gsub("\n","\n")
    lines=(text=="" and 0 or lines+1)
    self:SetHeight(math.max(176,lines*15+18))
    scroll:UpdateScrollChildRect()
    refreshPreview(not p.nsrtClearing)
  end)

  applyBtn:SetScript("OnClick",function()
    local text=edit:GetText() or ""
    local ok,msg=NR:Apply(text)
    p.nsrtResult=(ok and "|cff3fdb6c✓|r " or "|cffff5555✕|r ")..tostring(msg or "")
    p.nsrtLastOK=ok and true or false
    p.nsrtAppliedText=ok and text or nil
    if ok then
      -- 2.6.7: 성공하면 붙여넣기 칸을 비우고 커서를 넣어 둔다 → 다음 메모를 바로 Ctrl+V (실패하면 고칠 수 있게 그대로 둠)
      local parsed=NR:ParsePaste(text)
      p.nsrtLastApplied=parsed and {
        name=parsed.name,
        diff=DIFF_LABEL[parsed.difficultyID] or tostring(parsed.difficultyID or "-"),
        spec=(parsed.spec and parsed.spec.label) or currentSpecLabel(),
      } or {name="-",diff="-",spec="-"}
      p.nsrtClearing=true
      edit:SetText("")
      p.nsrtClearing=nil
      edit:SetFocus()
    end
    refreshPreview(false)
  end)

  -- Slim one-line guide: keep the help visible without stealing paste-box height.
  local guide=CreateFrame("Frame",nil,p,"BackdropTemplate")
  guide:SetPoint("TOPLEFT",16,-426); guide:SetPoint("TOPRIGHT",-16,-426); guide:SetHeight(46)
  self:Backdrop(guide,C.panel,C.border)
  guide:SetBackdropColor(C.panel[1],C.panel[2],C.panel[3],0.60)
  local guideTitle=self:Font(guide,9,"이렇게 사용하세요",C.text); guideTitle:SetPoint("LEFT",14,0)
  local guideFlow=self:Font(guide,9,"1  붙여넣기    →    2  자동 판별    →    3  NSRT 적용",C.muted)
  guideFlow:SetPoint("LEFT",guideTitle,"RIGHT",24,0)
  guideFlow:SetPoint("RIGHT",-14,0)
  guideFlow:SetJustifyH("LEFT")

  p.Refresh=function()
    refreshPreview(false)
  end
  refreshPreview(false)
end

function UI:BuildKick()
  local p=self:NewPage("KICK")
  p.kickRows={}
  local get=function() return NT:GetKickDB() end
  self:PrepareAccordionPage(p)

  -- 1) Interrupt assignment / rotation -------------------------------------------------
  local assign=self:AccordionSection(p,"assign","차단 담당 / 로테이션","브리핑을 받으면 자동 반영 · 필요하면 직접 수정",172,true)
  p.kickEnabled=self:Toggle(assign.body,"NiniKick 사용","enabled",get,nil,-8)
  p.kickRows[#p.kickRows+1]=p.kickEnabled

  local markerItems={}
  for i=1,8 do
    local names=(_G.NiniKick and _G.NiniKick.MARKER_NAMES) or {}
    markerItems[i]={text="",value=i,width=36,marker=i,tooltip=names[i] or tostring(i)}
  end
  p.markerRow=self:ChoiceRow(assign.body,"담당 징표",-50,markerItems,
    function(v) local c=_G.NiniKick and _G.NiniKick.GetInterruptConfig and _G.NiniKick.GetInterruptConfig(); return c and c.marker==v end,
    function(v) if _G.NiniKick and _G.NiniKick.SetInterruptMarker then _G.NiniKick.SetInterruptMarker(v) end end)
  p.rotaSizeRow=self:ChoiceRow(assign.body,"로테 인원",-90,{{text="없음",value=1,width=62},{text="2인",value=2},{text="3인",value=3}},
    function(v)
      local c=_G.NiniKick and _G.NiniKick.GetInterruptConfig and _G.NiniKick.GetInterruptConfig()
      if not c then return false end
      if v==1 then return c.rotationEnabled==false end
      return c.rotationEnabled==true and c.size==v
    end,
    function(v) if _G.NiniKick and _G.NiniKick.SetRotationSize then _G.NiniKick.SetRotationSize(v) end end)
  p.rotaOrderRow=self:ChoiceRow(assign.body,"내 순서",-130,{{text="1차단",value=1},{text="2차단",value=2},{text="3차단",value=3}},
    function(v) local c=_G.NiniKick and _G.NiniKick.GetInterruptConfig and _G.NiniKick.GetInterruptConfig(); return c and c.order==v end,
    function(v) if _G.NiniKick and _G.NiniKick.SetInterruptOrder then _G.NiniKick.SetInterruptOrder(v) end end)

  -- 2) M+ automation / interrupt --------------------------------------------------------
  local automation=self:AccordionSection(p,"automation","차단 알림 / 쐐기 자동화","브리핑 감지 · 인사 · 오토",252,false)
  -- These are grouped together because they all automate the M+ flow.
  local autoRows={}
  autoRows[1]=self:Toggle(automation.body,"자동 브리핑 감지","autoBriefing",get,nil,-8)
  autoRows[2]=self:Toggle(automation.body,"NiniKick 차단 알림 사용","interruptEnabled",get,nil,-48)
  autoRows[3]=self:Toggle(automation.body,"파티 입장 인사 · 안녕하세요.","partyGreetingEnabled",get,nil,-88)
  autoRows[4]=self:Toggle(automation.body,"쐐기 완료 인사 · 수고하셨습니다.","goodbyeEnabled",get,nil,-128)
  for _,row in ipairs(autoRows) do p.kickRows[#p.kickRows+1]=row end
  p.autoMacroRow=self:Toggle(automation.body,"오토","autoInterruptMacroEnabled",get,function(v)
    if v and _G.NiniKick and _G.NiniKick.UpdateAutoInterruptMacro then _G.NiniKick.UpdateAutoInterruptMacro(true) end
  end,-168)
  p.autoMacroRow.sub=self:Font(p.autoMacroRow,8,"브리핑 감지 시 차단 오더 자동 갱신",C.muted)
  p.autoMacroRow.sub:SetPoint("LEFT",p.autoMacroRow.text,"RIGHT",12,0)
  p.autoMacroRow.sub:SetPoint("RIGHT",p.autoMacroRow.switch,"LEFT",-14,0)
  p.autoMacroRow.sub:SetJustifyH("LEFT")
  p.kickRows[#p.kickRows+1]=p.autoMacroRow
  p.autoMacroRefresh=self:Button(automation.body,"오토 갱신",112,28,function()
    if _G.NiniKick and _G.NiniKick.UpdateAutoInterruptMacro then _G.NiniKick.UpdateAutoInterruptMacro(false) end
    UI:RefreshVisiblePage()
  end)
  p.autoMacroRefresh:SetPoint("BOTTOMLEFT",22,12)
  local autoNote=self:Font(automation.body,8,"차단음: NiniTools Naowh Kick 고정 · 액션바 배치는 변경하지 않습니다.",C.muted)
  autoNote:SetPoint("BOTTOMLEFT",216,18); autoNote:SetPoint("RIGHT",-18,0); autoNote:SetJustifyH("LEFT")

  -- 3) Important mob marker -------------------------------------------------------------
  local important=self:AccordionSection(p,"important","중요몹 ! 표시","쐐기 · 추종자 던전 · 레이드 중요 시전을 이름표 느낌표로 강조",494,false)
  local impLeft=CreateFrame("Frame",nil,important.body)
  impLeft:SetPoint("TOPLEFT",0,0); impLeft:SetPoint("BOTTOMLEFT",0,0); impLeft:SetWidth(570)
  p.importantRow=self:Toggle(impLeft,"중요몹 ! 표시 사용","importantCastMarkerEnabled",get,function(v)
    if _G.NiniKick and _G.NiniKick.SetDisplayOption then _G.NiniKick.SetDisplayOption("importantCastMarkerEnabled",v) end
  end,-8)

  p.importantSizeRow=self:SliderRow(impLeft,"아이콘 크기",-50,70,140,5,function()
    return math.floor((tonumber(get().importantCastMarkerScale) or 1)*100+.5)
  end,function(v)
    local d=get(); d.importantCastMarkerScale=math.max(.70,math.min(1.40,(tonumber(v) or 100)/100))
    if _G.NiniKick and _G.NiniKick.RefreshImportantCastStyle then _G.NiniKick.RefreshImportantCastStyle() end
  end,function(v) return math.floor((tonumber(v) or 100)+.5).."%" end)

  -- 2.6.3: 위치 = 체력바 위 가운데 기준 + X · Y 이동 (막대 · 숫자 입력)
  local range=(_G.NiniKick and _G.NiniKick.IMPORTANT_CAST_OFFSET_RANGE) or {xMin=-200,xMax=200,yMin=-80,yMax=160}
  local function offsetGetter(key)
    return function()
      if _G.NiniKick and _G.NiniKick.ImportantCastMigratePosition then pcall(_G.NiniKick.ImportantCastMigratePosition) end
      local d=get() or {}
      return math.floor((tonumber(d[key]) or 0)+.5)
    end
  end
  local function offsetSetter(key)
    return function(v)
      local d=get(); if not d then return end
      d[key]=math.floor((tonumber(v) or 0)+.5)
      if _G.NiniKick and _G.NiniKick.RefreshImportantCastAnchor then pcall(_G.NiniKick.RefreshImportantCastAnchor) end
      if p.importantPreview then p.importantPreview:Refresh() end
    end
  end
  p.importantOffsetXRow=self:SliderRow(impLeft,"좌우 (X)",-90,range.xMin,range.xMax,1,offsetGetter("importantCastOffsetX"),offsetSetter("importantCastOffsetX"),nil,{editable=true})
  p.importantOffsetYRow=self:SliderRow(impLeft,"위아래 (Y)",-126,range.yMin,range.yMax,1,offsetGetter("importantCastOffsetY"),offsetSetter("importantCastOffsetY"),nil,{editable=true})

  -- 2.6.6: 느낌표 그림(클래식/기울임)과 움직임(스타일)을 따로 고른다 · 카드도 지금 고른 조합으로 보여 줌
  local function curStyle() local d=get() or {}; return d.importantCastMarkerStyle, d.importantCastMarkerShape, d.importantCastRim~=false end
  local function refreshMarker() if _G.NiniKick and _G.NiniKick.RefreshImportantCastStyle then _G.NiniKick.RefreshImportantCastStyle() end end
  local shapeItems={}
  for _,id in ipairs(NT.IMPORTANT_CAST_SHAPE_ORDER or {"CLASSIC","SLANT"}) do
    local sh=NT.IMPORTANT_CAST_SHAPES and NT.IMPORTANT_CAST_SHAPES[id]
    local st,_,halo=curStyle()
    shapeItems[#shapeItems+1]={text=(sh and sh.label) or id,value=id,width=96,preset=NT:GetImportantCastStyle(st,id,halo)}
  end
  p.importantShapeRow=self:StyleCardRow(impLeft,"느낌표 그림",-164,shapeItems,
    function(v) return select(3,NT:GetImportantCastStyle(curStyle()))==v end,
    function(v) get().importantCastMarkerShape=v; refreshMarker() end)
  local styleItems={}
  for _,id in ipairs(NT.IMPORTANT_CAST_STYLE_ORDER or {"PREMIUM","PULSE","EMPHASIS"}) do
    local base=NT.IMPORTANT_CAST_STYLES and NT.IMPORTANT_CAST_STYLES[id]
    local _,sh,halo=curStyle()
    styleItems[#styleItems+1]={text=(base and base.label) or id,value=id,width=96,preset=NT:GetImportantCastStyle(id,sh,halo)}
  end
  p.importantStyleRow=self:StyleCardRow(impLeft,"표시 스타일",-248,styleItems,
    function(v) return select(2,NT:GetImportantCastStyle(get().importantCastMarkerStyle))==v end,
    function(v) get().importantCastMarkerStyle=v; refreshMarker() end)
  local impNote=self:Font(impLeft,8,"색은 둘 다 주황↔핫핑크 · 기본형=제자리 · 펄스형=두근두근 · 강조형=크게 부풀기",C.muted)
  impNote:SetPoint("TOPLEFT",22,-330); impNote:SetPoint("RIGHT",-12,0); impNote:SetJustifyH("LEFT")
  p.importantHaloRow=self:Toggle(impLeft,"「!」 흰 외곽선 (아주 얇게 · 60%)","importantCastRim",get,function() refreshMarker() end,-348)

  -- 2.6.2: 추종자 던전에서도 표시 (차단 순번·음성은 쐐기에서만) + 이름표에 띄워 보는 테스트
  p.importantFollowerRow=self:Toggle(impLeft,"추종자 던전에서도 표시","importantCastFollowerEnabled",get,function()
    if _G.NiniKick and _G.NiniKick.ImportantCastRefreshAll then pcall(_G.NiniKick.ImportantCastRefreshAll) end
  end,-390)
  -- 2.6.9: 레이드에서도 표시 (게임이 「중요」로 표시한 시전 · 차단 순번·음성은 쐐기에서만)
  p.importantRaidRow=self:Toggle(impLeft,"레이드에서도 표시","importantCastRaidEnabled",get,function()
    if _G.NiniKick and _G.NiniKick.ImportantCastRefreshAll then pcall(_G.NiniKick.ImportantCastRefreshAll) end
  end,-412)
  local bangTest=self:Button(impLeft,"이름표에 띄워 보기 (10초)",186,24,function()
    NT:CallSlash("NINIKICK","bang test 10")
  end)
  bangTest:SetPoint("TOPLEFT",22,-458)
  local posReset=self:Button(impLeft,"위치 초기화",96,24,function()
    local d=get(); if not d then return end
    d.importantCastOffsetX,d.importantCastOffsetY=0,0
    if _G.NiniKick and _G.NiniKick.RefreshImportantCastAnchor then pcall(_G.NiniKick.RefreshImportantCastAnchor) end
    UI:RefreshVisiblePage()
  end)
  posReset:SetPoint("LEFT",bangTest,"RIGHT",8,0)
  local bangHint=self:Font(impLeft,8,"타겟 이름표에 띄움 · 띄운 동안 X·Y를 움직여 맞추세요",C.muted)
  bangHint:SetPoint("LEFT",posReset,"RIGHT",10,0); bangHint:SetPoint("RIGHT",impLeft,"RIGHT",-12,0); bangHint:SetJustifyH("LEFT"); bangHint:SetWordWrap(true)

  local preview=CreateFrame("Frame",nil,important.body,"BackdropTemplate")
  preview:SetPoint("TOPRIGHT",-16,-12); preview:SetSize(336,260)
  self:Backdrop(preview,C.sidebar,C.border)
  preview:SetBackdropColor(C.sidebar[1],C.sidebar[2],C.sidebar[3],0.88)
  preview.title=self:Font(preview,8,"실시간 애니메이션 미리보기",C.muted); preview.title:SetPoint("TOPLEFT",12,-10)

  if preview.SetClipsChildren then preview:SetClipsChildren(true) end
  local fakeName=self:Font(preview,9,"분노한 전쟁군주",C.text)
  fakeName:SetPoint("BOTTOM",0,54)
  local fakePct=self:Font(preview,9,"100%",C.text)
  local fakeBar=CreateFrame("Frame",nil,preview,"BackdropTemplate")
  fakeBar:SetSize(210,15); fakeBar:SetPoint("BOTTOM",0,30)
  self:Backdrop(fakeBar,{0.20,0.03,0.03},{0.05,0.05,0.05})
  fakeBar:SetBackdropColor(.55,.05,.04,1); fakeBar:SetBackdropBorderColor(.05,.05,.05,1)
  local hp=fakeBar:CreateTexture(nil,"ARTWORK"); hp:SetPoint("TOPLEFT",2,-2); hp:SetPoint("BOTTOMRIGHT",-50,2); hp:SetColorTexture(.86,.08,.05,1)

  preview.iconHolder=CreateFrame("Frame",nil,preview)
  preview.iconHolder:SetPoint("BOTTOM",fakeName,"TOP",0,8)
  preview.ring=preview.iconHolder:CreateTexture(nil,"BACKGROUND")
  preview.ring:SetTexture("Interface\\AddOns\\NiniTools\\Media\\ImportantAlert_White.tga")
  preview.ring:SetPoint("CENTER")
  preview.ring:SetBlendMode("ADD")
  preview.glow=preview.iconHolder:CreateTexture(nil,"ARTWORK")
  preview.glow:SetTexture("Interface\\AddOns\\NiniTools\\Media\\ImportantAlert_White.tga")
  preview.glow:SetPoint("CENTER")
  preview.glow:SetBlendMode("ADD")
  preview.icon=preview.iconHolder:CreateTexture(nil,"OVERLAY")
  preview.icon:SetTexture("Interface\\AddOns\\NiniTools\\Media\\ImportantAlert_White.tga")
  preview.icon:SetPoint("CENTER")
  preview.icon:SetBlendMode("BLEND")
  preview.gloss=preview.iconHolder:CreateTexture(nil,"OVERLAY",nil,7)
  preview.gloss:SetPoint("CENTER")
  preview.gloss:Hide()
  for _,tx in ipairs({preview.ring,preview.glow,preview.icon}) do
    if tx.SetSnapToPixelGrid then pcall(tx.SetSnapToPixelGrid,tx,false) end
    if tx.SetTexelSnappingBias then pcall(tx.SetTexelSnappingBias,tx,0) end
  end
  preview.styleLabel=self:Font(preview,8,"",C.muted); preview.styleLabel:SetPoint("BOTTOMRIGHT",-10,8)

  function preview:Refresh()
    local d=get()
    local preset=NT:GetImportantCastStyle(d.importantCastMarkerStyle,d.importantCastMarkerShape,d.importantCastRim~=false)
    local scale=math.max(.70,math.min(1.40,tonumber(d.importantCastMarkerScale) or 1))
    local iconSize=(tonumber(preset.iconSize) or 68)*scale*.72
    local glowSize=iconSize
    self.iconHolder:SetSize(iconSize,iconSize)
    self.iconBase,self.glowBase=iconSize,glowSize
    self.icon:SetSize(iconSize,iconSize)
    self.glow:SetSize(glowSize,glowSize)
    self.stylePreset=preset
    local texPath=preset.texture or "Interface\\AddOns\\NiniTools\\Media\\ImportantAlert_White.tga"
    for _,tx in ipairs({self.ring,self.icon}) do tx:SetTexture(texPath) end
    if preset.gloss then self.gloss:SetTexture(preset.gloss); self.gloss:Show() else self.gloss:Hide() end
    if preset.rim then self.glow:SetTexture(preset.rim); self.glow:SetBlendMode("BLEND"); self.glow:Show() else self.glow:Hide() end
    self:SetAlpha(d.importantCastMarkerEnabled==false and .42 or 1)
    -- 2.6.3: 실제와 같은 기준 · 체력바 위 가운데 + X · Y (미리보기는 0.72배)
    local ox=math.floor((tonumber(d.importantCastOffsetX) or 0)+.5)
    local oy=math.floor((tonumber(d.importantCastOffsetY) or 0)+.5)
    local shp=NT.IMPORTANT_CAST_SHAPES and NT.IMPORTANT_CAST_SHAPES[preset.shape or "CLASSIC"]
    self.styleLabel:SetText((shp and shp.label or "클래식").." · "..(preset.label or "기본형").." · "..math.floor(scale*100+.5).."% · X "..ox.." · Y "..oy)
    local k=.72
    local barBottom=44
    if oy<0 then barBottom=math.min(150,44+(-oy*k)+iconSize*.35) end
    fakeBar:ClearAllPoints(); fakeBar:SetPoint("BOTTOM",0,barBottom)
    fakeName:ClearAllPoints(); fakeName:SetPoint("BOTTOMLEFT",fakeBar,"TOPLEFT",2,2)
    fakePct:ClearAllPoints(); fakePct:SetPoint("BOTTOMRIGHT",fakeBar,"TOPRIGHT",-2,2)
    self.iconHolder:ClearAllPoints()
    self.iconHolder:SetPoint("BOTTOM",fakeBar,"TOP",ox*k,oy*k-iconSize*(tonumber(preset.bottomPad) or 0.13))
  end
  preview:SetScript("OnUpdate",function(self)
    if not self.stylePreset or not NT.ImportantCastFrame then return end
    -- 2.5.5: 실제 이름표와 같은 계산 · 3초마다 시전 시작(튀어나옴) → 끝(사라짐)을 반복해서 보여 준다
    local now=GetTime()
    local cyc=now%3.0
    local fading=cyc>=2.55 and (cyc-2.55) or nil
    local f=NT:ImportantCastFrame(self.stylePreset,now,cyc,fading)
    local ib,gb=self.iconBase or 48,self.glowBase or 68
    self.icon:SetSize(ib*f.iconScale,ib*f.iconScale)
    if self.gloss:IsShown() then self.gloss:SetSize(ib*f.iconScale,ib*f.iconScale); self.gloss:SetAlpha(f.iconAlpha*f.alpha) end
    self.icon:SetVertexColor(f.r,f.g,f.b,1)
    self.icon:SetAlpha(f.iconAlpha*f.alpha)
    if self.glow:IsShown() and (f.glowAlpha or 0)>0.01 then
      self.glow:SetSize(gb*(f.glowScale or 1),gb*(f.glowScale or 1))
      self.glow:SetVertexColor(f.gr or 1,f.gg or 1,f.gb or 1,1)
      self.glow:SetAlpha(f.glowAlpha*f.alpha)
    else
      self.glow:SetAlpha(0)
    end
    if f.ringScale and f.ringAlpha>0.01 then
      self.ring:SetSize(ib*f.ringScale,ib*f.ringScale)
      self.ring:SetVertexColor(f.r,f.g,f.b,1)
      self.ring:SetAlpha(f.ringAlpha*f.alpha)
      self.ring:Show()
    else
      self.ring:Hide()
    end
  end)
  p.importantPreview=preview

  -- 4) Naowh Smart Reminders -----------------------------------------------------------
  local defensive=self:AccordionSection(p,"defensive","생존기 알림","Naowh Smart Reminders 연동 · 담당 자동 판정 / 필요 시 NiniTools 강제 유지",190,false)
  local modeTitle=self:Font(defensive.body,11,"EXBoss 있음: AOE → 도적 생존기   ·   EXBoss 없음: AoE18 → Sonar",C.text)
  modeTitle:SetPoint("TOPLEFT",22,-18)
  p.smartStatus=self:Font(defensive.body,9,"",C.muted); p.smartStatus:SetPoint("TOPLEFT",22,-48); p.smartStatus:SetPoint("RIGHT",-22,0); p.smartStatus:SetJustifyH("LEFT"); p.smartStatus:SetWordWrap(true)
  p.keepNiniDefensiveRow=self:Toggle(defensive.body,"Naowh가 켜져 있어도 NiniTools 생존기 알림 유지","keepDefensiveWithNaowh",get,nil,-78)
  p.kickRows[#p.kickRows+1]=p.keepNiniDefensiveRow
  local openNSR=self:Button(defensive.body,"Naowh 리마인더 열기",160,26,function()
    if NT.NSRBridge then NT.NSRBridge:OpenNaowh() end
  end); openNSR:SetPoint("BOTTOMLEFT",22,12)
  local reinstallNSR=self:Button(defensive.body,"니니 프로필 쓰기",138,26,function()
    if NT.NSRBridge then NT.NSRBridge:Reinstall() end
    UI:RefreshVisiblePage()
  end); reinstallNSR:SetPoint("LEFT",openNSR,"RIGHT",8,0)
  local sonarTest=self:Button(defensive.body,"Sonar 테스트",116,26,function()
    if NT.NSRBridge then NT.NSRBridge:TestSonar() end
  end); sonarTest:SetPoint("LEFT",reinstallNSR,"RIGHT",8,0)
  -- 2.5.7: 내 Smart Reminders 프로필을 쓰는 사람은 니니 프로필 관리를 끈다.
  local stopNSR=self:Button(defensive.body,"안 씀",72,26,function()
    if NT.NSRBridge and NT.NSRBridge.StopManaging then NT.NSRBridge:StopManaging() end
    UI:RefreshVisiblePage()
  end); stopNSR:SetPoint("LEFT",sonarTest,"RIGHT",8,0)
  p.smartOpenButton=openNSR; p.smartReinstallButton=reinstallNSR; p.smartSonarButton=sonarTest; p.smartStopButton=stopNSR

  -- 5) Combat overlays -----------------------------------------------------------------
  local combat=self:AccordionSection(p,"combat","전투 시간 / 주변 적 숫자","전투 중 필요한 정보만 화면에 간단히 표시",206,false)
  local left=CreateFrame("Frame",nil,combat.body,"BackdropTemplate")
  left:SetPoint("TOPLEFT",14,-10); left:SetPoint("BOTTOMLEFT",14,12); left:SetWidth(446)
  self:Backdrop(left,C.sidebar,C.border); left:SetBackdropColor(C.sidebar[1],C.sidebar[2],C.sidebar[3],.45)
  local right=CreateFrame("Frame",nil,combat.body,"BackdropTemplate")
  right:SetPoint("TOPRIGHT",-14,-10); right:SetPoint("BOTTOMRIGHT",-14,12); right:SetWidth(446)
  self:Backdrop(right,C.sidebar,C.border); right:SetBackdropColor(C.sidebar[1],C.sidebar[2],C.sidebar[3],.45)

  local leftTitle=self:Font(left,9,"전투시간",C.accent); leftTitle:SetPoint("TOPLEFT",14,-10)
  p.combatTimerRow=self:Toggle(left,"전투시간 표시","combatTimerEnabled",get,function(v)
    NT:CallSlash("NINIKICK",v and "combattime on" or "combattime off")
  end,-32)
  p.combatSize=self:AdjustRow(left,"글자 크기",-74,function()
    return tostring(math.floor((get().combatTimerTextSize or 24)+.5))
  end,function(dir) if _G.NiniKick and _G.NiniKick.AdjustAlertSize then _G.NiniKick.AdjustAlertSize("combat",dir) end end)
  p.timerPosButton=self:Button(left,"전투시간 위치 이동",152,26,function() NT:CallSlash("NINIKICK","combattime move"); UI:RefreshVisiblePage() end)
  p.timerPosButton:SetPoint("BOTTOMLEFT",18,12)

  local function enemyDB()
    if _G.NiniEnemyCount and _G.NiniEnemyCount.GetDB then return _G.NiniEnemyCount.GetDB() end
    local main=NT:GetDB()
    main.modules=main.modules or {}
    main.modules.enemyCount=main.modules.enemyCount or {enabled=true,fontSize=28,garroteCoverage=true}
    return main.modules.enemyCount
  end
  local rightTitle=self:Font(right,9,"주변 적 숫자",C.accent); rightTitle:SetPoint("TOPLEFT",14,-10)
  p.enemyCountRow=self:Toggle(right,"주변 적 숫자 표시 (암살: 목조르기/적 수 · 8야드)","enabled",enemyDB,function(v)
    if _G.NiniEnemyCount and _G.NiniEnemyCount.SetEnabled then _G.NiniEnemyCount.SetEnabled(v) end
  end,-32)
  p.enemyCountSize=self:AdjustRow(right,"적 숫자 크기",-74,function()
    local api=_G.NiniEnemyCount
    return api and api.GetFontSize and (math.floor((api.GetFontSize() or 28)+.5).." px") or ((enemyDB().fontSize or 28).." px")
  end,function(dir)
    local api=_G.NiniEnemyCount
    if api and api.AdjustFontSize then api.AdjustFontSize(dir) end
  end)
  p.enemyGarroteRow=self:Toggle(right,"암살 목조르기 커버리지 (7/12)","garroteCoverage",enemyDB,function(v)
    local api=_G.NiniEnemyCount
    if api and api.SetGarroteCoverage then api.SetGarroteCoverage(v) end
  end,-116)
  p.enemyPosButton=self:Button(right,"위치 이동",94,26,function()
    local api=_G.NiniEnemyCount; if api and api.SetUnlocked and api.IsUnlocked then api.SetUnlocked(not api.IsUnlocked()) end; UI:RefreshVisiblePage()
  end); p.enemyPosButton:SetPoint("BOTTOMLEFT",18,12)
  p.enemyResetButton=self:Button(right,"초기화",78,26,function()
    local api=_G.NiniEnemyCount; if api and api.ResetPosition then api.ResetPosition() end; UI:RefreshVisiblePage()
  end); p.enemyResetButton:SetPoint("LEFT",p.enemyPosButton,"RIGHT",8,0)
  p.enemyTestButton=self:Button(right,"3타겟 테스트",106,26,function()
    local api=_G.NiniEnemyCount
    if api and api.SetTestCount then
      local testing=api.GetTestCount and api.GetTestCount()~=nil
      if testing then api.SetTestCount(nil) else api.SetTestCount(3) end
    end
    UI:RefreshVisiblePage()
  end); p.enemyTestButton:SetPoint("LEFT",p.enemyResetButton,"RIGHT",8,0)

  p.Refresh=function(self)
    for _,r in ipairs(self.kickRows) do if r and r.Refresh then r:Refresh() end end
    self.markerRow:Refresh(); self.rotaSizeRow:Refresh(); self.rotaOrderRow:Refresh()
    self.importantRow:Refresh(); self.importantStyleRow:Refresh(); self.importantSizeRow:Refresh()
    if self.importantOffsetXRow then self.importantOffsetXRow:Refresh(); self.importantOffsetYRow:Refresh() end
    if self.importantHaloRow then self.importantHaloRow:Refresh() end
    do -- 2.6.6: 카드 그림을 지금 고른 그림·스타일·흰 외곽선으로 다시 입힘
      local kd=NT:GetKickDB() or {}
      local halo=kd.importantCastRim~=false
      for _,card in ipairs((self.importantShapeRow and self.importantShapeRow.cards) or {}) do
        card:SetPreset(NT:GetImportantCastStyle(kd.importantCastMarkerStyle,card.itemValue,halo))
      end
      for _,card in ipairs((self.importantStyleRow and self.importantStyleRow.cards) or {}) do
        card:SetPreset(NT:GetImportantCastStyle(card.itemValue,kd.importantCastMarkerShape,halo))
      end
      if self.importantShapeRow then self.importantShapeRow:Refresh() end
    end
    if self.importantFollowerRow then self.importantFollowerRow:Refresh() end
    if self.importantRaidRow then self.importantRaidRow:Refresh() end
    self.combatTimerRow:Refresh(); self.combatSize:Refresh(); self.enemyCountRow:Refresh(); self.enemyCountSize:Refresh(); self.enemyGarroteRow:Refresh()

    local nsrStatus=(NT.NSRBridge and NT.NSRBridge:GetStatus()) or "Naowh Smart Reminders 연결 대기"
    if self.smartStatus then self.smartStatus:SetText(nsrStatus) end

    local k=get() or {}
    local cfg=_G.NiniKick and _G.NiniKick.GetInterruptConfig and _G.NiniKick.GetInterruptConfig() or {}
    local markerNames=(_G.NiniKick and _G.NiniKick.MARKER_NAMES) or {"별","동그라미","다이아","세모","달","네모","가위표","해골"}
    local rotationOn=cfg.rotationEnabled==true
    if self.rotaOrderRow then
      self.rotaOrderRow:SetAlpha(rotationOn and 1 or .34)
      for _,b in ipairs(self.rotaOrderRow.buttons or {}) do b:EnableMouse(rotationOn) end
    end
    assign:SetEnabledState(k.enabled~=false)
    if rotationOn then
      assign:SetState(string.format("%s · %d인 · %d차단",markerNames[cfg.marker or 1] or "징표",cfg.size or 2,cfg.order or 1),"accent")
    else
      assign:SetState((markerNames[cfg.marker or 1] or "징표").." · 로테 없음","accent")
    end
    automation:SetState((k.interruptEnabled~=false and "차단 ON" or "차단 OFF").." · "..(k.autoBriefing~=false and "자동" or "수동"),k.interruptEnabled~=false and "good" or "warn")
    local preset=NT:GetImportantCastStyle(k.importantCastMarkerStyle,k.importantCastMarkerShape,k.importantCastRim~=false)
    local shp=NT.IMPORTANT_CAST_SHAPES and NT.IMPORTANT_CAST_SHAPES[preset.shape or "CLASSIC"]
    important:SetState((k.importantCastMarkerEnabled~=false and "ON" or "OFF").." · "..(shp and shp.label or "클래식").." "..(preset.label or "기본형").." · "..math.floor((tonumber(k.importantCastMarkerScale) or 1)*100+.5).."%",k.importantCastMarkerEnabled~=false and "accent" or "warn")
    local A=NT.Adapters
    local state=A and type(A.GetNaowhReminderState)=="function" and A:GetNaowhReminderState() or nil
    if state and state.owner=="naowh" then
      defensive:SetState("Naowh 담당","good")
    elseif state and state.override then
      defensive:SetState("NiniTools 강제","accent")
    else
      defensive:SetState("NiniTools 담당","accent")
    end
    local enemy=enemyDB()
    combat:SetState("시간 "..(k.combatTimerEnabled~=false and "ON" or "OFF").." · 적 "..(enemy.enabled~=false and "ON" or "OFF"),"accent")

    if self.importantPreview then self.importantPreview:Refresh() end
    if self.timerPosButton and self.timerPosButton.label then self.timerPosButton.label:SetText(k.combatTimerUnlocked and "전투시간 위치 고정" or "전투시간 위치 이동") end
    local enemyAPI=_G.NiniEnemyCount
    if self.enemyPosButton and self.enemyPosButton.label then self.enemyPosButton.label:SetText(enemyAPI and enemyAPI.IsUnlocked and enemyAPI.IsUnlocked() and "위치 고정" or "위치 이동") end
    if self.enemyTestButton and self.enemyTestButton.label then self.enemyTestButton.label:SetText(enemyAPI and enemyAPI.GetTestCount and enemyAPI.GetTestCount() and "테스트 종료" or "3타겟 테스트") end
    self:LayoutAccordions()
  end
end

function UI:BuildGold()
  local p=self:NewPage("GOLD")
  p.contentHeight=540
  p.selectedChar=nil
  p.goldDays=7
  p.goldFilter="ALL"
  p.goldSearch=""

  local FILTERS={
    {id="ALL",text="전체"},
    {id="REPAIR",text="수리"},
    {id="MAIL",text="우편"},
    {id="AUCTION",text="경매장"},
    {id="TRADE",text="거래"},
    {id="VENDOR",text="상점"},
    {id="OTHER",text="기타"},
  }
  local PERIODS={{1,"오늘"},{7,"7일"},{30,"30일"},{90,"90일"}}

  local function filterMatch(kind,filter)
    if filter=="ALL" then return true end
    if filter=="REPAIR" then return kind=="repair" end
    if filter=="MAIL" then return kind=="mail" end
    if filter=="AUCTION" then return kind=="auction" end
    if filter=="TRADE" then return kind=="trade_in" or kind=="trade_out" end
    if filter=="VENDOR" then return kind=="vendor_in" or kind=="vendor_out" end
    if filter=="OTHER" then return kind=="other_in" or kind=="other_out" end
    return true
  end

  local function makeCard(x,w,title)
    local card=CreateFrame("Frame",nil,p,"BackdropTemplate")
    card:SetPoint("TOPLEFT",x,-8)
    card:SetSize(w,105)
    UI:Backdrop(card,C.panel,C.border)
    card:SetBackdropColor(C.panel[1],C.panel[2],C.panel[3],0.86)
    card.title=UI:Font(card,10,title,C.muted)
    card.title:SetPoint("TOPLEFT",14,-12)
    card.value=UI:SingleLine(UI:Font(card,17,"",C.text))
    card.value:SetPoint("TOPLEFT",14,-34)
    card.value:SetPoint("RIGHT",-12,0)
    card.value:SetJustifyH("LEFT")
    card.income=UI:SingleLine(UI:Font(card,9,"",C.muted))
    card.income:SetPoint("TOPLEFT",14,-62)
    card.income:SetPoint("RIGHT",-12,0)
    card.income:SetJustifyH("LEFT")
    card.expense=UI:SingleLine(UI:Font(card,9,"",C.muted))
    card.expense:SetPoint("TOPLEFT",14,-82)
    card.expense:SetPoint("RIGHT",-12,0)
    card.expense:SetJustifyH("LEFT")
    return card
  end

  local cardW=228
  p.cardToday=makeCard(16,cardW,"오늘 순증감")
  p.cardWeek=makeCard(16+(cardW+10),cardW,"최근 7일")
  p.cardMonth=makeCard(16+(cardW+10)*2,cardW,"이번 달")
  p.cardTotal=makeCard(16+(cardW+10)*3,cardW,"총 보유 골드")

  local left=CreateFrame("Frame",nil,p,"BackdropTemplate")
  left:SetPoint("TOPLEFT",16,-121)
  left:SetSize(382,408)
  self:Backdrop(left,C.panel,C.border)
  left:SetBackdropColor(C.panel[1],C.panel[2],C.panel[3],0.76)
  p.charPanel=left

  local lt=self:Font(left,14,"캐릭터별 현재 골드",C.text)
  lt:SetPoint("TOPLEFT",14,-14)
  p.charCount=self:Font(left,9,"",C.muted)
  p.charCount:SetPoint("TOPRIGHT",-14,-17)
  p.charCount:SetJustifyH("RIGHT")

  local allBtn=self:Button(left,"전체 캐릭터",104,24,function()
    p.selectedChar=nil
    p.ledgerOffset=0
    p:Refresh()
  end)
  allBtn:SetPoint("TOPLEFT",14,-42)
  p.allButton=allBtn

  p.charSelected=self:Font(left,9,"전체 거래 내역 표시",C.accent)
  p.charSelected:SetPoint("LEFT",allBtn,"RIGHT",10,0)
  p.charSelected:SetPoint("RIGHT",-12,0)
  p.charSelected:SetJustifyH("LEFT")

  local charScroll=CreateFrame("ScrollFrame",nil,left,"UIPanelScrollFrameTemplate")
  -- Keep a little breathing room above the first character row. Inline money
  -- textures/font ascenders can otherwise be clipped by the ScrollFrame's top edge.
  charScroll:SetPoint("TOPLEFT",12,-76)
  charScroll:SetPoint("BOTTOMRIGHT",-28,68)
  charScroll:EnableMouseWheel(true)
  local charChild=CreateFrame("Frame",nil,charScroll)
  charChild:SetWidth(334)
  charChild:SetHeight(1)
  charScroll:SetScrollChild(charChild)
  p.charScroll=charScroll
  p.charChild=charChild
  p.goldRows={}

  local GOLD_ROW_STEP=30
  local GOLD_ROW_HEIGHT=28
  local GOLD_LIST_TOP_PAD=5

  local function createGoldRow(i)
    local row=CreateFrame("Button",nil,charChild,"BackdropTemplate")
    local y=-(GOLD_LIST_TOP_PAD+(i-1)*GOLD_ROW_STEP)
    row:SetPoint("TOPLEFT",0,y)
    row:SetPoint("TOPRIGHT",0,y)
    row:SetHeight(GOLD_ROW_HEIGHT)
    UI:Backdrop(row,C.panel2,C.border)
    row:SetBackdropColor(0,0,0,0)
    row:SetBackdropBorderColor(0,0,0,0)
    row.rank=UI:SingleLine(UI:Font(row,9,"",C.muted)); row.rank:SetPoint("LEFT",5,0); row.rank:SetWidth(24); row.rank:SetJustifyH("LEFT")
    row.name=UI:SingleLine(UI:Font(row,10,"",C.text)); row.name:SetPoint("LEFT",31,0); row.name:SetWidth(142); row.name:SetJustifyH("LEFT")
    row.amount=UI:SingleLine(UI:Font(row,10,"",C.text)); row.amount:SetPoint("RIGHT",-4,0); row.amount:SetWidth(178); row.amount:SetJustifyH("RIGHT")
    row:SetScript("OnClick",function(self)
      if not self.charKey then return end
      if p.selectedChar==self.charKey then p.selectedChar=nil else p.selectedChar=self.charKey end
      p.ledgerOffset=0
      p:Refresh()
    end)
    row:SetScript("OnEnter",function(self)
      if self.charKey and p.selectedChar~=self.charKey then self:SetBackdropColor(C.panel2[1],C.panel2[2],C.panel2[3],.78) end
      if self.charKey and GameTooltip then
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        GameTooltip:AddLine(self.charName or "",1,1,1)
        if self.realm and self.realm~="" then GameTooltip:AddLine(self.realm,.7,.75,.82) end
        if self.lastSeen and self.lastSeen>0 then GameTooltip:AddLine("마지막 확인: "..date("%m/%d %H:%M",self.lastSeen),.7,.75,.82) end
        if self.verified==false then GameTooltip:AddLine("현재 골드가 아직 검증되지 않은 기록입니다.",1,.72,.25) end
        GameTooltip:Show()
      end
    end)
    row:SetScript("OnLeave",function(self)
      if p.selectedChar~=self.charKey then self:SetBackdropColor(0,0,0,0) end
      if GameTooltip then GameTooltip:Hide() end
    end)
    return row
  end

  function p:EnsureGoldRows(count)
    for i=#self.goldRows+1,count do self.goldRows[i]=createGoldRow(i) end
  end

  charScroll:SetScript("OnMouseWheel",function(_,delta)
    local summary=NT:GetGoldSummary() or {}
    local count=type(summary.characters)=="table" and #summary.characters or 0
    local viewHeight=charScroll:GetHeight() or 1
    local maximum=math.max(0,GOLD_LIST_TOP_PAD + count*GOLD_ROW_STEP + 4 - viewHeight)
    local current=charScroll.GetVerticalScroll and (charScroll:GetVerticalScroll() or 0) or 0
    if charScroll.SetVerticalScroll then charScroll:SetVerticalScroll(clamp(current-delta*56,0,maximum)) end
  end)

  local bankLine=left:CreateTexture(nil,"ARTWORK")
  bankLine:SetColorTexture(C.border[1],C.border[2],C.border[3],.62)
  bankLine:SetPoint("BOTTOMLEFT",12,56); bankLine:SetPoint("BOTTOMRIGHT",-12,56); bankLine:SetHeight(1)
  p.totalLine=self:Font(left,11,"",C.warn)
  p.totalLine:SetPoint("BOTTOMLEFT",14,34); p.totalLine:SetPoint("BOTTOMRIGHT",-14,34); p.totalLine:SetJustifyH("LEFT")
  p.bankLine=self:Font(left,9,"",C.muted)
  p.bankLine:SetPoint("BOTTOMLEFT",14,12); p.bankLine:SetPoint("BOTTOMRIGHT",-14,12); p.bankLine:SetJustifyH("LEFT")

  local right=CreateFrame("Frame",nil,p,"BackdropTemplate")
  right:SetPoint("TOPLEFT",left,"TOPRIGHT",10,0)
  right:SetPoint("TOPRIGHT",p,"TOPRIGHT",-16,-121)
  right:SetHeight(408)
  self:Backdrop(right,C.panel,C.border)
  right:SetBackdropColor(C.panel[1],C.panel[2],C.panel[3],0.76)
  p.ledgerPanel=right

  local rt=self:Font(right,14,"최근 거래 내역",C.text)
  rt:SetPoint("TOPLEFT",14,-14)
  p.ledgerTitle=self:Font(right,9,"",C.accent)
  p.ledgerTitle:SetPoint("TOPRIGHT",-14,-17)
  p.ledgerTitle:SetJustifyH("RIGHT")

  local refresh=self:Button(right,"새로고침",82,24,function()
    NT:SyncGoldBackup()
    if type(NT.RefreshWarbandMoney)=="function" then pcall(NT.RefreshWarbandMoney) end
    p:Refresh()
  end)
  refresh:SetPoint("TOPRIGHT",-14,-40)

  p.periodButtons={}
  local px=14
  for _,it in ipairs(PERIODS) do
    local days,label=it[1],it[2]
    local b=self:Button(right,label,48,24,function()
      p.goldDays=days; p.ledgerOffset=0; p:RefreshLedger()
    end)
    b:SetPoint("TOPLEFT",px,-40)
    b.periodDays=days
    p.periodButtons[#p.periodButtons+1]=b
    px=px+54
  end

  p.filterButtons={}
  local fx=14
  for _,it in ipairs(FILTERS) do
    local item=it
    local w=(item.id=="AUCTION") and 64 or 52
    local b=self:Button(right,item.text,w,23,function()
      p.goldFilter=item.id; p.ledgerOffset=0; p:RefreshLedger()
    end)
    b:SetPoint("TOPLEFT",fx,-72)
    b.filterId=item.id
    p.filterButtons[#p.filterButtons+1]=b
    fx=fx+w+5
  end

  local searchBg=CreateFrame("Frame",nil,right,"BackdropTemplate")
  searchBg:SetPoint("TOPLEFT",14,-104); searchBg:SetPoint("TOPRIGHT",-14,-104); searchBg:SetHeight(28)
  self:Backdrop(searchBg,C.panel2,C.border)
  local searchIcon=self:Font(searchBg,10,"⌕",C.muted); searchIcon:SetPoint("LEFT",8,0)
  local search=CreateFrame("EditBox",nil,searchBg)
  search:SetPoint("LEFT",searchIcon,"RIGHT",6,0); search:SetPoint("RIGHT",-8,0); search:SetHeight(24)
  search:SetAutoFocus(false); search:SetFontObject("GameFontHighlight")
  search:SetTextInsets(0,0,0,0)
  p.searchBox=search
  p.searchPlaceholder=self:Font(searchBg,9,"상대 / 내용 검색",C.muted)
  p.searchPlaceholder:SetPoint("LEFT",searchIcon,"RIGHT",7,0)
  search:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
  search:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)
  search:SetScript("OnTextChanged",function(self)
    p.goldSearch=self:GetText() or ""
    p.searchPlaceholder:SetShown(p.goldSearch=="")
    p.ledgerOffset=0
    if p.RefreshLedger then p:RefreshLedger() end
  end)

  local headLine=right:CreateTexture(nil,"ARTWORK")
  headLine:SetColorTexture(C.border[1],C.border[2],C.border[3],.60)
  headLine:SetPoint("TOPLEFT",14,-140); headLine:SetPoint("TOPRIGHT",-14,-140); headLine:SetHeight(1)
  local headTime=self:Font(right,9,"날짜/시간",C.muted); headTime:SetPoint("TOPLEFT",18,-149); headTime:SetWidth(84); headTime:SetJustifyH("LEFT")
  local headKind=self:Font(right,9,"구분",C.muted); headKind:SetPoint("TOPLEFT",105,-149); headKind:SetWidth(82); headKind:SetJustifyH("LEFT")
  local headAmount=self:Font(right,9,"금액",C.muted); headAmount:SetPoint("TOPLEFT",191,-149); headAmount:SetWidth(142); headAmount:SetJustifyH("LEFT")
  local headWho=self:Font(right,9,"상대 · 내용",C.muted); headWho:SetPoint("TOPLEFT",338,-149); headWho:SetPoint("RIGHT",-16,0); headWho:SetJustifyH("LEFT")

  local list=CreateFrame("Frame",nil,right)
  list:SetPoint("TOPLEFT",14,-172); list:SetPoint("TOPRIGHT",-14,-172); list:SetHeight(192); list:EnableMouseWheel(true)
  p.ledgerVisibleRows=8
  p.ledgerList=list
  p.ledgerRows={}
  for i=1,10 do
    local row=CreateFrame("Frame",nil,list)
    row:SetPoint("TOPLEFT",0,-(i-1)*24); row:SetPoint("TOPRIGHT",0,-(i-1)*24); row:SetHeight(23)
    if i%2==0 then
      row.bg=row:CreateTexture(nil,"BACKGROUND"); row.bg:SetAllPoints(); row.bg:SetColorTexture(C.panel2[1],C.panel2[2],C.panel2[3],.18)
    end
    row.time=self:Font(row,9,"",C.muted); row.time:SetPoint("LEFT",4,0); row.time:SetWidth(84); row.time:SetJustifyH("LEFT")
    row.kind=self:Font(row,9,"",C.text); row.kind:SetPoint("LEFT",91,0); row.kind:SetWidth(82); row.kind:SetJustifyH("LEFT")
    row.amount=self:Font(row,9,"",C.text); row.amount:SetPoint("LEFT",177,0); row.amount:SetWidth(143); row.amount:SetJustifyH("LEFT")
    row.who=self:Font(row,9,"",C.muted); row.who:SetPoint("LEFT",324,0); row.who:SetPoint("RIGHT",-4,0); row.who:SetJustifyH("LEFT")
    p.ledgerRows[i]=row
  end
  p.ledgerEmpty=self:Font(right,10,"",C.muted); p.ledgerEmpty:SetPoint("TOPLEFT",20,-198); p.ledgerEmpty:SetPoint("RIGHT",-18,0); p.ledgerEmpty:SetJustifyH("LEFT")
  p.ledgerMore=self:Font(right,9,"",C.muted); p.ledgerMore:SetPoint("BOTTOMLEFT",16,12)

  list:SetScript("OnMouseWheel",function(_,delta)
    local total=p.ledgerTotal or 0
    local visible=p.ledgerVisibleRows or 8
    local maximum=math.max(0,total-visible)
    p.ledgerOffset=clamp((p.ledgerOffset or 0)-delta*3,0,maximum)
    if p.RefreshLedger then p:RefreshLedger() end
  end)

  local function setButtonActive(b,on)
    if on then
      b:SetBackdropColor(C.accent[1]*.16,C.accent[2]*.16,C.accent[3]*.16,1)
      b:SetBackdropBorderColor(C.accent[1],C.accent[2],C.accent[3],.95)
      b.label:SetTextColor(C.accent[1],C.accent[2],C.accent[3],1)
    else
      b:SetBackdropColor(C.panel2[1],C.panel2[2],C.panel2[3],.72)
      b:SetBackdropBorderColor(C.border[1],C.border[2],C.border[3],.82)
      b.label:SetTextColor(C.text[1],C.text[2],C.text[3],1)
    end
  end

  p.RefreshLedger=function(self,summary)
    local g=summary or NT:GetGoldSummary()
    local label
    if self.selectedChar then
      for _,c in ipairs(g.characters or {}) do if c.key==self.selectedChar then label=c.name break end end
    end
    self.ledgerTitle:SetText(label and (label.."만 보기") or "전체 캐릭터")

    for _,b in ipairs(self.periodButtons) do setButtonActive(b,b.periodDays==self.goldDays) end
    for _,b in ipairs(self.filterButtons) do setButtonActive(b,b.filterId==self.goldFilter) end

    local query=(self.goldSearch or ""):lower()
    local entries={}
    for _,e in ipairs(NT:GetRecentGoldEntries(self.goldDays,self.selectedChar)) do
      if filterMatch(e.kind,self.goldFilter) then
        local matched=true
        if query~="" then
          local hay=table.concat({tostring(e.who or ""),tostring(e.detail or ""),tostring(NT:GetGoldKindLabel(e.kind) or "")}," "):lower()
          matched=hay:find(query,1,true)~=nil
        end
        if matched then entries[#entries+1]=e end
      end
    end

    self.ledgerTotal=#entries
    local visible=self.ledgerVisibleRows or 8
    local maximum=math.max(0,#entries-visible)
    self.ledgerOffset=clamp(self.ledgerOffset or 0,0,maximum)
    local offset=self.ledgerOffset
    for i,row in ipairs(self.ledgerRows) do
      local e=(i<=visible) and entries[offset+i] or nil
      if e then
        row.time:SetText(date("%m/%d %H:%M",e.t))
        row.kind:SetText(NT:GetGoldKindLabel(e.kind))
        if e.kind=="trade_in" or e.kind=="trade_out" then row.kind:SetTextColor(C.accent[1],C.accent[2],C.accent[3],1)
        else row.kind:SetTextColor(C.text[1],C.text[2],C.text[3],1) end
        row.amount:SetText(UI:MoneyInline(e.amount,true))
        local col=UI:GoldColor(e.amount); row.amount:SetTextColor(col[1],col[2],col[3],1)
        local who=e.who; local detail=e.detail; local isTrade=e.kind=="trade_in" or e.kind=="trade_out"
        local text=""
        if who and who~="" then
          local shown=isTrade and UI:ColorText(who,C.accent) or who
          text=(detail and detail~="") and (shown.." · "..detail) or shown
        elseif isTrade then text=UI:ColorText("상대 확인 불가",C.warn)
        else text=detail or "" end
        row.who:SetText(text); row:Show()
      else row:Hide() end
    end
    self.ledgerEmpty:SetShown(#entries==0)
    if #entries==0 then self.ledgerEmpty:SetText("조건에 맞는 골드 기록이 아직 없어요.") end
    if #entries>0 then
      self.ledgerMore:SetText(string.format("%d–%d / %d건 · 마우스휠로 스크롤",offset+1,math.min(offset+visible,#entries),#entries))
    else self.ledgerMore:SetText("") end
  end

  local function setCard(card,amount,income,expense,colorAmount)
    card.value:SetText(UI:MoneyInline(amount,true))
    local col=UI:GoldColor(colorAmount==nil and amount or colorAmount)
    card.value:SetTextColor(col[1],col[2],col[3],1)
    card.income:SetText("수입  "..UI:MoneyInline(income,false))
    card.expense:SetText("지출  "..UI:MoneyInline(expense,false))
  end

  p.Refresh=function(self)
    local g=NT:GetGoldSummary()
    setCard(self.cardToday,g.todayNet,g.todayIncome,g.todayExpense)
    setCard(self.cardWeek,g.weekNet,g.weekIncome,g.weekExpense)
    setCard(self.cardMonth,g.monthNet,g.monthIncome,g.monthExpense)
    self.cardTotal.value:SetText(UI:MoneyInline(g.totalWithBank,false))
    self.cardTotal.value:SetTextColor(C.warn[1],C.warn[2],C.warn[3],1)
    self.cardTotal.income:SetText("캐릭터  "..UI:MoneyInline(g.tracked,false))
    if g.warbandGold~=nil then
      self.cardTotal.expense:SetText("전투부대  "..UI:MoneyInline(g.warbandGold,false))
    else
      self.cardTotal.expense:SetText("전투부대  미확인")
    end

    if self.selectedChar then
      local found=false
      for _,c in ipairs(g.characters or {}) do if c.key==self.selectedChar then found=true break end end
      if not found then self.selectedChar=nil; self.ledgerOffset=0 end
    end

    self:EnsureGoldRows(#(g.characters or {}))
    for _,row in ipairs(self.goldRows) do
      row.charKey=nil; row.rank:SetText(""); row.name:SetText(""); row.amount:SetText(""); row:Hide()
      row:SetBackdropColor(0,0,0,0); row:SetBackdropBorderColor(0,0,0,0)
    end
    local viewHeight=self.charScroll:GetHeight() or 1
    self.charChild:SetWidth(math.max(1,(self.charScroll:GetWidth() or 334)-4))
    self.charChild:SetHeight(math.max(viewHeight,GOLD_LIST_TOP_PAD + #g.characters*GOLD_ROW_STEP + 4))
    -- Never allow a stale fractional/negative scroll position to cut into row 1.
    if self.charScroll and self.charScroll.GetVerticalScroll and self.charScroll.SetVerticalScroll then
      local maxScroll=math.max(0,(self.charChild:GetHeight() or viewHeight)-viewHeight)
      local current=self.charScroll:GetVerticalScroll() or 0
      self.charScroll:SetVerticalScroll(clamp(current,0,maxScroll))
    end
    for i,c in ipairs(g.characters or {}) do
      local row=self.goldRows[i]
      row.charKey=c.key; row.charName=c.name; row.realm=c.realm; row.lastSeen=c.lastSeen; row.verified=c.goldVerified
      row.rank:SetText(i..".")
      row.name:SetText(c.name or "?")
      local classColor=c.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[c.class]
      if classColor then row.name:SetTextColor(classColor.r,classColor.g,classColor.b,1) else row.name:SetTextColor(C.text[1],C.text[2],C.text[3],1) end
      row.amount:SetText(UI:MoneyInline(c.gold,false))
      row.amount:SetTextColor(C.text[1],C.text[2],C.text[3],1)
      row:Show()
      if self.selectedChar==c.key then
        row:SetBackdropColor(C.accent[1]*.18,C.accent[2]*.18,C.accent[3]*.18,1)
        row:SetBackdropBorderColor(C.accent[1],C.accent[2],C.accent[3],.88)
        row.amount:SetTextColor(C.accent[1],C.accent[2],C.accent[3],1)
      end
    end
    self.charCount:SetText(#g.characters.."캐릭터")
    self.totalLine:SetText("캐릭터 합계  "..UI:MoneyInline(g.tracked,false))
    if g.warbandGold~=nil then
      local updated=g.warbandUpdated and date("%m/%d %H:%M",g.warbandUpdated) or "-"
      self.bankLine:SetText("전투부대 은행  "..UI:MoneyInline(g.warbandGold,false).."  ·  "..updated)
    else self.bankLine:SetText("전투부대 은행 · 은행을 한 번 열면 잔액을 저장합니다.") end
    if self.selectedChar then
      local selected=""
      for _,c in ipairs(g.characters) do if c.key==self.selectedChar then selected=c.name or "" break end end
      self.charSelected:SetText(selected~="" and (selected.." 거래만 표시") or "전체 거래 내역 표시")
    else self.charSelected:SetText("전체 거래 내역 표시") end
    setButtonActive(self.allButton,self.selectedChar==nil)
    self:RefreshLedger(g)
  end
end
function UI:BuildMedia()
  local p=self:NewPage("MEDIA")
  self:PrepareAccordionPage(p)
  local function mediaDB() return NT:GetDB().modules.media end

  local function setControlEnabled(control,enabled)
    if not control then return end
    control:SetAlpha(enabled and 1 or .34)
    if control.EnableMouse then control:EnableMouse(enabled) end
    if control.slider and control.slider.EnableMouse then control.slider:EnableMouse(enabled) end
    if control.button and control.button.EnableMouse then control.button:EnableMouse(enabled) end
  end

  -- 1) GTFO · 위험 경고음 -----------------------------------------------------------
  local gtfo=self:AccordionSection(p,"gtfo","GTFO · 위험 경고음","바닥 위험 경고 종류 · BigWigs 발밑음 브리지",210,true)
  p.gtfoRows={}
  local function proxy()
    local m=NT:GetMediaStatus(); if not m.gtfoReady then return nil end
    return {high=m.gtfoHigh,low=m.gtfoLow,fail=m.gtfoFail,friendly=m.gtfoFriendly}
  end
  local function setLevel(level,on)
    if type(_G.NiniMedia_SetGTFOCategory)~="function" or not _G.NiniMedia_SetGTFOCategory(level,on) then
      NT:Print("GTFO가 설치/로드되어 있는지 확인하세요.")
    end
  end
  local labels={{"큰 피해 · High Damage","high",1},{"낮은 피해 · Low Damage","low",2},{"실수 / 실패 · Fail","fail",3},{"아군 피해 · Friendly Fire","friendly",4}}
  for i,it in ipairs(labels) do
    local row=self:Toggle(gtfo.body,it[1],it[2],proxy,function(v) setLevel(it[3],v) end,-16-(i-1)*38)
    row:ClearAllPoints(); row:SetPoint("TOPLEFT",18,-12-(i-1)*38); row:SetSize(430,36)
    p.gtfoRows[#p.gtfoRows+1]=row
  end

  local gtfoInfo=CreateFrame("Frame",nil,gtfo.body,"BackdropTemplate")
  gtfoInfo:SetPoint("TOPLEFT",474,-14); gtfoInfo:SetPoint("BOTTOMRIGHT",-18,86)
  self:Backdrop(gtfoInfo,C.panel2,C.border)
  gtfoInfo:SetBackdropColor(C.panel2[1],C.panel2[2],C.panel2[3],0.52)
  p.mediaStatus=self:Font(gtfoInfo,10,"",C.text)
  p.mediaStatus:SetPoint("TOPLEFT",14,-14); p.mediaStatus:SetPoint("RIGHT",-14,0); p.mediaStatus:SetJustifyH("LEFT")

  local b1=self:Button(gtfo.body,"발밑 소리 테스트",144,28,function()
    if type(_G.NiniMedia_TestFloorSound)=="function" then _G.NiniMedia_TestFloorSound() end
    C_Timer.After(.15,function() UI:RefreshVisiblePage() end)
  end); b1:SetPoint("TOPLEFT",474,-130)
  local b2=self:Button(gtfo.body,"GTFO 소리 재적용",144,28,function()
    if type(_G.NiniMedia_ReapplyGTFO)=="function" then _G.NiniMedia_ReapplyGTFO() end
    C_Timer.After(.15,function() UI:RefreshVisiblePage() end)
  end); b2:SetPoint("LEFT",b1,"RIGHT",10,0)

  -- 2) 효과음 ------------------------------------------------------------------------
  local effects=self:AccordionSection(p,"effects","효과음","뜌미 초읽기/승리 · 점프 WaterDrop",182,false)
  local voiceCard=CreateFrame("Frame",nil,effects.body,"BackdropTemplate")
  voiceCard:SetPoint("TOPLEFT",18,-16); voiceCard:SetSize(448,150)
  self:Backdrop(voiceCard,C.panel2,C.border)
  voiceCard:SetBackdropColor(C.panel2[1],C.panel2[2],C.panel2[3],0.52)
  local voiceTitle=self:Font(voiceCard,11,"뜌미 음성",C.text); voiceTitle:SetPoint("TOPLEFT",14,-14)
  p.voiceStatus=self:Font(voiceCard,9,"",C.muted); p.voiceStatus:SetPoint("TOPLEFT",14,-44); p.voiceStatus:SetPoint("RIGHT",-14,0)
  local vb=self:Button(voiceCard,"승리 소리 테스트",140,28,function() NT:TestVictorySound() end); vb:SetPoint("BOTTOMLEFT",14,14)

  local jumpCard=CreateFrame("Frame",nil,effects.body,"BackdropTemplate")
  jumpCard:SetPoint("TOPLEFT",482,-16); jumpCard:SetPoint("TOPRIGHT",-18,-16); jumpCard:SetHeight(150)
  self:Backdrop(jumpCard,C.panel2,C.border)
  jumpCard:SetBackdropColor(C.panel2[1],C.panel2[2],C.panel2[3],0.52)
  local jumpTitle=self:Font(jumpCard,11,"점프 효과음",C.text); jumpTitle:SetPoint("TOPLEFT",14,-14)
  p.jumpRow=self:Toggle(jumpCard,"점프 소리 사용","jumpSoundEnabled",mediaDB,function() NT:RefreshJumpSound() end,-42)
  p.jumpRow:ClearAllPoints(); p.jumpRow:SetPoint("TOPLEFT",10,-36); p.jumpRow:SetPoint("TOPRIGHT",-10,-36)
  local jumpTest=self:Button(jumpCard,"점프 소리 테스트",140,28,function() NT:TestJumpSound() end); jumpTest:SetPoint("BOTTOMLEFT",14,14)

  -- 3) CallMe · 이름 호출 -------------------------------------------------------------
  local callme=self:AccordionSection(p,"callme","CallMe · 이름 호출","'니니' · 캐릭터 이름 · 등록 별명 감지 후 Navi Hey",224,false)
  p.callMeRow=self:Toggle(callme.body,"내 이름 / 별명 호출 알림","callMeEnabled",mediaDB,nil,-12)
  p.callMeRow:ClearAllPoints(); p.callMeRow:SetPoint("TOPLEFT",18,-10); p.callMeRow:SetPoint("TOPRIGHT",-180,-10); p.callMeRow:SetHeight(38)
  local callTest=self:Button(callme.body,"Hey 소리 테스트",142,28,function() NT:TestCallMeSound() end); callTest:SetPoint("TOPRIGHT",-18,-14)

  p.callMeVolumeRow=self:SliderRow(callme.body,"Hey 소리 크기",-54,50,250,10,
    function() return NT.GetCallMeVolume and NT:GetCallMeVolume() or (mediaDB().callMeVolume or 160) end,
    function(v) if NT.SetCallMeVolume then NT:SetCallMeVolume(v) else mediaDB().callMeVolume=math.floor(v+.5) end end,
    function(v) return math.floor(v+.5).."%" end)

  local aliasLabel=self:Font(callme.body,10,"별명",C.text); aliasLabel:SetPoint("TOPLEFT",22,-106)
  local aliasFrame=CreateFrame("Frame",nil,callme.body,"BackdropTemplate")
  aliasFrame:SetPoint("TOPLEFT",78,-100); aliasFrame:SetPoint("TOPRIGHT",-174,-100); aliasFrame:SetHeight(30)
  self:Backdrop(aliasFrame,C.panel2,C.border)
  local aliasEdit=CreateFrame("EditBox",nil,aliasFrame)
  aliasEdit:SetPoint("TOPLEFT",8,-3); aliasEdit:SetPoint("BOTTOMRIGHT",-8,3)
  aliasEdit:SetAutoFocus(false); aliasEdit:SetFontObject(ChatFontNormal); aliasEdit:SetTextInsets(2,2,0,0); aliasEdit:SetMaxLetters(300)
  p.callMeAliasEdit=aliasEdit
  local function saveAliases()
    local ok,text=NT:SetCallMeAliasesText(aliasEdit:GetText() or "")
    if ok then
      aliasEdit:SetText(text or ""); aliasEdit:ClearFocus()
      NT:Print("CallMe 별명 저장: "..((text and text~="") and text or "없음"))
    end
  end
  aliasEdit:SetScript("OnEnterPressed",saveAliases)
  aliasEdit:SetScript("OnEscapePressed",function(self) self:SetText(NT:GetCallMeAliasesText() or ""); self:ClearFocus() end)
  local aliasSave=self:Button(callme.body,"별명 저장",128,28,saveAliases); aliasSave:SetPoint("TOPRIGHT",-18,-101)
  local callNote=self:Font(callme.body,9,"쉼표로 여러 개 등록 · '니니'와 현재 캐릭터 이름은 자동 포함",C.muted)
  callNote:SetPoint("TOPLEFT",22,-143); callNote:SetPoint("RIGHT",-18,0)
  local callNote2=self:Font(callme.body,9,"내가 직접 보낸 채팅은 제외 · 호출 시 Navi 채팅에도 ★ 강조 표시",C.muted)
  callNote2:SetPoint("TOPLEFT",22,-170); callNote2:SetPoint("RIGHT",-18,0)
  local callNote3=self:Font(callme.body,9,"Hey 음량은 50~250% · 기본 160% · Master 채널로 재생",C.muted)
  callNote3:SetPoint("TOPLEFT",22,-197); callNote3:SetPoint("RIGHT",-18,0)

  -- 4) Navi · 마우스 커서 -------------------------------------------------------------
  local navi=self:AccordionSection(p,"navi","Navi · 마우스 커서","커서 강조 효과 · 실시간 미리보기 · Navi 채팅",320,false)
  p.naviCursorRow=self:Toggle(navi.body,"마우스 Navi 사용","naviCursorEnabled",mediaDB,function(v) NT:SetNaviCursorEnabled(v) end,-10)
  p.naviCursorRow:ClearAllPoints(); p.naviCursorRow:SetPoint("TOPLEFT",18,-8); p.naviCursorRow:SetSize(420,36)
  p.naviRingRow=self:Toggle(navi.body,"커서 링","naviCursorRingEnabled",mediaDB,function(v) if NT.SetNaviCursorRingEnabled then NT:SetNaviCursorRingEnabled(v) end end,-48)
  p.naviRingRow:ClearAllPoints(); p.naviRingRow:SetPoint("TOPLEFT",18,-46); p.naviRingRow:SetSize(420,36)
  p.naviGlowRow=self:Toggle(navi.body,"반짝임 효과","naviCursorGlowEnabled",mediaDB,function(v) if NT.SetNaviCursorGlowEnabled then NT:SetNaviCursorGlowEnabled(v) end end,-86)
  p.naviGlowRow:ClearAllPoints(); p.naviGlowRow:SetPoint("TOPLEFT",18,-84); p.naviGlowRow:SetSize(420,36)
  p.naviScaleRow=self:SliderRow(navi.body,"크기",-126,70,140,5,
    function() return NT.GetNaviCursorScale and NT:GetNaviCursorScale() or (mediaDB().naviCursorScale or 100) end,
    function(v) if NT.SetNaviCursorScale then NT:SetNaviCursorScale(v) else mediaDB().naviCursorScale=math.floor(v+.5) end end,
    function(v) return math.floor(v+.5).."%" end)
  p.naviScaleRow:ClearAllPoints(); p.naviScaleRow:SetPoint("TOPLEFT",18,-122); p.naviScaleRow:SetSize(420,34)

  -- Animated preview using the same geometry/offsets as NaviCursor.lua.
  -- Keep a dedicated preview scale instead of collapsing every layer onto one center point.
  local preview=CreateFrame("Frame",nil,navi.body,"BackdropTemplate")
  preview:SetPoint("TOPLEFT",474,-12); preview:SetPoint("TOPRIGHT",-18,-12); preview:SetHeight(178)
  self:Backdrop(preview,C.panel2,C.border)
  preview:SetBackdropColor(.025,.045,.070,.92)
  local previewTitle=self:Font(preview,9,"실시간 Navi 미리보기",C.muted); previewTitle:SetPoint("TOPLEFT",12,-10)
  local center=CreateFrame("Frame",nil,preview); center:SetSize(1,1); center:SetPoint("CENTER",-34,-24)
  local PREVIEW_SCALE=.82

  local function makePreviewTexture(name,w,h,x,y,textureOrAtlas,color,alpha)
    local region=CreateFrame("Frame",nil,center)
    region.name=name; region.baseWidth=w; region.baseHeight=h; region.baseX=x; region.baseY=y; region.baseAlpha=alpha or 1
    region:SetSize(w*PREVIEW_SCALE,h*PREVIEW_SCALE)
    region:SetPoint("CENTER",center,"CENTER",x*PREVIEW_SCALE,y*PREVIEW_SCALE)
    local tex=region:CreateTexture(nil,"ARTWORK"); tex:SetAllPoints(region)
    local atlas=false
    if type(textureOrAtlas)=="string" then
      if C_Texture and C_Texture.GetAtlasInfo then local ok,info=pcall(C_Texture.GetAtlasInfo,textureOrAtlas); atlas=ok and info and true or false end
      if not atlas and GetAtlasInfo then local ok,info=pcall(GetAtlasInfo,textureOrAtlas); atlas=ok and info and true or false end
    end
    if atlas and tex.SetAtlas then
      pcall(tex.SetAtlas,tex,textureOrAtlas)
    else
      local ok=pcall(tex.SetTexture,tex,textureOrAtlas,"CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
      if not ok then pcall(tex.SetTexture,tex,textureOrAtlas) end
    end
    if tex.SetDesaturated then tex:SetDesaturated(false) end
    tex:SetBlendMode("ADD")
    local r,g,b,a=unpack(color); tex:SetVertexColor(r,g,b,a)
    region.texture=tex; region:SetAlpha(region.baseAlpha)
    return region
  end

  local pvBackground=makePreviewTexture("background",30,30,56.817220306396,48.241638183594,"Interface\\AddOns\\NiniTools\\Media\\Aura87.tga",{1,1,1,1},.6)
  local pvModelRegion=CreateFrame("Frame",nil,center)
  pvModelRegion.baseWidth=76.449096679688; pvModelRegion.baseHeight=79.665534973145; pvModelRegion.baseX=54.671766662597; pvModelRegion.baseY=40.196268919083; pvModelRegion.baseAlpha=.5
  pvModelRegion:SetSize(pvModelRegion.baseWidth*PREVIEW_SCALE,pvModelRegion.baseHeight*PREVIEW_SCALE)
  pvModelRegion:SetPoint("CENTER",center,"CENTER",pvModelRegion.baseX*PREVIEW_SCALE,pvModelRegion.baseY*PREVIEW_SCALE); pvModelRegion:SetAlpha(.5)
  local pvModel=CreateFrame("PlayerModel",nil,pvModelRegion); pvModel:SetAllPoints(pvModelRegion)
  if pvModel.SetKeepModelOnHide then pcall(pvModel.SetKeepModelOnHide,pvModel,true) end
  pcall(pvModel.SetModel,pvModel,166890); if pvModel.SetPortraitZoom then pcall(pvModel.SetPortraitZoom,pvModel,0) end; if pvModel.ClearTransform then pcall(pvModel.ClearTransform,pvModel) end; if pvModel.SetPosition then pcall(pvModel.SetPosition,pvModel,-5.05,0,-1.9) end; if pvModel.SetFacing then pcall(pvModel.SetFacing,pvModel,0) end
  local pvOrb=makePreviewTexture("orb",60,60,53.602864837646,43.95361328125,"Artifacts-Anim-Orb",{0.462745,0.549020,1,.65},1)
  local pvCircle=makePreviewTexture("circle",55,55,53.602864837646,45.025573730469,"BonusChest-CircleGlow",{0,0.262745,1,1},1)
  pvBackground:SetFrameLevel(center:GetFrameLevel()+1); pvModelRegion:SetFrameLevel(center:GetFrameLevel()+2); pvOrb:SetFrameLevel(center:GetFrameLevel()+3); pvCircle:SetFrameLevel(center:GetFrameLevel()+4)
  local cursorGlyph=self:Font(preview,18,"✥",C.text); cursorGlyph:SetPoint("CENTER",center,"CENTER",0,0); cursorGlyph:SetAlpha(.88)
  local pvBorn=GetTime()
  preview:SetScript("OnUpdate",function()
    local db=mediaDB(); if not db then return end
    local enabled=db.naviCursorEnabled~=false
    local ring=db.naviCursorRingEnabled~=false
    local glow=db.naviCursorGlowEnabled~=false
    local scale=math.max(.7,math.min(1.4,(tonumber(db.naviCursorScale) or 100)/100))*PREVIEW_SCALE
    local age=GetTime()-pvBorn
    local progress=((age%0.75)/0.75)
    local angle=(progress*2*math.pi)-(math.pi/2)
    local pulse=1+(((math.sin(angle)+1)/2)*.05)
    local function geometry(region,factor)
      region:SetSize(region.baseWidth*scale*factor,region.baseHeight*scale*factor)
      region:ClearAllPoints()
      region:SetPoint("CENTER",center,"CENTER",region.baseX*scale,region.baseY*scale)
    end
    pvBackground:SetShown(enabled and glow); pvOrb:SetShown(enabled and glow); pvCircle:SetShown(enabled and ring); pvModelRegion:SetShown(enabled); cursorGlyph:SetShown(enabled)
    geometry(pvBackground,pulse); geometry(pvOrb,pulse); geometry(pvCircle,pulse); geometry(pvModelRegion,1)
    pvBackground:SetAlpha(enabled and pvBackground.baseAlpha or .15); pvOrb:SetAlpha(enabled and 1 or .15); pvCircle:SetAlpha(enabled and 1 or .15); pvModelRegion:SetAlpha(enabled and pvModelRegion.baseAlpha or .15)
    cursorGlyph:SetAlpha(enabled and .88 or .18)
  end)
  local pvNote=self:Font(preview,8,"실제 Navi 오프셋 · 비율 · 알파를 그대로 축소 재현",C.muted); pvNote:SetPoint("BOTTOM",0,10)
  p.naviPreview=preview

  local sep=navi.body:CreateTexture(nil,"ARTWORK"); sep:SetColorTexture(C.border[1],C.border[2],C.border[3],.6); sep:SetPoint("TOPLEFT",18,-202); sep:SetPoint("TOPRIGHT",-18,-202); sep:SetHeight(1)
  local chatTitle=self:Font(navi.body,10,"Navi 채팅",C.text); chatTitle:SetPoint("TOPLEFT",22,-220)
  p.naviChatRow=self:Toggle(navi.body,"Navi 채팅창 사용","naviChatEnabled",mediaDB,function(v) NT:SetNaviChatEnabled(v) end,-236)
  p.naviChatRow:ClearAllPoints(); p.naviChatRow:SetPoint("TOPLEFT",18,-234); p.naviChatRow:SetSize(420,36)
  p.naviFontRow=self:SliderRow(navi.body,"채팅 글자 크기",-276,8,32,1,function() return NT:GetNaviChatFontSize() end,function(v) NT:SetNaviChatFontSize(v) end,function(v) return math.floor(v+.5).." px" end)
  p.naviFontRow:ClearAllPoints(); p.naviFontRow:SetPoint("TOPLEFT",18,-272); p.naviFontRow:SetSize(420,34)
  p.naviMove=self:Button(navi.body,"채팅 위치 이동",130,28,function() NT:SetNaviChatUnlocked(not NT:IsNaviChatUnlocked()); UI:RefreshVisiblePage() end); p.naviMove:SetPoint("TOPLEFT",474,-232)
  local naviTest=self:Button(navi.body,"채팅 테스트",112,28,function() NT:TestNaviChat() end); naviTest:SetPoint("LEFT",p.naviMove,"RIGHT",8,0)
  local naviReset=self:Button(navi.body,"위치 초기화",112,28,function() NT:ResetNaviChatPosition(); UI:RefreshVisiblePage() end); naviReset:SetPoint("LEFT",naviTest,"RIGHT",8,0)
  local naviNote=self:Font(navi.body,8,"일반 채팅은 휴식/비전투에서 간헐 표시 · 이름/별명 호출은 항상 강조",C.muted); naviNote:SetPoint("TOPLEFT",474,-276); naviNote:SetPoint("RIGHT",-18,0)

  p.Refresh=function(self)
    local m=NT:GetMediaStatus()
    local db=mediaDB()

    for _,row in ipairs(self.gtfoRows) do row:Refresh() end
    local enabledCount=0
    for _,v in ipairs({m.gtfoHigh,m.gtfoLow,m.gtfoFail,m.gtfoFriendly}) do if v then enabledCount=enabledCount+1 end end
    if not m.gtfoLoaded then
      gtfo:SetState("미설치","bad")
      self.mediaStatus:SetText("GTFO 미설치/미로드\nBigWigs 발밑음 브리지는 GTFO 로드 후 적용됩니다.")
    else
      gtfo:SetState(string.format("%d/4 · v%s",enabledCount,m.gtfoVersion),m.gtfoReady and "good" or "warn")
      self.mediaStatus:SetText(string.format("GTFO v%s\nBigWigs 발밑음 %s\nVolume %s · %s",m.gtfoVersion,m.gtfoOverride and "적용됨" or "미적용",tostring(m.gtfoVolume),m.gtfoChannel))
    end

    self.jumpRow:Refresh()
    self.voiceStatus:SetText(string.format("초읽기 1~5  %s\n승리 사운드  %s",m.countdown and "등록됨" or "미등록",m.victory and "등록됨" or "미등록"))
    effects:SetState(string.format("카운트 %s · 점프 %s",m.countdown and "OK" or "-",db.jumpSoundEnabled~=false and "ON" or "OFF"),m.countdown and "good" or "warn")

    self.callMeRow:Refresh(); self.callMeVolumeRow:Refresh()
    callme:SetEnabledState(db.callMeEnabled~=false)
    local aliases=NT:GetCallMeAliasesText() or ""
    local aliasCount=0
    for _ in aliases:gmatch("[^,]+") do aliasCount=aliasCount+1 end
    local callVolume=NT.GetCallMeVolume and NT:GetCallMeVolume() or (tonumber(db.callMeVolume) or 160)
    callme:SetState(string.format("%s · Hey %d%%",aliasCount>0 and (aliasCount.."개 별명") or "기본 이름",callVolume),db.callMeEnabled~=false and "accent" or nil)
    if self.callMeAliasEdit and not self.callMeAliasEdit:HasFocus() and self.callMeAliasEdit:GetText()~=aliases then self.callMeAliasEdit:SetText(aliases) end
    local callEnabled=db.callMeEnabled~=false
    setControlEnabled(self.callMeVolumeRow,callEnabled)
    aliasEdit:SetAlpha(callEnabled and 1 or .34); aliasEdit:EnableMouse(callEnabled); aliasSave:SetAlpha(callEnabled and 1 or .34); aliasSave:EnableMouse(callEnabled)

    self.naviCursorRow:Refresh(); self.naviRingRow:Refresh(); self.naviGlowRow:Refresh(); self.naviScaleRow:Refresh(); self.naviChatRow:Refresh(); self.naviFontRow:Refresh()
    local cursorOn=db.naviCursorEnabled~=false
    local chatOn=db.naviChatEnabled~=false
    navi:SetEnabledState(cursorOn)
    navi:SetState(string.format("커서 %d%% · 채팅 %s",tonumber(db.naviCursorScale) or 100,chatOn and "ON" or "OFF"),cursorOn and "accent" or nil)
    setControlEnabled(self.naviRingRow,cursorOn); setControlEnabled(self.naviGlowRow,cursorOn); setControlEnabled(self.naviScaleRow,cursorOn)
    setControlEnabled(self.naviFontRow,chatOn); self.naviMove:SetAlpha(chatOn and 1 or .34); self.naviMove:EnableMouse(chatOn); naviTest:SetAlpha(chatOn and 1 or .34); naviTest:EnableMouse(chatOn); naviReset:SetAlpha(chatOn and 1 or .34); naviReset:EnableMouse(chatOn)
    if self.naviMove and self.naviMove.label then self.naviMove.label:SetText(NT:IsNaviChatUnlocked() and "채팅 위치 고정" or "채팅 위치 이동") end
  end

  p:LayoutAccordions()
end

function UI:BuildQOL()
  local p=self:NewPage("QOL")
  self:PrepareAccordionPage(p)
  local mainDB=function() return NT:GetDB() end
  local waypointDB=function() return NT.Waypoints:GetDB() end

  local function setControlEnabled(control,enabled)
    if not control then return end
    control:SetAlpha(enabled and 1 or .34)
    if control.EnableMouse then control:EnableMouse(enabled) end
    if control.slider and control.slider.EnableMouse then control.slider:EnableMouse(enabled) end
    if control.button and control.button.EnableMouse then control.button:EnableMouse(enabled) end
  end

  -- 1) Graphics / display -------------------------------------------------------------
  local graphics=self:AccordionSection(p,"graphics","그래픽 / 표시","Naowh 기준 그래픽 · 전투 CVar 프리셋과 현재값 백업",116,false)
  p.optimizeStatus=self:Font(graphics.body,9,"",C.muted)
  p.optimizeStatus:SetPoint("TOPLEFT",22,-12)
  p.optimizeStatus:SetPoint("RIGHT",-22,0)
  p.optimizeStatus:SetJustifyH("LEFT")

  local g1=self:Button(graphics.body,"Naowh 그래픽 적용",160,32,function()
    if _G.NiniKick and _G.NiniKick.ApplyNaowhGraphicsPreset then _G.NiniKick.ApplyNaowhGraphicsPreset() end
    C_Timer.After(.1,function() UI:RefreshVisiblePage() end)
  end)
  g1:SetPoint("TOPLEFT",22,-42)
  local g2=self:Button(graphics.body,"전투 옵션 적용",145,32,function()
    if _G.NiniKick and _G.NiniKick.ApplyNaowhCombatPreset then _G.NiniKick.ApplyNaowhCombatPreset() end
    C_Timer.After(.1,function() UI:RefreshVisiblePage() end)
  end)
  g2:SetPoint("LEFT",g1,"RIGHT",10,0)
  local g3=self:Button(graphics.body,"현재값 백업",130,32,function()
    if _G.NiniKick and _G.NiniKick.BackupOptimizationCVars then _G.NiniKick.BackupOptimizationCVars(true) end
    C_Timer.After(.1,function() UI:RefreshVisiblePage() end)
  end)
  g3:SetPoint("LEFT",g2,"RIGHT",10,0)
  local g4=self:Button(graphics.body,"백업 복원",120,32,function()
    if _G.NiniKick and _G.NiniKick.RestoreGraphicsBackup then _G.NiniKick.RestoreGraphicsBackup() end
    C_Timer.After(.1,function() UI:RefreshVisiblePage() end)
  end)
  g4:SetPoint("LEFT",g3,"RIGHT",10,0)
  local optNote=self:Font(graphics.body,8,"100% 렌더 · D3D12 · 저지연 3 · 레이드 그래픽 최적화 / 전투 옵션은 별도 적용",C.muted)
  optNote:SetPoint("BOTTOMLEFT",22,10); optNote:SetPoint("RIGHT",-22,0)

  -- 2) Waypoint guide ----------------------------------------------------------------
  local waypoint=self:AccordionSection(p,"waypoint","목적지 안내","지도 목적지를 이름 · 금빛 기둥으로 더 잘 보이게 표시",278,true)
  local wayLeft=CreateFrame("Frame",nil,waypoint.body)
  wayLeft:SetPoint("TOPLEFT",0,0); wayLeft:SetPoint("BOTTOMLEFT",0,0); wayLeft:SetWidth(548)

  p.waypointRows={}
  p.waypointRows[1]=self:Toggle(wayLeft,"목적지 안내 강화","enabled",waypointDB,function() NT.Waypoints:Refresh() end,-8)
  p.waypointRows[2]=self:Toggle(wayLeft,"목적지 이름 표시","showName",waypointDB,function() NT.Waypoints:Refresh() end,-48)
  p.waypointRows[3]=self:Toggle(wayLeft,"금빛 기둥 표시","glow",waypointDB,function() NT.Waypoints:Refresh() end,-88)
  p.waypointRows[4]=self:Toggle(wayLeft,"안내가 흐려져도 강조 표시 유지","alwaysShow",waypointDB,function() NT.Waypoints:Refresh() end,-128)
  p.waypointScale=self:SliderRow(wayLeft,"목적지 표시 크기",-170,65,150,5,function()
    return math.floor((tonumber(waypointDB().scale) or 1)*100+.5)
  end,function(v)
    local db=waypointDB()
    db.scale=math.max(.65,math.min(1.50,(tonumber(v) or 100)/100))
    NT.Waypoints:Refresh()
  end,function(v) return math.floor((tonumber(v) or 100)+.5).."%" end)

  local wayHelp=self:Font(wayLeft,8,"WilduTools의 같은 기능과는 한쪽만 켜세요. 전투 중 처음 켜면 전투 종료 후 표시됩니다.",C.muted)
  wayHelp:SetPoint("BOTTOMLEFT",22,14); wayHelp:SetPoint("RIGHT",-10,0); wayHelp:SetJustifyH("LEFT")

  local wayPreview=CreateFrame("Frame",nil,waypoint.body,"BackdropTemplate")
  wayPreview:SetPoint("TOPRIGHT",-16,-12); wayPreview:SetSize(374,258)
  self:Backdrop(wayPreview,C.sidebar,C.border)
  wayPreview:SetBackdropColor(.025,.045,.065,.96)
  wayPreview.title=self:Font(wayPreview,8,"시뮬레이션 미리보기",C.muted); wayPreview.title:SetPoint("TOPLEFT",12,-10)
  local previewNote=self:Font(wayPreview,7,"SuperTrackedFrame 실제 구성 기준",C.muted); previewNote:SetPoint("TOPRIGHT",-12,-11)

  -- Preview the same ingredients used by Waypoints.lua rather than a decorative
  -- fake landscape.  This keeps icon / label / legacy glow placement honest.
  local previewSpec=(NT.Waypoints and NT.Waypoints.GetVisualSpec and NT.Waypoints:GetVisualSpec()) or {}
  local previewScale=.60
  wayPreview.marker=CreateFrame("Frame",nil,wayPreview)
  wayPreview.marker:SetSize(1,1)
  wayPreview.marker:SetPoint("BOTTOM",0,82)

  wayPreview.icon=wayPreview.marker:CreateTexture(nil,"OVERLAY")
  local atlasOK=false
  if wayPreview.icon.SetAtlas then atlasOK=pcall(wayPreview.icon.SetAtlas,wayPreview.icon,previewSpec.pinAtlas or "Waypoint-MapPin-Tracked",true) end
  if not atlasOK then wayPreview.icon:SetTexture("Interface\\MINIMAP\\TRACKING\\None") end
  wayPreview.icon:SetPoint("CENTER")

  wayPreview.beam=wayPreview.marker:CreateTexture(nil,"ARTWORK")
  local glowAtlasOK=false
  if wayPreview.beam.SetAtlas and previewSpec.glowAtlas then
    glowAtlasOK=pcall(wayPreview.beam.SetAtlas,wayPreview.beam,previewSpec.glowAtlas)
  end
  if glowAtlasOK then
    wayPreview.beam:SetRotation(math.pi/2)
    wayPreview.beamUsesAtlas=true
  else
    wayPreview.beam:SetTexture(previewSpec.fallbackTexture or "Interface\\AddOns\\NiniTools\\Media\\waypoint_beam.tga")
    wayPreview.beam:SetBlendMode("ADD")
    wayPreview.beamUsesAtlas=false
  end

  wayPreview.name=self:Font(wayPreview,10,"울둠의 관문",{1,.82,0})
  wayPreview.distance=self:Font(wayPreview,9,"425 m",C.text)
  wayPreview.hold=self:Font(wayPreview,7,"강조 유지",C.accent)
  wayPreview.hold:SetPoint("BOTTOMRIGHT",-14,16)
  wayPreview.disabled=self:Font(wayPreview,10,"목적지 안내 OFF",C.muted)
  wayPreview.disabled:SetPoint("CENTER",0,-6)

  function wayPreview:Refresh()
    local db=waypointDB()
    local enabled=db.enabled~=false
    local scale=math.max(.65,math.min(1.50,tonumber(db.scale) or 1))
    local s=previewScale*scale
    local iconSize=(tonumber(previewSpec.targetIconSize) or 35)*1.2*s
    self.icon:SetSize(iconSize,iconSize)
    self.beam:ClearAllPoints()
    if self.beamUsesAtlas then
      self.beam:SetPoint("TOP",self.icon,"TOP",0,(tonumber(previewSpec.glowOffsetY) or 82)*s)
      self.beam:SetSize((tonumber(previewSpec.glowWidth) or 300)*s,(tonumber(previewSpec.glowHeight) or 32)*s)
      self.beam:SetRotation(math.pi/2)
    else
      self.beam:SetPoint("BOTTOM",self.icon,"TOP",0,(tonumber(previewSpec.fallbackOffsetY) or -6)*s)
      self.beam:SetSize((tonumber(previewSpec.fallbackWidth) or 64)*s,(tonumber(previewSpec.fallbackHeight) or 190)*s)
      self.beam:SetRotation(0)
    end
    self.name:ClearAllPoints()
    self.name:SetPoint("TOP",self.icon,"BOTTOM",0,(tonumber(previewSpec.labelOffsetY) or -22)*s)
    self.distance:ClearAllPoints()
    self.distance:SetPoint("TOP",self.name,"BOTTOM",0,-2)
    self.name:SetShown(enabled and db.showName~=false)
    self.beam:SetShown(enabled and db.glow~=false)
    self.hold:SetShown(enabled and db.alwaysShow==true)
    self.icon:SetShown(enabled)
    self.distance:SetShown(enabled)
    self.disabled:SetShown(not enabled)
    self:SetAlpha(enabled and 1 or .55)
  end
  p.waypointPreview=wayPreview

  -- 3) Chat bubbles -------------------------------------------------------------------
  local bubble=self:AccordionSection(p,"bubble","채팅 말풍선","머리 위 채팅 말풍선 글자 크기를 8~20px 사이에서 조절",100,false)
  p.bubbleSlider=self:SliderRow(bubble.body,"말풍선 글자 크기",-16,8,20,1,function()
    local m=NT:GetMediaStatus()
    return math.floor((tonumber(m.bubbleSize) or 10)+.5)
  end,function(v)
    local size=math.floor((tonumber(v) or 10)+.5)
    if type(_G.NiniMedia_SetBubbleFontSize)=="function" then _G.NiniMedia_SetBubbleFontSize(size) end
  end,function(v) return math.floor((tonumber(v) or 10)+.5).." px" end)
  local bubbleNote=self:Font(bubble.body,8,"필드 · 쐐기 · 레이드 존 진입 시 저장된 크기를 다시 적용합니다.",C.muted)
  bubbleNote:SetPoint("BOTTOMLEFT",22,18); bubbleNote:SetPoint("RIGHT",-22,0)

  -- 4) Dungeon search -----------------------------------------------------------------
  local finder=self:AccordionSection(p,"finder","던전 검색","참가 신청 창 아래에 한글 던전 선택 패널 표시",106,false)
  p.finderRow=self:Toggle(finder.body,"한글 던전 검색 패널","dungeonSearchEnabled",mainDB,function()
    if NT.DungeonSearch then NT.DungeonSearch:Initialize(); NT.DungeonSearch:Refresh() end
  end,-12)
  p.finderReset=self:Button(finder.body,"검색 패널 위치 초기화",176,28,function()
    local db=NT:GetDB(); db.dungeonSearchPosition=nil
    if NT.DungeonSearch and NT.DungeonSearch.Place then NT.DungeonSearch:Place() end
    UI:RefreshVisiblePage()
  end)
  p.finderReset:SetPoint("BOTTOMLEFT",22,16)
  local finderNote=self:Font(finder.body,8,"기본 검색 필터는 유지하고, 던전 선택만 빠르게 바꿉니다.",C.muted)
  finderNote:SetPoint("LEFT",p.finderReset,"RIGHT",14,0); finderNote:SetPoint("RIGHT",-20,0); finderNote:SetJustifyH("LEFT")

  -- 5) Minimap button -----------------------------------------------------------------
  local mini=self:AccordionSection(p,"minimap","미니맵 버튼","NiniTools 바로가기 버튼 표시 여부와 현재 상태",90,false)
  local miniProxy=setmetatable({}, {
    __index=function(_,key) if key=="visible" then return not NT:GetDB().minimapHide end end,
    __newindex=function(_,key,value) if key=="visible" then NT:SetMinimapVisible(value and true or false) end end,
  })
  p.miniRow=self:Toggle(mini.body,"NiniTools 미니맵 버튼","visible",function() return miniProxy end,function() UI:RefreshVisiblePage() end,-12)
  local miniNote=self:Font(mini.body,8,"왼쪽 클릭: NiniTools 열기 · 오른쪽 클릭: 화면 & 편의 바로 열기",C.muted)
  miniNote:SetPoint("BOTTOMLEFT",22,16); miniNote:SetPoint("RIGHT",-22,0)

  -- 6) NiniTools window ---------------------------------------------------------------
  local window=self:AccordionSection(p,"window","NiniTools 창 설정","설정창 배율 · 창 크기 초기화",136,false)
  local scale=CreateFrame("Slider",nil,window.body,"OptionsSliderTemplate")
  scale:SetPoint("TOPLEFT",22,-54); scale:SetWidth(330); scale:SetMinMaxValues(65,150); scale:SetValueStep(5)
  if scale.SetObeyStepOnDrag then scale:SetObeyStepOnDrag(true) end
  if scale.Low then scale.Low:SetText("65%") end; if scale.High then scale.High:SetText("150%") end; if scale.Text then scale.Text:SetText("") end
  p.windowScaleSlider=scale
  p.scaleValue=self:Font(window.body,11,"100%",C.accent); p.scaleValue:SetPoint("LEFT",scale,"RIGHT",24,0)
  local scaleLabel=self:Font(window.body,10,"창 배율",C.text); scaleLabel:SetPoint("BOTTOMLEFT",scale,"TOPLEFT",0,8)
  scale:SetScript("OnMouseDown",function(s) s.adjusting=true end)
  scale:SetScript("OnValueChanged",function(s,value)
    local chosen=math.floor((tonumber(value) or 100)/5+.5)*.05
    if s.adjusting or (IsMouseButtonDown and IsMouseButtonDown("LeftButton")) then
      s.adjusting=true; s.pendingScale=chosen
      p.scaleValue:SetText(math.floor(chosen*100+.5).."% · 놓으면 적용")
    else
      UI:ApplyWindowScale(chosen)
    end
  end)
  local function commitScale(s)
    s.adjusting=false
    if s.pendingScale then local value=s.pendingScale; s.pendingScale=nil; UI:ApplyWindowScale(value) end
  end
  scale:SetScript("OnMouseUp",commitScale); scale:SetScript("OnHide",commitScale)
  scale:SetScript("OnUpdate",function(s) if s.adjusting and IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then commitScale(s) end end)
  p.windowReset=self:Button(window.body,"기본 크기로 복원",170,30,function()
    local db=NT:GetDB(); db.windowWidth,db.windowHeight=1020,700
    UI.frame:SetSize(1020,700); scale:SetValue(100); UI:ApplyWindowScale(1)
    UI:RefreshVisiblePage()
  end)
  p.windowReset:SetPoint("BOTTOMLEFT",22,14)
  p.windowSize=self:Font(window.body,9,"",C.muted); p.windowSize:SetPoint("LEFT",p.windowReset,"RIGHT",16,0)

  p.Refresh=function(self)
    local wdb=waypointDB()
    for _,row in ipairs(self.waypointRows) do if row and row.Refresh then row:Refresh() end end
    if self.waypointScale then self.waypointScale:Refresh() end
    local wayEnabled=wdb.enabled~=false
    for i=2,#self.waypointRows do setControlEnabled(self.waypointRows[i],wayEnabled) end
    setControlEnabled(self.waypointScale,wayEnabled)
    if self.waypointPreview then self.waypointPreview:Refresh() end

    if self.bubbleSlider then self.bubbleSlider:Refresh() end
    if self.finderRow then self.finderRow:Refresh() end
    if self.miniRow then self.miniRow:Refresh() end

    local summary=(_G.NiniKick and _G.NiniKick.GetOptimizationSummary and _G.NiniKick.GetOptimizationSummary()) or "최적화 상태 준비 중"
    self.optimizeStatus:SetText(summary)
    graphics:SetState("프리셋 · 백업","accent")

    local parts={}
    if wdb.showName~=false then parts[#parts+1]="이름" end
    if wdb.glow~=false then parts[#parts+1]="기둥" end
    parts[#parts+1]=math.floor((tonumber(wdb.scale) or 1)*100+.5).."%"
    waypoint:SetEnabledState(wayEnabled)
    waypoint:SetState(table.concat(parts," · "),wayEnabled and "accent" or "warn")

    local m=NT:GetMediaStatus()
    local bubbleSize=math.floor((tonumber(m.bubbleSize) or 10)+.5)
    bubble:SetState(bubbleSize.." px","accent")

    local finderOn=NT:GetDB().dungeonSearchEnabled~=false
    finder:SetEnabledState(finderOn)
    finder:SetState(NT:GetDB().dungeonSearchPosition and "사용자 위치" or "기본 위치",finderOn and "good" or "warn")

    local miniOn=not NT:GetDB().minimapHide
    mini:SetEnabledState(miniOn)
    mini:SetState(miniOn and "표시 중" or "숨김","accent")

    local db=NT:GetDB()
    local requested=math.floor((tonumber(db.windowScale) or 1)*100+.5)
    if self.windowScaleSlider and not self.windowScaleSlider.adjusting then
      local current=math.floor((self.windowScaleSlider:GetValue() or 0)+.5)
      if current~=requested then self.windowScaleSlider:SetValue(requested) end
    end
    if self.scaleValue and not self.windowScaleSlider.adjusting then self.scaleValue:SetText(requested.."%") end
    if self.windowSize then self.windowSize:SetText(string.format("현재 %d × %d",math.floor(UI.frame:GetWidth()+.5),math.floor(UI.frame:GetHeight()+.5))) end
    window:SetState(string.format("%d%% · %d×%d",requested,math.floor(UI.frame:GetWidth()+.5),math.floor(UI.frame:GetHeight()+.5)),"accent")

    self:LayoutAccordions()
  end
end

function UI:BuildTools()
  local p=self:NewPage("TOOLS")
  p.contentHeight=510

  local versions=self:Section(p,"버전","현재 NiniTools 버전",-8,120)
  p.versionText=self:Font(versions,12,"",C.text); p.versionText:SetPoint("TOPLEFT",16,-58); p.versionText:SetPoint("RIGHT",-16,0); p.versionText:SetJustifyH("LEFT")

  local addons=self:Section(p,"현재 환경","주요 연동 애드온 로드 상태",-142,172)
  p.addonText=self:Font(addons,12,"",C.text); p.addonText:SetPoint("TOPLEFT",16,-58); p.addonText:SetPoint("RIGHT",-16,0); p.addonText:SetJustifyH("LEFT")

  local actions=self:Section(p,"유지관리","자주 쓰는 공통 작업",-328,150)
  local b1=self:Button(actions,"UI 다시 불러오기",150,32,function() ReloadUI() end); b1:SetPoint("TOPLEFT",16,-58)
  local back=self:Button(actions,"메인 설정으로",150,32,function() UI:ShowPage(NT:GetDB().lastPage or "GOLD") end); back:SetPoint("LEFT",b1,"RIGHT",10,0)
  local exb=self:Button(actions,"EXBoss 프로필",150,32,function() if NT.ExbossS2 then NT.ExbossS2:OpenDialog() end end); exb:SetPoint("LEFT",back,"RIGHT",10,0)
  local nui=self:Button(actions,"나오 프로필 전부",150,32,function() if NT.NaowhUILink then NT.NaowhUILink:OpenInstaller() end end); nui:SetPoint("LEFT",exb,"RIGHT",10,0)
  local note=self:Font(actions,9,"명령어 목록은 제거했습니다. 주요 설정은 NiniTools 창에서 바로 조작합니다.",C.muted)
  note:SetPoint("BOTTOMLEFT",16,18); note:SetPoint("RIGHT",-16,0)

  p.Refresh=function(self)
    self.versionText:SetText("NiniTools  "..tostring(NT.VERSION))
    local lines={}
    if NT.Adapters and type(NT.Adapters.GetAllStates)=="function" then
      for _,state in ipairs(NT.Adapters:GetAllStates()) do
        local word=NT.Adapters:StatusWord(state)
        local color=(word=="READY" and "|cff59e58c") or (word=="LOADED*" and "|cffffc857") or (word=="ENABLED" and "|cff7ec8ff") or "|cff73808a"
        lines[#lines+1]=string.format("%-24s %s%s|r",state.label,color,word)
      end
    else
      local names={"BigWigs","LittleWigs","NorthernSkyRaidTools","EllesmereUI","EXBoss"}
      for _,name in ipairs(names) do
        lines[#lines+1]=string.format("%-24s %s",name,NT:IsAddonLoaded(name) and "|cff59e58c로드됨|r" or "|cff73808a미로드|r")
      end
    end
    self.addonText:SetText(table.concat(lines,"\n"))
  end
end

function UI:ShowPage(id)
  id=self.pages[id] and id or "KICK"
  local changed=(self.currentPage~=id)
  for pid,p in pairs(self.pages) do p.viewport:SetShown(pid==id) end
  self.currentPage=id
  if changed then
    local page=self.pages[id]
    if page and page.ScrollToTop then page:ScrollToTop() end
  end
  if id~="TOOLS" then NT:GetDB().lastPage=id end
  self.pageTitle:SetText(self.pageNames[id] or id)
  self.pageTitle:SetTextColor(C.text[1],C.text[2],C.text[3],1)
  self.pageHint:SetText(self.pageHints[id] or "")
  self:RefreshNav()
  self:RefreshVisiblePage()
end

function UI:RefreshVisiblePage()
  local p=self.currentPage and self.pages[self.currentPage]
  if p and p.Refresh then p:Refresh() end
end

_G.NiniTools_RefreshVisiblePage=function()
  if UI and UI.frame and UI.frame:IsShown() then
    UI:RefreshVisiblePage()
  end
end

function NT:ToggleUI(page)
  local f=UI:BuildFrame()
  if f:IsShown() and not page then f:Hide(); return end
  f:Show()
  local target=page or NT:GetDB().lastPage or "GOLD"
  if target=="TOOLS" and not page then target="GOLD" end
  UI:ShowPage(target)
end

SLASH_NINITOOLS1="/nini"
SLASH_NINITOOLS2="/nt"
SlashCmdList.NINITOOLS=function(msg)
  local rawMsg=(msg or ""):match("^%s*(.-)%s*$")
  msg=rawMsg:lower()
  if msg=="font" or msg:match("^font%s+") or msg=="글꼴" or msg:match("^글꼴%s+") then
    -- 2.5.4: 글꼴 확인/지정 (SharedMedia 이름은 대소문자 그대로 저장)
    NT:FontSlash(msg:match("^%S+%s*(.-)$") or "", rawMsg:match("^%S+%s*(.-)$") or "")
    return
  end
  if msg=="memo" or msg:match("^memo%s+") then
    -- 2.5.3: 공대 메모 캡처 (분석기용, 기본 꺼짐)
    if NT.NoteCapture and type(NT.NoteCapture.Slash)=="function" then
      NT.NoteCapture:Slash(msg:match("^memo%s*(.-)%s*$") or "")
    else
      NT:Print("메모 캡처 모듈을 찾지 못했습니다.")
    end
    return
  end
  if msg=="naowh" or msg:match("^naowh%s+") or msg=="나오" then
    -- 2.5.5: 나오 프로필 전부 = 각자 설치한 NaowhUI 설치기 열기
    if NT.NaowhUILink and type(NT.NaowhUILink.Slash)=="function" then
      NT.NaowhUILink:Slash(msg:match("^naowh%s*(.-)%s*$") or "")
    else
      NT:Print("NaowhUI 연결 모듈을 찾지 못했습니다.")
    end
    return
  end
  if msg=="exboss" or msg:match("^exboss%s+") then
    -- 2.5.5: Nini_S2 EXBoss 프로필 · 음성팩
    if NT.ExbossS2 and type(NT.ExbossS2.Slash)=="function" then
      NT.ExbossS2:Slash(msg:match("^exboss%s*(.-)%s*$") or "")
    else
      NT:Print("EXBoss 프로필 모듈을 찾지 못했습니다.")
    end
    return
  end
  if msg=="bang" or msg:match("^bang%s+") or msg=="!" or msg:match("^!%s+") or msg=="느낌표" or msg:match("^느낌표%s+") then
    -- 2.6.2: 중요몹 「!」 확인 · /nini bang (상태) · /nini bang test [초] · /nini bang stop
    local arg=msg:match("^%S+%s*(.-)%s*$") or ""
    NT:CallSlash("NINIKICK","bang "..arg)
    return
  end
  if msg=="check" or msg:match("^check%s+") then
    local arg=msg:match("^check%s*(.-)%s*$") or ""
    if NT.Diagnostics and type(NT.Diagnostics.Run)=="function" then
      NT.Diagnostics:Run(arg)
    else
      NT:Print("자가진단 모듈을 찾지 못했습니다.")
    end
    return
  end
  local map={kick="KICK",gold="GOLD",media="MEDIA",sound="MEDIA",qol="QOL",tools="TOOLS",home="KICK",nsrt="NSRT",cal="CAL",calendar="CAL",["달력"]="CAL"}
  NT:ToggleUI(map[msg] or nil)
end

function NT:CreateMinimapButton()
  if self.minimapButton or not Minimap then return self.minimapButton end
  local db=self:GetDB()
  local b=CreateFrame("Button","NiniToolsMinimapButton",Minimap)
  self.minimapButton=b
  b:SetSize(32,32); b:SetFrameStrata("MEDIUM"); b:SetFrameLevel((Minimap:GetFrameLevel() or 0)+8)
  b:RegisterForClicks("LeftButtonUp","RightButtonUp"); b:RegisterForDrag("LeftButton")

  -- 2.5.3 RC1 R3: 메인 창 설정 버튼과 같은 두 줄 N(굵게 다듬은 미니맵 전용). 아이콘 자체에 어두운 원이 있으니
  -- 바탕 칸·직업색 덧칠 없이 버튼을 꽉 채운다 (미니맵 버튼 모음 애드온 칸에서도 다른 아이콘과 같은 크기).
  local icon=b:CreateTexture(nil,"ARTWORK"); icon:SetAllPoints()
  icon:SetTexture((NT.GetBrandMinimapIcon and NT:GetBrandMinimapIcon()) or (NT.GetBrandRoundIcon and NT:GetBrandRoundIcon()) or NT:GetBrandIcon(true)); icon:SetTexCoord(0,1,0,1)
  local hl=b:CreateTexture(nil,"HIGHLIGHT"); hl:SetAllPoints()
  hl:SetTexture((NT.GetBrandMinimapIcon and NT:GetBrandMinimapIcon()) or NT:GetBrandIcon(true)); hl:SetBlendMode("ADD"); hl:SetAlpha(.25)

  local function position()
    local a=math.rad(db.minimapAngle or 225)
    b:ClearAllPoints(); b:SetPoint("CENTER",Minimap,"CENTER",math.cos(a)*80,math.sin(a)*80)
  end
  position()

  b:SetScript("OnClick",function(_,button)
    if button=="RightButton" then NT:ToggleUI("QOL") else NT:ToggleUI() end
  end)
  b:SetScript("OnDragStart",function(self)
    self:SetScript("OnUpdate",function()
      local mx,my=Minimap:GetCenter(); local x,y=GetCursorPosition(); local scale=UIParent:GetEffectiveScale()
      if not mx or not my or not x or not y or not scale or scale==0 then return end
      db.minimapAngle=math.deg(math.atan2(y/scale-my,x/scale-mx)); position()
    end)
  end)
  b:SetScript("OnDragStop",function(self) self:SetScript("OnUpdate",nil) end)
  b:SetScript("OnEnter",function(self)
    GameTooltip:SetOwner(self,"ANCHOR_LEFT")
    GameTooltip:AddLine("NiniTools",1,1,1)
    local gs=NT:GetGoldSummary()
    local k=NT:GetKickDB() or {}
    GameTooltip:AddLine("차단 "..(k.enabled~=false and "|cff59e58cON|r" or "|cff999999OFF|r").." · 자동 브리핑 "..(k.autoBriefing~=false and "ON" or "OFF"),.72,.82,.9)
    GameTooltip:AddLine("총 골드 "..NT:MoneyShort(gs.tracked),1,.82,0)
    GameTooltip:AddLine("좌클릭: 통합 메뉴",.6,.7,.78)
    GameTooltip:AddLine("우클릭: 화면 & 편의",.6,.7,.78)
    GameTooltip:AddLine("드래그: 위치 이동",.45,.55,.62)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave",function() GameTooltip:Hide() end)
  b:SetShown(not db.minimapHide)
  return b
end

function NT:SetMinimapVisible(show)
  local db=self:GetDB()
  db.minimapHide=not show
  local b=self:CreateMinimapButton()
  if b then b:SetShown(show) end
end

_G.NiniTools_SetMinimapVisible=function(show) NT:SetMinimapVisible(show) end

function NiniTools_AddonCompartmentClick()
  NT:ToggleUI()
end
function NiniTools_AddonCompartmentOnEnter(button)
  GameTooltip:SetOwner(button,"ANCHOR_LEFT")
  GameTooltip:AddLine("NiniTools",1,1,1)
  GameTooltip:AddLine("클릭: 통합 메뉴 열기",.7,.8,.9)
  GameTooltip:Show()
end
function NiniTools_AddonCompartmentOnLeave()
  GameTooltip:Hide()
end
