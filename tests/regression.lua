-- Offline regression checks. Run from the repository root with Lua 5.1.
local combat, lockdown, inRaid = false, false, true
local sends, result, now = 0, 0, 10
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
GetInstanceInfo = function() return nil, nil, nil, nil, nil, nil, nil, 3004 end
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
    NewTimer = function(_, callback) return {callback = callback, Cancel = function(t) t.cancelled = true end} end,
    After = noop,
}
GameTooltip = setmetatable({}, {__index = function() return noop end})
local frameMethods = {}
local function protected(frame)
    if combat and frame.secure then error("secure frame mutated during combat") end
end
local function frame(parent, secure)
    return setmetatable({shown = true, scripts = {}, attributes = {}, secure = secure or (parent and parent.secure) or false}, {__index = frameMethods})
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
function frameMethods:SetFormattedText(format, ...) self.formatted = {format, ...} end
function frameMethods:SetFont(path, size) self.fontSize = size end
function frameMethods:GetCenter() return 400, 300 end
function frameMethods:GetEffectiveScale() return 1 end
function frameMethods:SetScale(value) protected(self); self.scale = value end
function frameMethods:SetPoint(...) protected(self) end
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
loadModule("Core/Comms.lua")
loadModule("Core/Encounter.lua")
SH.NSRTMacros:OnInitialize()
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
