local api = require("api")
local SettingsWidgets = require("nuzi-ui/settings_widgets")
local MountGliderCatalog = require("nuzi-ui/mount_glider_catalog")
local MountGliderLearning = require("nuzi-ui/mount_glider_learning")

local Custom = {}

local CreateLabel = SettingsWidgets.CreateLabel
local CreateHintLabel = SettingsWidgets.CreateHintLabel
local CreateCheckbox = SettingsWidgets.CreateCheckbox
local CreateButton = SettingsWidgets.CreateButton
local CreateEdit = SettingsWidgets.CreateEdit
local CreateSlider = SettingsWidgets.CreateSlider
local CreateComboBox = SettingsWidgets.CreateComboBox
local GetComboBoxIndex1Based = SettingsWidgets.GetComboBoxIndex1Based
local SetComboBoxIndex1Based = SettingsWidgets.SetComboBoxIndex1Based

local REPAIR_FRAME_DEFAULTS = {
    { key = "player", label = "Player", x = 10, y = 300 },
    { key = "target", label = "Target", x = 10, y = 380 },
    { key = "watchtarget", label = "Watchtarget", x = 10, y = 460 },
    { key = "target_of_target", label = "Target of Target", x = 10, y = 540 }
}

local REPAIR_COOLDOWN_DEFAULTS = {
    player = { x = 330, y = 100 },
    target = { x = 0, y = -8 },
    watchtarget = { x = 0, y = -8 },
    target_of_target = { x = 0, y = -8 }
}

local function getState(context)
    return type(context) == "table" and context.state or nil
end

local function getControls(context)
    local state = getState(context)
    if type(state) ~= "table" then
        return {}
    end
    if type(state.controls) ~= "table" then
        state.controls = {}
    end
    return state.controls
end

local function setReadableText(context, control, text)
    if type(context) == "table" and type(context.set_text) == "function" then
        context.set_text(control, text)
    elseif control ~= nil and control.SetText ~= nil then
        pcall(function()
            control:SetText(tostring(text or ""))
        end)
    end
end

local function getInterfaceNumber(methodName)
    if api == nil or api.Interface == nil or type(api.Interface[methodName]) ~= "function" then
        return nil
    end
    local ok, value = pcall(function()
        return api.Interface[methodName](api.Interface)
    end)
    if ok then
        return tonumber(value)
    end
    return nil
end

local function roundRepairNumber(value)
    local n = tonumber(value)
    if n == nil then
        return "?"
    end
    return tostring(math.floor(n + 0.5))
end

local function formatRepairPair(pos)
    if type(pos) ~= "table" then
        return "(?, ?)"
    end
    return "(" .. roundRepairNumber(pos.x) .. ", " .. roundRepairNumber(pos.y) .. ")"
end

local function setRepairStatus(context, text)
    local controls = getControls(context)
    setReadableText(context, controls.repair_status, tostring(text or ""))
end

