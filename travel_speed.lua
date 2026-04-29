local api = require("api")
local Layout = require("nuzi-ui/layout")
local SettingsStore = require("nuzi-ui/settings_store")

local TravelSpeed = {
    settings = nil,
    enabled = true,
    frame = nil,
    accum_ms = 0,
    elapsed_ms = 0,
    current_speed = 0,
    speed_source = "Idle",
    speed_bar_max = 20,
    last_world_position = nil,
    last_world_sample_ms = nil,
    travel_speed_samples = {},
    measured_travel_speed = 0,
    smoothed_travel_speed = 0
}

local WINDOW_ID = "NuziUiTravelSpeed"
local DEFAULT_WIDTH = 220
local DEFAULT_HEIGHT = 56
local DEFAULT_SCALE = 1
local DEFAULT_FONT_SIZE = 20
local DEFAULT_POS_X = 260
local DEFAULT_POS_Y = 170
local DEFAULT_SPEED_BAR_MAX = 20
local UPDATE_INTERVAL_MS = 120
local MIN_TRAVEL_SAMPLE_INTERVAL_MS = 80
local MAX_TRAVEL_SAMPLE_INTERVAL_MS = 450
local TRAVEL_SPEED_WINDOW_MS = 900
local MAX_TRAVEL_SAMPLE_DISTANCE = 12
local TRAVEL_SPEED_RISE_SMOOTHING = 0.28
local TRAVEL_SPEED_FALL_SMOOTHING = 0.4
local MIN_TRAVEL_SPEED_DISPLAY = 0.05

local function safeCall(fn)
    local ok, a, b, c = pcall(fn)
    if ok then
        return a, b, c
    end
    return nil
end

local function clampNumber(value, minValue, maxValue, fallback)
    local number = tonumber(value)
    if number == nil or number ~= number then
        return fallback
    end
    if number < minValue then
        return minValue
    elseif number > maxValue then
        return maxValue
    end
    return number
end

local function clampInt(value, minValue, maxValue, fallback)
    return math.floor(clampNumber(value, minValue, maxValue, fallback) + 0.5)
end

local function getAlignLeft()
    if ALIGN_LEFT ~= nil then
        return ALIGN_LEFT
    end
    if ALIGN ~= nil then
        return ALIGN.LEFT
    end
    return nil
end

local function getAlignRight()
    if ALIGN_RIGHT ~= nil then
        return ALIGN_RIGHT
    end
    if ALIGN ~= nil then
        return ALIGN.RIGHT
    end
    return nil
end

local function setWidgetVisible(widget, visible)
    if widget == nil or widget.Show == nil then
        return
    end
    visible = visible and true or false
    if widget.__nuzi_travel_visible == visible then
        return
    end
    safeCall(function()
        widget:Show(visible)
    end)
    widget.__nuzi_travel_visible = visible
end

local function setWidgetInteractive(widget, enabled)
    if widget == nil then
        return
    end

    enabled = enabled and true or false
    if widget.__nuzi_travel_interactive == enabled then
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

    widget.__nuzi_travel_interactive = enabled
end

local function setVisualWidgetsNotInteractive(frame)
    if frame == nil then
        return
    end
    for _, target in ipairs({
        frame.background,
        frame.header,
        frame.divider,
        frame.barBorder,
        frame.barBg,
        frame.barFill,
        frame.barShine
    }) do
        setWidgetInteractive(target, false)
    end
end

local function setText(widget, text)
    if widget == nil or widget.SetText == nil then
        return
    end
    text = tostring(text or "")
    if widget.__nuzi_travel_text == text then
        return
    end
    safeCall(function()
        widget:SetText(text)
    end)
    widget.__nuzi_travel_text = text
end

local function setLabelColor(widget, r, g, b, a)
    if widget == nil or widget.style == nil or widget.style.SetColor == nil then
        return
    end
    local key = string.format("%.3f:%.3f:%.3f:%.3f", r or 1, g or 1, b or 1, a or 1)
    if widget.__nuzi_travel_color == key then
        return
    end
    safeCall(function()
        widget.style:SetColor(r or 1, g or 1, b or 1, a or 1)
    end)
    widget.__nuzi_travel_color = key
