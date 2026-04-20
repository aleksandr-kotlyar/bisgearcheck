-- BiSGearCheck Comparison.lua
-- Faction filtering, gear comparison engine

BiSGearCheck = BiSGearCheck or {}

-- Reusable scratch tables (avoid per-call allocation)
local _filteredBuf = {}
local _equippedIDsBuf = {}
local _pairedEquippedBuf = {}

-- ============================================================
-- FACTION FILTERING
-- ============================================================

-- Check if an item is available to the player's faction.
-- Items with a "faction" field in SourceDB are restricted; items without it are available to both.
function BiSGearCheck:IsItemAvailableForFaction(itemID)
    local sourceInfo = BiSGearCheckSources and BiSGearCheckSources[itemID]
    if not sourceInfo or not sourceInfo.faction then
        return true -- no faction tag = available to both
    end
    return sourceInfo.faction == self:GetViewingFaction()
end

-- Filter a BiS item list to only include items available to the player's faction.
-- Uses a reusable buffer to avoid creating a new table each call.
function BiSGearCheck:FilterBisListByFaction(bisItems)
    wipe(_filteredBuf)
    for _, itemID in ipairs(bisItems) do
        if self:IsItemAvailableForFaction(itemID) then
            _filteredBuf[#_filteredBuf + 1] = itemID
        end
    end
    return _filteredBuf
end

-- ============================================================
-- CORE COMPARISON
-- ============================================================

function BiSGearCheck:RunComparison()
    local specKey = self.selectedSpec
    local db = self:GetActiveDB()
    if not specKey or not db or not db[specKey] then
        if self.comparisonResults then
            wipe(self.comparisonResults)
        else
            self.comparisonResults = {}
        end
        return
    end

    local specData = db[specKey]

    -- Reuse the top-level results table
    if not self.comparisonResults then
        self.comparisonResults = {}
    else
        wipe(self.comparisonResults)
    end
    local results = self.comparisonResults

    for _, slotName in ipairs(self.SlotOrder) do
        local bisItems = specData.slots[slotName]
        if bisItems and #bisItems > 0 then
            -- FilterBisListByFaction uses _filteredBuf, so copy results
            -- before the next call overwrites it
            local factionItems = self:FilterBisListByFaction(bisItems)
            if #factionItems > 0 then
                -- Copy filtered items into a stable list for this slot
                local stableItems = {}
                for i = 1, #factionItems do
                    stableItems[i] = factionItems[i]
                end
                local slotResult = self:CompareSlot(slotName, stableItems)
                if slotResult then
                    results[#results + 1] = slotResult
                end
            end
        end
    end

    -- Update gear snapshot for current character after comparison
    if self:IsViewingOwnCharacter() then
        self:SnapshotEquippedGear()
    end
end

function BiSGearCheck:CompareSlot(slotName, bisItems)
    local invSlots = self.SlotToInvSlot[slotName]
    if not invSlots then return nil end

    -- Drop items whose phase is beyond the current game phase. Those are
    -- future content that doesn't exist yet — shouldn't contribute to
    -- ranks, shouldn't appear as upgrades, shouldn't count as filtered.
    local phases = BiSGearCheckItemPhases
    local currentPhase = self:GetCurrentGamePhase()
    if phases then
        local visible = {}
        for _, id in ipairs(bisItems) do
            local p = phases[id] or 1
            if p <= currentPhase then
                visible[#visible + 1] = id
            end
        end
        bisItems = visible
    end

    local isDualSlot = (slotName == "Rings" or slotName == "Trinkets")
    local maxShow = isDualSlot and 10 or nil

    local result = {
        slotName = slotName,
        equipped = {},
        bisItems = bisItems,
        upgrades = {},
        bestEquippedRank = 999,
        worstEquippedRank = 0,
    }

    wipe(_equippedIDsBuf)
    wipe(_pairedEquippedBuf)

    local pairedSlot = self.DualWieldPair and self.DualWieldPair[slotName]
    local pairedInvSlots = pairedSlot and self.SlotToInvSlot[pairedSlot] or nil

    if self:IsViewingOwnCharacter() then
        -- Live equipped gear from the current character
        for _, invSlotID in ipairs(invSlots) do
            local itemID = GetInventoryItemID("player", invSlotID)
            local itemLink = GetInventoryItemLink("player", invSlotID)
            if itemID then
                result.equipped[#result.equipped + 1] = {
                    id = itemID,
                    link = itemLink,
                    invSlot = invSlotID,
                }
                _equippedIDsBuf[itemID] = true
            end
        end
        if pairedInvSlots then
            for _, invSlotID in ipairs(pairedInvSlots) do
                local itemID = GetInventoryItemID("player", invSlotID)
                if itemID then _pairedEquippedBuf[itemID] = true end
            end
        end
    else
        -- Snapshot data from another character
        local charData = self:GetViewingCharData()
        if charData and charData.equipped and charData.equipped[slotName] then
            for _, eqInfo in ipairs(charData.equipped[slotName]) do
                result.equipped[#result.equipped + 1] = {
                    id = eqInfo.id,
                    link = eqInfo.link,
                    invSlot = eqInfo.invSlot,
                }
                _equippedIDsBuf[eqInfo.id] = true
            end
        end
        if pairedSlot and charData and charData.equipped and charData.equipped[pairedSlot] then
            for _, eqInfo in ipairs(charData.equipped[pairedSlot]) do
                _pairedEquippedBuf[eqInfo.id] = true
            end
        end
    end

    for _, eq in ipairs(result.equipped) do
        eq.rank = nil
        for rank, bisID in ipairs(bisItems) do
            if bisID == eq.id then
                eq.rank = rank
                if rank < result.bestEquippedRank then
                    result.bestEquippedRank = rank
                end
                if rank > result.worstEquippedRank then
                    result.worstEquippedRank = rank
                end
                break
            end
        end
    end

    local cutoff
    if isDualSlot then
        -- worstEquippedRank starts at 0; 0 means no equipped item was found in BiS.
        cutoff = result.worstEquippedRank
        if cutoff == 0 then cutoff = #bisItems + 1 end
    else
        cutoff = result.bestEquippedRank
        if cutoff == 999 then cutoff = #bisItems + 1 end
    end

    local hideFiltered = BiSGearCheckSaved and BiSGearCheckSaved.hideFilteredRanks and true or false

    -- When hiding filtered ranks, compute raw→effective rank map so the
    -- display can show e.g. an equipped #2 as "BiS" when the #1 is filtered.
    local rawToEffective
    if hideFiltered then
        rawToEffective = {}
        local eff = 0
        for rank = 1, #bisItems do
            if not self:GetItemFilterReason(bisItems[rank], self.zoneFilter) then
                eff = eff + 1
                rawToEffective[rank] = eff
            end
        end
        for _, eq in ipairs(result.equipped) do
            if eq.rank then eq.effectiveRank = rawToEffective[eq.rank] end
        end
    end

    local shown = 0
    for rank = 1, math.min(cutoff - 1, #bisItems) do
        if maxShow and shown >= maxShow then break end
        local bisID = bisItems[rank]
        -- Skip if equipped in this slot, already equipped in the dual-wield
        -- paired slot (unique 1H weapons), or filtered by a user-enabled
        -- category (phase/zone/PvP/etc.) when "skip filtered ranks" is on.
        local skipThisItem = _equippedIDsBuf[bisID] or _pairedEquippedBuf[bisID]
        if not skipThisItem and hideFiltered
           and self:GetItemFilterReason(bisID, self.zoneFilter) then
            skipThisItem = true
        end
        if not skipThisItem then
            local name, link, quality, _, _, _, _, _, _, icon = GetItemInfo(bisID)
            if not name and not self.pendingItems[bisID] then
                self.pendingItems[bisID] = true
                C_Item.RequestLoadItemDataByID(bisID)
            end

            local sourceInfo = BiSGearCheckSources and BiSGearCheckSources[bisID]
            result.upgrades[#result.upgrades + 1] = {
                id = bisID,
                rank = rank,
                effectiveRank = rawToEffective and rawToEffective[rank] or nil,
                name = name,
                link = link,
                quality = quality,
                icon = icon,
                source = sourceInfo and sourceInfo.source or "Unknown",
                sourceType = sourceInfo and sourceInfo.sourceType or "",
                slotName = slotName,
            }
            shown = shown + 1
        end
    end

    return result
end
