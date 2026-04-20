-- Tests for Util.lua
-- Source settings, item filtering, zone mappings, item link parsing, color helpers

local T = {}

-- ============================================================
-- TESTS: GetSourceDBName / SourceHasPhase
-- ============================================================

function T.test_get_source_db_name()
    local src = BiSGearCheck.DataSources[1] -- wowtbcgg
    local name = BiSGearCheck:GetSourceDBName(src, 1)
    assert_equal("BiSGearCheckDB_WowTBCgg", name)
end

function T.test_get_source_db_name_missing_phase()
    local src = BiSGearCheck.DataSources[1]
    local name = BiSGearCheck:GetSourceDBName(src, 99)
    assert_nil(name)
end

function T.test_source_has_phase_true()
    local src = BiSGearCheck.DataSources[1]
    assert_true(BiSGearCheck:SourceHasPhase(src, 1))
end

function T.test_source_has_phase_false()
    local src = BiSGearCheck.DataSources[1]
    assert_false(BiSGearCheck:SourceHasPhase(src, 5))
end

-- ============================================================
-- TESTS: EnsureSourceSettings
-- ============================================================

function T.test_ensure_source_settings_creates_defaults()
    BiSGearCheckSaved = nil
    BiSGearCheck:EnsureSourceSettings()
    assert_not_nil(BiSGearCheckSaved.sourceSettings)
    for _, src in ipairs(BiSGearCheck.DataSources) do
        local s = BiSGearCheckSaved.sourceSettings[src.key]
        assert_not_nil(s, "missing settings for " .. src.key)
        assert_equal(true, s.addon)
        assert_equal(true, s.tooltip)
    end
end

function T.test_ensure_source_settings_migrates_old_format()
    BiSGearCheckSaved = {
        characters = {},
        enabledSources = { wowtbcgg = true, bistooltip = false },
        tooltipSources = { wowtbcgg = false },
    }
    BiSGearCheck:EnsureSourceSettings()
    local s = BiSGearCheckSaved.sourceSettings
    assert_equal(true, s.wowtbcgg.addon)
    assert_equal(false, s.wowtbcgg.tooltip)
    assert_equal(false, s.bistooltip.addon)
end

function T.test_ensure_source_settings_idempotent()
    BiSGearCheckSaved = { characters = {} }
    BiSGearCheck:EnsureSourceSettings()
    BiSGearCheckSaved.sourceSettings.wowtbcgg.addon = false
    BiSGearCheck:EnsureSourceSettings()
    assert_equal(false, BiSGearCheckSaved.sourceSettings.wowtbcgg.addon,
        "should not overwrite existing settings")
end

-- ============================================================
-- TESTS: GetSourceSetting / IsSourceEnabled
-- ============================================================

function T.test_get_source_setting_default_true()
    BiSGearCheckSaved = { characters = {} }
    local val = BiSGearCheck:GetSourceSetting("wowtbcgg", "addon")
    assert_true(val)
end

function T.test_get_source_setting_explicit_false()
    BiSGearCheckSaved = { characters = {} }
    BiSGearCheck:EnsureSourceSettings()
    BiSGearCheckSaved.sourceSettings.wowtbcgg.addon = false
    assert_false(BiSGearCheck:GetSourceSetting("wowtbcgg", "addon"))
end

