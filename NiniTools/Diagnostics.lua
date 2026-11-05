local ADDON_NAME, NT = ...

local D = NT.Diagnostics or {}
NT.Diagnostics = D
D.loadedAt = D.loadedAt or (GetTime and GetTime() or 0)
D.lastSample = D.lastSample or nil
D.cpuWindow = D.cpuWindow or nil
D.lastCPUWindow = D.lastCPUWindow or nil

local function round1(n)
  n = tonumber(n) or 0
  return math.floor(n * 10 + 0.5) / 10
end

local function onOff(v)
  return v and "ON" or "OFF"
end

local function yesNo(v)
  return v and "있음" or "없음"
end

local function trim(s)
  return tostring(s or ""):match("^%s*(.-)%s*$") or ""
end

local function versionSuffix(v)
  if v==nil then return "" end
  local s=tostring(v)
  if s=="" then return "" end
  if s:match("^[vV]") then return " "..s end
  return " v"..s
end

local function colorStatus(word)
  if word == "READY" then return "|cff59e58cREADY|r" end
  if word == "LOADED*" then return "|cffffc857LOADED*|r" end
  if word == "ENABLED" then return "|cff7ec8ffENABLED|r" end
  if word == "DISABLED" then return "|cff999999DISABLED|r" end
  if word == "MISSING" then return "|cff73808aMISSING|r" end
  return "|cffff6666" .. tostring(word or "UNKNOWN") .. "|r"
end

local function cvarBool(name)
  if C_CVar and type(C_CVar.GetCVarBool) == "function" then
    local ok, v = pcall(C_CVar.GetCVarBool, name)
    if ok then return v and true or false end
  end
  if type(GetCVarBool) == "function" then
    local ok, v = pcall(GetCVarBool, name)
    if ok then return v and true or false end
  end
  if type(GetCVar) == "function" then
    local ok, v = pcall(GetCVar, name)
    if ok then return tostring(v) == "1" end
  end
  return false
end

function D:GetMemoryKB()
  if type(UpdateAddOnMemoryUsage) ~= "function" or type(GetAddOnMemoryUsage) ~= "function" then return nil end
  pcall(UpdateAddOnMemoryUsage)
  local ok, kb = pcall(GetAddOnMemoryUsage, ADDON_NAME)
  if not ok then return nil end
  return tonumber(kb)
end

function D:GetCPUms()
  if not cvarBool("scriptProfile") then return nil, false end
  if type(UpdateAddOnCPUUsage) ~= "function" or type(GetAddOnCPUUsage) ~= "function" then return nil, true end
  pcall(UpdateAddOnCPUUsage)
  local ok, ms = pcall(GetAddOnCPUUsage, ADDON_NAME)
  if not ok then return nil, true end
  return tonumber(ms), true
end

function D:GetModuleState()
  local root = type(NiniToolsDB) == "table" and NiniToolsDB or {}
  local modules = type(root.modules) == "table" and root.modules or {}
  local kick = type(modules.kick) == "table" and modules.kick or {}
  local enemy = type(modules.enemyCount) == "table" and modules.enemyCount or {}
  local media = type(modules.media) == "table" and modules.media or {}

  return {
    kick = kick.enabled ~= false,
    importantCast = kick.importantCastMarkerEnabled ~= false,
    enemyCount = enemy.enabled ~= false,
    naviCursor = media.naviCursorEnabled ~= false,
    nsrBridge = type(NT.NSRBridge) == "table",
    nsrtImport = type(NT.NSRTImport) == "table",
  }
end

