-- BiSGearCheck Util.lua
-- Slot mappings, class/spec tables, zone mappings, helpers

BiSGearCheck = BiSGearCheck or {}

-- Map our slot names to WoW inventory slot IDs
BiSGearCheck.SlotToInvSlot = {
    ["Head"]      = { 1 },
    ["Neck"]      = { 2 },
    ["Shoulders"] = { 3 },
    ["Back"]      = { 15 },
    ["Chest"]     = { 5 },
    ["Wrist"]     = { 9 },
    ["Hands"]     = { 10 },
    ["Waist"]     = { 6 },
    ["Legs"]      = { 7 },
    ["Feet"]      = { 8 },
    ["Rings"]     = { 11, 12 },
    ["Trinkets"]  = { 13, 14 },
    ["Main Hand"] = { 16 },
    ["Offhand"]   = { 17 },
    ["Twohand"]   = { 16 },
    ["Ranged"]    = { 18 },
}

-- Display order for slots
BiSGearCheck.SlotOrder = {
    "Head", "Neck", "Shoulders", "Back", "Chest", "Wrist", "Hands",
    "Waist", "Legs", "Feet", "Rings", "Trinkets",
    "Main Hand", "Offhand", "Twohand", "Ranged"
}

-- Dual-wield slot pairs. Used to exclude items already equipped in the
-- paired slot from appearing as upgrades in this slot — e.g. a 1H weapon
-- equipped in OH shouldn't show up as an MH upgrade. MH-only/OH-only items
-- (shields, librams, 2H-only weapons) aren't in both slot lists, so this
-- check naturally respects handedness: only items valid in either slot get
-- deduped.
BiSGearCheck.DualWieldPair = {
    ["Main Hand"] = "Offhand",
    ["Offhand"]   = "Main Hand",
}

-- Map class token -> list of spec keys
BiSGearCheck.ClassSpecs = {
    ["DRUID"]   = {
        { key = "DruidBalance",       label = "Balance" },
        { key = "DruidFeralDPS",      label = "Feral DPS" },
        { key = "DruidFeralTank",     label = "Feral Tank" },
        { key = "DruidRestoration",   label = "Restoration" },
    },
    ["HUNTER"]  = {
        { key = "HunterBM",           label = "Beast Mastery" },
        { key = "HunterMM",           label = "Marksmanship" },
        { key = "HunterSV",           label = "Survival" },
    },
    ["MAGE"]    = {
        { key = "MageArcane",         label = "Arcane" },
        { key = "MageFire",           label = "Fire" },
        { key = "MageFrost",          label = "Frost" },
    },
    ["PALADIN"] = {
        { key = "PaladinHoly",        label = "Holy" },
        { key = "PaladinProtection",  label = "Protection" },
        { key = "PaladinRetribution", label = "Retribution" },
    },
    ["PRIEST"]  = {
        { key = "PriestHoly",         label = "Holy" },
        { key = "PriestShadow",       label = "Shadow" },
    },
    ["ROGUE"]   = {
        { key = "RogueAssassination", label = "Assassination" },
        { key = "RogueCombat",        label = "Combat" },
        { key = "RogueSubtlety",      label = "Subtlety" },
    },
    ["SHAMAN"]  = {
        { key = "ShamanElemental",    label = "Elemental" },
        { key = "ShamanEnhancement",  label = "Enhancement" },
        { key = "ShamanRestoration",  label = "Restoration" },
    },
    ["WARLOCK"] = {
        { key = "WarlockAffliction",  label = "Affliction" },
        { key = "WarlockDemonology",  label = "Demonology" },
        { key = "WarlockDestruction", label = "Destruction" },
    },
    ["WARRIOR"] = {
        { key = "WarriorArms",        label = "Arms" },
        { key = "WarriorFury",        label = "Fury" },
        { key = "WarriorProtection",  label = "Protection" },
    },
}

-- Data source definitions
-- Each source maps phases to global table names.
-- Phase 0 = Pre-Raid, 1-5 = content phases.
BiSGearCheck.DataSources = {
    { key = "wowtbcgg",    label = "WowTBC.gg",    phases = { [1] = "BiSGearCheckDB_WowTBCgg", [2] = "BiSGearCheckDB_WowTBCgg_Phase2" },
      desc = "Community-voted BiS lists from wowtbc.gg. Broad coverage across all specs, but rankings reflect community opinion rather than simulated performance. Phase 2 covers all 27 specs with SSC/TK gear." },
    { key = "bistooltip",  label = "BiS-Tooltip",   phases = { [1] = "BiSGearCheckDB_Phase1", [2] = "BiSGearCheckDB_Phase2" },
      desc = "BiS rankings from the BiS-Tooltip addon (boegi1's TBC backport). Comprehensive and well-maintained. Full Phase 1 and Phase 2 coverage for all 27 specs." },
    { key = "atlasloot",   label = "AtlasLoot",     phases = { [1] = "BiSGearCheckDB_AtlasLoot", [2] = "BiSGearCheckDB_AtlasLoot_Phase2" },
      desc = "BiS lists derived from AtlasLoot's loot tables. Good dungeon and raid coverage, but may include items not typically considered BiS by other sources. Phase 2 covers 25 specs. Missing Rogue Assassination and Rogue Subtlety in both phases." },
    { key = "wowsims",     label = "WoWSims",       phases = { [1] = "BiSGearCheckDB_WoWSims", [2] = "BiSGearCheckDB_WoWSims_Phase2" },
      desc = "Simulation-optimized gear sets from WoWSims TBC. Most mathematically rigorous. Phase 1 covers 22 specs. Phase 2 has limited coverage (5 specs with explicit presets); other specs fall back to Phase 1 data." },
    { key = "tmb",          label = "ThatsMyBis",    phases = { [1] = "BiSGearCheckDB_TMB", [2] = "BiSGearCheckDB_TMB_Phase2" },
      desc = "Community wishlist aggregates from thatsmybis.com. Reflects what raiders actually want. Phase 2 lists include SSC/TK items where wishlisted, with Phase 1 gear filling remaining slots." },
    { key = "wowhead",     label = "Wowhead",       phases = { [1] = "BiSGearCheckDB_Wowhead", [2] = "BiSGearCheckDB_Wowhead_Phase2" },
      desc = "Editorial BiS guides from Wowhead. Curated by guide writers. Phase 2 covers 24 specs. Missing Rogue Assassination, Rogue Subtlety, and Shaman Restoration." },
}

