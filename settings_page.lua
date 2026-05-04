local api = require("api")
local SafeRequire = require("nuzi-ui/safe_require")
local Compat = SafeRequire("nuzi-ui/compat", "nuzi-ui.compat")
local Layout = SafeRequire("nuzi-ui/layout", "nuzi-ui.layout")
local SettingsCommon = SafeRequire("nuzi-ui/settings_common", "nuzi-ui.settings_common")
local SettingsCooldown = SafeRequire("nuzi-ui/settings_cooldown", "nuzi-ui.settings_cooldown")
local SettingsCooldownPage = SafeRequire("nuzi-ui/settings_cooldown_page", "nuzi-ui.settings_cooldown_page")
local SettingsWidgets = SafeRequire("nuzi-ui/settings_widgets", "nuzi-ui.settings_widgets")
local SettingsCatalog = SafeRequire("nuzi-ui/settings_catalog", "nuzi-ui.settings_catalog")
local SettingsSchema = SafeRequire("nuzi-ui/settings_schema", "nuzi-ui.settings_schema")
local SettingsSchemaCustom = SafeRequire("nuzi-ui/settings_schema_custom", "nuzi-ui.settings_schema_custom")
local CastBar = SafeRequire("nuzi-ui/castbar", "nuzi-ui.castbar")
local GearLoadouts = SafeRequire("nuzi-ui/gear_loadouts", "nuzi-ui.gear_loadouts")
local Runtime = SafeRequire("nuzi-ui/runtime", "nuzi-ui.runtime")
local QuestWatchData = SafeRequire("nuzi-ui/quest_watch_data", "nuzi-ui.quest_watch_data")

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
    _refreshing_controls = false,
    cooldown_unit_key = "player",
    cooldown_track_kind = "any",
    cooldown_buff_page = 1,
    cooldown_scan_results = {},
    cooldown_search_results = {},
    cooldown_search_query = "",
    cooldown_search_cursor = 1,
    cooldown_search_complete = false,
    cooldown_buff_meta_cache = {},
    schema_control_states = {},
    restart_notice_overlay = nil,
    restart_notice_panel = nil,
    restart_notice_title = nil,
    restart_notice_line1 = nil,
    restart_notice_line2 = nil,
    restart_notice_line3 = nil,
    restart_notice_ok = nil
}

local detectedAddonDir = nil

local function GetQuestWatchProfile(cfg)
    if type(cfg) ~= "table" then
        return nil
    end
    if QuestWatchData ~= nil and QuestWatchData.EnsureCharacterProfile ~= nil then
        local characterName = ""
        if Runtime ~= nil and Runtime.GetPlayerName ~= nil then
            characterName = Runtime.GetPlayerName()
        end
        return QuestWatchData.EnsureCharacterProfile(cfg, characterName)
    end
    if type(cfg.tracked) ~= "table" then
        cfg.tracked = {}
    end
    return cfg
end

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

local COOLDOWN_UNIT_KEYS = SettingsCooldown.UNIT_KEYS
local COOLDOWN_DISPLAY_MODE_LABELS = SettingsCooldown.DISPLAY_MODE_LABELS
local COOLDOWN_DISPLAY_STYLE_LABELS = SettingsCooldown.DISPLAY_STYLE_LABELS
local COOLDOWN_BAR_ORDER_LABELS = SettingsCooldown.BAR_ORDER_LABELS
local COOLDOWN_TRACK_KIND_LABELS = SettingsCooldown.TRACK_KIND_LABELS

local CASTBAR_TEXTURE_MODE_KEYS = {
    "auto",
    "casting",
    "charge"
}

local CASTBAR_TEXTURE_MODE_LABELS = {
    "Auto",
    "Casting",
    "Charge"
}

local CASTBAR_FILL_STYLE_KEYS = {
    "texture",
    "solid"
}

local DEBUFF_ANCHOR_KEYS = {
    "top",
    "left",
    "right"
}

local PAGE_DEFS = (type(SettingsCatalog) == "table" and type(SettingsCatalog.PAGES) == "table" and SettingsCatalog.PAGES) or {
    { id = "general", label = "General", title = "General", summary = "Core addon toggles and shared runtime behavior." },
    { id = "repair", label = "UI Repair", title = "UI Repair", summary = "Screen scale diagnostics and safe layout reset tools." },
    { id = "npc", label = "NPC", title = "NPC", summary = "Stock unit-frame art, boss target decorations, target distance, and grade-star placement." },
    { id = "text", label = "Text", title = "Text", summary = "Name, level, role, guild, and number formatting." },
    { id = "bars", label = "Bars", title = "Bars", summary = "Frame sizing, alpha, bar colors, textures, and value placement." },
    { id = "castbar", label = "Cast Bar", title = "Cast Bar", summary = "Movable player cast bar with customizable colors, text, and textures." },
    { id = "travel", label = "Travel", title = "Travel Speed", summary = "Movable speed meter for vehicles, mounts, gliders, and on-foot travel." },
    { id = "mount_glider", label = "Mount/Glider", title = "Mount/Glider", summary = "Specialized timers for mount and glider movement abilities." },
    { id = "loadouts", label = "Loadouts", title = "Gear Loadouts", summary = "Per-character gear loadout bar with a drag/drop equipment editor." },
    { id = "dailies", label = "Dailies", title = "Daily Quests", summary = "Per-character incomplete daily quest checklist backed by the client quest API." },
    { id = "auras", label = "Auras", title = "Auras", summary = "Aura windows, icon layout, and buff or debuff anchor controls." },
    { id = "plates", label = "Nameplates", title = "Nameplates", summary = "Visibility rules, offsets, debuff icons, colors, and runtime nameplate behavior." },
    { id = "cooldown", label = "Cooldowns", title = "Cooldown Tracker", summary = "Tracked buff and debuff icons for player, target, watchtarget, and target of target." }
}

local ClampInt = SettingsCommon.ClampInt
local FormatBuffId = SettingsCommon.FormatBuffId
local PruneStyleFrameOverrides = SettingsCommon.PruneStyleFrameOverrides

local function GetCastBarTextureModeIndex(key)
    return SettingsCommon.GetIndexFromKey(CASTBAR_TEXTURE_MODE_KEYS, tostring(key or "auto"))
end

local function GetCastBarTextureModeFromIndex(idx)
    return SettingsCommon.GetKeyFromIndex(CASTBAR_TEXTURE_MODE_KEYS, idx)
end

local function GetCastBarFillStyleIndex(key)
    return SettingsCommon.GetIndexFromKey(CASTBAR_FILL_STYLE_KEYS, tostring(key or "texture"))
end

local function GetCastBarFillStyleFromIndex(idx)
    return SettingsCommon.GetKeyFromIndex(CASTBAR_FILL_STYLE_KEYS, idx)
end

local function GetDebuffAnchorIndex(anchor)
    return SettingsCommon.GetIndexFromKey(DEBUFF_ANCHOR_KEYS, tostring(anchor or "top"))
end

local function GetDebuffAnchorFromIndex(idx)
    return SettingsCommon.GetKeyFromIndex(DEBUFF_ANCHOR_KEYS, idx)
end

local function GetCooldownDisplayModeFromIndex(idx)
    return SettingsCooldown.GetDisplayModeFromIndex(idx)
end

local function GetCooldownDisplayModeIndex(mode)
    return SettingsCooldown.GetDisplayModeIndex(mode)
end

local function GetCooldownDisplayStyleFromIndex(idx)
    return SettingsCooldown.GetDisplayStyleFromIndex(idx)
end

local function GetCooldownDisplayStyleIndex(style)
    return SettingsCooldown.GetDisplayStyleIndex(style)
end

local function GetCooldownBarOrderFromIndex(idx)
    return SettingsCooldown.GetBarOrderFromIndex(idx)
end

local function GetCooldownBarOrderIndex(order)
    return SettingsCooldown.GetBarOrderIndex(order)
end

local function GetCooldownTrackKindFromIndex(idx)
    return SettingsCooldown.GetTrackKindFromIndex(idx)
end

local function GetCooldownTrackKindIndex(kind)
    return SettingsCooldown.GetTrackKindIndex(kind)
end

local function GetCooldownUnitKeyFromIndex(idx)
    return SettingsCooldown.GetUnitKeyFromIndex(idx)
end

local function GetCooldownUnitIndexFromKey(key)
    return SettingsCooldown.GetUnitIndexFromKey(key)
end

local function EnsureCooldownTrackerTables(s)
    return SettingsCooldown.EnsureTables(s)
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

local function RefreshCooldownBuffRows(unit_cfg)
    SettingsCooldown.RefreshTrackedRows(SettingsPage, unit_cfg)
end

local GetComboBoxIndexRaw = SettingsWidgets.GetComboBoxIndexRaw
local SetComboBoxIndex1Based = SettingsWidgets.SetComboBoxIndex1Based
local GetComboBoxIndex1Based = SettingsWidgets.GetComboBoxIndex1Based

local EnsureStyleFrames = SettingsCommon.EnsureStyleFrames
local SetReadableControlText

local function GetStyleTargetKeyFromIndex(idx)
    return SettingsCommon.GetKeyFromIndex(STYLE_TARGET_KEYS, idx)
end

local function GetStyleTargetIndexFromKey(key)
    return SettingsCommon.GetIndexFromKey(STYLE_TARGET_KEYS, tostring(key or "all"))
end

local function SyncStyleTargetCombos()
    SettingsPage._refreshing_style_target = true
    local targetIdx = GetStyleTargetIndexFromKey(SettingsPage.style_target)
    local controls = {
        SettingsPage.controls.style_target_text,
        SettingsPage.controls.style_target_bars
    }
    for _, ctrl in ipairs(controls) do
        if ctrl ~= nil then
            ctrl.__polar_index_base = nil
            SetComboBoxIndex1Based(ctrl, targetIdx)
        end
    end
    SettingsPage._refreshing_style_target = false
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
        SetReadableControlText(label, summary)
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

local function GetTargetFrameStyleTables(settings)
    if type(settings) ~= "table" then
        return nil, nil
    end

    EnsureStyleFrames(settings)
    if type(settings.style) ~= "table" then
        settings.style = {}
    end

    local base = settings.style
    if type(base.frames) ~= "table" then
        base.frames = {}
    end
    if type(base.frames.target) ~= "table" then
        base.frames.target = {}
    end

    return EffectiveStyle(base, base.frames.target), base.frames.target
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

local function IsSettingsWindowVisible()
    if SettingsPage.window == nil then
        return false
    end
    if SettingsPage.window.IsVisible ~= nil then
        local ok, visible = pcall(function()
            return SettingsPage.window:IsVisible()
        end)
        if ok then
            return visible and true or false
        end
    end
    return false
end

local function UpdateCastBarPreview()
    if CastBar == nil or CastBar.SetPreviewVisible == nil then
        return
    end
    local visible = IsSettingsWindowVisible() and SettingsPage.active_page == "castbar"
    pcall(function()
        CastBar.SetPreviewVisible(visible, SettingsPage.settings)
    end)
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

    SyncStyleTargetCombos()
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

    UpdateCastBarPreview()
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
            UpdateCastBarPreview()
        end
    end
end

local function AttachWindowShiftDrag(widget, target)
    if widget == nil or target == nil or widget.SetHandler == nil then
        return
    end
    pcall(function()
        if widget.RegisterForDrag ~= nil then
            widget:RegisterForDrag("LeftButton")
        end
        if widget.EnableDrag ~= nil then
            widget:EnableDrag(true)
        end
    end)
    widget:SetHandler("OnDragStart", function()
        if type(SettingsPage.settings) == "table" and SettingsPage.settings.drag_requires_shift == true and not IsShiftDown() then
            return
        end
        if target.StartMoving ~= nil then
            target:StartMoving()
        end
        if api ~= nil and api.Cursor ~= nil and api.Cursor.ClearCursor ~= nil then
            pcall(function()
                api.Cursor:ClearCursor()
            end)
        end
        if api ~= nil and api.Cursor ~= nil and api.Cursor.SetCursorImage ~= nil and CURSOR_PATH ~= nil and CURSOR_PATH.MOVE ~= nil then
            pcall(function()
                api.Cursor:SetCursorImage(CURSOR_PATH.MOVE, 0, 0)
            end)
        end
    end)
    widget:SetHandler("OnDragStop", function()
        if target.StopMovingOrSizing ~= nil then
            target:StopMovingOrSizing()
        end
        if api ~= nil and api.Cursor ~= nil and api.Cursor.ClearCursor ~= nil then
            pcall(function()
                api.Cursor:ClearCursor()
            end)
        end
    end)
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
        overlay:SetExtent(920, 760)
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
        if btn ~= nil and btn.SetAlpha ~= nil then
            pcall(function()
                btn:SetAlpha(page.id == pageId and 1 or 0.82)
            end)
        end
    end

    local meta = GetPageMeta(pageId) or {}
    if SettingsPage.controls.page_header_title ~= nil and SettingsPage.controls.page_header_title.SetText ~= nil then
        SettingsPage.controls.page_header_title:SetText(tostring(meta.title or ""))
    end
    SetReadableControlText(SettingsPage.controls.page_header_summary, meta.summary or "")
end

local function GetCooldownSecondsEditText()
    local text = GetEditText(SettingsPage.controls.ct_new_cooldown_s)
    text = tostring(text or "")
    text = text:gsub("%s+", "")
    return text
end

