local _, SH = ...

SH.Comms = {initializeOrder = 50, peers = {}, externalMarkers = {}}
SH.modules.Comms = SH.Comms

local function normalized(name)
    return tostring(name or ""):gsub("%s+", ""):lower()
end

local function shortName(name)
    return normalized(tostring(name or ""):match("^[^-]+") or name)
end

local function unitName(unit)
    local name, realm = UnitFullName(unit)
    if not name then return nil end
    realm = realm and realm:gsub("%s+", "") or ""
    return realm ~= "" and (name .. "-" .. realm) or name
end

local function namesMatch(a, b)
    local fullA, fullB = normalized(a), normalized(b)
    if fullA == fullB then return true end
    if tostring(a or ""):find("-", 1, true) and tostring(b or ""):find("-", 1, true) then return false end
    return shortName(a) == shortName(b)
end

function SH.Comms:OnInitialize()
    C_ChatInfo.RegisterAddonMessagePrefix(SH.Const.PREFIX)
    self:MarkPeer(unitName("player"))

    SH:RegisterEvent("CHAT_MSG_ADDON", function(_, prefix, message, _, sender)
        if prefix == SH.Const.PREFIX then SH.Comms:OnAddonMessage(message, sender) end
    end)
    SH:RegisterEvent("CHAT_MSG_RAID", function(_, message, sender) SH.Comms:OnRaidMessage(message, sender) end)
    SH:RegisterEvent("CHAT_MSG_RAID_LEADER", function(_, message, sender) SH.Comms:OnRaidMessage(message, sender) end)
    SH:RegisterEvent("GROUP_ROSTER_UPDATE", function()
        if SH.Encounter and SH.Encounter.active then SH.Comms:Announce() end
    end)
    SH:RegisterEvent("GROUP_LEFT", function()
        SH.Store:ClearTemporaryLayout()
        if SH.RoomMap then SH.RoomMap:RefreshLayout() end
    end)
    SH:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        if not IsInRaid() and SH.Store:HasTemporaryLayout() then
            SH.Store:ClearTemporaryLayout()
            if SH.RoomMap then SH.RoomMap:RefreshLayout() end
        end
    end)
end

function SH.Comms:MarkPeer(name)
    if not name or name == "" then return end
    self.peers[normalized(name)] = {name = name, seen = GetTime()}
end

function SH.Comms:Send(message)
    if not IsInRaid() then return false end
    C_ChatInfo.SendAddonMessage(SH.Const.PREFIX, message, "RAID")
    return true
end

function SH.Comms:Announce(force)
    local now = GetTime()
    if not force and self.lastAnnounce and now - self.lastAnnounce < 3 then return end
    self.lastAnnounce = now
    self:MarkPeer(unitName("player"))
    self:Send(string.format("HELLO|%d|%s", SH.Const.PROTOCOL, SH.version))
end

function SH.Comms:IsPeerUnit(unit)
    if UnitIsConnected and not UnitIsConnected(unit) then return false end
    local name = unitName(unit)
    if not name then return false end
    for _, peer in pairs(self.peers) do
        if namesMatch(name, peer.name) and ((SH.Encounter and SH.Encounter.active) or GetTime() - peer.seen < 90) then return true end
    end
    return false
end

