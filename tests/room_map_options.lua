local SH = ...
local ui, map, options = SH.OptionsUI, SH.RoomMap, SH.Store:Options()
local function check(value, reason) assert(value, "Room map options: " .. reason) end
local saved = {clear = options.showClearButton, spread = options.showMythicPosition, winds = options.showWindOrderButtons,
    preview = options.previewFrames, assignments = SH.Encounter.assignments, personal = SH.MythicPositions.personal,
    member = SH.MythicPositions:GetProfile().slots[8].member}
local originalCount, scans = GetNumGroupMembers, 0
GetNumGroupMembers = function() scans = scans + 1; return originalCount() end
options.showClearButton, options.showMythicPosition, options.showWindOrderButtons, options.previewFrames = false, false, true, true
SH.Encounter.assignments = {[1] = 2}
SH.MythicPositions:GetProfile().slots[8].member = {name = "Caller-Realm", class = "MAGE"}
ui:SelectPage("configuration")
check(ui.roomMapGearButton and ui.roomMapGearButton:GetParent().label:GetText() == "Room Mini Map", "gear is not beside the map toggle")
ui.roomMapGearButton.scripts.OnClick(ui.roomMapGearButton)
local dialog, controls = ui.roomMapDialog, ui.roomMapChecks
check(dialog:IsShown() and controls.clear and controls.spread and controls.winds, "gear did not open all three options")
local function click(control, value) control:SetChecked(value); control.scripts.OnClick(control) end
click(controls.clear, true)
check(options.showClearButton and map.frame.clear:IsShown(), "clear option did not show the button")
click(controls.clear, false)
check(not options.showClearButton and not map.frame.clear:IsShown(), "clear option did not hide the button")
click(controls.spread, true)
check(options.showMythicPosition and map.frame.mythicDot:IsShown(), "spread option did not show static point")
click(controls.spread, false)
check(not map.frame.mythicDot:IsShown(), "spread option did not hide static point")
click(controls.winds, false)
for _, group in ipairs(map.frame.groups) do
    check(group.marker:IsShown(), "hiding selection buttons removed a floor marker")
    for _, button in pairs(group.buttons) do check(not button:IsShown(), "wind button remained visible") end
end
check(SH.Encounter.assignments[1] == 2, "hiding wind buttons erased the wind selection")
click(controls.winds, true)
for _, group in ipairs(map.frame.groups) do
    for _, button in pairs(group.buttons) do check(button:IsShown(), "wind buttons did not return") end
end
check(map.frame.groups[2].buttons[1]._shEnabledStyle == "success", "restored wind buttons lost selected style")
dialog.close.scripts.OnClick(dialog.close)
check(not dialog:IsShown(), "close did not dismiss map settings")
ui.roomMapGearButton.scripts.OnClick(ui.roomMapGearButton)
check(ui.roomMapDialog == dialog and controls.winds:GetChecked(), "gear lost settings or recreated its dialog")
ui.frame:Hide()
check(not dialog:IsShown(), "closing configuration left the gear dialog open")
check(scans == 0, "map display settings enumerated the raid")

GetNumGroupMembers = originalCount
options.showClearButton, options.showMythicPosition, options.showWindOrderButtons, options.previewFrames = saved.clear, saved.spread, saved.winds, saved.preview
SH.Encounter.assignments = saved.assignments
SH.MythicPositions:GetProfile().slots[8].member = saved.member
SH.MythicPositions.personal = saved.personal
SH.Encounter:RefreshDisplays()
print("Room map options checks passed: gear dialog, clear/spread/wind toggles, preserved assignments and no roster scans.")
