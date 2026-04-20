-- WoW API Mock Layer for BiSGearCheck Tests
-- Provides stubs for WoW globals, API functions, and data tables.
-- Call MockWoW.reset() between tests to restore clean state.

MockWoW = MockWoW or {}

-- ============================================================
-- CONFIGURABLE STATE (tests set these before calling addon code)
-- ============================================================

MockWoW._playerName = "TestChar"
MockWoW._playerRealm = "TestRealm"
MockWoW._playerClass = "WARRIOR"
MockWoW._playerClassDisplay = "Warrior"
MockWoW._playerLevel = 70
MockWoW._playerFaction = "Alliance"
MockWoW._currentZone = "Shattrath City"

-- Inventory: [invSlotID] = { id = itemID, link = itemLink }
MockWoW._inventory = {}

-- Inspected unit data
MockWoW._inspectUnit = nil  -- { name, realm, class, classDisplay, level, faction, exists, canInspect, inventory }

-- Item info cache: [itemID] = { name, link, quality, ..., bindType }
MockWoW._itemInfo = {}

-- Faction standings: [factionID] = standing (1-8)
MockWoW._factionStandings = {}

-- Skill lines: { { name = "Blacksmithing", isHeader = false }, ... }
MockWoW._skillLines = {}

-- Talent tabs: { { points = 41 }, { points = 20 }, { points = 0 } }
MockWoW._talentTabs = {}

-- Inspect talents: { [tab] = { [index] = { name, rank } } }
-- Used by GetTalentInfo(tab, i, true, nil, activeSpec)
MockWoW._inspectTalents = {}
MockWoW._inspectActiveTalentGroup = 1

-- Group/raid members: { [unitID] = { name, realm, class, classDisplay, level, faction, inventory, connected, visible } }
MockWoW._groupMembers = {}
MockWoW._isInRaid = false

-- Loaded addons: { ["AddonName"] = true }
MockWoW._loadedAddons = {}

-- ============================================================
-- RESET
-- ============================================================

function MockWoW.reset()
    MockWoW._playerName = "TestChar"
    MockWoW._playerRealm = "TestRealm"
    MockWoW._playerClass = "WARRIOR"
    MockWoW._playerClassDisplay = "Warrior"
    MockWoW._playerLevel = 70
    MockWoW._playerFaction = "Alliance"
    MockWoW._currentZone = "Shattrath City"
    MockWoW._inventory = {}
    MockWoW._inspectUnit = nil
    MockWoW._itemInfo = {}
    MockWoW._factionStandings = {}
    MockWoW._skillLines = {}
    MockWoW._talentTabs = {}
    MockWoW._inspectTalents = {}
    MockWoW._inspectActiveTalentGroup = 1
    MockWoW._groupMembers = {}
    MockWoW._isInRaid = false
    MockWoW._loadedAddons = {}
    MockWoW._sentMessages = {}

    -- Reset addon globals
    BiSGearCheck = nil
    BiSGearCheckSaved = nil
    BiSGearCheckChar = nil
    BiSGearCheckSources = nil
    BiSGearCheckItemPhases = nil
    BiSGearCheckEnchantsDB = nil

    -- Reset UI stub globals
    StaticPopupDialogs = StaticPopupDialogs or {}
    SlashCmdList = SlashCmdList or {}
    SLASH_BISGEARCHECK1 = nil
    SLASH_BISGEARCHECK2 = nil

    -- Reload addon source files
    dofile("Util.lua")
    dofile("Theme.lua")
    dofile("ElvUISkin.lua")
    dofile("Comparison.lua")
    dofile("Wishlist.lua")
    dofile("WishlistCompare.lua")
    dofile("Character.lua")
    dofile("RaidScan.lua")
    dofile("Tooltip.lua")
    dofile("Core.lua")
end

-- ============================================================
-- LUA 5.4 COMPAT: provide globals that WoW's embedded Lua has
-- ============================================================

-- string library globals
strmatch = strmatch or string.match
strfind = strfind or string.find
strsub = strsub or string.sub
strlower = strlower or string.lower
strupper = strupper or string.upper
strlen = strlen or string.len
strtrim = strtrim or function(s)
    if not s then return "" end
    return s:match("^%s*(.-)%s*$")
