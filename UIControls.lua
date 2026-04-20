-- BiSGearCheck UIControls.lua
-- Tabs, character selector, data source/spec dropdowns, collapse controls, BiS Lists bar

BiSGearCheck = BiSGearCheck or {}
local T = BiSGearCheck.Theme

-- ============================================================
-- TABS: Compare + Wishlist + BiS Lists
-- ============================================================

function BiSGearCheck:SetupTabs(f)
    local TAB_WIDTH = 70
    local TAB_HEIGHT = 20

    local function CreateTab(parent, text, index)
        local tab = CreateFrame("Button", "BiSGearCheckTab" .. index, parent)
        tab:SetSize(TAB_WIDTH, TAB_HEIGHT)

        local bg = tab:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        tab.bg = bg

        local label = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("CENTER", 0, 0)
        label:SetText(text)
        T.applyFont(label, "small")
        tab.label = label

        return tab
    end

    local compTab = CreateTab(f, "Compare", 1)
    compTab:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -34)

    local wlTab = CreateTab(f, "Wishlists", 2)
    wlTab:SetPoint("LEFT", compTab, "RIGHT", 2, 0)

    local bisTab = CreateTab(f, "BiS Lists", 3)
    bisTab:SetPoint("LEFT", wlTab, "RIGHT", 2, 0)

    local raidTab = CreateTab(f, "Raid", 4)
    raidTab:SetPoint("LEFT", bisTab, "RIGHT", 2, 0)

    local function SetTabActive(tab)
        T.setTabActive(tab)
    end
    local function SetTabInactive(tab)
        T.setTabInactive(tab)
    end

    local function UpdateTabAppearance()
        local mode = BiSGearCheck.viewMode
        SetTabInactive(compTab)
        SetTabInactive(wlTab)
        SetTabInactive(bisTab)
        SetTabInactive(raidTab)
        if mode == "comparison" then
            SetTabActive(compTab)
        elseif mode == "wishlist" then
            SetTabActive(wlTab)
        elseif mode == "bislist" then
            SetTabActive(bisTab)
        elseif mode == "raid" then
            SetTabActive(raidTab)
        end
    end

    compTab:SetScript("OnClick", function()
        BiSGearCheck.viewMode = "comparison"
        UpdateTabAppearance()
        BiSGearCheck:Refresh()
    end)

    wlTab:SetScript("OnClick", function()
        BiSGearCheck.viewMode = "wishlist"
        UpdateTabAppearance()
        BiSGearCheck:RefreshView()
    end)

    bisTab:SetScript("OnClick", function()
        BiSGearCheck.viewMode = "bislist"
        UpdateTabAppearance()
        BiSGearCheck:RefreshView()
    end)

    raidTab:SetScript("OnClick", function()
        BiSGearCheck.viewMode = "raid"
        UpdateTabAppearance()
        BiSGearCheck:RefreshView()
    end)

    -- Gear icon button to open settings
    local settingsBtn = CreateFrame("Button", "BiSGearCheckSettingsBtn", f)
    settingsBtn:SetSize(20, 20)
    settingsBtn:SetPoint("RIGHT", f, "TOPRIGHT", -38, -20)

    local settingsIcon = settingsBtn:CreateTexture(nil, "ARTWORK")
    settingsIcon:SetAllPoints()
    settingsIcon:SetTexture("Interface\\Scenarios\\ScenarioIcon-Interact")
    T.applySettingsIcon(settingsIcon, false)
    settingsBtn.icon = settingsIcon

    settingsBtn:SetScript("OnClick", function()
        BiSGearCheck:ShowSettings()
    end)
    settingsBtn:SetScript("OnEnter", function(self)
        T.applySettingsIcon(self.icon, true)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Settings")
        GameTooltip:Show()
    end)
    settingsBtn:SetScript("OnLeave", function(self)
        T.applySettingsIcon(self.icon, false)
        GameTooltip:Hide()
    end)

    f.compTab = compTab
    f.wlTab = wlTab
    f.bisTab = bisTab
    f.raidTab = raidTab
    f.settingsBtn = settingsBtn
    f.UpdateTabAppearance = UpdateTabAppearance
end

-- ============================================================
-- CHARACTER SELECTOR (top-level, right of tabs)
-- ============================================================

