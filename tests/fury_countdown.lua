local SH = ...
local E, P, options = SH.Encounter, SH.PersonalWarning, SH.Store:Options()
local function check(value, reason) assert(value, "Fury countdown: " .. reason) end
local originalTime, originalVoice, originalShow = GetTime, C_VoiceChat, P.Show
local originalPlay, originalStop = PlaySoundFile, StopSound
local saved = {show = options.showFuryCountdown, voice = options.furyVoiceCountdown, tts = options.ttsWarnings,
    preview = options.previewFrames, schedule = options.encounterSchedules[16]}
local currentTime, speech, displays, audio = 100, {}, {}, {}
local handles, nextHandle, ttsRequests = {}, 0, 0
GetTime = function() return currentTime end
C_VoiceChat = {SpeakText = function() ttsRequests = ttsRequests + 1 end,
    StopSpeakingText = function() error("Fury interrupted the shared speech queue") end}
PlaySoundFile = function(path, channel)
    check(channel == "Master", "voice did not use the Master channel")
    local cue = path:match("SszorakHelper\\Media\\Countdown\\([^\\]+)%.ogg$")
    check(cue == "stack" or tonumber(cue) and tonumber(cue) >= 1 and tonumber(cue) <= 5, "invalid voice cue")
    nextHandle = nextHandle + 1
    handles[nextHandle] = {cue = cue, time = currentTime}
    audio[#audio + 1] = handles[nextHandle]
    speech[#speech + 1] = cue == "stack" and "Stack" or cue
    return true, nextHandle
end
StopSound = function(handle)
    check(handles[handle] and not handles[handle].stopped, "stopped an unrelated sound or stopped the same handle twice")
    handles[handle].stopped = currentTime
end
P.Show = function(self, format, ...)
    displays[#displays + 1] = {format, ...}
    return originalShow(self, format, ...)
end
options.previewFrames, options.showFuryCountdown, options.furyVoiceCountdown, options.ttsWarnings = false, true, false, false
local function drain()
    local ticks = 0
    while E.timers.furyTick do
        local timer = E.timers.furyTick
        check(not timer.cancelled and timer.delay > 0 and timer.delay <= 1, "invalid tick timer")
        currentTime = currentTime + timer.delay
        timer.callback()
        ticks = ticks + 1
        check(ticks <= 12, "countdown left repeating work")
    end
end
local function resetOutput() speech, displays, audio = {}, {}, {} end

-- NSRT's Mythic timestamps are the stack endpoints, not display starts.
check(saved.show == true and saved.voice == false, "incorrect default options")
E:Stop()
E:Start("Sszorak", 16)
for i, endpoint in ipairs({25.5, 72.5, 152.5, 199.5, 279.5, 326.6}) do
    local event, timer = E.scheduleByID["fury" .. i], E.timers["schedule:fury" .. i]
    check(event and event.time == endpoint and event.kind == "fury", "NSRT endpoint missing")
    check(timer and math.abs(timer.delay - (endpoint - 5)) < 0.001, "countdown starts at wrong time")
end
currentTime = E.startedAt + 20.5
E.timers["schedule:fury1"].callback()
check(displays[#displays][2] == 5 and P.frame:IsShown(), "live countdown did not start at five")
drain()
check(#displays == 6, "countdown repeated or missed a number")
for i = 1, 5 do
    check(displays[i][1] == "Stack in %d" and displays[i][2] == 6 - i, "warning text or countdown numbers incorrect")
end
check(displays[6][1] == "Stack now", "short stack cue missing")
check(#speech == 0 and not E.furyCountdown and not E.timers.furyTick, "silent countdown leaked voice or work")
E:Stop()
for _, difficulty in ipairs({14, 15, 17}) do
    E:Start("Sszorak", difficulty)
    check(not E.timers["schedule:fury1"], "Mythic reminder leaked to other difficulties")
    E:Stop()
end

-- Edits keep the existing next-pull snapshot behavior.
local values = {}
for _, event in ipairs(SH.Store:GetTimings(16, true)) do values[event.id] = event.time end
values.fury1 = 26.5
check(SH.Store:SaveTimings(16, values), "edited Fury endpoint rejected")
E:Start("Sszorak", 16)
local scheduled = E.timers["schedule:fury1"]
check(scheduled.delay == 21.5, "edited Fury endpoint was not scheduled")
values.fury1 = 27.5
check(SH.Store:SaveTimings(16, values) and scheduled.delay == 21.5, "edit changed current pull")
E:Stop()
E:Start("Sszorak", 16)
check(E.timers["schedule:fury1"].delay == 22.5, "next pull ignored edited Fury endpoint")
E:Stop()
options.encounterSchedules[16] = saved.schedule

-- Exercise the real Test Mode button, with independent visual and voice choices.
resetOutput()
options.showFuryCountdown, options.furyVoiceCountdown, options.ttsWarnings = false, true, false
SH.OptionsUI:EnterTestMode()
local testButton = SH.OptionsUI.testButtons["Fury Countdown"]
check(testButton ~= nil, "Fury button missing from Test Mode")
testButton.scripts.OnClick(testButton)
check(displays[1][2] == 5, "Test Mode did not preview a disabled visual warning")
drain()
check(table.concat(speech, ",") == "5,4,3,2,1,Stack", "voice depends on general TTS")
check(ttsRequests == 0 and #audio == 6, "Fury still queued synthesized speech")
for i = 1, 5 do
    check(math.abs(audio[i + 1].time - audio[i].time - 1) < 0.001, "voice cue drifted from its display tick")
    check(audio[i].stopped == audio[i + 1].time, "previous countdown cue was allowed to linger")
end
check(audio[6].time == currentTime, "Stack voice did not start on the final display tick")
check(SH.OptionsUI.furyCountdownToggle and SH.OptionsUI.furyVoiceToggle, "countdown settings missing")
resetOutput()
options.showFuryCountdown, options.furyVoiceCountdown, options.ttsWarnings = true, false, true
testButton.scripts.OnClick(testButton)
drain()
check(#speech == 0 and #displays == 6, "general TTS overrode Fury voice toggle")

-- Restart, Reset and Quit must not leave old callbacks speaking later.
testButton.scripts.OnClick(testButton)
local oldTick = E.timers.furyTick
testButton.scripts.OnClick(testButton)
check(oldTick.cancelled, "restart left prior countdown running")
local outputCount = #displays
oldTick.callback()
check(#displays == outputCount, "cancelled callback resurrected countdown")
local resetTick = E.timers.furyTick
SH.OptionsUI.testButtons.Reset.scripts.OnClick(SH.OptionsUI.testButtons.Reset)
check(resetTick.cancelled and not E.furyCountdown and not E.timers.furyTick, "Reset left countdown running")
testButton.scripts.OnClick(testButton)
local quitTick = E.timers.furyTick
SH.OptionsUI:QuitTestMode()
check(quitTick.cancelled and not E.furyCountdown and not P.frame:IsShown(), "quitting left countdown active")
check(not E:WarnFury(5, true) and not E:WarnFury(5, false), "inactive encounter accepted countdown")

-- Late callbacks skip elapsed numbers and still end at the configured time.
E:Start("Sszorak", 16)
resetOutput()
options.showFuryCountdown, options.furyVoiceCountdown = false, true
currentTime = E.startedAt + 22.7
E.timers["schedule:fury1"].callback()
check(speech[1] == "3" and #displays == 0, "late or voice-only reminder is incorrect")
drain()
check(table.concat(speech, ",") == "3,2,1,Stack", "late countdown missed stack time")
check(math.abs(currentTime - (E.startedAt + 25.5)) < 0.02, "countdown drifted from endpoint")
options.showFuryCountdown, options.furyVoiceCountdown = true, true
E:WarnFury(5, false)
local stopTick = E.timers.furyTick
E:Stop()
check(stopTick.cancelled and not E.furyCountdown, "encounter end left countdown running")
local speechCount = #speech
stopTick.callback()
check(#speech == speechCount, "stopped encounter spoke delayed number")
E:Start("Sszorak", 16)
options.showFuryCountdown, options.furyVoiceCountdown = false, false
check(not E:WarnFury(5, false) and not E.timers.furyTick, "disabled warning started work")
E:Stop()
for _, sound in pairs(handles) do check(sound.stopped ~= nil, "Reset/Quit/end left a countdown sound alive") end
check(ttsRequests == 0, "Fury used the shared TTS queue")

GetTime, C_VoiceChat, P.Show = originalTime, originalVoice, originalShow
PlaySoundFile, StopSound = originalPlay, originalStop
options.showFuryCountdown, options.furyVoiceCountdown, options.ttsWarnings, options.previewFrames = saved.show, saved.voice, saved.tts, saved.preview
print("Fury countdown checks passed: NSRT endpoints, editable timers, visual/voice settings, Test Mode and cleanup.")
