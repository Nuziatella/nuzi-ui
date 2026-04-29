local api = require("api")
local SettingsCommon = require("nuzi-ui/settings_common")

local SettingsCooldown = {}

SettingsCooldown.UNIT_KEYS = {
    "player",
    "target",
    "playerpet",
    "watchtarget",
    "target_of_target"
}

SettingsCooldown.UNIT_LABELS = {
    "Player",
    "Target",
    "Mount/Pet",
    "Watchtarget",
    "Target of Target"
}

SettingsCooldown.DISPLAY_MODE_LABELS = {
    "Active only",
    "Missing only",
    "Both"
}

SettingsCooldown.DISPLAY_STYLE_LABELS = {
    "Icon row",
    "Icon + bars"
}

local DISPLAY_STYLE_KEYS = {
    "icons",
    "bars"
}

SettingsCooldown.TRACK_KIND_LABELS = {
    "Any",
    "Buff",
    "Debuff"
}

SettingsCooldown.BUFFS_PER_PAGE = 6
SettingsCooldown.SCAN_ROWS = 10
SettingsCooldown.SEARCH_ROWS = 8

local SEARCH_BATCH = 1000
local SEARCH_MAX_ID = 250000

function SettingsCooldown.GetDisplayModeFromIndex(idx)
    idx = tonumber(idx) or 1
    if idx == 2 then
        return "missing"
    elseif idx == 3 then
        return "both"
    end
    return "active"
end

function SettingsCooldown.GetDisplayModeIndex(mode)
    mode = SettingsCommon.NormalizeCooldownDisplayMode(mode)
    if mode == "missing" then
        return 2
    elseif mode == "both" then
        return 3
    end
    return 1
end

function SettingsCooldown.GetDisplayStyleFromIndex(idx)
    return SettingsCommon.GetKeyFromIndex(DISPLAY_STYLE_KEYS, idx)
end

function SettingsCooldown.GetDisplayStyleIndex(style)
    style = SettingsCommon.NormalizeCooldownDisplayStyle(style)
    return SettingsCommon.GetIndexFromKey(DISPLAY_STYLE_KEYS, style)
end

function SettingsCooldown.GetTrackKindFromIndex(idx)
    idx = tonumber(idx) or 1
    if idx == 2 then
        return "buff"
    elseif idx == 3 then
        return "debuff"
    end
    return "any"
end

function SettingsCooldown.GetTrackKindIndex(kind)
    kind = SettingsCommon.NormalizeCooldownTrackKind(kind)
    if kind == "buff" then
        return 2
    elseif kind == "debuff" then
        return 3
    end
    return 1
end

function SettingsCooldown.GetUnitKeyFromIndex(idx)
    return SettingsCommon.GetKeyFromIndex(SettingsCooldown.UNIT_KEYS, idx)
end

function SettingsCooldown.GetUnitIndexFromKey(key)
    return SettingsCommon.GetIndexFromKey(SettingsCooldown.UNIT_KEYS, key)
end

function SettingsCooldown.EnsureTables(settings)
    return SettingsCommon.EnsureCooldownTrackerTables(settings, SettingsCooldown.UNIT_KEYS)
end

function SettingsCooldown.GetBuffMetaById(cache, rawId)
    local id = tonumber(rawId)
    if id == nil then
        return nil
    end
    id = math.floor(id + 0.5)

    if type(cache) == "table" and cache[id] ~= nil then
        return cache[id] ~= false and cache[id] or nil
    end

    if api == nil or api.Ability == nil or type(api.Ability.GetBuffTooltip) ~= "function" then
        if type(cache) == "table" then
            cache[id] = false
        end
        return nil
    end

    local ok, tooltip = pcall(function()
        return api.Ability:GetBuffTooltip(id, 1)
    end)
    if not ok or type(tooltip) ~= "table" then
        if type(cache) == "table" then
            cache[id] = false
        end
        return nil
    end

    local name = tostring(tooltip.name or tooltip.buffName or tooltip.title or "")
    if name == "" then
        if type(cache) == "table" then
            cache[id] = false
        end
        return nil
    end

    local meta = {
        id = SettingsCommon.FormatBuffId(id),
        name = name
    }
    if type(cache) == "table" then
        cache[id] = meta
    end
    return meta
