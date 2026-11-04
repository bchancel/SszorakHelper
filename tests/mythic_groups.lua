local SH, env = ...
local M, UI = SH.MythicPositions, SH.MythicPositionsUI
local function check(value, message) assert(value, "Mythic groups: " .. message) end
local names = {"GetNumGroupMembers", "UnitFullName", "GetNormalizedRealmName", "GetRaidRosterInfo",
    "UnitIsGroupLeader", "UnitIsGroupAssistant", "SetRaidSubgroup", "SwapRaidSubgroup"}
local originals = {}
for _, name in ipairs(names) do originals[name] = _G[name] end
local saved = {draft = UI.draft, message = UI.message, personal = M.personal, received = M.received, pageShown = UI.page:IsShown()}
UI.page:Show()
local roster, pending, actions, scans, leader, assistant = {}, nil, {}, 0, true, false
local expected = {}
for group, slots in ipairs({{2, 7, 11, 19, 20}, {6, 13, 16, 17, 18}, {1, 3, 5, 9, 14}, {4, 8, 10, 12, 15}}) do
    for _, slot in ipairs(slots) do expected[slot] = group end
end
GetNumGroupMembers = function() scans = scans + 1; return #roster end
GetNormalizedRealmName = function() return "Realm" end
UnitFullName = function(unit)
    if unit == "player" then return "Caller", "Realm" end
    local member = roster[tonumber(unit:match("%d+$"))]
    if member then return member.name, member.realm end
end
GetRaidRosterInfo = function(index) return roster[index].name, 0, roster[index].group end
UnitIsGroupLeader = function(unit) return unit == "player" and leader end
UnitIsGroupAssistant = function(unit) return unit == "player" and assistant end
local function counts()
    local result = {0, 0, 0, 0, 0, 0, 0, 0}
    for _, member in ipairs(roster) do result[member.group] = result[member.group] + 1 end
    return result
