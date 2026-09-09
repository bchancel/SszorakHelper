local _, SH = ...

SH.Store = {initializeOrder = 10}
SH.modules.Store = SH.Store

local PROFILE_LIMIT = 10
local PROFILE_NAME_LIMIT = 20

local defaults = {
    version = 2,
    options = {
        showRoomMap = true,
        showOrderFrame = true,
        showNSRTMacros = true,
        nsrtPanelOpen = false,
        receiveNSRT = true,
        previewFrames = false,
        lockFrames = true,
        roomMapScale = 1,
        orderFrameScale = 1,
        frameBackgroundOpacity = 1,
        minimapAngle = 220,
        rotateMap = true,
        raidWarningSurges = true,
        raidWarningPushes = false,
        personalWarningFontSize = 32,
        ttsWarnings = false,
        showClearButton = false,
        difficulties = {[17] = true, [14] = true, [15] = true, [16] = true},
    },
    layout = {5, 6, 4, 1, 8, 2, 7, 3},
    layoutProfiles = {
        {id = "default", name = "Default", layout = {5, 6, 4, 1, 8, 2, 7, 3}},
    },
    activeLayoutProfile = "default",
    nextLayoutProfileID = 1,
    temporaryLayout = nil,
    frames = {
        roomMap = {point = "CENTER", relativePoint = "CENTER", x = -360, y = 20},
        order = {point = "CENTER", relativePoint = "CENTER", x = 0, y = 260},
        personalWarning = {point = "CENTER", relativePoint = "CENTER", x = 0, y = 180},
        options = {point = "CENTER", relativePoint = "CENTER", x = 0, y = 0},
        test = {point = "CENTER", relativePoint = "CENTER", x = 360, y = 20},
    },
}

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

