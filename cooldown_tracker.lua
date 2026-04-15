local api = require("api")
local SettingsStore = require("nuzi-ui/settings_store")
local SettingsCommon = require("nuzi-ui/settings_common")

local CooldownTracker = {
    settings = nil,
    enabled = true,
    accum_ms = 0,
    windows = {},
    buff_meta_cache = {},
    target_cache = {},
    target_cache_unit_id = nil
}

local UNIT_ORDER = {
    "player",
    "target",
    "playerpet",
    "watchtarget",
    "target_of_target"
}

local UNIT_LABELS = {
    player = "Player",
    target = "Target",
    playerpet = "Pet",
    watchtarget = "Watch",
    target_of_target = "ToT"
}

local UNIT_TOKENS = {
    player = { "player" },
    target = { "target" },
    playerpet = { "playerpet1", "playerpet" },
    watchtarget = { "watchtarget" },
    target_of_target = { "targetoftarget", "target_of_target", "targettarget" }
}

local ANCHORED_UNITS = {
    target = true,
    playerpet = true,
    watchtarget = true,
    target_of_target = true
}

local DEFAULT_POSITIONS = {
    player = { x = 330, y = 100 },
    target = { x = 0, y = -8 },
    playerpet = { x = 0, y = -8 },
    watchtarget = { x = 0, y = -8 },
    target_of_target = { x = 0, y = -8 }
}

local READY_TIMER_COLOR = { 144, 255, 172, 255 }
local MISSING_TIMER_COLOR = { 255, 196, 120, 255 }

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

local function getUiMsec()
    if api ~= nil and api.Time ~= nil and api.Time.GetUiMsec ~= nil then
        local ok, value = pcall(function()
            return api.Time:GetUiMsec()
        end)
        if ok and tonumber(value) ~= nil then
            return tonumber(value)
        end
    end
    return 0
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
    local number = tonumber(value)
    if number == nil then
        return 0
    end
    if number >= 0 then
        return math.floor(number + 0.5)
    end
    return math.ceil(number - 0.5)
end

local function normalizeColor01(raw, fallback)
    local source = type(raw) == "table" and raw or fallback or { 255, 255, 255, 255 }
    local output = {}
    for i = 1, 4 do
        local value = tonumber(source[i])
        if value == nil then
            value = 255
        elseif value > 1 then
            value = value / 255
        end
        if value < 0 then
            value = 0
        elseif value > 1 then
            value = 1
        end
        output[i] = value
    end
    return output
end

local function normalizeTrackKind(rawKind)
    if type(SettingsCommon) == "table" and type(SettingsCommon.NormalizeCooldownTrackKind) == "function" then
        return SettingsCommon.NormalizeCooldownTrackKind(rawKind)
    end
    local kind = string.lower(tostring(rawKind or "any"))
    if kind == "buff" or kind == "debuff" then
        return kind
    end
    return "any"
end

local function normalizeDisplayMode(rawMode)
    if type(SettingsCommon) == "table" and type(SettingsCommon.NormalizeCooldownDisplayMode) == "function" then
        return SettingsCommon.NormalizeCooldownDisplayMode(rawMode)
    end
    local mode = string.lower(tostring(rawMode or "both"))
    if mode == "active" or mode == "missing" then
        return mode
    end
    return "both"
end

local function normalizeTrackedEntry(raw)
    if type(SettingsCommon) == "table" and type(SettingsCommon.NormalizeCooldownTrackedEntry) == "function" then
        return SettingsCommon.NormalizeCooldownTrackedEntry(raw)
    end
    local id = nil
    local kind = "any"
    if type(raw) == "table" then
        id = tonumber(raw.id or raw.buff_id or raw.buffId or raw.spellId or raw.spell_id)
        kind = normalizeTrackKind(raw.kind)
    else
        id = tonumber(raw)
    end
    if id == nil then
        return nil
    end
    id = math.floor(id + 0.5)
    if id <= 0 then
        return nil
    end
    return {
        id = id,
        kind = kind
    }
end

local function isAnchoredUnit(unitKey)
    return ANCHORED_UNITS[unitKey] == true
end

local function getDefaultPosition(unitKey)
    local defaults = DEFAULT_POSITIONS[unitKey] or DEFAULT_POSITIONS.player
    return defaults.x, defaults.y
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
    local ok = pcall(function()
        window:AddAnchor("TOPLEFT", "UIParent", tonumber(x) or 0, tonumber(y) or 0)
    end)
    if ok then
        return true
    end
    ok = pcall(function()
        window:AddAnchor("TOPLEFT", "UIParent", "TOPLEFT", tonumber(x) or 0, tonumber(y) or 0)
    end)
    return ok and true or false
end

local function saveSettings(settings)
    if type(settings) ~= "table" then
        return
    end
    SettingsStore.SaveSettingsFile(settings)
end

local function applyCommonWindowBehavior(window)
    if window == nil then
        return
    end
    safeCall(function()
        window:SetCloseOnEscape(false)
    end)
    safeCall(function()
        window:EnableHidingIsRemove(false)
    end)
    safeCall(function()
        window:SetUILayer("game")
    end)
