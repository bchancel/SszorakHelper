local _, SH = ...

SH.NSRTMacros = {
    initializeOrder = 35,
    markerIDs = {},
    available = {},
    expected = nil,
    nextStep = 1,
}
SH.modules.NSRTMacros = SH.NSRTMacros

local PANEL_WIDTH = 348
local PANEL_HEIGHT = 132
local SLOT_WIDTH = 48
local SLOT_HEIGHT = 58
local SLOT_GAP = 8
local SLOT_START_X = 10
local MACRO_ICONS = {"137001", "137002", "137003", "137004", "137005", "137006", "137007", "137008"}
local MACRO_POSITIONS = {2, 3, 4, 6, 7, 8}

local function macroName(markerID)
    return "NSRT_SSZORAK_" .. tostring(markerID)
end

local function markerTexture(markerID)
    return string.format("Interface\\TargetingFrame\\UI-RaidTargetingIcon_%d", markerID)
end

local function sameOrder(first, second)
    if first == nil or second == nil then return first == second end
    for index = 1, 3 do
        if tonumber(first[index]) ~= tonumber(second[index]) then return false end
    end
    return true
end

function SH.NSRTMacros:IsSupportedInstance()
    local instanceID = select(8, GetInstanceInfo())
    return tonumber(instanceID) == SH.Const.INSTANCE_ID
end

function SH.NSRTMacros:ShouldShow()
    if self.panelHidden then return false end
    local options = SH.Store:Options()
    local encounter = SH.Encounter
    return options.showNSRTMacros and ((encounter and encounter.testMode) or options.previewFrames
        or (options.nsrtPanelOpen and self:IsSupportedInstance()))
end

function SH.NSRTMacros:TogglePanel()
    self:SetPanelOpen(not self:ShouldShow())
end

function SH.NSRTMacros:SetPanelOpen(open)
    local options = SH.Store:Options()
    options.nsrtPanelOpen = open and true or false
    self.panelHidden = not options.nsrtPanelOpen
    if options.nsrtPanelOpen then options.showNSRTMacros = true end
    self:RefreshVisibility()
    SH:Print(options.nsrtPanelOpen and "Macro panel enabled for this raid. Show it before pulling Sszorak."
        or "Macro panel hidden. Right-click the minimap button or use /sh macros to reopen it.")
    if InCombatLockdown() then SH:Print("Panel visibility will change after combat ends.") end
end

function SH.NSRTMacros:CreateOrRepairMacros()
    if InCombatLockdown() then
        SH:Print("NSRT macros cannot be created or repaired during combat.")
        return false
    end
    if type(CreateMacro) ~= "function" or type(EditMacro) ~= "function" then
        SH:Print("The WoW macro API is unavailable.")
        return false
    end

    local created, repaired, failed = 0, 0, 0
    for markerID = 1, 8 do
        local name = macroName(markerID)
        local body = "/raid " .. tostring(markerID)
        if GetMacroInfo(name) then
            local ok, macroIndex = pcall(EditMacro, name, name, MACRO_ICONS[markerID], body)
            if ok and macroIndex then repaired = repaired + 1 else failed = failed + 1 end
        else
            local ok, macroIndex = pcall(CreateMacro, name, MACRO_ICONS[markerID], body)
            if ok and macroIndex then created = created + 1 else failed = failed + 1 end
        end
    end

    self:RefreshLayout()
    self:RefreshHighlights()
    if failed > 0 then
        SH:Print(string.format("NSRT macros: %d created, %d repaired, %d failed. Check available account macro slots.", created, repaired, failed))
        return false
    end
    SH:Print(string.format("All 8 NSRT Sszorak macros are ready (%d created, %d repaired).", created, repaired))
    return true
end

