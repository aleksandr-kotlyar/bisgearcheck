-- BiSGearCheck UIRenderRaid.lua
-- Raid tab controls and rendering: scan button, progress, per-character issue/upgrade display

BiSGearCheck = BiSGearCheck or {}
local T = BiSGearCheck.Theme

-- ============================================================
-- RAID CHARACTER CONTEXT MENU
-- ============================================================

local raidContextMenuFrame

function BiSGearCheck:ShowRaidCharContextMenu(charKey)
    local result = self.raidScanResults[charKey]
    if not result then return end

    if not raidContextMenuFrame then
        raidContextMenuFrame = CreateFrame("Frame", "BiSGearCheckRaidContextMenu", UIParent, "UIDropDownMenuTemplate")
    end

    local name = charKey:match("^([^%-]+)") or charKey

    UIDropDownMenu_Initialize(raidContextMenuFrame, function(self, level)
        local info = UIDropDownMenu_CreateInfo()

        if result.issueCount > 0 then
            info.text = "Whisper Issues to " .. name
            info.notCheckable = true
            info.func = function()
                BiSGearCheck:WhisperIssues(charKey)
            end
            UIDropDownMenu_AddButton(info, level)
        else
            info.text = "No issues to whisper"
            info.notCheckable = true
            info.disabled = true
            UIDropDownMenu_AddButton(info, level)
        end

        info = UIDropDownMenu_CreateInfo()
        info.text = "Cancel"
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)
    end, "MENU")

    ToggleDropDownMenu(1, nil, raidContextMenuFrame, "cursor", 0, 0)
end

-- ============================================================
-- RAID CONTROLS SETUP
-- ============================================================

function BiSGearCheck:SetupRaidControls(f)
    local bar = CreateFrame("Frame", nil, f)
    bar:SetHeight(54)
    bar:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -56)
    bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -56)
    bar:Hide()

    -- Row 1: Scan / Export / Report buttons (zone dropdown positioned in RenderRaid)
    local scanBtn = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    scanBtn:SetSize(90, 22)
    scanBtn:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, -4)
    scanBtn:SetText("Scan Raid")
    scanBtn:SetScript("OnClick", function()
        if BiSGearCheck.raidScanState == "scanning" then
            BiSGearCheck:CancelRaidScan()
        else
            BiSGearCheck:StartRaidScan()
        end
    end)

    local exportBtn = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    exportBtn:SetSize(56, 22)
    exportBtn:SetPoint("LEFT", scanBtn, "RIGHT", 4, 0)
    exportBtn:SetText("Export")
    exportBtn:SetScript("OnClick", function()
        BiSGearCheck:ShowRaidScanExport()
    end)

    local reportBtn = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    reportBtn:SetSize(56, 22)
    reportBtn:SetPoint("LEFT", exportBtn, "RIGHT", 4, 0)
    reportBtn:SetText("Report")
    reportBtn:SetScript("OnClick", function()
        BiSGearCheck:PrintRaidIssueReport()
    end)

    -- Row 2: Collapse/Expand All + progress text
    local collapseBtn = CreateFrame("Button", nil, bar)
    collapseBtn:SetSize(70, 16)
    collapseBtn:SetPoint("TOPLEFT", scanBtn, "BOTTOMLEFT", 3, -4)
    local collapseText = collapseBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    collapseText:SetPoint("LEFT")
    T.applyFont(collapseText, "small")
    collapseText:SetText(T.hex("collapseLink") .. "Collapse All|r")
    collapseBtn:SetScript("OnClick", function()
        for charKey in pairs(BiSGearCheck.raidScanResults) do
            BiSGearCheck.raidCollapsedChars[charKey] = true
        end
        BiSGearCheck:RefreshView()
    end)

    local expandBtn = CreateFrame("Button", nil, bar)
    expandBtn:SetSize(65, 16)
    expandBtn:SetPoint("LEFT", collapseBtn, "RIGHT", 8, 0)
    local expandText = expandBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    expandText:SetPoint("LEFT")
    T.applyFont(expandText, "small")
    expandText:SetText(T.hex("collapseLink") .. "Expand All|r")
    expandBtn:SetScript("OnClick", function()
        wipe(BiSGearCheck.raidCollapsedChars)
        BiSGearCheck:RefreshView()
    end)

    local progressText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    progressText:SetPoint("LEFT", expandBtn, "RIGHT", 10, 0)
    progressText:SetPoint("RIGHT", bar, "RIGHT", -5, 0)
    progressText:SetJustifyH("LEFT")
    T.applyFont(progressText, "small")
    T.applyProgressText(progressText)

    bar.scanBtn = scanBtn
    bar.exportBtn = exportBtn
    bar.reportBtn = reportBtn
    bar.collapseBtn = collapseBtn
    bar.expandBtn = expandBtn
    bar.progressText = progressText
    f.raidBar = bar
