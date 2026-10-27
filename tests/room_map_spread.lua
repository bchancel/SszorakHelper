local SH = ...
local map, E, ui, options = SH.RoomMap, SH.Encounter, SH.OptionsUI, SH.Store:Options()
local function check(value, message) assert(value, "Room spread: " .. message) end
local function near(a, b) return math.abs(a - b) < 0.00001 end
local keys = {"roomMapBackground", "roomMapFloorOpacity", "roomMapShowAssignmentLabel", "roomMapShowBoss",
    "roomMapSpreadSide", "roomMapStartingSide", "showMythicPosition", "previewFrames", "showFuryCountdown", "furyVoiceCountdown"}
local saved = {}
for _, key in ipairs(keys) do saved[key] = options[key] end
local personal = SH.MythicPositions.personal
local originalCount, originalName = GetNumGroupMembers, UnitFullName
local scans, reads = 0, 0
GetNumGroupMembers = function() scans = scans + 1; return originalCount() end
UnitFullName = function(...) reads = reads + 1; return originalName(...) end

check(options.roomMapBackground == "floor" and options.roomMapFloorOpacity == 0.6, "room-floor defaults missing")
check(options.roomMapSpreadSide == "auto" and options.roomMapStartingSide == "entrance", "automatic entrance-first defaults missing")
options.showMythicPosition, options.previewFrames = true, true
SH.MythicPositions.personal = {slot = 5, x = 0.4169, y = 0.7752}
local point = SH.MythicPositions.personal
map:ApplyFloorStyle()
E:SetFuryIndex(1)
check(map.frame.floor:IsShown() and map.frame.floor:GetTexture():find("SszorakHelper\\Media\\RoomFloor.tga", 1, true), "room floor did not use runtime media")
check(near(map.frame.floor:GetAlpha(), 0.6) and near(map.frame.floor:GetHeight() / map.frame.floor:GetWidth(), 1380 / 1456), "floor opacity or coordinate aspect ratio incorrect")
check(not rawget(map.frame, "player"), "fixed player arrow remained")
check(map.frame.mythicDot:IsShown() and map.frame.mythicHalo:IsShown() and map.frame.mythicBorder:IsShown(), "outlined planning point missing")
check(map.frame.mythicLabel:GetText() == "YOU - 5" and map.frame.mythicLabel:IsShown(), "assignment number label missing")
check(map.frame.boss:IsShown() and map.frame.boss:GetTexture() == 7966619, "boss portrait missing")
local exitGroup = map.frame.groups[SH.Const.EXIT_POSITION]
local entranceGroup = map.frame.groups[SH.Const.ENTRANCE_POSITION]
check(near(exitGroup.point[5], 124 - 5 - 17) and near(entranceGroup.point[5], -124 - 5 - 17),
    "entrance/exit markers were not moved outward")
check(map.frame:GetHeight() == 372, "map has no vertical clearance for endpoint markers and labels")
local entrance = map.frame.mythicDot.point
local boss = map.frame.boss.point
local markers, floor = {}, map.frame.floor.point
for i, group in ipairs(map.frame.groups) do markers[i] = group.point end
E:SetFuryIndex(2)
local exit = map.frame.mythicDot.point
check(near(exit[4], -entrance[4]) and near(exit[5] + 5, -(entrance[5] + 5)), "exit did not rotate both axes 180 degrees")
check(near(map.frame.boss.point[5] + 5, -(boss[5] + 5)) and map.frame.spreadSide:GetText() == "SPREAD: EXIT", "boss or side label did not follow rotation")
check(point.x == 0.4169 and point.y == 0.7752 and floor == map.frame.floor.point, "rotation changed saved point or room texture")
for i, group in ipairs(map.frame.groups) do check(group.point == markers[i], "a floor marker moved with the spread side") end
E:SetFuryIndex(3)
check(map:GetSpreadSide() == "entrance", "third Fury did not return to entrance")
for index, side in ipairs({"entrance", "exit", "entrance", "exit", "entrance", "exit"}) do
    E:SetFuryIndex(index)
    check(map:GetSpreadSide() == side, "second Fury of a later phase did not flip to Exit")
end

ui:ShowRoomMapDialog()
local function choose(key, value)
    for _, entry in ipairs(ui.roomMapChoices[key]) do
        if entry.value == value then entry.button.scripts.OnClick(entry.button); return entry.button end
    end
    error("missing option " .. value)
