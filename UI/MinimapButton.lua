local _, SH = ...

SH.MinimapButton = {initializeOrder = 15}
SH.modules.MinimapButton = SH.MinimapButton

local ICON_TEXTURE = 7966619
local BUTTON_RADIUS = 80

function SH.MinimapButton:UpdatePosition()
    if not self.button or not Minimap then return end
    local angle = math.rad(tonumber(SH.Store:Options().minimapAngle) or 220)
    self.button:ClearAllPoints()
    self.button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * BUTTON_RADIUS, math.sin(angle) * BUTTON_RADIUS)
end

function SH.MinimapButton:UpdateDragPosition()
    local cursorX, cursorY = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    local centerX, centerY = Minimap:GetCenter()
    if not cursorX or not cursorY or not centerX or not centerY or not scale or scale == 0 then return end
    cursorX, cursorY = cursorX / scale, cursorY / scale
    SH.Store:Options().minimapAngle = math.deg(math.atan2(cursorY - centerY, cursorX - centerX))
    self:UpdatePosition()
end

function SH.MinimapButton:OnInitialize()
    if not Minimap then return end

    local button = CreateFrame("Button", "SszorakHelperMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(24, 24)
    background:SetPoint("CENTER")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ICON_TEXTURE)
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT")

    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:SetScript("OnClick", function()
        if SH.OptionsLoader then SH.OptionsLoader:Open() end
    end)
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function() SH.MinimapButton:UpdateDragPosition() end)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Sszorak Helper", 0.21, 0.79, 1)
        GameTooltip:AddLine("Left-click: Open configuration", 1, 1, 1)
        GameTooltip:AddLine("Drag: Move button", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    self.button = button
    self:UpdatePosition()
end
