local api = require("api")

local SettingsWidgets = {}

local function setLabelStyle(label, fontSize, color)
    if label == nil or label.style == nil then
        return
    end
    pcall(function()
        label.style:SetFontSize(fontSize)
        label.style:SetAlign(ALIGN.LEFT)
        label.style:SetColor(color[1], color[2], color[3], color[4] or 1)
    end)
end

function SettingsWidgets.CreatePage(id, parent)
    local page = api.Interface:CreateWidget("emptywidget", id, parent)
    pcall(function()
        if page.AddAnchor ~= nil then
            page:AddAnchor("TOPLEFT", parent, 0, 0)
            page:AddAnchor("RIGHT", parent, 0, 0)
        end
    end)
    pcall(function()
        if page.Show ~= nil then
            page:Show(false)
        end
    end)
    return page
end

function SettingsWidgets.CreateLabel(id, parent, text, x, y, fontSize)
    local label = api.Interface:CreateWidget("label", id, parent)
    pcall(function()
        label:AddAnchor("TOPLEFT", x, y)
    end)
    label:SetExtent(360, 20)
    label:SetText(text)
    local titleColor = { 1, 1, 1, 1 }
    if FONT_COLOR ~= nil and FONT_COLOR.TITLE ~= nil then
        titleColor = { FONT_COLOR.TITLE[1] or 1, FONT_COLOR.TITLE[2] or 1, FONT_COLOR.TITLE[3] or 1, 1 }
    end
    setLabelStyle(label, fontSize, titleColor)
    return label
end

function SettingsWidgets.CreateHintLabel(id, parent, text, x, y, width)
    local label = api.Interface:CreateWidget("label", id, parent)
    pcall(function()
        label:AddAnchor("TOPLEFT", x, y)
    end)
    label:SetExtent(width or 520, 18)
    label:SetText(text)
    setLabelStyle(label, 12, { 0.75, 0.75, 0.75, 1 })
    return label
end

function SettingsWidgets.ApplyCheckButtonSkin(checkbox)
    if checkbox == nil or checkbox.CreateImageDrawable == nil then
        return
    end

    pcall(function()
        local function makeBg(coordsX, coordsY)
            local bg = checkbox:CreateImageDrawable("ui/button/check_button.dds", "background")
            bg:SetExtent(18, 17)
            bg:AddAnchor("CENTER", checkbox, 0, 0)
            bg:SetCoords(coordsX, coordsY, 18, 17)
            return bg
        end

        if checkbox.SetNormalBackground ~= nil then
            checkbox:SetNormalBackground(makeBg(0, 0))
        end
        if checkbox.SetHighlightBackground ~= nil then
            checkbox:SetHighlightBackground(makeBg(0, 0))
        end
        if checkbox.SetPushedBackground ~= nil then
            checkbox:SetPushedBackground(makeBg(0, 0))
        end
        if checkbox.SetDisabledBackground ~= nil then
            checkbox:SetDisabledBackground(makeBg(0, 17))
        end
        if checkbox.SetCheckedBackground ~= nil then
            checkbox:SetCheckedBackground(makeBg(18, 0))
        end
        if checkbox.SetDisabledCheckedBackground ~= nil then
            checkbox:SetDisabledCheckedBackground(makeBg(18, 17))
        end
    end)
end

function SettingsWidgets.CreateCheckbox(id, parent, text, x, y)
    local checkbox = nil

    if api._Library ~= nil and api._Library.UI ~= nil and api._Library.UI.CreateCheckButton ~= nil then
        local ok, res = pcall(function()
            return api._Library.UI.CreateCheckButton(id, parent, text)
        end)
        if ok then
            checkbox = res
        end
        if checkbox ~= nil and checkbox.AddAnchor ~= nil then
            local okAnchor = pcall(function()
                checkbox:AddAnchor("TOPLEFT", parent, x, y)
            end)
            if not okAnchor then
                pcall(function()
                    checkbox:AddAnchor("TOPLEFT", x, y)
                end)
            end
        end
        if checkbox ~= nil and checkbox.SetButtonStyle ~= nil then
            checkbox:SetButtonStyle("default")
        end
        return checkbox
    end

    checkbox = api.Interface:CreateWidget("checkbutton", id, parent)
    checkbox:SetExtent(18, 17)
    pcall(function()
        checkbox:AddAnchor("TOPLEFT", parent, x, y)
    end)
    SettingsWidgets.ApplyCheckButtonSkin(checkbox)

    local label = api.Interface:CreateWidget("label", id .. "Label", parent)
    pcall(function()
        label:AddAnchor("LEFT", checkbox, "RIGHT", 6, 0)
    end)
    label:SetExtent(320, 18)
    label:SetText(text)
    setLabelStyle(label, 13, { 1, 1, 1, 1 })
    pcall(function()
        if label.Clickable ~= nil then
            label:Clickable(true)
        end
    end)

    if label.SetHandler ~= nil then
        label:SetHandler("OnClick", function()
            if checkbox ~= nil and checkbox.SetChecked ~= nil and checkbox.GetChecked ~= nil then
                checkbox:SetChecked(not checkbox:GetChecked())
            end
        end)
    end

    return checkbox
