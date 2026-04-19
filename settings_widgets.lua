local api = require("api")

local SettingsWidgets = {}
local CreateNuziSlider = nil
local THEME = {
    title = { 0.98, 0.90, 0.72, 1 },
    heading = { 0.96, 0.88, 0.70, 1 },
    text = { 0.95, 0.93, 0.90, 1 },
    hint = { 0.78, 0.74, 0.68, 1 }
}

pcall(function()
    CreateNuziSlider = require("nuzi-core/ui/slider")
end)

local function setLabelStyle(label, fontSize, color)
    if label == nil or label.style == nil then
        return
    end
    pcall(function()
        label.style:SetFontSize(fontSize)
        label.style:SetAlign(ALIGN.LEFT)
        label.style:SetColor(color[1], color[2], color[3], color[4] or 1)
        if label.style.SetShadow ~= nil then
            label.style:SetShadow(true)
        end
        if label.style.SetEllipsis ~= nil then
            label.style:SetEllipsis(false)
        end
    end)
end

local function applyWidgetTextStyle(widget, fontSize, color)
    if type(widget) ~= "table" then
        return
    end

    local seen = {}
    for _, candidate in ipairs({
        widget,
        widget.label,
        widget.text,
        widget.textLabel,
        widget.textButton,
        widget.titleLabel,
        widget.selectedText,
        widget.editbox,
        widget.editBox
    }) do
        if type(candidate) == "table" and candidate.style ~= nil and not seen[candidate] then
            seen[candidate] = true
            setLabelStyle(candidate, fontSize, color)
        end
    end
end

local function estimateCharsPerLine(width, fontSize)
    local safeWidth = math.max(80, tonumber(width) or 520)
    local safeFont = math.max(10, tonumber(fontSize) or 12)
    return math.max(14, math.floor(safeWidth / math.max(6, safeFont * 0.55)))
end

