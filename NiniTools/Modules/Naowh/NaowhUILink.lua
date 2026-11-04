local ADDON_NAME, NT = ...
if not NT then return end

-- 2.5.5: 「나오 프로필 전부」 = NaowhUI 자체 설치기를 연다.
-- NiniTools는 Naowh 프로필 문자열을 담지 않는다. 각자 설치한 NaowhUI가
-- EXBoss · BigWigs · EllesmereUI · NSRT · Smart Reminders · 편집 모드 · 쿨다운 뷰어 ·
-- 직업 설정을 자기 방식(해상도 선택, 가져오기 확인창 등)으로 적용한다.
-- 그 프로필들은 NaowhUI_Media의 글꼴·텍스처를 쓰므로 NaowhUI 설치가 어차피 필요하다.

local M = {}
NT.NaowhUILink = M

local ADDON = "NaowhUI"
local MEDIA = "NaowhUI_Media"
local SHORT = {
  EXBoss = "EXBoss", BigWigs = "BigWigs", EllesmereUI = "Ellesmere", NorthernSkyRaidTools = "NSRT",
  NaowhSmartReminders = "Smart Reminders", Blizzard_EditMode = "편집 모드",
  Blizzard_CooldownViewer = "쿨다운 뷰어", NaowhForever = "Naowh Forever",
}

local function state(name)
  if NT.Adapters and type(NT.Adapters.GetAddonState) == "function" then return NT.Adapters:GetAddonState(name) end
  local loaded = NT:IsAddonLoaded(name)
  return { installed = loaded, enabled = loaded, loaded = loaded }
end

local function nui()
  local ns = _G.NaowhUI
  local core = type(ns) == "table" and ns[1] or nil
  return type(core) == "table" and core or nil
end

function M:Status()
  local s = state(ADDON)
  local media = state(MEDIA)
  local out = {
    installed = s.installed and true or false,
    enabled = s.enabled and true or false,
    loaded = s.loaded and true or false,
    version = s.version,
    media = media.installed and true or false,
    applied = {},
  }
  local core = nui()
  local ok, addons = pcall(function() return core and core.db and core.db.profile and core.db.profile.addons end)
  if ok and type(addons) == "table" then
    for key, on in pairs(addons) do
      if on then out.applied[#out.applied + 1] = SHORT[key] or tostring(key) end
    end
    table.sort(out.applied)
  end
  return out
end

function M:StatusLine()
  local s = self:Status()
  if not s.installed then return "NaowhUI · 미설치 (나오 프로필 전부를 쓰려면 설치 필요)" end
  if not s.enabled then return "NaowhUI · 설치됨 · 꺼져 있음" end
  if not s.loaded then return "NaowhUI · 켜짐 · /reload 후 사용" end
  local applied = #s.applied > 0 and table.concat(s.applied, ", ") or "아직 없음"
  return string.format("NaowhUI%s · 적용한 프로필: %s", s.version and (" v" .. s.version) or "", applied)
end

function M:OpenInstaller()
  local s = self:Status()
  if not s.installed then
    NT:Print("NaowhUI가 설치돼 있지 않습니다. CurseForge 또는 Wago에서 「NaowhUI」를 설치한 뒤 /reload 하세요.")
    NT:Print("설치 후 /nini naowh 를 다시 입력하면 나오 프로필 설치기가 열립니다.")
    return false
  end
  if not s.enabled or not s.loaded then
    NT:Print("NaowhUI가 꺼져 있거나 아직 로드되지 않았습니다. 애드온 목록에서 NaowhUI · NaowhUI_Media를 켜고 /reload 하세요.")
    return false
  end
  if type(InCombatLockdown) == "function" and InCombatLockdown() then
    NT:Print("전투 중에는 설치기를 열 수 없습니다. 전투가 끝난 뒤 다시 해 주세요.")
    return false
  end
  local core = nui()
  local ok, err
  if core and type(core.RunInstaller) == "function" then
    ok, err = pcall(core.RunInstaller, core)
  elseif type(_G.NaowhUI_AddonCompartmentFunc) == "function" then
    ok, err = pcall(_G.NaowhUI_AddonCompartmentFunc)
  else
    ok, err = false, "설치기 함수를 찾지 못함"
  end
  if not ok then
    NT:Print("NaowhUI 설치기를 열지 못했습니다 · " .. tostring(err) .. " · /nui install 로 직접 열어 보세요.")
    return false
  end
  NT:Print("NaowhUI 설치기를 열었습니다. 단계마다 [설치]를 누르면 나오 프로필이 적용됩니다. 끝나면 /reload")
  if NT.ExbossS2 and type(NT.ExbossS2.IsActive) == "function" and NT.ExbossS2:IsActive() then
    NT:Print("참고: 지금 EXBoss는 Nini_S2를 쓰고 있습니다. 설치기의 EXBoss 단계를 진행하면 나오 원본 EXBoss 프로필로 바뀝니다.")
  end
  return true
end

function M:Slash(arg)
  arg = tostring(arg or ""):lower():match("^%s*(.-)%s*$")
  if arg == "status" then
    NT:Print(self:StatusLine())
  elseif arg == "" or arg == "install" or arg == "all" then
    self:OpenInstaller()
  else
    NT:Print("명령: /nini naowh (나오 프로필 설치기 열기) · /nini naowh status")
  end
end
