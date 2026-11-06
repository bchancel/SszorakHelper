local SH, env = ...
local M, UI = SH.MythicPositions, SH.MythicPositionsUI
local check = function(value, reason) assert(value, "Mythic positions: " .. reason) end
env.setCombat(false)
env.setLockdown(false)
env.setRaid(true)
SH.Encounter.active, SH.Encounter.testMode = false, false
local roster = {
    {"Caller", "Realm", "MAGE", "DAMAGER"},
    {"Coollock", "Sargeras", "WARLOCK", "DAMAGER"},
    {"Tanky", "Realm", "WARRIOR", "TANK"},
    {"Healy", "Realm", "PRIEST", "HEALER"},
    {"Newlock", "Sargeras", "WARLOCK", "DAMAGER"},
    {"\195\137clat", "OtherRealm", "DRUID", "DAMAGER"},
    {"Coollock", "OtherRealm", "WARLOCK", "DAMAGER"},
}
local scans, nameReads, leader = 0, 0, true
GetNormalizedRealmName = function() return "Realm" end
GetNumGroupMembers = function() scans = scans + 1; return #roster end
UnitFullName = function(unit)
    if unit == "player" then return "Caller", "Realm" end
    if unit == "raid8" then return "Leader", "Realm" end
    local index = tonumber(unit:match("^raid(%d+)$"))
    if index then nameReads = nameReads + 1; local p = roster[index]; return p and p[1], p and p[2] end
end
UnitClass = function(unit) local p = roster[tonumber(unit:match("%d+$"))]; return "", p and p[3] end
UnitGroupRolesAssigned = function(unit) local p = roster[tonumber(unit:match("%d+$"))]; return p and p[4] end
UnitInRaid = function(unit) return unit == "Leader-Realm" and 8 or nil end
UnitIsGroupLeader = function(unit) return unit == "raid8" or unit == "player" and leader end
RAID_CLASS_COLORS = {WARLOCK = {r = 0.6, g = 0.4, b = 0.9}, MAGE = {r = 0.2, g = 0.7, b = 0.9}}

