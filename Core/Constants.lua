local _, SH = ...

SH.Const = {
    ENCOUNTER_ID = 3420,
    INSTANCE_ID = 3004,
    PREFIX = "SSZHELP",
    PROTOCOL = 1,
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