function BiSGearCheck:SetupCharacterSelector(f)
    local charDropdown = CreateFrame("Frame", "BiSGearCheckCharDropdown", f, "UIDropDownMenuTemplate")
    charDropdown:SetPoint("TOPRIGHT", f, "TOPRIGHT", 5, -32)
    UIDropDownMenu_SetWidth(charDropdown, 130)
    UIDropDownMenu_JustifyText(charDropdown, "RIGHT")

    local function CharDropdownInit(self, level)
        local charKeys = BiSGearCheck:GetCharacterKeys()
        for _, charKey in ipairs(charKeys) do
            local charData = BiSGearCheck:GetCharacterData(charKey)
            local info = UIDropDownMenu_CreateInfo()
            local classColor = charData and RAID_CLASS_COLORS[charData.class]
            local charName = charKey:match("^([^-]+)") or charKey
            local suffix = ""
            if charData and charData.inspected then
                suffix = " " .. T.hex("inspectedTag") .. "(Inspected)|r"
            end
            if classColor then
                info.text = string.format("|cff%02x%02x%02x%s|r%s", classColor.r * 255, classColor.g * 255, classColor.b * 255, charName, suffix)
            else
                info.text = charName .. suffix
            end
            info.value = charKey
            info.func = function(self)
                UIDropDownMenu_SetSelectedValue(charDropdown, self.value)
                BiSGearCheck:UpdateCharDropdownText()
                BiSGearCheck:SetViewingCharacter(self.value)
            end
            info.notCheckable = true
            UIDropDownMenu_AddButton(info, level)
        end
    end
    UIDropDownMenu_Initialize(charDropdown, CharDropdownInit)

    f.charDropdown = charDropdown

    -- Helper to update character dropdown text with class color
    function BiSGearCheck:UpdateCharDropdownText()
        local ck = self:GetViewingCharKey()
        local cd = self:GetCharacterData(ck)
        local cn = ck and ck:match("^([^-]+)") or ck
        local cc = cd and RAID_CLASS_COLORS[cd.class]
        if cc and cn then
            UIDropDownMenu_SetText(f.charDropdown, string.format("|cff%02x%02x%02x%s|r", cc.r * 255, cc.g * 255, cc.b * 255, cn))
        elseif cn then
            UIDropDownMenu_SetText(f.charDropdown, cn)
        end
    end
    self:UpdateCharDropdownText()
end

-- ============================================================
-- DATA SOURCE + SPEC DROPDOWNS (below tabs)
-- ============================================================

function BiSGearCheck:SetupSourceSpecDropdowns(f)
    -- Data source dropdown
    local sourceDropdown = CreateFrame("Frame", "BiSGearCheckSourceDropdown", f, "UIDropDownMenuTemplate")
    sourceDropdown:SetPoint("TOPLEFT", f, "TOPLEFT", -5, -60)
    UIDropDownMenu_SetWidth(sourceDropdown, 100)

    local function addSourceButton(level, srcInfo)
        local info = UIDropDownMenu_CreateInfo()
        info.text = srcInfo.label
        info.value = srcInfo.key
        info.func = function(self)
            UIDropDownMenu_SetSelectedValue(sourceDropdown, self.value)
            UIDropDownMenu_SetText(sourceDropdown, self:GetText())
            BiSGearCheck:SetDataSource(self.value)
        end
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)
    end

    local function SourceDropdownInit(self, level)
        for _, srcInfo in ipairs(BiSGearCheck:GetEnabledDataSourcesForPhase()) do
            addSourceButton(level, srcInfo)
        end
        -- Compare-enabled wishlists appear after published sources.
        if BiSGearCheck.GetCompareEnabledWishlists then
            for _, srcInfo in ipairs(BiSGearCheck:GetCompareEnabledWishlists()) do
                addSourceButton(level, srcInfo)
            end
        end
    end
    UIDropDownMenu_Initialize(sourceDropdown, SourceDropdownInit)

    -- Set initial source text: published or wishlist
    local function labelFor(key)
        for _, srcInfo in ipairs(self:GetEnabledDataSourcesForPhase()) do
            if srcInfo.key == key then return srcInfo.label end
        end
        if self.GetCompareEnabledWishlists then
            for _, srcInfo in ipairs(self:GetCompareEnabledWishlists()) do
                if srcInfo.key == key then return srcInfo.label end
            end
        end
    end
    local initialLabel = labelFor(self.dataSource)
    if initialLabel then
        UIDropDownMenu_SetText(sourceDropdown, initialLabel)
        UIDropDownMenu_SetSelectedValue(sourceDropdown, self.dataSource)
    end

    -- Spec dropdown
    local specDropdown = CreateFrame("Frame", "BiSGearCheckSpecDropdown", f, "UIDropDownMenuTemplate")
    specDropdown:SetPoint("LEFT", sourceDropdown, "RIGHT", -15, 0)
    UIDropDownMenu_SetWidth(specDropdown, 120)

    local function SpecDropdownInit(self, level)
        local classToken = BiSGearCheck:GetViewingClass()
        local specs = classToken and BiSGearCheck.ClassSpecs[classToken]
        if not specs then return end

        local db = BiSGearCheck:GetActiveDB()
        for _, specInfo in ipairs(specs) do
            if db and db[specInfo.key] then
                local info = UIDropDownMenu_CreateInfo()
                info.text = specInfo.label
                info.value = specInfo.key
                info.func = function(self)
                    UIDropDownMenu_SetSelectedValue(specDropdown, self.value)
                    UIDropDownMenu_SetText(specDropdown, self:GetText())
                    BiSGearCheck:SetSpec(self.value)
                end
                info.notCheckable = true
                UIDropDownMenu_AddButton(info, level)
            end
        end
    end
    UIDropDownMenu_Initialize(specDropdown, SpecDropdownInit)

    if self.selectedSpec then
        local db = self:GetActiveDB()
        if db and db[self.selectedSpec] then
            UIDropDownMenu_SetText(specDropdown, db[self.selectedSpec].spec)
            UIDropDownMenu_SetSelectedValue(specDropdown, self.selectedSpec)
        end
    end

    f.sourceDropdown = sourceDropdown
    f.specDropdown = specDropdown
