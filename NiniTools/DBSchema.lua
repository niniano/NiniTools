local ADDON_NAME, NT = ...
NT = NT or _G.NiniTools or {}
_G.NiniTools = NT

-- Formal SavedVariables schema management starts with 2.5.0-RC3.
-- Older NiniTools databases did not carry a root schema number, so RC3 adopts
-- them losslessly as schema 1 instead of guessing their age or resetting them.
local S = NT.DBSchema or {}
NT.DBSchema = S

S.CURRENT_SCHEMA = 1
S.MIN_MIGRATABLE_SCHEMA = 1
S.CLEANUP_REVISION = 1 -- RC4: remove only the three root keys audited in RC3.1.

S.KNOWN_ROOT_KEYS = {
  minimapHide=true,
  minimapAngle=true,
  lastPage=true,
  goldBackup=true,
  modules=true,
  unified=true,
  ui=true,
  diagnostics=true,
  _niniMeta=true,
  fontPrefs=true, -- 2.5.4: /nt font (본문·숫자 SharedMedia 글꼴 이름)
  exbossS2=true, -- 2.5.5: Nini_S2 EXBoss 프로필 선택 기록 (예전 선택 복원용)

  -- Active root-level settings that predate the formal schema.
  dungeonSearchEnabled=true,
  dungeonSearchIndividualSelection=true,
  dungeonSearchPosition=true,
  waypoints=true,
  windowWidth=true,
  windowHeight=true,
  windowScale=true,
}

-- Explicitly audited obsolete roots. RC3.1 still does not delete them; RC4 may
-- remove only these exact keys after the corresponding write path is retired.
S.DEPRECATED_ROOT_KEYS = {
  kickSubPage="write-only UI state (no read/restore path)",
  mediaSubPage="write-only UI state (no read/restore path)",
  migration="legacy migration state (no current code reference)",
}

-- These roots contain user state, accumulated history, or module-owned data.
-- Future cleanup code must never delete them merely because nested keys look old.

local CLEANUP_STEPS = {
  [1] = {
    keys = { "kickSubPage", "mediaSubPage", "migration" },
    note = "RC4 audited root cleanup",
  },
}

S.PROTECTED_ROOTS = {
  modules=true,
  goldBackup=true,
  diagnostics=true,
  ui=true,
  waypoints=true,
  exbossS2=true,
}

local function nowEpoch()
  return type(time)=="function" and time() or 0
end

local function countKeys(t)
  local n=0
  if type(t)=="table" then for _ in pairs(t) do n=n+1 end end
  return n
end

