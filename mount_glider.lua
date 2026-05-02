local api = require("api")
local Layout = require("nuzi-ui/layout")
local SettingsStore = require("nuzi-ui/settings_store")
local Catalog = require("nuzi-ui/mount_glider_catalog")

local MountGlider = {
    settings = nil,
    enabled = true,
    frame = nil,
    slots = {},
    slots_by_key = {},
    row_labels = {},
    icon_cache = {},
    buff_scan = {},
    manual_timers = {},
    accum_ms = 0,
    mana_initialized = false,
    last_mount_id = nil,
    last_mount_mana = 0,
    last_player_mana = 0
}

local WINDOW_ID = "NuziUiMountGliderTracker"
local DEFAULT_ICON_SIZE = 36
local DEFAULT_ICON_SPACING = 6
local DEFAULT_ICONS_PER_ROW = 9
local DEFAULT_TIMER_FONT_SIZE = 14
local DEFAULT_OFFSET_FROM_BOTTOM = 260
local UPDATE_INTERVAL_MS = 50
local ACTIVE_ALPHA = 1

local BUFF_UNITS = { "playerpet", "playerpet1", "playerpet2", "slave", "player" }
local MOUNT_MANA_UNITS = { "playerpet", "playerpet1", "playerpet2", "slave" }

local MANA_TRIGGERS = {
    [6] = { trigger = "glider_boost", duration_ms = 60000 },
    [7] = { trigger = "glider_boost", duration_ms = 60000 },
    [8] = { trigger = "glider_boost", duration_ms = 60000 },
    [9] = { trigger = "glider_boost", duration_ms = 60000 },
    [10] = { trigger = "glider_boost", duration_ms = 60000 },
    [11] = { trigger = "glider_boost", duration_ms = 60000 },
    [200] = { trigger = "glider_dive", duration_ms = 15000 },
    [201] = { trigger = "glider_dive", duration_ms = 15000 },
    [202] = { trigger = "glider_dive", duration_ms = 15000 },
    [203] = { trigger = "glider_dive", duration_ms = 15000 },
    [204] = { trigger = "glider_dive", duration_ms = 15000 },
    [205] = { trigger = "glider_dive", duration_ms = 15000 }
}

local FROZEN_TRIGGER = {
    mana_spent = 78,
    required_buff = 30300,
    trigger = "frozen_glider",
    duration_ms = 60000
}

