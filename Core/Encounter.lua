local _, SH = ...

SH.Encounter = {
    initializeOrder = 60,
    active = false,
    testMode = false,
    assignments = {},
    cycle = 0,
    revision = 0,
    timers = {},
    timelineEvents = {},
}
SH.modules.Encounter = SH.Encounter

local SURGE_SPELL_ID = 1305959
local HOWLING_SPELL_ID = 1285732

local function spellName(spellID)
    return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
end

local function readable(value)
    return value ~= nil and (not issecretvalue or not issecretvalue(value))
end

local function sameSpellName(value, spellID)
    if not readable(value) then return false end
    local expected = spellName(spellID)
    return expected and value == expected
end

local function cancelTimer(timer)
    if timer and timer.Cancel then timer:Cancel() end
end

function SH.Encounter:OnInitialize()
    SH:RegisterEvent("ENCOUNTER_START", function(_, encounterID, encounterName, difficultyID)
        if encounterID == SH.Const.ENCOUNTER_ID then SH.Encounter:Start(encounterName, difficultyID) end
    end)
    SH:RegisterEvent("ENCOUNTER_END", function(_, encounterID)
        if encounterID == SH.Const.ENCOUNTER_ID then SH.Encounter:Stop() end
    end)
    SH:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED", function(_, eventInfo)
        SH.Encounter:OnTimelineAdded(eventInfo)
    end)
    SH:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED", function(_, eventID)
        SH.Encounter:OnTimelineChanged(eventID)
    end)
    self:RefreshDisplays()
end

function SH.Encounter:IsDifficultyEnabled(difficultyID)
    return SH.Store:Options().difficulties[tonumber(difficultyID)] == true
end

function SH.Encounter:Start(encounterName, difficultyID)
    if self.testMode then self:QuitTestMode() end
    if not self:IsDifficultyEnabled(difficultyID) then return end
    self.active = true
    self.startedAt = GetTime()
    self.encounterName = encounterName
    self.difficultyID = difficultyID
    self.cycle = 1
    self.revision = 0
    self.assignments = {}
    self.surgeIndex = 0
    self.timelineEvents = {}
    self:CancelTimers()
    SH.RoomMap:RefreshLayout()
    self:RefreshDisplays()
    SH.Comms:Announce(true)
    C_Timer.After(1, function() if SH.Encounter.active then SH.Comms:Announce(true) end end)
end

function SH.Encounter:Stop()
    self.active = false
    self:CancelTimers()
    self.timelineEvents = {}
    SH.RoomMap:StopRotation()
    self:RefreshDisplays()
end

function SH.Encounter:CancelTimers()
    for _, timer in pairs(self.timers) do cancelTimer(timer) end
    wipe(self.timers)
end

function SH.Encounter:IsComplete()
    return self.assignments[1] ~= nil and self.assignments[2] ~= nil and self.assignments[3] ~= nil
end

function SH.Encounter:IsPositionUsed(position)
    for _, assigned in pairs(self.assignments) do if assigned == position then return true end end
    return false
end

function SH.Encounter:AcceptProposal(order, position, _, source)
    order, position = tonumber(order), tonumber(position)
    if not order or order < 1 or order > 3 or not SH.Const:IsWindPosition(position) then return false end
    if self.assignments[order] or self:IsPositionUsed(position) then return false end
    self.assignments[order] = position
    self.revision = self.revision + 1
    self:RefreshDisplays()
    if self.active and SH.Comms:IsCoordinator() then SH.Comms:BroadcastState() end
    if self:IsComplete() then self:OnAssignmentsComplete(source) end
    return true
end

function SH.Encounter:ApplyState(cycle, revision, assignments)
    if cycle ~= self.cycle or not revision or revision < self.revision then return end
    local validated, used = {}, {}
    for order = 1, 3 do
        local position = tonumber(assignments[order])
        if position and position ~= 0 and SH.Const:IsWindPosition(position) and not used[position] then
            validated[order] = position
            used[position] = true
        end
    end
    local wasComplete = self:IsComplete()
    self.assignments = validated
    self.revision = revision
    self:RefreshDisplays()
    if not wasComplete and self:IsComplete() then self:OnAssignmentsComplete("state") end