end

local function createWindow(id)
    if api.Interface == nil or api.Interface.CreateEmptyWindow == nil then
        return nil
    end
    local window = safeCall(function()
        return api.Interface:CreateEmptyWindow(id, "UIParent")
    end)
    applyCommonWindowBehavior(window)
    if window ~= nil and window.CreateColorDrawable ~= nil then
        local pad = safeCall(function()
            return window:CreateColorDrawable(0, 0, 0, 0, "background")
        end)
        if pad ~= nil then
            safeCall(function()
                pad:AddAnchor("TOPLEFT", window, 0, 0)
                pad:AddAnchor("BOTTOMRIGHT", window, 0, 0)
            end)
            window.__nuzi_drag_pad = pad
        end
    end
    return window
end

local function createLabel(parent, id, fontSize, align)
    if parent == nil then
        return nil
    end
    local label = nil
    if parent.CreateChildWidget ~= nil then
        label = safeCall(function()
            return parent:CreateChildWidget("label", id, 0, true)
        end)
    end
    if label == nil and api.Interface ~= nil and api.Interface.CreateWidget ~= nil then
        label = safeCall(function()
            return api.Interface:CreateWidget("label", id, parent)
        end)
    end
    if label ~= nil then
        safeCall(function()
            label:SetExtent(64, 18)
            if label.style ~= nil then
                label.style:SetFontSize(fontSize or 12)
                if align ~= nil then
                    label.style:SetAlign(align)
                elseif ALIGN ~= nil and ALIGN.CENTER ~= nil then
                    label.style:SetAlign(ALIGN.CENTER)
                end
                label.style:SetShadow(true)
            end
        end)
    end
    return label
end

local function setLabelText(label, value)
    if label == nil or label.SetText == nil then
        return
    end
    local text = tostring(value or "")
    if label.__nuzi_text ~= text then
        label.__nuzi_text = text
        label:SetText(text)
    end
end

local function setLabelColor(label, rgba)
    if label == nil or label.style == nil then
        return
    end
    local color = normalizeColor01(rgba)
    local sig = string.format("%.3f:%.3f:%.3f:%.3f", color[1], color[2], color[3], color[4])
    if label.__nuzi_color_sig ~= sig then
        label.__nuzi_color_sig = sig
        safeCall(function()
            label.style:SetColor(color[1], color[2], color[3], color[4])
        end)
    end
end

local function setLabelFontSize(label, value)
    if label == nil or label.style == nil then
        return
    end
    local size = clampInt(value, 8, 48, 12)
    if label.__nuzi_font_size ~= size then
        label.__nuzi_font_size = size
        safeCall(function()
            label.style:SetFontSize(size)
        end)
    end
end

local function showWidget(widget, visible)
    if widget == nil or widget.Show == nil then
        return
    end
    local want = visible and true or false
    if widget.__nuzi_visible ~= want then
        widget.__nuzi_visible = want
        widget:Show(want)
    end
end

local function setWidgetAlpha(widget, alpha)
    if widget == nil or widget.SetAlpha == nil then
        return
    end
    local value = tonumber(alpha) or 1
    if value < 0 then
        value = 0
    elseif value > 1 then
        value = 1
    end
    if widget.__nuzi_alpha ~= value then
        widget.__nuzi_alpha = value
        safeCall(function()
            widget:SetAlpha(value)
        end)
    end
end

local function createIconSlot(id, parent)
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

    if icon.back ~= nil and F_SLOT ~= nil and F_SLOT.ApplySlotSkin ~= nil and SLOT_STYLE ~= nil then
        local style = SLOT_STYLE.BUFF or SLOT_STYLE.DEFAULT or SLOT_STYLE.ITEM
        if style ~= nil then
            safeCall(function()
                F_SLOT.ApplySlotSkin(icon, icon.back, style)
            end)
        end
    end

    local timerLabel = createLabel(icon, id .. "Timer", 16, (ALIGN ~= nil and ALIGN.CENTER) or nil)
    local stackLabel = createLabel(icon, id .. "Stack", 12, (ALIGN ~= nil and ALIGN.RIGHT) or nil)
    local nameLabel = createLabel(parent, id .. "Name", 12, (ALIGN ~= nil and ALIGN.CENTER) or nil)

    if timerLabel ~= nil then
        safeCall(function()
            timerLabel:AddAnchor("CENTER", icon, 0, 0)
        end)
    end
    if stackLabel ~= nil then
        safeCall(function()
            stackLabel:AddAnchor("BOTTOMRIGHT", icon, -1, -1)
        end)
    end

    return {
        icon = icon,
        timer = timerLabel,
        stack = stackLabel,
        name = nameLabel
    }
end

