local api = require("api")
local Runtime = require("nuzi-ui/runtime")
local SettingsStore = require("nuzi-ui/settings_store")

local CastBar = {
    settings = nil,
    enabled = true,
    frame = nil,
    preview_visible = false,
    state = {
        is_casting = false,
        spell_name = "",
        cast_duration = 0,
        elapsed_ms = 0,
        casting_useable = false,
        ending = false,
        ignore_info_ms = 0
    }
}

local HUD_TEXTURE = "ui/common/hud.dds"
local DEFAULT_WIDTH = 500
local DEFAULT_SCALE = 1.1
local MIN_WIDTH = 240
local MAX_WIDTH = 620
local MIN_SCALE = 0.8
local MAX_SCALE = 2
local DEFAULT_OFFSET_FROM_BOTTOM = 220
local CUSTOM_BAR_HEIGHT = 28
local CUSTOM_BG_COLOR = { 0.05, 0.04, 0.03, 0.9 }
local CUSTOM_ACCENT_COLOR = { 0.94, 0.80, 0.48, 0.14 }
local CUSTOM_FILL_COLOR = { 0.96, 0.78, 0.42, 1 }
local CUSTOM_TEXT_FONT_SIZE = 15
local PLAYER_FRAME_OFFSET_Y = -16
local DEFAULT_BG_COLOR_255 = { 13, 10, 8, 230 }
local DEFAULT_ACCENT_COLOR_255 = { 240, 204, 122, 36 }
local DEFAULT_FILL_COLOR_255 = { 245, 199, 107, 255 }
local DEFAULT_TEXT_COLOR_255 = { 255, 255, 255, 255 }
local DEFAULT_TEXT_OFFSET_X = 0
local DEFAULT_TEXT_OFFSET_Y = 6
local DEFAULT_TEXTURE_MODE = "auto"
local PREVIEW_SPELL_NAME = "Preview Spell"
local PREVIEW_TOTAL_MS = 3000
local PREVIEW_CURRENT_MS = 1500

local getConfig

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

local function isWidget(value)
    local valueType = type(value)
    return value ~= nil and (valueType == "table" or valueType == "userdata")
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

local function clampNumber(value, minValue, maxValue, fallback)
    local number = tonumber(value)
    if number == nil or number ~= number then
        return fallback
    end
    if number < minValue then
        number = minValue
    elseif number > maxValue then
        number = maxValue
    end
    return number
end

local function normalizeColor255(rgba, fallback)
    fallback = type(fallback) == "table" and fallback or { 255, 255, 255, 255 }
    local source = type(rgba) == "table" and rgba or fallback
    local out = {}
    out[1] = clampInt(source[1], 0, 255, tonumber(fallback[1]) or 255)
    out[2] = clampInt(source[2], 0, 255, tonumber(fallback[2]) or 255)
    out[3] = clampInt(source[3], 0, 255, tonumber(fallback[3]) or 255)
    out[4] = clampInt(source[4], 0, 255, tonumber(fallback[4]) or 255)
    return out
end

local function color01(value, fallback)
    local number = tonumber(value)
    if number == nil then
        number = tonumber(fallback) or 255
    end
    if number < 0 then
        number = 0
    elseif number > 255 then
        number = 255
    end
    return number / 255
end

local function setWidgetColor(widget, rgba, fallback)
    if widget == nil or widget.SetColor == nil then
        return
    end
    local color = normalizeColor255(rgba, fallback)
    safeCall(function()
        widget:SetColor(
            color01(color[1], fallback and fallback[1]),
            color01(color[2], fallback and fallback[2]),
            color01(color[3], fallback and fallback[3]),
            color01(color[4], fallback and fallback[4])
        )
    end)
end

local function getCastBarTextureMode(cfg)
    local mode = string.lower(tostring(type(cfg) == "table" and cfg.bar_texture_mode or DEFAULT_TEXTURE_MODE))
    if mode ~= "casting" and mode ~= "charge" then
        return DEFAULT_TEXTURE_MODE
    end
    return mode
end

local function getResolvedTextureMode(cfg, castingUseable)
    local mode = getCastBarTextureMode(cfg)
    if mode == DEFAULT_TEXTURE_MODE then
        return castingUseable and "charge" or "casting"
    end
    return mode
end

local function saveSettings(settings)
    if type(settings) ~= "table" then
        return
    end
    SettingsStore.SaveSettingsFile(settings)
end

local function getPlayerFrame()
    if Runtime ~= nil and Runtime.GetStockContent ~= nil and UIC ~= nil and UIC.PLAYER_UNITFRAME ~= nil then
        local frame = Runtime.GetStockContent(UIC.PLAYER_UNITFRAME)
        if isWidget(frame) then
            return frame
        end
    end
    return nil
end

local function getWidgetExtent(widget)
    if widget == nil then
        return nil, nil
    end
    if type(widget.GetExtent) == "function" then
        local ok, width, height = pcall(function()
            return widget:GetExtent()
        end)
        if ok and tonumber(width) ~= nil and tonumber(height) ~= nil then
            return tonumber(width), tonumber(height)
        end
    end
    local width = nil
    local height = nil
    if type(widget.GetWidth) == "function" then
        width = safeCall(function()
            return widget:GetWidth()
        end)
    end
    if type(widget.GetHeight) == "function" then
        height = safeCall(function()
            return widget:GetHeight()
        end)
    end
    return tonumber(width), tonumber(height)
end

local function setWidgetVisible(widget, visible, fadeOutTime)
    if widget == nil or widget.Show == nil then
        return
    end
    if tonumber(fadeOutTime) ~= nil then
        safeCall(function()
            widget:Show(visible and true or false, fadeOutTime)
        end)
        return
    end
    safeCall(function()
        widget:Show(visible and true or false)
    end)
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

local function readMousePos()
    if api ~= nil and api.Input ~= nil and api.Input.GetMousePos ~= nil then
        local ok, x, y = pcall(function()
            return api.Input:GetMousePos()
        end)
        if ok and tonumber(x) ~= nil and tonumber(y) ~= nil then
            return tonumber(x), tonumber(y)
        end
    end
    return nil, nil
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

