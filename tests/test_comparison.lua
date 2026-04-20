-- Tests for Comparison.lua
-- Faction filtering, CompareSlot ranking, RunComparison orchestration

local T = {}

-- ============================================================
-- HELPERS
-- ============================================================

local function setupBasicState()
    BiSGearCheckSaved = {
        characters = {
            ["TestChar-TestRealm"] = {
                class = "WARRIOR",
                faction = "Alliance",
                level = 70,
                wishlists = { Default = {} },
                activeWishlist = "Default",
            }
        }
    }
    BiSGearCheckChar = {}
    BiSGearCheck.playerKey = "TestChar-TestRealm"
    BiSGearCheck.viewingCharKey = "TestChar-TestRealm"
    BiSGearCheck.playerFaction = "Alliance"
    BiSGearCheck.pendingItems = {}
    BiSGearCheck.selectedSpec = "WarriorFury"
    BiSGearCheck.phaseFilter = 1
    BiSGearCheck.dataSource = "wowtbcgg"
end

-- ============================================================
-- TESTS: IsItemAvailableForFaction
-- ============================================================

function T.test_faction_available_no_source_data()
    setupBasicState()
    BiSGearCheckSources = {}
    assert_true(BiSGearCheck:IsItemAvailableForFaction(100))
end

function T.test_faction_available_no_faction_tag()
    setupBasicState()
    BiSGearCheckSources = { [100] = { source = "Karazhan" } }
    assert_true(BiSGearCheck:IsItemAvailableForFaction(100))
end

function T.test_faction_available_matching()
    setupBasicState()
    BiSGearCheckSources = { [100] = { source = "PvP", faction = "Alliance" } }
    assert_true(BiSGearCheck:IsItemAvailableForFaction(100))
end

function T.test_faction_unavailable()
    setupBasicState()
    BiSGearCheckSources = { [100] = { source = "PvP", faction = "Horde" } }
    assert_false(BiSGearCheck:IsItemAvailableForFaction(100))
end

-- ============================================================
-- TESTS: FilterBisListByFaction
-- ============================================================