local function setIconPath(slot, path)
    if slot == nil or slot.icon == nil then
        return
    end
    local nextPath = type(path) == "string" and path or ""
    if slot.icon.__nuzi_icon_path == nextPath then
        return
    end
    slot.icon.__nuzi_icon_path = nextPath
    if nextPath == "" then
        safeCall(function()
            if slot.icon.SetTexture ~= nil then
                slot.icon:SetTexture("")
            end
        end)
        safeCall(function()
            if slot.icon.back ~= nil and slot.icon.back.SetTexture ~= nil then
                slot.icon.back:SetTexture("")
            end
        end)
        return
    end
    if F_SLOT ~= nil and F_SLOT.SetIconBackGround ~= nil then
        safeCall(function()
            F_SLOT.SetIconBackGround(slot.icon, nextPath)
        end)
    elseif slot.icon.SetTexture ~= nil then
        safeCall(function()
            slot.icon:SetTexture(nextPath)
        end)
    end
end

local function safeGetUnitId(unit)
    if api == nil or api.Unit == nil or api.Unit.GetUnitId == nil then
        return nil
    end
    local ok, value = pcall(function()
        return api.Unit:GetUnitId(unit)
    end)
    if ok and value ~= nil and tostring(value) ~= "" then
        return tostring(value)
    end
    return nil
end

local function resolveUnitToken(unitKey)
    for _, token in ipairs(UNIT_TOKENS[unitKey] or {}) do
        if safeGetUnitId(token) ~= nil then
            return token
        end
    end
    return (UNIT_TOKENS[unitKey] or {})[1]
end

local function resolveUnitScreenAnchor(unitKey)
    local unitToken = resolveUnitToken(unitKey)
    if unitToken == nil or api == nil or api.Unit == nil then
        return nil, nil
    end

    local offsetX = nil
    local offsetY = nil
    local offsetZ = nil

    if api.Unit.GetUnitScreenNameTagOffset ~= nil then
        pcall(function()
            offsetX, offsetY, offsetZ = api.Unit:GetUnitScreenNameTagOffset(unitToken)
        end)
    end

    if offsetX == nil or offsetY == nil or offsetZ == nil then
        pcall(function()
            offsetX, offsetY, offsetZ = api.Unit:GetUnitScreenPosition(unitToken)
        end)
    end

    if offsetX == nil or offsetY == nil or offsetZ == nil or tonumber(offsetZ) == nil or tonumber(offsetZ) < 0 then
        return nil, nil
    end

    return roundPixel(offsetX), roundPixel(offsetY)
end

local function computeAnchoredTopLeft(unitKey, windowWidth, windowHeight)
    local anchorX, anchorY = resolveUnitScreenAnchor(unitKey)
    if anchorX == nil or anchorY == nil then
        return nil, nil
    end

    local baseX = anchorX - roundPixel((tonumber(windowWidth) or 0) / 2)
    local baseY = anchorY - roundPixel(tonumber(windowHeight) or 0)
    return baseX, baseY
end

local function safeUnitBuffCount(unit)
    if api == nil or api.Unit == nil or api.Unit.UnitBuffCount == nil then
        return 0
    end
    local ok, value = pcall(function()
        return api.Unit:UnitBuffCount(unit)
    end)
    if ok then
        return tonumber(value) or 0
    end
    return 0
end

local function safeUnitDeBuffCount(unit)
    if api == nil or api.Unit == nil or api.Unit.UnitDeBuffCount == nil then
        return 0
    end
    local ok, value = pcall(function()
        return api.Unit:UnitDeBuffCount(unit)
    end)
    if ok then
        return tonumber(value) or 0
    end
    return 0
end

local function safeUnitBuff(unit, index)
    if api == nil or api.Unit == nil or api.Unit.UnitBuff == nil then
        return nil
    end
    local ok, value = pcall(function()
        return api.Unit:UnitBuff(unit, index)
    end)
    if ok and type(value) == "table" then
        return value
    end
    return nil
end

local function safeUnitDeBuff(unit, index)
    if api == nil or api.Unit == nil or api.Unit.UnitDeBuff == nil then
        return nil
    end
    local ok, value = pcall(function()
        return api.Unit:UnitDeBuff(unit, index)
    end)
    if ok and type(value) == "table" then
        return value
    end
    return nil
end

local function safeGetAuraId(aura)
    if type(aura) ~= "table" then
        return nil
    end
    for _, key in ipairs({
        "buff_id",
        "buffId",
        "id",
        "spellId",
        "spell_id",
        "abilityId",
        "ability_id"
    }) do
        local value = tonumber(aura[key])
        if value ~= nil then
            return math.floor(value + 0.5)
        end
    end
    return nil
end

local function safeGetAuraTimeLeftMs(aura)
    if type(aura) ~= "table" then
        return nil
    end
    return normalizeMs(aura.timeLeft or aura.leftTime or aura.remainTime)
end

local function safeGetAuraStacks(aura)
    if type(aura) ~= "table" then
        return nil
    end
    for _, key in ipairs({
        "stack",
        "stacks",
        "stackCount",
        "stack_count",
        "count",
        "buffCount"
    }) do
        local value = tonumber(aura[key])
        if value ~= nil then
            return math.floor(value + 0.5)
        end
    end
    return nil
end