end

local function setDrawableColor(drawable, r, g, b, a)
    if drawable == nil or drawable.SetColor == nil then
        return
    end
    local key = string.format("%.3f:%.3f:%.3f:%.3f", r or 0, g or 0, b or 0, a or 0)
    if drawable.__nuzi_travel_color == key then
        return
    end
    safeCall(function()
        drawable:SetColor(r or 0, g or 0, b or 0, a or 0)
    end)
    drawable.__nuzi_travel_color = key
end

local function setDrawableRect(drawable, parent, x, y, width, height)
    if drawable == nil then
        return
    end
    local key = table.concat({
        tostring(math.floor((tonumber(x) or 0) + 0.5)),
        tostring(math.floor((tonumber(y) or 0) + 0.5)),
        tostring(math.floor((tonumber(width) or 0) + 0.5)),
        tostring(math.floor((tonumber(height) or 0) + 0.5))
    }, ":")
    if drawable.__nuzi_travel_rect == key then
        return
    end
    safeCall(function()
        if drawable.RemoveAllAnchors ~= nil then
            drawable:RemoveAllAnchors()
        end
        drawable:AddAnchor("TOPLEFT", parent, x, y)
        if drawable.SetExtent ~= nil then
            drawable:SetExtent(width, height)
        end
    end)
    drawable.__nuzi_travel_rect = key
end

local function setLabelRect(label, parent, x, y, width, height)
    if label == nil then
        return
    end
    local key = table.concat({
        tostring(math.floor((tonumber(x) or 0) + 0.5)),
        tostring(math.floor((tonumber(y) or 0) + 0.5)),
        tostring(math.floor((tonumber(width) or 0) + 0.5)),
        tostring(math.floor((tonumber(height) or 0) + 0.5))
    }, ":")
    if label.__nuzi_travel_rect == key then
        return
    end
    safeCall(function()
        if label.RemoveAllAnchors ~= nil then
            label:RemoveAllAnchors()
        end
        label:AddAnchor("TOPLEFT", parent, x, y)
        if label.SetExtent ~= nil then
            label:SetExtent(width, height)
        end
    end)
    label.__nuzi_travel_rect = key
end

local function createColorDrawable(parent, r, g, b, a, layer)
    if parent == nil or parent.CreateColorDrawable == nil then
        return nil
    end
    return safeCall(function()
        return parent:CreateColorDrawable(r, g, b, a, layer or "artwork")
    end)
end

local function createLabel(parent, id, fontSize, align)
    if parent == nil or parent.CreateChildWidget == nil then
        return nil
    end
    local label = safeCall(function()
        return parent:CreateChildWidget("label", id, 0, true)
    end)
    if label == nil then
        return nil
    end
    if label.style ~= nil then
        safeCall(function()
            label.style:SetFontSize(fontSize)
        end)
        if align ~= nil then
            safeCall(function()
                label.style:SetAlign(align)
            end)
        end
        if label.style.SetShadow ~= nil then
            safeCall(function()
                label.style:SetShadow(true)
            end)
        end
    end
    setWidgetVisible(label, true)
    return label
end

local function getConfig()
    if type(TravelSpeed.settings) ~= "table" or type(TravelSpeed.settings.travel_speed) ~= "table" then
        return nil
    end
    return TravelSpeed.settings.travel_speed
end

local function isActive()
    local settings = TravelSpeed.settings
    local cfg = getConfig()
    if type(settings) ~= "table" or type(cfg) ~= "table" then
        return false, cfg
    end
    return TravelSpeed.enabled and settings.enabled and cfg.enabled == true, cfg
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

