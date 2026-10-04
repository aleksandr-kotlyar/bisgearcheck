-- BiSGearCheck UIWishlistControls.lua
-- Wishlist filter bar (zone dropdown, auto-filter), wishlist selector bar, static popup dialogs

BiSGearCheck = BiSGearCheck or {}
local T = BiSGearCheck.Theme

-- ============================================================
-- STATIC POPUP DIALOGS (defined at file scope)
-- ============================================================

-- Helper to get editBox from a static popup frame
local function GetPopupEditBox(dialog)
    return dialog.editBox or _G[dialog:GetName() .. "EditBox"]
end

StaticPopupDialogs["BISGEARCHECK_NEW_WISHLIST"] = {
    text = "Enter a name for the new wishlist:",
    button1 = "Create",
    button2 = "Cancel",
    hasEditBox = true,
    OnAccept = function(self)
        local eb = GetPopupEditBox(self)
        local name = eb and eb:GetText():trim() or ""
        if name ~= "" then
            if BiSGearCheck:CreateWishlist(name) then
                BiSGearCheck:RefreshView()
            else
                print(T.hex("chatError") .. "BiSGearCheck:|r A wishlist named '" .. name .. "' already exists.")
            end
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        local name = self:GetText():trim()
        if name ~= "" then
            if BiSGearCheck:CreateWishlist(name) then
                BiSGearCheck:RefreshView()
            else
                print(T.hex("chatError") .. "BiSGearCheck:|r A wishlist named '" .. name .. "' already exists.")
            end
        end
        parent:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0,
    whileDead = true,
    preferredIndex = 3,
}

-- Rename dialog was a StaticPopup but now also lets the user pick the
-- compare-spec override; built as a custom frame below so it can carry a
-- dropdown alongside the name edit box.

StaticPopupDialogs["BISGEARCHECK_DELETE_WISHLIST"] = {
    text = "Delete wishlist '%s'?\n\nThis cannot be undone.",
    button1 = "Delete",
    button2 = "Cancel",
    OnAccept = function()
        if BiSGearCheck:DeleteWishlist() then
            BiSGearCheck:RefreshView()
        end
    end,
    timeout = 0,
    whileDead = true,
    preferredIndex = 3,
}

-- ============================================================
-- WISHLIST FILTER BAR (zone dropdown + auto-filter checkbox)
-- ============================================================

