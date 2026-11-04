local SH, context = ...
local ui, M, map, E = SH.OptionsUI, SH.NSRTMacros, SH.RoomMap, SH.Encounter
local options = SH.Store:Options()
local function check(value, message) assert(value, "Map macros: " .. message) end
local function near(a, b) return math.abs(a - b) < 0.00001 end
local function click(control, value)
    control:SetChecked(value)
    control.scripts.OnClick(control)
end
local keys = {"showRoomMap", "showNSRTMacros", "nsrtButtonsOnMap", "nsrtAttachToMap", "nsrtAutoShow", "nsrtShowEntranceExit",
    "nsrtPanelOpen", "nsrtOppositeMacros", "nsrtRows", "previewFrames", "lockFrames", "roomMapScale", "nsrtKeybindsEnabled"}
local saved = {}
for _, key in ipairs(keys) do saved[key] = options[key] end
local savedBinds = options.nsrtKeybinds
local savedHidden, savedAuto = M.panelHidden, M.autoRoomVisible
local originalMacros = {}
for i = 1, 8 do originalMacros[i] = context.macros["NSRT_SSZORAK_" .. i] end

context.setRaid(true)
options.nsrtButtonsOnMap, options.showRoomMap, options.showNSRTMacros = false, true, true
options.nsrtAttachToMap, options.nsrtAutoShow, options.nsrtShowEntranceExit = true, false, false
options.previewFrames, options.lockFrames, options.roomMapScale = false, false, 1.25
options.nsrtKeybinds, options.nsrtKeybindsEnabled = {}, false
M.panelHidden = false
check(M:CreateOrRepairMacros(true), "could not prepare opposite macros")
M:SetPanelOpen(true)
map:ApplyScale()
M:ApplyScale()
check(SH.Keybinds:Set(6, "CTRL-F10") and SH.Keybinds:SetEnabled(true), "could not prepare existing room keybind")
local binding = GetBindingAction("CTRL-F10", true)
local buttons = {}
for i, button in ipairs(M.secureFrame.buttons) do buttons[i] = button end
local bodies = {}
for i = 1, 8 do bodies[i] = context.macros["NSRT_SSZORAK_" .. i] end
ui:SelectPage("configuration")
click(ui.buttonsOnMapToggle, true)
check(options.nsrtButtonsOnMap and options.nsrtAttachToMap and not M.attached, "map mode did not override saved attachment")
check(not ui.attachToMapCell.check:IsEnabled() and not ui.attachToMapCell.check:GetChecked(), "Attach to Map is not disabled and unchecked")
check(map.frame:IsShown() and M.secureFrame:IsShown() and not M.frame:IsShown(), "map macro visibility is wrong before the pull")
check(GetBindingAction("CTRL-F10", true) == binding, "map mode changed the existing keybind target")
check(M.secureFrame:GetParent() == UIParent and M.secureFrame.point[2] == UIParent, "secure layer depends on the map frame")
for position = 1, 8 do
    local slot = M:GetSlotForPosition(position)
    local button = M.secureFrame.buttons[slot]
    check(button == buttons[slot], "map mode replaced an existing keybind button")
    local x, y = map:GetMarkerPoint(position)
    local scale = map.frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    check(button.point[1] == "CENTER" and near(button.point[4], x * scale) and near(button.point[5], y * scale), "map click target is not aligned to its marker")
    check(near(button:GetWidth(), 32 * scale), "map click target does not match icon scale")
end
local oldCenterX, oldCenterY = rawget(map.frame, "centerX"), rawget(map.frame, "centerY")
map.frame.centerX, map.frame.centerY = 170, 240
map.frame.scripts.OnDragStop(map.frame)
local ratio = map.frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
check(near(M.secureFrame.point[4], 170 * ratio) and near(M.secureFrame.point[5], 240 * ratio), "dragging the map left macro targets behind")
map.frame.centerX, map.frame.centerY = oldCenterX, oldCenterY
M:ApplySecurePosition()
for position, markerID in pairs({[6] = 6, [8] = 1, [3] = 7}) do
    check(M.sentMarkerIDs[M:GetSlotForPosition(position)] == markerID, "Circle/Diamond/Triangle sent the wrong opposite")
end
for i, body in ipairs(bodies) do check(context.macros["NSRT_SSZORAK_" .. i] == body, "map mode rewrote a macro") end
check(not M.secureFrame.buttons[7]:IsShown() and not M.secureFrame.buttons[8]:IsShown(), "optional endpoint macros unexpectedly enabled")
click(ui.showEntranceExitToggle, true)
check(M.secureFrame.buttons[7]:IsShown() and M.secureFrame.buttons[8]:IsShown(), "optional endpoint macros did not enable")

