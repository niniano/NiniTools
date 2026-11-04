local ADDON_NAME, NT = ...
NT = NT or _G.NiniTools or {}
_G.NiniTools = NT

-- NiniTools EventDispatcher
-- One native WoW event frame, many lightweight proxy frames.
-- Existing module handlers keep the familiar RegisterEvent/SetScript API,
-- while duplicated registrations are collapsed behind this dispatcher.
local ED = NT.EventDispatcher or {}
NT.EventDispatcher = ED

ED.VERSION = "1.0"
ED._native = ED._native or CreateFrame("Frame")
ED._proxies = ED._proxies or {}
ED._events = ED._events or {}
ED._proxySerial = ED._proxySerial or 0
ED._stats = ED._stats or {
  dispatches = 0,
  callbacks = 0,
  nativeRebuilds = 0,
}

local unpack = unpack or table.unpack

local function unitSet(...)
  local out, n = {}, select("#", ...)
  for i=1,n do
    local unit = select(i, ...)
    if type(unit)=="string" and unit~="" then out[unit]=true end
  end
  return out
end

local function eventBucket(event)
  local b=ED._events[event]
  if not b then
    b={proxies={}, list={}, mode=nil, units=nil}
    ED._events[event]=b
  end
  return b
end

local function proxyWantsEvent(proxy,event)
  return proxy and proxy._events and proxy._events[event]~=nil and proxy._enabled~=false
end

