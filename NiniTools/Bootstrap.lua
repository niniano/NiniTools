local ADDON_NAME, NT = ...
-- SavedVariables are restored after file execution. Rebind before module init.
function NT:BindModuleDB()
NiniToolsDB = type(NiniToolsDB)=="table" and NiniToolsDB or {}
NiniToolsDB.modules = type(NiniToolsDB.modules)=="table" and NiniToolsDB.modules or {}

NiniToolsDB.modules.kick = type(NiniToolsDB.modules.kick)=="table" and NiniToolsDB.modules.kick or {}
NiniToolsDB.modules.gold = type(NiniToolsDB.modules.gold)=="table" and NiniToolsDB.modules.gold or {}
NiniToolsDB.modules.media = type(NiniToolsDB.modules.media)=="table" and NiniToolsDB.modules.media or {}
NiniToolsDB.modules.nsrt = type(NiniToolsDB.modules.nsrt)=="table" and NiniToolsDB.modules.nsrt or {}
NiniToolsDB.modules.enemyCount = type(NiniToolsDB.modules.enemyCount)=="table" and NiniToolsDB.modules.enemyCount or {}

-- Legacy global names remain as in-memory aliases so the mature module code can
-- keep working, but only NiniToolsDB is persisted by the single NiniTools addon.
RogueDefensivesDB = NiniToolsDB.modules.kick
NiniGoldDB = NiniToolsDB.modules.gold
NiniMediaDB = NiniToolsDB.modules.media
NiniEnemyCountDB = NiniToolsDB.modules.enemyCount
if NiniMediaDB.jumpSoundEnabled==nil then NiniMediaDB.jumpSoundEnabled=false end
if NiniMediaDB.callMeEnabled==nil then NiniMediaDB.callMeEnabled=true end
if type(NiniMediaDB.callMeAliases)~="string" then NiniMediaDB.callMeAliases="" end
if NiniMediaDB.callMeVolume==nil then NiniMediaDB.callMeVolume=160 end
if NiniMediaDB.naviCursorEnabled==nil then NiniMediaDB.naviCursorEnabled=true end
if NiniMediaDB.naviCursorRingEnabled==nil then NiniMediaDB.naviCursorRingEnabled=true end
if NiniMediaDB.naviCursorGlowEnabled==nil then NiniMediaDB.naviCursorGlowEnabled=true end
if NiniMediaDB.naviCursorScale==nil then NiniMediaDB.naviCursorScale=100 end
if NiniMediaDB.naviChatEnabled==nil then NiniMediaDB.naviChatEnabled=true end
if NiniMediaDB.naviChatFontSize==nil then NiniMediaDB.naviChatFontSize=14 end
if NiniMediaDB.naviChatX==nil then NiniMediaDB.naviChatX=-488 end
if NiniMediaDB.naviChatY==nil then NiniMediaDB.naviChatY=202 end
if NiniMediaDB.naviChatUnlocked==nil then NiniMediaDB.naviChatUnlocked=false end

NiniToolsDB.unified = type(NiniToolsDB.unified)=="table" and NiniToolsDB.unified or {}
NiniToolsDB.unified.version = 2
NiniToolsDB.unified.active = true
end
NT:BindModuleDB()
local boot=_G.NiniTools.EventDispatcher:CreateProxy("Bootstrap")
boot:RegisterEvent("ADDON_LOADED")
boot:SetScript("OnEvent",function(self,_,name)
  if name~=ADDON_NAME then return end
  NT:BindModuleDB()
  if NT.DBSchema and type(NT.DBSchema.EnsureMeta)=="function" then NT.DBSchema:EnsureMeta() end
  self:UnregisterEvent("ADDON_LOADED")
end)