function SH.NSRTMacros:OnInitialize()
    local secure = CreateFrame("Frame", "SszorakHelperNSRTSecureFrame", UIParent, "SecureHandlerBaseTemplate")
    secure:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    secure:SetFrameStrata("HIGH")
    secure:SetFrameLevel(100)
    secure:SetClampedToScreen(true)
    secure:Hide()

    local frame = CreateFrame("Frame", "SszorakHelperNSRTMacroFrame", UIParent, "BackdropTemplate")
    frame:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(40)
    frame:SetClampedToScreen(true)
    frame:Hide()
    SH.Widgets:ApplyBackdrop(frame, SH.Widgets.colors.canvas, SH.Widgets.colors.borderStrong)
    frame:SetPoint("TOP", SH.RoomMap.frame, "BOTTOM", 0, 0)

    frame.title = SH.Widgets:Label(frame, "NSRT MACROS")
    frame.title:SetPoint("TOPLEFT", 10, -7)
    frame.title:SetTextColor(unpack(SH.Widgets.colors.navigation))
    frame.status = SH.Widgets:Label(frame, "Complete wind assignments first")
    frame.status:SetPoint("TOPLEFT", 10, -32)
    frame.status:SetWidth(PANEL_WIDTH - 20)
    frame.status:SetJustifyH("CENTER")
    frame.status:SetWordWrap(false)
    frame.status:SetTextColor(unpack(SH.Widgets.colors.textMuted))

    frame.slots = {}
    secure.buttons = {}
    local hide = SH.Widgets:Button(frame, "Hide", 54, 22, function()
        SH.NSRTMacros:SetPanelOpen(false)
    end, "secondary")
    hide:SetPoint("TOPRIGHT", -10, -3)
    hide.tooltip = "Hide this macro panel. Reopen with /sh macros or right-click the minimap button. During combat, hiding waits until combat ends."

    for slotIndex = 1, #MACRO_POSITIONS do
        local index = slotIndex
        local x = SLOT_START_X + ((slotIndex - 1) * (SLOT_WIDTH + SLOT_GAP))
        local slot = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        slot:SetSize(SLOT_WIDTH, SLOT_HEIGHT)
        slot:SetPoint("BOTTOMLEFT", x, 8)
        SH.Widgets:ApplyBackdrop(slot, SH.Widgets.colors.control, SH.Widgets.colors.border)
        slot.icon = slot:CreateTexture(nil, "ARTWORK")
        slot.icon:SetSize(34, 34)
        slot.icon:SetPoint("CENTER", 0, -3)
        slot.badge = CreateFrame("Frame", nil, slot, "BackdropTemplate")
        slot.badge:SetSize(20, 20)
        slot.badge:SetPoint("TOPRIGHT", 5, 5)
        SH.Widgets:ApplyBackdrop(slot.badge, SH.Widgets.colors.pink, SH.Widgets.colors.pinkBorder)
        slot.badge.text = SH.Widgets:Text(slot.badge, "")
        slot.badge.text:SetPoint("CENTER")
        slot.badge:Hide()

        slot.blocker = CreateFrame("Frame", nil, frame)
        slot.blocker:SetSize(SLOT_WIDTH, SLOT_HEIGHT)
        slot.blocker:SetPoint("BOTTOMLEFT", x, 8)
        slot.blocker:SetFrameLevel(120)
        slot.blocker:EnableMouse(true)
        slot.blocker:SetScript("OnEnter", function()
            GameTooltip:SetOwner(slot.blocker, "ANCHOR_RIGHT")
            GameTooltip:SetText("Create or repair the NSRT macros in Configuration before combat.")
            GameTooltip:Show()
        end)
        slot.blocker:SetScript("OnLeave", function() GameTooltip:Hide() end)
        frame.slots[slotIndex] = slot

        local button = CreateFrame("Button", "SszorakHelperNSRTMacroButton" .. slotIndex, secure, "SecureActionButtonTemplate")
        button:SetSize(SLOT_WIDTH, SLOT_HEIGHT)
        button:SetPoint("BOTTOMLEFT", x, 8)
        button:RegisterForClicks("LeftButtonUp")
        button:SetAttribute("useOnKeyDown", false)
        button:SetScript("PostClick", function(_, mouseButton, down)
            if mouseButton == "LeftButton" and not down then SH.NSRTMacros:OnMacroClicked(index) end
        end)
        button:SetScript("OnEnter", function()
            local markerID = SH.NSRTMacros.markerIDs[index]
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetText(markerID and ("Run " .. macroName(markerID)) or "NSRT macro")
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        secure.buttons[slotIndex] = button
    end

    self.secureFrame = secure
    self.frame = frame
    self:ApplyScale()
    self:ApplySecurePosition()
    self:ApplyBackgroundOpacity()
    self:RefreshLayout()
    self:RefreshHighlights()
    self:RefreshVisibility()

    SH:RegisterEvent("PLAYER_ENTERING_WORLD", function() SH.NSRTMacros:RefreshVisibility() end)
    SH:RegisterEvent("ZONE_CHANGED_NEW_AREA", function() SH.NSRTMacros:RefreshVisibility() end)
    SH:RegisterEvent("UPDATE_MACROS", function() SH.NSRTMacros:RefreshLayout() end)
    SH:RegisterEvent("GROUP_ROSTER_UPDATE", function()
        SH.NSRTMacros:RefreshLayout()
        SH.NSRTMacros:RefreshVisibility()
    end)
    SH:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        SH.NSRTMacros:RefreshLayout()
        SH.NSRTMacros:ApplySecurePosition()
        SH.NSRTMacros:ApplyScale()
        SH.NSRTMacros:RefreshVisibility()
    end)
