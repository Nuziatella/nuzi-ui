local SettingsCommon = {}

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

function SettingsCommon.EnsureDailyAgeTables(s)
    if type(s) ~= "table" then
        return
    end
    if type(s.dailyage) ~= "table" then
        s.dailyage = {}
    end
    if s.dailyage.enabled == nil then
        s.dailyage.enabled = false
    end
    if type(s.dailyage.hidden) ~= "table" then
        s.dailyage.hidden = {}
    end
end

function SettingsCommon.EnsureCooldownTrackerTables(s, unitKeys)
    if type(s) ~= "table" then
        return
    end
    if type(s.cooldown_tracker) ~= "table" then
        s.cooldown_tracker = {}
    end
    if s.cooldown_tracker.enabled == nil then
        s.cooldown_tracker.enabled = false
    end
    if s.cooldown_tracker.update_interval_ms == nil then
        s.cooldown_tracker.update_interval_ms = 50
    end
    if type(s.cooldown_tracker.units) ~= "table" then
        s.cooldown_tracker.units = {}
    end
    for _, key in ipairs(unitKeys or {}) do
        if type(s.cooldown_tracker.units[key]) ~= "table" then
            s.cooldown_tracker.units[key] = {}
        end
        if type(s.cooldown_tracker.units[key].tracked_buffs) ~= "table" then
            s.cooldown_tracker.units[key].tracked_buffs = {}
        end
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