local function readWindowOffset(window)
    if window == nil then
        return nil, nil
    end
    if type(window.GetEffectiveOffset) == "function" then
        local ok, x, y = pcall(function()
            return window:GetEffectiveOffset()
        end)
        if ok and tonumber(x) ~= nil and tonumber(y) ~= nil then
            return tonumber(x), tonumber(y)
        end
    end
    if type(window.GetOffset) == "function" then
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
        return false
    end
    x = tonumber(x) or 0
    y = tonumber(y) or 0
    if window.__nuzi_castbar_x == x and window.__nuzi_castbar_y == y then
        return true
    end
    safeCall(function()
        if window.RemoveAllAnchors ~= nil then
            window:RemoveAllAnchors()
        end
    end)
    local ok = pcall(function()
        window:AddAnchor("TOPLEFT", "UIParent", x, y)
    end)
    if not ok then
        ok = pcall(function()
            window:AddAnchor("TOPLEFT", "UIParent", "TOPLEFT", x, y)
        end)
    end
    if ok then
        window.__nuzi_castbar_anchor_mode = "screen"
        window.__nuzi_castbar_anchor_target = nil
        window.__nuzi_castbar_rel_x = nil
        window.__nuzi_castbar_rel_y = nil
        window.__nuzi_castbar_x = x
        window.__nuzi_castbar_y = y
    end
    return ok and true or false
end

local function anchorToPlayerFrame(window)
    if window == nil or window.AddAnchor == nil then
        return false
    end

    local playerFrame = getPlayerFrame()
    if not isWidget(playerFrame) then
        return false
    end

    local cfg = getConfig(CastBar.settings)
    local dx = tonumber(type(cfg) == "table" and cfg.pos_x or nil) or 0
    local dy = tonumber(type(cfg) == "table" and cfg.pos_y or nil) or 0
    if window.__nuzi_castbar_anchor_mode == "player_frame"
        and window.__nuzi_castbar_anchor_target == playerFrame
        and window.__nuzi_castbar_rel_x == dx
        and window.__nuzi_castbar_rel_y == dy then
        return true
    end

    safeCall(function()
        if window.RemoveAllAnchors ~= nil then
            window:RemoveAllAnchors()
        end
    end)

    local ok = pcall(function()
        window:AddAnchor("TOPLEFT", playerFrame, "TOPLEFT", dx, dy)
    end)
    if not ok then
        ok = pcall(function()
            window:AddAnchor("TOPLEFT", playerFrame, dx, dy)
        end)
    end
    if ok then
        window.__nuzi_castbar_anchor_mode = "player_frame"
        window.__nuzi_castbar_anchor_target = playerFrame
        window.__nuzi_castbar_rel_x = dx
        window.__nuzi_castbar_rel_y = dy
        window.__nuzi_castbar_x = nil
        window.__nuzi_castbar_y = nil
    end
    return ok and true or false
end

local function getScreenSize()
    local width = 1920
    local height = 1080
    if api ~= nil and api.Interface ~= nil then
        if api.Interface.GetScreenWidth ~= nil then
            local ok, value = pcall(function()
                return api.Interface:GetScreenWidth()
            end)
            if ok and tonumber(value) ~= nil then
                width = tonumber(value)
            end
        end
        if api.Interface.GetScreenHeight ~= nil then
            local ok, value = pcall(function()
                return api.Interface:GetScreenHeight()
            end)
            if ok and tonumber(value) ~= nil then
                height = tonumber(value)
            end
        end
    end
    return width, height
end

getConfig = function(settings)
    if type(settings) ~= "table" then
        return nil
    end
    if type(settings.cast_bar) ~= "table" then
        settings.cast_bar = {}
    end
    return settings.cast_bar
end

local function getActiveConfig()
    local cfg = getConfig(CastBar.settings)
    if cfg == nil then
        return false, nil
    end
    return CastBar.enabled and cfg.enabled and true or false, cfg
end

local function getDefaultPosition(cfg)
    local width = clampInt(type(cfg) == "table" and cfg.width or nil, MIN_WIDTH, MAX_WIDTH, DEFAULT_WIDTH)
    local scale = clampNumber(type(cfg) == "table" and cfg.scale or nil, MIN_SCALE, MAX_SCALE, DEFAULT_SCALE)
    local screenWidth, screenHeight = getScreenSize()
    local x = math.floor(((screenWidth - (width * scale)) / 2) + 0.5)
    local y = math.floor((screenHeight - (DEFAULT_OFFSET_FROM_BOTTOM * scale)) + 0.5)
    if x < 0 then
        x = 0
    end
    if y < 0 then
        y = 0
    end
    return x, y
end

local function getScaledBarExtent(cfg)
    local width = clampInt(type(cfg) == "table" and cfg.width or nil, MIN_WIDTH, MAX_WIDTH, DEFAULT_WIDTH)
    local scale = clampNumber(type(cfg) == "table" and cfg.scale or nil, MIN_SCALE, MAX_SCALE, DEFAULT_SCALE)
    return math.floor((width * scale) + 0.5), math.floor((CUSTOM_BAR_HEIGHT * scale) + 0.5), width, scale
end

local function getDefaultPlayerRelativePosition(cfg, playerFrame)
    local _, _, width, scale = getScaledBarExtent(cfg)
    local playerWidth = getWidgetExtent(playerFrame)
    if tonumber(playerWidth) == nil then
        playerWidth = 320
    end
    local x = math.floor(((playerWidth - (width * scale)) / 2) + 0.5)
    local y = PLAYER_FRAME_OFFSET_Y - math.floor((CUSTOM_BAR_HEIGHT * scale) + 12)
    return x, y
end

local function getAbsoluteClampBounds(cfg)
    local screenWidth, screenHeight = getScreenSize()
    local barWidth, barHeight = getScaledBarExtent(cfg)
    local maxX = math.max(0, screenWidth - barWidth)
    local maxY = math.max(0, screenHeight - barHeight)
    return 0, maxX, 0, maxY
