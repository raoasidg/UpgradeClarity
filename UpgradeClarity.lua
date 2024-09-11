local _, namespace = ...
local localizations = namespace.localizations

-- Local References
local error, floor, ipairs, pairs, rawset, select, setmetatable,
        strlower, strmatch, tconcat, tinsert, tonumber, type =
      error, floor, ipairs, pairs, rawset, select, setmetatable,
        strlower, strmatch, table.concat, tinsert, tonumber, type

local API_AddTooltipPostCall = TooltipDataProcessor.AddTooltipPostCall
local API_CreateFrame = CreateFrame
local API_GameTooltip, API_ItemRefTooltip, API_ShoppingTooltip1, API_ShoppingTooltip2 =
      GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2
local API_GetCurrencyInfo = C_CurrencyInfo.GetCurrencyInfo
local API_GetDifficultyName = DifficultyUtil.GetDifficultyName
local API_GetDisplayedItem = TooltipUtil.GetDisplayedItem
local API_GetItemInfo = C_Item.GetItemInfo

local DIFFICULTY_IDS = DifficultyUtil.ID
local DELVES, DUNGEONS, RAIDS = DELVES_LABEL, DUNGEONS, RAIDS
local GARRISON_TIER = GARRISON_TIER
local HEADER_COLON = HEADER_COLON
local ITEM_QUALITY_COLORS = ITEM_QUALITY_COLORS
local ITEM_UPGRADE_TOOLTIP_FORMAT_STRING = ITEM_UPGRADE_TOOLTIP_FORMAT_STRING
--local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local TOOLTIP_TYPE_ITEM = Enum.TooltipDataType.Item

-- Upgrade Track Item Level Information
-- Every upgrade track has bands of BAND_COUNT item levels that are evenly spaced by BAND_SPACING levels.  It is
-- necessary to add/subtract BAND_ADJUSTMENT from neighboring band item levels for every subsequent band away from the
-- item's current upgrade band.
local BAND_COUNT = 4
local BAND_SPACING = 3
local BAND_ADJUSTMENT = 1

-- Data Structures
-- Table containing mappings of the names of dungeon and raid difficulties.  Doing it this way because I wanted to play
-- with metamethods and to reduce duplicated calls to API_GetDifficultyName in code.
local difficulty_names = setmetatable({
    dungeon = {},
    raid = {},
}, {
    __call = function(self, identifier)
        local difficulty_type_dungeon = strmatch(identifier, "^Dungeon(.+)")
        local difficulty_type_raid = strmatch(identifier, "^PrimaryRaid(.+)")
        local location_type = difficulty_type_dungeon and "dungeon" or difficulty_type_raid and "raid"

        if not location_type then return end

        local difficulty_type = strlower(difficulty_type_dungeon or difficulty_type_raid)
        self[location_type][difficulty_type] = API_GetDifficultyName(DIFFICULTY_IDS[identifier])
    end,
    __newindex = function()
        error("Assignment error: \"difficulty_names\" cannot be directly assigned attributes.")
    end,
})
difficulty_names("DungeonHeroic")
difficulty_names("DungeonMythic")
difficulty_names("DungeonChallenge") -- Mythic+
difficulty_names("PrimaryRaidLFR")
difficulty_names("PrimaryRaidNormal")
difficulty_names("PrimaryRaidHeroic")
difficulty_names("PrimaryRaidMythic")

-- Table containing mappings of the localized upgrade track names to the relevant indices.   Doing it this way for the
-- same reason as for difficulty_names (fun) and the values are always sequentially incremented by the call order
-- (e.g. VETERAN = 3).
local upgrade_mapping = setmetatable({}, {
    __call = function(self, upgrade_track_name)
        rawset(self, "__length", (self.__length or 0) + 1)
        rawset(self, localizations[upgrade_track_name], self.__length)
    end,
    __newindex = function()
        error("Assignment error: \"upgrade_mapping\" assignments must be done through function call.")
    end,
})
upgrade_mapping("UPGRADE_TRACK_NAME_EXPLORER")
upgrade_mapping("UPGRADE_TRACK_NAME_ADVENTURER")
upgrade_mapping("UPGRADE_TRACK_NAME_VETERAN")
upgrade_mapping("UPGRADE_TRACK_NAME_CHAMPION")
upgrade_mapping("UPGRADE_TRACK_NAME_HERO")
upgrade_mapping("UPGRADE_TRACK_NAME_MYTH")
upgrade_mapping("UPGRADE_TRACK_NAME_EX1")

