local _,NT=...
local function refresh()
  if not C_Bank or not C_Bank.FetchDepositedMoney or not C_Bank.CanViewBank
    or not Enum or not Enum.BankType then return false end
  local ok,view=pcall(C_Bank.CanViewBank,Enum.BankType.Account)
  if not ok or (issecretvalue and issecretvalue(view)) or not view then return false end
  local success,money=pcall(C_Bank.FetchDepositedMoney,Enum.BankType.Account)
  if not success or (issecretvalue and issecretvalue(money)) or type(money)~="number"
    or money<0 then return false end
  local db=NT:GetDB().modules.gold
  db.warband={money=money,updated=GetServerTime()}
  if NT.UI and NT.UI.frame and NT.UI.frame:IsShown() then NT.UI:RefreshVisiblePage() end
  return true
end
NT.RefreshWarbandMoney=refresh
local events=_G.NiniTools.EventDispatcher:CreateProxy("Gold.Warband")
for _,event in ipairs({"PLAYER_LOGIN","BANKFRAME_OPENED","ACCOUNT_MONEY"}) do
  pcall(events.RegisterEvent,events,event)
end
events:SetScript("OnEvent",function()
  refresh()
  if C_Timer and C_Timer.After then C_Timer.After(.5,refresh) end
end)