end

local function getPlayerRelativeClampBounds(cfg)
    local screenWidth, screenHeight = getScreenSize()
    local barWidth, barHeight = getScaledBarExtent(cfg)
    local minX = -screenWidth
    local minY = -screenHeight
    local maxX = screenWidth - math.floor(barWidth / 2)
    local maxY = screenHeight - math.floor(barHeight / 2)
    return minX, maxX, minY, maxY
end

local function ensurePosition(cfg)
    if type(cfg) ~= "table" then
        return 0, 0, false
    end

    local playerFrame = getPlayerFrame()
    local changed = false
    if playerFrame ~= nil and cfg.anchor_mode ~= "player_frame_relative" then
        cfg.pos_x, cfg.pos_y = getDefaultPlayerRelativePosition(cfg, playerFrame)
        cfg.position_initialized = true
        cfg.anchor_mode = "player_frame_relative"
        changed = true
    elseif not cfg.position_initialized then
        if playerFrame ~= nil and cfg.anchor_mode == "player_frame_relative" then
            cfg.pos_x, cfg.pos_y = getDefaultPlayerRelativePosition(cfg, playerFrame)
        else
            cfg.pos_x, cfg.pos_y = getDefaultPosition(cfg)
        end
        cfg.position_initialized = true
        changed = true
    end

    local x = tonumber(cfg.pos_x) or 0
    local y = tonumber(cfg.pos_y) or 0

    if playerFrame ~= nil and cfg.anchor_mode == "player_frame_relative" then
        local minX, maxX, minY, maxY = getPlayerRelativeClampBounds(cfg)
        local clampedX = clampInt(x, minX, maxX, 0)
        local clampedY = clampInt(y, minY, maxY, 0)
        if clampedX ~= cfg.pos_x or clampedY ~= cfg.pos_y then
            cfg.pos_x = clampedX
            cfg.pos_y = clampedY
            changed = true
        end
        return clampedX, clampedY, changed
    end

    local minX, maxX, minY, maxY = getAbsoluteClampBounds(cfg)
    x = clampInt(x, minX, maxX, 0)
    y = clampInt(y, minY, maxY, 0)
    if cfg.pos_x ~= x or cfg.pos_y ~= y then
        cfg.pos_x = x
        cfg.pos_y = y
        cfg.position_initialized = true
        changed = true
    end

    return x, y, changed
end

local function updateDragPosition(frame, cfg)
    if frame == nil or type(cfg) ~= "table" then
        return false
    end

    local drag = frame.__nuzi_castbar_drag_state
    if type(drag) ~= "table" then
        return false
    end

    local mouseX, mouseY = readMousePos()
    if mouseX == nil or mouseY == nil then
        return false
    end

    local deltaX = mouseX - drag.mouse_x
    local deltaY = mouseY - drag.mouse_y

    if drag.anchor_mode == "player_frame_relative" and getPlayerFrame() ~= nil then
        local minX, maxX, minY, maxY = getPlayerRelativeClampBounds(cfg)
        local nextX = clampInt(drag.pos_x + deltaX, minX, maxX, drag.pos_x)
        local nextY = clampInt(drag.pos_y + deltaY, minY, maxY, drag.pos_y)
        local changed = cfg.pos_x ~= nextX or cfg.pos_y ~= nextY or cfg.anchor_mode ~= "player_frame_relative"
        cfg.pos_x = nextX
        cfg.pos_y = nextY
        cfg.anchor_mode = "player_frame_relative"
        cfg.position_initialized = true
        anchorToPlayerFrame(frame)
        return changed
    end

    local minX, maxX, minY, maxY = getAbsoluteClampBounds(cfg)
    local nextX = clampInt(drag.pos_x + deltaX, minX, maxX, drag.pos_x)
    local nextY = clampInt(drag.pos_y + deltaY, minY, maxY, drag.pos_y)
    local changed = cfg.pos_x ~= nextX or cfg.pos_y ~= nextY or cfg.anchor_mode ~= "screen"
    cfg.pos_x = nextX
    cfg.pos_y = nextY
    cfg.anchor_mode = "screen"
    cfg.position_initialized = true
    anchorTopLeft(frame, nextX, nextY)
    return changed
end

local function resetState()
    CastBar.state.is_casting = false
    CastBar.state.spell_name = ""
    CastBar.state.cast_duration = 0
    CastBar.state.elapsed_ms = 0
    CastBar.state.casting_useable = false
    CastBar.state.ending = false
end

local function getCastingInfo()
    if type(X2Unit) ~= "table" or type(X2Unit.UnitCastingInfo) ~= "function" then
        return nil
    end
    local info = nil
    safeCall(function()
        info = X2Unit:UnitCastingInfo("player")
    end)
    if type(info) ~= "table" then
        return nil
    end
    return info
end

local function applyBackdrop(frame)
    if frame == nil then
        return
    end

    if frame.__nuzi_castbar_backdrop == nil and frame.CreateColorDrawable ~= nil then
        local bg = safeCall(function()
            return frame:CreateColorDrawable(
                CUSTOM_BG_COLOR[1],
                CUSTOM_BG_COLOR[2],
                CUSTOM_BG_COLOR[3],
                CUSTOM_BG_COLOR[4],
                "background"
            )
        end)
        if bg ~= nil then
            safeCall(function()
                bg:AddAnchor("TOPLEFT", frame, -8, -4)
                bg:AddAnchor("BOTTOMRIGHT", frame, 8, 4)
            end)
            frame.__nuzi_castbar_backdrop = bg
        end
    end

    if frame.__nuzi_castbar_accent == nil and frame.CreateColorDrawable ~= nil then
        local accent = safeCall(function()
            return frame:CreateColorDrawable(
                CUSTOM_ACCENT_COLOR[1],
                CUSTOM_ACCENT_COLOR[2],
                CUSTOM_ACCENT_COLOR[3],
                CUSTOM_ACCENT_COLOR[4],
                "overlay"
            )
        end)
        if accent ~= nil then
            safeCall(function()
                accent:AddAnchor("TOPLEFT", frame, -8, -4)
                accent:AddAnchor("TOPRIGHT", frame, 8, -4)
            end)
            safeCall(function()
                accent:SetHeight(6)
            end)
            frame.__nuzi_castbar_accent = accent
        end
    end
