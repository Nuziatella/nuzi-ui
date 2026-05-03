local api = require("api")
local SafeRequire = require("nuzi-ui/safe_require")
local Compat = SafeRequire("nuzi-ui/compat")
local Runtime = SafeRequire("nuzi-ui/runtime")
local DebuffEffects = SafeRequire("nuzi-ui/debuff_effects", "nuzi-ui.debuff_effects")

local Nameplates = {
    settings = nil,
    enabled = false,
    frames = {},
    debuff_frames = {},
    unit_keys = {},
    unit_state = {},
    target_unitframe = nil,
    tick = 0,
    discovery_index = 1
}

local FAST_UNITS = {
    player = true,
    target = true,
    watchtarget = true,
    playerpet1 = true
}

local DISCOVERY_BATCH_SIZE = 10
local STATIC_INFO_RETRY_TICKS = 30
local DEBUFF_SCAN_INTERVAL_MS = 250
local DEBUFF_ICON_COUNT = 4
local DEBUFF_DISPEL_SLOT_COLOR = { 0.7059, 0.2824, 1, 1 }
local DEBUFF_CATEGORY_SETTINGS = {
    hard = "show_hard",
    silence = "show_silence",
    root = "show_root",
    slow = "show_slow",
    dot = "show_dot",
    misc = "show_misc"
}

local function NormalizeUnitToken(unit)
    if type(unit) ~= "string" then
        return nil
    end
    local text = tostring(unit or "")
    if text == "" then
        return nil
    end
    return text
end

local function NormalizeUnitId(unitId)
    if unitId == nil then
        return nil
    end
    local valueType = type(unitId)
    if valueType == "string" then
        local text = tostring(unitId)
        if text == "" then
            return nil
        end
        return text
    end
    if valueType == "number" then
        return tostring(unitId)
    end
    return nil
end

local function SafeGetUnitInfoById(unitId)
    local normalizedId = NormalizeUnitId(unitId)
    if normalizedId == nil or api == nil or api.Unit == nil or api.Unit.GetUnitInfoById == nil then
        return nil
    end
    local info = nil
    pcall(function()
        info = api.Unit:GetUnitInfoById(normalizedId)
    end)
    if type(info) == "table" then
        return info
    end
    return nil
end

local function TrimText(value)
    local text = tostring(value or "")
    return string.match(text, "^%s*(.-)%s*$") or text
end

local function FormatGuildFamilyText(guild, family)
    guild = TrimText(guild)
    family = TrimText(family)
    if guild ~= "" and family ~= "" then
        return string.format("<%s> (%s)", guild, family)
    elseif guild ~= "" then
        return string.format("<%s>", guild)
    elseif family ~= "" then
        return string.format("(%s)", family)
    end
    return ""
end

local function ClampNumber(v, lo, hi, default)
    local n = tonumber(v)
    if n == nil then
        return default
    end
    if lo ~= nil and n < lo then
        return lo
    end
    if hi ~= nil and n > hi then
        return hi
    end
    return n
end

local function Percent01(pct, default)
    local n = tonumber(pct)
    if n == nil then
        local d = tonumber(default)
        if d == nil then
            d = 100
        end
        if d < 0 then
            d = 0
        elseif d > 100 then
            d = 100
        end
        return d / 100
    end
    if n < 0 then
        n = 0
    elseif n > 100 then
        n = 100
    end
    return n / 100
end

local function SafeShow(wnd, show)
    if wnd == nil or wnd.Show == nil then
        return
    end
    show = show and true or false
    if wnd.__polar_visible == show then
        return
    end
    pcall(function()
        wnd:Show(show)
    end)
    wnd.__polar_visible = show
end

local function SafeClickable(wnd, clickable)
    if wnd == nil then
        return
    end
    clickable = clickable and true or false
    if wnd.__polar_clickable == clickable then
        return
    end
    if wnd.Clickable ~= nil then
        pcall(function()
            wnd:Clickable(clickable)
        end)
    end
    if wnd.EnablePick ~= nil then
        pcall(function()
            wnd:EnablePick(clickable)
        end)
    end
    if not clickable and wnd.EnableDrag ~= nil then
        pcall(function()
            wnd:EnableDrag(false)
        end)
    end
    wnd.__polar_clickable = clickable
end

local function SafeSetText(lbl, txt)
    if lbl == nil or lbl.SetText == nil then
        return
    end
    txt = tostring(txt or "")
    if lbl.__polar_text == txt then
        return
    end
    pcall(function()
        lbl:SetText(txt)
    end)
    lbl.__polar_text = txt
end

local function SafeSetTextColor(lbl, r, g, b, a)
    if lbl == nil or lbl.style == nil or lbl.style.SetColor == nil then
        return
    end
    local colorKey = string.format("%.3f:%.3f:%.3f:%.3f", tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0, tonumber(a) or 0)
    if lbl.__polar_text_color_key == colorKey then
        return
    end
    pcall(function()
        lbl.style:SetColor(r, g, b, a)
    end)
    lbl.__polar_text_color_key = colorKey
end

local function Clamp01(v, default)
    local n = tonumber(v)
    if n == nil then
        return default
    end
    if n > 1 then
        n = n / 255
    end
    if n < 0 then
        return 0
    end
    if n > 1 then
        return 1
    end
    return n
end

local function RoundPixel(value)
    local n = tonumber(value)
    if n == nil then
        return 0
    end
    if n >= 0 then
        return math.floor(n + 0.5)
    end
    return math.ceil(n - 0.5)
end

local function NormalizeScreenAnchor(x, y, z)
    local nx = tonumber(x)
    local ny = tonumber(y)
    local nz = tonumber(z)
    if nx == nil or ny == nil or nz == nil or nz < 0 then
        return nil, nil, nil
    end
    return nx, ny, nz
end

