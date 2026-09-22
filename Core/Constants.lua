local _, SH = ...

SH.Const = {
    ENCOUNTER_ID = 3420,
    INSTANCE_ID = 3004,
    PREFIX = "SSZHELP",
    PROTOCOL = 1,
    FRAME_SCALE_BASE = 0.75,
    -- Elapsed cast times from NSRT's Sszorak data (2026-09-09).
    -- Normal: EncounterAlerts/MidnightS2/Sszorak.lua; Heroic/Mythic: BossTimelines/MidnightS2/Sszorak.lua.
    -- https://github.com/Reloe/NorthernSkyRaidTools/tree/main/NorthernSkyRaidTools
    ENCOUNTER_TIMES = {
        [14] = {surges = {36.25, 95, 188.3, 247, 340.3}, intermissions = {125, 277.1, 429.2}},
        [15] = {surges = {32.22, 84.44, 170.39, 222.64, 308.53, 360.72, 446.65}, intermissions = {111.17, 249.27, 387.42}},
        [16] = {surges = {29, 77, 156, 203, 283, 330}, intermissions = {100.02, 227.02, 354.02}},
    },
    EXIT_POSITION = 1,
    ENTRANCE_POSITION = 5,
    WIND_POSITIONS = {2, 3, 4, 6, 7, 8},
    DIRECTIONS = {"Exit", "Northeast", "East", "Southeast", "Entrance", "Southwest", "West", "Northwest"},
    MARKER_NAMES = {"Star", "Circle", "Diamond", "Triangle", "Moon", "Square", "Cross", "Skull"},
    DEFAULT_LAYOUT = {5, 6, 4, 1, 8, 2, 7, 3},
    DIFFICULTIES = {
        {id = 17, name = "Raid Finder"},
        {id = 14, name = "Normal"},
        {id = 15, name = "Heroic"},
        {id = 16, name = "Mythic"},
    },
}

function SH.Const:Opposite(position)
    return ((tonumber(position) or 1) + 3) % 8 + 1
end

function SH.Const:IsWindPosition(position)
    for _, value in ipairs(self.WIND_POSITIONS) do
        if value == position then return true end
    end
    return false
end

function SH.Const:MarkerToken(markerID)
    local id = tonumber(markerID) or 8
    if id < 1 or id > 8 then id = 8 end
    return string.format("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%d:0|t", id)
end

function SH.Const:MarkerName(markerID)
    return self.MARKER_NAMES[tonumber(markerID) or 8] or "Skull"
end

function SH.Const:IntermissionEvents(index, start)
    local prefix = "intermission" .. index
    return {
        {id = prefix, label = "Intermission " .. index .. " start", kind = "intermission", index = index, time = start},
        {id = prefix .. "wind1", label = "Intermission " .. index .. " - Wind 1", kind = "wind", index = 1, time = start},
        {id = prefix .. "wind2", label = "Intermission " .. index .. " - Wind 2", kind = "wind", index = 2, time = start + 8},
        {id = prefix .. "wind3", label = "Intermission " .. index .. " - Wind 3", kind = "wind", index = 3, time = start + 18},
        {id = prefix .. "rotationStop", label = "Intermission " .. index .. " - Rotation stop", kind = "rotationStop", index = index, time = start + 25},
        {id = prefix .. "phaseReset", label = "Intermission " .. index .. " end / reset", kind = "phaseReset", index = index, time = start + 30},
    }
end

function SH.Const:SortSchedule(events)
    local priority = {surge = 1, intermission = 2, wind = 3, rotationStop = 4, phaseReset = 5}
    table.sort(events, function(a, b)
        if a.time == b.time then return priority[a.kind] < priority[b.kind] end
        return a.time < b.time
    end)
    return events
end

function SH.Const:DefaultSchedule(difficultyID)
    difficultyID = tonumber(difficultyID)
    -- Raid Finder shares Normal's defaults; saved overrides remain per difficulty.
    local data = self.ENCOUNTER_TIMES[difficultyID == 17 and 14 or difficultyID]
    local events = {}
    if not data then return events end
    for index, elapsed in ipairs(data.surges) do
        events[#events + 1] = {id = "surge" .. index, label = "Surge " .. index, kind = "surge", index = (index - 1) % 2 + 1, time = elapsed}
    end
    for index, elapsed in ipairs(data.intermissions) do
        for _, event in ipairs(self:IntermissionEvents(index, elapsed)) do events[#events + 1] = event end
    end
    return self:SortSchedule(events)
end

function SH.Const:FormatFightTime(seconds)
    local ticks = math.floor(seconds * 100 + 0.5)
    return string.format("%d:%05.2f", math.floor(ticks / 6000), (ticks % 6000) / 100)
end

function SH.Const:ParseFightTime(value)
    if type(value) == "number" then return value end
    if type(value) ~= "string" then return nil end
    local minutes, seconds = value:match("^%s*(%d+):(%d+%.?%d*)%s*$")
    if minutes then
        seconds = tonumber(seconds)
        if seconds >= 60 then return nil end
        return tonumber(minutes) * 60 + seconds
    end
    return tonumber(value)
end