end

local function setCastingText(frame, text)
    if frame == nil or frame.text == nil then
        return
    end
    safeCall(function()
        frame.text:SetText(tostring(text or ""))
    end)
    safeCall(function()
        if frame.text.GetTextHeight ~= nil and frame.text.SetHeight ~= nil then
            frame.text:SetHeight(frame.text:GetTextHeight())
        end
    end)
end

local function setProbeText(frame, text)
    if frame == nil or frame.probeLabel == nil or frame.probeLabel.SetText == nil then
        return
    end
    safeCall(function()
        frame.probeLabel:SetText(tostring(text or ""))
    end)
end

local function styleBar(frame)
    if frame == nil then
        return
    end

    local cfg = getConfig(CastBar.settings)
    local bgColor = normalizeColor255(type(cfg) == "table" and cfg.bg_color or nil, DEFAULT_BG_COLOR_255)
    local accentColor = normalizeColor255(type(cfg) == "table" and cfg.accent_color or nil, DEFAULT_ACCENT_COLOR_255)
    local fillColor = normalizeColor255(type(cfg) == "table" and cfg.fill_color or nil, DEFAULT_FILL_COLOR_255)
    local textColor = normalizeColor255(type(cfg) == "table" and cfg.text_color or nil, DEFAULT_TEXT_COLOR_255)
    local textOffsetX = clampInt(type(cfg) == "table" and cfg.text_offset_x or nil, -120, 120, DEFAULT_TEXT_OFFSET_X)
    local textOffsetY = clampInt(type(cfg) == "table" and cfg.text_offset_y or nil, -40, 60, DEFAULT_TEXT_OFFSET_Y)
    local textFontSize = clampInt(type(cfg) == "table" and cfg.text_font_size or nil, 10, 24, CUSTOM_TEXT_FONT_SIZE)

    applyBackdrop(frame)
    setWidgetVisible(frame.__nuzi_castbar_backdrop, true)
    setWidgetVisible(frame.__nuzi_castbar_accent, true)
    setWidgetColor(frame.__nuzi_castbar_backdrop, bgColor, DEFAULT_BG_COLOR_255)
    setWidgetColor(frame.__nuzi_castbar_accent, accentColor, DEFAULT_ACCENT_COLOR_255)

    if frame.baseBg ~= nil then
        setWidgetVisible(frame.baseBg, true)
        setWidgetColor(frame.baseBg, bgColor, DEFAULT_BG_COLOR_255)
    end

    if frame.statusBar ~= nil then
        safeCall(function()
            frame.statusBar:SetBarColor(
                color01(fillColor[1], DEFAULT_FILL_COLOR_255[1]),
                color01(fillColor[2], DEFAULT_FILL_COLOR_255[2]),
                color01(fillColor[3], DEFAULT_FILL_COLOR_255[3]),
                color01(fillColor[4], DEFAULT_FILL_COLOR_255[4])
            )
        end)
    end

    if frame.text ~= nil then
        safeCall(function()
            if frame.text.RemoveAllAnchors ~= nil then
                frame.text:RemoveAllAnchors()
            end
            frame.text:AddAnchor("TOPLEFT", frame.statusBar or frame, "BOTTOMLEFT", textOffsetX, textOffsetY)
            frame.text:AddAnchor("TOPRIGHT", frame.statusBar or frame, "BOTTOMRIGHT", textOffsetX, textOffsetY)
        end)
        if frame.text.style ~= nil then
            safeCall(function()
                frame.text.style:SetShadow(true)
            end)
            safeCall(function()
                if ALIGN_CENTER ~= nil then
                    frame.text.style:SetAlign(ALIGN_CENTER)
                end
            end)
            safeCall(function()
                frame.text.style:SetFontSize(textFontSize)
            end)
            safeCall(function()
                frame.text.style:SetColor(
                    color01(textColor[1], DEFAULT_TEXT_COLOR_255[1]),
                    color01(textColor[2], DEFAULT_TEXT_COLOR_255[2]),
                    color01(textColor[3], DEFAULT_TEXT_COLOR_255[3]),
                    color01(textColor[4], DEFAULT_TEXT_COLOR_255[4])
                )
            end)
        end
    end

    if frame.ChangeBarTexture ~= nil then
        frame:ChangeBarTexture(CastBar.state.casting_useable)
    end
end

local function hideFrame(frame, force, isSucceed)
    if frame == nil then
        return
    end
    setWidgetVisible(frame.__nuzi_castbar_backdrop, false)
    setWidgetVisible(frame.__nuzi_castbar_accent, false)
    setWidgetVisible(frame.baseBg, false)
    setWidgetVisible(frame.statusBar, false)
    setWidgetVisible(frame.lightDeco, false)
    setWidgetVisible(frame.flashDeco, false)
    setWidgetVisible(frame.text, false)
    setWidgetVisible(frame.probeLabel, false)
    setWidgetVisible(frame, true)
end

local function showFrame(frame)
    if frame == nil then
        return
    end
    setWidgetVisible(frame.__nuzi_castbar_backdrop, true)
    setWidgetVisible(frame.__nuzi_castbar_accent, true)
    setWidgetVisible(frame.baseBg, true)
    setWidgetVisible(frame.statusBar, true)
    setWidgetVisible(frame.lightDeco, true)
    setWidgetVisible(frame.flashDeco, true)
    setWidgetVisible(frame.text, true)
    setWidgetVisible(frame.probeLabel, false)
    setWidgetVisible(frame, true)
end

