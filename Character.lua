-- BiSGearCheck Character.lua
-- Character key helper, saved variable migration, character registry, viewing character helpers

BiSGearCheck = BiSGearCheck or {}

-- ============================================================
-- WEAPON SLOT DEDUPLICATION
-- ============================================================
-- Main Hand and Twohand both map to inventory slot 16.
-- After snapshotting, clear the slot that doesn't match the item type.

local function DeduplicateWeaponSlots(equipped)
    local mhItems = equipped["Main Hand"]
    local thItems = equipped["Twohand"]
    if not mhItems or not thItems then return end
    -- Both slots will have the same item(s) from inv slot 16
    -- Use GetItemInfo to check if it's a 2H weapon
    if mhItems[1] and mhItems[1].id then
        local _, _, _, _, _, _, _, _, invType = GetItemInfo(mhItems[1].id)
        if invType == "INVTYPE_2HWEAPON" then
            wipe(equipped["Main Hand"])
        else
            wipe(equipped["Twohand"])
        end
    end
end

-- ============================================================
-- CHARACTER KEY HELPER
-- ============================================================

function BiSGearCheck:GetCharacterKey()
    local name = UnitName("player")
    local realm = GetRealmName()
    if name and realm then
        return name .. "-" .. realm
    end
    return nil
end

-- ============================================================
-- SAVED VARIABLE MIGRATION
-- ============================================================

function BiSGearCheck:MigrateSavedVars()
    -- Initialize account-wide saved vars if needed
    if not BiSGearCheckSaved then
        BiSGearCheckSaved = { characters = {} }
    end

    -- Detect old format: wishlists at top level (pre-2.1.0)
    if BiSGearCheckSaved.wishlists or BiSGearCheckSaved.wishlist then
        local oldWishlists = BiSGearCheckSaved.wishlists

        -- Handle even older single-wishlist format
        if BiSGearCheckSaved.wishlist and not oldWishlists then
            oldWishlists = { ["Default"] = BiSGearCheckSaved.wishlist }
        end

        if not oldWishlists then
            oldWishlists = { ["Default"] = {} }
        end

        -- Move per-character settings to BiSGearCheckChar
        if not BiSGearCheckChar then
            BiSGearCheckChar = {}
        end
        BiSGearCheckChar.selectedSpec = BiSGearCheckChar.selectedSpec or BiSGearCheckSaved.selectedSpec
        BiSGearCheckChar.dataSource = BiSGearCheckChar.dataSource or BiSGearCheckSaved.dataSource
        BiSGearCheckChar.wishlistAutoFilter = BiSGearCheckChar.wishlistAutoFilter or BiSGearCheckSaved.wishlistAutoFilter

        -- Move wishlists to character registry
        if not BiSGearCheckSaved.characters then
            BiSGearCheckSaved.characters = {}
        end

        local charKey = self:GetCharacterKey()
        if charKey then
            BiSGearCheckSaved.characters[charKey] = {
                class = select(2, UnitClass("player")),
                faction = UnitFactionGroup("player") or "Alliance",
                wishlists = oldWishlists,
                activeWishlist = BiSGearCheckSaved.activeWishlist or "Default",
            }
        end

        -- Clean up old top-level fields
        BiSGearCheckSaved.wishlists = nil
        BiSGearCheckSaved.wishlist = nil
        BiSGearCheckSaved.activeWishlist = nil
        BiSGearCheckSaved.selectedSpec = nil
        BiSGearCheckSaved.dataSource = nil
        BiSGearCheckSaved.wishlistAutoFilter = nil
    end

    -- Ensure characters table exists
    if not BiSGearCheckSaved.characters then
        BiSGearCheckSaved.characters = {}
    end

    -- Ensure character filter settings exist
    if BiSGearCheckSaved.minCharLevel == nil then
        BiSGearCheckSaved.minCharLevel = 70
    end
    if not BiSGearCheckSaved.ignoredCharacters then
        BiSGearCheckSaved.ignoredCharacters = {}
    end

    -- Ensure per-character vars exist
    if not BiSGearCheckChar then
        BiSGearCheckChar = {}
    end

    -- Raid scan used to have its own parallel filter flags; they now share
    -- the Compare-tab flags. Drop the obsolete keys so they don't linger.
    BiSGearCheckSaved.raidIncludeClassicZones = nil
    BiSGearCheckSaved.raidIncludePvP          = nil
    BiSGearCheckSaved.raidIncludeWorldBoss    = nil
