local api = require("api")
local SafeRequire = require("nuzi-ui/safe_require")
local Compat = SafeRequire("nuzi-ui/compat", "nuzi-ui.compat")
local SettingsCommon = SafeRequire("nuzi-ui/settings_common", "nuzi-ui.settings_common")
local SettingsWidgets = SafeRequire("nuzi-ui/settings_widgets", "nuzi-ui.settings_widgets")
local SettingsCatalog = SafeRequire("nuzi-ui/settings_catalog", "nuzi-ui.settings_catalog")

local SettingsPage = {
    settings = nil,
    on_save = nil,
    on_apply = nil,
    actions = nil,
    window = nil,
    scroll_frame = nil,
    content = nil,
    controls = {},
    pages = {},
    page_heights = {},
    active_page = nil,
    nav = {},
    toggle_button = nil,
    toggle_button_icon = nil,
    toggle_button_dragging = false,
    style_target = "all",
    _refreshing_style_target = false,
    cooldown_unit_key = "player",
    cooldown_track_kind = "any",
    cooldown_buff_page = 1,
    cooldown_scan_results = {},
    cooldown_search_results = {},
    cooldown_search_query = "",
    cooldown_search_cursor = 1,
    cooldown_search_complete = false,
    cooldown_buff_meta_cache = {},
    restart_notice_overlay = nil,
    restart_notice_panel = nil,
    restart_notice_title = nil,
    restart_notice_line1 = nil,
    restart_notice_line2 = nil,
    restart_notice_line3 = nil,
    restart_notice_ok = nil
}

local detectedAddonDir = nil

local function NormalizePath(path)
    return string.gsub(tostring(path or ""), "\\", "/")
end

local function FileExists(path)
    if type(io) ~= "table" or type(io.open) ~= "function" then
        return false
    end
    local file = nil
    local ok = pcall(function()
        file = io.open(path, "rb")
    end)
    if ok and file ~= nil then
        pcall(function()
            file:close()
        end)
        return true
    end
    return false
end

local function AddonDir()
    if detectedAddonDir ~= nil then
        return detectedAddonDir or nil
    end
    detectedAddonDir = false
    if type(debug) == "table" and type(debug.getinfo) == "function" then
        local info = debug.getinfo(1, "S")
        local source = type(info) == "table" and tostring(info.source or "") or ""
        if string.sub(source, 1, 1) == "@" then
            source = NormalizePath(string.sub(source, 2))
            local folder = string.match(source, "^(.*)/[^/]+$")
            if type(folder) == "string" and folder ~= "" then
                detectedAddonDir = folder
                return folder
            end
        end
    end
    return nil
end