local function merge(target, source)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then target[key] = {} end
            merge(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local function validLayout(layout)
    if type(layout) ~= "table" then return false end
    local seen = {}
    for position = 1, 8 do
        local markerID = tonumber(layout[position])
        if not markerID or markerID < 1 or markerID > 8 or seen[markerID] then return false end
        seen[markerID] = true
    end
    return true
end

local function layoutsEqual(first, second)
    if not validLayout(first) or not validLayout(second) then return false end
    for position = 1, 8 do
        if tonumber(first[position]) ~= tonumber(second[position]) then return false end
    end
    return true
end

local function cleanProfileName(name)
    name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if #name > PROFILE_NAME_LIMIT then name = name:sub(1, PROFILE_NAME_LIMIT) end
    return name
end

local function normalizedProfileName(name)
    return cleanProfileName(name):lower()
end

local function findProfile(profiles, profileID)
    for index, profile in ipairs(profiles or {}) do
        if profile.id == profileID then return profile, index end
    end
end

local function normalizeProfiles(db, legacyLayout, hadProfiles)
    local source = hadProfiles and db.layoutProfiles or {}
    local normalized = {}
    local usedIDs, usedNames = {}, {default = true}
    normalized[1] = {
        id = "default",
        name = "Default",
        layout = copy(SH.Const.DEFAULT_LAYOUT),
    }
    usedIDs.default = true

    for _, profile in ipairs(source) do
        if #normalized >= PROFILE_LIMIT then break end
        local id = tostring(profile.id or "")
        local name = cleanProfileName(profile.name)
        local normalizedName = normalizedProfileName(name)
        if id ~= "" and id ~= "default" and not usedIDs[id] and name ~= "" and not usedNames[normalizedName] and validLayout(profile.layout) then
            normalized[#normalized + 1] = {id = id, name = name, layout = copy(profile.layout)}
            usedIDs[id] = true
            usedNames[normalizedName] = true
        end
    end

    if not hadProfiles and not layoutsEqual(legacyLayout, SH.Const.DEFAULT_LAYOUT) and #normalized < PROFILE_LIMIT then
        normalized[#normalized + 1] = {id = "profile-1", name = "Migrated Layout", layout = copy(legacyLayout)}
        db.activeLayoutProfile = "profile-1"
        db.nextLayoutProfileID = math.max(2, tonumber(db.nextLayoutProfileID) or 1)
    end

    db.layoutProfiles = normalized
    if not findProfile(normalized, db.activeLayoutProfile) then db.activeLayoutProfile = "default" end
    db.nextLayoutProfileID = math.max(1, tonumber(db.nextLayoutProfileID) or 1)
    db.layout = copy(normalized[1].layout)
    db.version = 2
end

function SH.Store:OnInitialize()
    if type(SszorakHelperDB) ~= "table" then SszorakHelperDB = {} end
    local hadProfiles = type(SszorakHelperDB.layoutProfiles) == "table"
    local legacyLayout = validLayout(SszorakHelperDB.layout) and copy(SszorakHelperDB.layout) or copy(SH.Const.DEFAULT_LAYOUT)
    merge(SszorakHelperDB, copy(defaults))
    normalizeProfiles(SszorakHelperDB, legacyLayout, hadProfiles)
    if SszorakHelperDB.temporaryLayout and not validLayout(SszorakHelperDB.temporaryLayout.layout) then
        SszorakHelperDB.temporaryLayout = nil
    end
    self.db = SszorakHelperDB
end

function SH.Store:Options()
    return self.db.options
end

function SH.Store:GetLayout()
    local temporary = self.db.temporaryLayout
    return temporary and temporary.layout or self:GetActiveProfile().layout
end

function SH.Store:GetDefaultLayout()
    return findProfile(self.db.layoutProfiles, "default").layout
end

function SH.Store:GetProfiles()
    return self.db.layoutProfiles
end

function SH.Store:GetProfileLimit()
    return PROFILE_LIMIT
end

function SH.Store:GetActiveProfileID()
    return self.db.activeLayoutProfile
end

function SH.Store:GetActiveProfile()
    return findProfile(self.db.layoutProfiles, self.db.activeLayoutProfile) or self.db.layoutProfiles[1]
end

function SH.Store:GetTemporaryLayout()
    return self.db.temporaryLayout
end

function SH.Store:GetProfile(profileID)
    return findProfile(self.db.layoutProfiles, profileID)
end

function SH.Store:ProfileNameExists(name, exceptProfileID)
    local normalizedName = normalizedProfileName(name)
    if normalizedName == "" then return false end
    for _, profile in ipairs(self.db.layoutProfiles) do
        if profile.id ~= exceptProfileID and normalizedProfileName(profile.name) == normalizedName then return true end
    end
    return false
end

function SH.Store:ValidateProfileName(name, exceptProfileID)
    local cleaned = cleanProfileName(name)
    if cleaned == "" then return nil, "Enter a profile name."
    elseif self:ProfileNameExists(cleaned, exceptProfileID) then return nil, "That profile name is already in use."
    end
    return cleaned
end

function SH.Store:UniqueProfileName(baseName)
    local base = cleanProfileName(baseName)
    if base == "" then base = "Raid Layout" end
    if not self:ProfileNameExists(base) then return base end
    for suffix = 2, PROFILE_LIMIT + 1 do
        local suffixText = " " .. tostring(suffix)
        local candidate = base:sub(1, PROFILE_NAME_LIMIT - #suffixText) .. suffixText
        if not self:ProfileNameExists(candidate) then return candidate end
    end
    return nil
end

function SH.Store:SelectProfile(profileID)
    if not findProfile(self.db.layoutProfiles, profileID) then return false end
    self.db.activeLayoutProfile = profileID
    self.db.temporaryLayout = nil
    return true
end

function SH.Store:CreateProfile(name, layout)
    if #self.db.layoutProfiles >= PROFILE_LIMIT then return nil, "You can store up to 10 layout profiles." end
    local cleaned, reason = self:ValidateProfileName(name)
    if not cleaned then return nil, reason end
    layout = layout or self:GetLayout()
    if not validLayout(layout) then return nil, "The current marker layout is invalid." end

    local id
    repeat
        id = "profile-" .. tostring(self.db.nextLayoutProfileID)
        self.db.nextLayoutProfileID = self.db.nextLayoutProfileID + 1
    until not findProfile(self.db.layoutProfiles, id)

    self.db.layoutProfiles[#self.db.layoutProfiles + 1] = {id = id, name = cleaned, layout = copy(layout)}
    self.db.activeLayoutProfile = id
    self.db.temporaryLayout = nil
    return id
end

function SH.Store:RenameProfile(profileID, name)
    if profileID == "default" then return false, "The Default profile cannot be renamed." end
    local profile = findProfile(self.db.layoutProfiles, profileID)
    if not profile then return false, "That profile no longer exists." end
    local cleaned, reason = self:ValidateProfileName(name, profileID)
    if not cleaned then return false, reason end
    profile.name = cleaned
    return true
end

function SH.Store:DeleteProfile(profileID)
    if profileID == "default" then return false, "The Default profile cannot be deleted." end
    local _, index = findProfile(self.db.layoutProfiles, profileID)
    if not index then return false, "That profile no longer exists." end
    table.remove(self.db.layoutProfiles, index)
    if self.db.activeLayoutProfile == profileID then self.db.activeLayoutProfile = "default" end
    return true
end

function SH.Store:SwapLayoutPositions(first, second)
    first, second = tonumber(first), tonumber(second)
    if not first or not second or first < 1 or first > 8 or second < 1 or second > 8 then return false end
    if not self.db.temporaryLayout and self.db.activeLayoutProfile == "default" then
        return false, "Create a new profile before changing the Default layout."
    end
    local layout = self:GetLayout()
    layout[first], layout[second] = layout[second], layout[first]
    return true
end

function SH.Store:ResetCurrentLayout()
    if not self.db.temporaryLayout and self.db.activeLayoutProfile == "default" then return false end
    local layout = self:GetLayout()
    for position = 1, 8 do layout[position] = SH.Const.DEFAULT_LAYOUT[position] end
    return true
end

function SH.Store:ResetDefaultLayout()
    local defaultProfile = findProfile(self.db.layoutProfiles, "default")
    defaultProfile.layout = copy(SH.Const.DEFAULT_LAYOUT)
    self.db.layout = copy(SH.Const.DEFAULT_LAYOUT)
    self.db.activeLayoutProfile = "default"
    self.db.temporaryLayout = nil
    return true
end

function SH.Store:SetTemporaryLayout(layout, sender)
    if not validLayout(layout) then return false end
    self.db.temporaryLayout = {
        layout = copy(layout),
        sender = tostring(sender or ""),
        acceptedAt = GetServerTime and GetServerTime() or time(),
    }
    return true
end

function SH.Store:ClearTemporaryLayout()
    self.db.temporaryLayout = nil
end

function SH.Store:HasTemporaryLayout()
    return self.db.temporaryLayout ~= nil
end

function SH.Store:FrameState(key)
    self.db.frames[key] = self.db.frames[key] or copy(defaults.frames[key] or defaults.frames.roomMap)
    return self.db.frames[key]
end

function SH.Store:SaveFrame(key, frame)
    if not frame then return end
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    local state = self:FrameState(key)
    state.point = point or "CENTER"
    state.relativePoint = relativePoint or state.point
    state.x = math.floor((tonumber(x) or 0) + 0.5)
    state.y = math.floor((tonumber(y) or 0) + 0.5)
end

function SH.Store:ApplyFrame(key, frame)
    local state = self:FrameState(key)
    frame:ClearAllPoints()
    frame:SetPoint(state.point, UIParent, state.relativePoint, state.x, state.y)
end