function D:GetAdapterWarnings(states)
  local warnings = {}
  for _, state in ipairs(states or {}) do
    local p = state.primary or {}
    if p.loaded and state.ready == false then
      warnings[#warnings + 1] = state.label .. " 로드됨 / 연동 API 미확인"
    end
  end

  -- 2.5.1: suppression is adapter-owned.  If Naowh is loaded but its active
  -- profile state cannot be confirmed, fail safe by keeping NiniTools alerts and
  -- expose that ambiguity here instead of silently suppressing them.
  local adapters=NT.Adapters
  if adapters and type(adapters.GetNaowhReminderState)=="function" then
    local rs=adapters:GetNaowhReminderState()
    if rs and rs.loaded and not rs.confirmed and not rs.override then
      warnings[#warnings + 1] = "Naowh Smart Reminders 담당 상태 확인 불가 · 안전하게 NiniTools 생존기 알림 유지"
    end
  end
  if NT.ExbossS2 and type(NT.ExbossS2.Warnings)=="function" then
    local ok,list=pcall(NT.ExbossS2.Warnings,NT.ExbossS2)
    if ok and type(list)=="table" then for _,w in ipairs(list) do warnings[#warnings+1]=w end end
  end
  local schema=NT.DBSchema and NT.DBSchema.GetState and NT.DBSchema:GetState() or nil
  if schema then
    if schema.futureSchema then
      warnings[#warnings+1]=string.format("DB Schema가 애드온보다 새 버전입니다: %d > %d · 자동 정리 중지",schema.schemaVersion or 0,schema.currentSchema or 0)
    elseif schema.belowMinimum then
      warnings[#warnings+1]=string.format("DB Schema가 최소 지원보다 오래됐습니다: %d < %d · 자동 정리 중지",schema.schemaVersion or 0,schema.minMigratableSchema or 0)
    end
  end
  return warnings
end

function D:SaveBaseline(memoryKB)
  local db = NT:GetDB()
  db.diagnostics = type(db.diagnostics) == "table" and db.diagnostics or {}
  db.diagnostics.baseline = {
    version = tostring(NT.VERSION or "?"),
    memoryKB = tonumber(memoryKB),
    savedAt = type(time) == "function" and time() or 0,
  }
  return db.diagnostics.baseline
end

function D:GetBaseline()
  local db = NT:GetDB()
  local diag = type(db.diagnostics) == "table" and db.diagnostics or nil
  return diag and type(diag.baseline) == "table" and diag.baseline or nil
end

function D:StartCPUWindow(label)
  if self.cpuWindow then
    local now=GetTime and GetTime() or 0
    local dt=math.max(0,now-(tonumber(self.cpuWindow.at) or now))
    local tag=(self.cpuWindow.label and self.cpuWindow.label~="") and (" · "..self.cpuWindow.label) or ""
    NT:Print(string.format("CPU 측정이 이미 진행 중입니다%s · %.1f초 경과",tag,dt))
    NT:Print("처음부터 다시 재려면 /nini check cpu restart [메모]")
    return false
  end
  local cpuMS, profiling = self:GetCPUms()
  if not profiling then
    NT:Print("CPU 측정 시작 실패 · scriptProfile이 꺼져 있습니다.")
    NT:Print("/console scriptProfile 1 후 /reload → 다시 /nini check cpu start")
    return false
  end
  if cpuMS == nil then
    NT:Print("CPU 측정 시작 실패 · CPU 사용량 API를 사용할 수 없습니다.")
    return false
  end
  self.cpuWindow = {
    cpuMS = cpuMS,
    at = GetTime and GetTime() or 0,
    label = trim(label),
    version = tostring(NT.VERSION or "?"),
  }
  self.lastSample = {at = self.cpuWindow.at, cpuMS = cpuMS, memoryKB = self:GetMemoryKB()}
  local tag = self.cpuWindow.label ~= "" and (" · " .. self.cpuWindow.label) or ""
  NT:Print("CPU 구간 측정 시작" .. tag .. " · 시작 누적값 " .. string.format("%.2f ms", cpuMS))
  NT:Print("RC 간 비교는 같은 보스/같은 난이도/같은 구간에서 측정하세요.")
  return true
end

function D:StopCPUWindow()
  if not self.cpuWindow then
    NT:Print("진행 중인 CPU 구간 측정이 없습니다. /nini check cpu start 로 시작하세요.")
    return false
  end
  local cpuMS, profiling = self:GetCPUms()
  if not profiling or cpuMS == nil then
    NT:Print("CPU 구간 측정 종료 실패 · scriptProfile/CPU API 상태를 확인하세요.")
    return false
  end
  local now = GetTime and GetTime() or 0
  local start = self.cpuWindow
  local dcpu = math.max(0, cpuMS - (tonumber(start.cpuMS) or cpuMS))
  local dt = math.max(0, now - (tonumber(start.at) or now))
  local rate = dt > 0 and (dcpu / dt) or 0
  self.lastCPUWindow = {
    version = tostring(NT.VERSION or "?"),
    startVersion = start.version,
    label = start.label,
    cpuMS = dcpu,
    seconds = dt,
    rate = rate,
  }
  self.cpuWindow = nil
  local tag = (start.label and start.label ~= "") and (" · " .. start.label) or ""
  NT:Print(string.format("CPU 구간 측정 종료%s · Δ %.2f ms / %.1fs = %.3f ms/s", tag, dcpu, dt, rate))
  NT:Print("측정이 끝났으면 /console scriptProfile 0 후 /reload 로 끄세요.")
  return true
end

function D:BuildCopyReport(states, warnings)
  local A = NT.Adapters
  local modules = self:GetModuleState()
  local dispatcher=NT.EventDispatcher
  local ds=dispatcher and dispatcher.GetStats and dispatcher:GetStats() or nil
  local lines = {
    "NiniTools " .. tostring(NT.VERSION or "?"),
    ds and string.format("Dispatcher: OK · Native %d · Subs %d · Proxy %d",ds.nativeEvents or 0,ds.subscriptions or 0,ds.proxyCount or 0) or "Dispatcher: FAIL",
    "Adapters",
  }
  for _, state in ipairs(states or {}) do
    local word = A and A:StatusWord(state) or "UNKNOWN"
    lines[#lines + 1] = "- " .. tostring(state.label or state.id or "?") .. ": " .. tostring(word)
  end
  if A and type(A.DescribeNaowhReminderOwner)=="function" then
    local owner,detail=A:DescribeNaowhReminderOwner()
    lines[#lines + 1] = "Defensive alerts: " .. tostring(owner) .. " · " .. tostring(detail)
  else
    lines[#lines + 1] = "Defensive alerts: NiniTools 담당 · adapter unavailable"
  end
  lines[#lines + 1] = "NSR bridge: " .. onOff(modules.nsrBridge) .. " / NSRT import=" .. onOff(modules.nsrtImport)
  if NT.ExbossS2 and type(NT.ExbossS2.StatusLine)=="function" then
    local ok,line=pcall(NT.ExbossS2.StatusLine,NT.ExbossS2)
    if ok and line then lines[#lines + 1] = tostring(line) end
  end
  if NT.NaowhUILink and type(NT.NaowhUILink.StatusLine)=="function" then
    local ok,line=pcall(NT.NaowhUILink.StatusLine,NT.NaowhUILink)
    if ok and line then lines[#lines + 1] = tostring(line) end
  end
  local schema=NT.DBSchema and NT.DBSchema.GetState and NT.DBSchema:GetState() or nil
  if schema then
    lines[#lines + 1] = string.format("DB schema: %d/%d · min %d · cleanup %d/%d · legacy=%s · candidates=%d · unknown=%d",
      schema.schemaVersion or 0, schema.currentSchema or 0, schema.minMigratableSchema or 0,
      schema.cleanupRevision or 0, schema.targetCleanupRevision or 0, schema.adoptedLegacy and "YES" or "NO", schema.cleanupCandidateCount or 0, schema.unknownRootCount or 0)
    if (schema.lastCleanupRevision or 0)>0 then
      lines[#lines + 1] = string.format("Last cleanup: r%d · removed=%d · keys=%s",schema.lastCleanupRevision or 0,schema.lastCleanupRemovedCount or 0,table.concat(schema.lastCleanupRemovedKeys or {},","))
    end
  else
    lines[#lines + 1] = "DB schema: unavailable"
  end
  if #(warnings or {}) == 0 then
    lines[#lines + 1] = "Warnings: 0"
  else
    lines[#lines + 1] = "Warnings: " .. tostring(#warnings)
    for _, w in ipairs(warnings) do lines[#lines + 1] = "- " .. tostring(w) end
  end
  return table.concat(lines, "\n")
end

function D:ShowCopyBox(text)
  if not self.copyFrame then
    local f = CreateFrame("Frame", "NiniToolsDiagnosticsCopyFrame", UIParent, "BackdropTemplate")
    f:SetSize(590, 330)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    if f.SetBackdrop then
      f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
      })
      f:SetBackdropColor(0.03, 0.04, 0.05, 0.98)
      f:SetBackdropBorderColor(0.20, 0.75, 1.00, 0.85)
    end

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 18, -16)
    title:SetText("NiniTools 버그 리포트 복사")

    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    hint:SetText("Ctrl+C로 복사해서 디스코드에 붙여넣으세요.")

    local eb = CreateFrame("EditBox", nil, f)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetFontObject(ChatFontNormal)
    eb:SetPoint("TOPLEFT", 18, -66)
    eb:SetPoint("BOTTOMRIGHT", -18, 48)
    eb:SetTextInsets(8, 8, 8, 8)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus(); f:Hide() end)
    eb:SetScript("OnTextChanged", function(self, userInput)
      if userInput and self._niniLockedText then
        self:SetText(self._niniLockedText)
        self:HighlightText()
      end
    end)
    f.editBox = eb

    local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    close:SetSize(90, 24)
    close:SetPoint("BOTTOMRIGHT", -18, 14)
    close:SetText("닫기")
    close:SetScript("OnClick", function() f:Hide() end)

    f:Hide()
    self.copyFrame = f
  end
  local eb = self.copyFrame.editBox
  eb._niniLockedText = tostring(text or "")
  eb:SetText(eb._niniLockedText)
  self.copyFrame:Show()
  eb:SetFocus()
  eb:HighlightText()
end

function D:Run(arg)
  arg = trim(arg):lower()
  local cpuStartLabel = arg:match("^cpu%s+start%s*(.-)%s*$")
  local cpuRestartLabel = arg:match("^cpu%s+restart%s*(.-)%s*$")
  if cpuStartLabel ~= nil then
    self:StartCPUWindow(cpuStartLabel)
    return
  elseif cpuRestartLabel ~= nil then
    self.cpuWindow=nil
    self:StartCPUWindow(cpuRestartLabel)
    return
  elseif arg == "cpu stop" then
    self:StopCPUWindow()
    return
  end

  local A = NT.Adapters
  local states = A and A:GetAllStates() or {}
  local modules = self:GetModuleState()
  local memoryKB = self:GetMemoryKB()
  local cpuMS, profiling = self:GetCPUms()
  local now = GetTime and GetTime() or 0
  local warnings = self:GetAdapterWarnings(states)

  if arg == "baseline" then
    local b = self:SaveBaseline(memoryKB)
    NT:Print(string.format("메모리 기준값 저장 · v%s · Memory %s KB", tostring(b.version), b.memoryKB and tostring(round1(b.memoryKB)) or "N/A"))
  elseif arg == "clear" then
    local db = NT:GetDB()
    if type(db.diagnostics) == "table" then db.diagnostics.baseline = nil end
    NT:Print("진단 기준값을 지웠습니다.")
  elseif arg == "copy" or arg == "report" then
    self:ShowCopyBox(self:BuildCopyReport(states, warnings))
    NT:Print("버그 리포트 복사창을 열었습니다. Ctrl+C 후 디스코드에 붙여넣으세요.")
    return
  elseif arg == "db" then
    local schema=NT.DBSchema and NT.DBSchema.GetState and NT.DBSchema:GetState() or nil
    if not schema then
      NT:Print("DB Schema 관리자를 사용할 수 없습니다.")
      return
    end
    NT:Print(string.format("DB Schema %d/%d · 최소이전 %d · Cleanup %d/%d · Legacy채택 %s",
      schema.schemaVersion or 0, schema.currentSchema or 0, schema.minMigratableSchema or 0,
      schema.cleanupRevision or 0, schema.targetCleanupRevision or 0, schema.adoptedLegacy and "YES" or "NO"))
    NT:Print(string.format("보호 루트 %d · 정리 후보 루트 %d · 미분류 루트 %d",schema.protectedRootCount or 0,schema.cleanupCandidateCount or 0,schema.unknownRootCount or 0))
    if (schema.lastCleanupRevision or 0)>0 then
      local removed=table.concat(schema.lastCleanupRemovedKeys or {},", ")
      if removed=="" then removed="없음" end
      NT:Print(string.format("최근 Cleanup r%d · 삭제 %d개 · %s",schema.lastCleanupRevision or 0,schema.lastCleanupRemovedCount or 0,removed))
    end
    if (schema.cleanupCandidateCount or 0)>0 then
      NT:Print("후보(아직 삭제 안 함): "..table.concat(schema.cleanupCandidateKeys or {},", "))
      for _,key in ipairs(schema.cleanupCandidateKeys or {}) do
        local reason=NT.DBSchema.DEPRECATED_ROOT_KEYS and NT.DBSchema.DEPRECATED_ROOT_KEYS[key]
        if reason then NT:Print("- "..key.." · "..tostring(reason)) end
      end
    else
      NT:Print("정리 후보 없음 · 현재 Cleanup 완료")
    end
    if (schema.unknownRootCount or 0)>0 then
      NT:Print("미분류(자동 삭제 금지): "..table.concat(schema.unknownRootKeys or {},", "))
    end
    return
  end

  NT:Print("|cffffffff자가진단|r  v" .. tostring(NT.VERSION or "?"))
  local dispatcher=NT.EventDispatcher
  local ds=dispatcher and dispatcher.GetStats and dispatcher:GetStats() or nil
  NT:Print(string.format("Core %s · Dispatcher %s · Adapter %d · DB %s", type(NT.GetDB)=="function" and "OK" or "FAIL", ds and "OK" or "FAIL", #states, type(NiniToolsDB)=="table" and "OK" or "FAIL"))
  if ds then
    NT:Print(string.format("Event Dispatcher · Native %d · Subs %d · Proxy %d · Unit %d · Global %d", ds.nativeEvents or 0, ds.subscriptions or 0, ds.proxyCount or 0, ds.unitEvents or 0, ds.globalEvents or 0))
  end
  local schema=NT.DBSchema and NT.DBSchema.GetState and NT.DBSchema:GetState() or nil
  if schema then
    NT:Print(string.format("DB Schema %d/%d · Min %d · Cleanup %d/%d · Legacy %s · 후보 %d · 미분류 %d",
      schema.schemaVersion or 0, schema.currentSchema or 0, schema.minMigratableSchema or 0,
      schema.cleanupRevision or 0, schema.targetCleanupRevision or 0, schema.adoptedLegacy and "채택" or "아님", schema.cleanupCandidateCount or 0, schema.unknownRootCount or 0))
  else
    NT:Print("DB Schema FAIL")
  end

  for _, state in ipairs(states) do
    local p = state.primary or {}
    local word = A and A:StatusWord(state) or "UNKNOWN"
    local version = versionSuffix(p.version)
    NT:Print(string.format("%-22s %s%s", tostring(state.label), colorStatus(word), version))
  end

  NT:Print(string.format("Kick %s · Important %s · Enemy %s · Navi %s", onOff(modules.kick), onOff(modules.importantCast), onOff(modules.enemyCount), onOff(modules.naviCursor)))
  do -- 2.6.2: 중요몹 「!」 지금 뜨는지 (쐐기 / 추종자 던전 / 2.6.9 레이드)
    local K=_G.NiniKick
    if K and type(K.ImportantCastStatus)=="function" then
      local ok,line=pcall(K.ImportantCastStatus)
      if ok and line then NT:Print(tostring(line)) end
    end
  end
  NT:Print("Macro Ownership · NiniKickFocus/Auto = NiniTools · Potion/범용 = External(Ellesmere 권장)")
  if A and type(A.DescribeNaowhReminderOwner)=="function" then
    local owner,detail=A:DescribeNaowhReminderOwner()
    NT:Print(string.format("생존기 알림 · %s · %s",tostring(owner),tostring(detail)))
  else
    NT:Print("생존기 알림 · NiniTools 담당 · adapter unavailable")
  end
  NT:Print(string.format("NSR Bridge %s · NSRT Import %s",yesNo(modules.nsrBridge),onOff(modules.nsrtImport)))
  if NT.ExbossS2 and type(NT.ExbossS2.StatusLine)=="function" then
    local ok,line=pcall(NT.ExbossS2.StatusLine,NT.ExbossS2)
    if ok and line then NT:Print(tostring(line)) end
  end
  if NT.NaowhUILink and type(NT.NaowhUILink.StatusLine)=="function" then
    local ok,line=pcall(NT.NaowhUILink.StatusLine,NT.NaowhUILink)
    if ok and line then NT:Print(tostring(line)) end
  end
  if NT.AccountCalendar and type(NT.AccountCalendar.StatusLine)=="function" then
    local ok,line=pcall(NT.AccountCalendar.StatusLine,NT.AccountCalendar)
    if ok and line then NT:Print(tostring(line)) end
  end

  if memoryKB then
    local memLine = string.format("Memory %.1f KB", round1(memoryKB))
    local baseline = self:GetBaseline()
    if baseline and tonumber(baseline.memoryKB) then
      local diff = memoryKB - tonumber(baseline.memoryKB)
      memLine = memLine .. string.format(" · baseline v%s %+0.1f KB", tostring(baseline.version or "?"), round1(diff))
    end
    NT:Print(memLine)
  else
    NT:Print("Memory N/A")
  end

  if profiling and cpuMS then
    local line = string.format("CPU %.2f ms cumulative", cpuMS)
    local prev = self.lastSample
    if prev and prev.cpuMS and now > (prev.at or 0) then
      local dcpu = cpuMS - prev.cpuMS
      local dt = now - prev.at
      if dcpu >= 0 and dt > 0 then
        line = line .. string.format(" · Δ %.2f ms / %.1fs = %.3f ms/s", dcpu, dt, dcpu / dt)
      end
    else
      line = line .. " · 다음 /nini check부터 체크간 구간값 표시"
    end
    NT:Print(line)
    if self.cpuWindow then
      local dcpu = math.max(0, cpuMS - (tonumber(self.cpuWindow.cpuMS) or cpuMS))
      local dt = math.max(0, now - (tonumber(self.cpuWindow.at) or now))
      local tag = self.cpuWindow.label ~= "" and (" · " .. self.cpuWindow.label) or ""
      NT:Print(string.format("CPU 측정중%s · Δ %.2f ms / %.1fs", tag, dcpu, dt))
    end
    NT:Print("scriptProfile ON · 측정 후 /console scriptProfile 0 + /reload 권장")
  elseif profiling then
    NT:Print("CPU profiling ON · 사용량 API N/A · 측정 후 scriptProfile을 끄세요.")
  else
    NT:Print("CPU profiling OFF · /console scriptProfile 1 + /reload 후 측정 가능")
  end

  if #warnings == 0 then
    NT:Print("진단 경고 0")
  else
    for _, w in ipairs(warnings) do NT:Print("|cffffc857경고|r " .. w) end
  end

  NT:Print("복사용 리포트: /nini check copy")
  if profiling then NT:Print("고정 구간 CPU: /nini check cpu start [메모] → 끝에서 cpu stop · 재시작은 cpu restart") end

  self.lastSample = {at = now, cpuMS = cpuMS, memoryKB = memoryKB}
  return {
    adapters = states,
    modules = modules,
    memoryKB = memoryKB,
    cpuMS = cpuMS,
    profiling = profiling,
    warnings = warnings,
  }
end