local function GetUnitScreenAnchor(unit, preferNameTag)
    if api == nil or api.Unit == nil then
        return nil, nil, nil
    end

    local x = nil
    local y = nil
    local z = nil

    if preferNameTag and api.Unit.GetUnitScreenNameTagOffset ~= nil then
        pcall(function()
            x, y, z = api.Unit:GetUnitScreenNameTagOffset(unit)
        end)
        return NormalizeScreenAnchor(x, y, z)
    end

    if api.Unit.GetUnitScreenPosition == nil then
        return nil, nil, nil
    end

    pcall(function()
        x, y, z = api.Unit:GetUnitScreenPosition(unit)
    end)
    return NormalizeScreenAnchor(x, y, z)
end

local function SafeUiNowMs()
    if api.Time == nil or api.Time.GetUiMsec == nil then
        return 0
    end
    local ok, value = pcall(function()
        return api.Time:GetUiMsec()
    end)
    if not ok then
        return 0
    end
    return tonumber(value) or 0
end

local function GetUnitState(unit)
    local state = Nameplates.unit_state[unit]
    if state ~= nil then
        return state
    end
    state = {
        unit_id = nil,
        name = "",
        guild = "",
        family = "",
        is_character = true,
        next_info_retry_tick = 0,
        visible = false,
        debuff_visible = false,
        debuff_effects = {},
        debuff_last_scan_ms = 0
    }
    Nameplates.unit_state[unit] = state
    return state
end

local function HideUnit(unit, state)
    local frame = Nameplates.frames[unit]
    if frame ~= nil then
        SafeShow(frame, false)
    end
    if type(state) == "table" then
        state.visible = false
    end
end

local function HideDebuffs(unit, state)
    local frame = Nameplates.debuff_frames[unit]
    if frame ~= nil then
        SafeShow(frame, false)
    end
    if type(state) == "table" then
        state.debuff_visible = false
    end
end

local function HideAllFrames()
    for unit, frame in pairs(Nameplates.frames) do
        SafeShow(frame, false)
        local state = Nameplates.unit_state[unit]
        if type(state) == "table" then
            state.visible = false
        end
    end
end

local function HideAllDebuffs()
    for unit, frame in pairs(Nameplates.debuff_frames) do
        SafeShow(frame, false)
        local state = Nameplates.unit_state[unit]
        if type(state) == "table" then
            state.debuff_visible = false
        end
    end
end

local function ApplyGuildTextColor(lbl, cfg, guild)
    local r, g, b, a = 1, 1, 1, 1
    if type(cfg) == "table" and type(cfg.guild_colors) == "table" and guild ~= nil then
        local function normalize_key(raw)
            local k = tostring(raw or "")
            k = string.match(k, "^%s*(.-)%s*$") or k
            k = string.lower(k)
            k = string.gsub(k, "%s+", "_")
            k = string.gsub(k, "[^%w_]", "")
            if k ~= "" and string.match(k, "^%d") ~= nil then
                k = "_" .. k
            end
            return k
        end

        local key = tostring(guild or "")
        local rule = cfg.guild_colors[key]
        if rule == nil and key ~= "" then
            rule = cfg.guild_colors[string.lower(key)]
        end
        if rule == nil and key ~= "" then
            local norm = normalize_key(key)
            if norm ~= "" then
                rule = cfg.guild_colors[norm]
            end
        end
        if type(rule) == "table" then
            r = Clamp01(rule[1], 1)
            g = Clamp01(rule[2], 1)
            b = Clamp01(rule[3], 1)
            a = Clamp01(rule[4], 1)
        end
    end
    SafeSetTextColor(lbl, r, g, b, a)
end

local function SafeSetAlpha(wnd, a01)
    if wnd == nil then
        return
    end
    if wnd.SetAlpha == nil then
        return
    end
    local alpha = ClampNumber(a01, 0, 1, 1)
    if wnd.__polar_alpha == alpha then
        return
    end
    pcall(function()
        wnd:SetAlpha(alpha)
    end)
    wnd.__polar_alpha = alpha
end

local function SafeSetBg(frame, enabled, alpha01)
    if frame == nil or frame.bg == nil then
        return
    end
    local bg = frame.bg
    enabled = enabled and true or false
    local alpha = ClampNumber(alpha01, 0, 1, 0.8)
    SafeShow(bg, enabled)
    if bg.SetColor ~= nil and (bg.__polar_bg_alpha ~= alpha or bg.__polar_bg_enabled ~= enabled) then
        pcall(function()
            bg:SetColor(1, 1, 1, alpha)
        end)
        bg.__polar_bg_alpha = alpha
        bg.__polar_bg_enabled = enabled
    end
end

local function SafeSetAnchorTopLeft(wnd, x, y)
    if wnd == nil or wnd.AddAnchor == nil then
        return
    end
    x = tonumber(x) or 0
    y = tonumber(y) or 0
    if wnd.__polar_anchor_x == x and wnd.__polar_anchor_y == y then
        return
    end
    pcall(function()
        if wnd.RemoveAllAnchors ~= nil then
            wnd:RemoveAllAnchors()
        end
        wnd:AddAnchor("TOPLEFT", "UIParent", x, y)
    end)
    wnd.__polar_anchor_x = x
    wnd.__polar_anchor_y = y
end

local function SafeSetExtent(wnd, width, height)
    if wnd == nil or wnd.SetExtent == nil then
        return
    end
    width = tonumber(width) or 0
    height = tonumber(height) or 0
    if wnd.__polar_extent_w == width and wnd.__polar_extent_h == height then
        return
    end
    pcall(function()
        wnd:SetExtent(width, height)
    end)
    wnd.__polar_extent_w = width
    wnd.__polar_extent_h = height
end

local function SafeAnchor(wnd, point, relative, relativePoint, x, y)
    if wnd == nil or wnd.AddAnchor == nil then
        return
    end
    local key = table.concat({
        tostring(point or ""),
        tostring(relative or ""),
        tostring(relativePoint or ""),
        tostring(x or 0),
        tostring(y or 0)
    }, ":")
    if wnd.__polar_anchor_key == key then
        return
    end
    pcall(function()
        if wnd.RemoveAllAnchors ~= nil then
            wnd:RemoveAllAnchors()
        end
        wnd:AddAnchor(point, relative, relativePoint, x or 0, y or 0)
    end)
    wnd.__polar_anchor_key = key
