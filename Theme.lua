-- BiSGearCheck Theme.lua
-- Centralized theme system: all visual constants (colors, backdrops, fonts)
-- live here. The active theme is the single source of truth for styling.

BiSGearCheck = BiSGearCheck or {}

-- LibSharedMedia-3.0 (optional — graceful fallback when unavailable)
local LSM
if LibStub and type(LibStub) == "table" and LibStub.GetLibrary then
    LSM = LibStub:GetLibrary("LibSharedMedia-3.0", true)
elseif LibStub and type(LibStub) == "function" then
    local ok, lib = pcall(LibStub, "LibSharedMedia-3.0", true)
    if ok then LSM = lib end
end
BiSGearCheck.LSM = LSM

-- ============================================================
-- BREAKBONE THEME (default — the addon's signature look)
-- ============================================================

BiSGearCheck.BreakboneTheme = {
    name = "Breakbone",

    backdrop = {
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    },

    -- RGBA color tables for SetColorTexture / SetTextColor / SetVertexColor
    colors = {
        tabActive         = { 0.2,  0.2,  0.2,  1.0 },
        tabInactive       = { 0.08, 0.08, 0.08, 0.8 },
        tabTextActive     = { 1, 0.82, 0 },
        tabTextInactive   = { 0.5, 0.5, 0.5 },
        btnWishlistOn     = { 0.0, 0.5, 0.0, 0.8 },
        btnWishlistOff    = { 0.2, 0.2, 0.2, 0.6 },
        btnRemove         = { 0.5, 0.0, 0.0, 0.8 },
        separator         = { 0.3, 0.3, 0.3, 0.5 },
        separatorRaid     = { 0.3, 0.3, 0.3, 0.3 },
        sectionLine       = { 0.4, 0.4, 0.4, 0.6 },
        scrollBg          = { 0.05, 0.05, 0.05, 0.5 },
        sliderTrack       = { 0.15, 0.15, 0.15, 0.8 },
        settingsIcon      = { 0.8, 0.8, 0.8 },
        settingsIconHover = { 1.0, 1.0, 1.0 },
        progressText      = { 0.7, 0.7, 0.7 },
    },

    -- Hex color codes (6-char, no prefix) for inline |cff text formatting
    hex = {
        slotHeader     = "ffd100",   -- gold: slot names, arrows, gem header
        rankNum        = "00ccff",   -- cyan: #1, #2 rank numbers
        rankBis        = "00ff00",   -- green: "BiS!"
        rankText       = "ffffff",   -- white: "Rank N"
        notOnList      = "999999",   -- gray: "Not on list"
        sourceInfo     = "888888",   -- gray: source/drop text, gem labels
        emptySlot      = "999999",   -- gray: "(empty)", placeholders
        filtered       = "999999",   -- gray: "N items filtered"
        equipped       = "00ff00",   -- green: "[Equipped]"
        enchantLabel   = "00ccff",   -- cyan: "Enchants:" label
        enchantName    = "a335ee",   -- epic purple: enchant/gem names
        gemLabel       = "888888",   -- gray: "Meta:", "Red:", etc.
        gemName        = "a335ee",   -- epic purple: gem item names
        gemsHeader     = "ffd100",   -- gold: "Recommended Gems"
        collapseLink   = "00ccff",   -- cyan: "Collapse All" / "Expand All"
        collapseLinkHi = "ffffff",   -- white: hover state
        btnText        = "ffffff",   -- white: button labels (+, x)
        wishlistLabel  = "ffd100",   -- gold: "Wishlist:" label
        zoneHighlight  = "00ff00",   -- green: zones with items
        skippedLabel   = "888888",   -- gray: "Skipped:" header
        rosterChanged  = "ff6600",   -- orange: "(roster changed)"
        issuesBadge    = "ff3333",   -- red: "[N Issues]"
        okBadge        = "00ff00",   -- green: "[OK]"
        upgradesBadge  = "00ccff",   -- cyan: "[N Upgrades]"
        specLabel      = "888888",   -- gray: "(spec name)" in raid
        inspectedTag   = "888888",   -- gray: "(Inspected)" suffix
        linkUrl        = "69ccf0",   -- blue: URL text in settings
        settingsNote   = "888888",   -- gray: filter notes in settings
        chatPrefix     = "00ccff",   -- cyan: "BiSGearCheck:" in chat
        chatError      = "ff6666",   -- red: error messages in chat
        wishlistTitle  = "00ccff",   -- cyan: wishlist name in title
    },

    -- Warning badge hex codes
    warnHex = {
        red    = "ff4d4d",
        yellow = "ffcc00",
    },

    -- Font configuration (LSM integration)
    fonts = {
        name = nil,         -- LSM font key (nil = use stock GameFont objects)
        size = 11,          -- base size for normal text
        sizeSmall = 10,
        sizeLarge = 13,
    },

    -- LSM overrides (nil = use backdrop table defaults)
    lsmBorder = nil,        -- LSM border key
    lsmBackground = nil,    -- LSM background key
}

-- ============================================================
-- THEME ENGINE
-- ============================================================

local activeTheme = BiSGearCheck.BreakboneTheme
local hexCache = {}     -- key -> "|cffXXXXXX"
local warnHexCache = {} -- key -> "|cffXXXXXX"

-- Build the hex cache from the active theme
local function RebuildHexCache()
    wipe(hexCache)
    wipe(warnHexCache)
    for key, hex6 in pairs(activeTheme.hex) do
        hexCache[key] = "|cff" .. hex6
    end
    for key, hex6 in pairs(activeTheme.warnHex) do
        warnHexCache[key] = "|cff" .. hex6
    end
end

RebuildHexCache()

-- ============================================================
-- PUBLIC API (BiSGearCheck.Theme)
-- ============================================================

local Theme = {}
BiSGearCheck.Theme = Theme

--- Returns cached "|cffXXXXXX" prefix for a hex color key. Zero-alloc.
function Theme.hex(key)
    return hexCache[key]
end

--- Returns cached "|cffXXXXXX" prefix for a warning color key. Zero-alloc.
function Theme.warnHex(key)
    return warnHexCache[key]
end

--- Returns RGBA table {r, g, b, a} for a color key.
function Theme.rgba(key)
    return activeTheme.colors[key]
end

--- Returns the active backdrop definition table.
function Theme.backdrop()
    return activeTheme.backdrop
end

--- Applies the backdrop to a frame.
--- Uses LSM border/background if configured, theme hook if present, else raw backdrop.
function Theme.applyBackdrop(frame)
    if activeTheme.applyBackdrop then
        activeTheme.applyBackdrop(frame)
        return
    end
    local bd = activeTheme.backdrop
    if LSM and (activeTheme.lsmBorder or activeTheme.lsmBackground) then
        -- Resolve edge: "None" key is a deliberate no-border signal.
        local edgeFile
        if activeTheme.lsmBorder == "None" then
            edgeFile = nil
        elseif activeTheme.lsmBorder then
            local edge = LSM:Fetch("border", activeTheme.lsmBorder)
            edgeFile = (edge and edge ~= "" and edge ~= "Interface\\None") and edge or nil
        else
            edgeFile = bd.edgeFile
        end

        -- Resolve bg: "None" key is a deliberate no-background signal.
        local bgFile
        if activeTheme.lsmBackground == "None" then
            bgFile = nil
        elseif activeTheme.lsmBackground then
            local bg = LSM:Fetch("background", activeTheme.lsmBackground)
            bgFile = (bg and bg ~= "" and bg ~= "Interface\\None") and bg or nil
        else
            bgFile = bd.bgFile
        end

        local edgeSize = edgeFile and bd.edgeSize or 0
        local insets = edgeFile and bd.insets or { left = 0, right = 0, top = 0, bottom = 0 }
        frame:SetBackdrop({
            bgFile = bgFile,
            edgeFile = edgeFile,
            tile = bd.tile, tileSize = bd.tileSize, edgeSize = edgeSize,
            insets = insets,
        })
        return
    end
    frame:SetBackdrop(bd)
end

--- Applies active tab styling to a tab frame (bg texture + label text color).
function Theme.setTabActive(tab)
    local c = activeTheme.colors.tabActive
    tab.bg:SetColorTexture(c[1], c[2], c[3], c[4])
    local tc = activeTheme.colors.tabTextActive
    tab.label:SetTextColor(tc[1], tc[2], tc[3])
end

--- Applies inactive tab styling.
function Theme.setTabInactive(tab)
    local c = activeTheme.colors.tabInactive
    tab.bg:SetColorTexture(c[1], c[2], c[3], c[4])
    local tc = activeTheme.colors.tabTextInactive
    tab.label:SetTextColor(tc[1], tc[2], tc[3])
end

--- Applies separator line color (isRaid uses lower-alpha variant).
function Theme.applySeparator(line, isRaid)
    local c = isRaid and activeTheme.colors.separatorRaid or activeTheme.colors.separator
    line:SetColorTexture(c[1], c[2], c[3], c[4])
end

--- Applies wishlist button background color based on on/off state.
function Theme.applyWishlistBtn(bg, isOnWishlist)
    local c = isOnWishlist and activeTheme.colors.btnWishlistOn or activeTheme.colors.btnWishlistOff
    bg:SetColorTexture(c[1], c[2], c[3], c[4])
end

--- Applies remove button background color.
function Theme.applyRemoveBtn(bg)
    local c = activeTheme.colors.btnRemove
    bg:SetColorTexture(c[1], c[2], c[3], c[4])
end

--- Applies settings icon vertex color.
function Theme.applySettingsIcon(icon, isHover)
    local c = isHover and activeTheme.colors.settingsIconHover or activeTheme.colors.settingsIcon
    icon:SetVertexColor(c[1], c[2], c[3])
end

--- Applies progress text color.
function Theme.applyProgressText(fontString)
    local c = activeTheme.colors.progressText
    fontString:SetTextColor(c[1], c[2], c[3])
end

--- Applies section line color (for Settings section headers).
function Theme.applySectionLine(line)
    local c = activeTheme.colors.sectionLine
    line:SetColorTexture(c[1], c[2], c[3], c[4])
end

--- Applies scroll background color.
function Theme.applyScrollBg(texture)
    local c = activeTheme.colors.scrollBg
    texture:SetColorTexture(c[1], c[2], c[3], c[4])
end

--- Applies slider track background color.
function Theme.applySliderTrack(texture)
    local c = activeTheme.colors.sliderTrack
    texture:SetColorTexture(c[1], c[2], c[3], c[4])
end

-- ============================================================
-- FONT SUPPORT (via LibSharedMedia)
-- ============================================================

local FONT_SIZE_MAP = { normal = "size", small = "sizeSmall", large = "sizeLarge" }

--- Returns fontPath, fontSize if a custom LSM font is configured, else nil.
--- sizeKey: "normal", "small", or "large"
function Theme.getFont(sizeKey)
    local fonts = activeTheme.fonts
    if not fonts or not fonts.name or not LSM then return nil, nil end
    local path = LSM:Fetch("font", fonts.name)
    if not path then return nil, nil end
    local sizeField = FONT_SIZE_MAP[sizeKey or "normal"] or "size"
    return path, fonts[sizeField] or fonts.size
end

--- Applies the theme font and enables Cyrillic fallback for dynamic text.
--- sizeKey: "normal", "small", or "large"
function Theme.applyFont(fontString, sizeKey)
    local path, size = Theme.getFont(sizeKey)
    if path then
        fontString:SetFont(path, size)
    end
    Theme.watchTextFont(fontString)
end

-- Cyrillic names can be entered on an English client. Use the client's own
-- Cyrillic face without changing shared GameFont objects or the Latin UI.
local CYRILLIC_FONT = "Fonts\\FRIZQT___CYR.TTF"
local originalTextFonts = setmetatable({}, { __mode = "k" })
local watchedText = setmetatable({}, { __mode = "k" })

local function hasCyrillic(text)
    -- UTF-8 U+0400..U+04FF, including Russian Ё/ё and Ukrainian letters.
    return type(text) == "string" and text:find("[\208-\211][\128-\191]")
end

function Theme.applyTextFont(region, text)
    local path, size, flags = region:GetFont()
    if not path then return end
    if hasCyrillic(text) then
        if path ~= CYRILLIC_FONT then
            originalTextFonts[region] = { path, size, flags }
            region:SetFont(CYRILLIC_FONT, size, flags)
        end
    else
        local original = originalTextFonts[region]
        if original and path == CYRILLIC_FONT then
            region:SetFont(original[1], original[2], original[3])
        end
        originalTextFonts[region] = nil
    end
end

-- Rows and dropdown labels are reused and usually receive text after creation.
function Theme.watchTextFont(region)
    if not watchedText[region] then
        watchedText[region] = true
        hooksecurefunc(region, "SetText", function(self)
            Theme.applyTextFont(self, self:GetText())
        end)
    end
    Theme.applyTextFont(region, region:GetText())
end

-- UIDropDownMenu reuses buttons across addons. It resets all three state fonts
-- for each text entry; use private copies so later menus retain their fonts.
local dropdownFonts, dropdownFontCount = {}, 0
function Theme.addDropdownButton(info, level)
    UIDropDownMenu_AddButton(info, level)
    if not hasCyrillic(info.text) then return end
    local list = _G["DropDownList" .. (level or 1)]
    local button = list and _G[list:GetName() .. "Button" .. list.numButtons]
    if not button then return end
    for _, state in ipairs({ "Normal", "Highlight", "Disabled" }) do
        local original = button["Get" .. state .. "FontObject"](button)
        local font = dropdownFonts[original]
        if not font then
            dropdownFontCount = dropdownFontCount + 1
            font = CreateFont("BiSGearCheckCyrillicDropdown" .. dropdownFontCount)
            dropdownFonts[original] = font
        end
        font:SetFontObject(original)
        local _, size, flags = original:GetFont()
        font:SetFont(CYRILLIC_FONT, size, flags)
        button["Set" .. state .. "FontObject"](button, font)
    end
    list.shouldRefresh = true
end

-- Only style the line BGC just appended, and restore it when the tooltip clears.
local tooltipText = setmetatable({}, { __mode = "k" })
function Theme.applyTooltipTextFont(tooltip, text)
    local name = tooltip:GetName()
    if not name or not hasCyrillic(text) then return end
    local region = _G[name .. "TextLeft" .. tooltip:NumLines()]
    if not region then return end
    local regions = tooltipText[tooltip]
    if not regions then
        regions = {}
        tooltipText[tooltip] = regions
        tooltip:HookScript("OnTooltipCleared", function()
            for textRegion in pairs(regions) do
                Theme.applyTextFont(textRegion, nil)
                regions[textRegion] = nil
            end
        end)
    end
    regions[region] = true
    Theme.applyTextFont(region, text)
end

-- ============================================================
-- THEME SWITCHING
-- ============================================================

function BiSGearCheck:GetTheme()
    return activeTheme
end

function BiSGearCheck:SetTheme(theme)
    activeTheme = theme
    RebuildHexCache()
end