local function getTooltipInfo(buffId)
    local id = tonumber(buffId)
    if id == nil then
        return nil
    end
    if CooldownTracker.buff_meta_cache[id] ~= nil then
        return CooldownTracker.buff_meta_cache[id] ~= false and CooldownTracker.buff_meta_cache[id] or nil
    end
    if api == nil or api.Ability == nil or api.Ability.GetBuffTooltip == nil then
        CooldownTracker.buff_meta_cache[id] = false
        return nil
    end
    local tooltip = safeCall(function()
        return api.Ability:GetBuffTooltip(id, 1)
    end)
    if type(tooltip) ~= "table" then
        CooldownTracker.buff_meta_cache[id] = false
        return nil
    end
    local meta = {
        name = tostring(tooltip.name or tooltip.buffName or tooltip.title or ("Buff #" .. tostring(id))),
        path = tostring(tooltip.path or tooltip.iconPath or tooltip.icon_path or tooltip.texture or "")
    }
    CooldownTracker.buff_meta_cache[id] = meta
    return meta
end

local function resolveAuraName(aura, buffId)
    if type(aura) == "table" then
        for _, key in ipairs({ "name", "buffName", "debuffName", "title", "tooltip" }) do
            local value = aura[key]
            if type(value) == "string" and value ~= "" then
                return value
            end
        end
    end
    local meta = getTooltipInfo(buffId)
    if type(meta) == "table" and type(meta.name) == "string" and meta.name ~= "" then
        return meta.name
    end
    return "Buff #" .. tostring(buffId or "")
end

local function resolveAuraIconPath(aura, buffId)
    if type(aura) == "table" then
        for _, key in ipairs({ "path", "iconPath", "icon_path", "texture" }) do
            local value = aura[key]
            if type(value) == "string" and value ~= "" then
                return value
            end
        end
    end
    local meta = getTooltipInfo(buffId)
    if type(meta) == "table" and type(meta.path) == "string" and meta.path ~= "" then
        return meta.path
    end
    return nil
end