end

-- ============================================================
-- COLLAPSE ALL / EXPAND ALL + COMPARE TAB WISHLIST PICKER
-- ============================================================

function BiSGearCheck:SetupCollapseControls(f)
    local collapseAllBtn = CreateFrame("Button", nil, f)
    collapseAllBtn:SetSize(70, 16)
    collapseAllBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -92)
    local collapseText = collapseAllBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    collapseText:SetPoint("LEFT")
    T.applyFont(collapseText, "small")
    collapseText:SetText(T.hex("collapseLink") .. "Collapse All|r")
    collapseAllBtn:SetScript("OnClick", function()
        for _, slotName in ipairs(BiSGearCheck.SlotOrder) do
            BiSGearCheck.collapsedSlots[slotName] = true
        end
        BiSGearCheck:RefreshView()
    end)
    collapseAllBtn:SetScript("OnEnter", function(self) collapseText:SetText(T.hex("collapseLinkHi") .. "Collapse All|r") end)
    collapseAllBtn:SetScript("OnLeave", function(self) collapseText:SetText(T.hex("collapseLink") .. "Collapse All|r") end)

    local expandAllBtn = CreateFrame("Button", nil, f)
    expandAllBtn:SetSize(65, 16)
    expandAllBtn:SetPoint("LEFT", collapseAllBtn, "RIGHT", 5, 0)
    local expandText = expandAllBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    expandText:SetPoint("LEFT")
    T.applyFont(expandText, "small")
    expandText:SetText(T.hex("collapseLink") .. "Expand All|r")
    expandAllBtn:SetScript("OnClick", function()
        for _, slotName in ipairs(BiSGearCheck.SlotOrder) do
            BiSGearCheck.collapsedSlots[slotName] = false
        end
        BiSGearCheck:RefreshView()
    end)
    expandAllBtn:SetScript("OnEnter", function(self) expandText:SetText(T.hex("collapseLinkHi") .. "Expand All|r") end)
    expandAllBtn:SetScript("OnLeave", function(self) expandText:SetText(T.hex("collapseLink") .. "Expand All|r") end)

    -- Wishlist picker (right-aligned, shown on Compare tab)
    local compareWLDropdown = CreateFrame("Frame", "BiSGearCheckCompareWLDropdown", f, "UIDropDownMenuTemplate")
    compareWLDropdown:SetPoint("TOPRIGHT", f, "TOPRIGHT", 5, -90)
    UIDropDownMenu_SetWidth(compareWLDropdown, 130)
    UIDropDownMenu_JustifyText(compareWLDropdown, "RIGHT")

    local function CompareWLDropdownInit(self, level)
        local names = BiSGearCheck:GetWishlistNames()
        for _, name in ipairs(names) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = name
            info.value = name
            info.func = function(self)
                UIDropDownMenu_SetSelectedValue(compareWLDropdown, self.value)
                UIDropDownMenu_SetText(compareWLDropdown, self.value)
                BiSGearCheck:SetActiveWishlist(self.value)
            end
            info.notCheckable = true
            UIDropDownMenu_AddButton(info, level)
        end
    end
    UIDropDownMenu_Initialize(compareWLDropdown, CompareWLDropdownInit)
    UIDropDownMenu_SetText(compareWLDropdown, self.activeWishlist)
    compareWLDropdown:Hide()

    local compareWLLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    compareWLLabel:SetPoint("RIGHT", compareWLDropdown, "LEFT", 15, 2)
    T.applyFont(compareWLLabel, "small")
    compareWLLabel:SetText(T.hex("wishlistLabel") .. "Wishlist:|r")
    compareWLLabel:Hide()

    -- Zone filter dropdown (shown on Compare and BiS Lists tabs, positioned dynamically)
    local zoneFilterDropdown = CreateFrame("Frame", "BiSGearCheckZoneFilterDropdown", f, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(zoneFilterDropdown, 130)

    local function ZoneFilterInit(self, level)
        local info = UIDropDownMenu_CreateInfo()
        info.text = "All Zones"
        info.value = ""
        info.func = function()
            UIDropDownMenu_SetSelectedValue(zoneFilterDropdown, "")
            UIDropDownMenu_SetText(zoneFilterDropdown, "All Zones")
            BiSGearCheck.zoneFilter = nil
            BiSGearCheck:RefreshView()
        end
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)

        -- Build a set of zones that have items for the current spec
        local specKey = BiSGearCheck.viewMode == "bislist" and BiSGearCheck.bislistSpec or BiSGearCheck.selectedSpec
        local db = BiSGearCheck:GetActiveDB()
        local specData = specKey and db and db[specKey]
        local zoneHasItems = {}
        if specData and specData.slots then
            for _, items in pairs(specData.slots) do
                for _, itemID in ipairs(items) do
                    local zone = BiSGearCheck:GetItemZone(itemID)
                    if zone then zoneHasItems[zone] = true end
                end
            end
        end

        for _, category in ipairs(BiSGearCheck:GetZoneCategories()) do
            local hdr = UIDropDownMenu_CreateInfo()
            hdr.text = category.label
            hdr.isTitle = true
            hdr.notCheckable = true
            UIDropDownMenu_AddButton(hdr, level)

            for _, zone in ipairs(category.zones) do
                local zInfo = UIDropDownMenu_CreateInfo()
                if zoneHasItems[zone] then
                    zInfo.text = "  " .. T.hex("zoneHighlight") .. zone .. "|r"
                else
                    zInfo.text = "  " .. zone
                end
                zInfo.value = zone
                zInfo.func = function(self)
                    UIDropDownMenu_SetSelectedValue(zoneFilterDropdown, self.value)
                    UIDropDownMenu_SetText(zoneFilterDropdown, zone)
                    BiSGearCheck.zoneFilter = self.value
                    BiSGearCheck:RefreshView()
                end
                zInfo.notCheckable = true
                UIDropDownMenu_AddButton(zInfo, level)
            end
        end
    end
    UIDropDownMenu_Initialize(zoneFilterDropdown, ZoneFilterInit)
    UIDropDownMenu_SetText(zoneFilterDropdown, "All Zones")
    zoneFilterDropdown:Hide()

    f.collapseAllBtn = collapseAllBtn
    f.expandAllBtn = expandAllBtn
    f.zoneFilterDropdown = zoneFilterDropdown
    f.compareWLDropdown = compareWLDropdown
    f.compareWLLabel = compareWLLabel