-- Table containing data regarding non-crafted upgrade tracks.
local upgrade_tracks = {
    [1] = { -- Explorer
        color = ITEM_QUALITY_COLORS[1].hex,
        shared_tracks = {
            {
                start_upgrade_level = 5,
                track_index = 2,
            },
        },
    },
    [2] = { -- Adventurer
        color = ITEM_QUALITY_COLORS[2].hex,
        shared_tracks = {
            {
                start_upgrade_level = 5,
                track_index = 3,
            },
        },
    },
    [3] = { -- Veteran
        color = ITEM_QUALITY_COLORS[3].hex,
        shared_tracks = {
            {
                start_upgrade_level = 5,
                track_index = 4,
            },
        },
    },
    [4] = { -- Champion
        color = ITEM_QUALITY_COLORS[4].hex,
        shared_tracks = {
            {
                start_upgrade_level = 5,
                track_index = 5,
            },
        },
    },
    [5] = { -- Hero
        color = ITEM_QUALITY_COLORS[5].hex,
        shared_tracks = {
            {
                start_upgrade_level = 5,
                track_index = 6,
            },
        },
    },
    [6] = { -- Myth
        color = ITEM_QUALITY_COLORS[6].hex,
    },
--[[
    [7] = { -- Awakened; only relevant in Dragonflight Season 4.
        color = "|c"..RAID_CLASS_COLORS.PALADIN.colorStr,
        shared_tracks = {
            {
                start_upgrade_level = 1,
                track_index = 4,
            },
            {
                start_upgrade_level = 5,
                track_index = 5,
            },
            {
                start_upgrade_level = 9,
                track_index = 6,
            },
            {
                start_upgrade_level = 13,
            },
        },
    },
]]
}

-- Table containing data regarding upgrade track crest currency information and drop sources for the current expansion.
local upgrade_crests = setmetatable({
    [3] = { -- Weathered
        currency_id = 2914,
        name = localizations.CREST_NAME_VETERAN,
        sources = {
            delve = {
                levels = {1, 5},
            },
            dungeon = {
                type = difficulty_names.dungeon.heroic,
            },
            raid = difficulty_names.raid.lfr,
        },
    },
    [4] = { -- Carved
        currency_id = 2915,
        name = localizations.CREST_NAME_CHAMPION,
        sources = {
            delve = {
                levels = {6, 7},
            },
            dungeon = {
                levels = {2, 3},
                type = difficulty_names.dungeon.mythic,
            },
            raid = difficulty_names.raid.normal,
        },
    },
    [5] = { -- Runed
        currency_id = 2916,
        name = localizations.CREST_NAME_HERO,
        sources = {
            delve = {
                levels = {8, "+"},
            },
            dungeon = {
                levels = {4, 8},
            },
            raid = difficulty_names.raid.heroic,
        },
    },
    [6] = { -- Gilded
        currency_id = 2917,
        name = localizations.CREST_NAME_MYTH,
        sources = {
            dungeon = {
                levels = {9, "+"},
            },
            raid = difficulty_names.raid.mythic,
        },
    },
    __default = { -- Valorstones; catchall for anything referenced not in the table.
        currency_id = 3008,
        sources = {
            other = localizations.DEFAULT_CURRENCY_SOURCE,
        },
    }
}, {
    __index = function(self) return self.__default end,
})

