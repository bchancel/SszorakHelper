local SH = _G.SszorakHelper
if not SH then return end

local UI = {layoutButtons = {}, optionChecks = {}, profileButtons = {}}
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
    local text = cellLabel(cell, label)
    cell.label = text
    text:SetWidth(CELL_WIDTH - 82)
    local check = SH.Widgets:Check(cell, "", function(value)
        setter(value)
        SH.Encounter:RefreshDisplays()
    end)
    check:SetPoint("RIGHT", -12, 0)
    check:SetChecked(getter())
    cell.check = check
    UI.optionChecks[#UI.optionChecks + 1] = {check = check, getter = getter}
    return cell
end

local function toggleTooltip(cell, title, text)
    cell.tooltipTitle, cell.tooltip = title, text
    cell.check.tooltipTitle, cell.check.tooltip = title, text
    cell:EnableMouse(true)
    for _, target in ipairs({cell, cell.check}) do
        target:SetScript("OnEnter", function(owner)
            SH.Widgets:ShowTooltip(owner, cell.tooltip, cell.tooltipTitle)
        end)
        target:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
end

local function makeSection(parent, title, y, height)
    local section = SH.Widgets:Section(parent, title, height)
    section:SetPoint("TOPLEFT", 18, y)
    section:SetPoint("TOPRIGHT", -18, y)
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
            SH.NSRTMacros:RefreshVisibility()
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
            SH.NSRTMacros:ApplyBackgroundOpacity()
            SH.SurgeTargets:ApplyBackgroundOpacity()
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
    frame:SetSize(930, 800)
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

    local configuration = SH.Widgets:Button(nav, "Configuration", 134, 32, function() UI:SelectPage("configuration") end, "primary")
    configuration:SetPoint("TOPLEFT", 18, -126)
    local markerLayout = SH.Widgets:Button(nav, "Marker Layout", 134, 32, function() UI:SelectPage("layout") end, "secondary")
    markerLayout:SetPoint("TOPLEFT", 18, -166)
    local test = SH.Widgets:Button(nav, "TEST", 134, 34, function() UI:EnterTestMode() end, "primary")
    test:SetPoint("TOPLEFT", 18, -210)
    test.tooltipTitle = "Test encounter"
    test.tooltip = "Show encounter frames and fake-event controls.\n\nTurn off Lock Frames to move the frames."

    local close = SH.Widgets:Button(nav, "Close", 134, 30, function() frame:Hide() end, "secondary")
    close:SetPoint("BOTTOMLEFT", 18, 18)

    local header = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    header:SetPoint("TOPLEFT", nav, "TOPRIGHT", 0, 0)
    header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(56)
    SH.Widgets:ApplyBackdrop(header, SH.Widgets.colors.canvas, SH.Widgets.colors.transparent)
    header.title = SH.Widgets:Text(header, "Configuration", true)
    header.title:SetPoint("TOPLEFT", 24, -20)

    local topClose = SH.Widgets:Button(header, "×", 30, 30, function() frame:Hide() end, "danger")
    topClose:SetPoint("TOPRIGHT", -14, -14)
    topClose.tooltip = "Close configuration"

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", -28, 16)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(730, 704)
    scroll:SetScrollChild(content)

    local options = SH.Store:Options()
    self.scaleControls = {}
    local frameSection = makeSection(content, "Frame Options", -6, 208)
    addToggle(frameSection, "Preview Frames", CELL_LEFT, -34, function() return options.previewFrames end, function(v) options.previewFrames = v end)
    addToggle(frameSection, "Lock Frames", CELL_RIGHT, -34, function() return options.lockFrames end, function(v) options.lockFrames = v end)
    addToggle(frameSection, "Room Mini Map", CELL_LEFT, -68, function() return options.showRoomMap end, function(v) options.showRoomMap = v end)
    addToggle(frameSection, "Wind Drop Order Frame", CELL_RIGHT, -68, function() return options.showOrderFrame end, function(v) options.showOrderFrame = v end)
    addToggle(frameSection, "Surge Targets", CELL_LEFT, -102, function() return options.showSurgeTargets end, function(v) options.showSurgeTargets = v end)
    addToggle(frameSection, "Show Clear Button", CELL_RIGHT, -102, function() return options.showClearButton end, function(v) options.showClearButton = v end)
    addScaleControl(frameSection, "Map Scale", CELL_LEFT, -136, function() return options.roomMapScale end, function(v)
        options.roomMapScale = v
        SH.RoomMap:ApplyScale()
        SH.NSRTMacros:ApplyScale()
    end)
    addScaleControl(frameSection, "Order Scale", CELL_RIGHT, -136, function() return options.orderFrameScale end, function(v)
        options.orderFrameScale = v
        SH.OrderFrame:ApplyScale()
    end)
    addOpacityControl(frameSection, CELL_LEFT, -170, options)

    local macros = makeSection(content, "NSRT Macro Buttons", -222, 140)
    local macroEnable = addToggle(macros, "NSRT Macro Buttons", CELL_LEFT, -34, function() return options.showNSRTMacros end, function(v)
        options.showNSRTMacros = v
        UI.createMacrosButton:SetShown(v)
        if v then SH.NSRTMacros.inRoom = nil end
        SH.NSRTMacros:OnZoneChanged()
    end)
    macroEnable.label:SetWidth(CELL_WIDTH - 152)
    local entranceExit = addToggle(macros, "Show Entrance / Exit", CELL_RIGHT, -34,
        function() return options.nsrtShowEntranceExit end,
        function(v)
            options.nsrtShowEntranceExit = v
            SH.NSRTMacros:ApplyScale()
            SH.NSRTMacros:RefreshLayout()
        end)
    self.showEntranceExitToggle = entranceExit.check
    toggleTooltip(entranceExit, "Show Entrance / Exit",
        "Add the room's Exit and Entrance markers to the macro panel.\n\nSingle row: Exit, then Entrance at the right.\nDouble row: Exit at the top right, Entrance at the bottom right.\nChanges during combat apply after combat ends.")
    addToggle(macros, "Attach to Map", CELL_LEFT, -68, function() return options.nsrtAttachToMap end, function(v)
        options.nsrtAttachToMap = v
        SH.NSRTMacros:ApplyAttachment()
    end)
    addToggle(macros, "Auto Show / Hide by Room", CELL_RIGHT, -68, function() return options.nsrtAutoShow end, function(v)
        options.nsrtAutoShow = v
        SH.NSRTMacros.inRoom = nil
        SH.NSRTMacros.lastSubzone = nil
        SH.NSRTMacros:OnZoneChanged()
    end)
    addToggle(macros, "Double Row", CELL_LEFT, -102, function() return options.nsrtDoubleRow end, function(v)
        options.nsrtDoubleRow = v
        SH.NSRTMacros:ApplyScale()
    end)
    local createMacros = SH.Widgets:Button(macroEnable, "Create", 64, 24, function()
        SH.NSRTMacros:CreateOrRepairMacros()
        UI.oppositeMacrosToggle:SetChecked(options.nsrtOppositeMacros)
    end, "primary")
    createMacros:SetPoint("RIGHT", macroEnable.check, "LEFT", -8, 0)
    createMacros:SetShown(options.showNSRTMacros)
    createMacros.tooltipTitle = "Create macros"
    createMacros.tooltip = "Create or repair all eight NSRT macros.\nReset each icon to send its own marker.\n\nOverwrites NSRT_SSZORAK_1 through NSRT_SSZORAK_8.\nOut of combat only."
    self.createMacrosButton = createMacros
    local oppositeMacros = addToggle(macros, "Opposite macros", CELL_RIGHT, -102,
        function() return options.nsrtOppositeMacros end,
        function(value)
            SH.NSRTMacros:CreateOrRepairMacros(value)
            UI.oppositeMacrosToggle:SetChecked(options.nsrtOppositeMacros)
        end)
    toggleTooltip(oppositeMacros, "Opposite macros",
        "On: Send the opposite marker in the current layout.\nExample: Circle sends Square in Default.\n\nOff: Reset macros so each icon sends itself.\nChanges repair the eight NSRT macros. Out of combat only.")
    self.oppositeMacrosToggle = oppositeMacros.check

    local intermission = makeSection(content, "Intermission Options", -370, 70)
    addToggle(intermission, "Show Push Direction Warning", CELL_LEFT, -34, function() return options.raidWarningPushes end, function(v) options.raidWarningPushes = v end)

    local other = makeSection(content, "Personal Warnings / NSRT", -448, 138)
    addToggle(other, "Show Drop Location Warning", CELL_LEFT, -34, function() return options.raidWarningSurges end, function(v) options.raidWarningSurges = v end)
    addToggle(other, "TTS Warnings", CELL_RIGHT, -34, function() return options.ttsWarnings end, function(v) options.ttsWarnings = v end)
    local fontCell = optionCell(other, CELL_LEFT, -68, CELL_WIDTH)
    self.warningFontLabel = cellLabel(fontCell, "")
    self.warningFontSlider = SH.Widgets:Slider(fontCell, 150, 12, 72, 1, function(value, userInput)
        options.personalWarningFontSize = math.floor(value + 0.5)
        SH.PersonalWarning:ApplyFontSize()
        UI.warningFontLabel:SetText(string.format("Warning Font: %d px", options.personalWarningFontSize))
        if userInput then SH.PersonalWarning:Show("%s", "Personal warning preview") end
    end)
    self.warningFontSlider:SetPoint("RIGHT", -12, 0)
    addToggle(other, "Receive NSRT Raid Messages", CELL_RIGHT, -68, function() return options.receiveNSRT end, function(v)
        options.receiveNSRT = v
        SH.Comms.receivedCount = 0
        SH.Comms.receivedMarkers = {}
    end)
    local delayCell = optionCell(other, CELL_LEFT, -102, FULL_CELL_WIDTH)
    self.warningDelayLabel = cellLabel(delayCell, "")
    self.warningDelayLabel:SetWidth(330)
    self.warningDelaySlider = SH.Widgets:Slider(delayCell, 280, 1, 10, 0.5, function(value, userInput)
        options.personalWarningDelay = math.floor(value * 2 + 0.5) / 2
        UI.warningDelayLabel:SetText(string.format("Personal Warning Delay: %g s", options.personalWarningDelay))
        if userInput then SH.PersonalWarning:Show("%s", "Personal warning preview") end
    end)
    self.warningDelaySlider:SetPoint("RIGHT", -12, 0)
    local difficulty = makeSection(content, "Enabled Difficulties", -594, 104)
    self.difficultyGearButtons = {}
    for index, definition in ipairs(SH.Const.DIFFICULTIES) do
        local difficultyID = definition.id
        local column = (index - 1) % 2
        local row = math.floor((index - 1) / 2)
        local cell = addToggle(difficulty, definition.name, column == 0 and CELL_LEFT or CELL_RIGHT, -34 - (row * 34),
            function() return options.difficulties[difficultyID] == true end,
            function(v) options.difficulties[difficultyID] = v end)
        cell.label:SetWidth(CELL_WIDTH - 112)
        local gear = SH.Widgets:Button(cell, "", 26, 26, function() UI:ShowTimingDialog(difficultyID) end, "secondary")
        gear:SetPoint("RIGHT", -62, 0)
        gear.icon = gear:CreateTexture(nil, "ARTWORK")
        gear.icon:SetSize(20, 20)
        gear.icon:SetPoint("CENTER")
        gear.icon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
        gear.tooltip = "Adjust " .. definition.name .. " surge, intermission, and wind timings."
        self.difficultyGearButtons[difficultyID] = gear
    end

    local layoutPage = CreateFrame("Frame", nil, frame)
    layoutPage:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    layoutPage:SetPoint("BOTTOMRIGHT", -28, 16)
    layoutPage:Hide()

    local profileTitle = SH.Widgets:Label(layoutPage, "Layout profile")
    profileTitle:SetPoint("TOPLEFT", 18, -10)
    local selector = SH.Widgets:Button(layoutPage, "", 500, 30, function() UI:ToggleProfileMenu() end, "secondary")
    selector:SetPoint("TOPLEFT", 18, -31)
    selector.text:ClearAllPoints()
    selector.text:SetPoint("LEFT", 12, 0)
    selector.text:SetWidth(450)
    selector.text:SetJustifyH("LEFT")
    selector.text:SetWordWrap(false)
    local arrowLeft = selector:CreateLine(nil, "OVERLAY")
    arrowLeft:SetThickness(2)
    arrowLeft:SetColorTexture(unpack(SH.Widgets.colors.textSecondary))
    arrowLeft:SetStartPoint("RIGHT", selector, "RIGHT", -20, 3)
    arrowLeft:SetEndPoint("RIGHT", selector, "RIGHT", -15, -2)
    local arrowRight = selector:CreateLine(nil, "OVERLAY")
    arrowRight:SetThickness(2)
    arrowRight:SetColorTexture(unpack(SH.Widgets.colors.textSecondary))
    arrowRight:SetStartPoint("RIGHT", selector, "RIGHT", -15, -2)
    arrowRight:SetEndPoint("RIGHT", selector, "RIGHT", -10, 3)

    local newProfile = SH.Widgets:Button(layoutPage, "New", 54, 30, function() UI:PromptNewProfile() end, "success")
    newProfile:SetPoint("LEFT", selector, "RIGHT", 8, 0)
    newProfile.tooltip = "Create a named copy of the currently displayed layout."
    local renameProfile = SH.Widgets:Button(layoutPage, "Rename", 66, 30, function() UI:PromptRenameProfile() end, "secondary")
    renameProfile:SetPoint("LEFT", newProfile, "RIGHT", 4, 0)
    renameProfile._shEnabledStyle = "secondary"
    local deleteProfile = SH.Widgets:Button(layoutPage, "Delete", 58, 30, function() UI:PromptDeleteProfile() end, "danger")
    deleteProfile:SetPoint("LEFT", renameProfile, "RIGHT", 4, 0)
    deleteProfile._shEnabledStyle = "danger"

    local menuDismiss = CreateFrame("Frame", nil, frame)
    menuDismiss:SetAllPoints(frame)
    menuDismiss:SetFrameLevel(frame:GetFrameLevel() + 20)
    menuDismiss:EnableMouse(true)
    menuDismiss:Hide()
    menuDismiss:SetScript("OnMouseDown", function(self) self:Hide() end)
    local menu = CreateFrame("Frame", nil, menuDismiss, "BackdropTemplate")
    menu:SetPoint("TOPLEFT", selector, "BOTTOMLEFT", 0, -4)
    menu:SetSize(500, 42)
    menu:EnableMouse(true)
    SH.Widgets:ApplyBackdrop(menu, SH.Widgets.colors.canvasAlt, SH.Widgets.colors.borderStrong)

    local temporary = SH.Widgets:Button(menu, "Temporary Raid Layout", 488, 28, function() menuDismiss:Hide() end, "pink")
    temporary:SetPoint("TOPLEFT", 6, -6)
    temporary:Hide()
    temporary.tooltip = "The raid leader's temporary layout is active. Press New to save a permanent copy."
    self.temporaryProfileButton = temporary

    for index = 1, SH.Store:GetProfileLimit() do
        local profileIndex = index
        local button = SH.Widgets:Button(menu, "", 488, 28, function() UI:SelectProfile(profileIndex) end, "secondary")
        button.text:ClearAllPoints()
        button.text:SetPoint("LEFT", 10, 0)
        button.text:SetWidth(468)
        button.text:SetJustifyH("LEFT")
        button.text:SetWordWrap(false)
        self.profileButtons[index] = button
    end

    local layoutSection = makeSection(layoutPage, "Marker Layout", -80, 594)
    SH.Widgets:ApplyBackdrop(layoutSection, SH.Widgets.colors.canvasAlt, SH.Widgets.colors.border)
    local layoutHint = SH.Widgets:Label(layoutSection, "Click two positions to swap their markers.")
    layoutHint:SetPoint("TOPLEFT", 10, -38)
    layoutHint:SetWidth(450)
    layoutHint:SetWordWrap(true)

    local roomWidth, roomHeight = 550, 550 * 1380 / 1456
    local room = CreateFrame("Frame", nil, layoutSection)
    room:SetSize(roomWidth, roomHeight)
    room:SetPoint("TOP", layoutSection, "TOP", 0, -60)
    room.texture = room:CreateTexture(nil, "BACKGROUND")
    room.texture:SetAllPoints(room)
    room.texture:SetTexture("Interface\\AddOns\\SszorakHelper_Options\\Media\\MarkerLayoutRoom.tga")
    -- The original screenshot occupies this region of a power-of-two texture.
    room.texture:SetTexCoord(0, 1456 / 2048, 0, 1380 / 2048)
    local positions = {
        {0.5, 0.125}, {0.7, 0.3}, {0.79, 0.505}, {0.71, 0.72},
        {0.5, 0.87}, {0.305, 0.715}, {0.235, 0.51}, {0.31, 0.3},
    }
    for position = 1, 8 do
        local layoutPosition = position
        local point = positions[position]
        local button = CreateFrame("Button", nil, room, "BackdropTemplate")
        button:SetSize(56, 56)
        button:SetPoint("CENTER", room, "TOPLEFT", point[1] * roomWidth, -point[2] * roomHeight)
        SH.Widgets:ApplyBackdrop(button, SH.Widgets.colors.transparent, SH.Widgets.colors.transparent)
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetSize(40, 40)
        button.icon:SetPoint("CENTER")
        button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        button.label:SetPoint("TOP", button, "BOTTOM", 0, -1)
        button.label:SetShadowColor(0, 0, 0, 1)
        button.label:SetShadowOffset(1, -1)
        if position == SH.Const.EXIT_POSITION then
            button.label:SetText("Exit")
        elseif position == SH.Const.ENTRANCE_POSITION then
            button.label:SetText("Entrance")
        else
            button.label:SetText("")
        end
        button:SetScript("OnClick", function() UI:SelectLayoutPosition(layoutPosition) end)
        button:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(unpack(SH.Widgets.colors.accentBright))
        end)
        button:SetScript("OnLeave", function(self) UI:StyleLayoutButton(layoutPosition) end)
        self.layoutButtons[position] = button
    end

    local resetLayout = SH.Widgets:Button(layoutPage, "Reset Layout", 122, 32, function()
        if not SH.Store:ResetCurrentLayout() then
            SH:Print("The Default layout already uses Sszorak Helper's original markers.")
            return
        end
        UI.selectedLayoutPosition = nil
        SH.LayoutOffer:ApplyLayout()
    end, "secondary")
    resetLayout:SetPoint("TOPRIGHT", layoutSection, "BOTTOMRIGHT", -4, -16)
    resetLayout.tooltip = "Restore the currently selected layout to Sszorak Helper's original marker arrangement."
    resetLayout._shEnabledStyle = "secondary"
    local publish = SH.Widgets:Button(layoutPage, "Publish Layout", 140, 32, function() SH.Comms:PublishLayout() end, "success")
    publish:SetPoint("RIGHT", resetLayout, "LEFT", -8, 0)
    publish.tooltip = "Raid leader only. Offers the currently selected layout to other Sszorak Helper users."

    self.newProfileButton = newProfile
    self.renameProfileButton = renameProfile
    self.deleteProfileButton = deleteProfile

    frame:SetScript("OnMouseDown", function(self) self:Raise() end)
    frame:SetScript("OnHide", function() menuDismiss:Hide() end)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) if not InCombatLockdown() then self:StartMoving() end end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SH.Store:SaveFrame("options", self)
    end)

    self.frame = frame
    self.header, self.scroll, self.content = header, scroll, content
    self.page = "configuration"
    self.layoutPage, self.layoutSection = layoutPage, layoutSection
    self.layoutRoom = room
    self.configurationButton, self.markerLayoutButton = configuration, markerLayout
    self.profileSelector, self.profileMenu, self.profileMenuDismiss = selector, menu, menuDismiss
    self.publishButton = publish
    self.resetLayoutButton = resetLayout
    self.testButton = test
    self.topCloseButton = topClose
