local _, SH = ...

SH.Const = {
    ENCOUNTER_ID = 3420,
    PREFIX = "SSZHELP",
    PROTOCOL = 1,
    EXIT_POSITION = 1,
    ENTRANCE_POSITION = 5,
    WIND_POSITIONS = {2, 3, 4, 6, 7, 8},
    DIRECTIONS = {"Exit", "Northeast", "East", "Southeast", "Entrance", "Southwest", "West", "Northwest"},
    MARKER_NAMES = {"Star", "Circle", "Diamond", "Triangle", "Moon", "Square", "Cross", "Skull"},
    DEFAULT_LAYOUT = {7, 4, 5, 6, 8, 1, 2, 3},
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
    return string.format("{rt%d}", tonumber(markerID) or 8)
end
