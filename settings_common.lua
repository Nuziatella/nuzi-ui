local SettingsCommon = {}
local COOLDOWN_TRACKER_UNIT_DEFAULTS = {
    player = {
        enabled = false,
        pos_x = 330,
        pos_y = 100,
        icon_size = 40,
        icon_spacing = 5,
        max_icons = 10,
        lock_position = false,
        show_timer = true,
        timer_font_size = 16,
        timer_color = { 255, 255, 255, 255 },
        show_label = false,
        label_font_size = 14,
        label_color = { 255, 255, 255, 255 },
        display_mode = "both",
        display_style = "icons",
        bar_width = 180,
        bar_height = 14,
        bar_fill_color = { 207, 74, 22, 255 },
        bar_bg_color = { 18, 18, 18, 220 },
        tracked_buffs = {}
    },
    target = {
        enabled = false,
        pos_x = 0,
        pos_y = -8,
        icon_size = 40,
        icon_spacing = 5,
        max_icons = 10,
        lock_position = false,
        show_timer = true,
        timer_font_size = 16,
        timer_color = { 255, 255, 255, 255 },
        show_label = false,
        label_font_size = 14,
        label_color = { 255, 255, 255, 255 },
        display_mode = "both",
        display_style = "icons",
        bar_width = 180,
        bar_height = 14,
        bar_fill_color = { 207, 74, 22, 255 },
        bar_bg_color = { 18, 18, 18, 220 },
        cache_timeout_s = 300,
        tracked_buffs = {}
    },
    watchtarget = {
        enabled = false,
        pos_x = 0,
        pos_y = -8,
        icon_size = 40,
        icon_spacing = 5,
        max_icons = 10,
        lock_position = false,
        show_timer = true,
        timer_font_size = 16,
        timer_color = { 255, 255, 255, 255 },
        show_label = false,
        label_font_size = 14,
        label_color = { 255, 255, 255, 255 },
        display_mode = "both",
        display_style = "icons",
        bar_width = 180,
        bar_height = 14,
        bar_fill_color = { 207, 74, 22, 255 },
        bar_bg_color = { 18, 18, 18, 220 },
        tracked_buffs = {}
    },
    target_of_target = {
        enabled = false,
        pos_x = 0,
        pos_y = -8,
        icon_size = 40,
        icon_spacing = 5,
        max_icons = 10,
        lock_position = false,
        show_timer = true,
        timer_font_size = 16,
        timer_color = { 255, 255, 255, 255 },
        show_label = false,
        label_font_size = 14,
        label_color = { 255, 255, 255, 255 },
        display_mode = "both",
        display_style = "icons",
        bar_width = 180,
        bar_height = 14,
        bar_fill_color = { 207, 74, 22, 255 },
        bar_bg_color = { 18, 18, 18, 220 },
        tracked_buffs = {}
    }
}

local function DeepCopyTable(obj, visited)
    if type(obj) ~= "table" then
        return obj
    end
    visited = visited or {}
    if visited[obj] ~= nil then
        return visited[obj]
    end
    local out = {}
    visited[obj] = out
    for k, v in pairs(obj) do
        out[DeepCopyTable(k, visited)] = DeepCopyTable(v, visited)
    end
    return out
end

local function EnsureTableDefault(parent, key, defaultValue)
    if type(parent) ~= "table" then
        return
    end
    if type(defaultValue) == "table" then
        if type(parent[key]) ~= "table" then
            parent[key] = DeepCopyTable(defaultValue)
        else
            for childKey, childValue in pairs(defaultValue) do
                EnsureTableDefault(parent[key], childKey, childValue)
            end
        end
        return
    end
    if parent[key] == nil then
        parent[key] = defaultValue
    end
end

function SettingsCommon.ClampInt(v, min_v, max_v, fallback)
    local n = tonumber(v)
    if n == nil then
        return fallback
    end
    n = math.floor(n + 0.5)
    if n < min_v then
        return min_v
    end
    if n > max_v then
        return max_v
    end
    return n
end

function SettingsCommon.FormatBuffId(buff_id)
    if type(buff_id) == "number" then
        return string.format("%.0f", buff_id)
    end
    return tostring(buff_id)
end

function SettingsCommon.NormalizeCooldownTrackKind(rawKind)
    local kind = string.lower(tostring(rawKind or "any"))
    if kind == "buff" or kind == "debuff" then
        return kind
    end
    return "any"
end

function SettingsCommon.NormalizeCooldownDisplayMode(rawMode)
    local mode = string.lower(tostring(rawMode or "both"))
    if mode == "active" or mode == "missing" then
        return mode
    end
    return "both"
end

function SettingsCommon.NormalizeCooldownDisplayStyle(rawStyle)
    local style = string.lower(tostring(rawStyle or "icons"))
    if style == "bars" or style == "bar" then
        return "bars"
    end
    return "icons"
end

function SettingsCommon.NormalizeCooldownTrackedEntry(raw)
    local id = nil
    local kind = "any"
    local cooldownMs = nil

    if type(raw) == "table" then
        id = tonumber(raw.id or raw.buff_id or raw.buffId or raw.spellId or raw.spell_id)
        kind = SettingsCommon.NormalizeCooldownTrackKind(raw.kind)
        cooldownMs = tonumber(raw.cooldown_ms or raw.cooldownMs)
            or ((tonumber(raw.cooldown_s or raw.cooldown_seconds or raw.cooldown) or 0) * 1000)
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

    local entry = {
        id = id,
        kind = kind
    }
    if cooldownMs ~= nil and cooldownMs > 0 then
        entry.cooldown_ms = math.floor(cooldownMs + 0.5)
    end
    return entry
