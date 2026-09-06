local _, SH = ...

SH.RoomMap = {initializeOrder = 30}
SH.modules.RoomMap = SH.RoomMap

local TWO_PI = math.pi * 2
local INTERMISSION_ROOM_ROTATION = math.pi / 4
local MAP_RADIUS = 104
local EDGE_RADIUS = 126

local function pointFor(position, radius, rotation)
    local angle = ((position - 1) * (TWO_PI / 8)) + (rotation or 0)
    return math.sin(angle) * radius, math.cos(angle) * radius
end

function SH.RoomMap:OnInitialize()
    local frame = CreateFrame("Frame", "SszorakHelperRoomMap", UIParent, "BackdropTemplate")
    frame:SetSize(348, 348)
    frame:SetScale(SH.Store:Options().roomMapScale or 1)
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

    frame.edges = {}
    for index = 1, 8 do
        local edge = frame:CreateLine(nil, "ARTWORK")
        edge:SetThickness(2)
        edge:SetColorTexture(unpack(SH.Widgets.colors.borderStrong))
        frame.edges[index] = edge
    end

    frame.player = frame:CreateTexture(nil, "OVERLAY")
    frame.player:SetTexture("Interface\\Minimap\\MinimapArrow")
    frame.player:SetSize(28, 28)
    frame.player:SetPoint("CENTER", 0, -5)

    frame.groups = {}
    for position = 1, 8 do
        local buttonPosition = position
        local group = CreateFrame("Frame", nil, frame)
        group:SetSize(92, 66)
        group.marker = group:CreateTexture(nil, "OVERLAY")
        group.marker:SetSize(36, 36)
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
            group.location:SetPoint("BOTTOM", 0, 1)
            group.location:SetTextColor(unpack(SH.Widgets.colors.textMuted))
        end
        frame.groups[position] = group
    end

    frame.rotatingMarkers = {}
    for position = 1, 8 do
        local marker = frame:CreateTexture(nil, "OVERLAY")
        marker:Hide()
        frame.rotatingMarkers[position] = marker
    end

    frame.clear = SH.Widgets:Button(frame, "Clear", 70, 24, function()
        if SH.Comms then SH.Comms:RequestClear() end
    end, "danger")
    frame.clear:SetPoint("BOTTOM", 0, 8)

    SH.Widgets:MakeMovable(frame, "roomMap", frame)
    self.frame = frame
    self:Reposition(0)
    self:RefreshLayout()
    self:RefreshAssignments()
    self:ApplyBackgroundOpacity()
end

function SH.RoomMap:ApplyScale()
    self.frame:SetScale(SH.Store:Options().roomMapScale or 1)
end

function SH.RoomMap:ApplyBackgroundOpacity()
    local opacity = math.max(0, math.min(1, tonumber(SH.Store:Options().frameBackgroundOpacity) or 1))
    self.frame:SetBackdropColor(0.035, 0.064, 0.084, opacity)
    self.frame.circle:SetVertexColor(0.025, 0.05, 0.065, 0)
end

function SH.RoomMap:Reposition(rotation)
    local centerY = -5
    local vertices = {}
    for position = 1, 8 do
        local x, y = pointFor(position, EDGE_RADIUS, rotation)
        vertices[position] = {x, y + centerY}
    end
    for index, edge in ipairs(self.frame.edges) do
        local nextIndex = index == 8 and 1 or index + 1
        edge:SetStartPoint("CENTER", self.frame, "CENTER", vertices[index][1], vertices[index][2])
        edge:SetEndPoint("CENTER", self.frame, "CENTER", vertices[nextIndex][1], vertices[nextIndex][2])
    end
    for position, group in ipairs(self.frame.groups) do
        local x, y = pointFor(position, MAP_RADIUS, rotation)
        group:ClearAllPoints()
        group:SetPoint("CENTER", self.frame, "CENTER", x, y + centerY)
    end
end


function SH.RoomMap:PrepareRotatingMarkers()
    local layout = SH.Store:GetLayout()
    local rotationScale = math.sqrt(2)
    local layerSize = 264 * rotationScale
    local layerHalf = layerSize * 0.5
    local markerHalf = 36 * rotationScale * 0.5
    for position, marker in ipairs(self.frame.rotatingMarkers) do
        local x, y = pointFor(position, MAP_RADIUS, INTERMISSION_ROOM_ROTATION)
        local targetX = x * rotationScale
        local targetY = (y - 5) * rotationScale
        marker:SetRotation(0)
        marker:SetTexture(string.format("Interface\\TargetingFrame\\UI-RaidTargetingIcon_%d", layout[position]))
        marker:SetSize(layerSize, layerSize)
        marker:ClearAllPoints()
        marker:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
        marker:ClearVertexOffsets()
        marker:SetVertexOffset(UPPER_LEFT_VERTEX, targetX - markerHalf + layerHalf, targetY + markerHalf - layerHalf)
        marker:SetVertexOffset(LOWER_LEFT_VERTEX, targetX - markerHalf + layerHalf, targetY - markerHalf + layerHalf)
        marker:SetVertexOffset(UPPER_RIGHT_VERTEX, targetX + markerHalf - layerHalf, targetY + markerHalf - layerHalf)
        marker:SetVertexOffset(LOWER_RIGHT_VERTEX, targetX + markerHalf - layerHalf, targetY - markerHalf + layerHalf)
    end