end

-- ============================================================
-- RENDER RAID TAB
-- ============================================================

function BiSGearCheck:RenderRaid()
    local f = self.mainFrame
    if not f then return end

    -- Hide other tab controls
    f.filterBar:Hide()
    f.bislistBar:Hide()
    f.wlSelectorBar:Hide()
    f.compareWLDropdown:Hide()
    f.compareWLLabel:Hide()
    f.collapseAllBtn:Hide()
    f.expandAllBtn:Hide()
    f.sourceDropdown:Hide()
    f.specDropdown:Hide()
    if f.phaseDropdown then f.phaseDropdown:Hide() end
    f.charDropdown:Hide()
    if f.charDropdownLabel then f.charDropdownLabel:Hide() end

    -- Show raid controls + zone filter on the same row as buttons
    f.raidBar:Show()
    f.zoneFilterDropdown:ClearAllPoints()
    f.zoneFilterDropdown:SetPoint("TOPRIGHT", f, "TOPRIGHT", 5, -56)
    f.zoneFilterDropdown:Show()
    UIDropDownMenu_SetText(f.zoneFilterDropdown, self.zoneFilter or "All Zones")
    f.UpdateTabAppearance()
    f.scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", self.CONTENT_PADDING, -112)

    -- Update scan button text
    local scanBtn = f.raidBar.scanBtn
    if self.raidScanState == "scanning" then
        scanBtn:SetText("Cancel")
    elseif IsInRaid() then
        scanBtn:SetText("Scan Raid")
    elseif GetNumGroupMembers() > 0 then
        scanBtn:SetText("Scan Group")
    else
        scanBtn:SetText("Scan Raid")
    end

    -- Update progress text
    local progressText = f.raidBar.progressText
    if self.raidScanState == "scanning" then
        local total = #self.raidScanQueue
        local current = math.min(self.raidScanIndex, total)
        progressText:SetText(string.format("Scanning %d/%d...", current, total))
    elseif self.raidScanState == "complete" then
        local scanned = self:GetRaidScanCount()
        local skipped = #self.raidScanSkipped
        local timeStr = ""
        if BiSGearCheckSaved and BiSGearCheckSaved.lastRaidScan then
            local elapsed = time() - BiSGearCheckSaved.lastRaidScan.time
            if elapsed < 60 then
                timeStr = " (just now)"
            elseif elapsed < 3600 then
                timeStr = string.format(" (%d min ago)", math.floor(elapsed / 60))
            else
                timeStr = string.format(" (%d hr ago)", math.floor(elapsed / 3600))
            end
        end
        local msg = string.format("Complete: %d scanned", scanned)
        if skipped > 0 then
            msg = msg .. string.format(", %d skipped", skipped)
        end
        if self.raidScanRosterChanged then
            msg = msg .. " " .. T.hex("rosterChanged") .. "(roster changed)|r"
        end
        progressText:SetText(msg .. timeStr)
    else
        if GetNumGroupMembers() == 0 then
            progressText:SetText("Join a group to scan.")
        else
            progressText:SetText("")
        end
    end

    -- Render scroll content
    local scrollChild = f.scrollChild
    self:ClearScrollContent(scrollChild)

    local yOffset = -5
    local contentWidth = self.FRAME_WIDTH - 45

    -- If no results, show placeholder
    if not next(self.raidScanResults) and self.raidScanState ~= "scanning" then
        local row = self:CreateRow(scrollChild, yOffset, contentWidth)
        if GetNumGroupMembers() == 0 then
            row.text:SetText(T.hex("emptySlot") .. "Join a raid or party and click Scan to check gear.|r")
        else
            row.text:SetText(T.hex("emptySlot") .. "Click Scan to inspect group members.|r")
        end
        yOffset = yOffset - self.ITEM_ROW_HEIGHT
        scrollChild:SetHeight(math.abs(yOffset) + 20)
        return
    end

    -- Render each scanned character
    local sortedKeys = self:GetSortedRaidScanKeys()
    for _, charKey in ipairs(sortedKeys) do
        yOffset = self:RenderRaidCharacter(scrollChild, charKey, yOffset, contentWidth)
    end

    -- Render skipped section
    if #self.raidScanSkipped > 0 then
        yOffset = yOffset - self.SECTION_SPACING

        local header = self:CreateRow(scrollChild, yOffset, contentWidth)
        header.text:SetText(T.hex("skippedLabel") .. "Skipped:|r")
        yOffset = yOffset - self.SLOT_HEADER_HEIGHT

        for _, skip in ipairs(self.raidScanSkipped) do
            local row = self:CreateRow(scrollChild, yOffset, contentWidth)
            local coloredName = self:ClassColor(skip.class, skip.name)
            row.text:SetText("  " .. coloredName .. " " .. T.hex("sourceInfo") .. "- " .. skip.reason .. "|r")
            yOffset = yOffset - self.ITEM_ROW_HEIGHT
        end
    end

    scrollChild:SetHeight(math.abs(yOffset) + 20)
