-- Two isolated addon namespaces, real event dispatch, and a simulated RAID bus.
-- Run through regression.lua; shared frame primitives stand in for the WoW UI.
local check = function(value, message) assert(value, message) end
local clock, timers, clients, queue, traffic = 100, {}, {}, {}, {}
local dropAck, dropPlan = false, false
local roster = {{"Popamonk", "Area52", "MONK"}, {"Popadruid", "Area52", "DRUID"}}
local function fire(client, event, ...)
    client.SH.frame.scripts.OnEvent(client.SH.frame, event, ...)
    check(#client.errors == 0, "event handler error: " .. (client.errors[1] or ""))
end
local function deliver()
    while #queue > 0 do
        local packet = table.remove(queue, 1)
        for _, client in ipairs(clients) do
            if client.prefixes[packet.prefix] and not (dropAck and packet.message:match("^MPA|"))
                and not (dropPlan and client.index == 2 and packet.message:match("^MPS|")) then
                -- Same-realm senders are deliberately unqualified. UnitInRaid
                -- below only resolves unit tokens and short character names.
                fire(client, "CHAT_MSG_ADDON", packet.prefix, packet.message, "RAID", roster[packet.sender][1])
            end
        end
    end
end
local function advance(seconds)
    local deadline, steps = clock + seconds, 0
    deliver()
    while true do
        local nextTimer
        for _, timer in ipairs(timers) do
            if not timer.cancelled and not timer.fired and timer.at <= deadline
                and (not nextTimer or timer.at < nextTimer.at) then nextTimer = timer end
        end
        if not nextTimer then break end
        clock, nextTimer.fired = nextTimer.at, true
        nextTimer.callback()
        deliver()
        steps = steps + 1
        check(steps < 500, "transfer timers did not settle")
    end
    clock = deadline
end
local function makeClient(index)
    local client = {index = index, scans = 0, names = 0, errors = {}, logs = {}, prefixes = {}}
    local env = setmetatable({}, {__index = _G})
    client.env, env._G = env, env
    env.SlashCmdList, env.SszorakHelperDB = {}, {}
    env.GetTime, env.GetServerTime = function() return clock end, function() return math.floor(clock) end
    env.InCombatLockdown = function() return client.combat == true end
    env.IsInRaid = function() return true end
    env.GetNormalizedRealmName = function() return "Area52" end
    local function unitIndex(unit)
        if unit == "player" then return index end
        for i, member in ipairs(roster) do
            if unit == "raid" .. i or unit == member[1] then return i end
        end
    end
    env.UnitInRaid = unitIndex
    env.UnitFullName = function(unit)
        client.names = client.names + 1
        check(not client.combat, "read a name in combat")
        local member = roster[unitIndex(unit)]
        if member then return member[1], "Area 52" end
    end
    env.UnitClass = function(unit) local member = roster[unitIndex(unit)]; return "", member and member[3] end
    env.UnitGroupRolesAssigned = function() return "DAMAGER" end
    env.UnitIsGroupLeader = function(unit) return unitIndex(unit) == 1 end
    env.GetNumGroupMembers = function() client.scans = client.scans + 1; return client.emptySnapshot and 0 or #roster end
    env.geterrorhandler = function() return function(message) client.errors[#client.errors + 1] = message end end
    env.DEFAULT_CHAT_FRAME = {AddMessage = function(_, message) client.logs[#client.logs + 1] = message end}
    env.C_Timer = {NewTimer = function(delay, callback)
        local timer = {at = clock + delay, callback = callback, Cancel = function(self) self.cancelled = true end}
        timers[#timers + 1] = timer
        return timer
    end}
    env.C_Timer.After = function(delay, callback) env.C_Timer.NewTimer(delay, callback) end
    env.C_ChatInfo = {
        InChatMessagingLockdown = function() return client.lockdown == true end,
        RegisterAddonMessagePrefix = function(prefix) client.prefixes[prefix] = true end,
        SendAddonMessage = function(prefix, message, channel)
            check(not client.combat and not client.lockdown and channel == "RAID", "unsafe configuration send")
            if message:match("^MPA|") and client.throttleAck and client.throttleAck > 0 then
                client.throttleAck = client.throttleAck - 1
                return Enum.SendAddonMessageResult.AddonMessageThrottle
            end
            local packet = {sender = index, prefix = prefix, message = message}
            traffic[#traffic + 1], queue[#queue + 1] = packet, packet
            return Enum.SendAddonMessageResult.Success
        end,
    }
    local SH = {}
    local function load(path) setfenv(assert(loadfile(path)), env)("SszorakHelper", SH) end
    load("SszorakHelper.lua")
    for _, path in ipairs({"Core/Constants.lua", "Core/Store.lua", "Core/MythicPositions.lua", "UI/Widgets.lua", "UI/RoomMap.lua", "Core/Comms.lua"}) do load(path) end
    -- Initialize only the modules needed by this isolated transfer scenario.
    SH.modules.RoomMap = nil
    client.SH = SH
    fire(client, "ADDON_LOADED", "SszorakHelper")
    SH.Encounter = {testMode = true, IsComplete = function() return false end}
    SH.RoomMap:OnInitialize()
    SH.Store:Options().showMythicPosition = true
    load("Options/MythicPositions.lua")
    SH.MythicPositionsUI:Create({frame = env.CreateFrame("Frame"), header = env.CreateFrame("Frame")})
    clients[#clients + 1] = client
    return client
end
local publisher, receiver = makeClient(1), makeClient(2)
local P, R = publisher.SH.MythicPositions, receiver.SH.MythicPositions
local PU, RU = publisher.SH.MythicPositionsUI, receiver.SH.MythicPositionsUI
receiver.emptySnapshot = true
RU.page:Show(); RU:Open()
receiver.emptySnapshot = false
PU.page:Show(); PU:Open()
local draft = {slots = P:DefaultSlots(), previous = {}}
draft.slots[5].member = {name = "Popamonk-Area52", class = "MONK"}
draft.slots[17].member = {name = "Popadruid-Area52", class = "DRUID"}
draft.slots[17].x = 0.625
check(P:Publish(draft), "two-player plan did not start")
advance(6.35)
check(R.received and R.received.slots[17].member.name == "Popadruid-Area52", "other account did not receive the sparse plan")
check(RU.draft.slots[5].member and RU.draft.slots[17].member and RU.buttons[17].label:GetText() == "Popa",
    "open receiving editor kept its old empty draft")
check(R.personal and R.personal.slot == 17 and receiver.SH.RoomMap.frame.mythicDot:IsShown(), "receiver's assigned dot did not update")
check(P.publication and P.publication.count == 0 and PU.message:find("waiting", 1, true), "sending alone claimed confirmed receipt")
advance(0.1)
check(P.publication.count == 1 and PU.message:find("1 other addon user", 1, true), "publisher did not receive acknowledgment through CHAT_MSG_ADDON")
check(publisher.scans == 1 and receiver.scans == 1, "transfer or UI refresh enumerated the raid")
local ack = traffic[#traffic].message
fire(publisher, "CHAT_MSG_ADDON", "SSZHELP", ack, "RAID", "Popadruid")
check(P.publication.count == 1, "duplicate acknowledgment increased the receipt count")
fire(publisher, "CHAT_MSG_ADDON", "SSZHELP", ack, "RAID", "Popadruid-OtherRealm")
check(P.publication.count == 1, "cross-realm impostor acknowledged a plan")
local received = R.received
for _, sender in ipairs({"Popadruid", "Popamonk-OtherRealm"}) do
    fire(receiver, "CHAT_MSG_ADDON", "SSZHELP", "MPB|999-1|Fake|1", "RAID", sender)
    check(not R.pending and R.received == received, "unverified leader started a transfer")
end

-- Old headers and qualified sender names also work without a trusted index hint.
local header = traffic[1].message:match("^(MPB|%d+%-%d+|[^|]+)")
fire(receiver, "CHAT_MSG_ADDON", "SSZHELP", header, "RAID", "Popamonk-Area52")
check(R.pending and R.pending.sender == "Popamonk-Area52", "qualified sender could not resolve through its short raid name")
R.pending = nil
fire(receiver, "CHAT_MSG_ADDON", "SSZHELP", header, "RAID", "Popamonk")
check(R.pending, "same-realm short sender was rejected by full-name comparison")
R.pending = nil

-- A new leader plan updates the actual assignment while preserving unsaved edits.
RU:SetPosition(5, 0.4, 0.7)
draft.slots[17].x = 0.7
check(P:Publish(draft), "repeat publication failed")
advance(7)
check(R.personal.x == 0.7 and RU.draft.slots[5].x == 0.4 and RU.dirty
    and RU.message:find("Revert", 1, true), "incoming plan overwrote unsaved edits or failed to update the personal point")
RU:LoadDraft()
check(not RU.dirty and RU.draft.slots[17].x == 0.7, "Revert failed to display the received plan with a stale snapshot")

-- API success without a response must time out as unconfirmed, not published.
dropAck = true
check(P:Publish(draft), "unacknowledged publication failed to start")
advance(17)
check(not P.publication and not P.receiptTimer and PU.message:find("No receipt confirmed", 1, true), "missing receiver response reported success")
dropAck = false
dropPlan = true
received = R.received
check(P:Publish(draft), "partial transfer did not start")
advance(17)
check(R.received == received and PU.message:find("No receipt confirmed", 1, true), "partial transfer replaced a plan or acknowledged it")
dropPlan = false

-- A closed editor needs no opening scan to accept the plan and show the dot.
RU.page:Hide()
receiver.SH.Encounter.testMode = false
receiver.throttleAck = 2
check(P:Publish(draft), "closed-editor publication failed")
advance(7)
check(R.ackTimer and P.publication.count == 0, "throttled receipt was not queued for retry")
advance(2)
check(R.received ~= received and P.publication.count == 1 and R.personal.slot == 17,
    "closed editor, normal mode or a temporary receipt throttle prevented confirmation")
local scans, names = receiver.scans, receiver.names
receiver.combat = true
fire(receiver, "PLAYER_REGEN_DISABLED")
fire(receiver, "CHAT_MSG_ADDON", "SSZHELP", header, "RAID", "Popamonk")
check(not R.pending and receiver.names == names and receiver.scans == scans, "combat receiver read the roster")
receiver.combat = false
publisher.combat = true
local receiptTimer = P.receiptTimer
fire(publisher, "PLAYER_REGEN_DISABLED")
check(receiptTimer.cancelled and not P.publication and not P.receiptTimer, "combat left receipt tracking alive")
check(publisher.scans == 1 and receiver.scans == 1, "configuration messages rescanned the raid")
print("Independent client checks passed: sparse plans, real event dispatch, sender formats, open/closed editors, stale snapshots, receipts and combat cleanup.")