local profile = M:GetProfile()
profile.slots = M:DefaultSlots()
check(M.BAIT_SLOT == 20 and profile.slots[20].x == 0.5079326782226562 and profile.slots[20].y == 0.3810766672327898, "Fury bait default does not match the saved layout")
check(M:Role(M.BAIT_SLOT) == "DAMAGER", "Fury bait no longer uses damage players")
profile.slots[13].member = {name = "Coollock-Sargeras", class = "WARLOCK"}
profile.slots[20].member = {name = "Coollock-OtherRealm", class = "WARLOCK"}
profile.slots[12].member = {name = "Healy-Realm", class = "PRIEST"}
profile.slots[6].member = {name = "Tanky-Realm", class = "WARRIOR"}
profile.slots[8].member = {name = "Caller-Realm", class = "MAGE"}
check(#profile.slots == 20, "not twenty spots")
local counts = {DAMAGER = 0, TANK = 0, HEALER = 0}
for i = 1, 20 do counts[M:Role(i)] = counts[M:Role(i)] + 1 end
check(counts.DAMAGER == 14 and counts.TANK == 2 and counts.HEALER == 4, "role allocation changed")
local seenNumbers = {}
for i = 1, 20 do
    local number = M:DisplayNumber(i)
    if M:Role(i) == "DAMAGER" then
        check(number and number >= 1 and number <= 14 and not seenNumbers[number], "damage numbers are not a permutation of 1-14")
        seenNumbers[number] = true
    else
        check(number == nil and not M:PositionLabel(i):find("%d"), "tank or healer still has a display number")
    end
end
check(M:DisplayNumber(18) == 2 and M:DisplayNumber(19) == 9 and M:DisplayNumber(17) == 6
    and M:DisplayNumber(15) == 12 and M:DisplayNumber(20) == 14, "requested number mapping changed")

SH.OptionsUI:SelectPage("mythic")
check(SH.OptionsUI.page == "mythic" and SH.OptionsUI.mythicPage:IsShown(), "sidebar did not open the tab")
check(SH.OptionsUI.header.title:GetText() == "Mythic Positions", "wrong page title")
check(scans == 1 and nameReads == #roster, "opening did not take exactly one snapshot")
check(UI.draft.slots[13].member.name == "Coollock-Sargeras", "present player lost assignment")
check(not UI.buttons[2].number:IsShown() and UI.buttons[2].role:IsShown(), "empty tank has a number instead of an icon")
check(UI.boss and not rawget(UI.room, "markers"), "boss icon or marker-free assignment room missing")
check(UI.buttons[20].bait:GetText() == "14 - FURY BAIT" and not UI.buttons[20].number:IsShown(), "bait marker label missing or duplicated")
for i = 1, 20 do
    if M:Role(i) ~= "DAMAGER" then check(not UI.buttons[i].number:IsShown(), "role icon has a numeric badge") end
end
check(UI.buttons[18].number:GetText() == "2" and UI.buttons[19].number:GetText() == "9"
    and UI.buttons[17].number:GetText() == "6" and UI.buttons[15].number:GetText() == "12", "number badges were not updated")
UI.buttons[20].scripts.OnClick()
check(UI.pickerTitle:GetText():find("Serpent's Fury bait", 1, true), "bait picker is not identified")
UI.buttons[12].scripts.OnClick()
check(not UI.pickerTitle:GetText():find("%d"), "healer picker still shows an internal number")
UI.buttons[2].scripts.OnClick()
check(not UI.pickerTitle:GetText():find("%d"), "tank picker still shows an internal number")
UI.buttons[18].scripts.OnClick()
check(UI.pickerTitle:GetText():find("Position 2", 1, true), "picker shows old internal number")
UI.buttons[13].scripts.OnClick()
check(UI.picker:IsShown(), "position did not open picker")
for _, p in ipairs(M:Candidates(UI.draft, 13)) do
    check(p.role == "DAMAGER" and p.name ~= "Caller-Realm" and p.name ~= "Coollock-OtherRealm", "picker included wrong role or assigned player")
end
check(not M:Assign(UI.draft, 13, "Caller-Realm"), "duplicate assignment accepted")
check(M:Assign(UI.draft, 2, nil), "empty tank could not clear")
for _, member in ipairs(M:Candidates(UI.draft, 2)) do
    check(member.name ~= "Tanky-Realm", "assigned tank offered twice")
end
check(M:Assign(UI.draft, 6, nil) and M:Assign(UI.draft, 2, "Tanky-Realm"), "tank assignment failed")
check(M:Assign(UI.draft, 12, nil), "healer clear failed")
local candidates = M:Candidates(UI.draft, 12)
check(#candidates > 1 and candidates[1].role == "HEALER" and candidates[2].role == "DAMAGER", "matching role was not listed first")
check(M:Assign(UI.draft, 13, "Healy-Realm"), "off-role manual assignment failed")
check(M:Assign(UI.draft, 12, "Coollock-Sargeras"), "DPS could not take a healer slot")
check(M:Save(UI.draft) and profile.slots[13].member.name == "Healy-Realm", "off-role assignment was not saved")
check(M:Assign(UI.draft, 13, nil) and M:Assign(UI.draft, 12, nil), "could not clear off-role assignments")
check(M:Assign(UI.draft, 12, "Healy-Realm") and M:Assign(UI.draft, 13, "Coollock-Sargeras"), "could not restore assignments")
check(scans == 1, "picker rescanned the raid")

UI.move.scripts.OnClick(UI.move)
UI.buttons[8].scripts.OnDragStart(UI.buttons[8])
check(UI.buttons[8].scripts.OnUpdate ~= nil, "drag has no cursor update")
check(UI:SetPosition(8, 2, -1), "drag failed")
check(UI.draft.slots[8].x == 0.96 and UI.draft.slots[8].y == 0.04, "drag escaped room bounds")
UI.buttons[8].scripts.OnDragStop()
check(not UI.buttons[8].scripts.OnUpdate, "cursor polling continued after drag")
UI:SetPosition(8, 0.42, 0.68)
UI.save.scripts.OnClick(UI.save)
check(profile.slots[8].x == 0.42 and scans == 1, "save lost coordinates or rescanned")
UI:SetPosition(8, 0.2, 0.3)
UI.revert.scripts.OnClick(UI.revert)
check(UI.draft.slots[8].x == 0.42 and scans == 1, "revert lost saved coordinates or rescanned")

-- Same short name on another realm must not occupy an absent player's slot.
roster[2] = {"Different", "Sargeras", "WARLOCK", "DAMAGER"}
SH.OptionsUI:SelectPage("configuration")
SH.OptionsUI:SelectPage("mythic")
check(scans == 2, "reopening did not refresh snapshot")
local grey = UI.buttons[13].fill.vertexColor
check(UI.draft.slots[13].member.name == "Coollock-Sargeras" and UI.buttons[13].label:GetText() == "Cool"
    and grey[1] == grey[2] and grey[2] == grey[3], "absent player did not show a grey named circle")
check(M:Save(UI.draft) and profile.slots[13].member.name == "Coollock-Sargeras", "saving erased absent assignment")
check(UI.draft.slots[20].member.name == "Coollock-OtherRealm", "cross-realm identity mixed")
check(M:Assign(UI.draft, 13, "Newlock-Sargeras"), "replacement failed")
check(M:Save(UI.draft), "replacement not saved")
check(profile.slots[13].member.name == "Newlock-Sargeras", "saved replacement not remembered")
local initialID = profile.id
local newID = M:NewProfile("Alternate", UI.draft.slots)
check(newID and M:GetProfile().slots[13].member.name == "Newlock-Sargeras", "profile copy lost assignments")
check(M:RenameProfile("Alternate raid"), "rename failed")
check(M:SelectProfile(initialID) and scans == 2, "profile switch scanned raid")
local draft = M:DraftFromSnapshot()
local invalid = M:Copy(draft)
invalid.slots[1].member = M:Copy(invalid.slots[8].member)
check(not M:Save(invalid), "duplicate saved plan accepted")
invalid = M:Copy(draft); invalid.slots[1].x = 0 / 0
check(not M:Validate(invalid.slots), "NaN coordinate accepted")

-- Publishing is paced, uses full names, and commits only a complete leader plan.
local packets = {}
C_ChatInfo.SendAddonMessage = function(_, message)
    check(not InCombatLockdown(), "sent during combat")
    check(#message <= 254, "packet exceeded addon-message limit")
    packets[#packets + 1] = message
    return Enum.SendAddonMessageResult.Success
end
check(M:Publish(draft), "leader publish failed")
while M.sendTimer do local timer = M.sendTimer; timer.callback() end
check(#packets == 22 and not M.publishing, "publish did not finish twenty slots atomically")
check(UI.publish:IsEnabled(), "publish button stayed disabled after completion")
check(scans == 2, "publishing scanned roster")
M.received = nil
SH.Comms:OnAddonMessage(packets[1], "Impostor-Realm")
check(not M.pending, "accepted non-leader plan")
for i = 1, #packets - 1 do SH.Comms:OnAddonMessage(packets[i], "Leader-Realm") end
check(not M.received, "partial plan applied before commit")
SH.Comms:OnAddonMessage(packets[#packets], "Leader-Realm")
check(M.received and M.received.slots[13].member.name == "Newlock-Sargeras", "complete leader plan not applied")
check(M.personal and M.personal.slot == 8 and M.personal.x == 0.42, "receiver static point incorrect")
check(scans == 2, "receiving scanned raid")
local received = M.received
SH.Comms:OnAddonMessage(packets[1], "Leader-Realm")
SH.Comms:OnAddonMessage(packets[2], "Leader-Realm")
SH.Comms:OnAddonMessage(packets[2], "Leader-Realm")
SH.Comms:OnAddonMessage(packets[#packets], "Leader-Realm")
check(M.received == received and not M.pending, "duplicate packet replaced plan")
local testTime = 100
GetTime = function() return testTime end
SH.Comms:OnAddonMessage(packets[1], "Leader-Realm")
testTime = 121
SH.Comms:OnAddonMessage(packets[2], "Leader-Realm")
check(not M.pending and M.received == received, "expired transfer applied")
SH.Comms:OnAddonMessage(env.secret(), "Leader-Realm")
M:OnMessage(env.secret(), "Leader-Realm")
check(M.received == received, "secret data affected plan")

-- Sparse plans can publish and receive in Test Mode. Throttled packets retry unchanged.
local regularSend = C_ChatInfo.SendAddonMessage
for _, throttleResult in ipairs({Enum.SendAddonMessageResult.AddonMessageThrottle, Enum.SendAddonMessageResult.ChannelThrottle}) do
    local sparse = {slots = M:DefaultSlots(), previous = {}}
    sparse.slots[5].member = {name = "Caller-Realm", class = "MAGE"}
    sparse.slots[17].member = {name = "Newlock-Sargeras", class = "WARLOCK"}
    local accepted, attempts, rejected = {}, 0, nil
    C_ChatInfo.SendAddonMessage = function(_, message)
        attempts = attempts + 1
        if not rejected and message:match("^MPS|") then rejected = message; return throttleResult end
        accepted[#accepted + 1] = message
        return Enum.SendAddonMessageResult.Success
    end
    SH.Encounter.testMode = true
    check(not SH.Comms:Send("HELLO|ordinary-test-message"), "ordinary Test Mode message escaped")
    check(M:Publish(sparse), "two assigned characters could not publish in Test Mode")
    local callbacks = 0
    while M.sendTimer do
        local timer = M.sendTimer
        testTime = testTime + timer.delay
        timer.callback()
        callbacks = callbacks + 1
        check(callbacks <= 25, "publication retry did not finish")
    end
    check(#accepted == 22 and attempts == 23 and not M.publishing, "throttle lost a packet or retried forever")
    check(accepted[2] == rejected, "throttle retry changed the rejected packet")
    for _, message in ipairs(accepted) do SH.Comms:OnAddonMessage(message, "Leader-Realm") end
    check(M.received and M.received.slots[5].member.name == "Caller-Realm"
        and M.received.slots[17].member.name == "Newlock-Sargeras" and not M.received.slots[1].member,
        "receiver rejected sparse configuration while in Test Mode")
    check(M.personal and M.personal.slot == 5, "sparse publication did not update the personal position")
end
SH.Encounter.testMode = false
local throttleAttempts = 0
C_ChatInfo.SendAddonMessage = function() throttleAttempts = throttleAttempts + 1; return Enum.SendAddonMessageResult.AddonMessageThrottle end
check(M:Publish(draft), "throttled publication was not queued")
while M.sendTimer do
    local timer = M.sendTimer
    testTime = testTime + timer.delay
    timer.callback()
    check(throttleAttempts <= 4, "unbounded throttle retries")
end
check(throttleAttempts == 4 and not M.publishing and UI.message:find("AddonMessageThrottle", 1, true), "persistent throttle hid its cause")
C_ChatInfo.SendAddonMessage = regularSend
check(M:Save(draft), "sparse-plan test did not restore regular saved assignments")
check(scans == 2, "sparse publication or retry scanned the raid")

-- Only an opening scan can reconcile a changed raid; combat never reads live names.
SH.Store:Options().previewFrames = true
SH.Store:Options().showMythicPosition = true
M:RefreshPersonal()
SH.RoomMap:RefreshMythicPosition()
check(SH.RoomMap.frame.mythicDot:IsShown(), "enabled static dot did not show in preview")
local point = SH.RoomMap.frame.mythicDot.point
local beforeNames, beforeScans = nameReads, scans
check(M:Publish(draft), "second publish failed")
local timer = M.sendTimer
UI.move.scripts.OnClick(UI.move)
UI.buttons[8].scripts.OnDragStart(UI.buttons[8])
env.setCombat(true)
env.fire("PLAYER_REGEN_DISABLED")
check(timer.cancelled and not M.publishing, "combat did not cancel publication")
check(not UI.buttons[8].scripts.OnUpdate, "combat left drag polling active")
check(not M:ScanRoster() and not M:Save(draft) and not M:Assign(draft, 13, nil) and not M:Publish(draft), "combat allowed edits or roster scan")
check(not UI:SetPosition(8, 0.5, 0.5), "combat allowed dragging")
SH.Comms:OnAddonMessage(packets[1], "Leader-Realm")
SH.RoomMap:RefreshMythicPosition()
check(nameReads == beforeNames and scans == beforeScans, "combat read the raid")
check(SH.RoomMap.frame.mythicDot.point[4] == point[4], "static dot moved during combat")
env.setCombat(false)
env.fire("PLAYER_REGEN_ENABLED")
check(scans == beforeScans, "leaving combat rescanned roster")
SH.Store:Options().showMythicPosition = false
SH.RoomMap:RefreshMythicPosition()
check(not SH.RoomMap.frame.mythicDot:IsShown(), "dot toggle did not hide dot")
env.setLockdown(true)
check(not M:ScanRoster() and not M:Publish(draft), "chat lockdown ignored")
env.setLockdown(false)
leader = false
local oldSend = C_ChatInfo.SendAddonMessage
C_ChatInfo.SendAddonMessage = function() return Enum.SendAddonMessageResult.GeneralError end
leader = true
check(not M:Publish(draft) and not M.publishing, "failed send reported publication success")
check(UI.message:find("GeneralError", 1, true), "publisher hid the actual send failure")
C_ChatInfo.SendAddonMessage = oldSend
leader = false
check(not M:Publish(draft), "non-leader could publish")
leader = true

-- Reject unreadable snapshot data before any string operations.
roster[2] = {env.secret(), "Sargeras", "WARLOCK", "DAMAGER"}
check(M:ScanRoster(), "public roster entries were blocked by one unreadable entry")
check(#M.roster == #roster - 1, "unreadable entry not skipped")
env.fire("GROUP_LEFT")
check(not M.received and not M.personal and not M.pending, "previous raid plan survived leaving")
check(not UI.buttons[8].scripts.OnUpdate, "drag update leaked")
local saved = M:Copy(M.db)
saved.profiles[#saved.profiles + 1] = {id = "broken", name = "Broken", slots = {}}
saved.baitPositionVersion = nil
saved.defaultPositionsVersion = nil
saved.profiles[1].slots[1].x, saved.profiles[1].slots[1].y = 0.35, 0.9
saved.profiles[1].slots[8].x = 0.43
saved.profiles[1].slots[20].x, saved.profiles[1].slots[20].y = 0.3, 0.38
saved.profiles[2].slots[20].x, saved.profiles[2].slots[20].y = 0.62, 0.45
SH.Store.db.mythicPositions = saved
local countBeforeReload = scans
M:OnInitialize()
check(#M.db.profiles == 2 and M:GetProfile().slots[13].member.name == "Newlock-Sargeras", "reload damaged saved profile names or members")
check(M:GetProfile().slots[8].x == 0.43 and scans == countBeforeReload, "reload changed custom coordinates or scanned raid")
local defaults = M:DefaultSlots()
check(M.db.profiles[1].slots[20].x == defaults[20].x and M.db.profiles[1].slots[20].y == defaults[20].y, "old factory bait position was not updated")
check(M.db.profiles[1].slots[1].x == defaults[1].x and M.db.profiles[1].slots[1].y == defaults[1].y, "old factory layout was not updated")
check(M.db.profiles[1].slots[20].member.name == "Coollock-OtherRealm", "bait migration lost assigned player")
check(M.db.profiles[2].slots[20].x == 0.62 and M.db.profiles[2].slots[20].y == 0.45, "bait migration changed a custom position")
M.db.profiles[1].slots[20].x, M.db.profiles[1].slots[20].y = 0.3, 0.38
M:OnInitialize()
check(M.db.profiles[1].slots[20].x == 0.3 and M.db.profiles[1].slots[20].y == 0.38, "bait migration ran more than once")
print("Mythic position checks passed: roles, snapshots, saved identities, profiles, dragging, static dot and atomic publishing.")
