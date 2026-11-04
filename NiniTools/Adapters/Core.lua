local ADDON_NAME, NT = ...

local A = NT.Adapters or {}
NT.Adapters = A
A.registry = A.registry or {}
A.order = A.order or {}

local function safeCall(fn, ...)
  if type(fn) ~= "function" then return false, nil end
  local ok, a, b, c, d, e, f = pcall(fn, ...)
  if not ok then return false, a end
  return true, a, b, c, d, e, f
end

local function currentCharacter()
  if type(UnitName) ~= "function" then return nil end
  local ok, name = pcall(UnitName, "player")
  if ok and type(name) == "string" and name ~= "" then return name end
  return nil
end

function A:Register(id, spec)
  if type(id) ~= "string" or id == "" or type(spec) ~= "table" then return nil end
  if not self.registry[id] then
    self.order[#self.order + 1] = id
  end
  spec.id = id
  self.registry[id] = spec
  return spec
end

function A:Get(id)
  return self.registry[id]
end

function A:GetAddonState(name)
  local state = {
    name = tostring(name or "?"),
    installed = false,
    enabled = false,
    loaded = false,
    loadable = false,
    reason = nil,
    version = nil,
  }
  if type(name) ~= "string" or name == "" then return state end

  if C_AddOns and type(C_AddOns.GetAddOnInfo) == "function" then
    local ok, infoName, _, _, loadable, reason = safeCall(C_AddOns.GetAddOnInfo, name)
    if ok then
      state.loadable = loadable and true or false
      state.reason = reason
      state.installed = (reason ~= "MISSING") and (infoName ~= nil)
    end
  else
    -- Old-client fallback. NiniTools 2.5 targets retail 12.1, but keeping this
    -- branch costs little and makes diagnostics fail soft instead of erroring.
    state.installed = self:IsLoaded(name)
    state.loadable = state.installed
  end

  if state.installed and C_AddOns and type(C_AddOns.GetAddOnEnableState) == "function" then
    local ok, enabledState = safeCall(C_AddOns.GetAddOnEnableState, name, currentCharacter())
    state.enabled = ok and tonumber(enabledState) ~= nil and tonumber(enabledState) > 0 or false
  elseif state.installed then
    -- If the enable-state API is unavailable, a loaded addon is certainly enabled.
    state.enabled = self:IsLoaded(name)
  end

  state.loaded = self:IsLoaded(name)

  if state.installed and C_AddOns and type(C_AddOns.GetAddOnMetadata) == "function" then
    local ok, version = safeCall(C_AddOns.GetAddOnMetadata, name, "Version")
    if ok and version ~= nil and tostring(version) ~= "" then state.version = tostring(version) end
  end

  return state
end

function A:IsLoaded(name)
  if C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function" then
    local ok, loaded = safeCall(C_AddOns.IsAddOnLoaded, name)
    return ok and loaded and true or false
  end
  if type(IsAddOnLoaded) == "function" then
    local ok, loaded = safeCall(IsAddOnLoaded, name)
    return ok and loaded and true or false
  end
  return false
end

local function probe(spec)
  if type(spec.probe) ~= "function" then return nil, nil end
  local ok, ready, detail = pcall(spec.probe)
  if not ok then return false, "probe error: " .. tostring(ready) end
  return ready and true or false, detail
end

function A:GetState(id)
  local spec = self.registry[id]
  if not spec then return nil end

  local primaryName = spec.addon or spec.primary
  local primary = self:GetAddonState(primaryName)
  local extras = {}
  for _, name in ipairs(spec.extras or {}) do
    extras[#extras + 1] = self:GetAddonState(name)
  end
  local ready, detail = probe(spec)

  return {
    id = id,
    label = spec.label or id,
    role = spec.role or "",
    primary = primary,
    extras = extras,
    ready = ready,
    detail = detail,
  }
end

function A:GetAllStates()
  local out = {}
  for _, id in ipairs(self.order) do
    local state = self:GetState(id)
    if state then out[#out + 1] = state end
  end
  return out
end

function A:StatusWord(state)
  if not state then return "UNKNOWN" end
  local p = state.primary or {}
  if not p.installed then return "MISSING" end
  if not p.enabled then return "DISABLED" end
  if not p.loaded then return "ENABLED" end
  if state.ready == false then return "LOADED*" end
  return "READY"
end