local function showPreview(frame)
    if frame == nil then
        return
    end

    styleBar(frame)
    if frame.ChangeBarTexture ~= nil then
        frame:ChangeBarTexture(false)
    end
    if frame.statusBar ~= nil then
        safeCall(function()
            frame.statusBar:SetMinMaxValues(0, PREVIEW_TOTAL_MS)
            frame.statusBar:SetValue(PREVIEW_CURRENT_MS)
        end)
    end
    setCastingText(
        frame,
        string.format(
            "%s  %.1f / %.1f",
            PREVIEW_SPELL_NAME,
            PREVIEW_CURRENT_MS / 1000,
            PREVIEW_TOTAL_MS / 1000
        )
    )
    showFrame(frame)
end

local function refreshIdleFrame(frame)
    if frame == nil then
        return
    end

    local active = getActiveConfig()
    if active and CastBar.preview_visible and not CastBar.state.is_casting then
        showPreview(frame)
        return
    end

    hideFrame(frame, true)
end

local function updateCastingDisplay(frame, spellName, currentMs, totalMs, castingUseable)
    if frame == nil then
        return
    end

    totalMs = tonumber(totalMs) or 0
    currentMs = tonumber(currentMs) or 0
    if totalMs < 1 then
        totalMs = 1
    end
    if currentMs < 0 then
        currentMs = 0
    elseif currentMs > totalMs then
        currentMs = totalMs
    end

    CastBar.state.spell_name = tostring(spellName or "")
    CastBar.state.cast_duration = totalMs
    CastBar.state.casting_useable = castingUseable and true or false
    CastBar.state.elapsed_ms = currentMs

    if frame.ChangeBarTexture ~= nil then
        frame:ChangeBarTexture(CastBar.state.casting_useable)
    end
    if frame.statusBar ~= nil then
        safeCall(function()
            frame.statusBar:SetMinMaxValues(0, totalMs)
        end)
        safeCall(function()
            frame.statusBar:SetValue(currentMs)
        end)
    end

    setCastingText(
        frame,
        string.format(
            "%s  %.1f / %.1f",
            CastBar.state.spell_name,
            currentMs / 1000,
            totalMs / 1000
        )
    )

    showFrame(frame)

    if CastBar.state.is_casting and not CastBar.state.ending and currentMs >= (totalMs * 0.9) then
        CastBar.state.ending = true
        if frame.EndAnimation ~= nil then
            frame:EndAnimation(1)
        end
    end
end

local function beginCast(frame, spellName, castTime, castingUseable)
    CastBar.state.is_casting = true
    CastBar.state.ending = false
    CastBar.state.ignore_info_ms = 0
    CastBar.state.elapsed_ms = 0
    updateCastingDisplay(frame, spellName, 0, castTime, castingUseable)
    setProbeText(frame, "Cast source: event")
    if frame.StartAnimation ~= nil then
        frame:StartAnimation(1)
    end
end

local function stopCast(frame, succeeded)
    CastBar.state.is_casting = false
    CastBar.state.ending = false
    CastBar.state.ignore_info_ms = succeeded and 400 or 200
    CastBar.state.elapsed_ms = 0

    if frame == nil then
        return
    end

    if succeeded and frame.statusBar ~= nil then
        safeCall(function()
            frame.statusBar:SetMinMaxValues(0, 1)
            frame.statusBar:SetValue(1)
        end)
        if frame.FlashAnimation ~= nil then
            frame:FlashAnimation()
        end
        hideFrame(frame, false, true)
        return
    end

    hideFrame(frame)
end

local function createEmptyWindow(id)
    local frame = nil
    if api ~= nil and api.Interface ~= nil and api.Interface.CreateEmptyWindow ~= nil then
        safeCall(function()
            frame = api.Interface:CreateEmptyWindow(id, "UIParent")
        end)
        if frame == nil then
            safeCall(function()
                frame = api.Interface:CreateEmptyWindow(id)
            end)
        end
    end
    if frame == nil and type(CreateEmptyWindow) == "function" then
        safeCall(function()
            frame = CreateEmptyWindow(id, "UIParent")
        end)
    end
    return frame
end

local function createStatusBar(frame)
    if frame == nil then
        return nil
    end

    local statusBar = nil
    if UIParent ~= nil and UIParent.CreateWidget ~= nil then
        safeCall(function()
            statusBar = UIParent:CreateWidget("statusbar", "statusBar", frame)
        end)
    end
    if statusBar == nil and frame.CreateChildWidget ~= nil then
        safeCall(function()
            statusBar = frame:CreateChildWidget("statusbar", "statusBar", 0, true)
        end)
    end
    return statusBar
end

local function createTextWidget(frame)
    if frame == nil or frame.CreateChildWidget == nil then
        return nil
    end
    return safeCall(function()
        return frame:CreateChildWidget("textbox", "text", 0, true)
    end)
end

local function createLabelWidget(frame, id)
    if frame == nil then
        return nil
    end

    local label = nil
    if api ~= nil and api.Interface ~= nil and api.Interface.CreateWidget ~= nil then
        label = safeCall(function()
            return api.Interface:CreateWidget("label", id, frame)
        end)
    end
    if label == nil and frame.CreateChildWidget ~= nil then
        label = safeCall(function()
            return frame:CreateChildWidget("label", id, 0, true)
        end)
    end
    return label
end

