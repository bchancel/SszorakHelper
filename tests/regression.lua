-- Offline regression checks. Run from the repository root with Lua 5.1.
local combat, lockdown, inRaid = false, false, true
local sends, result, now = 0, 0, 10
local instanceID, subzone = 3004, ""
local handlers, macros, secrets = {}, {}, {}
local SH = {modules = {}, version = "test"}
local noop = function() end
local function check(value, message) assert(value, message) end
local function secret()
    local value = setmetatable({}, {
        __tostring = function() error("secret converted") end,
        __concat = function() error("secret concatenated") end,
        __add = function() error("secret arithmetic") end,
        __lt = function() error("secret compared") end,
    })
    secrets[value] = true
    return value
end
issecretvalue = function(value) return secrets[value] == true end
STANDARD_TEXT_FONT = "font.ttf"
Enum = {SendAddonMessageResult = {Success = 0}}
InCombatLockdown = function() return combat end
IsInRaid = function() return inRaid end
GetInstanceInfo = function() return nil, nil, nil, nil, nil, nil, nil, instanceID end
GetSubZoneText = function() return subzone end
GetTime = function() return now end
GetServerTime = GetTime
UnitFullName = function() return "Caller", "Realm" end
UnitIsGroupLeader = function() return true end
GetNumGroupMembers = function() return 1 end
strtrim = function(s) return s:match("^%s*(.-)%s*$") end
wipe = function(t) for k in pairs(t) do t[k] = nil end end
C_ChatInfo = {
    InChatMessagingLockdown = function() return lockdown end,
    SendAddonMessage = function() sends = sends + 1; return result end,
    RegisterAddonMessagePrefix = noop,
}
GetMacroInfo = function(name) if macros[name] then return name, 1, macros[name] end end
CreateMacro = function(name, icon, body)
    check(not combat, "created macro in combat")
    macros[name] = body
    return tonumber(name:match("(%d+)$"))
end
EditMacro = function(name, newName, icon, body)
    check(not combat, "edited macro in combat")
    macros[newName] = body
    return tonumber(newName:match("(%d+)$"))
end
C_Timer = {
    NewTimer = function(delay, callback) return {delay = delay, callback = callback, Cancel = function(t) t.cancelled = true end} end,
    After = noop,
}
GameTooltip = setmetatable({}, {__index = function() return noop end})
local frameMethods = {}
local function protected(frame)
    if combat and frame.secure then error("secure frame mutated during combat") end
end
local function frame(parent, secure)
    return setmetatable({parent = parent or false, moving = false, shown = true, scripts = {}, attributes = {}, registeredEvent = false, secure = secure or (parent and parent.secure) or false}, {__index = frameMethods})
end
function frameMethods:SetAttribute(key, value) protected(self); self.attributes[key] = value end
function frameMethods:GetAttribute(key) return self.attributes[key] end
function frameMethods:RegisterForClicks(...) self.clicks = {...} end
function frameMethods:SetScript(key, value) self.scripts[key] = value end
function frameMethods:CreateFontString() return frame(self) end
function frameMethods:CreateTexture() return frame(self) end
function frameMethods:CreateLine() return frame(self) end
function frameMethods:Show() protected(self); self.shown = true end
function frameMethods:Hide() protected(self); self.shown = false end
function frameMethods:SetShown(value) protected(self); self.shown = value and true or false end
function frameMethods:IsShown() return self.shown end
function frameMethods:SetText(value) self.textValue = value end
function frameMethods:GetText() return self.textValue end
function frameMethods:GetParent() return self.parent end
function frameMethods:GetFrameLevel() return rawget(self, "level") or 1 end
function frameMethods:SetFrameLevel(value) self.level = value end
function frameMethods:SetFrameStrata(value) protected(self); self.strata = value end
function frameMethods:GetFrameStrata() return rawget(self, "strata") or (self.parent and self.parent:GetFrameStrata()) end
function frameMethods:EnableMouse(value) self.mouseEnabled = value end
function frameMethods:RegisterForDrag(...) self.dragButtons = {...} end
function frameMethods:StartMoving() self.moving = true end
function frameMethods:StopMovingOrSizing() self.moving = false end
function frameMethods:SetVerticalScroll(value) self.scrollOffset = value end
function frameMethods:SetChecked(value) self.checked = value end
function frameMethods:GetChecked() return self.checked end
function frameMethods:IsEnabled() return self.enabled ~= false end
function frameMethods:SetEnabled(value) self.enabled = value end
function frameMethods:SetBackdropColor(r, g, b, a) self.opacity = a end
function frameMethods:SetValue(value)
    self.value = value
    if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, value, false) end
end
function frameMethods:SetFormattedText(format, ...) self.formatted = {format, ...} end
function frameMethods:SetFont(path, size) self.fontSize = size end
function frameMethods:GetCenter() return rawget(self, "centerX") or 400, rawget(self, "centerY") or 300 end
function frameMethods:GetEffectiveScale() return (rawget(self, "scale") or 1) * (self.parent and self.parent:GetEffectiveScale() or 1) end
function frameMethods:SetScale(value) protected(self); self.scale = value end
function frameMethods:SetPoint(...) protected(self); self.point = {...} end
function frameMethods:GetPoint() return unpack(self.point or {"CENTER", UIParent, "CENTER", 0, 0}) end
function frameMethods:RegisterUnitEvent(event, unit) self.registeredEvent = event; self.registeredUnit = unit end
function frameMethods:UnregisterEvent(event) if self.registeredEvent == event then self.registeredEvent = false end end
function frameMethods:ClearAllPoints() protected(self) end
function frameMethods:SetSize(width, height) protected(self); self.width, self.height = width, height end
function frameMethods:GetWidth() return self.width end
function frameMethods:GetHeight() return self.height end
setmetatable(frameMethods, {__index = function() return noop end})
UIParent = frame()
CreateFrame = function(_, _, parent, template)
    check(not combat, "created frame in combat")
    return frame(parent, template and template:find("Secure") ~= nil)
end
function SH:RegisterEvent(event, callback)
    handlers[event] = handlers[event] or {}
    table.insert(handlers[event], callback)
end
function SH:Print(message) self.lastPrint = message end
local function loadModule(path) assert(loadfile(path))("SszorakHelper", SH) end
loadModule("Core/Constants.lua")
loadModule("Core/Store.lua")
SH.Store:OnInitialize()
check(SH.Store:Options().frameBackgroundOpacity == 0.5, "fresh opacity must be 50 percent")
SH.Store:Options().frameBackgroundOpacity = 0.25
SH.Store:Options().rotateMap = true
SH.Store:Options().observedSchedules[14] = {
    {id = "intermission4rotationStop", kind = "rotationStop", time = 600},
}
SH.Store:OnInitialize()
check(SH.Store:Options().frameBackgroundOpacity == 0.25, "saved opacity was overwritten")
check(SH.Store:Options().rotateMap == nil, "removed rotation option survived migration")
for _, event in ipairs(SH.Store:GetTimings(14)) do
    check(event.kind ~= "rotationStop", "removed rotation event remained in schedule editor")
end
check(SH.Store:Options().nsrtDoubleRow == false, "double row must be opt-in")
loadModule("UI/Widgets.lua")
SH.RoomMap = setmetatable({frame = frame()}, {__index = function() return noop end})
loadModule("UI/OrderFrame.lua")
SH.OrderFrame:OnInitialize()
loadModule("UI/PersonalWarning.lua")
SH.PersonalWarning:OnInitialize()
SH.Store:Options().previewFrames = true
SH.PersonalWarning:SetUnlocked(true)
SH.PersonalWarning:RefreshVisibility()
check(SH.PersonalWarning.frame:IsShown(), "warning frame was not shown in preview")
check(SH.PersonalWarning.frame.text.textValue == "Personal warning preview", "warning preview text is wrong")
check(SH.PersonalWarning.frame._shUnlocked, "warning frame did not unlock")
SH.Store:Options().previewFrames = false
SH.PersonalWarning:RefreshVisibility()
check(not SH.PersonalWarning.frame:IsShown(), "warning preview did not hide")
loadModule("UI/NSRTMacros.lua")
loadModule("UI/SurgeTargets.lua")
loadModule("Core/Comms.lua")
loadModule("Core/Encounter.lua")
SH.NSRTMacros:OnInitialize()
SH.SurgeTargets:OnInitialize()
SH.Comms:OnInitialize()

-- API success is enum zero; errors and lockdown must never claim success.
check(SH.Comms:Send("HELLO|1|test"), "success enum rejected")
result = 3
check(not SH.Comms:Send("HELLO|1|test"), "throttle reported as success")
local previousSends = sends
lockdown = true
check(not SH.Comms:Send("HELLO|1|test") and sends == previousSends, "sent under lockdown")
check(not SH.Comms:PublishLayout(), "layout publish falsely succeeded")
SH.Encounter.testMode = true
lockdown = false
check(not SH.Comms:Send("HELLO|1|test") and sends == previousSends, "test mode sent traffic")
SH.Encounter.testMode = false

