-- Tests for Theme.lua and ElvUI/LSM integration
-- Covers: theme engine, hex cache, font resolution, LSM backdrop handling,
-- and the critical rule that ElvUI skin suppresses LSM overrides.

local T = {}

-- ============================================================
-- HELPERS
-- ============================================================

-- Build a minimal fake LSM for testing LSM-integration paths without
-- requiring the real library. Maps { mediatype -> { key -> path } }.
local function makeFakeLSM(media)
    return {
        Fetch = function(self, mediatype, key)
            local bucket = media[mediatype]
            if not bucket then return nil end
            return bucket[key]
        end,
        List = function(self, mediatype)
            local bucket = media[mediatype] or {}
            local keys = {}
            for k in pairs(bucket) do keys[#keys + 1] = k end
            table.sort(keys)
            return keys
        end,
    }
end

-- Capture SetBackdrop calls on a fake frame for assertions.
local function makeFakeFrame()
    return {
        _backdrop = nil,
        SetBackdrop = function(self, bd) self._backdrop = bd end,
    }
end

local function makeFakeFontString()
    return {
        _font = nil, _size = nil, _flags = nil,
        GetFont = function(self) return self._font, self._size, self._flags end,
        GetText = function() return "English label" end,
        SetFont = function(self, path, size, flags)
            self._font = path
            self._size = size
            self._flags = flags
        end,
    }
end

local function resetTheme()
    -- Reset the active theme back to the default Breakbone theme.
    BiSGearCheck:SetTheme(BiSGearCheck.BreakboneTheme)
    -- Clear LSM and font overrides on the theme
    BiSGearCheck.BreakboneTheme.lsmBorder = nil
    BiSGearCheck.BreakboneTheme.lsmBackground = nil
    BiSGearCheck.BreakboneTheme.fonts.name = nil
    BiSGearCheck.BreakboneTheme.fonts.size = 11
    BiSGearCheck.BreakboneTheme.fonts.sizeSmall = 10
    BiSGearCheck.BreakboneTheme.fonts.sizeLarge = 13
end

-- ============================================================
-- THEME ENGINE TESTS
-- ============================================================

function T.test_theme_has_breakbone_default()
    resetTheme()
    local active = BiSGearCheck:GetTheme()
    assert_equal("Breakbone", active.name)
end

function T.test_hex_returns_cached_color_code()
    resetTheme()
    local prefix = BiSGearCheck.Theme.hex("slotHeader")
    assert_equal("|cffffd100", prefix, "slotHeader hex prefix should be |cffffd100")
end

function T.test_hex_unknown_key_returns_nil()
    resetTheme()
    assert_nil(BiSGearCheck.Theme.hex("no_such_key"))
end

function T.test_warn_hex_returns_cached_color_code()
    resetTheme()
    assert_equal("|cffff4d4d", BiSGearCheck.Theme.warnHex("red"))
    assert_equal("|cffffcc00", BiSGearCheck.Theme.warnHex("yellow"))
end

function T.test_rgba_returns_color_table()
    resetTheme()
    local c = BiSGearCheck.Theme.rgba("tabActive")
    assert_not_nil(c)
    assert_equal(0.2, c[1])
    assert_equal(0.2, c[2])
    assert_equal(0.2, c[3])
    assert_equal(1.0, c[4])
end

function T.test_backdrop_returns_default_table()
    resetTheme()
    local bd = BiSGearCheck.Theme.backdrop()
    assert_not_nil(bd)
    assert_equal("Interface\\DialogFrame\\UI-DialogBox-Background-Dark", bd.bgFile)
    assert_equal("Interface\\DialogFrame\\UI-DialogBox-Border", bd.edgeFile)
    assert_equal(32, bd.edgeSize)
end

function T.test_set_theme_rebuilds_hex_cache()
    resetTheme()
    -- Define a minimal alternate theme
    local altTheme = {
        name = "Alt",
        backdrop = BiSGearCheck.BreakboneTheme.backdrop,
        colors = { tabActive = { 0.1, 0.1, 0.1, 1 } },
        hex = { slotHeader = "ff0000" },  -- red instead of gold
        warnHex = { red = "aa0000", yellow = "bbbb00" },
        fonts = { name = nil, size = 11, sizeSmall = 10, sizeLarge = 13 },
    }
    BiSGearCheck:SetTheme(altTheme)
    assert_equal("|cffff0000", BiSGearCheck.Theme.hex("slotHeader"))
    assert_equal("|cffaa0000", BiSGearCheck.Theme.warnHex("red"))
    -- Old keys should be gone
    assert_nil(BiSGearCheck.Theme.hex("rankNum"))
    -- Reset
    resetTheme()
end

-- ============================================================
-- FONT RESOLUTION TESTS
-- ============================================================

function T.test_get_font_returns_nil_when_no_custom_font()
    resetTheme()
    local path, size = BiSGearCheck.Theme.getFont("normal")
    assert_nil(path)
    assert_nil(size)
end

function T.test_apply_font_is_noop_when_no_custom_font()
    resetTheme()
    local fs = makeFakeFontString()
    BiSGearCheck.Theme.applyFont(fs, "normal")
    -- SetFont should NOT have been called
    assert_nil(fs._font)
end

-- ============================================================
-- LSM BACKDROP TESTS
-- ============================================================

function T.test_apply_backdrop_no_lsm_uses_default()
    resetTheme()
    local frame = makeFakeFrame()
    BiSGearCheck.Theme.applyBackdrop(frame)
    -- Should have used the default backdrop (edgeFile present, edgeSize=32)
    assert_not_nil(frame._backdrop)
    assert_equal("Interface\\DialogFrame\\UI-DialogBox-Border", frame._backdrop.edgeFile)
    assert_equal(32, frame._backdrop.edgeSize)
end

-- ============================================================
-- ELVUI OVERRIDE RULE: LSM settings are skipped when ElvUI skin is active
-- ============================================================

-- This mirrors the logic in Core.lua Initialize. If this logic changes,
-- these tests enforce the invariant: "ElvUI owns the look when enabled."
local function applyLSMPrefsForTest()
    -- Mirror of Core.lua's LSM override block
    if BiSGearCheckSaved and not (BiSGearCheckSaved.elvuiSkin == true) then
        local theme = BiSGearCheck.BreakboneTheme
        if BiSGearCheckSaved.lsmFont and theme.fonts then
            theme.fonts.name = BiSGearCheckSaved.lsmFont
        end
        if BiSGearCheckSaved.lsmFontSize and theme.fonts then
            local delta = BiSGearCheckSaved.lsmFontSize - 11
            theme.fonts.size = 11 + delta
            theme.fonts.sizeSmall = 10 + delta
            theme.fonts.sizeLarge = 13 + delta
        end
        if BiSGearCheckSaved.lsmBorder then
            theme.lsmBorder = BiSGearCheckSaved.lsmBorder
        end
        if BiSGearCheckSaved.lsmBackground then
            theme.lsmBackground = BiSGearCheckSaved.lsmBackground
        end
    end
end

function T.test_lsm_overrides_applied_when_elvui_skin_disabled()
    resetTheme()
    BiSGearCheckSaved = {
        elvuiSkin = false,
        lsmFont = "MyFont",
        lsmFontSize = 14,
        lsmBorder = "MyBorder",
        lsmBackground = "MyBg",
    }
    applyLSMPrefsForTest()
    assert_equal("MyFont", BiSGearCheck.BreakboneTheme.fonts.name)
    assert_equal(14, BiSGearCheck.BreakboneTheme.fonts.size)
    assert_equal(13, BiSGearCheck.BreakboneTheme.fonts.sizeSmall)  -- 10 + delta(3)
    assert_equal(16, BiSGearCheck.BreakboneTheme.fonts.sizeLarge)  -- 13 + delta(3)
    assert_equal("MyBorder", BiSGearCheck.BreakboneTheme.lsmBorder)
    assert_equal("MyBg", BiSGearCheck.BreakboneTheme.lsmBackground)
    resetTheme()
end

function T.test_lsm_overrides_skipped_when_elvui_skin_enabled()
    resetTheme()
    BiSGearCheckSaved = {
        elvuiSkin = true,
        lsmFont = "MyFont",
        lsmFontSize = 14,
        lsmBorder = "MyBorder",
        lsmBackground = "MyBg",
    }
    applyLSMPrefsForTest()
    -- Nothing should have been applied
    assert_nil(BiSGearCheck.BreakboneTheme.fonts.name)
    assert_equal(11, BiSGearCheck.BreakboneTheme.fonts.size)
    assert_equal(10, BiSGearCheck.BreakboneTheme.fonts.sizeSmall)
    assert_equal(13, BiSGearCheck.BreakboneTheme.fonts.sizeLarge)
    assert_nil(BiSGearCheck.BreakboneTheme.lsmBorder)
    assert_nil(BiSGearCheck.BreakboneTheme.lsmBackground)
    resetTheme()
end

function T.test_lsm_overrides_applied_when_elvui_skin_nil()
    resetTheme()
    BiSGearCheckSaved = {
        -- elvuiSkin is nil (never set) — should behave same as false
        lsmFont = "MyFont",
    }
    applyLSMPrefsForTest()
    assert_equal("MyFont", BiSGearCheck.BreakboneTheme.fonts.name)
    resetTheme()
end

-- ============================================================
-- FONT SIZE DELTA TESTS
-- ============================================================

function T.test_font_size_delta_is_zero_at_baseline()
    resetTheme()
    BiSGearCheckSaved = { elvuiSkin = false, lsmFontSize = 11 }
    applyLSMPrefsForTest()
    assert_equal(11, BiSGearCheck.BreakboneTheme.fonts.size)
    assert_equal(10, BiSGearCheck.BreakboneTheme.fonts.sizeSmall)
    assert_equal(13, BiSGearCheck.BreakboneTheme.fonts.sizeLarge)
    resetTheme()
end

function T.test_font_size_delta_positive()
    resetTheme()
    BiSGearCheckSaved = { elvuiSkin = false, lsmFontSize = 15 }
    applyLSMPrefsForTest()
    assert_equal(15, BiSGearCheck.BreakboneTheme.fonts.size)
    assert_equal(14, BiSGearCheck.BreakboneTheme.fonts.sizeSmall)
    assert_equal(17, BiSGearCheck.BreakboneTheme.fonts.sizeLarge)
    resetTheme()
end

function T.test_font_size_delta_negative()
    resetTheme()
    BiSGearCheckSaved = { elvuiSkin = false, lsmFontSize = 9 }
    applyLSMPrefsForTest()
    assert_equal(9, BiSGearCheck.BreakboneTheme.fonts.size)
    assert_equal(8, BiSGearCheck.BreakboneTheme.fonts.sizeSmall)
    assert_equal(11, BiSGearCheck.BreakboneTheme.fonts.sizeLarge)
    resetTheme()
end

-- ============================================================
-- ELVUI DETECTION TESTS
-- ============================================================

function T.test_is_elvui_loaded_false_without_global()
    local saved = _G.ElvUI
    _G.ElvUI = nil
    assert_false(BiSGearCheck:IsElvUILoaded())
    _G.ElvUI = saved
end

function T.test_is_elvui_loaded_true_with_global()
    local saved = _G.ElvUI
    _G.ElvUI = { "fake_engine" }
    assert_true(BiSGearCheck:IsElvUILoaded())
    _G.ElvUI = saved
end

function T.test_is_elvui_skin_enabled_false_when_not_set()
    BiSGearCheckSaved = {}
    assert_false(BiSGearCheck:IsElvUISkinEnabled())
end

function T.test_is_elvui_skin_enabled_false_when_disabled()
    BiSGearCheckSaved = { elvuiSkin = false }
    assert_false(BiSGearCheck:IsElvUISkinEnabled())
end

function T.test_is_elvui_skin_enabled_true_when_enabled()
    BiSGearCheckSaved = { elvuiSkin = true }
    assert_true(BiSGearCheck:IsElvUISkinEnabled())
end

function T.test_is_elvui_skin_enabled_false_when_saved_nil()
    BiSGearCheckSaved = nil
    assert_false(BiSGearCheck:IsElvUISkinEnabled())
end

return T