local function createFrame()
    local frame = createEmptyWindow("NuziUiPlayerCastBar")
    if frame == nil then
        return nil
    end

    safeCall(function()
        if frame.SetExtent ~= nil then
            frame:SetExtent(DEFAULT_WIDTH, CUSTOM_BAR_HEIGHT)
        end
    end)
    safeCall(function()
        if frame.SetCloseOnEscape ~= nil then
            frame:SetCloseOnEscape(false)
        end
    end)
    safeCall(function()
        if frame.SetUILayer ~= nil then
            frame:SetUILayer("game")
        end
    end)
    safeCall(function()
        if frame.SetZOrder ~= nil then
            frame:SetZOrder(9998)
        end
    end)
    safeCall(function()
        if frame.EnableHidingIsRemove ~= nil then
            frame:EnableHidingIsRemove(false)
        end
    end)

    if frame.CreateColorDrawable ~= nil then
        frame.baseBg = safeCall(function()
            return frame:CreateColorDrawable(0.12, 0.10, 0.08, 0.82, "background")
        end)
        if frame.baseBg ~= nil then
            safeCall(function()
                frame.baseBg:AddAnchor("TOPLEFT", frame, 0, 0)
                frame.baseBg:AddAnchor("BOTTOMRIGHT", frame, 0, 0)
            end)
        end
    end

    frame.statusBar = createStatusBar(frame)
    if frame.statusBar ~= nil then
        safeCall(function()
            frame.statusBar:AddAnchor("TOPLEFT", frame, 6, 3)
            frame.statusBar:AddAnchor("BOTTOMRIGHT", frame, -6, -3)
        end)
        safeCall(function()
            frame.statusBar:SetBarTexture(HUD_TEXTURE, "background")
        end)
        safeCall(function()
            frame.statusBar:SetBarTextureByKey("casting_status_bar")
        end)
        safeCall(function()
            frame.statusBar:SetOrientation("HORIZONTAL")
        end)
        safeCall(function()
            frame.statusBar:SetMinMaxValues(0, 1)
            frame.statusBar:SetValue(0)
        end)

        if frame.statusBar.CreateEffectDrawableByKey ~= nil then
            frame.lightDeco = safeCall(function()
                return frame.statusBar:CreateEffectDrawableByKey(HUD_TEXTURE, "casting_bar_light_deco", "background")
            end)
            if frame.lightDeco ~= nil then
                safeCall(function()
                    frame.lightDeco:SetRepeatCount(1)
                end)
                safeCall(function()
                    if frame.statusBar.AddAnchorChildToBar ~= nil then
                        frame.statusBar:AddAnchorChildToBar(frame.lightDeco, "TOPLEFT", "TOPRIGHT", -15, -2)
                    end
                end)
            end

            frame.flashDeco = safeCall(function()
                return frame.statusBar:CreateEffectDrawableByKey(HUD_TEXTURE, "casting_status_bar_fish_deco", "artwork")
            end)
            if frame.flashDeco ~= nil then
                safeCall(function()
                    frame.flashDeco:SetTextureColor("clear")
                end)
                safeCall(function()
                    frame.flashDeco:AddAnchor("TOPLEFT", frame.statusBar, 0, 0)
                    frame.flashDeco:AddAnchor("BOTTOMRIGHT", frame.statusBar, 0, 0)
                    frame.flashDeco:SetRepeatCount(1)
                end)
            end
        end
    end

    frame.text = createTextWidget(frame)
    if frame.text ~= nil then
        safeCall(function()
            frame.text:Raise()
        end)
        if frame.text.style ~= nil then
            safeCall(function()
                frame.text.style:SetShadow(true)
            end)
            safeCall(function()
                frame.text.style:SetFontSize(CUSTOM_TEXT_FONT_SIZE)
            end)
        end
        safeCall(function()
            frame.text:AddAnchor("TOPLEFT", frame.statusBar or frame, "BOTTOMLEFT", 0, 6)
            frame.text:AddAnchor("TOPRIGHT", frame.statusBar or frame, "BOTTOMRIGHT", 0, 6)
        end)
    end

    frame.probeLabel = createLabelWidget(frame, "NuziUiPlayerCastBarProbe")
    if frame.probeLabel ~= nil then
        safeCall(function()
            frame.probeLabel:SetExtent(DEFAULT_WIDTH, 22)
        end)
        safeCall(function()
            frame.probeLabel:AddAnchor("BOTTOM", frame, "TOP", 0, -8)
        end)
        if frame.probeLabel.style ~= nil then
            safeCall(function()
                if ALIGN ~= nil and ALIGN.CENTER ~= nil then
                    frame.probeLabel.style:SetAlign(ALIGN.CENTER)
                elseif ALIGN_CENTER ~= nil then
                    frame.probeLabel.style:SetAlign(ALIGN_CENTER)
                end
            end)
            safeCall(function()
                frame.probeLabel.style:SetFontSize(16)
            end)
            safeCall(function()
                frame.probeLabel.style:SetShadow(true)
            end)
            safeCall(function()
                frame.probeLabel.style:SetColor(1, 0.92, 0.62, 1)
            end)
        end
        safeCall(function()
            frame.probeLabel:SetText("Nuzi UI Cast Bar")
        end)
    end

    function frame:StartAnimation(time)
        if self.lightDeco == nil then
            return
        end
        safeCall(function()
            self.lightDeco:SetEffectPriority(1, "alpha", time, time)
            self.lightDeco:SetEffectPriority(1, "alpha", 0.7, 0.5)
            self.lightDeco:SetEffectInitialColor(1, 1, 1, 1, 0)
            self.lightDeco:SetEffectFinalColor(1, 1, 1, 1, 1)
            self.lightDeco:SetStartEffect(true)
        end)
    end

    function frame:EndAnimation(time)
        if self.lightDeco == nil then
            return
        end
        safeCall(function()
            self.lightDeco:SetEffectPriority(1, "alpha", time, time)
            self.lightDeco:SetEffectInitialColor(1, 1, 1, 1, 1)
            self.lightDeco:SetEffectFinalColor(1, 1, 1, 1, 0)
            self.lightDeco:SetStartEffect(true)
        end)
    end

    function frame:FlashAnimation()
        if self.flashDeco == nil then
            return
        end
        safeCall(function()
            self.flashDeco:SetEffectPriority(1, "alpha", 0.5, 0.3)
            self.flashDeco:SetEffectInitialColor(1, 1, 1, 1, 0)
            self.flashDeco:SetEffectFinalColor(1, 1, 1, 1, 1)
            self.flashDeco:SetEffectPriority(2, "alpha", 0.5, 0.3)
            self.flashDeco:SetEffectInitialColor(2, 1, 1, 1, 1)
            self.flashDeco:SetEffectFinalColor(2, 1, 1, 1, 0)
            self.flashDeco:SetStartEffect(true)
        end)
    end

    function frame:ChangeBarTexture(castingUseable)
        local cfg = getConfig(CastBar.settings)
        local textureMode = getResolvedTextureMode(cfg, castingUseable)
        if self.statusBar == nil or self.__nuzi_castbar_texture_mode == textureMode then
            return
        end
        if textureMode == "charge" then
            safeCall(function()
                if self.statusBar.RemoveAllAnchors ~= nil then
                    self.statusBar:RemoveAllAnchors()
                end
                self.statusBar:AddAnchor("TOPLEFT", self, 6, 2)
                self.statusBar:AddAnchor("BOTTOMRIGHT", self, -6, -2)
                self.statusBar:SetBarTextureByKey("charge_bar")
            end)
            if self.lightDeco ~= nil then
                safeCall(function()
                    self.lightDeco:SetTextureInfo("charge_bar_light")
                end)
            end
        else
            safeCall(function()
                if self.statusBar.RemoveAllAnchors ~= nil then
                    self.statusBar:RemoveAllAnchors()
                end
                self.statusBar:AddAnchor("TOPLEFT", self, 6, 3)
                self.statusBar:AddAnchor("BOTTOMRIGHT", self, -6, -3)
                self.statusBar:SetBarTextureByKey("casting_status_bar")
            end)
            if self.lightDeco ~= nil then
                safeCall(function()
                    self.lightDeco:SetTextureInfo("casting_bar_light_deco")
                end)
            end
        end
        self.__nuzi_castbar_texture_mode = textureMode
    end

    styleBar(frame)
    hideFrame(frame, true)

    return frame