local function wrapTextToWidth(text, width, fontSize)
    local content = tostring(text or "")
    local charsPerLine = estimateCharsPerLine(width, fontSize)
    local lines = {}

    local function pushLine(value)
        lines[#lines + 1] = value or ""
    end

    local function wrapParagraph(segment)
        if segment == "" then
            pushLine("")
            return
        end

        local current = ""
        for word in string.gmatch(segment, "%S+") do
            local wordLen = string.len(word)
            if wordLen > charsPerLine then
                if current ~= "" then
                    pushLine(current)
                    current = ""
                end
                local index = 1
                while index <= wordLen do
                    local chunk = string.sub(word, index, index + charsPerLine - 1)
                    index = index + charsPerLine
                    if string.len(chunk) >= charsPerLine then
                        pushLine(chunk)
                    else
                        current = chunk
                    end
                end
            elseif current == "" then
                current = word
            elseif (string.len(current) + 1 + wordLen) <= charsPerLine then
                current = current .. " " .. word
            else
                pushLine(current)
                current = word
            end
        end

        if current ~= "" then
            pushLine(current)
        end
    end

    for segment in string.gmatch(content .. "\n", "(.-)\n") do
        wrapParagraph(segment)
    end

    if #lines == 0 then
        lines[1] = ""
    end

    return table.concat(lines, "\n"), #lines
end

local function estimateWrappedTextHeight(text, width, fontSize, lineHeight, minLines)
    local safeFont = math.max(10, tonumber(fontSize) or 12)
    local _, totalLines = wrapTextToWidth(text, width, safeFont)
    totalLines = math.max(tonumber(minLines) or 1, totalLines)
    local step = math.max(safeFont + 4, tonumber(lineHeight) or (safeFont + 4))
    return totalLines * step
end

local function configureWrapping(label, width)
    if label == nil then
        return
    end
    local safeWidth = tonumber(width) or 520
    pcall(function()
        if label.SetAutoResize ~= nil then
            label:SetAutoResize(false)
        end
    end)
    local limitSet = false
    local ok = pcall(function()
        if label.SetLimitWidth ~= nil then
            label:SetLimitWidth(safeWidth)
            limitSet = true
        end
    end)
    if not ok or not limitSet then
        pcall(function()
            if label.SetLimitWidth ~= nil then
                label:SetLimitWidth(true)
            end
        end)
    end
end

local function setWidgetAlpha(widget, alpha)
    if widget == nil then
        return
    end
    pcall(function()
        if widget.SetAlpha ~= nil then
            widget:SetAlpha(alpha)
        end
    end)
end

local function applyCheckboxReadableStyle(widget)
    if type(widget) ~= "table" then
        return
    end
    for _, candidate in ipairs({
        widget,
        widget.label,
        widget.text,
        widget.textLabel,
        widget.textButton,
        widget.titleLabel
    }) do
        if type(candidate) == "table" and candidate.style ~= nil and candidate.style.SetShadow ~= nil then
            pcall(function()
                candidate.style:SetShadow(true)
            end)
        end
    end
end

local function applyWrappedLabelText(label, text, width, fontSize, lineHeight, minLines)
    if label == nil then
        return 0
    end

    local safeWidth = math.max(80, tonumber(width) or tonumber(label.__polar_wrap_width) or 520)
    local safeFont = math.max(10, tonumber(fontSize) or tonumber(label.__polar_font_size) or 12)
    local safeLineHeight = math.max(safeFont + 4, tonumber(lineHeight) or tonumber(label.__polar_line_height) or (safeFont + 4))
    local wrappedText = wrapTextToWidth(text, safeWidth, safeFont)
    local height = estimateWrappedTextHeight(text, safeWidth, safeFont, safeLineHeight, minLines)

    label.__polar_raw_text = tostring(text or "")
    label.__polar_wrap_width = safeWidth
    label.__polar_font_size = safeFont
    label.__polar_line_height = safeLineHeight
    label.__polar_estimated_height = height

    pcall(function()
        label:SetText(wrappedText)
    end)
    pcall(function()
        if label.SetExtent ~= nil then
            label:SetExtent(safeWidth, height)
        end
    end)
    configureWrapping(label, safeWidth)
    return height
end

local function createEmptyWidget(id, parent)
    if parent == nil then
        return nil
    end

    local widget = nil
    pcall(function()
        if parent.CreateChildWidget ~= nil then
            widget = parent:CreateChildWidget("emptywidget", id, 0, true)
        elseif api ~= nil and api.Interface ~= nil and api.Interface.CreateWidget ~= nil then
            widget = api.Interface:CreateWidget("emptywidget", id, parent)
        end
    end)
    return widget
end

function SettingsWidgets.AddPanelBackground(widget, alpha, layer, textureInfo)
    if widget == nil then
        return nil
    end

    local background = nil
    pcall(function()
        if widget.CreateNinePartDrawable ~= nil and TEXTURE_PATH ~= nil and TEXTURE_PATH.HUD ~= nil then
            background = widget:CreateNinePartDrawable(TEXTURE_PATH.HUD, layer or "background")
            if background ~= nil and background.SetTextureInfo ~= nil then
                background:SetTextureInfo(textureInfo or "bg_quest")
            end
        elseif widget.CreateColorDrawable ~= nil then
            background = widget:CreateColorDrawable(0.05, 0.04, 0.03, alpha or 0.86, layer or "background")
        end
    end)

    if background ~= nil then
        pcall(function()
            if background.SetColor ~= nil then
                background:SetColor(0.08, 0.07, 0.05, tonumber(alpha) or 0.86)
            end
            background:AddAnchor("TOPLEFT", widget, 0, 0)
            background:AddAnchor("BOTTOMRIGHT", widget, 0, 0)
        end)
    end

    return background
end

function SettingsWidgets.CreateSectionCard(id, parent, title, hint, x, y, width, height)
    local card = createEmptyWidget(id, parent)
    if card == nil then
        return nil, nil, 0
    end

    local cardWidth = tonumber(width) or 560
    local cardHeight = tonumber(height) or 120
    pcall(function()
        card:AddAnchor("TOPLEFT", parent, x or 0, y or 0)
        card:SetExtent(cardWidth, cardHeight)
        if card.Show ~= nil then
            card:Show(true)
        end
    end)

    SettingsWidgets.AddPanelBackground(card, 0.84)

    pcall(function()
        if card.CreateColorDrawable ~= nil then
            local glow = card:CreateColorDrawable(0.92, 0.78, 0.46, 0.09, "overlay")
            glow:AddAnchor("TOPLEFT", card, 0, 0)
            glow:AddAnchor("TOPRIGHT", card, 0, 0)
            glow:SetHeight(46)
        end
    end)

    local titleLabel = SettingsWidgets.CreateLabel(id .. "Title", card, tostring(title or ""), 18, 14, 17)
    if titleLabel ~= nil and titleLabel.style ~= nil then
        pcall(function()
            titleLabel.style:SetColor(THEME.heading[1], THEME.heading[2], THEME.heading[3], THEME.heading[4])
        end)
    end

    local headerHeight = 42
    if type(hint) == "string" and hint ~= "" then
        local hintLabel = SettingsWidgets.CreateHintLabel(id .. "Hint", card, hint, 18, 36, cardWidth - 36)
        if hintLabel ~= nil and hintLabel.SetExtent ~= nil then
            local hintHeight = tonumber(hintLabel.__polar_estimated_height) or
                estimateWrappedTextHeight(hint, cardWidth - 36, 12, 16, 1)
            pcall(function()
                hintLabel:SetExtent(cardWidth - 36, hintHeight)
            end)
            hintLabel.__polar_estimated_height = hintHeight
        end
        headerHeight = 46 + (tonumber(hintLabel ~= nil and hintLabel.__polar_estimated_height or nil) or 16)
    end

    pcall(function()
        if card.CreateColorDrawable ~= nil then
            local divider = card:CreateColorDrawable(0.88, 0.76, 0.46, 0.16, "overlay")
            divider:AddAnchor("TOPLEFT", card, 16, headerHeight - 8)
            divider:AddAnchor("TOPRIGHT", card, -16, headerHeight - 8)
            divider:SetHeight(1)
        end
    end)

    local body = createEmptyWidget(id .. "Body", card)
    if body ~= nil then
        pcall(function()
            body:AddAnchor("TOPLEFT", card, 16, headerHeight + 6)
            body:SetExtent(cardWidth - 32, math.max(20, cardHeight - headerHeight - 12))
            if body.Show ~= nil then
                body:Show(true)
            end
        end)
    end

    card.__polar_body = body
    card.__polar_header_height = headerHeight
    return card, body, headerHeight
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

function SettingsWidgets.CreateLabel(id, parent, text, x, y, fontSize, width)
    local label = api.Interface:CreateWidget("label", id, parent)
    pcall(function()
        label:AddAnchor("TOPLEFT", x, y)
    end)
    local labelWidth = tonumber(width) or 360
    local color = THEME.text
    if tonumber(fontSize) ~= nil and tonumber(fontSize) >= 18 then
        color = THEME.heading
    elseif tonumber(fontSize) ~= nil and tonumber(fontSize) >= 15 then
        color = THEME.title
    end
    setLabelStyle(label, fontSize, color)
    applyWrappedLabelText(label, text, labelWidth, fontSize, (tonumber(fontSize) or 13) + 4, 1)
    return label
end

function SettingsWidgets.CreateHintLabel(id, parent, text, x, y, width)
    local label = api.Interface:CreateWidget("label", id, parent)
    pcall(function()
        label:AddAnchor("TOPLEFT", x, y)
    end)
    local labelWidth = width or 520
    setLabelStyle(label, 12, THEME.hint)
    applyWrappedLabelText(label, text, labelWidth, 12, 16, 1)
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
        checkbox.__polar_label_widget = checkbox.label or checkbox.text or checkbox.textLabel or checkbox.textButton or checkbox.titleLabel
        if checkbox.__polar_label_widget ~= nil then
            setLabelStyle(checkbox.__polar_label_widget, 13, THEME.text)
        end
        applyCheckboxReadableStyle(checkbox)
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
    setLabelStyle(label, 13, THEME.text)
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

    checkbox.__polar_label_widget = label

    return checkbox
end

function SettingsWidgets.CreateButton(id, parent, text, x, y)
    local button = api.Interface:CreateWidget("button", id, parent)
    button:AddAnchor("TOPLEFT", x, y)
    button:SetExtent(90, 26)
    button:SetText(text)
    api.Interface:ApplyButtonSkin(button, BUTTON_BASIC.DEFAULT)
    pcall(function()
        if button.style ~= nil then
            button.style:SetColor(THEME.text[1], THEME.text[2], THEME.text[3], THEME.text[4])
            if button.style.SetShadow ~= nil then
                button.style:SetShadow(true)
            end
        end
    end)
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
            field.style:SetAlign(ALIGN.LEFT)
        end
    end)
    applyWidgetTextStyle(field, 13, THEME.text)
    return field