local function ResolveAssetPath(relativePath)
    local rawRelative = NormalizePath(relativePath)
    local strippedRelative = string.match(rawRelative, "^[^/]+/(.+)$") or rawRelative
    local candidates = {}
    local seen = {}
    local function addCandidate(path)
        path = NormalizePath(path)
        if path == "" or seen[path] then
            return
        end
        seen[path] = true
        candidates[#candidates + 1] = path
    end
    local folder = AddonDir()
    if folder ~= nil then
        addCandidate(folder .. "/" .. strippedRelative)
        addCandidate(folder .. "/" .. rawRelative)
    end
    local baseDir = NormalizePath(type(api) == "table" and type(api.baseDir) == "string" and api.baseDir or "")
    if baseDir ~= "" then
        addCandidate(baseDir .. "/" .. rawRelative)
        addCandidate(baseDir .. "/" .. strippedRelative)
    end
    addCandidate(rawRelative)
    addCandidate(strippedRelative)
    for _, candidate in ipairs(candidates) do
        if FileExists(candidate) then
            return candidate
        end
    end
    return candidates[1] or rawRelative
end

local function IsShiftDown()
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

local function GetSettingsButtonSize()
    local size = 48
    if type(SettingsPage.settings) == "table" and type(SettingsPage.settings.settings_button) == "table" then
        size = tonumber(SettingsPage.settings.settings_button.size) or size
    end
    size = math.floor(size + 0.5)
    if size < 36 then
        size = 36
    elseif size > 96 then
        size = 96
    end
    return size
end

local function ApplySettingsButtonLayout()
    local size = GetSettingsButtonSize()
    if SettingsPage.toggle_button ~= nil and SettingsPage.toggle_button.SetExtent ~= nil then
        pcall(function()
            SettingsPage.toggle_button:SetExtent(size, size)
        end)
    end
    if SettingsPage.toggle_button_icon ~= nil and SettingsPage.toggle_button_icon.SetExtent ~= nil then
        pcall(function()
            SettingsPage.toggle_button_icon:SetExtent(size, size)
        end)
    end
end

local STYLE_TARGET_KEYS = {
    "all",
    "player",
    "target",
    "watchtarget",
    "target_of_target",
    "party"
}

local COOLDOWN_UNIT_KEYS = {
    "player",
    "target",
    "playerpet",
    "watchtarget",
    "target_of_target"
}

local COOLDOWN_UNIT_LABELS = {
    "Player",
    "Target",
    "Mount/Pet",
    "Watchtarget",
    "Target of Target"
}

local COOLDOWN_DISPLAY_MODE_LABELS = {
    "Active only",
    "Missing only",
    "Both"
}

local COOLDOWN_TRACK_KIND_LABELS = {
    "Any",
    "Buff",
    "Debuff"
}

local COOLDOWN_BUFFS_PER_PAGE = 6
local COOLDOWN_SCAN_ROWS = 10
local COOLDOWN_SEARCH_ROWS = 8
local COOLDOWN_SEARCH_BATCH = 1000
local COOLDOWN_SEARCH_MAX_ID = 250000
local PAGE_DEFS = (type(SettingsCatalog) == "table" and type(SettingsCatalog.PAGES) == "table" and SettingsCatalog.PAGES) or {
    { id = "general", label = "General", title = "General", summary = "Core addon toggles and shared runtime behavior." },
    { id = "text", label = "Text", title = "Text", summary = "Name, level, role, guild, and number formatting." },
    { id = "bars", label = "Bars", title = "Bars", summary = "Frame sizing, alpha, bar colors, textures, and value placement." },
    { id = "auras", label = "Auras", title = "Auras", summary = "Aura windows, icon layout, and buff or debuff anchor controls." },
    { id = "plates", label = "Nameplates", title = "Nameplates", summary = "Visibility rules, offsets, colors, and runtime nameplate behavior." },
    { id = "cooldown", label = "Cooldowns", title = "Cooldown Tracker", summary = "Tracked buff and debuff icons for player, target, pet, watchtarget, and target of target." }
}

local ClampInt = SettingsCommon.ClampInt
local FormatBuffId = SettingsCommon.FormatBuffId
local PruneStyleFrameOverrides = SettingsCommon.PruneStyleFrameOverrides
local NormalizeCooldownTrackKind = SettingsCommon.NormalizeCooldownTrackKind
local NormalizeCooldownDisplayMode = SettingsCommon.NormalizeCooldownDisplayMode
local NormalizeCooldownTrackedEntry = SettingsCommon.NormalizeCooldownTrackedEntry

local function GetCooldownDisplayModeFromIndex(idx)
    idx = tonumber(idx) or 1
    if idx == 2 then
        return "missing"
    elseif idx == 3 then
        return "both"
    end
    return "active"
end

local function GetCooldownDisplayModeIndex(mode)
    mode = NormalizeCooldownDisplayMode(mode)
    if mode == "missing" then
        return 2
    elseif mode == "both" then
        return 3
    end
    return 1
end

local function GetCooldownTrackKindFromIndex(idx)
    idx = tonumber(idx) or 1
    if idx == 2 then
        return "buff"
    elseif idx == 3 then
        return "debuff"
    end
    return "any"
end

local function GetCooldownTrackKindIndex(kind)
    kind = NormalizeCooldownTrackKind(kind)
    if kind == "buff" then
        return 2
    elseif kind == "debuff" then
        return 3
    end
    return 1
end

local function ScanTargetEffects()
    local results = {}
    local seen = {}
    SettingsPage.cooldown_scan_results = results

    if api == nil or api.Unit == nil then
        return
    end

    local function getName(id, raw)
        local id_str = tostring(id or "")
        local id_num = tonumber(id_str)

        if type(raw) == "table" and raw.name ~= nil then
            local n = tostring(raw.name)
            if n ~= "" and n ~= id_str then
                return n
            end
        end

        if api ~= nil and api.Ability ~= nil and id_num ~= nil then
            local ok, tooltip = pcall(function()
                if type(api.Ability.GetBuffTooltip) == "function" then
                    return api.Ability:GetBuffTooltip(id_num, 1)
                end
                return nil
            end)
            if ok and type(tooltip) == "table" and tooltip.name ~= nil then
                local n = tostring(tooltip.name)
                if n ~= "" and n ~= id_str then
                    return n
                end
            end
        end

        if id_str ~= "" then
            return "Buff #" .. id_str
        end
        return ""
    end

    local function push(kind, eff)
        if type(eff) ~= "table" or eff.buff_id == nil then
            return
        end
        local id = FormatBuffId(eff.buff_id)
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
        SettingsPage.cooldown_scan_results = {}
        return
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
end

local function GetCooldownUnitKeyFromIndex(idx)
    return SettingsCommon.GetKeyFromIndex(COOLDOWN_UNIT_KEYS, idx)
end

local function GetCooldownUnitIndexFromKey(key)
    return SettingsCommon.GetIndexFromKey(COOLDOWN_UNIT_KEYS, key)
end

local function EnsureCooldownTrackerTables(s)
    return SettingsCommon.EnsureCooldownTrackerTables(s, COOLDOWN_UNIT_KEYS)
end

local function SetWidgetEnabled(widget, enabled)
    if widget == nil then
        return
    end
    pcall(function()
        if widget.Enable ~= nil then
            widget:Enable(enabled and true or false)
        elseif widget.SetEnabled ~= nil then
            widget:SetEnabled(enabled and true or false)
        end
    end)
end

local function RefreshCooldownScanRows()
    if SettingsPage.controls == nil then
        return
    end
    local rows = SettingsPage.controls.ct_scan_rows
    if type(rows) ~= "table" then
        return
    end

    local results = SettingsPage.cooldown_scan_results
    if type(results) ~= "table" then
        results = {}
        SettingsPage.cooldown_scan_results = results
    end

    if SettingsPage.controls.ct_scan_status ~= nil and SettingsPage.controls.ct_scan_status.SetText ~= nil then
        SettingsPage.controls.ct_scan_status:SetText(string.format("Found %d effect(s) on target", #results))
    end

    for i, row in ipairs(rows) do
        local entry = results[i]
        local show = type(entry) == "table"
        if type(row) == "table" then
            if row.label ~= nil and row.label.SetText ~= nil then
                if show then
                    local kind = tostring(entry.kind or "buff")
                    local prefix = (kind == "debuff") and "[D]" or "[B]"
                    local id = tostring(entry.id or "")
                    local name = tostring(entry.name or "")
                    local text = string.format("%s %s %s", prefix, id, name)
                    row.label:SetText(text)
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

local function GetEditText(field)
    if field == nil or field.GetText == nil then
        return ""
    end
    local ok, res = pcall(function()
        return field:GetText()
    end)
    if ok and res ~= nil then
        return tostring(res)
    end
    return ""
end

local function ParseEditNumber(field)
    local txt = GetEditText(field)
    txt = tostring(txt or "")
    txt = txt:gsub("%s+", "")
    local n = tonumber(txt)
    return n
end

local GetCooldownBuffMetaById

local function RefreshCooldownBuffRows(unit_cfg)
    if SettingsPage.controls == nil then
        return
    end
    local rows = SettingsPage.controls.ct_buff_rows
    if type(rows) ~= "table" then
        return
    end

    local tracked = type(unit_cfg) == "table" and unit_cfg.tracked_buffs or nil
    if type(tracked) ~= "table" then
        tracked = {}
    end

    local total = #tracked
    local pages = math.max(1, math.ceil(total / COOLDOWN_BUFFS_PER_PAGE))
    if SettingsPage.cooldown_buff_page < 1 then
        SettingsPage.cooldown_buff_page = 1
    elseif SettingsPage.cooldown_buff_page > pages then
        SettingsPage.cooldown_buff_page = pages
    end

    local start_idx = ((SettingsPage.cooldown_buff_page - 1) * COOLDOWN_BUFFS_PER_PAGE) + 1
    for i = 1, COOLDOWN_BUFFS_PER_PAGE do
        local idx = start_idx + (i - 1)
        local row = rows[i]
        if type(row) == "table" then
            local rawEntry = tracked[idx]
            local entry = NormalizeCooldownTrackedEntry(rawEntry)
            local show = entry ~= nil
            if row.label ~= nil and row.label.SetText ~= nil then
                if show then
                    local meta = GetCooldownBuffMetaById(entry.id)
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

    if SettingsPage.controls.ct_page_label ~= nil and SettingsPage.controls.ct_page_label.SetText ~= nil then
        SettingsPage.controls.ct_page_label:SetText(string.format("%d / %d", SettingsPage.cooldown_buff_page, pages))
    end
    if SettingsPage.controls.ct_prev_page ~= nil and SettingsPage.controls.ct_prev_page.SetEnable ~= nil then
        SettingsPage.controls.ct_prev_page:SetEnable(SettingsPage.cooldown_buff_page > 1)
    end
    if SettingsPage.controls.ct_next_page ~= nil and SettingsPage.controls.ct_next_page.SetEnable ~= nil then
        SettingsPage.controls.ct_next_page:SetEnable(SettingsPage.cooldown_buff_page < pages)
    end
end

local GetComboBoxIndexRaw = SettingsWidgets.GetComboBoxIndexRaw
local SetComboBoxIndex1Based = SettingsWidgets.SetComboBoxIndex1Based
local GetComboBoxIndex1Based = SettingsWidgets.GetComboBoxIndex1Based

local EnsureStyleFrames = SettingsCommon.EnsureStyleFrames

local function GetStyleTargetKeyFromIndex(idx)
    return SettingsCommon.GetKeyFromIndex(STYLE_TARGET_KEYS, idx)
end

local function GetStyleTargetIndexFromKey(key)
    return SettingsCommon.GetIndexFromKey(STYLE_TARGET_KEYS, tostring(key or "all"))
end

local function GetStyleTargetDisplayName(key)
    key = tostring(key or "all")
    if key == "player" then
        return "Player"
    elseif key == "target" then
        return "Target"
    elseif key == "watchtarget" then
        return "Watchtarget"
    elseif key == "target_of_target" then
        return "Target of Target"
    elseif key == "party" then
        return "Party"
    end
    return "All frames"
end

local function GetStyleTargetKeyFromLabel(text)
    local value = string.lower(tostring(text or ""))
    if value == "player" then
        return "player"
    elseif value == "target" then
        return "target"
    elseif value == "watchtarget" then
        return "watchtarget"
    elseif value == "target of target" then
        return "target_of_target"
    elseif value == "party" then
        return "party"
    elseif value == "all frames" then
        return "all"
    end
    return nil
end

local GetComboBoxText = SettingsWidgets.GetComboBoxText

local function GetStyleTargetKeyFromControl(ctrl, eventArg1, eventArg2)
    local directTextKeys = {
        GetStyleTargetKeyFromLabel(eventArg2),
        GetStyleTargetKeyFromLabel(eventArg1),
        GetStyleTargetKeyFromLabel(GetComboBoxText(ctrl))
    }
    for _, key in ipairs(directTextKeys) do
        if key ~= nil then
            return key
        end
    end

    local items = type(ctrl) == "table" and ctrl.__polar_items or nil
    local numericArgs = { tonumber(eventArg2), tonumber(eventArg1) }
    if type(items) == "table" then
        for _, rawArg in ipairs(numericArgs) do
            if type(rawArg) == "number" then
                local idx = math.floor(rawArg + 0.5)
                local key = GetStyleTargetKeyFromLabel(items[idx]) or GetStyleTargetKeyFromLabel(items[idx + 1])
                if key ~= nil then
                    return key
                end
            end
        end
    end

    local textKey = GetStyleTargetKeyFromLabel(GetComboBoxText(ctrl))
    if textKey ~= nil then
        return textKey
    end

    local raw = GetComboBoxIndexRaw(ctrl)
    if type(items) == "table" and type(raw) == "number" then
        local idx = math.floor(raw + 0.5)
        local key = GetStyleTargetKeyFromLabel(items[idx]) or GetStyleTargetKeyFromLabel(items[idx + 1])
        if key ~= nil then
            return key
        end
    end

    local idx = GetComboBoxIndex1Based(ctrl, #STYLE_TARGET_KEYS)
    if idx ~= nil then
        return GetStyleTargetKeyFromIndex(idx)
    end
    return "all"
end

local function UpdateStyleTargetHints()
    local targetLabel = GetStyleTargetDisplayName(SettingsPage.style_target)
    local summary = ""
    if SettingsPage.style_target == "all" then
        summary = "Editing shared defaults for all overlay and party frames."
    else
        summary = string.format("Editing only %s overrides. Unchanged values still inherit from All frames.", targetLabel)
    end

    local hintKeys = {
        "style_target_text_hint",
        "style_target_bars_hint"
    }

    for _, key in ipairs(hintKeys) do
        local label = SettingsPage.controls[key]
        if label ~= nil and label.SetText ~= nil then
            label:SetText(summary)
        end
    end
end

local function EffectiveStyle(base, override)
    local out = {}
    if type(base) == "table" then
        for k, v in pairs(base) do
            if k ~= "frames" then
                out[k] = v
            end
        end
    end
    if type(override) == "table" then
        for k, v in pairs(override) do
            if k ~= "frames" and k ~= "large_hpmp" and k ~= "buff_windows" and k ~= "aura" then
                out[k] = v
            end
        end
    end
    return out
end

local function GetStyleTables(settings)
    EnsureStyleFrames(settings)
    local base = settings.style

    local target = tostring(SettingsPage.style_target or "all")
    if target == "all" then
        return base, base
    end

    local override = (type(base.frames) == "table") and base.frames[target] or nil
    if type(override) ~= "table" then
        override = {}
    end
    return EffectiveStyle(base, override), override
end

local DeepCopySimple = SettingsCommon.DeepCopySimple
local CopyTableInto = SettingsCommon.CopyTableInto

local function CopyStatusbarCoords(dstKey, srcKey)
    if STATUSBAR_STYLE == nil or type(STATUSBAR_STYLE) ~= "table" then
        return
    end
    if type(dstKey) ~= "string" or type(srcKey) ~= "string" then
        return
    end
    local dst = STATUSBAR_STYLE[dstKey]
    local src = STATUSBAR_STYLE[srcKey]
    if type(dst) ~= "table" or type(src) ~= "table" then
        return
    end
    if type(src.coords) ~= "table" then
        return
    end
    dst.coords = DeepCopySimple(src.coords)
end

local CreatePage = SettingsWidgets.CreatePage
local UpdateNavigationState

local function GetPageMeta(pageId)
    if type(SettingsCatalog) == "table" and type(SettingsCatalog.GetPage) == "function" then
        local page = SettingsCatalog.GetPage(pageId)
        if type(page) == "table" then
            return page
        end
    end

    for _, page in ipairs(PAGE_DEFS) do
        if page.id == pageId then
            return page
        end
    end
    return nil
end

local function SetActivePage(pageId)
    if SettingsPage.pages == nil or SettingsPage.pages[pageId] == nil then
        return
    end

    for id, page in pairs(SettingsPage.pages) do
        if page ~= nil and page.Show ~= nil then
            page:Show(id == pageId)
        end
    end
    SettingsPage.active_page = pageId
    if type(UpdateNavigationState) == "function" then
        UpdateNavigationState(pageId)
    end

    local function syncStyleTargetCombo(ctrl)
        if ctrl == nil then
            return
        end
        SettingsPage._refreshing_style_target = true
        local targetIdx = GetStyleTargetIndexFromKey(SettingsPage.style_target)
        ctrl.__polar_index_base = nil
        SetComboBoxIndex1Based(ctrl, targetIdx)
        SettingsPage._refreshing_style_target = false
    end

    if pageId == "text" then
        syncStyleTargetCombo(SettingsPage.controls.style_target_text)
    elseif pageId == "bars" then
        syncStyleTargetCombo(SettingsPage.controls.style_target_bars)
    end

    UpdateStyleTargetHints()

    local page = SettingsPage.pages[pageId]

    local totalHeight = tonumber(SettingsPage.page_heights[pageId]) or 0
    pcall(function()
        if SettingsPage.scroll_frame ~= nil and SettingsPage.scroll_frame.ResetScroll ~= nil then
            SettingsPage.scroll_frame:ResetScroll(totalHeight)
        end
    end)

    pcall(function()
        if SettingsPage.scroll_frame ~= nil and SettingsPage.scroll_frame.scroll ~= nil and SettingsPage.scroll_frame.scroll.vs ~= nil then
            local vs = SettingsPage.scroll_frame.scroll.vs
            if vs.SetValue ~= nil then
                vs:SetValue(0, false)
            end
        end
    end)

    pcall(function()
        if page ~= nil and page.ChangeChildAnchorByScrollValue ~= nil then
            page:ChangeChildAnchorByScrollValue("vert", 0)
        end
    end)
end

local function MakeCloseHandler()
    return function()
        if SettingsPage.restart_notice_overlay ~= nil and SettingsPage.restart_notice_overlay.Show ~= nil then
            local visible = false
            if SettingsPage.restart_notice_overlay.IsVisible ~= nil then
                pcall(function()
                    visible = SettingsPage.restart_notice_overlay:IsVisible() and true or false
                end)
            end
            if visible then
                SettingsPage.restart_notice_overlay:Show(false)
                return
            end
        end
        if SettingsPage.window ~= nil then
            SettingsPage.window:Show(false)
        end
    end
end

local function CreateEmptyChild(parent, id)
    if parent == nil then
        return nil
    end

    local widget = nil
    if parent.CreateChildWidget ~= nil then
        local ok, res = pcall(function()
            return parent:CreateChildWidget("emptywidget", id, 0, true)
        end)
        if ok then
            widget = res
        end
    end

    if widget == nil and api ~= nil and api.Interface ~= nil and api.Interface.CreateWidget ~= nil then
        local ok, res = pcall(function()
            return api.Interface:CreateWidget("emptywidget", id, parent)
        end)
        if ok then
            widget = res
        end
    end

    return widget
end

local function AddPanelBackground(widget, alpha)
    if widget == nil or widget.CreateNinePartDrawable == nil or TEXTURE_PATH == nil or TEXTURE_PATH.HUD == nil then
        return nil
    end

    local background = nil
    local ok, res = pcall(function()
        return widget:CreateNinePartDrawable(TEXTURE_PATH.HUD, "background")
    end)
    if ok then
        background = res
    end

    if background ~= nil then
        pcall(function()
            if background.SetTextureInfo ~= nil then
                background:SetTextureInfo("bg_quest")
            end
            if background.SetColor ~= nil then
                background:SetColor(0, 0, 0, tonumber(alpha) or 0.82)
            end
            background:AddAnchor("TOPLEFT", widget, 0, 0)
            background:AddAnchor("BOTTOMRIGHT", widget, 0, 0)
        end)
    end

    return background
end

local function EnsureRestartNotice()
    if SettingsPage.window == nil or SettingsPage.restart_notice_overlay ~= nil then
        return
    end

    local overlay = CreateEmptyChild(SettingsPage.window, "polarUiRestartNoticeOverlay")
    if overlay == nil then
        return
    end
    SettingsPage.restart_notice_overlay = overlay
    pcall(function()
        overlay:AddAnchor("TOPLEFT", SettingsPage.window, 0, 0)
        overlay:AddAnchor("BOTTOMRIGHT", SettingsPage.window, 0, 0)
        overlay:SetExtent(820, 760)
        if overlay.Show ~= nil then
            overlay:Show(false)
        end
    end)
    AddPanelBackground(overlay, 0.4)

    local panel = CreateEmptyChild(overlay, "polarUiRestartNoticePanel")
    if panel == nil then
        return
    end
    SettingsPage.restart_notice_panel = panel
    pcall(function()
        panel:SetExtent(420, 170)
        panel:AddAnchor("CENTER", overlay, 0, 0)
    end)
    AddPanelBackground(panel, 0.92)

    local title = SettingsWidgets.CreateLabel("polarUiRestartNoticeTitle", panel, "Restart Required", 24, 22, 18)
    if title ~= nil and title.SetExtent ~= nil then
        pcall(function()
            title:SetExtent(320, 24)
        end)
    end
    SettingsPage.restart_notice_title = title

    SettingsPage.restart_notice_line1 = SettingsWidgets.CreateHintLabel(
        "polarUiRestartNoticeLine1",
        panel,
        "A full game restart is required for some",
        24,
        58,
        372
    )
    SettingsPage.restart_notice_line2 = SettingsWidgets.CreateHintLabel(
        "polarUiRestartNoticeLine2",
        panel,
        "Nuzi UI settings to take effect.",
        24,
        80,
        372
    )
    SettingsPage.restart_notice_line3 = SettingsWidgets.CreateHintLabel(
        "polarUiRestartNoticeLine3",
        panel,
        "UI reload alone may not be enough.",
        24,
        102,
        372
    )

    local okButton = SettingsWidgets.CreateButton("polarUiRestartNoticeOk", panel, "OK", 165, 130)
    if okButton ~= nil then
        pcall(function()
            okButton:SetExtent(90, 26)
        end)
        if okButton.SetHandler ~= nil then
            okButton:SetHandler("OnClick", function()
                if SettingsPage.restart_notice_overlay ~= nil and SettingsPage.restart_notice_overlay.Show ~= nil then
                    SettingsPage.restart_notice_overlay:Show(false)
                end
            end)
        end
    end
    SettingsPage.restart_notice_ok = okButton
end

local function ShowRestartNotice()
    EnsureRestartNotice()
    if SettingsPage.restart_notice_overlay ~= nil and SettingsPage.restart_notice_overlay.Show ~= nil then
        SettingsPage.restart_notice_overlay:Show(true)
    end
end

UpdateNavigationState = function(activePageId)
    local pageId = activePageId or SettingsPage.active_page

    for _, page in ipairs(PAGE_DEFS) do
        local btn = SettingsPage.nav[page.id]
        if btn ~= nil and btn.SetText ~= nil then
            local label = tostring(page.label or page.id)
            if page.id == pageId then
                label = "> " .. label
            end
            btn:SetText(label)
        end
    end

    local meta = GetPageMeta(pageId) or {}
    if SettingsPage.controls.page_header_title ~= nil and SettingsPage.controls.page_header_title.SetText ~= nil then
        SettingsPage.controls.page_header_title:SetText(tostring(meta.title or ""))
    end
    if SettingsPage.controls.page_header_summary ~= nil and SettingsPage.controls.page_header_summary.SetText ~= nil then
        SettingsPage.controls.page_header_summary:SetText(tostring(meta.summary or ""))
    end
end

GetCooldownBuffMetaById = function(rawId)
    local id = tonumber(rawId)
    if id == nil then
        return nil
    end
    id = math.floor(id + 0.5)

    if SettingsPage.cooldown_buff_meta_cache[id] ~= nil then
        return SettingsPage.cooldown_buff_meta_cache[id] ~= false and SettingsPage.cooldown_buff_meta_cache[id] or nil
    end

    if api == nil or api.Ability == nil or type(api.Ability.GetBuffTooltip) ~= "function" then
        SettingsPage.cooldown_buff_meta_cache[id] = false
        return nil
    end

    local ok, tooltip = pcall(function()
        return api.Ability:GetBuffTooltip(id, 1)
    end)
    if not ok or type(tooltip) ~= "table" then
        SettingsPage.cooldown_buff_meta_cache[id] = false
        return nil
    end

    local name = tostring(tooltip.name or tooltip.buffName or tooltip.title or "")
    if name == "" then
        SettingsPage.cooldown_buff_meta_cache[id] = false
        return nil
    end

    local meta = {
        id = FormatBuffId(id),
        name = name
    }
    SettingsPage.cooldown_buff_meta_cache[id] = meta
    return meta
end

local function AddCooldownTrackedBuffToSelectedUnit(rawId, rawKind)
    if SettingsPage.settings == nil then
        return false
    end

    local normalized = NormalizeCooldownTrackedEntry({
        id = rawId,
        kind = rawKind
    })
    if normalized == nil then
        return false
    end
    local id = FormatBuffId(normalized.id)
    local kind = normalized.kind

    EnsureCooldownTrackerTables(SettingsPage.settings)
    local unit_key = tostring(SettingsPage.cooldown_unit_key or "player")
    local tracker = SettingsPage.settings.cooldown_tracker
    local unit_cfg = type(tracker) == "table" and type(tracker.units) == "table" and tracker.units[unit_key] or nil
    if type(unit_cfg) ~= "table" or type(unit_cfg.tracked_buffs) ~= "table" then
        return false
    end

    for _, v in ipairs(unit_cfg.tracked_buffs) do
        local existing = NormalizeCooldownTrackedEntry(v)
        if existing ~= nil and FormatBuffId(existing.id) == id and existing.kind == kind then
            return false
        end
    end

    table.insert(unit_cfg.tracked_buffs, {
        id = normalized.id,
        kind = kind
    })
    if type(SettingsPage.on_apply) == "function" then
        pcall(function()
            SettingsPage.on_apply()
        end)
    end
    return true
end

local function RefreshCooldownSearchRows()
    if SettingsPage.controls == nil then
        return
    end

    local rows = SettingsPage.controls.ct_search_rows
    if type(rows) ~= "table" then
        return
    end

    local results = type(SettingsPage.cooldown_search_results) == "table" and SettingsPage.cooldown_search_results or {}
    local query = tostring(SettingsPage.cooldown_search_query or "")
    if SettingsPage.controls.ct_search_status ~= nil and SettingsPage.controls.ct_search_status.SetText ~= nil then
        local status = ""
        if query ~= "" then
            if #results > 0 then
                if SettingsPage.cooldown_search_complete then
                    status = string.format("Found %d match(es)", #results)
                else
                    status = string.format("Found %d match(es), scanned to #%d", #results, math.max(0, (tonumber(SettingsPage.cooldown_search_cursor) or 1) - 1))
                end
            elseif SettingsPage.cooldown_search_complete then
                status = "No matches found"
            else
                status = string.format("No matches yet, scanned to #%d", math.max(0, (tonumber(SettingsPage.cooldown_search_cursor) or 1) - 1))
            end
        end
        SettingsPage.controls.ct_search_status:SetText(status)
    end

    for i, row in ipairs(rows) do
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

    if SettingsPage.controls.ct_search_more ~= nil and SettingsPage.controls.ct_search_more.Show ~= nil then
        SettingsPage.controls.ct_search_more:Show(query ~= "" and not SettingsPage.cooldown_search_complete)
    end
end

local function RunCooldownBuffSearch(loadMore)
    local query = string.lower(tostring(GetEditText(SettingsPage.controls.ct_search_text) or ""))
    query = string.match(query, "^%s*(.-)%s*$") or query

    if query == "" then
        SettingsPage.cooldown_search_query = ""
        SettingsPage.cooldown_search_results = {}
        SettingsPage.cooldown_search_cursor = 1
        SettingsPage.cooldown_search_complete = false
        RefreshCooldownSearchRows()
        return
    end

    local continuing = loadMore and query == tostring(SettingsPage.cooldown_search_query or "")
    if not continuing then
        SettingsPage.cooldown_search_query = query
        SettingsPage.cooldown_search_results = {}
        SettingsPage.cooldown_search_cursor = 1
        SettingsPage.cooldown_search_complete = false
    end

    local results = SettingsPage.cooldown_search_results
    local seen = {}
    for _, entry in ipairs(results) do
        if type(entry) == "table" then
            seen[tostring(entry.id or "")] = true
        end
    end

    local numericQuery = tonumber(query)
    if numericQuery ~= nil and not continuing then
        local meta = GetCooldownBuffMetaById(numericQuery)
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
    local cursor = tonumber(SettingsPage.cooldown_search_cursor) or 1
    if cursor < 1 then
        cursor = 1
    end

    while cursor <= COOLDOWN_SEARCH_MAX_ID and #results < COOLDOWN_SEARCH_ROWS and scanned < COOLDOWN_SEARCH_BATCH do
        local meta = GetCooldownBuffMetaById(cursor)
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

    SettingsPage.cooldown_search_cursor = cursor
    if cursor > COOLDOWN_SEARCH_MAX_ID or #results >= COOLDOWN_SEARCH_ROWS then
        SettingsPage.cooldown_search_complete = cursor > COOLDOWN_SEARCH_MAX_ID
    else
        SettingsPage.cooldown_search_complete = false
    end

    RefreshCooldownSearchRows()
end

local function RestoreSettingsButtonPos(widget)
    if widget == nil then
        return
    end
    if SettingsPage.settings == nil or type(SettingsPage.settings) ~= "table" then
        return
    end

    local pos = SettingsPage.settings.settings_button
    local x = 10
    local y = 200
    if type(pos) == "table" then
        x = tonumber(pos.x) or x
        y = tonumber(pos.y) or y
    end

    pcall(function()
        if widget.RemoveAllAnchors ~= nil then
            widget:RemoveAllAnchors()
        end
        if widget.AddAnchor ~= nil then
            widget:AddAnchor("TOPLEFT", "UIParent", x, y)
        end
    end)
    ApplySettingsButtonLayout()
end

local function SaveSettingsButtonPos(widget)
    if widget == nil then
        return
    end
    if SettingsPage.settings == nil or type(SettingsPage.settings) ~= "table" then
        return
    end

    local ok = false
    local x, y = nil, nil
    if widget.GetEffectiveOffset ~= nil then
        ok, x, y = pcall(function()
            return widget:GetEffectiveOffset()
        end)
    end
    if (not ok or x == nil or y == nil) and widget.GetOffset ~= nil then
        ok, x, y = pcall(function()
            return widget:GetOffset()
        end)
    end
    if not ok then
        return
    end

    x = tonumber(x)
    y = tonumber(y)
    if x == nil or y == nil then
        return
    end

    if type(SettingsPage.settings.settings_button) ~= "table" then
        SettingsPage.settings.settings_button = {}
    end
    SettingsPage.settings.settings_button.x = x
    SettingsPage.settings.settings_button.y = y
    SettingsPage.settings.settings_button.size = GetSettingsButtonSize()

    if type(SettingsPage.on_save) == "function" then
        pcall(function()
            SettingsPage.on_save()
        end)
    end
end

local function EnsureSettingsButton()
    if SettingsPage.toggle_button ~= nil then
        return
    end

    local btn = nil
    pcall(function()
        if api.Interface ~= nil and api.Interface.CreateEmptyWindow ~= nil then
            btn = api.Interface:CreateEmptyWindow("polarUiSettingsToggleBtn", "UIParent")
        elseif api.Interface ~= nil and api.Interface.CreateWidget ~= nil then
            btn = api.Interface:CreateWidget("button", "polarUiSettingsToggleBtn", api.rootWindow)
        end
    end)
    if btn == nil then
        return
    end

    SettingsPage.toggle_button = btn
    SettingsPage.toggle_button_icon = nil
    SettingsPage.toggle_button_dragging = false

    pcall(function()
        if btn.SetText ~= nil then
            btn:SetText("")
        end
        if btn.SetUILayer ~= nil then
            btn:SetUILayer("game")
        end
        if btn.Show ~= nil then
            btn:Show(true)
        end
    end)

    pcall(function()
        if btn.CreateImageDrawable ~= nil then
            local icon = btn:CreateImageDrawable("polarUiSettingsToggleBtnIcon", "artwork")
            if icon ~= nil then
                icon:SetTexture(ResolveAssetPath("nuzi-ui/icon.png"))
                icon:AddAnchor("TOPLEFT", btn, 0, 0)
                icon:SetExtent(GetSettingsButtonSize(), GetSettingsButtonSize())
                icon:Show(true)
                SettingsPage.toggle_button_icon = icon
            end
        end
    end)

    RestoreSettingsButtonPos(btn)

    if btn.SetHandler ~= nil then
        btn:SetHandler("OnDragStart", function(self)
            if type(SettingsPage.settings) == "table" and SettingsPage.settings.drag_requires_shift ~= false and not IsShiftDown() then
                return
            end
            SettingsPage.toggle_button_dragging = true
            if self.StartMoving ~= nil then
                self:StartMoving()
            end
        end)
        btn:SetHandler("OnDragStop", function(self)
            if self.StopMovingOrSizing ~= nil then
                self:StopMovingOrSizing()
            end
            if api.Cursor ~= nil and api.Cursor.ClearCursor ~= nil then
                pcall(function()
                    api.Cursor:ClearCursor()
                end)
            end
            SaveSettingsButtonPos(self)
        end)
        btn:SetHandler("OnClick", function()
            if SettingsPage.toggle_button_dragging then
                SettingsPage.toggle_button_dragging = false
                return
            end
            if SettingsPage.toggle ~= nil then
                SettingsPage.toggle()
            end
        end)
    end

    pcall(function()
        if btn.RegisterForDrag ~= nil then
            btn:RegisterForDrag("LeftButton")
        end
        if btn.EnableDrag ~= nil then
            btn:EnableDrag(true)
        end
    end)
end

local CreateLabel = SettingsWidgets.CreateLabel
local CreateHintLabel = SettingsWidgets.CreateHintLabel
local ApplyCheckButtonSkin = SettingsWidgets.ApplyCheckButtonSkin
local CreateCheckbox = SettingsWidgets.CreateCheckbox
local CreateButton = SettingsWidgets.CreateButton
local CreateEdit = SettingsWidgets.CreateEdit
local GetSliderValue = SettingsWidgets.GetSliderValue
local SetSliderValue = SettingsWidgets.SetSliderValue
local CreateSlider = SettingsWidgets.CreateSlider
local CreateComboBox = SettingsWidgets.CreateComboBox

local function SetHpTextureModeChecks(mode)
    local resolved = tostring(mode or "stock")
    if SettingsPage.controls.hp_tex_stock ~= nil and SettingsPage.controls.hp_tex_stock.SetChecked ~= nil then
        SettingsPage.controls.hp_tex_stock:SetChecked(resolved == "stock")
    end
    if SettingsPage.controls.hp_tex_pc ~= nil and SettingsPage.controls.hp_tex_pc.SetChecked ~= nil then
        SettingsPage.controls.hp_tex_pc:SetChecked(resolved == "pc")
    end
    if SettingsPage.controls.hp_tex_npc ~= nil and SettingsPage.controls.hp_tex_npc.SetChecked ~= nil then
        SettingsPage.controls.hp_tex_npc:SetChecked(resolved == "npc")
    end
end

local function RefreshControls()
    local s = SettingsPage.settings
    if s == nil then
        return
    end
    if SettingsPage.controls.enabled ~= nil then
        SettingsPage.controls.enabled:SetChecked(s.enabled and true or false)
    end

    UpdateStyleTargetHints()

    local displayStyle, _ = GetStyleTables(s)

    local function refreshAlpha(slider, valueLabel, value)
        local pct = math.floor(((tonumber(value) or 1) * 100) + 0.5)
        if pct < 0 then
            pct = 0
        elseif pct > 100 then
            pct = 100
        end
        if slider ~= nil then
            SetSliderValue(slider, pct)
        end
        if valueLabel ~= nil and valueLabel.SetText ~= nil then
            valueLabel:SetText(tostring(pct))
        end
    end

    local function refreshSlider(slider, valueLabel, value)
        if slider ~= nil then
            SetSliderValue(slider, value)
        end
        if valueLabel ~= nil and valueLabel.SetText ~= nil then
            valueLabel:SetText(tostring(math.floor((tonumber(value) or 0) + 0.5)))
        end
    end

    if type(s.style) == "table" and SettingsPage.controls.large_hpmp ~= nil then
        SettingsPage.controls.large_hpmp:SetChecked(s.style.large_hpmp ~= false)
    end

    if SettingsPage.controls.show_distance ~= nil then
        SettingsPage.controls.show_distance:SetChecked(s.show_distance ~= false)
    end

    if SettingsPage.controls.alignment_grid_enabled ~= nil then
        SettingsPage.controls.alignment_grid_enabled:SetChecked(s.alignment_grid_enabled and true or false)
    end

    if SettingsPage.controls.launcher_size ~= nil then
        local size = GetSettingsButtonSize()
        refreshSlider(SettingsPage.controls.launcher_size, SettingsPage.controls.launcher_size_val, size)
        ApplySettingsButtonLayout()
    end

    if SettingsPage.controls.frame_alpha ~= nil then
        local fa = nil
        if type(displayStyle) == "table" then
            fa = tonumber(displayStyle.frame_alpha)
        end
        if fa == nil then
            fa = tonumber(s.frame_alpha)
        end
        refreshAlpha(SettingsPage.controls.frame_alpha, SettingsPage.controls.frame_alpha_val, fa)
    end

    if type(displayStyle) == "table" and SettingsPage.controls.overlay_alpha ~= nil then
        refreshAlpha(SettingsPage.controls.overlay_alpha, SettingsPage.controls.overlay_alpha_val, displayStyle.overlay_alpha)
    end

    if SettingsPage.controls.frame_width ~= nil then
        local fw = nil
        if type(displayStyle) == "table" then
            fw = tonumber(displayStyle.frame_width)
        end
        if fw == nil then
            fw = tonumber(s.frame_width)
        end
        refreshSlider(SettingsPage.controls.frame_width, SettingsPage.controls.frame_width_val, fw or 320)
    end
    if SettingsPage.controls.frame_height ~= nil then
        refreshSlider(SettingsPage.controls.frame_height, SettingsPage.controls.frame_height_val, tonumber(s.frame_height) or 64)
    end
    if SettingsPage.controls.frame_scale ~= nil then
        local fs = nil
        if type(displayStyle) == "table" then
            fs = tonumber(displayStyle.frame_scale)
        end
        if fs == nil then
            fs = tonumber(s.frame_scale)
        end
        local pct = math.floor(((tonumber(fs) or 1) * 100) + 0.5)
        if pct < 50 then
            pct = 50
        elseif pct > 150 then
            pct = 150
        end
        refreshSlider(SettingsPage.controls.frame_scale, SettingsPage.controls.frame_scale_val, pct)
    end
    if SettingsPage.controls.bar_height ~= nil then
        local bh = nil
        if type(displayStyle) == "table" then
            bh = tonumber(displayStyle.bar_height)
        end
        if bh == nil then
            bh = tonumber(s.bar_height)
        end
        refreshSlider(SettingsPage.controls.bar_height, SettingsPage.controls.bar_height_val, bh or 18)
    end
    if SettingsPage.controls.hp_bar_height ~= nil then
        local hpBh = nil
        if type(displayStyle) == "table" then
            hpBh = tonumber(displayStyle.hp_bar_height) or tonumber(displayStyle.bar_height)
        end
        if hpBh == nil then
            hpBh = tonumber(s.bar_height)
        end
        refreshSlider(SettingsPage.controls.hp_bar_height, SettingsPage.controls.hp_bar_height_val, hpBh or 18)
    end
    if SettingsPage.controls.mp_bar_height ~= nil then
        local mpBh = nil
        if type(displayStyle) == "table" then
            mpBh = tonumber(displayStyle.mp_bar_height) or tonumber(displayStyle.bar_height)
        end
        if mpBh == nil then
            mpBh = tonumber(s.bar_height)
        end
        refreshSlider(SettingsPage.controls.mp_bar_height, SettingsPage.controls.mp_bar_height_val, mpBh or 18)
    end
    if SettingsPage.controls.bar_gap ~= nil then
        local gap = 0
        if type(displayStyle) == "table" and displayStyle.bar_gap ~= nil then
            gap = tonumber(displayStyle.bar_gap) or 0
        end
        refreshSlider(SettingsPage.controls.bar_gap, SettingsPage.controls.bar_gap_val, gap)
    end
    if type(s.nameplates) == "table" then
        if SettingsPage.controls.plates_enabled ~= nil then
            SettingsPage.controls.plates_enabled:SetChecked(s.nameplates.enabled and true or false)
        end
        if SettingsPage.controls.plates_guild_only ~= nil then
            SettingsPage.controls.plates_guild_only:SetChecked(s.nameplates.guild_only and true or false)
        end
        if SettingsPage.controls.plates_show_target ~= nil then
            SettingsPage.controls.plates_show_target:SetChecked(s.nameplates.show_target ~= false)
        end
        if SettingsPage.controls.plates_show_player ~= nil then
            SettingsPage.controls.plates_show_player:SetChecked(s.nameplates.show_player and true or false)
        end
        if SettingsPage.controls.plates_show_raid_party ~= nil then
            SettingsPage.controls.plates_show_raid_party:SetChecked(s.nameplates.show_raid_party ~= false)
        end
        if SettingsPage.controls.plates_show_watchtarget ~= nil then
            SettingsPage.controls.plates_show_watchtarget:SetChecked(s.nameplates.show_watchtarget ~= false)
        end
        if SettingsPage.controls.plates_show_mount ~= nil then
            SettingsPage.controls.plates_show_mount:SetChecked(s.nameplates.show_mount ~= false)
        end
        if SettingsPage.controls.plates_show_guild ~= nil then
            SettingsPage.controls.plates_show_guild:SetChecked(s.nameplates.show_guild ~= false)
        end
        if SettingsPage.controls.plates_runtime_status ~= nil and SettingsPage.controls.plates_runtime_status.SetText ~= nil then
            local runtimeText = Compat ~= nil and Compat.GetStatusText() or "Runtime OK"
            SettingsPage.controls.plates_runtime_status:SetText(runtimeText)
        end
        if SettingsPage.controls.plates_alpha ~= nil then
            refreshSlider(SettingsPage.controls.plates_alpha, SettingsPage.controls.plates_alpha_val, tonumber(s.nameplates.alpha_pct) or 100)
        end
        if SettingsPage.controls.plates_width ~= nil then
            refreshSlider(SettingsPage.controls.plates_width, SettingsPage.controls.plates_width_val, tonumber(s.nameplates.width) or 100)
        end
        if SettingsPage.controls.plates_hp_h ~= nil then
            refreshSlider(SettingsPage.controls.plates_hp_h, SettingsPage.controls.plates_hp_h_val, tonumber(s.nameplates.hp_height) or 28)
        end
        if SettingsPage.controls.plates_mp_h ~= nil then
            refreshSlider(SettingsPage.controls.plates_mp_h, SettingsPage.controls.plates_mp_h_val, tonumber(s.nameplates.mp_height) or 4)
        end
        if SettingsPage.controls.plates_x_offset ~= nil then
            refreshSlider(SettingsPage.controls.plates_x_offset, SettingsPage.controls.plates_x_offset_val, tonumber(s.nameplates.x_offset) or 0)
        end
        if SettingsPage.controls.plates_max_dist ~= nil then
            refreshSlider(SettingsPage.controls.plates_max_dist, SettingsPage.controls.plates_max_dist_val, tonumber(s.nameplates.max_distance) or 130)
        end
        if SettingsPage.controls.plates_y_offset ~= nil then
            refreshSlider(SettingsPage.controls.plates_y_offset, SettingsPage.controls.plates_y_offset_val, tonumber(s.nameplates.y_offset) or 22)
        end
        if SettingsPage.controls.plates_anchor_tag ~= nil then
            SettingsPage.controls.plates_anchor_tag:SetChecked(s.nameplates.anchor_to_nametag ~= false)
        end
        if SettingsPage.controls.plates_bg_enabled ~= nil then
            SettingsPage.controls.plates_bg_enabled:SetChecked(s.nameplates.bg_enabled ~= false)
        end
        if SettingsPage.controls.plates_bg_alpha ~= nil then
            refreshSlider(SettingsPage.controls.plates_bg_alpha, SettingsPage.controls.plates_bg_alpha_val, tonumber(s.nameplates.bg_alpha_pct) or 80)
        end
        if SettingsPage.controls.plates_name_fs ~= nil then
            refreshSlider(SettingsPage.controls.plates_name_fs, SettingsPage.controls.plates_name_fs_val, tonumber(s.nameplates.name_font_size) or 14)
        end
        if SettingsPage.controls.plates_guild_fs ~= nil then
            refreshSlider(SettingsPage.controls.plates_guild_fs, SettingsPage.controls.plates_guild_fs_val, tonumber(s.nameplates.guild_font_size) or 11)
        end

        if SettingsPage.controls.plates_guild_color_r ~= nil then
            refreshSlider(SettingsPage.controls.plates_guild_color_r, SettingsPage.controls.plates_guild_color_r_val, 255)
        end
        if SettingsPage.controls.plates_guild_color_g ~= nil then
            refreshSlider(SettingsPage.controls.plates_guild_color_g, SettingsPage.controls.plates_guild_color_g_val, 255)
        end
        if SettingsPage.controls.plates_guild_color_b ~= nil then
            refreshSlider(SettingsPage.controls.plates_guild_color_b, SettingsPage.controls.plates_guild_color_b_val, 255)
        end

        if type(s.nameplates.guild_colors) ~= "table" then
            s.nameplates.guild_colors = {}
        end

        if type(SettingsPage.controls.plates_guild_color_rows) == "table" then
            local keys = {}
            for k, _ in pairs(s.nameplates.guild_colors) do
                table.insert(keys, tostring(k))
            end
            table.sort(keys)

            for i, row in ipairs(SettingsPage.controls.plates_guild_color_rows) do
                local key = keys[i]
                local show = key ~= nil and key ~= ""

                if type(row) == "table" then
                    if row.label ~= nil and row.label.SetText ~= nil then
                        if show then
                            local rgba = s.nameplates.guild_colors[key]
                            local r01 = type(rgba) == "table" and tonumber(rgba[1]) or 1
                            local g01 = type(rgba) == "table" and tonumber(rgba[2]) or 1
                            local b01 = type(rgba) == "table" and tonumber(rgba[3]) or 1
                            local r = math.floor((r01 * 255) + 0.5)
                            local g = math.floor((g01 * 255) + 0.5)
                            local b = math.floor((b01 * 255) + 0.5)
                            row.label:SetText(string.format("%s  (%d, %d, %d)", tostring(key), r, g, b))
                        else
                            row.label:SetText("")
                        end
                    end

                    if row.label ~= nil and row.label.Show ~= nil then
                        row.label:Show(show)
                    end

                    if row.remove ~= nil then
                        row.remove.__polar_guild_key = key
                        if row.remove.Show ~= nil then
                            row.remove:Show(show)
                        end
                    end
                end
            end
        end
    end

    if type(displayStyle) == "table" then
        if SettingsPage.controls.name_visible ~= nil then
            SettingsPage.controls.name_visible:SetChecked(displayStyle.name_visible ~= false)
        end
        if SettingsPage.controls.name_offset_x ~= nil then
            refreshSlider(SettingsPage.controls.name_offset_x, SettingsPage.controls.name_offset_x_val, tonumber(displayStyle.name_offset_x) or 0)
        end
        if SettingsPage.controls.name_offset_y ~= nil then
            refreshSlider(SettingsPage.controls.name_offset_y, SettingsPage.controls.name_offset_y_val, tonumber(displayStyle.name_offset_y) or 0)
        end

        if SettingsPage.controls.level_visible ~= nil then
            SettingsPage.controls.level_visible:SetChecked(displayStyle.level_visible ~= false)
        end
        if SettingsPage.controls.level_font_size ~= nil then
            refreshSlider(SettingsPage.controls.level_font_size, SettingsPage.controls.level_font_size_val, tonumber(displayStyle.level_font_size) or 12)
        end
        if SettingsPage.controls.level_offset_x ~= nil then
            refreshSlider(SettingsPage.controls.level_offset_x, SettingsPage.controls.level_offset_x_val, tonumber(displayStyle.level_offset_x) or 0)
        end
        if SettingsPage.controls.level_offset_y ~= nil then
            refreshSlider(SettingsPage.controls.level_offset_y, SettingsPage.controls.level_offset_y_val, tonumber(displayStyle.level_offset_y) or 0)
        end

        if SettingsPage.controls.name_font_size ~= nil then
            refreshSlider(SettingsPage.controls.name_font_size, SettingsPage.controls.name_font_size_val, tonumber(displayStyle.name_font_size) or 14)
        end
        if SettingsPage.controls.hp_font_size ~= nil then
            refreshSlider(SettingsPage.controls.hp_font_size, SettingsPage.controls.hp_font_size_val, tonumber(displayStyle.hp_font_size) or 16)
        end
        if SettingsPage.controls.mp_font_size ~= nil then
            refreshSlider(SettingsPage.controls.mp_font_size, SettingsPage.controls.mp_font_size_val, tonumber(displayStyle.mp_font_size) or 11)
        end
        if SettingsPage.controls.overlay_font_size ~= nil then
            refreshSlider(SettingsPage.controls.overlay_font_size, SettingsPage.controls.overlay_font_size_val, tonumber(displayStyle.overlay_font_size) or 12)
        end

        if SettingsPage.controls.gs_font_size ~= nil then
            refreshSlider(SettingsPage.controls.gs_font_size, SettingsPage.controls.gs_font_size_val, tonumber(displayStyle.gs_font_size) or (tonumber(displayStyle.overlay_font_size) or 12))
        end
        if SettingsPage.controls.class_font_size ~= nil then
            refreshSlider(SettingsPage.controls.class_font_size, SettingsPage.controls.class_font_size_val, tonumber(displayStyle.class_font_size) or (tonumber(displayStyle.overlay_font_size) or 12))
        end
        if SettingsPage.controls.target_guild_font_size ~= nil then
            refreshSlider(
                SettingsPage.controls.target_guild_font_size,
                SettingsPage.controls.target_guild_font_size_val,
                tonumber(displayStyle.target_guild_font_size) or (tonumber(displayStyle.overlay_font_size) or 12)
            )
        end
        if SettingsPage.controls.target_guild_visible ~= nil then
            SettingsPage.controls.target_guild_visible:SetChecked(displayStyle.target_guild_visible ~= false)
        end
        if SettingsPage.controls.target_class_visible ~= nil then
            SettingsPage.controls.target_class_visible:SetChecked(displayStyle.target_class_visible ~= false)
        end
        if SettingsPage.controls.target_gearscore_visible ~= nil then
            SettingsPage.controls.target_gearscore_visible:SetChecked(displayStyle.target_gearscore_visible ~= false)
        end
        if SettingsPage.controls.target_pdef_visible ~= nil then
            SettingsPage.controls.target_pdef_visible:SetChecked(displayStyle.target_pdef_visible ~= false)
        end
        if SettingsPage.controls.target_mdef_visible ~= nil then
            SettingsPage.controls.target_mdef_visible:SetChecked(displayStyle.target_mdef_visible ~= false)
        end

        if SettingsPage.controls.name_shadow ~= nil then
            SettingsPage.controls.name_shadow:SetChecked(displayStyle.name_shadow and true or false)
        end
        if SettingsPage.controls.value_shadow ~= nil then
            SettingsPage.controls.value_shadow:SetChecked(displayStyle.value_shadow ~= false)
        end
        if SettingsPage.controls.overlay_shadow ~= nil then
            SettingsPage.controls.overlay_shadow:SetChecked(displayStyle.overlay_shadow ~= false)
        end

        if SettingsPage.controls.hp_value_offset_x ~= nil then
            refreshSlider(SettingsPage.controls.hp_value_offset_x, SettingsPage.controls.hp_value_offset_x_val, tonumber(displayStyle.hp_value_offset_x) or 0)
        end
        if SettingsPage.controls.hp_value_offset_y ~= nil then
            refreshSlider(SettingsPage.controls.hp_value_offset_y, SettingsPage.controls.hp_value_offset_y_val, tonumber(displayStyle.hp_value_offset_y) or 0)
        end
        if SettingsPage.controls.mp_value_offset_x ~= nil then
            refreshSlider(SettingsPage.controls.mp_value_offset_x, SettingsPage.controls.mp_value_offset_x_val, tonumber(displayStyle.mp_value_offset_x) or 0)
        end
        if SettingsPage.controls.mp_value_offset_y ~= nil then
            refreshSlider(SettingsPage.controls.mp_value_offset_y, SettingsPage.controls.mp_value_offset_y_val, tonumber(displayStyle.mp_value_offset_y) or 0)
        end

        if SettingsPage.controls.target_guild_offset_x ~= nil then
            refreshSlider(
                SettingsPage.controls.target_guild_offset_x,
                SettingsPage.controls.target_guild_offset_x_val,
                tonumber(displayStyle.target_guild_offset_x) or 10
            )
        end
        if SettingsPage.controls.target_guild_offset_y ~= nil then
            refreshSlider(
                SettingsPage.controls.target_guild_offset_y,
                SettingsPage.controls.target_guild_offset_y_val,
                tonumber(displayStyle.target_guild_offset_y) or -18
            )
        end

        local guildColor = type(displayStyle.target_guild_color) == "table" and displayStyle.target_guild_color or { 255, 255, 255, 255 }
        local classColor = type(displayStyle.target_class_color) == "table" and displayStyle.target_class_color or { 255, 255, 255, 255 }
        local gearscoreColor = type(displayStyle.target_gearscore_color) == "table" and displayStyle.target_gearscore_color or { 255, 255, 255, 255 }
        local pdefColor = type(displayStyle.target_pdef_color) == "table" and displayStyle.target_pdef_color or { 255, 255, 255, 255 }
        local mdefColor = type(displayStyle.target_mdef_color) == "table" and displayStyle.target_mdef_color or { 255, 255, 255, 255 }

        if SettingsPage.controls.target_guild_r ~= nil then
            refreshSlider(SettingsPage.controls.target_guild_r, SettingsPage.controls.target_guild_r_val, tonumber(guildColor[1]) or 255)
        end
        if SettingsPage.controls.target_guild_g ~= nil then
            refreshSlider(SettingsPage.controls.target_guild_g, SettingsPage.controls.target_guild_g_val, tonumber(guildColor[2]) or 255)
        end
        if SettingsPage.controls.target_guild_b ~= nil then
            refreshSlider(SettingsPage.controls.target_guild_b, SettingsPage.controls.target_guild_b_val, tonumber(guildColor[3]) or 255)
        end
        if SettingsPage.controls.target_class_r ~= nil then
            refreshSlider(SettingsPage.controls.target_class_r, SettingsPage.controls.target_class_r_val, tonumber(classColor[1]) or 255)
        end
        if SettingsPage.controls.target_class_g ~= nil then
            refreshSlider(SettingsPage.controls.target_class_g, SettingsPage.controls.target_class_g_val, tonumber(classColor[2]) or 255)
        end
        if SettingsPage.controls.target_class_b ~= nil then
            refreshSlider(SettingsPage.controls.target_class_b, SettingsPage.controls.target_class_b_val, tonumber(classColor[3]) or 255)
        end
        if SettingsPage.controls.target_gearscore_r ~= nil then
            refreshSlider(SettingsPage.controls.target_gearscore_r, SettingsPage.controls.target_gearscore_r_val, tonumber(gearscoreColor[1]) or 255)
        end
        if SettingsPage.controls.target_gearscore_g ~= nil then
            refreshSlider(SettingsPage.controls.target_gearscore_g, SettingsPage.controls.target_gearscore_g_val, tonumber(gearscoreColor[2]) or 255)
        end
        if SettingsPage.controls.target_gearscore_b ~= nil then
            refreshSlider(SettingsPage.controls.target_gearscore_b, SettingsPage.controls.target_gearscore_b_val, tonumber(gearscoreColor[3]) or 255)
        end
        if SettingsPage.controls.target_pdef_r ~= nil then
            refreshSlider(SettingsPage.controls.target_pdef_r, SettingsPage.controls.target_pdef_r_val, tonumber(pdefColor[1]) or 255)
        end
        if SettingsPage.controls.target_pdef_g ~= nil then
            refreshSlider(SettingsPage.controls.target_pdef_g, SettingsPage.controls.target_pdef_g_val, tonumber(pdefColor[2]) or 255)
        end
        if SettingsPage.controls.target_pdef_b ~= nil then
            refreshSlider(SettingsPage.controls.target_pdef_b, SettingsPage.controls.target_pdef_b_val, tonumber(pdefColor[3]) or 255)
        end
        if SettingsPage.controls.target_mdef_r ~= nil then
            refreshSlider(SettingsPage.controls.target_mdef_r, SettingsPage.controls.target_mdef_r_val, tonumber(mdefColor[1]) or 255)
        end
        if SettingsPage.controls.target_mdef_g ~= nil then
            refreshSlider(SettingsPage.controls.target_mdef_g, SettingsPage.controls.target_mdef_g_val, tonumber(mdefColor[2]) or 255)
        end
        if SettingsPage.controls.target_mdef_b ~= nil then
            refreshSlider(SettingsPage.controls.target_mdef_b, SettingsPage.controls.target_mdef_b_val, tonumber(mdefColor[3]) or 255)
        end

        if SettingsPage.controls.bar_colors_enabled ~= nil then
            SettingsPage.controls.bar_colors_enabled:SetChecked(displayStyle.bar_colors_enabled and true or false)
        end

        local hpFill = type(displayStyle.hp_fill_color) == "table" and displayStyle.hp_fill_color or (type(displayStyle.hp_bar_color) == "table" and displayStyle.hp_bar_color or {})
        local hpAfter = type(displayStyle.hp_after_color) == "table" and displayStyle.hp_after_color or (type(displayStyle.hp_bar_color) == "table" and displayStyle.hp_bar_color or {})
        local mpFill = type(displayStyle.mp_fill_color) == "table" and displayStyle.mp_fill_color or (type(displayStyle.mp_bar_color) == "table" and displayStyle.mp_bar_color or {})
        local mpAfter = type(displayStyle.mp_after_color) == "table" and displayStyle.mp_after_color or (type(displayStyle.mp_bar_color) == "table" and displayStyle.mp_bar_color or {})

        if SettingsPage.controls.hp_r ~= nil then
            refreshSlider(SettingsPage.controls.hp_r, SettingsPage.controls.hp_r_val, tonumber(hpFill[1]) or 223)
        end
        if SettingsPage.controls.hp_g ~= nil then
            refreshSlider(SettingsPage.controls.hp_g, SettingsPage.controls.hp_g_val, tonumber(hpFill[2]) or 69)
        end
        if SettingsPage.controls.hp_b ~= nil then
            refreshSlider(SettingsPage.controls.hp_b, SettingsPage.controls.hp_b_val, tonumber(hpFill[3]) or 69)
        end
        if SettingsPage.controls.hp_a ~= nil then
            refreshSlider(SettingsPage.controls.hp_a, SettingsPage.controls.hp_a_val, tonumber(hpFill[4]) or 255)
        end

        if SettingsPage.controls.hp_after_r ~= nil then
            refreshSlider(SettingsPage.controls.hp_after_r, SettingsPage.controls.hp_after_r_val, tonumber(hpAfter[1]) or 223)
        end
        if SettingsPage.controls.hp_after_g ~= nil then
            refreshSlider(SettingsPage.controls.hp_after_g, SettingsPage.controls.hp_after_g_val, tonumber(hpAfter[2]) or 69)
        end
        if SettingsPage.controls.hp_after_b ~= nil then
            refreshSlider(SettingsPage.controls.hp_after_b, SettingsPage.controls.hp_after_b_val, tonumber(hpAfter[3]) or 69)
        end
        if SettingsPage.controls.hp_after_a ~= nil then
            refreshSlider(SettingsPage.controls.hp_after_a, SettingsPage.controls.hp_after_a_val, tonumber(hpAfter[4]) or 255)
        end

        if SettingsPage.controls.mp_r ~= nil then
            refreshSlider(SettingsPage.controls.mp_r, SettingsPage.controls.mp_r_val, tonumber(mpFill[1]) or 86)
        end
        if SettingsPage.controls.mp_g ~= nil then
            refreshSlider(SettingsPage.controls.mp_g, SettingsPage.controls.mp_g_val, tonumber(mpFill[2]) or 198)
        end
        if SettingsPage.controls.mp_b ~= nil then
            refreshSlider(SettingsPage.controls.mp_b, SettingsPage.controls.mp_b_val, tonumber(mpFill[3]) or 239)
        end
        if SettingsPage.controls.mp_a ~= nil then
            refreshSlider(SettingsPage.controls.mp_a, SettingsPage.controls.mp_a_val, tonumber(mpFill[4]) or 255)
        end

        if SettingsPage.controls.mp_after_r ~= nil then
            refreshSlider(SettingsPage.controls.mp_after_r, SettingsPage.controls.mp_after_r_val, tonumber(mpAfter[1]) or 86)
        end
        if SettingsPage.controls.mp_after_g ~= nil then
            refreshSlider(SettingsPage.controls.mp_after_g, SettingsPage.controls.mp_after_g_val, tonumber(mpAfter[2]) or 198)
        end
        if SettingsPage.controls.mp_after_b ~= nil then
            refreshSlider(SettingsPage.controls.mp_after_b, SettingsPage.controls.mp_after_b_val, tonumber(mpAfter[3]) or 239)
        end
        if SettingsPage.controls.mp_after_a ~= nil then
            refreshSlider(SettingsPage.controls.mp_after_a, SettingsPage.controls.mp_after_a_val, tonumber(mpAfter[4]) or 255)
        end

        local tex = tostring(displayStyle.hp_texture_mode or "stock")
        SetHpTextureModeChecks(tex)
    end

    if type(displayStyle) == "table" then
        local fmt = tostring(displayStyle.value_format or "stock")
        if SettingsPage.controls.value_fmt_curmax ~= nil then
            SettingsPage.controls.value_fmt_curmax:SetChecked(fmt == "curmax" or fmt == "curmax_percent")
        end
        if SettingsPage.controls.value_fmt_percent ~= nil then
            SettingsPage.controls.value_fmt_percent:SetChecked(fmt == "percent" or fmt == "curmax_percent")
        end
        if SettingsPage.controls.short_numbers ~= nil then
            SettingsPage.controls.short_numbers:SetChecked(displayStyle.short_numbers and true or false)
        end
    end

    if type(s.style) == "table" and type(s.style.buff_windows) == "table" and SettingsPage.controls.move_buffs ~= nil then
        SettingsPage.controls.move_buffs:SetChecked(s.style.buff_windows.enabled and true or false)
    elseif SettingsPage.controls.move_buffs ~= nil then
        SettingsPage.controls.move_buffs:SetChecked(false)
    end

    local bw = (type(s.style) == "table" and type(s.style.buff_windows) == "table") and s.style.buff_windows or nil
    local aura = (type(s.style) == "table" and type(s.style.aura) == "table") and s.style.aura or nil

    if bw ~= nil then
        refreshSlider(SettingsPage.controls.p_buff_x, SettingsPage.controls.p_buff_x_val, bw.player.buff.x or 0)
        refreshSlider(SettingsPage.controls.p_buff_y, SettingsPage.controls.p_buff_y_val, bw.player.buff.y or 0)
        refreshSlider(SettingsPage.controls.p_debuff_x, SettingsPage.controls.p_debuff_x_val, bw.player.debuff.x or 0)
        refreshSlider(SettingsPage.controls.p_debuff_y, SettingsPage.controls.p_debuff_y_val, bw.player.debuff.y or 0)

        refreshSlider(SettingsPage.controls.t_buff_x, SettingsPage.controls.t_buff_x_val, bw.target.buff.x or 0)
        refreshSlider(SettingsPage.controls.t_buff_y, SettingsPage.controls.t_buff_y_val, bw.target.buff.y or 0)
        refreshSlider(SettingsPage.controls.t_debuff_x, SettingsPage.controls.t_debuff_x_val, bw.target.debuff.x or 0)
        refreshSlider(SettingsPage.controls.t_debuff_y, SettingsPage.controls.t_debuff_y_val, bw.target.debuff.y or 0)
    end

    if aura ~= nil then
        if SettingsPage.controls.aura_enabled ~= nil then
            SettingsPage.controls.aura_enabled:SetChecked(aura.enabled and true or false)
        end
        refreshSlider(SettingsPage.controls.aura_icon_size, SettingsPage.controls.aura_icon_size_val, aura.icon_size or 24)
        refreshSlider(SettingsPage.controls.aura_x_gap, SettingsPage.controls.aura_x_gap_val, aura.icon_x_gap or 2)
        refreshSlider(SettingsPage.controls.aura_y_gap, SettingsPage.controls.aura_y_gap_val, aura.icon_y_gap or 2)
        refreshSlider(SettingsPage.controls.aura_per_row, SettingsPage.controls.aura_per_row_val, aura.buffs_per_row or 10)
        if SettingsPage.controls.aura_sort_vertical ~= nil then
            SettingsPage.controls.aura_sort_vertical:SetChecked(aura.sort_vertical and true or false)
        end
    end

    EnsureCooldownTrackerTables(s)
    local tracker = type(s.cooldown_tracker) == "table" and s.cooldown_tracker or nil
    local trackerUnits = tracker ~= nil and type(tracker.units) == "table" and tracker.units or {}
    local selectedUnitKey = tostring(SettingsPage.cooldown_unit_key or "player")
    local selectedUnitCfg = type(trackerUnits[selectedUnitKey]) == "table" and trackerUnits[selectedUnitKey] or {}

    if SettingsPage.controls.ct_enabled ~= nil then
        SettingsPage.controls.ct_enabled:SetChecked(tracker ~= nil and tracker.enabled == true)
    end
    if SettingsPage.controls.ct_update_interval ~= nil then
        refreshSlider(
            SettingsPage.controls.ct_update_interval,
            SettingsPage.controls.ct_update_interval_val,
            tracker ~= nil and (tonumber(tracker.update_interval_ms) or 50) or 50
        )
    end
    if SettingsPage.controls.ct_unit ~= nil then
        SetComboBoxIndex1Based(SettingsPage.controls.ct_unit, GetCooldownUnitIndexFromKey(selectedUnitKey))
    end
    if SettingsPage.controls.ct_display_mode ~= nil then
        SetComboBoxIndex1Based(SettingsPage.controls.ct_display_mode, GetCooldownDisplayModeIndex(selectedUnitCfg.display_mode))
    end
    if SettingsPage.controls.ct_track_kind ~= nil then
        SetComboBoxIndex1Based(SettingsPage.controls.ct_track_kind, GetCooldownTrackKindIndex(SettingsPage.cooldown_track_kind))
    end
    if SettingsPage.controls.ct_position_hint ~= nil and SettingsPage.controls.ct_position_hint.SetText ~= nil then
        if selectedUnitKey == "player" then
            SettingsPage.controls.ct_position_hint:SetText("Player uses an absolute screen position.")
        else
            SettingsPage.controls.ct_position_hint:SetText("These values are offsets from the unit's overhead nameplate.")
        end
    end
    if SettingsPage.controls.ct_unit_enabled ~= nil then
        SettingsPage.controls.ct_unit_enabled:SetChecked(selectedUnitCfg.enabled == true)
    end
    if SettingsPage.controls.ct_lock_position ~= nil then
        SettingsPage.controls.ct_lock_position:SetChecked(selectedUnitCfg.lock_position == true)
    end
    if SettingsPage.controls.ct_pos_x ~= nil and SettingsPage.controls.ct_pos_x.SetText ~= nil then
        SettingsPage.controls.ct_pos_x:SetText(tostring(ClampInt(selectedUnitCfg.pos_x, -5000, 5000, 330)))
    end
    if SettingsPage.controls.ct_pos_y ~= nil and SettingsPage.controls.ct_pos_y.SetText ~= nil then
        SettingsPage.controls.ct_pos_y:SetText(tostring(ClampInt(selectedUnitCfg.pos_y, -5000, 5000, 100)))
    end
    if SettingsPage.controls.ct_icon_size ~= nil then
        refreshSlider(SettingsPage.controls.ct_icon_size, SettingsPage.controls.ct_icon_size_val, tonumber(selectedUnitCfg.icon_size) or 40)
    end
    if SettingsPage.controls.ct_icon_spacing ~= nil then
        refreshSlider(SettingsPage.controls.ct_icon_spacing, SettingsPage.controls.ct_icon_spacing_val, tonumber(selectedUnitCfg.icon_spacing) or 5)
    end
    if SettingsPage.controls.ct_max_icons ~= nil then
        refreshSlider(SettingsPage.controls.ct_max_icons, SettingsPage.controls.ct_max_icons_val, tonumber(selectedUnitCfg.max_icons) or 10)
    end
    if SettingsPage.controls.ct_show_timer ~= nil then
        SettingsPage.controls.ct_show_timer:SetChecked(selectedUnitCfg.show_timer ~= false)
    end
    if SettingsPage.controls.ct_timer_fs ~= nil then
        refreshSlider(SettingsPage.controls.ct_timer_fs, SettingsPage.controls.ct_timer_fs_val, tonumber(selectedUnitCfg.timer_font_size) or 16)
    end
    local timerColor = type(selectedUnitCfg.timer_color) == "table" and selectedUnitCfg.timer_color or { 255, 255, 255, 255 }
    if SettingsPage.controls.ct_timer_r ~= nil then
        refreshSlider(SettingsPage.controls.ct_timer_r, SettingsPage.controls.ct_timer_r_val, tonumber(timerColor[1]) or 255)
    end
    if SettingsPage.controls.ct_timer_g ~= nil then
        refreshSlider(SettingsPage.controls.ct_timer_g, SettingsPage.controls.ct_timer_g_val, tonumber(timerColor[2]) or 255)
    end
    if SettingsPage.controls.ct_timer_b ~= nil then
        refreshSlider(SettingsPage.controls.ct_timer_b, SettingsPage.controls.ct_timer_b_val, tonumber(timerColor[3]) or 255)
    end
    if SettingsPage.controls.ct_show_label ~= nil then
        SettingsPage.controls.ct_show_label:SetChecked(selectedUnitCfg.show_label == true)
    end
    if SettingsPage.controls.ct_label_fs ~= nil then
        refreshSlider(SettingsPage.controls.ct_label_fs, SettingsPage.controls.ct_label_fs_val, tonumber(selectedUnitCfg.label_font_size) or 14)
    end
    local labelColor = type(selectedUnitCfg.label_color) == "table" and selectedUnitCfg.label_color or { 255, 255, 255, 255 }
    if SettingsPage.controls.ct_label_r ~= nil then
        refreshSlider(SettingsPage.controls.ct_label_r, SettingsPage.controls.ct_label_r_val, tonumber(labelColor[1]) or 255)
    end
    if SettingsPage.controls.ct_label_g ~= nil then
        refreshSlider(SettingsPage.controls.ct_label_g, SettingsPage.controls.ct_label_g_val, tonumber(labelColor[2]) or 255)
    end
    if SettingsPage.controls.ct_label_b ~= nil then
        refreshSlider(SettingsPage.controls.ct_label_b, SettingsPage.controls.ct_label_b_val, tonumber(labelColor[3]) or 255)
    end
    if SettingsPage.controls.ct_cache_timeout ~= nil then
        refreshSlider(SettingsPage.controls.ct_cache_timeout, SettingsPage.controls.ct_cache_timeout_val, tonumber(selectedUnitCfg.cache_timeout_s) or 300)
    end
    RefreshCooldownSearchRows()
    RefreshCooldownBuffRows(selectedUnitCfg)
    RefreshCooldownScanRows()

end

local function ApplyControlsToSettings()
    local s = SettingsPage.settings
    if s == nil then
        return
    end
    s.enabled = (SettingsPage.controls.enabled ~= nil and SettingsPage.controls.enabled:GetChecked()) and true or false

    if SettingsPage.controls.alignment_grid_enabled ~= nil then
        s.alignment_grid_enabled = SettingsPage.controls.alignment_grid_enabled:GetChecked() and true or false
    end

    if SettingsPage.controls.launcher_size ~= nil then
        if type(s.settings_button) ~= "table" then
            s.settings_button = {}
        end
        s.settings_button.size = GetSliderValue(SettingsPage.controls.launcher_size)
        ApplySettingsButtonLayout()
    end

    EnsureStyleFrames(s)
    if type(s.style) ~= "table" then
        s.style = {}
    end
    local _, editStyle = GetStyleTables(s)
    if SettingsPage.style_target == "all" then
        editStyle = s.style
    end
    if type(editStyle) ~= "table" then
        editStyle = s.style
    end
    if type(editStyle) ~= "table" then
        editStyle = {}
        s.style = editStyle
    end

    local function colorTable(r, g, b, a)
        return { r, g, b, a or 255 }
    end

    if type(s.nameplates) ~= "table" then
        s.nameplates = {}
    end

    if SettingsPage.controls.plates_enabled ~= nil then
        s.nameplates.enabled = SettingsPage.controls.plates_enabled:GetChecked() and true or false
    end
    if SettingsPage.controls.plates_guild_only ~= nil then
        s.nameplates.guild_only = SettingsPage.controls.plates_guild_only:GetChecked() and true or false
    end
    if SettingsPage.controls.plates_show_target ~= nil then
        s.nameplates.show_target = SettingsPage.controls.plates_show_target:GetChecked() and true or false
    end
    if SettingsPage.controls.plates_show_player ~= nil then
        s.nameplates.show_player = SettingsPage.controls.plates_show_player:GetChecked() and true or false
    end
    if SettingsPage.controls.plates_show_raid_party ~= nil then
        s.nameplates.show_raid_party = SettingsPage.controls.plates_show_raid_party:GetChecked() and true or false
    end
    if SettingsPage.controls.plates_show_watchtarget ~= nil then
        s.nameplates.show_watchtarget = SettingsPage.controls.plates_show_watchtarget:GetChecked() and true or false
    end
    if SettingsPage.controls.plates_show_mount ~= nil then
        s.nameplates.show_mount = SettingsPage.controls.plates_show_mount:GetChecked() and true or false
    end
    if SettingsPage.controls.plates_show_guild ~= nil then
        s.nameplates.show_guild = SettingsPage.controls.plates_show_guild:GetChecked() and true or false
    end
    if SettingsPage.controls.plates_alpha ~= nil then
        s.nameplates.alpha_pct = GetSliderValue(SettingsPage.controls.plates_alpha)
    end
    if SettingsPage.controls.plates_width ~= nil then
        s.nameplates.width = GetSliderValue(SettingsPage.controls.plates_width)
    end
    if SettingsPage.controls.plates_hp_h ~= nil then
        s.nameplates.hp_height = GetSliderValue(SettingsPage.controls.plates_hp_h)
    end
    if SettingsPage.controls.plates_mp_h ~= nil then
        s.nameplates.mp_height = GetSliderValue(SettingsPage.controls.plates_mp_h)
    end
    if SettingsPage.controls.plates_x_offset ~= nil then
        s.nameplates.x_offset = GetSliderValue(SettingsPage.controls.plates_x_offset)
    end
    if SettingsPage.controls.plates_max_dist ~= nil then
        s.nameplates.max_distance = GetSliderValue(SettingsPage.controls.plates_max_dist)
    end
    if SettingsPage.controls.plates_y_offset ~= nil then
        s.nameplates.y_offset = GetSliderValue(SettingsPage.controls.plates_y_offset)
    end
    if SettingsPage.controls.plates_anchor_tag ~= nil then
        s.nameplates.anchor_to_nametag = SettingsPage.controls.plates_anchor_tag:GetChecked() and true or false
    end
    if SettingsPage.controls.plates_bg_enabled ~= nil then
        s.nameplates.bg_enabled = SettingsPage.controls.plates_bg_enabled:GetChecked() and true or false
    end
    if SettingsPage.controls.plates_bg_alpha ~= nil then
        s.nameplates.bg_alpha_pct = GetSliderValue(SettingsPage.controls.plates_bg_alpha)
    end
    if SettingsPage.controls.plates_name_fs ~= nil then
        s.nameplates.name_font_size = GetSliderValue(SettingsPage.controls.plates_name_fs)
    end
    if SettingsPage.controls.plates_guild_fs ~= nil then
        s.nameplates.guild_font_size = GetSliderValue(SettingsPage.controls.plates_guild_fs)
    end

    if SettingsPage.controls.large_hpmp ~= nil then
        s.style.large_hpmp = SettingsPage.controls.large_hpmp:GetChecked() and true or false
    end

    if SettingsPage.controls.show_distance ~= nil then
        s.show_distance = SettingsPage.controls.show_distance:GetChecked() and true or false
    end

    if SettingsPage.controls.frame_alpha ~= nil then
        editStyle.frame_alpha = GetSliderValue(SettingsPage.controls.frame_alpha) / 100
    end

    if SettingsPage.controls.frame_width ~= nil then
        editStyle.frame_width = GetSliderValue(SettingsPage.controls.frame_width)
    end

    if SettingsPage.controls.frame_height ~= nil then
        s.frame_height = GetSliderValue(SettingsPage.controls.frame_height)
    end

    if SettingsPage.controls.frame_scale ~= nil then
        editStyle.frame_scale = GetSliderValue(SettingsPage.controls.frame_scale) / 100
    end

    if SettingsPage.controls.bar_height ~= nil then
        editStyle.bar_height = GetSliderValue(SettingsPage.controls.bar_height)
    end
    if SettingsPage.controls.hp_bar_height ~= nil then
        editStyle.hp_bar_height = GetSliderValue(SettingsPage.controls.hp_bar_height)
    end
    if SettingsPage.controls.mp_bar_height ~= nil then
        editStyle.mp_bar_height = GetSliderValue(SettingsPage.controls.mp_bar_height)
    end
    if SettingsPage.controls.bar_gap ~= nil then
        editStyle.bar_gap = GetSliderValue(SettingsPage.controls.bar_gap)
    end
    if SettingsPage.controls.name_visible ~= nil then
        editStyle.name_visible = SettingsPage.controls.name_visible:GetChecked() and true or false
    end
    if SettingsPage.controls.name_offset_x ~= nil then
        editStyle.name_offset_x = GetSliderValue(SettingsPage.controls.name_offset_x)
    end
    if SettingsPage.controls.name_offset_y ~= nil then
        editStyle.name_offset_y = GetSliderValue(SettingsPage.controls.name_offset_y)
    end

    if SettingsPage.controls.level_visible ~= nil then
        editStyle.level_visible = SettingsPage.controls.level_visible:GetChecked() and true or false
    end
    if SettingsPage.controls.level_font_size ~= nil then
        editStyle.level_font_size = GetSliderValue(SettingsPage.controls.level_font_size)
    end
    if SettingsPage.controls.level_offset_x ~= nil then
        editStyle.level_offset_x = GetSliderValue(SettingsPage.controls.level_offset_x)
    end
    if SettingsPage.controls.level_offset_y ~= nil then
        editStyle.level_offset_y = GetSliderValue(SettingsPage.controls.level_offset_y)
    end

    if SettingsPage.controls.name_font_size ~= nil then
        editStyle.name_font_size = GetSliderValue(SettingsPage.controls.name_font_size)
    end
    if SettingsPage.controls.hp_font_size ~= nil then
        editStyle.hp_font_size = GetSliderValue(SettingsPage.controls.hp_font_size)
    end
    if SettingsPage.controls.mp_font_size ~= nil then
        editStyle.mp_font_size = GetSliderValue(SettingsPage.controls.mp_font_size)
    end
    if SettingsPage.controls.overlay_font_size ~= nil then
        editStyle.overlay_font_size = GetSliderValue(SettingsPage.controls.overlay_font_size)
    end

    if SettingsPage.controls.gs_font_size ~= nil then
        editStyle.gs_font_size = GetSliderValue(SettingsPage.controls.gs_font_size)
    end
    if SettingsPage.controls.class_font_size ~= nil then
        editStyle.class_font_size = GetSliderValue(SettingsPage.controls.class_font_size)
    end
    if SettingsPage.controls.target_guild_font_size ~= nil then
        editStyle.target_guild_font_size = GetSliderValue(SettingsPage.controls.target_guild_font_size)
    end
    if SettingsPage.controls.target_guild_visible ~= nil then
        editStyle.target_guild_visible = SettingsPage.controls.target_guild_visible:GetChecked() and true or false
    end
    if SettingsPage.controls.target_class_visible ~= nil then
        editStyle.target_class_visible = SettingsPage.controls.target_class_visible:GetChecked() and true or false
    end
    if SettingsPage.controls.target_gearscore_visible ~= nil then
        editStyle.target_gearscore_visible = SettingsPage.controls.target_gearscore_visible:GetChecked() and true or false
    end
    if SettingsPage.controls.target_pdef_visible ~= nil then
        editStyle.target_pdef_visible = SettingsPage.controls.target_pdef_visible:GetChecked() and true or false
    end
    if SettingsPage.controls.target_mdef_visible ~= nil then
        editStyle.target_mdef_visible = SettingsPage.controls.target_mdef_visible:GetChecked() and true or false
    end

    if SettingsPage.controls.name_shadow ~= nil then
        editStyle.name_shadow = SettingsPage.controls.name_shadow:GetChecked() and true or false
    end
    if SettingsPage.controls.value_shadow ~= nil then
        editStyle.value_shadow = SettingsPage.controls.value_shadow:GetChecked() and true or false
    end
    if SettingsPage.controls.overlay_shadow ~= nil then
        editStyle.overlay_shadow = SettingsPage.controls.overlay_shadow:GetChecked() and true or false
    end

    if SettingsPage.controls.hp_value_offset_x ~= nil then
        editStyle.hp_value_offset_x = GetSliderValue(SettingsPage.controls.hp_value_offset_x)
    end
    if SettingsPage.controls.hp_value_offset_y ~= nil then
        editStyle.hp_value_offset_y = GetSliderValue(SettingsPage.controls.hp_value_offset_y)
    end
    if SettingsPage.controls.mp_value_offset_x ~= nil then
        editStyle.mp_value_offset_x = GetSliderValue(SettingsPage.controls.mp_value_offset_x)
    end
    if SettingsPage.controls.mp_value_offset_y ~= nil then
        editStyle.mp_value_offset_y = GetSliderValue(SettingsPage.controls.mp_value_offset_y)
    end

    if SettingsPage.controls.target_guild_offset_x ~= nil then
        editStyle.target_guild_offset_x = GetSliderValue(SettingsPage.controls.target_guild_offset_x)
    end
    if SettingsPage.controls.target_guild_offset_y ~= nil then
        editStyle.target_guild_offset_y = GetSliderValue(SettingsPage.controls.target_guild_offset_y)
    end
    if SettingsPage.controls.target_guild_r ~= nil and SettingsPage.controls.target_guild_g ~= nil and SettingsPage.controls.target_guild_b ~= nil then
        editStyle.target_guild_color = colorTable(
            GetSliderValue(SettingsPage.controls.target_guild_r),
            GetSliderValue(SettingsPage.controls.target_guild_g),
            GetSliderValue(SettingsPage.controls.target_guild_b),
            255
        )
    end
    if SettingsPage.controls.target_class_r ~= nil and SettingsPage.controls.target_class_g ~= nil and SettingsPage.controls.target_class_b ~= nil then
        editStyle.target_class_color = colorTable(
            GetSliderValue(SettingsPage.controls.target_class_r),
            GetSliderValue(SettingsPage.controls.target_class_g),
            GetSliderValue(SettingsPage.controls.target_class_b),
            255
        )
    end
    if SettingsPage.controls.target_gearscore_r ~= nil and SettingsPage.controls.target_gearscore_g ~= nil and SettingsPage.controls.target_gearscore_b ~= nil then
        editStyle.target_gearscore_color = colorTable(
            GetSliderValue(SettingsPage.controls.target_gearscore_r),
            GetSliderValue(SettingsPage.controls.target_gearscore_g),
            GetSliderValue(SettingsPage.controls.target_gearscore_b),
            255
        )
    end
    if SettingsPage.controls.target_pdef_r ~= nil and SettingsPage.controls.target_pdef_g ~= nil and SettingsPage.controls.target_pdef_b ~= nil then
        editStyle.target_pdef_color = colorTable(
            GetSliderValue(SettingsPage.controls.target_pdef_r),
            GetSliderValue(SettingsPage.controls.target_pdef_g),
            GetSliderValue(SettingsPage.controls.target_pdef_b),
            255
        )
    end
    if SettingsPage.controls.target_mdef_r ~= nil and SettingsPage.controls.target_mdef_g ~= nil and SettingsPage.controls.target_mdef_b ~= nil then
        editStyle.target_mdef_color = colorTable(
            GetSliderValue(SettingsPage.controls.target_mdef_r),
            GetSliderValue(SettingsPage.controls.target_mdef_g),
            GetSliderValue(SettingsPage.controls.target_mdef_b),
            255
        )
    end

    if SettingsPage.controls.bar_colors_enabled ~= nil then
        editStyle.bar_colors_enabled = SettingsPage.controls.bar_colors_enabled:GetChecked() and true or false
    end

    local function sliderOr(slider, fallback)
        if slider ~= nil then
            return GetSliderValue(slider)
        end
        return fallback
    end
    if SettingsPage.controls.hp_r ~= nil and SettingsPage.controls.hp_g ~= nil and SettingsPage.controls.hp_b ~= nil then
        local fill = colorTable(
            GetSliderValue(SettingsPage.controls.hp_r),
            GetSliderValue(SettingsPage.controls.hp_g),
            GetSliderValue(SettingsPage.controls.hp_b),
            sliderOr(SettingsPage.controls.hp_a, 255)
        )
        editStyle.hp_fill_color = fill
        editStyle.hp_bar_color = fill
    end
    if SettingsPage.controls.hp_after_r ~= nil and SettingsPage.controls.hp_after_g ~= nil and SettingsPage.controls.hp_after_b ~= nil then
        editStyle.hp_after_color = colorTable(
            GetSliderValue(SettingsPage.controls.hp_after_r),
            GetSliderValue(SettingsPage.controls.hp_after_g),
            GetSliderValue(SettingsPage.controls.hp_after_b),
            sliderOr(SettingsPage.controls.hp_after_a, 255)
        )
    end

    if SettingsPage.controls.mp_r ~= nil and SettingsPage.controls.mp_g ~= nil and SettingsPage.controls.mp_b ~= nil then
        local fill = colorTable(
            GetSliderValue(SettingsPage.controls.mp_r),
            GetSliderValue(SettingsPage.controls.mp_g),
            GetSliderValue(SettingsPage.controls.mp_b),
            sliderOr(SettingsPage.controls.mp_a, 255)
        )
        editStyle.mp_fill_color = fill
        editStyle.mp_bar_color = fill
    end
    if SettingsPage.controls.mp_after_r ~= nil and SettingsPage.controls.mp_after_g ~= nil and SettingsPage.controls.mp_after_b ~= nil then
        editStyle.mp_after_color = colorTable(
            GetSliderValue(SettingsPage.controls.mp_after_r),
            GetSliderValue(SettingsPage.controls.mp_after_g),
            GetSliderValue(SettingsPage.controls.mp_after_b),
            sliderOr(SettingsPage.controls.mp_after_a, 255)
        )
    end

    if SettingsPage.controls.hp_tex_stock ~= nil and SettingsPage.controls.hp_tex_pc ~= nil and SettingsPage.controls.hp_tex_npc ~= nil then
        if SettingsPage.controls.hp_tex_pc:GetChecked() then
            editStyle.hp_texture_mode = "pc"
        elseif SettingsPage.controls.hp_tex_npc:GetChecked() then
            editStyle.hp_texture_mode = "npc"
        else
            editStyle.hp_texture_mode = "stock"
        end

        if SettingsPage.style_target == "all" and type(s.style.frames) == "table" then
            for _, frameKey in ipairs(STYLE_TARGET_KEYS) do
                if frameKey ~= "all" then
                    local frameStyle = s.style.frames[frameKey]
                    if type(frameStyle) == "table" then
                        frameStyle.bar_colors_enabled = nil
                        frameStyle.hp_texture_mode = nil
                        frameStyle.hp_custom_texture_path = nil
                        frameStyle.hp_custom_texture_key = nil
                        frameStyle.hp_bar_color = nil
                        frameStyle.hp_fill_color = nil
                        frameStyle.hp_after_color = nil
                        frameStyle.mp_bar_color = nil
                        frameStyle.mp_fill_color = nil
                        frameStyle.mp_after_color = nil
                    end
                end
            end
        end
    end

    if type(s.style.buff_windows) ~= "table" then
        s.style.buff_windows = {}
    end

    if type(s.style.aura) ~= "table" then
        s.style.aura = {}
    end
    if type(s.style.buff_windows.player) ~= "table" then
        s.style.buff_windows.player = {}
    end
    if type(s.style.buff_windows.target) ~= "table" then
        s.style.buff_windows.target = {}
    end
    if type(s.style.buff_windows.player.buff) ~= "table" then
        s.style.buff_windows.player.buff = {}
    end
    if type(s.style.buff_windows.player.debuff) ~= "table" then
        s.style.buff_windows.player.debuff = {}
    end
    if type(s.style.buff_windows.target.buff) ~= "table" then
        s.style.buff_windows.target.buff = {}
    end
    if type(s.style.buff_windows.target.debuff) ~= "table" then
        s.style.buff_windows.target.debuff = {}
    end
    if SettingsPage.controls.move_buffs ~= nil then
        s.style.buff_windows.enabled = SettingsPage.controls.move_buffs:GetChecked() and true or false
    end

    if SettingsPage.controls.p_buff_x ~= nil then
        s.style.buff_windows.player.buff.x = GetSliderValue(SettingsPage.controls.p_buff_x)
    end
    if SettingsPage.controls.p_buff_y ~= nil then
        s.style.buff_windows.player.buff.y = GetSliderValue(SettingsPage.controls.p_buff_y)
    end
    if SettingsPage.controls.p_debuff_x ~= nil then
        s.style.buff_windows.player.debuff.x = GetSliderValue(SettingsPage.controls.p_debuff_x)
    end
    if SettingsPage.controls.p_debuff_y ~= nil then
        s.style.buff_windows.player.debuff.y = GetSliderValue(SettingsPage.controls.p_debuff_y)
    end

    if SettingsPage.controls.t_buff_x ~= nil then
        s.style.buff_windows.target.buff.x = GetSliderValue(SettingsPage.controls.t_buff_x)
    end
    if SettingsPage.controls.t_buff_y ~= nil then
        s.style.buff_windows.target.buff.y = GetSliderValue(SettingsPage.controls.t_buff_y)
    end
    if SettingsPage.controls.t_debuff_x ~= nil then
        s.style.buff_windows.target.debuff.x = GetSliderValue(SettingsPage.controls.t_debuff_x)
    end
    if SettingsPage.controls.t_debuff_y ~= nil then
        s.style.buff_windows.target.debuff.y = GetSliderValue(SettingsPage.controls.t_debuff_y)
    end

    if SettingsPage.controls.overlay_alpha ~= nil then
        editStyle.overlay_alpha = GetSliderValue(SettingsPage.controls.overlay_alpha) / 100
    end

    if SettingsPage.controls.aura_enabled ~= nil then
        s.style.aura.enabled = SettingsPage.controls.aura_enabled:GetChecked() and true or false
    end
    if SettingsPage.controls.aura_icon_size ~= nil then
        s.style.aura.icon_size = GetSliderValue(SettingsPage.controls.aura_icon_size)
    end
    if SettingsPage.controls.aura_x_gap ~= nil then
        s.style.aura.icon_x_gap = GetSliderValue(SettingsPage.controls.aura_x_gap)
    end
    if SettingsPage.controls.aura_y_gap ~= nil then
        s.style.aura.icon_y_gap = GetSliderValue(SettingsPage.controls.aura_y_gap)
    end
    if SettingsPage.controls.aura_per_row ~= nil then
        s.style.aura.buffs_per_row = GetSliderValue(SettingsPage.controls.aura_per_row)
    end
    if SettingsPage.controls.aura_sort_vertical ~= nil then
        s.style.aura.sort_vertical = SettingsPage.controls.aura_sort_vertical:GetChecked() and true or false
    end

    EnsureCooldownTrackerTables(s)
    local tracker = s.cooldown_tracker
    if SettingsPage.controls.ct_enabled ~= nil then
        tracker.enabled = SettingsPage.controls.ct_enabled:GetChecked() and true or false
    end
    if SettingsPage.controls.ct_update_interval ~= nil then
        tracker.update_interval_ms = GetSliderValue(SettingsPage.controls.ct_update_interval)
    end

    local selectedUnitKey = tostring(SettingsPage.cooldown_unit_key or "player")
    local selectedUnitCfg = tracker.units[selectedUnitKey]
    if type(selectedUnitCfg) ~= "table" then
        tracker.units[selectedUnitKey] = {}
        selectedUnitCfg = tracker.units[selectedUnitKey]
    end

    if SettingsPage.controls.ct_unit_enabled ~= nil then
        selectedUnitCfg.enabled = SettingsPage.controls.ct_unit_enabled:GetChecked() and true or false
    end
    if SettingsPage.controls.ct_lock_position ~= nil then
        selectedUnitCfg.lock_position = SettingsPage.controls.ct_lock_position:GetChecked() and true or false
    end
    if SettingsPage.controls.ct_display_mode ~= nil then
        local idx = GetComboBoxIndex1Based(SettingsPage.controls.ct_display_mode, #COOLDOWN_DISPLAY_MODE_LABELS)
        selectedUnitCfg.display_mode = GetCooldownDisplayModeFromIndex(idx)
    end
    if SettingsPage.controls.ct_pos_x ~= nil then
        local x = ParseEditNumber(SettingsPage.controls.ct_pos_x)
        if x ~= nil then
            selectedUnitCfg.pos_x = ClampInt(x, -5000, 5000, 330)
        end
    end
    if SettingsPage.controls.ct_pos_y ~= nil then
        local y = ParseEditNumber(SettingsPage.controls.ct_pos_y)
        if y ~= nil then
            selectedUnitCfg.pos_y = ClampInt(y, -5000, 5000, 100)
        end
    end
    if SettingsPage.controls.ct_icon_size ~= nil then
        selectedUnitCfg.icon_size = GetSliderValue(SettingsPage.controls.ct_icon_size)
    end
    if SettingsPage.controls.ct_icon_spacing ~= nil then
        selectedUnitCfg.icon_spacing = GetSliderValue(SettingsPage.controls.ct_icon_spacing)
    end
    if SettingsPage.controls.ct_max_icons ~= nil then
        selectedUnitCfg.max_icons = GetSliderValue(SettingsPage.controls.ct_max_icons)
    end
    if SettingsPage.controls.ct_show_timer ~= nil then
        selectedUnitCfg.show_timer = SettingsPage.controls.ct_show_timer:GetChecked() and true or false
    end
    if SettingsPage.controls.ct_timer_fs ~= nil then
        selectedUnitCfg.timer_font_size = GetSliderValue(SettingsPage.controls.ct_timer_fs)
    end
    if SettingsPage.controls.ct_timer_r ~= nil and SettingsPage.controls.ct_timer_g ~= nil and SettingsPage.controls.ct_timer_b ~= nil then
        selectedUnitCfg.timer_color = colorTable(
            GetSliderValue(SettingsPage.controls.ct_timer_r),
            GetSliderValue(SettingsPage.controls.ct_timer_g),
            GetSliderValue(SettingsPage.controls.ct_timer_b),
            255
        )
    end
    if SettingsPage.controls.ct_show_label ~= nil then
        selectedUnitCfg.show_label = SettingsPage.controls.ct_show_label:GetChecked() and true or false
    end
    if SettingsPage.controls.ct_label_fs ~= nil then
        selectedUnitCfg.label_font_size = GetSliderValue(SettingsPage.controls.ct_label_fs)
    end
    if SettingsPage.controls.ct_label_r ~= nil and SettingsPage.controls.ct_label_g ~= nil and SettingsPage.controls.ct_label_b ~= nil then
        selectedUnitCfg.label_color = colorTable(
            GetSliderValue(SettingsPage.controls.ct_label_r),
            GetSliderValue(SettingsPage.controls.ct_label_g),
            GetSliderValue(SettingsPage.controls.ct_label_b),
            255
        )
    end
    if SettingsPage.controls.ct_cache_timeout ~= nil then
        selectedUnitCfg.cache_timeout_s = GetSliderValue(SettingsPage.controls.ct_cache_timeout)
    end

    if SettingsPage.controls.value_fmt_curmax ~= nil and SettingsPage.controls.value_fmt_percent ~= nil then
        local wantCurMax = SettingsPage.controls.value_fmt_curmax:GetChecked() and true or false
        local wantPercent = SettingsPage.controls.value_fmt_percent:GetChecked() and true or false
        if wantCurMax and wantPercent then
            editStyle.value_format = "curmax_percent"
        elseif wantPercent then
            editStyle.value_format = "percent"
        elseif wantCurMax then
            editStyle.value_format = "curmax"
        else
            editStyle.value_format = "stock"
        end
    end

    if SettingsPage.controls.short_numbers ~= nil then
        editStyle.short_numbers = SettingsPage.controls.short_numbers:GetChecked() and true or false
    end

    if SettingsPage.style_target == "all" and type(PruneStyleFrameOverrides) == "function" then
        PruneStyleFrameOverrides(s, { "player", "target", "watchtarget", "target_of_target", "party" })
    end

end

local function EnsureWindow()
    if SettingsPage.window ~= nil then
        return
    end

    SettingsPage.window = api.Interface:CreateWindow("PolarUiSettings", "Nuzi UI Settings", 820, 760)
    SettingsPage.window:AddAnchor("CENTER", "UIParent", 0, 0)

    local closeHandler = MakeCloseHandler()
    SettingsPage.window:SetHandler("OnCloseByEsc", closeHandler)
    function SettingsPage.window:OnClose()
        closeHandler()
    end

    SettingsPage.scroll_frame = nil
    SettingsPage.content = SettingsPage.window

    if SettingsPage.window.CreateChildWidget ~= nil then
        local ok, res = pcall(function()
            return SettingsPage.window:CreateChildWidget("emptywidget", "polarUiScrollFrame", 0, true)
        end)
        if ok then
            SettingsPage.scroll_frame = res
        end
    end

    if SettingsPage.scroll_frame ~= nil then
        pcall(function()
            SettingsPage.scroll_frame:Show(true)
            SettingsPage.scroll_frame:AddAnchor("TOPLEFT", SettingsPage.window, 185, 105)
            SettingsPage.scroll_frame:AddAnchor("BOTTOMRIGHT", SettingsPage.window, -15, -50)
            SettingsPage.scroll_frame:SetExtent(620, 585)
        end)

        if SettingsPage.scroll_frame.CreateChildWidget ~= nil then
            local ok, res = pcall(function()
                return SettingsPage.scroll_frame:CreateChildWidget("emptywidget", "content", 0, true)
            end)
            if ok then
                SettingsPage.content = res
            end
        end

        if SettingsPage.content ~= nil then
            pcall(function()
                SettingsPage.content:Show(true)
            end)
            pcall(function()
                if SettingsPage.content.EnableScroll ~= nil then
                    SettingsPage.content:EnableScroll(true)
                end
            end)
        end
    end

    local scroll = nil
    if SettingsPage.scroll_frame ~= nil and W_CTRL ~= nil and W_CTRL.CreateScroll ~= nil then
        local ok, res = pcall(function()
            return W_CTRL.CreateScroll("polarUiScroll", SettingsPage.scroll_frame)
        end)
        if ok then
            scroll = res
        end
    end

    if scroll ~= nil and SettingsPage.scroll_frame ~= nil then
        scroll:AddAnchor("TOPRIGHT", SettingsPage.scroll_frame, 0, 0)
        scroll:AddAnchor("BOTTOMRIGHT", SettingsPage.scroll_frame, 0, 0)
        if scroll.AlwaysScrollShow ~= nil then
            scroll:AlwaysScrollShow()
        end
    end

    pcall(function()
        if SettingsPage.scroll_frame ~= nil and SettingsPage.content ~= nil and SettingsPage.content.AddAnchor ~= nil then
            SettingsPage.content:AddAnchor("TOPLEFT", SettingsPage.scroll_frame, 0, 0)
            SettingsPage.content:AddAnchor("BOTTOM", SettingsPage.scroll_frame, 0, 0)
            if scroll ~= nil then
                SettingsPage.content:AddAnchor("RIGHT", scroll, "LEFT", -5, 0)
            else
                SettingsPage.content:AddAnchor("RIGHT", SettingsPage.scroll_frame, 0, 0)
            end
        end
    end)

    if scroll ~= nil and SettingsPage.scroll_frame ~= nil and scroll.vs ~= nil and scroll.vs.SetHandler ~= nil then
        scroll.vs:SetHandler("OnSliderChanged", function(a, b)
            pcall(function()
                local value = b
                if type(value) ~= "number" then
                    value = a
                end
                if type(value) ~= "number" then
                    return
                end
                local page = SettingsPage.active_page ~= nil and SettingsPage.pages[SettingsPage.active_page] or nil
                if page ~= nil and page.ChangeChildAnchorByScrollValue ~= nil then
                    page:ChangeChildAnchorByScrollValue("vert", value)
                end
            end)
        end)
    end

    if SettingsPage.scroll_frame ~= nil then
        SettingsPage.scroll_frame.content = SettingsPage.content
        SettingsPage.scroll_frame.scroll = scroll
        function SettingsPage.scroll_frame:ResetScroll(totalHeight)
            if self.scroll == nil or self.scroll.vs == nil or self.scroll.vs.SetMinMaxValues == nil then
                return
            end
            local height = 0
            pcall(function()
                if self.GetHeight ~= nil then
                    height = self:GetHeight()
                end
            end)
            local total = tonumber(totalHeight) or 0
            local maxScroll = total
            if height > 0 then
                maxScroll = total - height
            end
            if maxScroll < 0 then
                maxScroll = 0
            end

            self.scroll.vs:SetMinMaxValues(0, maxScroll)
            if maxScroll <= 0 then
                if self.scroll.SetEnable ~= nil then
                    self.scroll:SetEnable(false)
                end
            else
                if self.scroll.SetEnable ~= nil then
                    self.scroll:SetEnable(true)
                end
            end
        end
    end

    CreateLabel("polarUiNavTitle", SettingsPage.window, "Sections", 15, 42, 18)
    SettingsPage.controls.page_header_title = CreateLabel("polarUiPageHeaderTitle", SettingsPage.window, "", 185, 42, 18)
    SettingsPage.controls.page_header_summary = CreateHintLabel("polarUiPageHeaderSummary", SettingsPage.window, "", 185, 68, 600)
    if SettingsPage.controls.page_header_summary ~= nil then
        SettingsPage.controls.page_header_summary:SetExtent(600, 32)
    end

    local navY = 72
    for _, page in ipairs(PAGE_DEFS) do
        local button = CreateButton("polarUiNav_" .. tostring(page.id), SettingsPage.window, tostring(page.label or page.id), 15, navY)
        if button ~= nil then
            pcall(function()
                button:SetExtent(155, 26)
            end)
            if button.SetHandler ~= nil then
                local pageId = page.id
                button:SetHandler("OnClick", function()
                    SetActivePage(pageId)
                end)
            end
        end
        SettingsPage.nav[page.id] = button
        navY = navY + 32
    end

    SettingsPage.pages = {}
    SettingsPage.page_heights = {}

    for _, page in ipairs(PAGE_DEFS) do
        SettingsPage.pages[page.id] = CreatePage("polarUiPage_" .. tostring(page.id), SettingsPage.content)
    end

    local gap = 24

    do
        local page = SettingsPage.pages.general
        local y = 35
        CreateLabel("polarUiGeneralPageTitle", page, "General", 15, y, 18)
        y = y + 30

        SettingsPage.controls.enabled = CreateCheckbox("polarUiEnabled", page, "Enable Nuzi UI overlays", 15, y)
        y = y + gap

        SettingsPage.controls.large_hpmp = CreateCheckbox("polarUiLargeHpMp", page, "Large HP/MP text", 15, y)
        y = y + gap

        SettingsPage.controls.show_distance = CreateCheckbox("polarUiShowDistance", page, "Show target distance", 15, y)
        y = y + gap

        SettingsPage.controls.alignment_grid_enabled = CreateCheckbox(
            "polarUiAlignmentGridEnabled",
            page,
            "Show alignment grid (30px)",
            15,
            y
        )
        y = y + gap

        SettingsPage.controls.launcher_size, SettingsPage.controls.launcher_size_val = CreateSlider(
            "polarUiLauncherSize",
            page,
            "Launcher size",
            15,
            y,
            36,
            96,
            1
        )
        y = y + 34

        SettingsPage.page_heights.general = y + 40
    end


    do
        local page = SettingsPage.pages.text
        local y = 35
        CreateLabel("polarUiTextPageTitle", page, "Text", 15, y, 18)
        y = y + 30

        CreateLabel("polarUiTextStyleTargetLabel", page, "Edit style for", 15, y, 15)
        SettingsPage.controls.style_target_text = CreateComboBox(
            page,
            { "All frames", "Player", "Target", "Watchtarget", "Target of Target", "Party" },
            175,
            y - 4,
            220,
            24
        )
        y = y + 34

        SettingsPage.controls.style_target_text_hint = CreateHintLabel(
            "polarUiTextStyleTargetHint",
            page,
            "Editing shared defaults for all overlay and party frames.",
            15,
            y
        )
        y = y + 24

        CreateLabel("polarUiFontSizesTitle", page, "Font Sizes", 15, y, 18)
        y = y + 30

        SettingsPage.controls.name_font_size, SettingsPage.controls.name_font_size_val = CreateSlider(
            "polarUiNameFontSize",
            page,
            "Name font size",
            15,
            y,
            8,
            30,
            1
        )
        y = y + 24

        SettingsPage.controls.hp_font_size, SettingsPage.controls.hp_font_size_val = CreateSlider(
            "polarUiHpFontSize",
            page,
            "HP font size",
            15,
            y,
            8,
            40,
            1
        )
        y = y + 24

        SettingsPage.controls.mp_font_size, SettingsPage.controls.mp_font_size_val = CreateSlider(
            "polarUiMpFontSize",
            page,
            "MP font size",
            15,
            y,
            8,
            40,
            1
        )
        y = y + 24

        SettingsPage.controls.overlay_font_size, SettingsPage.controls.overlay_font_size_val = CreateSlider(
            "polarUiOverlayFontSize",
            page,
            "Target overlay font size",
            15,
            y,
            8,
            30,
            1
        )
        y = y + 24

        SettingsPage.controls.gs_font_size, SettingsPage.controls.gs_font_size_val = CreateSlider(
            "polarUiGsFontSize",
            page,
            "Gearscore font size",
            15,
            y,
            8,
            30,
            1
        )
        y = y + 24

        SettingsPage.controls.class_font_size, SettingsPage.controls.class_font_size_val = CreateSlider(
            "polarUiClassFontSize",
            page,
            "Class font size",
            15,
            y,
            8,
            30,
            1
        )
        y = y + 24

        SettingsPage.controls.target_guild_font_size, SettingsPage.controls.target_guild_font_size_val = CreateSlider(
            "polarUiTargetGuildFontSize",
            page,
            "Target guild font size",
            15,
            y,
            8,
            30,
            1
        )
        y = y + gap

        CreateLabel("polarUiTargetOverlayFieldsTitle", page, "Target Overlay Fields", 15, y, 18)
        y = y + 30

        SettingsPage.controls.target_guild_visible = CreateCheckbox("polarUiTargetGuildVisible", page, "Show guild text", 15, y)
        y = y + gap

        SettingsPage.controls.target_class_visible = CreateCheckbox("polarUiTargetClassVisible", page, "Show class text", 15, y)
        y = y + gap

        SettingsPage.controls.target_pdef_visible = CreateCheckbox("polarUiTargetPdefVisible", page, "Show PDEF text", 15, y)
        y = y + gap

        SettingsPage.controls.target_mdef_visible = CreateCheckbox("polarUiTargetMdefVisible", page, "Show MDEF text", 15, y)
        y = y + gap

        SettingsPage.controls.target_gearscore_visible = CreateCheckbox("polarUiTargetGearscoreVisible", page, "Show gearscore text", 15, y)
        y = y + gap

        y = y + 10

        CreateLabel("polarUiTargetOverlayColorsTitle", page, "Target Overlay Colors", 15, y, 18)
        y = y + 30

        SettingsPage.controls.target_guild_r, SettingsPage.controls.target_guild_r_val = CreateSlider("polarUiTargetGuildR", page, "Guild R", 15, y, 0, 255, 1)
        y = y + 24
        SettingsPage.controls.target_guild_g, SettingsPage.controls.target_guild_g_val = CreateSlider("polarUiTargetGuildG", page, "Guild G", 15, y, 0, 255, 1)
        y = y + 24
        SettingsPage.controls.target_guild_b, SettingsPage.controls.target_guild_b_val = CreateSlider("polarUiTargetGuildB", page, "Guild B", 15, y, 0, 255, 1)
        y = y + 24

        SettingsPage.controls.target_class_r, SettingsPage.controls.target_class_r_val = CreateSlider("polarUiTargetClassR", page, "Class R", 15, y, 0, 255, 1)
        y = y + 24
        SettingsPage.controls.target_class_g, SettingsPage.controls.target_class_g_val = CreateSlider("polarUiTargetClassG", page, "Class G", 15, y, 0, 255, 1)
        y = y + 24
        SettingsPage.controls.target_class_b, SettingsPage.controls.target_class_b_val = CreateSlider("polarUiTargetClassB", page, "Class B", 15, y, 0, 255, 1)
        y = y + 24

        SettingsPage.controls.target_pdef_r, SettingsPage.controls.target_pdef_r_val = CreateSlider("polarUiTargetPdefR", page, "PDEF R", 15, y, 0, 255, 1)
        y = y + 24
        SettingsPage.controls.target_pdef_g, SettingsPage.controls.target_pdef_g_val = CreateSlider("polarUiTargetPdefG", page, "PDEF G", 15, y, 0, 255, 1)
        y = y + 24
        SettingsPage.controls.target_pdef_b, SettingsPage.controls.target_pdef_b_val = CreateSlider("polarUiTargetPdefB", page, "PDEF B", 15, y, 0, 255, 1)
        y = y + 24

        SettingsPage.controls.target_mdef_r, SettingsPage.controls.target_mdef_r_val = CreateSlider("polarUiTargetMdefR", page, "MDEF R", 15, y, 0, 255, 1)
        y = y + 24
        SettingsPage.controls.target_mdef_g, SettingsPage.controls.target_mdef_g_val = CreateSlider("polarUiTargetMdefG", page, "MDEF G", 15, y, 0, 255, 1)
        y = y + 24
        SettingsPage.controls.target_mdef_b, SettingsPage.controls.target_mdef_b_val = CreateSlider("polarUiTargetMdefB", page, "MDEF B", 15, y, 0, 255, 1)
        y = y + 24

        SettingsPage.controls.target_gearscore_r, SettingsPage.controls.target_gearscore_r_val = CreateSlider("polarUiTargetGsR", page, "Gearscore R", 15, y, 0, 255, 1)
        y = y + 24
        SettingsPage.controls.target_gearscore_g, SettingsPage.controls.target_gearscore_g_val = CreateSlider("polarUiTargetGsG", page, "Gearscore G", 15, y, 0, 255, 1)
        y = y + 24
        SettingsPage.controls.target_gearscore_b, SettingsPage.controls.target_gearscore_b_val = CreateSlider("polarUiTargetGsB", page, "Gearscore B", 15, y, 0, 255, 1)
        y = y + gap + 10

        CreateLabel("polarUiShadowsTitle", page, "Shadows", 15, y, 18)
        y = y + 30

        SettingsPage.controls.name_shadow = CreateCheckbox("polarUiNameShadow", page, "Name text shadow", 15, y)
        y = y + gap

        SettingsPage.controls.value_shadow = CreateCheckbox("polarUiValueShadow", page, "HP/MP value shadow", 15, y)
        y = y + gap

        SettingsPage.controls.overlay_shadow = CreateCheckbox("polarUiOverlayShadow", page, "Target overlay shadow", 15, y)
        y = y + gap + 10

        CreateLabel("polarUiValueOffsetsTitle", page, "HP/MP Value Offsets", 15, y, 18)
        y = y + 30

        SettingsPage.controls.hp_value_offset_x, SettingsPage.controls.hp_value_offset_x_val = CreateSlider(
            "polarUiHpValueOffsetX",
            page,
            "HP value offset X",
            15,
            y,
            -200,
            200,
            1
        )
        y = y + 24

        SettingsPage.controls.hp_value_offset_y, SettingsPage.controls.hp_value_offset_y_val = CreateSlider(
            "polarUiHpValueOffsetY",
            page,
            "HP value offset Y",
            15,
            y,
            -120,
            120,
            1
        )
        y = y + 24

        SettingsPage.controls.mp_value_offset_x, SettingsPage.controls.mp_value_offset_x_val = CreateSlider(
            "polarUiMpValueOffsetX",
            page,
            "MP value offset X",
            15,
            y,
            -200,
            200,
            1
        )
        y = y + 24

        SettingsPage.controls.mp_value_offset_y, SettingsPage.controls.mp_value_offset_y_val = CreateSlider(
            "polarUiMpValueOffsetY",
            page,
            "MP value offset Y",
            15,
            y,
            -120,
            120,
            1
        )
        y = y + 24

        SettingsPage.controls.target_guild_offset_x, SettingsPage.controls.target_guild_offset_x_val = CreateSlider(
            "polarUiTargetGuildOffsetX",
            page,
            "Target guild offset X",
            15,
            y,
            -200,
            200,
            1
        )
        y = y + 24

        SettingsPage.controls.target_guild_offset_y, SettingsPage.controls.target_guild_offset_y_val = CreateSlider(
            "polarUiTargetGuildOffsetY",
            page,
            "Target guild offset Y",
            15,
            y,
            -200,
            200,
            1
        )
        y = y + gap + 10

        CreateLabel("polarUiTextLayoutTitle", page, "Text Layout", 15, y, 18)
        y = y + 30

        SettingsPage.controls.name_visible = CreateCheckbox("polarUiNameVisible", page, "Show name text", 15, y)
        y = y + gap

        SettingsPage.controls.name_offset_x, SettingsPage.controls.name_offset_x_val = CreateSlider(
            "polarUiNameOffsetX",
            page,
            "Name offset X",
            15,
            y,
            -200,
            200,
            1
        )
        y = y + 24

        SettingsPage.controls.name_offset_y, SettingsPage.controls.name_offset_y_val = CreateSlider(
            "polarUiNameOffsetY",
            page,
            "Name offset Y",
            15,
            y,
            -120,
            120,
            1
        )
        y = y + 24

        SettingsPage.controls.level_visible = CreateCheckbox("polarUiLevelVisible", page, "Show level text", 15, y)
        y = y + gap

        SettingsPage.controls.level_font_size, SettingsPage.controls.level_font_size_val = CreateSlider(
            "polarUiLevelFontSize",
            page,
            "Level font size",
            15,
            y,
            8,
            24,
            1
        )
        y = y + 24

        SettingsPage.controls.level_offset_x, SettingsPage.controls.level_offset_x_val = CreateSlider(
            "polarUiLevelOffsetX",
            page,
            "Level offset X",
            15,
            y,
            -200,
            200,
            1
        )
        y = y + 24

        SettingsPage.controls.level_offset_y, SettingsPage.controls.level_offset_y_val = CreateSlider(
            "polarUiLevelOffsetY",
            page,
            "Level offset Y",
            15,
            y,
            -120,
            120,
            1
        )
        y = y + 34

        SettingsPage.page_heights.text = y + 40
    end

    do
        local page = SettingsPage.pages.bars
        local y = 35
        CreateLabel("polarUiBarsPageTitle", page, "Bars", 15, y, 18)
        y = y + 30

        CreateLabel("polarUiBarsStyleTargetLabel", page, "Edit style for", 15, y, 15)
        SettingsPage.controls.style_target_bars = CreateComboBox(
            page,
            { "All frames", "Player", "Target", "Watchtarget", "Target of Target", "Party" },
            175,
            y - 4,
            220,
            24
        )
        y = y + 34

        SettingsPage.controls.style_target_bars_hint = CreateHintLabel(
            "polarUiBarsStyleTargetHint",
            page,
            "Editing shared defaults for all overlay and party frames.",
            15,
            y
        )
        y = y + 24

        CreateLabel("polarUiFrameTitleBars", page, "Frame Styling", 15, y, 18)
        y = y + 30

        CreateLabel("polarUiFrameOpacityTitle", page, "Opacity", 15, y, 15)
        y = y + 22

        SettingsPage.controls.frame_alpha, SettingsPage.controls.frame_alpha_val = CreateSlider(
            "polarUiFrameAlpha",
            page,
            "Frame alpha (0-100)",
            15,
            y,
            0,
            100,
            1
        )
        y = y + 24

        SettingsPage.controls.overlay_alpha, SettingsPage.controls.overlay_alpha_val = CreateSlider(
            "polarUiOverlayAlpha",
            page,
            "Overlay alpha (0-100)",
            15,
            y,
            0,
            100,
            1
        )
        y = y + gap

        CreateLabel("polarUiFrameSizeTitle", page, "Dimensions", 15, y, 15)
        y = y + 22

        SettingsPage.controls.frame_width, SettingsPage.controls.frame_width_val = CreateSlider(
            "polarUiFrameWidth",
            page,
            "Frame width",
            15,
            y,
            200,
            600,
            1
        )
        y = y + 24

        SettingsPage.controls.frame_height, SettingsPage.controls.frame_height_val = CreateSlider(
            "polarUiFrameHeight",
            page,
            "Frame height (global)",
            15,
            y,
            40,
            120,
            1
        )
        y = y + 24

        SettingsPage.controls.frame_scale, SettingsPage.controls.frame_scale_val = CreateSlider(
            "polarUiFrameScale",
            page,
            "Frame scale (50-150)",
            15,
            y,
            50,
            150,
            1
        )
        y = y + 24

        CreateLabel("polarUiBarLayoutTitle", page, "Bar Layout", 15, y, 15)
        y = y + 22

        SettingsPage.controls.bar_height, SettingsPage.controls.bar_height_val = CreateSlider(
            "polarUiBarHeight",
            page,
            "Shared bar height",
            15,
            y,
            10,
            40,
            1
        )
        y = y + 24

        SettingsPage.controls.hp_bar_height, SettingsPage.controls.hp_bar_height_val = CreateSlider(
            "polarUiHpBarHeight",
            page,
            "HP bar height",
            15,
            y,
            10,
            40,
            1
        )
        y = y + 24

        SettingsPage.controls.mp_bar_height, SettingsPage.controls.mp_bar_height_val = CreateSlider(
            "polarUiMpBarHeight",
            page,
            "MP bar height",
            15,
            y,
            6,
            40,
            1
        )
        y = y + 24

        SettingsPage.controls.bar_gap, SettingsPage.controls.bar_gap_val = CreateSlider(
            "polarUiBarGap",
            page,
            "Bar gap",
            15,
            y,
            0,
            20,
            1
        )
        y = y + gap + 10

        CreateLabel("polarUiBarStyleTitle", page, "Bar Style", 15, y, 18)
        y = y + 30

        SettingsPage.controls.bar_colors_enabled = CreateCheckbox("polarUiBarColorsEnabled", page, "Override HP/MP bar colors", 15, y)
        y = y + gap

        CreateLabel("polarUiHpColorLabel", page, "HP Color (RGB)", 15, y, 15)
        y = y + 22

        SettingsPage.controls.hp_r, SettingsPage.controls.hp_r_val = CreateSlider("polarUiHpR", page, "HP R", 15, y, 0, 255, 1)
        y = y + 24
        SettingsPage.controls.hp_g, SettingsPage.controls.hp_g_val = CreateSlider("polarUiHpG", page, "HP G", 15, y, 0, 255, 1)
        y = y + 24
        SettingsPage.controls.hp_b, SettingsPage.controls.hp_b_val = CreateSlider("polarUiHpB", page, "HP B", 15, y, 0, 255, 1)
        y = y + 24
        SettingsPage.controls.hp_a, SettingsPage.controls.hp_a_val = CreateSlider("polarUiHpA", page, "HP Fill alpha", 15, y, 0, 255, 1)
        y = y + 30

        CreateLabel("polarUiHpAfterColorLabel", page, "HP Afterimage Color (RGB)", 15, y, 15)
        y = y + 22

        SettingsPage.controls.hp_after_r, SettingsPage.controls.hp_after_r_val = CreateSlider("polarUiHpAfterR", page, "HP After R", 15, y, 0, 255, 1)
        y = y + 24
        SettingsPage.controls.hp_after_g, SettingsPage.controls.hp_after_g_val = CreateSlider("polarUiHpAfterG", page, "HP After G", 15, y, 0, 255, 1)
        y = y + 24
        SettingsPage.controls.hp_after_b, SettingsPage.controls.hp_after_b_val = CreateSlider("polarUiHpAfterB", page, "HP After B", 15, y, 0, 255, 1)
        y = y + 24
        SettingsPage.controls.hp_after_a, SettingsPage.controls.hp_after_a_val = CreateSlider("polarUiHpAfterA", page, "HP After alpha", 15, y, 0, 255, 1)
        y = y + 30

        CreateLabel("polarUiMpColorLabel", page, "MP Color (RGB)", 15, y, 15)
        y = y + 22

        SettingsPage.controls.mp_r, SettingsPage.controls.mp_r_val = CreateSlider("polarUiMpR", page, "MP R", 15, y, 0, 255, 1)
        y = y + 24
        SettingsPage.controls.mp_g, SettingsPage.controls.mp_g_val = CreateSlider("polarUiMpG", page, "MP G", 15, y, 0, 255, 1)
        y = y + 24
        SettingsPage.controls.mp_b, SettingsPage.controls.mp_b_val = CreateSlider("polarUiMpB", page, "MP B", 15, y, 0, 255, 1)
        y = y + 24
        SettingsPage.controls.mp_a, SettingsPage.controls.mp_a_val = CreateSlider("polarUiMpA", page, "MP Fill alpha", 15, y, 0, 255, 1)
        y = y + 30

        CreateLabel("polarUiMpAfterColorLabel", page, "MP Afterimage Color (RGB)", 15, y, 15)
        y = y + 22

        SettingsPage.controls.mp_after_r, SettingsPage.controls.mp_after_r_val = CreateSlider("polarUiMpAfterR", page, "MP After R", 15, y, 0, 255, 1)
        y = y + 24
        SettingsPage.controls.mp_after_g, SettingsPage.controls.mp_after_g_val = CreateSlider("polarUiMpAfterG", page, "MP After G", 15, y, 0, 255, 1)
        y = y + 24
        SettingsPage.controls.mp_after_b, SettingsPage.controls.mp_after_b_val = CreateSlider("polarUiMpAfterB", page, "MP After B", 15, y, 0, 255, 1)
        y = y + 24
        SettingsPage.controls.mp_after_a, SettingsPage.controls.mp_after_a_val = CreateSlider("polarUiMpAfterA", page, "MP After alpha", 15, y, 0, 255, 1)
        y = y + gap + 10

        CreateLabel("polarUiHpTextureLabel", page, "HP Texture Mode", 15, y, 15)
        y = y + 22

        SettingsPage.controls.hp_tex_stock = CreateCheckbox("polarUiHpTexStock", page, "Stock", 15, y)
        y = y + gap
        SettingsPage.controls.hp_tex_pc = CreateCheckbox("polarUiHpTexPc", page, "PC", 15, y)
        y = y + gap
        SettingsPage.controls.hp_tex_npc = CreateCheckbox("polarUiHpTexNpc", page, "NPC", 15, y)
        y = y + gap + 10

        CreateLabel("polarUiValueTextTitle", page, "HP/MP Value Text", 15, y, 18)
        y = y + 30

        SettingsPage.controls.value_fmt_curmax = CreateCheckbox(
            "polarUiValueFmtCurMax",
            page,
            "Format HP/MP as cur/max",
            15,
            y
        )
        y = y + gap

        SettingsPage.controls.value_fmt_percent = CreateCheckbox(
            "polarUiValueFmtPercent",
            page,
            "Format HP/MP as percent",
            15,
            y
        )
        y = y + gap

        SettingsPage.controls.short_numbers = CreateCheckbox(
            "polarUiShortNumbers",
            page,
            "Short numbers (12.3k/4.5m)",
            15,
            y
        )
        y = y + 34

        SettingsPage.page_heights.bars = y + 40
    end

    do
        local page = SettingsPage.pages.auras
        local y = 35
        CreateLabel("polarUiAurasPageTitle", page, "Auras", 15, y, 18)
        y = y + 30

        CreateLabel("polarUiAuraTitle", page, "Aura Layout (Buff/Debuff Icon Size)", 15, y, 18)
        y = y + 30

        SettingsPage.controls.aura_enabled = CreateCheckbox(
            "polarUiAuraEnabled",
            page,
            "Override aura icon layout",
            15,
            y
        )
        y = y + gap

        SettingsPage.controls.aura_icon_size, SettingsPage.controls.aura_icon_size_val = CreateSlider(
            "polarUiAuraIconSize",
            page,
            "Icon size",
            15,
            y,
            12,
            48,
            1
        )
        y = y + 24

        SettingsPage.controls.aura_x_gap, SettingsPage.controls.aura_x_gap_val = CreateSlider(
            "polarUiAuraXGap",
            page,
            "Icon X gap",
            15,
            y,
            0,
            10,
            1
        )
        y = y + 24

        SettingsPage.controls.aura_y_gap, SettingsPage.controls.aura_y_gap_val = CreateSlider(
            "polarUiAuraYGap",
            page,
            "Icon Y gap",
            15,
            y,
            0,
            10,
            1
        )
        y = y + 24

        SettingsPage.controls.aura_per_row, SettingsPage.controls.aura_per_row_val = CreateSlider(
            "polarUiAuraPerRow",
            page,
            "Icons per row",
            15,
            y,
            1,
            30,
            1
        )
        y = y + 24

        SettingsPage.controls.aura_sort_vertical = CreateCheckbox(
            "polarUiAuraSortVertical",
            page,
            "Sort vertical",
            15,
            y
        )
        y = y + gap + 10

        SettingsPage.controls.move_buffs = CreateCheckbox("polarUiMoveBuffs", page, "Move buff/debuff strips (uses settings.txt offsets)", 15, y)
        y = y + gap

        CreateLabel("polarUiBuffPlacementTitle", page, "Buff/Debuff Placement (Offsets)", 15, y, 18)
        y = y + 30

        CreateLabel("polarUiBuffPlacementPlayer", page, "Player", 15, y, 15)
        y = y + 22

        SettingsPage.controls.p_buff_x, SettingsPage.controls.p_buff_x_val = CreateSlider("polarUiPBX", page, "Buff X", 15, y, -200, 200, 1)
        y = y + 24
        SettingsPage.controls.p_buff_y, SettingsPage.controls.p_buff_y_val = CreateSlider("polarUiPBY", page, "Buff Y", 15, y, -200, 200, 1)
        y = y + 24
        SettingsPage.controls.p_debuff_x, SettingsPage.controls.p_debuff_x_val = CreateSlider("polarUiPDBX", page, "Debuff X", 15, y, -200, 200, 1)
        y = y + 24
        SettingsPage.controls.p_debuff_y, SettingsPage.controls.p_debuff_y_val = CreateSlider("polarUiPDBY", page, "Debuff Y", 15, y, -200, 200, 1)
        y = y + 30

        CreateLabel("polarUiBuffPlacementTarget", page, "Target", 15, y, 15)
        y = y + 22

        SettingsPage.controls.t_buff_x, SettingsPage.controls.t_buff_x_val = CreateSlider("polarUiTBX", page, "Buff X", 15, y, -200, 200, 1)
        y = y + 24
        SettingsPage.controls.t_buff_y, SettingsPage.controls.t_buff_y_val = CreateSlider("polarUiTBY", page, "Buff Y", 15, y, -200, 200, 1)
        y = y + 24
        SettingsPage.controls.t_debuff_x, SettingsPage.controls.t_debuff_x_val = CreateSlider("polarUiTDBX", page, "Debuff X", 15, y, -200, 200, 1)
        y = y + 24
        SettingsPage.controls.t_debuff_y, SettingsPage.controls.t_debuff_y_val = CreateSlider("polarUiTDBY", page, "Debuff Y", 15, y, -200, 200, 1)
        y = y + 34

        SettingsPage.page_heights.auras = y + 40
    end

    do
        local page = SettingsPage.pages.plates
        local y = 35
        CreateLabel("polarUiPlatesPageTitle", page, "Plates", 15, y, 18)
        y = y + 30

        CreateLabel("polarUiPlatesHeader", page, "Overhead Raid/Party Plates", 15, y, 18)
        y = y + 30

        SettingsPage.controls.plates_enabled = CreateCheckbox("polarUiPlatesEnabled", page, "Enable overhead plates", 15, y)
        y = y + gap

        SettingsPage.controls.plates_guild_only = CreateCheckbox(
            "polarUiPlatesGuildOnly",
            page,
            "Guild-only overlay (keep stock nameplates)",
            15,
            y
        )
        y = y + gap

        SettingsPage.controls.plates_show_target = CreateCheckbox("polarUiPlatesShowTarget", page, "Show target (always)", 15, y)
        y = y + gap

        SettingsPage.controls.plates_show_player = CreateCheckbox("polarUiPlatesShowPlayer", page, "Show player (always)", 15, y)
        y = y + gap

        SettingsPage.controls.plates_show_raid_party = CreateCheckbox("polarUiPlatesShowRaid", page, "Show raid/party (team1..team50)", 15, y)
        y = y + gap

        SettingsPage.controls.plates_show_watchtarget = CreateCheckbox("polarUiPlatesShowWatch", page, "Show watchtarget", 15, y)
        y = y + gap

        SettingsPage.controls.plates_show_mount = CreateCheckbox("polarUiPlatesShowMount", page, "Show mount/pet (playerpet1)", 15, y)
        y = y + gap

        SettingsPage.controls.plates_show_guild = CreateCheckbox("polarUiPlatesShowGuild", page, "Show guild/expedition", 15, y)
        y = y + gap + 10

        SettingsPage.controls.plates_runtime_note = CreateLabel(
            "polarUiPlatesRuntimeNote",
            page,
            "Current client supports native targeting, so the old passthrough click modifiers are no longer needed.",
            15,
            y,
            13
        )
        if SettingsPage.controls.plates_runtime_note ~= nil then
            SettingsPage.controls.plates_runtime_note:SetExtent(470, 36)
        end
        y = y + 38

        SettingsPage.controls.plates_runtime_status = CreateLabel(
            "polarUiPlatesRuntimeStatus",
            page,
            "",
            15,
            y,
            12
        )
        if SettingsPage.controls.plates_runtime_status ~= nil then
            SettingsPage.controls.plates_runtime_status:SetExtent(470, 32)
        end
        y = y + 34

        CreateLabel("polarUiPlatesLayoutHeader", page, "Layout", 15, y, 18)
        y = y + 30

        SettingsPage.controls.plates_alpha, SettingsPage.controls.plates_alpha_val = CreateSlider(
            "polarUiPlatesAlpha",
            page,
            "Transparency (0-100)",
            15,
            y,
            0,
            100,
            1
        )
        y = y + 24

        SettingsPage.controls.plates_width, SettingsPage.controls.plates_width_val = CreateSlider(
            "polarUiPlatesWidth",
            page,
            "Width",
            15,
            y,
            50,
            250,
            1
        )
        y = y + 24

        SettingsPage.controls.plates_hp_h, SettingsPage.controls.plates_hp_h_val = CreateSlider(
            "polarUiPlatesHpHeight",
            page,
            "HP height",
            15,
            y,
            5,
            60,
            1
        )
        y = y + 24

        SettingsPage.controls.plates_mp_h, SettingsPage.controls.plates_mp_h_val = CreateSlider(
            "polarUiPlatesMpHeight",
            page,
            "MP height (0 hides)",
            15,
            y,
            0,
            40,
            1
        )
        y = y + 24

        SettingsPage.controls.plates_x_offset, SettingsPage.controls.plates_x_offset_val = CreateSlider(
            "polarUiPlatesXOffset",
            page,
            "X offset",
            15,
            y,
            -200,
            200,
            1
        )
        y = y + 24

        SettingsPage.controls.plates_max_dist, SettingsPage.controls.plates_max_dist_val = CreateSlider(
            "polarUiPlatesMaxDistance",
            page,
            "Max distance",
            15,
            y,
            1,
            300,
            1
        )
        y = y + 24

        SettingsPage.controls.plates_y_offset, SettingsPage.controls.plates_y_offset_val = CreateSlider(
            "polarUiPlatesYOffset",
            page,
            "Y offset",
            15,
            y,
            -100,
            100,
            1
        )
        y = y + gap

        SettingsPage.controls.plates_anchor_tag = CreateCheckbox(
            "polarUiPlatesAnchorToTag",
            page,
            "Anchor to stock name tag",
            15,
            y
        )
        y = y + gap

        SettingsPage.controls.plates_bg_enabled = CreateCheckbox(
            "polarUiPlatesBgEnabled",
            page,
            "Show background",
            15,
            y
        )
        y = y + gap

        SettingsPage.controls.plates_bg_alpha, SettingsPage.controls.plates_bg_alpha_val = CreateSlider(
            "polarUiPlatesBgAlpha",
            page,
            "Background alpha (0-100)",
            15,
            y,
            0,
            100,
            1
        )
        y = y + gap + 10

        CreateLabel("polarUiPlatesTextHeader", page, "Text", 15, y, 18)
        y = y + 30

        SettingsPage.controls.plates_name_fs, SettingsPage.controls.plates_name_fs_val = CreateSlider(
            "polarUiPlatesNameFontSize",
            page,
            "Name font size",
            15,
            y,
            6,
            32,
            1
        )
        y = y + 24

        SettingsPage.controls.plates_guild_fs, SettingsPage.controls.plates_guild_fs_val = CreateSlider(
            "polarUiPlatesGuildFontSize",
            page,
            "Guild font size",
            15,
            y,
            6,
            32,
            1
        )
        y = y + 34

        CreateLabel("polarUiPlatesGuildColorsHeader", page, "Guild Colors", 15, y, 18)
        y = y + 30

        CreateLabel("polarUiPlatesGuildColorNameLbl", page, "Guild", 15, y, 15)
        SettingsPage.controls.plates_guild_color_name = CreateEdit("polarUiPlatesGuildColorName", page, "", 70, y - 4, 180, 22)
        SettingsPage.controls.plates_guild_color_add = CreateButton("polarUiPlatesGuildColorAdd", page, "Add", 265, y - 6)
        SettingsPage.controls.plates_guild_color_add_target = CreateButton("polarUiPlatesGuildColorAddTarget", page, "Use Target", 340, y - 6)
        if SettingsPage.controls.plates_guild_color_add ~= nil then
            SettingsPage.controls.plates_guild_color_add:SetExtent(70, 22)
        end
        if SettingsPage.controls.plates_guild_color_add_target ~= nil then
            SettingsPage.controls.plates_guild_color_add_target:SetExtent(95, 22)
        end
        y = y + 28

        SettingsPage.controls.plates_guild_color_r, SettingsPage.controls.plates_guild_color_r_val = CreateSlider(
            "polarUiPlatesGuildColorR",
            page,
            "R (0-255)",
            15,
            y,
            0,
            255,
            1
        )
        y = y + 24
        SettingsPage.controls.plates_guild_color_g, SettingsPage.controls.plates_guild_color_g_val = CreateSlider(
            "polarUiPlatesGuildColorG",
            page,
            "G (0-255)",
            15,
            y,
            0,
            255,
            1
        )
        y = y + 24
        SettingsPage.controls.plates_guild_color_b, SettingsPage.controls.plates_guild_color_b_val = CreateSlider(
            "polarUiPlatesGuildColorB",
            page,
            "B (0-255)",
            15,
            y,
            0,
            255,
            1
        )
        y = y + 30

        SettingsPage.controls.plates_guild_color_rows = {}
        for i = 1, 8 do
            local row_y = y
            local label = CreateLabel("polarUiPlatesGuildColorRow" .. tostring(i), page, "", 30, row_y, 14)
            if label ~= nil then
                label:SetExtent(280, 18)
            end
            local rm = CreateButton("polarUiPlatesGuildColorRemove" .. tostring(i), page, "Remove", 320, row_y - 6)
            if rm ~= nil then
                rm:SetExtent(80, 22)
            end
            SettingsPage.controls.plates_guild_color_rows[i] = { label = label, remove = rm }
            y = y + 26
        end
        SettingsPage.page_heights.plates = y + 40
    end

    do
        local page = SettingsPage.pages.cooldown
        if page ~= nil then
        local y = 35
        CreateLabel("polarUiCooldownPageTitle", page, "Cooldown Tracker", 15, y, 18)
        y = y + 30

        SettingsPage.controls.ct_enabled = CreateCheckbox(
            "polarUiCooldownEnabled",
            page,
            "Enable cooldown tracker",
            15,
            y
        )
        y = y + gap

        SettingsPage.controls.ct_update_interval, SettingsPage.controls.ct_update_interval_val = CreateSlider(
            "polarUiCooldownUpdateInterval",
            page,
            "Update interval (ms)",
            15,
            y,
            10,
            500,
            1
        )
        y = y + gap + 10

        CreateLabel("polarUiCooldownUnitLabel", page, "Unit", 15, y, 15)
        SettingsPage.controls.ct_unit = CreateComboBox(page, COOLDOWN_UNIT_LABELS, 110, y - 4, 220, 24)
        CreateLabel("polarUiCooldownDisplayModeLabel", page, "Show", 350, y, 15)
        SettingsPage.controls.ct_display_mode = CreateComboBox(page, COOLDOWN_DISPLAY_MODE_LABELS, 400, y - 4, 180, 24)
        y = y + 34

        SettingsPage.controls.ct_unit_enabled = CreateCheckbox(
            "polarUiCooldownUnitEnabled",
            page,
            "Enable for selected unit",
            15,
            y
        )
        y = y + gap

        SettingsPage.controls.ct_lock_position = CreateCheckbox(
            "polarUiCooldownLockPosition",
            page,
            "Lock position (disable dragging)",
            15,
            y
        )
        y = y + gap + 10

        CreateLabel("polarUiCooldownPositionTitle", page, "Position", 15, y, 18)
        y = y + 30

        SettingsPage.controls.ct_position_hint = CreateHintLabel(
            "polarUiCooldownPositionHint",
            page,
            "Player uses an absolute screen position.",
            15,
            y
        )
        if SettingsPage.controls.ct_position_hint ~= nil then
            SettingsPage.controls.ct_position_hint:SetExtent(360, 18)
        end
        y = y + 24

        CreateLabel("polarUiCooldownPosXLabel", page, "X", 15, y, 15)
        SettingsPage.controls.ct_pos_x = CreateEdit("polarUiCooldownPosX", page, "0", 35, y - 4, 90, 22)
        if SettingsPage.controls.ct_pos_x ~= nil and SettingsPage.controls.ct_pos_x.SetDigit ~= nil then
            pcall(function()
                SettingsPage.controls.ct_pos_x:SetDigit(true)
            end)
        end

        CreateLabel("polarUiCooldownPosYLabel", page, "Y", 145, y, 15)
        SettingsPage.controls.ct_pos_y = CreateEdit("polarUiCooldownPosY", page, "0", 165, y - 4, 90, 22)
        if SettingsPage.controls.ct_pos_y ~= nil and SettingsPage.controls.ct_pos_y.SetDigit ~= nil then
            pcall(function()
                SettingsPage.controls.ct_pos_y:SetDigit(true)
            end)
        end
        y = y + gap + 10

        CreateLabel("polarUiCooldownIconsTitle", page, "Icons", 15, y, 18)
        y = y + 30

        SettingsPage.controls.ct_icon_size, SettingsPage.controls.ct_icon_size_val = CreateSlider(
            "polarUiCooldownIconSize",
            page,
            "Icon size",
            15,
            y,
            12,
            80,
            1
        )
        y = y + 24

        SettingsPage.controls.ct_icon_spacing, SettingsPage.controls.ct_icon_spacing_val = CreateSlider(
            "polarUiCooldownIconSpacing",
            page,
            "Icon spacing",
            15,
            y,
            0,
            20,
            1
        )
        y = y + 24

        SettingsPage.controls.ct_max_icons, SettingsPage.controls.ct_max_icons_val = CreateSlider(
            "polarUiCooldownMaxIcons",
            page,
            "Max icons",
            15,
            y,
            1,
            20,
            1
        )
        y = y + gap + 10

        CreateLabel("polarUiCooldownTimerTitle", page, "Timer Text", 15, y, 18)
        y = y + 30

        SettingsPage.controls.ct_show_timer = CreateCheckbox("polarUiCooldownShowTimer", page, "Show timer", 15, y)
        y = y + gap

        SettingsPage.controls.ct_timer_fs, SettingsPage.controls.ct_timer_fs_val = CreateSlider(
            "polarUiCooldownTimerFontSize",
            page,
            "Timer font size",
            15,
            y,
            6,
            40,
            1
        )
        y = y + 24

        CreateLabel("polarUiCooldownTimerColorTitle", page, "Timer color (RGB)", 15, y, 15)
        y = y + 22
        SettingsPage.controls.ct_timer_r, SettingsPage.controls.ct_timer_r_val = CreateSlider("polarUiCooldownTimerR", page, "R", 15, y, 0, 255, 1)
        y = y + 24
        SettingsPage.controls.ct_timer_g, SettingsPage.controls.ct_timer_g_val = CreateSlider("polarUiCooldownTimerG", page, "G", 15, y, 0, 255, 1)
        y = y + 24
        SettingsPage.controls.ct_timer_b, SettingsPage.controls.ct_timer_b_val = CreateSlider("polarUiCooldownTimerB", page, "B", 15, y, 0, 255, 1)
        y = y + gap + 10

        CreateLabel("polarUiCooldownLabelTitle", page, "Label Text", 15, y, 18)
        y = y + 30

        SettingsPage.controls.ct_show_label = CreateCheckbox("polarUiCooldownShowLabel", page, "Show label", 15, y)
        y = y + gap

        SettingsPage.controls.ct_label_fs, SettingsPage.controls.ct_label_fs_val = CreateSlider(
            "polarUiCooldownLabelFontSize",
            page,
            "Label font size",
            15,
            y,
            6,
            40,
            1
        )
        y = y + 24

        CreateLabel("polarUiCooldownLabelColorTitle", page, "Label color (RGB)", 15, y, 15)
        y = y + 22
        SettingsPage.controls.ct_label_r, SettingsPage.controls.ct_label_r_val = CreateSlider("polarUiCooldownLabelR", page, "R", 15, y, 0, 255, 1)
        y = y + 24
        SettingsPage.controls.ct_label_g, SettingsPage.controls.ct_label_g_val = CreateSlider("polarUiCooldownLabelG", page, "G", 15, y, 0, 255, 1)
        y = y + 24
        SettingsPage.controls.ct_label_b, SettingsPage.controls.ct_label_b_val = CreateSlider("polarUiCooldownLabelB", page, "B", 15, y, 0, 255, 1)
        y = y + gap + 10

        CreateLabel("polarUiCooldownTargetCacheTitle", page, "Target Cache", 15, y, 18)
        y = y + 30

        SettingsPage.controls.ct_cache_timeout, SettingsPage.controls.ct_cache_timeout_val = CreateSlider(
            "polarUiCooldownCacheTimeout",
            page,
            "Cache timeout (sec) (target only)",
            15,
            y,
            0,
            600,
            1
        )
        y = y + gap + 10

        CreateLabel("polarUiCooldownTrackedBuffsTitle", page, "Tracked Effects", 15, y, 18)
        y = y + 30

        SettingsPage.controls.ct_new_buff_id = CreateEdit("polarUiCooldownNewBuffId", page, "", 15, y - 4, 120, 22)
        if SettingsPage.controls.ct_new_buff_id ~= nil and SettingsPage.controls.ct_new_buff_id.SetDigit ~= nil then
            pcall(function()
                SettingsPage.controls.ct_new_buff_id:SetDigit(true)
            end)
        end
        SettingsPage.controls.ct_add_buff = CreateButton("polarUiCooldownAddBuff", page, "Add", 145, y - 6)
        CreateLabel("polarUiCooldownTrackKindLabel", page, "Track as", 225, y, 15)
        SettingsPage.controls.ct_track_kind = CreateComboBox(page, COOLDOWN_TRACK_KIND_LABELS, 290, y - 4, 110, 24)
        CreateLabel("polarUiCooldownSearchLabel", page, "Search", 420, y, 15)
        SettingsPage.controls.ct_search_text = CreateEdit("polarUiCooldownSearchText", page, "", 470, y - 4, 95, 22)
        SettingsPage.controls.ct_search_btn = CreateButton("polarUiCooldownSearchBtn", page, "Find", 575, y - 6)
        if SettingsPage.controls.ct_search_btn ~= nil then
            SettingsPage.controls.ct_search_btn:SetExtent(50, 22)
        end
        y = y + 34

        SettingsPage.controls.ct_search_status = CreateLabel("polarUiCooldownSearchStatus", page, "", 15, y, 14)
        if SettingsPage.controls.ct_search_status ~= nil then
            SettingsPage.controls.ct_search_status:SetExtent(380, 18)
        end
        SettingsPage.controls.ct_search_more = CreateButton("polarUiCooldownSearchMore", page, "More", 405, y - 6)
        if SettingsPage.controls.ct_search_more ~= nil then
            SettingsPage.controls.ct_search_more:SetExtent(65, 22)
        end
        y = y + 34

        SettingsPage.controls.ct_search_rows = {}
        for i = 1, COOLDOWN_SEARCH_ROWS do
            local row_y = y + ((i - 1) * 26)
            local label = CreateLabel("polarUiCooldownSearchRowLabel" .. tostring(i), page, "", 15, row_y + 6, 14)
            if label ~= nil then
                label:SetExtent(310, 18)
            end
            local add = CreateButton("polarUiCooldownSearchRowAdd" .. tostring(i), page, "Add", 335, row_y)
            if add ~= nil then
                add:SetExtent(60, 22)
            end
            SettingsPage.controls.ct_search_rows[i] = { label = label, add = add }
        end
        y = y + (COOLDOWN_SEARCH_ROWS * 26) + 10

        SettingsPage.controls.ct_prev_page = CreateButton("polarUiCooldownPrevPage", page, "Prev", 15, y)
        SettingsPage.controls.ct_next_page = CreateButton("polarUiCooldownNextPage", page, "Next", 110, y)
        SettingsPage.controls.ct_page_label = CreateLabel("polarUiCooldownPageLabel", page, "1 / 1", 215, y + 6, 14)
        y = y + 34

        SettingsPage.controls.ct_buff_rows = {}
        for i = 1, COOLDOWN_BUFFS_PER_PAGE do
            local row_y = y + ((i - 1) * 26)
            local label = CreateLabel("polarUiCooldownBuffRowLabel" .. tostring(i), page, "", 15, row_y + 6, 14)
            if label ~= nil then
                label:SetExtent(280, 18)
            end
            local rm = CreateButton("polarUiCooldownBuffRowRemove" .. tostring(i), page, "Remove", 305, row_y)
            if rm ~= nil then
                rm:SetExtent(90, 22)
            end
            SettingsPage.controls.ct_buff_rows[i] = { label = label, remove = rm }
        end
        y = y + (COOLDOWN_BUFFS_PER_PAGE * 26) + 20

        CreateLabel("polarUiCooldownScanTitle", page, "Scan Target Buffs/Debuffs", 15, y, 18)
        y = y + 30

        SettingsPage.controls.ct_scan_btn = CreateButton("polarUiCooldownScanBtn", page, "Scan", 15, y - 6)
        SettingsPage.controls.ct_scan_status = CreateLabel("polarUiCooldownScanStatus", page, "", 110, y, 14)
        if SettingsPage.controls.ct_scan_status ~= nil then
            SettingsPage.controls.ct_scan_status:SetExtent(320, 18)
        end
        y = y + 34

        SettingsPage.controls.ct_scan_rows = {}
        for i = 1, COOLDOWN_SCAN_ROWS do
            local row_y = y + ((i - 1) * 26)
            local label = CreateLabel("polarUiCooldownScanRowLabel" .. tostring(i), page, "", 15, row_y + 6, 14)
            if label ~= nil then
                label:SetExtent(310, 18)
            end
            local add = CreateButton("polarUiCooldownScanRowAdd" .. tostring(i), page, "Add", 335, row_y)
            if add ~= nil then
                add:SetExtent(60, 22)
            end
            SettingsPage.controls.ct_scan_rows[i] = { label = label, add = add }
        end
        y = y + (COOLDOWN_SCAN_ROWS * 26) + 20

        SettingsPage.page_heights.cooldown = y + 40
        end
    end

    local applyBtn = CreateButton("polarUiApplySettings", SettingsPage.window, "Apply", 185, 370)
    local closeBtn = CreateButton("polarUiCloseSettings", SettingsPage.window, "Close", 280, 370)
    local backupBtn = CreateButton("polarUiBackupSettings", SettingsPage.window, "Backup", 375, 370)
    local importBtn = CreateButton("polarUiImportSettings", SettingsPage.window, "Import", 470, 370)
    local backupStatus = CreateLabel("polarUiBackupStatus", SettingsPage.window, "", 570, 370 + 6, 14)
    if backupStatus ~= nil then
        backupStatus:SetExtent(220, 18)
    end

    pcall(function()
        applyBtn:RemoveAllAnchors()
        closeBtn:RemoveAllAnchors()
        if backupBtn ~= nil then
            backupBtn:RemoveAllAnchors()
        end
        if importBtn ~= nil then
            importBtn:RemoveAllAnchors()
        end
        if backupStatus ~= nil then
            backupStatus:RemoveAllAnchors()
        end
        applyBtn:AddAnchor("BOTTOMLEFT", SettingsPage.window, 185, -15)
        closeBtn:AddAnchor("BOTTOMLEFT", SettingsPage.window, 280, -15)
        if backupBtn ~= nil then
            backupBtn:AddAnchor("BOTTOMLEFT", SettingsPage.window, 375, -15)
        end
        if importBtn ~= nil then
            importBtn:AddAnchor("BOTTOMLEFT", SettingsPage.window, 470, -15)
        end
        if backupStatus ~= nil then
            backupStatus:AddAnchor("BOTTOMLEFT", SettingsPage.window, 570, -11)
        end
    end)

    SetActivePage("general")

    local function syncStyleTargetFromActivePage()
        local ctrl = nil
        if SettingsPage.active_page == "text" then
            ctrl = SettingsPage.controls.style_target_text
        elseif SettingsPage.active_page == "bars" then
            ctrl = SettingsPage.controls.style_target_bars
        else
            return
        end
        SettingsPage.style_target = GetStyleTargetKeyFromControl(ctrl)
        UpdateStyleTargetHints()
    end

    local function sliderChanged()
        if SettingsPage.settings == nil then
            return
        end
        syncStyleTargetFromActivePage()
        ApplyControlsToSettings()
        if type(SettingsPage.on_apply) == "function" then
            pcall(function()
                SettingsPage.on_apply()
            end)
        end
    end

    local sliderList = {
        { SettingsPage.controls.launcher_size, SettingsPage.controls.launcher_size_val },
        { SettingsPage.controls.frame_alpha, SettingsPage.controls.frame_alpha_val },
        { SettingsPage.controls.overlay_alpha, SettingsPage.controls.overlay_alpha_val },
        { SettingsPage.controls.frame_width, SettingsPage.controls.frame_width_val },
        { SettingsPage.controls.frame_height, SettingsPage.controls.frame_height_val },
        { SettingsPage.controls.frame_scale, SettingsPage.controls.frame_scale_val },
        { SettingsPage.controls.bar_height, SettingsPage.controls.bar_height_val },
        { SettingsPage.controls.hp_bar_height, SettingsPage.controls.hp_bar_height_val },
        { SettingsPage.controls.mp_bar_height, SettingsPage.controls.mp_bar_height_val },
        { SettingsPage.controls.bar_gap, SettingsPage.controls.bar_gap_val },
        { SettingsPage.controls.name_font_size, SettingsPage.controls.name_font_size_val },
        { SettingsPage.controls.hp_font_size, SettingsPage.controls.hp_font_size_val },
        { SettingsPage.controls.mp_font_size, SettingsPage.controls.mp_font_size_val },
        { SettingsPage.controls.overlay_font_size, SettingsPage.controls.overlay_font_size_val },
        { SettingsPage.controls.gs_font_size, SettingsPage.controls.gs_font_size_val },
        { SettingsPage.controls.class_font_size, SettingsPage.controls.class_font_size_val },
        { SettingsPage.controls.target_guild_font_size, SettingsPage.controls.target_guild_font_size_val },
        { SettingsPage.controls.target_guild_r, SettingsPage.controls.target_guild_r_val },
        { SettingsPage.controls.target_guild_g, SettingsPage.controls.target_guild_g_val },
        { SettingsPage.controls.target_guild_b, SettingsPage.controls.target_guild_b_val },
        { SettingsPage.controls.target_class_r, SettingsPage.controls.target_class_r_val },
        { SettingsPage.controls.target_class_g, SettingsPage.controls.target_class_g_val },
        { SettingsPage.controls.target_class_b, SettingsPage.controls.target_class_b_val },
        { SettingsPage.controls.target_pdef_r, SettingsPage.controls.target_pdef_r_val },
        { SettingsPage.controls.target_pdef_g, SettingsPage.controls.target_pdef_g_val },
        { SettingsPage.controls.target_pdef_b, SettingsPage.controls.target_pdef_b_val },
        { SettingsPage.controls.target_mdef_r, SettingsPage.controls.target_mdef_r_val },
        { SettingsPage.controls.target_mdef_g, SettingsPage.controls.target_mdef_g_val },
        { SettingsPage.controls.target_mdef_b, SettingsPage.controls.target_mdef_b_val },
        { SettingsPage.controls.target_gearscore_r, SettingsPage.controls.target_gearscore_r_val },
        { SettingsPage.controls.target_gearscore_g, SettingsPage.controls.target_gearscore_g_val },
        { SettingsPage.controls.target_gearscore_b, SettingsPage.controls.target_gearscore_b_val },
        { SettingsPage.controls.hp_value_offset_x, SettingsPage.controls.hp_value_offset_x_val },
        { SettingsPage.controls.hp_value_offset_y, SettingsPage.controls.hp_value_offset_y_val },
        { SettingsPage.controls.mp_value_offset_x, SettingsPage.controls.mp_value_offset_x_val },
        { SettingsPage.controls.mp_value_offset_y, SettingsPage.controls.mp_value_offset_y_val },
        { SettingsPage.controls.target_guild_offset_x, SettingsPage.controls.target_guild_offset_x_val },
        { SettingsPage.controls.target_guild_offset_y, SettingsPage.controls.target_guild_offset_y_val },
        { SettingsPage.controls.name_offset_x, SettingsPage.controls.name_offset_x_val },
        { SettingsPage.controls.name_offset_y, SettingsPage.controls.name_offset_y_val },
        { SettingsPage.controls.level_font_size, SettingsPage.controls.level_font_size_val },
        { SettingsPage.controls.level_offset_x, SettingsPage.controls.level_offset_x_val },
        { SettingsPage.controls.level_offset_y, SettingsPage.controls.level_offset_y_val },
        { SettingsPage.controls.hp_r, SettingsPage.controls.hp_r_val },
        { SettingsPage.controls.hp_g, SettingsPage.controls.hp_g_val },
        { SettingsPage.controls.hp_b, SettingsPage.controls.hp_b_val },
        { SettingsPage.controls.hp_a, SettingsPage.controls.hp_a_val },
        { SettingsPage.controls.hp_after_r, SettingsPage.controls.hp_after_r_val },
        { SettingsPage.controls.hp_after_g, SettingsPage.controls.hp_after_g_val },
        { SettingsPage.controls.hp_after_b, SettingsPage.controls.hp_after_b_val },
        { SettingsPage.controls.hp_after_a, SettingsPage.controls.hp_after_a_val },
        { SettingsPage.controls.mp_r, SettingsPage.controls.mp_r_val },
        { SettingsPage.controls.mp_g, SettingsPage.controls.mp_g_val },
        { SettingsPage.controls.mp_b, SettingsPage.controls.mp_b_val },
        { SettingsPage.controls.mp_a, SettingsPage.controls.mp_a_val },
        { SettingsPage.controls.mp_after_r, SettingsPage.controls.mp_after_r_val },
        { SettingsPage.controls.mp_after_g, SettingsPage.controls.mp_after_g_val },
        { SettingsPage.controls.mp_after_b, SettingsPage.controls.mp_after_b_val },
        { SettingsPage.controls.mp_after_a, SettingsPage.controls.mp_after_a_val },
        { SettingsPage.controls.p_buff_x, SettingsPage.controls.p_buff_x_val },
        { SettingsPage.controls.p_buff_y, SettingsPage.controls.p_buff_y_val },
        { SettingsPage.controls.p_debuff_x, SettingsPage.controls.p_debuff_x_val },
        { SettingsPage.controls.p_debuff_y, SettingsPage.controls.p_debuff_y_val },
        { SettingsPage.controls.t_buff_x, SettingsPage.controls.t_buff_x_val },
        { SettingsPage.controls.t_buff_y, SettingsPage.controls.t_buff_y_val },
        { SettingsPage.controls.t_debuff_x, SettingsPage.controls.t_debuff_x_val },
        { SettingsPage.controls.t_debuff_y, SettingsPage.controls.t_debuff_y_val },
        { SettingsPage.controls.aura_icon_size, SettingsPage.controls.aura_icon_size_val },
        { SettingsPage.controls.aura_x_gap, SettingsPage.controls.aura_x_gap_val },
        { SettingsPage.controls.aura_y_gap, SettingsPage.controls.aura_y_gap_val },
        { SettingsPage.controls.aura_per_row, SettingsPage.controls.aura_per_row_val },
        { SettingsPage.controls.plates_alpha, SettingsPage.controls.plates_alpha_val },
        { SettingsPage.controls.plates_width, SettingsPage.controls.plates_width_val },
        { SettingsPage.controls.plates_hp_h, SettingsPage.controls.plates_hp_h_val },
        { SettingsPage.controls.plates_mp_h, SettingsPage.controls.plates_mp_h_val },
        { SettingsPage.controls.plates_x_offset, SettingsPage.controls.plates_x_offset_val },
        { SettingsPage.controls.plates_max_dist, SettingsPage.controls.plates_max_dist_val },
        { SettingsPage.controls.plates_y_offset, SettingsPage.controls.plates_y_offset_val },
        { SettingsPage.controls.plates_bg_alpha, SettingsPage.controls.plates_bg_alpha_val },
        { SettingsPage.controls.plates_name_fs, SettingsPage.controls.plates_name_fs_val },
        { SettingsPage.controls.plates_guild_fs, SettingsPage.controls.plates_guild_fs_val },
        { SettingsPage.controls.ct_update_interval, SettingsPage.controls.ct_update_interval_val },
        { SettingsPage.controls.ct_icon_size, SettingsPage.controls.ct_icon_size_val },
        { SettingsPage.controls.ct_icon_spacing, SettingsPage.controls.ct_icon_spacing_val },
        { SettingsPage.controls.ct_max_icons, SettingsPage.controls.ct_max_icons_val },
        { SettingsPage.controls.ct_timer_fs, SettingsPage.controls.ct_timer_fs_val },
        { SettingsPage.controls.ct_label_fs, SettingsPage.controls.ct_label_fs_val },
        { SettingsPage.controls.ct_timer_r, SettingsPage.controls.ct_timer_r_val },
        { SettingsPage.controls.ct_timer_g, SettingsPage.controls.ct_timer_g_val },
        { SettingsPage.controls.ct_timer_b, SettingsPage.controls.ct_timer_b_val },
        { SettingsPage.controls.ct_label_r, SettingsPage.controls.ct_label_r_val },
        { SettingsPage.controls.ct_label_g, SettingsPage.controls.ct_label_g_val },
        { SettingsPage.controls.ct_label_b, SettingsPage.controls.ct_label_b_val },
        { SettingsPage.controls.ct_cache_timeout, SettingsPage.controls.ct_cache_timeout_val }
    }

    for _, pair in ipairs(sliderList) do
        local slider = pair[1]
        local valLabel = pair[2]
        if slider ~= nil and slider.SetHandler ~= nil then
            slider:SetHandler("OnSliderChanged", function(_, value)
                if valLabel ~= nil and valLabel.SetText ~= nil and type(value) == "number" then
                    valLabel:SetText(tostring(math.floor(value + 0.5)))
                end
                sliderChanged()
            end)
        end
    end

    local function bindValueLabelOnly(slider, valLabel)
        if slider ~= nil and slider.SetHandler ~= nil then
            slider:SetHandler("OnSliderChanged", function(_, value)
                if valLabel ~= nil and valLabel.SetText ~= nil and type(value) == "number" then
                    valLabel:SetText(tostring(math.floor(value + 0.5)))
                end
            end)
        end
    end

    bindValueLabelOnly(SettingsPage.controls.plates_guild_color_r, SettingsPage.controls.plates_guild_color_r_val)
    bindValueLabelOnly(SettingsPage.controls.plates_guild_color_g, SettingsPage.controls.plates_guild_color_g_val)
    bindValueLabelOnly(SettingsPage.controls.plates_guild_color_b, SettingsPage.controls.plates_guild_color_b_val)

    local checkboxList = {
        SettingsPage.controls.aura_enabled,
        SettingsPage.controls.aura_sort_vertical,
        SettingsPage.controls.name_visible,
        SettingsPage.controls.level_visible,
        SettingsPage.controls.large_hpmp,
        SettingsPage.controls.show_distance,
        SettingsPage.controls.alignment_grid_enabled,
        SettingsPage.controls.bar_colors_enabled,
        SettingsPage.controls.overlay_shadow,
        SettingsPage.controls.target_guild_visible,
        SettingsPage.controls.target_class_visible,
        SettingsPage.controls.target_gearscore_visible,
        SettingsPage.controls.target_pdef_visible,
        SettingsPage.controls.target_mdef_visible,
        SettingsPage.controls.name_shadow,
        SettingsPage.controls.value_shadow,
        SettingsPage.controls.buff_windows_enabled,
        SettingsPage.controls.plates_enabled,
        SettingsPage.controls.plates_guild_only,
        SettingsPage.controls.plates_show_target,
        SettingsPage.controls.plates_show_player,
        SettingsPage.controls.plates_show_raid_party,
        SettingsPage.controls.plates_show_watchtarget,
        SettingsPage.controls.plates_show_mount,
        SettingsPage.controls.plates_show_guild,
        SettingsPage.controls.plates_anchor_tag,
        SettingsPage.controls.plates_bg_enabled,
        SettingsPage.controls.ct_enabled,
        SettingsPage.controls.ct_unit_enabled,
        SettingsPage.controls.ct_lock_position,
        SettingsPage.controls.ct_show_timer,
        SettingsPage.controls.ct_show_label
    }

    if SettingsPage.controls.ct_unit ~= nil and SettingsPage.controls.ct_unit.SetHandler ~= nil then
        SettingsPage.controls.ct_unit:SetHandler("OnSelChanged", function()
            local idx = GetComboBoxIndex1Based(SettingsPage.controls.ct_unit, #COOLDOWN_UNIT_KEYS)
            if idx == nil then
                return
            end
            SettingsPage.cooldown_unit_key = GetCooldownUnitKeyFromIndex(idx)
            SettingsPage.cooldown_buff_page = 1
            RefreshControls()
        end)
    end

    if SettingsPage.controls.ct_display_mode ~= nil and SettingsPage.controls.ct_display_mode.SetHandler ~= nil then
        SettingsPage.controls.ct_display_mode:SetHandler("OnSelChanged", function()
            ApplyControlsToSettings()
            if type(SettingsPage.on_apply) == "function" then
                pcall(function()
                    SettingsPage.on_apply()
                end)
            end
            RefreshControls()
        end)
    end

    if SettingsPage.controls.ct_track_kind ~= nil and SettingsPage.controls.ct_track_kind.SetHandler ~= nil then
        SettingsPage.controls.ct_track_kind:SetHandler("OnSelChanged", function()
            local idx = GetComboBoxIndex1Based(SettingsPage.controls.ct_track_kind, #COOLDOWN_TRACK_KIND_LABELS)
            SettingsPage.cooldown_track_kind = GetCooldownTrackKindFromIndex(idx)
        end)
    end

    if SettingsPage.controls.plates_guild_color_add_target ~= nil and SettingsPage.controls.plates_guild_color_add_target.SetHandler ~= nil then
        SettingsPage.controls.plates_guild_color_add_target:SetHandler("OnClick", function()
            if SettingsPage.settings == nil then
                return
            end

            local guild = ""
            pcall(function()
                if api.Unit ~= nil and api.Unit.GetUnitId ~= nil and api.Unit.GetUnitInfoById ~= nil then
                    local id = api.Unit:GetUnitId("target")
                    local normalizedId = nil
                    if type(id) == "string" then
                        normalizedId = tostring(id)
                    elseif type(id) == "number" then
                        normalizedId = tostring(id)
                    end
                    if normalizedId ~= nil and normalizedId ~= "" then
                        local info = api.Unit:GetUnitInfoById(normalizedId)
                        if type(info) == "table" and info.expeditionName ~= nil then
                            guild = tostring(info.expeditionName or "")
                        end
                    end
                end
            end)
            guild = tostring(guild or "")
            guild = string.match(guild, "^%s*(.-)%s*$") or guild
            if guild == "" then
                return
            end

            if type(SettingsPage.settings.nameplates) ~= "table" then
                SettingsPage.settings.nameplates = {}
            end
            if type(SettingsPage.settings.nameplates.guild_colors) ~= "table" then
                SettingsPage.settings.nameplates.guild_colors = {}
            end

            local r = GetSliderValue(SettingsPage.controls.plates_guild_color_r)
            local g = GetSliderValue(SettingsPage.controls.plates_guild_color_g)
            local b = GetSliderValue(SettingsPage.controls.plates_guild_color_b)
            local key = string.lower(guild)
            key = string.gsub(key, "%s+", "_")
            key = string.gsub(key, "[^%w_]", "")
            if key ~= "" and string.match(key, "^%d") ~= nil then
                key = "_" .. key
            end
            SettingsPage.settings.nameplates.guild_colors[key] = { (r or 255) / 255, (g or 255) / 255, (b or 255) / 255, 1 }

            pcall(function()
                if SettingsPage.controls.plates_guild_color_name ~= nil and SettingsPage.controls.plates_guild_color_name.SetText ~= nil then
                    SettingsPage.controls.plates_guild_color_name:SetText(guild)
                end
            end)

            if type(SettingsPage.on_apply) == "function" then
                pcall(function()
                    SettingsPage.on_apply()
                end)
            end
            if type(SettingsPage.on_save) == "function" then
                pcall(function()
                    SettingsPage.on_save()
                end)
            end
            RefreshControls()
        end)
    end

    if SettingsPage.controls.plates_guild_color_add ~= nil and SettingsPage.controls.plates_guild_color_add.SetHandler ~= nil then
        SettingsPage.controls.plates_guild_color_add:SetHandler("OnClick", function()
            if SettingsPage.settings == nil then
                return
            end
            if type(SettingsPage.settings.nameplates) ~= "table" then
                SettingsPage.settings.nameplates = {}
            end
            if type(SettingsPage.settings.nameplates.guild_colors) ~= "table" then
                SettingsPage.settings.nameplates.guild_colors = {}
            end

            local guild = GetEditText(SettingsPage.controls.plates_guild_color_name)
            guild = tostring(guild or "")
            guild = string.match(guild, "^%s*(.-)%s*$") or guild
            if guild == "" then
                return
            end

            local r = GetSliderValue(SettingsPage.controls.plates_guild_color_r)
            local g = GetSliderValue(SettingsPage.controls.plates_guild_color_g)
            local b = GetSliderValue(SettingsPage.controls.plates_guild_color_b)
            local key = string.lower(guild)
            key = string.gsub(key, "%s+", "_")
            key = string.gsub(key, "[^%w_]", "")
            if key ~= "" and string.match(key, "^%d") ~= nil then
                key = "_" .. key
            end
            SettingsPage.settings.nameplates.guild_colors[key] = { (r or 255) / 255, (g or 255) / 255, (b or 255) / 255, 1 }

            if type(SettingsPage.on_apply) == "function" then
                pcall(function()
                    SettingsPage.on_apply()
                end)
            end
            if type(SettingsPage.on_save) == "function" then
                pcall(function()
                    SettingsPage.on_save()
                end)
            end
            RefreshControls()
        end)
    end

    if type(SettingsPage.controls.plates_guild_color_rows) == "table" then
        for _, row in ipairs(SettingsPage.controls.plates_guild_color_rows) do
            if type(row) == "table" and row.remove ~= nil and row.remove.SetHandler ~= nil then
                local btn = row.remove
                btn:SetHandler("OnClick", function()
                    if SettingsPage.settings == nil or type(SettingsPage.settings.nameplates) ~= "table" then
                        return
                    end
                    if type(SettingsPage.settings.nameplates.guild_colors) ~= "table" then
                        return
                    end
                    local key = tostring(btn.__polar_guild_key or "")
                    if key == "" then
                        return
                    end
                    SettingsPage.settings.nameplates.guild_colors[key] = nil
                    if type(SettingsPage.on_apply) == "function" then
                        pcall(function()
                            SettingsPage.on_apply()
                        end)
                    end
                    if type(SettingsPage.on_save) == "function" then
                        pcall(function()
                            SettingsPage.on_save()
                        end)
                    end
                    RefreshControls()
                end)
            end
        end
    end

    if SettingsPage.controls.ct_scan_btn ~= nil and SettingsPage.controls.ct_scan_btn.SetHandler ~= nil then
        SettingsPage.controls.ct_scan_btn:SetHandler("OnClick", function()
            ScanTargetEffects()
            RefreshControls()
        end)
    end

    if type(SettingsPage.controls.ct_scan_rows) == "table" then
        for _, row in ipairs(SettingsPage.controls.ct_scan_rows) do
            if type(row) == "table" and row.add ~= nil and row.add.SetHandler ~= nil then
                local btn = row.add
                row.add:SetHandler("OnClick", function()
                    if SettingsPage.settings == nil then
                        return
                    end
                    local idx = tonumber(btn ~= nil and btn.__polar_scan_index or nil)
                    local entry = (type(SettingsPage.cooldown_scan_results) == "table") and SettingsPage.cooldown_scan_results[idx] or nil
                    if type(entry) ~= "table" then
                        return
                    end

                    local id = tostring(entry.id or "")
                    if id == "" then
                        return
                    end
                    AddCooldownTrackedBuffToSelectedUnit(id, entry.kind)
                    RefreshControls()
                end)
            end
        end
    end

    if SettingsPage.controls.ct_add_buff ~= nil and SettingsPage.controls.ct_add_buff.SetHandler ~= nil then
        SettingsPage.controls.ct_add_buff:SetHandler("OnClick", function()
            if SettingsPage.settings == nil then
                return
            end
            local txt = GetEditText(SettingsPage.controls.ct_new_buff_id)
            txt = tostring(txt or "")
            txt = txt:gsub("%s+", "")
            if txt == "" then
                return
            end
            local numericId = tonumber(txt)
            if numericId == nil then
                return
            end
            txt = FormatBuffId(math.floor(numericId + 0.5))

            local kindIdx = GetComboBoxIndex1Based(SettingsPage.controls.ct_track_kind, #COOLDOWN_TRACK_KIND_LABELS)
            SettingsPage.cooldown_track_kind = GetCooldownTrackKindFromIndex(kindIdx)
            AddCooldownTrackedBuffToSelectedUnit(txt, SettingsPage.cooldown_track_kind)
            if SettingsPage.controls.ct_new_buff_id ~= nil and SettingsPage.controls.ct_new_buff_id.SetText ~= nil then
                SettingsPage.controls.ct_new_buff_id:SetText("")
            end
            RefreshControls()
        end)
    end

    if SettingsPage.controls.ct_search_btn ~= nil and SettingsPage.controls.ct_search_btn.SetHandler ~= nil then
        SettingsPage.controls.ct_search_btn:SetHandler("OnClick", function()
            RunCooldownBuffSearch(false)
        end)
    end

    if SettingsPage.controls.ct_search_more ~= nil and SettingsPage.controls.ct_search_more.SetHandler ~= nil then
        SettingsPage.controls.ct_search_more:SetHandler("OnClick", function()
            RunCooldownBuffSearch(true)
        end)
    end

    if type(SettingsPage.controls.ct_search_rows) == "table" then
        for _, row in ipairs(SettingsPage.controls.ct_search_rows) do
            if type(row) == "table" and row.add ~= nil and row.add.SetHandler ~= nil then
                local btn = row.add
                row.add:SetHandler("OnClick", function()
                    local rawId = tostring(btn ~= nil and btn.__polar_search_id or "")
                    if rawId == "" then
                        return
                    end
                    local kindIdx = GetComboBoxIndex1Based(SettingsPage.controls.ct_track_kind, #COOLDOWN_TRACK_KIND_LABELS)
                    SettingsPage.cooldown_track_kind = GetCooldownTrackKindFromIndex(kindIdx)
                    AddCooldownTrackedBuffToSelectedUnit(rawId, SettingsPage.cooldown_track_kind)
                    RefreshControls()
                end)
            end
        end
    end

    if SettingsPage.controls.ct_prev_page ~= nil and SettingsPage.controls.ct_prev_page.SetHandler ~= nil then
        SettingsPage.controls.ct_prev_page:SetHandler("OnClick", function()
            SettingsPage.cooldown_buff_page = (tonumber(SettingsPage.cooldown_buff_page) or 1) - 1
            RefreshControls()
        end)
    end

    if SettingsPage.controls.ct_next_page ~= nil and SettingsPage.controls.ct_next_page.SetHandler ~= nil then
        SettingsPage.controls.ct_next_page:SetHandler("OnClick", function()
            SettingsPage.cooldown_buff_page = (tonumber(SettingsPage.cooldown_buff_page) or 1) + 1
            RefreshControls()
        end)
    end

    if type(SettingsPage.controls.ct_buff_rows) == "table" then
        for _, row in ipairs(SettingsPage.controls.ct_buff_rows) do
            if type(row) == "table" and row.remove ~= nil and row.remove.SetHandler ~= nil then
                local btn = row.remove
                row.remove:SetHandler("OnClick", function()
                    if SettingsPage.settings == nil then
                        return
                    end
                    EnsureCooldownTrackerTables(SettingsPage.settings)
                    local unit_key = tostring(SettingsPage.cooldown_unit_key or "player")
                    local unit_cfg = SettingsPage.settings.cooldown_tracker.units[unit_key]
                    if type(unit_cfg) ~= "table" or type(unit_cfg.tracked_buffs) ~= "table" then
                        return
                    end
                    local idx = tonumber(btn ~= nil and btn.__polar_buff_index or nil)
                    if idx == nil or idx < 1 or idx > #unit_cfg.tracked_buffs then
                        return
                    end
                    table.remove(unit_cfg.tracked_buffs, idx)
                    if type(SettingsPage.on_apply) == "function" then
                        pcall(function()
                            SettingsPage.on_apply()
                        end)
                    end
                    RefreshControls()
                end)
            end
        end
    end

    local function styleTargetChanged(ctrl, a, b)
        if SettingsPage._refreshing_style_target then
            return
        end
        if ctrl == SettingsPage.controls.style_target_text and SettingsPage.active_page ~= "text" then
            return
        end
        if ctrl == SettingsPage.controls.style_target_bars and SettingsPage.active_page ~= "bars" then
            return
        end
        if ctrl == nil then
            return
        end
        SettingsPage.style_target = GetStyleTargetKeyFromControl(ctrl, a, b)
        UpdateStyleTargetHints()
        RefreshControls()
    end

    if SettingsPage.controls.style_target_text ~= nil and SettingsPage.controls.style_target_text.SetHandler ~= nil then
        SettingsPage.controls.style_target_text:SetHandler("OnSelChanged", function(a, b)
            styleTargetChanged(SettingsPage.controls.style_target_text, a, b)
        end)
    end
    if SettingsPage.controls.style_target_bars ~= nil and SettingsPage.controls.style_target_bars.SetHandler ~= nil then
        SettingsPage.controls.style_target_bars:SetHandler("OnSelChanged", function(a, b)
            styleTargetChanged(SettingsPage.controls.style_target_bars, a, b)
        end)
    end

    for _, cb in ipairs(checkboxList) do
        if cb ~= nil and cb.SetHandler ~= nil then
            cb:SetHandler("OnClick", function()
                sliderChanged()
            end)
        end
    end

    local function bindHpTextureCheckbox(ctrl, mode)
        if ctrl ~= nil and ctrl.SetHandler ~= nil then
            ctrl:SetHandler("OnClick", function()
                SetHpTextureModeChecks(mode)
                sliderChanged()
                RefreshControls()
            end)
        end
    end
    bindHpTextureCheckbox(SettingsPage.controls.hp_tex_stock, "stock")
    bindHpTextureCheckbox(SettingsPage.controls.hp_tex_pc, "pc")
    bindHpTextureCheckbox(SettingsPage.controls.hp_tex_npc, "npc")

    applyBtn:SetHandler("OnClick", function()
        if SettingsPage.settings == nil then
            return
        end
        syncStyleTargetFromActivePage()
        ApplyControlsToSettings()
        if type(SettingsPage.on_save) == "function" then
            pcall(function()
                SettingsPage.on_save()
            end)
        end
        if type(SettingsPage.on_apply) == "function" then
            pcall(function()
                SettingsPage.on_apply()
            end)
        end
        RefreshControls()
        ShowRestartNotice()
    end)

    closeBtn:SetHandler("OnClick", function()
        closeHandler()
    end)

    if backupBtn ~= nil and backupBtn.SetHandler ~= nil then
        backupBtn:SetHandler("OnClick", function()
            if backupStatus ~= nil and backupStatus.SetText ~= nil then
                backupStatus:SetText("")
            end
            if type(SettingsPage.actions) ~= "table" or type(SettingsPage.actions.backup_settings) ~= "function" then
                if backupStatus ~= nil and backupStatus.SetText ~= nil then
                    backupStatus:SetText("Backup not available")
                end
                return
            end
            local ok, res1, res2 = pcall(function()
                return SettingsPage.actions.backup_settings()
            end)
            local success = ok and (res1 == true)
            local err = ""
            if ok then
                err = tostring(res2 or "")
            else
                err = tostring(res1)
            end
            if backupStatus ~= nil and backupStatus.SetText ~= nil then
                if success then
                    backupStatus:SetText("Backup saved")
                else
                    backupStatus:SetText("Backup failed: " .. err)
                end
            end
        end)
    end

    if importBtn ~= nil and importBtn.SetHandler ~= nil then
        importBtn:SetHandler("OnClick", function()
            if backupStatus ~= nil and backupStatus.SetText ~= nil then
                backupStatus:SetText("")
            end
            if type(SettingsPage.actions) ~= "table" or type(SettingsPage.actions.import_settings) ~= "function" then
                if backupStatus ~= nil and backupStatus.SetText ~= nil then
                    backupStatus:SetText("Import not available")
                end
                return
            end
            local ok, res1, res2 = pcall(function()
                return SettingsPage.actions.import_settings()
            end)
            local success = ok and (res1 == true)
            local err = ""
            if ok then
                err = tostring(res2 or "")
            else
                err = tostring(res1)
            end
            if backupStatus ~= nil and backupStatus.SetText ~= nil then
                if success then
                    backupStatus:SetText("Imported")
                else
                    backupStatus:SetText("Import failed: " .. err)
                end
            end
            RefreshControls()
        end)
    end

    RefreshControls()
    EnsureRestartNotice()
end

function SettingsPage.init(settings, onSave, onApply, actions)
    SettingsPage.settings = settings
    SettingsPage.on_save = onSave
    SettingsPage.on_apply = onApply
    SettingsPage.actions = actions
    EnsureSettingsButton()
    local ok, err = pcall(function()
        EnsureWindow()
    end)
    if not ok and api ~= nil and api.Log ~= nil and api.Log.Err ~= nil then
        api.Log:Err("[Nuzi UI] SettingsPage.EnsureWindow failed: " .. tostring(err))
    end
end

function SettingsPage.open()
    if SettingsPage.settings == nil then
        return
    end
    EnsureSettingsButton()
    local ok, err = pcall(function()
        EnsureWindow()
    end)
    if not ok then
        if api ~= nil and api.Log ~= nil and api.Log.Err ~= nil then
            api.Log:Err("[Nuzi UI] SettingsPage.open failed: " .. tostring(err))
        end
        return
    end
    RefreshControls()
    SettingsPage.window:Show(true)
end

function SettingsPage.toggle()
    if SettingsPage.window == nil then
        SettingsPage.open()
        return
    end
    local want = true
    if SettingsPage.window.IsVisible ~= nil then
        local ok, res = pcall(function()
            return SettingsPage.window:IsVisible()
        end)
        if ok then
            want = not res
        end
    end
    if want then
        SettingsPage.open()
    else
        SettingsPage.window:Show(false)
    end
end

function SettingsPage.Unload()
    if SettingsPage.window ~= nil then
        pcall(function()
            SettingsPage.window:Show(false)
        end)
        pcall(function()
            if api ~= nil and api.Interface ~= nil and api.Interface.Free ~= nil then
                api.Interface:Free(SettingsPage.window)
            end
        end)
        SettingsPage.window = nil
    end
    if SettingsPage.toggle_button ~= nil and SettingsPage.toggle_button.Show ~= nil then
        pcall(function()
            SettingsPage.toggle_button:Show(false)
        end)
    end
    if SettingsPage.toggle_button ~= nil then
        pcall(function()
            if api ~= nil and api.Interface ~= nil and api.Interface.Free ~= nil then
                api.Interface:Free(SettingsPage.toggle_button)
            end
        end)
    end
    SettingsPage.toggle_button = nil
    SettingsPage.toggle_button_icon = nil
    SettingsPage.toggle_button_dragging = false
    SettingsPage.scroll_frame = nil
    SettingsPage.content = nil
    SettingsPage.pages = {}
    SettingsPage.page_heights = {}
    SettingsPage.nav = {}
    SettingsPage.controls = {}
end

return SettingsPage
