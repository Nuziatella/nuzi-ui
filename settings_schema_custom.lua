local api = require("api")
local SettingsWidgets = require("nuzi-ui/settings_widgets")

local Custom = {}

local CreateLabel = SettingsWidgets.CreateLabel
local CreateHintLabel = SettingsWidgets.CreateHintLabel
local CreateButton = SettingsWidgets.CreateButton
local CreateEdit = SettingsWidgets.CreateEdit
local CreateSlider = SettingsWidgets.CreateSlider

local REPAIR_FRAME_DEFAULTS = {
    { key = "player", label = "Player", x = 10, y = 300 },
    { key = "target", label = "Target", x = 10, y = 380 },
    { key = "watchtarget", label = "Watchtarget", x = 10, y = 460 },
    { key = "target_of_target", label = "Target of Target", x = 10, y = 540 }
}

local REPAIR_COOLDOWN_DEFAULTS = {
    player = { x = 330, y = 100 },
    target = { x = 0, y = -8 },
    playerpet = { x = 0, y = -8 },
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
