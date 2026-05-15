local api = require("api")
local Layout = require("nuzi-ui/layout")
local SettingsStore = require("nuzi-ui/settings_store")
local DebuffEffects = require("nuzi-ui/debuff_effects")

local CrowdControl = {
    settings = nil,
    enabled = true,
    frame = nil,
    slots = {},
    accum_ms = 0,
    layout_key = "",
    flash = {
        frame = nil,
        edges = {},
        active = false,
        elapsed_ms = 0,
        duration_ms = 0,
        intensity = 0,
        color = { 255, 76, 64, 255 },
        cooldown_remaining_ms = 0,
        seen_effects = {},
        layout_key = ""
    }
}

local WINDOW_ID = "NuziUiCrowdControl"
local FLASH_WINDOW_ID = "NuziUiCrowdControlEdgeFlash"
local DEFAULT_POS_X = 860
local DEFAULT_POS_Y = 430
local PREVIEW_ICON = "Game\\ui\\icon\\icon_skill_buff10.dds"
local MAX_RENDERED_ICONS = 8
local DEBUFF_DISPEL_SLOT_COLOR = { 0.7059, 0.2824, 1, 1 }

local CATEGORY_SETTINGS = {
    hard = "show_hard",
    silence = "show_silence",
    root = "show_root",
    slow = "show_slow",
    dot = "show_dot",
    misc = "show_misc"
}

local FLASH_CATEGORY_SETTINGS = {
    hard = "edge_flash_hard",
    silence = "edge_flash_silence",
    root = "edge_flash_root",
    slow = "edge_flash_slow",
    dot = "edge_flash_dot",
    misc = "edge_flash_misc"
}

local CATEGORY_LABELS = {
    hard = "Hard CC",
    silence = "Silence",
    root = "Root",
    slow = "Slow",
    dot = "DoT",
    misc = "CC"
}

local CATEGORY_COLORS = {
    hard = { 255, 76, 64, 255 },
    silence = { 205, 128, 255, 255 },
    root = { 92, 180, 255, 255 },
    slow = { 102, 220, 176, 255 },
    dot = { 245, 154, 66, 255 },
    misc = { 255, 220, 88, 255 }
}