end
choose("roomMapBackground", "outline")
check(not map.frame.floor:IsShown(), "outline kept the floor texture visible")
for _, line in ipairs(map.frame.floorLines) do check(line:IsShown(), "outline omitted a room landmark") end
choose("roomMapBackground", "none")
for _, line in ipairs(map.frame.floorLines) do check(not line:IsShown(), "None kept room details visible") end
for _, edge in ipairs(map.frame.edges) do check(not edge:IsShown(), "None kept the outer outline visible") end
choose("roomMapBackground", "floor")
local windowOpacity = options.frameBackgroundOpacity
ui.roomMapOpacity.scripts.OnValueChanged(ui.roomMapOpacity, 0.35, true)
check(near(map.frame.floor:GetAlpha(), 0.35) and ui.roomMapOpacityLabel:GetText() == "Floor opacity: 35%", "opacity control did not update floor and label")
check(options.frameBackgroundOpacity == windowOpacity, "floor opacity changed other window backgrounds")
local function toggle(control, value) control:SetChecked(value); control.scripts.OnClick(control) end
toggle(ui.roomMapChecks.label, false)
toggle(ui.roomMapChecks.boss, false)
check(not map.frame.mythicLabel:IsShown() and not map.frame.boss:IsShown() and map.frame.mythicDot:IsShown(), "label/boss toggles hid the assigned point")
toggle(ui.roomMapChecks.label, true)
toggle(ui.roomMapChecks.boss, true)
choose("roomMapStartingSide", "exit")
E:SetFuryIndex(1)
check(map:GetSpreadSide() == "exit", "exit-first option ignored")
E:SetFuryIndex(2)
check(map:GetSpreadSide() == "entrance", "exit-first option did not alternate")
choose("roomMapSpreadSide", "entrance")
E:SetFuryIndex(2)
check(map:GetSpreadSide() == "entrance" and not ui.roomMapChoices.roomMapStartingSide[1].button:IsEnabled(), "manual override or disabled starting-side controls incorrect")
choose("roomMapSpreadSide", "exit")
E:SetFuryIndex(3)
check(map:GetSpreadSide() == "exit", "manual exit override changed on a countdown")
choose("roomMapSpreadSide", "auto")
choose("roomMapStartingSide", "entrance")

-- Reuse real configured callbacks, with all warning output disabled.
options.showFuryCountdown, options.furyVoiceCountdown, options.previewFrames = false, false, false
E:Start("Sszorak", 16)
check(map:GetSpreadSide() == "entrance", "pull did not reset the starting side")
E.timers["schedule:fury2"].callback()
check(map:GetSpreadSide() == "exit" and not E.timers.furyTick, "automatic rotation depended on warning visibility")
E:Stop()
check(map:GetSpreadSide() == "entrance", "encounter end left the previous side active")

ui:EnterTestMode()
local button = ui.testButtons["Fury Countdown"]
button.scripts.OnClick(button)
check(map:GetSpreadSide() == "entrance", "first test countdown used wrong side")
button.scripts.OnClick(button)
check(map:GetSpreadSide() == "exit", "second test countdown did not alternate")
ui.testButtons.Reset.scripts.OnClick(ui.testButtons.Reset)
check(map:GetSpreadSide() == "entrance" and not E.timers.furyTick, "test Reset did not restore starting side or cancel countdown")
button.scripts.OnClick(button)
check(map:GetSpreadSide() == "entrance", "test sequence did not restart after Reset")
ui:QuitTestMode()
check(not E.timers.furyTick and map:GetSpreadSide() == "entrance", "quitting Test Mode left work or side state")
SH.MythicPositions.personal = {slot = 2, x = 0.5, y = 0.95}
options.previewFrames = true
map:RefreshMythicPosition()
check(map.frame.mythicLabel:GetText() == "YOU - Tank", "tank received a numeric label")
SH.MythicPositions.personal.slot = 9
map:RefreshMythicPosition()
check(map.frame.mythicLabel:GetText() == "YOU - Healer", "healer received a numeric label")
options.showMythicPosition = false
map:RefreshMythicPosition()
check(not map.frame.mythicDot:IsShown() and not map.frame.mythicHalo:IsShown() and not map.frame.mythicLabel:IsShown()
    and not map.frame.boss:IsShown() and not map.frame.spreadSide:IsShown(), "disabled spread left decorations visible")
check(not map.frame.scripts.OnUpdate and scans == 0 and reads == 0, "room rendering polled or inspected the raid")

GetNumGroupMembers, UnitFullName = originalCount, originalName
for _, key in ipairs(keys) do options[key] = saved[key] end
SH.MythicPositions.personal = personal
map:ApplyFloorStyle()
map:RefreshMythicPosition()
ui:RefreshRoomMapControls()
ui.roomMapDialog:Hide()
print("Room spread checks passed: floor styles, independent opacity, role labels, mirrored sides, fixed markers, scheduled/Test Mode rotation and no roster reads.")