end

function UI:SelectPage(page)
    self:Ensure()
    self.page = page == "layout" and "layout" or "configuration"
    self.profileMenuDismiss:Hide()
    self.selectedLayoutPosition = nil
    local layout = self.page == "layout"
    self.scroll:SetShown(not layout)
    self.layoutPage:SetShown(layout)
    self.header.title:SetText(layout and "Marker Layout" or "Configuration")
    SH.Widgets:StyleButton(self.configurationButton, layout and "secondary" or "primary")
    SH.Widgets:StyleButton(self.markerLayoutButton, layout and "primary" or "secondary")
    self:Refresh()
end

function UI:ToggleProfileMenu()
    local open = not self.profileMenuDismiss:IsShown()
    self:RefreshProfiles()
    self.profileMenuDismiss:SetShown(open)
end

function UI:EnsureTimingDialog()
    if self.timingDialog then return end
    local shade = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    shade:SetAllPoints(self.frame)
    shade:SetFrameLevel(self.frame:GetFrameLevel() + 50)
    shade:EnableMouse(true)
    shade:Hide()
    SH.Widgets:ApplyBackdrop(shade, SH.Widgets.colors.overlay, SH.Widgets.colors.transparent)

    local panel = CreateFrame("Frame", nil, shade, "BackdropTemplate")
    panel:SetSize(660, 610)
    panel:SetPoint("CENTER")
    SH.Widgets:ApplyBackdrop(panel, SH.Widgets.colors.canvasAlt, SH.Widgets.colors.borderStrong)
    panel.title = SH.Widgets:Text(panel, "Encounter timings", true)
    panel.title:SetPoint("TOPLEFT", 20, -18)
    local hint = SH.Widgets:Label(panel, "Event times from the pull. Enter minutes:seconds or seconds. Surge warnings appear 3 seconds before the listed cast. Save applies next pull.")
    hint:SetPoint("TOPLEFT", 20, -50)
    hint:SetWidth(620)
    hint:SetWordWrap(true)
    panel.source = SH.Widgets:Label(panel, "")
    panel.source:SetPoint("TOPLEFT", 20, -103)
    panel.source:SetWidth(620)
    panel.source:SetWordWrap(true)
    local eventHeading = SH.Widgets:Text(panel, "EVENT")
    eventHeading:SetPoint("TOPLEFT", 26, -144)
    local timeHeading = SH.Widgets:Text(panel, "TIME FROM PULL")
    timeHeading:SetPoint("TOPRIGHT", -58, -144)

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 20, -169)
    scroll:SetPoint("BOTTOMRIGHT", -44, 108)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(594, 1)
    scroll:SetScrollChild(content)
    panel.scroll, panel.content = scroll, content
    panel.rows, panel.edits = {}, {}
    panel.empty = SH.Widgets:Label(content, "No stored events for this difficulty.")
    panel.empty:SetPoint("TOPLEFT", 6, -12)
    panel.empty:SetWidth(570)
    panel.empty:SetWordWrap(true)
    panel.empty:Hide()
    panel.error = SH.Widgets:Label(panel, "")
    panel.error:SetPoint("BOTTOMLEFT", 20, 62)
    panel.error:SetWidth(620)
    panel.error:SetWordWrap(true)
    panel.error:SetTextColor(unpack(SH.Widgets.colors.dangerBorder))
    local reset = SH.Widgets:Button(panel, "Reset Defaults", 132, 30, function()
        UI:FillTimingDialog(SH.Store:GetTimings(shade.difficultyID, true))
    end, "secondary")
    reset:SetPoint("BOTTOMLEFT", 20, 20)
    local cancel = SH.Widgets:Button(panel, "Cancel", 100, 30, function() shade:Hide() end, "secondary")
    cancel:SetPoint("BOTTOMRIGHT", -132, 20)
    local save = SH.Widgets:Button(panel, "Save", 100, 30, function() UI:SubmitTimings() end, "success")
    save:SetPoint("BOTTOMRIGHT", -20, 20)
    panel.save = save
    shade.panel = panel
    self.timingDialog = shade
