local _, SH = ...

SH.RoomMap = {initializeOrder = 30}
SH.modules.RoomMap = SH.RoomMap

local TWO_PI = math.pi * 2
local MAP_RADIUS = 110
local END_MARKER_RADIUS = 124
local FLOOR_WIDTH, FLOOR_HEIGHT = 252, 252 * 1380 / 1456
local CIRCLE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

local function pointFor(position, radius)
    local angle = (position - 1) * (TWO_PI / 8)
    return math.sin(angle) * radius, math.cos(angle) * radius
end

function SH.RoomMap:OnInitialize()
    local frame = CreateFrame("Frame", "SszorakHelperRoomMap", UIParent, "BackdropTemplate")
    frame:SetSize(348, 372)
    frame:SetScale((SH.Store:Options().roomMapScale or 1) * SH.Const.FRAME_SCALE_BASE)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:Hide()
    SH.Widgets:ApplyBackdrop(frame, SH.Widgets.colors.canvas, SH.Widgets.colors.borderStrong)
    SH.Store:ApplyFrame("roomMap", frame)

    frame.title = SH.Widgets:Label(frame, "SSZORAK ROOM")
    frame.title:SetPoint("TOP", 0, -7)
    frame.title:SetTextColor(unpack(SH.Widgets.colors.navigation))

    frame.circle = frame:CreateTexture(nil, "BACKGROUND")
    frame.circle:SetTexture("Interface\\Buttons\\WHITE8x8")
    frame.circle:SetSize(264, 264)
    frame.circle:SetPoint("CENTER", 0, -5)
    frame.circle:SetVertexColor(0.025, 0.05, 0.065, 0.96)

    frame.floor = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    frame.floor:SetSize(FLOOR_WIDTH, FLOOR_HEIGHT)
    frame.floor:SetPoint("CENTER", 0, -5)
    frame.floor:SetVertexColor(0.75, 0.75, 0.75, 1)
    frame.edges = {}
    for index = 1, 8 do
        local edge = frame:CreateLine(nil, "ARTWORK")
        edge:SetThickness(2)
        edge:SetColorTexture(unpack(SH.Widgets.colors.borderStrong))
        frame.edges[index] = edge
    end

    frame.floorLines = {}
    local function segment(x1, y1, x2, y2)
        local line = frame:CreateLine(nil, "ARTWORK")
        line:SetThickness(1)
        line:SetColorTexture(0.4, 0.55, 0.58, 1)
        line:SetStartPoint("CENTER", frame, "CENTER", (x1 - 0.5) * FLOOR_WIDTH, (0.5 - y1) * FLOOR_HEIGHT - 5)
        line:SetEndPoint("CENTER", frame, "CENTER", (x2 - 0.5) * FLOOR_WIDTH, (0.5 - y2) * FLOOR_HEIGHT - 5)
        frame.floorLines[#frame.floorLines + 1] = line
    end
    local octagon = {{0.41, 0.34}, {0.59, 0.34}, {0.66, 0.41}, {0.66, 0.59},
        {0.59, 0.66}, {0.41, 0.66}, {0.34, 0.59}, {0.34, 0.41}}
    for i, point in ipairs(octagon) do
        local nextPoint = octagon[i % #octagon + 1]
        segment(point[1], point[2], nextPoint[1], nextPoint[2])
    end
    for _, ray in ipairs({{0.41, 0.03, 0.41, 0.18}, {0.59, 0.03, 0.59, 0.18},
        {0.41, 0.97, 0.41, 0.82}, {0.59, 0.97, 0.59, 0.82},
        {0.03, 0.41, 0.18, 0.41}, {0.03, 0.59, 0.18, 0.59},
        {0.97, 0.41, 0.82, 0.41}, {0.97, 0.59, 0.82, 0.59}}) do segment(unpack(ray)) end

    -- Keep planning landmarks above the marker frames, without intercepting clicks.
    local spread = CreateFrame("Frame", nil, frame)
    spread:SetAllPoints(frame)
    spread:SetFrameLevel(frame:GetFrameLevel() + 5)
    spread:EnableMouse(false)
    frame.boss = spread:CreateTexture(nil, "ARTWORK")
    frame.boss:SetSize(20, 20)
    frame.boss:SetTexture(7966619)
    local mask = spread:CreateMaskTexture()
    mask:SetAllPoints(frame.boss)
    mask:SetTexture(CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    frame.boss:AddMaskTexture(mask)
    frame.bossLabel = SH.Widgets:Label(spread, "BOSS")
    frame.bossLabel:SetFont(STANDARD_TEXT_FONT, 11)
    frame.bossLabel:SetTextColor(1, 0.82, 0.4, 1)
    frame.spreadSide = SH.Widgets:Label(frame, "SPREAD: ENTRANCE")
    frame.spreadSide:SetFont(STANDARD_TEXT_FONT, 11)
    frame.spreadSide:SetPoint("TOP", 0, -25)
    frame.spreadSide:SetTextColor(unpack(SH.Widgets.colors.accentBright))

    -- A saved planning point, never a live unit position or combat aura lookup.
    frame.mythicHalo = spread:CreateTexture(nil, "OVERLAY", nil, 5)
    frame.mythicHalo:SetTexture(CIRCLE)
    frame.mythicHalo:SetSize(22, 22)
    frame.mythicHalo:SetVertexColor(0.8, 1, 0.9, 1)
    frame.mythicBorder = spread:CreateTexture(nil, "OVERLAY", nil, 6)
    frame.mythicBorder:SetTexture(CIRCLE)
    frame.mythicBorder:SetSize(18, 18)
    frame.mythicBorder:SetVertexColor(0.025, 0.12, 0.065, 1)
    frame.mythicDot = spread:CreateTexture(nil, "OVERLAY", nil, 7)
    frame.mythicDot:SetTexture(CIRCLE)
    frame.mythicDot:SetSize(12, 12)
    frame.mythicDot:SetVertexColor(0.1, 1, 0.25, 1)
    frame.mythicDot:Hide()
    frame.mythicLabel = SH.Widgets:Label(spread, "")
    frame.mythicLabel:SetFont(STANDARD_TEXT_FONT, 11)
    frame.mythicLabel:SetTextColor(0.8, 1, 0.87, 1)

    frame.groups = {}
    for position = 1, 8 do
        local buttonPosition = position
        local group = CreateFrame("Frame", nil, frame)
        group:SetSize(92, 66)
        group.marker = group:CreateTexture(nil, "OVERLAY")
        group.marker:SetSize(32, 32)
        group.marker:SetPoint("TOP", 0, 0)
        group.dropBadge = CreateFrame("Frame", nil, group, "BackdropTemplate")
        group.dropBadge:SetSize(22, 22)
        group.dropBadge:SetPoint("TOPRIGHT", group.marker, "TOPRIGHT", 7, 7)
        SH.Widgets:ApplyBackdrop(group.dropBadge, SH.Widgets.colors.pink, SH.Widgets.colors.pinkBorder)
        group.dropBadge.text = SH.Widgets:Text(group.dropBadge, "")
        group.dropBadge.text:SetPoint("CENTER")
        group.dropBadge:Hide()
        group.buttons = {}
        if SH.Const:IsWindPosition(position) then
            for order = 1, 3 do
                local buttonOrder = order
                local button = SH.Widgets:Button(group, tostring(order), 26, 22, function()
                    if SH.Comms then SH.Comms:ProposeAssignment(buttonOrder, buttonPosition) end
                end, "secondary")
                button:SetPoint("BOTTOMLEFT", 5 + ((order - 1) * 28), 0)
                button._shEnabledStyle = "secondary"
                group.buttons[order] = button
            end
        else
            group.location = SH.Widgets:Text(group, position == SH.Const.EXIT_POSITION and "EXIT" or "ENTRANCE")
            if position == SH.Const.EXIT_POSITION then group.location:SetPoint("TOP", frame, "TOP", 0, -38)
            else group.location:SetPoint("BOTTOM", frame, "BOTTOM", 0, 29) end
            group.location:SetFont(STANDARD_TEXT_FONT, 11)
            group.location:SetTextColor(unpack(SH.Widgets.colors.textMuted))
        end
        frame.groups[position] = group
    end

    frame.clear = SH.Widgets:Button(frame, "Clear", 70, 24, function()
        if SH.Comms then SH.Comms:RequestClear() end
    end, "danger")
    frame.clear:SetPoint("BOTTOMRIGHT", -8, 8)

    SH.Widgets:MakeMovable(frame, "roomMap", frame)
    self.frame = frame
    self:Reposition()
    self:RefreshLayout()
    self:RefreshAssignments()
    self:ApplyBackgroundOpacity()
    self:ApplyFloorStyle()
    self:RefreshMythicPosition()
end

function SH.RoomMap:GetSpreadSide()
    local options = SH.Store:Options()
    if options.roomMapSpreadSide == "entrance" or options.roomMapSpreadSide == "exit" then return options.roomMapSpreadSide end
    local start = options.roomMapStartingSide == "exit" and "exit" or "entrance"
    local index = SH.Encounter and SH.Encounter.furyIndex or 1
    if index % 2 == 0 then return start == "exit" and "entrance" or "exit" end
    return start
end

function SH.RoomMap:GetSpreadPoint(point)
    if self:GetSpreadSide() == "exit" then return 1 - point.x, 1 - point.y end
    return point.x, point.y
end

function SH.RoomMap:ApplyFloorStyle()
    if not self.frame then return end
    local options = SH.Store:Options()
    local style = options.roomMapBackground or "floor"
    local opacity = tonumber(options.roomMapFloorOpacity) or 0.6
    if opacity ~= opacity then opacity = 0.6 end
    opacity = math.max(0, math.min(1, opacity))
    if self.floorStyle ~= style then
        self.frame.floor:SetTexture(style == "floor" and "Interface\\AddOns\\SszorakHelper\\Media\\RoomFloor.tga" or nil)
        self.floorStyle = style
    end
    self.frame.floor:SetAlpha(opacity)
    self.frame.floor:SetShown(style == "floor")
    for _, line in ipairs(self.frame.floorLines) do line:SetAlpha(opacity); line:SetShown(style == "outline") end
    for _, edge in ipairs(self.frame.edges) do edge:SetAlpha(opacity); edge:SetShown(style == "outline") end
end

function SH.RoomMap:RefreshMythicPosition()
    if not self.frame or not self.frame.mythicDot then return end
    local personal = SH.MythicPositions and SH.MythicPositions.personal
    local options = SH.Store:Options()
    local difficulty = SH.Encounter and SH.Encounter.difficultyID
    if not (SH.Encounter and SH.Encounter.active) then difficulty = select(3, GetInstanceInfo()) end
    local preview = options.previewFrames or (SH.Encounter and SH.Encounter.testMode)
    local context = options.showMythicPosition and (difficulty == 16 or preview)
    local shown = context and personal ~= nil
    local side = self:GetSpreadSide()
    self.frame.mythicDot:SetShown(shown)
    self.frame.mythicHalo:SetShown(shown)
    self.frame.mythicBorder:SetShown(shown)
    self.frame.mythicLabel:SetShown(shown and options.roomMapShowAssignmentLabel ~= false)
    self.frame.boss:SetShown(context and options.roomMapShowBoss ~= false)
    self.frame.bossLabel:SetShown(context and options.roomMapShowBoss ~= false)
    self.frame.spreadSide:SetShown(context)
    self.frame.spreadSide:SetText("SPREAD: " .. side:upper())
    self.frame.boss:ClearAllPoints()
    self.frame.boss:SetPoint("CENTER", self.frame, "CENTER", 0, (side == "exit" and 0.325 or -0.325) * FLOOR_HEIGHT - 5)
    self.frame.bossLabel:ClearAllPoints()
    self.frame.bossLabel:SetPoint(side == "exit" and "RIGHT" or "LEFT", self.frame.boss, side == "exit" and "LEFT" or "RIGHT", side == "exit" and -4 or 4, 0)
    if personal then
        local x, y = self:GetSpreadPoint(personal)
        self.frame.mythicDot:ClearAllPoints()
        self.frame.mythicDot:SetPoint("CENTER", self.frame, "CENTER", (x - 0.5) * FLOOR_WIDTH, (0.5 - y) * FLOOR_HEIGHT - 5)
        self.frame.mythicHalo:ClearAllPoints()
        self.frame.mythicHalo:SetPoint("CENTER", self.frame.mythicDot, "CENTER")
        self.frame.mythicBorder:ClearAllPoints()
        self.frame.mythicBorder:SetPoint("CENTER", self.frame.mythicDot, "CENTER")
        self.frame.mythicLabel:ClearAllPoints()
        self.frame.mythicLabel:SetPoint(side == "exit" and "TOP" or "BOTTOM", self.frame.mythicDot,
            side == "exit" and "BOTTOM" or "TOP", 0, side == "exit" and -5 or 5)
        local number = SH.MythicPositions:DisplayNumber(personal.slot)
        local role = SH.MythicPositions:Role(personal.slot)
        self.frame.mythicLabel:SetText("YOU - " .. (number or (role == "TANK" and "Tank" or "Healer")))
    end
end

function SH.RoomMap:ApplyScale()
    if InCombatLockdown() and SH.NSRTMacros and SH.NSRTMacros.buttonsOnMap then
        SH.NSRTMacros.pendingSecureRefresh = true
        return
    end
    self.frame:SetScale((SH.Store:Options().roomMapScale or 1) * SH.Const.FRAME_SCALE_BASE)
end

function SH.RoomMap:ApplyBackgroundOpacity()
    local opacity = math.max(0, math.min(1, tonumber(SH.Store:Options().frameBackgroundOpacity) or 0.75))
    self.frame:SetBackdropColor(0.035, 0.064, 0.084, opacity)
    self.frame.circle:SetVertexColor(0.025, 0.05, 0.065, 0)
end

function SH.RoomMap:GetMarkerPoint(position)
    local endpoint = position == SH.Const.EXIT_POSITION or position == SH.Const.ENTRANCE_POSITION
    local x, y = pointFor(position, endpoint and END_MARKER_RADIUS or MAP_RADIUS)
    return x, y - 5
end

function SH.RoomMap:Reposition()
    local centerY = -5
    local vertices = {{0.29, 0.03}, {0.71, 0.03}, {0.97, 0.29}, {0.97, 0.71},
        {0.71, 0.97}, {0.29, 0.97}, {0.03, 0.71}, {0.03, 0.29}}
    for index, edge in ipairs(self.frame.edges) do
        local nextIndex = index == 8 and 1 or index + 1
        edge:SetStartPoint("CENTER", self.frame, "CENTER", (vertices[index][1] - 0.5) * FLOOR_WIDTH, (0.5 - vertices[index][2]) * FLOOR_HEIGHT + centerY)
        edge:SetEndPoint("CENTER", self.frame, "CENTER", (vertices[nextIndex][1] - 0.5) * FLOOR_WIDTH, (0.5 - vertices[nextIndex][2]) * FLOOR_HEIGHT + centerY)
    end
    for position, group in ipairs(self.frame.groups) do
        local x, y = self:GetMarkerPoint(position)
        group:ClearAllPoints()
        -- A group's marker sits 17 pixels above its center; align the icon to the floor.
        group:SetPoint("CENTER", self.frame, "CENTER", x, y - 17)
    end
end

function SH.RoomMap:RefreshLayout()
    if InCombatLockdown() and SH.NSRTMacros and SH.NSRTMacros.buttonsOnMap then return end
    local layout = SH.Store:GetLayout()
    for position, group in ipairs(self.frame.groups) do
        local markerID = tonumber(layout[position]) or position
        group.marker:SetTexture(string.format("Interface\\TargetingFrame\\UI-RaidTargetingIcon_%d", markerID))
    end
end

function SH.RoomMap:RefreshAssignments()
    if not self.frame then return end
    local assignments = SH.Encounter and SH.Encounter.assignments or {}
    local usedPositions = {}
    for _, position in pairs(assignments) do usedPositions[position] = true end

    for position, group in ipairs(self.frame.groups) do
        group.dropBadge:Hide()
        for order, button in pairs(group.buttons) do
            button:SetShown(SH.Store:Options().showWindOrderButtons ~= false)
            local selectedHere = assignments[order] == position
            local orderTaken = assignments[order] ~= nil and not selectedHere
            local positionTaken = usedPositions[position] and not selectedHere
            button._shEnabledStyle = selectedHere and "success" or "secondary"
            SH.Widgets:SetEnabled(button, not orderTaken and not positionTaken)
            if selectedHere then SH.Widgets:StyleButton(button, "success") end
        end
    end
    if SH.Encounter and SH.Encounter:IsComplete() then
        for order = 1, 3 do
            local dropPosition = SH.Const:Opposite(assignments[order])
            local group = self.frame.groups[dropPosition]
            if group then
                group.dropBadge.text:SetText(tostring(order))
                group.dropBadge:Show()
            end
        end
    end
    self.frame.clear:SetShown(SH.Store:Options().showClearButton == true)
end

function SH.RoomMap:SetUnlocked(unlocked)
    self.frame._shUnlocked = unlocked and true or false
    self.frame.title:SetText("SSZORAK ROOM")
    self.frame:SetBackdropBorderColor(unpack(unlocked and SH.Widgets.colors.accentBright or SH.Widgets.colors.borderStrong))
end

function SH.RoomMap:RefreshVisibility()
    local options = SH.Store:Options()
    local macros = SH.NSRTMacros
    local autoShown = options.nsrtAutoShow and macros and macros.autoRoomVisible
    local macroShown = options.nsrtButtonsOnMap and macros and macros:ShouldShow()
    local pinned = InCombatLockdown() and macros and macros.buttonsOnMap and macros.secureFrame:IsShown()
    local context = (SH.Encounter and SH.Encounter.active) or (SH.Encounter and SH.Encounter.testMode) or options.previewFrames or autoShown or macroShown
    self:SetUnlocked(context and not options.lockFrames)
    self.frame:SetShown(pinned or (context and options.showRoomMap))
    self:RefreshMythicPosition()
end
