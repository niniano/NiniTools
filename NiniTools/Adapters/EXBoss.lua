local _, NT = ...
local A = NT and NT.Adapters
if not A then return end

A:Register("exboss", {
  label = "EXBoss",
  addon = "EXBoss",
  role = "던전 기믹/쓰레기 시전 신호",
  probe = function()
    return type(_G.ExwindTools) == "table", "ExwindTools event bus"
  end,
})
