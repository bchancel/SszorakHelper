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
    seenTimelineEvents = {},
}
SH.modules.Encounter = SH.Encounter

local SURGE_SPELL_ID = 1305959
local HOWLING_SPELL_ID = 1285732
local SURGE_WARNING_LEAD = 3
local INITIAL_SURGE_DURATIONS = {[29] = true, [32] = true, [36] = true}
local VARIABLE_EVENT_DURATIONS = {[47] = true, [52] = true, [59] = true}

local function spellName(spellID)
    return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
end

local function readable(value)
    return (not issecretvalue or not issecretvalue(value)) and value ~= nil
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
    SH.Comms.receivedCount = 0
    SH.Comms.receivedMarkers = {}
    self.variableTimelineStep = 0
    self.timelineEvents = {}
    self.seenTimelineEvents = {}
    self:CancelTimers()
    SH.RoomMap:RefreshLayout()
    self:RefreshDisplays()
end

function SH.Encounter:Stop()
    self.active = false
    SH.PersonalWarning:Hide()
    SH.Comms.receivedCount = 0
    SH.Comms.receivedMarkers = {}
    self:CancelTimers()
    self.timelineEvents = {}
    self.seenTimelineEvents = {}
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

function SH.Encounter:AcceptProposal(order, position)
    order, position = tonumber(order), tonumber(position)
    if not order or order < 1 or order > 3 or not SH.Const:IsWindPosition(position) then return false end
    if self.assignments[order] or self:IsPositionUsed(position) then return false end
    self.assignments[order] = position
    self.revision = self.revision + 1
    self:RefreshDisplays()
    if self:IsComplete() then self:OnAssignmentsComplete() end
    return true
end

function SH.Encounter:ClearAssignments()
    SH.PersonalWarning:Hide()
    self.assignments = {}
    SH.Comms.receivedCount = 0
    SH.Comms.receivedMarkers = {}
    self.revision = 0
    SH.OrderFrame:Update(nil)
    self:RefreshDisplays()
end

function SH.Encounter:ResetForNextPhase()
    SH.PersonalWarning:Hide()
    self.assignments = {}
    SH.Comms.receivedCount = 0
    SH.Comms.receivedMarkers = {}
    self.cycle = self.cycle + 1
    self.revision = 0
    self.surgeIndex = 0
    SH.OrderFrame:Update(nil)
    self:RefreshDisplays()
end

function SH.Encounter:ComputeDropOrder()
    if not self:IsComplete() then return nil end
    local layout = SH.Store:GetLayout()
    local dropPositions = {}
    for order = 1, 3 do
        dropPositions[order] = SH.Const:Opposite(self.assignments[order])
    end

    dropPositions[4] = SH.Const.EXIT_POSITION
    local drops = {}
    for order = 1, 4 do drops[order] = layout[dropPositions[order]] end
    return drops, dropPositions
end

function SH.Encounter:OnAssignmentsComplete()
    local drops = self:ComputeDropOrder()
    SH.OrderFrame:Update(drops)
end

function SH.Encounter:RefreshDisplays()
    local options = SH.Store:Options()
    local previewing = options.previewFrames and not self.active and not self.testMode
    SH.RoomMap:RefreshLayout()
    SH.RoomMap:RefreshAssignments()
    SH.RoomMap:RefreshVisibility()
    if self:IsComplete() then
        local drops = self:ComputeDropOrder()
        SH.OrderFrame:Update(drops)
        SH.NSRTMacros:SetOrder(drops)
    elseif previewing then
        local layout = SH.Store:GetLayout()
        local previewDrops = {layout[2], layout[3], layout[6], layout[1]}
        SH.OrderFrame:ShowPreview(previewDrops)
        SH.NSRTMacros:SetOrder(previewDrops)
    else
        if (self.active or self.testMode) and SH.Store:Options().receiveNSRT and (SH.Comms.receivedCount or 0) > 0 then
            SH.OrderFrame:ShowReceived(SH.Comms.receivedMarkers, SH.Comms.receivedCount)
        else
            SH.OrderFrame:Update(nil)
        end
        SH.NSRTMacros:SetOrder(nil)
    end
    local context = self.active or self.testMode or previewing
    local unlocked = context and not options.lockFrames
    SH.RoomMap:SetUnlocked(unlocked)
    SH.OrderFrame:SetUnlocked(unlocked)
    SH.NSRTMacros:SetUnlocked(unlocked)
    SH.NSRTMacros:RefreshVisibility()
    SH.PersonalWarning:SetUnlocked(unlocked)
    SH.PersonalWarning:RefreshVisibility()
end

function SH.Encounter:SendWarning(text, isTest)
    if not isTest and not self.active then return end
    SH.PersonalWarning:Show("%s", text)
end

function SH.Encounter:SpeakWarning(text)
    if not SH.Store:Options().ttsWarnings then return end
    if not C_VoiceChat or not C_VoiceChat.SpeakText then return end
    pcall(C_VoiceChat.SpeakText, 0, text, 0, 100, false)