local function syncInteractionState(frame)
    if frame == nil then
        return
    end

    local active, cfg = isActive()
    local interactive = frame.__nuzi_travel_dragging
        or (active and type(cfg) == "table" and not cfg.lock_position
            and (type(TravelSpeed.settings) ~= "table" or TravelSpeed.settings.drag_requires_shift ~= true or isShiftDown()))

    for _, target in ipairs({
        frame,
        frame.title,
        frame.value,
        frame.source
    }) do
        setWidgetInteractive(target, interactive)
    end
    setVisualWidgetsNotInteractive(frame)
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
    if window.GetEffectiveOffset ~= nil then
        local ok, x, y = pcall(function()
            return window:GetEffectiveOffset()
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
    if window.__nuzi_travel_x == x and window.__nuzi_travel_y == y and window.__nuzi_travel_ui_scale == uiScale then
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
    window.__nuzi_travel_x = x
    window.__nuzi_travel_y = y
    window.__nuzi_travel_ui_scale = uiScale
end

local function saveSettings()
    if type(TravelSpeed.settings) == "table" then
        SettingsStore.SaveSettingsFile(TravelSpeed.settings)
    end
end

local function resetTravelSamples()
    TravelSpeed.travel_speed_samples = {}
    TravelSpeed.measured_travel_speed = 0
    TravelSpeed.smoothed_travel_speed = 0
end

local function getVehicleSpeed()
    if api == nil or api.SiegeWeapon == nil or api.SiegeWeapon.GetSiegeWeaponSpeed == nil then
        return 0
    end
    return tonumber(safeCall(function()
        return api.SiegeWeapon:GetSiegeWeaponSpeed()
    end)) or 0
end

local function unitTokenExists(unit)
    if api == nil or api.Unit == nil or api.Unit.GetUnitId == nil then
        return false
    end
    local id = safeCall(function()
        return api.Unit:GetUnitId(unit)
    end)
    if id == nil then
        return false
    end
    local text = tostring(id or "")
    return text ~= "" and text ~= "0"
end

local function hasVehicleContext()
    return math.abs(getVehicleSpeed()) > MIN_TRAVEL_SPEED_DISPLAY
end

local function hasMountContext()
    return unitTokenExists("playerpet1") or unitTokenExists("playerpet") or unitTokenExists("slave")
end

local function shouldShowForContext(cfg)
    if type(cfg) ~= "table" or cfg.only_vehicle_or_mount ~= true then
        return true
    end
    local showVehicle = cfg.show_on_vehicle ~= false
    local showMount = cfg.show_on_mount ~= false
    if not showVehicle and not showMount then
        return false
    end
    return (showVehicle and hasVehicleContext()) or (showMount and hasMountContext())
end

local function getPlayerTravelPosition()
    if api == nil or api.Unit == nil or api.Unit.UnitWorldPosition == nil then
        return nil, nil
    end
    local ok, x, y, z = pcall(function()
        return api.Unit:UnitWorldPosition("player")
    end)
    if not ok or tonumber(x) == nil then
        return nil, nil
    end
    if tonumber(y) ~= nil then
        return tonumber(x), tonumber(y)
    end
    return tonumber(x), tonumber(z)
end

local function trimTravelSamples(nowMs)
    local samples = TravelSpeed.travel_speed_samples
    while #samples > 0 do
        local sample = samples[1]
        local age = (tonumber(nowMs) or 0) - (tonumber(sample.sample_ms) or 0)
        if age <= TRAVEL_SPEED_WINDOW_MS then
            break
        end
        table.remove(samples, 1)
    end
end

local function getWindowedTravelSpeed()
    local totalDistance = 0
    local totalMs = 0
    for _, sample in ipairs(TravelSpeed.travel_speed_samples or {}) do
        totalDistance = totalDistance + (tonumber(sample.distance) or 0)
        totalMs = totalMs + (tonumber(sample.delta_ms) or 0)
    end
    if totalMs <= 0 then
        return 0
    end
    return totalDistance / (totalMs / 1000)
end

local function updateSmoothedTravelSpeed(targetSpeed)
    local current = tonumber(TravelSpeed.smoothed_travel_speed) or 0
    local target = math.max(0, tonumber(targetSpeed) or 0)
    local alpha = target >= current and TRAVEL_SPEED_RISE_SMOOTHING or TRAVEL_SPEED_FALL_SMOOTHING
    local nextSpeed = current + ((target - current) * alpha)
    if target <= MIN_TRAVEL_SPEED_DISPLAY and nextSpeed <= MIN_TRAVEL_SPEED_DISPLAY then
        nextSpeed = 0
    end
    TravelSpeed.smoothed_travel_speed = nextSpeed
end

local function updateMovementSample(dt)
    TravelSpeed.elapsed_ms = (tonumber(TravelSpeed.elapsed_ms) or 0) + (tonumber(dt) or 0)
    local nowMs = TravelSpeed.elapsed_ms
    local x, z = getPlayerTravelPosition()
    if x == nil or z == nil then
        resetTravelSamples()
        TravelSpeed.last_world_position = nil
        TravelSpeed.last_world_sample_ms = nil
        return
    end

    local lastPosition = TravelSpeed.last_world_position
    local lastSampleMs = tonumber(TravelSpeed.last_world_sample_ms)
    if lastPosition ~= nil and lastSampleMs ~= nil and nowMs > lastSampleMs then
        local deltaMs = nowMs - lastSampleMs
        local dx = x - (tonumber(lastPosition.x) or x)
        local dz = z - (tonumber(lastPosition.z) or z)
        local distance = math.sqrt((dx * dx) + (dz * dz))
        local deltaSeconds = deltaMs / 1000

        if deltaMs > MAX_TRAVEL_SAMPLE_INTERVAL_MS or distance > MAX_TRAVEL_SAMPLE_DISTANCE then
            resetTravelSamples()
        elseif deltaMs >= MIN_TRAVEL_SAMPLE_INTERVAL_MS and deltaSeconds > 0 then
            local samples = TravelSpeed.travel_speed_samples
            samples[#samples + 1] = {
                distance = distance,
                delta_ms = deltaMs,
                sample_ms = nowMs
            }
            trimTravelSamples(nowMs)
            TravelSpeed.measured_travel_speed = getWindowedTravelSpeed()
            updateSmoothedTravelSpeed(TravelSpeed.measured_travel_speed)
        end
    end

    TravelSpeed.last_world_position = { x = x, z = z }
    TravelSpeed.last_world_sample_ms = nowMs
end

local function updateSpeed()
    local vehicleSpeed = math.abs(getVehicleSpeed())
    if vehicleSpeed > MIN_TRAVEL_SPEED_DISPLAY then
        TravelSpeed.current_speed = vehicleSpeed
        TravelSpeed.speed_source = "Vehicle"
    else
        TravelSpeed.current_speed = math.abs(tonumber(TravelSpeed.smoothed_travel_speed) or 0)
        TravelSpeed.speed_source = TravelSpeed.current_speed > MIN_TRAVEL_SPEED_DISPLAY and "Travel" or "Idle"
    end

    local speed = tonumber(TravelSpeed.current_speed) or 0
    if speed > TravelSpeed.speed_bar_max then
        TravelSpeed.speed_bar_max = math.ceil(speed + 2)
    elseif speed < (TravelSpeed.speed_bar_max * 0.4) and TravelSpeed.speed_bar_max > DEFAULT_SPEED_BAR_MAX then
        TravelSpeed.speed_bar_max = math.max(DEFAULT_SPEED_BAR_MAX, math.ceil(speed + 4))
    end
end

local function attachDragHandlers(frame)
    if frame == nil or frame.__nuzi_travel_drag_hooked then
        return
    end
    frame.__nuzi_travel_drag_hooked = true

    local function onDragStart()
        local _, cfg = isActive()
        if type(cfg) ~= "table" or cfg.lock_position then
            return
        end
        if type(TravelSpeed.settings) == "table" and TravelSpeed.settings.drag_requires_shift == true and not isShiftDown() then
            return
        end
        frame.__nuzi_travel_dragging = true
        if frame.StartMoving ~= nil then
            safeCall(function()
                frame:StartMoving()
            end)
        end
        setMoveCursor()
    end

    local function onDragStop()
        if not frame.__nuzi_travel_dragging then
            return
        end
        if frame.StopMovingOrSizing ~= nil then
            safeCall(function()
                frame:StopMovingOrSizing()
            end)
        end
        frame.__nuzi_travel_dragging = false
        clearCursor()

        local cfg = getConfig()
        if type(cfg) ~= "table" then
            syncInteractionState(frame)
            return
        end
        local x, y = readWindowOffset(frame)
        if x == nil or y == nil then
            syncInteractionState(frame)
            return
        end
        cfg.pos_x = clampInt(x, -5000, 5000, DEFAULT_POS_X)
        cfg.pos_y = clampInt(y, -5000, 5000, DEFAULT_POS_Y)
        frame.__nuzi_travel_x = nil
        frame.__nuzi_travel_y = nil
        anchorTopLeft(frame, cfg.pos_x, cfg.pos_y)
        saveSettings()
        syncInteractionState(frame)
    end

    for _, target in ipairs({
        frame,
        frame.title,
        frame.value,
        frame.source
    }) do
        if target ~= nil then
            safeCall(function()
                if target.RegisterForDrag ~= nil then
                    target:RegisterForDrag("LeftButton")
                end
            end)
            if target.SetHandler ~= nil then
                target:SetHandler("OnDragStart", onDragStart)
                target:SetHandler("OnDragStop", onDragStop)
            end
            setWidgetInteractive(target, false)
        end
    end
    setVisualWidgetsNotInteractive(frame)
end

local function createFrame()
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
        frame:SetExtent(DEFAULT_WIDTH, DEFAULT_HEIGHT)
    end)
    safeCall(function()
        if frame.SetCloseOnEscape ~= nil then
            frame:SetCloseOnEscape(false)
        end
        if frame.EnableHidingIsRemove ~= nil then
            frame:EnableHidingIsRemove(false)
        end
        if frame.SetUILayer ~= nil then
            frame:SetUILayer("game")
        end
        if frame.SetZOrder ~= nil then
            frame:SetZOrder(9998)
        end
    end)

    frame.header = createColorDrawable(frame, 0.92, 0.70, 0.32, 0.13, "overlay")
    frame.divider = createColorDrawable(frame, 0.88, 0.70, 0.35, 0.26, "overlay")
    frame.barBorder = createColorDrawable(frame, 0.70, 0.48, 0.22, 0.42, "overlay")
    frame.barBg = createColorDrawable(frame, 0.04, 0.03, 0.02, 0.84, "overlay")
    frame.barFill = createColorDrawable(frame, 1.00, 0.96, 0.72, 1.00, "artwork")
    frame.barShine = createColorDrawable(frame, 1.00, 1.00, 0.92, 1.00, "artwork")

    frame.title = createLabel(frame, "NuziUiTravelSpeedTitle", 12, getAlignLeft())
    frame.value = createLabel(frame, "NuziUiTravelSpeedValue", DEFAULT_FONT_SIZE, getAlignLeft())
    frame.source = createLabel(frame, "NuziUiTravelSpeedSource", 12, getAlignRight())

    setText(frame.title, "")
    setLabelColor(frame.title, 1, 0.82, 0.48, 1)
    setLabelColor(frame.value, 1, 0.96, 0.86, 1)
    setLabelColor(frame.source, 0.95, 0.78, 0.46, 1)
    setWidgetVisible(frame.header, false)
    setWidgetVisible(frame.divider, false)
    setWidgetVisible(frame.title, false)

    attachDragHandlers(frame)
    return frame
