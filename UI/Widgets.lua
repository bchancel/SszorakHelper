local _, SH = ...

SH.Widgets = {}

local WHITE = "Interface\\Buttons\\WHITE8x8"
local colors = {
    transparent = {0, 0, 0, 0},
    overlay = {0, 0, 0, 0.60},
    canvas = {0.035, 0.064, 0.084, 0.99},
    canvasAlt = {0.047, 0.086, 0.112, 0.99},
    control = {0.018, 0.038, 0.054, 1},
    surface = {0.064, 0.116, 0.150, 0.98},
    hover = {0.070, 0.190, 0.245, 1},
    pressed = {0.035, 0.230, 0.340, 1},
    accentSoft = {0.025, 0.210, 0.315, 0.96},
    accent = {0.035, 0.610, 0.875, 1},
    accentBright = {0.210, 0.790, 1, 1},
    border = {0.140, 0.240, 0.300, 1},
    borderStrong = {0.120, 0.360, 0.460, 1},
    text = {0.925, 0.955, 0.975, 1},
    textSecondary = {0.725, 0.790, 0.835, 1},
    textMuted = {0.500, 0.590, 0.660, 1},
    navigation = {0.340, 0.860, 0.560, 1},
    success = {0.025, 0.360, 0.310, 1},
    successBorder = {0.070, 0.760, 0.640, 1},
    danger = {0.310, 0.055, 0.070, 0.92},
    dangerBorder = {0.760, 0.180, 0.200, 1},
    pink = {0.38, 0.10, 0.28, 0.96},
    pinkBorder = {0.95, 0.35, 0.72, 1},
}
SH.Widgets.colors = colors

local backdrop = {bgFile = WHITE, edgeFile = WHITE, edgeSize = 1}

function SH.Widgets:ApplyBackdrop(frame, color, borderColor)
    frame:SetBackdrop(backdrop)
    frame:SetBackdropColor(unpack(color or colors.surface))
    frame:SetBackdropBorderColor(unpack(borderColor or colors.border))
end

function SH.Widgets:Text(parent, text, large)
    local font = parent:CreateFontString(nil, "OVERLAY", large and "GameFontHighlightLarge" or "GameFontHighlight")
    font:SetText(text or "")
    font:SetTextColor(unpack(colors.text))
    font:SetJustifyH("LEFT")
    return font
end

function SH.Widgets:Label(parent, text)
    local font = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    font:SetText(text or "")
    font:SetTextColor(unpack(colors.textSecondary))
    font:SetJustifyH("LEFT")
    return font
end

local styles = {
    secondary = {colors.surface, colors.border, colors.textSecondary},
    primary = {colors.accentSoft, colors.accent, colors.text},
    success = {colors.success, colors.successBorder, colors.text},
    danger = {colors.danger, colors.dangerBorder, colors.text},
    pink = {colors.pink, colors.pinkBorder, colors.text},
    disabled = {colors.control, colors.border, colors.textMuted},
}

function SH.Widgets:StyleButton(button, style)
    local definition = styles[style or "secondary"] or styles.secondary
    button._shStyle = style or "secondary"
    self:ApplyBackdrop(button, definition[1], definition[2])
    if button.text then button.text:SetTextColor(unpack(definition[3])) end
end

function SH.Widgets:Button(parent, text, width, height, onClick, style)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width or 120, height or 28)
    button.text = self:Text(button, text or "")
    button.text:SetPoint("CENTER")
    button:SetScript("OnClick", function(self)
        if self:IsEnabled() and onClick then onClick(self) end
    end)
    button:SetScript("OnEnter", function(self)
        if self:IsEnabled() then
            SH.Widgets:ApplyBackdrop(self, colors.hover, colors.accentBright)
        end
        if self.tooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.tooltip)
            GameTooltip:Show()
        end
    end)
    button:SetScript("OnLeave", function(self)
        SH.Widgets:StyleButton(self, self:IsEnabled() and self._shStyle or "disabled")
        GameTooltip:Hide()
    end)
    self:StyleButton(button, style)
    return button
end

function SH.Widgets:SetEnabled(button, enabled)
    button:SetEnabled(enabled and true or false)
    self:StyleButton(button, enabled and (button._shEnabledStyle or button._shStyle) or "disabled")
end

function SH.Widgets:Check(parent, text, onChanged)
    local check = CreateFrame("CheckButton", nil, parent, "BackdropTemplate")
    check:SetSize(42, 22)
    check.knob = check:CreateTexture(nil, "OVERLAY")
    check.knob:SetTexture(WHITE)
    check.knob:SetSize(14, 14)
    check.label = self:Text(check, text or "")
    check.label:SetPoint("LEFT", check, "RIGHT", 8, 0)
    local original = check.SetChecked
    local function refresh(self)
        local checked = self:GetChecked() and true or false
        SH.Widgets:ApplyBackdrop(self, checked and colors.success or colors.danger, checked and colors.successBorder or colors.dangerBorder)
        self.knob:ClearAllPoints()
        self.knob:SetPoint("CENTER", self, "CENTER", checked and 10 or -10, 0)
    end
    check.SetChecked = function(self, value) original(self, value); refresh(self) end
    check:SetScript("OnClick", function(self)
        refresh(self)
        if onChanged then onChanged(self:GetChecked() and true or false) end
    end)
    check:SetScript("OnShow", refresh)
    refresh(check)
    return check
end

function SH.Widgets:Slider(parent, width, minimum, maximum, step, onChanged)
    local slider = CreateFrame("Slider", nil, parent, "BackdropTemplate")
    slider:SetSize(width or 150, 18)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(minimum or 0, maximum or 1)
    slider:SetValueStep(step or 0.1)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    self:ApplyBackdrop(slider, colors.control, colors.border)
    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture(WHITE)
    thumb:SetSize(9, 22)
    thumb:SetVertexColor(unpack(colors.accentBright))
    slider:SetThumbTexture(thumb)
    slider:SetScript("OnValueChanged", function(_, value, userInput)
        if onChanged and not slider._shUpdating then onChanged(value, userInput) end
    end)
    slider:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(unpack(colors.accentBright)) end)
    slider:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(colors.border)) end)
    return slider
end

function SH.Widgets:Section(parent, title, height)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetHeight(height or 80)
    self:ApplyBackdrop(frame, colors.transparent, colors.transparent)
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.title:SetText(string.upper(title or ""))
    frame.title:SetTextColor(unpack(colors.navigation))
    frame.title:SetPoint("TOPLEFT", 4, -8)
    frame.line = frame:CreateTexture(nil, "ARTWORK")
    frame.line:SetTexture(WHITE)
    frame.line:SetHeight(1)
    frame.line:SetPoint("TOPLEFT", 4, -28)
    frame.line:SetPoint("TOPRIGHT", -4, -28)
    frame.line:SetVertexColor(unpack(colors.border))
    return frame
end

function SH.Widgets:MakeMovable(frame, stateKey, handle)
    local dragHandle = handle or frame
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    dragHandle:EnableMouse(true)
    dragHandle:RegisterForDrag("LeftButton")
    dragHandle:SetScript("OnDragStart", function()
        if frame._shUnlocked and not InCombatLockdown() then frame:StartMoving() end
    end)
    dragHandle:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SH.Store:SaveFrame(stateKey, frame)
        if stateKey == "roomMap" and SH.NSRTMacros then SH.NSRTMacros:ApplySecurePosition() end
    end)
end
