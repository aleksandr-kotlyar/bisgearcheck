-- Tests for WishlistCompare.lua + the Wishlist.lua hooks that propagate
-- rename/delete into the compare-source flag + active-source state.

local T = {}

local CHAR_A = "Gorother-Realm"
local CHAR_B = "Delphin-Realm"

local function setupState()
    BiSGearCheckSaved = {
        characters = {
            [CHAR_A] = { class = "DRUID", faction = "Alliance", level = 70,
                         wishlists = { Default = {}, Tree = {} },
                         activeWishlist = "Default" },
            [CHAR_B] = { class = "MAGE",  faction = "Alliance", level = 70,
                         wishlists = { Default = {} },
                         activeWishlist = "Default" },
        },
        sourceSettings = {},
    }
    BiSGearCheckChar = {}
    BiSGearCheck.playerKey = CHAR_A
    BiSGearCheck.viewingCharKey = CHAR_A
    BiSGearCheck.activeWishlist = "Default"
    BiSGearCheck.playerFaction = "Alliance"
    BiSGearCheck.pendingItems = {}
    BiSGearCheck.phaseFilter = 1
    BiSGearCheck.dataSource = "wowtbcgg"
    BiSGearCheck:EnsureSourceSettings()
end

-- ============================================================
-- TESTS: Flag storage (sourceSettings-backed)
-- ============================================================

function T.test_compare_flag_defaults_off()
    setupState()
    assert_false(BiSGearCheck:IsWishlistCompareEnabled(CHAR_A, "Tree"))
end

function T.test_enable_sets_both_addon_and_tooltip()
    -- "Enable Compare" is a single toggle that flips both flags together.
    setupState()
    BiSGearCheck:SetWishlistCompareEnabled(CHAR_A, "Tree", true)
    local key = BiSGearCheck:MakeWishlistSourceKey(CHAR_A, "Tree")
    local s = BiSGearCheckSaved.sourceSettings[key]
    assert_true(s.addon)
    assert_true(s.tooltip)
end

function T.test_disable_sets_both_off()
    setupState()
    BiSGearCheck:SetWishlistCompareEnabled(CHAR_A, "Tree", true)
    BiSGearCheck:SetWishlistCompareEnabled(CHAR_A, "Tree", false)
    local key = BiSGearCheck:MakeWishlistSourceKey(CHAR_A, "Tree")
    local s = BiSGearCheckSaved.sourceSettings[key]
    assert_false(s.addon)
    assert_false(s.tooltip)
end

function T.test_compare_enabled_if_either_flag_on()
    -- After the user independently toggles just one side in the Data
    -- Sources table, the Wishlists-tab checkbox still reads as "checked".
    setupState()
    BiSGearCheck:SetWishlistCompareEnabled(CHAR_A, "Tree", true)
    local key = BiSGearCheck:MakeWishlistSourceKey(CHAR_A, "Tree")
    BiSGearCheckSaved.sourceSettings[key].tooltip = false
    assert_true(BiSGearCheck:IsWishlistCompareEnabled(CHAR_A, "Tree"),
        "still compare-enabled when only addon is on")
    BiSGearCheckSaved.sourceSettings[key].addon = false
    assert_false(BiSGearCheck:IsWishlistCompareEnabled(CHAR_A, "Tree"),
        "off when both flags are off")
end

function T.test_flag_scoped_per_character()
    setupState()
    BiSGearCheck:SetWishlistCompareEnabled(CHAR_A, "Default", true)
    assert_false(BiSGearCheck:IsWishlistCompareEnabled(CHAR_B, "Default"))
end

function T.test_flags_live_in_sourceSettings()
    -- Published and wishlist sources share the same settings table.
    setupState()
    BiSGearCheck:SetWishlistCompareEnabled(CHAR_A, "Tree", true)
    local key = BiSGearCheck:MakeWishlistSourceKey(CHAR_A, "Tree")
    -- IsSourceEnabled should recognise the wishlist key
    assert_true(BiSGearCheck:IsSourceEnabled(key))
    assert_true(BiSGearCheck:IsTooltipSourceEnabled(key))
end

-- ============================================================
-- TESTS: Source key encoding
-- ============================================================