end

-- ============================================================
-- CHARACTER REGISTRY
-- ============================================================

function BiSGearCheck:RegisterCharacter()
    local charKey = self.playerKey
    if not charKey then return end

    -- Check ignore list — ignored characters are not registered or updated
    if self:IsCharacterIgnored(charKey) then return end

    -- Check minimum level threshold — characters below it are not registered
    local playerLevel = UnitLevel("player") or 0
    local minLevel = BiSGearCheckSaved.minCharLevel or 70
    if playerLevel < minLevel then return end

    if not BiSGearCheckSaved.characters[charKey] then
        BiSGearCheckSaved.characters[charKey] = {
            class = select(2, UnitClass("player")),
            faction = self.playerFaction,
            level = playerLevel,
            wishlists = { ["Default"] = {} },
            activeWishlist = "Default",
        }
    else
        -- Update class/faction/level in case of changes
        local charData = BiSGearCheckSaved.characters[charKey]
        charData.class = select(2, UnitClass("player"))
        charData.faction = self.playerFaction
        charData.level = playerLevel
    end

    -- Snapshot equipped gear for cross-character viewing
    self:SnapshotEquippedGear()
end

-- Save current equipped item IDs so other characters can view this character's gear
function BiSGearCheck:SnapshotEquippedGear()
    -- Don't snapshot ignored characters
    if self:IsCharacterIgnored(self.playerKey) then return end

    local charData = self:GetCharacterData(self.playerKey)
    if not charData then return end

    local equipped = {}
    for slotName, invSlots in pairs(self.SlotToInvSlot) do
        equipped[slotName] = {}
        for _, invSlotID in ipairs(invSlots) do
            local itemID = GetInventoryItemID("player", invSlotID)
            local itemLink = GetInventoryItemLink("player", invSlotID)
            if itemID then
                table.insert(equipped[slotName], {
                    id = itemID,
                    link = itemLink,
                    invSlot = invSlotID,
                })
            end
        end
    end
    DeduplicateWeaponSlots(equipped)
    charData.equipped = equipped
    charData.selectedSpec = self.selectedSpec
end

-- ============================================================
-- INSPECT SNAPSHOT
-- ============================================================