end

local function SafeSetBarValue(statusBar, maxValue, value)
    if statusBar == nil then
        return
    end
    maxValue = tonumber(maxValue) or 0
    value = tonumber(value) or 0
    if statusBar.__polar_max ~= maxValue then
        pcall(function()
            statusBar:SetMinMaxValues(0, maxValue)
        end)
        statusBar.__polar_max = maxValue
    end
    if statusBar.__polar_value == value then
        return
    end
    pcall(function()
        statusBar:SetValue(value)
    end)
    statusBar.__polar_value = value
end

local function ShouldShowUnit(unit, cfg)
    if unit == nil then
        return false
    end
    if unit == "target" then
        return cfg.show_target and true or false
    end
    if unit == "watchtarget" then
        return cfg.show_watchtarget and true or false
    end
    if unit == "playerpet1" then
        return cfg.show_mount and true or false
    end
    if unit == "player" then
        return cfg.show_player and true or false
    end
    if string.match(unit, "^team%d+$") then
        return cfg.show_raid_party and true or false
    end
    return false
end

local function GetDebuffCfg(cfg)
    if type(cfg) ~= "table" or type(cfg.debuffs) ~= "table" then
        return {}
    end
    return cfg.debuffs
end

local function DebuffsEnabled(cfg)
    local debuffs = GetDebuffCfg(cfg)
    return debuffs.enabled and true or false
end

local function ShouldTrackDebuffUnit(unit, cfg, debuffCfg)
    if not ShouldShowUnit(unit, cfg) then
        return false
    end
    if unit == "target" or unit == "player" or unit == "watchtarget" then
        return true
    end
    if string.match(unit or "", "^team%d+$") then
        return tostring(debuffCfg.tracking_scope or "focus") == "raid"
    end
    return false
end

local function IsDebuffCategoryEnabled(cfg, category)
    local key = DEBUFF_CATEGORY_SETTINGS[tostring(category or "")]
    if key == nil then
        return true
    end
    return cfg[key] ~= false
end