function T.test_filter_bis_list_mixed()
    setupBasicState()
    BiSGearCheckSources = {
        [101] = { source = "PvP", faction = "Alliance" },
        [102] = { source = "PvP", faction = "Horde" },
        [103] = { source = "Karazhan" }, -- neutral
    }
    local result = BiSGearCheck:FilterBisListByFaction({ 101, 102, 103 })
    assert_equal(2, #result)
    assert_equal(101, result[1])
    assert_equal(103, result[2])
end

function T.test_filter_bis_list_all_neutral()
    setupBasicState()
    BiSGearCheckSources = {}
    local result = BiSGearCheck:FilterBisListByFaction({ 101, 102, 103 })
    assert_equal(3, #result)
end

function T.test_filter_bis_list_empty()
    setupBasicState()
    local result = BiSGearCheck:FilterBisListByFaction({})
    assert_equal(0, #result)
end

-- ============================================================
-- TESTS: CompareSlot
-- ============================================================

function T.test_compare_slot_equipped_at_rank()
    setupBasicState()
    BiSGearCheckSources = {
        [201] = { source = "Karazhan", sourceType = "Boss" },
        [202] = { source = "Karazhan", sourceType = "Boss" },
        [203] = { source = "Karazhan", sourceType = "Boss" },
    }
    -- Equipped item is rank 3 in BiS list
    MockWoW.SetInventory({ [1] = { id = 203, link = "|Hitem:203:0:0:0:0:0|h[Helm]|h" } })
    -- Provide item info for upgrades
    MockWoW.SetItemInfo(201, { name = "Best Helm", quality = 4 })
    MockWoW.SetItemInfo(202, { name = "Good Helm", quality = 4 })

    local result = BiSGearCheck:CompareSlot("Head", { 201, 202, 203 })
    assert_not_nil(result)
    assert_equal("Head", result.slotName)
    assert_equal(1, #result.equipped)
    assert_equal(203, result.equipped[1].id)
    assert_equal(3, result.equipped[1].rank)
    assert_equal(3, result.bestEquippedRank)
    -- Upgrades: items ranked 1 and 2 (above equipped rank 3)
    assert_equal(2, #result.upgrades)
    assert_equal(201, result.upgrades[1].id)
    assert_equal(1, result.upgrades[1].rank)
    assert_equal(202, result.upgrades[2].id)
    assert_equal(2, result.upgrades[2].rank)
end

function T.test_compare_slot_equipped_is_bis()
    setupBasicState()
    BiSGearCheckSources = {
        [201] = { source = "Karazhan", sourceType = "Boss" },
    }
    MockWoW.SetInventory({ [1] = { id = 201, link = "|Hitem:201:0:0:0:0:0|h[Best Helm]|h" } })

    local result = BiSGearCheck:CompareSlot("Head", { 201, 202, 203 })
    assert_equal(1, result.bestEquippedRank)
    assert_equal(0, #result.upgrades, "no upgrades when equipped is BiS")
end

function T.test_compare_slot_unranked_equipped()
    setupBasicState()
    BiSGearCheckSources = {
        [201] = { source = "Karazhan", sourceType = "Boss" },
        [202] = { source = "Karazhan", sourceType = "Boss" },
    }
    -- Equipped item not on BiS list at all
    MockWoW.SetInventory({ [1] = { id = 999, link = "|Hitem:999:0:0:0:0:0|h[Bad Helm]|h" } })
    MockWoW.SetItemInfo(201, { name = "Best Helm", quality = 4 })
    MockWoW.SetItemInfo(202, { name = "Good Helm", quality = 4 })

    local result = BiSGearCheck:CompareSlot("Head", { 201, 202 })
    assert_equal(999, result.bestEquippedRank, "unranked stays at 999")
    assert_nil(result.equipped[1].rank)
    -- All BiS items should be shown as upgrades
    assert_equal(2, #result.upgrades)
end

function T.test_compare_slot_dual_slot_uses_worst_rank()
    setupBasicState()
    BiSGearCheckSources = {
        [301] = { source = "Karazhan", sourceType = "Boss" },
        [302] = { source = "Karazhan", sourceType = "Boss" },
        [303] = { source = "Karazhan", sourceType = "Boss" },
        [304] = { source = "Karazhan", sourceType = "Boss" },
        [305] = { source = "Karazhan", sourceType = "Boss" },
    }
    -- Two rings equipped: rank 2 and rank 4
    MockWoW.SetInventory({
        [11] = { id = 302, link = "|Hitem:302:0:0:0:0:0|h[Ring A]|h" },
        [12] = { id = 304, link = "|Hitem:304:0:0:0:0:0|h[Ring B]|h" },
    })
    MockWoW.SetItemInfo(301, { name = "BiS Ring", quality = 4 })
    MockWoW.SetItemInfo(303, { name = "Third Ring", quality = 4 })

    local result = BiSGearCheck:CompareSlot("Rings", { 301, 302, 303, 304, 305 })
    assert_equal(2, result.bestEquippedRank)
    assert_equal(4, result.worstEquippedRank)
    -- For dual slots, cutoff is worst rank (4), so upgrades are ranks 1 and 3
    assert_equal(2, #result.upgrades)
    assert_equal(301, result.upgrades[1].id)
    assert_equal(303, result.upgrades[2].id)
end

function T.test_compare_slot_dual_slot_neither_equipped_in_bis()
    -- Regression: when neither equipped ring/trinket is in the BiS list,
    -- we should still show all BiS items as upgrades. Previously the cutoff
    -- check compared to 999 (the single-slot sentinel), but dual-slot uses
    -- 0 as its "no match" sentinel, so cutoff was left at 0 and no upgrades
    -- were rendered.
    setupBasicState()
    BiSGearCheckSources = {
        [301] = { source = "Karazhan", sourceType = "Boss" },
        [302] = { source = "Karazhan", sourceType = "Boss" },
        [303] = { source = "Karazhan", sourceType = "Boss" },
    }
    -- Two rings equipped, neither on the BiS list
    MockWoW.SetInventory({
        [11] = { id = 900, link = "|Hitem:900:0:0:0:0:0|h[Violet Signet]|h" },
        [12] = { id = 901, link = "|Hitem:901:0:0:0:0:0|h[Keeper's Ring]|h" },
    })
    MockWoW.SetItemInfo(301, { name = "BiS Ring", quality = 4 })
    MockWoW.SetItemInfo(302, { name = "Second Ring", quality = 4 })
    MockWoW.SetItemInfo(303, { name = "Third Ring", quality = 4 })

    local result = BiSGearCheck:CompareSlot("Rings", { 301, 302, 303 })
    assert_equal(0, result.worstEquippedRank, "no equipped ring in BiS → worst stays 0")
    -- All 3 BiS items should be shown as upgrades
    assert_equal(3, #result.upgrades, "all BiS items should be shown when none equipped")
    assert_equal(301, result.upgrades[1].id)
    assert_equal(302, result.upgrades[2].id)
    assert_equal(303, result.upgrades[3].id)
end

function T.test_compare_slot_inspected_character()
    setupBasicState()
    -- Set up an inspected character
    BiSGearCheckSaved.characters["OtherPlayer-TestRealm"] = {
        class = "WARRIOR",
        faction = "Alliance",
        level = 70,
        wishlists = { Default = {} },
        activeWishlist = "Default",
        inspected = true,
        equipped = {
            Head = { { id = 203, link = "|Hitem:203:0:0:0:0:0|h[Helm]|h", invSlot = 1 } },
        },
    }
    BiSGearCheck.viewingCharKey = "OtherPlayer-TestRealm"

    BiSGearCheckSources = {
        [201] = { source = "Karazhan", sourceType = "Boss" },
        [202] = { source = "Karazhan", sourceType = "Boss" },
        [203] = { source = "Karazhan", sourceType = "Boss" },
    }
    MockWoW.SetItemInfo(201, { name = "Best Helm", quality = 4 })
    MockWoW.SetItemInfo(202, { name = "Good Helm", quality = 4 })

    local result = BiSGearCheck:CompareSlot("Head", { 201, 202, 203 })
    assert_equal(1, #result.equipped)
    assert_equal(203, result.equipped[1].id)
    assert_equal(3, result.bestEquippedRank)
    assert_equal(2, #result.upgrades)
end

-- ============================================================
-- TESTS: RunComparison
-- ============================================================

function T.test_run_comparison_no_spec()
    setupBasicState()
    BiSGearCheck.selectedSpec = nil
    BiSGearCheck:RunComparison()
    assert_equal(0, #BiSGearCheck.comparisonResults)
end

function T.test_run_comparison_no_db()
    setupBasicState()
    -- No database globals loaded
    BiSGearCheck:RunComparison()
    assert_equal(0, #BiSGearCheck.comparisonResults)
end

function T.test_run_comparison_with_data()
    setupBasicState()
    -- Set up a mock database
    _G["BiSGearCheckDB_WowTBCgg"] = {
        WarriorFury = {
            class = "WARRIOR",
            spec = "Fury",
            slots = {
                Head = { 201, 202, 203 },
            },
        },
    }
    BiSGearCheckSources = {
        [201] = { source = "Karazhan", sourceType = "Boss" },
        [202] = { source = "Karazhan", sourceType = "Boss" },
        [203] = { source = "Karazhan", sourceType = "Boss" },
    }
    MockWoW.SetInventory({ [1] = { id = 203, link = "|Hitem:203:0:0:0:0:0|h[Helm]|h" } })
    MockWoW.SetItemInfo(201, { name = "Best Helm", quality = 4 })
    MockWoW.SetItemInfo(202, { name = "Good Helm", quality = 4 })

    BiSGearCheck:RunComparison()
    assert_true(#BiSGearCheck.comparisonResults > 0)
    assert_equal("Head", BiSGearCheck.comparisonResults[1].slotName)
end

-- ============================================================
-- TESTS: MH/OH cross-slot dedup (shared 1H weapons)
-- ============================================================

function T.test_compare_slot_mh_oh_dedup_unique_1h_in_oh()
    -- User has a 1H weapon equipped in OH. When we compare MH, we must NOT
    -- list that weapon as an upgrade — the player can't equip a second copy
    -- of a unique item, and even for non-unique items they already own it.
    setupBasicState()
    BiSGearCheckSources = {
        [401] = { source = "Karazhan", sourceType = "Boss" },
        [402] = { source = "Karazhan", sourceType = "Boss" },
        [403] = { source = "Karazhan", sourceType = "Boss" },
    }
    -- MH slot empty, OH holds weapon 401 (rank #1 in both MH and OH lists)
    MockWoW.SetInventory({
        [17] = { id = 401, link = "|Hitem:401:0:0:0:0:0|h[BiS 1H]|h" },
    })
    MockWoW.SetItemInfo(402, { name = "Second 1H", quality = 4 })
    MockWoW.SetItemInfo(403, { name = "Third 1H", quality = 4 })

    local result = BiSGearCheck:CompareSlot("Main Hand", { 401, 402, 403 })
    assert_equal(0, #result.equipped, "MH slot is empty")
    -- 401 is in OH, must be excluded from MH upgrades. Expect #2 and #3.
    assert_equal(2, #result.upgrades)
    assert_equal(402, result.upgrades[1].id)
    assert_equal(403, result.upgrades[2].id)
end

function T.test_compare_slot_oh_dedup_when_mh_holds_shared_weapon()
    -- Mirror case: MH holds the shared 1H, OH slot is empty. The OH upgrades
    -- list must not show the MH weapon.
    setupBasicState()
    BiSGearCheckSources = {
        [401] = { source = "Karazhan", sourceType = "Boss" },
        [402] = { source = "Karazhan", sourceType = "Boss" },
    }
    MockWoW.SetInventory({
        [16] = { id = 401, link = "|Hitem:401:0:0:0:0:0|h[BiS 1H]|h" },
    })
    MockWoW.SetItemInfo(402, { name = "Second 1H", quality = 4 })

    local result = BiSGearCheck:CompareSlot("Offhand", { 401, 402 })
    assert_equal(0, #result.equipped, "OH slot is empty")
    assert_equal(1, #result.upgrades, "401 is already in MH, only 402 remains")
    assert_equal(402, result.upgrades[1].id)
end

function T.test_compare_slot_mh_only_items_not_affected_by_oh()
    -- Handedness: a Main Hand-only item (e.g. a 2H-preferred or MH-exclusive
    -- 1H that Loon listed under "Main Hand" not "Main Hand~Off Hand") isn't
    -- in the OH bis list. So having an unrelated OH weapon equipped must
    -- not affect the MH upgrade list.
    setupBasicState()
    BiSGearCheckSources = {
        [501] = { source = "Karazhan", sourceType = "Boss" },  -- MH-only
        [502] = { source = "Karazhan", sourceType = "Boss" },  -- MH-only
        [601] = { source = "Karazhan", sourceType = "Boss" },  -- OH-only
    }
    MockWoW.SetInventory({
        [17] = { id = 601, link = "|Hitem:601:0:0:0:0:0|h[Shield]|h" },
    })
    MockWoW.SetItemInfo(501, { name = "Best MH-only", quality = 4 })
    MockWoW.SetItemInfo(502, { name = "Second MH-only", quality = 4 })

    -- MH list contains only 501, 502 (not 601). OH item should not dedup.
    local result = BiSGearCheck:CompareSlot("Main Hand", { 501, 502 })
    assert_equal(2, #result.upgrades, "MH upgrades unaffected by OH-only item")
    assert_equal(501, result.upgrades[1].id)
end

-- ============================================================
-- TESTS: hideFilteredRanks (skip-filtered-items ranking)
-- ============================================================

function T.test_compare_slot_equipped_number_two_shows_as_bis_when_top_filtered()
    -- The canonical case from the feature request: #1 is filtered (PvP), user
    -- has #2. With hideFilteredRanks on, #2's effectiveRank should collapse
    -- to 1 so the UI renders "BiS!".
    setupBasicState()
    BiSGearCheckSaved.includePvP = false
    BiSGearCheckSaved.hideFilteredRanks = true
    BiSGearCheckSources = {
        [201] = { source = "PvP", sourceType = "Honor" },
        [202] = { source = "Karazhan", sourceType = "Boss" },
        [203] = { source = "Karazhan", sourceType = "Boss" },
    }
    MockWoW.SetInventory({ [1] = { id = 202, link = "|Hitem:202:0:0:0:0:0|h[Helm]|h" } })

    local result = BiSGearCheck:CompareSlot("Head", { 201, 202, 203 })
    assert_equal(2, result.equipped[1].rank, "raw rank is preserved")
    assert_equal(1, result.equipped[1].effectiveRank, "effective rank collapses to 1")
    assert_equal(0, #result.upgrades, "no upgrades — #1 is filtered, #2 is equipped")
end

function T.test_compare_slot_hide_filtered_off_shows_filtered_items()
    -- Same setup but hideFilteredRanks OFF — filtered items still appear in
    -- upgrades (render layer decides whether to hide them). effectiveRank
    -- must be nil so the display falls back to raw rank.
    setupBasicState()
    BiSGearCheckSaved.includePvP = false
    BiSGearCheckSaved.hideFilteredRanks = false
    BiSGearCheckSources = {
        [201] = { source = "PvP", sourceType = "Honor" },
        [202] = { source = "Karazhan", sourceType = "Boss" },
    }
    MockWoW.SetInventory({ [1] = { id = 202, link = "|Hitem:202:0:0:0:0:0|h[Helm]|h" } })
    MockWoW.SetItemInfo(201, { name = "PvP Helm", quality = 4 })

    local result = BiSGearCheck:CompareSlot("Head", { 201, 202 })
    assert_equal(1, #result.upgrades, "filtered item still surfaces for render-layer handling")
    assert_nil(result.upgrades[1].effectiveRank)
    assert_nil(result.equipped[1].effectiveRank)
end

function T.test_compare_slot_hide_filtered_dual_slot_rings()
    -- Rings example: list = {R1, R2, R3, R4}. R2 is filtered (WorldBoss),
    -- user has R1 + R3. With setting on, upgrades should be empty (R2 is
    -- filtered, R1/R3 are equipped — nothing left above worstEquipped R3).
    setupBasicState()
    BiSGearCheckSaved.includeWorldBoss = false
    BiSGearCheckSaved.hideFilteredRanks = true
    BiSGearCheckSources = {
        [301] = { source = "Karazhan", sourceType = "Boss" },
        [302] = { source = "World Boss", sourceType = "Doomwalker" },
        [303] = { source = "Karazhan", sourceType = "Boss" },
        [304] = { source = "Karazhan", sourceType = "Boss" },
    }
    MockWoW.SetInventory({
        [11] = { id = 301, link = "|Hitem:301:0:0:0:0:0|h[Ring1]|h" },
        [12] = { id = 303, link = "|Hitem:303:0:0:0:0:0|h[Ring3]|h" },
    })

    local result = BiSGearCheck:CompareSlot("Rings", { 301, 302, 303, 304 })
    assert_equal(0, #result.upgrades, "R2 is filtered so nothing above R3 exists as an upgrade")
    -- Effective ranks: R1→1, R3→2 (R2 filtered out of the count)
    assert_equal(1, result.equipped[1].effectiveRank)
    assert_equal(2, result.equipped[2].effectiveRank)
end

-- ============================================================
-- TESTS: Phase-future silent exclusion
-- ============================================================
--
-- Items whose phase exceeds the real current game phase are future content.
-- CompareSlot drops them from bisItems entirely so they don't contribute
-- to upgrade lists, rank numbers, or filtered counts. Items whose phase
-- is in the current game phase but above the user's phaseFilter are a
-- user-chosen filter and stay in bisItems to be counted/collapsed normally.

function T.test_phase_future_items_dropped_from_bisItems_entirely()
    setupBasicState()
    BiSGearCheck.CurrentGamePhase = 1  -- live on the server: phase 1
    BiSGearCheck.phaseFilter = 1
    BiSGearCheckItemPhases = {
        [201] = 2,  -- future content, should disappear silently
        [202] = 1,  -- available in current phase
        [203] = 1,  -- available in current phase (equipped)
    }
    BiSGearCheckSources = {
        [201] = { source = "Karazhan", sourceType = "Boss" },
        [202] = { source = "Karazhan", sourceType = "Boss" },
        [203] = { source = "Karazhan", sourceType = "Boss" },
    }
    MockWoW.SetInventory({ [1] = { id = 203, link = "|Hitem:203:0:0:0:0:0|h[Helm]|h" } })
    MockWoW.SetItemInfo(201, { name = "Phase2 Helm", quality = 4 })
    MockWoW.SetItemInfo(202, { name = "Current Helm", quality = 4 })

    local result = BiSGearCheck:CompareSlot("Head", { 201, 202, 203 })
    -- 201 is future content: absent from upgrades entirely
    assert_equal(1, #result.upgrades, "phase-future item silently excluded")
    assert_equal(202, result.upgrades[1].id)
    -- Equipped rank reflects the *filtered* list — 203 was position 3 of 3,
    -- becomes position 2 of 2 once 201 is gone
    assert_equal(2, result.equipped[1].rank)
end

function T.test_phase_current_but_narrowed_items_stay_in_list()
    -- User is in phase 2 on the server but narrowed phaseFilter to 1.
    -- Items whose phase == 2 (available now, but user narrowed away)
    -- should stay in bisItems so the UI can count them as "filtered".
    setupBasicState()
    BiSGearCheck.CurrentGamePhase = 2
    BiSGearCheck.phaseFilter = 1
    BiSGearCheckItemPhases = {
        [201] = 2,  -- current phase (2) but above filter (1): still in list
        [202] = 1,  -- below filter, unfiltered
    }
    BiSGearCheckSources = {
        [201] = { source = "Karazhan", sourceType = "Boss" },
        [202] = { source = "Karazhan", sourceType = "Boss" },
    }
    MockWoW.SetInventory({ [1] = { id = 202, link = "|Hitem:202:0:0:0:0:0|h[Helm]|h" } })
    MockWoW.SetItemInfo(201, { name = "Phase2 Helm", quality = 4 })

    local result = BiSGearCheck:CompareSlot("Head", { 201, 202 })
    -- 201 is in-phase for the server and still an "upgrade" the UI will
    -- count as filtered (via GetItemFilterReason → "Phase" → footer)
    assert_equal(1, #result.upgrades)
    assert_equal(201, result.upgrades[1].id)
end

function T.test_phase_future_rank_numbering_collapses()
    -- Phase-future items occupying low ranks shouldn't create holes — the
    -- remaining items should see their ranks renumber down.
    setupBasicState()
    BiSGearCheck.CurrentGamePhase = 1
    BiSGearCheck.phaseFilter = 1
    BiSGearCheckItemPhases = {
        [201] = 2, [202] = 2, [203] = 1, [204] = 1,  -- first two are future
    }
    BiSGearCheckSources = {
        [203] = { source = "Karazhan", sourceType = "Boss" },
        [204] = { source = "Karazhan", sourceType = "Boss" },
    }
    MockWoW.SetInventory({ [1] = { id = 204, link = "|Hitem:204:0:0:0:0:0|h[Helm]|h" } })
    MockWoW.SetItemInfo(203, { name = "Best Current", quality = 4 })

    local result = BiSGearCheck:CompareSlot("Head", { 201, 202, 203, 204 })
    assert_equal(1, #result.upgrades)
    assert_equal(203, result.upgrades[1].id)
    assert_equal(1, result.upgrades[1].rank, "203 is effectively rank 1 after phase-future items drop out")
    assert_equal(2, result.equipped[1].rank)
end

function T.test_compare_slot_hide_filtered_leaves_unfiltered_upgrades_visible()
    -- When some filtered items exist above equipped but an unfiltered upgrade
    -- also exists, the upgrade should still be shown with its effective rank.
    setupBasicState()
    BiSGearCheckSaved.includePvP = false
    BiSGearCheckSaved.hideFilteredRanks = true
    BiSGearCheckSources = {
        [201] = { source = "PvP", sourceType = "Arena" },       -- filtered
        [202] = { source = "Karazhan", sourceType = "Boss" },   -- real upgrade
        [203] = { source = "Karazhan", sourceType = "Boss" },   -- equipped
    }
    MockWoW.SetInventory({ [1] = { id = 203, link = "|Hitem:203:0:0:0:0:0|h[Helm]|h" } })
    MockWoW.SetItemInfo(202, { name = "Good Helm", quality = 4 })

    local result = BiSGearCheck:CompareSlot("Head", { 201, 202, 203 })
    assert_equal(1, #result.upgrades, "#2 is a genuine upgrade above equipped #3")
    assert_equal(202, result.upgrades[1].id)
    assert_equal(2, result.upgrades[1].rank, "raw rank preserved")
    assert_equal(1, result.upgrades[1].effectiveRank, "effective rank is 1 (#1 filtered)")
    assert_equal(3, result.equipped[1].rank)
    assert_equal(2, result.equipped[1].effectiveRank)
end

return T