-- Data Functions
-- Helper function to generate the crest source strings for the tooltip or item link.
local function build_crest_sources(upgrade_track, upgrade_level)
    local current_upgrade_track = upgrade_tracks[upgrade_track]
    local current_upgrade_crest = upgrade_crests[upgrade_track]
    local next_upgrade_crest, next_upgrade_track
    for _, shared_track in ipairs(current_upgrade_track.shared_tracks or {}) do
        local shared_track_index = shared_track.track_index

        -- Since Lua does not have a 'continue' statement, use 'repeat...until' with a 'break' within for a "fun"
        -- implementation.
        repeat
            if not shared_track_index then break end

            if shared_track.start_upgrade_level - 1 <= upgrade_level then
                current_upgrade_crest = upgrade_crests[shared_track_index]
                current_upgrade_track = upgrade_tracks[shared_track_index]
            elseif not next_upgrade_track then
                next_upgrade_crest = upgrade_crests[shared_track_index]
                next_upgrade_track = upgrade_tracks[shared_track_index]
            end
        until true
    end

    local current_track_upgrade_sources = {}
    local next_track_upgrade_sources = {}
    local set_header_delve, set_header_dungeon, set_header_raid = false, false, false
    -- Loop over a table of tuples that contain the relevant data elements to avoid code duplication.
    for i, crest_tuple in ipairs({
        {current_track_upgrade_sources, current_upgrade_crest, current_upgrade_track, localizations.HEADER_CREST_CURRENT},
        {next_track_upgrade_sources, next_upgrade_crest, next_upgrade_track, localizations.HEADER_CREST_NEXT},
    }) do
        -- Another 'continue' implementation.
        repeat
            if not crest_tuple[2] then break end

            local currency_info = API_GetCurrencyInfo(crest_tuple[2].currency_id)
            local currency_name = crest_tuple[2].name or currency_info.name

            tinsert(
                crest_tuple[1],
                "|cFFFFFFFF"..crest_tuple[4]..HEADER_COLON.."|r |T"..currency_info.iconFileID
                    ..":12:12:0:0:64:64:4:60:4:60|t"..crest_tuple[3].color..currency_name.."|r"
            )

            local crest_sources = crest_tuple[2].sources
            if crest_sources.other then
                tinsert(crest_tuple[1], crest_sources.other)
            end
            if crest_sources.dungeon then
                local crest_dungeon = crest_sources.dungeon
                local dungeon_string = ""

                if not set_header_dungeon then
                    dungeon_string = "|cFFFFFFFF"..DUNGEONS..HEADER_COLON.."|r "

                    set_header_dungeon = true
                end

                if crest_dungeon.levels then
                    local dungeon_type = crest_dungeon.type
                    if dungeon_type then
                        dungeon_string = dungeon_string..dungeon_type..", "
                    end

                    local dungeon_levels = crest_dungeon.levels
                    dungeon_string = dungeon_string..difficulty_names.dungeon.challenge.." "..dungeon_levels[1]

                    if type(dungeon_levels[2]) == "number" then
                        dungeon_string = dungeon_string.."-"..dungeon_levels[2]
                    else
                        dungeon_string = dungeon_string.." "..localizations.SOURCE_AND_ABOVE
                    end
                else
                    dungeon_string = dungeon_string..crest_dungeon.type
                end

                tinsert(crest_tuple[1], dungeon_string)
            end
            if crest_sources.raid then
                local raid_string = ""

                if not set_header_raid then
                    raid_string = "|cFFFFFFFF"..RAIDS..HEADER_COLON.."|r "

                    set_header_raid = true
                end

                tinsert(crest_tuple[1], raid_string..crest_sources.raid)
            end
            -- This is largely the same logic as the dungeon information, but restating it allows for easier
            -- modification in the future if necessary.
            if crest_sources.delve then
                local crest_delve = crest_sources.delve
                local delve_string = ""

                if not set_header_delve then
                    delve_string = "|cFFFFFFFF"..DELVES..HEADER_COLON.."|r "

                    set_header_delve = true
                end

                if crest_delve.levels then
                    local delve_levels = crest_delve.levels
                    -- GARRISON_TIER is the only global string I found that was "Tier" alone.  The localization context
                    -- should be alright I think.
                    delve_string = delve_string..GARRISON_TIER.." "..delve_levels[1]

                    if type(delve_levels[2]) == "number" then
                        delve_string = delve_string.."-"..delve_levels[2]
                    else
                        delve_string = delve_string.." "..localizations.SOURCE_AND_ABOVE
                    end
                end

                tinsert(crest_tuple[1], delve_string)
            end
        until true
    end

    -- The current track's crest information needs to have at least the same number of lines as the next track's crest
    -- information.  Otherwise, the tooltip formatting will be off.
    while #current_track_upgrade_sources < #next_track_upgrade_sources do
        tinsert(current_track_upgrade_sources, " ")
    end
    -- The next track's crest information needs to have at least the same number of lines as the current track's crest
    -- information.  Otherwise, the tooltip formatting will be off.
    while #next_track_upgrade_sources < #current_track_upgrade_sources do
        tinsert(next_track_upgrade_sources, " ")
    end

    return tconcat(current_track_upgrade_sources, "\n"), tconcat(next_track_upgrade_sources, "\n")
end