end
strsplit = strsplit or function(delimiter, str, max)
    if not str then return nil end
    local parts = {}
    local pattern = "(.-)" .. delimiter
    local last_end = 1
    local s, e, cap = str:find(pattern, 1)
    while s do
        if s ~= 1 or cap ~= "" then
            parts[#parts + 1] = cap
        end
        last_end = e + 1
        if max and #parts >= max - 1 then break end
        s, e, cap = str:find(pattern, last_end)
    end
    parts[#parts + 1] = str:sub(last_end)
    return table.unpack(parts)
end

format = format or string.format
tinsert = tinsert or table.insert
tremove = tremove or table.remove

-- WoW's wipe: clear a table in-place
function wipe(t)
    if not t then return end
    for k in pairs(t) do
        t[k] = nil
    end
    return t
end

-- select is built into Lua but WoW uses it frequently
-- (already available)

-- ============================================================
-- WOW API STUBS
-- ============================================================

function UnitName(unit)
    if unit == "player" then
        return MockWoW._playerName, nil
    end
    if MockWoW._inspectUnit and (unit == "target" or unit == "mouseover") then
        return MockWoW._inspectUnit.name, MockWoW._inspectUnit.realm
    end
    local member = MockWoW._groupMembers[unit]
    if member then return member.name, member.realm end
    return nil
end

function GetRealmName()
    return MockWoW._playerRealm
end

-- Helper: resolve unit data from inspect unit or group members
local function resolveUnit(unit)
    if MockWoW._inspectUnit and (unit == "target" or unit == "mouseover") then
        return MockWoW._inspectUnit
    end
    return MockWoW._groupMembers[unit]
end

function UnitClass(unit)
    if unit == "player" then
        return MockWoW._playerClassDisplay, MockWoW._playerClass
    end
    local data = resolveUnit(unit)
    if data then return data.classDisplay or data.class, data.class end
    return nil
end

function UnitLevel(unit)
    if unit == "player" then
        return MockWoW._playerLevel
    end
    local data = resolveUnit(unit)
    return data and data.level or 0
end

function UnitFactionGroup(unit)
    if unit == "player" then
        return MockWoW._playerFaction
    end
    local data = resolveUnit(unit)
    return data and data.faction
end

function UnitExists(unit)
    if unit == "player" then return true end
    local data = resolveUnit(unit)
    return data and data.exists ~= false or false
end

function UnitIsUnit(u1, u2)
    if u1 == u2 then return true end
    if MockWoW._inspectUnit and MockWoW._inspectUnit.isSelf then
        return true
    end
    return false
end

function UnitIsConnected(unit)
    if unit == "player" then return true end
    local data = resolveUnit(unit)
    return data and data.connected ~= false or false
end

function UnitIsVisible(unit)
    if unit == "player" then return true end
    local data = resolveUnit(unit)
    return data and data.visible ~= false or false
end

function CanInspect(unit)
    local data = resolveUnit(unit)
    return data and data.canInspect ~= false or false
end

function NotifyInspect(unit)
    -- In tests, immediately make this unit's inventory available for GetInventoryItemLink
    MockWoW._currentInspectUnit = unit
end

function ClearInspectPlayer()
    MockWoW._currentInspectUnit = nil
end

function GetNumGroupMembers()
    local count = 0
    for _ in pairs(MockWoW._groupMembers) do count = count + 1 end
    return count
end

function IsInRaid()
    return MockWoW._isInRaid
end

function GetActiveTalentGroup(isInspect)
    if isInspect then
        return MockWoW._inspectActiveTalentGroup or 1
    end
    return 1
end

function GetInventoryItemID(unit, slotID)
    if unit == "player" then
        local item = MockWoW._inventory[slotID]
        return item and item.id
    end
    -- For inspect/group units, check the unit's inventory
    local data = resolveUnit(unit)
    if data and data.inventory then
        local item = data.inventory[slotID]
        return item and item.id
    end
    return nil
end

function GetInventoryItemLink(unit, slotID)
    if unit == "player" then
        local item = MockWoW._inventory[slotID]
        return item and item.link
    end
    local data = resolveUnit(unit)
    if data and data.inventory then
        local item = data.inventory[slotID]
        return item and item.link
    end
    return nil
end

function GetItemInfo(itemID)
    itemID = tonumber(itemID)
    if not itemID then return nil end
    local info = MockWoW._itemInfo[itemID]
    if not info then return nil end
    -- Returns: name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, icon, vendorPrice, classID, subclassID, bindType
    return info.name, info.link, info.quality, info.iLevel or 0, info.reqLevel or 0,
        info.class or "", info.subclass or "", info.maxStack or 1,
        info.equipSlot or "", info.icon or "", info.vendorPrice or 0,
        info.classID or 0, info.subclassID or 0, info.bindType or 0
end

function GetRealZoneText()
    return MockWoW._currentZone
end

function GetFactionInfoByID(factionID)
    local standing = MockWoW._factionStandings[factionID]
    return "FactionName", nil, standing or 4
end

function GetNumSkillLines()
    return #MockWoW._skillLines
end

function GetSkillLineInfo(index)
    local skill = MockWoW._skillLines[index]
    if skill then
        return skill.name, skill.isHeader
    end
    return nil
end

function GetNumTalentTabs(isInspect)
    if isInspect and next(MockWoW._inspectTalents) then
        local max = 0
        for tab in pairs(MockWoW._inspectTalents) do
            if tab > max then max = tab end
        end
        return max
    end
    return #MockWoW._talentTabs
end

function GetNumTalents(tab, isInspect)
    -- Doesn't support inspect flag in real client; returns player's count
    local playerTab = MockWoW._talentTabs[tab]
    return playerTab and (playerTab.numTalents or 20) or 20
end

function GetTalentTabInfo(tabIndex)
    local tab = MockWoW._talentTabs[tabIndex]
    if tab then
        return "TabName", "icon", tab.points or 0
    end
    return nil
end

function GetTalentInfo(tab, index, isInspect, isPet, talentGroup)
    if isInspect and MockWoW._inspectTalents[tab] then
        local talent = MockWoW._inspectTalents[tab][index]
        if talent then
            return talent.name or ("Talent" .. index), "icon", talent.row or 1, talent.column or 1, talent.rank or 0
        end
        return nil
    end
    -- Player talents (non-inspect)
    local playerTab = MockWoW._talentTabs[tab]
    if playerTab and playerTab.talents and playerTab.talents[index] then
        local t = playerTab.talents[index]
        return t.name or ("Talent" .. index), "icon", t.row or 1, t.column or 1, t.rank or 0
    end
    return nil
end

function IsAddOnLoaded(name)
    return MockWoW._loadedAddons[name] or false
end

-- C_AddOns namespace
C_AddOns = C_AddOns or {}
function C_AddOns.IsAddOnLoaded(name)
    return MockWoW._loadedAddons[name] or false
end

-- C_Item namespace
C_Item = C_Item or {}
function C_Item.RequestLoadItemDataByID(itemID)
    -- no-op in tests
end

-- ============================================================
-- WOW UI STUBS (minimal, for code that references them at load)
-- ============================================================

RAID_CLASS_COLORS = {
    WARRIOR     = { r = 0.78, g = 0.61, b = 0.43 },
    PALADIN     = { r = 0.96, g = 0.55, b = 0.73 },
    HUNTER      = { r = 0.67, g = 0.83, b = 0.45 },
    ROGUE       = { r = 1.00, g = 0.96, b = 0.41 },
    PRIEST      = { r = 1.00, g = 1.00, b = 1.00 },
    SHAMAN      = { r = 0.00, g = 0.44, b = 0.87 },
    MAGE        = { r = 0.25, g = 0.78, b = 0.92 },
    WARLOCK     = { r = 0.53, g = 0.53, b = 0.93 },
    DRUID       = { r = 1.00, g = 0.49, b = 0.04 },
}

-- WorldFrame stub
WorldFrame = WorldFrame or {}

-- Frame stub for CreateFrame calls
local FrameMethods = {}
FrameMethods.__index = function(t, k)
    local v = rawget(FrameMethods, k)
    if v then return v end
    -- Return no-op for any unimplemented method (SetOwner, SetHyperlink, etc.)
    return function() end
end
function FrameMethods:RegisterEvent() end
function FrameMethods:UnregisterEvent() end
function FrameMethods:SetScript() end
function FrameMethods:HookScript() end
function FrameMethods:Show() end
function FrameMethods:Hide() end
function FrameMethods:IsShown() return false end
function FrameMethods:SetPoint() end
function FrameMethods:SetSize() end
function FrameMethods:SetWidth() end
function FrameMethods:SetHeight() end
function FrameMethods:CreateTexture() return setmetatable({}, FrameMethods) end
function FrameMethods:CreateFontString() return setmetatable({}, FrameMethods) end
function FrameMethods:SetTexture() end
function FrameMethods:SetText() end
function FrameMethods:SetFont() end
function FrameMethods:SetBackdrop() end
function FrameMethods:SetBackdropColor() end
function FrameMethods:SetBackdropBorderColor() end
function FrameMethods:SetAllPoints() end
function FrameMethods:GetParent() return nil end
function FrameMethods:SetParent() end
function FrameMethods:IsForbidden() return false end
function FrameMethods:GetItem() return nil, nil end
function FrameMethods:AddLine() end
function FrameMethods:AddDoubleLine() end
function FrameMethods:NumLines() return 0 end
function FrameMethods:ClearLines() end
function FrameMethods:SetHyperlink() end
function FrameMethods:GetText() return nil end

function CreateFrame(frameType, name, parent, template)
    local f = setmetatable({}, FrameMethods)
    if name then _G[name] = f end
    return f
end

-- hooksecurefunc stub
function hooksecurefunc(name, fn)
    -- no-op in tests
end

-- LibStub stub
LibStub = function(name, silent)
    if name == "LibDataBroker-1.1" then
        return {
            NewDataObject = function(self, objName, obj) return obj end,
        }
    end
    if name == "LibDBIcon-1.0" then
        return {
            Register = function() end,
        }
    end
    return nil
end

-- StaticPopup stub
StaticPopupDialogs = StaticPopupDialogs or {}
function StaticPopup_Show() end

-- Settings stub
Settings = nil

-- DEFAULT_CHAT_FRAME stub (used by RaidScan.lua)
DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME or { AddMessage = function() end }

-- GetTime stub
GetTime = GetTime or function() return MockWoW._gameTime or 0 end
MockWoW._gameTime = 0

-- WoW's time() maps to Lua's os.time() but is a global in WoW
if not rawget(_G, "time") then
    time = os.time
end

-- GameTooltip stub
GameTooltip = GameTooltip or setmetatable({}, { __index = function() return function() end end })

-- UISpecialFrames
UISpecialFrames = UISpecialFrames or {}

-- GetSpellInfo stub
GetSpellInfo = GetSpellInfo or function() return nil end

-- SendChatMessage stub — captures messages for test verification
MockWoW._sentMessages = {}
function SendChatMessage(msg, chatType, language, target)
    MockWoW._sentMessages[#MockWoW._sentMessages + 1] = {
        msg = msg,
        chatType = chatType,
        language = language,
        target = target,
    }
end

-- EasyMenu stub
function EasyMenu(menuList, menuFrame, anchor, x, y, displayMode)
    -- no-op in tests; we test WhisperIssues directly
end

-- InterfaceOptionsFrame stub
InterfaceOptionsFrame_OpenToCategory = function() end

-- collectgarbage is already in Lua 5.4

-- pcall is already in Lua 5.4

-- ============================================================
-- HELPER: Set up mock inventory items
-- ============================================================

function MockWoW.SetInventory(items)
    MockWoW._inventory = {}
    for slotID, data in pairs(items) do
        MockWoW._inventory[slotID] = data
    end
end

function MockWoW.SetItemInfo(itemID, info)
    MockWoW._itemInfo[itemID] = info
end

function MockWoW.SetInspectUnit(data)
    MockWoW._inspectUnit = data
end

-- ============================================================
-- Helper: set up group members for raid scan tests
function MockWoW.SetGroupMembers(members, isRaid)
    MockWoW._groupMembers = {}
    MockWoW._isInRaid = isRaid or false
    for unitID, data in pairs(members) do
        data.exists = data.exists ~= false
        data.connected = data.connected ~= false
        data.visible = data.visible ~= false
        data.canInspect = data.canInspect ~= false
        MockWoW._groupMembers[unitID] = data
    end
end

-- Helper: set up inspected unit talents
function MockWoW.SetInspectTalents(talents, activeGroup)
    MockWoW._inspectTalents = talents or {}
    MockWoW._inspectActiveTalentGroup = activeGroup or 1
end

-- ============================================================
-- INITIAL LOAD: load addon source files
-- ============================================================

-- Load source files in TOC order (excluding data files and UI files)
dofile("Util.lua")
dofile("Theme.lua")
dofile("ElvUISkin.lua")
dofile("Comparison.lua")
dofile("Wishlist.lua")
dofile("WishlistCompare.lua")
dofile("Character.lua")
dofile("RaidScan.lua")
dofile("Tooltip.lua")
dofile("Core.lua")