end

local function ensureFrame()
    if TravelSpeed.frame == nil then
        TravelSpeed.frame = createFrame()
    end
    return TravelSpeed.frame
end

local function applyFrameSettings(frame, cfg)
    if frame == nil or type(cfg) ~= "table" then
        return
    end

    local width = clampInt(cfg.width, 160, 360, DEFAULT_WIDTH)
    local scale = clampNumber(cfg.scale, 0.75, 1.6, DEFAULT_SCALE)
    local fontSize = clampInt(cfg.font_size, 14, 30, DEFAULT_FONT_SIZE)
    local showBar = cfg.show_bar ~= false
    local showStateText = cfg.show_state_text ~= false
    local valueY = 8
    local valueHeight = fontSize + 8
    local barY = valueY + valueHeight + 5
    local windowHeight = showBar and (barY + 13) or (valueY + valueHeight + 8)
    local valueWidth = showStateText and (width - 96) or (width - 24)
    local sourceY = valueY + math.max(0, math.floor((valueHeight - 18) / 2))
    local layoutKey = string.format("%d:%.2f:%d:%s:%s", width, scale, fontSize, tostring(showBar), tostring(showStateText))

    if frame.__nuzi_travel_layout_key ~= layoutKey then
        safeCall(function()
            frame:SetExtent(width, windowHeight)
        end)
        safeCall(function()
            if frame.SetScale ~= nil then
                frame:SetScale(scale)
            end
        end)
        if frame.background_is_color then
            setDrawableRect(frame.background, frame, 0, 0, width, windowHeight)
        end
        setWidgetVisible(frame.background, false)
        setWidgetVisible(frame.header, false)
        setWidgetVisible(frame.divider, false)
        setWidgetVisible(frame.title, false)
        setLabelRect(frame.value, frame, 12, valueY, valueWidth, valueHeight)
        setLabelRect(frame.source, frame, width - 84, sourceY, 72, 18)
        setDrawableRect(frame.barBorder, frame, 10, barY - 1, width - 20, 10)
        setDrawableRect(frame.barBg, frame, 11, barY, width - 22, 8)
        if frame.value ~= nil and frame.value.style ~= nil then
            safeCall(function()
                frame.value.style:SetFontSize(fontSize)
            end)
        end
        frame.__nuzi_travel_layout_key = layoutKey
    end
    setWidgetVisible(frame.source, showStateText)
    setWidgetVisible(frame.barBorder, showBar)
    setWidgetVisible(frame.barBg, showBar)

    if not frame.__nuzi_travel_dragging then
        anchorTopLeft(frame, cfg.pos_x, cfg.pos_y)
    end
    syncInteractionState(frame)
