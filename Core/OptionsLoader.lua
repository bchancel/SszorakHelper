local _, SH = ...

SH.OptionsLoader = {initializeOrder = 70, pending = {}}
SH.modules.OptionsLoader = SH.OptionsLoader

function SH.OptionsLoader:IsLoaded()
    return SH.OptionsUI ~= nil
end

function SH.OptionsLoader:EnsureLoaded()
    if self:IsLoaded() then return true end
    if InCombatLockdown() then return false, "combat" end
    local ok, loaded, reason = pcall(C_AddOns.LoadAddOn, "SszorakHelper_Options")
    if not ok then return false, tostring(loaded) end
    if loaded ~= true and not self:IsLoaded() then return false, tostring(reason or "disabled or missing") end
    return self:IsLoaded(), self:IsLoaded() and nil or "options did not initialize"
end

function SH.OptionsLoader:Open(callback, testOnly)
    if InCombatLockdown() then
        self.pending[#self.pending + 1] = {callback = callback, testOnly = testOnly}
        self.waitFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        SH:Print(testOnly and "Test controls will open after combat ends." or "Configuration will open after combat ends.")
        return
    end
    local ok, reason = self:EnsureLoaded()
    if not ok then SH:Print("Configuration could not load: " .. tostring(reason)); return end
    if not testOnly then SH.OptionsUI:Show() end
    if callback then callback() end
end

function SH.OptionsLoader:OnInitialize()
    self.waitFrame = CreateFrame("Frame")
    self.waitFrame:SetScript("OnEvent", function(frame)
        frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
        local pending = SH.OptionsLoader.pending
        SH.OptionsLoader.pending = {}
        for _, request in ipairs(pending) do SH.OptionsLoader:Open(request.callback, request.testOnly) end
    end)
end