end

function SH.Encounter:ClearAssignments(source)
    self.assignments = {}
    self.revision = 0
    SH.OrderFrame:Update(nil)
    self:RefreshDisplays()
    if self.active and source ~= "remote" and SH.Comms:IsCoordinator() then SH.Comms:BroadcastState() end
end

function SH.Encounter:ResetForNextPhase(targetCycle, broadcast)
    self.assignments = {}
    self.cycle = targetCycle or (self.cycle + 1)
    self.revision = 0
    self.surgeIndex = 0
    SH.Comms.externalMarkers = {}
    SH.OrderFrame:Update(nil)
    self:RefreshDisplays()
    if broadcast ~= false then SH.Comms:BroadcastReset() end
end

function SH.Encounter:ComputeDropOrder()
    if not self:IsComplete() then return nil end
    local layout = SH.Store:GetLayout()
    local drops = {}
    for order = 1, 3 do
        drops[order] = layout[SH.Const:Opposite(self.assignments[order])]
    end
    drops[4] = layout[SH.Const.EXIT_POSITION]
    return drops
end

function SH.Encounter:OnAssignmentsComplete(source)
    local drops = self:ComputeDropOrder()
    SH.OrderFrame:Update(drops)
    if self.active and SH.Comms:IsCoordinator() and source ~= "external" and source ~= "state" then
        C_Timer.After(0.2, function()
            if SH.Encounter.active and SH.Encounter:IsComplete() then SH.Comms:PublishDropOrder(SH.Encounter:ComputeDropOrder()) end
        end)
    end
end

function SH.Encounter:ImportExternalMarkers(markers)
    if self:IsComplete() then return false end
    local layout = SH.Store:GetLayout()
    local markerPositions = {}
    for position, markerID in ipairs(layout) do markerPositions[markerID] = position end
    local imported, used = {}, {}
    for order = 1, 3 do
        local dropPosition = markerPositions[tonumber(markers[order])]
        local windPosition = dropPosition and SH.Const:Opposite(dropPosition)
        if not windPosition or not SH.Const:IsWindPosition(windPosition) or used[windPosition] then return false end
        imported[order] = windPosition
        used[windPosition] = true
    end
    self.assignments = imported
    self.revision = self.revision + 1
    self:RefreshDisplays()
    SH.Comms:BroadcastState()
    self:OnAssignmentsComplete("external")
    return true
end

function SH.Encounter:RefreshDisplays()
    local options = SH.Store:Options()
    local previewing = options.previewFrames and not self.active and not self.testMode
    SH.RoomMap:RefreshLayout()
    SH.RoomMap:RefreshAssignments()
    SH.RoomMap:RefreshVisibility()
    if self:IsComplete() then
        SH.OrderFrame:Update(self:ComputeDropOrder())
    elseif previewing then
        local layout = SH.Store:GetLayout()
        SH.OrderFrame:ShowPreview({layout[2], layout[3], layout[6], layout[1]})
    else
        SH.OrderFrame:Update(nil)
    end
    local context = self.active or self.testMode or previewing
    local unlocked = context and not options.lockFrames
    SH.RoomMap:SetUnlocked(unlocked)
    SH.OrderFrame:SetUnlocked(unlocked)
end

function SH.Encounter:SendWarning(text, isTest)
    if isTest then
        if ChatFrame_ReplaceIconAndGroupExpressions then
            text = ChatFrame_ReplaceIconAndGroupExpressions(text)
        end
        if RaidNotice_AddMessage and RaidWarningFrame then
            RaidNotice_AddMessage(RaidWarningFrame, text, ChatTypeInfo.RAID_WARNING)
        else
            SH:Print(text)
        end
        return
    end
    if self.active and IsInRaid() and UnitIsGroupLeader("player") then
        C_ChatInfo.SendChatMessage(text, "RAID_WARNING")
    end
end