end

-- ============================================================
-- RENDER SINGLE CHARACTER
-- ============================================================

function BiSGearCheck:RenderRaidCharacter(parent, charKey, yOffset, width)
    local result = self.raidScanResults[charKey]
    if not result then return yOffset end

    local charData = self:GetCharacterData(charKey)
    if not charData then return yOffset end

    local isCollapsed = self.raidCollapsedChars[charKey]
    local arrow = isCollapsed and (T.hex("slotHeader") .. "[+]|r ") or (T.hex("slotHeader") .. "[-]|r ")

    -- Spec label
    local specLabel = ""
    local specs = self.ClassSpecs[charData.class]
    if specs and result.specKey then
        for _, s in ipairs(specs) do
            if s.key == result.specKey then
                specLabel = s.label
                break
            end
        end
    end

    -- Character name (class-colored)
    local name = charKey:match("^([^%-]+)")
    local coloredName = self:ClassColor(charData.class, name)

    -- Upgrade count
    local upgradeCount = 0
    for _, slotUpgrades in pairs(result.upgrades) do
        upgradeCount = upgradeCount + #slotUpgrades
    end
    local upgradeBadge = ""
    if upgradeCount > 0 then
        upgradeBadge = string.format(" %s[%d Upgrade%s]|r",
            T.hex("upgradesBadge"), upgradeCount, upgradeCount == 1 and "" or "s")
    end

    -- Header row
    local header = self:CreateRow(parent, yOffset, width)
    local headerText = arrow .. coloredName
    if specLabel ~= "" then
        headerText = headerText .. " " .. T.hex("specLabel") .. "(" .. specLabel .. ")|r"
    end
    header.text:SetText(headerText)
    header.text:SetPoint("RIGHT", header, "RIGHT", -120, 0)

    -- Issue badge (hoverable with tooltip showing specifics)
    local issueBadgeText
    if result.issueCount > 0 then
        issueBadgeText = string.format("%s[%d Issue%s]|r",
            T.hex("issuesBadge"), result.issueCount, result.issueCount == 1 and "" or "s")
    else
        issueBadgeText = T.hex("okBadge") .. "[OK]|r"
    end
    local wf, wLabel = self:GetWarningLabel(header)
    wLabel:SetText(issueBadgeText .. upgradeBadge)
    wf:SetWidth(wLabel:GetStringWidth() + 8)
    wf._raidCharKey = charKey

    if result.issueCount > 0 then
        wf:SetScript("OnEnter", function(frame)
            GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
            GameTooltip:AddLine(coloredName .. " — Issues", 1, 0.82, 0)
            local res = BiSGearCheck.raidScanResults[frame._raidCharKey]
            if res then
                for _, issue in ipairs(res.issues) do
                    local itemName
                    if issue.itemLink then
                        itemName = issue.itemLink
                    elseif issue.itemID then
                        local name = GetItemInfo(issue.itemID)
                        itemName = name or ("Item #" .. issue.itemID)
                    else
                        itemName = "?"
                    end
                    local rankTag = issue.bisRank and (" #" .. issue.bisRank) or ""
                    -- Strip color codes from warnings for cleaner tooltip
                    local warnList = table.concat(issue.warnings, " ")
                    GameTooltip:AddDoubleLine(
                        issue.slotName .. ": " .. itemName .. rankTag,
                        warnList,
                        1, 1, 1, 1, 1, 1
                    )
                end
            end
            GameTooltip:Show()
        end)
        wf:SetScript("OnLeave", self.OnTooltipLeave)
    end

    header._raidCharKey = charKey
    header:EnableMouse(true)
    header:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" then
            BiSGearCheck:ShowRaidCharContextMenu(charKey)
        else
            BiSGearCheck.raidCollapsedChars[charKey] = not BiSGearCheck.raidCollapsedChars[charKey]
            BiSGearCheck:RefreshView()
        end
    end)
    yOffset = yOffset - self.SLOT_HEADER_HEIGHT

    if isCollapsed then
        -- Separator
        local sep = self:CreateRow(parent, yOffset, width)
        local line = self:GetSeparatorLine(sep)
        T.applySeparator(line, true)
        yOffset = yOffset - 6
        return yOffset
    end

    -- Merge equipped + upgrades per-slot: one slot block per row group.
    -- Each block starts with the worn item (with BiS rank + any warnings
    -- inlined) and then indents upgrade candidates beneath it. Issues
    -- ("missing enchant", "bad gem", etc.) fold into the worn-item row
    -- for that slot rather than getting their own separate section.

    local charData = self:GetCharacterData(charKey)
    local equipped = charData and charData.equipped or {}

    -- Build a per-slot warnings lookup from the analyzer's issue list so
    -- we can suffix each worn-item row with its issue text, if any.
    local warnBySlotItem = {}  -- [slotName][itemID] = "warn1 warn2"
    for _, issue in ipairs(result.issues or {}) do
        warnBySlotItem[issue.slotName] = warnBySlotItem[issue.slotName] or {}
        if issue.itemID then
            warnBySlotItem[issue.slotName][issue.itemID] = table.concat(issue.warnings, " ")
        end
    end

    for _, slotName in ipairs(self.SlotOrder) do
        local slotItems = equipped[slotName]

        -- Pre-filter the slot's upgrade list (zone + source filters)
        local rawUpgrades = result.upgrades and result.upgrades[slotName] or nil
        local visibleUpgrades = {}
        if rawUpgrades then
            for _, upgrade in ipairs(rawUpgrades) do
                local hideSource = self:IsItemFilteredByRaidSource(upgrade.id)
                local hideZone = self.zoneFilter and not self:ItemMatchesZone(upgrade.id, self.zoneFilter)
                if not hideSource and not hideZone then
                    visibleUpgrades[#visibleUpgrades + 1] = upgrade
                end
            end
        end

        local hasEquipped = slotItems and #slotItems > 0
        if hasEquipped or #visibleUpgrades > 0 then
            -- Worn item row(s) — BiS rank + warning suffix inlined
            if hasEquipped then
                for _, item in ipairs(slotItems) do
                    local row = self:CreateRow(parent, yOffset, width)
                    local rankText = ""
                    if result.bisRankBySlot and result.bisRankBySlot[slotName] and item.id then
                        local rank = result.bisRankBySlot[slotName][item.id]
                        if rank then
                            rankText = string.format(" %s#%d|r", T.hex("rankNum"), rank)
                        end
                    end
                    local warnText = item.id and warnBySlotItem[slotName] and warnBySlotItem[slotName][item.id]
                    local warnSuffix = warnText and (" " .. warnText) or ""
                    local itemText = item.link or ("Item #" .. (item.id or "?"))
                    row.text:SetText(string.format("  %s%s:|r %s%s%s",
                        T.hex("slotHeader"), slotName, itemText, rankText, warnSuffix))

                    if item.link then
                        row._itemLink = item.link
                        row:EnableMouse(true)
                        row:SetScript("OnEnter", self.OnItemLinkEnter)
                        row:SetScript("OnLeave", self.OnTooltipLeave)
                    elseif item.id then
                        row._itemID = item.id
                        row:EnableMouse(true)
                        row:SetScript("OnEnter", self.OnItemIDEnter)
                        row:SetScript("OnLeave", self.OnTooltipLeave)
                    end
                    yOffset = yOffset - self.ITEM_ROW_HEIGHT
                end
            else
                -- Slot empty but upgrades exist — still show the slot name
                local row = self:CreateRow(parent, yOffset, width)
                row.text:SetText(string.format("  %s%s:|r %s(empty)|r",
                    T.hex("slotHeader"), slotName, T.hex("emptySlot")))
                yOffset = yOffset - self.ITEM_ROW_HEIGHT
            end

            -- Upgrade candidates indented beneath the slot's equipped row
            for _, upgrade in ipairs(visibleUpgrades) do
                local row = self:CreateRow(parent, yOffset, width)
                local lateName, lateLink = GetItemInfo(upgrade.id)
                local itemText = lateLink or lateName or ("Item #" .. upgrade.id)
                local sourceText = ""
                if upgrade.source and upgrade.source ~= "Unknown" then
                    if upgrade.sourceType and upgrade.sourceType ~= "" then
                        sourceText = string.format("%s%s (%s)|r", T.hex("sourceInfo"), upgrade.source, upgrade.sourceType)
                    else
                        sourceText = string.format("%s%s|r", T.hex("sourceInfo"), upgrade.source)
                    end
                end
                row.text:SetText(string.format("    %s#%d|r %s %s",
                    T.hex("rankNum"), upgrade.rank, itemText, sourceText))
                row._itemID = upgrade.id
                row:EnableMouse(true)
                row:SetScript("OnEnter", self.OnItemIDEnter)
                row:SetScript("OnLeave", self.OnTooltipLeave)
                yOffset = yOffset - self.ITEM_ROW_HEIGHT
            end
        end
    end

    -- Separator
    local sep = self:CreateRow(parent, yOffset, width)
    local line = self:GetSeparatorLine(sep)
    T.applySeparator(line, true)
    yOffset = yOffset - 6

    return yOffset
end
