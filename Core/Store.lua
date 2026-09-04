local _, SH = ...

SH.Store = {initializeOrder = 10}
SH.modules.Store = SH.Store

local defaults = {
    version = 1,
    options = {
        showRoomMap = true,
        showOrderFrame = true,
        previewFrames = false,
        lockFrames = true,
        roomMapScale = 1,
        orderFrameScale = 1,
        frameBackgroundOpacity = 1,
        minimapAngle = 220,
        rotateMap = true,
        raidWarningSurges = true,
        raidWarningPushes = false,
        showClearButton = false,
        difficulties = {[17] = true, [14] = true, [15] = true, [16] = true},
    },
    layout = {7, 4, 5, 6, 8, 1, 2, 3},
    temporaryLayout = nil,
    frames = {
        roomMap = {point = "CENTER", relativePoint = "CENTER", x = -360, y = 20},
        order = {point = "CENTER", relativePoint = "CENTER", x = 0, y = 260},
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

function SH.Store:OnInitialize()
    if type(SszorakHelperDB) ~= "table" then SszorakHelperDB = {} end
    merge(SszorakHelperDB, copy(defaults))
    if not validLayout(SszorakHelperDB.layout) then
        SszorakHelperDB.layout = copy(SH.Const.DEFAULT_LAYOUT)
    end
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
    return temporary and temporary.layout or self.db.layout
end

function SH.Store:GetDefaultLayout()
    return self.db.layout
end

function SH.Store:SetDefaultLayout(layout)
    if not validLayout(layout) then return false end
    self.db.layout = copy(layout)
    self.db.temporaryLayout = nil
    return true
end

function SH.Store:ResetDefaultLayout()
    self.db.layout = copy(SH.Const.DEFAULT_LAYOUT)
    self.db.temporaryLayout = nil
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