-- Resolve the global DB table name for a source at a given phase
function BiSGearCheck:GetSourceDBName(src, phase)
    if not src.phases then return nil end
    return src.phases[phase]
end

-- Check if a source has data for a given phase
function BiSGearCheck:SourceHasPhase(src, phase)
    return src.phases and src.phases[phase] ~= nil
end

-- Ensure sourceSettings saved var exists (all enabled by default)
-- Structure: sourceSettings[key] = { addon = bool, tooltip = bool }
function BiSGearCheck:EnsureSourceSettings()
    if not BiSGearCheckSaved then BiSGearCheckSaved = { characters = {} } end
    if not BiSGearCheckSaved.sourceSettings then
        BiSGearCheckSaved.sourceSettings = {}
        -- Migrate from old enabledSources/tooltipSources if present
        for _, src in ipairs(self.DataSources) do
            local addonEnabled = true
            local tooltipEnabled = true
            if BiSGearCheckSaved.enabledSources then
                addonEnabled = BiSGearCheckSaved.enabledSources[src.key] ~= false
            end
            if BiSGearCheckSaved.tooltipSources then
                tooltipEnabled = BiSGearCheckSaved.tooltipSources[src.key] ~= false
            elseif BiSGearCheckSaved.enabledSources then
                tooltipEnabled = BiSGearCheckSaved.enabledSources[src.key] ~= false
            end
            BiSGearCheckSaved.sourceSettings[src.key] = {
                addon = addonEnabled,
                tooltip = tooltipEnabled,
            }
        end
    end
    -- Ensure every source has an entry
    for _, src in ipairs(self.DataSources) do
        if not BiSGearCheckSaved.sourceSettings[src.key] then
            BiSGearCheckSaved.sourceSettings[src.key] = { addon = true, tooltip = true }
        end
    end
end

-- Backward compat alias
function BiSGearCheck:EnsureEnabledSources()
    self:EnsureSourceSettings()
end

-- Get source setting
function BiSGearCheck:GetSourceSetting(key, field)
    self:EnsureSourceSettings()
    local s = BiSGearCheckSaved.sourceSettings[key]
    return s and s[field] ~= false
end

-- Check if a data source is enabled for the addon UI
function BiSGearCheck:IsSourceEnabled(key)
    return self:GetSourceSetting(key, "addon")
end

-- Check if a data source is enabled for tooltips
function BiSGearCheck:IsTooltipSourceEnabled(key)
    return self:GetSourceSetting(key, "tooltip")
end

