local _,NT=...
local SOUND="Interface\\AddOns\\NiniTools\\Media\\Sounds\\WaterDrop.ogg"
local watcher=CreateFrame("Frame")
local pendingUntil,wasAirborne,played,groundSince
local installed=false

-- Movement flags can be unavailable/restricted. Never branch on secret values.
local function flag(fn,...)
  if type(fn)~="function" then return nil end
  local ok,value=pcall(fn,...)
  if not ok or (issecretvalue and issecretvalue(value)) then return nil end
  if type(value)~="boolean" then return nil end
  return value
end

local function enabled()
  local db=NiniToolsDB
  return db and db.modules and db.modules.media and db.modules.media.jumpSoundEnabled==true
end

local function excluded()
  return flag(IsSwimming)~=false or flag(IsFlying)~=false
    or flag(UnitOnTaxi,"player")==true or flag(UnitInVehicle,"player")==true
    or flag(UnitIsDeadOrGhost,"player")==true
end

local function reset()
  pendingUntil=nil
  wasAirborne=flag(IsFalling)
  played=wasAirborne~=false
  groundSince=wasAirborne==false and GetTime() or nil
end

local function update()
  if not enabled() then watcher:SetScript("OnUpdate",nil); reset(); return end
  local now=GetTime()
  local airborne=flag(IsFalling)
  if airborne==nil then reset(); return end
  if airborne then
    groundSince=nil
    if pendingUntil and now<=pendingUntil and not played and not excluded() then
      PlaySoundFile(SOUND,"Master")
      played=true
    end
    pendingUntil=nil
  else
    groundSince=groundSince or now
    if now-groundSince>=.06 then played=false end
    if pendingUntil and now>pendingUntil then pendingUntil=nil end
  end
  wasAirborne=airborne
end

local function attemptedJump()
  if not enabled() or played or wasAirborne~=false or excluded() then return end
  -- A post-hook may already see the new airborne flag; use the last sampled
  -- grounded state, then require airborne confirmation on the next frame.
  -- Do not extend the confirmation window when the key is spammed.
  if not pendingUntil then pendingUntil=GetTime()+.25 end
end

function NT:RefreshJumpSound()
  reset()
  watcher:SetScript("OnUpdate",enabled() and update or nil)
end

function NT:TestJumpSound()
  local ok=PlaySoundFile(SOUND,"Master")
  if not ok then self:Print("점프 음원 재생 실패: WaterDrop.ogg 설치를 확인해주세요.") end
end

local eventProxy=_G.NiniTools.EventDispatcher:CreateProxy("Media.Jump")
eventProxy:RegisterEvent("PLAYER_LOGIN")
eventProxy:RegisterEvent("PLAYER_ENTERING_WORLD")
eventProxy:SetScript("OnEvent",function()
  if not installed and type(JumpOrAscendStart)=="function" and type(hooksecurefunc)=="function" then
    hooksecurefunc("JumpOrAscendStart",attemptedJump)
    installed=true
  end
  NT:RefreshJumpSound()
end)