end

local function renderFrame(frame)
    if frame == nil then
        return
    end

    local speed = math.abs(tonumber(TravelSpeed.current_speed) or 0)
    local source = tostring(TravelSpeed.speed_source or "Idle")
    local maxSpeed = math.max(DEFAULT_SPEED_BAR_MAX, tonumber(TravelSpeed.speed_bar_max) or DEFAULT_SPEED_BAR_MAX)
    local cfg = getConfig()
    local showBar = type(cfg) ~= "table" or cfg.show_bar ~= false
    local showStateText = type(cfg) ~= "table" or cfg.show_state_text ~= false
    local width = clampInt(type(cfg) == "table" and cfg.width or nil, 160, 360, DEFAULT_WIDTH)
    local fillMax = math.max(1, width - 24)
    local progress = speed / maxSpeed
    if progress < 0 then
        progress = 0
    elseif progress > 1 then
        progress = 1
    end
    local fillWidth = math.floor((fillMax * progress) + 0.5)
    if speed > MIN_TRAVEL_SPEED_DISPLAY and fillWidth < 1 then
        fillWidth = 1
    end

    setText(frame.value, string.format("%.1f m/s", speed))
    setText(frame.source, string.upper(source))
    setWidgetVisible(frame.source, showStateText)

    if source == "Vehicle" then
        setLabelColor(frame.source, 1, 0.78, 0.42, 1)
        setDrawableColor(frame.barFill, 1.00, 0.96, 0.72, 1.00)
        setDrawableColor(frame.barShine, 1.00, 1.00, 0.92, 1.00)
    elseif source == "Travel" then
        setLabelColor(frame.source, 0.70, 0.88, 1, 1)
        setDrawableColor(frame.barFill, 1.00, 0.96, 0.72, 1.00)
        setDrawableColor(frame.barShine, 1.00, 1.00, 0.92, 1.00)
    else
        setLabelColor(frame.source, 0.62, 0.56, 0.46, 1)
        setDrawableColor(frame.barFill, 0.28, 0.22, 0.16, 0.0)
        setDrawableColor(frame.barShine, 0.28, 0.22, 0.16, 0.0)
    end

    local fontSize = clampInt(type(cfg) == "table" and cfg.font_size or nil, 14, 30, DEFAULT_FONT_SIZE)
    local barY = 8 + fontSize + 8 + 5
    setDrawableRect(frame.barFill, frame, 12, barY, math.max(1, fillWidth), 8)
    setDrawableRect(frame.barShine, frame, 12, barY, math.max(1, fillWidth), 3)
    setWidgetVisible(frame.barFill, showBar and fillWidth > 0)
    setWidgetVisible(frame.barShine, showBar and fillWidth > 0)