-- Get data sources enabled for the addon UI
function BiSGearCheck:GetEnabledDataSources()
    local enabled = {}
    for _, src in ipairs(self.DataSources) do
        if self:IsSourceEnabled(src.key) then
            enabled[#enabled + 1] = src
        end
    end
    return enabled
end

-- Get data sources enabled for the addon UI that have data for the current phase
function BiSGearCheck:GetEnabledDataSourcesForPhase()
    local phase = self.phaseFilter or 1
    local enabled = {}
    for _, src in ipairs(self.DataSources) do
        if self:IsSourceEnabled(src.key) and self:SourceHasPhase(src, phase) then
            enabled[#enabled + 1] = src
        end
    end
    return enabled
end

-- Get data sources enabled for tooltips
function BiSGearCheck:GetTooltipDataSources()
    local enabled = {}
    for _, src in ipairs(self.DataSources) do
        if self:IsTooltipSourceEnabled(src.key) then
            enabled[#enabled + 1] = src
        end
    end
    return enabled
end

-- Nil out globals for fully disabled sources (saves memory)
function BiSGearCheck:UnloadDisabledSources()
    self:EnsureSourceSettings()
    for _, src in ipairs(self.DataSources) do
        local s = BiSGearCheckSaved.sourceSettings[src.key]
        if s and not s.addon and not s.tooltip and src.phases then
            for _, dbName in pairs(src.phases) do
                _G[dbName] = nil
            end
        end
    end
end

-- Called when source settings change — rebuild tooltip index and refresh UI
function BiSGearCheck:OnSourceSettingsChanged()
    self:BuildTooltipIndex()
    -- Share the addon-enabled check between published + wishlist sources;
    -- sourceSettings holds flags for both kinds keyed by source key.
    local needSwitch = not self:IsSourceEnabled(self.dataSource)
    if not needSwitch then
        if self:IsWishlistSourceKey(self.dataSource) then
            -- Verify the underlying wishlist still exists
            local ck, wn = self:ParseWishlistSourceKey(self.dataSource)
            local cd = ck and BiSGearCheckSaved.characters and BiSGearCheckSaved.characters[ck]
            if not (cd and cd.wishlists and cd.wishlists[wn]) then
                needSwitch = true
            end
        else
            local phase = self.phaseFilter or 1
            local currentSrc
            for _, src in ipairs(self.DataSources) do
                if src.key == self.dataSource then currentSrc = src; break end
            end
            needSwitch = not currentSrc or not self:SourceHasPhase(currentSrc, phase)
        end
    end
    if needSwitch then
        local available = self:GetEnabledDataSourcesForPhase()
        if available[1] then
            self.dataSource = available[1].key
            BiSGearCheckChar.dataSource = self.dataSource
        end
    end
    if self.mainFrame and self.mainFrame:IsShown() then
        self:Refresh()
    end
end

-- Map SourceDB source strings to zone names returned by GetRealZoneText()
-- Multiple source strings can map to the same zone
BiSGearCheck.SourceToZone = {
    -- TBC Phase 1 Raids
    ["Karazhan"]            = "Karazhan",
    ["Gruul's Lair"]        = "Gruul's Lair",
    ["Magtheridon's Lair"]  = "Magtheridon's Lair",
    -- TBC Phase 2 Raids
    ["Serpentshrine Cavern"] = "Serpentshrine Cavern",
    ["Tempest Keep"]        = "Tempest Keep",
    -- TBC Phase 3 Raids
    ["Hyjal Summit"]        = "Hyjal Summit",
    ["Black Temple"]        = "Black Temple",
    -- TBC Phase 4
    ["Zul'Aman"]            = "Zul'Aman",
    -- TBC Phase 5
    ["Sunwell Plateau"]     = "Sunwell Plateau",
    ["Magisters' Terrace"]  = "Magisters' Terrace",
    -- Hellfire Citadel (normal + heroic variants)
    ["Hellfire Ramparts"]   = "Hellfire Ramparts",
    ["Hellfire Ramparts (H)"] = "Hellfire Ramparts",
    ["Ramparts (H)"]        = "Hellfire Ramparts",
    ["Blood Furnace"]       = "The Blood Furnace",
    ["Blood Furnace (N)"]   = "The Blood Furnace",
    ["Blood Furnace (H)"]   = "The Blood Furnace",
    ["The Blood Furnace"]   = "The Blood Furnace",
    ["The Blood Furnace (H)"] = "The Blood Furnace",
    ["Shattered Halls"]     = "The Shattered Halls",
    ["Shattered Halls (H)"] = "The Shattered Halls",
    ["The Shattered Halls"] = "The Shattered Halls",
    ["The Shattered Halls (H)"] = "The Shattered Halls",
    -- Coilfang Reservoir
    ["Slave Pens"]          = "The Slave Pens",
    ["Slave Pens (N)"]      = "The Slave Pens",
    ["Slave Pens (H)"]      = "The Slave Pens",
    ["The Slave Pens"]      = "The Slave Pens",
    ["The Slave Pens (H)"]  = "The Slave Pens",
    ["Underbog"]            = "The Underbog",
    ["Underbog (H)"]        = "The Underbog",
    ["The Underbog"]        = "The Underbog",
    ["The Underbog (H)"]    = "The Underbog",
    ["Steamvaults"]         = "The Steamvault",
    ["Steamvaults (H)"]     = "The Steamvault",
    ["The Steamvault"]      = "The Steamvault",
    ["The Steamvault (H)"]  = "The Steamvault",
    -- Auchindoun
    ["Mana-Tombs"]          = "Mana-Tombs",
    ["Mana-Tombs (H)"]      = "Mana-Tombs",
    ["Mana Tombs"]          = "Mana-Tombs",
    ["Mana Tombs (H)"]      = "Mana-Tombs",
    ["Auchenai Crypts"]     = "Auchenai Crypts",
    ["Auchenai Crypts (H)"] = "Auchenai Crypts",
    ["Sethekk Halls"]       = "Sethekk Halls",
    ["Sethekk Halls (H)"]   = "Sethekk Halls",
    ["Shadow Labyrinth"]    = "Shadow Labyrinth",
    ["Shadow Labyrinth (H)"] = "Shadow Labyrinth",
    -- Tempest Keep (dungeon wing)
    ["The Mechanar"]        = "The Mechanar",
    ["The Mechanar (H)"]    = "The Mechanar",
    ["Mechanar"]            = "The Mechanar",
    ["Mechanar (H)"]        = "The Mechanar",
    ["The Botanica"]        = "The Botanica",
    ["The Botanica (H)"]    = "The Botanica",
    ["Botanica"]            = "The Botanica",
    ["Botanica (H)"]        = "The Botanica",
    ["The Arcatraz"]        = "The Arcatraz",
    ["The Arcatraz (H)"]    = "The Arcatraz",
    ["Arcatraz"]            = "The Arcatraz",
    ["Arcatraz (H)"]        = "The Arcatraz",
    -- Caverns of Time
    ["Old Hillsbrad Foothills"]     = "Old Hillsbrad Foothills",
    ["Old Hillsbrad Foothills (N)"] = "Old Hillsbrad Foothills",
    ["Old Hillsbrad Foothills (H)"] = "Old Hillsbrad Foothills",
    ["The Black Morass"]    = "The Black Morass",
    ["The Black Morass (H)"] = "The Black Morass",
    ["Black Morass"]        = "The Black Morass",
    ["Black Morass (H)"]    = "The Black Morass",
    -- Classic raids
    ["Molten Core"]         = "Molten Core",
    ["Blackwing Lair"]      = "Blackwing Lair",
    ["Naxxramas"]           = "Naxxramas",
    ["Ahn'Qiraj"]           = "Ahn'Qiraj",
    -- Classic dungeons
    ["Blackrock Depths"]    = "Blackrock Depths",
    ["Stratholme"]          = "Stratholme",
    -- Other
    ["Tailoring"]           = "Crafted",
    ["Leatherworking"]      = "Crafted",
    ["Blacksmithing"]       = "Crafted",
    ["Alchemy"]             = "Crafted",
    ["Engineering"]         = "Crafted",
    ["Jewelcrafting"]       = "Crafted",
    ["Quest Reward"]        = "Quest",
    ["PvP"]                 = "PvP",
    ["Vendor & Rep"]              = "Vendor & Rep",
    ["Badge of Justice"]    = "Vendor & Rep",
    ["Reputation"]          = "Vendor & Rep",
    ["Spirit Shards"]       = "Vendor & Rep",
}

-- Reverse map: zone name -> list of source strings that drop items there
BiSGearCheck.ZoneToSources = {}
for src, zone in pairs(BiSGearCheck.SourceToZone) do
    if not BiSGearCheck.ZoneToSources[zone] then
        BiSGearCheck.ZoneToSources[zone] = {}
    end
    BiSGearCheck.ZoneToSources[zone][src] = true
end

-- Categorized zone lists for the dropdown
-- Zone phase mapping: zones available at or before this phase
BiSGearCheck.ZonePhase = {
    ["Karazhan"] = 1, ["Gruul's Lair"] = 1, ["Magtheridon's Lair"] = 1,
    ["Serpentshrine Cavern"] = 2, ["Tempest Keep"] = 2,
    ["Hyjal Summit"] = 3, ["Black Temple"] = 3,
    ["Zul'Aman"] = 4, ["Magisters' Terrace"] = 4,
    ["Sunwell Plateau"] = 5,
    -- Dungeons are all Phase 1 except Magisters' Terrace
    -- Classic, Other categories are always available (phase 1)
}

BiSGearCheck.ZoneCategoriesAll = {
    {
        label = "TBC Raids",
        zones = {
            "Karazhan", "Gruul's Lair", "Magtheridon's Lair",
            "Serpentshrine Cavern", "Tempest Keep",
            "Hyjal Summit", "Black Temple",
            "Zul'Aman", "Sunwell Plateau",
        },
    },
    {
        label = "TBC Dungeons",
        zones = {
            "Hellfire Ramparts", "The Blood Furnace", "The Shattered Halls",
            "The Slave Pens", "The Underbog", "The Steamvault",
            "Mana-Tombs", "Auchenai Crypts", "Sethekk Halls", "Shadow Labyrinth",
            "The Mechanar", "The Botanica", "The Arcatraz",
            "Old Hillsbrad Foothills", "The Black Morass",
            "Magisters' Terrace",
        },
    },
    {
        label = "Classic",
        zones = {
            "Molten Core", "Blackwing Lair", "Ahn'Qiraj", "Naxxramas",
            "Blackrock Depths", "Stratholme",
        },
    },
    {
        label = "Other",
        zones = { "Crafted", "Quest", "PvP", "Vendor & Rep" },
    },
}

-- Returns ZoneCategories filtered to the current phase and settings
function BiSGearCheck:GetZoneCategories()
    local phase = self.phaseFilter or 1
    local includeClassic = BiSGearCheckSaved and BiSGearCheckSaved.includeClassicZones ~= false
    local filtered = {}
    for _, category in ipairs(self.ZoneCategoriesAll) do
        if category.label == "Classic" and not includeClassic then
            -- Skip Classic category entirely
        else
            local zones = {}
            for _, zone in ipairs(category.zones) do
                local zonePhase = self.ZonePhase[zone] or 1
                if zonePhase <= phase then
                    zones[#zones + 1] = zone
                end
            end
            if #zones > 0 then
                filtered[#filtered + 1] = { label = category.label, zones = zones }
            end
        end
    end
    return filtered
end

-- Check if an item is from a Classic zone (for filtering BiS lists)
function BiSGearCheck:IsClassicZoneItem(itemID)
    local zone = self:GetItemZone(itemID)
    if not zone then return false end
    -- Check if this zone is in the Classic category
    for _, category in ipairs(self.ZoneCategoriesAll) do
        if category.label == "Classic" then
            for _, z in ipairs(category.zones) do
                if z == zone then return true end
            end
        end
    end
    return false
end

-- Backward compat: static reference used by other code
BiSGearCheck.ZoneCategories = BiSGearCheck.ZoneCategoriesAll

-- Resolve an item's zone, accounting for PvP vendor items
function BiSGearCheck:GetItemZone(itemID)
    local sourceInfo = BiSGearCheckSources and BiSGearCheckSources[itemID]
    if not sourceInfo or not sourceInfo.source then return nil end
    -- PvP items sold by vendors should be categorized as PvP
    if sourceInfo.source == "Vendor & Rep" and sourceInfo.sourceType then
        local st = sourceInfo.sourceType
        if st:find("Honor") or st:find("Marks") or st:find("Arena") then
            return "PvP"
        end
    end
    return self.SourceToZone[sourceInfo.source]
end

-- Get unique zone names (sorted) for filter dropdown
function BiSGearCheck:GetZoneList()
    local zones = {}
    local seen = {}
    for _, zone in pairs(self.SourceToZone) do
        if not seen[zone] then
            seen[zone] = true
            table.insert(zones, zone)
        end
    end
    table.sort(zones)
    return zones
end

-- Check if a zone has any wishlist items
function BiSGearCheck:ZoneHasWishlistItems(zone)
    local wl = self:GetActiveWishlistTable()
    if not wl then return false end
    for itemID, _ in pairs(wl) do
        if self:ItemMatchesZone(itemID, zone) then
            return true
        end
    end
    return false
end

-- Check if an item's source matches a zone
function BiSGearCheck:ItemMatchesZone(itemID, zone)
    return self:GetItemZone(itemID) == zone
end

-- Return the specific filter reason if an item is hidden by source filters, or nil
function BiSGearCheck:GetSourceFilterReason(itemID)
    if not BiSGearCheckSaved then return nil end
    local sourceInfo = BiSGearCheckSources and BiSGearCheckSources[itemID]

    -- PvP filter
    if not BiSGearCheckSaved.includePvP then
        if sourceInfo then
            if sourceInfo.source == "PvP" then return "PvP" end
            if sourceInfo.sourceType then
                local st = sourceInfo.sourceType
                if st:find("Honor") or st:find("Marks") or st:find("Arena") then
                    return "PvP"
                end
            end
        end
    end

    -- World Boss filter
    if not BiSGearCheckSaved.includeWorldBoss then
        if sourceInfo and sourceInfo.source == "World Boss" then return "World Boss" end
    end

    -- BoP crafted profession filter
    if not BiSGearCheckSaved.includeBoPCraftedOther then
        if sourceInfo and sourceInfo.sourceType then
            local profession = sourceInfo.source
            local isCrafted = self.SourceToZone[profession] == "Crafted"
            if isCrafted then
                local _, _, _, _, _, _, _, _, _, _, _, _, _, bindType = GetItemInfo(itemID)
                if bindType == 1 then
                    if not self:PlayerHasProfession(profession) then
                        return "BoP Crafted"
                    end
                end
            end
        end
    end

    return nil
end

-- Check if an item should be hidden by source filters (PvP, World Boss, BoP crafted)
function BiSGearCheck:IsItemFilteredBySource(itemID)
    if not BiSGearCheckSaved then return false end
    local sourceInfo = BiSGearCheckSources and BiSGearCheckSources[itemID]

    -- PvP filter
    if not BiSGearCheckSaved.includePvP then
        if sourceInfo then
            if sourceInfo.source == "PvP" then return true end
            if sourceInfo.sourceType then
                local st = sourceInfo.sourceType
                if st:find("Honor") or st:find("Marks") or st:find("Arena") then
                    return true
                end
            end
        end
    end

    -- World Boss filter
    if not BiSGearCheckSaved.includeWorldBoss then
        if sourceInfo and sourceInfo.source == "World Boss" then return true end
    end

    -- BoP crafted profession filter
    if not BiSGearCheckSaved.includeBoPCraftedOther then
        if sourceInfo and sourceInfo.sourceType then
            local profession = sourceInfo.source
            local isCrafted = self.SourceToZone[profession] == "Crafted"
            if isCrafted then
                -- Check if item is BoP via GetItemInfo
                local _, _, _, _, _, _, _, _, _, _, _, _, _, bindType = GetItemInfo(itemID)
                -- bindType 1 = BoP
                if bindType == 1 then
                    if not self:PlayerHasProfession(profession) then
                        return true
                    end
                end
            end
        end
    end

    return false
end

-- Get the player's professions (cached per session)
function BiSGearCheck:GetPlayerProfessions()
    if self._professionCache then return self._professionCache end
    local profs = {}
    for i = 1, GetNumSkillLines() do
        local name, isHeader = GetSkillLineInfo(i)
        if not isHeader and name then
            profs[name] = true
        end
    end
    self._professionCache = profs
    return profs
end

function BiSGearCheck:PlayerHasProfession(profession)
    local profs = self:GetPlayerProfessions()
    return profs[profession] or false
end

-- The highest phase currently live on the server. Separate from
-- `phaseFilter`, which is the user's chosen view (may be lower). Used to
-- distinguish "future content" (item phase > currentGamePhase — never
-- display, never count) from "user narrowed their filter" (item phase
-- ≤ currentGamePhase but > phaseFilter — count as filtered).
--
-- Bump this when a new content phase goes live on Anniversary.
BiSGearCheck.CurrentGamePhase = 2

function BiSGearCheck:GetCurrentGamePhase()
    return self.CurrentGamePhase or 1
end

-- Check if an item belongs to a phase at or below the given max phase
-- Items with no phase data are assumed to be available (phase 1 / pre-raid)
function BiSGearCheck:ItemInPhase(itemID, maxPhase)
    if not maxPhase then return true end
    local phases = BiSGearCheckItemPhases
    if not phases then return true end
    local itemPhase = phases[itemID]
    if not itemPhase then return true end  -- unknown phase = always show
    return itemPhase <= maxPhase
end

-- Unified item filter: returns a reason string if the item should be hidden, nil if it should show.
-- Checks: zone filter, classic zones, phase, PvP, World Boss, BoP crafted.
-- Use this everywhere items are displayed to ensure consistent filtering.
function BiSGearCheck:GetItemFilterReason(itemID, zoneFilter)
    -- Zone filter
    if zoneFilter and not self:ItemMatchesZone(itemID, zoneFilter) then
        return "Zone filter"
    end
    -- Classic zones
    if BiSGearCheckSaved and BiSGearCheckSaved.includeClassicZones == false and self:IsClassicZoneItem(itemID) then
        return "Classic"
    end
    -- Phase filter
    local maxPhase = self.phaseFilter or 1
    if not self:ItemInPhase(itemID, maxPhase) then
        return "Phase"
    end
    -- Source filters (PvP, World Boss, BoP crafted)
    return self:GetSourceFilterReason(itemID)
end

-- Talent tab index → spec key for classes where ClassSpecs doesn't
-- map 1:1 with talent tabs (Druid has 4 specs for 3 tabs, Priest
-- has 2 specs for 3 tabs).
local TalentTabToSpec = {
    ["DRUID"]  = { "DruidBalance", "DruidFeralDPS", "DruidRestoration" },
    ["PRIEST"] = { "PriestHoly",   "PriestHoly",    "PriestShadow" },
}
-- Try to auto-detect spec from talent points. Returns nil when talent data
-- isn't available yet (login / addon-load race) or when every tab is empty —
-- callers should leave the saved spec alone in that case. Previously this
-- fell back to specs[1], which quietly persisted a wrong guess for anyone
-- whose talents load after the initial guess runs.
function BiSGearCheck:GuessSpec()
    local _, classToken = UnitClass("player")
    local specs = self.ClassSpecs[classToken]
    if not specs then return nil end

    local tabCount = GetNumTalentTabs() or 0
    if tabCount == 0 then return nil end

    local bestTab, bestPoints = 0, 0
    local anyData = false
    for i = 1, tabCount do
        local results = { GetTalentTabInfo(i) }
        -- Points spent could be at index 3 or 5 depending on client version
        local points = 0
        for j = 3, #results do
            local val = tonumber(results[j])
            if val and val >= 0 and val <= 71 then
                points = val
                anyData = true
                break
            end
        end
        if points > bestPoints then
            bestPoints = points
            bestTab = i
        end
    end

    -- No points spent anywhere (fresh character) or no tab data returned yet
    -- (talents not loaded). Don't guess — let the caller try again later.
    if not anyData or bestTab == 0 then return nil end

    local tabMap = TalentTabToSpec[classToken]
    if tabMap and tabMap[bestTab] then
        return tabMap[bestTab]
    end
    if bestTab <= #specs then
        return specs[bestTab].key
    end
    return nil
end

-- Guess spec for an inspected character from their talent tree.
-- Uses the full GetTalentInfo signature: (tab, index, isInspect, isPet, talentGroup)
-- Falls back to gear-based matching if talent data is unavailable.
function BiSGearCheck:GuessSpecFromGear(classToken, equipped)
    local specs = self.ClassSpecs[classToken]
    if not specs then return nil end

    -- Try talent-based detection first
    local talentSpec = self:GuessSpecFromTalents(classToken)
    if talentSpec then return talentSpec end

    -- Fallback: match equipped items against BiS lists
    if not equipped then return specs[1].key end

    local equippedIDs = {}
    local equippedEnchantIDs = {}
    for _, slotItems in pairs(equipped) do
        for _, item in ipairs(slotItems) do
            if item.id then equippedIDs[item.id] = true end
            if item.link then
                local enchantID = tonumber(item.link:match("item:%d+:(%d+)"))
                if enchantID and enchantID > 0 then
                    equippedEnchantIDs[enchantID] = true
                end
            end
        end
    end

    local bestSpec, bestScore = nil, -1
    for _, specInfo in ipairs(specs) do
        local score = 0
        -- Score from BiS item matches
        for _, src in ipairs(self.DataSources) do
            local dbName = self:GetSourceDBName(src, self.phaseFilter or 1)
            local db = dbName and _G[dbName]
            if db and db[specInfo.key] and db[specInfo.key].slots then
                for _, bisItems in pairs(db[specInfo.key].slots) do
                    for _, bisID in ipairs(bisItems) do
                        if equippedIDs[bisID] then
                            score = score + 1
                        end
                    end
                end
            end
        end
        -- Score from enchant matches (strong spec signal)
        local specEnchants = BiSGearCheckEnchantsDB and BiSGearCheckEnchantsDB[specInfo.key]
        if specEnchants then
            for _, slotEnchants in pairs(specEnchants) do
                for _, enchant in ipairs(slotEnchants) do
                    if equippedEnchantIDs[enchant[1]] then
                        score = score + 3  -- enchants are strong spec indicators
                    end
                end
            end
        end
        if score > bestScore then
            bestScore = score
            bestSpec = specInfo.key
        end
    end

    return bestSpec or specs[1].key
end

-- Talent-based spec detection for inspected characters.
-- Classic API: GetTalentInfo(tabIndex, talentIndex [, isInspect])
-- Returns nil if talent data is unavailable (caller should use gear fallback).
function BiSGearCheck:GuessSpecFromTalents(classToken)
    local specs = self.ClassSpecs[classToken]
    if not specs then return nil end

    -- Count points per talent tab
    local bestTab, bestPoints, totalPoints = 0, 0, 0
    for tab = 1, 3 do
        local points = 0
        for i = 1, 40 do
            local name, _, _, _, rank = GetTalentInfo(tab, i, true)
            if not name then break end
            points = points + (rank or 0)
        end
        totalPoints = totalPoints + points
        if points > bestPoints then
            bestPoints = points
            bestTab = tab
        end
    end

    -- If we got no talent data at all, signal caller to use gear fallback
    if totalPoints == 0 then return nil end

    -- Druid special case: Feral DPS vs Feral Tank both live in tab 2
    if classToken == "DRUID" and bestTab == 2 then
        -- Talent indices don't map to tree position, so search by name
        for i = 1, 40 do
            local name, _, _, _, rank = GetTalentInfo(2, i, true)
            if not name then break end
            if name == "Survival of the Fittest" and rank and rank >= 2 then
                return "DruidFeralTank"
            end
        end
        return "DruidFeralDPS"
    end

    -- For Druid non-Feral tabs: Tab 1 = Balance, Tab 3 = Restoration
    if classToken == "DRUID" then
        if bestTab == 1 then return "DruidBalance" end
        if bestTab == 3 then return "DruidRestoration" end
    end

    -- All other classes: specs map 1:1 to talent tabs
    if bestTab <= #specs then
        return specs[bestTab].key
    end

    return nil
end

-- Get class-colored text
function BiSGearCheck:ClassColor(classToken, text)
    local color = RAID_CLASS_COLORS[classToken]
    if color then
        return string.format("|cff%02x%02x%02x%s|r", math.floor(color.r * 255), math.floor(color.g * 255), math.floor(color.b * 255), text)
    end
    return text
end

-- Quality color for item links
local QUALITY_COLORS = {
    [0] = "9d9d9d", -- Poor
    [1] = "ffffff", -- Common
    [2] = "1eff00", -- Uncommon
    [3] = "0070dd", -- Rare
    [4] = "a335ee", -- Epic
    [5] = "ff8000", -- Legendary
}

function BiSGearCheck:QualityColor(quality)
    return QUALITY_COLORS[quality] or "ffffff"
end

-- ============================================================
-- ITEM LINK PARSING (for enchant/gem detection)
-- ============================================================

-- Map our slot names to enchant DB slot keys
BiSGearCheck.SlotToEnchantSlot = {
    ["Head"]      = "Head",
    ["Shoulders"] = "Shoulder",
    ["Back"]      = "Back",
    ["Chest"]     = "Chest",
    ["Wrist"]     = "Wrist",
    ["Hands"]     = "Hands",
    ["Legs"]      = "Legs",
    ["Feet"]      = "Feet",
    ["Main Hand"] = "Weapon",
    ["Offhand"]   = "Shield",
    ["Twohand"]   = "Weapon",
    ["Ranged"]    = "Ranged",
    ["Rings"]     = "Ring",
}

-- Aldor/Scryer shoulder enchant IDs (SpellItemEnchantment IDs)
BiSGearCheck.AldorEnchantIDs = {
    [2986] = true, [2982] = true, [2980] = true, [2978] = true,  -- Greater Inscriptions
    [2985] = true, [2981] = true, [2979] = true, [2977] = true,  -- Lesser Inscriptions
}
BiSGearCheck.ScryerEnchantIDs = {
    [2995] = true, [2997] = true, [2993] = true,  -- Greater Inscriptions
    [2994] = true, [2996] = true, [2992] = true,  -- Lesser Inscriptions
}

-- Detect player's Shattrath faction (Aldor=932, Scryer=934)
-- Returns "aldor", "scryer", or nil if unchosen
function BiSGearCheck:GetShattFaction()
    if self._shattFaction then return self._shattFaction end
    local _, _, aldorStanding = GetFactionInfoByID(932)
    local _, _, scryerStanding = GetFactionInfoByID(934)
    if aldorStanding and aldorStanding >= 5 then
        self._shattFaction = "aldor"
    elseif scryerStanding and scryerStanding >= 5 then
        self._shattFaction = "scryer"
    else
        return nil  -- don't cache nil, check again next time
    end
    return self._shattFaction
end

-- Check if an enchant ID belongs to the opposing Shattrath faction
function BiSGearCheck:IsWrongShattFaction(enchantID)
    local faction = self:GetShattFaction()
    if not faction then return false end  -- can't determine, allow all
    if faction == "aldor" then
        return self.ScryerEnchantIDs[enchantID] or false
    else
        return self.AldorEnchantIDs[enchantID] or false
    end
end

-- Lesser enchant IDs: cheaper/lower-rank versions of BiS enchants
-- Keyed by enchantID, value is the enchant slot it applies to
BiSGearCheck.LesserEnchantIDs = {
    -- Shoulder: Lesser Inscriptions (Aldor)
    [2985] = "Shoulder",  -- Lesser Inscription of Discipline
    [2981] = "Shoulder",  -- Lesser Inscription of Vengeance
    [2979] = "Shoulder",  -- Lesser Inscription of Faith
    [2977] = "Shoulder",  -- Lesser Inscription of Warding
    -- Shoulder: Lesser Inscriptions (Scryer)
    [2994] = "Shoulder",  -- Lesser Inscription of the Oracle
    [2996] = "Shoulder",  -- Lesser Inscription of the Orb
    [2992] = "Shoulder",  -- Lesser Inscription of the Knight
    -- Legs: Lesser spellthreads
    [2745] = "Legs",      -- Silver Spellthread
    [2747] = "Legs",      -- Mystic Spellthread
    -- Legs: Lesser leg armors
    [3010] = "Legs",      -- Cobrahide Leg Armor
    [3011] = "Legs",      -- Clefthide Leg Armor
}

-- Slots that can have enchants (used for warnings)
-- Excludes Neck, Waist, Trinkets (not enchantable in TBC)
BiSGearCheck.EnchantableSlots = {
    ["Head"] = true, ["Shoulders"] = true, ["Back"] = true,
    ["Chest"] = true, ["Wrist"] = true, ["Hands"] = true,
    ["Legs"] = true, ["Feet"] = true,
    ["Main Hand"] = true, ["Offhand"] = true, ["Twohand"] = true,
    ["Ranged"] = true, ["Rings"] = true,
}

-- Parse an item link string, extracting enchantID and gem itemIDs
-- Format: item:itemID:enchantID:gem1:gem2:gem3:gem4:suffixID:uniqueID
function BiSGearCheck:ParseItemLink(itemLink)
    if not itemLink then return nil end
    local fields = { itemLink:match("item:(%d+):(%d*):(%d*):(%d*):(%d*):(%d*)") }
    if not fields[1] then return nil end
    local result = {}
    for i = 1, 6 do
        result[i] = tonumber(fields[i]) or 0
    end
    return result[1], result[2], result[3], result[4], result[5], result[6]
    -- returns: itemID, enchantID, gem1, gem2, gem3, gem4
end

-- Check if an enchantID is in the spec's recommended list for a given slot
-- Filters out enchants from the opposing Shattrath faction
function BiSGearCheck:IsEnchantRecommended(specKey, slotName, enchantID)
    if not enchantID or enchantID == 0 then return false end
    local enchantSlot = self.SlotToEnchantSlot[slotName]
    if not enchantSlot then return false end
    local specEnchants = BiSGearCheckEnchantsDB and BiSGearCheckEnchantsDB[specKey]
    if not specEnchants then return false end
    local slotEnchants = specEnchants[enchantSlot]
    if not slotEnchants then return false end
    for _, enchant in ipairs(slotEnchants) do
        if enchant[1] == enchantID and not self:IsWrongShattFaction(enchantID) then
            return true
        end
    end
    return false
end

-- Get a hidden tooltip for scanning item socket info
function BiSGearCheck:GetScanTooltip()
    if not self.scanTooltip then
        local tip = CreateFrame("GameTooltip", "BiSGearCheckScanTip", nil, "GameTooltipTemplate")
        tip:SetOwner(WorldFrame, "ANCHOR_NONE")
        self.scanTooltip = tip
    end
    return self.scanTooltip
end

-- Count sockets on an equipped item by scanning its tooltip
function BiSGearCheck:CountItemSockets(itemLink)
    if not itemLink then return 0 end
    local tip = self:GetScanTooltip()
    tip:ClearLines()
    tip:SetOwner(WorldFrame, "ANCHOR_NONE")
    tip:SetHyperlink(itemLink)
    local count = 0
    for i = 1, tip:NumLines() do
        local left = _G["BiSGearCheckScanTipTextLeft" .. i]
        if left then
            local text = left:GetText()
            if text then
                if text:find("Red Socket") or text:find("Blue Socket")
                   or text:find("Yellow Socket") or text:find("Meta Socket") then
                    count = count + 1
                end
            end
        end
    end
    return count
end

-- Warning color codes (initialized with defaults, updated from theme in InitWarningColors)
local WARN_RED    = "|cffff4d4d"
local WARN_YELLOW = "|cffffcc00"

function BiSGearCheck:InitWarningColors()
    local T = self.Theme
    if T then
        WARN_RED    = T.warnHex("red")
        WARN_YELLOW = T.warnHex("yellow")
    end
end

-- Build warning list for an equipped item's enchant and gems
-- Returns: warnings (table of color-coded strings), wrongEnchantID (number or nil)
function BiSGearCheck:GetEquipWarnings(itemLink, slotName, specKey)
    if not itemLink or not specKey then return {}, nil end

    local itemID, enchantID, gem1, gem2, gem3, gem4 = self:ParseItemLink(itemLink)
    local warnings = {}
    local wrongEnchantID = nil

    -- Mount-speed items left equipped (common raid mistake)
    local MOUNT_SPEED_ITEMS = {
        [25653] = true,  -- Riding Crop
        [11122] = true,  -- Carrot on a Stick
    }
    if itemID and MOUNT_SPEED_ITEMS[itemID] then
        warnings[#warnings + 1] = WARN_RED .. "[Mount Speed Item!]|r"
    end

    -- Enchant check (only for enchantable slots that have spec recommendations)
    if self.EnchantableSlots[slotName] then
        local enchantSlot = self.SlotToEnchantSlot[slotName]
        local specEnchants = BiSGearCheckEnchantsDB and BiSGearCheckEnchantsDB[specKey]
        local hasRecommendations = specEnchants and specEnchants[enchantSlot] and #specEnchants[enchantSlot] > 0
        if hasRecommendations then
            if not enchantID or enchantID == 0 then
                warnings[#warnings + 1] = WARN_RED .. "[No Enchant]|r"
            elseif not self:IsEnchantRecommended(specKey, slotName, enchantID) then
                wrongEnchantID = enchantID
                -- Check if this is a lesser version rather than completely wrong
                local lesserSlot = self.LesserEnchantIDs[enchantID]
                if lesserSlot and lesserSlot == enchantSlot then
                    warnings[#warnings + 1] = WARN_YELLOW .. "[Lesser Enchant]|r"
                else
                    warnings[#warnings + 1] = WARN_RED .. "[Wrong Enchant]|r"
                end
            end
        end
    end

    -- Gem check: filled gems from item link, empty sockets from tooltip
    local gems = { gem1, gem2, gem3, gem4 }
    local filledCount = 0
    local wrongGemCount = 0
    local lesserGemCount = 0
    local uncachedGemCount = 0
    for i = 1, 4 do
        local gemID = gems[i]
        if gemID and gemID > 0 then
            filledCount = filledCount + 1
            local _, _, quality = GetItemInfo(gemID)
            if quality then
                if quality == 2 then
                    lesserGemCount = lesserGemCount + 1  -- Green (Uncommon)
                elseif quality < 2 then
                    wrongGemCount = wrongGemCount + 1    -- White/Grey
                end
            else
                uncachedGemCount = uncachedGemCount + 1
                if not self.pendingItems[gemID] then
                    self.pendingItems[gemID] = true
                    C_Item.RequestLoadItemDataByID(gemID)
                end
            end
        end
    end

    -- Tooltip only shows unfilled sockets ("Red Socket", etc.) — but a
    -- socket holding a gem the client hasn't cached renders the same
    -- placeholder line. The link says those sockets are filled, so don't
    -- report them as empty.
    local emptySockets = self:CountItemSockets(itemLink)
    emptySockets = math.max(0, emptySockets - uncachedGemCount)
    if filledCount + emptySockets > 0 then
        if emptySockets > 0 then
            if emptySockets == 1 then
                warnings[#warnings + 1] = WARN_RED .. "[Empty Socket]|r"
            else
                warnings[#warnings + 1] = WARN_RED .. "[" .. emptySockets .. " Empty Sockets]|r"
            end
        end
        if wrongGemCount > 0 then
            warnings[#warnings + 1] = WARN_RED .. "[Wrong Gems]|r"
        elseif lesserGemCount > 0 then
            warnings[#warnings + 1] = WARN_YELLOW .. "[Lesser Gems]|r"
        end
    end

    return warnings, wrongEnchantID
end
