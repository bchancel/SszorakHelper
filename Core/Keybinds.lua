local _, SH = ...

SH.Keybinds = {initializeOrder = 36, warnedConflicts = {}, appliedKeys = {}}
SH.modules.Keybinds = SH.Keybinds

local function validPosition(position)
    return type(position) == "number" and position >= 1 and position <= 8 and position == math.floor(position)
end

function SH.Keybinds:KeyLabel(key)
    return key and (GetBindingText(key, "KEY_", true) or key) or "Unassigned"
end

function SH.Keybinds:Get(position)
    local key = SH.Store:Options().nsrtKeybinds[position]
    return type(key) == "string" and key ~= "" and key or nil
end

function SH.Keybinds:WithModifiers(key)
    return (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "")
        .. (IsShiftKeyDown() and "SHIFT-" or "") .. key
end

function SH.Keybinds:GetConflict(key, position)
    for other = 1, 8 do
        if other ~= position and self:Get(other) == key then
            return self:KeyLabel(key) .. " is already assigned to " .. SH.Const.DIRECTIONS[other] .. ". Choose another key."
        end
    end
    local base = GetBindingAction(key, false)
    local effective = GetBindingAction(key, true)
    local ownAction = "CLICK SszorakHelperNSRTMacroButton" .. SH.NSRTMacros:GetSlotForPosition(position) .. ":LeftButton"
    local own = effective == ownAction and self.appliedKeys[key] == ownAction
    local action = base and base ~= "" and base or (not own and effective or nil)
    if action and action ~= "" then
        local name = _G["BINDING_NAME_" .. action] or (action:match("^CLICK ") and "another addon action") or action
        return self:KeyLabel(key) .. " is already bound to " .. name .. ". Choose another key."
    end
end

function SH.Keybinds:Set(position, key)
    if InCombatLockdown() then return false, "Keybinds cannot be changed during combat." end
    if not validPosition(position) then return false, "Choose a room position." end
    if key then
        if type(key) ~= "string" or key == "" or key:find("%s") then return false, "Choose a valid key." end
        key = key:upper()
        if key == "BUTTON1" or key == "BUTTON2" or key == "ESCAPE" then return false, "Choose another key." end
        local conflict = self:GetConflict(key, position)
        if conflict then return false, conflict end
    end
    SH.Store:Options().nsrtKeybinds[position] = key
    self:Refresh()
    return true
end

function SH.Keybinds:SetEnabled(enabled)
    if InCombatLockdown() then return false, "Keybinds cannot be changed during combat." end
    SH.Store:Options().nsrtKeybindsEnabled = enabled and true or false
    self:Refresh()
    return true
end

function SH.Keybinds:ClearAll()
    if InCombatLockdown() then return false, "Keybinds cannot be cleared during combat." end
    SH.Store:Options().nsrtKeybinds = {}
    self:Refresh()
    return true
end

function SH.Keybinds:BeginCapture()
    self.capturing = true
    self:Refresh()
end

function SH.Keybinds:EndCapture()
    self.capturing = false
    self:Refresh()
end

function SH.Keybinds:Refresh()
    if not self.owner or self.refreshing then return end
    if InCombatLockdown() then self.pendingRefresh = true; return end
    self.refreshing = true
    -- Only overrides owned by this frame are removed. Normal WoW bindings are never edited.
    ClearOverrideBindings(self.owner)
    self.appliedKeys = {}
    local macros, options = SH.NSRTMacros, SH.Store:Options()
    if options.nsrtKeybindsEnabled and not self.capturing and macros.secureFrame:IsShown() then
        for position = 1, 8 do
            local key = self:Get(position)
            local slot = macros:GetSlotForPosition(position)
            if key and macros.available[slot] and macros.secureFrame.buttons[slot]:IsShown() then
                local conflict = self:GetConflict(key, position)
                if conflict then
                    if self.warnedConflicts[key] ~= conflict then SH:Print(conflict) end
                    self.warnedConflicts[key] = conflict
                else
                    SetOverrideBindingClick(self.owner, false, key, "SszorakHelperNSRTMacroButton" .. slot, "LeftButton")
                    self.appliedKeys[key] = "CLICK SszorakHelperNSRTMacroButton" .. slot .. ":LeftButton"
                    self.warnedConflicts[key] = nil
                end
            end
        end
    end
    self.pendingRefresh, self.refreshing = nil, false
    if SH.OptionsUI and SH.OptionsUI.frame then SH.OptionsUI:RefreshKeybindControls() end
end

function SH.Keybinds:OnInitialize()
    self.owner = CreateFrame("Frame", "SszorakHelperKeybindOwner", UIParent)
    SH:RegisterEvent("UPDATE_BINDINGS", function() SH.Keybinds:Refresh() end)
    SH:RegisterEvent("PLAYER_REGEN_ENABLED", function() SH.Keybinds:Refresh() end)
    SH:RegisterEvent("PLAYER_REGEN_DISABLED", function()
        local ui = SH.OptionsUI
        if ui and ui.frame then
            ui:CancelKeybindCapture()
            ui:RefreshKeybindControls()
        end
    end)
    self:Refresh()
end