end

function SettingsWidgets.GetSliderValue(slider)
    if slider == nil then
        return 0
    end
    if type(slider.__polar_live_value) == "number" then
        return slider.__polar_live_value
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
    if type(value) == "number" then
        slider.__polar_live_value = value
    else
        slider.__polar_live_value = nil
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
    setLabelStyle(label, 13, THEME.text)

    local slider = nil
    if CreateNuziSlider ~= nil then
        local ok, res = pcall(function()
            return CreateNuziSlider(id, parent)
        end)
        if ok then
            slider = res
        end
    end
    if slider == nil and api._Library ~= nil and api._Library.UI ~= nil and api._Library.UI.CreateSlider ~= nil then
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
    setLabelStyle(valueLabel, 13, THEME.title)

    if slider ~= nil then
        slider.__polar_label_widget = label
        slider.__polar_value_label = valueLabel
    end

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
    applyWidgetTextStyle(dropdown, 13, THEME.text)
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

function SettingsWidgets.SetControlEnabled(control, enabled)
    if control == nil then
        return
    end

    local resolved = enabled ~= false
    pcall(function()
        if control.SetEnable ~= nil then
            control:SetEnable(resolved)
        elseif control.Enable ~= nil then
            control:Enable(resolved)
        end
    end)

    local alpha = resolved and 1 or 0.45
    setWidgetAlpha(control, alpha)

    local linked = {
        control.__polar_label_widget,
        control.__polar_value_label,
        control.label,
        control.text,
        control.textLabel,
        control.textButton,
        control.titleLabel
    }
    for _, widget in ipairs(linked) do
        if widget ~= nil then
            setWidgetAlpha(widget, alpha)
        end
    end
end

SettingsWidgets.EstimateTextHeight = estimateWrappedTextHeight
SettingsWidgets.SetWrappedText = applyWrappedLabelText

return SettingsWidgets
