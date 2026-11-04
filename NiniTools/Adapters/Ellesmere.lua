local _, NT = ...
local A = NT and NT.Adapters
if not A then return end

A:Register("ellesmere", {
  label = "EllesmereUI",
  addon = "EllesmereUI",
  role = "쿨다운/강화효과 UI 표시",
  probe = function()
    return type(_G.EllesmereUI) == "table", "EllesmereUI"
  end,
})
