local _, SH = ...

SH.MythicPositions = {initializeOrder = 20, BAIT_SLOT = 20}
SH.modules.MythicPositions = SH.MythicPositions
local M = SH.MythicPositions

local points = {
    -- Saved raid layout, 2026-10-25. Indices remain stable for saved assignments.
    {0.45578466796875, 0.8822593131982185},
    {0.49655517578125, 0.9552859459918478},
    {0.3581256510416667, 0.9472830479128924},
    {0.6292958984375, 0.9492838475618961},
    {0.41691064453125, 0.7752202884397644},
    {0.5050885009765625, 0.73820667553593},
    {0.3287330729166668, 0.8442455365904287},
    {0.6814440104166667, 0.8552494409533514},
    {0.3183030395507813, 0.6061587069746377},
    {0.6861847330729167, 0.7151984455200785},
    {0.4093253580729168, 0.6651801286043176},
    {0.7914290974934896, 0.7812226015247584},
    {0.5022439778645833, 0.6131612266945954},
    {0.21021435546875, 0.7792218018757547},
    {0.6131775716145833, 0.6621789935273249},
    {0.7013548787434896, 0.6041578643946256},
    {0.5999033203125, 0.7832233153117452},
    {0.561029296875, 0.87625712890625},
    {0.3296809895833333, 0.7212005439500301},
    {0.5079326782226562, 0.3810766672327898},
}
local legacyPoints = {
    {35, 90}, {50, 90}, {66, 90}, {62, 79}, {58, 69}, {50, 75}, {38, 78}, {42, 68},
    {70, 63}, {80, 75}, {82, 57}, {31, 62}, {21, 76}, {63, 49}, {44, 56}, {35, 49},
    {54, 56}, {19, 58}, {10, 67}, {50, 50},
}
local healers, tanks = {[9] = true, [12] = true, [14] = true, [16] = true}, {[2] = true, [6] = true}
local displayNumbers = {
    [1] = 1, [3] = 3, [4] = 4, [5] = 5, [7] = 7, [8] = 8, [10] = 10,
    [11] = 11, [13] = 13, [15] = 12, [17] = 6, [18] = 2, [19] = 9, [20] = 14,
}
-- Fixed position-to-group assignments from the raid's saved formation.
-- Groups 1/3 are left and 2/4 are right; dragging a circle keeps its group.
local positionGroups = {3, 1, 3, 4, 3, 2, 1, 4, 3, 4, 1, 4, 2, 3, 4, 2, 2, 2, 1, 1}
local classes = {}
for class in ("WARRIOR PALADIN HUNTER ROGUE PRIEST DEATHKNIGHT SHAMAN MAGE WARLOCK MONK DRUID DEMONHUNTER EVOKER"):gmatch("%S+") do classes[class] = true end

local function secret(value) return type(issecretvalue) == "function" and issecretvalue(value) end
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end
local function identity(name) return name:gsub("%s+", ""):lower() end
local function senderName(name)
    if type(name) ~= "string" then return nil end
    if not name:find("-", 1, true) then
        local realm = GetNormalizedRealmName()
        if secret(realm) or type(realm) ~= "string" then return nil end
        name = name .. "-" .. realm
    end
    return name:gsub("%s+", "")
end
local function raidIndex(index)
    return not secret(index) and type(index) == "number" and index >= 1 and index <= 40 and index % 1 == 0
end
local function validName(name)
    return type(name) == "string" and #name <= 128 and name:match("^[^-]+%-.+$") and not name:find("[%c|,;]") and not name:find("%s")
end
local function profileName(name)
    if type(name) ~= "string" then return nil end
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" or #name > 40 or name:find("[%c|]") then return nil end
    return name
end
local function fullName(unit)
    local name, realm = UnitFullName(unit)
    if secret(name) or secret(realm) or type(name) ~= "string" then return nil end
    if not realm or realm == "" then realm = GetNormalizedRealmName() end
    if secret(realm) or type(realm) ~= "string" then return nil end
    local result = name .. "-" .. realm:gsub("%s+", "")
    return validName(result) and result or nil
end

function M:Role(slot) return healers[slot] and "HEALER" or tanks[slot] and "TANK" or "DAMAGER" end
function M:DisplayNumber(slot) return displayNumbers[slot] end
function M:GroupForSlot(slot) return positionGroups[slot] end
function M:PositionLabel(slot)
    if slot == self.BAIT_SLOT then return tostring(self:DisplayNumber(slot)) .. " - Fury Bait" end
    local number = self:DisplayNumber(slot)
    return number and ("Position " .. number) or self:Role(slot) == "TANK" and "Tank position" or "Healer position"
end
function M:DefaultSlots()
    local slots = {}
    for i, point in ipairs(points) do slots[i] = {x = point[1], y = point[2]} end
    return slots