end

function SH.RoomMap:RefreshLayout()
    local layout = SH.Store:GetLayout()
    for position, group in ipairs(self.frame.groups) do
        local markerID = tonumber(layout[position]) or position
        group.marker:SetTexture(string.format("Interface\\TargetingFrame\\UI-RaidTargetingIcon_%d", markerID))
    end
    self:PrepareRotatingMarkers()
end

function SH.RoomMap:RefreshAssignments()
    if not self.frame then return end
    local assignments = SH.Encounter and SH.Encounter.assignments or {}
    local usedPositions = {}
    for _, position in pairs(assignments) do usedPositions[position] = true end

    for position, group in ipairs(self.frame.groups) do
        group.dropBadge:Hide()
        for order, button in pairs(group.buttons) do
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
    self.frame.clear:SetShown(SH.Store:Options().showClearButton == true and not self.rotating)
end

function SH.RoomMap:SetUnlocked(unlocked)
    self.frame._shUnlocked = unlocked and true or false
    self.frame.title:SetText("SSZORAK ROOM")
    self.frame:SetBackdropBorderColor(unpack(unlocked and SH.Widgets.colors.accentBright or SH.Widgets.colors.borderStrong))
end

function SH.RoomMap:RefreshVisibility()
    local options = SH.Store:Options()
    local context = (SH.Encounter and SH.Encounter.active) or (SH.Encounter and SH.Encounter.testMode) or options.previewFrames
    self.frame:SetShown(context and options.showRoomMap)
end

local function showCompassTexture()
    if not MinimapCompassTexture then return end
    local metatable = getmetatable(MinimapCompassTexture)
    local methods = metatable and metatable.__index
    local realShow = type(methods) == "table" and methods.Show
    if type(realShow) == "function" then realShow(MinimapCompassTexture) else MinimapCompassTexture:Show() end
end

function SH.RoomMap:StartRotation()
    if self.rotating or not SH.Store:Options().rotateMap then return end
    self.rotating = true
    self.elapsed = 0
    self:PrepareRotatingMarkers()
    for _, group in ipairs(self.frame.groups) do group:Hide() end
    for _, marker in ipairs(self.frame.rotatingMarkers) do marker:Show() end
    self.frame.clear:Hide()
    self.previousRotateMinimap = GetCVar("rotateMinimap")
    if MinimapCompassTexture then
        self.compassWasShown = MinimapCompassTexture:IsShown()
        self.compassAlpha = MinimapCompassTexture:GetAlpha()
        if not self.compassWasShown then MinimapCompassTexture:SetAlpha(0) end
        showCompassTexture()
    end
    if self.previousRotateMinimap ~= "1" then
        C_CVar.SetCVar("rotateMinimap", "1")
        if MinimapCluster and MinimapCluster.SetRotateMinimap then MinimapCluster:SetRotateMinimap(true) end
    end
    self.frame:SetScript("OnUpdate", function(_, elapsed)
        SH.RoomMap.elapsed = SH.RoomMap.elapsed + elapsed
        if SH.RoomMap.elapsed < 0.05 then return end
        SH.RoomMap.elapsed = 0
        if not MinimapCompassTexture then return end
        local ok, rotation = pcall(MinimapCompassTexture.GetRotation, MinimapCompassTexture)
        if ok then
            for _, marker in ipairs(SH.RoomMap.frame.rotatingMarkers) do marker:SetRotation(rotation) end
        end
    end)
end

function SH.RoomMap:StopRotation()
    if not self.rotating then return end
    self.rotating = false
    self.frame:SetScript("OnUpdate", nil)
    for _, marker in ipairs(self.frame.rotatingMarkers) do
        marker:SetRotation(0)
        marker:Hide()
    end
    for _, group in ipairs(self.frame.groups) do group:Show() end
    self.frame.clear:SetShown(SH.Store:Options().showClearButton == true)
    if self.previousRotateMinimap ~= nil then
        C_CVar.SetCVar("rotateMinimap", self.previousRotateMinimap)
        if MinimapCluster and MinimapCluster.SetRotateMinimap then
            MinimapCluster:SetRotateMinimap(self.previousRotateMinimap == "1")
        end
    end
    if MinimapCompassTexture then
        if not self.compassWasShown then MinimapCompassTexture:Hide() end
        MinimapCompassTexture:SetAlpha(self.compassAlpha or 1)
    end
    self.previousRotateMinimap = nil
    self.compassWasShown = nil
    self.compassAlpha = nil
end
