local _, SH = ...

SH.LayoutOffer = {initializeOrder = 40}
SH.modules.LayoutOffer = SH.LayoutOffer

function SH.LayoutOffer:OnInitialize()
    local shade = CreateFrame("Frame", "SszorakHelperLayoutShade", UIParent, "BackdropTemplate")
    shade:SetAllPoints(UIParent)
    shade:SetFrameStrata("FULLSCREEN_DIALOG")
    shade:SetFrameLevel(2000)
    shade:EnableMouse(true)
    shade:Hide()
    SH.Widgets:ApplyBackdrop(shade, SH.Widgets.colors.overlay, SH.Widgets.colors.transparent)

    local frame = CreateFrame("Frame", nil, shade, "BackdropTemplate")
    frame:SetSize(490, 190)
    frame:SetPoint("CENTER")
    SH.Widgets:ApplyBackdrop(frame, SH.Widgets.colors.canvasAlt, SH.Widgets.colors.borderStrong)
    frame.title = SH.Widgets:Text(frame, "New marker layout", true)
    frame.title:SetPoint("TOPLEFT", 22, -20)
    frame.message = SH.Widgets:Text(frame, "")
    frame.message:SetPoint("TOPLEFT", 22, -58)
    frame.message:SetWidth(446)
    frame.message:SetWordWrap(true)

    local reject = SH.Widgets:Button(frame, "Reject", 130, 32, function() shade:Hide() end, "danger")
    reject:SetPoint("BOTTOMLEFT", 22, 20)
    local temporary = SH.Widgets:Button(frame, "Temporary", 130, 32, function()
        local offer = SH.LayoutOffer.pending
        if offer and SH.Store:SetTemporaryLayout(offer.layout, offer.sender) then
            SH.LayoutOffer:ApplyLayout()
        end
        shade:Hide()
    end, "pink")
    temporary:SetPoint("LEFT", reject, "RIGHT", 18, 0)
    local makeDefault = SH.Widgets:Button(frame, "Make Default", 150, 32, function()
        local offer = SH.LayoutOffer.pending
        if offer and SH.Store:SetDefaultLayout(offer.layout) then
            SH.LayoutOffer:ApplyLayout()
        end
        shade:Hide()
    end, "success")
    makeDefault:SetPoint("LEFT", temporary, "RIGHT", 18, 0)

    self.shade = shade
    self.frame = frame
end

function SH.LayoutOffer:Show(sender, layout)
    self.pending = {sender = sender, layout = layout}
    self.frame.message:SetText(string.format("%s wants to push a new marker layout. Reject it, use it for this raid group, or save it as your account-wide default.", sender or "The raid leader"))
    self.shade:Show()
end

function SH.LayoutOffer:ApplyLayout()
    if SH.RoomMap then SH.RoomMap:RefreshLayout() end
    if SH.Encounter then SH.Encounter:RefreshDisplays() end
    if SH.OptionsUI and SH.OptionsUI.frame and SH.OptionsUI.frame:IsShown() then SH.OptionsUI:RefreshLayoutEditor() end
end