function BiSGearCheck:SetupWishlistFilterBar(f)
    local filterBar = CreateFrame("Frame", nil, f)
    filterBar:SetHeight(52)
    filterBar:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -60)
    filterBar:SetPoint("RIGHT", f, "RIGHT", -10, 0)
    filterBar:Hide()

    -- Zone dropdown (right-aligned, same row as wishlist name dropdown)
    local zoneDropdown = CreateFrame("Frame", "BiSGearCheckZoneDropdown", filterBar, "UIDropDownMenuTemplate")
    zoneDropdown:SetPoint("TOPRIGHT", f, "TOPRIGHT", 5, -60)
    UIDropDownMenu_SetWidth(zoneDropdown, 130)

    local function ZoneDropdownInit(self, level)
        -- "All Zones" option
        local info = UIDropDownMenu_CreateInfo()
        info.text = "All Zones"
        info.value = ""
        info.func = function(self)
            UIDropDownMenu_SetSelectedValue(zoneDropdown, "")
            UIDropDownMenu_SetText(zoneDropdown, "All Zones")
            BiSGearCheck.wishlistZoneFilter = nil
            BiSGearCheck:RefreshView()
        end
        info.notCheckable = true
        T.addDropdownButton(info, level)

        -- Categorized zones with dividers
        for catIdx, category in ipairs(BiSGearCheck.ZoneCategories) do
            -- Section header (non-clickable divider)
            local hdr = UIDropDownMenu_CreateInfo()
            hdr.text = category.label
            hdr.isTitle = true
            hdr.notCheckable = true
            T.addDropdownButton(hdr, level)

            -- Zone entries in this category
            for _, zone in ipairs(category.zones) do
                local hasItems = BiSGearCheck:ZoneHasWishlistItems(zone)
                local zInfo = UIDropDownMenu_CreateInfo()
                if hasItems then
                    zInfo.text = "  " .. T.hex("zoneHighlight") .. zone .. "|r"
                else
                    zInfo.text = "  " .. zone
                end
                zInfo.value = zone
                zInfo.func = function(self)
                    UIDropDownMenu_SetSelectedValue(zoneDropdown, self.value)
                    UIDropDownMenu_SetText(zoneDropdown, zone)
                    BiSGearCheck.wishlistZoneFilter = self.value
                    BiSGearCheck:RefreshView()
                end
                zInfo.notCheckable = true
                T.addDropdownButton(zInfo, level)
            end
        end
    end
    UIDropDownMenu_Initialize(zoneDropdown, ZoneDropdownInit)
    UIDropDownMenu_SetText(zoneDropdown, "All Zones")

    -- Auto checkbox (right-aligned, below zone dropdown)
    local autoCheck = CreateFrame("CheckButton", "BiSGearCheckAutoFilter", filterBar, "UICheckButtonTemplate")
    autoCheck:SetSize(24, 24)
    autoCheck:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -88)
    autoCheck:SetChecked(self.wishlistAutoFilter)
    autoCheck.text = autoCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    autoCheck.text:SetPoint("RIGHT", autoCheck, "LEFT", -2, 0)
    T.applyFont(autoCheck.text, "small")
    autoCheck.text:SetText("Auto")
    autoCheck:SetScript("OnClick", function(self)
        BiSGearCheck:SetWishlistAutoFilter(self:GetChecked())
        BiSGearCheck:RefreshView()
    end)
    autoCheck:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Auto Zone Filter", 1, 1, 1)
        GameTooltip:AddLine("Automatically filter wishlist by your current zone when in a dungeon or raid.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    autoCheck:SetScript("OnLeave", function() GameTooltip:Hide() end)

    f.filterBar = filterBar
    f.zoneDropdown = zoneDropdown
    f.autoCheck = autoCheck
end

-- ============================================================
-- WISHLIST SELECTOR BAR (dropdown + New / Rename / Delete)
-- ============================================================

-- ============================================================
-- RENAME DIALOG (custom frame — includes compare-spec dropdown)
-- ============================================================
--
-- Replaces the old StaticPopup. Lets the user rename the active wishlist
-- AND set the spec override (used when Enable Compare is on). Spec dropdown
-- has an "(Auto)" option that clears the override so BuildWishlistDB falls
-- back to majority-specKey inference.

local renameDialog  -- built lazily on first open

local function buildRenameDialog()
    local f = CreateFrame("Frame", "BiSGearCheckWLRenameDialog", UIParent, "BackdropTemplate")
    f:SetSize(340, 180)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:Hide()

    local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOP", 0, -14)
    title:SetText("Rename Wishlist")
    f.title = title

    local nameLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    nameLabel:SetPoint("TOPRIGHT", f, "TOPLEFT", 80, -46)
    nameLabel:SetText("Name:")

    local nameBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    nameBox:SetSize(210, 22)
    nameBox:SetPoint("LEFT", nameLabel, "RIGHT", 14, 0)
    nameBox:SetAutoFocus(false)
    nameBox:SetMaxLetters(40)
    T.applyFont(nameBox, "normal")
    nameBox:HookScript("OnTextChanged", function(self)
        T.applyTextFont(self, self:GetText())
    end)
    f.nameBox = nameBox

    local specLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    specLabel:SetPoint("TOPRIGHT", f, "TOPLEFT", 80, -78)
    specLabel:SetText("Compare Spec:")

    local specDropdown = CreateFrame("Frame", "BiSGearCheckWLRenameSpecDropdown", f, "UIDropDownMenuTemplate")
    specDropdown:SetPoint("LEFT", specLabel, "RIGHT", -8, -2)
    UIDropDownMenu_SetWidth(specDropdown, 180)
    f.specDropdown = specDropdown

    local errorLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    errorLabel:SetPoint("BOTTOM", 0, 44)
    errorLabel:SetTextColor(1, 0.3, 0.3)
    errorLabel:SetText("")
    T.watchTextFont(errorLabel)
    f.errorLabel = errorLabel

    local okBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    okBtn:SetSize(90, 22)
    okBtn:SetPoint("BOTTOMRIGHT", -20, 14)
    okBtn:SetText("OK")
    f.okBtn = okBtn

    local cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cancelBtn:SetSize(90, 22)
    cancelBtn:SetPoint("RIGHT", okBtn, "LEFT", -6, 0)
    cancelBtn:SetText("Cancel")
    cancelBtn:SetScript("OnClick", function() f:Hide() end)

    return f
end

local function refreshSpecDropdownLabel(f, charKey, wishlistName)
    if f._specValue then
        UIDropDownMenu_SetText(f.specDropdown, BiSGearCheck:WishlistSpecLabel(f._specValue))
    else
        local inferred = BiSGearCheck:InferWishlistSpec(charKey, wishlistName)
        if inferred then
            UIDropDownMenu_SetText(f.specDropdown, "(Auto: " .. BiSGearCheck:WishlistSpecLabel(inferred) .. ")")
        else
            UIDropDownMenu_SetText(f.specDropdown, "(Auto)")
        end
    end
end

function BiSGearCheck:ShowWishlistRenameDialog()
    if not renameDialog then renameDialog = buildRenameDialog() end
    local f = renameDialog
    local charKey = self.viewingCharKey
    local wishlistName = self.activeWishlist
    local cd = charKey and BiSGearCheckSaved.characters[charKey]
    local class = cd and cd.class
    local specs = class and self.ClassSpecs[class] or {}

    f._origCharKey = charKey
    f._origName    = wishlistName
    f._specValue   = self:GetWishlistSpecOverride(charKey, wishlistName)  -- nil = Auto

    f.nameBox:SetText(wishlistName)
    f.nameBox:HighlightText()
    f.errorLabel:SetText("")

    UIDropDownMenu_Initialize(f.specDropdown, function(_, level)
        local auto = UIDropDownMenu_CreateInfo()
        auto.text = "(Auto)"
        auto.notCheckable = true
        auto.func = function()
            f._specValue = nil
            refreshSpecDropdownLabel(f, f._origCharKey, f._origName)
        end
        T.addDropdownButton(auto, level)
        for _, spec in ipairs(specs) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = spec.label
            info.value = spec.key
            info.notCheckable = true
            info.func = function()
                f._specValue = spec.key
                refreshSpecDropdownLabel(f, f._origCharKey, f._origName)
            end
            T.addDropdownButton(info, level)
        end
    end)
    refreshSpecDropdownLabel(f, charKey, wishlistName)

    f.okBtn:SetScript("OnClick", function()
        local newName = f.nameBox:GetText():trim()
        if newName == "" then
            f.errorLabel:SetText("Name cannot be empty")
            return
        end
        -- Rename only if the name actually changed (avoids a self-collision)
        if newName ~= f._origName then
            if not BiSGearCheck:RenameWishlist(newName) then
                f.errorLabel:SetText("A wishlist named '" .. newName .. "' already exists")
                return
            end
        end
        BiSGearCheck:SetWishlistSpecOverride(f._origCharKey, newName, f._specValue)
        BiSGearCheck:OnSourceSettingsChanged()
        BiSGearCheck:RefreshView()
        f:Hide()
    end)
    f:Show()
end

function BiSGearCheck:SetupWishlistSelectorBar(f)
    local wlSelectorBar = CreateFrame("Frame", nil, f)
    wlSelectorBar:SetHeight(52)
    wlSelectorBar:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -60)
    wlSelectorBar:SetPoint("RIGHT", f, "RIGHT", -10, 0)
    wlSelectorBar:Hide()

    -- Wishlist name dropdown (left side, row 2)
    local wlNameDropdown = CreateFrame("Frame", "BiSGearCheckWLNameDropdown", wlSelectorBar, "UIDropDownMenuTemplate")
    wlNameDropdown:SetPoint("TOPLEFT", f, "TOPLEFT", -5, -60)
    UIDropDownMenu_SetWidth(wlNameDropdown, 130)

    local function WLNameDropdownInit(self, level)
        local names = BiSGearCheck:GetWishlistNames()
        for _, name in ipairs(names) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = name
            info.value = name
            info.func = function(self)
                UIDropDownMenu_SetSelectedValue(wlNameDropdown, self.value)
                UIDropDownMenu_SetText(wlNameDropdown, self.value)
                BiSGearCheck:SetActiveWishlist(self.value)
            end
            info.notCheckable = true
            T.addDropdownButton(info, level)
        end
    end
    UIDropDownMenu_Initialize(wlNameDropdown, WLNameDropdownInit)
    UIDropDownMenu_SetText(wlNameDropdown, self.activeWishlist)

    -- New / Rename / Delete buttons (below wishlist dropdown, row 3)
    local wlNewBtn = CreateFrame("Button", nil, wlSelectorBar, "UIPanelButtonTemplate")
    wlNewBtn:SetSize(50, 22)
    wlNewBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -88)
    wlNewBtn:SetText("New")
    wlNewBtn:SetScript("OnClick", function()
        StaticPopup_Show("BISGEARCHECK_NEW_WISHLIST")
    end)

    local wlRenameBtn = CreateFrame("Button", nil, wlSelectorBar, "UIPanelButtonTemplate")
    wlRenameBtn:SetSize(60, 22)
    wlRenameBtn:SetPoint("LEFT", wlNewBtn, "RIGHT", 2, 0)
    wlRenameBtn:SetText("Rename")
    wlRenameBtn:SetScript("OnClick", function()
        BiSGearCheck:ShowWishlistRenameDialog()
    end)

    local wlDeleteBtn = CreateFrame("Button", nil, wlSelectorBar, "UIPanelButtonTemplate")
    wlDeleteBtn:SetSize(55, 22)
    wlDeleteBtn:SetPoint("LEFT", wlRenameBtn, "RIGHT", 2, 0)
    wlDeleteBtn:SetText("Delete")
    wlDeleteBtn:SetScript("OnClick", function()
        StaticPopupDialogs["BISGEARCHECK_DELETE_WISHLIST"].text = "Delete wishlist '" .. BiSGearCheck.activeWishlist .. "'?\n\nThis cannot be undone."
        StaticPopup_Show("BISGEARCHECK_DELETE_WISHLIST")
    end)

    -- "Enable Compare" checkbox — opts the active wishlist in as a
    -- comparison source. When checked, the wishlist appears in the Compare
    -- tab's source dropdown as "{CharName}: {WishlistName}".
    local wlCompareCheck = CreateFrame("CheckButton", "BiSGearCheckWLEnableCompare", wlSelectorBar, "UICheckButtonTemplate")
    wlCompareCheck:SetSize(24, 24)
    wlCompareCheck:SetPoint("LEFT", wlDeleteBtn, "RIGHT", 12, 0)
    wlCompareCheck.text = wlCompareCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    wlCompareCheck.text:SetPoint("LEFT", wlCompareCheck, "RIGHT", 2, 0)
    T.applyFont(wlCompareCheck.text, "small")
    wlCompareCheck.text:SetText("Enable Compare")
    wlCompareCheck:SetScript("OnClick", function(self)
        BiSGearCheck:SetWishlistCompareEnabled(
            BiSGearCheck.viewingCharKey,
            BiSGearCheck.activeWishlist,
            self:GetChecked()
        )
        BiSGearCheck:OnSourceSettingsChanged()
    end)
    wlCompareCheck:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Enable Compare", 1, 1, 1)
        GameTooltip:AddLine("Make this wishlist selectable as a comparison source on the Compare tab. All wishlist items are used regardless of which spec was active when they were added.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    wlCompareCheck:SetScript("OnLeave", function() GameTooltip:Hide() end)

    f.wlSelectorBar = wlSelectorBar
    f.wlNameDropdown = wlNameDropdown
    f.wlCompareCheck = wlCompareCheck
end
