local _, NT = ...
local A = NT and NT.Adapters
if not A then return end

A:Register("naowh", {
  label = "Naowh Smart Reminders",
  addon = "NaowhSmartReminders",
  role = "생존기 사전 알림/출력",
  probe = function()
    return type(_G.NaowhUITankReminder) == "table", "NaowhUITankReminder"
  end,
})

-- 2.5.1: Defensive-alert ownership lives in the adapter, not Kick/Core or NSRBridge.
-- This is deliberately evaluated on demand (after login and again at every consumer)
-- so addon load order and a user toggling the active Smart Reminders profile are safe.
local function forceNiniDefensive()
  local db = type(_G.RogueDefensivesDB) == "table" and _G.RogueDefensivesDB or nil
  return db and db.keepDefensiveWithNaowh == true or false
end

function A:GetNaowhReminderState()
  local state = {
    owner = "ninitools",
    active = false,
    confirmed = false,
    override = forceNiniDefensive(),
    loaded = false,
    profile = nil,
    profileEnabled = false,
    reason = "unknown",
  }

  if state.override then
    state.confirmed = true
    state.reason = "user-override"
    return state
  end

  local addon = self:GetAddonState("NaowhSmartReminders")
  state.installed = addon and addon.installed or false
  state.addonEnabled = addon and addon.enabled or false
  state.loaded = addon and addon.loaded or false
  if not state.installed then
    state.confirmed = true
    state.reason = "addon-missing"
    return state
  end
  if not state.addonEnabled then
    state.confirmed = true
    state.reason = "addon-disabled"
    return state
  end
  if not state.loaded then
    -- Enabled-but-not-loaded is not enough to take ownership.  Keep NiniTools until
    -- Smart Reminders actually has a live runtime.
    state.confirmed = true
    state.reason = "addon-not-loaded"
    return state
  end

  local ns = _G.NaowhUITankReminder
  if type(ns) ~= "table" then
    state.reason = "runtime-api-missing"
    return state
  end
  if type(ns.ActiveProfileName) ~= "function" or type(ns.ProfileSettings) ~= "function" then
    state.reason = "profile-api-missing"
    return state
  end

  local okName, profile = pcall(ns.ActiveProfileName)
  if not okName or type(profile) ~= "string" or profile == "" then
    state.reason = "active-profile-unavailable"
    return state
  end
  state.profile = profile

  local okRoot, root = pcall(ns.ProfileSettings, profile)
  if not okRoot or type(root) ~= "table" then
    state.reason = "profile-settings-unavailable"
    return state
  end

  state.confirmed = true
  state.profileEnabled = root.enabled == true
  if state.profileEnabled then
    state.owner = "naowh"
    state.active = true
    state.reason = "active-profile-enabled"
  else
    state.reason = "active-profile-disabled"
  end
  return state
end

function A:IsNaowhReminderOwner()
  local state = self:GetNaowhReminderState()
  return state.owner == "naowh", state
end

function A:DescribeNaowhReminderOwner()
  local state = self:GetNaowhReminderState()
  local owner = state.owner == "naowh" and "Naowh 담당" or "NiniTools 담당"
  local detail
  if state.override then
    detail = "사용자 강제 유지"
  elseif state.reason == "active-profile-enabled" then
    detail = "활성 프로필 ON" .. (state.profile and (" · " .. state.profile) or "")
  elseif state.reason == "active-profile-disabled" then
    detail = "활성 프로필 OFF" .. (state.profile and (" · " .. state.profile) or "")
  elseif state.reason == "addon-missing" then
    detail = "Naowh Smart Reminders 미설치"
  elseif state.reason == "addon-disabled" then
    detail = "Naowh Smart Reminders 애드온 OFF"
  elseif state.reason == "addon-not-loaded" then
    detail = "Naowh Smart Reminders 로드 대기"
  elseif state.reason == "runtime-api-missing" or state.reason == "profile-api-missing"
      or state.reason == "active-profile-unavailable" or state.reason == "profile-settings-unavailable" then
    detail = "Naowh 담당 상태 확인 불가 · 안전하게 NiniTools 유지"
  else
    detail = tostring(state.reason or "상태 미확인")
  end
  return owner, detail, state
end