end

function SettingsWidgets.CreateButton(id, parent, text, x, y)
    local button = api.Interface:CreateWidget("button", id, parent)
    button:AddAnchor("TOPLEFT", x, y)
    button:SetExtent(90, 26)
    button:SetText(text)
    api.Interface:ApplyButtonSkin(button, BUTTON_BASIC.DEFAULT)
    return button
end

function SettingsWidgets.CreateEdit(id, parent, text, x, y, width, height)
    local field = nil
    pcall(function()
        if W_CTRL ~= nil and W_CTRL.CreateEdit ~= nil then
            field = W_CTRL.CreateEdit(id, parent)
        elseif api.Interface ~= nil and api.Interface.CreateWidget ~= nil then
            field = api.Interface:CreateWidget("edit", id, parent)
        end
    end)
    if field == nil then
        return nil
    end
    pcall(function()
        field:SetExtent(width, height)
        if field.AddAnchor ~= nil then
            local okAnchor = pcall(function()
                field:AddAnchor("TOPLEFT", parent, x, y)
            end)
            if not okAnchor then
                field:AddAnchor("TOPLEFT", x, y)
            end
        end
        if field.SetText ~= nil then
            field:SetText(tostring(text or ""))
        end
        if field.style ~= nil then
            field.style:SetColor(0, 0, 0, 1)
            field.style:SetAlign(ALIGN.LEFT)
        end
    end)
    return field
end

function SettingsWidgets.GetSliderValue(slider)
    if slider == nil then
        return 0
    end
    local ok, res = pcall(function()
        if slider.GetValue ~= nil then
            return slider:GetValue()
        end
        return nil
    end)
    if ok and type(res) == "number" then
        return res
    end
    return 0
end

function SettingsWidgets.SetSliderValue(slider, value)
    if slider == nil then
        return
    end
    pcall(function()
        if slider.SetValue ~= nil then
            slider:SetValue(value, false)
        elseif slider.SetInitialValue ~= nil then
            slider:SetInitialValue(value)
        end
    end)
end

function SettingsWidgets.CreateSlider(id, parent, text, x, y, minVal, maxVal, step)
    local label = api.Interface:CreateWidget("label", id .. "Label", parent)
    pcall(function()
        label:AddAnchor("TOPLEFT", x, y)
    end)
    label:SetExtent(170, 18)
    label:SetText(text)
    setLabelStyle(label, 13, { 1, 1, 1, 1 })

    local slider = nil
    if api._Library ~= nil and api._Library.UI ~= nil and api._Library.UI.CreateSlider ~= nil then
        local ok, res = pcall(function()
            return api._Library.UI.CreateSlider(id, parent)
        end)
        if ok then
            slider = res
        end
    end

    if slider ~= nil then
        pcall(function()
            slider:SetExtent(250, 26)
            slider:AddAnchor("TOPLEFT", x + 175, y - 4)
            slider:SetMinMaxValues(minVal, maxVal)
            if slider.SetStep ~= nil then
                slider:SetStep(step)
            else
                slider:SetValueStep(step)
            end
        end)
    end

    local valueLabel = api.Interface:CreateWidget("label", id .. "Value", parent)
    pcall(function()
        valueLabel:AddAnchor("TOPLEFT", x + 430, y)
    end)
    valueLabel:SetExtent(60, 18)
    valueLabel:SetText("0")
    setLabelStyle(valueLabel, 13, { 1, 1, 1, 1 })

    return slider, valueLabel
end