end

function TravelSpeed.Init(settings)
    TravelSpeed.settings = settings
    TravelSpeed.enabled = type(settings) == "table" and settings.enabled and true or false
    TravelSpeed.accum_ms = 0
    local active, cfg = isActive()
    if not active or not shouldShowForContext(cfg) then
        if TravelSpeed.frame ~= nil then
            setWidgetVisible(TravelSpeed.frame, false)
        end
        return
    end
    local frame = ensureFrame()
    if frame ~= nil then
        applyFrameSettings(frame, cfg)
        renderFrame(frame)
        setWidgetVisible(frame, true)
    end
end

function TravelSpeed.ApplySettings(settings)
    TravelSpeed.settings = settings
    local active, cfg = isActive()
    if not active or not shouldShowForContext(cfg) then
        if TravelSpeed.frame ~= nil then
            setWidgetVisible(TravelSpeed.frame, false)
        end
        return
    end
    local frame = ensureFrame()
    if frame ~= nil then
        applyFrameSettings(frame, cfg)
        renderFrame(frame)
        setWidgetVisible(frame, true)
    end
end

function TravelSpeed.SetEnabled(enabled)
    TravelSpeed.enabled = enabled and true or false
    if not TravelSpeed.enabled and TravelSpeed.frame ~= nil then
        setWidgetVisible(TravelSpeed.frame, false)
    end