-- Local planning works immediately even though peers cannot coordinate in a fight.
SH.Encounter.active = true
SH.Encounter.cycle = 1
SH.Comms:ProposeAssignment(1, 2)
SH.Comms:ProposeAssignment(2, 3)
SH.Comms:ProposeAssignment(3, 6)
check(SH.Encounter:IsComplete(), "local assignment blocked by coordinator")
check(sends == previousSends, "local assignments tried sending")
local before = SH.Encounter.assignments[1]
SH.Comms:OnAddonMessage("CLEAR|1", "Other-Realm")
check(SH.Encounter.assignments[1] == before, "active encounter consumed old addon state")

-- Drop order follows the caller's wind order and keeps Exit in Surge 2.
SH.Encounter:ClearAssignments()
SH.Comms:ProposeAssignment(1, 4)
SH.Comms:ProposeAssignment(2, 2)
SH.Comms:ProposeAssignment(3, 3)
local drops = SH.Encounter:ComputeDropOrder()
check(drops[1] == 3 and drops[2] == 2 and drops[3] == 7 and drops[4] == 5, "base drop order changed")

-- Received payloads are opaque: display them without parsing, including warnings.
SH.Encounter:ClearAssignments("test")
local values = {secret(), secret(), secret(), secret()}
for i = 1, 4 do SH.Comms:OnRaidMessage(values[i], secret()) end
check(SH.Comms.receivedCount == 4, "receiver did not collect four slots")
check(SH.OrderFrame.frame.slots[4].received.formatted[2] == values[4], "secret did not reach renderer")
check(not SH.Encounter:IsComplete(), "received secrets became editable assignments")
SH.Store:Options().raidWarningPushes = true
SH.Encounter:WarnSurge(2, false)
check(SH.PersonalWarning.frame.text.formatted[2] == values[3], "surge marker lost")
check(SH.PersonalWarning.frame.text.formatted[3] == values[4], "exit marker lost")
SH.Encounter:WarnPush(2, false)
check(SH.PersonalWarning.frame.text.formatted[2] == values[2], "push marker lost")
SH.Encounter:RefreshDisplays()
check(SH.OrderFrame.receivedCount == 4, "refresh erased received order")
SH.Comms:OnRaidMessage(values[1], secret())
check(SH.Comms.receivedCount == 1, "next batch did not restart")
SH.Store:Options().receiveNSRT = false
SH.Comms:OnRaidMessage(values[2], secret())
check(SH.Comms.receivedCount == 1, "disabled receiver consumed chat")
SH.Encounter:Stop()
check(not SH.PersonalWarning.frame:IsShown(), "warning lingered after encounter")
check(SH.Comms.receivedCount == 0, "received batch survived encounter")