function T.test_get_enabled_data_sources()
    BiSGearCheckSaved = { characters = {} }
    BiSGearCheck:EnsureSourceSettings()
    BiSGearCheckSaved.sourceSettings.wowtbcgg.addon = false
    BiSGearCheckSaved.sourceSettings.bistooltip.addon = false
    local enabled = BiSGearCheck:GetEnabledDataSources()
    for _, src in ipairs(enabled) do
        assert_true(src.key ~= "wowtbcgg" and src.key ~= "bistooltip",
            "disabled sources should not appear")
    end
    assert_equal(4, #enabled, "should have 4 enabled sources")
end

function T.test_get_enabled_data_sources_for_phase()
    BiSGearCheckSaved = { characters = {} }
    BiSGearCheck.phaseFilter = 1
    BiSGearCheck:EnsureSourceSettings()
    local enabled = BiSGearCheck:GetEnabledDataSourcesForPhase()
    assert_true(#enabled > 0, "should have sources for phase 1")
end

-- ============================================================
-- TESTS: ItemInPhase
-- ============================================================

function T.test_item_in_phase_nil_max()
    assert_true(BiSGearCheck:ItemInPhase(12345, nil))
end

function T.test_item_in_phase_no_data()
    BiSGearCheckItemPhases = nil
    assert_true(BiSGearCheck:ItemInPhase(12345, 1))
end

function T.test_item_in_phase_unknown_item()
    BiSGearCheckItemPhases = {}
    assert_true(BiSGearCheck:ItemInPhase(99999, 1), "unknown item = always show")
end

function T.test_item_in_phase_pass()
    BiSGearCheckItemPhases = { [28000] = 1 }
    assert_true(BiSGearCheck:ItemInPhase(28000, 1))
    assert_true(BiSGearCheck:ItemInPhase(28000, 3))
end

function T.test_item_in_phase_fail()
    BiSGearCheckItemPhases = { [28000] = 3 }
    assert_false(BiSGearCheck:ItemInPhase(28000, 2))
end

-- ============================================================
-- TESTS: GetItemZone
-- ============================================================

function T.test_get_item_zone_dungeon()
    BiSGearCheckSources = {
        [28000] = { source = "Karazhan", sourceType = "Boss Drop" },
    }
    assert_equal("Karazhan", BiSGearCheck:GetItemZone(28000))
end

function T.test_get_item_zone_crafted()
    BiSGearCheckSources = {
        [28000] = { source = "Tailoring", sourceType = "Crafted" },
    }
    assert_equal("Crafted", BiSGearCheck:GetItemZone(28000))
end

function T.test_get_item_zone_pvp_vendor_with_honor()
    BiSGearCheckSources = {
        [28000] = { source = "Vendor & Rep", sourceType = "15,300 Honor + 20 AB Marks" },
    }
    assert_equal("PvP", BiSGearCheck:GetItemZone(28000))
end

function T.test_get_item_zone_pvp_vendor_with_arena()
    BiSGearCheckSources = {
        [28000] = { source = "Vendor & Rep", sourceType = "1850 Arena Rating" },
    }
    assert_equal("PvP", BiSGearCheck:GetItemZone(28000))
end

function T.test_get_item_zone_regular_vendor()
    BiSGearCheckSources = {
        [28000] = { source = "Vendor & Rep", sourceType = "Exalted Cenarion" },
    }
    assert_equal("Vendor & Rep", BiSGearCheck:GetItemZone(28000))
end

function T.test_get_item_zone_no_source()
    BiSGearCheckSources = {}
    assert_nil(BiSGearCheck:GetItemZone(99999))
end

-- ============================================================
-- TESTS: IsClassicZoneItem
-- ============================================================

function T.test_is_classic_zone_item_true()
    BiSGearCheckSources = {
        [28000] = { source = "Molten Core", sourceType = "Boss Drop" },
    }
    assert_true(BiSGearCheck:IsClassicZoneItem(28000))
end

function T.test_is_classic_zone_item_false()
    BiSGearCheckSources = {
        [28000] = { source = "Karazhan", sourceType = "Boss Drop" },
    }
    assert_false(BiSGearCheck:IsClassicZoneItem(28000))
end

function T.test_is_classic_zone_item_no_source()
    BiSGearCheckSources = {}
    assert_false(BiSGearCheck:IsClassicZoneItem(99999))
end

-- ============================================================
-- TESTS: GetSourceFilterReason
-- ============================================================

function T.test_source_filter_pvp_source()
    BiSGearCheckSaved = { characters = {}, includePvP = false }
    BiSGearCheckSources = { [100] = { source = "PvP", sourceType = "" } }
    assert_equal("PvP", BiSGearCheck:GetSourceFilterReason(100))
end

function T.test_source_filter_pvp_vendor_honor()
    BiSGearCheckSaved = { characters = {}, includePvP = false }
    BiSGearCheckSources = { [100] = { source = "Vendor & Rep", sourceType = "15300 Honor" } }
    assert_equal("PvP", BiSGearCheck:GetSourceFilterReason(100))
end

function T.test_source_filter_pvp_vendor_marks()
    BiSGearCheckSaved = { characters = {}, includePvP = false }
    BiSGearCheckSources = { [100] = { source = "Vendor & Rep", sourceType = "20 AB Marks" } }
    assert_equal("PvP", BiSGearCheck:GetSourceFilterReason(100))
end

function T.test_source_filter_pvp_included()
    BiSGearCheckSaved = { characters = {}, includePvP = true }
    BiSGearCheckSources = { [100] = { source = "PvP", sourceType = "" } }
    assert_nil(BiSGearCheck:GetSourceFilterReason(100))
end

function T.test_source_filter_world_boss()
    BiSGearCheckSaved = { characters = {}, includeWorldBoss = false }
    BiSGearCheckSources = { [100] = { source = "World Boss", sourceType = "" } }
    assert_equal("World Boss", BiSGearCheck:GetSourceFilterReason(100))
end

function T.test_source_filter_world_boss_included()
    BiSGearCheckSaved = { characters = {}, includeWorldBoss = true }
    BiSGearCheckSources = { [100] = { source = "World Boss", sourceType = "" } }
    assert_nil(BiSGearCheck:GetSourceFilterReason(100))
end

function T.test_source_filter_bop_crafted()
    BiSGearCheckSaved = { characters = {}, includeBoPCraftedOther = false }
    BiSGearCheckSources = { [100] = { source = "Tailoring", sourceType = "Crafted" } }
    -- bindType 1 = BoP
    MockWoW.SetItemInfo(100, { name = "Robe", bindType = 1 })
    -- Player does NOT have Tailoring
    MockWoW._skillLines = { { name = "Blacksmithing", isHeader = false } }
    BiSGearCheck._professionCache = nil
    assert_equal("BoP Crafted", BiSGearCheck:GetSourceFilterReason(100))
end

function T.test_source_filter_bop_crafted_has_profession()
    BiSGearCheckSaved = { characters = {}, includeBoPCraftedOther = false }
    BiSGearCheckSources = { [100] = { source = "Tailoring", sourceType = "Crafted" } }
    MockWoW.SetItemInfo(100, { name = "Robe", bindType = 1 })
    -- Player HAS Tailoring
    MockWoW._skillLines = { { name = "Tailoring", isHeader = false } }
    BiSGearCheck._professionCache = nil
    assert_nil(BiSGearCheck:GetSourceFilterReason(100))
end

function T.test_source_filter_boe_crafted_passes()
    BiSGearCheckSaved = { characters = {}, includeBoPCraftedOther = false }
    BiSGearCheckSources = { [100] = { source = "Tailoring", sourceType = "Crafted" } }
    -- bindType 2 = BoE
    MockWoW.SetItemInfo(100, { name = "Robe", bindType = 2 })
    assert_nil(BiSGearCheck:GetSourceFilterReason(100))
end

-- ============================================================
-- TESTS: GetItemFilterReason (unified)
-- ============================================================

function T.test_item_filter_zone_mismatch()
    BiSGearCheckSaved = { characters = {} }
    BiSGearCheckSources = { [100] = { source = "Karazhan", sourceType = "" } }
    assert_equal("Zone filter", BiSGearCheck:GetItemFilterReason(100, "Black Temple"))
end

function T.test_item_filter_zone_match()
    BiSGearCheckSaved = { characters = {} }
    BiSGearCheckSources = { [100] = { source = "Karazhan", sourceType = "" } }
    assert_nil(BiSGearCheck:GetItemFilterReason(100, "Karazhan"))
end

function T.test_item_filter_classic_zone()
    BiSGearCheckSaved = { characters = {}, includeClassicZones = false }
    BiSGearCheckSources = { [100] = { source = "Molten Core", sourceType = "" } }
    assert_equal("Classic", BiSGearCheck:GetItemFilterReason(100))
end

function T.test_item_filter_phase()
    BiSGearCheckSaved = { characters = {} }
    BiSGearCheckItemPhases = { [100] = 3 }
    BiSGearCheck.phaseFilter = 1
    BiSGearCheckSources = {}
    assert_equal("Phase", BiSGearCheck:GetItemFilterReason(100))
end

function T.test_item_filter_no_reason()
    BiSGearCheckSaved = { characters = {} }
    BiSGearCheckItemPhases = { [100] = 1 }
    BiSGearCheckSources = { [100] = { source = "Karazhan", sourceType = "" } }
    BiSGearCheck.phaseFilter = 1
    assert_nil(BiSGearCheck:GetItemFilterReason(100))
end

-- ============================================================
-- TESTS: ParseItemLink
-- ============================================================

function T.test_parse_item_link_full()
    local itemID, enchantID, gem1, gem2, gem3, gem4 =
        BiSGearCheck:ParseItemLink("|cff0070dd|Hitem:28000:2928:24028:24058:0:0|h[Robe]|h|r")
    assert_equal(28000, itemID)
    assert_equal(2928, enchantID)
    assert_equal(24028, gem1)
    assert_equal(24058, gem2)
    assert_equal(0, gem3)
    assert_equal(0, gem4)
end

function T.test_parse_item_link_no_enchant()
    local itemID, enchantID = BiSGearCheck:ParseItemLink("|Hitem:12345:0:0:0:0:0|h[Test]|h")
    assert_equal(12345, itemID)
    assert_equal(0, enchantID)
end

function T.test_parse_item_link_nil()
    assert_nil(BiSGearCheck:ParseItemLink(nil))
end

function T.test_parse_item_link_bad_format()
    assert_nil(BiSGearCheck:ParseItemLink("not an item link"))
end

-- ============================================================
-- TESTS: QualityColor / ClassColor
-- ============================================================

function T.test_quality_color()
    assert_equal("a335ee", BiSGearCheck:QualityColor(4)) -- Epic
    assert_equal("0070dd", BiSGearCheck:QualityColor(3)) -- Rare
    assert_equal("ffffff", BiSGearCheck:QualityColor(99)) -- Unknown -> default
end

function T.test_class_color()
    local colored = BiSGearCheck:ClassColor("WARRIOR", "Arms")
    assert_true(colored:find("Arms"), "should contain text")
    assert_true(colored:find("|cff"), "should have color code")
    assert_true(colored:find("|r"), "should have reset code")
end

function T.test_class_color_unknown()
    local text = BiSGearCheck:ClassColor("DEATHKNIGHT", "Frost")
    assert_equal("Frost", text, "unknown class returns plain text")
end

-- ============================================================
-- TESTS: GetZoneList
-- ============================================================

function T.test_get_zone_list_sorted()
    local zones = BiSGearCheck:GetZoneList()
    assert_true(#zones > 0)
    for i = 2, #zones do
        assert_true(zones[i - 1] <= zones[i], "zone list should be sorted")
    end
end

function T.test_get_zone_list_unique()
    local zones = BiSGearCheck:GetZoneList()
    local seen = {}
    for _, z in ipairs(zones) do
        assert_false(seen[z], "duplicate zone: " .. z)
        seen[z] = true
    end
end

-- ============================================================
-- TESTS: GetZoneCategories
-- ============================================================

function T.test_get_zone_categories_includes_phase_1()
    BiSGearCheckSaved = { characters = {} }
    BiSGearCheck.phaseFilter = 1
    local cats = BiSGearCheck:GetZoneCategories()
    assert_true(#cats > 0)
end

function T.test_get_zone_categories_excludes_classic()
    BiSGearCheckSaved = { characters = {}, includeClassicZones = false }
    BiSGearCheck.phaseFilter = 1
    local cats = BiSGearCheck:GetZoneCategories()
    for _, cat in ipairs(cats) do
        assert_true(cat.label ~= "Classic", "Classic category should be excluded")
    end
end

function T.test_get_zone_categories_includes_classic()
    BiSGearCheckSaved = { characters = {}, includeClassicZones = true }
    BiSGearCheck.phaseFilter = 1
    local cats = BiSGearCheck:GetZoneCategories()
    local found = false
    for _, cat in ipairs(cats) do
        if cat.label == "Classic" then found = true end
    end
    assert_true(found, "Classic category should be included")
end

-- ============================================================
-- TESTS: IsEnchantRecommended
-- ============================================================

function T.test_is_enchant_recommended_found()
    BiSGearCheckEnchantsDB = {
        WarriorFury = {
            Chest = { { 2661 }, { 1144 } },
        }
    }
    -- Not aldor/scryer enchant, so faction check won't filter it
    BiSGearCheck._shattFaction = nil
    assert_true(BiSGearCheck:IsEnchantRecommended("WarriorFury", "Chest", 2661))
end

function T.test_is_enchant_recommended_not_found()
    BiSGearCheckEnchantsDB = {
        WarriorFury = {
            Chest = { { 2661 } },
        }
    }
    assert_false(BiSGearCheck:IsEnchantRecommended("WarriorFury", "Chest", 9999))
end

function T.test_is_enchant_recommended_zero_id()
    assert_false(BiSGearCheck:IsEnchantRecommended("WarriorFury", "Chest", 0))
end

function T.test_is_enchant_recommended_no_slot_mapping()
    -- "Neck" has no enchant slot mapping
    assert_false(BiSGearCheck:IsEnchantRecommended("WarriorFury", "Neck", 2661))
end

-- ============================================================
-- TESTS: ItemMatchesZone
-- ============================================================

function T.test_item_matches_zone_true()
    BiSGearCheckSources = { [100] = { source = "Karazhan", sourceType = "" } }
    assert_true(BiSGearCheck:ItemMatchesZone(100, "Karazhan"))
end

function T.test_item_matches_zone_false()
    BiSGearCheckSources = { [100] = { source = "Karazhan", sourceType = "" } }
    assert_false(BiSGearCheck:ItemMatchesZone(100, "Black Temple"))
end

-- ============================================================
-- TESTS: GuessSpec
-- ============================================================

-- Helper: set up talent tabs for a class
local function setupGuessSpec(classToken, tabs)
    MockWoW._playerClass = classToken
    MockWoW._playerClassDisplay = classToken:sub(1, 1) .. classToken:sub(2):lower()
    MockWoW._talentTabs = {}
    for _, points in ipairs(tabs) do
        MockWoW._talentTabs[#MockWoW._talentTabs + 1] = { points = points }
    end
end

-- Standard classes (1:1 talent tab → spec mapping)

function T.test_guess_spec_warrior_fury()
    setupGuessSpec("WARRIOR", { 5, 41, 15 })
    assert_equal("WarriorFury", BiSGearCheck:GuessSpec())
end

function T.test_guess_spec_warrior_arms()
    setupGuessSpec("WARRIOR", { 41, 20, 0 })
    assert_equal("WarriorArms", BiSGearCheck:GuessSpec())
end

function T.test_guess_spec_warrior_protection()
    setupGuessSpec("WARRIOR", { 5, 5, 41 })
    assert_equal("WarriorProtection", BiSGearCheck:GuessSpec())
end

function T.test_guess_spec_mage_arcane()
    setupGuessSpec("MAGE", { 40, 21, 0 })
    assert_equal("MageArcane", BiSGearCheck:GuessSpec())
end

function T.test_guess_spec_mage_fire()
    setupGuessSpec("MAGE", { 10, 41, 0 })
    assert_equal("MageFire", BiSGearCheck:GuessSpec())
end

function T.test_guess_spec_mage_frost()
    setupGuessSpec("MAGE", { 0, 0, 41 })
    assert_equal("MageFrost", BiSGearCheck:GuessSpec())
end

function T.test_guess_spec_rogue_combat()
    setupGuessSpec("ROGUE", { 15, 41, 5 })
    assert_equal("RogueCombat", BiSGearCheck:GuessSpec())
end

function T.test_guess_spec_hunter_bm()
    setupGuessSpec("HUNTER", { 41, 20, 0 })
    assert_equal("HunterBM", BiSGearCheck:GuessSpec())
end

function T.test_guess_spec_warlock_destruction()
    setupGuessSpec("WARLOCK", { 0, 10, 51 })
    assert_equal("WarlockDestruction", BiSGearCheck:GuessSpec())
end

function T.test_guess_spec_shaman_restoration()
    setupGuessSpec("SHAMAN", { 0, 5, 41 })
    assert_equal("ShamanRestoration", BiSGearCheck:GuessSpec())
end

function T.test_guess_spec_paladin_holy()
    setupGuessSpec("PALADIN", { 41, 10, 10 })
    assert_equal("PaladinHoly", BiSGearCheck:GuessSpec())
end

-- Druid: TalentTabToSpec mapping (4 specs, 3 talent tabs)
-- Tab 1 = Balance, Tab 2 = Feral DPS (not Feral Tank), Tab 3 = Restoration

function T.test_guess_spec_druid_balance()
    setupGuessSpec("DRUID", { 41, 0, 20 })
    assert_equal("DruidBalance", BiSGearCheck:GuessSpec())
end

function T.test_guess_spec_druid_feral()
    setupGuessSpec("DRUID", { 0, 41, 20 })
    -- Tab 2 maps to DruidFeralDPS via TalentTabToSpec
    assert_equal("DruidFeralDPS", BiSGearCheck:GuessSpec())
end

function T.test_guess_spec_druid_restoration()
    setupGuessSpec("DRUID", { 10, 0, 41 })
    assert_equal("DruidRestoration", BiSGearCheck:GuessSpec())
end

-- Priest: TalentTabToSpec mapping (2 specs, 3 talent tabs)
-- Tab 1 (Discipline) = PriestHoly, Tab 2 (Holy) = PriestHoly, Tab 3 (Shadow) = PriestShadow

function T.test_guess_spec_priest_shadow()
    setupGuessSpec("PRIEST", { 10, 0, 41 })
    assert_equal("PriestShadow", BiSGearCheck:GuessSpec())
end

function T.test_guess_spec_priest_holy_tab()
    setupGuessSpec("PRIEST", { 10, 41, 0 })
    -- Tab 2 (Holy) maps to PriestHoly
    assert_equal("PriestHoly", BiSGearCheck:GuessSpec())
end

function T.test_guess_spec_priest_discipline_tab()
    setupGuessSpec("PRIEST", { 41, 20, 0 })
    -- Tab 1 (Discipline) maps to PriestHoly via TalentTabToSpec
    assert_equal("PriestHoly", BiSGearCheck:GuessSpec())
end

-- Edge cases

function T.test_guess_spec_no_talents_returns_nil()
    -- All tabs present but all 0 points (fresh character or talents not
    -- yet loaded). Return nil so callers don't persist a wrong guess.
    setupGuessSpec("WARRIOR", { 0, 0, 0 })
    assert_nil(BiSGearCheck:GuessSpec())
end

function T.test_guess_spec_nil_class()
    MockWoW._playerClass = "DEATHKNIGHT"
    MockWoW._playerClassDisplay = "Death Knight"
    assert_nil(BiSGearCheck:GuessSpec())
end

function T.test_guess_spec_no_talent_tabs_returns_nil()
    -- GetNumTalentTabs() == 0 means talent data isn't available yet.
    setupGuessSpec("WARRIOR", {})
    assert_nil(BiSGearCheck:GuessSpec())
end

function T.test_guess_spec_warlock_destruction_heavy()
    -- Regression: a warlock with 0 Affliction, 1 Demo, 40 Destruction used
    -- to get guessed as Affliction (specs[1] fallback) when talents were
    -- slow to load. Now returns Destruction as long as tab data is present.
    setupGuessSpec("WARLOCK", { 0, 1, 40 })
    assert_equal("WarlockDestruction", BiSGearCheck:GuessSpec())
end

function T.test_guess_spec_tied_points_picks_first()
    setupGuessSpec("WARRIOR", { 41, 41, 0 })
    -- First tab with highest points wins (tab 1, since it's checked first)
    -- Actually the loop uses >, so equal doesn't replace — first one stays
    assert_equal("WarriorArms", BiSGearCheck:GuessSpec())
end

return T