local function AddCooldownTrackedBuffToSelectedUnit(rawId, rawKind, rawCooldownSeconds)
    return SettingsCooldown.AddTrackedBuff(SettingsPage, rawId, rawKind, rawCooldownSeconds)
end

local function RefreshCooldownSearchRows()
    SettingsCooldown.RefreshSearchRows(SettingsPage)
end

local function RunCooldownBuffSearch(loadMore)
    SettingsCooldown.RunBuffSearch(SettingsPage, GetEditText(SettingsPage.controls.ct_search_text), loadMore)
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
        if Layout ~= nil and type(Layout.AnchorTopLeftScreen) == "function" then
            Layout.AnchorTopLeftScreen(widget, x, y)
        else
            if widget.RemoveAllAnchors ~= nil then
                widget:RemoveAllAnchors()
            end
            if widget.AddAnchor ~= nil then
                widget:AddAnchor("TOPLEFT", "UIParent", x, y)
            end
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

    local x, y = nil, nil
    if Layout ~= nil and type(Layout.ReadScreenOffset) == "function" then
        x, y = Layout.ReadScreenOffset(widget)
    else
        local ok = false
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
            if type(SettingsPage.settings) == "table" and SettingsPage.settings.drag_requires_shift == true and not IsShiftDown() then
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
local CreateCheckbox = SettingsWidgets.CreateCheckbox
local CreateButton = SettingsWidgets.CreateButton
local CreateEdit = SettingsWidgets.CreateEdit
local GetSliderValue = SettingsWidgets.GetSliderValue
local SetSliderValue = SettingsWidgets.SetSliderValue
local CreateSlider = SettingsWidgets.CreateSlider
local CreateComboBox = SettingsWidgets.CreateComboBox
local CreateSectionCard = SettingsWidgets.CreateSectionCard
local SetControlEnabled = SettingsWidgets.SetControlEnabled
local EstimateTextHeight = SettingsWidgets.EstimateTextHeight
local SetWrappedText = SettingsWidgets.SetWrappedText

local RefreshControls
local ApplyControlsToSettings

local SCHEMA_PAGE_IDS = { "general", "repair", "npc", "text", "bars", "castbar", "travel", "mount_glider", "loadouts", "dailies", "auras", "plates" }
local SCHEMA_PAGE_LEFT = 18
local SCHEMA_PAGE_TOP = 18
local SCHEMA_CARD_WIDTH = 650
local SCHEMA_SECTION_GAP = 16

SetReadableControlText = function(control, text)
    if control == nil then
        return
    end

    local content = tostring(text or "")
    if type(SetWrappedText) == "function" and control.__polar_wrap_width ~= nil then
        local ok = pcall(function()
            SetWrappedText(control, content)
        end)
        if ok then
            return
        end
    end

    if control.SetText ~= nil then
        pcall(function()
            control:SetText(content)
        end)
    end
end

local function EstimateSchemaFieldAdvance(field)
    if type(field) ~= "table" then
        return 0
    end
    if tonumber(field.advance) ~= nil then
        return math.max(0, tonumber(field.advance))
    end
    local kind = tostring(field.kind or "")
    if kind == "combo" then
        return 34
    elseif kind == "hint" then
        local width = tonumber(field.width) or 520
        local height = tonumber(field.height) or
            (type(EstimateTextHeight) == "function" and EstimateTextHeight(field.text, width, 12, 16, 1)) or 16
        return math.max(height + 8, 26)
    elseif kind == "label" then
        local width = tonumber(field.width) or 520
        local fontSize = tonumber(field.font_size) or 13
        local height = tonumber(field.height) or
            (type(EstimateTextHeight) == "function" and EstimateTextHeight(field.text, width, fontSize, fontSize + 4, 1)) or 18
        return math.max(height + 6, 22)
    elseif kind == "slider" then
        return 24
    elseif kind == "custom" then
        return math.max(0, tonumber(field.estimate_height) or 0)
    elseif kind == "spacer" then
        return math.max(0, tonumber(field.size) or 12)
    end
    return 24
end

local function EvaluateSchemaDependency(dep)
    if type(dep) ~= "table" then
        return true
    end
    local control = dep.control ~= nil and SettingsPage.controls[tostring(dep.control)] or nil
    local checked = nil
    if control ~= nil and control.GetChecked ~= nil then
        local ok, value = pcall(function()
            return control:GetChecked()
        end)
        if ok then
            checked = value and true or false
        end
    end
    if dep.checked ~= nil then
        return checked == (dep.checked and true or false)
    end
    return checked == true
end

