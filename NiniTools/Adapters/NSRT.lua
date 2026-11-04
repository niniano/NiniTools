local _, NT = ...
local A = NT and NT.Adapters
if not A then return end

A:Register("nsrt", {
  label = "NorthernSkyRaidTools",
  addon = "NorthernSkyRaidTools",
  role = "개인 메모/레이드 리마인더",
  probe = function()
    return type(_G.NSRT) == "table" or type(_G.NorthernSkyRaidTools) == "table", "NSRT globals"
  end,
})