function Custom.RefreshRepairDiagnostics(context)
    local width = getInterfaceNumber("GetScreenWidth")
    local height = getInterfaceNumber("GetScreenHeight")
    local scale = getInterfaceNumber("GetUIScale")
    local screenText = "Screen: unavailable"
    if width ~= nil and height ~= nil then
        screenText = "Screen: " .. roundRepairNumber(width) .. " x " .. roundRepairNumber(height)
    end
    if scale ~= nil then
        if scale > 10 then
            screenText = screenText .. "  UI scale: " .. roundRepairNumber(scale) .. "%"
        else
            screenText = screenText .. "  UI scale: " .. string.format("%.2f", scale)
        end
    else
        screenText = screenText .. "  UI scale: unavailable"
    end

    local state = getState(context)
    local settings = type(state) == "table" and state.settings or nil
    local frameBits = {}
    if type(settings) == "table" then
        for _, item in ipairs(REPAIR_FRAME_DEFAULTS) do
            frameBits[#frameBits + 1] = item.label .. " " .. formatRepairPair(settings[item.key])
        end
    end
    if #frameBits == 0 then
        frameBits[1] = "Frame positions unavailable"
    end

    local launcherText = "Launcher: unavailable"
    local castText = "Cast bar: unavailable"
    if type(settings) == "table" then
        launcherText = "Launcher " .. formatRepairPair(settings.settings_button)
        if type(settings.cast_bar) == "table" then
            castText = "Cast bar (" ..
                roundRepairNumber(settings.cast_bar.pos_x) .. ", " ..
                roundRepairNumber(settings.cast_bar.pos_y) .. ")"
            if settings.cast_bar.position_initialized == false then
                castText = castText .. " not initialized"
            end
        end
    end

    local controls = getControls(context)
    setReadableText(context, controls.repair_display_info, screenText)
    setReadableText(context, controls.repair_frame_info, table.concat(frameBits, "  "))
    setReadableText(context, controls.repair_extra_info, launcherText .. "  " .. castText)
end

local function setRepairPosition(settings, key, x, y)
    if type(settings) ~= "table" or type(key) ~= "string" then
        return
    end
    if type(settings[key]) ~= "table" then
        settings[key] = {}
    end
    settings[key].x = math.floor((tonumber(x) or 0) + 0.5)
    settings[key].y = math.floor((tonumber(y) or 0) + 0.5)
end

local function resetCoreFramePositions(settings)
    for _, item in ipairs(REPAIR_FRAME_DEFAULTS) do
        setRepairPosition(settings, item.key, item.x, item.y)
    end
end

local function centerCoreFramePositions(settings)
    local screenWidth = getInterfaceNumber("GetScreenWidth") or 1920
    local screenHeight = getInterfaceNumber("GetScreenHeight") or 1080
    local frameWidth = tonumber(settings.frame_width) or 320
    local frameHeight = tonumber(settings.frame_height) or 64
    local frameScale = 1
    local hasStyleScale = false
    if type(settings.style) == "table" then
        if tonumber(settings.style.frame_width) ~= nil then
            frameWidth = tonumber(settings.style.frame_width)
        end
        if tonumber(settings.style.frame_scale) ~= nil then
            frameScale = tonumber(settings.style.frame_scale)
            hasStyleScale = true
        end
    end
    if not hasStyleScale and tonumber(settings.frame_scale) ~= nil then
        frameScale = tonumber(settings.frame_scale)
    end
    if frameScale <= 0 then
        frameScale = 1
    end

    local scaledWidth = frameWidth * frameScale
    local rowHeight = math.max(36, (frameHeight * frameScale) + 12)
    local totalHeight = rowHeight * #REPAIR_FRAME_DEFAULTS
    local x = math.floor(((screenWidth - scaledWidth) / 2) + 0.5)
    local y = math.floor(((screenHeight - totalHeight) / 2) + 0.5)
    if x < 0 then
        x = 0
    end
    if y < 0 then
        y = 0
    end

    for index, item in ipairs(REPAIR_FRAME_DEFAULTS) do
        setRepairPosition(settings, item.key, x, y + math.floor((index - 1) * rowHeight + 0.5))
    end
end

local function resetCastBarPosition(settings)
    if type(settings.cast_bar) ~= "table" then
        settings.cast_bar = {}
    end
    settings.cast_bar.pos_x = 0
    settings.cast_bar.pos_y = 0
    settings.cast_bar.anchor_mode = nil
    settings.cast_bar.position_initialized = false
end

local function resetTravelSpeedPosition(settings)
    if type(settings.travel_speed) ~= "table" then
        settings.travel_speed = {}
    end
    settings.travel_speed.pos_x = 260
    settings.travel_speed.pos_y = 170
end

local function resetMountGliderPosition(settings)
    if type(settings.mount_glider) ~= "table" then
        settings.mount_glider = {}
    end
    settings.mount_glider.pos_x = 0
    settings.mount_glider.pos_y = 0
    settings.mount_glider.position_initialized = false
    settings.mount_glider.mount_pos_x = 0
    settings.mount_glider.mount_pos_y = 0
    settings.mount_glider.mount_position_initialized = false
    settings.mount_glider.glider_pos_x = 0
    settings.mount_glider.glider_pos_y = 0
    settings.mount_glider.glider_position_initialized = false
end

local function resetGearLoadoutsPosition(settings)
    if type(settings.gear_loadouts) ~= "table" then
        settings.gear_loadouts = {}
    end
    settings.gear_loadouts.bar_pos_x = 420
    settings.gear_loadouts.bar_pos_y = 240
    settings.gear_loadouts.editor_pos_x = 520
    settings.gear_loadouts.editor_pos_y = 170
end

local function resetLauncherPosition(settings)
    if type(settings.settings_button) ~= "table" then
        settings.settings_button = {}
    end
    settings.settings_button.x = 10
    settings.settings_button.y = 200
    if tonumber(settings.settings_button.size) == nil then
        settings.settings_button.size = 48
    end
end

local function resetNameplateOffsets(settings)
    if type(settings.nameplates) ~= "table" then
        settings.nameplates = {}
    end
    settings.nameplates.x_offset = 0
    settings.nameplates.y_offset = 22
    settings.nameplates.anchor_to_nametag = true
end

local function resetCooldownPositions(settings)
    if type(settings.cooldown_tracker) ~= "table" then
        settings.cooldown_tracker = {}
    end
    if type(settings.cooldown_tracker.units) ~= "table" then
        settings.cooldown_tracker.units = {}
    end
    for key, pos in pairs(REPAIR_COOLDOWN_DEFAULTS) do
        if type(settings.cooldown_tracker.units[key]) ~= "table" then
            settings.cooldown_tracker.units[key] = {}
        end
        settings.cooldown_tracker.units[key].pos_x = pos.x
        settings.cooldown_tracker.units[key].pos_y = pos.y
    end
end

local function saveApplyRepair(context, message)
    local state = getState(context)
    if type(state) == "table" and type(state.on_save) == "function" then
        pcall(function()
            state.on_save()
        end)
    end
    if type(state) == "table" and type(state.on_apply) == "function" then
        pcall(function()
            state.on_apply()
        end)
    end
    if type(context) == "table" and type(context.refresh_controls) == "function" then
        pcall(function()
            context.refresh_controls()
        end)
    else
        Custom.RefreshRepairDiagnostics(context)
    end
    setRepairStatus(context, message)
end

local function runRepairAction(context, action, successMessage)
    local state = getState(context)
    if type(state) ~= "table" or type(state.settings) ~= "table" then
        setRepairStatus(context, "Settings are not ready yet.")
        return
    end
    if type(context) == "table" and type(context.apply_controls) == "function" then
        pcall(function()
            context.apply_controls()
        end)
    end

    local ok, err = pcall(function()
        action(state.settings)
    end)
    if ok then
        saveApplyRepair(context, successMessage)
    else
        setRepairStatus(context, "Repair failed: " .. tostring(err))
    end
end

local function createRepairButton(parent, id, text, x, y, width, handler)
    local button = CreateButton(id, parent, text, x, y)
    if button ~= nil then
        pcall(function()
            button:SetExtent(width or 170, 24)
        end)
        if button.SetHandler ~= nil then
            button:SetHandler("OnClick", handler)
        end
    end
    return button
end

local function getMountGliderSettings(context)
    local state = getState(context)
    local settings = type(state) == "table" and state.settings or nil
    if type(settings) ~= "table" then
        return nil
    end
    if type(settings.mount_glider) ~= "table" then
        settings.mount_glider = {}
    end
    if type(settings.mount_glider.selected_devices) ~= "table" then
        settings.mount_glider.selected_devices = {}
    end
    if type(settings.mount_glider.selected_abilities) ~= "table" then
        settings.mount_glider.selected_abilities = {}
    end
    if type(settings.mount_glider.learned_gliders) ~= "table" then
        settings.mount_glider.learned_gliders = {}
    end
    if type(settings.mount_glider.learned_mounts) ~= "table" then
        settings.mount_glider.learned_mounts = {}
    end
    if type(settings.mount_glider.selected_mount) ~= "string" then
        settings.mount_glider.selected_mount = ""
    end
    if type(settings.mount_glider.selected_glider) ~= "string" then
        settings.mount_glider.selected_glider = ""
    end
    return settings.mount_glider
end

local function setWidgetShown(widget, shown)
    if widget ~= nil and widget.Show ~= nil then
        pcall(function()
            widget:Show(shown and true or false)
        end)
    end
    local label = type(widget) == "table" and widget.__polar_label_widget or nil
    if label ~= nil and label.Show ~= nil then
        pcall(function()
            label:Show(shown and true or false)
        end)
    end
end

local function getEditText(field)
    if field == nil or field.GetText == nil then
        return ""
    end
    local ok, value = pcall(function()
        return field:GetText()
    end)
    if ok and value ~= nil then
        return tostring(value)
    end
    return ""
end

local function setCheckboxText(context, checkbox, text)
    if checkbox ~= nil and checkbox.__polar_label_widget ~= nil then
        setReadableText(context, checkbox.__polar_label_widget, text)
        return
    end
    if checkbox ~= nil and checkbox.SetText ~= nil then
        pcall(function()
            checkbox:SetText(tostring(text or ""))
        end)
    end
end

local function makeDeviceMenu(devices)
    local items = {
        { key = "", label = "None" }
    }
    local labels = { "None" }
    for _, device in ipairs(devices or {}) do
        items[#items + 1] = {
            key = device.key,
            label = tostring(device.name or "")
        }
        labels[#labels + 1] = tostring(device.name or "")
    end
    return items, labels
end

local function setComboItems(combo, labels)
    if combo == nil then
        return
    end
    combo.__polar_items = labels
    combo.dropdownItem = labels
    if combo.AddItem ~= nil then
        pcall(function()
            if combo.Clear ~= nil then
                combo:Clear()
            elseif combo.RemoveAllItems ~= nil then
                combo:RemoveAllItems()
            end
            for _, label in ipairs(labels or {}) do
                combo:AddItem(tostring(label))
            end
        end)
    end
end

local function findMenuIndex(items, key)
    key = tostring(key or "")
    for index, item in ipairs(items or {}) do
        if item.key == key then
            return index
        end
    end
    return 1
end

local function getMenuIndexFromEvent(combo, items, eventArg1, eventArg2)
    local labels = type(combo) == "table" and combo.__polar_items or nil
    local function indexFromText(value)
        value = tostring(value or "")
        if value == "" or type(items) ~= "table" then
            return nil
        end
        for index, item in ipairs(items) do
            if tostring(item.label or "") == value then
                return index
            end
        end
        return nil
    end
    local textIndex = indexFromText(eventArg2) or indexFromText(eventArg1)
    if textIndex ~= nil then
        return textIndex
    end
    for _, raw in ipairs({ tonumber(eventArg2), tonumber(eventArg1) }) do
        if type(raw) == "number" then
            local idx = math.floor(raw + 0.5)
            local base = type(combo) == "table" and combo.__polar_index_base or nil
            if base == 0 and items[idx + 1] ~= nil then
                return idx + 1
            elseif base == 1 and items[idx] ~= nil then
                return idx
            elseif type(labels) == "table" then
                if labels[idx] ~= nil then
                    return idx
                elseif labels[idx + 1] ~= nil then
                    return idx + 1
                end
            elseif idx >= 1 and idx <= #items then
                return idx
            elseif idx >= 0 and idx < #items then
                return idx + 1
            end
        end
    end
    return GetComboBoxIndex1Based(combo, #items) or 1
end

local function migrateMountGliderSelection(context)
    local cfg = getMountGliderSettings(context)
    if type(cfg) ~= "table" then
        return
    end
    local hasMount = cfg.selected_mount ~= ""
    local hasGlider = cfg.selected_glider ~= ""
    if hasMount and MountGliderCatalog.GetDevice(cfg.selected_mount, cfg) == nil then
        cfg.selected_abilities[cfg.selected_mount] = nil
        cfg.selected_mount = ""
        hasMount = false
    end
    if hasGlider and MountGliderCatalog.GetDevice(cfg.selected_glider, cfg) == nil then
        cfg.selected_abilities[cfg.selected_glider] = nil
        cfg.selected_glider = ""
        hasGlider = false
    end
    if hasMount and hasGlider then
        return
    end
    for _, device in ipairs(MountGliderCatalog.GetDevices(cfg)) do
        if cfg.selected_devices[device.key] == true then
            if device.kind == "Mount" and not hasMount then
                cfg.selected_mount = device.key
                MountGliderCatalog.EnsureAbilitySelection(cfg.selected_abilities, device)
                hasMount = true
            elseif device.kind ~= "Mount" and not hasGlider then
                cfg.selected_glider = device.key
                MountGliderCatalog.EnsureAbilitySelection(cfg.selected_abilities, device)
                hasGlider = true
            end
        end
    end
    cfg.selected_devices = {}
end

local function saveApplyMountGlider(context)
    if type(context) == "table" and type(context.apply_controls) == "function" then
        pcall(function()
            context.apply_controls()
        end)
    end
    local state = getState(context)
    if type(state) == "table" and type(state.on_save) == "function" then
        pcall(function()
            state.on_save()
        end)
    end
    if type(state) == "table" and type(state.on_apply) == "function" then
        pcall(function()
            state.on_apply()
        end)
    end
end

local function getSelectedDevice(context, group)
    local cfg = getMountGliderSettings(context)
    if type(cfg) ~= "table" then
        return nil
    end
    local key = group == "mount" and cfg.selected_mount or cfg.selected_glider
    return MountGliderCatalog.GetDevice(key, cfg)
end

local function setMountGliderStatus(context)
    local controls = getControls(context)
    local mount = getSelectedDevice(context, "mount")
    local glider = getSelectedDevice(context, "glider")
    local text = "Mount: " .. tostring(type(mount) == "table" and mount.name or "None")
        .. "  Glider: " .. tostring(type(glider) == "table" and glider.name or "None")
    setReadableText(context, controls.mount_glider_devices_status, text)
end

local function formatCooldownSeconds(value)
    local ms = tonumber(value) or 0
    if ms <= 0 then
        return ""
    end
    return tostring(math.floor((ms / 1000) + 0.5))
end

local function findLearnedDevice(cfg, deviceKey)
    if type(cfg) ~= "table" then
        return nil
    end
    for _, listKey in ipairs({ "learned_mounts", "learned_gliders" }) do
        for deviceIndex, device in ipairs(type(cfg[listKey]) == "table" and cfg[listKey] or {}) do
            if type(device) == "table" and device.key == deviceKey then
                return device, listKey, deviceIndex
            end
        end
    end
    return nil
end

local function findLearnedAbility(cfg, deviceKey, abilityKey)
    local device, listKey, deviceIndex = findLearnedDevice(cfg, deviceKey)
    if type(device) ~= "table" then
        return nil
    end
    for abilityIndex, ability in ipairs(type(device.abilities) == "table" and device.abilities or {}) do
        if type(ability) == "table" and ability.key == abilityKey then
            return ability, device, listKey, deviceIndex, abilityIndex
        end
    end
    return nil
end

local function saveAbilityCooldown(context, row)
    local cfg = getMountGliderSettings(context)
    local controls = getControls(context)
    if type(cfg) ~= "table" or type(row) ~= "table" then
        return
    end
    local ability = findLearnedAbility(cfg, row.device_key, row.ability_key)
    if type(ability) ~= "table" then
        setReadableText(context, controls.mount_glider_learning_status, "Select a learned ability first.")
        return
    end

    local seconds = tonumber(getEditText(row.cooldown_edit))
    if seconds == nil or seconds <= 0 then
        setReadableText(context, controls.mount_glider_learning_status, "Enter a cooldown in seconds.")
        return
    end
    seconds = math.floor(seconds + 0.5)
    ability.duration_ms = seconds * 1000
    saveApplyMountGlider(context)
    refreshMountGliderSelector(context)
    setReadableText(
        context,
        controls.mount_glider_learning_status,
        "Saved " .. tostring(ability.label or ability.key or "ability") .. " cooldown: " .. tostring(seconds) .. "s."
    )
end

local function refreshAbilityRows(context, group)
    local controls = getControls(context)
    local cfg = getMountGliderSettings(context)
    local device = getSelectedDevice(context, group)
    local rows = group == "mount" and controls.mount_glider_mount_ability_rows or controls.mount_glider_glider_ability_rows
    if type(rows) ~= "table" then
        return
    end
    local abilities = type(device) == "table" and device.abilities or {}
    if type(device) == "table" then
        MountGliderCatalog.EnsureAbilitySelection(cfg.selected_abilities, device)
    end
    for index, row in ipairs(rows) do
        local ability = abilities[index]
        local show = type(ability) == "table"
        setWidgetShown(row.checkbox, show)
        setWidgetShown(row.cooldown_edit, show)
        setWidgetShown(row.cooldown_button, show)
        setWidgetShown(row.remove_button, show)
        if show then
            setCheckboxText(context, row.checkbox, tostring(ability.label or ability.key or "Ability"))
            row.device_key = device.key
            row.ability_key = ability.key
            setReadableText(context, row.cooldown_edit, formatCooldownSeconds(ability.duration_ms))
            if row.checkbox ~= nil and row.checkbox.SetChecked ~= nil then
                local selected = MountGliderCatalog.IsAbilitySelected(cfg.selected_abilities, device, ability)
                pcall(function()
                    row.checkbox:SetChecked(selected)
                end)
            end
        else
            row.device_key = nil
            row.ability_key = nil
        end
    end
end

local function refreshMountGliderSelector(context)
    local controls = getControls(context)
    local cfg = getMountGliderSettings(context)
    if type(cfg) ~= "table" then
        return
    end
    migrateMountGliderSelection(context)
    controls.mount_glider_selector_refreshing = true
    if controls.mount_glider_mount_combo ~= nil and type(controls.mount_glider_mount_items) == "table" then
        SetComboBoxIndex1Based(
            controls.mount_glider_mount_combo,
            findMenuIndex(controls.mount_glider_mount_items, cfg.selected_mount)
        )
    end
    if controls.mount_glider_glider_combo ~= nil and type(controls.mount_glider_glider_items) == "table" then
        SetComboBoxIndex1Based(
            controls.mount_glider_glider_combo,
            findMenuIndex(controls.mount_glider_glider_items, cfg.selected_glider)
        )
    end
    controls.mount_glider_selector_refreshing = false
    refreshAbilityRows(context, "mount")
    refreshAbilityRows(context, "glider")
    setMountGliderStatus(context)
end

local function refreshLearnedGliderMenu(context)
    local controls = getControls(context)
    local cfg = getMountGliderSettings(context)
    if type(cfg) ~= "table" or controls.mount_glider_glider_combo == nil then
        return
    end
    local gliderItems, gliderLabels = makeDeviceMenu(MountGliderCatalog.GetGliderDevices(cfg))
    controls.mount_glider_glider_items = gliderItems
    setComboItems(controls.mount_glider_glider_combo, gliderLabels)
    controls.mount_glider_glider_label_count = #gliderLabels
end

local function refreshLearnedMountMenu(context)
    local controls = getControls(context)
    local cfg = getMountGliderSettings(context)
    if type(cfg) ~= "table" or controls.mount_glider_mount_combo == nil then
        return
    end
    local mountItems, mountLabels = makeDeviceMenu(MountGliderCatalog.GetMountDevices(cfg))
    controls.mount_glider_mount_items = mountItems
    setComboItems(controls.mount_glider_mount_combo, mountLabels)
    controls.mount_glider_mount_label_count = #mountLabels
end

local function removeLearnedAbility(context, row)
    local cfg = getMountGliderSettings(context)
    local controls = getControls(context)
    if type(cfg) ~= "table" or type(row) ~= "table" then
        return
    end
    local ability, device, listKey, deviceIndex, abilityIndex = findLearnedAbility(cfg, row.device_key, row.ability_key)
    if type(ability) ~= "table" or type(device) ~= "table" then
        setReadableText(context, controls.mount_glider_learning_status, "Select a learned ability first.")
        return
    end

    table.remove(device.abilities, abilityIndex)
    if type(cfg.selected_abilities[device.key]) == "table" then
        cfg.selected_abilities[device.key][ability.key] = nil
    end

    local removedDevice = false
    if #device.abilities == 0 then
        table.remove(cfg[listKey], deviceIndex)
        cfg.selected_abilities[device.key] = nil
        if cfg.selected_mount == device.key then
            cfg.selected_mount = ""
        end
        if cfg.selected_glider == device.key then
            cfg.selected_glider = ""
        end
        removedDevice = true
    else
        local labels = {}
        for _, item in ipairs(device.abilities) do
            labels[#labels + 1] = tostring(item.label or item.key)
        end
        device.summary = table.concat(labels, ", ")
    end

    refreshLearnedMountMenu(context)
    refreshLearnedGliderMenu(context)
    refreshMountGliderSelector(context)
    saveApplyMountGlider(context)

    local text = "Removed " .. tostring(ability.label or ability.key or "ability") .. "."
    if removedDevice then
        text = text .. " Removed the learned device because it has no skills left."
    end
    setReadableText(context, controls.mount_glider_learning_status, text)
end

local function removeLearnedDevice(context, group)
    local cfg = getMountGliderSettings(context)
    local controls = getControls(context)
    if type(cfg) ~= "table" then
        return
    end

    local key = group == "mount" and cfg.selected_mount or cfg.selected_glider
    local device = MountGliderCatalog.GetDevice(key, cfg)
    local label = group == "mount" and "mount" or "glider/magithopter"
    if type(device) ~= "table" or device.learned ~= true then
        setReadableText(context, controls.mount_glider_learning_status, "Select a learned " .. label .. " to remove.")
        return
    end

    local listKey = group == "mount" and "learned_mounts" or "learned_gliders"
    local list = type(cfg[listKey]) == "table" and cfg[listKey] or {}
    for index = #list, 1, -1 do
        if type(list[index]) == "table" and list[index].key == key then
            table.remove(list, index)
        end
    end
    cfg.selected_devices[key] = nil
    cfg.selected_abilities[key] = nil
    if group == "mount" then
        cfg.selected_mount = ""
        refreshLearnedMountMenu(context)
    else
        cfg.selected_glider = ""
        refreshLearnedGliderMenu(context)
    end
    refreshMountGliderSelector(context)
    saveApplyMountGlider(context)
    setReadableText(context, controls.mount_glider_learning_status, "Removed " .. tostring(device.name or label) .. ".")
end

local function startMountGliderLearning(context)
    local ok, message = MountGliderLearning.Start(getMountGliderSettings(context))
    local controls = getControls(context)
    setReadableText(context, controls.mount_glider_learning_status, message)
    return ok
end

local function startMountAdding(context)
    local controls = getControls(context)
    local ok, message = MountGliderLearning.StartMount(getMountGliderSettings(context))
    setReadableText(context, controls.mount_glider_learning_status, message)
    return ok
end

local function addMountSkill(context)
    local controls = getControls(context)
    local ok, message = MountGliderLearning.AddMountSkill(
        getMountGliderSettings(context),
        getEditText(controls.mount_glider_mount_skill_name),
        getEditText(controls.mount_glider_mount_skill_mana)
    )
    setReadableText(context, controls.mount_glider_learning_status, message)
    return ok
end

local function addMountBuffSkills(context)
    local controls = getControls(context)
    local ok, message = MountGliderLearning.AddMountBuffSkills(getMountGliderSettings(context))
    setReadableText(context, controls.mount_glider_learning_status, message)
    return ok
end

local function finishMountGliderLearning(context)
    local cfg = getMountGliderSettings(context)
    if type(cfg) ~= "table" then
        return
    end
    local ok, message, key, abilityKeys = MountGliderLearning.Finish(cfg)
    local controls = getControls(context)
    setReadableText(context, controls.mount_glider_learning_status, message)
    if not ok then
        return
    end
    cfg.selected_devices = {}
    cfg.selected_glider = tostring(key or "")
    local device = MountGliderCatalog.GetDevice(cfg.selected_glider, cfg)
    if type(device) == "table" then
        MountGliderCatalog.EnsureAbilitySelection(cfg.selected_abilities, device)
        if type(cfg.selected_abilities[device.key]) == "table" then
            for _, abilityKey in ipairs(type(abilityKeys) == "table" and abilityKeys or {}) do
                cfg.selected_abilities[device.key][abilityKey] = true
            end
        end
    end
    refreshLearnedGliderMenu(context)
    refreshMountGliderSelector(context)
    saveApplyMountGlider(context)
end

local function finishMountLearning(context)
    local cfg = getMountGliderSettings(context)
    if type(cfg) ~= "table" then
        return
    end
    local ok, message, key, abilityKeys = MountGliderLearning.FinishMount(cfg)
    local controls = getControls(context)
    setReadableText(context, controls.mount_glider_learning_status, message)
    if not ok then
        return
    end
    cfg.selected_devices = {}
    cfg.selected_mount = tostring(key or "")
    local device = MountGliderCatalog.GetDevice(cfg.selected_mount, cfg)
    if type(device) == "table" then
        MountGliderCatalog.EnsureAbilitySelection(cfg.selected_abilities, device)
        if type(cfg.selected_abilities[device.key]) == "table" then
            for _, abilityKey in ipairs(type(abilityKeys) == "table" and abilityKeys or {}) do
                cfg.selected_abilities[device.key][abilityKey] = true
            end
        end
    end
    refreshLearnedMountMenu(context)
    refreshMountGliderSelector(context)
    saveApplyMountGlider(context)
end

local function setSelectedMountGliderDevice(context, group, key)
    local cfg = getMountGliderSettings(context)
    if type(cfg) ~= "table" then
        return
    end
    local device = MountGliderCatalog.GetDevice(key, cfg)
    cfg.selected_devices = {}
    if group == "mount" then
        cfg.selected_mount = type(device) == "table" and device.kind == "Mount" and device.key or ""
        if cfg.selected_mount ~= "" then
            MountGliderCatalog.EnsureAbilitySelection(cfg.selected_abilities, device)
        end
    else
        cfg.selected_glider = type(device) == "table" and device.kind ~= "Mount" and device.key or ""
        if cfg.selected_glider ~= "" then
            MountGliderCatalog.EnsureAbilitySelection(cfg.selected_abilities, device)
        end
    end
    refreshMountGliderSelector(context)
    saveApplyMountGlider(context)
end

local function setSelectedMountGliderAbility(context, row, checked)
    local cfg = getMountGliderSettings(context)
    if type(cfg) ~= "table" or type(row) ~= "table" or row.device_key == nil or row.ability_key == nil then
        return
    end
    if type(cfg.selected_abilities[row.device_key]) ~= "table" then
        cfg.selected_abilities[row.device_key] = {}
    end
    cfg.selected_abilities[row.device_key][row.ability_key] = checked and true or nil
    if row.checkbox ~= nil and row.checkbox.SetChecked ~= nil then
        pcall(function()
            row.checkbox:SetChecked(checked and true or false)
        end)
    end
    refreshMountGliderSelector(context)
    saveApplyMountGlider(context)
end

local function toggleSelectedMountGliderAbility(context, row)
    local cfg = getMountGliderSettings(context)
    if type(cfg) ~= "table" or type(row) ~= "table" then
        return
    end
    local device = MountGliderCatalog.GetDevice(row.device_key, cfg)
    local ability = nil
    if type(device) == "table" then
        for _, item in ipairs(device.abilities or {}) do
            if item.key == row.ability_key then
                ability = item
                break
            end
        end
    end
    if type(device) ~= "table" or type(ability) ~= "table" then
        return
    end
    local checked = not MountGliderCatalog.IsAbilitySelected(cfg.selected_abilities, device, ability)
    setSelectedMountGliderAbility(context, row, checked)
end

function Custom.BuildPlatesGuildColorEditor(context, parent, y)
    local controls = getControls(context)
    controls.plates_guild_color_rows = {}

    local guildLabel = CreateLabel("polarUiPlatesGuildColorNameLbl", parent, "Guild", 0, y, 15)
    if guildLabel ~= nil and guildLabel.SetExtent ~= nil then
        pcall(function()
            guildLabel:SetExtent(50, 18)
        end)
    end
    controls.plates_guild_color_name = CreateEdit("polarUiPlatesGuildColorName", parent, "", 58, y - 4, 180, 22)
    controls.plates_guild_color_add = CreateButton("polarUiPlatesGuildColorAdd", parent, "Add", 250, y - 6)
    controls.plates_guild_color_add_target = CreateButton("polarUiPlatesGuildColorAddTarget", parent, "Use Target", 328, y - 6)
    if controls.plates_guild_color_add ~= nil then
        pcall(function()
            controls.plates_guild_color_add:SetExtent(68, 22)
        end)
    end
    if controls.plates_guild_color_add_target ~= nil then
        pcall(function()
            controls.plates_guild_color_add_target:SetExtent(102, 22)
        end)
    end
    y = y + 28

    controls.plates_guild_color_r, controls.plates_guild_color_r_val = CreateSlider("polarUiPlatesGuildColorR", parent, "R (0-255)", 0, y, 0, 255, 1)
    y = y + 24
    controls.plates_guild_color_g, controls.plates_guild_color_g_val = CreateSlider("polarUiPlatesGuildColorG", parent, "G (0-255)", 0, y, 0, 255, 1)
    y = y + 24
    controls.plates_guild_color_b, controls.plates_guild_color_b_val = CreateSlider("polarUiPlatesGuildColorB", parent, "B (0-255)", 0, y, 0, 255, 1)
    y = y + 30

    for i = 1, 8 do
        local rowY = y
        local rowLabel = CreateLabel("polarUiPlatesGuildColorRow" .. tostring(i), parent, "", 15, rowY, 14)
        if rowLabel ~= nil and rowLabel.SetExtent ~= nil then
            pcall(function()
                rowLabel:SetExtent(300, 18)
            end)
        end
        local rowRemove = CreateButton("polarUiPlatesGuildColorRemove" .. tostring(i), parent, "Remove", 330, rowY - 6)
        if rowRemove ~= nil and rowRemove.SetExtent ~= nil then
            pcall(function()
                rowRemove:SetExtent(80, 22)
            end)
        end
        controls.plates_guild_color_rows[i] = {
            label = rowLabel,
            remove = rowRemove
        }
        y = y + 26
    end

    return y
end

function Custom.BuildRepairDiagnostics(context, parent, y)
    local controls = getControls(context)
    controls.repair_display_info = CreateHintLabel("polarUiRepairDisplayInfo", parent, "", 0, y, 520)
    y = y + 30
    controls.repair_frame_info = CreateHintLabel("polarUiRepairFrameInfo", parent, "", 0, y, 520)
    y = y + 46
    controls.repair_extra_info = CreateHintLabel("polarUiRepairExtraInfo", parent, "", 0, y, 520)
    y = y + 34
    createRepairButton(parent, "polarUiRepairRefresh", "Refresh", 0, y, 120, function()
        Custom.RefreshRepairDiagnostics(context)
        setRepairStatus(context, "Diagnostics refreshed.")
    end)
    Custom.RefreshRepairDiagnostics(context)
    return y + 32
end

function Custom.BuildRepairActions(context, parent, y)
    createRepairButton(parent, "polarUiRepairResetFrames", "Reset Frames", 0, y, 170, function()
        runRepairAction(context, resetCoreFramePositions, "Frame positions reset.")
    end)
    createRepairButton(parent, "polarUiRepairCenterFrames", "Center Frames", 190, y, 170, function()
        runRepairAction(context, centerCoreFramePositions, "Frame positions centered.")
    end)
    y = y + 32

    createRepairButton(parent, "polarUiRepairResetCastBar", "Reset Cast Bar", 0, y, 170, function()
        runRepairAction(context, resetCastBarPosition, "Cast bar position reset.")
    end)
    createRepairButton(parent, "polarUiRepairResetTravelSpeed", "Reset Travel", 190, y, 170, function()
        runRepairAction(context, resetTravelSpeedPosition, "Travel speed position reset.")
    end)
    y = y + 32

    createRepairButton(parent, "polarUiRepairResetLoadouts", "Reset Loadouts", 0, y, 170, function()
        runRepairAction(context, resetGearLoadoutsPosition, "Loadout positions reset.")
    end)
    createRepairButton(parent, "polarUiRepairResetMountGlider", "Reset Mount/Glider", 190, y, 170, function()
        runRepairAction(context, resetMountGliderPosition, "Mount/glider timer position reset.")
    end)
    y = y + 32

    createRepairButton(parent, "polarUiRepairResetLauncher", "Reset Launcher", 0, y, 170, function()
        runRepairAction(context, resetLauncherPosition, "Launcher position reset.")
    end)
    createRepairButton(parent, "polarUiRepairResetPlates", "Reset Nameplates", 190, y, 170, function()
        runRepairAction(context, resetNameplateOffsets, "Nameplate offsets reset.")
    end)
    y = y + 32

    createRepairButton(parent, "polarUiRepairResetCooldowns", "Reset Cooldowns", 0, y, 170, function()
        runRepairAction(context, resetCooldownPositions, "Cooldown tracker positions reset.")
    end)
    y = y + 32

    createRepairButton(parent, "polarUiRepairResetAll", "Reset All Layout", 0, y, 170, function()
        runRepairAction(context, function(settings)
            resetCoreFramePositions(settings)
            resetCastBarPosition(settings)
            resetTravelSpeedPosition(settings)
            resetMountGliderPosition(settings)
            resetGearLoadoutsPosition(settings)
            resetLauncherPosition(settings)
            resetNameplateOffsets(settings)
            resetCooldownPositions(settings)
        end, "All saved layout positions reset.")
    end)
    y = y + 38

    local controls = getControls(context)
    controls.repair_status = CreateHintLabel("polarUiRepairStatus", parent, "", 0, y, 520)
    setRepairStatus(context, "")
    return y + 36
end

function Custom.BuildMountGliderSelector(context, parent, y)
    local controls = getControls(context)
    migrateMountGliderSelection(context)
    local cfg = getMountGliderSettings(context)

    local mountItems, mountLabels = makeDeviceMenu(MountGliderCatalog.GetMountDevices(cfg))
    local gliderItems, gliderLabels = makeDeviceMenu(MountGliderCatalog.GetGliderDevices(cfg))
    controls.mount_glider_mount_items = mountItems
    controls.mount_glider_glider_items = gliderItems

    local function createAbilityRow(prefix, index, rowY)
        local row = {}
        row.checkbox = CreateCheckbox(prefix .. tostring(index), parent, "", 18, rowY)
        local label = row.checkbox ~= nil and row.checkbox.__polar_label_widget or nil
        if label ~= nil and label.SetExtent ~= nil then
            pcall(function()
                label:SetExtent(210, 18)
            end)
        end
        row.cooldown_edit = CreateEdit(prefix .. "Cooldown" .. tostring(index), parent, "", 270, rowY - 4, 48, 22)
        row.cooldown_button = createRepairButton(parent, prefix .. "CooldownSave" .. tostring(index), "Save CD", 326, rowY - 6, 84, function()
            saveAbilityCooldown(context, row)
        end)
        row.remove_button = createRepairButton(parent, prefix .. "Remove" .. tostring(index), "Remove", 416, rowY - 6, 82, function()
            removeLearnedAbility(context, row)
        end)
        return row
    end

    CreateLabel("polarUiMountGliderMountLabel", parent, "Mount", 0, y, 15, 120)
    controls.mount_glider_mount_combo = CreateComboBox(parent, mountLabels, 120, y - 4, 330, 24)
    if controls.mount_glider_mount_combo ~= nil then
        controls.mount_glider_mount_combo.dropdownItem = mountLabels
        controls.mount_glider_mount_label_count = #mountLabels
    end
    y = y + 34

    CreateLabel("polarUiMountGliderMountAbilitiesLabel", parent, "Mount abilities", 0, y, 13, 180)
    CreateLabel("polarUiMountGliderMountCooldownLabel", parent, "Cooldown", 270, y, 13, 90)
    y = y + 24
    controls.mount_glider_mount_ability_rows = {}
    for index = 1, 8 do
        controls.mount_glider_mount_ability_rows[index] = createAbilityRow("polarUiMountGliderMountAbility", index, y)
        y = y + 24
    end

    y = y + 8
    createRepairButton(parent, "polarUiMountGliderMountAdd", "Add/Update Mount", 0, y, 150, function()
        startMountAdding(context)
    end)
    createRepairButton(parent, "polarUiMountGliderMountLearnFinish", "End Mount", 164, y, 116, function()
        finishMountLearning(context)
    end)
    createRepairButton(parent, "polarUiMountGliderMountRemove", "Remove Learned", 294, y, 150, function()
        removeLearnedDevice(context, "mount")
    end)
    y = y + 34
    createRepairButton(parent, "polarUiMountGliderMountLearnBuffs", "Add Buff Skills", 0, y, 150, function()
        addMountBuffSkills(context)
    end)
    y = y + 30
    CreateLabel("polarUiMountGliderMountSkillNameLabel", parent, "No-buff skill name", 0, y, 13, 120)
    controls.mount_glider_mount_skill_name = CreateEdit("polarUiMountGliderMountSkillName", parent, "", 120, y - 4, 180, 22)
    y = y + 28
    CreateLabel("polarUiMountGliderMountSkillManaLabel", parent, "Mana cost", 0, y, 13, 120)
    controls.mount_glider_mount_skill_mana = CreateEdit("polarUiMountGliderMountSkillMana", parent, "", 120, y - 4, 80, 22)
    createRepairButton(parent, "polarUiMountGliderMountLearnStart", "Add No-Buff Skill", 214, y - 6, 136, function()
        addMountSkill(context)
    end)
    y = y + 30

    y = y + 10
    CreateLabel("polarUiMountGliderGliderLabel", parent, "Glider", 0, y, 15, 120)
    controls.mount_glider_glider_combo = CreateComboBox(parent, gliderLabels, 120, y - 4, 330, 24)
    if controls.mount_glider_glider_combo ~= nil then
        controls.mount_glider_glider_combo.dropdownItem = gliderLabels
        controls.mount_glider_glider_label_count = #gliderLabels
    end
    y = y + 34

    CreateLabel("polarUiMountGliderGliderAbilitiesLabel", parent, "Glider abilities", 0, y, 13, 180)
    CreateLabel("polarUiMountGliderGliderCooldownLabel", parent, "Cooldown", 270, y, 13, 90)
    y = y + 24
    controls.mount_glider_glider_ability_rows = {}
    for index = 1, 8 do
        controls.mount_glider_glider_ability_rows[index] = createAbilityRow("polarUiMountGliderGliderAbility", index, y)
        y = y + 24
    end

    y = y + 8
    createRepairButton(parent, "polarUiMountGliderLearnStart", "Add/Update Glider", 0, y, 160, function()
        startMountGliderLearning(context)
    end)
    createRepairButton(parent, "polarUiMountGliderLearnFinish", "End Adding", 174, y, 116, function()
        finishMountGliderLearning(context)
    end)
    createRepairButton(parent, "polarUiMountGliderRemove", "Remove Learned", 304, y, 150, function()
        removeLearnedDevice(context, "glider")
    end)
    y = y + 32

    controls.mount_glider_learning_status = CreateHintLabel("polarUiMountGliderLearningStatus", parent, "", 0, y, 520)
    setReadableText(context, controls.mount_glider_learning_status, MountGliderLearning.GetStatus())
    y = y + 42

    controls.mount_glider_devices_status = CreateHintLabel("polarUiMountGliderDeviceStatus", parent, "", 0, y + 4, 520)
    y = y + 34

    local function bindDeviceCombo(combo, group)
        if combo == nil then
            return
        end
        local function selected(a, b, source)
            if controls.mount_glider_selector_refreshing then
                return
            end
            local activeCombo = source or combo
            local items = group == "mount" and controls.mount_glider_mount_items or controls.mount_glider_glider_items
            items = type(items) == "table" and items or { { key = "", label = "None" } }
            local index = getMenuIndexFromEvent(activeCombo, items, a, b)
            local item = items[index] or items[1]
            setSelectedMountGliderDevice(context, group, item.key)
        end
        function combo:SelectedProc()
            selected(nil, nil, self)
        end
        if combo.SetHandler ~= nil then
            combo:SetHandler("OnSelChanged", function(a, b)
                selected(a, b, combo)
            end)
        end
    end

    local function bindAbilityRows(rows)
        for _, row in ipairs(rows or {}) do
            local checkbox = row.checkbox
            if checkbox ~= nil and checkbox.SetHandler ~= nil then
                checkbox:SetHandler("OnClick", function()
                    toggleSelectedMountGliderAbility(context, row)
                end)
            end
            local label = checkbox ~= nil and checkbox.__polar_label_widget or nil
            if label ~= nil and label.SetHandler ~= nil then
                label:SetHandler("OnClick", function()
                    toggleSelectedMountGliderAbility(context, row)
                end)
            end
        end
    end

    bindDeviceCombo(controls.mount_glider_mount_combo, "mount")
    bindDeviceCombo(controls.mount_glider_glider_combo, "glider")
    bindAbilityRows(controls.mount_glider_mount_ability_rows)
    bindAbilityRows(controls.mount_glider_glider_ability_rows)

    refreshMountGliderSelector(context)
    return y
end

function Custom.RefreshMountGliderSelector(context)
    refreshMountGliderSelector(context)
end

function Custom.OnUpdate(context, dt)
    if MountGliderLearning.OnUpdate(dt) then
        local controls = getControls(context)
        setReadableText(context, controls.mount_glider_learning_status, MountGliderLearning.GetStatus())
    end
end

function Custom.Unload()
    MountGliderLearning.Cancel()
end

function Custom.BuildGearLoadoutActions(context, parent, y)
    local editButton = createRepairButton(parent, "polarUiGearLoadoutsEdit", "Edit Loadouts", 0, y, 150, function()
        if type(context) == "table" and type(context.apply_controls) == "function" then
            pcall(function()
                context.apply_controls()
            end)
        end
        local state = getState(context)
        if type(state) == "table" and type(state.on_save) == "function" then
            pcall(function()
                state.on_save()
            end)
        end
        if type(state) == "table" and type(state.on_apply) == "function" then
            pcall(function()
                state.on_apply()
            end)
        end
        local gearLoadouts = type(context) == "table" and context.gear_loadouts or nil
        if gearLoadouts ~= nil and gearLoadouts.ToggleEditor ~= nil then
            pcall(function()
                gearLoadouts.ToggleEditor(type(state) == "table" and state.settings or nil)
            end)
        end
    end)
    getControls(context).gear_loadouts_edit = editButton
    return y + 34
end

return Custom