function SH.Comms:CoordinatorName()
    if not IsInRaid() then return unitName("player") end
    local assistants, members = {}, {}
    for index = 1, GetNumGroupMembers() do
        local unit = "raid" .. index
        if self:IsPeerUnit(unit) then
            local name = unitName(unit)
            if UnitIsGroupLeader(unit) then return name end
            members[#members + 1] = name
            if UnitIsGroupAssistant(unit) then assistants[#assistants + 1] = name end
        end
    end
    local pool = #assistants > 0 and assistants or members
    table.sort(pool, function(a, b) return normalized(a) < normalized(b) end)
    return pool[1] or unitName("player")
end

function SH.Comms:IsCoordinator()
    return namesMatch(self:CoordinatorName(), unitName("player"))
end

function SH.Comms:IsSenderCoordinator(sender)
    return namesMatch(sender, self:CoordinatorName())
end

function SH.Comms:IsSenderLeader(sender)
    if not IsInRaid() then return false end
    for index = 1, GetNumGroupMembers() do
        local unit = "raid" .. index
        if UnitIsGroupLeader(unit) and namesMatch(sender, unitName(unit)) then return true end
    end
    return false
end

function SH.Comms:ProposeAssignment(order, position)
    if not SH.Encounter then return end
    if SH.Encounter.testMode then
        SH.Encounter:AcceptProposal(order, position, unitName("player"), "test")
        return
    end
    if not SH.Encounter.active then return end
    local warmupRemaining = 1.2 - (GetTime() - (SH.Encounter.startedAt or 0))
    if warmupRemaining > 0 then
        C_Timer.After(warmupRemaining, function()
            if SH.Encounter and SH.Encounter.active then SH.Comms:ProposeAssignment(order, position) end
        end)
        return
    end
    local message = string.format("PROPOSE|%d|%d|%d", SH.Encounter.cycle, order, position)
    if self:IsCoordinator() then SH.Encounter:AcceptProposal(order, position, unitName("player"), "addon") end
    self:Send(message)
end

function SH.Comms:BroadcastState()
    if not self:IsCoordinator() or not SH.Encounter.active then return end
    local assignments = SH.Encounter.assignments
    self:Send(string.format("STATE|%d|%d|%d|%d|%d", SH.Encounter.cycle, SH.Encounter.revision,
        assignments[1] or 0, assignments[2] or 0, assignments[3] or 0))
end

function SH.Comms:RequestClear()
    if not SH.Encounter then return end
    if SH.Encounter.testMode then SH.Encounter:ClearAssignments("test"); return end
    if not SH.Encounter.active then return end
    SH.Encounter:ClearAssignments("local")
    self:Send(string.format("CLEAR|%d|%s", SH.Encounter.cycle, tostring(GetTime())))
end

function SH.Comms:BroadcastReset()
    if self:IsCoordinator() and SH.Encounter.active then
        self:Send(string.format("RESET|%d", SH.Encounter.cycle))
    end
end

function SH.Comms:PublishDropOrder(markers, firstIndex)
    if not IsInRaid() or type(markers) ~= "table" then return end
    firstIndex = firstIndex or 1
    for index = firstIndex, 4 do
        local markerID = tonumber(markers[index])
        if markerID then
            local publishedMarker = markerID
            local delay = (index - firstIndex) * 0.35
            C_Timer.After(delay, function()
                if SH.Encounter and SH.Encounter.active then
                    C_ChatInfo.SendChatMessage(tostring(publishedMarker), "RAID")
                end
            end)
        end
    end
end

function SH.Comms:PublishLayout()
    if not IsInRaid() or not UnitIsGroupLeader("player") then
        SH:Print("Only the raid leader can publish a marker layout.")
        return false
    end
    local layout = SH.Store:GetDefaultLayout()
    local values = {}
    for position = 1, 8 do values[position] = tostring(layout[position]) end
    self:Send("LAYOUT|" .. table.concat(values, ","))
    SH:Print("Marker layout offered to Sszorak Helper users in the raid.")
    return true
end

function SH.Comms:OnAddonMessage(message, sender)
    local command, payload = message:match("^([^|]+)|?(.*)$")
    if command == "HELLO" then
        self:MarkPeer(sender)
        return
    end
    self:MarkPeer(sender)
    if not SH.Encounter then return end

    if command == "PROPOSE" and SH.Encounter.active and self:IsCoordinator() then
        local cycle, order, position = strsplit("|", payload)
        if tonumber(cycle) == SH.Encounter.cycle then
            SH.Encounter:AcceptProposal(tonumber(order), tonumber(position), sender, "addon")
        end
    elseif command == "STATE" and SH.Encounter.active and self:IsSenderCoordinator(sender) then
        local cycle, revision, one, two, three = strsplit("|", payload)
        SH.Encounter:ApplyState(tonumber(cycle), tonumber(revision), {tonumber(one), tonumber(two), tonumber(three)})
    elseif command == "CLEAR" and SH.Encounter.active then
        local cycle = tonumber((payload:match("^([^|]+)")))
        if cycle == SH.Encounter.cycle then SH.Encounter:ClearAssignments("remote") end
    elseif command == "RESET" and SH.Encounter.active and self:IsSenderCoordinator(sender) then
        local cycle = tonumber(payload)
        if cycle and cycle > SH.Encounter.cycle then SH.Encounter:ResetForNextPhase(cycle, false) end
    elseif command == "LAYOUT" and self:IsSenderLeader(sender) and not namesMatch(sender, unitName("player")) then
        local layout, seen = {}, {}
        for value in payload:gmatch("[^,]+") do
            local markerID = tonumber(value)
            if not markerID or markerID < 1 or markerID > 8 or seen[markerID] then return end
            seen[markerID] = true
            layout[#layout + 1] = markerID
        end
        if #layout == 8 then SH.LayoutOffer:Show(sender, layout) end
    end
end

function SH.Comms:OnRaidMessage(message, sender)
    if not (SH.Encounter and SH.Encounter.active) or SH.Encounter:IsComplete() then return end
    if not self:IsCoordinator() then return end
    local markerID = tonumber(tostring(message or ""):match("^%s*([1-8])%s*$"))
    if not markerID then return end

    local now = GetTime()
    if not self.externalStarted or now - self.externalStarted > 6 then
        self.externalMarkers = {}
        self.externalStarted = now
    end
    self.externalMarkers[#self.externalMarkers + 1] = markerID
    if #self.externalMarkers == 3 then
        local token = tostring(now) .. tostring(sender)
        self.externalToken = token
        C_Timer.After(0.8, function()
            if SH.Comms.externalToken == token then SH.Comms:FinalizeExternal(false) end
        end)
    elseif #self.externalMarkers >= 4 then
        self:FinalizeExternal(true)
    end
end

function SH.Comms:FinalizeExternal(hadExit)
    if #self.externalMarkers < 3 or not (SH.Encounter and SH.Encounter.active) then return end
    self.externalToken = nil
    local markers = {self.externalMarkers[1], self.externalMarkers[2], self.externalMarkers[3]}
    self.externalMarkers = {}
    local completed = SH.Encounter:ImportExternalMarkers(markers)
    if completed and not hadExit then
        local drops = SH.Encounter:ComputeDropOrder()
        C_Timer.After(0.15, function()
            if SH.Encounter and SH.Encounter.active then SH.Comms:PublishDropOrder(drops, 4) end
        end)
    end
end