end

function UI:FillTimingDialog(events)
    local dialog = self.timingDialog
    local panel = dialog.panel
    panel.events, panel.edits = events, {}
    for _, row in ipairs(panel.rows) do row:Hide() end
    for index, event in ipairs(events) do
        local row = panel.rows[index]
        if not row then
            row = optionCell(panel.content, 0, -(index - 1) * 36, 590)
            row.label = cellLabel(row, "")
            row.label:SetWidth(380)
            row.edit = CreateFrame("EditBox", nil, row, "BackdropTemplate")
            row.edit:SetSize(142, 28)
            row.edit:SetPoint("RIGHT", -6, 0)
            row.edit:SetFontObject(ChatFontNormal)
            row.edit:SetTextInsets(9, 9, 0, 0)
            row.edit:SetMaxLetters(10)
            row.edit:SetAutoFocus(false)
            row.edit:SetScript("OnEscapePressed", function() dialog:Hide() end)
            row.edit:SetScript("OnEnterPressed", function() UI:SubmitTimings() end)
            local rowIndex = index
            row.edit:SetScript("OnTabPressed", function()
                local nextIndex = rowIndex % #panel.events + 1
                local nextEdit = panel.rows[nextIndex].edit
                panel.scroll:SetVerticalScroll(math.max(0, (nextIndex - 2) * 36))
                nextEdit:SetFocus()
                nextEdit:HighlightText()
            end)
            SH.Widgets:ApplyBackdrop(row.edit, SH.Widgets.colors.control, SH.Widgets.colors.border)
            panel.rows[index] = row
        end
        row.label:SetText(event.label)
        row.edit:SetText(SH.Const:FormatFightTime(event.time))
        panel.edits[event.id] = row.edit
        row:Show()
    end
    panel.content:SetHeight(math.max(100, #events * 36))
    panel.scroll:SetVerticalScroll(0)
    panel.empty:SetShown(#events == 0)
    SH.Widgets:SetEnabled(panel.save, #events > 0)
    panel.error:SetText("")
end

function UI:ShowTimingDialog(difficultyID)
    self:EnsureTimingDialog()
    local dialog = self.timingDialog
    dialog.difficultyID = difficultyID
    for _, definition in ipairs(SH.Const.DIFFICULTIES) do
        if definition.id == difficultyID then dialog.panel.title:SetText(definition.name .. " Fight Schedule") end
    end
    dialog.panel.source:SetText(difficultyID == 17
        and "Raid Finder defaults to Normal's schedule. Saved adjustments apply only to Raid Finder."
        or "Default cast times: NSRT. Wind prompts and intermission end times use this addon's existing timing defaults.")
    self:FillTimingDialog(SH.Store:GetTimings(difficultyID))
    dialog:Show()
end

function UI:SubmitTimings()
    local dialog = self.timingDialog
    local values = {}
    for _, event in ipairs(dialog.panel.events) do
        values[event.id] = dialog.panel.edits[event.id]:GetText()
    end
    local ok, reason = SH.Store:SaveTimings(dialog.difficultyID, values)
    if not ok then dialog.panel.error:SetText(reason); return end
    dialog:Hide()
end

function UI:EnsureNameDialog()
    if self.nameDialog then return end
    local shade = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    shade:SetAllPoints(self.frame)
    shade:SetFrameLevel(self.frame:GetFrameLevel() + 50)
    shade:EnableMouse(true)
    shade:Hide()
    SH.Widgets:ApplyBackdrop(shade, SH.Widgets.colors.overlay, SH.Widgets.colors.transparent)

    local panel = CreateFrame("Frame", nil, shade, "BackdropTemplate")
    panel:SetSize(390, 184)
    panel:SetPoint("CENTER")
    SH.Widgets:ApplyBackdrop(panel, SH.Widgets.colors.canvasAlt, SH.Widgets.colors.borderStrong)
    panel.title = SH.Widgets:Text(panel, "Layout profile", true)
    panel.title:SetPoint("TOPLEFT", 20, -18)
    panel.hint = SH.Widgets:Label(panel, "Profile name")
    panel.hint:SetPoint("TOPLEFT", 20, -55)

    panel.edit = CreateFrame("EditBox", nil, panel, "BackdropTemplate")
    panel.edit:SetSize(350, 32)
    panel.edit:SetPoint("TOPLEFT", 20, -76)
    panel.edit:SetFontObject(ChatFontNormal)
    panel.edit:SetTextInsets(9, 9, 0, 0)
    panel.edit:SetMaxLetters(20)
    panel.edit:SetAutoFocus(false)
    SH.Widgets:ApplyBackdrop(panel.edit, SH.Widgets.colors.control, SH.Widgets.colors.border)

    panel.error = SH.Widgets:Label(panel, "")
    panel.error:SetPoint("TOPLEFT", 20, -112)
    panel.error:SetTextColor(unpack(SH.Widgets.colors.dangerBorder))

    local cancel = SH.Widgets:Button(panel, "Cancel", 100, 30, function() shade:Hide() end, "secondary")
    cancel:SetPoint("BOTTOMLEFT", 20, 16)
    local accept = SH.Widgets:Button(panel, "Save", 100, 30, function() UI:SubmitProfileName() end, "success")
    accept:SetPoint("BOTTOMRIGHT", -20, 16)
    panel.edit:SetScript("OnEnterPressed", function() UI:SubmitProfileName() end)
    panel.edit:SetScript("OnEscapePressed", function() shade:Hide() end)

    shade.panel = panel
    self.nameDialog = shade
end

function UI:ShowProfileNameDialog(title, initialValue, callback)
    self:EnsureNameDialog()
    local panel = self.nameDialog.panel
    panel.title:SetText(title)
    panel.error:SetText("")
    panel.edit:SetText(initialValue or "")
    self.nameDialog.callback = callback
    self.nameDialog:Show()
    panel.edit:SetFocus()
    panel.edit:HighlightText()
end

function UI:SubmitProfileName()
    local dialog = self.nameDialog
    if not dialog or not dialog.callback then return end
    local ok, reason = dialog.callback(dialog.panel.edit:GetText())
    if not ok then
        dialog.panel.error:SetText(reason or "Could not save that profile name.")
        return
    end
    dialog:Hide()
    self.selectedLayoutPosition = nil
    SH.LayoutOffer:ApplyLayout()
end

function UI:EnsureDeleteDialog()
    if self.deleteDialog then return end
    local shade = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    shade:SetAllPoints(self.frame)
    shade:SetFrameLevel(self.frame:GetFrameLevel() + 50)
    shade:EnableMouse(true)
    shade:Hide()
    SH.Widgets:ApplyBackdrop(shade, SH.Widgets.colors.overlay, SH.Widgets.colors.transparent)

    local panel = CreateFrame("Frame", nil, shade, "BackdropTemplate")
    panel:SetSize(390, 148)
    panel:SetPoint("CENTER")
    SH.Widgets:ApplyBackdrop(panel, SH.Widgets.colors.canvasAlt, SH.Widgets.colors.borderStrong)
    panel.title = SH.Widgets:Text(panel, "Delete layout profile?", true)
    panel.title:SetPoint("TOPLEFT", 20, -18)
    panel.message = SH.Widgets:Label(panel, "")
    panel.message:SetPoint("TOPLEFT", 20, -54)
    panel.message:SetWidth(350)

    local cancel = SH.Widgets:Button(panel, "Cancel", 100, 30, function() shade:Hide() end, "secondary")
    cancel:SetPoint("BOTTOMLEFT", 20, 16)
    local remove = SH.Widgets:Button(panel, "Delete", 100, 30, function()
        local profileID = shade.profileID
        local ok, reason = SH.Store:DeleteProfile(profileID)
        if not ok then SH:Print(reason or "Could not delete that profile.") end
        shade:Hide()
        UI.selectedLayoutPosition = nil
        SH.LayoutOffer:ApplyLayout()
    end, "danger")
    remove:SetPoint("BOTTOMRIGHT", -20, 16)

    shade.panel = panel
    self.deleteDialog = shade
end

function UI:PromptNewProfile()
    if #SH.Store:GetProfiles() >= SH.Store:GetProfileLimit() then
        SH:Print("You can store up to 10 layout profiles.")
        return
    end
    local sourceLayout = {}
    for position, markerID in ipairs(SH.Store:GetLayout()) do sourceLayout[position] = markerID end
    self:ShowProfileNameDialog("New layout profile", "", function(name)
        return SH.Store:CreateProfile(name, sourceLayout)
    end)
end

function UI:PromptRenameProfile()
    if SH.Store:HasTemporaryLayout() then return end
    local profile = SH.Store:GetActiveProfile()
    if not profile or profile.id == "default" then return end
    self:ShowProfileNameDialog("Rename layout profile", profile.name, function(name)
        return SH.Store:RenameProfile(profile.id, name)
    end)
end

function UI:PromptDeleteProfile()
    if SH.Store:HasTemporaryLayout() then return end
    local profile = SH.Store:GetActiveProfile()
    if not profile or profile.id == "default" then return end
    self:EnsureDeleteDialog()
    self.deleteDialog.profileID = profile.id
    self.deleteDialog.panel.message:SetText(string.format("Delete \"%s\"? This cannot be undone.", profile.name))
    self.deleteDialog:Show()
end

function UI:SelectProfile(profileIndex)
    self.profileMenuDismiss:Hide()
    local profile = SH.Store:GetProfiles()[profileIndex]
    if not profile or not SH.Store:SelectProfile(profile.id) then return end
    self.selectedLayoutPosition = nil
    SH.LayoutOffer:ApplyLayout()
end

function UI:RefreshProfiles()
    if not self.profileButtons then return end
    local profiles = SH.Store:GetProfiles()
    local activeProfileID = SH.Store:GetActiveProfileID()
    local temporary = SH.Store:GetTemporaryLayout()
    for index, button in ipairs(self.profileButtons) do
        local profile = profiles[index]
        if profile then
            button.text:SetText(profile.name)
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", 6, -6 - ((index - 1 + (temporary and 1 or 0)) * 30))
            button.tooltip = profile.id == "default" and "Default factory layout. Press New to create an editable copy." or profile.name
            button:Show()
            SH.Widgets:StyleButton(button, not temporary and profile.id == activeProfileID and "primary" or "secondary")
        else
            button:Hide()
        end
    end

    if temporary then
        local sender = tostring(temporary.sender or "")
        local name = sender ~= "" and ("Temporary: " .. sender) or "Temporary Raid Layout"
        self.temporaryProfileButton.text:SetText(name)
        self.temporaryProfileButton:Show()
        self.profileSelector.text:SetText(name)
        self.profileSelector.tooltip = self.temporaryProfileButton.tooltip
        SH.Widgets:StyleButton(self.profileSelector, "pink")
    else
        self.temporaryProfileButton:Hide()
        self.profileSelector.text:SetText(SH.Store:GetActiveProfile().name)
        self.profileSelector.tooltip = "Choose a layout profile. Default is locked; press New to create an editable copy."
        SH.Widgets:StyleButton(self.profileSelector, "secondary")
    end
    self.profileMenu:SetHeight(12 + ((#profiles + (temporary and 1 or 0)) * 30))

    self.newProfileButton._shEnabledStyle = "success"
    SH.Widgets:SetEnabled(self.newProfileButton, #profiles < SH.Store:GetProfileLimit())
    local canManage = not temporary and activeProfileID ~= "default"
    SH.Widgets:SetEnabled(self.renameProfileButton, canManage)
    SH.Widgets:SetEnabled(self.deleteProfileButton, canManage)
    SH.Widgets:SetEnabled(self.resetLayoutButton, temporary ~= nil or activeProfileID ~= "default")
end

function UI:StyleLayoutButton(position)
    local button = self.layoutButtons[position]
    if not button then return end
    local selected = self.selectedLayoutPosition == position
    SH.Widgets:ApplyBackdrop(button, selected and SH.Widgets.colors.accentSoft or SH.Widgets.colors.transparent,
        selected and SH.Widgets.colors.accentBright or SH.Widgets.colors.transparent)
end

function UI:RefreshLayoutEditor()
    if not self.frame then return end
    local layout = SH.Store:GetLayout()
    for position, button in ipairs(self.layoutButtons) do
        button.icon:SetTexture(markerTexture(layout[position]))
        if position ~= SH.Const.EXIT_POSITION and position ~= SH.Const.ENTRANCE_POSITION then
            button.label:SetText(SH.Const:MarkerName(layout[position]))
        end
        self:StyleLayoutButton(position)
    end
    self:RefreshProfiles()
end

function UI:RefreshOpacityControl()
    if not self.opacityButtons then return end
    local selected = tonumber(SH.Store:Options().frameBackgroundOpacity) or 0.5
    for index, button in ipairs(self.opacityButtons) do
        SH.Widgets:StyleButton(button, math.abs(OPACITY_VALUES[index] - selected) < 0.01 and "primary" or "secondary")
    end
end

function UI:SelectLayoutPosition(position)
    if not SH.Store:HasTemporaryLayout() and SH.Store:GetActiveProfileID() == "default" then
        SH:Print("Create a new profile before changing the Default layout.")
        return
    end
    if not self.selectedLayoutPosition then
        self.selectedLayoutPosition = position
    elseif self.selectedLayoutPosition == position then
        self.selectedLayoutPosition = nil
    else
        local first = self.selectedLayoutPosition
        SH.Store:SwapLayoutPositions(first, position)
        self.selectedLayoutPosition = nil
        SH.LayoutOffer:ApplyLayout()
    end
    self:RefreshLayoutEditor()
end

function UI:Refresh()
    SH.PersonalWarning:ApplyFontSize()
    self.warningFontSlider._shUpdating = true
    self.warningFontSlider:SetValue(SH.Store:Options().personalWarningFontSize)
    self.warningFontSlider._shUpdating = false
    self.warningFontLabel:SetText(string.format("Warning Font: %d px", SH.Store:Options().personalWarningFontSize))
    local warningDelay = SH.Store:GetPersonalWarningDelay()
    self.warningDelaySlider._shUpdating = true
    self.warningDelaySlider:SetValue(warningDelay)
    self.warningDelaySlider._shUpdating = false
    self.warningDelayLabel:SetText(string.format("Personal Warning Delay: %g s", warningDelay))
    for _, entry in ipairs(self.optionChecks) do entry.check:SetChecked(entry.getter()) end
    self.createMacrosButton:SetShown(SH.Store:Options().showNSRTMacros)
    for _, entry in ipairs(self.scaleControls) do
        local value = tonumber(entry.getter()) or 1
        entry.slider._shUpdating = true
        entry.slider:SetValue(value)
        entry.slider._shUpdating = false
        entry.text:SetText(string.format("%s: %d%%", entry.label, math.floor((value * 100) + 0.5)))
    end
    self:RefreshOpacityControl()
    self:RefreshLayoutEditor()
    local canPublish = IsInRaid() and UnitIsGroupLeader("player") and not SH.Comms:IsLockedDown()
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
    local hint = SH.Widgets:Label(frame, "Macros send to your raid.")
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