-- A normal secure click advances existing suggestions; no local selection or
-- fabricated raid reception is introduced by the map click layer.
local slot = M:GetSlotForPosition(6)
M:SetOrder({6, 1, 7})
local assignments, received = E.assignments, SH.Comms.receivedCount
buttons[slot].scripts.PostClick(buttons[slot], "LeftButton", false)
check(M.nextStep == 2 and E.assignments == assignments and SH.Comms.receivedCount == received, "map click changed local planning or fabricated raid messages")
local macroName = "NSRT_SSZORAK_6"
context.macros[macroName] = "/raid unexpected"
M:RefreshLayout()
check(buttons[slot].attributes.type == nil and not M.available[slot], "map accepted a modified macro")
check(map.frame.groups[6].marker:GetAlpha() < 1, "unavailable map macro was not dimmed")
context.macros[macroName] = bodies[6]
M:RefreshLayout()

-- Public configuration changes may be queued, but cannot move live secure
-- targets or change what their visible markers mean during combat.
context.setCombat(true)
local point, scale, macro = buttons[slot].point, map.frame.scale, buttons[slot].attributes.macro
options.roomMapScale = 1.75
map:ApplyScale()
M:ApplyScale()
click(ui.buttonsOnMapToggle, false)
M:SetPanelOpen(false)
map:RefreshVisibility()
check(M.buttonsOnMap and buttons[slot].point == point and map.frame.scale == scale, "combat option change moved the live map buttons")
check(buttons[slot].attributes.macro == macro and GetBindingAction("CTRL-F10", true) == binding, "combat option change altered a macro or keybind")
check(map.frame:IsShown() and M.secureFrame:IsShown() and not M.frame:IsShown(), "combat hide left live buttons without the map")
context.setCombat(false)
context.fire("PLAYER_REGEN_ENABLED")
check(not M.buttonsOnMap and M.attached and not M.secureFrame:IsShown(), "queued mode/hide changes were not applied")
check(near(map.frame.scale, 1.75 * SH.Const.FRAME_SCALE_BASE), "queued map scale was not applied")
check(GetBindingAction("CTRL-F10", true) == "", "hidden buttons retained their override binding")
M:SetPanelOpen(true)
check(GetBindingAction("CTRL-F10", true) == binding and M.frame:IsShown(), "normal panel did not restore the original keybind")
check(ui.attachToMapCell.check:IsEnabled(), "leaving map mode did not enable Attach to Map")

-- Test a custom layout with unchanged physical-position bindings.
check(SH.Store:SetTemporaryLayout({8, 1, 2, 3, 4, 5, 6, 7}, "Map test"), "custom layout rejected")
context.setCombat(true)
point = buttons[slot].point
click(ui.buttonsOnMapToggle, true)
check(not M.buttonsOnMap and M.frame:IsShown() and buttons[slot].point == point, "enabling map buttons during combat moved the normal panel")
context.setCombat(false)
context.fire("PLAYER_REGEN_ENABLED")
check(M.buttonsOnMap and not M.frame:IsShown(), "queued enabling of map buttons did not apply")
map:RefreshLayout()
M:RefreshLayout()
check(buttons[slot].attributes.macro == "NSRT_SSZORAK_1", "map mode ignored custom opposite layout")
check(GetBindingAction("CTRL-F10", true) == binding, "custom layout changed the physical-position bind")
SH.Store:ClearTemporaryLayout()

-- Disabling all macro buttons removes map clicks without hiding the room map
-- in an encounter preview, and re-enabling restores the existing targets.
options.previewFrames = true
click(ui.macroEnableToggle, false)
check(not M.secureFrame:IsShown() and map.frame:IsShown(), "disabling macros removed the map or left live clicks")
check(GetBindingAction("CTRL-F10", true) == "", "disabled map macros retained keybind overrides")
click(ui.macroEnableToggle, true)
check(M.secureFrame:IsShown() and GetBindingAction("CTRL-F10", true) == binding, "re-enabling map macros lost keybinds")
options.showRoomMap = false
E:RefreshDisplays()
check(not M.secureFrame:IsShown() and GetBindingAction("CTRL-F10", true) == "", "hidden room map left invisible click targets or keybinds")
click(ui.buttonsOnMapToggle, true)
check(options.showRoomMap and map.frame:IsShown() and M.secureFrame:IsShown(), "enabling map buttons did not enable the room map")

for _, key in ipairs(keys) do options[key] = saved[key] end
options.nsrtKeybinds = savedBinds
M.panelHidden, M.autoRoomVisible = savedHidden, savedAuto
for i = 1, 8 do context.macros["NSRT_SSZORAK_" .. i] = originalMacros[i] end
map:ApplyScale()
map:RefreshLayout()
M:ApplyScale()
M:RefreshLayout()
E:RefreshDisplays()
ui:Refresh()
print("Map macros checks passed: shared secure buttons/keybinds, opposite/custom layouts, scaled targets, missing macros and combat deferral.")
