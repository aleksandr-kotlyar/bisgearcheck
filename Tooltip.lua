-- BiSGearCheck Tooltip.lua
-- Injects BiS ranking info into item tooltips using Data.lua

BiSGearCheck = BiSGearCheck or {}

-- Reverse lookup: itemID -> { { specKey, slotName, rank }, ... }
BiSGearCheck.TooltipIndex = {}

-- Build the reverse index from enabled data sources
function BiSGearCheck:BuildTooltipIndex()
    self.TooltipIndex = {}

    local phase = self.phaseFilter or 1

    local function indexDB(db, srcKey, srcLabel)
        if not db then return end
        for specKey, specData in pairs(db) do
            if specData.slots then
                for slotName, items in pairs(specData.slots) do
                    for rank, itemID in ipairs(items) do
                        local id = tostring(itemID)
                        if not self.TooltipIndex[id] then
                            self.TooltipIndex[id] = {}
                        end
                        table.insert(self.TooltipIndex[id], {
                            specKey = specKey,
                            class = specData.class,
                            spec = specData.spec,
                            slot = slotName,
                            rank = rank,
                            source = srcKey,
                            sourceLabel = srcLabel,
                            phase = phase,
                        })
                    end
                end
            end
        end
    end

    for _, src in ipairs(self:GetTooltipDataSources()) do
        local dbName = self:GetSourceDBName(src, phase)
        indexDB(dbName and _G[dbName], src.key, src.label)
    end

    -- Tooltip-enabled wishlists participate the same way — synthesize the
    -- DB on the fly and flow it through the same indexer.
    if self.GetTooltipEnabledWishlists then
        for _, desc in ipairs(self:GetTooltipEnabledWishlists()) do
            indexDB(self:BuildWishlistDB(desc.charKey, desc.wishlistName),
                desc.key, desc.label)
        end
    end
end

-- Settings helpers
function BiSGearCheck:GetTooltipSetting(key)
    if BiSGearCheckSaved and BiSGearCheckSaved.tooltip then
        return BiSGearCheckSaved.tooltip[key]
    end
    return nil
end

function BiSGearCheck:SetTooltipSetting(key, value)
    if not BiSGearCheckSaved then BiSGearCheckSaved = { characters = {} } end
    if not BiSGearCheckSaved.tooltip then
        BiSGearCheckSaved.tooltip = {}
    end
    BiSGearCheckSaved.tooltip[key] = value
end

function BiSGearCheck:EnsureTooltipSettings()
    if not BiSGearCheckSaved then BiSGearCheckSaved = { characters = {} } end
    if not BiSGearCheckSaved.tooltip then
        BiSGearCheckSaved.tooltip = {}
    end
    local t = BiSGearCheckSaved.tooltip
    if t.showBiS == nil then t.showBiS = true end
    if t.showOnlyMyClass == nil then t.showOnlyMyClass = false end
end