local function sortedKeys(t)
  local out={}
  if type(t)=="table" then
    for k in pairs(t) do out[#out+1]=tostring(k) end
  end
  table.sort(out)
  return out
end

function S:EnsureMeta()
  if type(NT.BindModuleDB)=="function" then NT:BindModuleDB() end
  NiniToolsDB = type(NiniToolsDB)=="table" and NiniToolsDB or {}
  local db=NiniToolsDB
  db._niniMeta=type(db._niniMeta)=="table" and db._niniMeta or {}
  local meta=db._niniMeta

  local schema=tonumber(meta.schemaVersion)
  if schema==nil then
    -- First formal schema adoption. No existing settings are changed or removed.
    meta.schemaVersion=self.CURRENT_SCHEMA
    meta.adoptedLegacy=true
    meta.adoptedAt=meta.adoptedAt or nowEpoch()
    meta.adoptedVersion=meta.adoptedVersion or tostring(NT.VERSION or "?")
    schema=self.CURRENT_SCHEMA
  end

  meta.minimumMigratableSchema=self.MIN_MIGRATABLE_SCHEMA
  meta.cleanupRevision=tonumber(meta.cleanupRevision) or 0

  -- Never run destructive cleanup against an unsupported/future schema.
  if schema>=self.MIN_MIGRATABLE_SCHEMA and schema<=self.CURRENT_SCHEMA then
    local rev=meta.cleanupRevision
    while rev<self.CLEANUP_REVISION do
      local nextRev=rev+1
      local step=CLEANUP_STEPS[nextRev]
      if not step then break end

      local removed={}
      for _,key in ipairs(step.keys or {}) do
        if db[key]~=nil then
          db[key]=nil
          removed[#removed+1]=key
        end
      end

      rev=nextRev
      meta.cleanupRevision=rev
      meta.lastCleanupRevision=rev
      meta.lastCleanupAt=nowEpoch()
      meta.lastCleanupVersion=tostring(NT.VERSION or "?")
      meta.lastCleanupRemovedCount=#removed
      meta.lastCleanupRemovedKeys=removed
      meta.lastCleanupNote=step.note
    end
  end

  meta.lastSeenVersion=tostring(NT.VERSION or "?")
  meta.lastSeenAt=nowEpoch()
  return meta
end

function S:GetDeprecatedRootKeys()
  local out={}
  local db=type(NiniToolsDB)=="table" and NiniToolsDB or {}
  for k in pairs(self.DEPRECATED_ROOT_KEYS) do
    if db[k]~=nil then out[#out+1]=tostring(k) end
  end
  table.sort(out)
  return out
end

function S:GetUnknownRootKeys()
  local out={}
  local db=type(NiniToolsDB)=="table" and NiniToolsDB or {}
  for k in pairs(db) do
    if not self.KNOWN_ROOT_KEYS[k] and not self.DEPRECATED_ROOT_KEYS[k] then
      out[#out+1]=tostring(k)
    end
  end
  table.sort(out)
  return out
end

function S:GetState()
  local meta=self:EnsureMeta()
  local schema=tonumber(meta.schemaVersion) or 0
  local deprecated=self:GetDeprecatedRootKeys()
  local unknown=self:GetUnknownRootKeys()
  return {
    schemaVersion=schema,
    currentSchema=self.CURRENT_SCHEMA,
    minMigratableSchema=self.MIN_MIGRATABLE_SCHEMA,
    cleanupRevision=tonumber(meta.cleanupRevision) or 0,
    targetCleanupRevision=self.CLEANUP_REVISION,
    lastCleanupRevision=tonumber(meta.lastCleanupRevision) or 0,
    lastCleanupRemovedCount=tonumber(meta.lastCleanupRemovedCount) or 0,
    lastCleanupRemovedKeys=type(meta.lastCleanupRemovedKeys)=="table" and meta.lastCleanupRemovedKeys or {},
    lastCleanupVersion=meta.lastCleanupVersion,
    adoptedLegacy=meta.adoptedLegacy==true,
    adoptedVersion=meta.adoptedVersion,
    futureSchema=schema>self.CURRENT_SCHEMA,
    belowMinimum=schema<self.MIN_MIGRATABLE_SCHEMA,
    deprecatedRootKeys=deprecated,
    deprecatedRootCount=#deprecated,
    cleanupCandidateKeys=deprecated,
    cleanupCandidateCount=#deprecated,
    unknownRootKeys=unknown,
    unknownRootCount=#unknown,
    protectedRootCount=countKeys(self.PROTECTED_ROOTS),
    protectedRoots=sortedKeys(self.PROTECTED_ROOTS),
  }
end

function S:IsHealthy()
  local st=self:GetState()
  return not st.futureSchema and not st.belowMinimum
end

function S:Describe()
  local st=self:GetState()
  local origin=st.adoptedLegacy and "Legacy→S1" or ("S"..tostring(st.schemaVersion))
  return string.format(
    "Schema %d/%d · Min %d · Cleanup %d · %s · 후보 %d · 미분류 %d",
    st.schemaVersion, st.currentSchema, st.minMigratableSchema,
    st.cleanupRevision, origin, st.cleanupCandidateCount or 0, st.unknownRootCount or 0
  )
end