local function RegisterSchemaDependency(dep, widgets)
    if type(dep) ~= "table" or type(widgets) ~= "table" then
        return
    end
    local list = {}
    for _, widget in ipairs(widgets) do
        if widget ~= nil then
            list[#list + 1] = widget
        end
    end
    if #list == 0 then
        return
    end
    SettingsPage.schema_control_states[#SettingsPage.schema_control_states + 1] = {
        dep = dep,
        widgets = list
    }
end

local function RefreshSchemaControlStates()
    if type(SettingsPage.schema_control_states) ~= "table" then
        return
    end
    for _, entry in ipairs(SettingsPage.schema_control_states) do
        local enabled = EvaluateSchemaDependency(entry.dep)
        if type(entry.widgets) == "table" then
            for _, widget in ipairs(entry.widgets) do
                if widget ~= nil and SetControlEnabled ~= nil then
                    SetControlEnabled(widget, enabled)
                end
            end
        end
    end
end

local function MakeCustomSchemaContext()
    return {
        state = SettingsPage,
        gear_loadouts = GearLoadouts,
        set_text = SetReadableControlText,
        apply_controls = function()
            if type(ApplyControlsToSettings) == "function" then
                ApplyControlsToSettings()
            end
        end,
        refresh_controls = function()
            if type(RefreshControls) == "function" then
                RefreshControls()
            end
        end
    }
end

local function RefreshRepairDiagnostics()
    local fn = SettingsSchemaCustom ~= nil and SettingsSchemaCustom.RefreshRepairDiagnostics or nil
    if type(fn) == "function" then
        fn(MakeCustomSchemaContext())
    end
end

local function CallCustomSchemaRenderer(name, parent, y)
    local fn = SettingsSchemaCustom ~= nil and SettingsSchemaCustom[name] or nil
    if type(fn) == "function" then
        return fn(MakeCustomSchemaContext(), parent, y)
    end
    return y
end
local CUSTOM_SCHEMA_RENDERERS = {
    plates_guild_colors = function(parent, y) return CallCustomSchemaRenderer("BuildPlatesGuildColorEditor", parent, y) end,
    ui_repair_diagnostics = function(parent, y) return CallCustomSchemaRenderer("BuildRepairDiagnostics", parent, y) end,
    ui_repair_actions = function(parent, y) return CallCustomSchemaRenderer("BuildRepairActions", parent, y) end,
    gear_loadouts_editor_button = function(parent, y) return CallCustomSchemaRenderer("BuildGearLoadoutActions", parent, y) end,
    mount_glider_devices = function(parent, y) return CallCustomSchemaRenderer("BuildMountGliderSelector", parent, y) end,
    quest_watch_selector = function(parent, y) return CallCustomSchemaRenderer("BuildQuestWatchSelector", parent, y) end
}

local function BuildSchemaField(parent, y, field)
    if type(field) ~= "table" then
        return y
    end

    local kind = tostring(field.kind or "")
    local widgets = {}

    if kind == "checkbox" then
        local checkbox = CreateCheckbox(tostring(field.widget_id), parent, tostring(field.label or ""), 0, y)
        SettingsPage.controls[tostring(field.control)] = checkbox
        widgets[1] = checkbox
    elseif kind == "slider" then
        local slider, valueLabel = CreateSlider(
            tostring(field.widget_id),
            parent,
            tostring(field.label or ""),
            0,
            y,
            tonumber(field.min) or 0,
            tonumber(field.max) or 100,
            tonumber(field.step) or 1
        )
        SettingsPage.controls[tostring(field.control)] = slider
        SettingsPage.controls[tostring(field.value_control or (tostring(field.control) .. "_val"))] = valueLabel
        widgets[1] = slider
    elseif kind == "combo" then
        local comboLabel = CreateLabel(tostring(field.widget_id) .. "Label", parent, tostring(field.label or ""), 0, y, tonumber(field.font_size) or 15)
        local combo = CreateComboBox(parent, field.items or {}, 175, y - 4, tonumber(field.width) or 220, tonumber(field.height) or 24)
        SettingsPage.controls[tostring(field.control)] = combo
        widgets[1] = combo
        widgets[2] = comboLabel
    elseif kind == "hint" then
        local hintLabel = CreateHintLabel(
            tostring(field.widget_id),
            parent,
            tostring(field.text or ""),
            0,
            y,
            tonumber(field.width) or 520
        )
        if hintLabel ~= nil and hintLabel.SetExtent ~= nil then
            local hintHeight = tonumber(field.height) or tonumber(hintLabel.__polar_estimated_height) or 18
            pcall(function()
                hintLabel:SetExtent(tonumber(field.width) or 520, hintHeight)
            end)
        end
        if field.control ~= nil then
            SettingsPage.controls[tostring(field.control)] = hintLabel
        end
        widgets[1] = hintLabel
    elseif kind == "label" then
        local labelWidget = CreateLabel(
            tostring(field.widget_id),
            parent,
            tostring(field.text or ""),
            0,
            y,
            tonumber(field.font_size) or 13,
            tonumber(field.width) or 520
        )
        if labelWidget ~= nil and labelWidget.SetExtent ~= nil then
            local labelHeight = tonumber(field.height) or tonumber(labelWidget.__polar_estimated_height) or 18
            pcall(function()
                labelWidget:SetExtent(tonumber(field.width) or 520, labelHeight)
            end)
        end
        if field.control ~= nil then
            SettingsPage.controls[tostring(field.control)] = labelWidget
        end
        widgets[1] = labelWidget
    elseif kind == "custom" then
        local renderer = CUSTOM_SCHEMA_RENDERERS[tostring(field.renderer or "")]
        if type(renderer) == "function" then
            y = renderer(parent, y, field)
        end
        return y
    end

    RegisterSchemaDependency(field.depends_on, widgets)
    return y + EstimateSchemaFieldAdvance(field)
end

local function BuildSchemaSection(page, pageId, y, section)
    local fields = type(section.fields) == "table" and section.fields or {}
    local estimatedBody = 0
    for _, field in ipairs(fields) do
        estimatedBody = estimatedBody + EstimateSchemaFieldAdvance(field)
    end
    estimatedBody = math.max(estimatedBody + 6, tonumber(section.min_body_height) or 24)

    local card, body, headerHeight = CreateSectionCard(
        "polarUiSchema_" .. tostring(pageId) .. "_" .. tostring(section.id or "section"),
        page,
        tostring(section.title or ""),
        section.hint,
        SCHEMA_PAGE_LEFT,
        y,
        SCHEMA_CARD_WIDTH,
        estimatedBody + 88
    )
    if card == nil or body == nil then
        return y
    end

    local bodyY = 0
    for _, field in ipairs(fields) do
        bodyY = BuildSchemaField(body, bodyY, field)
    end

    local bodyHeight = math.max(bodyY + 6, tonumber(section.min_body_height) or 24)
    local cardHeight = math.max(estimatedBody + 88, (tonumber(headerHeight) or 42) + bodyHeight + 16)

    pcall(function()
        body:SetExtent(SCHEMA_CARD_WIDTH - 32, bodyHeight)
    end)
    pcall(function()
        card:SetExtent(SCHEMA_CARD_WIDTH, cardHeight)
    end)

    return y + cardHeight + SCHEMA_SECTION_GAP
end

local function BuildSchemaPage(pageId)
    local page = SettingsPage.pages[pageId]
    local schemaPage = type(SettingsSchema) == "table" and type(SettingsSchema.PAGES) == "table" and SettingsSchema.PAGES[pageId] or nil
    if page == nil or type(schemaPage) ~= "table" then
        return
    end

    local y = SCHEMA_PAGE_TOP
    for _, section in ipairs(schemaPage.sections or {}) do
        y = BuildSchemaSection(page, pageId, y, section)
    end

    SettingsPage.page_heights[pageId] = y + 18
end

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

RefreshControls = function()
    local s = SettingsPage.settings
    if s == nil then
        return
    end
    SettingsPage._refreshing_controls = true
    SyncStyleTargetCombos()
    if SettingsPage.controls.enabled ~= nil then
        SettingsPage.controls.enabled:SetChecked(s.enabled and true or false)
    end
    if SettingsPage.controls.drag_requires_shift ~= nil then
        SettingsPage.controls.drag_requires_shift:SetChecked(s.drag_requires_shift == true)
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

    if SettingsPage.controls.hide_ancestral_icon_level ~= nil then
        SettingsPage.controls.hide_ancestral_icon_level:SetChecked(s.hide_ancestral_icon_level and true or false)
    end

    if SettingsPage.controls.show_class_icons ~= nil then
        SettingsPage.controls.show_class_icons:SetChecked(s.show_class_icons ~= false)
    end

    if SettingsPage.controls.hide_boss_frame_background ~= nil then
        SettingsPage.controls.hide_boss_frame_background:SetChecked(s.hide_boss_frame_background and true or false)
    end

    if SettingsPage.controls.hide_target_grade_star ~= nil then
        SettingsPage.controls.hide_target_grade_star:SetChecked(s.hide_target_grade_star and true or false)
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

    local castBar = type(s.cast_bar) == "table" and s.cast_bar or {}
    local castBarFill = type(castBar.fill_color) == "table" and castBar.fill_color or { 245, 199, 107, 255 }
    local castBarBg = type(castBar.bg_color) == "table" and castBar.bg_color or { 13, 10, 8, 230 }
    local castBarAccent = type(castBar.accent_color) == "table" and castBar.accent_color or { 240, 204, 122, 36 }
    local castBarText = type(castBar.text_color) == "table" and castBar.text_color or { 255, 255, 255, 255 }
    if SettingsPage.controls.castbar_enabled ~= nil then
        SettingsPage.controls.castbar_enabled:SetChecked(castBar.enabled and true or false)
    end
    if SettingsPage.controls.castbar_lock_position ~= nil then
        SettingsPage.controls.castbar_lock_position:SetChecked(castBar.lock_position and true or false)
    end
    if SettingsPage.controls.castbar_width ~= nil then
        refreshSlider(
            SettingsPage.controls.castbar_width,
            SettingsPage.controls.castbar_width_val,
            tonumber(castBar.width) or 500
        )
    end
    if SettingsPage.controls.castbar_scale ~= nil then
        local scalePct = math.floor(((tonumber(castBar.scale) or 1.1) * 100) + 0.5)
        if scalePct < 80 then
            scalePct = 80
        elseif scalePct > 200 then
            scalePct = 200
        end
        refreshSlider(SettingsPage.controls.castbar_scale, SettingsPage.controls.castbar_scale_val, scalePct)
    end
    if SettingsPage.controls.castbar_texture_mode ~= nil then
        SettingsPage._refreshing_castbar_texture = true
        SetComboBoxIndex1Based(
            SettingsPage.controls.castbar_texture_mode,
            GetCastBarTextureModeIndex(castBar.bar_texture_mode)
        )
        SettingsPage._refreshing_castbar_texture = false
    end
    if SettingsPage.controls.castbar_fill_style ~= nil then
        SettingsPage._refreshing_castbar_fill_style = true
        SetComboBoxIndex1Based(
            SettingsPage.controls.castbar_fill_style,
            GetCastBarFillStyleIndex(castBar.fill_style)
        )
        SettingsPage._refreshing_castbar_fill_style = false
    end
    if SettingsPage.controls.castbar_border_thickness ~= nil then
        refreshSlider(
            SettingsPage.controls.castbar_border_thickness,
            SettingsPage.controls.castbar_border_thickness_val,
            tonumber(castBar.border_thickness) or 4
        )
    end
    if SettingsPage.controls.castbar_text_font_size ~= nil then
        refreshSlider(
            SettingsPage.controls.castbar_text_font_size,
            SettingsPage.controls.castbar_text_font_size_val,
            tonumber(castBar.text_font_size) or 15
        )
    end
    if SettingsPage.controls.castbar_text_offset_x ~= nil then
        refreshSlider(
            SettingsPage.controls.castbar_text_offset_x,
            SettingsPage.controls.castbar_text_offset_x_val,
            tonumber(castBar.text_offset_x) or 0
        )
    end
    if SettingsPage.controls.castbar_text_offset_y ~= nil then
        refreshSlider(
            SettingsPage.controls.castbar_text_offset_y,
            SettingsPage.controls.castbar_text_offset_y_val,
            tonumber(castBar.text_offset_y) or 6
        )
    end
    if SettingsPage.controls.castbar_fill_r ~= nil then
        refreshSlider(SettingsPage.controls.castbar_fill_r, SettingsPage.controls.castbar_fill_r_val, tonumber(castBarFill[1]) or 245)
    end
    if SettingsPage.controls.castbar_fill_g ~= nil then
        refreshSlider(SettingsPage.controls.castbar_fill_g, SettingsPage.controls.castbar_fill_g_val, tonumber(castBarFill[2]) or 199)
    end
    if SettingsPage.controls.castbar_fill_b ~= nil then
        refreshSlider(SettingsPage.controls.castbar_fill_b, SettingsPage.controls.castbar_fill_b_val, tonumber(castBarFill[3]) or 107)
    end
    if SettingsPage.controls.castbar_fill_a ~= nil then
        refreshSlider(SettingsPage.controls.castbar_fill_a, SettingsPage.controls.castbar_fill_a_val, tonumber(castBarFill[4]) or 255)
    end
    if SettingsPage.controls.castbar_bg_r ~= nil then
        refreshSlider(SettingsPage.controls.castbar_bg_r, SettingsPage.controls.castbar_bg_r_val, tonumber(castBarBg[1]) or 13)
    end
    if SettingsPage.controls.castbar_bg_g ~= nil then
        refreshSlider(SettingsPage.controls.castbar_bg_g, SettingsPage.controls.castbar_bg_g_val, tonumber(castBarBg[2]) or 10)
    end
    if SettingsPage.controls.castbar_bg_b ~= nil then
        refreshSlider(SettingsPage.controls.castbar_bg_b, SettingsPage.controls.castbar_bg_b_val, tonumber(castBarBg[3]) or 8)
    end
    if SettingsPage.controls.castbar_bg_a ~= nil then
        refreshSlider(SettingsPage.controls.castbar_bg_a, SettingsPage.controls.castbar_bg_a_val, tonumber(castBarBg[4]) or 230)
    end
    if SettingsPage.controls.castbar_accent_r ~= nil then
        refreshSlider(SettingsPage.controls.castbar_accent_r, SettingsPage.controls.castbar_accent_r_val, tonumber(castBarAccent[1]) or 240)
    end
    if SettingsPage.controls.castbar_accent_g ~= nil then
        refreshSlider(SettingsPage.controls.castbar_accent_g, SettingsPage.controls.castbar_accent_g_val, tonumber(castBarAccent[2]) or 204)
    end
    if SettingsPage.controls.castbar_accent_b ~= nil then
        refreshSlider(SettingsPage.controls.castbar_accent_b, SettingsPage.controls.castbar_accent_b_val, tonumber(castBarAccent[3]) or 122)
    end
    if SettingsPage.controls.castbar_accent_a ~= nil then
        refreshSlider(SettingsPage.controls.castbar_accent_a, SettingsPage.controls.castbar_accent_a_val, tonumber(castBarAccent[4]) or 36)
    end
    if SettingsPage.controls.castbar_text_r ~= nil then
        refreshSlider(SettingsPage.controls.castbar_text_r, SettingsPage.controls.castbar_text_r_val, tonumber(castBarText[1]) or 255)
    end
    if SettingsPage.controls.castbar_text_g ~= nil then
        refreshSlider(SettingsPage.controls.castbar_text_g, SettingsPage.controls.castbar_text_g_val, tonumber(castBarText[2]) or 255)
    end
    if SettingsPage.controls.castbar_text_b ~= nil then
        refreshSlider(SettingsPage.controls.castbar_text_b, SettingsPage.controls.castbar_text_b_val, tonumber(castBarText[3]) or 255)
    end
    if SettingsPage.controls.castbar_text_a ~= nil then
        refreshSlider(SettingsPage.controls.castbar_text_a, SettingsPage.controls.castbar_text_a_val, tonumber(castBarText[4]) or 255)
    end

    local travelSpeed = type(s.travel_speed) == "table" and s.travel_speed or {}
    if SettingsPage.controls.travel_speed_enabled ~= nil then
        SettingsPage.controls.travel_speed_enabled:SetChecked(travelSpeed.enabled and true or false)
    end
    if SettingsPage.controls.travel_speed_lock_position ~= nil then
        SettingsPage.controls.travel_speed_lock_position:SetChecked(travelSpeed.lock_position and true or false)
    end
    if SettingsPage.controls.travel_speed_only_vehicle_or_mount ~= nil then
        SettingsPage.controls.travel_speed_only_vehicle_or_mount:SetChecked(travelSpeed.only_vehicle_or_mount and true or false)
    end
    if SettingsPage.controls.travel_speed_show_on_mount ~= nil then
        SettingsPage.controls.travel_speed_show_on_mount:SetChecked(travelSpeed.show_on_mount ~= false)
    end
    if SettingsPage.controls.travel_speed_show_on_vehicle ~= nil then
        SettingsPage.controls.travel_speed_show_on_vehicle:SetChecked(travelSpeed.show_on_vehicle ~= false)
    end
    if SettingsPage.controls.travel_speed_show_speed_text ~= nil then
        SettingsPage.controls.travel_speed_show_speed_text:SetChecked(travelSpeed.show_speed_text ~= false)
    end
    if SettingsPage.controls.travel_speed_show_bar ~= nil then
        SettingsPage.controls.travel_speed_show_bar:SetChecked(travelSpeed.show_bar ~= false)
    end
    if SettingsPage.controls.travel_speed_show_state_text ~= nil then
        SettingsPage.controls.travel_speed_show_state_text:SetChecked(travelSpeed.show_state_text ~= false)
    end
    if SettingsPage.controls.travel_speed_width ~= nil then
        refreshSlider(
            SettingsPage.controls.travel_speed_width,
            SettingsPage.controls.travel_speed_width_val,
            tonumber(travelSpeed.width) or 220
        )
    end
    if SettingsPage.controls.travel_speed_scale ~= nil then
        local speedScalePct = math.floor(((tonumber(travelSpeed.scale) or 1) * 100) + 0.5)
        if speedScalePct < 75 then
            speedScalePct = 75
        elseif speedScalePct > 160 then
            speedScalePct = 160
        end
        refreshSlider(SettingsPage.controls.travel_speed_scale, SettingsPage.controls.travel_speed_scale_val, speedScalePct)
    end
    if SettingsPage.controls.travel_speed_font_size ~= nil then
        refreshSlider(
            SettingsPage.controls.travel_speed_font_size,
            SettingsPage.controls.travel_speed_font_size_val,
            tonumber(travelSpeed.font_size) or 20
        )
    end

    local mountGlider = type(s.mount_glider) == "table" and s.mount_glider or {}
    if SettingsPage.controls.mount_glider_enabled ~= nil then
        SettingsPage.controls.mount_glider_enabled:SetChecked(mountGlider.enabled and true or false)
    end
    if SettingsPage.controls.mount_glider_lock_position ~= nil then
        SettingsPage.controls.mount_glider_lock_position:SetChecked(mountGlider.lock_position and true or false)
    end
    if SettingsPage.controls.mount_glider_show_ready_icons ~= nil then
        SettingsPage.controls.mount_glider_show_ready_icons:SetChecked(mountGlider.show_ready_icons ~= false)
    end
    if SettingsPage.controls.mount_glider_show_timer ~= nil then
        SettingsPage.controls.mount_glider_show_timer:SetChecked(mountGlider.show_timer ~= false)
    end
    if SettingsPage.controls.mount_glider_use_mana_triggers ~= nil then
        SettingsPage.controls.mount_glider_use_mana_triggers:SetChecked(mountGlider.use_mana_triggers ~= false)
    end
    if SettingsPage.controls.mount_glider_notify_ready ~= nil then
        SettingsPage.controls.mount_glider_notify_ready:SetChecked(mountGlider.notify_ready ~= false)
    end
    if SettingsPage.controls.mount_glider_icon_size ~= nil then
        refreshSlider(
            SettingsPage.controls.mount_glider_icon_size,
            SettingsPage.controls.mount_glider_icon_size_val,
            tonumber(mountGlider.icon_size) or 36
        )
    end
    if SettingsPage.controls.mount_glider_icon_spacing ~= nil then
        refreshSlider(
            SettingsPage.controls.mount_glider_icon_spacing,
            SettingsPage.controls.mount_glider_icon_spacing_val,
            tonumber(mountGlider.icon_spacing) or 6
        )
    end
    if SettingsPage.controls.mount_glider_icons_per_row ~= nil then
        refreshSlider(
            SettingsPage.controls.mount_glider_icons_per_row,
            SettingsPage.controls.mount_glider_icons_per_row_val,
            tonumber(mountGlider.icons_per_row) or 9
        )
    end
    if SettingsPage.controls.mount_glider_timer_font_size ~= nil then
        refreshSlider(
            SettingsPage.controls.mount_glider_timer_font_size,
            SettingsPage.controls.mount_glider_timer_font_size_val,
            tonumber(mountGlider.timer_font_size) or 14
        )
    end

    local gearLoadouts = type(s.gear_loadouts) == "table" and s.gear_loadouts or {}
    if SettingsPage.controls.gear_loadouts_enabled ~= nil then
        SettingsPage.controls.gear_loadouts_enabled:SetChecked(gearLoadouts.enabled and true or false)
    end
    if SettingsPage.controls.gear_loadouts_lock_bar ~= nil then
        SettingsPage.controls.gear_loadouts_lock_bar:SetChecked(gearLoadouts.lock_bar and true or false)
    end
    if SettingsPage.controls.gear_loadouts_lock_editor ~= nil then
        SettingsPage.controls.gear_loadouts_lock_editor:SetChecked(gearLoadouts.lock_editor and true or false)
    end
    if SettingsPage.controls.gear_loadouts_show_icons ~= nil then
        SettingsPage.controls.gear_loadouts_show_icons:SetChecked(gearLoadouts.show_icons and true or false)
    end
    if SettingsPage.controls.gear_loadouts_button_size ~= nil then
        refreshSlider(
            SettingsPage.controls.gear_loadouts_button_size,
            SettingsPage.controls.gear_loadouts_button_size_val,
            tonumber(gearLoadouts.button_size) or 38
        )
    end
    if SettingsPage.controls.gear_loadouts_button_width ~= nil then
        refreshSlider(
            SettingsPage.controls.gear_loadouts_button_width,
            SettingsPage.controls.gear_loadouts_button_width_val,
            tonumber(gearLoadouts.button_width) or 126
        )
    end

    local questWatch = type(s.quest_watch) == "table" and s.quest_watch or {}
    if SettingsPage.controls.quest_watch_enabled ~= nil then
        SettingsPage.controls.quest_watch_enabled:SetChecked(questWatch.enabled and true or false)
    end
    if SettingsPage.controls.quest_watch_lock_position ~= nil then
        SettingsPage.controls.quest_watch_lock_position:SetChecked(questWatch.lock_position and true or false)
    end
    if SettingsPage.controls.quest_watch_hide_when_done ~= nil then
        SettingsPage.controls.quest_watch_hide_when_done:SetChecked(questWatch.hide_when_done ~= false)
    end
    if SettingsPage.controls.quest_watch_show_ids ~= nil then
        SettingsPage.controls.quest_watch_show_ids:SetChecked(questWatch.show_ids and true or false)
    end
    if SettingsPage.controls.quest_watch_width ~= nil then
        refreshSlider(
            SettingsPage.controls.quest_watch_width,
            SettingsPage.controls.quest_watch_width_val,
            tonumber(questWatch.width) or 330
        )
    end
    if SettingsPage.controls.quest_watch_scale ~= nil then
        local questScalePct = math.floor(((tonumber(questWatch.scale) or 1) * 100) + 0.5)
        if questScalePct < 75 then
            questScalePct = 75
        elseif questScalePct > 160 then
            questScalePct = 160
        end
        refreshSlider(SettingsPage.controls.quest_watch_scale, SettingsPage.controls.quest_watch_scale_val, questScalePct)
    end
    if SettingsPage.controls.quest_watch_max_visible ~= nil then
        refreshSlider(
            SettingsPage.controls.quest_watch_max_visible,
            SettingsPage.controls.quest_watch_max_visible_val,
            tonumber(questWatch.max_visible) or 12
        )
    end
    if SettingsPage.controls.quest_watch_update_interval ~= nil then
        refreshSlider(
            SettingsPage.controls.quest_watch_update_interval,
            SettingsPage.controls.quest_watch_update_interval_val,
            math.floor(((tonumber(questWatch.update_interval_ms) or 10000) / 1000) + 0.5)
        )
    end
    if type(SettingsPage.controls.quest_watch_rows) == "table" then
        local questWatchProfile = GetQuestWatchProfile(questWatch)
        local tracked = type(questWatchProfile) == "table" and type(questWatchProfile.tracked) == "table" and questWatchProfile.tracked or {}
        for _, row in ipairs(SettingsPage.controls.quest_watch_rows) do
            if type(row) == "table" and row.checkbox ~= nil and row.checkbox.SetChecked ~= nil then
                row.checkbox:SetChecked(tracked[tostring(row.key or "")] ~= false)
            end
        end
    end

    local npcStyle = nil
    npcStyle, _ = GetTargetFrameStyleTables(s)
    if SettingsPage.controls.target_grade_star_offset_x ~= nil then
        refreshSlider(
            SettingsPage.controls.target_grade_star_offset_x,
            SettingsPage.controls.target_grade_star_offset_x_val,
            tonumber(type(npcStyle) == "table" and npcStyle.target_grade_star_offset_x or nil) or 0
        )
    end
    if SettingsPage.controls.target_grade_star_offset_y ~= nil then
        refreshSlider(
            SettingsPage.controls.target_grade_star_offset_y,
            SettingsPage.controls.target_grade_star_offset_y_val,
            tonumber(type(npcStyle) == "table" and npcStyle.target_grade_star_offset_y or nil) or 0
        )
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
        local runtimeText = Compat ~= nil and Compat.GetStatusText() or "Runtime OK"
        SetReadableControlText(SettingsPage.controls.plates_runtime_status, runtimeText)
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

        local debuffs = type(s.nameplates.debuffs) == "table" and s.nameplates.debuffs or {}
        if SettingsPage.controls.plates_debuffs_enabled ~= nil then
            SettingsPage.controls.plates_debuffs_enabled:SetChecked(debuffs.enabled and true or false)
        end
        if SettingsPage.controls.plates_debuffs_track_raid ~= nil then
            SettingsPage.controls.plates_debuffs_track_raid:SetChecked(tostring(debuffs.tracking_scope or "focus") == "raid")
        end
        if SettingsPage.controls.plates_debuffs_show_timer ~= nil then
            SettingsPage.controls.plates_debuffs_show_timer:SetChecked(debuffs.show_timer ~= false)
        end
        if SettingsPage.controls.plates_debuffs_show_secondary ~= nil then
            SettingsPage.controls.plates_debuffs_show_secondary:SetChecked(debuffs.show_secondary ~= false)
        end
        if SettingsPage.controls.plates_debuffs_anchor ~= nil then
            SettingsPage._refreshing_debuff_anchor = true
            SetComboBoxIndex1Based(SettingsPage.controls.plates_debuffs_anchor, GetDebuffAnchorIndex(debuffs.anchor))
            SettingsPage._refreshing_debuff_anchor = false
        end
        if SettingsPage.controls.plates_debuffs_max_icons ~= nil then
            refreshSlider(SettingsPage.controls.plates_debuffs_max_icons, SettingsPage.controls.plates_debuffs_max_icons_val, tonumber(debuffs.max_icons) or 4)
        end
        if SettingsPage.controls.plates_debuffs_icon_size ~= nil then
            refreshSlider(SettingsPage.controls.plates_debuffs_icon_size, SettingsPage.controls.plates_debuffs_icon_size_val, tonumber(debuffs.icon_size) or 30)
        end
        if SettingsPage.controls.plates_debuffs_secondary_size ~= nil then
            refreshSlider(SettingsPage.controls.plates_debuffs_secondary_size, SettingsPage.controls.plates_debuffs_secondary_size_val, tonumber(debuffs.secondary_icon_size) or 18)
        end
        if SettingsPage.controls.plates_debuffs_timer_size ~= nil then
            refreshSlider(SettingsPage.controls.plates_debuffs_timer_size, SettingsPage.controls.plates_debuffs_timer_size_val, tonumber(debuffs.timer_font_size) or 11)
        end
        if SettingsPage.controls.plates_debuffs_gap ~= nil then
            refreshSlider(SettingsPage.controls.plates_debuffs_gap, SettingsPage.controls.plates_debuffs_gap_val, tonumber(debuffs.gap) or 4)
        end
        if SettingsPage.controls.plates_debuffs_offset_x ~= nil then
            refreshSlider(SettingsPage.controls.plates_debuffs_offset_x, SettingsPage.controls.plates_debuffs_offset_x_val, tonumber(debuffs.offset_x) or 0)
        end
        if SettingsPage.controls.plates_debuffs_offset_y ~= nil then
            refreshSlider(SettingsPage.controls.plates_debuffs_offset_y, SettingsPage.controls.plates_debuffs_offset_y_val, tonumber(debuffs.offset_y) or -8)
        end
        if SettingsPage.controls.plates_debuffs_show_hard ~= nil then
            SettingsPage.controls.plates_debuffs_show_hard:SetChecked(debuffs.show_hard ~= false)
        end
        if SettingsPage.controls.plates_debuffs_show_silence ~= nil then
            SettingsPage.controls.plates_debuffs_show_silence:SetChecked(debuffs.show_silence ~= false)
        end
        if SettingsPage.controls.plates_debuffs_show_root ~= nil then
            SettingsPage.controls.plates_debuffs_show_root:SetChecked(debuffs.show_root ~= false)
        end
        if SettingsPage.controls.plates_debuffs_show_slow ~= nil then
            SettingsPage.controls.plates_debuffs_show_slow:SetChecked(debuffs.show_slow ~= false)
        end
        if SettingsPage.controls.plates_debuffs_show_dot ~= nil then
            SettingsPage.controls.plates_debuffs_show_dot:SetChecked(debuffs.show_dot ~= false)
        end
        if SettingsPage.controls.plates_debuffs_show_misc ~= nil then
            SettingsPage.controls.plates_debuffs_show_misc:SetChecked(debuffs.show_misc ~= false)
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
        if SettingsPage.controls.target_gearscore_gradient ~= nil then
            SettingsPage.controls.target_gearscore_gradient:SetChecked(displayStyle.target_gearscore_gradient and true or false)
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
        if SettingsPage.controls.target_class_offset_x ~= nil then
            refreshSlider(SettingsPage.controls.target_class_offset_x, SettingsPage.controls.target_class_offset_x_val, tonumber(displayStyle.target_class_offset_x) or 10)
        end
        if SettingsPage.controls.target_class_offset_y ~= nil then
            refreshSlider(SettingsPage.controls.target_class_offset_y, SettingsPage.controls.target_class_offset_y_val, tonumber(displayStyle.target_class_offset_y) or -36)
        end
        if SettingsPage.controls.target_pdef_offset_x ~= nil then
            refreshSlider(SettingsPage.controls.target_pdef_offset_x, SettingsPage.controls.target_pdef_offset_x_val, tonumber(displayStyle.target_pdef_offset_x) or 110)
        end
        if SettingsPage.controls.target_pdef_offset_y ~= nil then
            refreshSlider(SettingsPage.controls.target_pdef_offset_y, SettingsPage.controls.target_pdef_offset_y_val, tonumber(displayStyle.target_pdef_offset_y) or -36)
        end
        if SettingsPage.controls.target_mdef_offset_x ~= nil then
            refreshSlider(SettingsPage.controls.target_mdef_offset_x, SettingsPage.controls.target_mdef_offset_x_val, tonumber(displayStyle.target_mdef_offset_x) or 190)
        end
        if SettingsPage.controls.target_mdef_offset_y ~= nil then
            refreshSlider(SettingsPage.controls.target_mdef_offset_y, SettingsPage.controls.target_mdef_offset_y_val, tonumber(displayStyle.target_mdef_offset_y) or -36)
        end
        if SettingsPage.controls.target_gearscore_offset_x ~= nil then
            refreshSlider(SettingsPage.controls.target_gearscore_offset_x, SettingsPage.controls.target_gearscore_offset_x_val, tonumber(displayStyle.target_gearscore_offset_x) or 10)
        end
        if SettingsPage.controls.target_gearscore_offset_y ~= nil then
            refreshSlider(SettingsPage.controls.target_gearscore_offset_y, SettingsPage.controls.target_gearscore_offset_y_val, tonumber(displayStyle.target_gearscore_offset_y) or -54)
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
        local hostileTargetHp = type(displayStyle.hostile_target_hp_color) == "table" and displayStyle.hostile_target_hp_color or { 255, 54, 40, 255 }
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

        if SettingsPage.controls.hostile_target_hp_enabled ~= nil then
            SettingsPage.controls.hostile_target_hp_enabled:SetChecked(displayStyle.hostile_target_hp_enabled == true)
        end
        if SettingsPage.controls.hostile_target_hp_r ~= nil then
            refreshSlider(SettingsPage.controls.hostile_target_hp_r, SettingsPage.controls.hostile_target_hp_r_val, tonumber(hostileTargetHp[1]) or 255)
        end
        if SettingsPage.controls.hostile_target_hp_g ~= nil then
            refreshSlider(SettingsPage.controls.hostile_target_hp_g, SettingsPage.controls.hostile_target_hp_g_val, tonumber(hostileTargetHp[2]) or 54)
        end
        if SettingsPage.controls.hostile_target_hp_b ~= nil then
            refreshSlider(SettingsPage.controls.hostile_target_hp_b, SettingsPage.controls.hostile_target_hp_b_val, tonumber(hostileTargetHp[3]) or 40)
        end
        if SettingsPage.controls.hostile_target_hp_a ~= nil then
            refreshSlider(SettingsPage.controls.hostile_target_hp_a, SettingsPage.controls.hostile_target_hp_a_val, tonumber(hostileTargetHp[4]) or 255)
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
        if SettingsPage.controls.hp_value_visible ~= nil then
            SettingsPage.controls.hp_value_visible:SetChecked(displayStyle.hp_value_visible ~= false)
        end
        if SettingsPage.controls.mp_value_visible ~= nil then
            SettingsPage.controls.mp_value_visible:SetChecked(displayStyle.mp_value_visible ~= false)
        end
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
        if SettingsPage.controls.aura_reverse_growth ~= nil then
            SettingsPage.controls.aura_reverse_growth:SetChecked(aura.reverse_growth and true or false)
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
    if SettingsPage.controls.ct_display_style ~= nil then
        SetComboBoxIndex1Based(SettingsPage.controls.ct_display_style, GetCooldownDisplayStyleIndex(selectedUnitCfg.display_style))
    end
    if SettingsPage.controls.ct_bar_order ~= nil then
        SetComboBoxIndex1Based(SettingsPage.controls.ct_bar_order, GetCooldownBarOrderIndex(selectedUnitCfg.cooldown_bar_order))
    end
    if SettingsPage.controls.ct_track_kind ~= nil then
        SetComboBoxIndex1Based(SettingsPage.controls.ct_track_kind, GetCooldownTrackKindIndex(SettingsPage.cooldown_track_kind))
    end
    if selectedUnitKey == "player" then
        SetReadableControlText(SettingsPage.controls.ct_position_hint, "Player uses an absolute screen position.")
    else
        SetReadableControlText(SettingsPage.controls.ct_position_hint, "These values are offsets from the unit's overhead nameplate.")
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
    if SettingsPage.controls.ct_bar_width ~= nil then
        refreshSlider(SettingsPage.controls.ct_bar_width, SettingsPage.controls.ct_bar_width_val, tonumber(selectedUnitCfg.bar_width) or 180)
    end
    if SettingsPage.controls.ct_bar_height ~= nil then
        refreshSlider(SettingsPage.controls.ct_bar_height, SettingsPage.controls.ct_bar_height_val, tonumber(selectedUnitCfg.bar_height) or 14)
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
    local barFillColor = type(selectedUnitCfg.bar_fill_color) == "table" and selectedUnitCfg.bar_fill_color or { 207, 74, 22, 255 }
    if SettingsPage.controls.ct_bar_fill_r ~= nil then
        refreshSlider(SettingsPage.controls.ct_bar_fill_r, SettingsPage.controls.ct_bar_fill_r_val, tonumber(barFillColor[1]) or 207)
    end
    if SettingsPage.controls.ct_bar_fill_g ~= nil then
        refreshSlider(SettingsPage.controls.ct_bar_fill_g, SettingsPage.controls.ct_bar_fill_g_val, tonumber(barFillColor[2]) or 74)
    end
    if SettingsPage.controls.ct_bar_fill_b ~= nil then
        refreshSlider(SettingsPage.controls.ct_bar_fill_b, SettingsPage.controls.ct_bar_fill_b_val, tonumber(barFillColor[3]) or 22)
    end
    local barBgColor = type(selectedUnitCfg.bar_bg_color) == "table" and selectedUnitCfg.bar_bg_color or { 18, 18, 18, 220 }
    if SettingsPage.controls.ct_bar_bg_r ~= nil then
        refreshSlider(SettingsPage.controls.ct_bar_bg_r, SettingsPage.controls.ct_bar_bg_r_val, tonumber(barBgColor[1]) or 18)
    end
    if SettingsPage.controls.ct_bar_bg_g ~= nil then
        refreshSlider(SettingsPage.controls.ct_bar_bg_g, SettingsPage.controls.ct_bar_bg_g_val, tonumber(barBgColor[2]) or 18)
    end
    if SettingsPage.controls.ct_bar_bg_b ~= nil then
        refreshSlider(SettingsPage.controls.ct_bar_bg_b, SettingsPage.controls.ct_bar_bg_b_val, tonumber(barBgColor[3]) or 18)
    end
    if SettingsPage.controls.ct_cache_timeout ~= nil then
        refreshSlider(SettingsPage.controls.ct_cache_timeout, SettingsPage.controls.ct_cache_timeout_val, tonumber(selectedUnitCfg.cache_timeout_s) or 300)
    end
    RefreshCooldownSearchRows()
    RefreshCooldownBuffRows(selectedUnitCfg)
    SettingsCooldown.RefreshScanRows(SettingsPage)
    RefreshSchemaControlStates()
    RefreshRepairDiagnostics()
    SettingsPage._refreshing_controls = false

end

ApplyControlsToSettings = function()
    local s = SettingsPage.settings
    if s == nil then
        return
    end
    s.enabled = (SettingsPage.controls.enabled ~= nil and SettingsPage.controls.enabled:GetChecked()) and true or false
    if SettingsPage.controls.drag_requires_shift ~= nil then
        s.drag_requires_shift = SettingsPage.controls.drag_requires_shift:GetChecked() and true or false
    end

    if SettingsPage.controls.alignment_grid_enabled ~= nil then
        s.alignment_grid_enabled = SettingsPage.controls.alignment_grid_enabled:GetChecked() and true or false
    end

    if SettingsPage.controls.hide_ancestral_icon_level ~= nil then
        s.hide_ancestral_icon_level = SettingsPage.controls.hide_ancestral_icon_level:GetChecked() and true or false
    end

    if SettingsPage.controls.show_class_icons ~= nil then
        s.show_class_icons = SettingsPage.controls.show_class_icons:GetChecked() and true or false
    end

    if SettingsPage.controls.hide_boss_frame_background ~= nil then
        s.hide_boss_frame_background = SettingsPage.controls.hide_boss_frame_background:GetChecked() and true or false
    end

    if SettingsPage.controls.hide_target_grade_star ~= nil then
        s.hide_target_grade_star = SettingsPage.controls.hide_target_grade_star:GetChecked() and true or false
    end

    if SettingsPage.controls.launcher_size ~= nil then
        if type(s.settings_button) ~= "table" then
            s.settings_button = {}
        end
        s.settings_button.size = GetSliderValue(SettingsPage.controls.launcher_size)
        ApplySettingsButtonLayout()
    end

    if type(s.cast_bar) ~= "table" then
        s.cast_bar = {}
    end
    if SettingsPage.controls.castbar_enabled ~= nil then
        s.cast_bar.enabled = SettingsPage.controls.castbar_enabled:GetChecked() and true or false
    end
    if SettingsPage.controls.castbar_lock_position ~= nil then
        s.cast_bar.lock_position = SettingsPage.controls.castbar_lock_position:GetChecked() and true or false
    end
    if SettingsPage.controls.castbar_width ~= nil then
        s.cast_bar.width = GetSliderValue(SettingsPage.controls.castbar_width)
    end
    if SettingsPage.controls.castbar_scale ~= nil then
        s.cast_bar.scale = GetSliderValue(SettingsPage.controls.castbar_scale) / 100
    end
    if SettingsPage.controls.castbar_texture_mode ~= nil then
        local idx = GetComboBoxIndex1Based(SettingsPage.controls.castbar_texture_mode, #CASTBAR_TEXTURE_MODE_KEYS)
        s.cast_bar.bar_texture_mode = GetCastBarTextureModeFromIndex(idx)
    end
    if SettingsPage.controls.castbar_fill_style ~= nil then
        local idx = GetComboBoxIndex1Based(SettingsPage.controls.castbar_fill_style, #CASTBAR_FILL_STYLE_KEYS)
        s.cast_bar.fill_style = GetCastBarFillStyleFromIndex(idx)
    end
    if SettingsPage.controls.castbar_border_thickness ~= nil then
        s.cast_bar.border_thickness = GetSliderValue(SettingsPage.controls.castbar_border_thickness)
    end
    if SettingsPage.controls.castbar_text_font_size ~= nil then
        s.cast_bar.text_font_size = GetSliderValue(SettingsPage.controls.castbar_text_font_size)
    end
    if SettingsPage.controls.castbar_text_offset_x ~= nil then
        s.cast_bar.text_offset_x = GetSliderValue(SettingsPage.controls.castbar_text_offset_x)
    end
    if SettingsPage.controls.castbar_text_offset_y ~= nil then
        s.cast_bar.text_offset_y = GetSliderValue(SettingsPage.controls.castbar_text_offset_y)
    end

    if type(s.travel_speed) ~= "table" then
        s.travel_speed = {}
    end
    if SettingsPage.controls.travel_speed_enabled ~= nil then
        s.travel_speed.enabled = SettingsPage.controls.travel_speed_enabled:GetChecked() and true or false
    end
    if SettingsPage.controls.travel_speed_lock_position ~= nil then
        s.travel_speed.lock_position = SettingsPage.controls.travel_speed_lock_position:GetChecked() and true or false
    end
    if SettingsPage.controls.travel_speed_only_vehicle_or_mount ~= nil then
        s.travel_speed.only_vehicle_or_mount = SettingsPage.controls.travel_speed_only_vehicle_or_mount:GetChecked() and true or false
    end
    if SettingsPage.controls.travel_speed_show_on_mount ~= nil then
        s.travel_speed.show_on_mount = SettingsPage.controls.travel_speed_show_on_mount:GetChecked() and true or false
    end
    if SettingsPage.controls.travel_speed_show_on_vehicle ~= nil then
        s.travel_speed.show_on_vehicle = SettingsPage.controls.travel_speed_show_on_vehicle:GetChecked() and true or false
    end
    if SettingsPage.controls.travel_speed_show_speed_text ~= nil then
        s.travel_speed.show_speed_text = SettingsPage.controls.travel_speed_show_speed_text:GetChecked() and true or false
    end
    if SettingsPage.controls.travel_speed_show_bar ~= nil then
        s.travel_speed.show_bar = SettingsPage.controls.travel_speed_show_bar:GetChecked() and true or false
    end
    if SettingsPage.controls.travel_speed_show_state_text ~= nil then
        s.travel_speed.show_state_text = SettingsPage.controls.travel_speed_show_state_text:GetChecked() and true or false
    end
    if SettingsPage.controls.travel_speed_width ~= nil then
        s.travel_speed.width = GetSliderValue(SettingsPage.controls.travel_speed_width)
    end
    if SettingsPage.controls.travel_speed_scale ~= nil then
        s.travel_speed.scale = GetSliderValue(SettingsPage.controls.travel_speed_scale) / 100
    end
    if SettingsPage.controls.travel_speed_font_size ~= nil then
        s.travel_speed.font_size = GetSliderValue(SettingsPage.controls.travel_speed_font_size)
    end

    if type(s.mount_glider) ~= "table" then
        s.mount_glider = {}
    end
    if SettingsPage.controls.mount_glider_enabled ~= nil then
        s.mount_glider.enabled = SettingsPage.controls.mount_glider_enabled:GetChecked() and true or false
    end
    if SettingsPage.controls.mount_glider_lock_position ~= nil then
        s.mount_glider.lock_position = SettingsPage.controls.mount_glider_lock_position:GetChecked() and true or false
    end
    if SettingsPage.controls.mount_glider_show_ready_icons ~= nil then
        s.mount_glider.show_ready_icons = SettingsPage.controls.mount_glider_show_ready_icons:GetChecked() and true or false
    end
    if SettingsPage.controls.mount_glider_show_timer ~= nil then
        s.mount_glider.show_timer = SettingsPage.controls.mount_glider_show_timer:GetChecked() and true or false
    end
    if SettingsPage.controls.mount_glider_use_mana_triggers ~= nil then
        s.mount_glider.use_mana_triggers = SettingsPage.controls.mount_glider_use_mana_triggers:GetChecked() and true or false
    end
    if SettingsPage.controls.mount_glider_notify_ready ~= nil then
        s.mount_glider.notify_ready = SettingsPage.controls.mount_glider_notify_ready:GetChecked() and true or false
    end
    if SettingsPage.controls.mount_glider_icon_size ~= nil then
        s.mount_glider.icon_size = GetSliderValue(SettingsPage.controls.mount_glider_icon_size)
    end
    if SettingsPage.controls.mount_glider_icon_spacing ~= nil then
        s.mount_glider.icon_spacing = GetSliderValue(SettingsPage.controls.mount_glider_icon_spacing)
    end
    if SettingsPage.controls.mount_glider_icons_per_row ~= nil then
        s.mount_glider.icons_per_row = GetSliderValue(SettingsPage.controls.mount_glider_icons_per_row)
    end
    if SettingsPage.controls.mount_glider_timer_font_size ~= nil then
        s.mount_glider.timer_font_size = GetSliderValue(SettingsPage.controls.mount_glider_timer_font_size)
    end

    if type(s.gear_loadouts) ~= "table" then
        s.gear_loadouts = {}
    end
    if SettingsPage.controls.gear_loadouts_enabled ~= nil then
        s.gear_loadouts.enabled = SettingsPage.controls.gear_loadouts_enabled:GetChecked() and true or false
    end
    if SettingsPage.controls.gear_loadouts_lock_bar ~= nil then
        s.gear_loadouts.lock_bar = SettingsPage.controls.gear_loadouts_lock_bar:GetChecked() and true or false
    end
    if SettingsPage.controls.gear_loadouts_lock_editor ~= nil then
        s.gear_loadouts.lock_editor = SettingsPage.controls.gear_loadouts_lock_editor:GetChecked() and true or false
    end
    if SettingsPage.controls.gear_loadouts_show_icons ~= nil then
        s.gear_loadouts.show_icons = SettingsPage.controls.gear_loadouts_show_icons:GetChecked() and true or false
    end
    if SettingsPage.controls.gear_loadouts_button_size ~= nil then
        s.gear_loadouts.button_size = GetSliderValue(SettingsPage.controls.gear_loadouts_button_size)
    end
    if SettingsPage.controls.gear_loadouts_button_width ~= nil then
        s.gear_loadouts.button_width = GetSliderValue(SettingsPage.controls.gear_loadouts_button_width)
    end

    if type(s.quest_watch) ~= "table" then
        s.quest_watch = {}
    end
    local questWatchProfile = GetQuestWatchProfile(s.quest_watch)
    if SettingsPage.controls.quest_watch_enabled ~= nil then
        s.quest_watch.enabled = SettingsPage.controls.quest_watch_enabled:GetChecked() and true or false
    end
    if SettingsPage.controls.quest_watch_lock_position ~= nil then
        s.quest_watch.lock_position = SettingsPage.controls.quest_watch_lock_position:GetChecked() and true or false
    end
    if SettingsPage.controls.quest_watch_hide_when_done ~= nil then
        s.quest_watch.hide_when_done = SettingsPage.controls.quest_watch_hide_when_done:GetChecked() and true or false
    end
    if SettingsPage.controls.quest_watch_show_ids ~= nil then
        s.quest_watch.show_ids = SettingsPage.controls.quest_watch_show_ids:GetChecked() and true or false
    end
    if SettingsPage.controls.quest_watch_width ~= nil then
        s.quest_watch.width = GetSliderValue(SettingsPage.controls.quest_watch_width)
    end
    if SettingsPage.controls.quest_watch_scale ~= nil then
        s.quest_watch.scale = GetSliderValue(SettingsPage.controls.quest_watch_scale) / 100
    end
    if SettingsPage.controls.quest_watch_max_visible ~= nil then
        s.quest_watch.max_visible = GetSliderValue(SettingsPage.controls.quest_watch_max_visible)
    end
    if SettingsPage.controls.quest_watch_update_interval ~= nil then
        s.quest_watch.update_interval_ms = GetSliderValue(SettingsPage.controls.quest_watch_update_interval) * 1000
    end
    if type(questWatchProfile) == "table" and type(SettingsPage.controls.quest_watch_rows) == "table" then
        if type(questWatchProfile.tracked) ~= "table" then
            questWatchProfile.tracked = {}
        end
        for _, row in ipairs(SettingsPage.controls.quest_watch_rows) do
            if type(row) == "table" and row.checkbox ~= nil and row.checkbox.GetChecked ~= nil then
                questWatchProfile.tracked[tostring(row.key or "")] = row.checkbox:GetChecked() and true or false
            end
        end
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
    local activePage = tostring(SettingsPage.active_page or "")
    local applyTextStyle = activePage == "text"
    local applyBarsStyle = activePage == "bars"

    local _, targetEditStyle = GetTargetFrameStyleTables(s)

    local function colorTable(r, g, b, a)
        return { r, g, b, a or 255 }
    end

    if type(s.cast_bar) == "table" then
        if SettingsPage.controls.castbar_fill_r ~= nil then
            s.cast_bar.fill_color = colorTable(
                GetSliderValue(SettingsPage.controls.castbar_fill_r),
                GetSliderValue(SettingsPage.controls.castbar_fill_g),
                GetSliderValue(SettingsPage.controls.castbar_fill_b),
                GetSliderValue(SettingsPage.controls.castbar_fill_a)
            )
        end
        if SettingsPage.controls.castbar_bg_r ~= nil then
            s.cast_bar.bg_color = colorTable(
                GetSliderValue(SettingsPage.controls.castbar_bg_r),
                GetSliderValue(SettingsPage.controls.castbar_bg_g),
                GetSliderValue(SettingsPage.controls.castbar_bg_b),
                GetSliderValue(SettingsPage.controls.castbar_bg_a)
            )
        end
        if SettingsPage.controls.castbar_accent_r ~= nil then
            s.cast_bar.accent_color = colorTable(
                GetSliderValue(SettingsPage.controls.castbar_accent_r),
                GetSliderValue(SettingsPage.controls.castbar_accent_g),
                GetSliderValue(SettingsPage.controls.castbar_accent_b),
                GetSliderValue(SettingsPage.controls.castbar_accent_a)
            )
        end
        if SettingsPage.controls.castbar_text_r ~= nil then
            s.cast_bar.text_color = colorTable(
                GetSliderValue(SettingsPage.controls.castbar_text_r),
                GetSliderValue(SettingsPage.controls.castbar_text_g),
                GetSliderValue(SettingsPage.controls.castbar_text_b),
                GetSliderValue(SettingsPage.controls.castbar_text_a)
            )
        end
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
    if type(s.nameplates.debuffs) ~= "table" then
        s.nameplates.debuffs = {}
    end
    if SettingsPage.controls.plates_debuffs_enabled ~= nil then
        s.nameplates.debuffs.enabled = SettingsPage.controls.plates_debuffs_enabled:GetChecked() and true or false
    end
    if SettingsPage.controls.plates_debuffs_track_raid ~= nil then
        s.nameplates.debuffs.tracking_scope = SettingsPage.controls.plates_debuffs_track_raid:GetChecked() and "raid" or "focus"
    end
    if SettingsPage.controls.plates_debuffs_show_timer ~= nil then
        s.nameplates.debuffs.show_timer = SettingsPage.controls.plates_debuffs_show_timer:GetChecked() and true or false
    end
    if SettingsPage.controls.plates_debuffs_show_secondary ~= nil then
        s.nameplates.debuffs.show_secondary = SettingsPage.controls.plates_debuffs_show_secondary:GetChecked() and true or false
    end
    if SettingsPage.controls.plates_debuffs_anchor ~= nil then
        local idx = GetComboBoxIndex1Based(SettingsPage.controls.plates_debuffs_anchor, #DEBUFF_ANCHOR_KEYS)
        s.nameplates.debuffs.anchor = GetDebuffAnchorFromIndex(idx)
    end
    if SettingsPage.controls.plates_debuffs_max_icons ~= nil then
        s.nameplates.debuffs.max_icons = GetSliderValue(SettingsPage.controls.plates_debuffs_max_icons)
    end
    if SettingsPage.controls.plates_debuffs_icon_size ~= nil then
        s.nameplates.debuffs.icon_size = GetSliderValue(SettingsPage.controls.plates_debuffs_icon_size)
    end
    if SettingsPage.controls.plates_debuffs_secondary_size ~= nil then
        s.nameplates.debuffs.secondary_icon_size = GetSliderValue(SettingsPage.controls.plates_debuffs_secondary_size)
    end
    if SettingsPage.controls.plates_debuffs_timer_size ~= nil then
        s.nameplates.debuffs.timer_font_size = GetSliderValue(SettingsPage.controls.plates_debuffs_timer_size)
    end
    if SettingsPage.controls.plates_debuffs_gap ~= nil then
        s.nameplates.debuffs.gap = GetSliderValue(SettingsPage.controls.plates_debuffs_gap)
    end
    if SettingsPage.controls.plates_debuffs_offset_x ~= nil then
        s.nameplates.debuffs.offset_x = GetSliderValue(SettingsPage.controls.plates_debuffs_offset_x)
    end
    if SettingsPage.controls.plates_debuffs_offset_y ~= nil then
        s.nameplates.debuffs.offset_y = GetSliderValue(SettingsPage.controls.plates_debuffs_offset_y)
    end
    if SettingsPage.controls.plates_debuffs_show_hard ~= nil then
        s.nameplates.debuffs.show_hard = SettingsPage.controls.plates_debuffs_show_hard:GetChecked() and true or false
    end
    if SettingsPage.controls.plates_debuffs_show_silence ~= nil then
        s.nameplates.debuffs.show_silence = SettingsPage.controls.plates_debuffs_show_silence:GetChecked() and true or false
    end
    if SettingsPage.controls.plates_debuffs_show_root ~= nil then
        s.nameplates.debuffs.show_root = SettingsPage.controls.plates_debuffs_show_root:GetChecked() and true or false
    end
    if SettingsPage.controls.plates_debuffs_show_slow ~= nil then
        s.nameplates.debuffs.show_slow = SettingsPage.controls.plates_debuffs_show_slow:GetChecked() and true or false
    end
    if SettingsPage.controls.plates_debuffs_show_dot ~= nil then
        s.nameplates.debuffs.show_dot = SettingsPage.controls.plates_debuffs_show_dot:GetChecked() and true or false
    end
    if SettingsPage.controls.plates_debuffs_show_misc ~= nil then
        s.nameplates.debuffs.show_misc = SettingsPage.controls.plates_debuffs_show_misc:GetChecked() and true or false
    end

    if SettingsPage.controls.large_hpmp ~= nil then
        s.style.large_hpmp = SettingsPage.controls.large_hpmp:GetChecked() and true or false
    end

    if SettingsPage.controls.show_distance ~= nil then
        s.show_distance = SettingsPage.controls.show_distance:GetChecked() and true or false
    end

    if type(targetEditStyle) == "table" then
        if SettingsPage.controls.target_grade_star_offset_x ~= nil then
            targetEditStyle.target_grade_star_offset_x = GetSliderValue(SettingsPage.controls.target_grade_star_offset_x)
        end
        if SettingsPage.controls.target_grade_star_offset_y ~= nil then
            targetEditStyle.target_grade_star_offset_y = GetSliderValue(SettingsPage.controls.target_grade_star_offset_y)
        end
    end

    if applyBarsStyle then
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
    end

    if applyTextStyle then
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
        if SettingsPage.controls.target_gearscore_gradient ~= nil then
            editStyle.target_gearscore_gradient = SettingsPage.controls.target_gearscore_gradient:GetChecked() and true or false
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

        if SettingsPage.controls.hp_value_visible ~= nil then
            editStyle.hp_value_visible = SettingsPage.controls.hp_value_visible:GetChecked() and true or false
        end
        if SettingsPage.controls.mp_value_visible ~= nil then
            editStyle.mp_value_visible = SettingsPage.controls.mp_value_visible:GetChecked() and true or false
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
        if SettingsPage.controls.target_class_offset_x ~= nil then
            editStyle.target_class_offset_x = GetSliderValue(SettingsPage.controls.target_class_offset_x)
        end
        if SettingsPage.controls.target_class_offset_y ~= nil then
            editStyle.target_class_offset_y = GetSliderValue(SettingsPage.controls.target_class_offset_y)
        end
        if SettingsPage.controls.target_pdef_offset_x ~= nil then
            editStyle.target_pdef_offset_x = GetSliderValue(SettingsPage.controls.target_pdef_offset_x)
        end
        if SettingsPage.controls.target_pdef_offset_y ~= nil then
            editStyle.target_pdef_offset_y = GetSliderValue(SettingsPage.controls.target_pdef_offset_y)
        end
        if SettingsPage.controls.target_mdef_offset_x ~= nil then
            editStyle.target_mdef_offset_x = GetSliderValue(SettingsPage.controls.target_mdef_offset_x)
        end
        if SettingsPage.controls.target_mdef_offset_y ~= nil then
            editStyle.target_mdef_offset_y = GetSliderValue(SettingsPage.controls.target_mdef_offset_y)
        end
        if SettingsPage.controls.target_gearscore_offset_x ~= nil then
            editStyle.target_gearscore_offset_x = GetSliderValue(SettingsPage.controls.target_gearscore_offset_x)
        end
        if SettingsPage.controls.target_gearscore_offset_y ~= nil then
            editStyle.target_gearscore_offset_y = GetSliderValue(SettingsPage.controls.target_gearscore_offset_y)
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
    end

    if applyBarsStyle then
        if SettingsPage.controls.bar_colors_enabled ~= nil then
            editStyle.bar_colors_enabled = SettingsPage.controls.bar_colors_enabled:GetChecked() and true or false
        end
        if SettingsPage.controls.hostile_target_hp_enabled ~= nil then
            editStyle.hostile_target_hp_enabled = SettingsPage.controls.hostile_target_hp_enabled:GetChecked() and true or false
        end
    end

    if applyBarsStyle then
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
        if SettingsPage.controls.hostile_target_hp_r ~= nil
            and SettingsPage.controls.hostile_target_hp_g ~= nil
            and SettingsPage.controls.hostile_target_hp_b ~= nil then
            editStyle.hostile_target_hp_color = colorTable(
                GetSliderValue(SettingsPage.controls.hostile_target_hp_r),
                GetSliderValue(SettingsPage.controls.hostile_target_hp_g),
                GetSliderValue(SettingsPage.controls.hostile_target_hp_b),
                sliderOr(SettingsPage.controls.hostile_target_hp_a, 255)
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
                            frameStyle.hostile_target_hp_enabled = nil
                            frameStyle.hostile_target_hp_color = nil
                            frameStyle.mp_bar_color = nil
                            frameStyle.mp_fill_color = nil
                            frameStyle.mp_after_color = nil
                        end
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

    if applyBarsStyle and SettingsPage.controls.overlay_alpha ~= nil then
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
    if SettingsPage.controls.aura_reverse_growth ~= nil then
        s.style.aura.reverse_growth = SettingsPage.controls.aura_reverse_growth:GetChecked() and true or false
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
    if SettingsPage.controls.ct_display_style ~= nil then
        local idx = GetComboBoxIndex1Based(SettingsPage.controls.ct_display_style, #COOLDOWN_DISPLAY_STYLE_LABELS)
        selectedUnitCfg.display_style = GetCooldownDisplayStyleFromIndex(idx)
    end
    if SettingsPage.controls.ct_bar_order ~= nil then
        local idx = GetComboBoxIndex1Based(SettingsPage.controls.ct_bar_order, #COOLDOWN_BAR_ORDER_LABELS)
        selectedUnitCfg.cooldown_bar_order = GetCooldownBarOrderFromIndex(idx)
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
    if SettingsPage.controls.ct_bar_width ~= nil then
        selectedUnitCfg.bar_width = GetSliderValue(SettingsPage.controls.ct_bar_width)
    end
    if SettingsPage.controls.ct_bar_height ~= nil then
        selectedUnitCfg.bar_height = GetSliderValue(SettingsPage.controls.ct_bar_height)
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
    if SettingsPage.controls.ct_bar_fill_r ~= nil and SettingsPage.controls.ct_bar_fill_g ~= nil and SettingsPage.controls.ct_bar_fill_b ~= nil then
        selectedUnitCfg.bar_fill_color = colorTable(
            GetSliderValue(SettingsPage.controls.ct_bar_fill_r),
            GetSliderValue(SettingsPage.controls.ct_bar_fill_g),
            GetSliderValue(SettingsPage.controls.ct_bar_fill_b),
            255
        )
    end
    if SettingsPage.controls.ct_bar_bg_r ~= nil and SettingsPage.controls.ct_bar_bg_g ~= nil and SettingsPage.controls.ct_bar_bg_b ~= nil then
        selectedUnitCfg.bar_bg_color = colorTable(
            GetSliderValue(SettingsPage.controls.ct_bar_bg_r),
            GetSliderValue(SettingsPage.controls.ct_bar_bg_g),
            GetSliderValue(SettingsPage.controls.ct_bar_bg_b),
            220
        )
    end
    if SettingsPage.controls.ct_cache_timeout ~= nil then
        selectedUnitCfg.cache_timeout_s = GetSliderValue(SettingsPage.controls.ct_cache_timeout)
    end

    if applyBarsStyle and SettingsPage.controls.value_fmt_curmax ~= nil and SettingsPage.controls.value_fmt_percent ~= nil then
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

    if applyBarsStyle and SettingsPage.controls.short_numbers ~= nil then
        editStyle.short_numbers = SettingsPage.controls.short_numbers:GetChecked() and true or false
    end

    if (applyTextStyle or applyBarsStyle) and SettingsPage.style_target == "all" and type(PruneStyleFrameOverrides) == "function" then
        PruneStyleFrameOverrides(s, { "player", "target", "watchtarget", "target_of_target", "party" })
    end

end

local function EnsureWindow()
    if SettingsPage.window ~= nil then
        return
    end

    if api == nil or api.Interface == nil then
        return
    end

    if api.Interface.CreateEmptyWindow ~= nil then
        SettingsPage.window = api.Interface:CreateEmptyWindow("PolarUiSettings", "UIParent")
    elseif api.Interface.CreateWindow ~= nil then
        SettingsPage.window = api.Interface:CreateWindow("PolarUiSettings", "Nuzi UI Settings", 0, 0)
    end
    if SettingsPage.window == nil then
        return
    end
    if SettingsPage.window.SetExtent ~= nil then
        SettingsPage.window:SetExtent(920, 760)
    end
    if SettingsPage.window.EnableHidingIsRemove ~= nil then
        SettingsPage.window:EnableHidingIsRemove(false)
    end
    SettingsPage.window:AddAnchor("CENTER", "UIParent", 0, 0)

    local closeHandler = MakeCloseHandler()
    if SettingsPage.window.SetHandler ~= nil then
        SettingsPage.window:SetHandler("OnCloseByEsc", closeHandler)
    end
    function SettingsPage.window:OnClose()
        closeHandler()
    end

    local shell = CreateEmptyChild(SettingsPage.window, "polarUiShell")
    if shell ~= nil then
        pcall(function()
            shell:AddAnchor("TOPLEFT", SettingsPage.window, 0, 0)
            shell:AddAnchor("BOTTOMRIGHT", SettingsPage.window, 0, 0)
            shell:Show(true)
        end)
        AddPanelBackground(shell, 0.94)
    end

    local header = CreateEmptyChild(SettingsPage.window, "polarUiHeader")
    if header ~= nil then
        pcall(function()
            header:AddAnchor("TOPLEFT", SettingsPage.window, 0, 0)
            header:AddAnchor("TOPRIGHT", SettingsPage.window, 0, 0)
            if header.SetHeight ~= nil then
                header:SetHeight(34)
            else
                header:SetExtent(1, 34)
            end
            header:Show(true)
        end)
        AddPanelBackground(header, 0.98)
        pcall(function()
            if header.CreateColorDrawable ~= nil then
                local accent = header:CreateColorDrawable(0.94, 0.80, 0.48, 0.10, "overlay")
                accent:AddAnchor("TOPLEFT", header, 0, 0)
                accent:AddAnchor("TOPRIGHT", header, 0, 0)
                accent:SetHeight(34)
                local divider = header:CreateColorDrawable(0.94, 0.80, 0.48, 0.18, "overlay")
                divider:AddAnchor("BOTTOMLEFT", header, 10, 0)
                divider:AddAnchor("BOTTOMRIGHT", header, -10, 0)
                divider:SetHeight(1)
            end
        end)
        CreateLabel("polarUiHeaderTitle", header, "Nuzi UI Settings", 16, 8, 15, 260)
        local headerClose = CreateButton("polarUiHeaderClose", header, "X", 878, 4)
        if headerClose ~= nil then
            pcall(function()
                headerClose:SetExtent(28, 24)
            end)
            if headerClose.SetHandler ~= nil then
                headerClose:SetHandler("OnClick", closeHandler)
            end
        end
        AttachWindowShiftDrag(header, SettingsPage.window)
    end

    local navPanel = CreateEmptyChild(SettingsPage.window, "polarUiNavPanel")
    if navPanel ~= nil then
        pcall(function()
            navPanel:SetExtent(160, 655)
            navPanel:AddAnchor("TOPLEFT", SettingsPage.window, 12, 38)
            navPanel:AddAnchor("BOTTOMLEFT", SettingsPage.window, 12, -52)
            navPanel:Show(true)
        end)
        AddPanelBackground(navPanel, 0.88)
        pcall(function()
            if navPanel.CreateColorDrawable ~= nil then
                local accent = navPanel:CreateColorDrawable(0.93, 0.78, 0.45, 0.12, "overlay")
                accent:AddAnchor("TOPLEFT", navPanel, 0, 0)
                accent:AddAnchor("TOPRIGHT", navPanel, 0, 0)
                accent:SetHeight(42)
            end
        end)
    end

    local contentPanel = CreateEmptyChild(SettingsPage.window, "polarUiContentPanel")
    if contentPanel ~= nil then
        pcall(function()
            contentPanel:AddAnchor("TOPLEFT", SettingsPage.window, 182, 34)
            contentPanel:AddAnchor("BOTTOMRIGHT", SettingsPage.window, -12, -52)
            contentPanel:Show(true)
        end)
        AddPanelBackground(contentPanel, 0.86)
        pcall(function()
            if contentPanel.CreateColorDrawable ~= nil then
                local accent = contentPanel:CreateColorDrawable(0.94, 0.80, 0.48, 0.12, "overlay")
                accent:AddAnchor("TOPLEFT", contentPanel, 0, 0)
                accent:AddAnchor("TOPRIGHT", contentPanel, 0, 0)
                accent:SetHeight(54)

                local divider = contentPanel:CreateColorDrawable(0.94, 0.80, 0.48, 0.18, "overlay")
                divider:AddAnchor("TOPLEFT", contentPanel, 18, 58)
                divider:AddAnchor("TOPRIGHT", contentPanel, -18, 58)
                divider:SetHeight(1)
            end
        end)
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
            if contentPanel ~= nil then
                SettingsPage.scroll_frame:AddAnchor("TOPLEFT", contentPanel, 12, 78)
                SettingsPage.scroll_frame:AddAnchor("BOTTOMRIGHT", contentPanel, -12, -14)
            else
                SettingsPage.scroll_frame:AddAnchor("TOPLEFT", SettingsPage.window, 185, 105)
                SettingsPage.scroll_frame:AddAnchor("BOTTOMRIGHT", SettingsPage.window, -15, -50)
            end
            SettingsPage.scroll_frame:SetExtent(700, 585)
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

    local navParent = navPanel or SettingsPage.window
    local headerParent = contentPanel or SettingsPage.window

    CreateLabel("polarUiNavTitle", navParent, "Sections", 14, 12, 18)
    SettingsPage.controls.page_header_title = CreateLabel("polarUiPageHeaderTitle", headerParent, "", 18, 12, 18)
    SettingsPage.controls.page_header_summary = CreateHintLabel("polarUiPageHeaderSummary", headerParent, "", 18, 38, 690)
    if SettingsPage.controls.page_header_summary ~= nil then
        SettingsPage.controls.page_header_summary:SetExtent(
            690,
            math.max(32, tonumber(SettingsPage.controls.page_header_summary.__polar_estimated_height) or 16)
        )
    end

    local navY = 44
    for _, page in ipairs(PAGE_DEFS) do
        local button = CreateButton("polarUiNav_" .. tostring(page.id), navParent, tostring(page.label or page.id), 10, navY)
        if button ~= nil then
            pcall(function()
                button:SetExtent(140, 28)
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

    SettingsPage.schema_control_states = {}
    for _, schemaPageId in ipairs(SCHEMA_PAGE_IDS) do
        BuildSchemaPage(schemaPageId)
    end

    if SettingsCooldownPage ~= nil and SettingsCooldownPage.Build ~= nil then
        SettingsPage.page_heights.cooldown = SettingsCooldownPage.Build(SettingsPage, SettingsPage.pages.cooldown, gap)
    end

    local applyBtn = CreateButton("polarUiApplySettings", SettingsPage.window, "Apply", 185, 370)
    local closeBtn = CreateButton("polarUiCloseSettings", SettingsPage.window, "Close", 280, 370)
    local backupBtn = CreateButton("polarUiBackupSettings", SettingsPage.window, "Backup", 375, 370)
    local importBtn = CreateButton("polarUiImportSettings", SettingsPage.window, "Import", 470, 370)
    local backupStatus = CreateLabel("polarUiBackupStatus", SettingsPage.window, "", 570, 370 + 6, 14)
    if backupStatus ~= nil then
        backupStatus:SetExtent(320, 18)
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
        if SettingsPage._refreshing_controls then
            return
        end
        local ctrl = nil
        if SettingsPage.active_page == "text" then
            ctrl = SettingsPage.controls.style_target_text
        elseif SettingsPage.active_page == "bars" then
            ctrl = SettingsPage.controls.style_target_bars
        else
            return
        end
        SettingsPage.style_target = GetStyleTargetKeyFromControl(ctrl)
        SyncStyleTargetCombos()
        UpdateStyleTargetHints()
    end

    local function sliderChanged()
        if SettingsPage._refreshing_controls then
            return
        end
        if SettingsPage.settings == nil then
            return
        end
        syncStyleTargetFromActivePage()
        ApplyControlsToSettings()
        RefreshSchemaControlStates()
        if type(SettingsPage.on_apply) == "function" then
            pcall(function()
                SettingsPage.on_apply()
            end)
        end
    end

    local sliderList = {
        { SettingsPage.controls.launcher_size, SettingsPage.controls.launcher_size_val },
        { SettingsPage.controls.castbar_width, SettingsPage.controls.castbar_width_val },
        { SettingsPage.controls.castbar_scale, SettingsPage.controls.castbar_scale_val },
        { SettingsPage.controls.castbar_border_thickness, SettingsPage.controls.castbar_border_thickness_val },
        { SettingsPage.controls.castbar_text_font_size, SettingsPage.controls.castbar_text_font_size_val },
        { SettingsPage.controls.castbar_text_offset_x, SettingsPage.controls.castbar_text_offset_x_val },
        { SettingsPage.controls.castbar_text_offset_y, SettingsPage.controls.castbar_text_offset_y_val },
        { SettingsPage.controls.castbar_fill_r, SettingsPage.controls.castbar_fill_r_val },
        { SettingsPage.controls.castbar_fill_g, SettingsPage.controls.castbar_fill_g_val },
        { SettingsPage.controls.castbar_fill_b, SettingsPage.controls.castbar_fill_b_val },
        { SettingsPage.controls.castbar_fill_a, SettingsPage.controls.castbar_fill_a_val },
        { SettingsPage.controls.castbar_bg_r, SettingsPage.controls.castbar_bg_r_val },
        { SettingsPage.controls.castbar_bg_g, SettingsPage.controls.castbar_bg_g_val },
        { SettingsPage.controls.castbar_bg_b, SettingsPage.controls.castbar_bg_b_val },
        { SettingsPage.controls.castbar_bg_a, SettingsPage.controls.castbar_bg_a_val },
        { SettingsPage.controls.castbar_accent_r, SettingsPage.controls.castbar_accent_r_val },
        { SettingsPage.controls.castbar_accent_g, SettingsPage.controls.castbar_accent_g_val },
        { SettingsPage.controls.castbar_accent_b, SettingsPage.controls.castbar_accent_b_val },
        { SettingsPage.controls.castbar_accent_a, SettingsPage.controls.castbar_accent_a_val },
        { SettingsPage.controls.castbar_text_r, SettingsPage.controls.castbar_text_r_val },
        { SettingsPage.controls.castbar_text_g, SettingsPage.controls.castbar_text_g_val },
        { SettingsPage.controls.castbar_text_b, SettingsPage.controls.castbar_text_b_val },
        { SettingsPage.controls.castbar_text_a, SettingsPage.controls.castbar_text_a_val },
        { SettingsPage.controls.travel_speed_width, SettingsPage.controls.travel_speed_width_val },
        { SettingsPage.controls.travel_speed_scale, SettingsPage.controls.travel_speed_scale_val },
        { SettingsPage.controls.travel_speed_font_size, SettingsPage.controls.travel_speed_font_size_val },
        { SettingsPage.controls.mount_glider_icon_size, SettingsPage.controls.mount_glider_icon_size_val },
        { SettingsPage.controls.mount_glider_icon_spacing, SettingsPage.controls.mount_glider_icon_spacing_val },
        { SettingsPage.controls.mount_glider_icons_per_row, SettingsPage.controls.mount_glider_icons_per_row_val },
        { SettingsPage.controls.mount_glider_timer_font_size, SettingsPage.controls.mount_glider_timer_font_size_val },
        { SettingsPage.controls.gear_loadouts_button_size, SettingsPage.controls.gear_loadouts_button_size_val },
        { SettingsPage.controls.gear_loadouts_button_width, SettingsPage.controls.gear_loadouts_button_width_val },
        { SettingsPage.controls.quest_watch_width, SettingsPage.controls.quest_watch_width_val },
        { SettingsPage.controls.quest_watch_scale, SettingsPage.controls.quest_watch_scale_val },
        { SettingsPage.controls.quest_watch_max_visible, SettingsPage.controls.quest_watch_max_visible_val },
        { SettingsPage.controls.quest_watch_update_interval, SettingsPage.controls.quest_watch_update_interval_val },
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
        { SettingsPage.controls.target_class_offset_x, SettingsPage.controls.target_class_offset_x_val },
        { SettingsPage.controls.target_class_offset_y, SettingsPage.controls.target_class_offset_y_val },
        { SettingsPage.controls.target_pdef_offset_x, SettingsPage.controls.target_pdef_offset_x_val },
        { SettingsPage.controls.target_pdef_offset_y, SettingsPage.controls.target_pdef_offset_y_val },
        { SettingsPage.controls.target_mdef_offset_x, SettingsPage.controls.target_mdef_offset_x_val },
        { SettingsPage.controls.target_mdef_offset_y, SettingsPage.controls.target_mdef_offset_y_val },
        { SettingsPage.controls.target_gearscore_offset_x, SettingsPage.controls.target_gearscore_offset_x_val },
        { SettingsPage.controls.target_gearscore_offset_y, SettingsPage.controls.target_gearscore_offset_y_val },
        { SettingsPage.controls.target_grade_star_offset_x, SettingsPage.controls.target_grade_star_offset_x_val },
        { SettingsPage.controls.target_grade_star_offset_y, SettingsPage.controls.target_grade_star_offset_y_val },
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
        { SettingsPage.controls.hostile_target_hp_r, SettingsPage.controls.hostile_target_hp_r_val },
        { SettingsPage.controls.hostile_target_hp_g, SettingsPage.controls.hostile_target_hp_g_val },
        { SettingsPage.controls.hostile_target_hp_b, SettingsPage.controls.hostile_target_hp_b_val },
        { SettingsPage.controls.hostile_target_hp_a, SettingsPage.controls.hostile_target_hp_a_val },
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
        { SettingsPage.controls.plates_debuffs_max_icons, SettingsPage.controls.plates_debuffs_max_icons_val },
        { SettingsPage.controls.plates_debuffs_icon_size, SettingsPage.controls.plates_debuffs_icon_size_val },
        { SettingsPage.controls.plates_debuffs_secondary_size, SettingsPage.controls.plates_debuffs_secondary_size_val },
        { SettingsPage.controls.plates_debuffs_timer_size, SettingsPage.controls.plates_debuffs_timer_size_val },
        { SettingsPage.controls.plates_debuffs_gap, SettingsPage.controls.plates_debuffs_gap_val },
        { SettingsPage.controls.plates_debuffs_offset_x, SettingsPage.controls.plates_debuffs_offset_x_val },
        { SettingsPage.controls.plates_debuffs_offset_y, SettingsPage.controls.plates_debuffs_offset_y_val },
        { SettingsPage.controls.ct_update_interval, SettingsPage.controls.ct_update_interval_val },
        { SettingsPage.controls.ct_icon_size, SettingsPage.controls.ct_icon_size_val },
        { SettingsPage.controls.ct_icon_spacing, SettingsPage.controls.ct_icon_spacing_val },
        { SettingsPage.controls.ct_max_icons, SettingsPage.controls.ct_max_icons_val },
        { SettingsPage.controls.ct_bar_width, SettingsPage.controls.ct_bar_width_val },
        { SettingsPage.controls.ct_bar_height, SettingsPage.controls.ct_bar_height_val },
        { SettingsPage.controls.ct_bar_fill_r, SettingsPage.controls.ct_bar_fill_r_val },
        { SettingsPage.controls.ct_bar_fill_g, SettingsPage.controls.ct_bar_fill_g_val },
        { SettingsPage.controls.ct_bar_fill_b, SettingsPage.controls.ct_bar_fill_b_val },
        { SettingsPage.controls.ct_bar_bg_r, SettingsPage.controls.ct_bar_bg_r_val },
        { SettingsPage.controls.ct_bar_bg_g, SettingsPage.controls.ct_bar_bg_g_val },
        { SettingsPage.controls.ct_bar_bg_b, SettingsPage.controls.ct_bar_bg_b_val },
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
                if type(value) == "number" then
                    slider.__polar_live_value = value
                end
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
                if type(value) == "number" then
                    slider.__polar_live_value = value
                end
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
        SettingsPage.controls.aura_reverse_growth,
        SettingsPage.controls.name_visible,
        SettingsPage.controls.level_visible,
        SettingsPage.controls.drag_requires_shift,
        SettingsPage.controls.large_hpmp,
        SettingsPage.controls.hide_ancestral_icon_level,
        SettingsPage.controls.show_class_icons,
        SettingsPage.controls.hide_boss_frame_background,
        SettingsPage.controls.hide_target_grade_star,
        SettingsPage.controls.show_distance,
        SettingsPage.controls.alignment_grid_enabled,
        SettingsPage.controls.castbar_enabled,
        SettingsPage.controls.castbar_lock_position,
        SettingsPage.controls.travel_speed_enabled,
        SettingsPage.controls.travel_speed_lock_position,
        SettingsPage.controls.travel_speed_only_vehicle_or_mount,
        SettingsPage.controls.travel_speed_show_on_mount,
        SettingsPage.controls.travel_speed_show_on_vehicle,
        SettingsPage.controls.travel_speed_show_speed_text,
        SettingsPage.controls.travel_speed_show_bar,
        SettingsPage.controls.travel_speed_show_state_text,
        SettingsPage.controls.mount_glider_enabled,
        SettingsPage.controls.mount_glider_lock_position,
        SettingsPage.controls.mount_glider_show_ready_icons,
        SettingsPage.controls.mount_glider_show_timer,
        SettingsPage.controls.mount_glider_use_mana_triggers,
        SettingsPage.controls.mount_glider_notify_ready,
        SettingsPage.controls.gear_loadouts_enabled,
        SettingsPage.controls.gear_loadouts_lock_bar,
        SettingsPage.controls.gear_loadouts_lock_editor,
        SettingsPage.controls.gear_loadouts_show_icons,
        SettingsPage.controls.quest_watch_enabled,
        SettingsPage.controls.quest_watch_lock_position,
        SettingsPage.controls.quest_watch_hide_when_done,
        SettingsPage.controls.quest_watch_show_ids,
        SettingsPage.controls.bar_colors_enabled,
        SettingsPage.controls.hostile_target_hp_enabled,
        SettingsPage.controls.overlay_shadow,
        SettingsPage.controls.target_guild_visible,
        SettingsPage.controls.target_class_visible,
        SettingsPage.controls.target_gearscore_visible,
        SettingsPage.controls.target_gearscore_gradient,
        SettingsPage.controls.target_pdef_visible,
        SettingsPage.controls.target_mdef_visible,
        SettingsPage.controls.name_shadow,
        SettingsPage.controls.value_shadow,
        SettingsPage.controls.hp_value_visible,
        SettingsPage.controls.mp_value_visible,
        SettingsPage.controls.move_buffs,
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
        SettingsPage.controls.plates_debuffs_enabled,
        SettingsPage.controls.plates_debuffs_track_raid,
        SettingsPage.controls.plates_debuffs_show_timer,
        SettingsPage.controls.plates_debuffs_show_secondary,
        SettingsPage.controls.plates_debuffs_show_hard,
        SettingsPage.controls.plates_debuffs_show_silence,
        SettingsPage.controls.plates_debuffs_show_root,
        SettingsPage.controls.plates_debuffs_show_slow,
        SettingsPage.controls.plates_debuffs_show_dot,
        SettingsPage.controls.plates_debuffs_show_misc,
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

    if SettingsPage.controls.ct_display_style ~= nil and SettingsPage.controls.ct_display_style.SetHandler ~= nil then
        SettingsPage.controls.ct_display_style:SetHandler("OnSelChanged", function()
            ApplyControlsToSettings()
            if type(SettingsPage.on_apply) == "function" then
                pcall(function()
                    SettingsPage.on_apply()
                end)
            end
            RefreshControls()
        end)
    end

    if SettingsPage.controls.ct_bar_order ~= nil and SettingsPage.controls.ct_bar_order.SetHandler ~= nil then
        SettingsPage.controls.ct_bar_order:SetHandler("OnSelChanged", function()
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
            SettingsCooldown.ScanTargetEffects(SettingsPage)
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
                    AddCooldownTrackedBuffToSelectedUnit(id, entry.kind, GetCooldownSecondsEditText())
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
            if tonumber(txt) == nil then
                return
            end
            txt = FormatBuffId(txt)

            local kindIdx = GetComboBoxIndex1Based(SettingsPage.controls.ct_track_kind, #COOLDOWN_TRACK_KIND_LABELS)
            SettingsPage.cooldown_track_kind = GetCooldownTrackKindFromIndex(kindIdx)
            AddCooldownTrackedBuffToSelectedUnit(txt, SettingsPage.cooldown_track_kind, GetCooldownSecondsEditText())
            if SettingsPage.controls.ct_new_buff_id ~= nil and SettingsPage.controls.ct_new_buff_id.SetText ~= nil then
                SettingsPage.controls.ct_new_buff_id:SetText("")
            end
            if SettingsPage.controls.ct_new_cooldown_s ~= nil and SettingsPage.controls.ct_new_cooldown_s.SetText ~= nil then
                SettingsPage.controls.ct_new_cooldown_s:SetText("")
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
                    AddCooldownTrackedBuffToSelectedUnit(rawId, SettingsPage.cooldown_track_kind, GetCooldownSecondsEditText())
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
            if type(row) == "table" and row.cooldown_save ~= nil and row.cooldown_save.SetHandler ~= nil then
                local currentRow = row
                local btn = row.cooldown_save
                row.cooldown_save:SetHandler("OnClick", function()
                    if SettingsPage.settings == nil then
                        return
                    end
                    local idx = tonumber(btn ~= nil and btn.__polar_buff_index or nil)
                    local seconds = GetEditText(currentRow.cooldown_edit)
                    if SettingsCooldown.SetTrackedBuffCooldown(SettingsPage, idx, seconds) then
                        RefreshControls()
                    end
                end)
            end
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
        if SettingsPage._refreshing_controls or SettingsPage._refreshing_style_target then
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
        SyncStyleTargetCombos()
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
    if SettingsPage.controls.castbar_texture_mode ~= nil and SettingsPage.controls.castbar_texture_mode.SetHandler ~= nil then
        SettingsPage.controls.castbar_texture_mode:SetHandler("OnSelChanged", function()
            if SettingsPage._refreshing_castbar_texture then
                return
            end
            sliderChanged()
        end)
    end
    if SettingsPage.controls.castbar_fill_style ~= nil and SettingsPage.controls.castbar_fill_style.SetHandler ~= nil then
        SettingsPage.controls.castbar_fill_style:SetHandler("OnSelChanged", function()
            if SettingsPage._refreshing_castbar_fill_style then
                return
            end
            sliderChanged()
        end)
    end
    if SettingsPage.controls.plates_debuffs_anchor ~= nil and SettingsPage.controls.plates_debuffs_anchor.SetHandler ~= nil then
        SettingsPage.controls.plates_debuffs_anchor:SetHandler("OnSelChanged", function()
            if SettingsPage._refreshing_debuff_anchor then
                return
            end
            sliderChanged()
        end)
    end

    for _, cb in ipairs(checkboxList) do
        if cb ~= nil and cb.SetHandler ~= nil then
            cb:SetHandler("OnClick", function()
                if SettingsPage._refreshing_controls then
                    return
                end
                sliderChanged()
            end)
        end
    end

    if type(SettingsPage.controls.quest_watch_rows) == "table" then
        for _, row in ipairs(SettingsPage.controls.quest_watch_rows) do
            if type(row) == "table" and row.checkbox ~= nil and row.checkbox.SetHandler ~= nil then
                row.checkbox:SetHandler("OnClick", function()
                    if SettingsPage._refreshing_controls then
                        return
                    end
                    sliderChanged()
                    if type(SettingsPage.on_save) == "function" then
                        pcall(function()
                            SettingsPage.on_save()
                        end)
                    end
                end)
            end
        end
    end

    local function bindHpTextureCheckbox(ctrl, mode)
        if ctrl ~= nil and ctrl.SetHandler ~= nil then
            ctrl:SetHandler("OnClick", function()
                if SettingsPage._refreshing_controls then
                    return
                end
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
    UpdateCastBarPreview()
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
        UpdateCastBarPreview()
    end
end

function SettingsPage.OnUpdate(dt)
    if SettingsSchemaCustom ~= nil and type(SettingsSchemaCustom.OnUpdate) == "function" then
        SettingsSchemaCustom.OnUpdate(MakeCustomSchemaContext(), dt)
    end
end

function SettingsPage.Unload()
    if SettingsSchemaCustom ~= nil and type(SettingsSchemaCustom.Unload) == "function" then
        SettingsSchemaCustom.Unload()
    end
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
    UpdateCastBarPreview()
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