-- Fixed secure macros, retryable icons, click progression, and deferred visibility.
for i = 1, 8 do macros["NSRT_SSZORAK_" .. i] = "/raid " .. i end
SH.NSRTMacros:RefreshLayout()
SH.NSRTMacros:SetOrder({6, 4, 2, 5})
check(#SH.NSRTMacros.secureFrame.buttons == 8, "optional secure buttons were not prepared before combat")
for index = 1, 6 do
    local markerID = SH.NSRTMacros.markerIDs[index]
    check(markerID ~= SH.Store:GetLayout()[SH.Const.EXIT_POSITION], "exit macro appeared on panel")
    check(markerID ~= SH.Store:GetLayout()[SH.Const.ENTRANCE_POSITION], "entrance macro appeared on panel")
end
for i, button in ipairs(SH.NSRTMacros.secureFrame.buttons) do
    check(button.attributes.useOnKeyDown == false, "click depends on user CVar")
    check(button.attributes.type == (i <= 6 and "macro" or nil), "live macro visibility disagrees with its binding")
    check(button:IsShown() == (i <= 6) and SH.NSRTMacros.frame.slots[i]:IsShown() == (i <= 6), "Entrance / Exit did not default to hidden")
    check(not SH.NSRTMacros.frame.slots[i].blocker:IsShown(), "available macro blocked")
end
SH.NSRTMacros:TogglePanel()
check(SH.NSRTMacros.secureFrame:IsShown(), "toggle did not show secure panel")
combat = true
SH.NSRTMacros:TogglePanel()
check(SH.NSRTMacros.secureFrame:IsShown(), "combat visibility changed")
SH.NSRTMacros:RefreshLayout()
local button = SH.NSRTMacros.secureFrame.buttons[1]
button.scripts.PostClick(button, "LeftButton", false)
check(SH.NSRTMacros.nextStep == 2, "mouse-up not tracked exactly once")
button.scripts.PostClick(button, "LeftButton", true)
check(SH.NSRTMacros.nextStep == 2, "mouse-down double counted")
SH.NSRTMacros:OnMacroClicked(2)
SH.NSRTMacros:OnMacroClicked(4)
check(SH.NSRTMacros.nextStep == 4, "side-macro sequence did not finish after three clicks")
check(rawget(SH.NSRTMacros.frame, "status") == nil, "macro panel still includes status text")
combat = false
for _, callback in ipairs(handlers.PLAYER_REGEN_ENABLED) do callback() end
check(not SH.NSRTMacros.secureFrame:IsShown(), "queued hide not applied")
macros.NSRT_SSZORAK_6 = "/raid unexpected"
SH.NSRTMacros:RefreshLayout()
check(SH.NSRTMacros.secureFrame.buttons[1].attributes.type == nil, "modified macro remained executable")
SH.Encounter.testMode = true
SH.NSRTMacros:RefreshLayout()
check(SH.NSRTMacros.secureFrame.buttons[1].attributes.type == nil, "invalid macro enabled in raid test")
check(not SH.NSRTMacros.available[1], "raid test pretended a missing macro works")

-- Two test-mode clients use the actual raid-event receiver. The transport here
-- simulates delivery; protected hardware execution must also be tested in WoW.
macros.NSRT_SSZORAK_6 = "/raid 6"
SH.Store:Options().receiveNSRT = true
SH.Encounter:EnterTestMode()
SH.NSRTMacros:RefreshLayout()
local recipientHandlers = {}
local recipient = {
    modules = {}, Const = SH.Const, Store = SH.Store, Widgets = SH.Widgets,
    Encounter = {active = false, testMode = true, IsComplete = function() return false end},
    RegisterEvent = function(_, event, callback) recipientHandlers[event] = callback end,
}
assert(loadfile("UI/OrderFrame.lua"))("SszorakHelper", recipient)
recipient.OrderFrame:OnInitialize()
assert(loadfile("Core/Comms.lua"))("SszorakHelper", recipient)
recipient.Comms:OnInitialize()
button = SH.NSRTMacros.secureFrame.buttons[1]
check(button.attributes.type == "macro", "raid Test mode disabled real macros")
check(button.attributes.macro == "NSRT_SSZORAK_6", "raid Test mode bound wrong macro")
local message = macros[button.attributes.macro]:match("^/raid (.+)$")
for _, callback in ipairs(handlers.CHAT_MSG_RAID) do callback("CHAT_MSG_RAID", message, "Caller-Realm") end
recipientHandlers.CHAT_MSG_RAID("CHAT_MSG_RAID", message, "Caller-Realm")
button.scripts.PostClick(button, "LeftButton", false)
check(recipient.Comms.receivedCount == 1, "second test client dropped first message")
check(recipient.OrderFrame.frame:IsShown(), "second test client did not show received order")
check(recipient.OrderFrame.frame.slots[1].received.formatted[2] == "6", "second client displayed wrong marker")
check(SH.Comms.receivedCount == 1, "raid Test mode added a duplicate local echo")
recipientHandlers.CHAT_MSG_RAID_LEADER("CHAT_MSG_RAID_LEADER", "4", "Caller-Realm")
check(recipient.Comms.receivedCount == 2, "leader macro message dropped in Test mode")
SH.Comms:OnRaidMessage(values[2])
SH.Encounter:RefreshDisplays()
check(SH.OrderFrame.receivedCount == 2, "Test refresh erased received order")
SH.Encounter:WarnSurge(1, true)
check(SH.PersonalWarning.frame.text.formatted[3] == values[2], "test Surge overwrote received warning")
SH.Encounter:WarnPush(2, true)
check(SH.PersonalWarning.frame.text.formatted[2] == values[2], "test Push ignored received marker")
recipient.Encounter.testMode = false
recipientHandlers.CHAT_MSG_RAID("CHAT_MSG_RAID", "2", "Caller-Realm")
check(recipient.Comms.receivedCount == 2, "inactive receiver consumed raid chat")

-- Leaving/joining a raid updates bindings; solo Test uses the same receiver.
inRaid = false
for _, callback in ipairs(handlers.GROUP_ROSTER_UPDATE) do callback() end
check(button.attributes.type == nil, "solo Test attempted raid chat")
local receivedBefore = SH.Comms.receivedCount
button.scripts.PostClick(button, "LeftButton", false)
check(SH.Comms.receivedCount == receivedBefore + 1, "solo click did not exercise receiver")
inRaid = true
for _, callback in ipairs(handlers.GROUP_ROSTER_UPDATE) do callback() end
check(button.attributes.type == "macro", "joining raid did not restore real Test macros")

-- Font clamping and warning replacement cancel the prior timer.
SH.Store:Options().personalWarningFontSize = 500
SH.PersonalWarning:Show("%s", "first")
local timer = SH.PersonalWarning.timer
check(SH.PersonalWarning.frame.text.fontSize == 72, "font upper bound ignored")
SH.Store:Options().personalWarningFontSize = 8
SH.PersonalWarning:Show("%s", "second")
check(timer.cancelled, "old warning timer still active")
check(SH.PersonalWarning.frame.text.fontSize == 12, "font lower bound ignored")

-- Duration affects new warnings, and replacing a warning cancels its timeout.
check(SH.PersonalWarning.timer.delay == 4, "default warning duration changed")
SH.Store:Options().personalWarningDelay = 7.5
SH.PersonalWarning:Show("%s", "longer")
check(SH.PersonalWarning.timer.delay == 7.5, "warning duration ignored")
SH.PersonalWarning.timer.callback()
check(not SH.PersonalWarning.frame:IsShown(), "warning timeout did not hide frame")
SH.Store:Options().personalWarningDelay = 100
check(SH.Store:GetPersonalWarningDelay() == 10, "warning duration upper bound ignored")
SH.Store:Options().personalWarningDelay = -1
check(SH.Store:GetPersonalWarningDelay() == 1, "warning duration lower bound ignored")
SH.Store:Options().personalWarningDelay = 4

-- Absolute schedules preserve precision and isolate each difficulty.
local function eventByID(events, id)
    for _, event in ipairs(events) do if event.id == id then return event end end
end
local function timingValues(events)
    local values = {}
    for _, event in ipairs(events) do values[event.id] = event.time end
    return values
end
local heroic = SH.Store:GetTimings(15)
check(eventByID(heroic, "surge1").time == 32.22, "Heroic first cast time incorrect")
check(eventByID(heroic, "surge7").time == 446.65, "later surge missing from editor")
check(eventByID(heroic, "intermission1wind2").time == 119.17, "wind time is not measured from pull")
local normalDefaults, lfrDefaults = SH.Store:GetTimings(14, true), SH.Store:GetTimings(17, true)
check(#normalDefaults == #lfrDefaults and #lfrDefaults > 0, "Raid Finder default schedule is incomplete")
for index, event in ipairs(normalDefaults) do
    check(lfrDefaults[index].id == event.id and lfrDefaults[index].time == event.time, "Raid Finder default differs from Normal")
end
local lfrEdits = timingValues(lfrDefaults)
lfrEdits.surge1 = 38
check(SH.Store:SaveTimings(17, lfrEdits), "Raid Finder edits rejected")
check(eventByID(SH.Store:GetTimings(17), "surge1").time == 38, "Raid Finder edit ignored")
check(eventByID(SH.Store:GetTimings(14), "surge1").time == 36.25, "Raid Finder edit changed Normal")
check(eventByID(SH.Store:GetTimings(17, true), "surge1").time == 36.25, "Raid Finder reset did not restore Normal defaults")
check(SH.Store:SaveTimings(17, timingValues(lfrDefaults)), "Raid Finder reset rejected")
local edits = timingValues(heroic)
edits.surge1 = "0:34.25"
check(SH.Store:SaveTimings(15, edits), "valid elapsed timestamp rejected")
edits.surge2 = "0:20"
check(not SH.Store:SaveTimings(15, edits), "out-of-order events accepted")
edits.surge2 = "1:75"
check(not SH.Store:SaveTimings(15, edits), "malformed timestamp accepted")
edits.surge2 = math.huge
check(not SH.Store:SaveTimings(15, edits), "infinite time accepted")
check(eventByID(SH.Store:GetTimings(15), "surge1").time == 34.25, "invalid save changed settings")
check(eventByID(SH.Store:GetTimings(14), "surge1").time == 36.25, "Heroic edit leaked to Normal")
SH.Store:OnInitialize()
check(eventByID(SH.Store:GetTimings(15), "surge1").time == 34.25, "schedule did not persist")
check(SH.Const:FormatFightTime(119.17) == "1:59.17", "timestamp formatting lost precision")

-- Pull timers use absolute event times, warn three seconds before casts, and snapshot edits.
SH.Encounter:Start("Sszorak", 15)
local scheduled = SH.Encounter.timers
check(scheduled["schedule:surge1"].delay == 31.25, "edited first cast did not move warning")
check(math.abs(scheduled["schedule:surge2"].delay - 81.44) < 0.001, "second surge is not from pull")
check(SH.Encounter.scheduleByID.intermission1.time == 111.17, "intermission time incorrect")
check(not scheduled["schedule:intermission1"], "reference-only intermission started a timer")
check(scheduled["schedule:intermission1wind3"].delay == 129.17, "Wind 3 time incorrect")
local firstSurge = scheduled["schedule:surge1"]
SH.Encounter:OnTimelineAdded({source = 0, id = 101, duration = 32.22})
SH.Encounter:OnTimelineAdded({source = 0, id = 101, duration = 32.22})
check(SH.Encounter.totalSurgeIndex == 1, "duplicate timeline changed occurrence counter")
check(not scheduled.surge101 and scheduled["schedule:surge1"] == firstSurge, "live timeline duplicated scheduled warning")
C_EncounterTimeline = {GetEventState = function() return 2 end}
SH.Encounter:OnTimelineChanged(101)
check(not firstSurge.cancelled, "live cast cancelled the edited schedule")
check(SH.Store:SaveTimings(15, timingValues(SH.Store:GetTimings(15, true))), "reset defaults failed")
check(firstSurge.delay == 31.25, "edit changed current pull")
local warnings = {}
local realWarnSurge, realWarnPush = SH.Encounter.WarnSurge, SH.Encounter.WarnPush
SH.Encounter.WarnSurge = function(_, index) warnings[#warnings + 1] = "surge" .. index end
SH.Encounter.WarnPush = function(_, index) warnings[#warnings + 1] = "wind" .. index end
firstSurge.callback()
scheduled["schedule:surge2"].callback()
scheduled["schedule:surge3"].callback()
scheduled["schedule:intermission1wind3"].callback()
check(table.concat(warnings, ",") == "surge1,surge2,surge1,wind3", "schedule dispatched incorrect marker pairs")
SH.Encounter.WarnSurge, SH.Encounter.WarnPush = realWarnSurge, realWarnPush
SH.Encounter:Stop()
check(firstSurge.cancelled, "encounter stop left scheduled timers running")
SH.Encounter:Start("Sszorak", 15)
check(SH.Encounter.timers["schedule:surge1"].delay == 29.22, "next pull did not adopt reset")
SH.Encounter:Stop()

-- Unlisted occurrences still use live events and record completed timings.
SH.Encounter:Start("Sszorak", 17)
check(SH.Encounter.timers["schedule:surge1"].delay == 33.25, "Raid Finder did not schedule Normal's first surge")
check(SH.Encounter.scheduleByID.intermission1.time == 125, "Raid Finder did not use Normal's intermission")
SH.Encounter.totalSurgeIndex, SH.Encounter.intermissionIndex = 5, 3
now = SH.Encounter.startedAt + 450
SH.Encounter:OnTimelineAdded({source = 0, id = 201, duration = 36})
local liveSurge = SH.Encounter.timers.surge201
check(liveSurge.delay == 33, "unknown occurrence lost live surge warning")
now = now + 36
SH.Encounter:OnTimelineChanged(201)
check(liveSurge.cancelled, "finished live surge did not cancel timer")
check(eventByID(SH.Store:GetTimings(17), "surge6").time == 486, "observed surge was not stored")
SH.Encounter:OnTimelineAdded({source = 0, id = 202, duration = 125})
now = SH.Encounter.startedAt + 611
SH.Encounter:OnTimelineChanged(202)
local wind2 = SH.Encounter.timers["schedule:intermission4wind2"]
check(wind2.delay == 8, "observed intermission did not schedule relative winds")
check(eventByID(SH.Store:GetTimings(17), "intermission4wind2").time == 619, "observed wind not stored as elapsed time")
SH.Encounter:OnTimelineChanged(202)
check(SH.Encounter.timers["schedule:intermission4wind2"] == wind2, "intermission finished twice")
SH.Encounter:Stop()
check(wind2.cancelled, "stopping unknown occurrence left wind timer")
SH.Encounter:Start("Sszorak", 17)
check(SH.Encounter.timers["schedule:surge6"].delay == 483, "recorded occurrence was not used next pull")
SH.Encounter:Stop()

-- A cancelled unknown event must not become a recorded default or start an intermission.
SH.Store:Options().observedSchedules[17] = nil
SH.Encounter:Start("Sszorak", 17)
SH.Encounter.totalSurgeIndex, SH.Encounter.intermissionIndex = 5, 3
C_EncounterTimeline.GetEventState = function() return 3 end
SH.Encounter:OnTimelineAdded({source = 0, id = 301, duration = 36})
local cancelledSurge = SH.Encounter.timers.surge301
SH.Encounter:OnTimelineChanged(301)
SH.Encounter:OnTimelineAdded({source = 0, id = 302, duration = 125})
SH.Encounter:OnTimelineChanged(302)
check(cancelledSurge.cancelled and not eventByID(SH.Store:GetTimings(17), "surge6"), "cancelled event was recorded")
check(not SH.Encounter.timers["schedule:intermission4"], "cancelled intermission started")
SH.Encounter:Stop()

-- Build actual option widgets; drafts, invalid input, defaults, and every difficulty gear.
_G.SszorakHelper = SH
loadModule("UI/LayoutOffer.lua")
SH.LayoutOffer:OnInitialize()
loadModule("Options/Configuration.lua")
SH.OptionsUI:Ensure()
check(SH.OptionsUI.header:GetParent() == SH.OptionsUI.frame, "configuration header is inside scrolling content")
check(SH.OptionsUI.header.title:GetParent() == SH.OptionsUI.header, "configuration title is not fixed")
check(SH.OptionsUI.topCloseButton:GetParent() == SH.OptionsUI.header, "close button is inside scrolling content")
check(SH.OptionsUI.content:GetParent() == SH.OptionsUI.scroll, "options content stopped scrolling")
local headerPoint, closePoint = SH.OptionsUI.header.point, SH.OptionsUI.topCloseButton.point
SH.OptionsUI.scroll:SetVerticalScroll(150)
check(SH.OptionsUI.header.point == headerPoint and SH.OptionsUI.topCloseButton.point == closePoint, "scrolling moved the fixed header")

-- The Marker Layout page supports the full profile workflow through its toolbar.
local ui = SH.OptionsUI
ui:Show()
ui.markerLayoutButton.scripts.OnClick(ui.markerLayoutButton)
check(ui.layoutPage:IsShown() and not ui.scroll:IsShown() and ui.header.title:GetText() == "Marker Layout", "Marker Layout navigation did not switch pages")
check(ui.publishButton:GetParent() == ui.layoutPage and ui.resetLayoutButton:GetParent() == ui.layoutPage, "layout actions stayed on the sidebar")
check(ui.profileSelector.text:GetText() == "Default" and not ui.resetLayoutButton:IsEnabled(), "Default profile is not protected")
ui.layoutButtons[2].scripts.OnClick()
check(ui.selectedLayoutPosition == nil, "Default layout became editable")
ui.newProfileButton.scripts.OnClick(ui.newProfileButton)
ui.nameDialog.panel.edit:SetText("My full layout name")
ui:SubmitProfileName()
local toolbarProfileID = SH.Store:GetActiveProfileID()
check(ui.profileSelector.text:GetText() == "My full layout name", "toolbar truncated the profile name")
ui.renameProfileButton.scripts.OnClick(ui.renameProfileButton)
ui.nameDialog.panel.edit:SetText("Renamed raid layout")
ui:SubmitProfileName()
check(ui.profileSelector.text:GetText() == "Renamed raid layout", "renamed profile did not refresh the selector")
ui.layoutButtons[2].scripts.OnClick()
ui.layoutButtons[6].scripts.OnClick()
check(SH.Store:GetLayout()[2] == 2 and SH.NSRTMacros.markerIDs[1] == 2, "toolbar layout swap did not reach the macro panel")
check(ui.layoutButtons[2].label:GetText() == "Circle", "swapped marker label did not refresh")
ui.resetLayoutButton.scripts.OnClick(ui.resetLayoutButton)
check(SH.Store:GetLayout()[2] == 6 and SH.NSRTMacros.markerIDs[1] == 6, "layout reset did not restore the selected profile")
local toolbarProfiles = {toolbarProfileID}
while #SH.Store:GetProfiles() < SH.Store:GetProfileLimit() do
    toolbarProfiles[#toolbarProfiles + 1] = assert(SH.Store:CreateProfile("Layout " .. #SH.Store:GetProfiles()))
end
ui:RefreshLayoutEditor()
ui.profileSelector.scripts.OnClick(ui.profileSelector)
check(ui.profileMenuDismiss:IsShown() and ui.profileButtons[10]:IsShown() and not ui.newProfileButton:IsEnabled(), "profile selector lost the ten-profile limit")
ui.profileButtons[2].scripts.OnClick(ui.profileButtons[2])
check(not ui.profileMenuDismiss:IsShown() and SH.Store:GetActiveProfileID() == toolbarProfileID, "dropdown did not select and close")
check(SH.Store:SetTemporaryLayout({8, 1, 2, 3, 4, 5, 6, 7}, "RaidLeader"), "temporary test layout rejected")
SH.LayoutOffer:ApplyLayout()
check(ui.profileSelector.text:GetText() == "Temporary: RaidLeader" and ui.profileSelector._shStyle == "pink", "temporary layout is missing from the selector")
check(not ui.renameProfileButton:IsEnabled() and not ui.deleteProfileButton:IsEnabled(), "temporary layout enabled permanent profile management")
ui.profileSelector.scripts.OnClick(ui.profileSelector)
ui.profileButtons[1].scripts.OnClick(ui.profileButtons[1])
check(not SH.Store:HasTemporaryLayout() and ui.profileSelector.text:GetText() == "Default", "selecting Default did not leave temporary layout")
for _, profileID in ipairs(toolbarProfiles) do check(SH.Store:DeleteProfile(profileID), "toolbar test profile cleanup failed") end
ui:RefreshLayoutEditor()
ui.profileSelector.scripts.OnClick(ui.profileSelector)
ui.configurationButton.scripts.OnClick(ui.configurationButton)
check(ui.scroll:IsShown() and not ui.layoutPage:IsShown() and not ui.profileMenuDismiss:IsShown(), "returning to Configuration left the layout or menu open")
check(ui.header.title:GetText() == "Configuration", "Configuration title was not restored")

local doubleRowCheck, attachToMapCheck, macroEnableCheck
for _, entry in ipairs(SH.OptionsUI.optionChecks) do
    if entry.check:GetParent().label:GetText() == "Double Row" then doubleRowCheck = entry.check end
    if entry.check:GetParent().label:GetText() == "Attach to Map" then attachToMapCheck = entry.check end
    if entry.check:GetParent().label:GetText() == "NSRT Macro Buttons" then macroEnableCheck = entry.check end
end
check(doubleRowCheck and doubleRowCheck:GetParent():GetParent().title:GetText() == "NSRT MACRO BUTTONS", "double row toggle is missing from NSRT section")
check(ui.createMacrosButton:GetParent() == macroEnableCheck:GetParent(), "Create is outside the macro-enable cell")
macroEnableCheck:SetChecked(false)
macroEnableCheck.scripts.OnClick(macroEnableCheck)
check(not ui.createMacrosButton:IsShown(), "disabling NSRT macros left Create visible")
macroEnableCheck:SetChecked(true)
macroEnableCheck.scripts.OnClick(macroEnableCheck)
check(ui.createMacrosButton:IsShown(), "enabling NSRT macros did not show Create")
SH.Store:Options().showNSRTMacros = false
ui:Refresh()
check(not ui.createMacrosButton:IsShown(), "options refresh left Create visible while disabled")
SH.Store:Options().showNSRTMacros = true
ui:Refresh()
SH.OptionsUI.frame:Show()
SH.OptionsUI.topCloseButton.scripts.OnClick(SH.OptionsUI.topCloseButton)
check(not SH.OptionsUI.frame:IsShown(), "fixed close button did not close configuration")
SH.OptionsUI:ShowTimingDialog(17)
check(not SH.OptionsUI.timingDialog.panel.empty:IsShown(), "Raid Finder editor is empty")
check(SH.OptionsUI.timingDialog.panel.save:IsEnabled(), "Raid Finder schedule cannot be saved")
check(SH.OptionsUI.timingDialog.panel.edits.surge1:GetText() == "0:36.25", "Raid Finder editor did not display Normal default")
SH.OptionsUI:ShowTimingDialog(14)
local dialog = SH.OptionsUI.timingDialog
check(dialog.panel.edits.surge1:GetText() == "0:36.25", "editor did not show time from pull")
dialog.panel.edits.surge1:SetText("0:38.5")
check(eventByID(SH.Store:GetTimings(14), "surge1").time == 36.25, "unsaved draft changed settings")
SH.OptionsUI:SubmitTimings()
check(not dialog:IsShown() and eventByID(SH.Store:GetTimings(14), "surge1").time == 38.5, "modal save failed")
SH.OptionsUI:ShowTimingDialog(14)
dialog.panel.edits.surge1:SetText("invalid")
SH.OptionsUI:SubmitTimings()
check(dialog:IsShown() and dialog.panel.error:GetText() ~= "", "invalid time not reported")
SH.OptionsUI:FillTimingDialog(SH.Store:GetTimings(14, true))
check(eventByID(SH.Store:GetTimings(14), "surge1").time == 38.5, "reset saved before Save was clicked")
SH.OptionsUI:SubmitTimings()
check(eventByID(SH.Store:GetTimings(14), "surge1").time == 36.25, "modal reset failed")
for _, definition in ipairs(SH.Const.DIFFICULTIES) do
    local gear = SH.OptionsUI.difficultyGearButtons[definition.id]
    gear.scripts.OnClick(gear)
    check(dialog.difficultyID == definition.id, "gear opened wrong difficulty")
end
SH.OptionsUI.warningDelaySlider._shUpdating = false
SH.Store:Options().previewFrames = false
SH.PersonalWarning:RefreshVisibility()
SH.OptionsUI.warningDelaySlider.scripts.OnValueChanged(SH.OptionsUI.warningDelaySlider, 6.5, true)
check(SH.PersonalWarning.timer.delay == 6.5, "duration slider did not preview selected duration")

SH.Store:Options().orderFrameScale = 1
SH.OrderFrame:ApplyScale()
check(SH.OrderFrame.frame.scale == 0.75, "100 percent order scale did not map to old 75 percent")
SH.Store:Options().roomMapScale = 1
SH.NSRTMacros:ApplyScale()
check(SH.NSRTMacros.frame.scale == 0.75, "macro panel scale did not follow map baseline")

-- Macro room entry is event-driven, respects manual hides, and defers protected work.
local options = SH.Store:Options()
options.previewFrames, options.nsrtAutoShow, options.showNSRTMacros = false, true, true
SH.NSRTMacros:SetPanelOpen(false)
subzone = "Altar of the Six Winds"
SH.NSRTMacros:OnZoneChanged()
check(SH.NSRTMacros.secureFrame:IsShown(), "room entry did not auto-open macros")
SH.NSRTMacros:SetPanelOpen(false)
SH.NSRTMacros:OnZoneChanged()
check(not SH.NSRTMacros.secureFrame:IsShown(), "same room overrode manual hide")
subzone = "Hallway"
SH.NSRTMacros:OnZoneChanged()
combat = true
subzone = "Altar of the Six Winds"
SH.NSRTMacros:OnZoneChanged()
check(not SH.NSRTMacros.secureFrame:IsShown(), "auto-show changed protected frame in combat")
combat = false
for _, callback in ipairs(handlers.PLAYER_REGEN_ENABLED) do callback() end
check(SH.NSRTMacros.secureFrame:IsShown(), "pending room entry did not open after combat")
SH.NSRTMacros:SetPanelOpen(false)
subzone = "Hallway"
SH.NSRTMacros:OnZoneChanged()
combat = true
subzone = "Altar of the Six Winds"
SH.NSRTMacros:OnZoneChanged()
subzone = "Hallway"
SH.NSRTMacros:OnZoneChanged()
combat = false
for _, callback in ipairs(handlers.PLAYER_REGEN_ENABLED) do callback() end
check(not SH.NSRTMacros.secureFrame:IsShown(), "left room but pending auto-show survived")
instanceID, subzone = 1, "Altar of the Six Winds"
SH.NSRTMacros:OnZoneChanged()
check(not SH.NSRTMacros.secureFrame:IsShown(), "same subzone in wrong instance opened macros")
instanceID = 3004
options.showNSRTMacros = false
SH.NSRTMacros:OnZoneChanged()
check(not SH.NSRTMacros.secureFrame:IsShown(), "room entry bypassed disabled macros")
options.showNSRTMacros = true
for _, room in ipairs({"The Serpent Warren", "Pit of Fangs"}) do
    subzone = "Altar of the Six Winds"
    SH.NSRTMacros:SetPanelOpen(true)
    SH.NSRTMacros:OnZoneChanged()
    subzone = room
    for _, callback in ipairs(handlers.ZONE_CHANGED) do callback() end
    check(not SH.NSRTMacros.secureFrame:IsShown(), "adjacent room did not auto-hide macros: " .. room)
    SH.NSRTMacros:SetPanelOpen(true)
    SH.NSRTMacros:OnZoneChanged()
    check(SH.NSRTMacros.secureFrame:IsShown(), "repeated room event overrode manual open")
    subzone = "Altar of the Six Winds"
    SH.NSRTMacros:OnZoneChanged()
    combat = true
    subzone = room
    SH.NSRTMacros:OnZoneChanged()
    check(SH.NSRTMacros.secureFrame:IsShown(), "auto-hide mutated protected visibility in combat")
    combat = false
    for _, callback in ipairs(handlers.PLAYER_REGEN_ENABLED) do callback() end
    check(not SH.NSRTMacros.secureFrame:IsShown(), "auto-hide was not applied after combat")
    options.previewFrames = true
    SH.NSRTMacros:RefreshVisibility()
    check(SH.NSRTMacros.secureFrame:IsShown(), "auto-hide prevented explicit preview")
    options.previewFrames = false
end
subzone = "Altar of the Six Winds"
SH.NSRTMacros:OnZoneChanged()
combat = true
subzone = "Pit of Fangs"
SH.NSRTMacros:OnZoneChanged()
subzone = "Altar of the Six Winds"
SH.NSRTMacros:OnZoneChanged()
combat = false
for _, callback in ipairs(handlers.PLAYER_REGEN_ENABLED) do callback() end
check(SH.NSRTMacros.secureFrame:IsShown(), "return to altar did not cancel pending hide")
options.nsrtAutoShow = false
subzone = "The Serpent Warren"
SH.NSRTMacros:OnZoneChanged()
check(SH.NSRTMacros.secureFrame:IsShown(), "disabled room automation still hid panel")
options.showNSRTMacros, options.nsrtAutoShow = true, false

-- Detaching keeps the current location; a fresh detached panel restores its saved position.
options.nsrtAttachToMap, options.lockFrames = false, false
SH.Store.db.frames.nsrtMacros = {point = "CENTER", relativePoint = "CENTER", x = 123, y = 45}
SH.NSRTMacros:ApplyAttachment()
check(SH.NSRTMacros.frame.point[2] == UIParent and SH.NSRTMacros.frame.point[3] == "BOTTOMLEFT"
    and SH.NSRTMacros.frame.point[4] == 400 and SH.NSRTMacros.frame.point[5] == 300, "detaching moved the panel away from the map")
check(SH.Store:FrameState("nsrtMacros").x == 400, "detached current position was not saved")
SH.NSRTMacros.attached = nil
SH.Store.db.frames.nsrtMacros = {point = "CENTER", relativePoint = "CENTER", x = 123, y = 45}
SH.NSRTMacros:ApplyAttachment()
check(SH.NSRTMacros.frame.point[2] == UIParent and SH.NSRTMacros.frame.point[4] == 123, "detached saved anchor not used")
check(SH.NSRTMacros.frame._shUnlocked, "detached macros did not unlock")
local dragHandle = SH.NSRTMacros.frame.dragHandle
check(dragHandle.mouseEnabled and dragHandle.dragButtons[1] == "LeftButton", "macro header cannot receive dragging")
check(dragHandle:GetFrameLevel() > SH.NSRTMacros.secureFrame:GetFrameLevel(), "secure layer covers macro drag handle")
check(not SH.NSRTMacros.secureFrame.mouseEnabled, "secure container blocks header input")
dragHandle.scripts.OnDragStart()
check(SH.NSRTMacros.frame.moving, "detached macro header did not start moving")
SH.NSRTMacros.frame:SetPoint("CENTER", UIParent, "CENTER", 231, 54)
SH.NSRTMacros.frame.centerX, SH.NSRTMacros.frame.centerY = 500, 350
dragHandle.scripts.OnDragStop()
check(not SH.NSRTMacros.frame.moving, "macro drag did not stop")
check(SH.Store:FrameState("nsrtMacros").x == 231, "macro drag did not save")
check(SH.NSRTMacros.secureFrame.point[4] == 375 and SH.NSRTMacros.secureFrame.point[5] == 262.5, "dragged macro click layer was not repositioned")
options.lockFrames = true
SH.NSRTMacros:ApplyAttachment()
dragHandle.scripts.OnDragStart()
check(not SH.NSRTMacros.frame.moving, "locked macro panel moved")
options.lockFrames = false
SH.NSRTMacros:ApplyAttachment()
combat = true
dragHandle.scripts.OnDragStart()
check(not SH.NSRTMacros.frame.moving, "macro panel moved during combat")
combat = false
options.nsrtAttachToMap = true
combat = true
SH.NSRTMacros:ApplyAttachment()
check(SH.NSRTMacros.frame.point[2] == UIParent, "combat attachment changed visual layer")
combat = false
for _, callback in ipairs(handlers.PLAYER_REGEN_ENABLED) do callback() end
check(SH.NSRTMacros.frame.point[2] == SH.RoomMap.frame, "attachment was not applied after combat")
check(not SH.NSRTMacros.frame._shUnlocked, "attached macro panel independently movable")
dragHandle.scripts.OnDragStart()
check(not SH.NSRTMacros.frame.moving, "attached macro header moved independently")
options.nsrtAttachToMap = false
SH.NSRTMacros:ApplyAttachment()
check(SH.NSRTMacros.frame.point[4] == 500 and SH.NSRTMacros.frame.point[5] == 350, "detaching did not keep current position")
options.nsrtAttachToMap, options.lockFrames = true, true

-- Double row pairs opposite markers; secure targets and missing-macro blockers track each icon.
SH.Store:ResetDefaultLayout()
doubleRowCheck:SetChecked(true)
doubleRowCheck.scripts.OnClick(doubleRowCheck)
check(options.nsrtDoubleRow and SH.NSRTMacros.frame:GetWidth() == 180 and SH.NSRTMacros.frame:GetHeight() == 166, "double row toggle did not resize panel")
local topMarkers, bottomMarkers = {2, 7, 3}, {6, 4, 1}
for _, scale in ipairs({0.5, 1, 2}) do
    options.roomMapScale = scale
    SH.NSRTMacros:ApplyScale()
    local appliedScale = scale * SH.Const.FRAME_SCALE_BASE
    for column = 1, 3 do
        check(SH.NSRTMacros.markerIDs[column + 3] == topMarkers[column], "top-row marker order incorrect")
        check(SH.NSRTMacros.markerIDs[column] == bottomMarkers[column], "bottom-row marker order incorrect")
        local top, bottom = SH.NSRTMacros.frame.slots[column + 3], SH.NSRTMacros.frame.slots[column]
        check(top.point[2] == bottom.point[2] and top.point[3] > bottom.point[3], "opposite markers are not vertically paired")
    end
    for index, slot in ipairs(SH.NSRTMacros.frame.slots) do
        local target = SH.NSRTMacros.secureFrame.buttons[index]
        check(target.point[2] == slot.point[2] * appliedScale and target.point[3] == slot.point[3] * appliedScale, "double-row secure button missed its icon")
        check(slot.blocker.point[2] == slot.point[2] and slot.blocker.point[3] == slot.point[3], "double-row missing-macro blocker missed its icon")
        check(target:GetWidth() == slot:GetWidth() * appliedScale and target:GetHeight() == slot:GetHeight() * appliedScale, "scaled secure target size incorrect")
        check(target.attributes.macro == (index <= 6 and "NSRT_SSZORAK_" .. SH.NSRTMacros.markerIDs[index] or nil), "double row changed macro binding")
    end
end
local customMacroLayout = {8, 1, 2, 3, 4, 5, 6, 7}
SH.Store:SetTemporaryLayout(customMacroLayout, "Caller")
SH.NSRTMacros:RefreshLayout()
for column = 1, 3 do
    check(SH.NSRTMacros.markerIDs[column] == customMacroLayout[column + 1]
        and SH.NSRTMacros.markerIDs[column + 3] == customMacroLayout[column + 5], "double row ignored custom marker layout")
end
SH.Store:ClearTemporaryLayout()
SH.NSRTMacros:RefreshLayout()
combat = true
doubleRowCheck:SetChecked(false)
doubleRowCheck.scripts.OnClick(doubleRowCheck)
check(SH.NSRTMacros.frame:GetWidth() == 180 and SH.NSRTMacros.doubleRow, "combat toggle moved macro targets immediately")
combat = false
for _, callback in ipairs(handlers.PLAYER_REGEN_ENABLED) do callback() end
check(SH.NSRTMacros.frame:GetWidth() == 348 and SH.NSRTMacros.frame:GetHeight() == 100 and not SH.NSRTMacros.doubleRow, "queued single-row layout was not restored")
for index, slot in ipairs(SH.NSRTMacros.frame.slots) do
    check(slot.point[2] == 10 + (index - 1) * 56 and slot.point[3] == 8, "single-row icon order was not restored")
end
options.roomMapScale = 1
SH.NSRTMacros:ApplyScale()

-- Optional room markers occupy the final single-row slots or the last paired column.
local entranceExitToggle = ui.showEntranceExitToggle
check(not entranceExitToggle:GetChecked(), "Entrance / Exit starts enabled")
entranceExitToggle:SetChecked(true)
entranceExitToggle.scripts.OnClick(entranceExitToggle)
for _, doubleRow in ipairs({false, true}) do
    options.nsrtDoubleRow = doubleRow
    SH.NSRTMacros:ApplyScale()
    check(SH.NSRTMacros.frame:GetWidth() == (doubleRow and 236 or 460), "Entrance / Exit did not expand panel width")
    local exitSlot, entranceSlot = SH.NSRTMacros.frame.slots[7], SH.NSRTMacros.frame.slots[8]
    check(exitSlot.point[2] == (doubleRow and 178 or 346) and exitSlot.point[3] == (doubleRow and 74 or 8), "Exit is not in the final top/single-row slot")
    check(entranceSlot.point[2] == (doubleRow and 178 or 402) and entranceSlot.point[3] == 8, "Entrance is not in the final bottom/single-row slot")
    check(SH.NSRTMacros.markerIDs[7] == 5 and SH.NSRTMacros.markerIDs[8] == 8, "Entrance / Exit used the wrong room markers")
    for index = 7, 8 do
        local slot, target = SH.NSRTMacros.frame.slots[index], SH.NSRTMacros.secureFrame.buttons[index]
        check(slot:IsShown() and target:IsShown(), "enabled room marker is hidden")
        check(target.attributes.macro == "NSRT_SSZORAK_" .. SH.NSRTMacros.markerIDs[index], "room marker is not bound to its macro")
        check(target.point[2] == slot.point[2] * 0.75 and target.point[3] == slot.point[3] * 0.75, "room-marker secure target missed its icon")
    end
end
combat = true
entranceExitToggle:SetChecked(false)
entranceExitToggle.scripts.OnClick(entranceExitToggle)
check(SH.NSRTMacros.secureFrame.buttons[7]:IsShown() and SH.NSRTMacros.frame:GetWidth() == 236, "combat toggle hid or moved live targets")
combat = false
for _, callback in ipairs(handlers.PLAYER_REGEN_ENABLED) do callback() end
check(SH.NSRTMacros.frame:GetWidth() == 180, "deferred room-marker removal did not shrink panel")
for index = 7, 8 do
    local slot, target = SH.NSRTMacros.frame.slots[index], SH.NSRTMacros.secureFrame.buttons[index]
    check(not slot:IsShown() and not target:IsShown() and not slot.blocker:IsShown(), "disabled room-marker control remained visible")
    check(not SH.NSRTMacros.available[index] and target.attributes.type == nil and target.attributes.macro == nil, "hidden room marker remained executable")
end
combat = true
entranceExitToggle:SetChecked(true)
entranceExitToggle.scripts.OnClick(entranceExitToggle)
check(not SH.NSRTMacros.secureFrame.buttons[7]:IsShown(), "combat toggle immediately enabled a secure target")
combat = false
for _, callback in ipairs(handlers.PLAYER_REGEN_ENABLED) do callback() end
check(SH.NSRTMacros.secureFrame.buttons[7]:IsShown() and SH.NSRTMacros.secureFrame.buttons[7].attributes.macro == "NSRT_SSZORAK_5", "deferred room marker was not shown and bound")
macros.NSRT_SSZORAK_5 = "/raid unexpected"
SH.NSRTMacros:RefreshLayout()
check(SH.NSRTMacros.frame.slots[7].blocker:IsShown() and SH.NSRTMacros.secureFrame.buttons[7].attributes.type == nil, "room marker accepted a modified macro")
ui.createMacrosButton.scripts.OnClick(ui.createMacrosButton)
check(not SH.NSRTMacros.frame.slots[7].blocker:IsShown() and SH.NSRTMacros.secureFrame.buttons[7].attributes.type == "macro", "Create did not repair the Exit macro")
SH.Store:OnInitialize()
check(SH.Store:Options().nsrtShowEntranceExit, "saved Entrance / Exit setting was lost")
ui:Refresh()
check(entranceExitToggle:GetChecked(), "Entrance / Exit toggle lost its saved state")

-- Opposite mode preserves the icons but sends and tracks the opposite room marker.
local oppositeToggle, resetButton = SH.OptionsUI.oppositeMacrosToggle, SH.OptionsUI.createMacrosButton
check(resetButton.text:GetText() == "Create", "macro creation action was not renamed")
check(oppositeToggle.tooltip:find("Circle sends Square", 1, true), "opposite toggle lacks its explanatory tooltip")
check(not oppositeToggle:GetChecked(), "opposite toggle starts on")
oppositeToggle:SetChecked(true)
oppositeToggle.scripts.OnClick(oppositeToggle)
check(options.nsrtOppositeMacros and oppositeToggle:GetChecked() and SH.NSRTMacros.frame.oppositeNotice:IsShown(), "opposite mode was not enabled")
check(SH.NSRTMacros.frame.oppositeNotice:GetText() == "Opposite Macros. RESET to revert.", "opposite notice is wrong")
check(SH.NSRTMacros.markerIDs[4] == 2 and SH.NSRTMacros.secureFrame.buttons[4].attributes.macro == "NSRT_SSZORAK_6", "Circle did not send Square")
check(SH.NSRTMacros.sentMarkerIDs[7] == 8 and SH.NSRTMacros.sentMarkerIDs[8] == 5, "Opposite mode did not pair Exit and Entrance")
macros.NSRT_SSZORAK_6 = "/raid unexpected"
oppositeToggle:SetChecked(false)
oppositeToggle.scripts.OnClick(oppositeToggle)
check(not options.nsrtOppositeMacros and not oppositeToggle:GetChecked() and not SH.NSRTMacros.frame.oppositeNotice:IsShown(), "turning off the toggle did not reset opposite mode")
check(macros.NSRT_SSZORAK_6 == "/raid 6", "turning off the toggle did not repair the macros")
for index, target in ipairs(SH.NSRTMacros.secureFrame.buttons) do
    check(target.attributes.macro == "NSRT_SSZORAK_" .. SH.NSRTMacros.markerIDs[index], "turning off the toggle left opposite bindings")
end
oppositeToggle:SetChecked(true)
oppositeToggle.scripts.OnClick(oppositeToggle)
for _, doubleRow in ipairs({false, true}) do
    options.nsrtDoubleRow = doubleRow
    SH.NSRTMacros:ApplyScale()
    check(SH.NSRTMacros.frame:GetHeight() == (doubleRow and 200 or 134), "opposite notice overlaps macro icons")
    for index, target in ipairs(SH.NSRTMacros.secureFrame.buttons) do
        check(target.attributes.macro == "NSRT_SSZORAK_" .. SH.NSRTMacros.sentMarkerIDs[index], "opposite binding disagrees with sent marker")
    end
end
SH.NSRTMacros:SetOrder({6, 4, 1})
check(SH.NSRTMacros.frame.slots[4].badge.text:GetText() == "1", "opposite suggestion highlights the wrong icon")
SH.NSRTMacros:OnMacroClicked(4)
check(SH.NSRTMacros.nextStep == 2, "opposite click did not advance by the sent marker")
macros.NSRT_SSZORAK_6 = "/raid unexpected"
SH.NSRTMacros:RefreshLayout()
check(not SH.NSRTMacros.available[4] and SH.NSRTMacros.frame.slots[4].blocker:IsShown(), "opposite button accepted a modified target macro")
check(SH.NSRTMacros:CreateOrRepairMacros(true), "opposite macros were not repaired")
SH.Store:SetTemporaryLayout(customMacroLayout, "Caller")
SH.NSRTMacros:RefreshLayout()
for index, position in ipairs(SH.Const.WIND_POSITIONS) do
    check(SH.NSRTMacros.markerIDs[index] == customMacroLayout[position], "opposite mode changed custom icons")
    check(SH.NSRTMacros.sentMarkerIDs[index] == customMacroLayout[SH.Const:Opposite(position)], "opposite mode ignored custom room positions")
end
check(SH.NSRTMacros.markerIDs[7] == customMacroLayout[1] and SH.NSRTMacros.markerIDs[8] == customMacroLayout[5], "room-marker icons ignored custom layout")
check(SH.NSRTMacros.sentMarkerIDs[7] == customMacroLayout[5] and SH.NSRTMacros.sentMarkerIDs[8] == customMacroLayout[1], "opposite room markers ignored custom layout")
SH.Store:ClearTemporaryLayout()
SH.NSRTMacros:RefreshLayout()
SH.Store:OnInitialize()
check(SH.Store:Options().nsrtOppositeMacros, "saved opposite mode was lost on initialization")
oppositeToggle:SetChecked(false)
SH.OptionsUI:Refresh()
check(oppositeToggle:GetChecked(), "options refresh lost the saved opposite state")
combat = true
oppositeToggle:SetChecked(false)
oppositeToggle.scripts.OnClick(oppositeToggle)
check(options.nsrtOppositeMacros and oppositeToggle:GetChecked(), "combat rejection changed opposite mode or left the toggle off")
combat = false
local editMacro = EditMacro
EditMacro = function() return nil end
oppositeToggle:SetChecked(false)
oppositeToggle.scripts.OnClick(oppositeToggle)
check(options.nsrtOppositeMacros and oppositeToggle:GetChecked(), "failed macro repair changed opposite mode or left the toggle off")
EditMacro = editMacro
SH.Encounter.testMode, inRaid = true, false
SH.NSRTMacros:RefreshLayout()
SH.Comms.receivedCount, SH.Comms.receivedMarkers = 0, {}
SH.NSRTMacros:OnMacroClicked(4)
check(SH.Comms.receivedMarkers[1] == "6", "solo opposite click displayed the visible icon instead of Square")
SH.NSRTMacros:OnMacroClicked(7)
SH.NSRTMacros:OnMacroClicked(8)
check(SH.Comms.receivedMarkers[2] == "8" and SH.Comms.receivedMarkers[3] == "5", "solo opposite room markers sent the wrong sequence")
SH.Encounter.testMode, inRaid = false, true
resetButton.scripts.OnClick(resetButton)
check(not options.nsrtOppositeMacros and not oppositeToggle:GetChecked() and not SH.NSRTMacros.frame.oppositeNotice:IsShown(), "reset did not disable opposite mode and its toggle")
for index, target in ipairs(SH.NSRTMacros.secureFrame.buttons) do
    check(target.attributes.macro == "NSRT_SSZORAK_" .. SH.NSRTMacros.markerIDs[index], "reset left opposite bindings")
end
options.nsrtDoubleRow = false
entranceExitToggle:SetChecked(false)
entranceExitToggle.scripts.OnClick(entranceExitToggle)
SH.NSRTMacros:ApplyScale()
SH.NSRTMacros:SetOrder(nil)
SH.Comms.receivedCount, SH.Comms.receivedMarkers = 0, {}

-- Reproduce the configuration sequence: Preview, Double Row, then detach and drag.
options.previewFrames, options.showNSRTMacros, options.lockFrames = true, true, false
SH.NSRTMacros.panelHidden = false
SH.OptionsUI:Show()
SH.Encounter:RefreshDisplays()
doubleRowCheck:SetChecked(true)
doubleRowCheck.scripts.OnClick(doubleRowCheck)
local beforeDetachX, beforeDetachY = SH.NSRTMacros.frame:GetCenter()
attachToMapCheck:SetChecked(false)
attachToMapCheck.scripts.OnClick(attachToMapCheck)
check(SH.NSRTMacros.frame:IsShown() and SH.NSRTMacros.secureFrame:IsShown(), "detached double-row preview disappeared")
check(SH.NSRTMacros.frame.point[4] == beforeDetachX and SH.NSRTMacros.frame.point[5] == beforeDetachY, "detached preview jumped to an old saved position")
local strataOrder = {HIGH = 1, FULLSCREEN_DIALOG = 2, TOOLTIP = 3}
check(strataOrder[SH.NSRTMacros.frame:GetFrameStrata()] > strataOrder[SH.OptionsUI.frame:GetFrameStrata()], "Configuration covers detached preview")
check(SH.NSRTMacros.frame:GetFrameStrata() == SH.NSRTMacros.secureFrame:GetFrameStrata(), "preview clicks and icons use different layers")
dragHandle.scripts.OnDragStart()
check(SH.NSRTMacros.frame.moving, "detached preview could not be dragged with Configuration open")
dragHandle.scripts.OnDragStop()
check(SH.NSRTMacros.frame:GetHeight() == 166 and rawget(SH.NSRTMacros.frame, "status") == nil, "preview still reserves space for status text")
combat = true
options.previewFrames = false
SH.Encounter:RefreshDisplays()
check(SH.NSRTMacros.secureFrame:GetFrameStrata() == "TOOLTIP", "preview layer changed during combat")
combat = false
for _, callback in ipairs(handlers.PLAYER_REGEN_ENABLED) do callback() end
check(SH.NSRTMacros.frame:GetFrameStrata() == "HIGH" and SH.NSRTMacros.secureFrame:GetFrameStrata() == "HIGH", "preview layer did not reset after combat")
options.nsrtDoubleRow, options.nsrtAttachToMap, options.lockFrames = false, true, true
SH.NSRTMacros:ApplyAttachment()
SH.NSRTMacros:ApplyScale()

-- Surge previews, timed capture, opaque values, assignment pairs, and cleanup.
local targets = SH.SurgeTargets
options.showSurgeTargets, options.previewFrames, options.lockFrames = true, true, false
SH.Encounter:RefreshDisplays()
check(targets.frame:IsShown() and targets.frame._shUnlocked, "Surge preview not visible/movable")
check(not targets.events.registeredEvent and not targets.frame.scripts.OnUpdate, "static preview started live work")
SH.Widgets:MakeMovable(targets.frame, "surgeTargets")
targets.frame:SetPoint("CENTER", UIParent, "CENTER", 310, 170)
targets.frame.scripts.OnDragStop()
check(SH.Store:FrameState("surgeTargets").x == 310, "Surge position did not save")
options.showSurgeTargets = false
targets:RefreshVisibility()
check(not targets.frame:IsShown(), "Surge preview bypassed disabled setting")
options.showSurgeTargets, options.previewFrames = true, false
SH.Encounter:EnterTestMode()
SH.Encounter:WarnSurge(2, true)
check(targets.frame.rows[2].marker.formatted[2] == SH.Store:GetLayout()[SH.Const.EXIT_POSITION], "Surge 2 preview lost Exit")
check(targets.frame.scripts.OnUpdate and not targets.events.registeredEvent, "test countdown did not stay isolated")
SH.Encounter:QuitTestMode()
check(not targets.frame:IsShown() and not targets.frame.scripts.OnUpdate, "test quit leaked countdown")
SH.Encounter:Start("Sszorak", 15)
local captureTimer = SH.Encounter.timers["targets:surge1"]
check(captureTimer.delay == 32.22, "capture must start at cast, not warning")
local unknownMarker, hasMarker = targets:GetMarker(1)
check(not hasMarker and unknownMarker == nil, "missing assignments fabricated a drop")
check(targets:GetMarker(4) == SH.Store:GetLayout()[SH.Const.EXIT_POSITION], "unassigned fourth drop lost Exit")
SH.Encounter.assignments = {[1] = 2, [2] = 3, [3] = 4}
SH.Comms.receivedCount, SH.Comms.receivedMarkers = 1, {secret()}
check(targets:GetMarker(1) == SH.Encounter:ComputeDropOrder()[1], "local assignments did not take precedence")
SH.Encounter.assignments = {}
SH.Comms.receivedCount, SH.Comms.receivedMarkers = 0, {}
captureTimer.callback()
check(targets.events.registeredEvent == "UNIT_TARGET" and targets.events.registeredUnit == "boss1", "capture not scoped to boss1")
local exists, targetName = false, secret()
UnitExists = function() return exists end
UnitName = function() return targetName end
targets.events.scripts.OnEvent(nil, "UNIT_TARGET", "boss1")
check(targets.captures == 0, "cleared boss target created a bar")
exists = secret()
targets:CaptureTarget()
check(targets.captures == 0, "restricted existence value was used as a boolean")
exists = true
SH.Comms.receivedCount, SH.Comms.receivedMarkers = 3, {secret(), secret(), secret()}
targets.events.scripts.OnEvent(nil, "UNIT_TARGET", "boss2")
check(targets.captures == 0, "other boss captured")
combat = true
targets:CaptureTarget()
check(targets.frame.rows[1].name.textValue == targetName, "restricted target name lost")
check(targets.frame.rows[1].marker.formatted[2] == SH.Comms.receivedMarkers[1], "restricted drop marker lost")
local windowTimer = targets.windowTimer
targets:CaptureTarget()
check(targets.captures == 2 and not targets.events.registeredEvent and windowTimer.cancelled, "capture did not stop after two targets")
targets:CaptureTarget()
check(targets.captures == 2, "extra target captured after window closed")
now = now + 11
targets.frame.scripts.OnUpdate(targets.frame, 0.1)
check(not targets.frame:IsShown() and not targets.frame.scripts.OnUpdate, "expired bars kept updating")
targets:BeginCast(2)
targets:CaptureTarget()
targets:CaptureTarget()
check(targets.frame.rows[1].marker.formatted[2] == SH.Comms.receivedMarkers[3], "second cast used wrong marker pair")
check(targets.frame.rows[2].marker.formatted[2] == SH.Store:GetLayout()[SH.Const.EXIT_POSITION], "second cast lost Exit")
targets:BeginCast(1)
windowTimer = targets.windowTimer
windowTimer.callback()
check(not targets.events.registeredEvent, "empty capture window did not time out")
targets:BeginCast(1)
options.showSurgeTargets = false
targets:RefreshVisibility()
check(not targets.events.registeredEvent and not targets.frame:IsShown(), "disabled Surge Targets kept running")
options.showSurgeTargets = true
targets:BeginCast(1)
targets:CaptureTarget()
windowTimer = targets.windowTimer
SH.Encounter:Stop()
check(windowTimer.cancelled and not targets.events.registeredEvent and not targets.frame.scripts.OnUpdate, "encounter stop leaked capture or display work")
check(captureTimer.cancelled, "stop did not cancel scheduled capture")
combat = false

loadModule("UI/RoomMap.lua")
SH.RoomMap:OnInitialize()
SH.RoomMap:ApplyScale()
check(SH.RoomMap.frame.scale == 0.75, "100 percent map scale did not map to old 75 percent")

-- The real room-map visibility follows committed auto-room transitions, including regen.
options.nsrtAutoShow, options.showNSRTMacros, options.showRoomMap = true, true, true
options.previewFrames, options.lockFrames = false, false
instanceID, subzone = 3004, "The Serpent Warren"
SH.NSRTMacros:OnZoneChanged()
check(not SH.RoomMap.frame:IsShown(), "room map shown before entering altar")
subzone = "Altar of the Six Winds"
SH.NSRTMacros:OnZoneChanged()
check(SH.RoomMap.frame:IsShown() and SH.NSRTMacros.secureFrame:IsShown(), "altar did not show both frames")
check(SH.RoomMap.frame._shUnlocked, "auto-shown room map could not be moved")
options.showRoomMap = false
SH.RoomMap:RefreshVisibility()
check(not SH.RoomMap.frame:IsShown(), "auto-room ignored map enable toggle")
options.showRoomMap, options.lockFrames = true, true
SH.RoomMap:RefreshVisibility()
check(SH.RoomMap.frame:IsShown() and not SH.RoomMap.frame._shUnlocked, "auto-shown map ignored frame lock")
SH.Encounter.active = true
SH.RoomMap:RefreshVisibility()
SH.Encounter.active = false
SH.RoomMap:RefreshVisibility()
check(SH.RoomMap.frame:IsShown(), "ending encounter in altar hid auto-shown map")
for _, room in ipairs({"The Serpent Warren", "Pit of Fangs"}) do
    combat = true
    subzone = room
    SH.NSRTMacros:OnZoneChanged()
    check(SH.RoomMap.frame:IsShown() and SH.NSRTMacros.secureFrame:IsShown(), "room map hid before macros during combat")
    combat = false
    for _, callback in ipairs(handlers.PLAYER_REGEN_ENABLED) do callback() end
    check(not SH.RoomMap.frame:IsShown() and not SH.NSRTMacros.secureFrame:IsShown(), "room exit did not hide both frames")
    combat = true
    subzone = "Altar of the Six Winds"
    SH.NSRTMacros:OnZoneChanged()
    check(not SH.RoomMap.frame:IsShown(), "room map showed before macros during combat")
    combat = false
    for _, callback in ipairs(handlers.PLAYER_REGEN_ENABLED) do callback() end
    check(SH.RoomMap.frame:IsShown(), "deferred altar entry did not show map")
end
options.nsrtAutoShow = false
SH.RoomMap:RefreshVisibility()
check(not SH.RoomMap.frame:IsShown(), "disabling automation left room map visible")
options.previewFrames = true
SH.RoomMap:RefreshVisibility()
check(SH.RoomMap.frame:IsShown(), "map preview stopped working without automation")
options.previewFrames = false
SH.Encounter.testMode = true
SH.RoomMap:RefreshVisibility()
check(SH.RoomMap.frame:IsShown(), "map test mode stopped working without automation")
SH.Encounter.testMode = false
options.nsrtAutoShow = true
instanceID = 1
SH.NSRTMacros:OnZoneChanged()
check(not SH.RoomMap.frame:IsShown(), "leaving instance retained auto-shown map")

-- Map room automation does not depend on enabling macro buttons.
instanceID, subzone = 3004, "The Serpent Warren"
options.showNSRTMacros, options.showRoomMap, options.nsrtAutoShow = false, true, true
SH.NSRTMacros:OnZoneChanged()
subzone = "Altar of the Six Winds"
SH.NSRTMacros:OnZoneChanged()
check(SH.RoomMap.frame:IsShown() and not SH.NSRTMacros.secureFrame:IsShown(), "disabled NSRT buttons suppressed room map")
options.showNSRTMacros = true
SH.NSRTMacros:OnZoneChanged()
check(SH.NSRTMacros.secureFrame:IsShown(), "re-enabling macros in altar did not restore panel")
options.showNSRTMacros = false
SH.NSRTMacros:OnZoneChanged()
check(SH.RoomMap.frame:IsShown() and not SH.NSRTMacros.secureFrame:IsShown(), "disabling visible macros hid room map")
subzone = "Pit of Fangs"
SH.NSRTMacros:OnZoneChanged()
check(not SH.RoomMap.frame:IsShown(), "disabled macros prevented room map auto-hide")
subzone = "Altar of the Six Winds"
combat = true
SH.NSRTMacros:OnZoneChanged()
combat = false
for _, callback in ipairs(handlers.PLAYER_REGEN_ENABLED) do callback() end
check(SH.RoomMap.frame:IsShown() and not SH.NSRTMacros.secureFrame:IsShown(), "deferred map show required enabled macros")
instanceID = 1
SH.NSRTMacros:OnZoneChanged()
check(not SH.RoomMap.frame:IsShown(), "disabled macros prevented map cleanup on instance exit")

-- The detached double-row panel remains usable with the room map turned off.
instanceID, subzone = 3004, "Altar of the Six Winds"
options.showRoomMap, options.showNSRTMacros, options.nsrtDoubleRow = false, true, true
options.nsrtAttachToMap, options.lockFrames = false, false
SH.NSRTMacros:ApplyScale()
SH.NSRTMacros:OnZoneChanged()
check(not SH.RoomMap.frame:IsShown() and SH.NSRTMacros.secureFrame:IsShown(), "macro-only double-row panel required visible map")
dragHandle.scripts.OnDragStart()
check(SH.NSRTMacros.frame.moving, "detached double-row panel could not move without map")
dragHandle.scripts.OnDragStop()

-- Intermissions keep the room map static and retain wind prompts.
SH.Encounter:StartIntermission(true)
check(not SH.RoomMap.frame.scripts.OnUpdate and not SH.RoomMap.StartRotation, "intermission retained map rotation")
check(SH.Encounter.timers.push2.delay == 8 and SH.Encounter.timers.push3.delay == 18, "rotation removal changed wind prompt timings")
for _, group in ipairs(SH.RoomMap.frame.groups) do check(group:IsShown(), "intermission hid static room markers") end
SH.Encounter:CancelTimers()

-- Compile every shipped Lua file, including load-on-demand configuration.
for _, toc in ipairs({"SszorakHelper.toc", "Options/SszorakHelper_Options.toc"}) do
    for line in io.lines(toc) do
        if line:match("%.lua%s*$") then
            local path = line:gsub("%s+$", "")
            if toc:match("^Options/") then path = "Options/" .. path end
            assert(loadfile(path))
        end
    end
end
print("Offline regression checks passed (Lua " .. _VERSION .. ").")