function SH.Encounter:WarnSurge(index, isTest)
    if not SH.Store:Options().raidWarningSurges and not isTest then return end
    local drops = self:ComputeDropOrder()
    if not drops then
        if isTest then self:SendWarning("Surge assignments are incomplete", true) end
        return
    end
    local first = index == 1 and 1 or 3
    self:SendWarning(string.format("Surges to %s and %s", SH.Const:MarkerToken(drops[first]), SH.Const:MarkerToken(drops[first + 1])), isTest)
end

function SH.Encounter:WarnPush(index, isTest)
    if not SH.Store:Options().raidWarningPushes and not isTest then return end
    local position = self.assignments[index]
    local markerID = position and SH.Store:GetLayout()[position]
    if markerID then self:SendWarning("Push toward " .. SH.Const:MarkerToken(markerID), isTest) end
end

function SH.Encounter:OnTimelineAdded(eventInfo)
    if not self.active or type(eventInfo) ~= "table" or eventInfo.source ~= 0 then return end
    local eventID = eventInfo.id
    local duration = tonumber(eventInfo.duration)
    if not eventID or not duration then return end

    if sameSpellName(eventInfo.spellName, SURGE_SPELL_ID) then
        self.surgeIndex = (self.surgeIndex or 0) + 1
        local index = ((self.surgeIndex - 1) % 2) + 1
        self.timelineEvents[eventID] = {kind = "surge", index = index}
        self.timers["surge" .. eventID] = C_Timer.NewTimer(math.max(0, duration - 2), function()
            if SH.Encounter.active then SH.Encounter:WarnSurge(index, false) end
        end)
        return
    end

    local rounded = math.floor(duration + 0.5)
    if sameSpellName(eventInfo.spellName, HOWLING_SPELL_ID) or rounded == 100 or rounded == 111 or rounded == 125 then
        self.timelineEvents[eventID] = {kind = "digIn", started = false}
    end
end

function SH.Encounter:OnTimelineChanged(eventID)
    if not self.active then return end
    local tracked = self.timelineEvents[eventID]
    if not tracked then return end
    local ok, state = pcall(C_EncounterTimeline.GetEventState, eventID)
    if not ok then return end
    if tracked.kind == "surge" and (state == 2 or state == 3) then
        cancelTimer(self.timers["surge" .. eventID])
        self.timers["surge" .. eventID] = nil
    elseif tracked.kind == "digIn" and not tracked.started and (state == 2 or state == 3) then
        tracked.started = true
        self:StartIntermission(false)
    end
end

function SH.Encounter:StartIntermission(isTest)
    SH.RoomMap:StartRotation()
    self:WarnPush(1, isTest)
    self.timers.push2 = C_Timer.NewTimer(8, function() SH.Encounter:WarnPush(2, isTest) end)
    self.timers.push3 = C_Timer.NewTimer(18, function() SH.Encounter:WarnPush(3, isTest) end)
    self.timers.rotationStop = C_Timer.NewTimer(25, function() SH.RoomMap:StopRotation() end)
    if not isTest then
        self.timers.phaseReset = C_Timer.NewTimer(30, function()
            if SH.Encounter.active then SH.Encounter:ResetForNextPhase(nil, true) end
        end)
    end
end

function SH.Encounter:EnterTestMode()
    if self.active then SH:Print("Test mode is unavailable during the Sszorak encounter."); return false end
    self:CancelTimers()
    self.testMode = true
    self.cycle = 1
    self.revision = 0
    self.assignments = {}
    self:RefreshDisplays()
    return true
end

function SH.Encounter:TestIntermission()
    if not self.testMode then return end
    cancelTimer(self.timers.push2)
    cancelTimer(self.timers.push3)
    cancelTimer(self.timers.rotationStop)
    self:StartIntermission(true)
end

function SH.Encounter:QuitTestMode()
    self:CancelTimers()
    self.testMode = false
    self.assignments = {}
    SH.RoomMap:StopRotation()
    self:RefreshDisplays()
    if SH.OptionsUI and SH.OptionsUI.testFrame then SH.OptionsUI.testFrame:Hide() end
    return true
end
