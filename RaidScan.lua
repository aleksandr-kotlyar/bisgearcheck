-- BiSGearCheck RaidScan.lua
-- Raid scan queue, inspect throttling, per-character issue analysis, upgrade generation

BiSGearCheck = BiSGearCheck or {}

-- Scan state
BiSGearCheck.raidScanState = "idle" -- "idle", "scanning", "complete"
BiSGearCheck.raidScanQueue = {}
BiSGearCheck.raidScanIndex = 0
BiSGearCheck.raidScanUnit = nil
BiSGearCheck.raidScanResults = {}
BiSGearCheck.raidScanSkipped = {}
BiSGearCheck.raidScanTimer = 0
BiSGearCheck.raidScanInspectTime = 0
BiSGearCheck.raidScanRosterChanged = false
BiSGearCheck.isRaidScanning = false

-- Collapsed state for raid tab character rows
BiSGearCheck.raidCollapsedChars = {}

-- Scan interval and timeout (seconds)
local SCAN_INTERVAL = 2.0
local INSPECT_TIMEOUT = 5.0

-- Return a copy of `bisItems` filtered down to what should actually count
-- toward rank numbering in the raid scan.
--   * Always drops phase-future items (content that doesn't exist yet).
--   * Always drops items unavailable to the player's faction (RunComparison
--     pre-filters these for Compare; raid scan mirrors that here).
--   * When hideFilteredRanks ("Close Rank Gaps") is on, also drops
--     source-filtered items (PvP, World Boss, Classic zones) so the
--     equipped-item rank tag collapses around them.
function BiSGearCheck:RaidVisibleBisItems(bisItems)
    if not bisItems then return bisItems end
    local phases = BiSGearCheckItemPhases
    local currentPhase = self:GetCurrentGamePhase()
    local hideFiltered = BiSGearCheckSaved and BiSGearCheckSaved.hideFilteredRanks
    local out = {}
    for _, id in ipairs(bisItems) do
        local keep = true
        if phases then
            local p = phases[id] or 1
            if p > currentPhase then keep = false end
        end
        if keep and not self:IsItemAvailableForFaction(id) then
            keep = false
        end
        if keep and hideFiltered and self:IsItemFilteredByRaidSource(id) then
            keep = false
        end
        if keep then out[#out + 1] = id end
    end
    return out
end

-- ============================================================
-- RAID SOURCE FILTERS
-- ============================================================
--
-- Honors the same PvP / World Boss / Classic flags as the Compare tab. If
-- you've turned off World Boss items for your own comparisons, the raid
-- scan shouldn't recommend them either. A separate parallel set of raid
-- flags used to exist (raidIncludePvP / raidIncludeWorldBoss /
-- raidIncludeClassicZones); those are obsolete — MigrateSavedVars wipes
-- them so they don't sit as stale saved state.

function BiSGearCheck:IsItemFilteredByRaidSource(itemID)
    if not BiSGearCheckSaved then return false end
    local sourceInfo = BiSGearCheckSources and BiSGearCheckSources[itemID]

    -- Classic zone filter — also catch items with no source that have
    -- classic-era item IDs (raid-scan-specific heuristic for unknown
    -- low-ID items, since we don't have source info for everything yet).
    if BiSGearCheckSaved.includeClassicZones == false then
        if self:IsClassicZoneItem(itemID) then return true end
        if not sourceInfo or not sourceInfo.source then
            if itemID and itemID < 23500 then return true end
        end
    end

    if not BiSGearCheckSaved.includePvP then
        if sourceInfo then
            if sourceInfo.source == "PvP" then return true end
            -- SourceDB mixes "Vendor", "Vendor & Rep", and occasionally
            -- other source labels for honor/marks/arena items; don't
            -- gate the sourceType check on a specific source value.
            if sourceInfo.sourceType then
                local st = sourceInfo.sourceType
                if st:find("Honor") or st:find("Marks") or st:find("Arena") then
                    return true
                end
            end
        end
    end

    if not BiSGearCheckSaved.includeWorldBoss then
        if sourceInfo and sourceInfo.source == "World Boss" then return true end
    end

    return false
end

-- ============================================================
-- SCAN QUEUE
-- ============================================================

function BiSGearCheck:StartRaidScan()
    local numMembers = GetNumGroupMembers()
    -- DEBUG: allow scan while solo (remove this check for release)
    -- if numMembers == 0 then
    --     self:PrintRaidScanMessage("You are not in a group.")
    --     return
    -- end

    -- Reset state
    self.raidScanState = "scanning"
    self.raidScanIndex = 1
    self.isRaidScanning = true
    self.raidScanRosterChanged = false
    wipe(self.raidScanQueue)
    wipe(self.raidScanResults)
    wipe(self.raidScanSkipped)

    local isRaid = IsInRaid()
    local prefix = isRaid and "raid" or "party"

    -- Build queue of group members (skip self)
    for i = 1, numMembers do
        local unit = prefix .. i
        if UnitExists(unit) and not UnitIsUnit(unit, "player") then
            local name, realm = UnitName(unit)
            if name then
                if not realm or realm == "" then
                    realm = GetRealmName()
                end
                local _, classToken = UnitClass(unit)
                self.raidScanQueue[#self.raidScanQueue + 1] = {
                    unit = unit,
                    name = name,
                    realm = realm,
                    class = classToken,
                    charKey = name .. "-" .. realm,
                }
            end
        end
    end

    -- Include self in results (no inspect needed)
    if self.playerKey then
        -- Prefer a fresh talent-based guess so the scan reflects what the
        -- player is actually playing, ignoring any manual Compare-tab pick.
        -- GuessSpec returns nil when talent data isn't available — in that
        -- case keep the current self.selectedSpec rather than clobbering it
        -- (otherwise AnalyzeCharacter would fall back to specs[1], which
        -- surfaces as the wrong spec on the raid scan header).
        local savedSpec = self.selectedSpec
        local guess = self:GuessSpec()
        if guess then self.selectedSpec = guess end
        self:SnapshotEquippedGear()
        self:AnalyzeCharacter(self.playerKey)
        self.selectedSpec = savedSpec
    end

    if #self.raidScanQueue == 0 then
        self:FinishRaidScan()
        return
    end

    -- Start scanning
    self.raidScanTimer = SCAN_INTERVAL -- fire immediately
    self:RefreshView()
end

function BiSGearCheck:ProcessNextScan()
    if self.raidScanState ~= "scanning" then return end
    if self.raidScanIndex > #self.raidScanQueue then
        self:FinishRaidScan()
        return
    end

    local entry = self.raidScanQueue[self.raidScanIndex]
    local unit = entry.unit

    -- Check if unit is still valid, connected, and in range
    if not UnitExists(unit) or not UnitIsConnected(unit) then
        self.raidScanSkipped[#self.raidScanSkipped + 1] = {
            name = entry.name,
            class = entry.class,
            reason = "Offline",
        }
        self.raidScanIndex = self.raidScanIndex + 1
        self.raidScanTimer = SCAN_INTERVAL -- try next immediately
        self:RefreshView()
        return
    end

    if not UnitIsVisible(unit) or not CanInspect(unit) then
        self.raidScanSkipped[#self.raidScanSkipped + 1] = {
            name = entry.name,
            class = entry.class,
            reason = "Out of range",
        }
        self.raidScanIndex = self.raidScanIndex + 1
        self.raidScanTimer = SCAN_INTERVAL -- try next immediately
        self:RefreshView()
        return
    end

    -- Request inspect (don't set expectingInspect — that's for the normal
    -- inspect path; the raid scan routes via isRaidScanning instead)
    self.raidScanUnit = unit
    self.raidScanInspectTime = GetTime()
    local name = UnitName(unit) or "?"
    self:DebugLog("RaidScan NotifyInspect — unit=" .. unit .. ", name=" .. name .. ", index=" .. self.raidScanIndex .. "/" .. #self.raidScanQueue)
    BiSGearCheckEventFrame:RegisterEvent("INSPECT_READY")
    NotifyInspect(unit)
end

function BiSGearCheck:OnRaidScanInspectReady()
    if self.raidScanState ~= "scanning" then
        self:DebugLog("OnRaidScanInspectReady — SKIPPED (state=" .. tostring(self.raidScanState) .. ")")
        return
    end

    local unit = self.raidScanUnit
    if unit then
        local unitExists = UnitExists(unit)
        local unitName = UnitName(unit) or "nil"
        self:DebugLog("OnRaidScanInspectReady — unit=" .. unit .. ", name=" .. unitName .. ", exists=" .. tostring(unitExists))
        local charKey = self:SnapshotInspectedGearFromUnit(unit)
        if charKey then
            self:DebugLog("OnRaidScanInspectReady — snapshot OK: " .. charKey)
            self:AnalyzeCharacter(charKey)
        else
            self:DebugLog("OnRaidScanInspectReady — snapshot FAILED for " .. unitName)
            -- Snapshot failed (likely no item data returned)
            local entry = self.raidScanQueue[self.raidScanIndex]
            if entry then
                self.raidScanSkipped[#self.raidScanSkipped + 1] = {
                    name = entry.name,
                    class = entry.class,
                    reason = "No gear data",
                }
            end
        end
    else
        -- No raidScanUnit — this INSPECT_READY was not initiated by us
        -- (likely another addon called NotifyInspect). Ignore it entirely.
        self:DebugLog("OnRaidScanInspectReady — no raidScanUnit set, ignoring stale INSPECT_READY")
        return
    end

    BiSGearCheckEventFrame:UnregisterEvent("INSPECT_READY")
    self.raidScanUnit = nil
    self.raidScanIndex = self.raidScanIndex + 1
    self.raidScanTimer = 0 -- wait for SCAN_INTERVAL before next
    self:RefreshView()
end

function BiSGearCheck:OnRaidScanTimeout()
    if self.raidScanState ~= "scanning" then return end
    if not self.raidScanUnit then return end

    local unitName = UnitName(self.raidScanUnit) or "nil"
    self:DebugLog("OnRaidScanTimeout — unit=" .. self.raidScanUnit .. ", name=" .. unitName .. ", elapsed=" .. string.format("%.1f", GetTime() - (self.raidScanInspectTime or 0)) .. "s")
    local entry = self.raidScanQueue[self.raidScanIndex]
    if entry then
        self.raidScanSkipped[#self.raidScanSkipped + 1] = {
            name = entry.name,
            class = entry.class,
            reason = "Inspect timed out",
        }
    end

    BiSGearCheckEventFrame:UnregisterEvent("INSPECT_READY")
    self.raidScanUnit = nil
    self.raidScanIndex = self.raidScanIndex + 1
    self.raidScanTimer = 0
    self:RefreshView()
end

function BiSGearCheck:FinishRaidScan()
    self.raidScanState = "complete"
    self.isRaidScanning = false
    self.raidScanUnit = nil
    BiSGearCheckEventFrame:UnregisterEvent("INSPECT_READY")

    -- Default to all collapsed
    for charKey in pairs(self.raidScanResults) do
        self.raidCollapsedChars[charKey] = true
    end

    -- Save results for persistence across /reload. Pinning the spec to the
    -- scan entry (rather than re-deriving from charData.selectedSpec on
    -- restore) means the UI reports the spec we actually scanned — even if
    -- the player's saved spec later changes (respec, late-arriving talent
    -- data correction, etc.).
    if not BiSGearCheckSaved then BiSGearCheckSaved = { characters = {} } end
    BiSGearCheckSaved.lastRaidScan = {
        time = time(),
        entries = {},
        skipped = {},
        -- charKeys kept for back-compat with older saved data; dropped
        -- once the new `entries` format is written at least once.
        charKeys = nil,
    }
    for charKey, result in pairs(self.raidScanResults) do
        BiSGearCheckSaved.lastRaidScan.entries[#BiSGearCheckSaved.lastRaidScan.entries + 1] = {
            charKey = charKey,
            specKey = result.specKey,
        }
    end
    for _, skip in ipairs(self.raidScanSkipped) do
        BiSGearCheckSaved.lastRaidScan.skipped[#BiSGearCheckSaved.lastRaidScan.skipped + 1] = skip
    end

    self:RefreshView()
end

function BiSGearCheck:CancelRaidScan()
    self.raidScanState = "idle"
    self.isRaidScanning = false
    self.raidScanUnit = nil
    self:RefreshView()
end

function BiSGearCheck:UpdateRaidScanTimer(elapsed)
    if self.raidScanState ~= "scanning" then return end

    -- Check for inspect timeout
    if self.raidScanUnit and (GetTime() - self.raidScanInspectTime) >= INSPECT_TIMEOUT then
        self:OnRaidScanTimeout()
        return
    end

    -- Throttle between inspects (only advance when not waiting on an inspect)
    if not self.raidScanUnit then
        self.raidScanTimer = self.raidScanTimer + elapsed
        if self.raidScanTimer >= SCAN_INTERVAL then
            self.raidScanTimer = 0
            self:ProcessNextScan()
        end
    end
end

function BiSGearCheck:PrintRaidScanMessage(msg)
    DEFAULT_CHAT_FRAME:AddMessage(BiSGearCheck.Theme.hex("chatPrefix") .. "BiSGearCheck:|r " .. msg)
end

-- ============================================================
-- CHARACTER ANALYSIS
-- ============================================================

-- `pinnedSpec` (optional): the spec to analyze against, overriding the
-- character's currently-saved selectedSpec. Used by RestoreLastRaidScan so
-- scans keep the spec they were captured with even if the player's saved
-- spec has since changed (respec, talent-data correction, etc.).
function BiSGearCheck:AnalyzeCharacter(charKey, pinnedSpec)
    local charData = self:GetCharacterData(charKey)
    if not charData or not charData.equipped then return end

    local classToken = charData.class
    if not classToken then return end

    local specKey = pinnedSpec or charData.selectedSpec
    if not specKey then
        local specs = self.ClassSpecs[classToken]
        if specs and #specs > 0 then
            specKey = specs[1].key
        end
    end

    local issues = {}
    local totalIssueCount = 0
    local upgrades = {}

    -- Build BiS rank lookup for this spec. Filter phase-future items so
    -- the rank tag reflects what's actually available now (not shifted
    -- by items the player can't even obtain yet).
    local db = self:GetActiveDB()
    local bisRankBySlot = {}  -- bisRankBySlot[slotName][itemID] = rank
    if db and db[specKey] and db[specKey].slots then
        for sName, bisItems in pairs(db[specKey].slots) do
            bisRankBySlot[sName] = {}
            local visible = self:RaidVisibleBisItems(bisItems)
            for rank, bisID in ipairs(visible) do
                bisRankBySlot[sName][bisID] = rank
            end
        end
    end

    -- Analyze each slot
    for _, slotName in ipairs(self.SlotOrder) do
        local slotItems = charData.equipped[slotName]
        if slotItems then
            for _, item in ipairs(slotItems) do
                local slotIssues = {}

                -- Enchant/gem warnings (existing system)
                if item.link then
                    local warnings = self:GetEquipWarnings(item.link, slotName, specKey)
                    for _, warn in ipairs(warnings) do
                        slotIssues[#slotIssues + 1] = warn
                        totalIssueCount = totalIssueCount + 1
                    end
                end

                -- BiS rank for this item
                local bisRank
                if item.id and bisRankBySlot[slotName] then
                    bisRank = bisRankBySlot[slotName][item.id]
                end

                if #slotIssues > 0 then
                    issues[#issues + 1] = {
                        slotName = slotName,
                        itemID = item.id,
                        itemLink = item.link,
                        warnings = slotIssues,
                        bisRank = bisRank,
                    }
                end
            end
        end

        -- Generate upgrade list for this slot (top 3)
        local slotUpgrades = self:GetSlotUpgrades(charKey, slotName, specKey, 3)
        if slotUpgrades and #slotUpgrades > 0 then
            upgrades[slotName] = slotUpgrades
        end
    end

    self.raidScanResults[charKey] = {
        charKey = charKey,
        specKey = specKey,
        issues = issues,
        issueCount = totalIssueCount,
        upgrades = upgrades,
        bisRankBySlot = bisRankBySlot,  -- consumed by UIRenderRaid to tag worn items
    }
end

-- ============================================================
-- UPGRADE HELPERS
-- ============================================================

-- Get top N upgrades for a slot using the active data source (matches Compare behavior)
function BiSGearCheck:GetSlotUpgrades(charKey, slotName, specKey, maxCount)
    local charData = self:GetCharacterData(charKey)
    if not charData or not charData.equipped then return nil end

    local equippedIDs = {}
    local slotItems = charData.equipped[slotName]
    if slotItems then
        for _, item in ipairs(slotItems) do
            if item.id then equippedIDs[item.id] = true end
        end
    end

    -- Use the active data source only (same as Compare tab)
    local db = self:GetActiveDB()
    local isDualSlot = (slotName == "Rings" or slotName == "Trinkets")
    local candidates = {}
    do
        if db and db[specKey] and db[specKey].slots and db[specKey].slots[slotName] then
            -- Same phase-future filter the rank lookup uses — keeps
            -- upgrade rank numbers aligned with the equipped-item tag.
            local bisItems = self:RaidVisibleBisItems(db[specKey].slots[slotName])

            -- Find the best equipped rank on this BiS list (for cutoff)
            local bestEquippedRank = 999
            for rank, bisID in ipairs(bisItems) do
                if equippedIDs[bisID] and rank < bestEquippedRank then
                    bestEquippedRank = rank
                end
            end

            -- For single slots, only consider items ranked above equipped
            -- For dual slots (Rings/Trinkets), consider all items
            local cutoff
            if isDualSlot then
                cutoff = #bisItems + 1
            else
                cutoff = bestEquippedRank
                if cutoff == 999 then cutoff = #bisItems + 1 end
            end

            for rank = 1, math.min(cutoff - 1, #bisItems) do
                local itemID = bisItems[rank]
                if not equippedIDs[itemID]
                    and self:IsItemAvailableForFaction(itemID)
                    and not self:IsItemFilteredByRaidSource(itemID)
                    and self:ItemInPhase(itemID, self.phaseFilter) then
                    if not candidates[itemID] then
                        local sourceInfo = BiSGearCheckSources and BiSGearCheckSources[itemID]
                        candidates[itemID] = {
                            id = itemID,
                            rank = rank,
                            source = sourceInfo and sourceInfo.source or "Unknown",
                            sourceType = sourceInfo and sourceInfo.sourceType or "",
                            slotName = slotName,
                        }
                    end
                end
            end
        end
    end

    -- Convert to array and sort by rank (lower = better)
    local result = {}
    for _, upgrade in pairs(candidates) do
        result[#result + 1] = upgrade
    end
    table.sort(result, function(a, b) return a.rank < b.rank end)

    -- Trim to maxCount
    if maxCount and #result > maxCount then
        for i = maxCount + 1, #result do
            result[i] = nil
        end
    end

    -- Request item data for any uncached items
    for _, upgrade in ipairs(result) do
        local name = GetItemInfo(upgrade.id)
        if not name and not self.pendingItems[upgrade.id] then
            self.pendingItems[upgrade.id] = true
            C_Item.RequestLoadItemDataByID(upgrade.id)
        end
    end

    return result
end

-- ============================================================
-- RESTORE LAST SCAN
-- ============================================================

-- Re-analyze saved raid scan results (called after /reload). Each entry
-- carries its pinned specKey from scan time so restored analyses use the
-- spec we told the user when they ran the scan, not whatever is in the
-- character record today.
function BiSGearCheck:RestoreLastRaidScan()
    if not BiSGearCheckSaved or not BiSGearCheckSaved.lastRaidScan then return end

    local lastScan = BiSGearCheckSaved.lastRaidScan
    wipe(self.raidScanResults)

    -- Prefer the new `entries` format (pinned specs); fall back to the old
    -- `charKeys` shape so saved scans from older versions still restore.
    if lastScan.entries then
        for _, entry in ipairs(lastScan.entries) do
            local charData = self:GetCharacterData(entry.charKey)
            if charData and charData.equipped then
                self:AnalyzeCharacter(entry.charKey, entry.specKey)
            end
        end
    else
        -- Legacy scans predate spec pinning AND the talent/gear guess, so
        -- the recorded spec is often just the class's first spec. Re-guess
        -- from the gear snapshot instead of trusting the stale record —
        -- except the player's own character, whose choice is authoritative.
        for _, charKey in ipairs(lastScan.charKeys or {}) do
            local charData = self:GetCharacterData(charKey)
            if charData and charData.equipped then
                local guess
                if charKey ~= self.playerKey then
                    guess = self:GuessSpecFromGear(charData.class, charData.equipped)
                end
                self:AnalyzeCharacter(charKey, guess)
            end
        end
    end

    -- Restore skipped list
    wipe(self.raidScanSkipped)
    for _, skip in ipairs(lastScan.skipped or {}) do
        self.raidScanSkipped[#self.raidScanSkipped + 1] = skip
    end

    if next(self.raidScanResults) then
        self.raidScanState = "complete"
        -- Default to all collapsed
        for charKey in pairs(self.raidScanResults) do
            self.raidCollapsedChars[charKey] = true
        end
    end
end

-- ============================================================
-- CSV REPORT EXPORT
-- ============================================================

-- Escape a value for CSV (quote if it contains commas, quotes, or newlines)
local function csvEscape(val)
    if not val then return "" end
    val = tostring(val)
    -- Strip WoW color codes
    val = val:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", "")
    if val:find('[,"\n]') then
        return '"' .. val:gsub('"', '""') .. '"'
    end
    return val
end

-- Get gem names from an item link
local function getGemNames(itemLink)
    if not itemLink then return "" end
    local _, _, gem1, gem2, gem3, gem4 = BiSGearCheck:ParseItemLink(itemLink)
    local gems = {}
    for _, gemID in ipairs({ gem1, gem2, gem3, gem4 }) do
        if gemID and gemID > 0 then
            local name = GetItemInfo(gemID)
            gems[#gems + 1] = name or ("Gem#" .. gemID)
        end
    end
    -- Also count empty sockets from tooltip
    local emptySockets = BiSGearCheck:CountItemSockets(itemLink)
    for i = 1, emptySockets do
        gems[#gems + 1] = "(empty)"
    end
    if #gems == 0 then return "" end
    return table.concat(gems, "; ")
end

-- Get enchant name from an item link (best-effort)
local function getEnchantName(itemLink)
    if not itemLink then return "" end
    local _, enchantID = BiSGearCheck:ParseItemLink(itemLink)
    if not enchantID or enchantID == 0 then return "" end
    -- Try to resolve via BiSGearCheckEnchantLinks
    local linkData = BiSGearCheckEnchantLinks and BiSGearCheckEnchantLinks[enchantID]
    if linkData then
        local linkType, linkID = linkData[1], linkData[2]
        if linkType == "spell" then
            local name = GetSpellInfo(linkID)
            if name then return name end
        elseif linkType == "item" then
            local itemID = linkID
            if linkData.horde and UnitFactionGroup("player") == "Horde" then
                itemID = linkData.horde
            end
            local name = GetItemInfo(itemID)
            if name then return name end
        end
    end
    return "Enchant#" .. enchantID
end

function BiSGearCheck:GenerateRaidScanCSV()
    if not next(self.raidScanResults) then return nil end

    local lines = {}
    -- Header
    lines[#lines + 1] = "Character,Class,Spec,Slot,Equipped Item,Enchant,Gems,Issues,Upgrade #1,Upgrade #2,Upgrade #3"

    local sortedKeys = self:GetSortedRaidScanKeys()
    for _, charKey in ipairs(sortedKeys) do
        local result = self.raidScanResults[charKey]
        local charData = self:GetCharacterData(charKey)
        if result and charData then
            local name = charKey:match("^([^%-]+)") or charKey
            local classToken = charData.class or ""
            local specLabel = ""
            local specs = self.ClassSpecs[classToken]
            if specs and result.specKey then
                for _, s in ipairs(specs) do
                    if s.key == result.specKey then
                        specLabel = s.label
                        break
                    end
                end
            end

            -- Build issue lookup by slot
            local issuesBySlot = {}
            for _, issue in ipairs(result.issues) do
                if not issuesBySlot[issue.slotName] then
                    issuesBySlot[issue.slotName] = {}
                end
                local t = issuesBySlot[issue.slotName]
                for _, w in ipairs(issue.warnings) do
                    t[#t + 1] = w
                end
            end

            for _, slotName in ipairs(self.SlotOrder) do
                local slotItems = charData.equipped and charData.equipped[slotName]
                if slotItems and #slotItems > 0 then
                    for _, item in ipairs(slotItems) do
                        local itemName = ""
                        if item.link then
                            itemName = item.link:match("%[(.-)%]") or ""
                        elseif item.id then
                            local n = GetItemInfo(item.id)
                            itemName = n or ("Item#" .. item.id)
                        end

                        local enchant = getEnchantName(item.link)
                        local gems = getGemNames(item.link)

                        -- Issues for this slot
                        local issueText = ""
                        local slotIssues = issuesBySlot[slotName]
                        if slotIssues and #slotIssues > 0 then
                            issueText = table.concat(slotIssues, "; ")
                        end

                        -- Upgrades for this slot (up to 3)
                        local upg = {"", "", ""}
                        local slotUpgrades = result.upgrades[slotName]
                        if slotUpgrades then
                            for i = 1, math.min(3, #slotUpgrades) do
                                local u = slotUpgrades[i]
                                local uName = GetItemInfo(u.id)
                                local uText = uName or ("Item#" .. u.id)
                                if u.source and u.source ~= "Unknown" then
                                    uText = uText .. " (" .. u.source
                                    if u.sourceType and u.sourceType ~= "" then
                                        uText = uText .. " - " .. u.sourceType
                                    end
                                    uText = uText .. ")"
                                end
                                upg[i] = uText
                            end
                        end

                        lines[#lines + 1] = table.concat({
                            csvEscape(name),
                            csvEscape(classToken),
                            csvEscape(specLabel),
                            csvEscape(slotName),
                            csvEscape(itemName),
                            csvEscape(enchant),
                            csvEscape(gems),
                            csvEscape(issueText),
                            csvEscape(upg[1]),
                            csvEscape(upg[2]),
                            csvEscape(upg[3]),
                        }, ",")
                    end
                end
            end
        end
    end

    return table.concat(lines, "\n")
end

-- Show CSV in a copy-paste popup
function BiSGearCheck:ShowRaidScanExport()
    local csv = self:GenerateRaidScanCSV()
    if not csv then
        self:PrintRaidScanMessage("No scan results to export.")
        return
    end

    -- Create or reuse the export frame
    if not self.exportFrame then
        local ef = CreateFrame("Frame", "BiSGearCheckExportFrame", UIParent, "BackdropTemplate")
        ef:SetSize(600, 400)
        ef:SetPoint("CENTER")
        ef:SetMovable(true)
        ef:EnableMouse(true)
        ef:RegisterForDrag("LeftButton")
        ef:SetScript("OnDragStart", ef.StartMoving)
        ef:SetScript("OnDragStop", ef.StopMovingOrSizing)
        ef:SetClampedToScreen(true)
        BiSGearCheck.Theme.applyBackdrop(ef)
        ef:SetFrameStrata("DIALOG")

        local title = ef:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -14)
        title:SetText("Raid Scan Report (CSV)")

        local closeBtn = CreateFrame("Button", nil, ef, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", -4, -4)

        local hint = ef:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOP", 0, -30)
        hint:SetText("Press Ctrl+A to select all, then Ctrl+C to copy.")
        hint:SetTextColor(0.7, 0.7, 0.7)

        local sf = CreateFrame("ScrollFrame", "BiSGearCheckExportScroll", ef, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 16, -48)
        sf:SetPoint("BOTTOMRIGHT", -34, 14)

        local editBox = CreateFrame("EditBox", "BiSGearCheckExportEditBox", sf)
        editBox:SetMultiLine(true)
        editBox:SetAutoFocus(false)
        editBox:SetFontObject("GameFontHighlightSmall")
        editBox:SetWidth(540)
        editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        sf:SetScrollChild(editBox)

        ef.editBox = editBox
        self.exportFrame = ef
        table.insert(UISpecialFrames, "BiSGearCheckExportFrame")

        -- Apply ElvUI skin to the lazily-created export frame
        self:ApplyElvUISkinToExport()
    end

    self.exportFrame.editBox:SetText(csv)
    self.exportFrame:Show()
    self.exportFrame.editBox:HighlightText()
    self.exportFrame.editBox:SetFocus()
end

-- ============================================================
-- IN-GAME CHAT REPORT (issues only)
-- ============================================================

function BiSGearCheck:PrintRaidIssueReport()
    if not next(self.raidScanResults) then
        self:PrintRaidScanMessage("No scan results to report.")
        return
    end

    local sortedKeys = self:GetSortedRaidScanKeys()
    local totalIssues = 0
    local charsWithIssues = 0

    self:PrintRaidScanMessage("--- Raid Scan Issue Report ---")

    for _, charKey in ipairs(sortedKeys) do
        local result = self.raidScanResults[charKey]
        if result and result.issueCount > 0 then
            charsWithIssues = charsWithIssues + 1
            totalIssues = totalIssues + result.issueCount

            local charData = self:GetCharacterData(charKey)
            local name = charKey:match("^([^%-]+)") or charKey
            local coloredName = charData and self:ClassColor(charData.class, name) or name

            -- Spec label
            local specLabel = ""
            if charData then
                local specs = self.ClassSpecs[charData.class]
                if specs and result.specKey then
                    for _, s in ipairs(specs) do
                        if s.key == result.specKey then
                            specLabel = " (" .. s.label .. ")"
                            break
                        end
                    end
                end
            end

            -- Print character header
            DEFAULT_CHAT_FRAME:AddMessage(string.format(
                "  %s%s %s[%d issue%s]|r",
                coloredName, specLabel,
                BiSGearCheck.Theme.hex("issuesBadge"), result.issueCount, result.issueCount == 1 and "" or "s"
            ))

            -- Print each issue
            for _, issue in ipairs(result.issues) do
                local itemName
                if issue.itemLink then
                    itemName = issue.itemLink
                elseif issue.itemID then
                    local n = GetItemInfo(issue.itemID)
                    itemName = n or ("Item #" .. issue.itemID)
                else
                    itemName = "?"
                end
                -- Strip color codes from warnings for readability
                local warnText = table.concat(issue.warnings, " ")
                DEFAULT_CHAT_FRAME:AddMessage(string.format(
                    "    %s%s:|r %s %s",
                    BiSGearCheck.Theme.hex("slotHeader"), issue.slotName, itemName, warnText
                ))
            end
        end
    end

    if charsWithIssues == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("  " .. BiSGearCheck.Theme.hex("okBadge") .. "No issues found!|r")
    else
        self:PrintRaidScanMessage(string.format(
            "Total: %d issue%s across %d character%s.",
            totalIssues, totalIssues == 1 and "" or "s",
            charsWithIssues, charsWithIssues == 1 and "" or "s"
        ))
    end
end

-- Get count of successfully scanned characters
function BiSGearCheck:GetRaidScanCount()
    local count = 0
    for _ in pairs(self.raidScanResults) do
        count = count + 1
    end
    return count
end

-- ============================================================
-- WHISPER ISSUES TO A CHARACTER
-- ============================================================

-- Send one whisper per slot with issues to the scanned character
-- Strip WoW color escape sequences (|cAARRGGBB ... |r) from a string
local function StripColorCodes(text)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    return text
end

function BiSGearCheck:WhisperIssues(charKey)
    local result = self.raidScanResults[charKey]
    if not result or result.issueCount == 0 then
        self:PrintRaidScanMessage("No issues to whisper.")
        return
    end

    local displayName = charKey:match("^([^%-]+)") or charKey

    for _, issue in ipairs(result.issues) do
        local itemName
        if issue.itemLink then
            itemName = issue.itemLink
        elseif issue.itemID then
            local n = GetItemInfo(issue.itemID)
            itemName = n or ("Item #" .. issue.itemID)
        else
            itemName = "?"
        end

        local warnText = StripColorCodes(table.concat(issue.warnings, " "))
        local msg = string.format("[BiSGearCheck] %s: %s %s",
            issue.slotName, itemName, warnText)
        SendChatMessage(msg, "WHISPER", nil, charKey)
    end

    self:PrintRaidScanMessage(string.format(
        "Whispered %d issue%s to %s.",
        result.issueCount, result.issueCount == 1 and "" or "s", displayName
    ))
end

-- Get sorted list of scanned character keys (by issue count, descending)
function BiSGearCheck:GetSortedRaidScanKeys()
    local keys = {}
    for charKey in pairs(self.raidScanResults) do
        keys[#keys + 1] = charKey
    end
    table.sort(keys, function(a, b)
        local ra = self.raidScanResults[a]
        local rb = self.raidScanResults[b]
        if ra.issueCount ~= rb.issueCount then
            return ra.issueCount > rb.issueCount
        end
        return a < b
    end)
    return keys
end