-- Render BiS info into a tooltip
function BiSGearCheck:OnTooltipSetItem(tooltip)
    if not tooltip or tooltip:IsForbidden() then return end

    self:EnsureTooltipSettings()
    if not BiSGearCheckSaved.tooltip.showBiS then return end

    local _, link = tooltip:GetItem()
    if not link then return end

    local itemID = link:match("item:(%d+)")
    if not itemID or not self.TooltipIndex[itemID] then return end

    local entries = self.TooltipIndex[itemID]
    local _, playerClass = UnitClass("player")
    local filterClass = BiSGearCheckSaved.tooltip.showOnlyMyClass

    -- Skip faction-restricted items unavailable to the player
    local numItemID = tonumber(itemID)
    if numItemID and not self:IsItemAvailableForFaction(numItemID) then
        return
    end

    local currentPhase = self.phaseFilter or 1

    -- Group visible entries by source
    local sourceOrder = {}
    local sourceGroups = {}
    for _, entry in ipairs(entries) do
        local show = true
        if filterClass and entry.class ~= playerClass then
            show = false
        end
        if show then
            if not sourceGroups[entry.source] then
                sourceGroups[entry.source] = { label = entry.sourceLabel, entries = {} }
                sourceOrder[#sourceOrder + 1] = entry.source
            end
            table.insert(sourceGroups[entry.source].entries, entry)
        end
    end

    local anyShown = false
    for _, sourceKey in ipairs(sourceOrder) do
        local group = sourceGroups[sourceKey]

        -- Source header
        local header = "BiSGearCheck (" .. group.label .. ")"
        if currentPhase ~= 1 then
            header = header .. " P" .. currentPhase
        end
        tooltip:AddLine(" ")
        tooltip:AddDoubleLine(
            header,
            "Rank",
            1.0, 0.82, 0.0,
            0, 1, 0.82
        )
        anyShown = true

        for _, entry in ipairs(group.entries) do
            local classColor = RAID_CLASS_COLORS[entry.class]
            if classColor then
                tooltip:AddDoubleLine(
                    entry.spec,
                    entry.rank,
                    classColor.r, classColor.g, classColor.b,
                    classColor.r, classColor.g, classColor.b
                )
            end
        end
    end

    if anyShown then
        tooltip:Show()
    end
end

-- Hook tooltips
function BiSGearCheck:InstallTooltipHooks()
    if self.tooltipHooked then return end
    self.tooltipHooked = true

    local tooltips = {
        "GameTooltip",
        "ItemRefTooltip",
        "ShoppingTooltip1",
        "ShoppingTooltip2",
    }

    for _, name in ipairs(tooltips) do
        local tt = _G[name]
        if tt and tt.HookScript then
            tt:HookScript("OnTooltipSetItem", function(self)
                pcall(function()
                    BiSGearCheck:OnTooltipSetItem(self)
                end)
            end)
        end
    end
end

-- ============================================================
-- CONFLICT DETECTION
-- ============================================================

-- Conflicting addons that also inject BiS data into tooltips
local CONFLICTING_ADDONS = {
    {
        name = "AtlasBIStooltips",
        label = "AtlasBIS Tooltips",
    },
}

-- Static popup dialog definition
StaticPopupDialogs["BISGEARCHECK_TOOLTIP_CONFLICT"] = {
    text = "BiSGearCheck has detected that |cff00ccff%s|r is also adding BiS rankings to item tooltips.\n\nWhich would you like to use?",
    button1 = "BiSGearCheck",
    button2 = "Keep Both",
    button3 = "%s",
    OnAccept = function()
        -- Use BiSGearCheck only — disable the conflicting addon's tooltips
        BiSGearCheck:EnsureTooltipSettings()
        BiSGearCheckSaved.tooltip.showBiS = true
        BiSGearCheckSaved.tooltip.conflictResolved = BiSGearCheck._conflictAddon
        BiSGearCheckSaved.tooltip.conflictChoice = "bisgearcheck"
        -- Disable the other addon's tooltip output
        BiSGearCheck:DisableConflictingTooltips()
        BiSGearCheck:InstallTooltipHooks()
    end,
    OnCancel = function()
        -- Keep both
        BiSGearCheck:EnsureTooltipSettings()
        BiSGearCheckSaved.tooltip.conflictResolved = BiSGearCheck._conflictAddon
        BiSGearCheckSaved.tooltip.conflictChoice = "both"
        BiSGearCheck:InstallTooltipHooks()
    end,
    OnAlt = function()
        -- Use the other addon only — disable BiSGearCheck tooltips
        BiSGearCheck:EnsureTooltipSettings()
        BiSGearCheckSaved.tooltip.showBiS = false
        BiSGearCheckSaved.tooltip.conflictResolved = BiSGearCheck._conflictAddon
        BiSGearCheckSaved.tooltip.conflictChoice = "other"
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = false,
    preferredIndex = 3,
}

function BiSGearCheck:CheckTooltipConflict()
    for _, conflict in ipairs(CONFLICTING_ADDONS) do
        local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded)(conflict.name)
        if loaded then
            -- Check if we already resolved this conflict
            local resolved = BiSGearCheckSaved and BiSGearCheckSaved.tooltip
                and BiSGearCheckSaved.tooltip.conflictResolved == conflict.name

            if resolved then
                -- Apply the previous choice silently
                local choice = BiSGearCheckSaved.tooltip.conflictChoice
                if choice == "bisgearcheck" then
                    self:DisableConflictingTooltips()
                    self:InstallTooltipHooks()
                elseif choice == "both" then
                    self:InstallTooltipHooks()
                elseif choice == "other" then
                    -- Don't install our hooks
                end
            else
                -- Show the dialog
                self._conflictAddon = conflict.name
                -- Set button3 text dynamically
                StaticPopupDialogs["BISGEARCHECK_TOOLTIP_CONFLICT"].button3 = conflict.label
                StaticPopupDialogs["BISGEARCHECK_TOOLTIP_CONFLICT"].text =
                    "BiSGearCheck has detected that |cff00ccff" .. conflict.label ..
                    "|r is also adding BiS rankings to item tooltips.\n\nWhich would you like to use?"
                StaticPopup_Show("BISGEARCHECK_TOOLTIP_CONFLICT")
            end
            return
        end
    end

    -- No conflict — just install hooks
    self:InstallTooltipHooks()
end

-- Disable the conflicting addon's tooltip injection
function BiSGearCheck:DisableConflictingTooltips()
    -- AtlasBIStooltips uses slcDB.showBiS to control its tooltip output
    if _G.slcDB then
        _G.slcDB.showBiS = 0
    end
end
