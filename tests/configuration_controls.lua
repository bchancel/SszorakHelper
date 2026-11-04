local SH = ...
local ui, options = SH.OptionsUI, SH.Store:Options()
local function check(value, message) assert(value, "Configuration controls: " .. message) end
local function click(control, value)
    control:SetChecked(value)
    control.scripts.OnClick(control)
end
local saved = {lock = options.lockFrames, preview = options.previewFrames, macros = options.showNSRTMacros,
    mapScale = options.roomMapScale, orderScale = options.orderFrameScale, rows = options.nsrtRows}
ui:SelectPage("configuration")
ui:Show()

click(ui.lockFramesToggle, true)
check(ui.previewCell.check:IsEnabled() and ui.previewCell:GetAlpha() == 1, "locked preview is unavailable")
click(ui.previewCell.check, true)
check(options.previewFrames and not options.lockFrames and not ui.lockFramesToggle:GetChecked(), "preview did not turn off lock")
click(ui.lockFramesToggle, true)
check(not options.previewFrames and not ui.previewCell.check:GetChecked(), "locking left preview active")
click(ui.previewCell.check, true)
check(options.previewFrames and not options.lockFrames, "preview could not be re-enabled while locked")
click(ui.previewCell.check, false)
check(not options.previewFrames and not options.lockFrames, "disabling preview unexpectedly locked frames")
click(ui.lockFramesToggle, true)
click(ui.lockFramesToggle, false)
check(ui.previewCell.check:IsEnabled() and not options.previewFrames, "unlocking unexpectedly restored preview")

click(ui.macroEnableToggle, true)
ui:SelectRows(3)
ui:ToggleRowsMenu()
click(ui.macroEnableToggle, false)
check(not ui.profileMenuDismiss:IsShown(), "disabling macros left the Rows menu open")
for _, cell in ipairs(ui.macroOptionCells) do
    check(cell:GetAlpha() < 1, "disabled macro option is not grey")
    local toggle = rawget(cell, "check")
    if toggle then
        check(not toggle:IsEnabled(), "disabled macro toggle is still interactive")
        local previous = toggle:GetChecked()
        toggle.scripts.OnClick(toggle)
        check(toggle:GetChecked() == previous, "disabled macro click changed the toggle")
    end
end
check(not ui.rowsDropdown:IsEnabled(), "disabled macro Rows control is interactive")
ui.rowsDropdown.scripts.OnClick(ui.rowsDropdown)
check(not ui.profileMenuDismiss:IsShown(), "disabled Rows control opened a menu")
click(ui.macroEnableToggle, true)
check(ui.rowsDropdown:IsEnabled() and options.nsrtRows == 3, "enabling macros lost saved row choice")
check(ui.rowsDropdown._shStyle ~= "disabled", "enabled Rows control kept its disabled style")
for _, cell in ipairs(ui.macroOptionCells) do
    check(cell:GetAlpha() == 1, "enabled macro option stayed grey")
    local toggle = rawget(cell, "check")
    if toggle then check(toggle:IsEnabled(), "enabled macro toggle stayed disabled") end
end

ui.roomMapGearButton.scripts.OnClick(ui.roomMapGearButton)
local mapDialog = ui.roomMapDialog
check(ui.roomMapScaleCell:GetParent():GetParent() == mapDialog, "map scale is outside the map submenu")
ui.roomMapScaleCell.slider.scripts.OnValueChanged(ui.roomMapScaleCell.slider, 1.25, true)
check(options.roomMapScale == 1.25 and SH.RoomMap.frame.scale == 1.25 * SH.Const.FRAME_SCALE_BASE, "map scale did not apply")
check(SH.NSRTMacros.frame.scale == SH.RoomMap.frame.scale, "macro scale stopped following map scale")
ui.orderFrameGearButton.scripts.OnClick(ui.orderFrameGearButton)
local orderDialog = ui.orderFrameDialog
check(orderDialog:IsShown() and not mapDialog:IsShown(), "order submenu did not replace map submenu")
check(ui.orderFrameScaleCell:GetParent():GetParent() == orderDialog, "order scale is outside the order submenu")
ui.orderFrameScaleCell.slider.scripts.OnValueChanged(ui.orderFrameScaleCell.slider, 1.5, true)
check(options.orderFrameScale == 1.5 and SH.OrderFrame.frame.scale == 1.5 * SH.Const.FRAME_SCALE_BASE, "order scale did not apply")
check(options.roomMapScale == 1.25, "order scale changed map scale")
ui.frame:Hide()
check(not orderDialog:IsShown(), "closing Configuration left the order submenu open")
ui:Show()
ui.orderFrameGearButton.scripts.OnClick(ui.orderFrameGearButton)
check(ui.orderFrameDialog == orderDialog and #ui.scaleControls == 2, "reopening duplicated the scale controls")
ui:SelectPage("layout")
check(not orderDialog:IsShown(), "switching pages left the order submenu open")
check(ui.frame.clamped == false, "Configuration is still clamped to the screen")
ui.frame.scripts.OnDragStart(ui.frame)
check(ui.frame.moving, "Configuration cannot be dragged")
ui.frame.scripts.OnDragStop(ui.frame)
check(not ui.frame.moving, "Configuration drag did not stop")

options.lockFrames, options.previewFrames, options.showNSRTMacros = saved.lock, saved.preview, saved.macros
options.roomMapScale, options.orderFrameScale, options.nsrtRows = saved.mapScale, saved.orderScale, saved.rows
SH.RoomMap:ApplyScale()
SH.NSRTMacros:ApplyScale()
SH.OrderFrame:ApplyScale()
ui:SelectPage("configuration")
SH.Encounter:RefreshDisplays()
print("Configuration controls checks passed: mutually exclusive preview/lock, disabled macro controls, scale submenus and unclamped dragging.")
