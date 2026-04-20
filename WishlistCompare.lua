-- BiSGearCheck WishlistCompare.lua
-- Lets a wishlist act as a data source, alongside published datasets.
--
-- Per-wishlist Addon + Tooltip flags reuse `BiSGearCheckSaved.sourceSettings`
-- (the same table published sources use) keyed by a synthetic source key of
-- the form `wishlist:<charKey>|<wishlistName>`. So a compare-enabled
-- wishlist participates in IsSourceEnabled / IsTooltipSourceEnabled checks
-- and surfaces as a row in the Data Sources settings table, with no
-- parallel flag storage.
--
-- The "Enable Compare" checkbox on the Wishlists tab flips both flags at
-- once (on → both true; off → both false). The Data Sources table lets the
-- user tweak them independently afterward.

BiSGearCheck = BiSGearCheck or {}

local WISHLIST_SOURCE_PREFIX = "wishlist:"
-- Char key is "Name-Realm" (no "|"); we use "|" as the internal separator
-- so wishlist names can include anything else the UI allows.
local WISHLIST_KEY_SEP = "|"

-- ============================================================
-- SOURCE KEY CONVENTIONS
-- ============================================================

function BiSGearCheck:MakeWishlistSourceKey(charKey, wishlistName)
    return WISHLIST_SOURCE_PREFIX .. charKey .. WISHLIST_KEY_SEP .. wishlistName
end