end

function TravelSpeed.OnUpdate(dt, settings)
    if type(settings) == "table" then
        TravelSpeed.settings = settings
    end

    local active, cfg = isActive()
    if not active then
        if TravelSpeed.frame ~= nil then
            setWidgetVisible(TravelSpeed.frame, false)
        end
        resetTravelSamples()
        TravelSpeed.current_speed = 0
        TravelSpeed.speed_source = "Idle"
        return
    end

    if not shouldShowForContext(cfg)
        and not (TravelSpeed.frame ~= nil and TravelSpeed.frame.__nuzi_travel_dragging) then
        if TravelSpeed.frame ~= nil then
            setWidgetVisible(TravelSpeed.frame, false)
        end
        resetTravelSamples()
        TravelSpeed.current_speed = 0
        TravelSpeed.speed_source = "Idle"
        return
    end

    local frame = ensureFrame()
    if frame == nil then
        return
    end

    applyFrameSettings(frame, cfg)
    setWidgetVisible(frame, true)

    TravelSpeed.accum_ms = (tonumber(TravelSpeed.accum_ms) or 0) + (tonumber(dt) or 0)
    if TravelSpeed.accum_ms < UPDATE_INTERVAL_MS then
        if frame.__nuzi_travel_dragging then
            renderFrame(frame)
        end
        return
    end

    local elapsed = TravelSpeed.accum_ms
    TravelSpeed.accum_ms = 0
    updateMovementSample(elapsed)
    updateSpeed()
    renderFrame(frame)
end

function TravelSpeed.Unload()
    if TravelSpeed.frame ~= nil then
        TravelSpeed.frame.__nuzi_travel_dragging = false
        setWidgetVisible(TravelSpeed.frame, false)
        if api ~= nil and api.Interface ~= nil and api.Interface.Free ~= nil then
            safeCall(function()
                api.Interface:Free(TravelSpeed.frame)
            end)
        end
    end
    clearCursor()
    TravelSpeed.frame = nil
    TravelSpeed.accum_ms = 0
    TravelSpeed.elapsed_ms = 0
    TravelSpeed.current_speed = 0
    TravelSpeed.speed_source = "Idle"
    TravelSpeed.speed_bar_max = DEFAULT_SPEED_BAR_MAX
    TravelSpeed.last_world_position = nil
    TravelSpeed.last_world_sample_ms = nil
    resetTravelSamples()
end

return TravelSpeed