end

function SettingsCooldown.ScanTargetEffects(state)
    local results = {}
    local seen = {}
    if type(state) == "table" then
        state.cooldown_scan_results = results
    end

    if api == nil or api.Unit == nil then
        return results
    end

    local function getName(id, raw)
        local idStr = tostring(id or "")
        local idNum = tonumber(idStr)

        if type(raw) == "table" and raw.name ~= nil then
            local n = tostring(raw.name)
            if n ~= "" and n ~= idStr then
                return n
            end
        end

        local meta = SettingsCooldown.GetBuffMetaById(type(state) == "table" and state.cooldown_buff_meta_cache or nil, idNum)
        if type(meta) == "table" and tostring(meta.name or "") ~= "" then
            return tostring(meta.name or "")
        end

        if idStr ~= "" then
            return "Buff #" .. idStr
        end
        return ""
    end

    local function push(kind, eff)
        if type(eff) ~= "table" or eff.buff_id == nil then
            return
        end
        local id = SettingsCommon.FormatBuffId(eff.buff_id)
        if id == "" then
            return
        end
        local seenKey = tostring(kind or "buff") .. ":" .. id
        if seen[seenKey] then
            return
        end
        seen[seenKey] = true
        table.insert(results, {
            kind = kind,
            id = id,
            name = getName(id, eff)
        })
    end

    local ok = pcall(function()
        local bc = api.Unit:UnitBuffCount("target") or 0
        for i = 1, bc do
            push("buff", api.Unit:UnitBuff("target", i))
        end
        local dc = api.Unit:UnitDeBuffCount("target") or 0
        for i = 1, dc do
            push("debuff", api.Unit:UnitDeBuff("target", i))
        end
    end)
    if not ok then
        if type(state) == "table" then
            state.cooldown_scan_results = {}
        end
        return {}
    end

    table.sort(results, function(a, b)
        local kindA = tostring(a.kind or "buff")
        local kindB = tostring(b.kind or "buff")
        if kindA ~= kindB then
            return kindA < kindB
        end
        local nameA = string.lower(tostring(a.name or ""))
        local nameB = string.lower(tostring(b.name or ""))
        if nameA ~= nameB then
            return nameA < nameB
        end
        return tostring(a.id or "") < tostring(b.id or "")
    end)
    return results
end