end
function M:Copy(value) return copy(value) end
function M:Validate(slots)
    if type(slots) ~= "table" then return nil end
    local result, seen = {}, {}
    for i = 1, 20 do
        local slot = slots[i]
        if type(slot) ~= "table" then return nil end
        local x, y = slot.x, slot.y
        if type(x) ~= "number" or type(y) ~= "number" or x ~= x or y ~= y or x < 0.04 or x > 0.96 or y < 0.04 or y > 0.96 then return nil end
        local member = slot.member
        if member ~= nil then
            if type(member) ~= "table" or not validName(member.name) or not classes[member.class] then return nil end
            local key = identity(member.name)
            if seen[key] then return nil end
            seen[key] = true
        end
        result[i] = {x = x, y = y, member = member and {name = member.name, class = member.class} or nil}
    end
    return result
end
function M:CanEdit()
    return not InCombatLockdown() and not (SH.Encounter and SH.Encounter.active)
        and not (C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown())
end
function M:GetProfile()
    for _, profile in ipairs(self.db.profiles) do if profile.id == self.db.active then return profile end end
    return self.db.profiles[1]
end
function M:OnInitialize()
    local db = SH.Store.db.mythicPositions
    if type(db) ~= "table" then db = {} end
    local migrateDefaults = db.defaultPositionsVersion ~= 1
    local profiles, ids, names = {}, {}, {}
    for _, profile in ipairs(type(db.profiles) == "table" and db.profiles or {}) do
        if #profiles >= 10 then break end
        if type(profile) == "table" then
            local name, slots = profileName(profile.name), self:Validate(profile.slots)
            -- Upgrade untouched factory locations once; keep custom positions and identities.
            if slots and migrateDefaults then
                for i, slot in ipairs(slots) do
                    local old = legacyPoints[i]
                    local oldDefault = slot.x == old[1] / 100 and slot.y == old[2] / 100
                    local originalBait = i == self.BAIT_SLOT and slot.x == 0.3 and slot.y == 0.38
                    if oldDefault or originalBait then slot.x, slot.y = points[i][1], points[i][2] end
                end
            end
            if type(profile.id) == "string" and name and slots and not ids[profile.id] and not names[name:lower()] then
                profiles[#profiles + 1] = {id = profile.id, name = name, slots = slots}
                ids[profile.id], names[name:lower()] = true, true
            end
        end
    end
    if #profiles == 0 then profiles[1] = {id = "mythic-1", name = "Mythic progression", slots = self:DefaultSlots()} end
    db.profiles = profiles
    db.baitPositionVersion = 1
    db.defaultPositionsVersion = 1
    if not ids[db.active] then db.active = profiles[1].id end
    local nextID = tonumber(db.nextID)
    db.nextID = nextID and nextID == nextID and nextID >= 2 and nextID < 1000000 and math.floor(nextID) or 2
    self.db, SH.Store.db.mythicPositions = db, db
    self.roster, self.rosterByName = {}, {}
    if self:CanEdit() then self.playerName = fullName("player") end
    SH:RegisterEvent("INSPECT_READY", function(_, guid) self:AutoAssignInspectReady(guid) end)
    SH:RegisterEvent("PLAYER_REGEN_DISABLED", function()
        self:CancelAutoAssign("Auto Assign stopped by combat.")
        self:FinishGroupOrganization("Group organization stopped by combat. Some players may already have moved.")
        self:CancelPublish()
        self.pending = nil
        if SH.MythicPositionsUI then SH.MythicPositionsUI:LockForCombat() end
    end)
    SH:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        -- No roster scan here. A fresh snapshot requires reopening the tab.
        self:RefreshPersonal()
        if SH.MythicPositionsUI then SH.MythicPositionsUI:Refresh() end
    end)
    SH:RegisterEvent("GROUP_LEFT", function() self:ClearRaidPlan() end)
    SH:RegisterEvent("PARTY_LEADER_CHANGED", function()
        self:CancelAutoAssign("Auto Assign stopped by a leader change.")
        self:FinishGroupOrganization("Group organization stopped by a leader change. Some players may already have moved.")
        self.pending = nil
        self:CancelPublish()
    end)
    SH:RegisterEvent("GROUP_ROSTER_UPDATE", function()
        -- Live reads are limited to an explicitly started group operation.
        if self.autoAssign then self:UpdateAutoAssignRoster() end
        if self.organizing then self:UpdateGroupOrganization() end
        if SH.MythicPositionsUI and SH.MythicPositionsUI.page and SH.MythicPositionsUI.page:IsShown() then
            SH.MythicPositionsUI:Refresh()
        end
    end)
    SH:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        if not IsInRaid() then self:ClearRaidPlan() end
        if self:CanEdit() then self.playerName = fullName("player"); self:RefreshPersonal() end
    end)
end

-- The editor takes a snapshot on open. Group operations use their own live roster.
local function readMember(unit, name)
    local _, class = UnitClass(unit)
    local role = UnitGroupRolesAssigned(unit)
    if secret(class) or secret(role) or not name or not classes[class] then return nil end
    if role ~= "TANK" and role ~= "HEALER" and role ~= "DAMAGER" then role = "NONE" end
    return {name = name, class = class, role = role}
