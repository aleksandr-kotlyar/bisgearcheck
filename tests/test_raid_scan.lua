-- Tests for RaidScan.lua and related spec detection
-- Scan queue, inspect flow, character analysis, spec guessing, CSV export

local T = {}

-- ============================================================
-- HELPERS
-- ============================================================

local function setupBaseState()
    BiSGearCheckSaved = {
        characters = {
            ["TestChar-TestRealm"] = {
                class = "WARRIOR",
                faction = "Alliance",
                level = 70,
                wishlists = { Default = {} },
                activeWishlist = "Default",
                selectedSpec = "WarriorFury",
            }
        },
        minCharLevel = 70,
        ignoredCharacters = {},
    }
    BiSGearCheckChar = { selectedSpec = "WarriorFury" }
    BiSGearCheck.playerKey = "TestChar-TestRealm"
    BiSGearCheck.viewingCharKey = "TestChar-TestRealm"
    BiSGearCheck.playerFaction = "Alliance"
    BiSGearCheck.selectedSpec = "WarriorFury"
    BiSGearCheck.activeWishlist = "Default"
    BiSGearCheck.pendingItems = {}
    BiSGearCheck.phaseFilter = 1
    BiSGearCheck.dataSource = "wowtbcgg"
    -- Stub RefreshView so it doesn't try to render UI
    BiSGearCheck.RefreshView = function() end
    BiSGearCheck.Refresh = function() end
end

-- Build a mock item link from an ID
local function mockLink(id, name)
    name = name or ("Item" .. id)
    return string.format("|Hitem:%d:0:0:0:0:0|h[%s]|h", id, name)
end

-- Build a simple inventory table for a unit
local function makeInventory(items)
    local inv = {}
    for slotID, id in pairs(items) do
        inv[slotID] = { id = id, link = mockLink(id) }
    end
    return inv
end

-- Set up a party with N members (excludes player)
local function setupParty(members)
    local group = {}
    for i, m in ipairs(members) do
        group["party" .. i] = {
            name = m.name,
            realm = m.realm or "TestRealm",
            class = m.class,
            classDisplay = m.classDisplay or m.class,
            level = m.level or 70,
            faction = m.faction or "Alliance",
            inventory = m.inventory or {},
            connected = m.connected,
            visible = m.visible,
            canInspect = m.canInspect,
        }
    end
    MockWoW.SetGroupMembers(group, false)
end

-- ============================================================
-- TESTS: Scan State Management
-- ============================================================