end

function SH.NSRTMacros:ApplySecurePosition()
    if not self.frame or not self.secureFrame or InCombatLockdown() then return end
    local centerX, centerY = self.frame:GetCenter()
    if not centerX or not centerY then return end
    local frameScale = self.frame:GetEffectiveScale()
    local uiScale = UIParent:GetEffectiveScale()
    centerX = centerX * frameScale / uiScale
    centerY = centerY * frameScale / uiScale
    self.secureFrame:ClearAllPoints()
    self.secureFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", centerX, centerY)
end

function SH.NSRTMacros:ApplyScale()
    if not self.frame then return end
    local scale = SH.Store:Options().roomMapScale or 1
    if InCombatLockdown() then
        self.pendingSecureRefresh = true
        return
    end
    self.frame:SetScale(scale)
    self.secureFrame:SetScale(1)
    self.secureFrame:SetSize(PANEL_WIDTH * scale, PANEL_HEIGHT * scale)
    for slotIndex, button in ipairs(self.secureFrame.buttons) do
        local x = SLOT_START_X + ((slotIndex - 1) * (SLOT_WIDTH + SLOT_GAP))
        button:ClearAllPoints()
        button:SetSize(SLOT_WIDTH * scale, SLOT_HEIGHT * scale)
        button:SetPoint("BOTTOMLEFT", x * scale, 8 * scale)
    end
    self:ApplySecurePosition()
end

function SH.NSRTMacros:ApplyBackgroundOpacity()
    if not self.frame then return end
    local opacity = math.max(0, math.min(1, tonumber(SH.Store:Options().frameBackgroundOpacity) or 1))
    self.frame:SetBackdropColor(0.035, 0.064, 0.084, opacity)
end

function SH.NSRTMacros:SetUnlocked(unlocked)
    if not self.frame then return end
    self.frame._shUnlocked = unlocked and true or false
    self.frame:SetBackdropBorderColor(unpack(unlocked and SH.Widgets.colors.accentBright or SH.Widgets.colors.borderStrong))
end

function SH.NSRTMacros:RefreshLayout()
    if not self.frame then return end
    if InCombatLockdown() then
        self.pendingSecureRefresh = true
        return
    end
    local layout = SH.Store:GetLayout()
    local simulate = SH.Encounter and SH.Encounter.testMode and not IsInRaid()
    self.simulateClicks = simulate
    for slotIndex, position in ipairs(MACRO_POSITIONS) do
        local markerID = tonumber(layout[position])
        local name = markerID and macroName(markerID)
        local macroBody
        if name then macroBody = select(3, GetMacroInfo(name)) end
        local found = type(macroBody) == "string" and strtrim(macroBody) == ("/raid " .. tostring(markerID))
        self.markerIDs[slotIndex] = markerID
        self.available[slotIndex] = found or simulate
        self.frame.slots[slotIndex].icon:SetTexture(markerTexture(markerID or 8))
        self.frame.slots[slotIndex].icon:SetAlpha(self.available[slotIndex] and 1 or 0.3)
        local button = self.secureFrame.buttons[slotIndex]
        button:SetAttribute("type", found and not simulate and "macro" or nil)
        button:SetAttribute("macro", found and not simulate and name or nil)
    end
    self.pendingSecureRefresh = nil
    self:RefreshHighlights()
