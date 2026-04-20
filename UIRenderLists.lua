-- BiSGearCheck UIRenderLists.lua
-- RenderWishlist and RenderBisList for the Wishlists and BiS Lists tabs

BiSGearCheck = BiSGearCheck or {}
local T = BiSGearCheck.Theme

-- Reusable buffer for wishlist zone filtering
local _wlFilterBuf = {}

-- ============================================================
-- RENDER WISHLIST
-- ============================================================

function BiSGearCheck:RenderWishlist()
    local f = self.mainFrame
    if not f then return end

    f.wlSelectorBar:Show()
    f.filterBar:Show()
    f.bislistBar:Hide()
    if f.raidBar then f.raidBar:Hide() end
    f.compareWLDropdown:Hide()
    f.compareWLLabel:Hide()
    f.collapseAllBtn:Hide()
    f.expandAllBtn:Hide()
    f.zoneFilterDropdown:Hide()
    f.sourceDropdown:Hide()
    f.specDropdown:Hide()
    if f.phaseDropdown then f.phaseDropdown:Hide() end
    f.UpdateTabAppearance()
    f.scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", self.CONTENT_PADDING, -114)

    -- Update character dropdown text
    self:UpdateCharDropdownText()

    -- Update wishlist name dropdown
    UIDropDownMenu_SetText(f.wlNameDropdown, self.activeWishlist)

    if self.wishlistZoneFilter then
        UIDropDownMenu_SetText(f.zoneDropdown, self.wishlistZoneFilter)
    else
        UIDropDownMenu_SetText(f.zoneDropdown, "All Zones")
    end
    f.autoCheck:SetChecked(self.wishlistAutoFilter)

    if f.wlCompareCheck then
        f.wlCompareCheck:SetChecked(
            self:IsWishlistCompareEnabled(self.viewingCharKey, self.activeWishlist))
    end

    local scrollChild = f.scrollChild
    self:ClearScrollContent(scrollChild)

    -- Show character name in title if viewing another character's wishlist
    local titleSuffix = T.hex("wishlistTitle") .. self.activeWishlist .. "|r"
    if self.viewingCharKey and self.viewingCharKey ~= self.playerKey then
        local vcd = self:GetCharacterData(self.viewingCharKey)
        local vcc = vcd and RAID_CLASS_COLORS[vcd.class]
        local charName = self.viewingCharKey:match("^([^-]+)")
        if vcc then
            titleSuffix = string.format("|cff%02x%02x%02x%s|r - %s", vcc.r * 255, vcc.g * 255, vcc.b * 255, charName, titleSuffix)
        else
            titleSuffix = charName .. " - " .. titleSuffix
        end
    end
    f.title:SetText("BiSGearCheck")

    local items = self:GetWishlistItems()
    local yOffset = -5
    local contentWidth = self.FRAME_WIDTH - 45

    -- Apply zone and source filters (reuse buffer)
    wipe(_wlFilterBuf)
    for _, item in ipairs(items) do
        if not self:IsItemFilteredBySource(item.id) and (not self.wishlistZoneFilter or self:ItemMatchesZone(item.id, self.wishlistZoneFilter)) then
            _wlFilterBuf[#_wlFilterBuf + 1] = item
        end
    end
    local filteredItems = _wlFilterBuf

    if #filteredItems == 0 then
        local row = self:CreateRow(scrollChild, yOffset, contentWidth)
        if self.wishlistZoneFilter then
            row.text:SetText(T.hex("emptySlot") .. "No wishlist items for " .. self.wishlistZoneFilter .. "|r")
        else
            row.text:SetText(T.hex("emptySlot") .. "Your wishlist is empty. Add items from the comparison view.|r")
        end
        yOffset = yOffset - self.ITEM_ROW_HEIGHT
    else
        local currentSlot = nil
        for _, item in ipairs(filteredItems) do
            if item.slotName ~= currentSlot then
                currentSlot = item.slotName
                local header = self:CreateRow(scrollChild, yOffset, contentWidth)
                header.text:SetText(T.hex("slotHeader") .. (currentSlot or "Unknown") .. "|r")
                yOffset = yOffset - self.SLOT_HEADER_HEIGHT
            end

            local row = self:CreateRow(scrollChild, yOffset, contentWidth)

            local itemName = item.link or item.name
            local sourceText = ""
            if item.source and item.source ~= "" and item.source ~= "Unknown" then
                if item.sourceType and item.sourceType ~= "" then
                    sourceText = string.format("%s- %s (%s)|r", T.hex("sourceInfo"), item.source, item.sourceType)
                else
                    sourceText = string.format("%s- %s|r", T.hex("sourceInfo"), item.source)
                end
            end

            local prefix = ""
            if item.isEquipped then
                prefix = T.hex("equipped") .. "[Equipped]|r "
            end

            row.text:SetText(string.format("  %s%s %s", prefix, itemName, sourceText))
            row.text:SetPoint("RIGHT", row, "RIGHT", -30, 0)

            -- Store data on the row for shared handlers
            row._itemID = item.id

            -- Remove button (reused from pool, shared handlers)
            local removeBtn, removeBg, btnText = self:GetActionButton(row)
            T.applyRemoveBtn(removeBg)
            btnText:SetText(T.hex("btnText") .. "x|r")

            removeBtn:SetScript("OnClick", self.OnWishlistRemoveClick)
            removeBtn:SetScript("OnEnter", self.OnWishlistRemoveEnter)
            removeBtn:SetScript("OnLeave", self.OnTooltipLeave)

            -- Item tooltip (shared handler)
            row:EnableMouse(true)
            row:SetScript("OnEnter", self.OnItemIDEnter)
            row:SetScript("OnLeave", self.OnTooltipLeave)

            yOffset = yOffset - self.ITEM_ROW_HEIGHT
        end
    end

    scrollChild:SetHeight(math.abs(yOffset) + 20)
end

-- ============================================================
-- RENDER BIS LISTS
-- ============================================================

function BiSGearCheck:RenderBisList()
    local f = self.mainFrame
    if not f then return end

    f.filterBar:Hide()
    f.bislistBar:Show()
    f.wlSelectorBar:Hide()
    if f.raidBar then f.raidBar:Hide() end
    f.compareWLDropdown:Hide()
    f.compareWLLabel:Hide()
    f.sourceDropdown:Hide()
    f.specDropdown:Hide()
    -- Position zone filter on the bislist bar row
    f.zoneFilterDropdown:ClearAllPoints()
    f.zoneFilterDropdown:SetPoint("TOPRIGHT", f, "TOPRIGHT", 5, -60)
    f.zoneFilterDropdown:Show()
    UIDropDownMenu_SetText(f.zoneFilterDropdown, self.zoneFilter or "All Zones")
    f.collapseAllBtn:ClearAllPoints()
    f.collapseAllBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -95)
    f.collapseAllBtn:Show()
    f.expandAllBtn:ClearAllPoints()
    f.expandAllBtn:SetPoint("LEFT", f.collapseAllBtn, "RIGHT", 5, 0)
    f.expandAllBtn:Show()
    f.UpdateTabAppearance()
    f.scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", self.CONTENT_PADDING, -124)

    -- Update character dropdown
    self:UpdateCharDropdownText()

    -- Update bislist source dropdown text
    for _, srcInfo in ipairs(self.DataSources) do
        if srcInfo.key == self.dataSource then
            UIDropDownMenu_SetText(f.bislistSourceDropdown, srcInfo.label)
            break
        end
    end

    -- Update bislist spec dropdown text
    if self.bislistSpec then
        local db = self:GetActiveDB()
        if db and db[self.bislistSpec] then
            UIDropDownMenu_SetText(f.bislistSpecDropdown, db[self.bislistSpec].spec)
        end
    else
        UIDropDownMenu_SetText(f.bislistSpecDropdown, "Select Spec")
    end

    local scrollChild = f.scrollChild
    self:ClearScrollContent(scrollChild)

    local specKey = self.bislistSpec
    local db = self:GetActiveDB()

    if not specKey or not db or not db[specKey] then
        f.title:SetText("BiSGearCheck")
        local yOffset = -5
        local contentWidth = self.FRAME_WIDTH - 45
        local row = self:CreateRow(scrollChild, yOffset, contentWidth)
        row.text:SetText(T.hex("emptySlot") .. "Select a spec from the dropdown above.|r")
        scrollChild:SetHeight(40)
        return
    end

    local specData = db[specKey]
    local classColor = RAID_CLASS_COLORS[specData.class]
    if classColor then
        local colored = string.format("|cff%02x%02x%02x%s|r", classColor.r * 255, classColor.g * 255, classColor.b * 255, specData.spec)
        f.title:SetText("BiSGearCheck")
    else
        f.title:SetText("BiSGearCheck")
    end

    local yOffset = -5
    local contentWidth = self.FRAME_WIDTH - 45

    for _, slotName in ipairs(self.SlotOrder) do
        local rawItems = specData.slots[slotName]
        local items = rawItems and self:FilterBisListByFaction(rawItems) or {}

        -- When zone filter is active, check if any items match
        if self.zoneFilter and #items > 0 then
            local hasMatch = false
            for _, itemID in ipairs(items) do
                if not self:IsItemFilteredBySource(itemID) and self:ItemMatchesZone(itemID, self.zoneFilter) then
                    hasMatch = true
                    break
                end
            end
            if not hasMatch then items = {} end
        end

        if #items > 0 then
            local isCollapsed = self.collapsedSlots[slotName]
            local arrow = isCollapsed and (T.hex("slotHeader") .. "[+]|r ") or (T.hex("slotHeader") .. "[-]|r ")

            -- Slot header (shared handler)
            local header = self:CreateRow(scrollChild, yOffset, contentWidth)
            header.text:SetText(arrow .. T.hex("slotHeader") .. slotName .. "|r")
            header._slotName = slotName
            header:EnableMouse(true)
            header:SetScript("OnMouseDown", self.OnSlotHeaderClick)
            yOffset = yOffset - self.SLOT_HEADER_HEIGHT

            if not isCollapsed then
                for rank, itemID in ipairs(items) do
                    -- Skip items hidden by unified filter (zone, classic, phase, PvP, world boss, BoP crafted)
                    if not self:GetItemFilterReason(itemID, self.zoneFilter) then
                    local row = self:CreateRow(scrollChild, yOffset, contentWidth)

                    local name, link, quality, _, _, _, _, _, _, icon = GetItemInfo(itemID)
                    if not name and not self.pendingItems[itemID] then
                        self.pendingItems[itemID] = true
                        C_Item.RequestLoadItemDataByID(itemID)
                    end

                    local itemText = link or name or ("Item #" .. itemID)
                    local sourceInfo = BiSGearCheckSources and BiSGearCheckSources[itemID]
                    local sourceText = ""
                    if sourceInfo and sourceInfo.source and sourceInfo.source ~= "Unknown" then
                        if sourceInfo.sourceType and sourceInfo.sourceType ~= "" then
                            sourceText = string.format("%s- %s (%s)|r", T.hex("sourceInfo"), sourceInfo.source, sourceInfo.sourceType)
                        else
                            sourceText = string.format("%s- %s|r", T.hex("sourceInfo"), sourceInfo.source)
                        end
                    end

                    row.text:SetText(string.format("  %s#%d|r %s %s", T.hex("rankNum"), rank, itemText, sourceText))

                    -- Item tooltip on hover (shared handler)
                    row._itemID = itemID
                    row:EnableMouse(true)
                    row:SetScript("OnEnter", self.OnItemIDEnter)
                    row:SetScript("OnLeave", self.OnTooltipLeave)

                    yOffset = yOffset - self.ITEM_ROW_HEIGHT
                    end -- end zone filter check
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
                        local enchHeader = self:CreateRow(scrollChild, yOffset, contentWidth)
                        enchHeader.text:SetText("  " .. T.hex("enchantLabel") .. "Enchants:|r")
                        yOffset = yOffset - self.ITEM_ROW_HEIGHT

                        for _, enchant in ipairs(slotEnchants) do
                            if not self:IsWrongShattFaction(enchant[1]) then
                                local row = self:CreateRow(scrollChild, yOffset, contentWidth)
                                row.text:SetText(string.format("    %s%s|r", T.hex("enchantName"), enchant[2]))
                                local lf = self:GetLinkFrame(row)
                                lf._enchantID = enchant[1]
                                lf._enchantSpellOverride = enchant[3]
                                lf:SetScript("OnEnter", self.OnEnchantEnter)
                                lf:SetScript("OnLeave", self.OnTooltipLeave)
                                yOffset = yOffset - self.ITEM_ROW_HEIGHT
                            end
                        end
                    end
                end
            end

            -- Separator (reused from pool)
            local sep = self:CreateRow(scrollChild, yOffset, contentWidth)
            local line = self:GetSeparatorLine(sep)
            T.applySeparator(line)
            yOffset = yOffset - 6
            yOffset = yOffset - self.SECTION_SPACING
        end
    end

    -- Recommended gems section at bottom
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
