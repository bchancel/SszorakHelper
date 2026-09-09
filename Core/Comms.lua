local _, SH = ...

SH.Comms = {initializeOrder = 50, receivedCount = 0, receivedMarkers = {}}
SH.modules.Comms = SH.Comms

local function normalized(name)
    return tostring(name or ""):gsub("%s+", ""):lower()
end

local function unitName(unit)
    local name, realm = UnitFullName(unit)
    if not name then return nil end
    realm = realm and realm:gsub("%s+", "") or ""
    return realm ~= "" and (name .. "-" .. realm) or name
end

local function namesMatch(a, b)
    local first, second = normalized(a), normalized(b)
    if first == second then return true end
    if first:find("-", 1, true) and second:find("-", 1, true) then return false end
    return first:match("^[^-]+") == second:match("^[^-]+")
end

local function secretValue(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

function SH.Comms:OnInitialize()
    C_ChatInfo.RegisterAddonMessagePrefix(SH.Const.PREFIX)
    SH:RegisterEvent("CHAT_MSG_ADDON", function(_, prefix, message, _, sender)
        if not secretValue(prefix) and prefix == SH.Const.PREFIX then self:OnAddonMessage(message, sender) end
    end)
    SH:RegisterEvent("CHAT_MSG_RAID", function(_, message) self:OnRaidMessage(message) end)
    SH:RegisterEvent("CHAT_MSG_RAID_LEADER", function(_, message) self:OnRaidMessage(message) end)
    SH:RegisterEvent("GROUP_LEFT", function()
        SH.Store:ClearTemporaryLayout()
        if SH.LayoutOffer then SH.LayoutOffer:ApplyLayout() end
    end)
    SH:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        if not IsInRaid() and SH.Store:HasTemporaryLayout() then
            SH.Store:ClearTemporaryLayout()
            if SH.LayoutOffer then SH.LayoutOffer:ApplyLayout() end
        end
    end)
end

function SH.Comms:IsLockedDown()
    return (C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown())
        or (SH.Encounter and SH.Encounter.active) or false
end

function SH.Comms:Send(message)
    if SH.Encounter and SH.Encounter.testMode then return false end
    if not IsInRaid() or self:IsLockedDown() then return false end
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, SH.Const.PREFIX, message, "RAID")
    self.lastSendResult = ok and result or nil
    return ok and result == Enum.SendAddonMessageResult.Success
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
    if not SH.Encounter or not (SH.Encounter.active or SH.Encounter.testMode) then return end
    -- Human selections stay local. Fixed, hardware-clicked raid macros publish
    -- the chosen drop markers; no coordinator or addon traffic is used in combat.
    SH.Encounter:AcceptProposal(order, position)
end

function SH.Comms:RequestClear()
    if SH.Encounter and (SH.Encounter.active or SH.Encounter.testMode) then
        SH.Encounter:ClearAssignments()
    end
end

function SH.Comms:PublishLayout()
    if not IsInRaid() or not UnitIsGroupLeader("player") then
        SH:Print("Only the raid leader can publish a marker layout.")
        return false
    end
    local values = {}
    for position, markerID in ipairs(SH.Store:GetLayout()) do values[position] = tostring(markerID) end
    if not self:Send("LAYOUT|" .. table.concat(values, ",")) then
        SH:Print("Layout could not be sent. Publish outside the encounter and chat lockdown.")
        return false
    end
    SH:Print("Marker layout offered to Sszorak Helper users in the raid.")
    return true
end

function SH.Comms:OnAddonMessage(message, sender)
    if secretValue(message) or secretValue(sender) then return end
    if type(message) ~= "string" or type(sender) ~= "string" then return end
    if self:IsLockedDown() or (SH.Encounter and SH.Encounter.testMode) then return end
    local payload = message:match("^LAYOUT|(.+)$")
    if not payload or not self:IsSenderLeader(sender) or namesMatch(sender, unitName("player")) then return end
    local layout, seen = {}, {}
    for value in payload:gmatch("[^,]+") do
        local markerID = tonumber(value)
        if not markerID or markerID % 1 ~= 0 or markerID < 1 or markerID > 8 or seen[markerID] then return end
        seen[markerID] = true
        layout[#layout + 1] = markerID
    end
    if #layout == 8 then SH.LayoutOffer:Show(sender, layout) end
end

function SH.Comms:OnRaidMessage(message)
    if not (SH.Encounter and (SH.Encounter.active or SH.Encounter.testMode)) or not SH.Store:Options().receiveNSRT then return end
    -- Secret chat can be passed to a display API, never parsed or compared.
    -- As in NSRT, every raid/raid-leader message consumes a display slot.
    -- The raid must use one caller and keep these channels clear of other text.
    self.receivedCount = (self.receivedCount % 4) + 1
    if self.receivedCount == 1 then self.receivedMarkers = {} end
    self.receivedMarkers[self.receivedCount] = message
    if not SH.Encounter:IsComplete() then SH.OrderFrame:ShowReceived(self.receivedMarkers, self.receivedCount) end
end