end

local function handleSpellcastEvent(frame, event, ...)
    local active = getActiveConfig()
    if not active then
        return
    end

    if event == "SPELLCAST_START" then
        local spellName, castTime, caster, castingUseable = ...
        if caster ~= "player" then
            return
        end
        beginCast(frame, spellName, castTime, castingUseable)
        return
    end

    local caster = ...
    if caster ~= "player" then
        return
    end

    if not CastBar.state.is_casting then
        return
    end

    if event == "SPELLCAST_SUCCEEDED" then
        stopCast(frame, true)
        return
    end

    if event == "SPELLCAST_STOP" then
        stopCast(frame, false)
    end
end

local function ensureEventsRegistered(frame)
    if frame == nil or frame.__nuzi_castbar_events_registered then
        return
    end
    if frame.RegisterEvent == nil or frame.SetHandler == nil then
        return
    end

    for _, eventName in ipairs({
        "SPELLCAST_START",
        "SPELLCAST_STOP",
        "SPELLCAST_SUCCEEDED"
    }) do
        safeCall(function()
            frame:RegisterEvent(eventName)
        end)
    end

    frame:SetHandler("OnEvent", function(_, event, ...)
        handleSpellcastEvent(frame, event, ...)
    end)
    frame.__nuzi_castbar_events_registered = true
end

local function attachDragHandlers(frame)
    if frame == nil or frame.__nuzi_castbar_drag_hooked then
        return
    end

    frame.__nuzi_castbar_drag_hooked = true
    local dragTargets = { frame, frame.statusBar, frame.text }

    local function onDragStart()
        local active, cfg = getActiveConfig()
        if not active or cfg == nil or cfg.lock_position then
            return
        end
        if type(CastBar.settings) == "table" and CastBar.settings.drag_requires_shift ~= false and not isShiftDown() then
            return
        end

        local mouseX, mouseY = readMousePos()
        if mouseX == nil or mouseY == nil then
            return
        end

        frame.__nuzi_castbar_drag_state = {
            mouse_x = mouseX,
            mouse_y = mouseY,
            pos_x = tonumber(cfg.pos_x) or 0,
            pos_y = tonumber(cfg.pos_y) or 0,
            anchor_mode = getPlayerFrame() ~= nil and "player_frame_relative" or "screen"
        }
        frame.__nuzi_castbar_dragging = true
        setMoveCursor()
    end

    local function onDragStop()
        if not frame.__nuzi_castbar_dragging then
            return
        end

        local _, cfg = getActiveConfig()
        if cfg == nil then
            frame.__nuzi_castbar_dragging = false
            frame.__nuzi_castbar_drag_state = nil
            clearCursor()
            return
        end

        updateDragPosition(frame, cfg)
        frame.__nuzi_castbar_dragging = false
        frame.__nuzi_castbar_drag_state = nil
        clearCursor()
        saveSettings(CastBar.settings)
    end

    for _, target in ipairs(dragTargets) do
        if target ~= nil then
            safeCall(function()
                if target.EnableDrag ~= nil then
                    target:EnableDrag(true)
                end
            end)
            safeCall(function()
                if target.RegisterForDrag ~= nil then
                    target:RegisterForDrag("LeftButton")
                end
            end)
            if target.SetHandler ~= nil then
                target:SetHandler("OnDragStart", onDragStart)
                target:SetHandler("OnDragStop", onDragStop)
            end
        end
    end
end

local function applyFrameSettings(frame, cfg)
    if frame == nil or type(cfg) ~= "table" then
        return
    end

    local x, y, changed = ensurePosition(cfg)
    if changed then
        saveSettings(CastBar.settings)
    end

    local width = clampInt(cfg.width, MIN_WIDTH, MAX_WIDTH, DEFAULT_WIDTH)
    local scale = clampNumber(cfg.scale, MIN_SCALE, MAX_SCALE, DEFAULT_SCALE)

    if frame.__nuzi_castbar_width ~= width or frame.__nuzi_castbar_height ~= CUSTOM_BAR_HEIGHT then
        safeCall(function()
            if frame.SetExtent ~= nil then
                frame:SetExtent(width, CUSTOM_BAR_HEIGHT)
            elseif frame.SetWidth ~= nil then
                frame:SetWidth(width)
            end
        end)
        frame.__nuzi_castbar_width = width
        frame.__nuzi_castbar_height = CUSTOM_BAR_HEIGHT
    end

    if frame.__nuzi_castbar_scale ~= scale then
        safeCall(function()
            if frame.SetScale ~= nil then
                frame:SetScale(scale)
            end
        end)
        frame.__nuzi_castbar_scale = scale
    end

    if not frame.__nuzi_castbar_dragging then
        if cfg.anchor_mode == "player_frame_relative" and anchorToPlayerFrame(frame) then
            -- anchored directly to the stock player frame for stable placement
        else
            anchorTopLeft(frame, x, y)
        end
    end
    styleBar(frame)