end
local function request(first, second, group)
    check(not InCombatLockdown() and M:CanOrganizeGroups(), "mutation without permission")
    check(not pending, "sent another operation before the first was confirmed")
    check(first and (second or group), "invalid live raid index")
    pending = {first = first, second = second, group = group}
    actions[#actions + 1] = pending
end
SetRaidSubgroup = function(index, group)
    check(counts()[group] < 5, "moved into a full group")
    request(roster[index], nil, group)
end
SwapRaidSubgroup = function(first, second) request(roster[first], roster[second]) end
local function confirm()
    local operation = pending
    check(operation, "no operation awaiting server confirmation")
    pending = nil
    if operation.second then
        operation.first.group, operation.second.group = operation.second.group, operation.first.group
    else
        operation.first.group = operation.group
    end
    -- Simulate raid indexes changing after every server update.
    table.sort(roster, function(a, b)
        if #actions % 2 == 0 then return a.name < b.name end
        return a.name > b.name
    end)
    for _, count in ipairs(counts()) do check(count <= 5, "exceeded five players per group") end
    env.fire("GROUP_ROSTER_UPDATE")
end
local function finish()
    local iterations = 0
    while M.organizing do
        confirm()
        iterations = iterations + 1
        check(iterations <= 40, "unbounded reorganization")
    end
    check(not M.groupTimer, "completed run left a timer")
end
local function setup(size, omit)
    roster, pending, actions = {}, nil, {}
    leader, assistant = true, false
    env.setCombat(false); env.setLockdown(false); env.setRaid(true)
    SH.Encounter.active = false
    local draft = {slots = M:DefaultSlots(), previous = {}}
    for slot = 1, 20 do
        check(M:GroupForSlot(slot) == expected[slot], "formation group mapping changed for slot " .. slot)
        draft.slots[slot].member = {name = "Position" .. slot .. "-Realm", class = "MAGE"}
        if slot ~= omit then
            roster[#roster + 1] = {name = "Position" .. slot, realm = "Realm", group = expected[slot] % 4 + 1, slot = slot}
        end
    end
    for i = 21, size do
        roster[#roster + 1] = {name = "Extra" .. i, realm = "Realm", group = math.floor((i - 21) / 5) + 5}
    end
    UI.draft = draft
    return draft
end
local function organized()
    for _, member in ipairs(roster) do
        if member.slot then check(member.group == expected[member.slot], "player ended in wrong group: " .. member.name) end
    end
end

-- Full groups require swaps; resolve each subsequent index from the new roster.
local draft = setup(40)
UI:Refresh()
check(UI.organize:IsShown() and UI.organize:IsEnabled(), "leader button unavailable")
UI.organize.scripts.OnClick(UI.organize)
check(M.organizing and not UI.organize:IsEnabled(), "button did not start or disable during organization")
local before = #actions
check(not M:OrganizeGroups(draft) and #actions == before, "repeat click started a concurrent run")
env.fire("GROUP_ROSTER_UPDATE")
check(#actions == before, "unrelated roster event advanced an unconfirmed operation")
finish()
organized()
for _, member in ipairs(roster) do
    if not member.slot then check(member.group >= 5, "unrelated group was reorganized") end
end
check(UI.organize:IsEnabled() and UI.message:find("20 assigned", 1, true), "success was not confirmed")
local completedActions, completedScans = #actions, scans
check(M:OrganizeGroups(draft) and not M.organizing and #actions == completedActions, "already organized raid was changed")
local idleScans = scans
env.fire("GROUP_ROSTER_UPDATE")
check(scans == idleScans and completedScans < scans, "idle event enumerated the raid")

-- A 19-player formation leaves its absent member's place open.
draft = setup(20, 12)
check(M:OrganizeGroups(draft), "partial roster rejected")
finish(); organized()
check(UI.message:find("19 assigned", 1, true) and UI.message:find("Skipped 1", 1, true), "absent member not reported")

-- Use the displayed draft, including unsaved assignments and same-name realms.
draft = {slots = M:DefaultSlots(), previous = {}}
draft.slots[19].member = {name = "Twin-OtherRealm", class = "DRUID"}
draft.slots[19].x = 0.9
roster = {{name = "Twin", realm = "Realm", group = 2}, {name = "Twin", realm = "OtherRealm", group = 3}}
actions, pending, UI.draft = {}, nil, draft
UI.organize.scripts.OnClick(UI.organize)
check(pending.first.realm == "OtherRealm" and pending.group == 1, "short-name match or dragged coordinates changed target")
finish()
for _, member in ipairs(roster) do
    check(member.group == (member.realm == "OtherRealm" and 1 or 2), "moved wrong same-name player")
end

-- Swap an unassigned occupant only when needed to fit a planned member.
roster, actions, pending = {{name = "Twin", realm = "OtherRealm", group = 5}}, {}, nil
for i = 1, 5 do roster[#roster + 1] = {name = "Unassigned" .. i, realm = "Realm", group = 1} end
check(M:OrganizeGroups(draft), "full group with unassigned occupants rejected")
check(pending.second and pending.second.name:find("Unassigned", 1, true), "did not swap an unassigned occupant")
finish()
check(#actions == 1, "unassigned players caused unnecessary moves")

-- Permissions update button visibility without taking an editor snapshot.
leader, assistant = false, false
idleScans = scans
env.fire("GROUP_ROSTER_UPDATE")
check(not UI.organize:IsShown() and not M:OrganizeGroups(draft) and scans == idleScans, "ordinary member could organize or read roster")
assistant = true
env.fire("GROUP_ROSTER_UPDATE")
check(UI.organize:IsShown() and UI.organize:IsEnabled() and scans == idleScans, "assistant promotion did not show button")
roster[1].group = 2
check(M:OrganizeGroups(draft), "assistant could not organize")
finish()

-- Interruptions stop further writes, including late events/timers.
for _, interruption in ipairs({"combat", "permission", "lockdown", "roster", "leader", "leave", "timeout"}) do
    draft = setup(20)
    check(M:OrganizeGroups(draft), "could not prepare interrupted run")
    local timer, writes, reads = M.groupTimer, #actions, scans
    if interruption == "combat" then env.setCombat(true); env.fire("PLAYER_REGEN_DISABLED")
    elseif interruption == "permission" then leader = false; env.fire("GROUP_ROSTER_UPDATE")
    elseif interruption == "lockdown" then env.setLockdown(true); env.fire("GROUP_ROSTER_UPDATE")
    elseif interruption == "roster" then roster[1].name = "Replacement"; env.fire("GROUP_ROSTER_UPDATE")
    elseif interruption == "leader" then env.fire("PARTY_LEADER_CHANGED")
    elseif interruption == "leave" then env.setRaid(false); env.fire("GROUP_LEFT")
    else timer.callback() end
    check(not M.organizing and not M.groupTimer, "interruption left active run: " .. interruption)
    if interruption == "combat" or interruption == "permission" or interruption == "lockdown" then
        check(scans == reads, "restricted event scanned roster")
    end
    env.fire("GROUP_ROSTER_UPDATE")
    timer.callback()
    check(#actions == writes, "late event resumed cancelled run")
    pending = nil
end

-- Preflight rejects lockdown, duplicate assignments, and unreadable roster data.
draft = setup(20)
env.setCombat(true)
check(not M:OrganizeGroups(draft) and #actions == 0, "combat start allowed mutations")
env.setCombat(false); env.setLockdown(true)
check(not M:OrganizeGroups(draft) and #actions == 0, "lockdown start allowed mutations")
env.setLockdown(false)
draft.slots[2].member = M:Copy(draft.slots[1].member)
check(not M:OrganizeGroups(draft) and #actions == 0, "duplicate plan allowed mutations")
draft = setup(20)
roster[1].group = env.secret()
check(not M:OrganizeGroups(draft) and #actions == 0, "unreadable subgroup allowed mutations")
draft = setup(20)
SetRaidSubgroup, SwapRaidSubgroup = function() error("rejected") end, function() error("rejected") end
check(M:OrganizeGroups(draft) and not M.organizing and not M.groupTimer, "API failure did not stop run")
check(UI.message:find("Could not change", 1, true), "API failure claimed success")

for _, name in ipairs(names) do _G[name] = originals[name] end
UI.draft, UI.message, M.personal, M.received = saved.draft, saved.message, saved.personal, saved.received
UI.page:SetShown(saved.pageShown)
env.setCombat(false); env.setLockdown(false); env.setRaid(true)
UI:Refresh()
print("Mythic group checks passed: exact formation, full/partial raids, live indexes, permissions, missing players and cancellation.")
