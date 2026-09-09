local _, SH = ...

SH.OrderFrame = {initializeOrder = 20}
SH.modules.OrderFrame = SH.OrderFrame

function SH.OrderFrame:OnInitialize()
    local frame = CreateFrame("Frame", "SszorakHelperOrderFrame", UIParent, "BackdropTemplate")
    frame:SetSize(266, 88)
    frame:SetScale(SH.Store:Options().orderFrameScale or 1)
    frame:SetFrameStrata("MEDIUM")
    frame:Hide()
    SH.Widgets:ApplyBackdrop(frame, SH.Widgets.colors.canvas, SH.Widgets.colors.borderStrong)
    SH.Store:ApplyFrame("order", frame)

    frame.title = SH.Widgets:Label(frame, "WIND DROP ORDER")
    frame.title:SetPoint("TOP", 0, -7)
    frame.title:SetTextColor(unpack(SH.Widgets.colors.navigation))

    frame.slots = {}
    for index = 1, 4 do
        local slot = CreateFrame("Frame", nil, frame)
        slot:SetSize(54, 54)
        slot:SetPoint("BOTTOMLEFT", 13 + ((index - 1) * 62), 5)
        slot.number = SH.Widgets:Text(slot, tostring(index))
        slot.number:SetPoint("TOP", 0, 1)
        slot.icon = slot:CreateTexture(nil, "ARTWORK")
        slot.icon:SetSize(36, 36)
        slot.icon:SetPoint("BOTTOM")
        slot.received = slot:CreateFontString(nil, "ARTWORK")
        slot.received:SetFont(STANDARD_TEXT_FONT, 16)
        slot.received:SetPoint("BOTTOM")
        slot.received:Hide()
        frame.slots[index] = slot
    end

    SH.Widgets:MakeMovable(frame, "order", frame)
    self.frame = frame
    self:ApplyBackgroundOpacity()
end

function SH.OrderFrame:ApplyScale()
    self.frame:SetScale(SH.Store:Options().orderFrameScale or 1)
end

function SH.OrderFrame:ApplyBackgroundOpacity()
    local opacity = math.max(0, math.min(1, tonumber(SH.Store:Options().frameBackgroundOpacity) or 1))
    self.frame:SetBackdropColor(0.035, 0.064, 0.084, opacity)
end

function SH.OrderFrame:SetUnlocked(unlocked)
    self.frame._shUnlocked = unlocked and true or false
    self.frame.title:SetText("WIND DROP ORDER")
    self.frame:SetBackdropBorderColor(unpack(unlocked and SH.Widgets.colors.accentBright or SH.Widgets.colors.borderStrong))
end

function SH.OrderFrame:Update(markers)
    self.markers = markers
    self.receivedCount = nil
    for index, slot in ipairs(self.frame.slots) do
        slot.received:Hide()
        local markerID = markers and tonumber(markers[index])
        if markerID then
            slot.icon:SetTexture(string.format("Interface\\TargetingFrame\\UI-RaidTargetingIcon_%d", markerID))
            slot.icon:Show()
        else
            slot.icon:Hide()
        end
    end
    self:RefreshVisibility()
end

function SH.OrderFrame:ShowReceived(markers, count)
    self.markers = nil
    self.receivedCount = count
    for index, slot in ipairs(self.frame.slots) do
        slot.icon:Hide()
        slot.received:Hide()
        if index <= count then
            slot.received:SetFormattedText("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%s:36:36|t", markers[index])
            slot.received:Show()
        elseif index == 4 then
            slot.icon:SetTexture(string.format("Interface\\TargetingFrame\\UI-RaidTargetingIcon_%d", SH.Store:GetLayout()[SH.Const.EXIT_POSITION]))
            slot.icon:Show()
        end
    end
    self:RefreshVisibility()
end

function SH.OrderFrame:RefreshVisibility()
    local options = SH.Store:Options()
    local context = (SH.Encounter and SH.Encounter.active) or (SH.Encounter and SH.Encounter.testMode) or options.previewFrames
    self.frame:SetShown(context and options.showOrderFrame and (self.markers ~= nil or self.receivedCount ~= nil))
end

function SH.OrderFrame:ShowPreview(markers)
    self:Update(markers or {4, 5, 1, 7})
end

function SH.OrderFrame:HidePreview()
    self.markers = nil
    self:RefreshVisibility()
end
