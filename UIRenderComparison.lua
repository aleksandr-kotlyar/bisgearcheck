-- BiSGearCheck UIRenderComparison.lua
-- RenderResults and RenderSlotSection for the Compare tab

BiSGearCheck = BiSGearCheck or {}
local T = BiSGearCheck.Theme

-- Rank text helper (module-level, not per-call).
-- When hideFilteredRanks is on, CompareSlot sets eq.effectiveRank to the
-- item's rank among unfiltered items — so an equipped #2 with #1 filtered
-- collapses to "BiS!" here without changing the underlying raw rank.
--
-- Dual slots (Rings, Trinkets) have two slots, so the top two BiS picks
-- are both co-BiS — rank 2 there reads as "BiS2!" rather than "Rank 2".
local function rankStr(eq, isDualSlot)
    local r = eq.effectiveRank or eq.rank
    if r then
        if r == 1 then
            return T.hex("rankBis") .. "BiS!|r"
        elseif r == 2 and isDualSlot then
            return T.hex("rankBis") .. "BiS2!|r"
        else
            return string.format(T.hex("rankText") .. "Rank %d|r", r)
        end
    end
    return T.hex("notOnList") .. "Not on list|r"
end

-- ============================================================
-- RENDER COMPARISON RESULTS
-- ============================================================

function BiSGearCheck:RenderResults()
    local f = self.mainFrame
    if not f then return end

    f.filterBar:Hide()
    f.bislistBar:Hide()
    f.wlSelectorBar:Hide()
    if f.raidBar then f.raidBar:Hide() end
    f.compareWLDropdown:ClearAllPoints()
    f.compareWLDropdown:SetPoint("TOPRIGHT", f, "TOPRIGHT", 5, -88)
    f.compareWLDropdown:Show()
    f.compareWLLabel:Show()
    f.collapseAllBtn:ClearAllPoints()
    f.collapseAllBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -94)
    f.collapseAllBtn:Show()
    f.expandAllBtn:ClearAllPoints()
    f.expandAllBtn:SetPoint("LEFT", f.collapseAllBtn, "RIGHT", 5, 0)
    f.expandAllBtn:Show()
    UIDropDownMenu_SetText(f.compareWLDropdown, self.activeWishlist)
    f.sourceDropdown:Show()
    f.specDropdown:Show()
    f.charDropdown:Show()
    if f.charDropdownLabel then f.charDropdownLabel:Show() end
    if f.phaseDropdown then f.phaseDropdown:Hide() end
    -- Position zone filter on the source/spec row, after the spec dropdown
    f.zoneFilterDropdown:ClearAllPoints()
    f.zoneFilterDropdown:SetPoint("TOPRIGHT", f, "TOPRIGHT", 5, -60)
    f.zoneFilterDropdown:Show()
    UIDropDownMenu_SetText(f.zoneFilterDropdown, self.zoneFilter or "All Zones")
    f.UpdateTabAppearance()
    f.scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", self.CONTENT_PADDING, -124)

    local scrollChild = f.scrollChild
    self:ClearScrollContent(scrollChild)

    -- Update character dropdown
    self:UpdateCharDropdownText()

    if self.selectedSpec then
        local db = self:GetActiveDB()
        if db and db[self.selectedSpec] then
            local specData = db[self.selectedSpec]
            local classToken = self:GetViewingClass()
            local classColored = self:ClassColor(classToken, specData.spec)
            f.title:SetText("BiSGearCheck")
            UIDropDownMenu_SetText(f.specDropdown, specData.spec)
        end
    end

    for _, srcInfo in ipairs(self.DataSources) do
        if srcInfo.key == self.dataSource then
            UIDropDownMenu_SetText(f.sourceDropdown, srcInfo.label)
            break
        end
    end

    local yOffset = -5
    local contentWidth = self.FRAME_WIDTH - 45

    for _, slotResult in ipairs(self.comparisonResults) do
        -- When zone filter is active, skip slots with no matching upgrades
        if self.zoneFilter then
            local hasMatch = false
            for _, upgrade in ipairs(slotResult.upgrades) do
                if not self:IsItemFilteredBySource(upgrade.id) and self:ItemMatchesZone(upgrade.id, self.zoneFilter) then
                    hasMatch = true
                    break
                end
            end
            if not hasMatch then
                -- skip this slot entirely
            else
                yOffset = self:RenderSlotSection(scrollChild, slotResult, yOffset, contentWidth)
                yOffset = yOffset - self.SECTION_SPACING
            end
        else
            yOffset = self:RenderSlotSection(scrollChild, slotResult, yOffset, contentWidth)
            yOffset = yOffset - self.SECTION_SPACING
        end
    end

    -- Recommended gems section at bottom
    local specKey = self.selectedSpec
    local gemsData = specKey and BiSGearCheckGemsDB and BiSGearCheckGemsDB[specKey]
    if gemsData then
        local gemHeader = self:CreateRow(scrollChild, yOffset, contentWidth)
        gemHeader.text:SetText(T.hex("gemsHeader") .. "Recommended Gems|r")
        yOffset = yOffset - self.SLOT_HEADER_HEIGHT

        if gemsData.meta then
            local row = self:CreateRow(scrollChild, yOffset, contentWidth)
            row.text:SetText(string.format("  %sMeta:|r %s%s|r", T.hex("gemLabel"), T.hex("gemName"), gemsData.meta[2]))
            row._itemID = gemsData.meta[1]
            row:EnableMouse(true)
            row:SetScript("OnEnter", self.OnItemIDEnter)
            row:SetScript("OnLeave", self.OnTooltipLeave)
            yOffset = yOffset - self.ITEM_ROW_HEIGHT
        end

        for _, color in ipairs({"red", "yellow", "blue"}) do
            local gems = gemsData[color]
            if gems and #gems > 0 then
                local label = color:sub(1,1):upper() .. color:sub(2)
                for _, gem in ipairs(gems) do
                    local row = self:CreateRow(scrollChild, yOffset, contentWidth)
                    row.text:SetText(string.format("  %s%s:|r %s%s|r", T.hex("gemLabel"), label, T.hex("gemName"), gem[2]))
                    row._itemID = gem[1]
                    row:EnableMouse(true)
                    row:SetScript("OnEnter", self.OnItemIDEnter)
                    row:SetScript("OnLeave", self.OnTooltipLeave)
                    yOffset = yOffset - self.ITEM_ROW_HEIGHT
                end
            end
        end

        local sep = self:CreateRow(scrollChild, yOffset, contentWidth)
        local line = self:GetSeparatorLine(sep)
        T.applySeparator(line)
        yOffset = yOffset - 6
    end

    scrollChild:SetHeight(math.abs(yOffset) + 20)
