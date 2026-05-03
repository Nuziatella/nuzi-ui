local SettingsCooldown = require("nuzi-ui/settings_cooldown")
local SettingsWidgets = require("nuzi-ui/settings_widgets")

local CooldownPage = {}

local CreateLabel = SettingsWidgets.CreateLabel
local CreateHintLabel = SettingsWidgets.CreateHintLabel
local CreateCheckbox = SettingsWidgets.CreateCheckbox
local CreateButton = SettingsWidgets.CreateButton
local CreateEdit = SettingsWidgets.CreateEdit
local CreateSlider = SettingsWidgets.CreateSlider
local CreateComboBox = SettingsWidgets.CreateComboBox

local function setDigit(field)
    if field ~= nil and field.SetDigit ~= nil then
        pcall(function()
            field:SetDigit(true)
        end)
    end
end

local function createSlider(controls, key, id, page, label, x, y, minValue, maxValue, step)
    controls[key], controls[key .. "_val"] = CreateSlider(id, page, label, x, y, minValue, maxValue, step)
end

local function createColorSliders(controls, prefix, idPrefix, page, y)
    createSlider(controls, prefix .. "_r", idPrefix .. "R", page, "R", 15, y, 0, 255, 1)
    y = y + 24
    createSlider(controls, prefix .. "_g", idPrefix .. "G", page, "G", 15, y, 0, 255, 1)
    y = y + 24
    createSlider(controls, prefix .. "_b", idPrefix .. "B", page, "B", 15, y, 0, 255, 1)
    return y + 24
end