-- Capture gear from an inspected player and store as a snapshot character
-- The inspected unit is "target" (you inspect your current target)
function BiSGearCheck:SnapshotInspectedGear(hintUnit)
    -- Use the unit captured from the inspect hook if available and valid,
    -- otherwise fall back to target/mouseover
    local unit
    if hintUnit and UnitExists(hintUnit) and CanInspect(hintUnit) then
        unit = hintUnit
    elseif UnitExists("target") and CanInspect("target") then
        unit = "target"
    elseif UnitExists("mouseover") and CanInspect("mouseover") then
        unit = "mouseover"
    else
        self:DebugLog("SnapshotInspectedGear — no valid unit found (hint=" .. tostring(hintUnit) .. ", target exists=" .. tostring(UnitExists("target")) .. ", mouseover exists=" .. tostring(UnitExists("mouseover")) .. ")")
        return nil
    end
    self:DebugLog("SnapshotInspectedGear — using unit=" .. unit .. " (hint was " .. tostring(hintUnit) .. ")")

    -- Don't capture self-inspections
    if UnitIsUnit(unit, "player") then
        self:DebugLog("SnapshotInspectedGear — self-inspection via " .. unit)
        return nil
    end

    local name, realm = UnitName(unit)
    if not name then return nil end
    if not realm or realm == "" then
        realm = GetRealmName()
    end
    local charKey = name .. "-" .. realm

    -- Double-check: don't overwrite own character data
    if charKey == self.playerKey then return nil end

    local _, classToken = UnitClass(unit)
    local level = UnitLevel(unit) or 0
    local faction = UnitFactionGroup(unit) or self.playerFaction

    -- Build equipped gear snapshot
    local equipped = {}
    local itemCount = 0
    for slotName, invSlots in pairs(self.SlotToInvSlot) do
        equipped[slotName] = {}
        for _, invSlotID in ipairs(invSlots) do
            local itemLink = GetInventoryItemLink(unit, invSlotID)
            if itemLink then
                local itemID = tonumber(itemLink:match("item:(%d+)"))
                if itemID then
                    table.insert(equipped[slotName], {
                        id = itemID,
                        link = itemLink,
                        invSlot = invSlotID,
                    })
                    itemCount = itemCount + 1
                end
            end
        end
    end

    -- Don't save if we got no items (inspect data not ready)
    if itemCount == 0 then return nil end

    DeduplicateWeaponSlots(equipped)

    -- Store or update character entry
    if not BiSGearCheckSaved.characters[charKey] then
        BiSGearCheckSaved.characters[charKey] = {
            class = classToken,
            faction = faction,
            level = level,
            wishlists = { ["Default"] = {} },
            activeWishlist = "Default",
            inspected = true,
        }
    else
        local charData = BiSGearCheckSaved.characters[charKey]
        charData.class = classToken
        charData.faction = faction
        charData.level = level
        charData.inspected = true
    end

    BiSGearCheckSaved.characters[charKey].equipped = equipped

    -- Guess spec from gear (not talents — inspect talent data may be stale
    -- on this path since we don't know if INSPECT_READY just fired)
    if not BiSGearCheckSaved.characters[charKey].selectedSpec then
        local specs = self.ClassSpecs[classToken]
        if specs and #specs > 0 then
            BiSGearCheckSaved.characters[charKey].selectedSpec = specs[1].key
        end
    end

    return charKey
end

-- Snapshot gear for a specific unit (used by raid scan where we already know the unit)
function BiSGearCheck:SnapshotInspectedGearFromUnit(unit)
    if not unit or not UnitExists(unit) then
        self:DebugLog("SnapshotFromUnit — unit invalid (unit=" .. tostring(unit) .. ", exists=" .. tostring(unit and UnitExists(unit)) .. ")")
        return nil
    end
    if UnitIsUnit(unit, "player") then return nil end

    local name, realm = UnitName(unit)
    if not name then return nil end
    if not realm or realm == "" then
        realm = GetRealmName()
    end
    local charKey = name .. "-" .. realm
    if charKey == self.playerKey then return nil end

    local _, classToken = UnitClass(unit)
    local level = UnitLevel(unit) or 0
    local faction = UnitFactionGroup(unit) or self.playerFaction

    -- Build equipped gear snapshot
    local equipped = {}
    local itemCount = 0
    for slotName, invSlots in pairs(self.SlotToInvSlot) do
        equipped[slotName] = {}
        for _, invSlotID in ipairs(invSlots) do
            local itemLink = GetInventoryItemLink(unit, invSlotID)
            if itemLink then
                local itemID = tonumber(itemLink:match("item:(%d+)"))
                if itemID then
                    table.insert(equipped[slotName], {
                        id = itemID,
                        link = itemLink,
                        invSlot = invSlotID,
                    })
                    itemCount = itemCount + 1
                end
            end
        end
    end

    if itemCount == 0 then return nil end

    DeduplicateWeaponSlots(equipped)

    if not BiSGearCheckSaved.characters[charKey] then
        BiSGearCheckSaved.characters[charKey] = {
            class = classToken,
            faction = faction,
            level = level,
            wishlists = { ["Default"] = {} },
            activeWishlist = "Default",
            inspected = true,
        }
    else
        local charData = BiSGearCheckSaved.characters[charKey]
        charData.class = classToken
        charData.faction = faction
        charData.level = level
        charData.inspected = true
    end

    BiSGearCheckSaved.characters[charKey].equipped = equipped

    -- Guess spec from equipped gear vs BiS lists
    BiSGearCheckSaved.characters[charKey].selectedSpec =
        self:GuessSpecFromGear(classToken, equipped)

    return charKey
end

-- Check if a character is an inspected snapshot
function BiSGearCheck:IsInspectedCharacter(charKey)
    local charData = self:GetCharacterData(charKey)
    return charData and charData.inspected == true
end

-- Remove an inspected character from saved data
function BiSGearCheck:RemoveInspectedCharacter(charKey)
    if not BiSGearCheckSaved or not BiSGearCheckSaved.characters then return end
    -- Never delete own character
    if charKey == self.playerKey then return end
    local charData = BiSGearCheckSaved.characters[charKey]
    if charData and charData.inspected then
        BiSGearCheckSaved.characters[charKey] = nil
        -- If we were viewing this character, switch back to self
        if self.viewingCharKey == charKey then
            self:SetViewingCharacter(self.playerKey)
        end
    end
end

-- Get character data (for any character on the account)
function BiSGearCheck:GetCharacterData(charKey)
    if not charKey or not BiSGearCheckSaved or not BiSGearCheckSaved.characters then
        return nil
    end
    return BiSGearCheckSaved.characters[charKey]
end

-- Get sorted list of visible character keys (filtered by level threshold and ignore list)
function BiSGearCheck:GetCharacterKeys()
    local keys = {}
    if BiSGearCheckSaved and BiSGearCheckSaved.characters then
        local minLevel = BiSGearCheckSaved.minCharLevel or 70
        local showInspected = BiSGearCheckSaved.showInspectedInDropdown ~= false
        for key, charData in pairs(BiSGearCheckSaved.characters) do
            local dominated = self:IsCharacterIgnored(key)
            if not dominated and (charData.level or 70) >= minLevel then
                if charData.inspected and not showInspected then
                    -- skip inspected characters when setting is off
                else
                    table.insert(keys, key)
                end
            end
        end
    end
    table.sort(keys)
    return keys
end

-- Get sorted list of ALL character keys (unfiltered, for settings UI)
function BiSGearCheck:GetAllCharacterKeys()
    local keys = {}
    if BiSGearCheckSaved and BiSGearCheckSaved.characters then
        for key in pairs(BiSGearCheckSaved.characters) do
            table.insert(keys, key)
        end
    end
    table.sort(keys)
    return keys
end

-- ============================================================
-- CHARACTER FILTER HELPERS
-- ============================================================

-- Check if a character is on the ignore list
function BiSGearCheck:IsCharacterIgnored(charKey)
    if not BiSGearCheckSaved or not BiSGearCheckSaved.ignoredCharacters then
        return false
    end
    return BiSGearCheckSaved.ignoredCharacters[charKey] == true
end

-- Add a character to the ignore list
function BiSGearCheck:IgnoreCharacter(charKey)
    if not BiSGearCheckSaved then return end
    if not BiSGearCheckSaved.ignoredCharacters then
        BiSGearCheckSaved.ignoredCharacters = {}
    end
    BiSGearCheckSaved.ignoredCharacters[charKey] = true
end

-- Remove a character from the ignore list
function BiSGearCheck:UnignoreCharacter(charKey)
    if not BiSGearCheckSaved or not BiSGearCheckSaved.ignoredCharacters then return end
    BiSGearCheckSaved.ignoredCharacters[charKey] = nil
end

-- Get the character key we're currently viewing wishlists for
function BiSGearCheck:GetViewingCharKey()
    return self.viewingCharKey or self.playerKey
end

-- Switch which character the entire UI operates as
function BiSGearCheck:SetViewingCharacter(charKey)
    local charData = self:GetCharacterData(charKey)
    if not charData then return end

    self.viewingCharKey = charKey

    -- Switch wishlist context
    self.activeWishlist = charData.activeWishlist or "Default"
    if not charData.wishlists[self.activeWishlist] then
        for name in pairs(charData.wishlists) do
            self.activeWishlist = name
            break
        end
    end

    -- Switch spec context to the viewed character's spec/class
    if charKey == self.playerKey then
        -- Viewing own character — restore per-character spec
        self.selectedSpec = BiSGearCheckChar.selectedSpec or self:GuessSpec()
    else
        -- Viewing another character — use their last-known spec
        self.selectedSpec = charData.selectedSpec
        -- If their spec is unknown, pick the first available for their class
        if not self.selectedSpec then
            local specs = self.ClassSpecs[charData.class]
            if specs then
                self.selectedSpec = specs[1].key
            end
        end
    end

    self:Refresh()
end

-- Get the class token for the character we're currently viewing
function BiSGearCheck:GetViewingClass()
    local charKey = self:GetViewingCharKey()
    if charKey == self.playerKey then
        return select(2, UnitClass("player"))
    end
    local charData = self:GetCharacterData(charKey)
    return charData and charData.class
end

-- Get the faction for the character we're currently viewing
function BiSGearCheck:GetViewingFaction()
    local charKey = self:GetViewingCharKey()
    if charKey == self.playerKey then
        return self.playerFaction
    end
    local charData = self:GetCharacterData(charKey)
    return charData and charData.faction or "Alliance"
end

-- Check if viewing the currently logged-in character
function BiSGearCheck:IsViewingOwnCharacter()
    return self.viewingCharKey == nil or self.viewingCharKey == self.playerKey
end