end

-- ============================================================
-- RENDER SLOT SECTION
-- ============================================================

function BiSGearCheck:RenderSlotSection(parent, slotResult, yOffset, width)
    local slotName = slotResult.slotName
    local isCollapsed = self.collapsedSlots[slotName]
    local isDualSlot = (slotName == "Rings" or slotName == "Trinkets")
    local specKey = self.selectedSpec

    local arrow = isCollapsed and (T.hex("slotHeader") .. "[+]|r ") or (T.hex("slotHeader") .. "[-]|r ")

    if not isDualSlot and #slotResult.equipped == 1 then
        -- Single-slot: combine header + equipped on one line
        local eq = slotResult.equipped[1]
        local header = self:CreateRow(parent, yOffset, width)
        local eqLink = eq.link or GetInventoryItemLink("player", eq.invSlot)
        local eqText = eqLink or ("Item #" .. eq.id)
        local warnings, wrongEnchantID = {}, nil
        if eqLink then
            warnings, wrongEnchantID = self:GetEquipWarnings(eqLink, slotName, specKey)
        end
        header.text:SetText(arrow .. T.hex("slotHeader") .. slotName .. ":|r " .. eqText .. " - " .. rankStr(eq, isDualSlot))
        header._slotName = slotName
        header:EnableMouse(true)
        header:SetScript("OnMouseDown", self.OnSlotHeaderClick)
        if eqLink then
            header._itemLink = eqLink
            header:SetScript("OnEnter", self.OnItemLinkEnter)
            header:SetScript("OnLeave", self.OnTooltipLeave)
        end

        -- All warnings pinned to right side of same row
        if #warnings > 0 then
            local warnText = table.concat(warnings, " ")
            header.text:SetPoint("RIGHT", header, "RIGHT", -100, 0)
            local wf, wLabel = self:GetWarningLabel(header)
            wLabel:SetText(warnText)
            wf:SetWidth(wLabel:GetStringWidth() + 8)
            if wrongEnchantID then
                wf._enchantID = wrongEnchantID
                wf._enchantSlot = slotName
                wf:SetScript("OnEnter", self.OnEnchantEnter)
                wf:SetScript("OnLeave", self.OnTooltipLeave)
            end
        end

        yOffset = yOffset - self.SLOT_HEADER_HEIGHT
    elseif not isDualSlot and #slotResult.equipped == 0 then
        -- Single-slot empty: combine header + empty
        local header = self:CreateRow(parent, yOffset, width)
        header.text:SetText(arrow .. T.hex("slotHeader") .. slotName .. ":|r " .. T.hex("emptySlot") .. "(empty)|r")
        header._slotName = slotName
        header:EnableMouse(true)
        header:SetScript("OnMouseDown", self.OnSlotHeaderClick)
        yOffset = yOffset - self.SLOT_HEADER_HEIGHT
    else
        -- Dual-slot: when collapsed, inline both equipped items on the
        -- header so the summary isn't an empty "[+] Rings" row.
        if isCollapsed and #slotResult.equipped > 0 then
            local header = self:CreateRow(parent, yOffset, width)
            local parts = {}
            for _, eq in ipairs(slotResult.equipped) do
                local lateLink = eq.link or GetInventoryItemLink("player", eq.invSlot)
                local eqText = lateLink or ("Item #" .. eq.id)
                parts[#parts + 1] = eqText .. " " .. rankStr(eq, isDualSlot)
            end
            header.text:SetText(arrow .. T.hex("slotHeader") .. slotName .. ":|r "
                .. table.concat(parts, "  "))
            header._slotName = slotName
            header:EnableMouse(true)
            header:SetScript("OnMouseDown", self.OnSlotHeaderClick)
            yOffset = yOffset - self.SLOT_HEADER_HEIGHT
            -- Upgrades section is skipped below via the `not isCollapsed` guard.
            return yOffset
        end

        -- Expanded: header then equipped items on their own rows
        local header = self:CreateRow(parent, yOffset, width)
        header.text:SetText(arrow .. T.hex("slotHeader") .. slotName .. "|r")
        header._slotName = slotName
        header:EnableMouse(true)
        header:SetScript("OnMouseDown", self.OnSlotHeaderClick)
        yOffset = yOffset - self.SLOT_HEADER_HEIGHT

        if not isCollapsed then
            for _, eq in ipairs(slotResult.equipped) do
                local row = self:CreateRow(parent, yOffset, width)
                local lateLink = eq.link or GetInventoryItemLink("player", eq.invSlot)
                local eqText = lateLink or ("Item #" .. eq.id)
                local warnings, wrongEnchantID = {}, nil
                if lateLink then
                    warnings, wrongEnchantID = self:GetEquipWarnings(lateLink, slotName, specKey)
                end
                row.text:SetText("  Equipped: " .. eqText .. " - " .. rankStr(eq, isDualSlot))
                if lateLink then
                    row._itemLink = lateLink
                    row:EnableMouse(true)
                    row:SetScript("OnEnter", self.OnItemLinkEnter)
                    row:SetScript("OnLeave", self.OnTooltipLeave)
                end

                -- All warnings pinned to right side of same row
                if #warnings > 0 then
                    local warnText = table.concat(warnings, " ")
                    row.text:SetPoint("RIGHT", row, "RIGHT", -100, 0)
                    local wf, wLabel = self:GetWarningLabel(row)
                    wLabel:SetText(warnText)
                    wf:SetWidth(wLabel:GetStringWidth() + 8)
                    if wrongEnchantID then
                        wf._enchantID = wrongEnchantID
                        wf._enchantSlot = slotName
                        wf:SetScript("OnEnter", self.OnEnchantEnter)
                        wf:SetScript("OnLeave", self.OnTooltipLeave)
                    end
                end

                yOffset = yOffset - self.ITEM_ROW_HEIGHT
            end

            if #slotResult.equipped == 0 then
                local row = self:CreateRow(parent, yOffset, width)
                row.text:SetText("  " .. T.hex("emptySlot") .. "(empty slots)|r")
                yOffset = yOffset - self.ITEM_ROW_HEIGHT
            end
        end
    end

    if not isCollapsed then
        local shownUpgrades = 0
        local hiddenCounts = {}
        for _, upgrade in ipairs(slotResult.upgrades) do
            local filterReason = self:GetItemFilterReason(upgrade.id, self.zoneFilter)
            -- Phase-future items (itemPhase > currentGamePhase) are dropped
            -- at CompareSlot time, so any Phase reason we see here means
            -- "item exists in-game but user's phase filter narrows past it"
            -- — that's a legitimate user-chosen filter, count it.
            if filterReason then
                hiddenCounts[filterReason] = (hiddenCounts[filterReason] or 0) + 1
            else
            shownUpgrades = shownUpgrades + 1
            local row = self:CreateRow(parent, yOffset, width)

            -- Re-query item info at render time in case it loaded since comparison
            local lateName, lateLink, lateQuality, _, _, _, _, _, _, lateIcon = GetItemInfo(upgrade.id)
            local itemName = lateLink or upgrade.link or lateName or upgrade.name or ("Item #" .. upgrade.id)
            local sourceText = ""
            if upgrade.source and upgrade.source ~= "" and upgrade.source ~= "Unknown" then
                if upgrade.sourceType and upgrade.sourceType ~= "" then
                    sourceText = string.format("%s- %s (%s)|r", T.hex("sourceInfo"), upgrade.source, upgrade.sourceType)
                else
                    sourceText = string.format("%s- %s|r", T.hex("sourceInfo"), upgrade.source)
                end
            end

            local displayRank = upgrade.effectiveRank or upgrade.rank
            row.text:SetText(string.format("  %s#%d|r %s %s", T.hex("rankNum"), displayRank, itemName, sourceText))
            row.text:SetPoint("RIGHT", row, "RIGHT", -30, 0)

            -- Store data on the row for shared handlers
            row._upgrade = upgrade
            row._itemID = upgrade.id

            -- Wishlist + button (reused from pool, shared handlers)
            local onWL = self:IsOnWishlist(upgrade.id)
            local addBtn, btnBg, btnText = self:GetActionButton(row)

            T.applyWishlistBtn(btnBg, onWL)
            btnText:SetText(T.hex("btnText") .. "+|r")

            addBtn:SetScript("OnClick", self.OnWishlistToggleClick)
            addBtn:SetScript("OnEnter", self.OnWishlistToggleEnter)
            addBtn:SetScript("OnLeave", self.OnTooltipLeave)

            -- Item tooltip on hover (shared handler)
            row:EnableMouse(true)
            row:SetScript("OnEnter", self.OnItemIDEnter)
            row:SetScript("OnLeave", self.OnTooltipLeave)

            yOffset = yOffset - self.ITEM_ROW_HEIGHT
            end -- end zone filter else
        end

        local totalHidden = 0
        for _, count in pairs(hiddenCounts) do totalHidden = totalHidden + count end
        if totalHidden > 0 then
            local row = self:CreateRow(parent, yOffset, width)
            row.text:SetText(string.format("  %s%d item%s filtered|r", T.hex("filtered"), totalHidden, totalHidden == 1 and "" or "s"))
            row._hiddenCounts = hiddenCounts
            row:EnableMouse(true)
            row:SetScript("OnEnter", self.OnFilteredRowEnter)
            row:SetScript("OnLeave", self.OnTooltipLeave)
            yOffset = yOffset - self.ITEM_ROW_HEIGHT
        end

        -- Enchant recommendations for this slot
        local enchantSlot = self.SlotToEnchantSlot[slotName]
        local specEnchants = specKey and BiSGearCheckEnchantsDB and BiSGearCheckEnchantsDB[specKey]
        local slotEnchants = enchantSlot and specEnchants and specEnchants[enchantSlot]
        if slotEnchants and #slotEnchants > 0 then
            -- Filter out enchants from the opposing Shattrath faction
            local hasVisible = false
            for _, enchant in ipairs(slotEnchants) do
                if not self:IsWrongShattFaction(enchant[1]) then
                    hasVisible = true
                    break
                end
            end

            if hasVisible then
                local enchHeader = self:CreateRow(parent, yOffset, width)
                enchHeader.text:SetText("  " .. T.hex("enchantLabel") .. "Enchants:|r")
                yOffset = yOffset - self.ITEM_ROW_HEIGHT

                for _, enchant in ipairs(slotEnchants) do
                    if not self:IsWrongShattFaction(enchant[1]) then
                        local row = self:CreateRow(parent, yOffset, width)
                        row.text:SetText(string.format("    %s%s|r", T.hex("enchantName"), enchant[2]))
                        local lf = self:GetLinkFrame(row)
                        lf._enchantID = enchant[1]
                        lf._enchantSpellOverride = enchant[3]  -- optional spell ID for tooltip
                        lf:SetScript("OnEnter", self.OnEnchantEnter)
                        lf:SetScript("OnLeave", self.OnTooltipLeave)
                        yOffset = yOffset - self.ITEM_ROW_HEIGHT
                    end
                end
            end
        end
    end

    -- Separator (reused from pool)
    local sep = self:CreateRow(parent, yOffset, width)
    local line = self:GetSeparatorLine(sep)
    T.applySeparator(line)
    yOffset = yOffset - 6

    return yOffset
end