local function safeCall(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then
        return a, b, c, d
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
        number = minValue
    elseif number > maxValue then
        number = maxValue
    end
    return number
end

local function roundPixel(value)
    local number = tonumber(value) or 0
    if number >= 0 then
        return math.floor(number + 0.5)
    end
    return math.ceil(number - 0.5)
end

local function color01(value, fallback)
    local number = tonumber(value)
    if number == nil then
        number = tonumber(fallback) or 255
    end
    if number <= 1 then
        if number < 0 then
            return 0
        end
        return number
    end
    if number < 0 then
        number = 0
    elseif number > 255 then
        number = 255
    end
    return number / 255
end

local function normalizeColor(raw, fallback)
    local source = type(raw) == "table" and raw or fallback or { 255, 255, 255, 255 }
    return {
        clampInt(source[1], 0, 255, tonumber((fallback or {})[1]) or 255),
        clampInt(source[2], 0, 255, tonumber((fallback or {})[2]) or 255),
        clampInt(source[3], 0, 255, tonumber((fallback or {})[3]) or 255),
        clampInt(source[4], 0, 255, tonumber((fallback or {})[4]) or 255)
    }
end

local function setWidgetVisible(widget, visible)
    if widget == nil or widget.Show == nil then
        return
    end
    visible = visible and true or false
    if widget.__nuzi_cc_visible == visible then
        return
    end
    safeCall(function()
        widget:Show(visible)
    end)
    widget.__nuzi_cc_visible = visible
end

local function setWidgetInteractive(widget, enabled)
    if widget == nil then
        return
    end
    enabled = enabled and true or false
    if widget.__nuzi_cc_interactive == enabled then
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
    widget.__nuzi_cc_interactive = enabled
end

local function setText(widget, text)
    if widget == nil or widget.SetText == nil then
        return
    end
    text = tostring(text or "")
    if widget.__nuzi_cc_text == text then
        return
    end
    safeCall(function()
        widget:SetText(text)
    end)
    widget.__nuzi_cc_text = text
end

local function setLabelStyle(label, fontSize, color)
    if label == nil or label.style == nil then
        return
    end
    local rgba = normalizeColor(color)
    local size = clampInt(fontSize, 8, 48, 14)
    local key = table.concat({
        tostring(size),
        tostring(rgba[1]),
        tostring(rgba[2]),
        tostring(rgba[3]),
        tostring(rgba[4])
    }, ":")
    if label.__nuzi_cc_style_key == key then
        return
    end
    safeCall(function()
        if label.style.SetFontSize ~= nil then
            label.style:SetFontSize(size)
        end
        if label.style.SetAlign ~= nil then
            local align = (ALIGN ~= nil and ALIGN.CENTER) or ALIGN_CENTER
            if align ~= nil then
                label.style:SetAlign(align)
            end
        end
        if label.style.SetShadow ~= nil then
            label.style:SetShadow(true)
        end
        if label.style.SetColor ~= nil then
            label.style:SetColor(color01(rgba[1]), color01(rgba[2]), color01(rgba[3]), color01(rgba[4]))
        end
    end)
    label.__nuzi_cc_style_key = key
end

local function setDrawableColor(drawable, r, g, b, a)
    if drawable == nil or drawable.SetColor == nil then
        return
    end
    local key = string.format("%.3f:%.3f:%.3f:%.3f", r or 0, g or 0, b or 0, a or 0)
    if drawable.__nuzi_cc_color == key then
        return
    end
    safeCall(function()
        drawable:SetColor(r or 0, g or 0, b or 0, a or 0)
    end)
    drawable.__nuzi_cc_color = key
end

local function setWidgetRect(widget, parent, x, y, width, height)
    if widget == nil or parent == nil then
        return
    end
    local left = roundPixel(x)
    local top = roundPixel(y)
    local w = math.max(1, roundPixel(width))
    local h = math.max(1, roundPixel(height))
    local key = table.concat({ tostring(left), tostring(top), tostring(w), tostring(h) }, ":")
    if widget.__nuzi_cc_rect == key then
        return
    end
    safeCall(function()
        if widget.RemoveAllAnchors ~= nil then
            widget:RemoveAllAnchors()
        end
        widget:AddAnchor("TOPLEFT", parent, left, top)
        if widget.SetExtent ~= nil then
            widget:SetExtent(w, h)
        else
            if widget.SetWidth ~= nil then
                widget:SetWidth(w)
            end
            if widget.SetHeight ~= nil then
                widget:SetHeight(h)
            end
        end
    end)
    widget.__nuzi_cc_rect = key
end

local function anchorCenter(widget, parent, offsetX, offsetY, width, height)
    if widget == nil or parent == nil then
        return
    end
    local x = roundPixel(offsetX)
    local y = roundPixel(offsetY)
    local w = math.max(1, roundPixel(width))
    local h = math.max(1, roundPixel(height))
    local key = table.concat({ tostring(x), tostring(y), tostring(w), tostring(h) }, ":")
    if widget.__nuzi_cc_anchor == key then
        return
    end
    safeCall(function()
        if widget.RemoveAllAnchors ~= nil then
            widget:RemoveAllAnchors()
        end
        widget:AddAnchor("CENTER", parent, x, y)
        if widget.SetExtent ~= nil then
            widget:SetExtent(w, h)
        end
    end)
    widget.__nuzi_cc_anchor = key
end

local function createColorDrawable(parent, r, g, b, a, layer)
    if parent == nil or parent.CreateColorDrawable == nil then
        return nil
    end
    return safeCall(function()
        return parent:CreateColorDrawable(r, g, b, a, layer or "background")
    end)
end

local function hideFlashFrame()
    local flash = CrowdControl.flash
    flash.active = false
    flash.elapsed_ms = 0
    for _, edge in pairs(flash.edges or {}) do
        setWidgetVisible(edge, false)
    end
    setWidgetVisible(flash.frame, false)
end

local function ensureFlashFrame()
    local flash = CrowdControl.flash
    if flash.frame ~= nil then
        return flash.frame
    end
    if api == nil or api.Interface == nil or api.Interface.CreateEmptyWindow == nil then
        return nil
    end

    local frame = safeCall(function()
        return api.Interface:CreateEmptyWindow(FLASH_WINDOW_ID, "UIParent")
    end)
    if frame == nil then
        return nil
    end

    safeCall(function()
        if frame.SetCloseOnEscape ~= nil then
            frame:SetCloseOnEscape(false)
        end
        if frame.EnableHidingIsRemove ~= nil then
            frame:EnableHidingIsRemove(false)
        end
        if frame.SetUILayer ~= nil then
            frame:SetUILayer("hud")
        end
        if frame.SetZOrder ~= nil then
            frame:SetZOrder(9999)
        end
        if frame.RemoveAllAnchors ~= nil then
            frame:RemoveAllAnchors()
        end
        frame:AddAnchor("TOPLEFT", "UIParent", 0, 0)
        frame:AddAnchor("BOTTOMRIGHT", "UIParent", 0, 0)
    end)

    setWidgetInteractive(frame, false)
    flash.frame = frame
    flash.edges.top = createColorDrawable(frame, 1, 0, 0, 0, "overlay")
    flash.edges.bottom = createColorDrawable(frame, 1, 0, 0, 0, "overlay")
    flash.edges.left = createColorDrawable(frame, 1, 0, 0, 0, "overlay")
    flash.edges.right = createColorDrawable(frame, 1, 0, 0, 0, "overlay")
    hideFlashFrame()
    return frame
end

local function applyFlashLayout(cfg)
    local frame = ensureFlashFrame()
    if frame == nil then
        return
    end

    local thickness = clampInt(type(cfg) == "table" and cfg.edge_flash_thickness or nil, 16, 260, 96)
    local layoutKey = tostring(thickness)
    if CrowdControl.flash.layout_key == layoutKey then
        return
    end

    local edges = CrowdControl.flash.edges
    if edges.top ~= nil then
        safeCall(function()
            edges.top:RemoveAllAnchors()
            edges.top:AddAnchor("TOPLEFT", frame, 0, 0)
            edges.top:AddAnchor("TOPRIGHT", frame, 0, 0)
            edges.top:SetHeight(thickness)
        end)
    end
    if edges.bottom ~= nil then
        safeCall(function()
            edges.bottom:RemoveAllAnchors()
            edges.bottom:AddAnchor("BOTTOMLEFT", frame, 0, 0)
            edges.bottom:AddAnchor("BOTTOMRIGHT", frame, 0, 0)
            edges.bottom:SetHeight(thickness)
        end)
    end
    if edges.left ~= nil then
        safeCall(function()
            edges.left:RemoveAllAnchors()
            edges.left:AddAnchor("TOPLEFT", frame, 0, 0)
            edges.left:AddAnchor("BOTTOMLEFT", frame, 0, 0)
            edges.left:SetWidth(thickness)
        end)
    end
    if edges.right ~= nil then
        safeCall(function()
            edges.right:RemoveAllAnchors()
            edges.right:AddAnchor("TOPRIGHT", frame, 0, 0)
            edges.right:AddAnchor("BOTTOMRIGHT", frame, 0, 0)
            edges.right:SetWidth(thickness)
        end)
    end
    CrowdControl.flash.layout_key = layoutKey
end

local function getFlashColor(cfg, effect)
    if type(cfg) == "table" and cfg.edge_flash_category_color ~= false and type(effect) == "table" then
        local categoryColor = CATEGORY_COLORS[tostring(effect.category or "")]
        if categoryColor ~= nil then
            return normalizeColor(categoryColor, { 255, 76, 64, 255 })
        end
    end
    return normalizeColor(type(cfg) == "table" and cfg.edge_flash_color or nil, { 255, 76, 64, 255 })
end

local function shouldFlashEffect(cfg, effect)
    if type(cfg) ~= "table" or cfg.edge_flash_enabled ~= true or type(effect) ~= "table" then
        return false
    end
    local category = tostring(effect.category or "misc")
    local settingKey = FLASH_CATEGORY_SETTINGS[category] or "edge_flash_misc"
    return cfg[settingKey] == true
end

local function getEffectKey(effect)
    if type(effect) ~= "table" then
        return ""
    end
    return table.concat({
        tostring(effect.buff_id or ""),
        tostring(effect.category or ""),
        tostring(effect.name or "")
    }, ":")
end

local function triggerFlash(cfg, effect)
    if not shouldFlashEffect(cfg, effect) then
        return
    end

    local flash = CrowdControl.flash
    if (tonumber(flash.cooldown_remaining_ms) or 0) > 0 then
        return
    end

    local duration = clampInt(cfg.edge_flash_duration_ms, 120, 1500, 420)
    local intensity = clampInt(cfg.edge_flash_intensity, 0, 100, 65) / 100
    if duration <= 0 or intensity <= 0 then
        return
    end

    flash.active = true
    flash.elapsed_ms = 0
    flash.duration_ms = duration
    flash.intensity = intensity
    flash.color = getFlashColor(cfg, effect)
    flash.cooldown_remaining_ms = clampInt(cfg.edge_flash_cooldown_ms, 0, 5000, 750)
    applyFlashLayout(cfg)
    setWidgetVisible(flash.frame, true)
    for _, edge in pairs(flash.edges or {}) do
        setDrawableColor(edge, color01(flash.color[1]), color01(flash.color[2]), color01(flash.color[3]), intensity)
        setWidgetVisible(edge, true)
    end
end

local function updateFlash(dt, cfg)
    local flash = CrowdControl.flash
    flash.cooldown_remaining_ms = math.max(0, (tonumber(flash.cooldown_remaining_ms) or 0) - (tonumber(dt) or 0))

    if type(cfg) ~= "table" or cfg.edge_flash_enabled ~= true then
        hideFlashFrame()
        return
    end
    if not flash.active then
        return
    end

    local duration = math.max(1, tonumber(flash.duration_ms) or 1)
    flash.elapsed_ms = (tonumber(flash.elapsed_ms) or 0) + (tonumber(dt) or 0)
    local remaining = 1 - (flash.elapsed_ms / duration)
    if remaining <= 0 then
        hideFlashFrame()
        return
    end

    applyFlashLayout(cfg)
    local color = normalizeColor(flash.color, { 255, 76, 64, 255 })
    local alpha = (tonumber(flash.intensity) or 0.65) * remaining
    if alpha < 0 then
        alpha = 0
    elseif alpha > 1 then
        alpha = 1
    end
    for _, edge in pairs(flash.edges or {}) do
        setDrawableColor(edge, color01(color[1]), color01(color[2]), color01(color[3]), alpha)
        setWidgetVisible(edge, true)
    end
    setWidgetVisible(flash.frame, true)
end

local function updateFlashTriggers(effects, cfg)
    local current = {}
    local triggerEffect = nil
    if type(effects) == "table" then
        for _, effect in ipairs(effects) do
            local key = getEffectKey(effect)
            if key ~= "" then
                current[key] = true
                if triggerEffect == nil and CrowdControl.flash.seen_effects[key] ~= true and shouldFlashEffect(cfg, effect) then
                    triggerEffect = effect
                end
            end
        end
    end
    CrowdControl.flash.seen_effects = current
    if triggerEffect ~= nil then
        triggerFlash(cfg, triggerEffect)
    end
end

local function cloneSlotStyle(base)
    if type(base) ~= "table" then
        return base
    end
    local out = {}
    for key, value in pairs(base) do
        if type(value) == "table" then
            local nested = {}
            for nestedKey, nestedValue in pairs(value) do
                nested[nestedKey] = nestedValue
            end
            out[key] = nested
        else
            out[key] = value
        end
    end
    return out
end

local function getDebuffSlotStyle(dispellable)
    local base = DEBUFF or (SLOT_STYLE ~= nil and (SLOT_STYLE.BUFF or SLOT_STYLE.DEFAULT or SLOT_STYLE.ITEM)) or nil
    if not dispellable or type(base) ~= "table" then
        return base
    end
    local style = cloneSlotStyle(base)
    style.color = {
        DEBUFF_DISPEL_SLOT_COLOR[1],
        DEBUFF_DISPEL_SLOT_COLOR[2],
        DEBUFF_DISPEL_SLOT_COLOR[3],
        DEBUFF_DISPEL_SLOT_COLOR[4]
    }
    return style
end

local function applyIconStyle(icon, dispellable)
    if icon == nil or icon.back == nil or F_SLOT == nil or F_SLOT.ApplySlotSkin == nil then
        return
    end
    local key = dispellable and "dispellable" or "normal"
    if icon.__nuzi_cc_style == key then
        return
    end
    local style = getDebuffSlotStyle(dispellable == true)
    if style == nil then
        return
    end
    safeCall(function()
        F_SLOT.ApplySlotSkin(icon, icon.back, style)
    end)
    icon.__nuzi_cc_style = key
end

local function setIconPath(slot, path)
    if slot == nil or slot.icon == nil then
        return
    end
    path = tostring(path or "")
    if slot.icon.__nuzi_cc_path == path then
        return
    end
    slot.icon.__nuzi_cc_path = path
    if path == "" then
        safeCall(function()
            if slot.icon.SetTexture ~= nil then
                slot.icon:SetTexture("")
            end
            if slot.icon.back ~= nil and slot.icon.back.SetTexture ~= nil then
                slot.icon.back:SetTexture("")
            end
        end)
        return
    end
    safeCall(function()
        if F_SLOT ~= nil and F_SLOT.SetIconBackGround ~= nil then
            F_SLOT.SetIconBackGround(slot.icon, path)
        elseif slot.icon.SetIconPath ~= nil then
            slot.icon:SetIconPath(path)
        elseif slot.icon.SetTexture ~= nil then
            slot.icon:SetTexture(path)
        end
    end)
end

local function createLabel(parent, id, fontSize)
    if parent == nil or parent.CreateChildWidget == nil then
        return nil
    end
    local label = safeCall(function()
        return parent:CreateChildWidget("label", id, 0, true)
    end)
    if label == nil then
        return nil
    end
    setLabelStyle(label, fontSize, { 255, 255, 255, 255 })
    setWidgetVisible(label, false)
    setWidgetInteractive(label, false)
    return label
end

local function createIcon(parent, id)
    if parent == nil then
        return nil
    end

    local icon = nil
    if type(CreateItemIconButton) == "function" then
        icon = safeCall(function()
            return CreateItemIconButton(id, parent)
        end)
    end
    if icon == nil and api.Interface ~= nil and api.Interface.CreateWidget ~= nil then
        icon = safeCall(function()
            return api.Interface:CreateWidget("button", id, parent)
        end)
    end
    if icon == nil then
        return nil
    end

    setWidgetVisible(icon, false)
    setWidgetInteractive(icon, false)
    applyIconStyle(icon, false)
    return icon
end

local function createSlot(index)
    local frame = CrowdControl.frame
    if frame == nil then
        return nil
    end

    local id = WINDOW_ID .. "Icon" .. tostring(index)
    local icon = createIcon(frame, id)
    if icon == nil then
        return nil
    end

    return {
        icon = icon,
        timer = createLabel(icon, id .. "Timer", 20),
        label = createLabel(frame, id .. "Label", 18),
        category = createLabel(frame, id .. "Category", 11)
    }
end

local function ensureSlots(count)
    local total = clampInt(count, 1, MAX_RENDERED_ICONS, 1)
    for index = 1, total do
        if CrowdControl.slots[index] == nil then
            CrowdControl.slots[index] = createSlot(index)
        end
    end
    return total
end

local function getConfig()
    if type(CrowdControl.settings) ~= "table" or type(CrowdControl.settings.crowd_control) ~= "table" then
        return nil
    end
    return CrowdControl.settings.crowd_control
end

local function isActive()
    local settings = CrowdControl.settings
    local cfg = getConfig()
    if type(settings) ~= "table" or type(cfg) ~= "table" then
        return false, cfg
    end
    return CrowdControl.enabled and settings.enabled and cfg.enabled == true, cfg
end

local function clearCursor()
    if api ~= nil and api.Cursor ~= nil and api.Cursor.ClearCursor ~= nil then
        safeCall(function()
            api.Cursor:ClearCursor()
        end)
    end
end

local function setMoveCursor()
    clearCursor()
    if api ~= nil and api.Cursor ~= nil and api.Cursor.SetCursorImage ~= nil and CURSOR_PATH ~= nil and CURSOR_PATH.MOVE ~= nil then
        safeCall(function()
            api.Cursor:SetCursorImage(CURSOR_PATH.MOVE, 0, 0)
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
    x = clampInt(x, -5000, 5000, DEFAULT_POS_X)
    y = clampInt(y, -5000, 5000, DEFAULT_POS_Y)
    local uiScale = (Layout ~= nil and type(Layout.GetUiScale) == "function") and Layout.GetUiScale() or 1
    if window.__nuzi_cc_x == x and window.__nuzi_cc_y == y and window.__nuzi_cc_ui_scale == uiScale then
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
    window.__nuzi_cc_x = x
    window.__nuzi_cc_y = y
    window.__nuzi_cc_ui_scale = uiScale
end

local function saveSettings()
    if type(CrowdControl.settings) == "table" then
        SettingsStore.SaveSettingsFile(CrowdControl.settings)
    end
end

local function hideAllSlots()
    for _, slot in ipairs(CrowdControl.slots or {}) do
        if type(slot) == "table" then
            setWidgetVisible(slot.icon, false)
            setWidgetVisible(slot.timer, false)
            setWidgetVisible(slot.label, false)
            setWidgetVisible(slot.category, false)
        end
    end
end

local function hideFrame()
    hideAllSlots()
    setWidgetVisible(CrowdControl.frame, false)
end

local function syncInteractionState()
    local frame = CrowdControl.frame
    if frame == nil then
        return
    end
    local active, cfg = isActive()
    local interactive = frame.__nuzi_cc_dragging
        or (active and type(cfg) == "table" and cfg.lock_position ~= true
            and (type(CrowdControl.settings) ~= "table"
                or CrowdControl.settings.drag_requires_shift ~= true
                or isShiftDown()))

    setWidgetInteractive(frame, interactive)
    for _, slot in ipairs(CrowdControl.slots or {}) do
        if type(slot) == "table" then
            setWidgetInteractive(slot.icon, false)
            setWidgetInteractive(slot.timer, false)
            setWidgetInteractive(slot.label, false)
            setWidgetInteractive(slot.category, false)
        end
    end
end

local function attachDragHandlers(frame)
    if frame == nil or frame.__nuzi_cc_drag_handlers then
        return
    end
    frame.__nuzi_cc_drag_handlers = true

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
        if type(CrowdControl.settings) == "table"
            and CrowdControl.settings.drag_requires_shift == true
            and not isShiftDown() then
            return
        end
        frame.__nuzi_cc_dragging = true
        syncInteractionState()
        setMoveCursor()
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
        frame.__nuzi_cc_dragging = false
        local cfg = getConfig()
        local x, y = readWindowOffset(frame)
        if type(cfg) == "table" and x ~= nil and y ~= nil then
            cfg.pos_x = clampInt(x, -5000, 5000, tonumber(cfg.pos_x) or DEFAULT_POS_X)
            cfg.pos_y = clampInt(y, -5000, 5000, tonumber(cfg.pos_y) or DEFAULT_POS_Y)
            anchorTopLeft(frame, cfg.pos_x, cfg.pos_y)
            saveSettings()
        end
        clearCursor()
        syncInteractionState()
    end)
end

local function ensureFrame()
    if CrowdControl.frame ~= nil then
        return CrowdControl.frame
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
        frame:SetExtent(130, 150)
        if frame.SetCloseOnEscape ~= nil then
            frame:SetCloseOnEscape(false)
        end
        if frame.EnableHidingIsRemove ~= nil then
            frame:EnableHidingIsRemove(false)
        end
        if frame.SetUILayer ~= nil then
            frame:SetUILayer("hud")
        end
        if frame.SetZOrder ~= nil then
            frame:SetZOrder(9998)
        end
    end)

    frame.background = createColorDrawable(frame, 0.04, 0.03, 0.02, 0.45, "background")
    CrowdControl.frame = frame
    attachDragHandlers(frame)
    setWidgetVisible(frame, false)
    return frame