local function FilterDebuffEffects(cfg, effects)
    if type(effects) ~= "table" or #effects == 0 then
        return {}
    end
    local filtered = {}
    for _, effect in ipairs(effects) do
        if type(effect) == "table" and IsDebuffCategoryEnabled(cfg, effect.category) then
            filtered[#filtered + 1] = effect
        end
    end
    return filtered
end

local function GetCachedDebuffEffects(state, unit)
    if DebuffEffects == nil then
        return {}
    end
    local nowMs = SafeUiNowMs()
    local last = tonumber(state.debuff_last_scan_ms) or 0
    if type(state.debuff_effects) == "table"
        and nowMs > 0
        and last > 0
        and (nowMs - last) < DEBUFF_SCAN_INTERVAL_MS then
        return state.debuff_effects
    end
    local effects = DebuffEffects.ScanUnit(unit)
    state.debuff_effects = effects
    state.debuff_last_scan_ms = nowMs
    return effects
end

local function ApplyLayout(frame, cfg)
    if frame == nil or type(cfg) ~= "table" then
        return
    end

    local guildOnly = cfg.guild_only and true or false
    local width = ClampNumber(cfg.width, 50, 400, 120)
    local hpHeight = ClampNumber(cfg.hp_height, 5, 60, 28)
    local mpHeight = ClampNumber(cfg.mp_height, 0, 40, 4)
    local totalHeight = hpHeight + mpHeight

    if guildOnly then
        local guildFs = ClampNumber(cfg.guild_font_size, 6, 32, 11)
        totalHeight = guildFs + 8
    end

    local layoutKey = table.concat({
        guildOnly and "1" or "0",
        tostring(width),
        tostring(hpHeight),
        tostring(mpHeight),
        tostring(ClampNumber(cfg.name_font_size, 6, 32, 14)),
        tostring(ClampNumber(cfg.guild_font_size, 6, 32, 11))
    }, ":")
    if frame.__polar_layout_key == layoutKey then
        return
    end
    frame.__polar_layout_key = layoutKey

    pcall(function()
        if frame.SetExtent ~= nil then
            frame:SetExtent(width, totalHeight)
        end
    end)

    if guildOnly then
        if frame.guildLabel ~= nil and frame.guildLabel.style ~= nil then
            pcall(function()
                local size = ClampNumber(cfg.guild_font_size, 6, 32, 11)
                frame.guildLabel.style:SetFontSize(size)
            end)
        end
        return
    end

    if frame.hpBar ~= nil then
        pcall(function()
            frame.hpBar:RemoveAllAnchors()
            frame.hpBar:AddAnchor("TOPLEFT", frame, 0, 0)
            frame.hpBar:AddAnchor("TOPRIGHT", frame, 0, 0)
            frame.hpBar:SetHeight(hpHeight)
        end)
    end

    if frame.mpBar ~= nil then
        pcall(function()
            frame.mpBar:RemoveAllAnchors()
            frame.mpBar:AddAnchor("TOPLEFT", frame.hpBar, "BOTTOMLEFT", 0, -1)
            frame.mpBar:AddAnchor("TOPRIGHT", frame.hpBar, "BOTTOMRIGHT", 0, -1)
            frame.mpBar:SetHeight(mpHeight)
        end)
        if mpHeight > 0 then
            SafeShow(frame.mpBar, true)
        else
            SafeShow(frame.mpBar, false)
        end
    end

    if frame.nameLabel ~= nil and frame.nameLabel.style ~= nil then
        pcall(function()
            local size = ClampNumber(cfg.name_font_size, 6, 32, 14)
            frame.nameLabel.style:SetFontSize(size)
        end)
    end

    if frame.guildLabel ~= nil and frame.guildLabel.style ~= nil then
        pcall(function()
            local size = ClampNumber(cfg.guild_font_size, 6, 32, 11)
            frame.guildLabel.style:SetFontSize(size)
        end)
    end

    if frame.bg ~= nil then
        pcall(function()
            if frame.bg.RemoveAllAnchors ~= nil then
                frame.bg:RemoveAllAnchors()
            end
            if frame.hpBar ~= nil and frame.mpBar ~= nil and frame.bg.AddAnchor ~= nil then
                frame.bg:AddAnchor("TOPLEFT", frame.hpBar, -3, -3)
                frame.bg:AddAnchor("BOTTOMRIGHT", frame.mpBar, 2, 3)
            end
        end)
    end
end

local function ApplyGuildMode(frame, guildOnly, showMpBar)
    if frame == nil or frame.__polar_guild_only == guildOnly then
        if not guildOnly then
            SafeShow(frame.hpBar, true)
            SafeShow(frame.mpBar, showMpBar and true or false)
        end
        return
    end
    frame.__polar_guild_only = guildOnly

    if guildOnly then
        SafeShow(frame.hpBar, false)
        SafeShow(frame.mpBar, false)
        SafeShow(frame.nameLabel, false)
        SafeSetBg(frame, false, 0)
        SafeShow(frame.eventWindow, false)
        pcall(function()
            if frame.guildLabel ~= nil then
                if frame.guildLabel.RemoveAllAnchors ~= nil then
                    frame.guildLabel:RemoveAllAnchors()
                end
                if frame.guildLabel.AddAnchor ~= nil then
                    frame.guildLabel:AddAnchor("TOPLEFT", frame, 3, -3)
                end
            end
        end)
        return
    end

    SafeShow(frame.nameLabel, true)
    SafeShow(frame.hpBar, true)
    SafeShow(frame.mpBar, showMpBar and true or false)
    SafeShow(frame.eventWindow, false)
    pcall(function()
        if frame.guildLabel ~= nil and frame.nameLabel ~= nil then
            if frame.guildLabel.RemoveAllAnchors ~= nil then
                frame.guildLabel:RemoveAllAnchors()
            end
            if frame.guildLabel.AddAnchor ~= nil then
                frame.guildLabel:AddAnchor("TOPLEFT", frame.nameLabel, "BOTTOMLEFT", 0, 0)
            end
        end
    end)
end

local function EnsureFrame(unit)
    if Nameplates.frames[unit] ~= nil then
        return Nameplates.frames[unit]
    end

    local frameId = "polarUiPlate_" .. unit
    local frame = api.Interface:CreateEmptyWindow(frameId)
    pcall(function()
        if frame.SetUILayer ~= nil then
            frame:SetUILayer("hud")
        end
    end)
    SafeClickable(frame, false)
    SafeShow(frame, false)

    local bg = nil
    pcall(function()
        if frame.CreateNinePartDrawable ~= nil and TEXTURE_PATH ~= nil and TEXTURE_PATH.RAID ~= nil then
            bg = frame:CreateNinePartDrawable(TEXTURE_PATH.RAID, "background")
            bg:SetCoords(33, 141, 7, 7)
            bg:SetInset(3, 3, 3, 3)
            bg:SetColor(1, 1, 1, 0.8)
            bg:Show(false)
        end
    end)
    frame.bg = bg

    local hpBar = nil
    local mpBar = nil
    pcall(function()
        if W_BAR ~= nil and W_BAR.CreateStatusBarOfRaidFrame ~= nil then
            hpBar = W_BAR.CreateStatusBarOfRaidFrame(frameId .. ".hpBar", frame)
            hpBar:Show(true)
            hpBar:Clickable(false)
            if hpBar.statusBar ~= nil and hpBar.statusBar.Clickable ~= nil then
                hpBar.statusBar:Clickable(false)
            end
            if STATUSBAR_STYLE ~= nil and STATUSBAR_STYLE.HP_RAID ~= nil then
                hpBar:ApplyBarTexture(STATUSBAR_STYLE.HP_RAID)
            end

            mpBar = W_BAR.CreateStatusBarOfRaidFrame(frameId .. ".mpBar", frame)
            mpBar:Show(true)
            mpBar:Clickable(false)
            if mpBar.statusBar ~= nil and mpBar.statusBar.Clickable ~= nil then
                mpBar.statusBar:Clickable(false)
            end
            if STATUSBAR_STYLE ~= nil and STATUSBAR_STYLE.MP_RAID ~= nil then
                mpBar:ApplyBarTexture(STATUSBAR_STYLE.MP_RAID)
            end
        end
    end)
    frame.hpBar = hpBar
    frame.mpBar = mpBar

    local nameLabel = api.Interface:CreateWidget("label", frameId .. ".name", frame)
    pcall(function()
        nameLabel:Show(true)
        if nameLabel.Clickable ~= nil then
            nameLabel:Clickable(false)
        end
        if nameLabel.SetLimitWidth ~= nil then
            nameLabel:SetLimitWidth(true)
        end
        if nameLabel.SetExtent ~= nil then
            nameLabel:SetExtent(220, FONT_SIZE and FONT_SIZE.MIDDLE or 14)
        end
        if nameLabel.style ~= nil then
            nameLabel.style:SetAlign(ALIGN.LEFT)
            nameLabel.style:SetFontSize(FONT_SIZE and FONT_SIZE.MIDDLE or 14)
            nameLabel.style:SetColor(1, 1, 1, 1)
        end
        nameLabel:AddAnchor("TOPLEFT", frame, 3, -3)
    end)
    frame.nameLabel = nameLabel

    local guildLabel = api.Interface:CreateWidget("label", frameId .. ".guild", frame)
    pcall(function()
        guildLabel:Show(true)
        if guildLabel.Clickable ~= nil then
            guildLabel:Clickable(false)
        end
        if guildLabel.SetLimitWidth ~= nil then
            guildLabel:SetLimitWidth(true)
        end
        if guildLabel.SetExtent ~= nil then
            guildLabel:SetExtent(220, FONT_SIZE and FONT_SIZE.SMALL or 11)
        end
        if guildLabel.style ~= nil then
            guildLabel.style:SetAlign(ALIGN.LEFT)
            guildLabel.style:SetFontSize(FONT_SIZE and FONT_SIZE.SMALL or 11)
            guildLabel.style:SetColor(1, 1, 1, 1)
        end
        guildLabel:AddAnchor("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, 0)
        guildLabel:SetText("")
    end)
    frame.guildLabel = guildLabel

    local eventWindow = api.Interface:CreateWidget("emptywidget", frameId .. ".event", frame)
    pcall(function()
        eventWindow:AddAnchor("TOPLEFT", frame, 0, 0)
        eventWindow:AddAnchor("BOTTOMRIGHT", frame, 0, 0)
        eventWindow:Show(false)
        eventWindow:EnableDrag(false)
        if eventWindow.EnablePick ~= nil then
            eventWindow:EnablePick(false)
        end
    end)
    if eventWindow.Clickable ~= nil then
        pcall(function()
            eventWindow:Clickable(false)
        end)
    end
    frame.eventWindow = eventWindow

    Nameplates.frames[unit] = frame
    return frame
end

local function CloneSlotStyle(style)
    if type(style) ~= "table" then
        return style
    end
    local out = {}
    for key, value in pairs(style) do
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

local function GetDebuffSlotStyle(isDispellable)
    local base = DEBUFF or (SLOT_STYLE ~= nil and (SLOT_STYLE.BUFF or SLOT_STYLE.DEFAULT or SLOT_STYLE.ITEM)) or nil
    if not isDispellable or type(base) ~= "table" then
        return base
    end
    local style = CloneSlotStyle(base)
    style.color = {
        DEBUFF_DISPEL_SLOT_COLOR[1],
        DEBUFF_DISPEL_SLOT_COLOR[2],
        DEBUFF_DISPEL_SLOT_COLOR[3],
        DEBUFF_DISPEL_SLOT_COLOR[4]
    }
    return style
end

local function ApplyDebuffIconStyle(icon, isDispellable)
    if icon == nil or icon.back == nil or F_SLOT == nil or F_SLOT.ApplySlotSkin == nil then
        return
    end
    local style = GetDebuffSlotStyle(isDispellable == true)
    if style == nil then
        return
    end
    pcall(function()
        F_SLOT.ApplySlotSkin(icon, icon.back, style)
    end)
end

local function SetDebuffIconPath(icon, path)
    if icon == nil then
        return
    end
    path = tostring(path or "")
    if icon.__polar_debuff_icon_path == path then
        return
    end
    icon.__polar_debuff_icon_path = path
    if path == "" then
        pcall(function()
            if icon.SetTexture ~= nil then
                icon:SetTexture("")
            end
            if icon.back ~= nil and icon.back.SetTexture ~= nil then
                icon.back:SetTexture("")
            end
        end)
        return
    end
    pcall(function()
        if F_SLOT ~= nil and F_SLOT.SetIconBackGround ~= nil then
            F_SLOT.SetIconBackGround(icon, path)
        elseif icon.SetIconPath ~= nil then
            icon:SetIconPath(path)
        elseif icon.SetTexture ~= nil then
            icon:SetTexture(path)
        end
    end)
end

local function CreateDebuffIcon(id, parent)
    if parent == nil then
        return nil
    end
    local icon = nil
    if type(CreateItemIconButton) == "function" then
        pcall(function()
            icon = CreateItemIconButton(id, parent)
        end)
    end
    if icon == nil and api.Interface ~= nil and api.Interface.CreateWidget ~= nil then
        pcall(function()
            icon = api.Interface:CreateWidget("button", id, parent)
        end)
    end
    if icon == nil then
        return nil
    end
    SafeClickable(icon, false)
    SafeShow(icon, false)
    ApplyDebuffIconStyle(icon, false)
    return icon
end

local function CreateDebuffTimerLabel(id, parent)
    if parent == nil or api.Interface == nil or api.Interface.CreateWidget == nil then
        return nil
    end
    local label = nil
    pcall(function()
        label = api.Interface:CreateWidget("label", id, parent)
    end)
    if label == nil then
        return nil
    end
    SafeClickable(label, false)
    SafeShow(label, false)
    pcall(function()
        if label.style ~= nil then
            if label.style.SetAlign ~= nil and ALIGN ~= nil then
                label.style:SetAlign(ALIGN.CENTER)
            end
            if label.style.SetShadow ~= nil then
                label.style:SetShadow(true)
            end
            if label.style.SetColor ~= nil then
                label.style:SetColor(1, 1, 1, 1)
            end
        end
    end)
    return label
end

local function SetDebuffTimerStyle(label, fontSize)
    if label == nil then
        return
    end
    local size = ClampNumber(fontSize, 8, 24, 11)
    if label.__polar_debuff_timer_size == size then
        return
    end
    SafeSetExtent(label, 56, size + 6)
    pcall(function()
        if label.style ~= nil and label.style.SetFontSize ~= nil then
            label.style:SetFontSize(size)
        end
    end)
    label.__polar_debuff_timer_size = size
end

local function EnsureDebuffFrame(unit)
    if Nameplates.debuff_frames[unit] ~= nil then
        return Nameplates.debuff_frames[unit]
    end
    if api.Interface == nil or api.Interface.CreateEmptyWindow == nil then
        return nil
    end

    local frameId = "polarUiPlateDebuffs_" .. unit
    local frame = api.Interface:CreateEmptyWindow(frameId, "UIParent")
    if frame == nil then
        return nil
    end
    pcall(function()
        if frame.SetUILayer ~= nil then
            frame:SetUILayer("hud")
        end
    end)
    SafeClickable(frame, false)
    SafeShow(frame, false)

    frame.icons = {}
    for index = 1, DEBUFF_ICON_COUNT do
        local icon = CreateDebuffIcon(frameId .. ".icon" .. tostring(index), frame)
        local timer = CreateDebuffTimerLabel(frameId .. ".timer" .. tostring(index), icon)
        frame.icons[index] = {
            icon = icon,
            timer = timer
        }
    end

    Nameplates.debuff_frames[unit] = frame
    return frame
end

local function PositionDebuffFrame(frame, cfg, rowWidth, rowHeight, screenX, screenY)
    local anchor = tostring(cfg.anchor or "top")
    local gap = ClampNumber(cfg.gap, 0, 12, 4)
    local offsetX = ClampNumber(cfg.offset_x, -120, 120, 0)
    local offsetY = ClampNumber(cfg.offset_y, -120, 120, -8)
    local rootX = screenX - (rowWidth / 2) + offsetX
    local rootY = screenY - rowHeight - gap + offsetY

    if anchor == "left" then
        rootX = screenX - rowWidth - gap + offsetX
        rootY = screenY - (rowHeight / 2) + offsetY
    elseif anchor == "right" then
        rootX = screenX + gap + offsetX
        rootY = screenY - (rowHeight / 2) + offsetY
    end

    SafeSetExtent(frame, rowWidth, rowHeight)
    SafeSetAnchorTopLeft(frame, RoundPixel(rootX), RoundPixel(rootY))
end

local function LayoutDebuffIcons(frame, cfg, count)
    local anchor = tostring(cfg.anchor or "top")
    local iconSize = ClampNumber(cfg.icon_size, 16, 48, 30)
    local secondarySize = ClampNumber(cfg.secondary_icon_size, 10, 32, 18)
    secondarySize = math.min(secondarySize, math.max(10, iconSize - 4))
    local gap = ClampNumber(cfg.gap, 0, 12, 4)
    local rowWidth = iconSize
    if count > 1 then
        rowWidth = iconSize + ((count - 1) * (secondarySize + gap))
    end
    local rowHeight = iconSize

    local primaryX = anchor == "left" and (rowWidth - iconSize) or 0
    local layoutKey = table.concat({
        tostring(anchor),
        tostring(count),
        tostring(iconSize),
        tostring(secondarySize),
        tostring(gap)
    }, ":")
    if frame.__polar_debuff_layout_key ~= layoutKey then
        for index, entry in ipairs(frame.icons or {}) do
            local icon = entry.icon
            if icon ~= nil then
                local size = index == 1 and iconSize or secondarySize
                local x = primaryX
                if index > 1 then
                    if anchor == "left" then
                        x = primaryX - ((index - 1) * (secondarySize + gap))
                    else
                        x = iconSize + gap + ((index - 2) * (secondarySize + gap))
                    end
                end
                local y = index == 1 and 0 or RoundPixel((iconSize - secondarySize) / 2)
                SafeSetExtent(icon, size, size)
                SafeAnchor(icon, "TOPLEFT", frame, "TOPLEFT", RoundPixel(x), y)
                if entry.timer ~= nil then
                    SafeAnchor(entry.timer, "CENTER", icon, "CENTER", 0, 0)
                end
            end
        end
        frame.__polar_debuff_layout_key = layoutKey
    end

    return rowWidth, rowHeight
end

local function UpdateDebuffWidgets(frame, cfg, effects, screenX, screenY)
    if frame == nil or type(frame.icons) ~= "table" then
        return false
    end

    effects = FilterDebuffEffects(cfg, effects)
    if type(effects) ~= "table" or #effects == 0 then
        for _, entry in ipairs(frame.icons) do
            SafeShow(entry.icon, false)
            SafeShow(entry.timer, false)
        end
        SafeShow(frame, false)
        return false
    end

    local maxIcons = ClampNumber(cfg.max_icons, 1, DEBUFF_ICON_COUNT, 4)
    if cfg.show_secondary == false then
        maxIcons = 1
    end
    local count = math.min(#effects, maxIcons, #frame.icons)
    local rowWidth, rowHeight = LayoutDebuffIcons(frame, cfg, count)
    frame.__polar_debuff_row_width = rowWidth
    frame.__polar_debuff_row_height = rowHeight
    PositionDebuffFrame(frame, cfg, rowWidth, rowHeight, screenX, screenY)

    for index, entry in ipairs(frame.icons) do
        local effect = effects[index]
        if index <= count and effect ~= nil then
            ApplyDebuffIconStyle(entry.icon, effect.dispellable == true)
            SetDebuffIconPath(entry.icon, effect.path)
            SafeShow(entry.icon, true)
            if cfg.show_timer ~= false and entry.timer ~= nil then
                SetDebuffTimerStyle(entry.timer, cfg.timer_font_size)
                SafeSetText(entry.timer, string.format("%.1f", math.max(0, (tonumber(effect.time_left_ms) or 0) / 1000)))
                SafeShow(entry.timer, true)
            else
                SafeShow(entry.timer, false)
            end
        else
            SafeShow(entry.icon, false)
            SafeShow(entry.timer, false)
        end
    end

    SafeShow(frame, true)
    return true
end

local function GetCfg(settings)
    if type(settings) ~= "table" or type(settings.nameplates) ~= "table" then
        return {}
    end
    return settings.nameplates
end

local function GetPlateLayoutMetrics(cfg)
    if type(cfg) ~= "table" then
        cfg = {}
    end

    local guildOnly = cfg.guild_only and true or false
    local width = ClampNumber(cfg.width, 50, 400, 120)
    local hpHeight = ClampNumber(cfg.hp_height, 5, 60, 28)
    local mpHeight = ClampNumber(cfg.mp_height, 0, 40, 4)
    local totalHeight = hpHeight + mpHeight

    if guildOnly then
        local guildFs = ClampNumber(cfg.guild_font_size, 6, 32, 11)
        totalHeight = guildFs + 8
    end

    return width, hpHeight, mpHeight, totalHeight
end

local function PositionPlateFrame(frame, cfg, screenX, screenY)
    if frame == nil then
        return
    end
    if type(cfg) ~= "table" then
        cfg = {}
    end

    local width, _, _, totalHeight = GetPlateLayoutMetrics(cfg)
    local posX = RoundPixel(screenX + ClampNumber(cfg.x_offset, -500, 500, 0) - (width / 2))
    local posY = RoundPixel(screenY - ClampNumber(cfg.y_offset, -200, 200, 22) - (totalHeight / 2))
    SafeSetAnchorTopLeft(frame, posX, posY)
end

local function RefreshStaticState(state, id, unit, cfg)
    if type(state) ~= "table" then
        return
    end

    if state.unit_id ~= id then
        state.unit_id = id
        state.name = ""
        state.guild = ""
        state.family = ""
        state.is_character = true
        state.next_info_retry_tick = 0
    end

    if state.name == "" and Runtime ~= nil and Runtime.GetUnitNameById ~= nil then
        state.name = tostring(Runtime.GetUnitNameById(id) or "")
    end

    local needInfo = cfg.guild_only or cfg.show_guild
    local shouldProbeInfo = needInfo or state.name == ""
    if not shouldProbeInfo then
        return
    end

    if (tonumber(state.next_info_retry_tick) or 0) > (tonumber(Nameplates.tick) or 0) then
        return
    end

    local info = SafeGetUnitInfoById(id)
    if type(info) ~= "table" then
        state.next_info_retry_tick = (tonumber(Nameplates.tick) or 0) + STATIC_INFO_RETRY_TICKS
        return
    end

    local infoName = tostring(info.name or info.unitName or info.family_name or "")
    if infoName ~= "" then
        state.name = infoName
    end
    state.guild = TrimText(info.expeditionName or info.guildName or info.guild or "")
    state.family = TrimText(info.family_name or "")
    if info.type ~= nil then
        state.is_character = (tostring(info.type) == "character")
    end
    state.next_info_retry_tick = math.huge
end

local function UpdateDebuffsForUnit(unit, settings)
    unit = NormalizeUnitToken(unit)
    if unit == nil then
        return
    end

    local state = GetUnitState(unit)
    local cfg = GetCfg(settings)
    local debuffCfg = GetDebuffCfg(cfg)
    if not (Nameplates.enabled and DebuffsEnabled(cfg)) then
        HideDebuffs(unit, state)
        return
    end
    if not ShouldTrackDebuffUnit(unit, cfg, debuffCfg) then
        HideDebuffs(unit, state)
        return
    end

    local id = nil
    pcall(function()
        id = api.Unit:GetUnitId(unit)
    end)
    if NormalizeUnitId(id) == nil then
        HideDebuffs(unit, state)
        return
    end

    local offsetX, offsetY = GetUnitScreenAnchor(unit, true)
    if offsetX == nil or offsetY == nil then
        HideDebuffs(unit, state)
        return
    end

    local dist = nil
    pcall(function()
        if api.Unit.UnitDistance ~= nil then
            dist = api.Unit:UnitDistance(unit)
        end
    end)
    local maxDist = ClampNumber(cfg.max_distance, 1, 500, 130)
    if type(dist) == "number" and dist > maxDist then
        HideDebuffs(unit, state)
        return
    end

    local frame = EnsureDebuffFrame(unit)
    if frame == nil then
        return
    end

    local shown = UpdateDebuffWidgets(frame, debuffCfg, GetCachedDebuffEffects(state, unit), offsetX, offsetY)
    state.debuff_visible = shown and true or false
end

local function UpdateOne(unit, settings)
    unit = NormalizeUnitToken(unit)
    if unit == nil then
        return
    end
    local state = GetUnitState(unit)
    local cfg = GetCfg(settings)
    if Compat ~= nil and not Compat.NameplatesSupported() then
        HideUnit(unit, state)
        return
    end

    local guildOnly = cfg.guild_only and true or false

    if not (Nameplates.enabled and cfg.enabled) then
        HideUnit(unit, state)
        return
    end

    if not ShouldShowUnit(unit, cfg) then
        HideUnit(unit, state)
        return
    end

    local id = nil
    pcall(function()
        id = api.Unit:GetUnitId(unit)
    end)
    id = NormalizeUnitId(id)
    if id == nil then
        HideUnit(unit, state)
        return
    end

    local offsetX, offsetY = GetUnitScreenAnchor(unit, cfg.anchor_to_nametag and true or false)
    if offsetX == nil or offsetY == nil then
        HideUnit(unit, state)
        return
    end

    local dist = nil
    pcall(function()
        if api.Unit.UnitDistance ~= nil then
            dist = api.Unit:UnitDistance(unit)
        end
    end)
    local maxDist = ClampNumber(cfg.max_distance, 1, 500, 130)
    if type(dist) == "number" and dist > maxDist then
        HideUnit(unit, state)
        return
    end

    local frame = EnsureFrame(unit)
    if frame == nil then
        return
    end

    ApplyLayout(frame, cfg)

    local alpha01 = Percent01(cfg.alpha_pct, 100)
    SafeSetAlpha(frame, alpha01)

    if not guildOnly then
        local bgEnabled = cfg.bg_enabled ~= false
        local bgAlpha01 = Percent01(cfg.bg_alpha_pct, 80)
        SafeSetBg(frame, bgEnabled, bgAlpha01)
    end

    local width, hpHeight, mpHeight, totalHeight = GetPlateLayoutMetrics(cfg)

    PositionPlateFrame(frame, cfg, offsetX, offsetY)

    ApplyGuildMode(frame, guildOnly, mpHeight > 0)

    RefreshStaticState(state, id, unit, cfg)
    SafeSetText(frame.nameLabel, state.name or "")

    local guildText = FormatGuildFamilyText(state.guild, state.family)
    if cfg.show_guild and state.is_character and guildText ~= "" then
        ApplyGuildTextColor(frame.guildLabel, cfg, state.guild)
        SafeShow(frame.guildLabel, true)
        SafeSetText(frame.guildLabel, guildText)
    else
        ApplyGuildTextColor(frame.guildLabel, cfg, nil)
        SafeSetText(frame.guildLabel, "")
        SafeShow(frame.guildLabel, false)
    end

    if not guildOnly then
        if frame.hpBar ~= nil and frame.hpBar.statusBar ~= nil then
            pcall(function()
                local maxHp = api.Unit:UnitMaxHealth(unit) or 0
                local hp = api.Unit:UnitHealth(unit) or 0
                SafeSetBarValue(frame.hpBar.statusBar, maxHp, hp)
            end)
        end

        if frame.mpBar ~= nil and frame.mpBar.statusBar ~= nil and mpHeight > 0 then
            pcall(function()
                local maxMp = api.Unit:UnitMaxMana(unit) or 0
                local mp = api.Unit:UnitMana(unit) or 0
                SafeSetBarValue(frame.mpBar.statusBar, maxMp, mp)
            end)
        end
    end

    SafeShow(frame, true)
    state.visible = true
end

local function EnsureUnitKeys()
    if #Nameplates.unit_keys > 0 then
        return
    end

    table.insert(Nameplates.unit_keys, "target")
    table.insert(Nameplates.unit_keys, "player")
    for i = 1, 50 do
        table.insert(Nameplates.unit_keys, string.format("team%d", i))
    end
    table.insert(Nameplates.unit_keys, "watchtarget")
    table.insert(Nameplates.unit_keys, "playerpet1")
end

Nameplates.Init = function(settings)
    Nameplates.settings = settings
    Nameplates.tick = 0
    Nameplates.discovery_index = 1
    if Compat ~= nil then
        Compat.Probe(false)
    end
    EnsureUnitKeys()

    if Runtime ~= nil and UIC ~= nil then
        Nameplates.target_unitframe = Runtime.GetStockContent(UIC.TARGET_UNITFRAME)
    end
end

Nameplates.ApplySettings = function(settings)
    Nameplates.settings = settings
end

Nameplates.SetEnabled = function(enabled)
    Nameplates.enabled = enabled and true or false
    if not Nameplates.enabled then
        HideAllFrames()
        HideAllDebuffs()
    end
end

Nameplates.OnPositionUpdate = function(settings)
    if settings == nil then
        return
    end
    if Compat ~= nil and not Compat.NameplatesSupported() then
        return
    end

    local cfg = GetCfg(settings)
    local customEnabled = Nameplates.enabled and cfg.enabled
    local debuffsEnabled = Nameplates.enabled and DebuffsEnabled(cfg)

    if customEnabled then
        for unit, frame in pairs(Nameplates.frames) do
            local state = Nameplates.unit_state[unit]
            if type(state) == "table" and state.visible then
                local x, y = GetUnitScreenAnchor(unit, cfg.anchor_to_nametag and true or false)
                if x ~= nil and y ~= nil then
                    PositionPlateFrame(frame, cfg, x, y)
                else
                    HideUnit(unit, state)
                end
            end
        end
    end

    if debuffsEnabled then
        local debuffCfg = GetDebuffCfg(cfg)
        for unit, frame in pairs(Nameplates.debuff_frames) do
            local state = Nameplates.unit_state[unit]
            if type(state) == "table" and state.debuff_visible then
                local rowWidth = tonumber(frame.__polar_debuff_row_width)
                local rowHeight = tonumber(frame.__polar_debuff_row_height)
                local x, y = GetUnitScreenAnchor(unit, true)
                if x ~= nil and y ~= nil and rowWidth ~= nil and rowHeight ~= nil then
                    PositionDebuffFrame(frame, debuffCfg, rowWidth, rowHeight, x, y)
                else
                    HideDebuffs(unit, state)
                end
            end
        end
    end
end

Nameplates.OnUpdate = function(settings)
    if settings == nil then
        return
    end
    if Compat ~= nil and not Compat.NameplatesSupported() then
        HideAllFrames()
        HideAllDebuffs()
        return
    end

    local cfg = GetCfg(settings)
    local customEnabled = Nameplates.enabled and cfg.enabled
    local debuffsEnabled = Nameplates.enabled and DebuffsEnabled(cfg)

    if not customEnabled then
        HideAllFrames()
    end
    if not debuffsEnabled then
        HideAllDebuffs()
    end
    if not customEnabled and not debuffsEnabled then
        return
    end

    Nameplates.tick = (tonumber(Nameplates.tick) or 0) + 1

    local processed = {}
    for _, unit in ipairs(Nameplates.unit_keys) do
        local state = GetUnitState(unit)
        if FAST_UNITS[unit] or state.visible or state.debuff_visible then
            if customEnabled then
                UpdateOne(unit, settings)
            end
            if debuffsEnabled then
                UpdateDebuffsForUnit(unit, settings)
            end
            processed[unit] = true
        end
    end

    local totalUnits = #Nameplates.unit_keys
    if totalUnits < 1 then
        return
    end

    local attempts = 0
    local processedHidden = 0
    local idx = tonumber(Nameplates.discovery_index) or 1
    while attempts < totalUnits and processedHidden < DISCOVERY_BATCH_SIZE do
        if idx > totalUnits then
            idx = 1
        end
        local unit = Nameplates.unit_keys[idx]
        idx = idx + 1
        attempts = attempts + 1

        if not processed[unit] then
            local state = GetUnitState(unit)
            if not state.visible and not state.debuff_visible then
                if customEnabled then
                    UpdateOne(unit, settings)
                end
                if debuffsEnabled then
                    UpdateDebuffsForUnit(unit, settings)
                end
                processedHidden = processedHidden + 1
            end
        end
    end

    Nameplates.discovery_index = idx
end

Nameplates.Unload = function()
    for _, frame in pairs(Nameplates.frames) do
        SafeShow(frame, false)
        pcall(function()
            if api.Interface ~= nil and api.Interface.Free ~= nil and frame ~= nil then
                api.Interface:Free(frame)
            end
        end)
    end
    for _, frame in pairs(Nameplates.debuff_frames) do
        SafeShow(frame, false)
        pcall(function()
            if api.Interface ~= nil and api.Interface.Free ~= nil and frame ~= nil then
                api.Interface:Free(frame)
            end
        end)
    end
    Nameplates.frames = {}
    Nameplates.debuff_frames = {}
    Nameplates.settings = nil
    Nameplates.target_unitframe = nil
    Nameplates.unit_keys = {}
    Nameplates.unit_state = {}
    Nameplates.tick = 0
    Nameplates.discovery_index = 1
end

return Nameplates