end

function SH.Encounter:WarnSurge(index, isTest)
    if not isTest and not self.active then return end
    local options = SH.Store:Options()
    local showWarning = options.raidWarningSurges or isTest
    if not showWarning and not options.ttsWarnings then return end
    local drops = self:ComputeDropOrder()
    if not drops then
        local first = index == 1 and 1 or 3
        if showWarning and SH.Store:Options().receiveNSRT and (SH.Comms.receivedCount or 0) >= first then
            local markers = SH.Comms.receivedMarkers
            local second = first + 1
            if (SH.Comms.receivedCount or 0) >= second or second == 4 then
                local secondMarker = SH.Store:GetLayout()[SH.Const.EXIT_POSITION]
                if second <= SH.Comms.receivedCount then secondMarker = markers[second] end
                SH.PersonalWarning:Show("Surges to |TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%s:0|t and |TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%s:0|t",
                    markers[first], secondMarker)
                return
            end
        end
        if isTest then self:SendWarning("Surge assignments are incomplete", true) end
        return
    end
    local first = index == 1 and 1 or 3
    if showWarning then
        self:SendWarning(string.format("Surges to %s and %s", SH.Const:MarkerToken(drops[first]), SH.Const:MarkerToken(drops[first + 1])), isTest)
    end
    self:SpeakWarning(string.format("Surges to %s and %s", SH.Const:MarkerName(drops[first]), SH.Const:MarkerName(drops[first + 1])))
end

function SH.Encounter:WarnPush(index, isTest)
    if not isTest and not self.active then return end
    local options = SH.Store:Options()
    local showWarning = options.raidWarningPushes or isTest
    if not showWarning and not options.ttsWarnings then return end
    local drops = self:ComputeDropOrder()
    local markerID = drops and drops[index]
    if not markerID then
        if showWarning and SH.Store:Options().receiveNSRT and (SH.Comms.receivedCount or 0) >= index then
            SH.PersonalWarning:Show("Push toward |TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%s:0|t", SH.Comms.receivedMarkers[index])
        end
        return
    end
    if showWarning then self:SendWarning("Push toward " .. SH.Const:MarkerToken(markerID), isTest) end
    self:SpeakWarning("Push toward " .. SH.Const:MarkerName(markerID))
end

function SH.Encounter:OnTimelineAdded(eventInfo)
    if not self.active or not readable(eventInfo) or type(eventInfo) ~= "table" then return end
    if not readable(eventInfo.source) or eventInfo.source ~= 0 then return end
    if not readable(eventInfo.id) or not readable(eventInfo.duration) then return end
    local eventID = eventInfo.id
    local duration = tonumber(eventInfo.duration)
    if not eventID or not duration then return end
    if self.seenTimelineEvents[eventID] then return end
    self.seenTimelineEvents[eventID] = true

    local rounded = math.floor(duration + 0.5)
    local variableSurge = false
    if VARIABLE_EVENT_DURATIONS[rounded] then
        self.variableTimelineStep = ((self.variableTimelineStep or 0) % 3) + 1
        variableSurge = self.variableTimelineStep == 2
    end

    if sameSpellName(eventInfo.spellName, SURGE_SPELL_ID) or INITIAL_SURGE_DURATIONS[rounded] or variableSurge then
        self.surgeIndex = (self.surgeIndex or 0) + 1
        local index = ((self.surgeIndex - 1) % 2) + 1
        self.timelineEvents[eventID] = {kind = "surge", index = index}
        self.timers["surge" .. eventID] = C_Timer.NewTimer(math.max(0, duration - SURGE_WARNING_LEAD), function()
            if SH.Encounter.active then SH.Encounter:WarnSurge(index, false) end
        end)
        return
    end

    if sameSpellName(eventInfo.spellName, HOWLING_SPELL_ID) or rounded == 100 or rounded == 111 or rounded == 125 then
        self.timelineEvents[eventID] = {kind = "digIn", started = false}
    end
end

function SH.Encounter:OnTimelineChanged(eventID)
    if not self.active then return end
    local tracked = self.timelineEvents[eventID]
    if not tracked then return end
    local ok, state = pcall(C_EncounterTimeline.GetEventState, eventID)
    if not ok or not readable(state) then return end
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
            if SH.Encounter.active then SH.Encounter:ResetForNextPhase() end
        end)
    end
end

function SH.Encounter:EnterTestMode()
    if self.active then SH:Print("Test mode is unavailable during the Sszorak encounter."); return false end
    self:CancelTimers()
    SH.Comms.receivedCount = 0
    SH.Comms.receivedMarkers = {}
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
    SH.PersonalWarning:Hide()
    self.testMode = false
    self.assignments = {}
    SH.RoomMap:StopRotation()
    self:RefreshDisplays()
    if SH.OptionsUI and SH.OptionsUI.testFrame then SH.OptionsUI.testFrame:Hide() end
    return true
end