function T.test_source_key_round_trip()
    setupState()
    local key = BiSGearCheck:MakeWishlistSourceKey(CHAR_A, "Tree")
    assert_true(BiSGearCheck:IsWishlistSourceKey(key))
    local ck, wn = BiSGearCheck:ParseWishlistSourceKey(key)
    assert_equal(CHAR_A, ck)
    assert_equal("Tree", wn)
end

function T.test_published_source_key_not_wishlist()
    setupState()
    assert_false(BiSGearCheck:IsWishlistSourceKey("wowhead"))
    assert_nil(BiSGearCheck:ParseWishlistSourceKey("wowhead"))
end

-- ============================================================
-- TESTS: Enumeration
-- ============================================================

function T.test_enumerate_returns_only_addon_enabled_wishlists()
    setupState()
    BiSGearCheck:SetWishlistCompareEnabled(CHAR_A, "Tree", true)
    BiSGearCheck:SetWishlistCompareEnabled(CHAR_B, "Default", true)
    local lists = BiSGearCheck:GetCompareEnabledWishlists()
    assert_equal(2, #lists)
    assert_equal("Delphin: Default", lists[1].label)
    assert_equal("Gorother: Tree", lists[2].label)
end

function T.test_enumerate_tooltip_separately_from_addon()
    -- Addon off, tooltip on: Addon-enabled list excludes it; Tooltip-enabled
    -- list includes it; All-enabled list includes it.
    setupState()
    BiSGearCheck:SetWishlistCompareEnabled(CHAR_A, "Tree", true)
    local key = BiSGearCheck:MakeWishlistSourceKey(CHAR_A, "Tree")
    BiSGearCheckSaved.sourceSettings[key].addon = false

    assert_equal(0, #BiSGearCheck:GetAddonEnabledWishlists())
    assert_equal(1, #BiSGearCheck:GetTooltipEnabledWishlists())
    assert_equal(1, #BiSGearCheck:GetAllEnabledWishlists())
end

function T.test_enumerate_label_and_char_fields()
    setupState()
    BiSGearCheck:SetWishlistCompareEnabled(CHAR_A, "Tree", true)
    local desc = BiSGearCheck:GetCompareEnabledWishlists()[1]
    assert_equal(CHAR_A, desc.charKey)
    assert_equal("Gorother", desc.charName)
    assert_equal("DRUID", desc.class)
    assert_equal("Tree", desc.wishlistName)
    assert_equal(BiSGearCheck:MakeWishlistSourceKey(CHAR_A, "Tree"), desc.key)
end

-- ============================================================
-- TESTS: BuildWishlistDB
-- ============================================================

function T.test_build_db_uses_all_items_regardless_of_item_specKey()
    -- Items tagged for different specs: all contribute to the same slot list
    setupState()
    local wl = BiSGearCheckSaved.characters[CHAR_A].wishlists.Tree
    wl[30728] = { slotName = "Head", rank = 1, specKey = "DruidRestoration" }
    wl[24264] = { slotName = "Head", rank = 2, specKey = "DruidBalance" }
    wl[21875] = { slotName = "Chest", rank = 1, specKey = "DruidRestoration" }

    -- Majority specKey is DruidRestoration (2 items vs 1), so the wishlist
    -- is exposed only under DruidRestoration.
    local db = BiSGearCheck:BuildWishlistDB(CHAR_A, "Tree")
    assert_not_nil(db.DruidRestoration)
    assert_nil(db.DruidBalance, "non-majority spec does not get exposed")
    assert_equal(2, #db.DruidRestoration.slots.Head)
    assert_equal(30728, db.DruidRestoration.slots.Head[1])
    assert_equal(24264, db.DruidRestoration.slots.Head[2])
    assert_equal(21875, db.DruidRestoration.slots.Chest[1])
end

function T.test_build_db_uses_explicit_spec_override_over_inference()
    setupState()
    local wl = BiSGearCheckSaved.characters[CHAR_A].wishlists.Tree
    wl[30728] = { slotName = "Head", rank = 1, specKey = "DruidRestoration" }
    wl[24264] = { slotName = "Head", rank = 2, specKey = "DruidRestoration" }
    -- Inference would yield DruidRestoration, but the user chose Balance
    BiSGearCheck:SetWishlistSpecOverride(CHAR_A, "Tree", "DruidBalance")

    local db = BiSGearCheck:BuildWishlistDB(CHAR_A, "Tree")
    assert_not_nil(db.DruidBalance, "override wins over inference")
    assert_nil(db.DruidRestoration, "inferred spec dropped once override is set")
    assert_equal(2, #db.DruidBalance.slots.Head)
end

function T.test_build_db_does_not_include_other_class_specs()
    setupState()
    BiSGearCheckSaved.characters[CHAR_A].wishlists.Tree[30728] =
        { slotName = "Head", rank = 1, specKey = "DruidRestoration" }
    local db = BiSGearCheck:BuildWishlistDB(CHAR_A, "Tree")
    assert_nil(db.MageArcane)
    assert_nil(db.WarriorFury)
end

function T.test_build_db_returns_nil_for_missing_wishlist()
    setupState()
    assert_nil(BiSGearCheck:BuildWishlistDB(CHAR_A, "Nonexistent"))
end

function T.test_build_db_empty_wishlist_falls_back_to_all_class_specs()
    -- No items → no inferable spec → fall back so the user can still pick
    -- a spec from the dropdown.
    setupState()
    local db = BiSGearCheck:BuildWishlistDB(CHAR_A, "Default")
    assert_not_nil(db)
    assert_not_nil(db.DruidRestoration)
    assert_not_nil(db.DruidBalance)
    assert_not_nil(db.DruidFeralDPS)
    assert_nil(db.MageArcane, "still scoped to character's class only")
end

function T.test_empty_wishlist_with_override_uses_override()
    setupState()
    BiSGearCheck:SetWishlistSpecOverride(CHAR_A, "Default", "DruidBalance")
    local db = BiSGearCheck:BuildWishlistDB(CHAR_A, "Default")
    assert_not_nil(db.DruidBalance)
    assert_nil(db.DruidRestoration)
end

-- ============================================================
-- TESTS: Spec override helpers
-- ============================================================

function T.test_spec_override_default_nil()
    setupState()
    assert_nil(BiSGearCheck:GetWishlistSpecOverride(CHAR_A, "Tree"))
end

function T.test_set_spec_override_persists()
    setupState()
    BiSGearCheck:SetWishlistSpecOverride(CHAR_A, "Tree", "DruidBalance")
    assert_equal("DruidBalance", BiSGearCheck:GetWishlistSpecOverride(CHAR_A, "Tree"))
end

function T.test_set_spec_override_nil_clears()
    setupState()
    BiSGearCheck:SetWishlistSpecOverride(CHAR_A, "Tree", "DruidBalance")
    BiSGearCheck:SetWishlistSpecOverride(CHAR_A, "Tree", nil)
    assert_nil(BiSGearCheck:GetWishlistSpecOverride(CHAR_A, "Tree"))
end

function T.test_effective_spec_prefers_override()
    setupState()
    BiSGearCheckSaved.characters[CHAR_A].wishlists.Tree[30728] =
        { slotName = "Head", rank = 1, specKey = "DruidRestoration" }
    BiSGearCheck:SetWishlistSpecOverride(CHAR_A, "Tree", "DruidBalance")
    assert_equal("DruidBalance", BiSGearCheck:GetEffectiveWishlistSpec(CHAR_A, "Tree"))
end

function T.test_effective_spec_falls_back_to_inference()
    setupState()
    local wl = BiSGearCheckSaved.characters[CHAR_A].wishlists.Tree
    wl[30728] = { slotName = "Head", rank = 1, specKey = "DruidRestoration" }
    wl[24264] = { slotName = "Head", rank = 2, specKey = "DruidRestoration" }
    wl[21875] = { slotName = "Chest", rank = 1, specKey = "DruidBalance" }
    assert_equal("DruidRestoration",
        BiSGearCheck:GetEffectiveWishlistSpec(CHAR_A, "Tree"))
end

function T.test_effective_spec_nil_when_no_items_and_no_override()
    setupState()
    assert_nil(BiSGearCheck:GetEffectiveWishlistSpec(CHAR_A, "Default"))
end

function T.test_override_persists_through_compare_toggle()
    -- Turning Enable Compare off then on must not clobber the stored spec.
    setupState()
    BiSGearCheck:SetWishlistCompareEnabled(CHAR_A, "Tree", true)
    BiSGearCheck:SetWishlistSpecOverride(CHAR_A, "Tree", "DruidBalance")
    BiSGearCheck:SetWishlistCompareEnabled(CHAR_A, "Tree", false)
    BiSGearCheck:SetWishlistCompareEnabled(CHAR_A, "Tree", true)
    assert_equal("DruidBalance",
        BiSGearCheck:GetWishlistSpecOverride(CHAR_A, "Tree"))
end

-- ============================================================
-- TESTS: GetActiveDB integration
-- ============================================================

function T.test_get_active_db_resolves_wishlist_source()
    setupState()
    BiSGearCheckSaved.characters[CHAR_A].wishlists.Tree[30728] =
        { slotName = "Head", rank = 1 }
    BiSGearCheck.dataSource = BiSGearCheck:MakeWishlistSourceKey(CHAR_A, "Tree")
    local db = BiSGearCheck:GetActiveDB()
    assert_not_nil(db)
    assert_equal(30728, db.DruidRestoration.slots.Head[1])
end

-- ============================================================
-- TESTS: OnSourceSettingsChanged falls back when wishlist source goes away
-- ============================================================

function T.test_source_fallback_when_wishlist_disabled()
    setupState()
    BiSGearCheck:SetWishlistCompareEnabled(CHAR_A, "Tree", true)
    BiSGearCheck.dataSource = BiSGearCheck:MakeWishlistSourceKey(CHAR_A, "Tree")

    BiSGearCheck:SetWishlistCompareEnabled(CHAR_A, "Tree", false)
    BiSGearCheck:OnSourceSettingsChanged()

    assert_false(BiSGearCheck:IsWishlistSourceKey(BiSGearCheck.dataSource),
        "active source should fall back to a published source")
end

function T.test_source_fallback_when_wishlist_deleted()
    setupState()
    BiSGearCheck:SetWishlistCompareEnabled(CHAR_A, "Tree", true)
    BiSGearCheck.dataSource = BiSGearCheck:MakeWishlistSourceKey(CHAR_A, "Tree")
    BiSGearCheck.activeWishlist = "Tree"
    BiSGearCheck:EnsureSourceSettings()

    BiSGearCheck:DeleteWishlist()
    assert_false(BiSGearCheck:IsWishlistSourceKey(BiSGearCheck.dataSource),
        "active source should fall back after the wishlist is deleted")
end

-- ============================================================
-- TESTS: Rename propagation
-- ============================================================

function T.test_rename_carries_compare_flag_and_source_key()
    setupState()
    BiSGearCheck:SetWishlistCompareEnabled(CHAR_A, "Tree", true)
    BiSGearCheck.dataSource = BiSGearCheck:MakeWishlistSourceKey(CHAR_A, "Tree")
    BiSGearCheck.activeWishlist = "Tree"
    BiSGearCheck:EnsureSourceSettings()

    assert_true(BiSGearCheck:RenameWishlist("TreeV2"))
    assert_true(BiSGearCheck:IsWishlistCompareEnabled(CHAR_A, "TreeV2"))
    assert_false(BiSGearCheck:IsWishlistCompareEnabled(CHAR_A, "Tree"))
    assert_equal(BiSGearCheck:MakeWishlistSourceKey(CHAR_A, "TreeV2"),
        BiSGearCheck.dataSource, "active source key should re-point to the new name")
end

function T.test_delete_clears_compare_flag()
    setupState()
    BiSGearCheck:SetWishlistCompareEnabled(CHAR_A, "Tree", true)
    BiSGearCheck.activeWishlist = "Tree"
    BiSGearCheck:EnsureSourceSettings()

    assert_true(BiSGearCheck:DeleteWishlist())
    assert_false(BiSGearCheck:IsWishlistCompareEnabled(CHAR_A, "Tree"))
end

return T
