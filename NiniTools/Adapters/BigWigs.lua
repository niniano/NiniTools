local _, NT = ...
local A = NT and NT.Adapters
if not A then return end

A:Register("bigwigs", {
  label = "BigWigs",
  addon = "BigWigs",
  extras = {"LittleWigs"},
  role = "보스/던전 타이머 · 카운트다운 · 위험 신호",
  probe = function()
    return type(_G.BigWigsAPI) == "table", "BigWigsAPI"
  end,
})