end

function M:ScanRoster()
    if not self:CanEdit() then return false, "Open Mythic Positions outside combat and chat lockdown." end
    self.roster, self.rosterByName = {}, {}
    self.playerName = fullName("player")
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            local member = readMember(unit, fullName(unit))
            if member then
                if member.role == "NONE" then member.role = "DAMAGER" end
                self.roster[#self.roster + 1] = member
                self.rosterByName[identity(member.name)] = member
            end
        end
    end
    table.sort(self.roster, function(a, b) return identity(a.name) < identity(b.name) end)
    return true
end
function M:OpenDraft()
    local ok, reason = self:ScanRoster()
    if not ok then return nil, reason end
    return self:DraftFromSnapshot()
end
function M:DraftFromSnapshot()
    local slots = copy(self.received and self.received.slots or self:GetProfile().slots)
    for _, slot in ipairs(slots) do
        if slot.member then
            local current = self.rosterByName[identity(slot.member.name)]
            if current then slot.member.class = current.class end
        end
    end
    return {slots = slots, profileID = self:GetProfile().id}
end
function M:IsAbsent(member)
    return member ~= nil and (not IsInRaid() or not self.rosterByName[identity(member.name)])
end
function M:Candidates(draft, slot)
    local used, result, other = {}, {}, {}
    local role = self:Role(slot)
    for _, point in ipairs(draft.slots) do if point.member then used[identity(point.member.name)] = true end end
    for _, member in ipairs(self.roster) do
        if not used[identity(member.name)] then
            local list = member.role == role and result or other
            list[#list + 1] = member
        end
    end
    for _, member in ipairs(other) do result[#result + 1] = member end
    return result
end
function M:Assign(draft, slot, name)
    if not self:CanEdit() then return false end
    if not draft or not draft.slots[slot] then return false end
    if name == nil then draft.slots[slot].member = nil; return true end
    for _, member in ipairs(self:Candidates(draft, slot)) do
        if member.name == name then draft.slots[slot].member = {name = name, class = member.class}; return true end
    end
    return false
end
function M:Save(draft)
    if not self:CanEdit() then return false, "Save positions outside combat." end
    local slots = draft and self:Validate(draft.slots)
    if not slots then return false, "The position assignments are invalid." end
    self:GetProfile().slots = slots
    self.received = nil
    self:RefreshPersonal()
    return true
end
function M:NewProfile(name, slots)
    if not self:CanEdit() then return nil, "Edit profiles outside combat." end
    name = profileName(name)
    if not name then return nil, "Enter a profile name (up to 40 bytes)." end
    if #self.db.profiles >= 10 then return nil, "You can store up to 10 position profiles." end
    for _, profile in ipairs(self.db.profiles) do if profile.name:lower() == name:lower() then return nil, "That profile name is already in use." end end
    slots = self:Validate(slots or self:GetProfile().slots)
    if not slots then return nil, "Invalid positions." end
    local id
    repeat
        id = "mythic-" .. tostring(self.db.nextID)
        self.db.nextID = self.db.nextID + 1
        local found = false
        for _, profile in ipairs(self.db.profiles) do if profile.id == id then found = true end end
        if not found then break end
    until false
    self.db.profiles[#self.db.profiles + 1] = {id = id, name = name, slots = slots}
    self.db.active, self.received = id, nil
    return id
end
function M:RenameProfile(name)
    if not self:CanEdit() then return false, "Edit profiles outside combat." end
    name = profileName(name)
    if not name then return false, "Enter a profile name (up to 40 bytes)." end
    for _, profile in ipairs(self.db.profiles) do
        if profile.id ~= self.db.active and profile.name:lower() == name:lower() then return false, "That name is already in use." end
    end
    self:GetProfile().name = name
    return true
end
function M:SelectProfile(id)
    if not self:CanEdit() then return false end
    for _, profile in ipairs(self.db.profiles) do
        if profile.id == id then self.db.active, self.received = id, nil; self:RefreshPersonal(); return true end
    end
    return false
end
function M:RefreshPersonal()
    if not self:CanEdit() then return end
    if not self.playerName then self.playerName = fullName("player") end
    self.personal = nil
    local slots = self.received and self.received.slots or self:GetProfile().slots
    if self.playerName then
        for i, slot in ipairs(slots) do
            if slot.member and identity(slot.member.name) == identity(self.playerName) then
                self.personal = {slot = i, x = slot.x, y = slot.y}
                break
            end
        end
    end
    if SH.RoomMap and SH.RoomMap.RefreshMythicPosition then SH.RoomMap:RefreshMythicPosition() end
end
function M:ClearRaidPlan()
    self:CancelAutoAssign("Auto Assign stopped because you left the raid.")
    self:FinishGroupOrganization("Group organization stopped because you left the raid.")
    self.received, self.pending = nil, nil
    self.roster, self.rosterByName = {}, {}
    self:CancelPublish()
    -- Do not carry a raid leader's dot into the next group or a new combat.
    self.personal = nil
    if SH.RoomMap and SH.RoomMap.RefreshMythicPosition then SH.RoomMap:RefreshMythicPosition() end
end

function M:CanOrganizeGroups()
    return IsInRaid() and (UnitIsGroupLeader("player")
        or type(UnitIsGroupAssistant) == "function" and UnitIsGroupAssistant("player"))
end

local function groupRoster()
    local roster = {byName = {}, groups = {0, 0, 0, 0, 0, 0, 0, 0}}
    local count = GetNumGroupMembers()
    if secret(count) or type(count) ~= "number" or count < 1 or count > 40 then return nil end
    for i = 1, count do
        local name = fullName("raid" .. i)
        local _, _, group = GetRaidRosterInfo(i)
        if not name or secret(group) or type(group) ~= "number" or group % 1 ~= 0 or group < 1 or group > 8 then return nil end
        local key = identity(name)
        if roster.byName[key] then return nil end
        local member = {index = i, key = key, name = name, group = group}
        roster[#roster + 1], roster.byName[key] = member, member
        roster.groups[group] = roster.groups[group] + 1
        if roster.groups[group] > 5 then return nil end
    end
    return roster
end

local function sameGroupRoster(roster, snapshot)
    if not roster or #roster ~= #snapshot then return false end
    for key in pairs(snapshot.byName) do
        if not roster.byName[key] then return false end
    end
    return true
end

function M:FinishGroupOrganization(message, success)
    local run = self.organizing
    if not run then return end
    if self.groupTimer then self.groupTimer:Cancel(); self.groupTimer = nil end
    self.organizing = nil
    if success and run.onSuccess then message = run.onSuccess() end
    if SH.MythicPositionsUI then
        SH.MythicPositionsUI.message = message
        SH.MythicPositionsUI:Refresh()
    end
end

local function groupOrganizationError(self)
    if not self:CanOrganizeGroups() then return "Only raid leaders and assistants can organize groups." end
    if not self:CanEdit() then return "Organize groups outside combat and chat lockdown." end
    if self.organizing or self.autoAssign then return "Group organization is already in progress." end
    if type(GetRaidRosterInfo) ~= "function" or type(SetRaidSubgroup) ~= "function" or type(SwapRaidSubgroup) ~= "function" then
        return "Raid group controls are unavailable."
    end
end

local function startGroupOrganization(self, slots, roster, onSuccess)
    local run = {targets = {}, order = {}, roster = roster, changes = 0, absent = 0, onSuccess = onSuccess}
    for slot, point in ipairs(slots) do
        if point.member then
            local key = identity(point.member.name)
            if roster.byName[key] then
                run.targets[key] = self:GroupForSlot(slot)
                run.order[#run.order + 1] = key
            else
                run.absent = run.absent + 1
            end
        end
    end
    if #run.order == 0 then return false, "No assigned players are currently in the raid." end
    self.organizing = run
    if SH.MythicPositionsUI then
        SH.MythicPositionsUI.message = onSuccess and "Auto Assign is balancing raid groups..."
            or "Organizing raid groups from the displayed assignments..."
    end
    self:UpdateGroupOrganization(roster)
    return true
end

function M:OrganizeGroups(draft)
    local reason = groupOrganizationError(self)
    if reason then return false, reason end
    local slots = draft and self:Validate(draft.slots)
    if not slots then return false, "Assign positions before organizing groups." end
    local roster = groupRoster()
    if not roster then return false, "The raid roster is not ready. Try again in a moment." end
    return startGroupOrganization(self, slots, roster)
end

function M:UpdateGroupOrganization(roster)
    local run = self.organizing
    if not run then return end
    if not self:CanEdit() or not self:CanOrganizeGroups() then
        self:FinishGroupOrganization("Group organization stopped: combat, lockdown, or raid permissions changed. Some players may already have moved.")
        return
    end
    roster = roster or groupRoster()
    if not sameGroupRoster(roster, run.roster) then
        self:FinishGroupOrganization("Group organization stopped because the raid roster changed. Try again.")
        return
    end
    -- Raid indexes may change after every move. Wait for confirmation, then
    -- choose the next operation using current indexes and full Name-Realm keys.
    if run.pending then
        for key, group in pairs(run.pending) do
            if roster.byName[key].group ~= group then return end
        end
        self.groupTimer:Cancel()
        self.groupTimer, run.pending = nil, nil
    end
    for _, key in ipairs(run.order) do
        local member, target = roster.byName[key], run.targets[key]
        if member.group ~= target then
            if run.changes >= 40 then
                self:FinishGroupOrganization("Group organization stopped after repeated group changes. Try again.")
                return
            end
            local partner
            if roster.groups[target] >= 5 then
                for _, candidate in ipairs(roster) do
                    if candidate.group == target and run.targets[candidate.key] ~= target then
                        partner = partner or candidate
                        if run.targets[candidate.key] == member.group then partner = candidate; break end
                    end
                end
                if not partner then self:FinishGroupOrganization("The destination group is full. Check the position assignments."); return end
            end
            run.pending, run.changes = {[key] = target}, run.changes + 1
            if partner then run.pending[partner.key] = member.group end
            self.groupTimer = C_Timer.NewTimer(3, function()
                if M.organizing == run then
                    M:FinishGroupOrganization("Raid group change was not confirmed. Some players may already have moved; try again.")
                end
            end)
            local ok
            if partner then ok = pcall(SwapRaidSubgroup, member.index, partner.index)
            else ok = pcall(SetRaidSubgroup, member.index, target) end
            if not ok then self:FinishGroupOrganization("Could not change raid groups. Some players may already have moved; try again.") end
            return
        end
    end
    local message = "Raid groups organized: " .. #run.order .. " assigned players in their position groups."
    if run.absent > 0 then message = message .. " Skipped " .. run.absent .. " absent players." end
    self:FinishGroupOrganization(message, true)
end

local meleeClasses = {PALADIN = true, DEATHKNIGHT = true, WARRIOR = true, ROGUE = true, MONK = true}
local meleeSpecs = {[255] = true, [103] = true, [263] = true, [577] = true} -- Survival, Feral, Enhancement, Havoc
local prioritySpecClasses = {HUNTER = true, MAGE = true, DRUID = true, SHAMAN = true, DEMONHUNTER = true}
local furySpecs = {[253] = 1, [254] = 2, [62] = 3, [102] = 5} -- BM, Marksmanship, Arcane, Balance
-- Internal slot IDs ordered by the display numbers for melee tiers, then the other damage spots.
local damageSlots = {1, 18, 5, 17, 3, 4, 7, 8, 19, 10, 11, 15, 13}

local function readSpec(unit)
    local api = C_SpecializationInfo
    if not api then return nil end
    local spec
    if unit == "player" and api.GetSpecialization and api.GetSpecializationInfo then
        local index = api.GetSpecialization()
        if not secret(index) and type(index) == "number" and index > 0 then spec = api.GetSpecializationInfo(index) end
    elseif api.GetInspectSpecialization then
        spec = api.GetInspectSpecialization(unit)
    end
    if not secret(spec) and type(spec) == "number" and spec > 0 then return spec end
end

local function melee(member)
    return member.role == "DAMAGER" and (meleeClasses[member.class] or meleeSpecs[member.spec])
end

local function furyRank(member)
    return furySpecs[member.spec] or (member.class == "MAGE" and 4) or (melee(member) and 7 or 6)
end

local function buildAutoAssignments(slots, members, byName)
    local result, used = copy(slots), {}
    for _, point in ipairs(result) do point.member = nil end
    local function place(slot, member)
        if not member then return end
        result[slot].member = {name = member.name, class = member.class}
        used[member] = true
    end
    local function pick(role, slot, rank)
        local best, score
        for _, member in ipairs(members) do
            if not used[member] and (not role or member.role == role) then
                local candidateScore = (rank and rank(member) or 0) * 2
                    + (member.group == positionGroups[slot] and 0 or 1)
                if not score or candidateScore < score then best, score = member, candidateScore end
            end
        end
        return best
    end

    for _, slot in ipairs({2, 6}) do place(slot, pick("TANK", slot)) end
    for _, slot in ipairs({9, 12, 14, 16, 13}) do place(slot, pick("HEALER", slot)) end
    local bait = pick("DAMAGER", M.BAIT_SLOT, furyRank)
    place(M.BAIT_SLOT, bait)

    local meleePlayers, available = {}, {}
    for _, member in ipairs(members) do
        if not used[member] and melee(member) then meleePlayers[#meleePlayers + 1] = member end
    end
    for _, slot in ipairs(damageSlots) do
        if not result[slot].member then available[#available + 1] = slot end
    end
    if #meleePlayers > #available then
        for _, slot in ipairs({2, 6, 9, 12, 14, 16}) do
            if not result[slot].member then available[#available + 1] = slot end
        end
    end
    local oddCapacity = 0
    for _, slot in ipairs(available) do oddCapacity = oddCapacity + positionGroups[slot] % 2 end
    local evenCapacity = #available - oddCapacity
    local baitMelee = bait and melee(bait) and 1 or 0
    local idealOdd = math.floor((#meleePlayers + baitMelee) / 2) - baitMelee
    local odd = math.max(0, #meleePlayers - evenCapacity, math.min(idealOdd, oddCapacity))
    local remaining = {[0] = #meleePlayers - odd, [1] = odd}
    for _, slot in ipairs(available) do
        local side = positionGroups[slot] % 2
        if remaining[side] > 0 then
            place(slot, table.remove(meleePlayers, 1))
            remaining[side] = remaining[side] - 1
        end
    end

    for _, slot in ipairs(damageSlots) do
        if not result[slot].member then place(slot, pick("DAMAGER", slot)) end
    end
    for slot, point in ipairs(result) do
        if not point.member then
            place(slot, pick(nil, slot))
            local previous = slots[slot].member
            if not point.member and previous and not byName[identity(previous.name)] then point.member = previous end
        end
    end
    return result
end

function M:CancelAutoAssign(message)
    local run = self.autoAssign
    if not run then return end
    if run.timer then run.timer:Cancel() end
    self.autoAssign = nil
    if SH.MythicPositionsUI then
        SH.MythicPositionsUI.message = message
        SH.MythicPositionsUI:Refresh()
    end
end

function M:AutoAssignInspectReady(guid)
    local run = self.autoAssign
    local member = run and run.inspecting
    if not member or secret(guid) or guid ~= run.guid or not self:CanEdit() then return end
    local unit = "raid" .. member.index
    local current = UnitGUID(unit)
    if not secret(current) and current == guid then member.spec = readSpec(unit) end
end

function M:UpdateAutoAssignRoster()
    local run = self.autoAssign
    if not self:CanEdit() or not self:CanOrganizeGroups() then
        self:CancelAutoAssign("Auto Assign stopped because combat, lockdown, or raid permissions changed.")
        return
    end
    local roster = groupRoster()
    if not sameGroupRoster(roster, run.roster) then
        self:CancelAutoAssign("Auto Assign stopped because the raid roster changed. Try again.")
        return
    end
    for key, member in pairs(run.byName) do member.index = roster.byName[key].index end
    return roster
end

function M:ContinueAutoAssign(run)
    if self.autoAssign ~= run then return end
    if not self:CanEdit() or not self:CanOrganizeGroups() then
        self:CancelAutoAssign("Auto Assign stopped because combat, lockdown, or raid permissions changed.")
        return
    end
    run.inspecting = nil
    while run.next <= #run.inspect do
        local member = run.inspect[run.next]
        run.next = run.next + 1
        local unit = "raid" .. member.index
        if fullName(unit) == member.name and CanInspect(unit) and not (InspectFrame and InspectFrame:IsShown()) then
            local guid = UnitGUID(unit)
            if not secret(guid) and type(guid) == "string" then
                run.inspecting, run.guid = member, guid
                if pcall(NotifyInspect, unit) then
                    -- Pace inspect requests and move on if this player doesn't respond.
                    run.timer = C_Timer.NewTimer(2, function()
                        run.timer = nil
                        self:ContinueAutoAssign(run)
                    end)
                    return
                end
                run.inspecting = nil
            end
        end
    end
    local roster = self:UpdateAutoAssignRoster()
    if not roster then return end
    local unknown, tanksFound, healersFound = 0, 0, 0
    local roleBySpec = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationRoleByID or GetSpecializationRoleByID
    for _, member in ipairs(run.members) do
        local current = readMember("raid" .. member.index, member.name)
        if not current or current.role ~= member.role then
            self:CancelAutoAssign("Auto Assign stopped because raid roles changed. Try again.")
            return
        end
        member.group = roster.byName[identity(member.name)].group
        if member.role == "NONE" then
            local role = member.spec and roleBySpec and roleBySpec(member.spec)
            member.role = not secret(role) and (role == "TANK" or role == "HEALER") and role or "DAMAGER"
        end
        if member.role == "TANK" then tanksFound = tanksFound + 1 end
        if member.role == "HEALER" then healersFound = healersFound + 1 end
        if member.needsSpec and not member.spec then unknown = unknown + 1 end
    end
    local slots = buildAutoAssignments(run.slots, run.members, run.byName)
    self.autoAssign = nil
    startGroupOrganization(self, slots, roster, function()
        self.roster, self.rosterByName = run.members, run.byName
        run.draft.slots = slots
        local ui = SH.MythicPositionsUI
        if ui and ui.draft == run.draft then ui.dirty = true end
        local message = "Auto Assign placed " .. #roster .. " players. Positions are unsaved."
        if tanksFound < 2 or healersFound < 4 then message = message .. " Fewer than 2 tanks or 4 healers." end
        if unknown > 0 then message = message .. " Specs unavailable for " .. unknown .. "." end
        return message
    end)
end

function M:AutoAssign(draft)
    local reason = groupOrganizationError(self)
    if reason then return false, reason end
    local slots = draft and self:Validate(draft.slots)
    if not slots then return false, "Open a position profile before using Auto Assign." end
    local roster = groupRoster()
    if not roster then return false, "The raid roster is not ready. Try again in a moment." end
    if #roster > #slots then return false, "Auto Assign supports up to 20 raid members." end
    local run = {draft = draft, slots = slots, roster = roster, members = {}, byName = {}, inspect = {}, next = 1}
    local player = fullName("player")
    local canInspect = type(CanInspect) == "function" and type(NotifyInspect) == "function"
        and type(UnitGUID) == "function" and C_SpecializationInfo and C_SpecializationInfo.GetInspectSpecialization
    for _, entry in ipairs(roster) do
        local unit = "raid" .. entry.index
        local member = readMember(unit, entry.name)
        if not member then return false, "The raid roster is not ready. Try again in a moment." end
        member.index = entry.index
        member.needsSpec = member.role == "NONE" or (member.role == "DAMAGER" and prioritySpecClasses[member.class])
        if member.needsSpec then
            member.spec = readSpec(entry.name == player and "player" or unit)
            if not member.spec and canInspect and entry.name ~= player then
                run.inspect[#run.inspect + 1] = member
            end
        end
        run.members[#run.members + 1], run.byName[entry.key] = member, member
    end
    table.sort(run.members, function(a, b) return identity(a.name) < identity(b.name) end)
    self.autoAssign = run
    if SH.MythicPositionsUI then SH.MythicPositionsUI.message = "Auto Assign is checking raid specializations..." end
    self:ContinueAutoAssign(run)
    return true
end

function M:CancelPublish()
    local wasPublishing = self.publishing or self.publication ~= nil
    if self.sendTimer then self.sendTimer:Cancel(); self.sendTimer = nil end
    if self.receiptTimer then self.receiptTimer:Cancel(); self.receiptTimer = nil end
    if self.ackTimer then self.ackTimer:Cancel(); self.ackTimer = nil end
    self.publication = nil
    self.publishing = false
    if SH.MythicPositionsUI then
        if wasPublishing then SH.MythicPositionsUI:PublicationFinished(false, "Publication cancelled by combat, a group change, or a leader change.")
        else SH.MythicPositionsUI:Refresh() end
    end
end
function M:ReceiptStatus(final)
    local publication = self.publication
    if not publication or not publication.complete then return end
    local message
    if publication.count > 0 then
        message = "Positions received by " .. publication.count .. " other addon user" .. (publication.count == 1 and "." or "s.")
    elseif final then
        message = "No receipt confirmed. /reload both clients, check the raid leader, then publish again outside combat."
    else
        message = "Positions sent; waiting for another addon user to confirm receipt..."
    end
    if final or publication.count == 1 then SH:Print(message) end
    if SH.MythicPositionsUI then SH.MythicPositionsUI:PublicationFinished(publication.count > 0, message) end
end
function M:Publish(draft)
    if not self:CanEdit() or not IsInRaid() or not UnitIsGroupLeader("player") then return false, "Only the raid leader can publish outside combat." end
    if self.publishing then return false, "A position plan is already being published." end
    local ok, reason = self:Save(draft)
    if not ok then return false, reason end
    self:CancelPublish()
    self.serial = (self.serial or 0) + 1
    local token = tostring(GetServerTime()) .. "-" .. tostring(self.serial)
    local packets = {"MPB|" .. token .. "|" .. self:GetProfile().name}
    -- A checked raid token also resolves cross-realm names on clients where
    -- UnitInRaid does not resolve the chat sender's qualified name.
    local indexHint = UnitInRaid("player")
    if raidIndex(indexHint) then packets[1] = packets[1] .. "|" .. indexHint end
    for i, slot in ipairs(self:GetProfile().slots) do
        local member = slot.member
        packets[#packets + 1] = table.concat({"MPS", token, tostring(i), tostring(math.floor(slot.x * 1000 + 0.5)),
            tostring(math.floor(slot.y * 1000 + 0.5)), member and member.class or "", member and member.name or ""}, "|")
    end
    packets[#packets + 1] = "MPE|" .. token
    self.publishing = true
    self.publication = {token = token, receipts = {}, count = 0}
    self.publishError = nil
    local index, retries, deadline = 1, 0, GetTime() + 15
    local function fail(reason)
        self.publishing, self.publishError = false, reason
        self.publication = nil
        SH:Print("Positions could not be published: " .. reason)
        if SH.MythicPositionsUI then SH.MythicPositionsUI:PublicationFinished(false, reason) end
    end
    local function sendNext()
        self.sendTimer = nil
        if not self.publishing then return end
        if not self:CanEdit() then fail("Combat, encounter, or chat messaging lockdown is active."); return end
        if not IsInRaid() then fail("You left the raid group."); return end
        if not UnitIsGroupLeader("player") then fail("Only the current raid leader can publish positions."); return end
        if GetTime() > deadline then fail("The transfer timed out while waiting for addon messaging. Try publishing again."); return end
        local sent, reason = SH.Comms:Send(packets[index], true)
        if not sent then
            if SH.Comms:IsThrottleResult(SH.Comms.lastSendResult) and retries < 3 and GetTime() + 1 <= deadline then
                retries = retries + 1
                self.sendTimer = C_Timer.NewTimer(1, sendNext)
                return
            end
            fail(reason or "WoW rejected an addon message.")
            return
        end
        retries = 0
        index = index + 1
        if index <= #packets then self.sendTimer = C_Timer.NewTimer(0.3, sendNext)
        else
            self.publishing = false
            self.publication.complete = true
            self:ReceiptStatus(false)
            self.receiptTimer = C_Timer.NewTimer(10, function()
                self.receiptTimer = nil
                if self.publication and self:CanEdit() then self:ReceiptStatus(true) end
                self.publication = nil
            end)
        end
    end
    sendNext()
    return self.publishing, self.publishError
end

-- One bounded, atomic transfer. A partial, duplicate or expired plan is never applied.
function M:ResolveSender(sender, hint)
    local expected = senderName(sender)
    if not expected then return nil end
    local function resolve(index)
        if not raidIndex(index) then return nil end
        local unit = "raid" .. index
        local name = fullName(unit)
        if name and identity(name) == identity(expected) then return unit, name end
    end
    -- Hints are never trusted for identity: verify against the actual raid unit.
    local unit, name = resolve(hint)
    if unit then return unit, name end
    unit, name = resolve(UnitInRaid(sender))
    if unit then return unit, name end
    return resolve(UnitInRaid(expected:match("^[^-]+")))
end
function M:IsLeaderSender(sender, hint)
    -- Resolve just this sender; receiving never enumerates the raid.
    local unit, name = self:ResolveSender(sender, hint)
    if not unit then return false end
    local leader = UnitIsGroupLeader(unit)
    if secret(leader) or leader ~= true then return false end
    return true, name
end
function M:Acknowledge(token, publisher)
    if self.ackTimer then self.ackTimer:Cancel(); self.ackTimer = nil end
    local index = UnitInRaid("player")
    local message = "MPA|" .. token .. "|" .. publisher .. "|" .. (raidIndex(index) and index or 0)
    local attempts = 0
    local function send()
        self.ackTimer = nil
        if not self:CanEdit() or not IsInRaid() or not self.received or self.received.token ~= token then return end
        attempts = attempts + 1
        if not SH.Comms:Send(message, true) and SH.Comms:IsThrottleResult(SH.Comms.lastSendResult) and attempts < 3 then
            self.ackTimer = C_Timer.NewTimer(1, send)
        end
    end
    -- Stagger small replies instead of all raid clients responding at once.
    self.ackTimer = C_Timer.NewTimer(raidIndex(index) and index * 0.03 or 0.1, send)
end
function M:OnMessage(message, sender)
    if secret(message) or secret(sender) then return end
    if not self:CanEdit() or not IsInRaid() then return end
    if type(message) ~= "string" or type(sender) ~= "string" or #message > 254 then return end
    local ackToken, publisher, ackIndex = message:match("^MPA|(%d+%-%d+)|([^|]+)|(%d+)$")
    if ackToken then
        local publication = self.publication
        if not publication or publication.token ~= ackToken or not self.playerName
            or identity(publisher) ~= identity(self.playerName) or not UnitIsGroupLeader("player") then return end
        local unit, name = self:ResolveSender(sender, tonumber(ackIndex))
        if not unit or identity(name) == identity(self.playerName) or publication.receipts[identity(name)] then return end
        publication.receipts[identity(name)] = true
        publication.count = publication.count + 1
        self:ReceiptStatus(false)
        return
    end
    local token, name, hint = message:match("^MPB|(%d+%-%d+)|([^|]+)|(%d+)$")
    if not token then token, name = message:match("^MPB|(%d+%-%d+)|([^|]+)$") end
    if token then
        local verified, canonical = self:IsLeaderSender(sender, tonumber(hint))
        if not verified or (self.playerName and identity(canonical) == identity(self.playerName)) then return end
        name = profileName(name)
        if name then self.pending = {token = token, sender = canonical, hint = tonumber(hint), name = name, slots = {}, count = 0, expires = GetTime() + 20} end
        return
    end
    local pending = self.pending
    if not pending then return end
    if GetTime() > pending.expires then self.pending = nil; return end
    local canonical = senderName(sender)
    if not canonical or identity(canonical) ~= identity(pending.sender) then return end
    local id, number, x, y, class, player = message:match("^MPS|(%d+%-%d+)|(%d+)|(%d+)|(%d+)|([^|]*)|([^|]*)$")
    if id then
        if id ~= pending.token then return end
        number, x, y = tonumber(number), tonumber(x), tonumber(y)
        if number < 1 or number > 20 or pending.slots[number] or x < 40 or x > 960 or y < 40 or y > 960
            or (player ~= "" and (not validName(player) or not classes[class])) or (player == "" and class ~= "") then self.pending = nil; return end
        pending.slots[number] = {x = x / 1000, y = y / 1000, member = player ~= "" and {name = player, class = class} or nil}
        pending.count = pending.count + 1
        return
    end
    id = message:match("^MPE|(%d+%-%d+)$")
    if id ~= pending.token then return end
    self.pending = nil
    if pending.count ~= 20 or not self:IsLeaderSender(sender, pending.hint) then return end
    local slots = self:Validate(pending.slots)
    if not slots then return end
    self.received = {slots = slots, sender = pending.sender, name = pending.name, token = id}
    self:RefreshPersonal()
    if SH.MythicPositionsUI then SH.MythicPositionsUI:Received() end
    SH:Print("Mythic positions received from " .. pending.sender .. ".")
    self:Acknowledge(id, pending.sender)
end