end

local function getIconSize(cfg)
    return clampInt(type(cfg) == "table" and cfg.icon_size or nil, 42, 160, 88)
end

local function getSecondarySize(cfg)
    return clampInt(type(cfg) == "table" and cfg.secondary_icon_size or nil, 16, 80, 36)
end

local function getMaxIcons(cfg)
    return clampInt(type(cfg) == "table" and cfg.max_icons or nil, 1, MAX_RENDERED_ICONS, 5)
end

local function getPanelAlpha(cfg)
    return clampInt(type(cfg) == "table" and cfg.panel_alpha or nil, 0, 100, 45) / 100
end

local function applyLayout(cfg)
    local frame = ensureFrame()
    if frame == nil or type(cfg) ~= "table" then
        return
    end

    local iconSize = getIconSize(cfg)
    local secondarySize = getSecondarySize(cfg)
    local maxIcons = getMaxIcons(cfg)
    local showSecondary = cfg.show_secondary ~= false and maxIcons > 1
    local visibleSecondarySlots = showSecondary and (maxIcons - 1) or 0
    local gap = clampInt(cfg.icon_gap, 0, 16, 4)
    local labelFont = clampInt(cfg.label_font_size, 8, 36, 18)
    local timerFont = clampInt(cfg.timer_font_size, 8, 48, 28)
    local secondaryTimerFont = clampInt(cfg.secondary_timer_font_size, 8, 24, 12)
    local labelHeight = math.max(labelFont + 8, 18)
    local categoryHeight = 18
    local timerHeight = math.max(timerFont + 8, 18)
    local secondaryTimerHeight = math.max(secondaryTimerFont + 6, 14)
    local padding = 8
    local secondaryRowWidth = 0
    if visibleSecondarySlots > 0 then
        secondaryRowWidth = (visibleSecondarySlots * secondarySize) + ((visibleSecondarySlots - 1) * gap)
    end
    local contentWidth = math.max(iconSize, secondaryRowWidth)
    local width = contentWidth + (padding * 2)
    local primaryY = padding
    if visibleSecondarySlots > 0 then
        primaryY = padding + secondarySize + gap
    end
    local bottomLabelSpace = cfg.show_label ~= false and (labelHeight + 8) or 8
    local height = primaryY + iconSize + padding + bottomLabelSpace

    local layoutKey = table.concat({
        tostring(iconSize),
        tostring(secondarySize),
        tostring(maxIcons),
        tostring(visibleSecondarySlots),
        tostring(gap),
        tostring(labelFont),
        tostring(timerFont),
        tostring(secondaryTimerFont),
        tostring(cfg.show_label ~= false),
        tostring(clampInt(cfg.label_offset_x, -160, 160, 0)),
        tostring(clampInt(cfg.label_offset_y, -160, 180, 58)),
        tostring(clampInt(cfg.timer_offset_x, -120, 120, 0)),
        tostring(clampInt(cfg.timer_offset_y, -120, 120, 0)),
        tostring(width),
        tostring(height)
    }, ":")

    if CrowdControl.layout_key ~= layoutKey then
        safeCall(function()
            frame:SetExtent(width, height)
        end)
        if frame.background ~= nil then
            setWidgetRect(frame.background, frame, 0, 0, width, height)
        end

        local primaryX = padding + ((contentWidth - iconSize) / 2)
        local slotsNeeded = ensureSlots(maxIcons)
        if CrowdControl.slots[1] ~= nil then
            setWidgetRect(CrowdControl.slots[1].icon, frame, primaryX, primaryY, iconSize, iconSize)
            anchorCenter(
                CrowdControl.slots[1].timer,
                CrowdControl.slots[1].icon,
                clampInt(cfg.timer_offset_x, -120, 120, 0),
                clampInt(cfg.timer_offset_y, -120, 120, 0),
                iconSize + 50,
                timerHeight
            )
            anchorCenter(
                CrowdControl.slots[1].label,
                CrowdControl.slots[1].icon,
                clampInt(cfg.label_offset_x, -160, 160, 0),
                clampInt(cfg.label_offset_y, -160, 180, 58),
                width + 90,
                labelHeight
            )
            anchorCenter(CrowdControl.slots[1].category, CrowdControl.slots[1].icon, 0, -(iconSize / 2) + 12, width + 40, categoryHeight)
        end

        if visibleSecondarySlots > 0 then
            local startX = padding + ((contentWidth - secondaryRowWidth) / 2)
            for index = 2, slotsNeeded do
                local slot = CrowdControl.slots[index]
                if slot ~= nil then
                    local secondaryIndex = index - 2
                    local x = startX + (secondaryIndex * (secondarySize + gap))
                    setWidgetRect(slot.icon, frame, x, padding, secondarySize, secondarySize)
                    anchorCenter(slot.timer, slot.icon, 0, 0, secondarySize + 18, secondaryTimerHeight)
                end
            end
        end

        CrowdControl.layout_key = layoutKey
    end

    if frame.background ~= nil then
        setDrawableColor(frame.background, 0.04, 0.03, 0.02, getPanelAlpha(cfg))
    end

    anchorTopLeft(frame, cfg.pos_x, cfg.pos_y)
    syncInteractionState()