function BiSGearCheck:IsWishlistSourceKey(sourceKey)
    return type(sourceKey) == "string"
        and sourceKey:sub(1, #WISHLIST_SOURCE_PREFIX) == WISHLIST_SOURCE_PREFIX
end

function BiSGearCheck:ParseWishlistSourceKey(sourceKey)
    if not self:IsWishlistSourceKey(sourceKey) then return nil end
    local rest = sourceKey:sub(#WISHLIST_SOURCE_PREFIX + 1)
    local sep = rest:find(WISHLIST_KEY_SEP, 1, true)
    if not sep then return nil end
    return rest:sub(1, sep - 1), rest:sub(sep + 1)
end

-- ============================================================
-- FLAG ACCESS (via sourceSettings)
-- ============================================================

local function ensureSettingsFor(self, sourceKey)
    if not BiSGearCheckSaved then BiSGearCheckSaved = { characters = {} } end
    if not BiSGearCheckSaved.sourceSettings then BiSGearCheckSaved.sourceSettings = {} end
    if not BiSGearCheckSaved.sourceSettings[sourceKey] then
        BiSGearCheckSaved.sourceSettings[sourceKey] = { addon = false, tooltip = false }
    end
    return BiSGearCheckSaved.sourceSettings[sourceKey]
end

-- Set both Addon + Tooltip together. `value` true enables both, false
-- disables both — matches the "Enable Compare" checkbox on the Wishlists
-- tab, which is a single on/off control.
function BiSGearCheck:SetWishlistCompareEnabled(charKey, wishlistName, value)
    if not charKey or not wishlistName then return end
    local key = self:MakeWishlistSourceKey(charKey, wishlistName)
    local s = ensureSettingsFor(self, key)
    s.addon   = value and true or false
    s.tooltip = value and true or false
end

-- The Wishlists-tab checkbox is "checked" if *either* flag is on. Unchecking
-- it turns both off; re-checking turns both on.
function BiSGearCheck:IsWishlistCompareEnabled(charKey, wishlistName)
    if not charKey or not wishlistName then return false end
    local key = self:MakeWishlistSourceKey(charKey, wishlistName)
    local s = BiSGearCheckSaved and BiSGearCheckSaved.sourceSettings and BiSGearCheckSaved.sourceSettings[key]
    if not s then return false end
    return s.addon == true or s.tooltip == true
end

-- Called from RenameWishlist / DeleteWishlist to keep the sourceSettings
-- keys in sync when the wishlist's name changes or goes away.
function BiSGearCheck:RenameWishlistFlags(charKey, oldName, newName)
    if not charKey or not oldName or not newName then return end
    if not BiSGearCheckSaved or not BiSGearCheckSaved.sourceSettings then return end
    local oldKey = self:MakeWishlistSourceKey(charKey, oldName)
    local newKey = self:MakeWishlistSourceKey(charKey, newName)
    local s = BiSGearCheckSaved.sourceSettings[oldKey]
    if s then
        BiSGearCheckSaved.sourceSettings[newKey] = s
        BiSGearCheckSaved.sourceSettings[oldKey] = nil
    end
end

function BiSGearCheck:ClearWishlistFlags(charKey, wishlistName)
    if not charKey or not wishlistName then return end
    if not BiSGearCheckSaved or not BiSGearCheckSaved.sourceSettings then return end
    local key = self:MakeWishlistSourceKey(charKey, wishlistName)
    BiSGearCheckSaved.sourceSettings[key] = nil
end

-- ============================================================
-- SPEC RESOLUTION (inferred default + explicit override)
-- ============================================================
--
-- A wishlist doesn't have its own spec field. For compare purposes we pick
-- exactly one spec so the wishlist shows up once in the spec dropdown, not
-- under every spec of the character's class. Resolution order:
--
--   1. Explicit override stored in sourceSettings[key].spec (set by the
--      dropdown next to Enable Compare on the Wishlists tab).
--   2. Majority specKey across the wishlist's items (items carry specKey
--      as a breadcrumb from when they were added).
--   3. Nil — fall back to exposing under all class specs (empty wishlist).

function BiSGearCheck:InferWishlistSpec(charKey, wishlistName)
    local cd = BiSGearCheckSaved and BiSGearCheckSaved.characters and BiSGearCheckSaved.characters[charKey]
    local wl = cd and cd.wishlists and cd.wishlists[wishlistName]
    if not wl then return nil end
    local counts = {}
    for _, info in pairs(wl) do
        if info and info.specKey then
            counts[info.specKey] = (counts[info.specKey] or 0) + 1
        end
    end
    local best, bestN
    for sk, n in pairs(counts) do
        if not bestN or n > bestN or (n == bestN and sk < best) then
            best, bestN = sk, n
        end
    end
    return best
end

function BiSGearCheck:GetWishlistSpecOverride(charKey, wishlistName)
    if not charKey or not wishlistName then return nil end
    local key = self:MakeWishlistSourceKey(charKey, wishlistName)
    local s = BiSGearCheckSaved and BiSGearCheckSaved.sourceSettings and BiSGearCheckSaved.sourceSettings[key]
    return s and s.spec
end

-- Pass nil to clear the override and fall back to inference.
function BiSGearCheck:SetWishlistSpecOverride(charKey, wishlistName, specKey)
    if not charKey or not wishlistName then return end
    local key = self:MakeWishlistSourceKey(charKey, wishlistName)
    local s = ensureSettingsFor(self, key)
    s.spec = specKey  -- nil clears
end

function BiSGearCheck:GetEffectiveWishlistSpec(charKey, wishlistName)
    local override = self:GetWishlistSpecOverride(charKey, wishlistName)
    if override then return override end
    return self:InferWishlistSpec(charKey, wishlistName)
end

-- ============================================================
-- ENUMERATION
-- ============================================================

-- Every wishlist as a source-like descriptor. `flag` is "addon" or "tooltip"
-- to filter to wishlists enabled for that purpose; pass nil to enumerate
-- wishlists regardless of flag state (used by the settings table so every
-- compare-enabled wishlist gets a row).
--
-- Returns an array:
--   { key, label, category = "wishlist", charKey, charName, class, wishlistName, hasAnyFlag }
local function enumerate(self, flag)
    if not BiSGearCheckSaved or not BiSGearCheckSaved.characters then return {} end
    local out = {}
    local keys = {}
    for k in pairs(BiSGearCheckSaved.characters) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, charKey in ipairs(keys) do
        local cd = BiSGearCheckSaved.characters[charKey]
        if cd.wishlists then
            local names = {}
            for n in pairs(cd.wishlists) do names[#names + 1] = n end
            table.sort(names)
            for _, name in ipairs(names) do
                local sKey = self:MakeWishlistSourceKey(charKey, name)
                local s = BiSGearCheckSaved.sourceSettings and BiSGearCheckSaved.sourceSettings[sKey]
                local include
                if flag == "addon" then
                    include = s and s.addon == true
                elseif flag == "tooltip" then
                    include = s and s.tooltip == true
                else
                    include = s and (s.addon == true or s.tooltip == true)
                end
                if include then
                    local charName = charKey:match("^([^-]+)") or charKey
                    out[#out + 1] = {
                        key          = sKey,
                        label        = charName .. ": " .. name,
                        category     = "wishlist",
                        charKey      = charKey,
                        charName     = charName,
                        class        = cd.class,
                        wishlistName = name,
                    }
                end
            end
        end
    end
    return out
end

function BiSGearCheck:GetAddonEnabledWishlists()   return enumerate(self, "addon")   end
function BiSGearCheck:GetTooltipEnabledWishlists() return enumerate(self, "tooltip") end
function BiSGearCheck:GetAllEnabledWishlists()     return enumerate(self, nil)       end

-- Backwards-compat alias used by the compare source dropdown.
function BiSGearCheck:GetCompareEnabledWishlists()
    return self:GetAddonEnabledWishlists()
end

-- ============================================================
-- VIRTUAL DB
-- ============================================================

function BiSGearCheck:WishlistSpecLabel(specKey)
    if not specKey or not self.ClassSpecs then return specKey or "" end
    for _, classSpecs in pairs(self.ClassSpecs) do
        for _, spec in ipairs(classSpecs) do
            if spec.key == specKey then return spec.label end
        end
    end
    return specKey
end

-- Build a DB-shaped table from a wishlist. All items are used regardless of
-- which spec was active when they were added. Which spec the wishlist is
-- exposed under in the compare spec dropdown is resolved by
-- GetEffectiveWishlistSpec (explicit override → inferred majority → fall
-- back to every class spec for empty wishlists).
function BiSGearCheck:BuildWishlistDB(charKey, wishlistName)
    local cd = BiSGearCheckSaved and BiSGearCheckSaved.characters and BiSGearCheckSaved.characters[charKey]
    local wl = cd and cd.wishlists and cd.wishlists[wishlistName]
    if not wl then return nil end

    local bySlot = {}
    for itemID, info in pairs(wl) do
        local slot = info and info.slotName
        if slot then
            bySlot[slot] = bySlot[slot] or {}
            table.insert(bySlot[slot], { id = itemID, rank = info.rank or 999 })
        end
    end
    local slotMap = {}
    for slot, entries in pairs(bySlot) do
        table.sort(entries, function(a, b) return (a.rank or 999) < (b.rank or 999) end)
        local ids = {}
        for i, e in ipairs(entries) do ids[i] = e.id end
        slotMap[slot] = ids
    end

    local db = {}
    local effective = self:GetEffectiveWishlistSpec(charKey, wishlistName)
    if effective then
        db[effective] = {
            class = cd.class or "UNKNOWN",
            spec  = self:WishlistSpecLabel(effective),
            slots = slotMap,
        }
    else
        -- Empty wishlist with no inferable spec — expose under every spec
        -- of the character's class so the user can still pick anywhere.
        local classSpecs = cd.class and self.ClassSpecs and self.ClassSpecs[cd.class]
        if classSpecs then
            for _, spec in ipairs(classSpecs) do
                db[spec.key] = {
                    class = cd.class,
                    spec  = spec.label,
                    slots = slotMap,
                }
            end
        end
    end
    return db
end