-- Helper function to generate the upgrade track gear item levels string for the tooltip or item link.
local function build_item_level_track(item_level, upgrade_track, upgrade_level, max_upgrade_level)
    -- track_start_item_level = current item level
    --      MINUS total upgrade item levels
    --      MINUS the item level adjustment for the number of upgrade bands to the start of the upgrade track.
    local track_start_item_level = item_level
        - ((upgrade_level - 1) * BAND_SPACING)
        - (floor((upgrade_level - 1) / BAND_COUNT) * BAND_ADJUSTMENT)
    local color = upgrade_level == 1 and ITEM_QUALITY_COLORS[7].hex or ITEM_QUALITY_COLORS[0].hex

    local track_item_levels = {color..track_start_item_level.."|r"}
    for i = 1, max_upgrade_level - 1 do
        local band_adjustment = floor(i / BAND_COUNT) * BAND_ADJUSTMENT
        local band_spacing = (BAND_SPACING * i) + band_adjustment

        color = ITEM_QUALITY_COLORS[0].hex

        -- Offsetting the index by 1 beyond here when comparing to the upgrade level due to the loop being off by one
        -- since the first upgrade item level was already determined before entering the loop.
        local offset_i = i + 1
        if upgrade_level < offset_i then
            local current_upgrade_track = upgrade_tracks[upgrade_track]
            color = current_upgrade_track.color
            for _, shared_track in ipairs(current_upgrade_track.shared_tracks or {}) do
                if shared_track.start_upgrade_level <= offset_i then
                    if shared_track.track_index then
                        color = upgrade_tracks[shared_track.track_index].color
                    else
                        color = current_upgrade_track.color
                    end
                end
            end
        elseif upgrade_level == offset_i then
            color = ITEM_QUALITY_COLORS[7].hex
        end

        tinsert(track_item_levels, color..(track_start_item_level + band_spacing).."|r")
    end

    return tconcat(track_item_levels, " ")
end

-- Helper function to needily iterate over the tooltip or item link lines.
local function get_upgrade_information(tooltip_lines)
    local upgrade_track, upgrade_level, max_upgrade_level

    for i, tooltip_line in ipairs(tooltip_lines) do
        tooltip_line = tooltip_line.leftText

        -- Current behavior in the game is for previous season items (which are no longer reasonably upgradeable) to
        -- have a specific tooltip line denoting the originating season.  This is not present on current season items.
        -- Currently just checking the color of that specific line to save investigative effort; this is bound to break
        -- at some point.
        if i == 2 and strmatch(tooltip_line, "^|cFF808080") then return end

        if not upgrade_track or not upgrade_level or not max_upgrade_level then
            local upgrade_string_pattern = ITEM_UPGRADE_TOOLTIP_FORMAT_STRING:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
            upgrade_track, upgrade_level, max_upgrade_level = strmatch(tooltip_line, upgrade_string_pattern)
        end

        -- Found everything; exit.
        if upgrade_track and upgrade_level and max_upgrade_level then
            return upgrade_mapping[upgrade_track], tonumber(upgrade_level), tonumber(max_upgrade_level)
        end
    end
end

-- Add upgrade track information to the bottom of item tooltips and links.
local function tooltip_handler(tooltip, data)
    local function eq_sequence(compare, sequence)
        for _, sequence_item in ipairs(sequence) do
            if compare == sequence_item then return true end
        end

        return false
    end
    if not eq_sequence(
        tooltip,
        {API_GameTooltip, API_ItemRefTooltip, API_ShoppingTooltip1, API_ShoppingTooltip2}
    ) then return end

    local item_link = select(2, API_GetDisplayedItem(tooltip))
    -- Catch an edge case where the handler has fired but the tooltip has not loaded the item yet.
    if not item_link then return end

    local item_level = select(4, API_GetItemInfo(item_link))
    local upgrade_track, upgrade_level, max_upgrade_level = get_upgrade_information(data.lines)
    if not upgrade_track
        or not upgrade_level
        or not max_upgrade_level
        or upgrade_level == max_upgrade_level then return end

    tooltip:AddLine("\n"..localizations.HEADER_UPGRADE_CRESTS..HEADER_COLON)
    tooltip:AddLine(build_item_level_track(item_level, upgrade_track, upgrade_level, max_upgrade_level))
    tooltip:AddDoubleLine(build_crest_sources(upgrade_track, upgrade_level))

    tooltip:Show()
end

-- Event Handling
-- Establish addon frame
local UpgradeClarity = {
    events = {},
    frame = API_CreateFrame("Frame"),
}

-- PLAYER_LOGIN event hook.
function UpgradeClarity.events:PLAYER_LOGIN()
    -- Hook into the GameTooltip data processor
    API_AddTooltipPostCall(TOOLTIP_TYPE_ITEM, tooltip_handler)
end

-- Register events established for the addon frame.
for key in pairs(UpgradeClarity.events) do
    UpgradeClarity.frame:RegisterEvent(key)
end

-- Trigger the event functions for the relevant registered events.
UpgradeClarity.frame:SetScript("OnEvent", function(self, event, ...)
    UpgradeClarity.events[event](self, ...)
end)