end

local function formatTimeLeft(ms)
    local value = tonumber(ms)
    if value == nil or value <= 0 then
        return ""
    end
    if value >= 60000 then
        local total = math.floor((value / 1000) + 0.5)
        local minutes = math.floor(total / 60)
        local seconds = total - (minutes * 60)
        return string.format("%d:%02d", minutes, seconds)
    end
    if value >= 10000 then
        return tostring(math.floor((value / 1000) + 0.5))
    end
    return string.format("%.1f", value / 1000)
end

local function filterEffects(effects, cfg)
    local out = {}
    if type(effects) ~= "table" or type(cfg) ~= "table" then
        return out
    end
    for _, effect in ipairs(effects) do
        if type(effect) == "table" then
            local settingKey = CATEGORY_SETTINGS[tostring(effect.category or "misc")] or "show_misc"
            if cfg[settingKey] ~= false then
                out[#out + 1] = effect
            end
        end
    end
    return out
end

local function scanPlayerEffects()
    if DebuffEffects == nil or type(DebuffEffects.ScanUnit) ~= "function" then
        return {}
    end
    local ok, effects = pcall(function()
        return DebuffEffects.ScanUnit("player")
    end)
    if not ok or type(effects) ~= "table" then
        return {}
    end
    return effects
end

local function timerColorFor(cfg, effect)
    local base = normalizeColor(type(cfg) == "table" and cfg.timer_color or nil, { 255, 255, 255, 255 })
    if type(effect) ~= "table" then
        return base
    end
    local urgentMs = clampInt(type(cfg) == "table" and cfg.urgent_threshold_ms or nil, 0, 10000, 2000)
    if urgentMs > 0 and tonumber(effect.time_left_ms) ~= nil and tonumber(effect.time_left_ms) <= urgentMs then
        return normalizeColor(cfg.urgent_timer_color, { 255, 76, 64, 255 })
    end
    return base
end

local function showSlot(slot, show)
    if slot == nil then
        return
    end
    setWidgetVisible(slot.icon, show)
    if not show then
        setWidgetVisible(slot.timer, false)
        setWidgetVisible(slot.label, false)
        setWidgetVisible(slot.category, false)
    end
end

local function renderPrimary(slot, effect, cfg, preview)
    if slot == nil then
        return
    end
    local labelColor = normalizeColor(cfg.label_color, { 255, 255, 255, 255 })
    local category = tostring(type(effect) == "table" and effect.category or "misc")
    local categoryColor = CATEGORY_COLORS[category] or CATEGORY_COLORS.misc
    local path = preview and PREVIEW_ICON or tostring(type(effect) == "table" and effect.path or "")
    local name = preview and "Crowd Control" or tostring(type(effect) == "table" and effect.name or "")

    showSlot(slot, true)
    applyIconStyle(slot.icon, type(effect) == "table" and effect.dispellable == true)
    setIconPath(slot, path)

    if cfg.show_timer ~= false and not preview then
        setLabelStyle(slot.timer, cfg.timer_font_size, timerColorFor(cfg, effect))
        setText(slot.timer, formatTimeLeft(effect.time_left_ms))
        setWidgetVisible(slot.timer, true)
    else
        setWidgetVisible(slot.timer, false)
    end

    if cfg.show_label ~= false then
        setLabelStyle(slot.label, cfg.label_font_size, labelColor)
        setText(slot.label, name)
        setWidgetVisible(slot.label, true)
    else
        setWidgetVisible(slot.label, false)
    end

    if cfg.show_category ~= false then
        setLabelStyle(slot.category, 11, preview and { 255, 220, 88, 255 } or categoryColor)
        setText(slot.category, preview and "Ready" or (CATEGORY_LABELS[category] or "CC"))
        setWidgetVisible(slot.category, true)
    else
        setWidgetVisible(slot.category, false)
    end
end

local function renderSecondary(slot, effect, cfg)
    if slot == nil then
        return
    end
    showSlot(slot, true)
    applyIconStyle(slot.icon, type(effect) == "table" and effect.dispellable == true)
    setIconPath(slot, tostring(type(effect) == "table" and effect.path or ""))
    setWidgetVisible(slot.label, false)
    setWidgetVisible(slot.category, false)
    if cfg.show_timer ~= false then
        setLabelStyle(slot.timer, cfg.secondary_timer_font_size, timerColorFor(cfg, effect))
        setText(slot.timer, formatTimeLeft(effect.time_left_ms))
        setWidgetVisible(slot.timer, true)
    else
        setWidgetVisible(slot.timer, false)
    end
end

local function renderEffects(effects, cfg)
    local frame = ensureFrame()
    if frame == nil then
        return
    end

    applyLayout(cfg)

    local count = type(effects) == "table" and #effects or 0
    if count <= 0 then
        if cfg.show_when_empty == true then
            setWidgetVisible(frame, true)
            renderPrimary(CrowdControl.slots[1], nil, cfg, true)
            for index = 2, #CrowdControl.slots do
                showSlot(CrowdControl.slots[index], false)
            end
        else
            hideFrame()
        end
        return
    end

    local maxIcons = getMaxIcons(cfg)
    setWidgetVisible(frame, true)
    renderPrimary(CrowdControl.slots[1], effects[1], cfg, false)

    local showSecondary = cfg.show_secondary ~= false
    for index = 2, #CrowdControl.slots do
        local effect = effects[index]
        if showSecondary and index <= maxIcons and effect ~= nil then
            renderSecondary(CrowdControl.slots[index], effect, cfg)
        else
            showSlot(CrowdControl.slots[index], false)
        end
    end
end

function CrowdControl.ApplySettings(settings)
    if type(settings) ~= "table" then
        return
    end
    CrowdControl.settings = settings
    local active, cfg = isActive()
    if not active or type(cfg) ~= "table" then
        hideFrame()
        hideFlashFrame()
        CrowdControl.flash.seen_effects = {}
        return
    end
    applyLayout(cfg)
    if cfg.edge_flash_enabled ~= true then
        hideFlashFrame()
    else
        applyFlashLayout(cfg)
    end
    CrowdControl.accum_ms = 999999
end

function CrowdControl.Init(settings)
    CrowdControl.settings = settings
    CrowdControl.enabled = type(settings) == "table" and settings.enabled and true or false
    CrowdControl.accum_ms = 999999
    CrowdControl.layout_key = ""
    local active, cfg = isActive()
    if active and type(cfg) == "table" then
        applyLayout(cfg)
        if cfg.edge_flash_enabled == true then
            applyFlashLayout(cfg)
        end
    else
        hideFrame()
        hideFlashFrame()
    end
end

function CrowdControl.SetEnabled(enabled)
    CrowdControl.enabled = enabled and true or false
    if not CrowdControl.enabled then
        hideFrame()
        hideFlashFrame()
        CrowdControl.flash.seen_effects = {}
    else
        CrowdControl.accum_ms = 999999
    end
    syncInteractionState()
end

function CrowdControl.OnUpdate(dt, settings)
    if type(settings) == "table" then
        CrowdControl.settings = settings
    end
    if type(dt) ~= "number" then
        return
    end

    local active, cfg = isActive()
    if not active or type(cfg) ~= "table" then
        hideFrame()
        hideFlashFrame()
        CrowdControl.flash.seen_effects = {}
        return
    end

    applyLayout(cfg)
    updateFlash(dt, cfg)
    CrowdControl.accum_ms = (tonumber(CrowdControl.accum_ms) or 0) + dt
    local interval = clampInt(cfg.update_interval_ms, 20, 500, 50)
    if CrowdControl.accum_ms < interval then
        return
    end
    CrowdControl.accum_ms = 0
    local effects = scanPlayerEffects()
    updateFlashTriggers(effects, cfg)
    renderEffects(filterEffects(effects, cfg), cfg)
end

function CrowdControl.Unload()
    clearCursor()
    hideFrame()
    hideFlashFrame()
    if CrowdControl.frame ~= nil then
        safeCall(function()
            if api ~= nil and api.Interface ~= nil and api.Interface.Free ~= nil then
                api.Interface:Free(CrowdControl.frame)
            end
        end)
    end
    if CrowdControl.flash.frame ~= nil then
        safeCall(function()
            if api ~= nil and api.Interface ~= nil and api.Interface.Free ~= nil then
                api.Interface:Free(CrowdControl.flash.frame)
            end
        end)
    end
    CrowdControl.frame = nil
    CrowdControl.slots = {}
    CrowdControl.flash.frame = nil
    CrowdControl.flash.edges = {}
    CrowdControl.flash.active = false
    CrowdControl.flash.seen_effects = {}
    CrowdControl.flash.layout_key = ""
    CrowdControl.layout_key = ""
    CrowdControl.accum_ms = 0
end

return CrowdControl
