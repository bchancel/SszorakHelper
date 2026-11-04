local SH = ...
local E, P, options = SH.Encounter, SH.PersonalWarning, SH.Store:Options()
local function check(value, message) assert(value, "Wind warnings: " .. message) end
local function near(a, b) return math.abs(a - b) < 0.00001 end
local originalTime = GetTime
local saved = {preview = options.previewFrames, pushes = options.raidWarningPushes,
    delay = options.personalWarningDelay, tts = options.ttsWarnings, schedule = options.encounterSchedules[16]}
GetTime = function() return 100 end
options.previewFrames, options.raidWarningPushes, options.ttsWarnings = false, true, false
options.personalWarningDelay = 6.5

-- Lead time applies to every Mythic wind without changing saved event times or resets.
for _, difficulty in ipairs({17, 14, 15, 16}) do
    E:Start("Sszorak", difficulty)
    local lead = difficulty == 16 and 2 or 0
    for _, event in ipairs(E.timings) do
        if event.kind == "wind" or event.kind == "phaseReset" then
            local expected = event.time - (event.kind == "wind" and lead or 0)
            check(near(E.timers["schedule:" .. event.id].delay, expected), "incorrect wind/reset timing on " .. difficulty)
        end
    end
    E:AcceptProposal(1, 2)
    E:AcceptProposal(2, 3)
    E:AcceptProposal(3, 4)
    E.timers["schedule:intermission1wind2"].callback()
    check(P.frame:IsShown() and P.timer.delay == 6.5 + lead, "local warning duration lost lead time")
    E:ClearAssignments()
    SH.Comms.receivedCount, SH.Comms.receivedMarkers = 3, {1, 2, 3}
    E:WarnPush(2, false)
    check(P.frame.text.formatted[2] == 2 and P.timer.delay == 6.5 + lead, "received warning duration or marker changed")
    local warningTimer = P.timer
    E:Stop()
    check(warningTimer.cancelled and not P.frame:IsShown(), "stop left an early warning visible")
end

local edits = {}
for _, event in ipairs(SH.Store:GetTimings(16)) do edits[event.id] = event.time end
edits.intermission1wind2 = edits.intermission1wind2 + 1
check(SH.Store:SaveTimings(16, edits), "could not save custom wind time")
E:Start("Sszorak", 16)
check(near(E.timers["schedule:intermission1wind2"].delay, edits.intermission1wind2 - 2), "custom wind did not warn early")
check(E.scheduleByID.intermission1wind2.time == edits.intermission1wind2, "lead time changed configured timestamp")
E:ScheduleEvent({id = "lateWind", kind = "wind", index = 1, time = 1})
check(E.timers["schedule:lateWind"].delay == 0, "late wind used a negative timer")
E:Stop()

options.previewFrames, options.raidWarningPushes = saved.preview, saved.pushes
options.personalWarningDelay, options.ttsWarnings, options.encounterSchedules[16] = saved.delay, saved.tts, saved.schedule
GetTime = originalTime
E:RefreshDisplays()
print("Wind warning checks passed: Mythic lead time, custom schedules, duration, received markers and cleanup.")
