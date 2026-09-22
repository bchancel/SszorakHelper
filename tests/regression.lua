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
    return setmetatable({shown = true, scripts = {}, attributes = {}, registeredEvent = false, secure = secure or (parent and parent.secure) or false}, {__index = frameMethods})
end
function frameMethods:SetAttribute(key, value) protected(self); self.attributes[key] = value end
function frameMethods:GetAttribute(key) return self.attributes[key] end
function frameMethods:RegisterForClicks(...) self.clicks = {...} end
function frameMethods:SetScript(key, value) self.scripts[key] = value end
function frameMethods:CreateFontString() return frame(self) end
function frameMethods:CreateTexture() return frame(self) end
function frameMethods:Show() protected(self); self.shown = true end
function frameMethods:Hide() protected(self); self.shown = false end
function frameMethods:SetShown(value) protected(self); self.shown = value and true or false end
function frameMethods:IsShown() return self.shown end
function frameMethods:SetText(value) self.textValue = value end
function frameMethods:GetText() return self.textValue end
function frameMethods:GetFrameLevel() return 1 end
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
function frameMethods:GetCenter() return 400, 300 end
function frameMethods:GetEffectiveScale() return 1 end
function frameMethods:SetScale(value) protected(self); self.scale = value end
function frameMethods:SetPoint(...) protected(self); self.point = {...} end
function frameMethods:GetPoint() return unpack(self.point or {"CENTER", UIParent, "CENTER", 0, 0}) end
function frameMethods:RegisterUnitEvent(event, unit) self.registeredEvent = event; self.registeredUnit = unit end
function frameMethods:UnregisterEvent(event) if self.registeredEvent == event then self.registeredEvent = false end end
function frameMethods:ClearAllPoints() protected(self) end
function frameMethods:SetSize(...) protected(self) end
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
SH.Store:OnInitialize()
check(SH.Store:Options().frameBackgroundOpacity == 0.25, "saved opacity was overwritten")
local colors = setmetatable({}, {__index = function() return {1, 1, 1, 1} end})
SH.Widgets = {
    colors = colors,
    ApplyBackdrop = noop,
    MakeMovable = noop,
    Label = function(parent) return frame(parent) end,
    Text = function(parent) return frame(parent) end,
    Button = function(parent, _, _, _, callback)
        local b = frame(parent); b.callback = callback; return b
    end,
}
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
check(#SH.NSRTMacros.secureFrame.buttons == 6, "macro panel must contain only six side buttons")
for _, markerID in ipairs(SH.NSRTMacros.markerIDs) do
    check(markerID ~= SH.Store:GetLayout()[SH.Const.EXIT_POSITION], "exit macro appeared on panel")
    check(markerID ~= SH.Store:GetLayout()[SH.Const.ENTRANCE_POSITION], "entrance macro appeared on panel")
end
for i, button in ipairs(SH.NSRTMacros.secureFrame.buttons) do
    check(button.attributes.useOnKeyDown == false, "click depends on user CVar")
    check(button.attributes.type == "macro", "live macro not bound")
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
check(SH.NSRTMacros.frame.status.textValue == "Clicked 1-3 (delivery unconfirmed)", "panel still requested an exit click")
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
check(scheduled["schedule:intermission1"].delay == 111.17, "intermission time incorrect")
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
check(SH.Encounter.timers["schedule:intermission1"].delay == 125, "Raid Finder did not schedule Normal's intermission")
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
loadModule("UI/Widgets.lua")
_G.SszorakHelper = SH
loadModule("Options/Configuration.lua")
SH.OptionsUI:Ensure()
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

-- Detached positions persist; reattaching and combat changes keep both layers aligned.
options.nsrtAttachToMap, options.lockFrames = false, false
SH.Store.db.frames.nsrtMacros = {point = "CENTER", relativePoint = "CENTER", x = 123, y = 45}
SH.NSRTMacros:ApplyAttachment()
check(SH.NSRTMacros.frame.point[2] == UIParent and SH.NSRTMacros.frame.point[4] == 123, "detached saved anchor not used")
check(SH.NSRTMacros.frame._shUnlocked, "detached macros did not unlock")
SH.Widgets:MakeMovable(SH.NSRTMacros.frame, "nsrtMacros")
SH.NSRTMacros.frame:SetPoint("CENTER", UIParent, "CENTER", 231, 54)
SH.NSRTMacros.frame.scripts.OnDragStop()
check(SH.Store:FrameState("nsrtMacros").x == 231, "macro drag did not save")
options.nsrtAttachToMap = true
combat = true
SH.NSRTMacros:ApplyAttachment()
check(SH.NSRTMacros.frame.point[2] == UIParent, "combat attachment changed visual layer")
combat = false
for _, callback in ipairs(handlers.PLAYER_REGEN_ENABLED) do callback() end
check(SH.NSRTMacros.frame.point[2] == SH.RoomMap.frame, "attachment was not applied after combat")
check(not SH.NSRTMacros.frame._shUnlocked, "attached macro panel independently movable")
options.nsrtAttachToMap = false
SH.NSRTMacros:ApplyAttachment()
check(SH.NSRTMacros.frame.point[4] == 231, "reattach lost detached position")
options.nsrtAttachToMap, options.lockFrames = true, true

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
SH.RoomMap.frame = frame()
SH.RoomMap:ApplyScale()
check(SH.RoomMap.frame.scale == 0.75, "100 percent map scale did not map to old 75 percent")

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
