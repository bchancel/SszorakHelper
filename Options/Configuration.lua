local SH = _G.SszorakHelper
if not SH then return end

local UI = {layoutButtons = {}, optionChecks = {}}
SH.OptionsUI = UI

local CELL_LEFT = 4
local CELL_RIGHT = 349
local CELL_WIDTH = 340
local FULL_CELL_WIDTH = CELL_RIGHT + CELL_WIDTH - CELL_LEFT
local OPACITY_VALUES = {0, 0.25, 0.5, 0.75, 1}

local function markerTexture(markerID)
    return string.format("Interface\\TargetingFrame\\UI-RaidTargetingIcon_%d", markerID)
end

local function optionCell(parent, x, y, width)
    local cell = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    cell:SetPoint("TOPLEFT", x, y)
    cell:SetSize(width, 32)
    SH.Widgets:ApplyBackdrop(cell, SH.Widgets.colors.canvasAlt, SH.Widgets.colors.transparent)
    return cell
end

local function cellLabel(cell, text)
    local label = SH.Widgets:Text(cell, text)
    label:SetPoint("LEFT", 12, 0)
    label:SetWidth(145)
    label:SetWordWrap(false)
    return label
end

local function addToggle(parent, label, x, y, getter, setter)
    local cell = optionCell(parent, x, y, CELL_WIDTH)
    cellLabel(cell, label)
    local check = SH.Widgets:Check(cell, "", function(value)
        setter(value)
        SH.Encounter:RefreshDisplays()
    end)
    check:SetPoint("RIGHT", -12, 0)
    check:SetChecked(getter())
    UI.optionChecks[#UI.optionChecks + 1] = {check = check, getter = getter}
    return cell
end

local function makeSection(parent, title, y, height)
    local section = SH.Widgets:Section(parent, title, height)
    section:SetPoint("TOPLEFT", 18, y)
    section:SetPoint("RIGHT", -18, 0)
    return section
end

local function addScaleControl(parent, label, x, y, getter, setter)
    local cell = optionCell(parent, x, y, CELL_WIDTH)
    local text = cellLabel(cell, "")
    local slider = SH.Widgets:Slider(cell, 150, 0.5, 2, 0.05, function(value, userInput)
        value = math.floor((value * 20) + 0.5) / 20
        setter(value)
        text:SetText(string.format("%s: %d%%", label, math.floor((value * 100) + 0.5)))
        if userInput then
            SH.RoomMap:RefreshVisibility()
            SH.OrderFrame:RefreshVisibility()
        end
    end)
    slider:SetPoint("RIGHT", -12, 0)
    UI.scaleControls[#UI.scaleControls + 1] = {slider = slider, text = text, label = label, getter = getter}
    return cell
end

local function addOpacityControl(parent, x, y, options)
    local cell = optionCell(parent, x, y, FULL_CELL_WIDTH)
    cellLabel(cell, "Background Opacity")
    UI.opacityButtons = {}
    for index, value in ipairs(OPACITY_VALUES) do
        local opacity = value
        local button = SH.Widgets:Button(cell, tostring(math.floor(value * 100)) .. "%", 58, 24, function()
            options.frameBackgroundOpacity = opacity
            SH.RoomMap:ApplyBackgroundOpacity()
            SH.OrderFrame:ApplyBackgroundOpacity()
            UI:RefreshOpacityControl()
        end, "secondary")
        button:SetPoint("RIGHT", -12 - ((#OPACITY_VALUES - index) * 62), 0)
        UI.opacityButtons[index] = button
    end
    return cell
end

function UI:Ensure()
    if self.frame then return end

    local frame = CreateFrame("Frame", "SszorakHelperOptionsFrame", UIParent, "BackdropTemplate")
    frame:SetSize(900, 824)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:Hide()
    SH.Widgets:ApplyBackdrop(frame, SH.Widgets.colors.canvas, SH.Widgets.colors.borderStrong)
    SH.Store:ApplyFrame("options", frame)

    local nav = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    nav:SetPoint("TOPLEFT", 1, -1)
    nav:SetPoint("BOTTOMLEFT", 1, 1)
    nav:SetWidth(170)
    SH.Widgets:ApplyBackdrop(nav, SH.Widgets.colors.canvasAlt, SH.Widgets.colors.border)
    local brand = CreateFrame("Frame", nil, nav, "BackdropTemplate")
    brand:SetSize(48, 40)
    brand:SetPoint("TOPLEFT", 18, -18)
    SH.Widgets:ApplyBackdrop(brand, SH.Widgets.colors.accentSoft, SH.Widgets.colors.accent)
    local initials = SH.Widgets:Text(brand, "/SH")
    initials:SetPoint("CENTER")
    initials:SetTextColor(unpack(SH.Widgets.colors.accentBright))
    local name = SH.Widgets:Text(nav, "Sszorak\nHelper", true)
    name:SetPoint("LEFT", brand, "RIGHT", 10, 0)
    name:SetTextColor(unpack(SH.Widgets.colors.accentBright))
    local version = SH.Widgets:Label(nav, "Version " .. SH.version)
    version:SetPoint("TOPLEFT", 18, -82)
    version:SetTextColor(unpack(SH.Widgets.colors.textMuted))

    local test = SH.Widgets:Button(nav, "TEST", 134, 34, function() UI:EnterTestMode() end, "primary")
    test:SetPoint("TOPLEFT", 18, -126)
    test.tooltip = "Show the encounter frames and open the fake-event controls. Turn off Lock Frames to move them."
    local publish = SH.Widgets:Button(nav, "Publish Layout", 134, 32, function() SH.Comms:PublishLayout() end, "success")
    publish:SetPoint("TOPLEFT", 18, -174)
    publish.tooltip = "Raid leader only. Offers this account-wide layout to other Sszorak Helper users."
    local resetLayout = SH.Widgets:Button(nav, "Reset Layout", 134, 30, function()
        SH.Store:ResetDefaultLayout()
        UI.selectedLayoutPosition = nil
        UI:RefreshLayoutEditor()
        SH.LayoutOffer:ApplyLayout()
    end, "secondary")
    resetLayout:SetPoint("TOPLEFT", 18, -218)

    local note = SH.Widgets:Label(nav, "Turn off Lock Frames, then drag the room map or wind order frame to save its position.")
    note:SetPoint("TOPLEFT", 18, -278)
    note:SetWidth(134)
    note:SetWordWrap(true)

    local close = SH.Widgets:Button(nav, "Close", 134, 30, function() frame:Hide() end, "secondary")
    close:SetPoint("BOTTOMLEFT", 18, 18)

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", nav, "TOPRIGHT", 0, 0)
    content:SetPoint("BOTTOMRIGHT")

    local header = SH.Widgets:Text(content, "Configuration", true)
    header:SetPoint("TOPLEFT", 24, -20)
    local hint = SH.Widgets:Label(content, "Account-wide encounter, warning, layout, and frame settings.")
    hint:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -7)
    hint:SetTextColor(unpack(SH.Widgets.colors.textMuted))

    local topClose = SH.Widgets:Button(content, "×", 30, 30, function() frame:Hide() end, "danger")
    topClose:SetPoint("TOPRIGHT", -14, -14)
    topClose.tooltip = "Close configuration"

    local options = SH.Store:Options()
    self.scaleControls = {}
    local frameSection = makeSection(content, "Frame Options", -78, 174)
    addToggle(frameSection, "Preview Frames", CELL_LEFT, -34, function() return options.previewFrames end, function(v) options.previewFrames = v end)
    addToggle(frameSection, "Lock Frames", CELL_RIGHT, -34, function() return options.lockFrames end, function(v) options.lockFrames = v end)
    addToggle(frameSection, "Room Mini Map", CELL_LEFT, -68, function() return options.showRoomMap end, function(v) options.showRoomMap = v end)
    addToggle(frameSection, "Wind Drop Order Frame", CELL_RIGHT, -68, function() return options.showOrderFrame end, function(v) options.showOrderFrame = v end)
    addScaleControl(frameSection, "Map Scale", CELL_LEFT, -102, function() return options.roomMapScale end, function(v)
        options.roomMapScale = v
        SH.RoomMap:ApplyScale()
    end)
    addScaleControl(frameSection, "Order Scale", CELL_RIGHT, -102, function() return options.orderFrameScale end, function(v)
        options.orderFrameScale = v
        SH.OrderFrame:ApplyScale()
    end)
    addOpacityControl(frameSection, CELL_LEFT, -136, options)

    local intermission = makeSection(content, "Intermission Options", -260, 70)
    addToggle(intermission, "Rotate Mini Map", CELL_LEFT, -34, function() return options.rotateMap end, function(v)
        options.rotateMap = v
        if not v then SH.RoomMap:StopRotation() end
    end)
    addToggle(intermission, "Raid Warning Push Directions", CELL_RIGHT, -34, function() return options.raidWarningPushes end, function(v) options.raidWarningPushes = v end)

    local other = makeSection(content, "Other Options", -338, 70)
    addToggle(other, "Raid Warning Drop Locations", CELL_LEFT, -34, function() return options.raidWarningSurges end, function(v) options.raidWarningSurges = v end)
    addToggle(other, "Show Clear Button", CELL_RIGHT, -34, function() return options.showClearButton end, function(v) options.showClearButton = v end)

    local difficulty = makeSection(content, "Enabled Difficulties", -416, 104)
    for index, definition in ipairs(SH.Const.DIFFICULTIES) do
        local difficultyID = definition.id
        local column = (index - 1) % 2
        local row = math.floor((index - 1) / 2)
        addToggle(difficulty, definition.name, column == 0 and CELL_LEFT or CELL_RIGHT, -34 - (row * 34),
            function() return options.difficulties[difficultyID] == true end,
            function(v) options.difficulties[difficultyID] = v end)
    end

    local layoutSection = makeSection(content, "Marker Layout", -528, 280)
    local layoutHint = SH.Widgets:Label(layoutSection, "Click one position, then another, to swap their markers. Exit is always drop 4; exit and entrance never receive wind buttons.")
    layoutHint:SetPoint("TOPLEFT", 10, -38)
    layoutHint:SetWidth(680)
    layoutHint:SetWordWrap(true)

    local centerX, centerY, radius = 350, -163, 84
    for position = 1, 8 do
        local layoutPosition = position
        local angle = (position - 1) * (math.pi * 2 / 8)
        local x = centerX + math.sin(angle) * radius
        local y = centerY + math.cos(angle) * radius
        local button = CreateFrame("Button", nil, layoutSection, "BackdropTemplate")
        button:SetSize(72, 58)
        button:SetPoint("CENTER", layoutSection, "TOPLEFT", x, y)
        SH.Widgets:ApplyBackdrop(button, SH.Widgets.colors.control, SH.Widgets.colors.border)
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetSize(34, 34)
        button.icon:SetPoint("TOP", 0, -3)
        button.label = button:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        button.label:SetPoint("BOTTOM", 0, 3)
        button.label:SetText(SH.Const.DIRECTIONS[position])
        button:SetScript("OnClick", function() UI:SelectLayoutPosition(layoutPosition) end)
        button:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(unpack(SH.Widgets.colors.accentBright))
        end)
        button:SetScript("OnLeave", function(self) UI:StyleLayoutButton(layoutPosition) end)
        self.layoutButtons[position] = button
    end

    frame:SetScript("OnMouseDown", function(self) self:Raise() end)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) if not InCombatLockdown() then self:StartMoving() end end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SH.Store:SaveFrame("options", self)
    end)

    self.frame = frame
    self.publishButton = publish
    self.testButton = test
    self.topCloseButton = topClose
end

function UI:StyleLayoutButton(position)
    local button = self.layoutButtons[position]
    if not button then return end
    local selected = self.selectedLayoutPosition == position
    SH.Widgets:ApplyBackdrop(button, selected and SH.Widgets.colors.accentSoft or SH.Widgets.colors.control,
        selected and SH.Widgets.colors.accentBright or SH.Widgets.colors.border)
end

function UI:RefreshLayoutEditor()
    if not self.frame then return end
    local layout = SH.Store:GetDefaultLayout()
    for position, button in ipairs(self.layoutButtons) do
        button.icon:SetTexture(markerTexture(layout[position]))
        self:StyleLayoutButton(position)
    end
end

function UI:RefreshOpacityControl()
    if not self.opacityButtons then return end
    local selected = tonumber(SH.Store:Options().frameBackgroundOpacity) or 1
    for index, button in ipairs(self.opacityButtons) do
        SH.Widgets:StyleButton(button, math.abs(OPACITY_VALUES[index] - selected) < 0.01 and "primary" or "secondary")
    end
end

function UI:SelectLayoutPosition(position)
    if not self.selectedLayoutPosition then
        self.selectedLayoutPosition = position
    elseif self.selectedLayoutPosition == position then
        self.selectedLayoutPosition = nil
    else
        local layout = SH.Store:GetDefaultLayout()
        local first = self.selectedLayoutPosition
        layout[first], layout[position] = layout[position], layout[first]
        self.selectedLayoutPosition = nil
        SH.LayoutOffer:ApplyLayout()
    end
    self:RefreshLayoutEditor()
end

function UI:Refresh()
    for _, entry in ipairs(self.optionChecks) do entry.check:SetChecked(entry.getter()) end
    for _, entry in ipairs(self.scaleControls) do
        local value = tonumber(entry.getter()) or 1
        entry.slider._shUpdating = true
        entry.slider:SetValue(value)
        entry.slider._shUpdating = false
        entry.text:SetText(string.format("%s: %d%%", entry.label, math.floor((value * 100) + 0.5)))
    end
    self:RefreshOpacityControl()
    self:RefreshLayoutEditor()
    local canPublish = IsInRaid() and UnitIsGroupLeader("player")
    self.publishButton._shEnabledStyle = "success"
    SH.Widgets:SetEnabled(self.publishButton, canPublish)
end

function UI:Show()
    self:Ensure()
    self:Refresh()
    self.frame:Show()
    self.frame:Raise()
end

function UI:EnsureTestFrame()
    if self.testFrame then return end
    local frame = CreateFrame("Frame", "SszorakHelperTestFrame", UIParent, "BackdropTemplate")
    frame:SetSize(220, 270)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetClampedToScreen(true)
    frame:Hide()
    SH.Widgets:ApplyBackdrop(frame, SH.Widgets.colors.canvasAlt, SH.Widgets.colors.borderStrong)
    SH.Store:ApplyFrame("test", frame)
    local title = SH.Widgets:Text(frame, "Test Frame", true)
    title:SetPoint("TOPLEFT", 16, -14)
    local hint = SH.Widgets:Label(frame, "Fake events stay local.")
    hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    hint:SetTextColor(unpack(SH.Widgets.colors.textMuted))

    local definitions = {
        {"Surge 1", function() SH.Encounter:WarnSurge(1, true) end, "primary"},
        {"Surge 2", function() SH.Encounter:WarnSurge(2, true) end, "primary"},
        {"Intermission", function() SH.Encounter:TestIntermission() end, "pink"},
        {"Reset", function() SH.Encounter:ClearAssignments("test") end, "danger"},
        {"Quit Test Mode", function() UI:QuitTestMode() end, "success"},
    }
    for index, definition in ipairs(definitions) do
        local button = SH.Widgets:Button(frame, definition[1], 188, 30, definition[2], definition[3])
        button:SetPoint("TOPLEFT", 16, -66 - ((index - 1) * 38))
    end
    frame._shUnlocked = true
    SH.Widgets:MakeMovable(frame, "test", frame)
    self.testFrame = frame
end

function UI:EnterTestMode()
    self:EnsureTestFrame()
    if SH.Encounter:EnterTestMode() then self.testFrame:Show() end
end

function UI:QuitTestMode()
    SH.Encounter:QuitTestMode()
    if self.testFrame then self.testFrame:Hide() end
end

function UI:ToggleTestMode()
    if SH.Encounter.testMode then
        self:QuitTestMode()
    else
        self:EnterTestMode()
    end
end