end

local function showProbe(frame, text)
    if frame == nil then
        return
    end
    setWidgetVisible(frame, true)
    setWidgetVisible(frame.baseBg, true)
    setWidgetVisible(frame.statusBar, true)
    setWidgetVisible(frame.text, false)
    setWidgetVisible(frame.probeLabel, true)
    if frame.baseBg ~= nil and frame.baseBg.SetColor ~= nil then
        safeCall(function()
            frame.baseBg:SetColor(0.45, 0.10, 0.10, 0.92)
        end)
    end
    if frame.statusBar ~= nil then
        safeCall(function()
            frame.statusBar:SetMinMaxValues(0, 1)
            frame.statusBar:SetValue(1)
        end)
    end
    setCastingText(frame, "")
    setProbeText(frame, text or "Nuzi UI Cast Bar Probe")
end

local function ensureFrame()
    if CastBar.frame == nil then
        CastBar.frame = createFrame()
    end
    if CastBar.frame == nil then
        return nil
    end

    ensureEventsRegistered(CastBar.frame)
    attachDragHandlers(CastBar.frame)

    local active, cfg = getActiveConfig()

    if cfg ~= nil then
        applyFrameSettings(CastBar.frame, cfg)
    end

    if not active then
        CastBar.frame.__nuzi_castbar_dragging = false
        CastBar.frame.__nuzi_castbar_drag_state = nil
        clearCursor()
        resetState()
        hideFrame(CastBar.frame, true)
        setWidgetVisible(CastBar.frame.probeLabel, false)
        setWidgetVisible(CastBar.frame.text, false)
    end

    return CastBar.frame
end

function CastBar.Init(settings)
    CastBar.settings = settings
    CastBar.enabled = type(settings) == "table" and settings.enabled and true or false
    local frame = ensureFrame()
    if frame ~= nil and not CastBar.state.is_casting then
        refreshIdleFrame(frame)
    end
end

function CastBar.ApplySettings(settings)
    CastBar.settings = settings
    local frame = ensureFrame()
    if frame ~= nil and not CastBar.state.is_casting then
        refreshIdleFrame(frame)
    end
end

function CastBar.SetEnabled(enabled)
    CastBar.enabled = enabled and true or false
    local frame = ensureFrame()
    if frame ~= nil and not CastBar.state.is_casting then
        refreshIdleFrame(frame)
    end
end

function CastBar.SetPreviewVisible(visible, settings)
    if type(settings) == "table" then
        CastBar.settings = settings
    end

    CastBar.preview_visible = visible and true or false

    if not CastBar.preview_visible and CastBar.frame == nil then
        return
    end

    local frame = ensureFrame()
    if frame == nil or CastBar.state.is_casting then
        return
    end

    refreshIdleFrame(frame)
end

function CastBar.OnUpdate(dt, settings)
    if type(settings) == "table" then
        CastBar.settings = settings
    end

    local frame = ensureFrame()
    if frame == nil then
        return
    end

    dt = tonumber(dt) or 0
    if CastBar.state.ignore_info_ms > 0 then
        CastBar.state.ignore_info_ms = math.max(0, CastBar.state.ignore_info_ms - dt)
    end

    local active = getActiveConfig()
    if not active then
        return
    end

    if frame.__nuzi_castbar_dragging then
        local _, cfg = getActiveConfig()
        if cfg ~= nil then
            updateDragPosition(frame, cfg)
        end
    end

    if CastBar.state.ignore_info_ms > 0 and CastBar.state.is_casting then
        return
    end

    local info = getCastingInfo()
    local totalMs = tonumber(type(info) == "table" and info.castingTime or nil)
    local currentMs = tonumber(type(info) == "table" and info.currCastingTime or nil)

    if totalMs ~= nil and currentMs ~= nil then
        local spellName = tostring(info.spellName or CastBar.state.spell_name or "")
        local castingUseable = CastBar.state.casting_useable
        if info.castingUseable ~= nil then
            castingUseable = info.castingUseable and true or false
        end
        if not CastBar.state.is_casting then
            beginCast(frame, spellName, totalMs, castingUseable)
        end
        updateCastingDisplay(frame, spellName, currentMs, totalMs, castingUseable)
        setProbeText(frame, "Cast source: UnitCastingInfo")
        return
    end

    if CastBar.state.is_casting then
        local totalMsFallback = tonumber(CastBar.state.cast_duration) or 0
        if totalMsFallback > 0 then
            local currentMsFallback = (tonumber(CastBar.state.elapsed_ms) or 0) + dt
            updateCastingDisplay(
                frame,
                CastBar.state.spell_name,
                currentMsFallback,
                totalMsFallback,
                CastBar.state.casting_useable
            )
            setProbeText(frame, "Cast source: local timer")
            return
        end

        stopCast(frame, false)
        return
    end

    refreshIdleFrame(frame)
end

function CastBar.Unload()
    if CastBar.frame ~= nil then
        CastBar.frame.__nuzi_castbar_dragging = false
        CastBar.frame.__nuzi_castbar_drag_state = nil
        hideFrame(CastBar.frame, true)
        if api ~= nil and api.Interface ~= nil and api.Interface.Free ~= nil then
            safeCall(function()
                api.Interface:Free(CastBar.frame)
            end)
        end
    end
    clearCursor()
    CastBar.frame = nil
    CastBar.preview_visible = false
    CastBar.state.ignore_info_ms = 0
    resetState()
end

return CastBar