local function recomputeNative(event)
  local bucket=ED._events[event]
  if not bucket then return end

  local any=false
  local needsGlobal=false
  local units={}
  local unitCount=0
  local ordered={}

  for proxy in pairs(bucket.proxies) do
    ordered[#ordered+1]=proxy
    if proxyWantsEvent(proxy,event) then
      any=true
      local spec=proxy._events[event]
      if not spec or spec.global then
        needsGlobal=true
      elseif not needsGlobal then
        for unit in pairs(spec.units or {}) do
          if not units[unit] then
            units[unit]=true
            unitCount=unitCount+1
            if unitCount>4 then needsGlobal=true end
          end
        end
      end
    end
  end

  table.sort(ordered,function(a,b) return (a._serial or 0)<(b._serial or 0) end)
  bucket.list=ordered

  local desiredMode
  local desiredUnits
  if not any then
    desiredMode="off"
  elseif needsGlobal or unitCount==0 then
    desiredMode="global"
  else
    desiredMode="unit"
    desiredUnits={}
    for unit in pairs(units) do desiredUnits[#desiredUnits+1]=unit end
    table.sort(desiredUnits)
  end

  local same=bucket.mode==desiredMode
  if same and desiredMode=="unit" then
    local old=bucket.units or {}
    if #old~=#desiredUnits then
      same=false
    else
      for i=1,#old do if old[i]~=desiredUnits[i] then same=false; break end end
    end
  end
  if same then return end

  -- Do not call UnregisterEvent for a bucket that has never been registered.
  -- In Midnight 12.x, even a redundant native UnregisterEvent can raise
  -- ADDON_ACTION_FORBIDDEN (pcall does not suppress the protected-action report).
  -- Only tear down the native registration when we know one currently exists.
  if bucket.mode=="global" or bucket.mode=="unit" then
    ED._native:UnregisterEvent(event)
  end
  bucket.mode=desiredMode
  bucket.units=desiredUnits
  ED._stats.nativeRebuilds=(ED._stats.nativeRebuilds or 0)+1

  if desiredMode=="global" then
    pcall(ED._native.RegisterEvent,ED._native,event)
  elseif desiredMode=="unit" then
    local ok=pcall(ED._native.RegisterUnitEvent,ED._native,event,unpack(desiredUnits))
    if not ok then
      -- Defensive fallback for an event/unit combination Blizzard refuses.
      bucket.mode="global"
      bucket.units=nil
      pcall(ED._native.RegisterEvent,ED._native,event)
    end
  end
end

local Proxy={}
Proxy.__index=Proxy

function Proxy:RegisterEvent(event)
  if type(event)~="string" or event=="" then return false end
  self._events[event]={global=true}
  eventBucket(event).proxies[self]=true
  recomputeNative(event)
  return true
end

function Proxy:RegisterUnitEvent(event,...)
  if type(event)~="string" or event=="" then return false end
  local units=unitSet(...)
  if not next(units) then return self:RegisterEvent(event) end
  self._events[event]={global=false,units=units}
  eventBucket(event).proxies[self]=true
  recomputeNative(event)
  return true
end

function Proxy:UnregisterEvent(event)
  if type(event)~="string" or not self._events[event] then return end
  self._events[event]=nil
  local bucket=ED._events[event]
  if bucket then
    bucket.proxies[self]=nil
    recomputeNative(event)
    if not next(bucket.proxies) then
      ED._events[event]=nil
    end
  end
end

function Proxy:UnregisterAllEvents()
  local list={}
  for event in pairs(self._events) do list[#list+1]=event end
  for _,event in ipairs(list) do self:UnregisterEvent(event) end
end

function Proxy:IsEventRegistered(event)
  return self._events[event]~=nil
end

function Proxy:SetScript(scriptType,func)
  if scriptType~="OnEvent" then
    error("NiniTools EventDispatcher proxy only supports OnEvent")
  end
  if func~=nil and type(func)~="function" then
    error("OnEvent handler must be a function or nil")
  end
  self._onEvent=func
end

function Proxy:GetScript(scriptType)
  if scriptType=="OnEvent" then return self._onEvent end
  return nil
end

function Proxy:SetEventsEnabled(enabled)
  enabled=enabled~=false
  if self._enabled==enabled then return end
  self._enabled=enabled
  for event in pairs(self._events) do recomputeNative(event) end
end

function Proxy:AreEventsEnabled()
  return self._enabled~=false
end

function Proxy:GetDispatcherOwner()
  return self._owner
end

function ED:CreateProxy(owner)
  self._proxySerial=self._proxySerial+1
  local p=setmetatable({
    _owner=tostring(owner or ("Proxy"..self._proxySerial)),
    _serial=self._proxySerial,
    _events={},
    _enabled=true,
    _onEvent=nil,
  },Proxy)
  self._proxies[p]=true
  return p
end

function ED:RefreshEvent(event)
  recomputeNative(event)
end

function ED:GetStats()
  local proxyCount,subscriptionCount=0,0
  for p in pairs(self._proxies) do
    proxyCount=proxyCount+1
    for _ in pairs(p._events or {}) do subscriptionCount=subscriptionCount+1 end
  end
  local nativeEvents,globalEvents,unitEvents=0,0,0
  for _,bucket in pairs(self._events) do
    if bucket.mode and bucket.mode~="off" then
      nativeEvents=nativeEvents+1
      if bucket.mode=="unit" then unitEvents=unitEvents+1 else globalEvents=globalEvents+1 end
    end
  end
  return {
    version=self.VERSION,
    proxyCount=proxyCount,
    subscriptions=subscriptionCount,
    nativeEvents=nativeEvents,
    globalEvents=globalEvents,
    unitEvents=unitEvents,
    dispatches=tonumber(self._stats.dispatches) or 0,
    callbacks=tonumber(self._stats.callbacks) or 0,
    nativeRebuilds=tonumber(self._stats.nativeRebuilds) or 0,
  }
end

function ED:IsHealthy()
  return self._native~=nil and type(self.CreateProxy)=="function"
end

ED._native:SetScript("OnEvent",function(_,event,...)
  local bucket=ED._events[event]
  if not bucket then return end
  ED._stats.dispatches=(ED._stats.dispatches or 0)+1
  local unit=select(1,...)

  -- Registration changes are rare, so the ordered proxy list is cached in the
  -- bucket.  High-frequency events allocate/sort nothing on their hot path.
  for _,proxy in ipairs(bucket.list or {}) do
    if proxyWantsEvent(proxy,event) and type(proxy._onEvent)=="function" then
      local spec=proxy._events[event]
      local deliver=true
      if spec and not spec.global then
        deliver=type(unit)=="string" and spec.units and spec.units[unit] and true or false
      end
      if deliver then
        ED._stats.callbacks=(ED._stats.callbacks or 0)+1
        proxy._onEvent(proxy,event,...)
      end
    end
  end
end)
