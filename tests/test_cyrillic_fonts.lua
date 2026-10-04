-- Regression coverage for Cyrillic names on non-Russian clients.
local T = {}
local CYRILLIC = "Fonts\\FRIZQT___CYR.TTF"
local globals = {}

local function replaceGlobal(name, value)
    globals[#globals + 1] = { name, _G[name] }
    _G[name] = value
end

local function font(path, size, flags, color)
    return {
        path = path or "Fonts\\FRIZQT__.TTF", size = size or 12,
        flags = flags or "", color = color or "white", text = "",
        GetFont = function(self) return self.path, self.size, self.flags end,
        SetFont = function(self, p, s, f) self.path, self.size, self.flags = p, s, f end,
        SetFontObject = function(self, other)
            self.path, self.size, self.flags = other:GetFont()
            self.color = other.color
        end,
        SetText = function(self, text) self.text = text end,
        GetText = function(self) return self.text end,
    }
end

function T.setup()
    globals = {}
    replaceGlobal("hooksecurefunc", function(object, key, hook)
        local original = object[key]
        object[key] = function(self, ...)
            original(self, ...)
            hook(self, ...)
        end
    end)
end

function T.teardown()
    for i = #globals, 1, -1 do _G[globals[i][1]] = globals[i][2] end
end

function T.test_reused_label_switches_fonts_and_preserves_style()
    local fs = font("Custom.ttf", 15, "OUTLINE", "gold")
    BiSGearCheck.Theme.applyFont(fs, "small")
    fs:SetText("|cffffd100MS 01 - Усиления, Ёж, ї|r")
    assert_equal(CYRILLIC, fs.path)
    assert_equal(15, fs.size)
    assert_equal("OUTLINE", fs.flags)
    assert_equal("gold", fs.color)
    fs:SetText("Квесты") -- must not save the fallback as the original
    fs:SetText("English wishlist")
    assert_equal("Custom.ttf", fs.path)
    fs:SetText("中文")
    assert_equal("Custom.ttf", fs.path, "other scripts keep their existing font")
    fs:SetText(nil)
    assert_equal("Custom.ttf", fs.path)
end

function T.test_existing_cyrillic_and_external_font_changes()
    local fs = font()
    fs:SetText("Защита")
    BiSGearCheck.Theme.watchTextFont(fs)
    assert_equal(CYRILLIC, fs.path, "text set before registration is handled")
    fs:SetFont("ElvUI.ttf", 14, "OUTLINE")
    fs:SetText("Усиления")
    assert_equal(CYRILLIC, fs.path)
    assert_equal(14, fs.size)
    fs:SetText("Default")
    assert_equal("ElvUI.ttf", fs.path, "restore the latest external font")
    fs:SetText("Квесты")
    fs:SetFont("Another.ttf", 16, "")
    fs:SetText("Default")
    assert_equal("Another.ttf", fs.path, "do not undo a later skin change")
end

function T.test_dropdown_states_and_reuse_by_another_addon()
    local defaults = {
        Normal = font(), Highlight = font(nil, 12, "OUTLINE"),
        Disabled = font(nil, 12, "", "gray"),
    }
    local button = {}
    for _, state in ipairs({ "Normal", "Highlight", "Disabled" }) do
        button["Get" .. state .. "FontObject"] = function(self) return self[state] end
        button["Set" .. state .. "FontObject"] = function(self, value) self[state] = value end
    end
    replaceGlobal("DropDownList2", { numButtons = 1, GetName = function() return "DropDownList2" end })
    replaceGlobal("DropDownList2Button1", button)
    local created = 0
    replaceGlobal("CreateFont", function() created = created + 1; return font() end)
    replaceGlobal("UIDropDownMenu_AddButton", function()
        -- Blizzard resets all three state fonts before assigning each text entry.
        for state, original in pairs(defaults) do button[state] = original end
    end)
    BiSGearCheck.Theme.addDropdownButton({ text = "Квесты", disabled = true }, 2)
    for state, original in pairs(defaults) do
        assert_equal(CYRILLIC, button[state].path)
        assert_equal(original.flags, button[state].flags)
        assert_equal(original.color, button[state].color)
        assert_equal("Fonts\\FRIZQT__.TTF", original.path, "shared fonts stay untouched")
    end
    assert_true(DropDownList2.shouldRefresh)
    BiSGearCheck.Theme.addDropdownButton({ text = "Защита" }, 2)
    assert_equal(3, created, "font objects are reused")
    UIDropDownMenu_AddButton({ text = "Another addon's menu" }, 2)
    for state, original in pairs(defaults) do assert_equal(original, button[state]) end
end

function T.test_tooltip_only_changes_appended_header_and_restores_on_clear()
    local tt = { lines = 1, hooks = {} }
    function tt:IsForbidden() return false end
    function tt:GetItem() return "Test", "item:12345" end
    function tt:GetName() return "TestCyrillicTooltip" end
    function tt:NumLines() return self.lines end
    function tt:HookScript(event, hook)
        assert_nil(self.hooks[event], "only one restoration hook is installed")
        self.hooks[event] = hook
    end
    function tt:AddLine() self.lines = self.lines + 1 end
    function tt:AddDoubleLine(text)
        self.lines = self.lines + 1
        _G[self:GetName() .. "TextLeft" .. self.lines]:SetText(text)
    end
    function tt:Show() end
    for i = 1, 4 do replaceGlobal(tt:GetName() .. "TextLeft" .. i, font()) end
    TestCyrillicTooltipTextLeft1:SetText("Чужая строка")
    BiSGearCheckSaved = { tooltip = { showBiS = true, showOnlyMyClass = false } }
    BiSGearCheck.phaseFilter = 1
    BiSGearCheck.TooltipIndex = { ["12345"] = {
        { source = "wishlist", sourceLabel = "Квесты", spec = "Fury", class = "WARRIOR" },
    } }
    BiSGearCheck:OnTooltipSetItem(tt)
    assert_equal("Fonts\\FRIZQT__.TTF", TestCyrillicTooltipTextLeft1.path)
    assert_equal(CYRILLIC, TestCyrillicTooltipTextLeft3.path)
    tt.hooks.OnTooltipCleared()
    assert_equal("Fonts\\FRIZQT__.TTF", TestCyrillicTooltipTextLeft3.path)
    tt.lines = 1
    BiSGearCheck:OnTooltipSetItem(tt)
    tt.hooks.OnTooltipCleared()
    assert_equal("Fonts\\FRIZQT__.TTF", TestCyrillicTooltipTextLeft3.path)
end

return T