end

function SH.NSRTMacros:SetOrder(markers)
    local nextOrder = markers and {tonumber(markers[1]), tonumber(markers[2]), tonumber(markers[3])} or nil
    if not sameOrder(self.expected, nextOrder) then
        self.expected = nextOrder
        self.nextStep = 1
    end
    self:RefreshHighlights()
end

function SH.NSRTMacros:OnMacroClicked(slotIndex)
    if not self.available[slotIndex] then return end
    -- In a raid, only the actual chat event supplies the received message.
    -- Without raid recipients, exercise that same receiver locally.
    if self.simulateClicks and SH.Encounter.testMode and not IsInRaid() then
        SH.Comms:OnRaidMessage(tostring(self.markerIDs[slotIndex]))
    end
    if not self.available[slotIndex] or not self.expected or self.nextStep > 3 then return end
    if self.markerIDs[slotIndex] ~= self.expected[self.nextStep] then return end
    self.nextStep = self.nextStep + 1
    self:RefreshHighlights()
end

function SH.NSRTMacros:RefreshHighlights()
    if not self.frame then return end
    local orderByMarker = {}
    for order = 1, 3 do
        local markerID = self.expected and self.expected[order]
        if markerID then orderByMarker[markerID] = order end
    end

    local nextAvailable = false
    for slotIndex, slot in ipairs(self.frame.slots) do
        local order = orderByMarker[self.markerIDs[slotIndex]]
        if order then
            slot.badge.text:SetText(tostring(order))
            slot.badge:Show()
        else
            slot.badge:Hide()
        end
        local isNext = order == self.nextStep and self.available[slotIndex]
        local completed = order and order < self.nextStep
        SH.Widgets:ApplyBackdrop(slot,
            isNext and SH.Widgets.colors.pink or (completed and SH.Widgets.colors.success or SH.Widgets.colors.control),
            isNext and SH.Widgets.colors.pinkBorder or (completed and SH.Widgets.colors.successBorder or SH.Widgets.colors.border))
        -- Suggestions are visual only. Keep working macros clickable for retries.
        slot.blocker:SetShown(not self.available[slotIndex])
        if isNext then nextAvailable = true end
    end

    if not self.expected then
        self.frame.status:SetText("Click a marker, or select winds")
        self.frame.status:SetTextColor(unpack(SH.Widgets.colors.textMuted))
    elseif self.nextStep > 3 then
        self.frame.status:SetText("Clicked 1-3 (delivery unconfirmed)")
        self.frame.status:SetTextColor(unpack(SH.Widgets.colors.navigation))
    elseif nextAvailable then
        self.frame.status:SetText("Press macro " .. tostring(self.nextStep))
        self.frame.status:SetTextColor(unpack(SH.Widgets.colors.textSecondary))
    else
        self.frame.status:SetText("Required macro missing or changed")
        self.frame.status:SetTextColor(unpack(SH.Widgets.colors.dangerBorder))
    end
end

function SH.NSRTMacros:RefreshVisibility()
    if not self.frame then return end
    if not self:IsSupportedInstance() then SH.Store:Options().nsrtPanelOpen = false end
    local shouldShow = self:ShouldShow()
    if InCombatLockdown() then
        self.frame:SetShown(self.secureFrame:IsShown())
        return
    end
    self.frame:SetShown(shouldShow)
    self.secureFrame:SetShown(shouldShow)
    if shouldShow then
        self:ApplySecurePosition()
        self:RefreshLayout()
    end
end