end

-- ============================================================
-- BIS LISTS BAR: Data Source + All-Specs dropdown
-- ============================================================

function BiSGearCheck:SetupBisListBar(f)
    local bislistBar = CreateFrame("Frame", nil, f)
    bislistBar:SetHeight(26)
    bislistBar:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -60)
    bislistBar:SetPoint("RIGHT", f, "RIGHT", -10, 0)
    bislistBar:Hide()

    local bislistSourceDropdown = CreateFrame("Frame", "BiSGearCheckBislistSourceDropdown", bislistBar, "UIDropDownMenuTemplate")
    bislistSourceDropdown:SetPoint("TOPLEFT", f, "TOPLEFT", -5, -60)
    UIDropDownMenu_SetWidth(bislistSourceDropdown, 100)

    local function addBislistSourceButton(level, srcInfo)
        local info = UIDropDownMenu_CreateInfo()
        info.text = srcInfo.label
        info.value = srcInfo.key
        info.func = function(self)
            UIDropDownMenu_SetSelectedValue(bislistSourceDropdown, self.value)
            UIDropDownMenu_SetText(bislistSourceDropdown, self:GetText())
            BiSGearCheck:SetDataSource(self.value)
        end
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)
    end

    local function BislistSourceInit(self, level)
        for _, srcInfo in ipairs(BiSGearCheck:GetEnabledDataSourcesForPhase()) do
            addBislistSourceButton(level, srcInfo)
        end
        if BiSGearCheck.GetCompareEnabledWishlists then
            for _, srcInfo in ipairs(BiSGearCheck:GetCompareEnabledWishlists()) do
                addBislistSourceButton(level, srcInfo)
            end
        end
    end
    UIDropDownMenu_Initialize(bislistSourceDropdown, BislistSourceInit)

    -- Set initial text: published or wishlist
    local function bislistLabelFor(key)
        for _, srcInfo in ipairs(self:GetEnabledDataSourcesForPhase()) do
            if srcInfo.key == key then return srcInfo.label end
        end
        if self.GetCompareEnabledWishlists then
            for _, srcInfo in ipairs(self:GetCompareEnabledWishlists()) do
                if srcInfo.key == key then return srcInfo.label end
            end
        end
    end
    local bislistInitialLabel = bislistLabelFor(self.dataSource)
    if bislistInitialLabel then
        UIDropDownMenu_SetText(bislistSourceDropdown, bislistInitialLabel)
    end

    local bislistSpecDropdown = CreateFrame("Frame", "BiSGearCheckBislistSpecDropdown", bislistBar, "UIDropDownMenuTemplate")
    bislistSpecDropdown:SetPoint("LEFT", bislistSourceDropdown, "RIGHT", -15, 0)
    UIDropDownMenu_SetWidth(bislistSpecDropdown, 120)

    local CLASS_ORDER = { "DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR" }

    local function BislistSpecInit(self, level)
        local db = BiSGearCheck:GetActiveDB()
        if not db then return end

        for _, classToken in ipairs(CLASS_ORDER) do
            local specs = BiSGearCheck.ClassSpecs[classToken]
            if specs then
                -- Class header
                local hdr = UIDropDownMenu_CreateInfo()
                local classColor = RAID_CLASS_COLORS[classToken]
                if classColor then
                    hdr.text = string.format("|cff%02x%02x%02x%s|r", classColor.r * 255, classColor.g * 255, classColor.b * 255, classToken:sub(1,1) .. classToken:sub(2):lower())
                else
                    hdr.text = classToken:sub(1,1) .. classToken:sub(2):lower()
                end
                hdr.isTitle = true
                hdr.notCheckable = true
                UIDropDownMenu_AddButton(hdr, level)

                for _, specInfo in ipairs(specs) do
                    if db[specInfo.key] then
                        local sInfo = UIDropDownMenu_CreateInfo()
                        sInfo.text = "  " .. specInfo.label
                        sInfo.value = specInfo.key
                        sInfo.func = function(self)
                            UIDropDownMenu_SetSelectedValue(bislistSpecDropdown, self.value)
                            UIDropDownMenu_SetText(bislistSpecDropdown, self:GetText())
                            BiSGearCheck.bislistSpec = self.value
                            BiSGearCheck:RefreshView()
                        end
                        sInfo.notCheckable = true
                        UIDropDownMenu_AddButton(sInfo, level)
                    end
                end
            end
        end
    end
    UIDropDownMenu_Initialize(bislistSpecDropdown, BislistSpecInit)
    UIDropDownMenu_SetText(bislistSpecDropdown, "Select Spec")

    f.bislistBar = bislistBar
    f.bislistSourceDropdown = bislistSourceDropdown
    f.bislistSpecDropdown = bislistSpecDropdown
end