end

function SettingsCommon.EnsureCooldownTrackerTables(s, unitKeys)
    if type(s) ~= "table" then
        return
    end
    if type(s.cooldown_tracker) ~= "table" then
        s.cooldown_tracker = {}
    end
    EnsureTableDefault(s, "cooldown_tracker", {
        enabled = false,
        update_interval_ms = 50,
        migrated_from_cbt = false,
        anchor_layout_version = 2,
        units = {}
    })
    if type(s.cooldown_tracker.units) ~= "table" then
        s.cooldown_tracker.units = {}
    end
    for _, key in ipairs(unitKeys or {}) do
        local defaults = COOLDOWN_TRACKER_UNIT_DEFAULTS[key] or {
            enabled = false,
            pos_x = 330,
            pos_y = 100,
            icon_size = 40,
            icon_spacing = 5,
            max_icons = 10,
            lock_position = false,
            show_timer = true,
            timer_font_size = 16,
            timer_color = { 255, 255, 255, 255 },
            show_label = false,
            label_font_size = 14,
            label_color = { 255, 255, 255, 255 },
            display_mode = "both",
            display_style = "icons",
            bar_width = 180,
            bar_height = 14,
            bar_fill_color = { 207, 74, 22, 255 },
            bar_bg_color = { 18, 18, 18, 220 },
            tracked_buffs = {}
        }
        EnsureTableDefault(s.cooldown_tracker.units, key, defaults)
        if type(s.cooldown_tracker.units[key].tracked_buffs) ~= "table" then
            s.cooldown_tracker.units[key].tracked_buffs = {}
        end
        s.cooldown_tracker.units[key].display_mode = SettingsCommon.NormalizeCooldownDisplayMode(
            s.cooldown_tracker.units[key].display_mode
        )
        s.cooldown_tracker.units[key].display_style = SettingsCommon.NormalizeCooldownDisplayStyle(
            s.cooldown_tracker.units[key].display_style
        )
    end
end

function SettingsCommon.GetKeyFromIndex(keys, idx)
    idx = tonumber(idx) or 1
    if idx < 1 then
        idx = 1
    end
    if idx > #keys then
        idx = #keys
    end
    return keys[idx]
end

function SettingsCommon.GetIndexFromKey(keys, key)
    for i, k in ipairs(keys) do
        if k == key then
            return i
        end
    end
    return 1
end

function SettingsCommon.EnsureStyleFrames(settings)
    if type(settings) ~= "table" then
        return
    end
    if type(settings.style) ~= "table" then
        settings.style = {}
    end
    if type(settings.style.frames) ~= "table" then
        settings.style.frames = {}
    end
    if type(settings.style.frames.player) ~= "table" then
        settings.style.frames.player = {}
    end
    if type(settings.style.frames.target) ~= "table" then
        settings.style.frames.target = {}
    end
    if type(settings.style.frames.watchtarget) ~= "table" then
        settings.style.frames.watchtarget = {}
    end
    if type(settings.style.frames.target_of_target) ~= "table" then
        settings.style.frames.target_of_target = {}
    end
    if type(settings.style.frames.party) ~= "table" then
        settings.style.frames.party = {}
    end
end

function SettingsCommon.DeepCopySimple(obj, visited)
    visited = visited or {}
    if type(obj) ~= "table" then
        return obj
    end
    if visited[obj] ~= nil then
        return visited[obj]
    end
    local out = {}
    visited[obj] = out
    for k, v in pairs(obj) do
        out[SettingsCommon.DeepCopySimple(k, visited)] = SettingsCommon.DeepCopySimple(v, visited)
    end
    return out
end

function SettingsCommon.DeepEqualSimple(a, b, visited)
    if a == b then
        return true
    end
    if type(a) ~= type(b) then
        return false
    end
    if type(a) ~= "table" then
        return false
    end

    visited = visited or {}
    if visited[a] ~= nil and visited[a] == b then
        return true
    end
    visited[a] = b

    for k, v in pairs(a) do
        if not SettingsCommon.DeepEqualSimple(v, b[k], visited) then
            return false
        end
    end
    for k in pairs(b) do
        if a[k] == nil then
            return false
        end
    end
    return true
end

function SettingsCommon.PruneStyleFrameOverrides(settings, frameKeys)
    if type(settings) ~= "table" or type(settings.style) ~= "table" or type(settings.style.frames) ~= "table" then
        return false
    end

    local baseStyle = settings.style
    local frames = settings.style.frames
    local changed = false

    local function pruneFrame(frameStyle)
        if type(frameStyle) ~= "table" then
            return
        end
        for key, value in pairs(frameStyle) do
            if key ~= "frames" and key ~= "buff_windows" and key ~= "aura" then
                local baseValue = baseStyle[key]
                if baseValue ~= nil and SettingsCommon.DeepEqualSimple(value, baseValue) then
                    frameStyle[key] = nil
                    changed = true
                end
            end
        end
    end

    if type(frameKeys) == "table" then
        for _, frameKey in ipairs(frameKeys) do
            pruneFrame(frames[frameKey])
        end
    else
        for _, frameStyle in pairs(frames) do
            pruneFrame(frameStyle)
        end
    end

    return changed
end

function SettingsCommon.CopyTableInto(dst, src)
    if type(dst) ~= "table" or type(src) ~= "table" then
        return
    end
    for k in pairs(dst) do
        dst[k] = nil
    end
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = SettingsCommon.DeepCopySimple(v)
        else
            dst[k] = v
        end
    end
end

return SettingsCommon
