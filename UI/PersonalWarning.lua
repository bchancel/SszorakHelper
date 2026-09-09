local _, SH = ...

SH.PersonalWarning = {initializeOrder = 55}
SH.modules.PersonalWarning = SH.PersonalWarning

function SH.PersonalWarning:OnInitialize()
    local frame = CreateFrame("Frame", "SszorakHelperPersonalWarningFrame", UIParent)
    frame:SetSize(1200, 180)
    frame:SetFrameStrata("HIGH")
    frame:Hide()
    SH.Store:ApplyFrame("personalWarning", frame)
    frame.text = frame:CreateFontString(nil, "OVERLAY")
    frame.text:SetAllPoints()
    frame.text:SetJustifyH("CENTER")
    frame.text:SetJustifyV("MIDDLE")
    frame.text:SetTextColor(1, 0.82, 0, 1)
    frame.text:SetShadowColor(0, 0, 0, 1)
    frame.text:SetShadowOffset(2, -2)
    frame.dragHint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.dragHint:SetPoint("TOP", frame.text, "BOTTOM", 0, -8)
    frame.dragHint:SetText("Drag to move warning")
    frame.dragHint:SetTextColor(0.21, 0.79, 1, 1)
    frame.dragHint:Hide()
    SH.Widgets:MakeMovable(frame, "personalWarning", frame)
    self.frame = frame
    self:ApplyFontSize()
end

function SH.PersonalWarning:ApplyFontSize()
    if not self.frame then return end
    local options = SH.Store:Options()
    local size = tonumber(options.personalWarningFontSize) or 32
    options.personalWarningFontSize = math.max(12, math.min(72, math.floor(size + 0.5)))
    self.frame.text:SetFont(STANDARD_TEXT_FONT, options.personalWarningFontSize, "OUTLINE")
end

function SH.PersonalWarning:Hide()
    if self.timer then self.timer:Cancel(); self.timer = nil end
    if self.frame then self.frame:Hide() end
end

function SH.PersonalWarning:SetUnlocked(unlocked)
    if not self.frame then return end
    self.frame._shUnlocked = unlocked and true or false
    self.frame:EnableMouse(unlocked and true or false)
    self.frame.dragHint:SetShown(unlocked)
end

function SH.PersonalWarning:ShowPreview()
    if not self.frame then return end
    self:Hide()
    self.previewing = true
    self:ApplyFontSize()
    self.frame.text:SetText("Personal warning preview")
    self.frame:Show()
end

function SH.PersonalWarning:RefreshVisibility()
    local encounter = SH.Encounter
    local previewing = SH.Store:Options().previewFrames and not (encounter and (encounter.active or encounter.testMode))
    if previewing then
        if not self.previewing then self:ShowPreview() end
    elseif self.previewing then
        self.previewing = false
        self:Hide()
    end
end

function SH.PersonalWarning:Show(format, ...)
    if self.previewing then return end
    self:Hide()
    self:ApplyFontSize()
    -- Format is public; secret arguments go straight to the rendering API.
    -- Never measure this text or send it through Blizzard's raid-warning frame.
    self.frame.text:SetFormattedText(format, ...)
    self.frame:Show()
    self.timer = C_Timer.NewTimer(4, function() SH.PersonalWarning:Hide() end)
end