function SettingsCooldown.RefreshScanRows(state)
    local controls = type(state) == "table" and state.controls or nil
    if controls == nil or type(controls.ct_scan_rows) ~= "table" then
        return
    end

    local results = state.cooldown_scan_results
    if type(results) ~= "table" then
        results = {}
        state.cooldown_scan_results = results
    end

    if controls.ct_scan_status ~= nil and controls.ct_scan_status.SetText ~= nil then
        controls.ct_scan_status:SetText(string.format("Found %d effect(s) on target", #results))
    end

    for i, row in ipairs(controls.ct_scan_rows) do
        local entry = results[i]
        local show = type(entry) == "table"
        if type(row) == "table" then
            if row.label ~= nil and row.label.SetText ~= nil then
                if show then
                    local kind = tostring(entry.kind or "buff")
                    local prefix = (kind == "debuff") and "[D]" or "[B]"
                    row.label:SetText(string.format("%s %s %s", prefix, tostring(entry.id or ""), tostring(entry.name or "")))
                else
                    row.label:SetText("")
                end
            end
            if row.label ~= nil and row.label.Show ~= nil then
                row.label:Show(show)
            end
            if row.add ~= nil and row.add.Show ~= nil then
                row.add:Show(show)
            end
            if row.add ~= nil then
                row.add.__polar_scan_index = i
            end
        end
    end
end

function SettingsCooldown.RefreshTrackedRows(state, unitCfg)
    local controls = type(state) == "table" and state.controls or nil
    if controls == nil or type(controls.ct_buff_rows) ~= "table" then
        return
    end

    local tracked = type(unitCfg) == "table" and unitCfg.tracked_buffs or nil
    if type(tracked) ~= "table" then
        tracked = {}
    end

    local total = #tracked
    local pages = math.max(1, math.ceil(total / SettingsCooldown.BUFFS_PER_PAGE))
    if state.cooldown_buff_page < 1 then
        state.cooldown_buff_page = 1
    elseif state.cooldown_buff_page > pages then
        state.cooldown_buff_page = pages
    end

    local startIdx = ((state.cooldown_buff_page - 1) * SettingsCooldown.BUFFS_PER_PAGE) + 1
    for i = 1, SettingsCooldown.BUFFS_PER_PAGE do
        local idx = startIdx + (i - 1)
        local row = controls.ct_buff_rows[i]
        if type(row) == "table" then
            local entry = SettingsCommon.NormalizeCooldownTrackedEntry(tracked[idx])
            local show = entry ~= nil
            if row.label ~= nil and row.label.SetText ~= nil then
                if show then
                    local meta = SettingsCooldown.GetBuffMetaById(state.cooldown_buff_meta_cache, entry.id)
                    local prefix = "[A]"
                    if entry.kind == "buff" then
                        prefix = "[B]"
                    elseif entry.kind == "debuff" then
                        prefix = "[D]"
                    end
                    local text = string.format("%s %s", prefix, tostring(entry.id))
                    if type(meta) == "table" and tostring(meta.name or "") ~= "" then
                        text = string.format("%s %s %s", prefix, tostring(entry.id), tostring(meta.name or ""))
                    end
                    row.label:SetText(text)
                else
                    row.label:SetText("")
                end
            end
            if row.label ~= nil and row.label.Show ~= nil then
                row.label:Show(show)
            end
            if row.remove ~= nil and row.remove.Show ~= nil then
                row.remove:Show(show)
            end
            if row.remove ~= nil then
                row.remove.__polar_buff_index = idx
            end
        end
    end

    if controls.ct_page_label ~= nil and controls.ct_page_label.SetText ~= nil then
        controls.ct_page_label:SetText(string.format("%d / %d", state.cooldown_buff_page, pages))
    end
    if controls.ct_prev_page ~= nil and controls.ct_prev_page.SetEnable ~= nil then
        controls.ct_prev_page:SetEnable(state.cooldown_buff_page > 1)
    end
    if controls.ct_next_page ~= nil and controls.ct_next_page.SetEnable ~= nil then
        controls.ct_next_page:SetEnable(state.cooldown_buff_page < pages)
    end
end

function SettingsCooldown.AddTrackedBuff(state, rawId, rawKind)
    if type(state) ~= "table" or state.settings == nil then
        return false
    end

    local normalized = SettingsCommon.NormalizeCooldownTrackedEntry({
        id = rawId,
        kind = rawKind
    })
    if normalized == nil then
        return false
    end

    local id = SettingsCommon.FormatBuffId(normalized.id)
    SettingsCooldown.EnsureTables(state.settings)
    local unitKey = tostring(state.cooldown_unit_key or "player")
    local tracker = state.settings.cooldown_tracker
    local unitCfg = type(tracker) == "table" and type(tracker.units) == "table" and tracker.units[unitKey] or nil
    if type(unitCfg) ~= "table" or type(unitCfg.tracked_buffs) ~= "table" then
        return false
    end

    for _, v in ipairs(unitCfg.tracked_buffs) do
        local existing = SettingsCommon.NormalizeCooldownTrackedEntry(v)
        if existing ~= nil and SettingsCommon.FormatBuffId(existing.id) == id and existing.kind == normalized.kind then
            return false
        end
    end

    table.insert(unitCfg.tracked_buffs, {
        id = normalized.id,
        kind = normalized.kind
    })
    if type(state.on_apply) == "function" then
        pcall(function()
            state.on_apply()
        end)
    end
    return true
end

function SettingsCooldown.RefreshSearchRows(state)
    local controls = type(state) == "table" and state.controls or nil
    if controls == nil or type(controls.ct_search_rows) ~= "table" then
        return
    end

    local results = type(state.cooldown_search_results) == "table" and state.cooldown_search_results or {}
    local query = tostring(state.cooldown_search_query or "")
    if controls.ct_search_status ~= nil and controls.ct_search_status.SetText ~= nil then
        local status = ""
        if query ~= "" then
            if #results > 0 then
                if state.cooldown_search_complete then
                    status = string.format("Found %d match(es)", #results)
                else
                    status = string.format("Found %d match(es), scanned to #%d", #results, math.max(0, (tonumber(state.cooldown_search_cursor) or 1) - 1))
                end
            elseif state.cooldown_search_complete then
                status = "No matches found"
            else
                status = string.format("No matches yet, scanned to #%d", math.max(0, (tonumber(state.cooldown_search_cursor) or 1) - 1))
            end
        end
        controls.ct_search_status:SetText(status)
    end

    for i, row in ipairs(controls.ct_search_rows) do
        local entry = results[i]
        local show = type(entry) == "table"
        if type(row) == "table" then
            if row.label ~= nil and row.label.SetText ~= nil then
                if show then
                    row.label:SetText(string.format("%s %s", tostring(entry.id or ""), tostring(entry.name or "")))
                else
                    row.label:SetText("")
                end
            end
            if row.label ~= nil and row.label.Show ~= nil then
                row.label:Show(show)
            end
            if row.add ~= nil and row.add.Show ~= nil then
                row.add:Show(show)
            end
            if row.add ~= nil then
                row.add.__polar_search_id = show and tostring(entry.id or "") or nil
            end
        end
    end

    if controls.ct_search_more ~= nil and controls.ct_search_more.Show ~= nil then
        controls.ct_search_more:Show(query ~= "" and not state.cooldown_search_complete)
    end
end

function SettingsCooldown.RunBuffSearch(state, query, loadMore)
    query = string.lower(tostring(query or ""))
    query = string.match(query, "^%s*(.-)%s*$") or query

    if query == "" then
        state.cooldown_search_query = ""
        state.cooldown_search_results = {}
        state.cooldown_search_cursor = 1
        state.cooldown_search_complete = false
        SettingsCooldown.RefreshSearchRows(state)
        return
    end

    local continuing = loadMore and query == tostring(state.cooldown_search_query or "")
    if not continuing then
        state.cooldown_search_query = query
        state.cooldown_search_results = {}
        state.cooldown_search_cursor = 1
        state.cooldown_search_complete = false
    end

    local results = state.cooldown_search_results
    local seen = {}
    for _, entry in ipairs(results) do
        if type(entry) == "table" then
            seen[tostring(entry.id or "")] = true
        end
    end

    local numericQuery = tonumber(query)
    if numericQuery ~= nil and not continuing then
        local meta = SettingsCooldown.GetBuffMetaById(state.cooldown_buff_meta_cache, numericQuery)
        if meta ~= nil then
            local id = tostring(meta.id or "")
            if id ~= "" and not seen[id] then
                table.insert(results, {
                    id = id,
                    name = tostring(meta.name or "")
                })
                seen[id] = true
            end
        end
    end

    local scanned = 0
    local cursor = tonumber(state.cooldown_search_cursor) or 1
    if cursor < 1 then
        cursor = 1
    end

    while cursor <= SEARCH_MAX_ID and #results < SettingsCooldown.SEARCH_ROWS and scanned < SEARCH_BATCH do
        local meta = SettingsCooldown.GetBuffMetaById(state.cooldown_buff_meta_cache, cursor)
        if meta ~= nil then
            local id = tostring(meta.id or "")
            local name = string.lower(tostring(meta.name or ""))
            if id ~= "" and not seen[id] and string.find(name, query, 1, true) ~= nil then
                table.insert(results, {
                    id = id,
                    name = tostring(meta.name or "")
                })
                seen[id] = true
            end
        end
        cursor = cursor + 1
        scanned = scanned + 1
    end

    state.cooldown_search_cursor = cursor
    if cursor > SEARCH_MAX_ID or #results >= SettingsCooldown.SEARCH_ROWS then
        state.cooldown_search_complete = cursor > SEARCH_MAX_ID
    else
        state.cooldown_search_complete = false
    end

    SettingsCooldown.RefreshSearchRows(state)
end

return SettingsCooldown
