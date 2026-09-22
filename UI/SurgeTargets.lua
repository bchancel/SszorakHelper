local _, SH = ...

SH.SurgeTargets = {initializeOrder = 36}
SH.modules.SurgeTargets = SH.SurgeTargets

local DURATION = 10
local CAPTURE_WINDOW = 5
local WIDTH, HEIGHT = 300, 98

local function readable(value)
    return not issecretvalue or not issecretvalue(value)
end

function SH.SurgeTargets:OnInitialize()
    local frame = CreateFrame("Frame", "SszorakHelperSurgeTargets", UIParent, "BackdropTemplate")
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetFrameStrata("HIGH")
    frame:Hide()
    SH.Widgets:ApplyBackdrop(frame, SH.Widgets.colors.canvas, SH.Widgets.colors.borderStrong)
    SH.Store:ApplyFrame("surgeTargets", frame)
    frame.title = SH.Widgets:Label(frame, "SURGE TARGETS")
    frame.title:SetPoint("TOPLEFT", 10, -7)
    frame.title:SetTextColor(unpack(SH.Widgets.colors.navigation))
    frame.rows = {}
    for index = 1, 2 do
        local row = CreateFrame("StatusBar", nil, frame)
        row:SetSize(WIDTH - 62, 28)
        row:SetPoint("TOPLEFT", 48, -28 - (index - 1) * 32)
        row:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        row:SetStatusBarColor(0.15, 0.55, 0.36, 0.9)
        row:SetMinMaxValues(0, DURATION)
        row.name = SH.Widgets:Text(row, "")
        row.name:SetPoint("LEFT", 6, 0)
        row.name:SetWidth(WIDTH - 120)
        row.name:SetWordWrap(false)
        row.name:SetJustifyH("LEFT")
        row.time = SH.Widgets:Text(row, "")
        row.time:SetPoint("RIGHT", -6, 0)
        row.marker = SH.Widgets:Text(row, "")
        row.marker:SetPoint("RIGHT", row, "LEFT", -5, 0)
        row:Hide()
        frame.rows[index] = row
    end
    SH.Widgets:MakeMovable(frame, "surgeTargets", frame)
    self.frame = frame
    -- Only listen to this unit during a bounded cast window, never scan raid auras.
    self.events = CreateFrame("Frame")
    self.events:SetScript("OnEvent", function(_, event, unit)
        if event == "UNIT_TARGET" and unit == "boss1" then self:CaptureTarget() end
    end)
    self:ApplyBackgroundOpacity()
end

function SH.SurgeTargets:ApplyBackgroundOpacity()
    local opacity = math.max(0, math.min(1, tonumber(SH.Store:Options().frameBackgroundOpacity) or 0.5))
    self.frame:SetBackdropColor(0.035, 0.064, 0.084, opacity)
end

function SH.SurgeTargets:CloseWindow()
    self.events:UnregisterEvent("UNIT_TARGET")
    if self.windowTimer then self.windowTimer:Cancel(); self.windowTimer = nil end
    self.capturing = false
end

function SH.SurgeTargets:ClearRows()
    self.frame:SetScript("OnUpdate", nil)
    self.preview = false
    for _, row in ipairs(self.frame.rows) do row.expires = nil; row:Hide() end
    self.frame:Hide()
end

function SH.SurgeTargets:Reset()
    self:CloseWindow()
    self:ClearRows()
end

function SH.SurgeTargets:BeginCast(index)
    self:Reset()
    if not SH.Encounter.active or not SH.Store:Options().showSurgeTargets then return end
    self.firstDrop = (index - 1) * 2 + 1
    self.captures = 0
    self.capturing = true
    self.events:RegisterUnitEvent("UNIT_TARGET", "boss1")
    self.windowTimer = C_Timer.NewTimer(CAPTURE_WINDOW, function() self:CloseWindow() end)
end

function SH.SurgeTargets:GetMarker(position)
    if position == 4 then return SH.Store:GetLayout()[SH.Const.EXIT_POSITION], true end
    local drops = SH.Encounter:ComputeDropOrder()
    if drops then return drops[position], true end
    if SH.Store:Options().receiveNSRT and (SH.Comms.receivedCount or 0) > 0 then
        if position <= SH.Comms.receivedCount then return SH.Comms.receivedMarkers[position], true end
        return nil, false
    end
    return nil, false
end

function SH.SurgeTargets:SetRow(index, name, position, duration, preview)
    local row = self.frame.rows[index]
    -- Names and received markers may be secret. Pass them directly to display APIs.
    row.name:SetText(name)
    local marker, hasMarker = self:GetMarker(position)
    if preview and not hasMarker then
        local layout = SH.Store:GetLayout()
        marker = ({layout[2], layout[3], layout[6], layout[1]})[position]
        hasMarker = true
    end
    if hasMarker then
        row.marker:SetFormattedText("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%s:28:28|t", marker)
    else
        row.marker:SetText("?")
    end
    row.expires = GetTime() + duration
    row:SetValue(duration)
    row.time:SetFormattedText("%.1f", duration)
    row:Show()
    self.frame:Show()
end

function SH.SurgeTargets:StartCountdown()
    self.elapsed = 0
    self.frame:SetScript("OnUpdate", function(_, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed < 0.05 then return end
        self.elapsed = 0
        local visible = false
        local now = GetTime()
        for _, row in ipairs(self.frame.rows) do
            if row.expires then
                local remaining = math.max(0, row.expires - now)
                row:SetValue(remaining)
                row.time:SetFormattedText("%.1f", remaining)
                if remaining > 0 then visible = true else row.expires = nil; row:Hide() end
            end
        end
        if not visible then self.frame:SetScript("OnUpdate", nil); self.frame:Hide() end
    end)
end

function SH.SurgeTargets:CaptureTarget()
    if not self.capturing or not SH.Encounter.active or not SH.Store:Options().showSurgeTargets then return end
    local exists = UnitExists("boss1target")
    if not readable(exists) or not exists then return end
    self.captures = self.captures + 1
    self:SetRow(self.captures, UnitName("boss1target"), self.firstDrop + self.captures - 1, DURATION, false)
    self:StartCountdown()
    if self.captures == 2 then self:CloseWindow() end
end

function SH.SurgeTargets:ShowPreview(index, animate)
    if SH.Encounter.active then return end
    self:Reset()
    if not SH.Store:Options().showSurgeTargets then return end
    self.preview = true
    local first = ((index or 1) - 1) * 2 + 1
    self:SetRow(1, "Surge target 1", first, 9, true)
    self:SetRow(2, "Surge target 2", first + 1, 7.5, true)
    if animate then self:StartCountdown() end
end

function SH.SurgeTargets:RefreshVisibility()
    local options = SH.Store:Options()
    local preview = not SH.Encounter.active and (options.previewFrames or SH.Encounter.testMode)
    self.frame._shUnlocked = not options.lockFrames
    self.frame:SetBackdropBorderColor(unpack(self.frame._shUnlocked and SH.Widgets.colors.accentBright or SH.Widgets.colors.borderStrong))
    if not options.showSurgeTargets then
        self:Reset()
    elseif preview then
        self:ShowPreview()
    elseif self.preview or not SH.Encounter.active then
        self:Reset()
    end
end