function T.test_initial_scan_state()
    setupBaseState()
    assert_equal("idle", BiSGearCheck.raidScanState)
    assert_false(BiSGearCheck.isRaidScanning)
    assert_equal(0, #BiSGearCheck.raidScanQueue)
end

function T.test_start_scan_sets_scanning_state()
    setupBaseState()
    setupParty({
        { name = "Alice", class = "MAGE", inventory = makeInventory({ [1] = 30000 }) },
    })
    BiSGearCheck:StartRaidScan()
    assert_equal("scanning", BiSGearCheck.raidScanState)
    assert_true(BiSGearCheck.isRaidScanning)
end

function T.test_start_scan_builds_queue()
    setupBaseState()
    setupParty({
        { name = "Alice", class = "MAGE", inventory = makeInventory({ [1] = 30000 }) },
        { name = "Bob", class = "WARRIOR", inventory = makeInventory({ [1] = 30001 }) },
    })
    BiSGearCheck:StartRaidScan()
    assert_equal(2, #BiSGearCheck.raidScanQueue)
    assert_equal("Alice", BiSGearCheck.raidScanQueue[1].name)
    assert_equal("Bob", BiSGearCheck.raidScanQueue[2].name)
end

function T.test_start_scan_clears_previous_results()
    setupBaseState()
    BiSGearCheck.raidScanResults = { ["Old-TestRealm"] = { issueCount = 5 } }
    BiSGearCheck.raidScanSkipped = { { name = "Old" } }
    setupParty({
        { name = "Alice", class = "MAGE", inventory = makeInventory({ [1] = 30000 }) },
    })
    BiSGearCheck:StartRaidScan()
    assert_nil(BiSGearCheck.raidScanResults["Old-TestRealm"])
    -- Skipped list should be fresh (only populated during new scan)
end

function T.test_cancel_scan()
    setupBaseState()
    setupParty({
        { name = "Alice", class = "MAGE", inventory = makeInventory({ [1] = 30000 }) },
    })
    BiSGearCheck:StartRaidScan()
    BiSGearCheck:CancelRaidScan()
    assert_equal("idle", BiSGearCheck.raidScanState)
    assert_false(BiSGearCheck.isRaidScanning)
end

function T.test_empty_group_finishes_immediately()
    setupBaseState()
    MockWoW.SetGroupMembers({}, false)
    BiSGearCheck:StartRaidScan()
    -- With no group members (only self), should finish since queue is empty
    assert_equal("complete", BiSGearCheck.raidScanState)
end

-- ============================================================
-- TESTS: ProcessNextScan — skip conditions
-- ============================================================

function T.test_skip_offline_member()
    setupBaseState()
    setupParty({
        { name = "Offline", class = "MAGE", connected = false,
          inventory = makeInventory({ [1] = 30000 }) },
    })
    BiSGearCheck:StartRaidScan()
    BiSGearCheck:ProcessNextScan()
    assert_equal(1, #BiSGearCheck.raidScanSkipped)
    assert_equal("Offline", BiSGearCheck.raidScanSkipped[1].reason)
end

function T.test_skip_out_of_range_member()
    setupBaseState()
    setupParty({
        { name = "FarAway", class = "MAGE", visible = false,
          inventory = makeInventory({ [1] = 30000 }) },
    })
    BiSGearCheck:StartRaidScan()
    BiSGearCheck:ProcessNextScan()
    assert_equal(1, #BiSGearCheck.raidScanSkipped)
    assert_equal("Out of range", BiSGearCheck.raidScanSkipped[1].reason)
end

-- ============================================================
-- TESTS: SnapshotInspectedGearFromUnit
-- ============================================================

function T.test_snapshot_from_unit_basic()
    setupBaseState()
    MockWoW._groupMembers["party1"] = {
        name = "Alice",
        realm = "TestRealm",
        class = "MAGE",
        classDisplay = "Mage",
        level = 70,
        faction = "Alliance",
        exists = true,
        connected = true,
        visible = true,
        canInspect = true,
        inventory = makeInventory({ [1] = 30000, [15] = 30001 }),
    }

    local charKey = BiSGearCheck:SnapshotInspectedGearFromUnit("party1")
    assert_equal("Alice-TestRealm", charKey)
    local data = BiSGearCheckSaved.characters[charKey]
    assert_not_nil(data)
    assert_equal("MAGE", data.class)
    assert_equal(true, data.inspected)
    assert_not_nil(data.equipped)
    assert_equal(30000, data.equipped.Head[1].id)
end

function T.test_snapshot_from_unit_returns_nil_for_self()
    setupBaseState()
    -- player unit should return nil
    local charKey = BiSGearCheck:SnapshotInspectedGearFromUnit("player")
    assert_nil(charKey)
end

function T.test_snapshot_from_unit_returns_nil_for_empty_gear()
    setupBaseState()
    MockWoW._groupMembers["party1"] = {
        name = "Naked",
        realm = "TestRealm",
        class = "MAGE",
        classDisplay = "Mage",
        level = 70,
        faction = "Alliance",
        exists = true,
        inventory = {},  -- no gear
    }

    local charKey = BiSGearCheck:SnapshotInspectedGearFromUnit("party1")
    assert_nil(charKey)
end

-- ============================================================
-- TESTS: OnRaidScanInspectReady
-- ============================================================

function T.test_inspect_ready_snapshots_and_advances()
    setupBaseState()
    MockWoW._groupMembers["party1"] = {
        name = "Alice",
        realm = "TestRealm",
        class = "MAGE",
        classDisplay = "Mage",
        level = 70,
        faction = "Alliance",
        exists = true,
        connected = true,
        visible = true,
        canInspect = true,
        inventory = makeInventory({ [1] = 30000 }),
    }

    BiSGearCheck:StartRaidScan()
    -- Simulate ProcessNextScan setting up the inspect
    BiSGearCheck.raidScanUnit = "party1"
    BiSGearCheck.raidScanIndex = 1

    BiSGearCheck:OnRaidScanInspectReady()
    -- Should have analyzed Alice and advanced index
    assert_not_nil(BiSGearCheck.raidScanResults["Alice-TestRealm"])
    assert_equal(2, BiSGearCheck.raidScanIndex)
    assert_nil(BiSGearCheck.raidScanUnit, "should clear raidScanUnit")
end

function T.test_inspect_ready_skips_on_no_gear()
    setupBaseState()
    MockWoW._groupMembers["party1"] = {
        name = "Naked",
        realm = "TestRealm",
        class = "MAGE",
        classDisplay = "Mage",
        level = 70,
        faction = "Alliance",
        exists = true,
        inventory = {},
    }

    BiSGearCheck:StartRaidScan()
    BiSGearCheck.raidScanUnit = "party1"
    BiSGearCheck.raidScanQueue = {{ unit = "party1", name = "Naked", realm = "TestRealm", class = "MAGE", charKey = "Naked-TestRealm" }}
    BiSGearCheck.raidScanIndex = 1

    BiSGearCheck:OnRaidScanInspectReady()
    assert_nil(BiSGearCheck.raidScanResults["Naked-TestRealm"])
    assert_equal(1, #BiSGearCheck.raidScanSkipped)
    assert_equal("No gear data", BiSGearCheck.raidScanSkipped[1].reason)
end

-- ============================================================
-- TESTS: Inspect timeout
-- ============================================================

function T.test_inspect_timeout_skips_member()
    setupBaseState()
    setupParty({
        { name = "Laggy", class = "MAGE", inventory = makeInventory({ [1] = 30000 }) },
    })

    BiSGearCheck:StartRaidScan()
    BiSGearCheck.raidScanUnit = "party1"
    BiSGearCheck.raidScanIndex = 1
    -- Simulate timeout by setting inspect time far in the past
    BiSGearCheck.raidScanInspectTime = -100

    MockWoW._gameTime = 10
    BiSGearCheck:OnRaidScanTimeout()

    assert_equal(1, #BiSGearCheck.raidScanSkipped)
    assert_equal("Inspect timed out", BiSGearCheck.raidScanSkipped[1].reason)
    assert_nil(BiSGearCheck.raidScanUnit)
end

-- ============================================================
-- TESTS: FinishRaidScan
-- ============================================================

function T.test_finish_scan_sets_complete_state()
    setupBaseState()
    BiSGearCheck.raidScanState = "scanning"
    BiSGearCheck.isRaidScanning = true
    BiSGearCheck.raidScanResults = {
        ["Alice-TestRealm"] = { issueCount = 2, upgrades = {} },
    }

    BiSGearCheck:FinishRaidScan()
    assert_equal("complete", BiSGearCheck.raidScanState)
    assert_false(BiSGearCheck.isRaidScanning)
end

function T.test_finish_scan_saves_to_saved_vars_with_pinned_spec()
    setupBaseState()
    BiSGearCheck.raidScanState = "scanning"
    BiSGearCheck.isRaidScanning = true
    BiSGearCheck.raidScanResults = {
        ["Alice-TestRealm"] = { specKey = "WarlockDestruction", issueCount = 1, upgrades = {} },
    }
    BiSGearCheck.raidScanSkipped = {
        { name = "Bob", class = "WARRIOR", reason = "Offline" },
    }

    BiSGearCheck:FinishRaidScan()
    assert_not_nil(BiSGearCheckSaved.lastRaidScan)
    assert_equal(1, #BiSGearCheckSaved.lastRaidScan.entries)
    assert_equal("Alice-TestRealm", BiSGearCheckSaved.lastRaidScan.entries[1].charKey)
    assert_equal("WarlockDestruction",
        BiSGearCheckSaved.lastRaidScan.entries[1].specKey,
        "scan entry pins the spec observed at scan time")
    assert_equal(1, #BiSGearCheckSaved.lastRaidScan.skipped)
end

function T.test_finish_scan_collapses_all_by_default()
    setupBaseState()
    BiSGearCheck.raidScanState = "scanning"
    BiSGearCheck.isRaidScanning = true
    BiSGearCheck.raidScanResults = {
        ["Alice-TestRealm"] = { issueCount = 0, upgrades = {} },
        ["Bob-TestRealm"] = { issueCount = 3, upgrades = {} },
    }

    BiSGearCheck:FinishRaidScan()
    assert_true(BiSGearCheck.raidCollapsedChars["Alice-TestRealm"])
    assert_true(BiSGearCheck.raidCollapsedChars["Bob-TestRealm"])
end

-- ============================================================
-- TESTS: GetSortedRaidScanKeys
-- ============================================================

function T.test_sorted_keys_by_issue_count_desc()
    setupBaseState()
    BiSGearCheck.raidScanResults = {
        ["Alice-TestRealm"] = { issueCount = 1 },
        ["Bob-TestRealm"] = { issueCount = 5 },
        ["Charlie-TestRealm"] = { issueCount = 0 },
    }

    local keys = BiSGearCheck:GetSortedRaidScanKeys()
    assert_equal("Bob-TestRealm", keys[1])
    assert_equal("Alice-TestRealm", keys[2])
    assert_equal("Charlie-TestRealm", keys[3])
end

function T.test_sorted_keys_alpha_when_tied()
    setupBaseState()
    BiSGearCheck.raidScanResults = {
        ["Charlie-TestRealm"] = { issueCount = 2 },
        ["Alice-TestRealm"] = { issueCount = 2 },
    }

    local keys = BiSGearCheck:GetSortedRaidScanKeys()
    assert_equal("Alice-TestRealm", keys[1])
    assert_equal("Charlie-TestRealm", keys[2])
end

-- ============================================================
-- TESTS: GetRaidScanCount
-- ============================================================

function T.test_raid_scan_count()
    setupBaseState()
    BiSGearCheck.raidScanResults = {
        ["A-R"] = { issueCount = 0 },
        ["B-R"] = { issueCount = 0 },
        ["C-R"] = { issueCount = 0 },
    }
    assert_equal(3, BiSGearCheck:GetRaidScanCount())
end

function T.test_raid_scan_count_empty()
    setupBaseState()
    BiSGearCheck.raidScanResults = {}
    assert_equal(0, BiSGearCheck:GetRaidScanCount())
end

-- ============================================================
-- TESTS: Raid Source Filters
-- ============================================================

function T.test_raid_filter_reads_shared_compare_flags()
    -- Raid scan and Compare share the same filter flags now; raidInclude*
    -- keys are obsolete.
    setupBaseState()
    BiSGearCheckSaved.includeClassicZones = true
    BiSGearCheckSaved.includePvP          = false
    BiSGearCheckSaved.includeWorldBoss    = false
    BiSGearCheckSources = { [99999] = { source = "PvP" } }
    assert_true(BiSGearCheck:IsItemFilteredByRaidSource(99999),
        "PvP excluded when compare-tab flag is off")
    BiSGearCheckSaved.includePvP = true
    assert_false(BiSGearCheck:IsItemFilteredByRaidSource(99999),
        "PvP allowed when compare-tab flag is on")
end

function T.test_raid_filter_classic_zone_by_source()
    setupBaseState()
    BiSGearCheckSaved.includeClassicZones = false
    BiSGearCheckSaved.includePvP = true
    BiSGearCheckSaved.includeWorldBoss = true
    BiSGearCheckSources = { [12345] = { source = "Dungeon", zone = "Stratholme" } }
    local orig = BiSGearCheck.IsClassicZoneItem
    BiSGearCheck.IsClassicZoneItem = function(self, id) return id == 12345 end

    assert_true(BiSGearCheck:IsItemFilteredByRaidSource(12345))

    BiSGearCheck.IsClassicZoneItem = orig
end

function T.test_raid_filter_pvp_item()
    setupBaseState()
    BiSGearCheckSaved.includeClassicZones = true
    BiSGearCheckSaved.includePvP = false
    BiSGearCheckSaved.includeWorldBoss = true
    BiSGearCheckSources = { [99999] = { source = "PvP" } }
    assert_true(BiSGearCheck:IsItemFilteredByRaidSource(99999))
end

function T.test_raid_filter_pvp_matches_honor_marks_regardless_of_source()
    -- Regression: General's Silk Cuffs has source = "Vendor" (not
    -- "Vendor & Rep") and sourceType = "Honor & WSG Marks". Raid scan
    -- used to require source == "Vendor & Rep" to recognize the PvP
    -- sourceType, leaking it through the filter.
    setupBaseState()
    BiSGearCheckSaved.includeClassicZones = true
    BiSGearCheckSaved.includePvP = false
    BiSGearCheckSaved.includeWorldBoss = true
    BiSGearCheckSources = {
        [28411] = { source = "Vendor", sourceType = "Honor & WSG Marks" },
    }
    assert_true(BiSGearCheck:IsItemFilteredByRaidSource(28411),
        "honor/marks items should filter regardless of their 'source' label")
end

function T.test_raid_filter_world_boss()
    setupBaseState()
    BiSGearCheckSaved.includeClassicZones = true
    BiSGearCheckSaved.includePvP = true
    BiSGearCheckSaved.includeWorldBoss = false
    BiSGearCheckSources = { [88888] = { source = "World Boss" } }
    assert_true(BiSGearCheck:IsItemFilteredByRaidSource(88888))
end

function T.test_raid_visible_bis_items_drops_future_content()
    -- Regression: WowTBC.gg Destro Head lists 32494 (phase 2 engineering
    -- goggles) at position 1; Voidheart Crown (28963) is raw position 2.
    -- On phase 1, 32494 should be stripped so Voidheart Crown is #1 — not
    -- tagged "#2" in the raid scan's BiS rank suffix.
    setupBaseState()
    BiSGearCheck.CurrentGamePhase = 1
    BiSGearCheckItemPhases = { [32494] = 2, [28963] = 1, [32089] = 1 }
    local visible = BiSGearCheck:RaidVisibleBisItems({ 32494, 28963, 32089 })
    assert_equal(2, #visible)
    assert_equal(28963, visible[1])
    assert_equal(32089, visible[2])
end

function T.test_raid_visible_bis_items_collapses_filtered_when_close_gaps_on()
    -- Regression: with Close Rank Gaps on, source-filtered items (PvP, etc.)
    -- should disappear from the rank numbering in the raid scan — so an
    -- equipped item at raw rank 2 whose rank-1 sibling is a filtered PvP
    -- item tags as "#1".
    setupBaseState()
    BiSGearCheck.CurrentGamePhase = 1
    BiSGearCheckSaved.includePvP = false
    BiSGearCheckSaved.hideFilteredRanks = true
    BiSGearCheckSources = {
        [1001] = { source = "PvP" },
        [1002] = { source = "Karazhan" },
        [1003] = { source = "Karazhan" },
    }
    local visible = BiSGearCheck:RaidVisibleBisItems({ 1001, 1002, 1003 })
    assert_equal(2, #visible)
    assert_equal(1002, visible[1], "PvP item drops out; rank 1 becomes the next eligible")
    assert_equal(1003, visible[2])
end

function T.test_raid_visible_bis_items_drops_wrong_faction_unconditionally()
    -- Faction-restricted items are unavailable to the player; they should
    -- never occupy a rank slot, regardless of Close Rank Gaps.
    setupBaseState()
    BiSGearCheck.CurrentGamePhase = 1
    BiSGearCheckSaved.hideFilteredRanks = false
    BiSGearCheck.playerFaction = "Alliance"
    BiSGearCheckSources = {
        [2001] = { source = "PvP", faction = "Horde" },
        [2002] = { source = "Karazhan" },
    }
    local visible = BiSGearCheck:RaidVisibleBisItems({ 2001, 2002 })
    assert_equal(1, #visible)
    assert_equal(2002, visible[1],
        "opposing-faction item drops out of the rank list regardless of setting")
end

function T.test_raid_visible_bis_items_keeps_filtered_when_close_gaps_off()
    -- With the setting off, source-filtered items stay in the list so
    -- their "slot" still consumes a rank number (raid-scan UI drops them
    -- from the upgrade list separately).
    setupBaseState()
    BiSGearCheck.CurrentGamePhase = 1
    BiSGearCheckSaved.includePvP = false
    BiSGearCheckSaved.hideFilteredRanks = false
    BiSGearCheckSources = {
        [1001] = { source = "PvP" },
        [1002] = { source = "Karazhan" },
    }
    local visible = BiSGearCheck:RaidVisibleBisItems({ 1001, 1002 })
    assert_equal(2, #visible, "filtered items stay in the list when Close Rank Gaps is off")
end

function T.test_raid_visible_bis_items_preserves_current_phase_items()
    -- Once the server is on phase 2, 32494 is real content and should be
    -- kept in the list (equipped rank tags then reflect the phase-2 world).
    setupBaseState()
    BiSGearCheck.CurrentGamePhase = 2
    BiSGearCheckItemPhases = { [32494] = 2, [28963] = 1 }
    local visible = BiSGearCheck:RaidVisibleBisItems({ 32494, 28963 })
    assert_equal(2, #visible)
    assert_equal(32494, visible[1])
end

function T.test_start_scan_preserves_selected_spec_when_guess_fails()
    -- Regression: StartRaidScan used to overwrite self.selectedSpec with
    -- GuessSpec()'s return value unconditionally. When GuessSpec returns
    -- nil (talent data not available yet), AnalyzeCharacter then fell back
    -- to specs[1] and the raid header displayed the wrong spec for the
    -- player — e.g. a Destruction warlock showed as "Affliction".
    setupBaseState()
    BiSGearCheckSaved.characters["TestChar-TestRealm"].class = "WARLOCK"
    BiSGearCheckSaved.characters["TestChar-TestRealm"].selectedSpec = "WarlockDestruction"
    MockWoW._playerClass = "WARLOCK"
    MockWoW._playerClassDisplay = "Warlock"
    BiSGearCheck.selectedSpec = "WarlockDestruction"
    -- No talent data available — GuessSpec will return nil
    MockWoW.SetInspectTalents({})
    -- Stub away the rest of scan machinery
    BiSGearCheck.GetNumGroupMembers = function() return 0 end
    MockWoW.SetGroupMembers({}, false)

    BiSGearCheck:StartRaidScan()

    assert_equal("WarlockDestruction", BiSGearCheck.selectedSpec,
        "selectedSpec must be preserved when GuessSpec returns nil")
    local result = BiSGearCheck.raidScanResults["TestChar-TestRealm"]
    assert_not_nil(result)
    assert_equal("WarlockDestruction", result.specKey,
        "raid scan result should use the preserved spec, not specs[1] fallback")
end

function T.test_raid_filter_migration_wipes_legacy_raid_keys()
    setupBaseState()
    BiSGearCheckSaved.raidIncludePvP       = true
    BiSGearCheckSaved.raidIncludeWorldBoss = false
    BiSGearCheckSaved.raidIncludeClassicZones = true
    BiSGearCheck:MigrateSavedVars()
    assert_nil(BiSGearCheckSaved.raidIncludePvP)
    assert_nil(BiSGearCheckSaved.raidIncludeWorldBoss)
    assert_nil(BiSGearCheckSaved.raidIncludeClassicZones)
end

-- ============================================================
-- TESTS: SetSpec saves to correct character
-- ============================================================

function T.test_set_spec_own_char_saves_to_player()
    setupBaseState()
    BiSGearCheck:SetSpec("WarriorArms")
    assert_equal("WarriorArms", BiSGearCheckChar.selectedSpec)
    assert_equal("WarriorArms", BiSGearCheckSaved.characters["TestChar-TestRealm"].selectedSpec)
end

function T.test_set_spec_inspected_char_does_not_corrupt_player()
    setupBaseState()
    -- Add an inspected druid
    BiSGearCheckSaved.characters["Druid-TestRealm"] = {
        class = "DRUID",
        faction = "Alliance",
        level = 70,
        wishlists = { Default = {} },
        activeWishlist = "Default",
        inspected = true,
        selectedSpec = "DruidBalance",
    }
    -- Switch to viewing the druid
    BiSGearCheck.viewingCharKey = "Druid-TestRealm"

    BiSGearCheck:SetSpec("DruidFeralTank")

    -- Druid's spec should be updated
    assert_equal("DruidFeralTank", BiSGearCheckSaved.characters["Druid-TestRealm"].selectedSpec)
    -- Player's spec should NOT be changed
    assert_equal("WarriorFury", BiSGearCheckChar.selectedSpec)
    assert_equal("WarriorFury", BiSGearCheckSaved.characters["TestChar-TestRealm"].selectedSpec)
end

-- ============================================================
-- TESTS: WhisperIssues
-- ============================================================

function T.test_whisper_sends_one_per_slot()
    setupBaseState()
    MockWoW._sentMessages = {}
    BiSGearCheck.raidScanResults = {
        ["Alice-TestRealm"] = {
            charKey = "Alice-TestRealm",
            specKey = "MageArcane",
            issueCount = 3,
            issues = {
                { slotName = "Head", itemID = 30000, itemLink = mockLink(30000, "Cool Helm"), warnings = { "|cffff3333[No Enchant]|r" } },
                { slotName = "Chest", itemID = 30001, itemLink = mockLink(30001, "Nice Robe"), warnings = { "|cffff3333[No Enchant]|r", "|cffffff00[Empty Socket]|r" } },
            },
            upgrades = {},
        },
    }

    BiSGearCheck:WhisperIssues("Alice-TestRealm")
    assert_equal(2, #MockWoW._sentMessages, "should send one whisper per slot")
end

function T.test_whisper_targets_correct_player()
    setupBaseState()
    MockWoW._sentMessages = {}
    BiSGearCheck.raidScanResults = {
        ["Alice-TestRealm"] = {
            charKey = "Alice-TestRealm",
            specKey = "MageArcane",
            issueCount = 1,
            issues = {
                { slotName = "Head", itemLink = mockLink(30000, "Helm"), warnings = { "[No Enchant]" } },
            },
            upgrades = {},
        },
    }

    BiSGearCheck:WhisperIssues("Alice-TestRealm")
    assert_equal("Alice-TestRealm", MockWoW._sentMessages[1].target)
    assert_equal("WHISPER", MockWoW._sentMessages[1].chatType)
end

function T.test_whisper_message_format()
    setupBaseState()
    MockWoW._sentMessages = {}
    BiSGearCheck.raidScanResults = {
        ["Bob-TestRealm"] = {
            charKey = "Bob-TestRealm",
            specKey = "WarriorFury",
            issueCount = 1,
            issues = {
                { slotName = "Chest", itemLink = mockLink(30001, "Plate Chest"), warnings = { "|cffff3333[No Enchant]|r" } },
            },
            upgrades = {},
        },
    }

    BiSGearCheck:WhisperIssues("Bob-TestRealm")
    local msg = MockWoW._sentMessages[1].msg
    assert_true(msg:find("%[BiSGearCheck%]") ~= nil, "should have addon prefix")
    assert_true(msg:find("Chest") ~= nil, "should contain slot name")
    assert_true(msg:find("Plate Chest") ~= nil, "should contain item name")
    assert_true(msg:find("No Enchant") ~= nil, "should contain warning text")
end

function T.test_whisper_strips_color_codes()
    setupBaseState()
    MockWoW._sentMessages = {}
    BiSGearCheck.raidScanResults = {
        ["Bob-TestRealm"] = {
            charKey = "Bob-TestRealm",
            specKey = "WarriorFury",
            issueCount = 1,
            issues = {
                { slotName = "Head", itemLink = mockLink(30000), warnings = { "|cffff3333[No Enchant]|r" } },
            },
            upgrades = {},
        },
    }

    BiSGearCheck:WhisperIssues("Bob-TestRealm")
    local msg = MockWoW._sentMessages[1].msg
    assert_true(msg:find("|c") == nil, "should strip color codes from whisper warnings")
    assert_true(msg:find("No Enchant") ~= nil, "should keep warning text")
end

function T.test_whisper_no_issues_sends_nothing()
    setupBaseState()
    MockWoW._sentMessages = {}
    BiSGearCheck.raidScanResults = {
        ["Clean-TestRealm"] = {
            charKey = "Clean-TestRealm",
            specKey = "MageArcane",
            issueCount = 0,
            issues = {},
            upgrades = {},
        },
    }

    BiSGearCheck:WhisperIssues("Clean-TestRealm")
    assert_equal(0, #MockWoW._sentMessages, "should not whisper when no issues")
end

function T.test_whisper_no_result_sends_nothing()
    setupBaseState()
    MockWoW._sentMessages = {}
    BiSGearCheck.raidScanResults = {}

    BiSGearCheck:WhisperIssues("Nobody-TestRealm")
    assert_equal(0, #MockWoW._sentMessages)
end

function T.test_whisper_multiple_warnings_per_slot()
    setupBaseState()
    MockWoW._sentMessages = {}
    BiSGearCheck.raidScanResults = {
        ["Alice-TestRealm"] = {
            charKey = "Alice-TestRealm",
            specKey = "MageArcane",
            issueCount = 2,
            issues = {
                { slotName = "Chest", itemLink = mockLink(30001, "Robe"),
                  warnings = { "|cffff3333[No Enchant]|r", "|cffffff00[Empty Socket]|r" } },
            },
            upgrades = {},
        },
    }

    BiSGearCheck:WhisperIssues("Alice-TestRealm")
    assert_equal(1, #MockWoW._sentMessages, "multiple warnings on one slot = one whisper")
    local msg = MockWoW._sentMessages[1].msg
    assert_true(msg:find("No Enchant") ~= nil)
    assert_true(msg:find("Empty Socket") ~= nil)
end

-- ============================================================
-- TESTS: GuessSpecFromTalents
-- ============================================================

function T.test_talent_guess_elemental_shaman()
    setupBaseState()
    -- Elemental shaman: most points in tab 1
    MockWoW.SetInspectTalents({
        [1] = {  -- Elemental (most points)
            [1] = { name = "Convection", rank = 5 },
            [2] = { name = "Concussion", rank = 5 },
            [3] = { name = "CallOfFlame", rank = 3 },
            [4] = { name = "ElementalFocus", rank = 1 },
            [5] = { name = "Reverberation", rank = 5 },
            [6] = { name = "CallOfThunder", rank = 1 },
            [7] = { name = "EyeOfTheStorm", rank = 3 },
            [8] = { name = "ElementalDevastation", rank = 3 },
            [9] = { name = "StormReach", rank = 2 },
            [10] = { name = "ElementalFury", rank = 1 },
            [11] = { name = "UnrelentingStorm", rank = 3 },
            [12] = { name = "ElementalPrecision", rank = 3 },
            [13] = { name = "LightningMastery", rank = 5 },
            [14] = { name = "ElementalMastery", rank = 1 },
            [15] = { name = "LightningOverload", rank = 5 },
            [16] = { name = "TotemOfWrath", rank = 1 },
        },
        [2] = {  -- Enhancement (some points)
            [1] = { name = "AncestralKnowledge", rank = 5 },
        },
        [3] = {},  -- Restoration (no points)
    })

    local spec = BiSGearCheck:GuessSpecFromTalents("SHAMAN")
    assert_equal("ShamanElemental", spec)
end

function T.test_talent_guess_resto_shaman()
    setupBaseState()
    -- Resto shaman: most points in tab 3
    MockWoW.SetInspectTalents({
        [1] = {},  -- Elemental
        [2] = { [1] = { name = "AncestralKnowledge", rank = 5 } },  -- Enhancement
        [3] = {  -- Restoration (most points)
            [1] = { name = "ImprovedHealingWave", rank = 5 },
            [2] = { name = "TidalFocus", rank = 5 },
            [3] = { name = "ImprovedReincarnation", rank = 2 },
            [4] = { name = "AncestralHealing", rank = 3 },
            [5] = { name = "TotallyPurify", rank = 2 },
            [6] = { name = "HealingFocus", rank = 5 },
            [7] = { name = "TidalMastery", rank = 5 },
            [8] = { name = "NaturesSwiftness", rank = 1 },
            [9] = { name = "FocusedMind", rank = 3 },
            [10] = { name = "Purification", rank = 5 },
            [11] = { name = "ManaTideTotem", rank = 1 },
            [12] = { name = "NaturesGuardian", rank = 5 },
            [13] = { name = "ImprovedChainHeal", rank = 2 },
            [14] = { name = "EarthShield", rank = 1 },
        },
    })

    local spec = BiSGearCheck:GuessSpecFromTalents("SHAMAN")
    assert_equal("ShamanRestoration", spec)
end

function T.test_talent_guess_druid_feral_tank()
    setupBaseState()
    -- Feral tank druid: most points in tab 2, with Survival of the Fittest
    MockWoW.SetInspectTalents({
        [1] = {},  -- Balance
        [2] = {  -- Feral (most points)
            [1] = { name = "Ferocity", rank = 5 },
            [2] = { name = "FeralAggression", rank = 5 },
            [3] = { name = "FeralInstinct", rank = 3 },
            [4] = { name = "BrutalImpact", rank = 2 },
            [5] = { name = "ThickHide", rank = 3 },
            [6] = { name = "FeralSwiftness", rank = 2 },
            [7] = { name = "FeralCharge", rank = 1 },
            [8] = { name = "SharpenedClaws", rank = 3 },
            [9] = { name = "ShreddingAttacks", rank = 2 },
            [10] = { name = "PredatoryStrikes", rank = 3 },
            [11] = { name = "PrimalFury", rank = 2 },
            [12] = { name = "SavageFury", rank = 2 },
            [13] = { name = "Nurturing", rank = 2 },
            [14] = { name = "HeartOfTheWild", rank = 5 },
            [15] = { name = "CatForm", rank = 1 },
            [16] = { name = "LeaderOfThePack", rank = 1 },
            [17] = { name = "ImprovedLeader", rank = 2 },
            [18] = { name = "Survival of the Fittest", rank = 3 },  -- Tank identifier
            [19] = { name = "Predatory", rank = 3 },
            [20] = { name = "Mangle", rank = 1 },
        },
        [3] = {  -- Restoration (some points)
            [1] = { name = "MarkOfTheWild", rank = 5 },
            [2] = { name = "Furor", rank = 5 },
            [3] = { name = "NaturalShapeshifter", rank = 3 },
            [4] = { name = "Intensity", rank = 3 },
            [5] = { name = "OmenOfClarity", rank = 1 },
        },
    })

    local spec = BiSGearCheck:GuessSpecFromTalents("DRUID")
    assert_equal("DruidFeralTank", spec)
end

function T.test_talent_guess_druid_feral_dps()
    setupBaseState()
    -- Feral DPS druid: most points in tab 2, without SotF
    MockWoW.SetInspectTalents({
        [1] = {},  -- Balance
        [2] = {  -- Feral (most points)
            [1] = { name = "Ferocity", rank = 5 },
            [2] = { name = "FeralAggression", rank = 5 },
            [3] = { name = "FeralInstinct", rank = 3 },
            [4] = { name = "BrutalImpact", rank = 2 },
            [5] = { name = "ThickHide", rank = 0 },
            [6] = { name = "FeralSwiftness", rank = 2 },
            [7] = { name = "FeralCharge", rank = 1 },
            [8] = { name = "SharpenedClaws", rank = 3 },
            [9] = { name = "ShreddingAttacks", rank = 2 },
            [10] = { name = "PredatoryStrikes", rank = 3 },
            [11] = { name = "PrimalFury", rank = 2 },
            [12] = { name = "SavageFury", rank = 2 },
            [13] = { name = "Nurturing", rank = 2 },
            [14] = { name = "HeartOfTheWild", rank = 5 },
            [15] = { name = "CatForm", rank = 1 },
            [16] = { name = "LeaderOfThePack", rank = 1 },
            [17] = { name = "ImprovedLeader", rank = 2 },
            [18] = { name = "Survival of the Fittest", rank = 0 },  -- 0 = not tank
            [19] = { name = "Predatory", rank = 3 },
            [20] = { name = "Mangle", rank = 1 },
        },
        [3] = {},
    })

    local spec = BiSGearCheck:GuessSpecFromTalents("DRUID")
    assert_equal("DruidFeralDPS", spec)
end

function T.test_talent_guess_returns_nil_when_no_data()
    setupBaseState()
    MockWoW.SetInspectTalents({})
    local spec = BiSGearCheck:GuessSpecFromTalents("MAGE")
    assert_nil(spec, "should return nil when no talent data available")
end

function T.test_talent_guess_druid_balance()
    setupBaseState()
    MockWoW.SetInspectTalents({
        [1] = {  -- Balance (most points)
            [1] = { name = "Starlight", rank = 5 },
            [2] = { name = "NaturesGrasp", rank = 1 },
            [3] = { name = "ImprovedNaturesGrasp", rank = 4 },
            [4] = { name = "ControlOfNature", rank = 3 },
            [5] = { name = "FocusedStarlight", rank = 2 },
            [6] = { name = "ImprovedMoonfire", rank = 2 },
            [7] = { name = "Brambles", rank = 3 },
            [8] = { name = "InsectSwarm", rank = 1 },
            [9] = { name = "NaturesReach", rank = 2 },
            [10] = { name = "Vengeance", rank = 5 },
            [11] = { name = "CelestialFocus", rank = 3 },
            [12] = { name = "LunarGuidance", rank = 3 },
            [13] = { name = "NaturesGrace", rank = 1 },
            [14] = { name = "Moonglow", rank = 3 },
            [15] = { name = "BalanceOfPower", rank = 2 },
            [16] = { name = "Moonkin", rank = 1 },
            [17] = { name = "ImprovedFF", rank = 3 },
            [18] = { name = "WrathOfCenarius", rank = 5 },
            [19] = { name = "ForceOfNature", rank = 1 },
        },
        [2] = {},  -- Feral
        [3] = {  -- Restoration (some)
            [1] = { name = "MarkOfTheWild", rank = 5 },
        },
    })

    local spec = BiSGearCheck:GuessSpecFromTalents("DRUID")
    assert_equal("DruidBalance", spec)
end

-- ============================================================
-- TESTS: GuessSpecFromGear (BiS matching fallback)
-- ============================================================

function T.test_gear_guess_falls_back_to_first_spec()
    setupBaseState()
    -- No BiS data loaded, no talents = should pick first spec
    MockWoW.SetInspectTalents({})
    local spec = BiSGearCheck:GuessSpecFromGear("WARRIOR", {
        Head = {{ id = 99999 }},
    })
    assert_equal("WarriorArms", spec, "should fall back to first spec when no data")
end

function T.test_gear_guess_prefers_talents_over_gear()
    setupBaseState()
    -- Set up inspect talents that say Enhancement
    MockWoW.SetInspectTalents({
        [1] = {},
        [2] = {  -- Enhancement
            [1] = { name = "AncestralKnowledge", rank = 5 },
            [2] = { name = "ShieldSpec", rank = 5 },
            [3] = { name = "GuardianTotems", rank = 2 },
            [4] = { name = "Thundering", rank = 5 },
            [5] = { name = "ImprovedGhostWolf", rank = 2 },
            [6] = { name = "Enhancing", rank = 2 },
            [7] = { name = "Shamanistic", rank = 1 },
            [8] = { name = "FlurryTalent", rank = 5 },
            [9] = { name = "ImprovedWF", rank = 2 },
            [10] = { name = "SpiritWeapons", rank = 1 },
            [11] = { name = "ElementalWeapons", rank = 3 },
            [12] = { name = "MentalQuickness", rank = 3 },
            [13] = { name = "WeaponMastery", rank = 5 },
            [14] = { name = "DualWield", rank = 1 },
            [15] = { name = "Stormstrike", rank = 1 },
        },
        [3] = {},
    })

    local spec = BiSGearCheck:GuessSpecFromGear("SHAMAN", { Head = {{ id = 1 }} })
    assert_equal("ShamanEnhancement", spec, "talents should take priority over gear matching")
end

-- ============================================================
-- TESTS: CSV Export
-- ============================================================

function T.test_csv_export_nil_when_no_results()
    setupBaseState()
    BiSGearCheck.raidScanResults = {}
    local csv = BiSGearCheck:GenerateRaidScanCSV()
    assert_nil(csv)
end

function T.test_csv_export_has_header()
    setupBaseState()
    BiSGearCheck.raidScanResults = {
        ["TestChar-TestRealm"] = {
            charKey = "TestChar-TestRealm",
            specKey = "WarriorFury",
            issues = {},
            issueCount = 0,
            upgrades = {},
        },
    }

    local csv = BiSGearCheck:GenerateRaidScanCSV()
    assert_not_nil(csv)
    local firstLine = csv:match("^([^\n]+)")
    assert_true(firstLine:find("Character") ~= nil, "header should contain Character")
    assert_true(firstLine:find("Spec") ~= nil, "header should contain Spec")
    assert_true(firstLine:find("Upgrade") ~= nil, "header should contain Upgrade")
end

-- ============================================================
-- TESTS: RestoreLastRaidScan
-- ============================================================

function T.test_restore_last_scan_repopulates_results_with_pinned_spec()
    setupBaseState()
    -- Character record's current selectedSpec is "Fire", but the scan
    -- entry pins "Arcane" — restored result should read Arcane, reflecting
    -- what the scan actually observed.
    BiSGearCheckSaved.characters["Alice-TestRealm"] = {
        class = "MAGE",
        faction = "Alliance",
        level = 70,
        wishlists = { Default = {} },
        activeWishlist = "Default",
        inspected = true,
        selectedSpec = "MageFire",
        equipped = { Head = {{ id = 30000, link = mockLink(30000) }} },
    }
    BiSGearCheckSaved.lastRaidScan = {
        time = os.time(),
        entries = { { charKey = "Alice-TestRealm", specKey = "MageArcane" } },
        skipped = { { name = "Bob", class = "WARRIOR", reason = "Offline" } },
    }

    BiSGearCheck:RestoreLastRaidScan()
    assert_equal("complete", BiSGearCheck.raidScanState)
    local result = BiSGearCheck.raidScanResults["Alice-TestRealm"]
    assert_not_nil(result)
    assert_equal("MageArcane", result.specKey,
        "restored scan uses the pinned spec, not charData.selectedSpec")
    assert_equal(1, #BiSGearCheck.raidScanSkipped)
end

function T.test_restore_last_scan_legacy_reguesses_spec_from_gear()
    -- Saved data from older versions had charKeys instead of entries, with
    -- specs recorded by a guesser that often fell through to the class's
    -- first spec. Legacy restores re-guess from the gear snapshot.
    setupBaseState()
    MockWoW.SetInspectTalents({})
    local origDB = BiSGearCheckDB_WowTBCgg
    BiSGearCheckDB_WowTBCgg = {
        MageFire = { class = "MAGE", spec = "Fire",
            slots = { Head = { 30000 } } },
    }
    BiSGearCheckSaved.characters["Alice-TestRealm"] = {
        class = "MAGE", faction = "Alliance", level = 70,
        wishlists = { Default = {} }, selectedSpec = "MageFrost",
        equipped = { Head = {{ id = 30000, link = mockLink(30000) }} },
    }
    BiSGearCheckSaved.lastRaidScan = {
        time = os.time(),
        charKeys = { "Alice-TestRealm" },
        skipped = {},
    }
    BiSGearCheck:RestoreLastRaidScan()
    local result = BiSGearCheck.raidScanResults["Alice-TestRealm"]
    assert_not_nil(result)
    assert_equal("MageFire", result.specKey,
        "legacy restore should re-guess from gear, not trust the stale record")
    BiSGearCheckDB_WowTBCgg = origDB
end

function T.test_restore_last_scan_legacy_keeps_own_selected_spec()
    -- The player's own spec choice is authoritative — never re-guessed.
    setupBaseState()
    MockWoW.SetInspectTalents({})
    BiSGearCheckSaved.characters["TestChar-TestRealm"].equipped =
        { Head = {{ id = 30000, link = mockLink(30000) }} }
    BiSGearCheckSaved.lastRaidScan = {
        time = os.time(),
        charKeys = { "TestChar-TestRealm" },
        skipped = {},
    }
    BiSGearCheck:RestoreLastRaidScan()
    local result = BiSGearCheck.raidScanResults["TestChar-TestRealm"]
    assert_not_nil(result)
    assert_equal("WarriorFury", result.specKey)
end

function T.test_analyze_character_honors_pinned_spec_argument()
    setupBaseState()
    BiSGearCheckSaved.characters["Alice-TestRealm"] = {
        class = "WARLOCK", faction = "Alliance", level = 70,
        wishlists = { Default = {} }, selectedSpec = "WarlockAffliction",
        equipped = { Head = {} },
    }
    BiSGearCheck:AnalyzeCharacter("Alice-TestRealm", "WarlockDestruction")
    assert_equal("WarlockDestruction",
        BiSGearCheck.raidScanResults["Alice-TestRealm"].specKey)
end

function T.test_restore_last_scan_noop_when_no_data()
    setupBaseState()
    BiSGearCheckSaved.lastRaidScan = nil
    BiSGearCheck:RestoreLastRaidScan()
    assert_equal("idle", BiSGearCheck.raidScanState)
end

return T