local function buildTrackedEntries(unitCfg)
    local seen = {}
    local entries = {}
    if type(unitCfg) ~= "table" or type(unitCfg.tracked_buffs) ~= "table" then
        return entries
    end
    for _, raw in ipairs(unitCfg.tracked_buffs) do
        local entry = normalizeTrackedEntry(raw)
        if entry ~= nil then
            entry.key = string.format("%s:%d", entry.kind, entry.id)
            if not seen[entry.key] then
                seen[entry.key] = true
                entries[#entries + 1] = entry
            end
        end
    end
    return entries
end

local function buildTrackedKindSets(trackedEntries)
    local buffIds = {}
    local debuffIds = {}
    for _, entry in ipairs(trackedEntries or {}) do
        if entry.kind == "any" or entry.kind == "buff" then
            buffIds[entry.id] = true
        end
        if entry.kind == "any" or entry.kind == "debuff" then
            debuffIds[entry.id] = true
        end
    end
    return buffIds, debuffIds
end

local function scanTrackedEffects(unitToken, trackedEntries)
    local found = {
        buff = {},
        debuff = {}
    }
    if unitToken == nil then
        return found
    end

    local trackedBuffIds, trackedDebuffIds = buildTrackedKindSets(trackedEntries)

    local function push(aura, kind)
        local buffId = safeGetAuraId(aura)
        if buffId == nil then
            return
        end
        if kind == "buff" then
            if not trackedBuffIds[buffId] then
                return
            end
        elseif not trackedDebuffIds[buffId] then
            return
        end
        local timeLeftMs = safeGetAuraTimeLeftMs(aura)
        local bucket = found[kind]
        local existing = bucket[buffId]
        if existing ~= nil and tonumber(existing.time_left_ms) ~= nil and tonumber(timeLeftMs) ~= nil then
            if tonumber(existing.time_left_ms) >= tonumber(timeLeftMs) then
                return
            end
        elseif existing ~= nil then
            return
        end
        bucket[buffId] = {
            buff_id = buffId,
            kind = kind,
            name = resolveAuraName(aura, buffId),
            icon_path = resolveAuraIconPath(aura, buffId),
            time_left_ms = timeLeftMs,
            stacks = safeGetAuraStacks(aura)
        }
    end

    local buffCount = safeUnitBuffCount(unitToken)
    for index = 1, buffCount do
        push(safeUnitBuff(unitToken, index), "buff")
    end
    local debuffCount = safeUnitDeBuffCount(unitToken)
    for index = 1, debuffCount do
        push(safeUnitDeBuff(unitToken, index), "debuff")
    end

    return found
end

local function resolveLiveEntry(found, trackedEntry)
    if type(found) ~= "table" or type(trackedEntry) ~= "table" then
        return nil
    end

    if trackedEntry.kind == "buff" then
        return found.buff ~= nil and found.buff[trackedEntry.id] or nil
    elseif trackedEntry.kind == "debuff" then
        return found.debuff ~= nil and found.debuff[trackedEntry.id] or nil
    end

    local buffEntry = found.buff ~= nil and found.buff[trackedEntry.id] or nil
    local debuffEntry = found.debuff ~= nil and found.debuff[trackedEntry.id] or nil
    if buffEntry ~= nil and debuffEntry ~= nil then
        local buffTime = tonumber(buffEntry.time_left_ms) or -1
        local debuffTime = tonumber(debuffEntry.time_left_ms) or -1
        if buffTime >= debuffTime then
            return buffEntry
        end
        return debuffEntry
    end
    return buffEntry or debuffEntry
end

local function clearTargetCache()
    CooldownTracker.target_cache = {}
    CooldownTracker.target_cache_unit_id = nil
end

local function updateTargetCache(currentUnitId, liveFound, trackedEntries, unitCfg, nowMs)
    local cacheTimeoutMs = math.max(0, (tonumber(unitCfg.cache_timeout_s) or 300) * 1000)
    if currentUnitId ~= nil and CooldownTracker.target_cache_unit_id ~= nil and currentUnitId ~= CooldownTracker.target_cache_unit_id then
        clearTargetCache()
    end
    if currentUnitId ~= nil then
        CooldownTracker.target_cache_unit_id = currentUnitId
    end

    for _, trackedEntry in ipairs(trackedEntries or {}) do
        local live = resolveLiveEntry(liveFound, trackedEntry)
        if live ~= nil then
            local ttl = tonumber(live.time_left_ms) or 0
            CooldownTracker.target_cache[trackedEntry.key] = {
                buff_id = trackedEntry.id,
                track_kind = trackedEntry.kind,
                kind = live.kind,
                name = live.name,
                icon_path = live.icon_path,
                stacks = live.stacks,
                expire_at_ms = ttl > 0 and (nowMs + ttl) or nil,
                cache_expire_at_ms = nowMs + cacheTimeoutMs
            }
        end
    end

    local out = {}
    for _, trackedEntry in ipairs(trackedEntries or {}) do
        local live = resolveLiveEntry(liveFound, trackedEntry)
        if live ~= nil then
            out[trackedEntry.key] = live
        else
            local cached = CooldownTracker.target_cache[trackedEntry.key]
            if type(cached) == "table" then
                local cacheAlive = tonumber(cached.cache_expire_at_ms) ~= nil and nowMs <= tonumber(cached.cache_expire_at_ms)
                local timeLeftMs = tonumber(cached.expire_at_ms) ~= nil and math.max(0, tonumber(cached.expire_at_ms) - nowMs) or nil
                if cacheAlive and (timeLeftMs == nil or timeLeftMs > 0) then
                    out[trackedEntry.key] = {
                        buff_id = trackedEntry.id,
                        track_kind = trackedEntry.kind,
                        kind = cached.kind,
                        name = cached.name,
                        icon_path = cached.icon_path,
                        stacks = cached.stacks,
                        time_left_ms = timeLeftMs
                    }
                else
                    CooldownTracker.target_cache[trackedEntry.key] = nil
                end
            end
        end
    end
    return out
end

local function buildActiveEntryMap(trackedEntries, liveFound)
    local out = {}
    for _, trackedEntry in ipairs(trackedEntries or {}) do
        local live = resolveLiveEntry(liveFound, trackedEntry)
        if live ~= nil then
            out[trackedEntry.key] = live
        end
    end
    return out
end

local function buildMissingEntry(unitKey, trackedEntry)
    local meta = getTooltipInfo(trackedEntry.id)
    local missingState = (unitKey == "player") and "ready" or "missing"
    return {
        buff_id = trackedEntry.id,
        track_kind = trackedEntry.kind,
        kind = trackedEntry.kind,
        name = (type(meta) == "table" and tostring(meta.name or "") ~= "") and tostring(meta.name or "") or ("Buff #" .. tostring(trackedEntry.id)),
        icon_path = type(meta) == "table" and tostring(meta.path or "") or nil,
        time_left_ms = nil,
        stacks = nil,
        state = missingState
    }
end

local function collectUnitEntries(unitKey, unitCfg, nowMs)
    local trackedEntries = buildTrackedEntries(unitCfg)
    if #trackedEntries == 0 then
        if unitKey == "target" then
            clearTargetCache()
        end
        return {}
    end

    local unitToken = resolveUnitToken(unitKey)
    local unitId = unitToken ~= nil and safeGetUnitId(unitToken) or nil
    local liveFound = scanTrackedEffects(unitToken, trackedEntries)
    local activeByKey = nil

    if unitKey == "target" then
        activeByKey = updateTargetCache(unitId, liveFound, trackedEntries, unitCfg, nowMs)
    else
        activeByKey = buildActiveEntryMap(trackedEntries, liveFound)
    end

    local displayMode = normalizeDisplayMode(type(unitCfg) == "table" and unitCfg.display_mode or "both")
    local entries = {}
    for _, trackedEntry in ipairs(trackedEntries) do
        local entry = type(activeByKey) == "table" and activeByKey[trackedEntry.key] or nil
        if entry ~= nil then
            if displayMode ~= "missing" then
                entry.track_kind = trackedEntry.kind
                entry.state = "active"
                entries[#entries + 1] = entry
            end
        elseif displayMode ~= "active" then
            entries[#entries + 1] = buildMissingEntry(unitKey, trackedEntry)
        end
    end
    return entries
end

local function formatTimeLeftMs(timeLeftMs)
    local value = tonumber(timeLeftMs)
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
    local minutes = math.floor(total / 60)
    local remain = total % 60
    return string.format("%d:%02d", minutes, remain)
end

local function applyWindowPosition(window, unitKey, unitCfg, windowWidth, windowHeight)
    if window == nil or type(unitCfg) ~= "table" then
        return true
    end
    if window.__nuzi_dragging then
        return true
    end

    local defaultX, defaultY = getDefaultPosition(unitKey)
    local x = clampInt(unitCfg.pos_x, -5000, 5000, defaultX)
    local y = clampInt(unitCfg.pos_y, -5000, 5000, defaultY)

    if isAnchoredUnit(unitKey) then
        local baseX, baseY = computeAnchoredTopLeft(unitKey, windowWidth, windowHeight)
        if baseX == nil or baseY == nil then
            return false
        end
        window.__nuzi_anchor_base_x = baseX
        window.__nuzi_anchor_base_y = baseY
        x = baseX + x
        y = baseY + y
    else
        window.__nuzi_anchor_base_x = nil
        window.__nuzi_anchor_base_y = nil
    end

    if window.__nuzi_pos_x ~= x or window.__nuzi_pos_y ~= y then
        safeCall(function()
            if window.RemoveAllAnchors ~= nil then
                window:RemoveAllAnchors()
            end
            anchorTopLeft(window, x, y)
        end)
        window.__nuzi_pos_x = x
        window.__nuzi_pos_y = y
    end
    return true
end

local function attachDragTarget(window, target, unitKey)
    if window == nil or target == nil then
        return
    end

    local function onDragStart()
        if CooldownTracker.settings == nil or type(CooldownTracker.settings.cooldown_tracker) ~= "table" then
            return
        end
        local units = CooldownTracker.settings.cooldown_tracker.units
        local unitCfg = type(units) == "table" and units[unitKey] or nil
        if type(unitCfg) == "table" and unitCfg.lock_position then
            return
        end
        if type(CooldownTracker.settings) == "table" and CooldownTracker.settings.drag_requires_shift ~= false and not isShiftDown() then
            return
        end
        window.__nuzi_dragging = true
        if type(window.StartMoving) == "function" then
            window:StartMoving()
        end
    end

    local function onDragStop()
        if type(window.StopMovingOrSizing) == "function" then
            window:StopMovingOrSizing()
        end
        window.__nuzi_dragging = false
        local x, y = readWindowOffset(window)
        if x == nil or y == nil then
            return
        end
        safeCall(function()
            if window.RemoveAllAnchors ~= nil then
                window:RemoveAllAnchors()
            end
            anchorTopLeft(window, x, y)
        end)
        if CooldownTracker.settings ~= nil and type(CooldownTracker.settings.cooldown_tracker) == "table" then
            local units = CooldownTracker.settings.cooldown_tracker.units
            if type(units) == "table" and type(units[unitKey]) == "table" then
                if isAnchoredUnit(unitKey) then
                    local defaultX, defaultY = getDefaultPosition(unitKey)
                    local baseX, baseY = computeAnchoredTopLeft(
                        unitKey,
                        tonumber(window.__nuzi_width) or 0,
                        tonumber(window.__nuzi_height) or 0
                    )
                    if baseX ~= nil and baseY ~= nil then
                        units[unitKey].pos_x = clampInt(x - baseX, -5000, 5000, defaultX)
                        units[unitKey].pos_y = clampInt(y - baseY, -5000, 5000, defaultY)
                    end
                else
                    units[unitKey].pos_x = x
                    units[unitKey].pos_y = y
                end
                saveSettings(CooldownTracker.settings)
            end
        end
        window.__nuzi_pos_x = x
        window.__nuzi_pos_y = y
    end

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
        target:SetHandler("OnMouseDown", function(_, btn)
            if btn == nil or btn == "LeftButton" then
                onDragStart()
            end
        end)
        target:SetHandler("OnMouseUp", function(_, btn)
            if btn == nil or btn == "LeftButton" then
                onDragStop()
            end
        end)
    end
end

local function ensureUnitWindow(unitKey)
    local state = CooldownTracker.windows[unitKey]
    if type(state) == "table" and state.window ~= nil then
        return state
    end

    local window = createWindow("NuziUiCooldownTracker_" .. tostring(unitKey))
    if window == nil then
        return nil
    end

    state = {
        window = window,
        slots = {},
        placeholder = createLabel(window, "NuziUiCooldownTrackerPlaceholder_" .. tostring(unitKey), 12, (ALIGN ~= nil and ALIGN.CENTER) or nil)
    }
    CooldownTracker.windows[unitKey] = state

    if state.placeholder ~= nil then
        safeCall(function()
            state.placeholder:AddAnchor("CENTER", window, 0, 0)
        end)
    end

    attachDragTarget(window, window, unitKey)
    if window.__nuzi_drag_pad ~= nil then
        attachDragTarget(window, window.__nuzi_drag_pad, unitKey)
    end

    showWidget(window, false)
    return state
end

local function ensureSlot(state, unitKey, index)
    if type(state) ~= "table" then
        return nil
    end
    if state.slots[index] ~= nil then
        return state.slots[index]
    end
    local slot = createIconSlot("NuziUiCooldownTracker_" .. tostring(unitKey) .. "_" .. tostring(index), state.window)
    if slot == nil then
        return nil
    end
    state.slots[index] = slot
    attachDragTarget(state.window, slot.icon, unitKey)
    if slot.name ~= nil then
        attachDragTarget(state.window, slot.name, unitKey)
    end
    return slot
end

local function trimLabel(text, limit)
    local value = tostring(text or "")
    local maxChars = tonumber(limit) or 12
    if string.len(value) <= maxChars then
        return value
    end
    if maxChars <= 3 then
        return string.sub(value, 1, maxChars)
    end
    return string.sub(value, 1, maxChars - 3) .. "..."
end

local function updateWindow(unitKey, unitCfg, entries)
    local state = ensureUnitWindow(unitKey)
    if state == nil or type(unitCfg) ~= "table" then
        return
    end

    local count = math.min(#entries, clampInt(unitCfg.max_icons, 1, 16, 10))
    local iconSize = clampInt(unitCfg.icon_size, 12, 80, 40)
    local spacing = clampInt(unitCfg.icon_spacing, 0, 24, 5)
    local showTimer = unitCfg.show_timer ~= false
    local showLabel = unitCfg.show_label and true or false
    local timerColor = normalizeColor01(unitCfg.timer_color)
    local labelColor = normalizeColor01(unitCfg.label_color)
    local timerFontSize = clampInt(unitCfg.timer_font_size, 8, 40, 16)
    local labelFontSize = clampInt(unitCfg.label_font_size, 8, 32, 14)
    local labelHeight = showLabel and (labelFontSize + 8) or 0
    local windowWidth = math.max(iconSize, (count > 0 and ((count * iconSize) + ((count - 1) * spacing)) or iconSize))
    local windowHeight = iconSize + labelHeight

    safeCall(function()
        if state.window.SetExtent ~= nil then
            state.window:SetExtent(windowWidth, windowHeight)
        end
    end)
    state.window.__nuzi_width = windowWidth
    state.window.__nuzi_height = windowHeight

    if count == 0 then
        setLabelText(state.placeholder, tostring(UNIT_LABELS[unitKey] or unitKey))
        setLabelFontSize(state.placeholder, 12)
        setLabelColor(state.placeholder, { 200, 200, 200, 255 })
        showWidget(state.placeholder, false)
        for _, slot in ipairs(state.slots) do
            showWidget(slot.icon, false)
            showWidget(slot.timer, false)
            showWidget(slot.stack, false)
            showWidget(slot.name, false)
        end
        showWidget(state.window, false)
        return
    end

    if not applyWindowPosition(state.window, unitKey, unitCfg, windowWidth, windowHeight) then
        for _, slot in ipairs(state.slots) do
            showWidget(slot.icon, false)
            showWidget(slot.timer, false)
            showWidget(slot.stack, false)
            showWidget(slot.name, false)
        end
        showWidget(state.window, false)
        return
    end

    showWidget(state.placeholder, false)
    showWidget(state.window, true)

    for index = 1, count do
        local entry = entries[index]
        local slot = ensureSlot(state, unitKey, index)
        if slot ~= nil and entry ~= nil then
            local x = (index - 1) * (iconSize + spacing)
            safeCall(function()
                if slot.icon.SetExtent ~= nil then
                    slot.icon:SetExtent(iconSize, iconSize)
                end
                if slot.icon.RemoveAllAnchors ~= nil then
                    slot.icon:RemoveAllAnchors()
                end
                slot.icon:AddAnchor("TOPLEFT", state.window, x, 0)
            end)
            if slot.name ~= nil then
                safeCall(function()
                    slot.name:SetExtent(iconSize + 20, labelHeight)
                    if slot.name.RemoveAllAnchors ~= nil then
                        slot.name:RemoveAllAnchors()
                    end
                    slot.name:AddAnchor("TOPLEFT", state.window, x - 10, iconSize + 2)
                end)
            end
            setIconPath(slot, entry.icon_path)
            showWidget(slot.icon, true)
            if entry.state == "ready" or entry.state == "missing" then
                setWidgetAlpha(slot.icon, 0.5)
            else
                setWidgetAlpha(slot.icon, 1)
            end

            if slot.timer ~= nil then
                setLabelFontSize(slot.timer, timerFontSize)
                if entry.state == "ready" then
                    setLabelColor(slot.timer, READY_TIMER_COLOR)
                    setLabelText(slot.timer, showTimer and "Ready" or "")
                    showWidget(slot.timer, showTimer)
                elseif entry.state == "missing" then
                    setLabelColor(slot.timer, MISSING_TIMER_COLOR)
                    setLabelText(slot.timer, showTimer and "Missing" or "")
                    showWidget(slot.timer, showTimer)
                else
                    setLabelColor(slot.timer, timerColor)
                    setLabelText(slot.timer, showTimer and formatTimeLeftMs(entry.time_left_ms) or "")
                    showWidget(slot.timer, showTimer and entry.time_left_ms ~= nil)
                end
            end

            if slot.stack ~= nil then
                setLabelFontSize(slot.stack, math.max(10, math.floor(timerFontSize * 0.75)))
                setLabelColor(slot.stack, { 255, 255, 255, 255 })
                local stacks = tonumber(entry.stacks)
                local showStacks = entry.state == "active" and stacks ~= nil and stacks > 1
                setLabelText(slot.stack, showStacks and tostring(stacks) or "")
                showWidget(slot.stack, showStacks)
            end

            if slot.name ~= nil then
                setLabelFontSize(slot.name, labelFontSize)
                setLabelColor(slot.name, labelColor)
                setLabelText(slot.name, showLabel and trimLabel(entry.name, math.max(8, math.floor((iconSize + 20) / 5))) or "")
                showWidget(slot.name, showLabel)
            end
        end
    end

    for index = count + 1, #state.slots do
        local slot = state.slots[index]
        if slot ~= nil then
            showWidget(slot.icon, false)
            showWidget(slot.timer, false)
            showWidget(slot.stack, false)
            showWidget(slot.name, false)
        end
    end
end

local function hideAllWindows()
    for _, state in pairs(CooldownTracker.windows) do
        if type(state) == "table" then
            showWidget(state.window, false)
            if type(state.slots) == "table" then
                for _, slot in ipairs(state.slots) do
                    showWidget(slot.icon, false)
                    showWidget(slot.timer, false)
                    showWidget(slot.stack, false)
                    showWidget(slot.name, false)
                end
            end
        end
    end
end

local function updateAllUnits(nowMs)
    if type(CooldownTracker.settings) ~= "table" then
        hideAllWindows()
        return
    end
    local root = CooldownTracker.settings.cooldown_tracker
    if type(root) ~= "table" or not CooldownTracker.enabled or root.enabled ~= true then
        hideAllWindows()
        clearTargetCache()
        return
    end

    local units = type(root.units) == "table" and root.units or {}
    for _, unitKey in ipairs(UNIT_ORDER) do
        local unitCfg = units[unitKey]
        if type(unitCfg) ~= "table" or unitCfg.enabled ~= true then
            local state = CooldownTracker.windows[unitKey]
            if state ~= nil then
                showWidget(state.window, false)
            end
            if unitKey == "target" then
                clearTargetCache()
            end
        else
            local entries = collectUnitEntries(unitKey, unitCfg, nowMs)
            updateWindow(unitKey, unitCfg, entries)
        end
    end
end

function CooldownTracker.Init(settings)
    CooldownTracker.settings = settings
    CooldownTracker.accum_ms = 0
    clearTargetCache()
    hideAllWindows()
end

function CooldownTracker.ApplySettings(settings)
    CooldownTracker.settings = settings
    if type(settings) ~= "table" or type(settings.cooldown_tracker) ~= "table" then
        hideAllWindows()
        return
    end

    local units = type(settings.cooldown_tracker.units) == "table" and settings.cooldown_tracker.units or {}
    for _, unitKey in ipairs(UNIT_ORDER) do
        local unitCfg = units[unitKey]
        if type(unitCfg) == "table" then
            local state = ensureUnitWindow(unitKey)
            if state ~= nil then
                applyWindowPosition(
                    state.window,
                    unitKey,
                    unitCfg,
                    tonumber(state.window.__nuzi_width) or 0,
                    tonumber(state.window.__nuzi_height) or 0
                )
            end
        end
    end
end

function CooldownTracker.SetEnabled(enabled)
    CooldownTracker.enabled = enabled and true or false
    if not CooldownTracker.enabled then
        hideAllWindows()
    end
end

function CooldownTracker.OnUpdate(dt, settings)
    if type(settings) == "table" then
        CooldownTracker.settings = settings
    end
    if type(CooldownTracker.settings) ~= "table" then
        return
    end

    local trackerSettings = CooldownTracker.settings.cooldown_tracker
    if type(trackerSettings) ~= "table" then
        hideAllWindows()
        return
    end

    CooldownTracker.accum_ms = (tonumber(CooldownTracker.accum_ms) or 0) + (tonumber(dt) or 0)
    local interval = clampInt(trackerSettings.update_interval_ms, 10, 500, 50)
    if CooldownTracker.accum_ms < interval then
        return
    end
    CooldownTracker.accum_ms = CooldownTracker.accum_ms - interval
    if CooldownTracker.accum_ms < 0 then
        CooldownTracker.accum_ms = 0
    end
    updateAllUnits(getUiMsec())
end

function CooldownTracker.Unload()
    clearTargetCache()
    for _, state in pairs(CooldownTracker.windows) do
        if type(state) == "table" then
            showWidget(state.window, false)
            safeCall(function()
                if state.window ~= nil and state.window.Destroy ~= nil then
                    state.window:Destroy()
                elseif state.window ~= nil and api.Interface ~= nil and api.Interface.Free ~= nil then
                    api.Interface:Free(state.window)
                end
            end)
        end
    end
    CooldownTracker.windows = {}
    CooldownTracker.buff_meta_cache = {}
    CooldownTracker.settings = nil
    CooldownTracker.accum_ms = 0
end

return CooldownTracker