function CooldownPage.Build(state, page, gap)
    if type(state) ~= "table" or page == nil then
        return 0
    end
    if type(state.controls) ~= "table" then
        state.controls = {}
    end

    local controls = state.controls
    gap = tonumber(gap) or 24

    local y = 35
    CreateLabel("polarUiCooldownPageTitle", page, "Cooldown Tracker", 15, y, 18)
    y = y + 30

    controls.ct_enabled = CreateCheckbox("polarUiCooldownEnabled", page, "Enable cooldown tracker", 15, y)
    y = y + gap

    createSlider(
        controls,
        "ct_update_interval",
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
    controls.ct_unit = CreateComboBox(page, SettingsCooldown.UNIT_LABELS, 110, y - 4, 220, 24)
    CreateLabel("polarUiCooldownDisplayModeLabel", page, "Show", 350, y, 15)
    controls.ct_display_mode = CreateComboBox(page, SettingsCooldown.DISPLAY_MODE_LABELS, 400, y - 4, 180, 24)
    y = y + 34

    CreateLabel("polarUiCooldownDisplayStyleLabel", page, "Style", 15, y, 15)
    controls.ct_display_style = CreateComboBox(page, SettingsCooldown.DISPLAY_STYLE_LABELS, 110, y - 4, 220, 24)
    y = y + 34

    controls.ct_unit_enabled = CreateCheckbox("polarUiCooldownUnitEnabled", page, "Enable for selected unit", 15, y)
    y = y + gap

    controls.ct_lock_position = CreateCheckbox("polarUiCooldownLockPosition", page, "Lock position (disable dragging)", 15, y)
    y = y + gap + 10

    CreateLabel("polarUiCooldownPositionTitle", page, "Position", 15, y, 18)
    y = y + 30

    controls.ct_position_hint = CreateHintLabel("polarUiCooldownPositionHint", page, "Player uses an absolute screen position.", 15, y)
    if controls.ct_position_hint ~= nil then
        controls.ct_position_hint:SetExtent(360, math.max(18, tonumber(controls.ct_position_hint.__polar_estimated_height) or 16))
    end
    y = y + 24

    CreateLabel("polarUiCooldownPosXLabel", page, "X", 15, y, 15)
    controls.ct_pos_x = CreateEdit("polarUiCooldownPosX", page, "0", 35, y - 4, 90, 22)
    setDigit(controls.ct_pos_x)

    CreateLabel("polarUiCooldownPosYLabel", page, "Y", 145, y, 15)
    controls.ct_pos_y = CreateEdit("polarUiCooldownPosY", page, "0", 165, y - 4, 90, 22)
    setDigit(controls.ct_pos_y)
    y = y + gap + 10

    CreateLabel("polarUiCooldownIconsTitle", page, "Icons", 15, y, 18)
    y = y + 30

    createSlider(controls, "ct_icon_size", "polarUiCooldownIconSize", page, "Icon size", 15, y, 12, 80, 1)
    y = y + 24
    createSlider(controls, "ct_icon_spacing", "polarUiCooldownIconSpacing", page, "Icon spacing", 15, y, -8, 20, 1)
    y = y + 24
    createSlider(controls, "ct_max_icons", "polarUiCooldownMaxIcons", page, "Max icons", 15, y, 1, 20, 1)
    y = y + gap + 10

    CreateLabel("polarUiCooldownBarsTitle", page, "Bars", 15, y, 18)
    y = y + 30

    createSlider(controls, "ct_bar_width", "polarUiCooldownBarWidth", page, "Bar width", 15, y, 60, 360, 1)
    y = y + 24
    createSlider(controls, "ct_bar_height", "polarUiCooldownBarHeight", page, "Bar height", 15, y, 4, 32, 1)
    y = y + 24

    CreateLabel("polarUiCooldownBarOrderLabel", page, "Bar order", 15, y, 15)
    controls.ct_bar_order = CreateComboBox(page, SettingsCooldown.BAR_ORDER_LABELS, 110, y - 4, 220, 24)
    y = y + 34

    CreateLabel("polarUiCooldownBarFillColorTitle", page, "Bar fill color (RGB)", 15, y, 15)
    y = createColorSliders(controls, "ct_bar_fill", "polarUiCooldownBarFill", page, y + 22)

    CreateLabel("polarUiCooldownBarBgColorTitle", page, "Bar background color (RGB)", 15, y, 15)
    y = createColorSliders(controls, "ct_bar_bg", "polarUiCooldownBarBg", page, y + 22)
    y = y + gap + 10

    CreateLabel("polarUiCooldownTimerTitle", page, "Timer Text", 15, y, 18)
    y = y + 30

    controls.ct_show_timer = CreateCheckbox("polarUiCooldownShowTimer", page, "Show timer", 15, y)
    y = y + gap

    createSlider(controls, "ct_timer_fs", "polarUiCooldownTimerFontSize", page, "Timer font size", 15, y, 6, 40, 1)
    y = y + 24

    CreateLabel("polarUiCooldownTimerColorTitle", page, "Timer color (RGB)", 15, y, 15)
    y = createColorSliders(controls, "ct_timer", "polarUiCooldownTimer", page, y + 22)
    y = y + gap + 10

    CreateLabel("polarUiCooldownLabelTitle", page, "Label Text", 15, y, 18)
    y = y + 30

    controls.ct_show_label = CreateCheckbox("polarUiCooldownShowLabel", page, "Show label", 15, y)
    y = y + gap

    createSlider(controls, "ct_label_fs", "polarUiCooldownLabelFontSize", page, "Label font size", 15, y, 6, 40, 1)
    y = y + 24

    CreateLabel("polarUiCooldownLabelColorTitle", page, "Label color (RGB)", 15, y, 15)
    y = createColorSliders(controls, "ct_label", "polarUiCooldownLabel", page, y + 22)
    y = y + gap + 10

    CreateLabel("polarUiCooldownTargetCacheTitle", page, "Target Cache", 15, y, 18)
    y = y + 30

    createSlider(controls, "ct_cache_timeout", "polarUiCooldownCacheTimeout", page, "Cache timeout (sec) (target only)", 15, y, 0, 600, 1)
    y = y + gap + 10

    CreateLabel("polarUiCooldownTrackedBuffsTitle", page, "Tracked Effects", 15, y, 18)
    y = y + 30

    controls.ct_new_buff_id = CreateEdit("polarUiCooldownNewBuffId", page, "", 15, y - 4, 120, 22)
    setDigit(controls.ct_new_buff_id)
    controls.ct_add_buff = CreateButton("polarUiCooldownAddBuff", page, "Add", 145, y - 6)
    CreateLabel("polarUiCooldownTrackKindLabel", page, "Track as", 225, y, 15)
    controls.ct_track_kind = CreateComboBox(page, SettingsCooldown.TRACK_KIND_LABELS, 290, y - 4, 110, 24)
    CreateLabel("polarUiCooldownNewCooldownLabel", page, "Cooldown sec", 420, y, 15)
    controls.ct_new_cooldown_s = CreateEdit("polarUiCooldownNewCooldownS", page, "", 525, y - 4, 70, 22)
    setDigit(controls.ct_new_cooldown_s)
    y = y + 34

    CreateLabel("polarUiCooldownSearchLabel", page, "Search", 15, y, 15)
    controls.ct_search_text = CreateEdit("polarUiCooldownSearchText", page, "", 75, y - 4, 220, 22)
    controls.ct_search_btn = CreateButton("polarUiCooldownSearchBtn", page, "Find", 305, y - 6)
    if controls.ct_search_btn ~= nil then
        controls.ct_search_btn:SetExtent(60, 22)
    end
    y = y + 34

    controls.ct_search_status = CreateLabel("polarUiCooldownSearchStatus", page, "", 15, y, 14)
    if controls.ct_search_status ~= nil then
        controls.ct_search_status:SetExtent(380, 18)
    end
    controls.ct_search_more = CreateButton("polarUiCooldownSearchMore", page, "More", 405, y - 6)
    if controls.ct_search_more ~= nil then
        controls.ct_search_more:SetExtent(65, 22)
    end
    y = y + 34

    controls.ct_search_rows = {}
    for i = 1, SettingsCooldown.SEARCH_ROWS do
        local rowY = y + ((i - 1) * 26)
        local label = CreateLabel("polarUiCooldownSearchRowLabel" .. tostring(i), page, "", 15, rowY + 6, 14)
        if label ~= nil then
            label:SetExtent(560, 18)
        end
        local add = CreateButton("polarUiCooldownSearchRowAdd" .. tostring(i), page, "Add", 585, rowY)
        if add ~= nil then
            add:SetExtent(60, 22)
        end
        controls.ct_search_rows[i] = { label = label, add = add }
    end
    y = y + (SettingsCooldown.SEARCH_ROWS * 26) + 10

    controls.ct_prev_page = CreateButton("polarUiCooldownPrevPage", page, "Prev", 15, y)
    controls.ct_next_page = CreateButton("polarUiCooldownNextPage", page, "Next", 110, y)
    controls.ct_page_label = CreateLabel("polarUiCooldownPageLabel", page, "1 / 1", 215, y + 6, 14)
    y = y + 34

    CreateLabel("polarUiCooldownTrackedEffectHeader", page, "Effect", 15, y, 13, 360)
    CreateLabel("polarUiCooldownTrackedCooldownHeader", page, "CD sec", 405, y, 13, 60)
    y = y + 22

    controls.ct_buff_rows = {}
    for i = 1, SettingsCooldown.BUFFS_PER_PAGE do
        local rowY = y + ((i - 1) * 26)
        local label = CreateLabel("polarUiCooldownBuffRowLabel" .. tostring(i), page, "", 15, rowY + 6, 14)
        if label ~= nil then
            label:SetExtent(380, 18)
        end
        local cooldownEdit = CreateEdit("polarUiCooldownBuffRowCooldown" .. tostring(i), page, "", 405, rowY - 1, 55, 22)
        setDigit(cooldownEdit)
        local cooldownSave = CreateButton("polarUiCooldownBuffRowCooldownSave" .. tostring(i), page, "Save", 466, rowY)
        if cooldownSave ~= nil then
            cooldownSave:SetExtent(58, 22)
        end
        local remove = CreateButton("polarUiCooldownBuffRowRemove" .. tostring(i), page, "Remove", 535, rowY)
        if remove ~= nil then
            remove:SetExtent(90, 22)
        end
        controls.ct_buff_rows[i] = { label = label, cooldown_edit = cooldownEdit, cooldown_save = cooldownSave, remove = remove }
    end
    y = y + (SettingsCooldown.BUFFS_PER_PAGE * 26) + 20

    CreateLabel("polarUiCooldownScanTitle", page, "Scan Target Buffs/Debuffs", 15, y, 18)
    y = y + 30

    controls.ct_scan_btn = CreateButton("polarUiCooldownScanBtn", page, "Scan", 15, y - 6)
    controls.ct_scan_status = CreateLabel("polarUiCooldownScanStatus", page, "", 110, y, 14)
    if controls.ct_scan_status ~= nil then
        controls.ct_scan_status:SetExtent(320, 18)
    end
    y = y + 34

    controls.ct_scan_rows = {}
    for i = 1, SettingsCooldown.SCAN_ROWS do
        local rowY = y + ((i - 1) * 26)
        local label = CreateLabel("polarUiCooldownScanRowLabel" .. tostring(i), page, "", 15, rowY + 6, 14)
        if label ~= nil then
            label:SetExtent(560, 18)
        end
        local add = CreateButton("polarUiCooldownScanRowAdd" .. tostring(i), page, "Add", 585, rowY)
        if add ~= nil then
            add:SetExtent(60, 22)
        end
        controls.ct_scan_rows[i] = { label = label, add = add }
    end
    y = y + (SettingsCooldown.SCAN_ROWS * 26) + 20

    return y + 40
end

return CooldownPage
