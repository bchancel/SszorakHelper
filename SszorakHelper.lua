local addonName, SH = ...

SH.name = addonName
SH.version = "12.1.1"
SH.modules = {}
SH.handlers = {}
SH.frame = CreateFrame("Frame")

_G.SszorakHelper = SH

function SH:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff35caffSszorak Helper|r " .. tostring(message or ""))
end

function SH:RegisterEvent(eventName, handler)
    if type(handler) ~= "function" then return end
    local handlers = self.handlers[eventName]
    if not handlers then
        handlers = {}
        self.handlers[eventName] = handlers
        self.frame:RegisterEvent(eventName)
    end
    handlers[#handlers + 1] = handler
end

function SH:CallModules(methodName, ...)
    local ordered = {}
    for _, module in pairs(self.modules) do ordered[#ordered + 1] = module end
    table.sort(ordered, function(a, b) return (a.initializeOrder or 100) < (b.initializeOrder or 100) end)
    for _, module in ipairs(ordered) do
        local method = module and module[methodName]
        if type(method) == "function" then
            method(module, ...)
        end
    end
end

SH.frame:SetScript("OnEvent", function(_, eventName, ...)
    local handlers = SH.handlers[eventName]
    if not handlers then return end
    local args = {...}
    for _, handler in ipairs(handlers) do
        local ok, err = xpcall(function()
            handler(eventName, unpack(args))
        end, geterrorhandler())
        if not ok and err then
            SH:Print("Error in " .. eventName .. ": " .. tostring(err))
        end
    end
end)

SH:RegisterEvent("ADDON_LOADED", function(_, loadedName)
    if loadedName ~= addonName then return end
    SH:CallModules("OnInitialize")
end)

local function showHelp()
    SH:Print("Commands:")
    SH:Print("/sszorak config (or /sh config) - open configuration")
    SH:Print("/sszorak test (or /sh test) - toggle test mode")
    SH:Print("/sh macros - show/hide the NSRT macro panel before combat")
    SH:Print("/sszorak help (or /sh help) - show this help")
end

SLASH_SSZORAKHELPER1 = "/sszorak"
SLASH_SSZORAKHELPER2 = "/sh"
SlashCmdList.SSZORAKHELPER = function(input)
    local command = strtrim(input or ""):lower()
    if command == "config" or command == "options" or command == "" then
        if SH.OptionsLoader then SH.OptionsLoader:Open() end
    elseif command == "macros" then
        SH.NSRTMacros:TogglePanel()
    elseif command == "test" then
        if SH.Encounter and SH.Encounter.testMode and SH.OptionsUI then
            SH.OptionsUI:QuitTestMode()
        elseif SH.OptionsLoader then
            SH.OptionsLoader:Open(function()
                if SH.OptionsUI then SH.OptionsUI:EnterTestMode() end
            end, true)
        end
    else
        showHelp()
    end
end
