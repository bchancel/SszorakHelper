local SH, env = ...
local M, UI = SH.MythicPositions, SH.MythicPositionsUI
local function check(value, message) assert(value, "Mythic groups: " .. message) end
local names = {"GetNumGroupMembers", "UnitFullName", "GetNormalizedRealmName", "GetRaidRosterInfo",
    "UnitIsGroupLeader", "UnitIsGroupAssistant", "SetRaidSubgroup", "SwapRaidSubgroup",
    "UnitClass", "UnitGroupRolesAssigned", "UnitGUID", "C_SpecializationInfo", "CanInspect", "NotifyInspect"}
local originals = {}
for _, name in ipairs(names) do originals[name] = _G[name] end
local saved = {draft = UI.draft, dirty = UI.dirty, message = UI.message, personal = M.personal, received = M.received,
    pageShown = UI.page:IsShown(), roster = M.roster, byName = M.rosterByName}
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

local inspected, delaySpec
local function unitMember(unit) return roster[tonumber(unit:match("%d+$"))] end
UnitClass = function(unit) return "", unitMember(unit).class end
UnitGroupRolesAssigned = function(unit) return unitMember(unit).role end
UnitGUID = function(unit) return unitMember(unit).name end
CanInspect = function() return true end
NotifyInspect = function(unit) inspected = UnitGUID(unit) end
C_SpecializationInfo = {GetInspectSpecialization = function(unit)
    local member = unitMember(unit)
    if member.name == delaySpec then return 0 end
    return member.spec or 0
end}
local function add(name, class, role, spec)
    roster[#roster + 1] = {name = name, realm = "Realm", class = class, role = role, spec = spec,
        group = math.floor(#roster / 5) + 1}
end
local function resetAuto()
    setup(20)
    roster = {}
    local plan = {slots = M:DefaultSlots()}
    plan.slots[6].x = 0.86
    UI.draft, UI.dirty = plan, false
    return plan
end
draft = resetAuto()
add("TankA", "DEATHKNIGHT", "TANK")
add("TankB", "WARRIOR", "TANK")
for i = 1, 5 do add("Healer" .. i, "PRIEST", "HEALER") end
add("Survival", "HUNTER", "DAMAGER", 255)
add("Feral", "DRUID", "DAMAGER", 103)
add("Enhancement", "SHAMAN", "DAMAGER", 263)
add("Havoc", "DEMONHUNTER", "DAMAGER", 577)
for _, class in ipairs({"WARRIOR", "MONK", "DEATHKNIGHT", "PALADIN"}) do add(class, class, "DAMAGER") end
add("Balance", "DRUID", "DAMAGER", 102)
add("Fire", "MAGE", "DAMAGER", 63)
add("Arcane", "MAGE", "DAMAGER", 62)
add("Marks", "HUNTER", "DAMAGER", 254)
add("BeastMaster", "HUNTER", "DAMAGER", 253)
local savedSlots = M:GetProfile().slots
UI:Refresh()
check(UI.auto:IsShown() and UI.auto:IsEnabled(), "leader Auto Assign button unavailable")
UI.auto.scripts.OnClick(UI.auto)
check(M.organizing and not UI.auto:IsEnabled() and not draft.slots[6].member, "Auto Assign changed the draft before group confirmation")
finish()
local membersByName, seen = {}, {}
for _, member in ipairs(roster) do membersByName[member.name .. "-Realm"] = member end
for slot, point in ipairs(draft.slots) do
    local member = membersByName[point.member.name]
    check(member and not seen[member] and member.group == expected[slot], "Auto Assign left a duplicate or misgrouped player")
    seen[member] = true
    if M:Role(slot) ~= "DAMAGER" then check(member.role == M:Role(slot), "tank or healer role mismatch") end
    local display = M:DisplayNumber(slot)
    if display and display <= 8 then
        check(not ({Balance = true, Fire = true, Arcane = true, Marks = true, BeastMaster = true})[member.name],
            "ranged player took a melee priority spot")
    end
end
check(draft.slots[20].member.name == "BeastMaster-Realm" and membersByName["BeastMaster-Realm"].group == 1, "Fury bait priority or side wrong")
check(membersByName[draft.slots[13].member.name].role == "HEALER" and expected[13] % 2 == 0, "fifth healer not in even position 13")
check(draft.slots[6].x == 0.86 and UI.dirty and M:GetProfile().slots == savedSlots, "Auto Assign lost coordinates or saved without review")

-- Four melee fit the first tier, and later bait choices are used in order.
local baitOrder = {{"BeastMaster", "HUNTER", 253}, {"Marks", "HUNTER", 254}, {"Arcane", "MAGE", 62},
    {"Fire", "MAGE", 63}, {"Balance", "DRUID", 102}}
for first = 1, #baitOrder do
    draft = resetAuto()
    for i = first, #baitOrder do
        local bait = baitOrder[i]
        add(bait[1], bait[2], "DAMAGER", bait[3])
    end
    for i = 1, 4 do add("Rogue" .. i, "ROGUE", "DAMAGER") end
    draft.slots[16].member = {name = "Away-Realm", class = "PRIEST"}
    check(M:AutoAssign(draft), "sparse Auto Assign failed")
    finish()
    for _, slot in ipairs({1, 18, 5, 17}) do
        check(draft.slots[slot].member.name:match("^Rogue"), "melee skipped a tier 1 spot")
    end
    check(draft.slots[20].member.name == baitOrder[first][1] .. "-Realm", "incorrect fallback in Fury order")
    check(draft.slots[16].member.name == "Away-Realm", "unused absent assignment was dropped")
end

-- Inspect results must match the requested GUID, and late results after combat are ignored.
draft = resetAuto()
add("Marks", "HUNTER", "DAMAGER", 254)
add("BeastMaster", "HUNTER", "DAMAGER", 253)
delaySpec = "BeastMaster"
check(M:AutoAssign(draft) and M.autoAssign and inspected == "BeastMaster" and #actions == 0, "inspect did not precede group moves")
local timer = M.autoAssign.timer
delaySpec = nil
env.fire("INSPECT_READY", "Marks")
check(not M.autoAssign.inspecting.spec, "wrong GUID supplied an inspected spec")
env.fire("INSPECT_READY", "BeastMaster")
timer.callback()
finish()
check(draft.slots[20].member.name == "BeastMaster-Realm", "inspected spec did not take priority")
draft = resetAuto()
add("Unknown", "HUNTER", "DAMAGER")
check(M:AutoAssign(draft) and M.autoAssign, "unavailable spec did not start a bounded inspection")
M.autoAssign.timer.callback()
finish()
check(draft.slots[20].member.name == "Unknown-Realm" and UI.message:find("Specs unavailable for 1", 1, true), "unknown-spec fallback was not reported")
draft = resetAuto()
add("Unknown", "HUNTER", "DAMAGER")
check(M:AutoAssign(draft) and M.autoAssign, "could not start interrupted inspection")
timer = M.autoAssign.timer
env.setCombat(true)
env.fire("PLAYER_REGEN_DISABLED")
timer.callback()
env.fire("INSPECT_READY", "Unknown")
check(timer.cancelled and not M.autoAssign and not M.organizing and #actions == 0 and not draft.slots[20].member,
    "combat let a late inspection apply assignments")
env.setCombat(false)

draft = resetAuto()
add("TankA", "WARRIOR", "TANK")
add("TankB", "PALADIN", "TANK")
leader, assistant = false, true
check(M:AutoAssign(draft) and M.groupTimer, "assistant could not start Auto Assign")
M.groupTimer.callback()
check(not M.organizing and not draft.slots[2].member and not draft.slots[6].member and not UI.dirty,
    "unconfirmed group move committed the Auto Assign draft")

draft = setup(20)
SetRaidSubgroup, SwapRaidSubgroup = function() error("rejected") end, function() error("rejected") end
check(M:OrganizeGroups(draft) and not M.organizing and not M.groupTimer, "API failure did not stop run")
check(UI.message:find("Could not change", 1, true), "API failure claimed success")

for _, name in ipairs(names) do _G[name] = originals[name] end
UI.draft, UI.dirty, UI.message = saved.draft, saved.dirty, saved.message
M.personal, M.received, M.roster, M.rosterByName = saved.personal, saved.received, saved.roster, saved.byName
UI.page:SetShown(saved.pageShown)
env.setCombat(false); env.setLockdown(false); env.setRaid(true)
UI:Refresh()
print("Mythic group checks passed: organization, auto assignment, melee tiers, Fury priorities, inspection and cancellation.")