local function safeCall(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, a, b, c = pcall(fn, ...)
    if ok then
        return a, b, c
    end
    return nil
end

local function clampInt(value, minValue, maxValue, fallback)
    local number = tonumber(value)
    if number == nil then
        return fallback
    end
    number = math.floor(number + 0.5)
    if number < minValue then
        return minValue
    elseif number > maxValue then
        return maxValue
    end
    return number
end

local function normalizeMs(value)
    local number = tonumber(value)
    if number == nil then
        return nil
    end
    if number > 0 and number < 5 then
        return number * 1000
    end
    return number
end

local function widgetKey(value)
    return tostring(value or ""):gsub("[^%w_]", "_")
end

local function getSlotKey(device, ability)
    return tostring(device.key or device.name or "") .. "." .. tostring(ability.key or ability.label or "")
end

local function asIdList(value)
    if type(value) == "table" then
        return value
    end
    if tonumber(value) ~= nil then
        return { value }
    end
    return {}
end

local function getUiMsec()
    if api ~= nil and api.Time ~= nil and api.Time.GetUiMsec ~= nil then
        return tonumber(safeCall(function()
            return api.Time:GetUiMsec()
        end)) or 0
    end
    return 0
end

local function isValidUnitId(id)
    local text = tostring(id or "")
    return id ~= nil and text ~= "" and text ~= "0"
end

local function getUnitId(unit)
    if api == nil or api.Unit == nil or api.Unit.GetUnitId == nil then
        return nil
    end
    local id = safeCall(function()
        return api.Unit:GetUnitId(unit)
    end)
    if isValidUnitId(id) then
        return id
    end
    return nil
end

local function unitExists(unit)
    return getUnitId(unit) ~= nil
end

local function getUnitMana(unit)
    if api == nil or api.Unit == nil or api.Unit.UnitMana == nil then
        return 0
    end
    return tonumber(safeCall(function()
        return api.Unit:UnitMana(unit)
    end)) or 0
end

local function getBuffCount(unit)
    if api == nil or api.Unit == nil or api.Unit.UnitBuffCount == nil then
        return 0
    end
    return tonumber(safeCall(function()
        return api.Unit:UnitBuffCount(unit)
    end)) or 0
end

local function getBuff(unit, index)
    if api == nil or api.Unit == nil or api.Unit.UnitBuff == nil then
        return nil
    end
    local buff = safeCall(function()
        return api.Unit:UnitBuff(unit, index)
    end)
    return type(buff) == "table" and buff or nil
end

local function getBuffId(buff)
    if type(buff) ~= "table" then
        return nil
    end
    return tonumber(buff.buff_id or buff.buffId or buff.id or buff.spellId or buff.spell_id)
end

local function getBuffTimeLeftMs(buff)
    if type(buff) ~= "table" then
        return nil
    end
    return normalizeMs(buff.timeLeft or buff.leftTime or buff.remainTime)
end

local function getConfig()
    if type(MountGlider.settings) ~= "table" then
        return nil
    end
    if type(MountGlider.settings.mount_glider) ~= "table" then
        MountGlider.settings.mount_glider = {}
    end
    if type(MountGlider.settings.mount_glider.selected_devices) ~= "table" then
        MountGlider.settings.mount_glider.selected_devices = {}
    end
    if type(MountGlider.settings.mount_glider.selected_abilities) ~= "table" then
        MountGlider.settings.mount_glider.selected_abilities = {}
    end
    if type(MountGlider.settings.mount_glider.learned_gliders) ~= "table" then
        MountGlider.settings.mount_glider.learned_gliders = {}
    end
    if type(MountGlider.settings.mount_glider.learned_mounts) ~= "table" then
        MountGlider.settings.mount_glider.learned_mounts = {}
    end
    return MountGlider.settings.mount_glider
end

local function migrateSelectedDevices(cfg)
    if type(cfg) ~= "table" or type(cfg.selected_devices) ~= "table" then
        return
    end
    local hasMount = type(cfg.selected_mount) == "string" and cfg.selected_mount ~= ""
    local hasGlider = type(cfg.selected_glider) == "string" and cfg.selected_glider ~= ""
    if hasMount and Catalog.GetDevice(cfg.selected_mount, cfg) == nil then
        cfg.selected_abilities[cfg.selected_mount] = nil
        cfg.selected_mount = ""
        hasMount = false
    end
    if hasGlider and Catalog.GetDevice(cfg.selected_glider, cfg) == nil then
        cfg.selected_abilities[cfg.selected_glider] = nil
        cfg.selected_glider = ""
        hasGlider = false
    end
    if hasMount and hasGlider then
        return
    end
    for _, device in ipairs(Catalog.GetDevices(cfg)) do
        if cfg.selected_devices[device.key] == true then
            if device.kind == "Mount" and not hasMount then
                cfg.selected_mount = device.key
                Catalog.EnsureAbilitySelection(cfg.selected_abilities, device)
                hasMount = true
            elseif device.kind ~= "Mount" and not hasGlider then
                cfg.selected_glider = device.key
                Catalog.EnsureAbilitySelection(cfg.selected_abilities, device)
                hasGlider = true
            end
        end
    end
    cfg.selected_devices = {}
end

local function getConfiguredDevices(cfg)
    migrateSelectedDevices(cfg)
    local out = {}
    local mount = Catalog.GetDevice(type(cfg) == "table" and cfg.selected_mount or nil, cfg)
    if type(mount) == "table" and mount.kind == "Mount" then
        out[#out + 1] = mount
    end
    local glider = Catalog.GetDevice(type(cfg) == "table" and cfg.selected_glider or nil, cfg)
    if type(glider) == "table" and glider.kind ~= "Mount" then
        out[#out + 1] = glider
    end
    return out
end

local function isActive()
    local cfg = getConfig()
    local settings = MountGlider.settings
    return MountGlider.enabled
        and type(settings) == "table"
        and settings.enabled == true
        and type(cfg) == "table"
        and cfg.enabled == true,
        cfg
end

local function setWidgetVisible(widget, visible)
    if widget == nil then
        return
    end
    visible = visible and true or false
    local cached = nil
    pcall(function()
        cached = widget.__nuzi_mount_visible
    end)
    if cached == visible then
        return
    end
    safeCall(function()
        if widget.Show ~= nil then
            widget:Show(visible)
        elseif widget.SetVisible ~= nil then
            widget:SetVisible(visible)
        end
    end)
    pcall(function()
        widget.__nuzi_mount_visible = visible
    end)
end

local function setWidgetAlpha(widget, alpha)
    if widget == nil or widget.SetAlpha == nil then
        return
    end
    alpha = tonumber(alpha) or 1
    if widget.__nuzi_mount_alpha == alpha then
        return
    end
    safeCall(function()
        widget:SetAlpha(alpha)
    end)
    widget.__nuzi_mount_alpha = alpha
end

local function setWidgetInteractive(widget, enabled)
    if widget == nil then
        return
    end
    enabled = enabled and true or false
    if widget.__nuzi_mount_interactive == enabled then
        return
    end
    if widget.Clickable ~= nil then
        safeCall(function()
            widget:Clickable(enabled)
        end)
    end
    if widget.EnablePick ~= nil then
        safeCall(function()
            widget:EnablePick(enabled)
        end)
    end
    if widget.EnableDrag ~= nil then
        safeCall(function()
            widget:EnableDrag(enabled)
        end)
    end
    widget.__nuzi_mount_interactive = enabled
end

local function setText(label, text)
    if label == nil or label.SetText == nil then
        return
    end
    text = tostring(text or "")
    if label.__nuzi_mount_text == text then
        return
    end
    safeCall(function()
        label:SetText(text)
    end)
    label.__nuzi_mount_text = text
end

local function setTextColor(label, color)
    if label == nil or label.style == nil or label.style.SetColor == nil then
        return
    end
    local r = tonumber(color[1]) or 1
    local g = tonumber(color[2]) or 1
    local b = tonumber(color[3]) or 1
    local a = tonumber(color[4]) or 1
    local key = string.format("%.3f:%.3f:%.3f:%.3f", r, g, b, a)
    if label.__nuzi_mount_color == key then
        return
    end
    safeCall(function()
        label.style:SetColor(r, g, b, a)
    end)
    label.__nuzi_mount_color = key
end

local function getAlignCenter()
    if ALIGN ~= nil and ALIGN.CENTER ~= nil then
        return ALIGN.CENTER
    end
    return nil
end

local function getFontSizeLarge()
    if FONT_SIZE ~= nil and FONT_SIZE.LARGE ~= nil then
        return FONT_SIZE.LARGE
    end
    return DEFAULT_TIMER_FONT_SIZE
end

local function applyTimerStyle(label, fontSize)
    if label == nil or label.style == nil then
        return
    end
    safeCall(function()
        label.style:SetFontSize(fontSize)
    end)
    if label.style.SetAlign ~= nil then
        local align = getAlignCenter()
        if align ~= nil then
            safeCall(function()
                label.style:SetAlign(align)
            end)
        end
    end
    if label.style.SetFont ~= nil then
        safeCall(function()
            label.style:SetFont("bold")
        end)
    end
    if label.style.SetOutline ~= nil then
        safeCall(function()
            label.style:SetOutline(true)
        end)
    end
end

local function tryIconPath(kind, id)
    id = tonumber(id)
    if id == nil then
        return nil
    end
    if kind == "item" and api ~= nil and api.Item ~= nil and api.Item.GetItemInfoByType ~= nil then
        local item = safeCall(function()
            return api.Item:GetItemInfoByType(id)
        end)
        if type(item) == "table" then
            return item.iconPath or item.path
        end
    elseif kind == "skill" and api ~= nil and api.Skill ~= nil and api.Skill.GetSkillTooltip ~= nil then
        local skill = safeCall(function()
            return api.Skill:GetSkillTooltip(id)
        end)
        if type(skill) == "table" then
            return skill.iconPath or skill.path
        end
    elseif kind == "buff" and api ~= nil and api.Ability ~= nil and api.Ability.GetBuffTooltip ~= nil then
        local buff = safeCall(function()
            return api.Ability:GetBuffTooltip(id, 1)
        end)
        if type(buff) == "table" then
            return buff.iconPath or buff.path
        end
    end
    return nil
end

local function tryIconList(kind, ids)
    for _, id in ipairs(asIdList(ids)) do
        local path = tryIconPath(kind, id)
        if path ~= nil then
            return path
        end
    end
    return nil
end

local getIconPath

local function getDeviceIconPath(device)
    if type(device) ~= "table" then
        return nil
    end
    if type(device.icon_path) == "string" and device.icon_path ~= "" then
        return device.icon_path
    end
    local path = tryIconList("item", device.item_ids)
    if path ~= nil then
        return path
    end
    for _, ability in ipairs(device.abilities or {}) do
        path = getIconPath(ability)
        if path ~= nil then
            return path
        end
    end
    return nil
end

getIconPath = function(ability, fallbackDevice)
    if type(ability) ~= "table" then
        return getDeviceIconPath(fallbackDevice)
    end
    if type(ability.icon_path) == "string" and ability.icon_path ~= "" then
        return ability.icon_path
    end
    local preferredType = tostring(ability.icon_type or "buff")
    local preferredId = tonumber(ability.icon_id)
    local exact = ability.exact_spell_id == true or ability.learned == true
    local cacheKey = preferredType .. ":" .. tostring(preferredId) .. ":" ..
        tostring(exact) .. ":" .. tostring(ability.key or ability.label or "")
    if MountGlider.icon_cache[cacheKey] ~= nil then
        if MountGlider.icon_cache[cacheKey] ~= false then
            return MountGlider.icon_cache[cacheKey]
        end
        return getDeviceIconPath(fallbackDevice)
    end

    local path = tryIconPath(preferredType, preferredId)
    if path == nil and not exact then
        path = tryIconList("buff", ability.buff_ids)
            or tryIconList("item", ability.item_ids)
            or tryIconList("skill", ability.skill_ids)
    end

    MountGlider.icon_cache[cacheKey] = path or false
    return path or getDeviceIconPath(fallbackDevice)
end

local function applyIcon(slot, ability, device)
    if slot == nil or slot.icon == nil then
        return
    end
    local path = slot.use_device_icon and (getDeviceIconPath(device) or getIconPath(ability, device)) or getIconPath(ability, device)
    path = type(path) == "string" and path or ""
    if slot.icon.__nuzi_mount_icon_path == path then
        return
    end
    slot.icon.__nuzi_mount_icon_path = path
    if path == "" then
        return
    end
    if F_SLOT ~= nil and F_SLOT.SetIconBackGround ~= nil then
        safeCall(function()
            F_SLOT.SetIconBackGround(slot.icon, path)
        end)
    elseif slot.icon.SetTexture ~= nil then
        safeCall(function()
            slot.icon:SetTexture(path)
        end)
    end
end

local function createIcon(parent, id)
    if type(CreateItemIconButton) == "function" then
        local icon = safeCall(function()
            return CreateItemIconButton(id, parent)
        end)
        if icon ~= nil then
            return icon
        end
    end
    if parent ~= nil and parent.CreateChildWidget ~= nil then
        return safeCall(function()
            return parent:CreateChildWidget("emptywidget", id, 0, true)
        end)
    end
    return nil
end

local function ensureSlot(slotKey, device, ability)
    local slot = MountGlider.slots_by_key[slotKey]
    if type(slot) == "table" then
        slot.device = device
        slot.ability = ability
        return slot
    end
    local frame = MountGlider.frame
    if frame == nil or frame.CreateChildWidget == nil then
        return nil
    end

    local safeKey = widgetKey(slotKey)
    local slotFrame = safeCall(function()
        return frame:CreateChildWidget("emptywidget", "NuziUiMountGliderSlot" .. safeKey, 0, true)
    end)
    if slotFrame == nil then
        return nil
    end
    setWidgetInteractive(slotFrame, false)

    local icon = createIcon(slotFrame, "NuziUiMountGliderIcon" .. safeKey)
    if icon ~= nil then
        safeCall(function()
            icon:AddAnchor("TOPLEFT", slotFrame, 0, 0)
        end)
        setWidgetInteractive(icon, false)
        if icon.back ~= nil then
            setWidgetInteractive(icon.back, false)
        end
        if icon.back ~= nil and F_SLOT ~= nil and F_SLOT.ApplySlotSkin ~= nil and SLOT_STYLE ~= nil then
            local style = SLOT_STYLE.DEFAULT or SLOT_STYLE.BUFF or SLOT_STYLE.ITEM
            if style ~= nil then
                safeCall(function()
                    F_SLOT.ApplySlotSkin(icon, icon.back, style)
                end)
            end
        end
    end

    local overlay = nil
    if slotFrame.CreateColorDrawable ~= nil then
        overlay = safeCall(function()
            return slotFrame:CreateColorDrawable(0.72, 0.02, 0.02, 0.46, "overlay")
        end)
        if overlay ~= nil then
            safeCall(function()
                overlay:AddAnchor("TOPLEFT", slotFrame, 0, 0)
                overlay:AddAnchor("BOTTOMRIGHT", slotFrame, 0, 0)
                overlay:SetVisible(false)
            end)
        end
    end

    local timer = safeCall(function()
        return slotFrame:CreateChildWidget("label", "NuziUiMountGliderTimer" .. safeKey, 0, true)
    end)
    if timer ~= nil then
        applyTimerStyle(timer, getFontSizeLarge())
        setWidgetInteractive(timer, false)
    end

    slot = {
        key = slotKey,
        frame = slotFrame,
        icon = icon,
        overlay = overlay,
        timer = timer,
        device = device,
        ability = ability,
        manual_end_ms = MountGlider.manual_timers[slotKey],
        live_seen = false,
        was_active = false
    }
    MountGlider.slots[#MountGlider.slots + 1] = slot
    MountGlider.slots_by_key[slotKey] = slot
    applyIcon(slot, ability, device)
    return slot
end

local function clearCursor()
    if api ~= nil and api.Cursor ~= nil and api.Cursor.ClearCursor ~= nil then
        safeCall(function()
            api.Cursor:ClearCursor()
        end)
    end
end

local function isShiftDown()
    if api ~= nil and api.Input ~= nil and api.Input.IsShiftKeyDown ~= nil then
        local ok, down = pcall(function()
            return api.Input:IsShiftKeyDown()
        end)
        if ok then
            return down and true or false
        end
    end
    return false
end

local function readWindowOffset(window)
    if window == nil then
        return nil, nil
    end
    if Layout ~= nil and type(Layout.ReadScreenOffset) == "function" then
        return Layout.ReadScreenOffset(window)
    end
    if window.GetOffset ~= nil then
        local ok, x, y = pcall(function()
            return window:GetOffset()
        end)
        if ok and tonumber(x) ~= nil and tonumber(y) ~= nil then
            return tonumber(x), tonumber(y)
        end
    end
    return nil, nil
end

local function anchorTopLeft(window, x, y)
    if window == nil or window.AddAnchor == nil then
        return
    end
    local uiScale = (Layout ~= nil and type(Layout.GetUiScale) == "function") and Layout.GetUiScale() or 1
    if window.__nuzi_mount_x == x and window.__nuzi_mount_y == y and window.__nuzi_mount_scale == uiScale then
        return
    end
    if Layout ~= nil and type(Layout.AnchorTopLeftScreen) == "function" then
        Layout.AnchorTopLeftScreen(window, x, y)
    else
        safeCall(function()
            if window.RemoveAllAnchors ~= nil then
                window:RemoveAllAnchors()
            end
            window:AddAnchor("TOPLEFT", "UIParent", x, y)
        end)
    end
    window.__nuzi_mount_x = x
    window.__nuzi_mount_y = y
    window.__nuzi_mount_scale = uiScale
end

local function getScreenSize()
    if Layout ~= nil and type(Layout.GetScreenSize) == "function" then
        return Layout.GetScreenSize(1920, 1080)
    end
    return 1920, 1080
end

local function getFrameLayout(cfg, clusters)
    local iconSize = clampInt(cfg.icon_size, 28, 96, DEFAULT_ICON_SIZE)
    local spacing = clampInt(cfg.icon_spacing, 0, 20, DEFAULT_ICON_SPACING)
    local perRow = clampInt(cfg.icons_per_row, 1, 12, DEFAULT_ICONS_PER_ROW)
    local timerFontSize = clampInt(cfg.timer_font_size, 8, 24, DEFAULT_TIMER_FONT_SIZE)
    local rowGap = math.max(4, math.floor(spacing + 4))
    local clusterGap = math.max(spacing * 2, 10)
    local width = 0
    local height = 0
    local x = 0

    for _, cluster in ipairs(clusters) do
        local childCount = #cluster.children
        local childRows = childCount > 0 and math.ceil(childCount / perRow) or 0
        local childCols = childCount > 0 and math.min(childCount, perRow) or 0
        local childWidth = childCols > 0 and ((childCols * iconSize) + (math.max(0, childCols - 1) * spacing)) or 0
        local clusterWidth = math.max(iconSize, childWidth)
        cluster.x = x
        cluster.device_x = x + math.floor(((clusterWidth - iconSize) / 2) + 0.5)
        cluster.device_y = 0
        cluster.child_x = x + math.floor(((clusterWidth - childWidth) / 2) + 0.5)
        cluster.child_y = childCount > 0 and (iconSize + rowGap) or 0
        cluster.width = clusterWidth
        cluster.height = iconSize + (childCount > 0 and (rowGap + (childRows * iconSize) + (math.max(0, childRows - 1) * spacing)) or 0)
        if cluster.height > height then
            height = cluster.height
        end
        width = x + clusterWidth
        x = x + clusterWidth + clusterGap
    end

    return math.max(1, width), math.max(1, height), iconSize, spacing, perRow, timerFontSize
end

local function getChildOffset(cluster, index, iconSize, spacing, perRow)
    local col = (index - 1) % perRow
    local line = math.floor((index - 1) / perRow)
    return cluster.child_x + (col * (iconSize + spacing)), cluster.child_y + (line * (iconSize + spacing))
end

local function hideRowLabels()
    for _, label in ipairs(MountGlider.row_labels) do
        setWidgetVisible(label, false)
    end
end

local function ensurePosition(cfg, width, height)
    if type(cfg) ~= "table" then
        return 0, 0
    end
    if cfg.position_initialized ~= true then
        local screenWidth, screenHeight = getScreenSize()
        cfg.pos_x = math.max(0, math.floor(((screenWidth - width) / 2) + 0.5))
        cfg.pos_y = math.max(0, math.floor((screenHeight - DEFAULT_OFFSET_FROM_BOTTOM - height) + 0.5))
        cfg.position_initialized = true
    end
    cfg.pos_x = clampInt(cfg.pos_x, -5000, 5000, 0)
    cfg.pos_y = clampInt(cfg.pos_y, -5000, 5000, 0)
    return cfg.pos_x, cfg.pos_y
end

local function saveSettings()
    if type(MountGlider.settings) == "table" then
        SettingsStore.SaveSettingsFile(MountGlider.settings)
    end
end

local function syncInteractionState(frame)
    if frame == nil then
        return
    end
    local active, cfg = isActive()
    local interactive = frame.__nuzi_mount_dragging
        or (active and type(cfg) == "table" and cfg.lock_position ~= true
            and (type(MountGlider.settings) ~= "table"
                or MountGlider.settings.drag_requires_shift ~= true
                or isShiftDown()))
    setWidgetInteractive(frame, interactive)
end

local function attachDragHandlers(frame)
    if frame == nil or frame.__nuzi_mount_drag_handlers then
        return
    end
    frame.__nuzi_mount_drag_handlers = true

    safeCall(function()
        if frame.RegisterForDrag ~= nil then
            frame:RegisterForDrag("LeftButton")
        end
    end)

    if frame.SetHandler == nil then
        return
    end

    frame:SetHandler("OnDragStart", function()
        local active, cfg = isActive()
        if not active or type(cfg) ~= "table" or cfg.lock_position == true then
            return
        end
        if type(MountGlider.settings) == "table"
            and MountGlider.settings.drag_requires_shift == true
            and not isShiftDown() then
            return
        end
        frame.__nuzi_mount_dragging = true
        syncInteractionState(frame)
        if frame.StartMoving ~= nil then
            safeCall(function()
                frame:StartMoving()
            end)
        end
    end)

    frame:SetHandler("OnDragStop", function()
        if frame.StopMovingOrSizing ~= nil then
            safeCall(function()
                frame:StopMovingOrSizing()
            end)
        end
        frame.__nuzi_mount_dragging = false
        local cfg = getConfig()
        local x, y = readWindowOffset(frame)
        if type(cfg) == "table" and x ~= nil and y ~= nil then
            cfg.pos_x = clampInt(x, -5000, 5000, tonumber(cfg.pos_x) or 0)
            cfg.pos_y = clampInt(y, -5000, 5000, tonumber(cfg.pos_y) or 0)
            cfg.position_initialized = true
            anchorTopLeft(frame, cfg.pos_x, cfg.pos_y)
            saveSettings()
        end
        clearCursor()
        syncInteractionState(frame)
    end)
end

local function ensureFrame()
    if MountGlider.frame ~= nil then
        return MountGlider.frame
    end
    if api == nil or api.Interface == nil or api.Interface.CreateEmptyWindow == nil then
        return nil
    end
    local frame = safeCall(function()
        return api.Interface:CreateEmptyWindow(WINDOW_ID, "UIParent")
    end)
    if frame == nil then
        return nil
    end
    safeCall(function()
        frame:SetCloseOnEscape(false)
    end)
    safeCall(function()
        frame:EnableHidingIsRemove(false)
    end)
    safeCall(function()
        frame:SetUILayer("game")
    end)
    setWidgetVisible(frame, false)
    MountGlider.frame = frame
    attachDragHandlers(frame)
    return frame
end

local function scanBuffs()
    for key in pairs(MountGlider.buff_scan) do
        MountGlider.buff_scan[key] = nil
    end

    for _, unit in ipairs(BUFF_UNITS) do
        if unitExists(unit) then
            local count = getBuffCount(unit)
            for index = 1, count do
                local buff = getBuff(unit, index)
                local id = getBuffId(buff)
                if id ~= nil then
                    id = math.floor(id + 0.5)
                    local timeLeft = getBuffTimeLeftMs(buff)
                    local previous = MountGlider.buff_scan[id]
                    if previous == nil
                        or ((tonumber(timeLeft) or -1) > (tonumber(previous.time_left_ms) or -1)) then
                        MountGlider.buff_scan[id] = {
                            buff = buff,
                            time_left_ms = timeLeft
                        }
                    end
                end
            end
        end
    end
end

local function getLiveForAbility(ability)
    local best = nil
    for _, id in ipairs(asIdList(ability.buff_ids or ability.buff_id)) do
        local live = MountGlider.buff_scan[tonumber(id)]
        if live ~= nil
            and (best == nil
                or ((tonumber(live.time_left_ms) or -1) > (tonumber(best.time_left_ms) or -1))) then
            best = live
        end
    end
    return best
end

local function findMountManaUnit()
    for _, unit in ipairs(MOUNT_MANA_UNITS) do
        local id = getUnitId(unit)
        if id ~= nil then
            return unit, id, getUnitMana(unit)
        end
    end
    return nil, nil, 0
end

local function playerHasBuff(buffId)
    if not unitExists("player") then
        return false
    end
    local count = getBuffCount("player")
    for index = 1, count do
        local buff = getBuff("player", index)
        local id = getBuffId(buff)
        if id ~= nil and math.floor(id + 0.5) == buffId then
            return true
        end
    end
    return false
end

local function startManualTimerForTrigger(cfg, triggerName, durationMs, nowMs)
    if type(triggerName) ~= "string" or triggerName == "" then
        return
    end
    local selected = getConfiguredDevices(cfg)
    local endMs = (tonumber(nowMs) or getUiMsec()) + (tonumber(durationMs) or 0)
    for _, device in ipairs(selected) do
        for _, ability in ipairs(device.abilities or {}) do
            if ability.trigger == triggerName and Catalog.IsAbilitySelected(cfg.selected_abilities, device, ability) then
                local slotKey = getSlotKey(device, ability)
                MountGlider.manual_timers[slotKey] = endMs
                local slot = MountGlider.slots_by_key[slotKey]
                if type(slot) == "table" then
                    slot.manual_end_ms = endMs
                end
            end
        end
    end
end

local function startManualTimerForMountManaSpent(cfg, spent, nowMs)
    spent = tonumber(spent)
    if spent == nil or spent <= 0 then
        return
    end
    spent = math.floor(spent + 0.5)
    local selected = getConfiguredDevices(cfg)
    for _, device in ipairs(selected) do
        for _, ability in ipairs(device.abilities or {}) do
            if tonumber(ability.mount_mana_spent) == spent
                and Catalog.IsAbilitySelected(cfg.selected_abilities, device, ability) then
                local durationMs = tonumber(ability.duration_ms) or 0
                local endMs = (tonumber(nowMs) or getUiMsec()) + durationMs
                local slotKey = getSlotKey(device, ability)
                MountGlider.manual_timers[slotKey] = endMs
                local slot = MountGlider.slots_by_key[slotKey]
                if type(slot) == "table" then
                    slot.manual_end_ms = endMs
                end
            end
        end
    end
end

local function checkManaSpent(cfg, nowMs)
    if type(cfg) ~= "table" or cfg.use_mana_triggers == false then
        MountGlider.mana_initialized = false
        return
    end

    local _, mountId, mountMana = findMountManaUnit()
    local playerMana = getUnitMana("player")
    if not MountGlider.mana_initialized then
        MountGlider.mana_initialized = true
        MountGlider.last_mount_id = mountId
        MountGlider.last_mount_mana = mountMana
        MountGlider.last_player_mana = playerMana
        return
    end

    if mountId ~= nil then
        if tostring(mountId) == tostring(MountGlider.last_mount_id or "") then
            local spent = (tonumber(MountGlider.last_mount_mana) or 0) - (tonumber(mountMana) or 0)
            local trigger = spent > 0 and MANA_TRIGGERS[spent] or nil
            if trigger ~= nil then
                startManualTimerForTrigger(cfg, trigger.trigger, trigger.duration_ms, nowMs)
            end
            if spent > 0 then
                startManualTimerForMountManaSpent(cfg, spent, nowMs)
            end
        end
        MountGlider.last_mount_id = mountId
        MountGlider.last_mount_mana = mountMana
    else
        MountGlider.last_mount_id = nil
        MountGlider.last_mount_mana = 0
    end

    local playerSpent = (tonumber(MountGlider.last_player_mana) or 0) - (tonumber(playerMana) or 0)
    if playerSpent == FROZEN_TRIGGER.mana_spent and playerHasBuff(FROZEN_TRIGGER.required_buff) then
        startManualTimerForTrigger(cfg, FROZEN_TRIGGER.trigger, FROZEN_TRIGGER.duration_ms, nowMs)
    end
    MountGlider.last_player_mana = playerMana
end

local function formatTimeLeft(ms)
    local value = tonumber(ms)
    if value == nil then
        return ""
    end
    if value < 0 then
        value = 0
    end
    local seconds = value / 1000
    if seconds < 10 then
        return string.format("%.1f", seconds)
    end
    if seconds < 60 then
        return tostring(math.floor(seconds + 0.5))
    end
    local total = math.floor(seconds + 0.5)
    return string.format("%d:%02d", math.floor(total / 60), total % 60)
end

local function notifyReady(cfg, device, ability)
    if type(cfg) == "table" and cfg.notify_ready == false then
        return
    end
    if api == nil or api.Log == nil or api.Log.Info == nil then
        return
    end
    safeCall(function()
        api.Log:Info("[Nuzi UI] " .. tostring(device.name or "Mount/Glider") .. ": " .. tostring(ability.label or "Ability") .. " ready")
    end)
end

local function clearSlotState(slotKey)
    local slot = MountGlider.slots_by_key[slotKey]
    if type(slot) == "table" then
        slot.was_active = false
        slot.live_seen = false
        slot.live_time_left_ms = nil
        slot.manual_end_ms = nil
    end
    MountGlider.manual_timers[slotKey] = nil
end

local function makeAbilityEntry(cfg, device, ability, slotKey, nowMs, useDeviceIcon)
    local slot = ensureSlot(slotKey, device, ability)
    if slot == nil then
        return nil
    end
    slot.use_device_icon = useDeviceIcon and true or false
    local live = getLiveForAbility(ability)
    if live ~= nil then
        local liveTimeLeft = tonumber(live.time_left_ms)
        local refreshed = liveTimeLeft ~= nil
            and tonumber(slot.live_time_left_ms) ~= nil
            and liveTimeLeft > (tonumber(slot.live_time_left_ms) + 500)
        if (slot.live_seen ~= true or refreshed) and ability.duration_ms ~= nil then
            slot.manual_end_ms = nowMs + ability.duration_ms
            MountGlider.manual_timers[slotKey] = slot.manual_end_ms
        end
        slot.live_time_left_ms = liveTimeLeft
        slot.live_seen = true
    else
        slot.live_seen = false
        slot.live_time_left_ms = nil
    end

    local remaining = nil
    if tonumber(slot.manual_end_ms) ~= nil then
        remaining = tonumber(slot.manual_end_ms) - nowMs
        if remaining <= 0 then
            slot.manual_end_ms = nil
            MountGlider.manual_timers[slotKey] = nil
            remaining = nil
        end
    elseif MountGlider.manual_timers[slotKey] ~= nil then
        MountGlider.manual_timers[slotKey] = nil
    end

    local active = remaining ~= nil and remaining > 0
    if slot.was_active == true and not active then
        notifyReady(cfg, device, ability)
    end
    slot.was_active = active

    return {
        ability = ability,
        slot = slot,
        active = active,
        remaining_ms = remaining
    }
end

local function collectClusters(cfg, nowMs)
    scanBuffs()
    local clusters = {}
    local showReady = type(cfg) ~= "table" or cfg.show_ready_icons ~= false
    local selected = getConfiguredDevices(cfg)

    for _, device in ipairs(selected) do
        local selectedAbilities = {}
        for _, ability in ipairs(device.abilities or {}) do
            local slotKey = getSlotKey(device, ability)
            if Catalog.IsAbilitySelected(cfg.selected_abilities, device, ability) then
                selectedAbilities[#selectedAbilities + 1] = ability
            else
                clearSlotState(slotKey)
            end
        end

        local cluster = {
            device = device,
            children = {}
        }

        if #selectedAbilities == 1 then
            local ability = selectedAbilities[1]
            local entry = makeAbilityEntry(cfg, device, ability, getSlotKey(device, ability), nowMs, true)
            if entry ~= nil and (entry.active or showReady) then
                cluster.device_entry = entry
            end
        else
            local deviceAbility = {
                key = "__device",
                label = tostring(device.name or "Device"),
                icon_path = getDeviceIconPath(device),
                duration_ms = 0
            }
            cluster.device_entry = {
                ability = deviceAbility,
                slot = ensureSlot(tostring(device.key or device.name or "") .. ".__device", device, deviceAbility),
                active = false,
                remaining_ms = nil
            }
            if type(cluster.device_entry.slot) == "table" then
                cluster.device_entry.slot.use_device_icon = true
            end
            for _, ability in ipairs(selectedAbilities) do
                local entry = makeAbilityEntry(cfg, device, ability, getSlotKey(device, ability), nowMs, false)
                if entry ~= nil and (entry.active or showReady) then
                    cluster.children[#cluster.children + 1] = entry
                end
            end
        end

        if type(cluster.device_entry) == "table"
            and (cluster.device_entry.active or showReady or #cluster.children > 0) then
            clusters[#clusters + 1] = cluster
        end
    end

    return clusters
end

local function applySlotLayout(slot, frame, x, y, iconSize, timerFontSize)
    if type(slot) ~= "table" or slot.frame == nil then
        return
    end

    safeCall(function()
        slot.frame:SetExtent(iconSize, iconSize)
        if slot.frame.RemoveAllAnchors ~= nil then
            slot.frame:RemoveAllAnchors()
        end
        slot.frame:AddAnchor("TOPLEFT", frame, x, y)
    end)
    if slot.icon ~= nil then
        safeCall(function()
            slot.icon:SetExtent(iconSize, iconSize)
            if slot.icon.RemoveAllAnchors ~= nil then
                slot.icon:RemoveAllAnchors()
            end
            slot.icon:AddAnchor("TOPLEFT", slot.frame, 0, 0)
        end)
        applyIcon(slot, slot.ability, slot.device)
    end
    if slot.overlay ~= nil then
        safeCall(function()
            if slot.overlay.RemoveAllAnchors ~= nil then
                slot.overlay:RemoveAllAnchors()
            end
            slot.overlay:AddAnchor("TOPLEFT", slot.frame, 0, 0)
            slot.overlay:AddAnchor("BOTTOMRIGHT", slot.frame, 0, 0)
        end)
    end
    if slot.timer ~= nil then
        safeCall(function()
            slot.timer:SetExtent(iconSize + 6, math.max(14, timerFontSize + 2))
            if slot.timer.RemoveAllAnchors ~= nil then
                slot.timer:RemoveAllAnchors()
            end
            slot.timer:AddAnchor("CENTER", slot.frame, 0, 0)
        end)
        applyTimerStyle(slot.timer, timerFontSize)
    end
end

local function applySlotState(entry, cfg)
    local slot = type(entry) == "table" and entry.slot or nil
    if type(slot) ~= "table" then
        return
    end
    setWidgetVisible(slot.frame, true)
    setWidgetVisible(slot.icon, true)
    setWidgetAlpha(slot.icon, ACTIVE_ALPHA)
    if slot.icon ~= nil and slot.icon.back ~= nil then
        setWidgetAlpha(slot.icon.back, ACTIVE_ALPHA)
    end
    if slot.overlay ~= nil then
        setWidgetVisible(slot.overlay, entry.active)
    end

    local showTimer = cfg.show_timer ~= false and entry.active and entry.remaining_ms ~= nil
    if showTimer then
        setText(slot.timer, formatTimeLeft(entry.remaining_ms))
        if tonumber(entry.remaining_ms) ~= nil and tonumber(entry.remaining_ms) <= 2000 then
            setTextColor(slot.timer, { 1, 0.18, 0.12, 1 })
        else
            setTextColor(slot.timer, { 1, 1, 1, 1 })
        end
    else
        setText(slot.timer, "")
    end
    setWidgetVisible(slot.timer, showTimer)
end

local function renderFrame(frame, cfg)
    if frame == nil or type(cfg) ~= "table" then
        return
    end

    local nowMs = getUiMsec()
    checkManaSpent(cfg, nowMs)
    local clusters = collectClusters(cfg, nowMs)
    if #clusters == 0 then
        setWidgetVisible(frame, false)
        for _, slot in ipairs(MountGlider.slots) do
            setWidgetVisible(slot.frame, false)
            setWidgetVisible(slot.overlay, false)
        end
        hideRowLabels()
        return
    end

    hideRowLabels()
    local width, height, iconSize, spacing, perRow, timerFontSize = getFrameLayout(cfg, clusters)
    safeCall(function()
        frame:SetExtent(width, height)
    end)
    if not frame.__nuzi_mount_dragging then
        local x, y = ensurePosition(cfg, width, height)
        anchorTopLeft(frame, x, y)
    end

    local visibleSlots = {}
    for _, cluster in ipairs(clusters) do
        local deviceEntry = cluster.device_entry
        if type(deviceEntry) == "table" and type(deviceEntry.slot) == "table" then
            visibleSlots[deviceEntry.slot] = true
            applySlotLayout(deviceEntry.slot, frame, cluster.device_x, cluster.device_y, iconSize, timerFontSize)
            applySlotState(deviceEntry, cfg)
        end
        for entryIndex, entry in ipairs(cluster.children) do
            if type(entry.slot) == "table" then
                local x, y = getChildOffset(cluster, entryIndex, iconSize, spacing, perRow)
                visibleSlots[entry.slot] = true
                applySlotLayout(entry.slot, frame, x, y, iconSize, timerFontSize)
                applySlotState(entry, cfg)
            end
        end
    end

    for _, slot in ipairs(MountGlider.slots) do
        if not visibleSlots[slot] then
            setWidgetVisible(slot.frame, false)
            setWidgetVisible(slot.icon, false)
            setWidgetVisible(slot.timer, false)
            setWidgetVisible(slot.overlay, false)
        end
    end

    setWidgetVisible(frame, true)
    syncInteractionState(frame)
end

function MountGlider.Init(settings)
    MountGlider.settings = settings
    MountGlider.enabled = type(settings) == "table" and settings.enabled == true
    MountGlider.accum_ms = 0
    MountGlider.mana_initialized = false
    local active, cfg = isActive()
    if not active then
        if MountGlider.frame ~= nil then
            setWidgetVisible(MountGlider.frame, false)
        end
        return
    end
    local frame = ensureFrame()
    renderFrame(frame, cfg)
end

function MountGlider.ApplySettings(settings)
    MountGlider.settings = settings
    local active, cfg = isActive()
    if not active then
        MountGlider.mana_initialized = false
        if MountGlider.frame ~= nil then
            setWidgetVisible(MountGlider.frame, false)
        end
        return
    end
    local frame = ensureFrame()
    renderFrame(frame, cfg)
end

function MountGlider.SetEnabled(enabled)
    MountGlider.enabled = enabled and true or false
    if not MountGlider.enabled and MountGlider.frame ~= nil then
        setWidgetVisible(MountGlider.frame, false)
    end
end

function MountGlider.OnUpdate(dt, settings)
    if type(settings) == "table" then
        MountGlider.settings = settings
    end
    local active, cfg = isActive()
    if not active then
        MountGlider.mana_initialized = false
        if MountGlider.frame ~= nil then
            setWidgetVisible(MountGlider.frame, false)
        end
        return
    end
    local frame = ensureFrame()
    if frame == nil then
        return
    end
    syncInteractionState(frame)

    MountGlider.accum_ms = (tonumber(MountGlider.accum_ms) or 0) + (tonumber(dt) or 0)
    if MountGlider.accum_ms < UPDATE_INTERVAL_MS and not frame.__nuzi_mount_dragging then
        return
    end
    MountGlider.accum_ms = 0
    renderFrame(frame, cfg)
end

function MountGlider.Unload()
    if MountGlider.frame ~= nil then
        MountGlider.frame.__nuzi_mount_dragging = false
        setWidgetVisible(MountGlider.frame, false)
        if api ~= nil and api.Interface ~= nil and api.Interface.Free ~= nil then
            safeCall(function()
                api.Interface:Free(MountGlider.frame)
            end)
        end
    end
    clearCursor()
    MountGlider.frame = nil
    MountGlider.slots = {}
    MountGlider.slots_by_key = {}
    MountGlider.row_labels = {}
    MountGlider.icon_cache = {}
    MountGlider.buff_scan = {}
    MountGlider.manual_timers = {}
    MountGlider.accum_ms = 0
    MountGlider.mana_initialized = false
    MountGlider.last_mount_id = nil
    MountGlider.last_mount_mana = 0
    MountGlider.last_player_mana = 0
end

return MountGlider