function SettingsWidgets.CreateComboBox(parent, values, x, y, width, height)
    local dropdown = nil
    pcall(function()
        if W_CTRL ~= nil and W_CTRL.CreateComboBox ~= nil then
            dropdown = W_CTRL.CreateComboBox(parent)
        elseif api.Interface ~= nil and api.Interface.CreateComboBox ~= nil then
            dropdown = api.Interface:CreateComboBox(parent)
        end
    end)
    if dropdown == nil then
        return nil
    end
    dropdown.__polar_items = values
    pcall(function()
        local anchored = false
        if dropdown.AddAnchor ~= nil then
            local okAnchor = pcall(function()
                dropdown:AddAnchor("TOPLEFT", parent, x, y)
            end)
            anchored = okAnchor and true or false
            if not anchored then
                pcall(function()
                    dropdown:AddAnchor("TOPLEFT", x, y)
                end)
            end
        end
        if dropdown.SetExtent ~= nil then
            dropdown:SetExtent(width or 220, height or 24)
        end
        if dropdown.AddItem ~= nil and type(values) == "table" then
            for _, v in ipairs(values) do
                dropdown:AddItem(tostring(v))
            end
        else
            dropdown.dropdownItem = values
        end
        if dropdown.Show ~= nil then
            dropdown:Show(true)
        end
    end)
    return dropdown
end

function SettingsWidgets.GetComboBoxIndexRaw(ctrl)
    if ctrl == nil then
        return nil
    end
    local idx = nil
    if ctrl.GetSelectedIndex ~= nil then
        idx = ctrl:GetSelectedIndex()
    elseif ctrl.GetSelIndex ~= nil then
        idx = ctrl:GetSelIndex()
    end
    return tonumber(idx)
end

function SettingsWidgets.SetComboBoxIndex1Based(ctrl, idx1)
    if ctrl == nil or idx1 == nil then
        return
    end

    local function updateBaseFromRaw(raw)
        raw = tonumber(raw)
        if raw == nil then
            return
        end
        if raw == idx1 then
            ctrl.__polar_index_base = 1
        elseif raw == (idx1 - 1) then
            ctrl.__polar_index_base = 0
        end
    end

    if ctrl.Select ~= nil then
        local selVal = idx1
        if ctrl.GetSelectedIndex ~= nil then
            ctrl.__polar_index_base = 1
            selVal = idx1
        elseif ctrl.GetSelIndex ~= nil then
            ctrl.__polar_index_base = 0
            selVal = idx1 - 1
        end
        ctrl:Select(selVal)
        updateBaseFromRaw(SettingsWidgets.GetComboBoxIndexRaw(ctrl))
        return
    end

    local function trySetter(setter, val)
        local ok = pcall(function()
            setter(ctrl, val)
        end)
        if not ok then
            return nil
        end
        return SettingsWidgets.GetComboBoxIndexRaw(ctrl)
    end

    if ctrl.SetSelectedIndex ~= nil then
        ctrl.__polar_index_base = nil
        local raw = trySetter(ctrl.SetSelectedIndex, idx1)
        updateBaseFromRaw(raw)
        if ctrl.__polar_index_base == nil then
            raw = trySetter(ctrl.SetSelectedIndex, idx1 - 1)
            updateBaseFromRaw(raw)
        end
        return
    end

    if ctrl.SetSelIndex ~= nil then
        ctrl.__polar_index_base = 0
        local raw = trySetter(ctrl.SetSelIndex, idx1 - 1)
        updateBaseFromRaw(raw)
    end
end

function SettingsWidgets.GetComboBoxIndex1Based(ctrl, maxCount)
    local raw = SettingsWidgets.GetComboBoxIndexRaw(ctrl)
    if raw == nil then
        return nil
    end

    local base = ctrl.__polar_index_base
    if base == nil then
        if raw == 0 then
            base = 0
        elseif raw == maxCount then
            base = 1
        elseif raw == (maxCount - 1) then
            base = 0
        else
            base = 1
        end
        ctrl.__polar_index_base = base
    end

    if base == 0 then
        return raw + 1
    end
    return raw
end

function SettingsWidgets.GetComboBoxText(ctrl)
    if ctrl == nil then
        return nil
    end

    local getters = { "GetSelectedText", "GetText", "GetSelectedValue", "GetSelectedItemText" }
    for _, name in ipairs(getters) do
        local fn = ctrl[name]
        if type(fn) == "function" then
            local ok, res = pcall(function()
                return fn(ctrl)
            end)
            if ok and type(res) == "string" and res ~= "" then
                return res
            end
        end
    end

    return nil
end

return SettingsWidgets
