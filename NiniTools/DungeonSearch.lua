local _,NT=...
local DS={}
NT.DungeonSearch=DS
-- Challenge map -> activity GROUP ID, verified against the supplied WT 4.21
-- metadata. These are group IDs, not individual normal/heroic/mythic activities.
local dungeons={
  {588,420,"제단"},{249,141,"왕안"},{586,392,"날로라크"},{584,382,"골짜기"},
  {250,139,"사원"},{585,398,"투기장"},{587,396,"골목"},{399,306,"루비"},
}
local category=GROUP_FINDER_CATEGORY_ID_DUNGEONS or 2
local panel,searchPanel
local bg={.04,.055,.07}
local edge={.14,.18,.21}

local function availableGroups()
  if not C_LFGList or not C_LFGList.GetAvailableActivityGroups or not Enum
    or not Enum.LFGListFilter or not bit then return nil end
  local flags=Enum.LFGListFilter
  if not flags.CurrentSeason or not flags.CurrentExpansion or not flags.NotCurrentSeason or not flags.PvE then return nil end
  local groups,known={},{}
  for _,filter in ipairs({bit.bor(flags.CurrentSeason,flags.PvE),
    bit.bor(flags.CurrentExpansion,flags.NotCurrentSeason,flags.PvE)}) do
    local ok,ids=pcall(C_LFGList.GetAvailableActivityGroups,category,filter)
    if not ok or type(ids)~="table" then return nil end
    for _,id in ipairs(ids) do
      if not known[id] then known[id]=true; groups[#groups+1]=id end
    end
  end
  return groups,known
end

local function readFilters()
  if not C_LFGList or not C_LFGList.GetAdvancedFilter then return nil end
  local ok,filters=pcall(C_LFGList.GetAdvancedFilter)
  if ok and type(filters)=="table" and (filters.activities==nil or type(filters.activities)=="table") then
    local copy={}
    for key,value in pairs(filters) do copy[key]=value end
    return copy
  end
end

local function selection(filters,groups)
  local selected={}
  for _,id in ipairs(filters.activities or {}) do selected[id]=true end
  local all=next(selected)==nil
  if not all and #groups>0 and NT:GetDB().dungeonSearchIndividualSelection~=true then
    all=true
    for _,id in ipairs(groups) do if not selected[id] then all=false; break end end
  end
  return selected,all
end

function DS:Place()
  if not panel then return end
  local pos=NT:GetDB().dungeonSearchPosition
  panel:ClearAllPoints()
  if type(pos)=="table" and type(pos.x)=="number" and type(pos.y)=="number" then
    local ratio=panel:GetEffectiveScale()/UIParent:GetEffectiveScale()
    panel:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",pos.x/ratio,pos.y/ratio)
  else
    panel:SetPoint("TOPRIGHT",PVEFrame or searchPanel,"BOTTOMRIGHT",0,-8)
  end
end

function DS:StopMoving()
  if not panel or not panel.moving then return end
  panel:StopMovingOrSizing()
  panel.moving=false
  local ratio=panel:GetEffectiveScale()/UIParent:GetEffectiveScale()
  local x,y=panel:GetLeft(),panel:GetBottom()
  if x and y then NT:GetDB().dungeonSearchPosition={x=x*ratio,y=y*ratio} end
  self:Place()
end

function DS:CanShow()
  return NT:GetDB().dungeonSearchEnabled~=false and searchPanel and searchPanel:IsShown()
    and searchPanel.categoryID==category
end

function DS:Refresh()
  if not panel then return end
  local show=self:CanShow()
  panel:SetShown(show and true or false)
  if not show then return end
  local groups,known=availableGroups()
  local filters=readFilters()
  local ready=groups and #groups>0 and filters and C_LFGList.SaveAdvancedFilter
    and not (InCombatLockdown and InCombatLockdown())
  local selected,all={},false
  if ready then selected,all=selection(filters,groups) end
  for _,button in ipairs(panel.buttons) do
    local active=ready and (button.groupID and not all and selected[button.groupID] or not button.groupID and all)
    button:SetEnabled(ready and (not button.groupID or known[button.groupID]) and true or false)
    local c=NT.ACCENT or {0,.8,1}
    button:SetBackdropColor(active and c[1]*.22 or bg[1],active and c[2]*.22 or bg[2],active and c[3]*.22 or bg[3],1)
    button.label:SetTextColor(active and c[1] or .9,active and c[2] or .93,active and c[3] or 1)
  end
  panel.status:SetText(ready and "클릭: 선택 / 해제 · 복수 선택" or
    (InCombatLockdown and InCombatLockdown() and "전투 종료 후 검색 가능" or "던전 정보를 불러오는 중"))
end

function DS:Choose(groupID)
  if not self:CanShow() then return end
  if InCombatLockdown and InCombatLockdown() then return end
  local groups,known=availableGroups()
  local filters=readFilters()
  if not groups or #groups==0 or not filters or not C_LFGList.SaveAdvancedFilter then return end
  if groupID and not known[groupID] then return end
  local selected,all=selection(filters,groups)
  local ids={}
  if groupID then
    if all then selected={} end
    selected[groupID]=not selected[groupID] or nil
    for id,on in pairs(selected) do if on then ids[#ids+1]=id end end
    table.sort(ids)
  end
  if #ids==0 then ids=groups end
  -- Only dungeon selection changes; rating, role and other native filters survive.
  filters.activities=ids
  local ok=pcall(C_LFGList.SaveAdvancedFilter,filters)
  if not ok then NT:Print("던전 필터를 적용하지 못했어요. 기본 필터를 확인해주세요."); return end
  NT:GetDB().dungeonSearchIndividualSelection=groupID~=nil and next(selected)~=nil
  self:Refresh()
  if type(LFGListSearchPanel_DoSearch)=="function" then
    local searched=pcall(LFGListSearchPanel_DoSearch,searchPanel)
    if not searched then NT:Print("던전은 선택됐어요. 기본 검색 버튼을 눌러주세요.") end
  end
end

function DS:Initialize()
  if panel or not NT.UI or not LFGListFrame or not LFGListFrame.SearchPanel then return end
  searchPanel=LFGListFrame.SearchPanel
  panel=CreateFrame("Frame","NiniToolsDungeonSearchPanel",searchPanel,"BackdropTemplate")
  self.panel=panel
  panel:SetSize(218,236)
  panel:SetClampedToScreen(true)
  panel:SetMovable(true)
  panel:EnableMouse(true)
  panel:RegisterForDrag("LeftButton")
  self:Place()
  panel:SetScript("OnDragStart",function(p)
    if p.unlocked and not (InCombatLockdown and InCombatLockdown()) then p.moving=true; p:StartMoving() end
  end)
  panel:SetScript("OnDragStop",function() DS:StopMoving() end)
  panel:SetScript("OnHide",function() DS:StopMoving() end)
  NT.UI:Backdrop(panel,bg,edge)
  local title=NT.UI:Font(panel,12,"니니 던전 검색",NT.ACCENT)
  title:SetPoint("TOPLEFT",12,-12)
  local move=CreateFrame("Button",nil,panel)
  move:SetSize(44,24); move:SetPoint("TOPRIGHT",-5,-5)
  move.label=NT.UI:Font(move,10,"이동"); move.label:SetPoint("CENTER")
  move:SetScript("OnClick",function()
    DS:StopMoving(); panel.unlocked=not panel.unlocked
    move.label:SetText(panel.unlocked and "잠금" or "이동")
  end)
  local reset=CreateFrame("Button",nil,panel)
  reset:SetSize(194,22); reset:SetPoint("TOPLEFT",12,-246)
  reset.label=NT.UI:Font(reset,10,"위치 초기화"); reset.label:SetPoint("CENTER")
  reset:SetScript("OnClick",function()
    DS:StopMoving(); NT:GetDB().dungeonSearchPosition=nil; DS:Place()
  end)
  panel.buttons={}
  for i,data in ipairs(dungeons) do
    local b=CreateFrame("Button",nil,panel,"BackdropTemplate")
    b:SetSize(94,32)
    b:SetPoint("TOPLEFT",12+((i-1)%2)*100,-38-math.floor((i-1)/2)*38)
    NT.UI:Backdrop(b,bg,edge)
    b.groupID=data[2]
    b.label=NT.UI:Font(b,11,data[3]); b.label:SetPoint("CENTER")
    b:SetScript("OnClick",function() DS:Choose(data[2]) end)
    b:SetScript("OnEnter",function()
      if not GameTooltip then return end
      local name=data[3]
      if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        local ok,full=pcall(C_ChallengeMode.GetMapUIInfo,data[1])
        if ok and type(full)=="string" then name=full end
      end
      GameTooltip:SetOwner(b,"ANCHOR_RIGHT"); GameTooltip:AddLine(name,1,1,1); GameTooltip:Show()
    end)
    b:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    panel.buttons[#panel.buttons+1]=b
  end
  local all=CreateFrame("Button",nil,panel,"BackdropTemplate")
  all:SetSize(194,28); all:SetPoint("TOPLEFT",12,-190)
  NT.UI:Backdrop(all,bg,edge)
  all.label=NT.UI:Font(all,11,"전체 던전"); all.label:SetPoint("CENTER")
  all:SetScript("OnClick",function() DS:Choose() end)
  panel.buttons[#panel.buttons+1]=all
  panel.status=NT.UI:Font(panel,8,"")
  panel.status:SetPoint("TOPLEFT",12,-225)
  panel.status:SetWidth(194)
  panel.status:SetJustifyH("LEFT")
  panel:SetHeight(276)
  searchPanel:HookScript("OnShow",function() DS:Refresh() end)
  if type(LFGListSearchPanel_SetCategory)=="function" then
    hooksecurefunc("LFGListSearchPanel_SetCategory",function() DS:Refresh() end)
  end
  if C_LFGList and type(C_LFGList.SaveAdvancedFilter)=="function" then
    hooksecurefunc(C_LFGList,"SaveAdvancedFilter",function() DS:Refresh() end)
  end
  self:Refresh()
end

local events=_G.NiniTools.EventDispatcher:CreateProxy("DungeonSearch")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent",function() DS:Initialize(); DS:Refresh() end)
