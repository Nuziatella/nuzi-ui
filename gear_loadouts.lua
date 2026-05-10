local api = require("api")
local Runtime = require("nuzi-ui/runtime")
local Layout = require("nuzi-ui/layout")
local SettingsStore = require("nuzi-ui/settings_store")

local GearLoadouts = {
    settings = nil,
    enabled = true,
    bar = nil,
    editor = nil,
    bar_buttons = {},
    slot_widgets = {},
    selected_slot_key = nil,
    current_character_key = nil,
    equip_queue = {},
    equip_delay_ms = 0,
    equip_target_loadout_id = nil,
    pending_check_ms = nil,
    pending_check_loadout_id = nil,
    refreshing_dropdown = false,
    refreshing_auto_controls = false,
    auto_accum_ms = 0,
    auto_active_loadout_id = nil,
    auto_pending_loadout_id = nil,
    auto_zone_name = "",
    auto_zone_ms = 0,
    auto_buff_name_cache = {}
}

local SLOT_DEFS = {
    { key = "head", api_key = "HEAD", label = "Head", short = "Head", x = 24, y = 0 },
    { key = "chest", api_key = "CHEST", label = "Chest", short = "Chest", x = 24, y = 46 },
    { key = "waist", api_key = "WAIST", label = "Waist", short = "Waist", x = 24, y = 92 },
    { key = "arms", api_key = "ARMS", label = "Wrist", short = "Wrist", x = 24, y = 138 },
    { key = "hands", api_key = "HANDS", label = "Hands", short = "Hands", x = 24, y = 184 },
    { key = "back", api_key = "BACK", label = "Cloak", short = "Cloak", x = 24, y = 230 },
    { key = "legs", api_key = "LEGS", label = "Pants", short = "Pants", x = 24, y = 276 },
    { key = "feet", api_key = "FEET", label = "Boots", short = "Boots", x = 24, y = 322 },
    { key = "undershirt", api_key = "UNDERPANTS", label = "Undergarments", short = "Under", x = 24, y = 368 },
    { key = "cosplay", api_key = "COSPLAY", label = "Costume", short = "Cost", x = 178, y = 0 },
    { key = "backpack", api_key = "BACKPACK", label = "Glider", short = "Glider", x = 178, y = 368 },
    { key = "neck", api_key = "NECK", label = "Neck", short = "Neck", x = 316, y = 0 },
    { key = "ear1", api_key = "EAR_1", label = "Ear 1", short = "Ear 1", x = 316, y = 46 },
    { key = "ear2", api_key = "EAR_2", label = "Ear 2", short = "Ear 2", x = 316, y = 92, is_aux = true },
    { key = "finger1", api_key = "FINGER_1", label = "Ring 1", short = "Ring 1", x = 316, y = 138 },
    { key = "finger2", api_key = "FINGER_2", label = "Ring 2", short = "Ring 2", x = 316, y = 184, is_aux = true },
    { key = "mainhand", api_key = "MAINHAND", label = "Main", short = "Main", x = 316, y = 230 },
    { key = "offhand", api_key = "OFFHAND", label = "Off", short = "Off", x = 316, y = 276, is_aux = true },
    { key = "ranged", api_key = "RANGED", label = "Bow", short = "Bow", x = 316, y = 322 },
    { key = "musical", api_key = "MUSICAL", label = "Music", short = "Music", x = 316, y = 368 }
}

local SLOT_BY_KEY = {}
for _, def in ipairs(SLOT_DEFS) do
    SLOT_BY_KEY[def.key] = def
end

local APPELLATION_TYPE_INDEX = 1

local AUTO_TRIGGER_MANUAL = "manual"
local AUTO_TRIGGER_SWIMMING = "swimming"
local AUTO_TRIGGER_CAPTAIN = "captain"
local AUTO_TRIGGER_BUFF_ACTIVE = "buff_active"
local AUTO_UPDATE_INTERVAL_MS = 150
local ROUGH_SEA_ID = 7743
local DASH_ID = 2675
local STEALTH_ID = 8225
local AUTO_SWIMMING_BLOCKED_ZONES = { "growlgate", "freedich" }

local AUTO_TRIGGER_OPTIONS = {
    { value = AUTO_TRIGGER_MANUAL, label = "Manual" },
    { value = AUTO_TRIGGER_SWIMMING, label = "Swimming" },
    { value = AUTO_TRIGGER_CAPTAIN, label = "Captain" },
    { value = AUTO_TRIGGER_BUFF_ACTIVE, label = "Buff Active" }
}

local AUTO_DEFAULT_HINT = "Addon auto-swaps wait until combat ends."
local AUTO_SWIMMING_HINT = "Swimming does not auto-trigger in Freedich or Growlgate."

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

local function trim(value)
    return (tostring(value or ""):gsub("^%s*(.-)%s*$", "%1"))
end

local function clampInt(value, minValue, maxValue, fallback)
    local n = tonumber(value)
    if n == nil then
        return fallback
    end
    n = math.floor(n + 0.5)
    if n < minValue then
        return minValue
    elseif n > maxValue then
        return maxValue
    end
    return n
end

local function showWidget(widget, visible)
    if widget == nil or widget.Show == nil then
        return
    end
    safeCall(function()
        widget:Show(visible and true or false)
    end)
end

local function setWidgetClickable(widget, enabled)
    if widget == nil then
        return
    end
    enabled = enabled and true or false
    if widget.__nuzi_loadouts_clickable == enabled then
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
    widget.__nuzi_loadouts_clickable = enabled
end

local function setWidgetDragEnabled(widget, enabled)
    if widget == nil then
        return
    end
    enabled = enabled and true or false
    if widget.__nuzi_loadouts_drag_enabled == enabled then
        return
    end
    if widget.EnableDrag ~= nil then
        safeCall(function()
            widget:EnableDrag(enabled)
        end)
    end
    widget.__nuzi_loadouts_drag_enabled = enabled
end

local function freeWidget(widget)
    if widget == nil then
        return
    end
    showWidget(widget, false)
    if api.Interface ~= nil and api.Interface.Free ~= nil then
        safeCall(function()
            api.Interface:Free(widget)
        end)
    end
end

local function setText(widget, text)
    if widget == nil or widget.SetText == nil then
        return
    end
    local value = tostring(text or "")
    if widget.__nuzi_text == value then
        return
    end
    widget.__nuzi_text = value
    safeCall(function()
        widget:SetText(value)
    end)
end

local function setLabelColor(label, r, g, b, a)
    if label == nil or label.style == nil or label.style.SetColor == nil then
        return
    end
    safeCall(function()
        label.style:SetColor(r, g, b, a or 1)
    end)
end

local function applyButtonSkin(button, skin)
    if button == nil or api.Interface == nil or api.Interface.ApplyButtonSkin == nil or skin == nil then
        return
    end
    safeCall(function()
        api.Interface:ApplyButtonSkin(button, skin)
    end)
end

local function attachButtonHover(button)
    if button == nil or button.__nuzi_loadouts_hover_ready then
        return
    end
    button.__nuzi_loadouts_hover_ready = true

    local hover = nil
    if button.CreateColorDrawable ~= nil then
        hover = safeCall(function()
            return button:CreateColorDrawable(0.95, 0.70, 0.28, 0.18, "overlay")
        end)
        if hover ~= nil then
            safeCall(function()
                hover:AddAnchor("TOPLEFT", button, 0, 0)
                hover:AddAnchor("BOTTOMRIGHT", button, 0, 0)
                hover:Show(false)
            end)
            button.__nuzi_loadouts_hover = hover
        end
    end

    local function setHover(active)
        if button.__nuzi_loadouts_hover ~= nil then
            showWidget(button.__nuzi_loadouts_hover, active)
        elseif button.style ~= nil and button.style.SetColor ~= nil then
            safeCall(function()
                if active then
                    button.style:SetColor(1, 0.92, 0.58, 1)
                else
                    button.style:SetColor(0.94, 0.86, 0.70, 1)
                end
            end)
        end
    end

    setHover(false)
    if button.SetHandler ~= nil then
        button:SetHandler("OnEnter", function()
            setHover(true)
        end)
        button:SetHandler("OnLeave", function()
            setHover(false)
        end)
    end
end

local function createWindow(id)
    if api.Interface == nil or api.Interface.CreateEmptyWindow == nil then
        return nil
    end
    local window = safeCall(function()
        return api.Interface:CreateEmptyWindow(id, "UIParent")
    end)
    if window ~= nil then
        safeCall(function()
            if window.SetCloseOnEscape ~= nil then
                window:SetCloseOnEscape(false)
            end
            if window.EnableHidingIsRemove ~= nil then
                window:EnableHidingIsRemove(false)
            end
            if window.SetUILayer ~= nil then
                window:SetUILayer("game")
            end
        end)
        setWidgetClickable(window, true)
        setWidgetDragEnabled(window, false)
    end
    return window
end

local function addPanelBackground(parent, alpha)
    if parent == nil then
        return nil
    end
    local bg = nil
    if parent.CreateNinePartDrawable ~= nil and TEXTURE_PATH ~= nil and TEXTURE_PATH.HUD ~= nil then
        bg = safeCall(function()
            return parent:CreateNinePartDrawable(TEXTURE_PATH.HUD, "background")
        end)
        if bg ~= nil then
            safeCall(function()
                if bg.SetTextureInfo ~= nil then
                    bg:SetTextureInfo("bg_quest")
                end
                if bg.SetColor ~= nil then
                    bg:SetColor(0.07, 0.055, 0.035, alpha or 0.88)
                end
                bg:AddAnchor("TOPLEFT", parent, 0, 0)
                bg:AddAnchor("BOTTOMRIGHT", parent, 0, 0)
            end)
        end
    elseif parent.CreateColorDrawable ~= nil then
        bg = safeCall(function()
            return parent:CreateColorDrawable(0.07, 0.055, 0.035, alpha or 0.88, "background")
        end)
        if bg ~= nil then
            safeCall(function()
                bg:AddAnchor("TOPLEFT", parent, 0, 0)
                bg:AddAnchor("BOTTOMRIGHT", parent, 0, 0)
            end)
        end
    end
    return bg
end

local function createLabel(parent, id, text, x, y, width, height, fontSize, align)
    if parent == nil then
        return nil
    end
    local label = nil
    if W_CTRL ~= nil and W_CTRL.CreateLabel ~= nil then
        label = safeCall(function()
            return W_CTRL.CreateLabel(id, parent)
        end)
    end
    if label == nil and parent.CreateChildWidget ~= nil then
        label = safeCall(function()
            return parent:CreateChildWidget("label", id, 0, true)
        end)
    end
    if label ~= nil then
        safeCall(function()
            label:AddAnchor("TOPLEFT", parent, x or 0, y or 0)
            label:SetExtent(width or 120, height or 18)
            label:SetText(tostring(text or ""))
            if label.style ~= nil then
                label.style:SetFontSize(fontSize or 13)
                label.style:SetShadow(true)
                if align ~= nil then
                    label.style:SetAlign(align)
                elseif ALIGN ~= nil and ALIGN.LEFT ~= nil then
                    label.style:SetAlign(ALIGN.LEFT)
                end
            end
            label:Show(true)
        end)
    end
    return label
end

local function createButton(parent, id, text, x, y, width, height)
    if parent == nil or parent.CreateChildWidget == nil then
        return nil
    end
    local button = safeCall(function()
        return parent:CreateChildWidget("button", id, 0, true)
    end)
    if button ~= nil then
        safeCall(function()
            button:AddAnchor("TOPLEFT", parent, x or 0, y or 0)
            button:SetExtent(width or 80, height or 24)
            button:SetText(tostring(text or ""))
            if button.Enable ~= nil then
                button:Enable(true)
            end
            button:Show(true)
        end)
        applyButtonSkin(button, BUTTON_BASIC ~= nil and BUTTON_BASIC.DEFAULT or nil)
        setWidgetClickable(button, true)
        attachButtonHover(button)
    end
    return button
end

local function createIconButton(parent, id)
    local button = nil
    if type(CreateItemIconButton) == "function" then
        button = safeCall(function()
            return CreateItemIconButton(id, parent)
        end)
    end
    if button == nil and parent ~= nil and parent.CreateChildWidget ~= nil then
        button = safeCall(function()
            return parent:CreateChildWidget("button", id, 0, true)
        end)
        applyButtonSkin(button, BUTTON_BASIC ~= nil and BUTTON_BASIC.DEFAULT or nil)
    end
    if button ~= nil then
        safeCall(function()
            if button.Enable ~= nil then
                button:Enable(true)
            end
        end)
        setWidgetClickable(button, true)
    end
    return button
end

local function createEdit(parent, id, x, y, width, height, guide)
    local edit = nil
    if W_CTRL ~= nil and W_CTRL.CreateEdit ~= nil then
        edit = safeCall(function()
            return W_CTRL.CreateEdit(id, parent)
        end)
    end
    if edit ~= nil then
        safeCall(function()
            edit:AddAnchor("TOPLEFT", parent, x or 0, y or 0)
            edit:SetExtent(width or 160, height or 26)
            if guide ~= nil and edit.CreateGuideText ~= nil then
                edit:CreateGuideText(tostring(guide))
            end
            edit:Show(true)
        end)
    end
    return edit
end

local function createComboBox(parent, items, x, y, width, height)
    local combo = nil
    if api.Interface ~= nil and api.Interface.CreateComboBox ~= nil then
        combo = safeCall(function()
            return api.Interface:CreateComboBox(parent)
        end)
    end
    if combo ~= nil then
        safeCall(function()
            combo:SetExtent(width or 160, height or 26)
            combo:AddAnchor("TOPLEFT", parent, x or 0, y or 0)
            combo.dropdownItem = items or {}
            combo:Show(true)
        end)
    end
    return combo
end

local function getEditText(edit)
    if edit == nil or edit.GetText == nil then
        return ""
    end
    local value = safeCall(function()
        return edit:GetText()
    end)
    return tostring(value or "")
end

local function setEditText(edit, text)
    if edit == nil or edit.SetText == nil then
        return
    end
    safeCall(function()
        edit:SetText(tostring(text or ""))
    end)
end

local function anchorTopLeft(window, x, y)
    if window == nil or window.AddAnchor == nil then
        return
    end
    local uiScale = (Layout ~= nil and type(Layout.GetUiScale) == "function") and Layout.GetUiScale() or 1
    if Layout ~= nil and type(Layout.AnchorTopLeftScreen) == "function" then
        Layout.AnchorTopLeftScreen(window, x, y)
        window.__nuzi_layout_ui_scale = uiScale
        return
    end
    safeCall(function()
        window:AddAnchor("TOPLEFT", "UIParent", tonumber(x) or 0, tonumber(y) or 0)
    end)
    window.__nuzi_layout_ui_scale = uiScale
end

local function saveSettings(settings)
    if type(settings) ~= "table" then
        return
    end
    SettingsStore.SaveSettingsFile(settings)
end

local function ensureSettings(settings)
    if type(settings) ~= "table" then
        return nil
    end
    if type(settings.gear_loadouts) ~= "table" then
        settings.gear_loadouts = {}
    end
    local cfg = settings.gear_loadouts
    if cfg.enabled == nil then
        cfg.enabled = false
    end
    if cfg.show_icons == nil then
        cfg.show_icons = false
    end
    if tonumber(cfg.bar_pos_x) == nil then
        cfg.bar_pos_x = 420
    end
    if tonumber(cfg.bar_pos_y) == nil then
        cfg.bar_pos_y = 240
    end
    if tonumber(cfg.editor_pos_x) == nil then
        cfg.editor_pos_x = 520
    end
    if tonumber(cfg.editor_pos_y) == nil then
        cfg.editor_pos_y = 170
    end
    if tonumber(cfg.button_size) == nil then
        cfg.button_size = 38
    end
    if tonumber(cfg.button_width) == nil then
        cfg.button_width = 126
    end
    if type(cfg.characters) ~= "table" then
        cfg.characters = {}
    end
    return cfg
end

local function normalizeCharacterKey(name)
    local key = trim(name)
    if key == "" then
        key = "player"
    end
    key = string.lower(key)
    key = string.gsub(key, "%s+", "_")
    key = string.gsub(key, "[^%w_%-]", "")
    if key == "" then
        key = "player"
    end
    return key
end

local function getCharacterKey()
    local name = ""
    if Runtime ~= nil and Runtime.GetPlayerName ~= nil then
        name = Runtime.GetPlayerName()
    end
    return normalizeCharacterKey(name)
end

local function getProfile(settings)
    local cfg = ensureSettings(settings)
    if cfg == nil then
        return nil
    end
    local key = getCharacterKey()
    if type(cfg.characters[key]) ~= "table" then
        cfg.characters[key] = {
            loadouts = {},
            selected_id = nil
        }
    end
    local profile = cfg.characters[key]
    if type(profile.loadouts) ~= "table" then
        profile.loadouts = {}
    end
    GearLoadouts.current_character_key = key
    return profile
end

local function getSlotIndex(def)
    if type(def) ~= "table" then
        return nil
    end
    if type(EQUIP_SLOT) == "table" then
        return tonumber(EQUIP_SLOT[def.api_key])
    end
    return nil
end

local function getLoadoutById(profile, id)
    if type(profile) ~= "table" or type(profile.loadouts) ~= "table" then
        return nil, nil
    end
    for index, loadout in ipairs(profile.loadouts) do
        if tostring(loadout.id or "") == tostring(id or "") then
            return loadout, index
        end
    end
    return nil, nil
end

local function getSelectedLoadout(settings)
    local profile = getProfile(settings)
    if profile == nil then
        return nil, nil, nil
    end
    local loadout, index = getLoadoutById(profile, profile.selected_id)
    if loadout == nil and #profile.loadouts > 0 then
        index = 1
        loadout = profile.loadouts[1]
        profile.selected_id = loadout.id
    end
    return loadout, index, profile
end

local function getAutoTriggerValue(loadout)
    if type(loadout) ~= "table" then
        return AUTO_TRIGGER_MANUAL
    end
    local value = tostring(loadout.auto_trigger or AUTO_TRIGGER_MANUAL)
    for _, option in ipairs(AUTO_TRIGGER_OPTIONS) do
        if option.value == value then
            return value
        end
    end
    return AUTO_TRIGGER_MANUAL
end

local function getAutoTriggerLabel(value)
    for _, option in ipairs(AUTO_TRIGGER_OPTIONS) do
        if option.value == value then
            return option.label
        end
    end
    return AUTO_TRIGGER_OPTIONS[1].label
end

local function getAutoTriggerIndex(value)
    for index, option in ipairs(AUTO_TRIGGER_OPTIONS) do
        if option.value == value then
            return index
        end
    end
    return 1
end

local function getAutoTriggerLabels()
    local labels = {}
    for _, option in ipairs(AUTO_TRIGGER_OPTIONS) do
        labels[#labels + 1] = option.label
    end
    return labels
end

local function getAutoTriggerHint(value)
    if value == AUTO_TRIGGER_SWIMMING then
        return AUTO_SWIMMING_HINT
    end
    return AUTO_DEFAULT_HINT
end

local function makeLoadoutId(profile)
    local stamp = 0
    if api.Time ~= nil and api.Time.GetUiMsec ~= nil then
        stamp = tonumber(safeCall(function()
            return api.Time:GetUiMsec()
        end)) or 0
    end
    return string.format("%s_%d_%d", tostring(GearLoadouts.current_character_key or "player"), math.floor(stamp + 0.5), #profile.loadouts + 1)
end

local function createNewLoadout(settings)
    local profile = getProfile(settings)
    if profile == nil then
        return nil
    end
    local loadout = {
        id = makeLoadoutId(profile),
        name = "Loadout " .. tostring(#profile.loadouts + 1),
        slots = {},
        icon_slot = nil
    }
    table.insert(profile.loadouts, loadout)
    profile.selected_id = loadout.id
    saveSettings(settings)
    return loadout
end

local function normalizeItemName(value)
    local text = trim(value)
    text = string.lower(text)
    text = string.gsub(text, "%s+", " ")
    return text
end

local function itemIsEmpty(info)
    if type(info) ~= "table" then
        return true
    end
    local itemType = tonumber(info.itemType or info.item_type)
    if itemType ~= nil and itemType <= 0 then
        return true
    end
    local name = trim(info.name)
    if name == "" or name == "invalid item type" then
        return itemType == nil or itemType <= 0
    end
    return false
end

local function readEquippedItem(def)
    local slotIndex = getSlotIndex(def)
    if slotIndex == nil or api.Equipment == nil then
        return nil
    end
    local item = nil
    if api.Equipment.GetEquippedItemTooltipInfo ~= nil then
        item = safeCall(function()
            return api.Equipment:GetEquippedItemTooltipInfo(slotIndex)
        end)
    end
    if api.Equipment.GetEquippedItemTooltipText ~= nil then
        if itemIsEmpty(item) then
            item = safeCall(function()
                return api.Equipment:GetEquippedItemTooltipText("player", slotIndex)
            end)
        end
    end
    if itemIsEmpty(item) then
        return nil
    end
    return item
end

local function readCurrentAppellationType()
    if api.Player == nil or api.Player.GetShowingAppellation == nil then
        return nil
    end
    local info = safeCall(function()
        return api.Player:GetShowingAppellation()
    end)
    if info == nil then
        return 0
    end
    if type(info) ~= "table" then
        return nil
    end
    local titleType = tonumber(info[APPELLATION_TYPE_INDEX])
    if titleType == nil then
        return nil
    end
    return math.floor(titleType + 0.5)
end

local function getBagCapacity()
    if api.Bag ~= nil and api.Bag.Capacity ~= nil then
        local value = tonumber(safeCall(function()
            return api.Bag:Capacity()
        end))
        if value ~= nil and value > 0 then
            return math.floor(value + 0.5)
        end
    end
    return 150
end

local function getBagItem(index)
    if api.Bag == nil or api.Bag.GetBagItemInfo == nil then
        return nil
    end
    local item = safeCall(function()
        return api.Bag:GetBagItemInfo(1, index)
    end)
    if itemIsEmpty(item) then
        return nil
    end
    return item
end

local function getCursorBagIndex()
    if api.Cursor == nil or api.Cursor.GetCursorPickedBagItemIndex == nil then
        return nil
    end
    local index = tonumber(safeCall(function()
        return api.Cursor:GetCursorPickedBagItemIndex()
    end))
    if index == nil or index <= 0 then
        return nil
    end
    return math.floor(index + 0.5)
end

local function clearCursor()
    if api.Cursor ~= nil and api.Cursor.ClearCursor ~= nil then
        safeCall(function()
            api.Cursor:ClearCursor()
        end)
    end
end

local function copyIconInfo(iconInfo)
    if type(iconInfo) ~= "table" then
        return nil
    end
    local copy = {}
    local copied = false
    if type(iconInfo.itemIcon) == "string" and iconInfo.itemIcon ~= "" then
        copy.itemIcon = iconInfo.itemIcon
        copied = true
    end
    if type(iconInfo.overIcon) == "string" and iconInfo.overIcon ~= "" then
        copy.overIcon = iconInfo.overIcon
        copied = true
    end
    if type(iconInfo.frameIcon) == "string" and iconInfo.frameIcon ~= "" then
        copy.frameIcon = iconInfo.frameIcon
        copied = true
    end
    if copied then
        return copy
    end
    return nil
end

local function itemDescriptor(def, item)
    if type(def) ~= "table" or type(item) ~= "table" then
        return nil
    end
    local itemType = tonumber(item.itemType)
    local lookType = tonumber(item.lookType)
    local itemGrade = tonumber(item.itemGrade)
    local iconInfo = copyIconInfo(item.iconInfo)
    if iconInfo == nil and type(item.path) == "string" and item.path ~= "" then
        iconInfo = {
            itemIcon = item.path
        }
    end
    return {
        slot_key = def.key,
        slot_index = getSlotIndex(def),
        name = trim(item.name),
        item_type = itemType,
        look_type = lookType,
        item_grade = itemGrade,
        icon_path = tostring(item.path or ""),
        icon_info = iconInfo,
        is_aux = def.is_aux and true or false
    }
end

local function buildItemInfo(saved)
    if type(saved) ~= "table" then
        return nil
    end
    local itemType = tonumber(saved.item_type or saved.itemType)
    local itemGrade = tonumber(saved.item_grade or saved.itemGrade) or 1
    local info = {}
    if itemType ~= nil then
        info.itemType = itemType
    end
    if tonumber(saved.look_type or saved.lookType) ~= nil then
        info.lookType = tonumber(saved.look_type or saved.lookType)
    end
    info.itemGrade = itemGrade
    if trim(saved.name) ~= "" then
        info.name = trim(saved.name)
    end
    if trim(saved.icon_path) ~= "" then
        info.path = trim(saved.icon_path)
    end
    info.iconInfo = copyIconInfo(saved.icon_info or saved.iconInfo)
    if info.iconInfo == nil and info.path ~= nil and info.path ~= "" then
        info.iconInfo = {
            itemIcon = info.path
        }
    end
    return info
end

local function itemsMatch(saved, info)
    if type(saved) ~= "table" or type(info) ~= "table" or itemIsEmpty(info) then
        return false
    end
    local savedName = normalizeItemName(saved.name)
    local infoName = normalizeItemName(info.name)
    if savedName ~= "" and infoName ~= "" then
        return savedName == infoName
    end

    local savedType = tonumber(saved.item_type or saved.itemType)
    local infoType = tonumber(info.itemType or info.item_type)
    local savedGrade = tonumber(saved.item_grade or saved.itemGrade)
    local infoGrade = tonumber(info.itemGrade or info.item_grade)
    if savedType ~= nil and infoType ~= nil then
        if savedType ~= infoType then
            return false
        end
        if savedGrade ~= nil and infoGrade ~= nil and savedGrade ~= infoGrade then
            return false
        end
        return true
    end
    return false
end

local function findItemInBag(saved, usedSlots)
    local capacity = getBagCapacity()
    for index = 1, capacity do
        if usedSlots == nil or not usedSlots[index] then
            local item = getBagItem(index)
            if itemsMatch(saved, item) then
                return index, item
            end
        end
    end
    return nil, nil
end

local function getSavedSlotDef(saved)
    if type(saved) ~= "table" then
        return nil
    end
    local key = tostring(saved.slot_key or saved.slotKey or "")
    return SLOT_BY_KEY[key]
end

local function resolveDisplayItemInfo(saved)
    if type(saved) ~= "table" then
        return nil
    end

    local def = getSavedSlotDef(saved)
    if def ~= nil then
        local equipped = readEquippedItem(def)
        if itemsMatch(saved, equipped) then
            return equipped
        end
    end

    local _, bagItem = findItemInBag(saved)
    if type(bagItem) == "table" then
        return bagItem
    end

    return buildItemInfo(saved)
end

local function shorten(text, maxChars)
    text = tostring(text or "")
    local limit = tonumber(maxChars) or 18
    if string.len(text) <= limit then
        return text
    end
    if limit <= 3 then
        return string.sub(text, 1, limit)
    end
    return string.sub(text, 1, limit - 3) .. "..."
end

local function setStatus(text, isError)
    local label = GearLoadouts.editor ~= nil and GearLoadouts.editor.status or nil
    if label ~= nil then
        setText(label, text)
        if isError then
            setLabelColor(label, 1.0, 0.34, 0.22, 1)
        else
            setLabelColor(label, 0.94, 0.82, 0.52, 1)
        end
    end
    local barLabel = GearLoadouts.bar ~= nil and GearLoadouts.bar.status or nil
    if barLabel ~= nil then
        setText(barLabel, shorten(text, 64))
    end
end

local function logWarning(text)
    local message = "[Nuzi UI] " .. tostring(text or "")
    if api.Log ~= nil and api.Log.Err ~= nil then
        safeCall(function()
            api.Log:Err(message)
        end)
    end
end

local function getLoadoutSlots(loadout)
    if type(loadout) ~= "table" then
        return {}
    end
    if type(loadout.slots) ~= "table" then
        loadout.slots = {}
    end
    return loadout.slots
end

local function getIconSource(loadout)
    if type(loadout) ~= "table" then
        return nil
    end
    local slots = getLoadoutSlots(loadout)
    if type(loadout.icon_slot) == "string" and type(slots[loadout.icon_slot]) == "table" then
        return slots[loadout.icon_slot]
    end
    for _, def in ipairs(SLOT_DEFS) do
        if type(slots[def.key]) == "table" then
            return slots[def.key]
        end
    end
    return nil
end

local function setIconInfo(button, saved)
    if button == nil then
        return
    end
    local info = resolveDisplayItemInfo(saved)
    if button.SetItemInfo ~= nil then
        safeCall(function()
            button:SetItemInfo(info)
        end)
    elseif info ~= nil and info.path ~= nil and button.SetTexture ~= nil then
        safeCall(function()
            button:SetTexture(info.path)
        end)
    end
end

local function collectLoadoutIssues(loadout)
    local issues = {}
    if type(loadout) ~= "table" then
        return issues
    end
    local slots = getLoadoutSlots(loadout)
    for _, def in ipairs(SLOT_DEFS) do
        local saved = slots[def.key]
        if type(saved) == "table" then
            local equipped = readEquippedItem(def)
            local equippedMatches = itemsMatch(saved, equipped)
            local bagSlot = nil
            if not equippedMatches then
                bagSlot = findItemInBag(saved)
            end
            if not equippedMatches then
                if bagSlot == nil then
                    local wearing = equipped ~= nil and trim(equipped.name) or "empty"
                    issues[#issues + 1] = {
                        kind = "missing",
                        text = string.format("%s missing %s; wearing %s.", def.label, trim(saved.name), wearing)
                    }
                elseif equipped ~= nil then
                    issues[#issues + 1] = {
                        kind = "mismatch",
                        text = string.format("%s has %s instead of %s.", def.label, trim(equipped.name), trim(saved.name))
                    }
                end
            end
        end
    end
    return issues
end

local function showIssues(loadout, prefix)
    local issues = collectLoadoutIssues(loadout)
    if #issues == 0 then
        setStatus((prefix or "Loadout") .. " matches equipped gear.", false)
        return false
    end
    local first = issues[1].text
    setStatus(first, true)
    logWarning(first)
    for i = 2, #issues do
        logWarning(issues[i].text)
    end
    return true
end

local refreshBar
local refreshEditor

local function refreshAutoControls()
    local editor = GearLoadouts.editor
    if editor == nil then
        return
    end
    local loadout = getSelectedLoadout(GearLoadouts.settings)
    local trigger = getAutoTriggerValue(loadout)
    GearLoadouts.refreshing_auto_controls = true
    if editor.auto_dropdown ~= nil then
        editor.auto_dropdown.dropdownItem = getAutoTriggerLabels()
        if editor.auto_dropdown.Select ~= nil then
            safeCall(function()
                editor.auto_dropdown:Select(getAutoTriggerIndex(trigger))
            end)
        end
    end
    setEditText(editor.auto_value_edit, loadout ~= nil and loadout.auto_trigger_value or "")
    setText(editor.auto_hint, getAutoTriggerHint(trigger))
    GearLoadouts.refreshing_auto_controls = false
end

local function saveAutoTrigger(index)
    if GearLoadouts.refreshing_auto_controls then
        return
    end
    local loadout = getSelectedLoadout(GearLoadouts.settings)
    if loadout == nil then
        return
    end
    local option = AUTO_TRIGGER_OPTIONS[tonumber(index) or 1] or AUTO_TRIGGER_OPTIONS[1]
    loadout.auto_trigger = option.value
    GearLoadouts.auto_active_loadout_id = nil
    GearLoadouts.auto_pending_loadout_id = nil
    saveSettings(GearLoadouts.settings)
    if GearLoadouts.editor ~= nil then
        setText(GearLoadouts.editor.auto_hint, getAutoTriggerHint(option.value))
    end
    if option.value == AUTO_TRIGGER_SWIMMING then
        setStatus(AUTO_SWIMMING_HINT, false)
    else
        setStatus("Auto trigger set to " .. option.label .. ".", false)
    end
end

local function saveAutoTriggerValue()
    if GearLoadouts.refreshing_auto_controls then
        return
    end
    local loadout = getSelectedLoadout(GearLoadouts.settings)
    if loadout == nil or GearLoadouts.editor == nil then
        return
    end
    loadout.auto_trigger_value = trim(getEditText(GearLoadouts.editor.auto_value_edit))
    GearLoadouts.auto_active_loadout_id = nil
    GearLoadouts.auto_pending_loadout_id = nil
    saveSettings(GearLoadouts.settings)
end

local function applyLoadoutTitle(loadout)
    if type(loadout) ~= "table" or loadout.title_type == nil then
        return false
    end
    if api.Player == nil or api.Player.ChangeAppellation == nil then
        return false
    end
    local titleType = tonumber(loadout.title_type)
    if titleType == nil then
        return false
    end
    titleType = math.floor(titleType + 0.5)
    local currentType = readCurrentAppellationType()
    if currentType ~= nil and currentType == titleType then
        return false
    end
    return safeCall(function()
        return api.Player:ChangeAppellation(titleType)
    end) and true or false
end

local function equipLoadout(loadout)
    if type(loadout) ~= "table" then
        return
    end
    if GearLoadouts.settings == nil then
        return
    end

    showIssues(loadout, tostring(loadout.name or "Loadout"))
    local titleChanged = applyLoadoutTitle(loadout)

    local usedSlots = {}
    local queue = {}
    local slots = getLoadoutSlots(loadout)
    for _, def in ipairs(SLOT_DEFS) do
        local saved = slots[def.key]
        if type(saved) == "table" then
            local equipped = readEquippedItem(def)
            if not itemsMatch(saved, equipped) then
                local bagSlot = nil
                bagSlot = findItemInBag(saved, usedSlots)
                if bagSlot ~= nil then
                    usedSlots[bagSlot] = true
                    queue[#queue + 1] = {
                        bag_slot = bagSlot,
                        is_aux = def.is_aux and true or false,
                        name = trim(saved.name),
                        slot_label = def.label
                    }
                end
            end
        end
    end

    GearLoadouts.equip_queue = queue
    GearLoadouts.equip_delay_ms = 250
    GearLoadouts.equip_target_loadout_id = loadout.id
    GearLoadouts.pending_check_ms = nil
    GearLoadouts.pending_check_loadout_id = nil

    if #queue == 0 then
        GearLoadouts.equip_target_loadout_id = nil
        if titleChanged then
            setStatus("Applied title for " .. tostring(loadout.name or "loadout") .. ".", false)
        else
            setStatus("No gear to equip for " .. tostring(loadout.name or "loadout") .. ".", false)
        end
        return
    end
    setStatus("Equipping " .. tostring(loadout.name or "loadout") .. "...", false)
end

local function processEquipQueue(dt)
    if #GearLoadouts.equip_queue == 0 then
        return
    end
    GearLoadouts.equip_delay_ms = (tonumber(GearLoadouts.equip_delay_ms) or 0) + (tonumber(dt) or 0)
    if GearLoadouts.equip_delay_ms < 250 then
        return
    end
    GearLoadouts.equip_delay_ms = 0

    local nextItem = table.remove(GearLoadouts.equip_queue, 1)
    if nextItem ~= nil and api.Bag ~= nil and api.Bag.EquipBagItem ~= nil then
        safeCall(function()
            api.Bag:EquipBagItem(nextItem.bag_slot, nextItem.is_aux and true or false)
        end)
        setStatus("Equipping " .. tostring(nextItem.slot_label or "") .. ": " .. tostring(nextItem.name or ""), false)
    end

    if #GearLoadouts.equip_queue == 0 then
        GearLoadouts.pending_check_ms = 700
        GearLoadouts.pending_check_loadout_id = GearLoadouts.equip_target_loadout_id
        GearLoadouts.equip_target_loadout_id = nil
        setStatus("Equip requests sent.", false)
    end
end

local function readPlayerAuras()
    local buffs = {}
    local debuffs = {}
    if api.Unit == nil then
        return buffs, debuffs
    end
    if api.Unit.UnitBuffCount ~= nil and api.Unit.UnitBuff ~= nil then
        local count = tonumber(safeCall(function()
            return api.Unit:UnitBuffCount("player")
        end)) or 0
        for index = 1, count do
            local buff = safeCall(function()
                return api.Unit:UnitBuff("player", index)
            end)
            if type(buff) == "table" then
                buffs[#buffs + 1] = buff
            end
        end
    end
    if api.Unit.UnitDeBuffCount ~= nil and api.Unit.UnitDeBuff ~= nil then
        local count = tonumber(safeCall(function()
            return api.Unit:UnitDeBuffCount("player")
        end)) or 0
        for index = 1, count do
            local debuff = safeCall(function()
                return api.Unit:UnitDeBuff("player", index)
            end)
            if type(debuff) == "table" then
                debuffs[#debuffs + 1] = debuff
            end
        end
    end
    return buffs, debuffs
end

local function getAuraId(aura)
    if type(aura) ~= "table" then
        return nil
    end
    return tonumber(aura.buff_id or aura.buffId or aura.id or aura.spellId or aura.spell_id)
end

local function getAuraTooltipName(id)
    id = tonumber(id)
    if id == nil then
        return ""
    end
    if GearLoadouts.auto_buff_name_cache[id] ~= nil then
        return GearLoadouts.auto_buff_name_cache[id] or ""
    end
    if api.Ability == nil or api.Ability.GetBuffTooltip == nil then
        return ""
    end
    local tooltip = safeCall(function()
        return api.Ability:GetBuffTooltip(id, 1)
    end)
    local name = ""
    if type(tooltip) == "table" then
        for _, key in ipairs({ "name", "buffName", "buff_name", "title", "skillName", "skill_name" }) do
            name = trim(tooltip[key])
            if name ~= "" then
                break
            end
        end
    elseif type(tooltip) == "string" then
        name = trim(tooltip)
    end
    name = string.lower(name)
    GearLoadouts.auto_buff_name_cache[id] = name ~= "" and name or false
    return name
end

local function getAuraName(aura)
    if type(aura) ~= "table" then
        return ""
    end
    for _, key in ipairs({ "name", "buff_name", "buffName", "skill_name", "skillName", "title" }) do
        local value = trim(aura[key])
        if value ~= "" then
            return string.lower(value)
        end
    end
    return getAuraTooltipName(getAuraId(aura))
end

local function auraMatches(aura, query)
    local text = string.lower(trim(query))
    if text == "" then
        return false
    end
    local queryId = tonumber(text)
    local auraId = getAuraId(aura)
    if queryId ~= nil and auraId ~= nil and queryId == auraId then
        return true
    end
    local auraName = getAuraName(aura)
    return auraName ~= "" and string.find(auraName, text, 1, true) ~= nil
end

local function anyAuraMatches(buffs, debuffs, query)
    for _, aura in ipairs(buffs or {}) do
        if auraMatches(aura, query) then
            return true
        end
    end
    for _, aura in ipairs(debuffs or {}) do
        if auraMatches(aura, query) then
            return true
        end
    end
    return false
end

local function refreshCurrentZoneName()
    GearLoadouts.auto_zone_ms = (tonumber(GearLoadouts.auto_zone_ms) or 0) + AUTO_UPDATE_INTERVAL_MS
    if GearLoadouts.auto_zone_ms < 1000 and trim(GearLoadouts.auto_zone_name) ~= "" then
        return GearLoadouts.auto_zone_name
    end
    GearLoadouts.auto_zone_ms = 0
    local zoneName = ""
    if api.Unit ~= nil and api.Unit.GetCurrentZoneGroup ~= nil and api.Zone ~= nil and api.Zone.GetZoneStateInfoByZoneId ~= nil then
        local currentZoneGroup = safeCall(function()
            return api.Unit:GetCurrentZoneGroup()
        end)
        local candidates = {}
        if type(currentZoneGroup) == "number" then
            candidates[#candidates + 1] = currentZoneGroup
        elseif type(currentZoneGroup) == "table" then
            for _, value in ipairs(currentZoneGroup) do
                local zoneId = tonumber(value)
                if zoneId ~= nil and zoneId > 0 then
                    candidates[#candidates + 1] = zoneId
                end
            end
        end
        for _, zoneId in ipairs(candidates) do
            local zoneInfo = safeCall(function()
                return api.Zone:GetZoneStateInfoByZoneId(zoneId)
            end)
            if type(zoneInfo) == "table" and trim(zoneInfo.zoneName) ~= "" then
                zoneName = trim(zoneInfo.zoneName)
                if zoneInfo.isCurrentZone == true then
                    break
                end
            end
        end
    end
    GearLoadouts.auto_zone_name = zoneName
    return zoneName
end

local function isSwimmingZoneBlocked()
    local zoneName = string.lower(refreshCurrentZoneName())
    if zoneName == "" then
        return false
    end
    for _, blocked in ipairs(AUTO_SWIMMING_BLOCKED_ZONES) do
        if string.find(zoneName, blocked, 1, true) ~= nil then
            return true
        end
    end
    return false
end

local function isSwimmingTriggerActive(buffs, debuffs)
    if isSwimmingZoneBlocked() then
        return false
    end
    local hasMove = false
    local hasRoughSea = false
    for _, aura in ipairs(buffs or {}) do
        local id = getAuraId(aura)
        local name = getAuraName(aura)
        if id == DASH_ID or id == STEALTH_ID
            or string.find(name, "dash", 1, true) ~= nil
            or string.find(name, "stealth", 1, true) ~= nil then
            hasMove = true
        end
        if id == ROUGH_SEA_ID or string.find(name, "rough sea winds", 1, true) ~= nil then
            hasRoughSea = true
        end
    end
    if not hasRoughSea then
        for _, aura in ipairs(debuffs or {}) do
            local id = getAuraId(aura)
            local name = getAuraName(aura)
            if id == ROUGH_SEA_ID or string.find(name, "rough sea winds", 1, true) ~= nil then
                hasRoughSea = true
                break
            end
        end
    end
    return hasMove and hasRoughSea
end

local function isLoadoutAutoTriggered(loadout, buffs, debuffs)
    local trigger = getAutoTriggerValue(loadout)
    if trigger == AUTO_TRIGGER_SWIMMING then
        return isSwimmingTriggerActive(buffs, debuffs)
    elseif trigger == AUTO_TRIGGER_CAPTAIN then
        return anyAuraMatches(buffs, debuffs, "captain")
    elseif trigger == AUTO_TRIGGER_BUFF_ACTIVE then
        return anyAuraMatches(buffs, debuffs, loadout.auto_trigger_value)
    end
    return false
end

local function isPlayerInCombat()
    if api.Unit == nil or api.Unit.UnitCombatState == nil then
        return false
    end
    local state = safeCall(function()
        return api.Unit:UnitCombatState("player")
    end)
    if state == true then
        return true
    end
    if type(state) == "number" then
        return state ~= 0
    end
    if type(state) == "string" then
        local value = string.lower(trim(state))
        return value ~= "" and value ~= "0" and value ~= "false"
    end
    return false
end

local function processAutoTriggers(dt)
    GearLoadouts.auto_accum_ms = (tonumber(GearLoadouts.auto_accum_ms) or 0) + (tonumber(dt) or 0)
    if GearLoadouts.auto_accum_ms < AUTO_UPDATE_INTERVAL_MS then
        return
    end
    GearLoadouts.auto_accum_ms = 0
    if #GearLoadouts.equip_queue > 0 or GearLoadouts.pending_check_ms ~= nil then
        return
    end

    local profile = getProfile(GearLoadouts.settings)
    if type(profile) ~= "table" or type(profile.loadouts) ~= "table" then
        return
    end
    local buffs, debuffs = readPlayerAuras()
    local activeLoadout = nil
    for _, loadout in ipairs(profile.loadouts) do
        if isLoadoutAutoTriggered(loadout, buffs, debuffs) then
            activeLoadout = loadout
            break
        end
    end

    if activeLoadout == nil then
        GearLoadouts.auto_active_loadout_id = nil
        GearLoadouts.auto_pending_loadout_id = nil
        return
    end

    local activeId = tostring(activeLoadout.id or "")
    if activeId == "" or GearLoadouts.auto_active_loadout_id == activeId then
        return
    end

    if isPlayerInCombat() then
        if GearLoadouts.auto_pending_loadout_id ~= activeId then
            GearLoadouts.auto_pending_loadout_id = activeId
            setStatus("Auto trigger waiting for combat to end: " .. tostring(activeLoadout.name or "loadout") .. ".", true)
        end
        return
    end

    GearLoadouts.auto_active_loadout_id = activeId
    GearLoadouts.auto_pending_loadout_id = nil
    setStatus("Auto trigger: " .. getAutoTriggerLabel(getAutoTriggerValue(activeLoadout)) .. ".", false)
    equipLoadout(activeLoadout)
end

local function isShiftDown()
    if api.Input ~= nil and api.Input.IsShiftKeyDown ~= nil then
        return safeCall(function()
            return api.Input:IsShiftKeyDown()
        end) and true or false
    end
    return false
end

local function shouldRequireShiftDrag()
    return type(GearLoadouts.settings) == "table" and GearLoadouts.settings.drag_requires_shift == true
end

local function syncMoveInteraction(window, cfg, lockKey)
    if window == nil then
        return
    end
    local interactive = window.__nuzi_loadouts_dragging
        or (type(cfg) == "table" and not cfg[lockKey] and (not shouldRequireShiftDrag() or isShiftDown()))
    setWidgetClickable(window, true)
    setWidgetDragEnabled(window, interactive)
end

local function attachMoveHandlers(window, cfgKeyX, cfgKeyY, lockKey)
    if window == nil then
        return
    end
    safeCall(function()
        if window.RegisterForDrag ~= nil then
            window:RegisterForDrag("LeftButton")
        end
    end)
    if window.SetHandler ~= nil then
        window:SetHandler("OnDragStart", function()
            local cfg = ensureSettings(GearLoadouts.settings)
            if cfg == nil or cfg[lockKey] then
                syncMoveInteraction(window, cfg, lockKey)
                return
            end
            if not shouldRequireShiftDrag() or isShiftDown() then
                window.__nuzi_loadouts_dragging = true
                syncMoveInteraction(window, cfg, lockKey)
                safeCall(function()
                    window:StartMoving()
                end)
                if api.Cursor ~= nil and api.Cursor.ClearCursor ~= nil and CURSOR_PATH ~= nil and CURSOR_PATH.MOVE ~= nil then
                    safeCall(function()
                        api.Cursor:ClearCursor()
                        api.Cursor:SetCursorImage(CURSOR_PATH.MOVE, 0, 0)
                    end)
                end
            end
        end)
        window:SetHandler("OnDragStop", function()
            safeCall(function()
                window:StopMovingOrSizing()
            end)
            window.__nuzi_loadouts_dragging = false
            local cfg = ensureSettings(GearLoadouts.settings)
            if cfg ~= nil then
                local x, y = nil, nil
                if Layout ~= nil and type(Layout.ReadScreenOffset) == "function" then
                    x, y = Layout.ReadScreenOffset(window)
                elseif window.GetOffset ~= nil then
                    x, y = safeCall(function()
                        return window:GetOffset()
                    end)
                end
                if tonumber(x) ~= nil and tonumber(y) ~= nil then
                    cfg[cfgKeyX] = math.floor(tonumber(x) + 0.5)
                    cfg[cfgKeyY] = math.floor(tonumber(y) + 0.5)
                    saveSettings(GearLoadouts.settings)
                end
            end
            if api.Cursor ~= nil and api.Cursor.ClearCursor ~= nil then
                safeCall(function()
                    api.Cursor:ClearCursor()
                end)
            end
            syncMoveInteraction(window, cfg, lockKey)
        end)
    end
    syncMoveInteraction(window, ensureSettings(GearLoadouts.settings), lockKey)
end

local function refreshLoadoutDropdown()
    if GearLoadouts.editor == nil or GearLoadouts.editor.dropdown == nil then
        return
    end
    local loadout, index, profile = getSelectedLoadout(GearLoadouts.settings)
    local names = {}
    if type(profile) == "table" then
        for _, entry in ipairs(profile.loadouts) do
            names[#names + 1] = tostring(entry.name or "Loadout")
        end
    end
    local dropdown = GearLoadouts.editor.dropdown
    dropdown.dropdownItem = names
    GearLoadouts.refreshing_dropdown = true
    if #names > 0 and dropdown.Select ~= nil then
        safeCall(function()
            dropdown:Select(index or 1)
        end)
    elseif dropdown.ClearSelection ~= nil then
        safeCall(function()
            dropdown:ClearSelection()
        end)
    end
    GearLoadouts.refreshing_dropdown = false
    setEditText(GearLoadouts.editor.name_edit, loadout ~= nil and loadout.name or "")
end

local function setSelectedLoadoutIndex(index)
    local profile = getProfile(GearLoadouts.settings)
    if profile == nil then
        return
    end
    local idx = tonumber(index)
    if idx == nil or idx < 1 or idx > #profile.loadouts then
        return
    end
    local loadout = profile.loadouts[idx]
    profile.selected_id = loadout.id
    saveSettings(GearLoadouts.settings)
    refreshEditor()
    refreshBar()
end

local function saveCurrentName()
    local loadout = getSelectedLoadout(GearLoadouts.settings)
    if loadout == nil then
        loadout = createNewLoadout(GearLoadouts.settings)
    end
    if loadout == nil then
        return
    end
    local name = trim(getEditText(GearLoadouts.editor ~= nil and GearLoadouts.editor.name_edit or nil))
    if name == "" then
        name = tostring(loadout.name or "Loadout")
    end
    loadout.name = name
    saveSettings(GearLoadouts.settings)
    setStatus("Saved " .. name .. ".", false)
    refreshEditor()
    refreshBar()
end

local function saveEquippedToLoadout()
    local loadout = getSelectedLoadout(GearLoadouts.settings)
    if loadout == nil then
        loadout = createNewLoadout(GearLoadouts.settings)
    end
    if loadout == nil then
        return
    end
    local name = trim(getEditText(GearLoadouts.editor ~= nil and GearLoadouts.editor.name_edit or nil))
    if name ~= "" then
        loadout.name = name
    end
    local slots = getLoadoutSlots(loadout)
    for _, def in ipairs(SLOT_DEFS) do
        local item = readEquippedItem(def)
        if item ~= nil then
            slots[def.key] = itemDescriptor(def, item)
        end
    end
    local titleType = readCurrentAppellationType()
    if titleType ~= nil then
        loadout.title_type = titleType
    end
    saveSettings(GearLoadouts.settings)
    setStatus("Saved equipped gear to " .. tostring(loadout.name or "loadout") .. ".", false)
    refreshEditor()
    refreshBar()
end

local function deleteSelectedLoadout()
    local loadout, index, profile = getSelectedLoadout(GearLoadouts.settings)
    if loadout == nil or profile == nil or index == nil then
        return
    end
    local name = tostring(loadout.name or "Loadout")
    table.remove(profile.loadouts, index)
    profile.selected_id = profile.loadouts[math.min(index, #profile.loadouts)] ~= nil and profile.loadouts[math.min(index, #profile.loadouts)].id or nil
    GearLoadouts.auto_active_loadout_id = nil
    GearLoadouts.auto_pending_loadout_id = nil
    saveSettings(GearLoadouts.settings)
    setStatus("Deleted " .. name .. ".", false)
    refreshEditor()
    refreshBar()
end

local function setLoadoutIconFromSelection()
    local loadout = getSelectedLoadout(GearLoadouts.settings)
    if loadout == nil then
        return
    end
    local key = GearLoadouts.selected_slot_key
    local slots = getLoadoutSlots(loadout)
    if key == nil or type(slots[key]) ~= "table" then
        setStatus("Select a filled slot first.", true)
        return
    end
    loadout.icon_slot = key
    saveSettings(GearLoadouts.settings)
    setStatus("Icon set from " .. tostring(SLOT_BY_KEY[key] and SLOT_BY_KEY[key].label or "slot") .. ".", false)
    refreshBar()
    refreshEditor()
end

local function captureCursorItem(slotKey)
    local def = SLOT_BY_KEY[slotKey]
    if def == nil then
        return false
    end
    local index = getCursorBagIndex()
    if index == nil then
        return false
    end
    local item = getBagItem(index)
    if item == nil then
        return false
    end
    local loadout = getSelectedLoadout(GearLoadouts.settings)
    if loadout == nil then
        loadout = createNewLoadout(GearLoadouts.settings)
    end
    if loadout == nil then
        return false
    end
    local slots = getLoadoutSlots(loadout)
    slots[slotKey] = itemDescriptor(def, item)
    GearLoadouts.selected_slot_key = slotKey
    if loadout.icon_slot == nil then
        loadout.icon_slot = slotKey
    end
    saveSettings(GearLoadouts.settings)
    clearCursor()
    setStatus(def.label .. ": " .. trim(item.name), false)
    refreshEditor()
    refreshBar()
    return true
end

local function selectOrClearSlot(slotKey, arg)
    local loadout = getSelectedLoadout(GearLoadouts.settings)
    if loadout == nil then
        return
    end
    if arg == "RightButton" then
        local slots = getLoadoutSlots(loadout)
        slots[slotKey] = nil
        if loadout.icon_slot == slotKey then
            loadout.icon_slot = nil
        end
        saveSettings(GearLoadouts.settings)
        GearLoadouts.selected_slot_key = nil
        setStatus("Cleared " .. tostring(SLOT_BY_KEY[slotKey] and SLOT_BY_KEY[slotKey].label or "slot") .. ".", false)
        refreshEditor()
        refreshBar()
        return
    end
    if captureCursorItem(slotKey) then
        return
    end
    GearLoadouts.selected_slot_key = slotKey
    local saved = getLoadoutSlots(loadout)[slotKey]
    if type(saved) == "table" then
        setStatus((SLOT_BY_KEY[slotKey] and SLOT_BY_KEY[slotKey].label or "Slot") .. ": " .. trim(saved.name), false)
    else
        setStatus((SLOT_BY_KEY[slotKey] and SLOT_BY_KEY[slotKey].label or "Slot") .. " selected.", false)
    end
    refreshEditor()
end

local function createSlot(parent, def, index)
    local button = createIconButton(parent, "nuziGearSlot" .. tostring(index))
    if button == nil then
        return nil
    end
    safeCall(function()
        button:AddAnchor("TOPLEFT", parent, def.x, def.y)
        button:SetExtent(42, 42)
        button:Show(true)
    end)
    local label = createLabel(button, "nuziGearSlotLabel" .. tostring(index), def.short, 1, 12, 40, 16, 9, ALIGN ~= nil and ALIGN.CENTER or nil)
    if label ~= nil then
        setLabelColor(label, 0.84, 0.74, 0.52, 1)
    end
    local outline = nil
    if parent.CreateColorDrawable ~= nil then
        outline = safeCall(function()
            return parent:CreateColorDrawable(0.95, 0.66, 0.24, 0, "overlay")
        end)
        if outline ~= nil then
            safeCall(function()
                outline:AddAnchor("TOPLEFT", button, -2, -2)
                outline:SetExtent(46, 2)
                outline:Show(false)
            end)
        end
    end

    if button.SetItemInfo ~= nil then
        button.OnClickProc = function(_, arg)
            selectOrClearSlot(def.key, arg)
        end
    elseif button.SetHandler ~= nil then
        button:SetHandler("OnClick", function(_, arg)
            selectOrClearSlot(def.key, arg)
        end)
    end
    if button.SetHandler ~= nil then
        button:SetHandler("OnDragReceive", function()
            captureCursorItem(def.key)
        end)
    end
    return {
        button = button,
        label = label,
        outline = outline,
        def = def
    }
end

local function createEditor(settings)
    local cfg = ensureSettings(settings)
    if cfg == nil then
        return
    end
    if GearLoadouts.editor ~= nil then
        return
    end

    local window = createWindow("nuziGearLoadoutEditor")
    if window == nil then
        return
    end
    GearLoadouts.editor = window
    addPanelBackground(window, 0.92)
    safeCall(function()
        window:SetExtent(520, 640)
    end)
    anchorTopLeft(window, cfg.editor_pos_x, cfg.editor_pos_y)
    attachMoveHandlers(window, "editor_pos_x", "editor_pos_y", "lock_editor")

    local title = createLabel(window, "nuziGearEditorTitle", "Gear Loadouts", 16, 12, 330, 22, 18)
    if title ~= nil then
        setLabelColor(title, 0.98, 0.84, 0.52, 1)
    end

    local closeBtn = createButton(window, "nuziGearEditorClose", "", 484, 10, 24, 24)
    applyButtonSkin(closeBtn, BUTTON_BASIC ~= nil and (BUTTON_BASIC.WINDOW_CLOSE or BUTTON_BASIC.DEFAULT) or nil)
    if closeBtn ~= nil and closeBtn.SetHandler ~= nil then
        closeBtn:SetHandler("OnClick", function()
            showWidget(GearLoadouts.editor, false)
        end)
    end

    window.dropdown = api.Interface ~= nil and api.Interface.CreateComboBox ~= nil and safeCall(function()
        return api.Interface:CreateComboBox(window)
    end) or nil
    if window.dropdown ~= nil then
        safeCall(function()
            window.dropdown:SetExtent(210, 26)
            window.dropdown:AddAnchor("TOPLEFT", window, 16, 48)
        end)
        function window.dropdown:SelectedProc()
            if GearLoadouts.refreshing_dropdown then
                return
            end
            setSelectedLoadoutIndex(self:GetSelectedIndex())
        end
    end

    window.name_edit = createEdit(window, "nuziGearLoadoutName", 236, 48, 180, 26, "Name")
    local newBtn = createButton(window, "nuziGearNew", "New", 426, 48, 78, 24)
    local saveBtn = createButton(window, "nuziGearSave", "Save", 16, 82, 78, 24)
    local equippedBtn = createButton(window, "nuziGearFromEquipped", "Equipped", 104, 82, 104, 24)
    local iconBtn = createButton(window, "nuziGearIcon", "Set Icon", 218, 82, 96, 24)
    local checkBtn = createButton(window, "nuziGearCheck", "Check", 324, 82, 80, 24)
    local deleteBtn = createButton(window, "nuziGearDelete", "Delete", 414, 82, 90, 24)

    if newBtn ~= nil and newBtn.SetHandler ~= nil then
        newBtn:SetHandler("OnClick", function()
            local loadout = createNewLoadout(GearLoadouts.settings)
            setStatus("Created " .. tostring(loadout ~= nil and loadout.name or "loadout") .. ".", false)
            refreshEditor()
            refreshBar()
        end)
    end
    if saveBtn ~= nil and saveBtn.SetHandler ~= nil then
        saveBtn:SetHandler("OnClick", saveCurrentName)
    end
    if equippedBtn ~= nil and equippedBtn.SetHandler ~= nil then
        equippedBtn:SetHandler("OnClick", saveEquippedToLoadout)
    end
    if iconBtn ~= nil and iconBtn.SetHandler ~= nil then
        iconBtn:SetHandler("OnClick", setLoadoutIconFromSelection)
    end
    if checkBtn ~= nil and checkBtn.SetHandler ~= nil then
        checkBtn:SetHandler("OnClick", function()
            local loadout = getSelectedLoadout(GearLoadouts.settings)
            if loadout ~= nil then
                showIssues(loadout, tostring(loadout.name or "Loadout"))
            end
        end)
    end
    if deleteBtn ~= nil and deleteBtn.SetHandler ~= nil then
        deleteBtn:SetHandler("OnClick", deleteSelectedLoadout)
    end

    createLabel(window, "nuziGearAutoLabel", "Auto", 16, 118, 42, 20, 12)
    window.auto_dropdown = createComboBox(window, getAutoTriggerLabels(), 58, 114, 136, 26)
    if window.auto_dropdown ~= nil then
        function window.auto_dropdown:SelectedProc()
            saveAutoTrigger(self:GetSelectedIndex())
        end
    end
    createLabel(window, "nuziGearAutoValueLabel", "Buff/ID", 206, 118, 54, 20, 12)
    window.auto_value_edit = createEdit(window, "nuziGearAutoValue", 264, 114, 116, 26, "name or ID")
    if window.auto_value_edit ~= nil and window.auto_value_edit.SetHandler ~= nil then
        window.auto_value_edit:SetHandler("OnTextChanged", saveAutoTriggerValue)
    end
    window.auto_hint = createLabel(window, "nuziGearAutoHint", AUTO_DEFAULT_HINT, 16, 144, 488, 18, 11)
    if window.auto_hint ~= nil then
        setLabelColor(window.auto_hint, 0.92, 0.62, 0.28, 1)
    end

    local slotPanel = safeCall(function()
        return window:CreateChildWidget("emptywidget", "nuziGearSlotPanel", 0, true)
    end)
    if slotPanel == nil then
        return
    end
    window.slot_panel = slotPanel
    safeCall(function()
        slotPanel:AddAnchor("TOPLEFT", window, 61, 166)
        slotPanel:SetExtent(398, 430)
        slotPanel:Show(true)
    end)
    if slotPanel.CreateColorDrawable ~= nil then
        local center = safeCall(function()
            return slotPanel:CreateColorDrawable(0.36, 0.27, 0.15, 0.26, "background")
        end)
        if center ~= nil then
            safeCall(function()
                center:AddAnchor("TOPLEFT", slotPanel, 139, 30)
                center:SetExtent(118, 340)
            end)
        end
        local centerLine = safeCall(function()
            return slotPanel:CreateColorDrawable(0.95, 0.75, 0.34, 0.18, "artwork")
        end)
        if centerLine ~= nil then
            safeCall(function()
                centerLine:AddAnchor("TOPLEFT", slotPanel, 196, 40)
                centerLine:SetExtent(2, 320)
            end)
        end
    end

    GearLoadouts.slot_widgets = {}
    for index, def in ipairs(SLOT_DEFS) do
        GearLoadouts.slot_widgets[def.key] = createSlot(slotPanel, def, index)
    end

    window.status = createLabel(window, "nuziGearStatus", "", 16, 608, 488, 20, 12)
    setStatus("", false)
    showWidget(window, false)
end

refreshEditor = function()
    if GearLoadouts.editor == nil then
        return
    end
    refreshLoadoutDropdown()
    refreshAutoControls()
    local loadout = getSelectedLoadout(GearLoadouts.settings)
    local slots = getLoadoutSlots(loadout)
    for _, def in ipairs(SLOT_DEFS) do
        local widgets = GearLoadouts.slot_widgets[def.key]
        local saved = slots[def.key]
        if widgets ~= nil and widgets.button ~= nil then
            if type(saved) == "table" then
                setIconInfo(widgets.button, saved)
                showWidget(widgets.label, false)
            else
                if widgets.button.SetItemInfo ~= nil then
                    safeCall(function()
                        widgets.button:SetItemInfo(nil)
                    end)
                end
                showWidget(widgets.label, true)
            end
            local selected = GearLoadouts.selected_slot_key == def.key
            showWidget(widgets.outline, selected)
        end
    end
end

local function createBarButton(parent, loadout, index, x, cfg)
    local showIcons = cfg.show_icons and true or false
    local buttonSize = clampInt(cfg.button_size, 28, 58, 38)
    local buttonWidth = clampInt(cfg.button_width, 80, 220, 126)
    local buttonGap = 10
    local button = nil
    if showIcons then
        button = createIconButton(parent, "nuziGearBarIcon" .. tostring(index))
        if button ~= nil then
            safeCall(function()
                button:AddAnchor("TOPLEFT", parent, x, 8)
                button:SetExtent(buttonSize, buttonSize)
                if button.SetText ~= nil then
                    button:SetText("")
                end
                button:Show(true)
            end)
            setIconInfo(button, getIconSource(loadout))
            if button.SetItemInfo ~= nil then
                button.OnClickProc = function()
                    equipLoadout(loadout)
                end
            elseif button.SetHandler ~= nil then
                button:SetHandler("OnClick", function()
                    equipLoadout(loadout)
                end)
            end
        end
        return button, x + math.max(buttonSize, 42) + buttonGap
    end

    button = createButton(parent, "nuziGearBarButton" .. tostring(index), shorten(loadout.name, 18), x, 8, buttonWidth, 28)
    if button ~= nil and button.SetHandler ~= nil then
        button:SetHandler("OnClick", function()
            equipLoadout(loadout)
        end)
    end
    return button, x + buttonWidth + buttonGap
end

refreshBar = function()
    if GearLoadouts.settings == nil then
        return
    end
    local cfg = ensureSettings(GearLoadouts.settings)
    if cfg == nil then
        return
    end
    if GearLoadouts.bar == nil then
        return
    end
    for _, button in ipairs(GearLoadouts.bar_buttons) do
        freeWidget(button)
    end
    GearLoadouts.bar_buttons = {}

    local profile = getProfile(GearLoadouts.settings)
    local x = 8
    local barHeight = cfg.show_icons and (clampInt(cfg.button_size, 28, 58, 38) + 16) or 60
    if profile ~= nil and #profile.loadouts > 0 then
        for index, loadout in ipairs(profile.loadouts) do
            local button = nil
            button, x = createBarButton(GearLoadouts.bar, loadout, index, x, cfg)
            if button ~= nil then
                GearLoadouts.bar_buttons[#GearLoadouts.bar_buttons + 1] = button
            end
        end
        setText(GearLoadouts.bar.empty_label, "")
    else
        setText(GearLoadouts.bar.empty_label, "Loadouts")
        x = 96
    end
    local width = math.max(170, x + 8)
    safeCall(function()
        GearLoadouts.bar:SetExtent(width, barHeight)
        if GearLoadouts.bar.status ~= nil then
            GearLoadouts.bar.status:SetExtent(math.max(80, width - 16), 16)
            GearLoadouts.bar.status:RemoveAllAnchors()
            GearLoadouts.bar.status:AddAnchor("BOTTOMLEFT", GearLoadouts.bar, 8, -6)
            GearLoadouts.bar.status:Show(not (cfg.show_icons and true or false))
        end
    end)
end

local function createBar(settings)
    local cfg = ensureSettings(settings)
    if cfg == nil or GearLoadouts.bar ~= nil then
        return
    end
    local bar = createWindow("nuziGearLoadoutBar")
    if bar == nil then
        return
    end
    GearLoadouts.bar = bar
    addPanelBackground(bar, 0.78)
    safeCall(function()
        bar:SetExtent(170, 44)
    end)
    anchorTopLeft(bar, cfg.bar_pos_x, cfg.bar_pos_y)
    attachMoveHandlers(bar, "bar_pos_x", "bar_pos_y", "lock_bar")

    bar.empty_label = createLabel(bar, "nuziGearBarEmpty", "", 8, 14, 100, 18, 13)
    bar.status = createLabel(bar, "nuziGearBarStatus", "", 8, 28, 112, 14, 10)
    if bar.status ~= nil then
        setLabelColor(bar.status, 0.94, 0.82, 0.52, 1)
    end
    refreshBar()
end

local function applyVisibility()
    local cfg = ensureSettings(GearLoadouts.settings)
    local visible = GearLoadouts.enabled and cfg ~= nil and cfg.enabled
    showWidget(GearLoadouts.bar, visible)
    if not visible then
        showWidget(GearLoadouts.editor, false)
        setWidgetDragEnabled(GearLoadouts.bar, false)
        setWidgetDragEnabled(GearLoadouts.editor, false)
    end
end

function GearLoadouts.ToggleEditor(settings)
    if settings ~= nil then
        GearLoadouts.settings = settings
    end
    if GearLoadouts.settings == nil then
        return
    end
    ensureSettings(GearLoadouts.settings)
    createEditor(GearLoadouts.settings)
    if GearLoadouts.editor == nil then
        return
    end

    local visible = true
    if GearLoadouts.editor.IsVisible ~= nil then
        visible = not (safeCall(function()
            return GearLoadouts.editor:IsVisible()
        end) and true or false)
    end
    syncMoveInteraction(GearLoadouts.editor, ensureSettings(GearLoadouts.settings), "lock_editor")
    showWidget(GearLoadouts.editor, visible)
    if visible then
        refreshEditor()
    end
end

function GearLoadouts.ApplySettings(settings)
    GearLoadouts.settings = settings
    local cfg = ensureSettings(settings)
    if cfg == nil then
        return
    end
    if GearLoadouts.bar == nil then
        createBar(settings)
    end
    if GearLoadouts.editor ~= nil then
        safeCall(function()
            GearLoadouts.editor:RemoveAllAnchors()
        end)
        anchorTopLeft(GearLoadouts.editor, cfg.editor_pos_x, cfg.editor_pos_y)
    end
    if GearLoadouts.bar ~= nil then
        safeCall(function()
            GearLoadouts.bar:RemoveAllAnchors()
        end)
        anchorTopLeft(GearLoadouts.bar, cfg.bar_pos_x, cfg.bar_pos_y)
    end
    refreshBar()
    refreshEditor()
    applyVisibility()
end

function GearLoadouts.Init(settings)
    GearLoadouts.settings = settings
    GearLoadouts.enabled = true
    GearLoadouts.equip_queue = {}
    GearLoadouts.equip_delay_ms = 0
    GearLoadouts.equip_target_loadout_id = nil
    GearLoadouts.auto_accum_ms = 0
    GearLoadouts.auto_active_loadout_id = nil
    GearLoadouts.auto_pending_loadout_id = nil
    GearLoadouts.auto_zone_name = ""
    GearLoadouts.auto_zone_ms = 0
    GearLoadouts.auto_buff_name_cache = {}
    ensureSettings(settings)
    createBar(settings)
    applyVisibility()
end

function GearLoadouts.SetEnabled(enabled)
    GearLoadouts.enabled = enabled and true or false
    applyVisibility()
end

function GearLoadouts.OnUpdate(dt, settings)
    if settings ~= nil then
        GearLoadouts.settings = settings
    end
    if GearLoadouts.settings == nil then
        return
    end
    local cfg = ensureSettings(GearLoadouts.settings)
    if cfg == nil or not cfg.enabled or not GearLoadouts.enabled then
        return
    end
    local key = getCharacterKey()
    if GearLoadouts.current_character_key ~= nil and key ~= GearLoadouts.current_character_key then
        GearLoadouts.current_character_key = key
        refreshBar()
        refreshEditor()
    end
    local uiScale = (Layout ~= nil and type(Layout.GetUiScale) == "function") and Layout.GetUiScale() or 1
    if GearLoadouts.bar ~= nil and GearLoadouts.bar.__nuzi_layout_ui_scale ~= uiScale then
        anchorTopLeft(GearLoadouts.bar, cfg.bar_pos_x, cfg.bar_pos_y)
    end
    if GearLoadouts.editor ~= nil and GearLoadouts.editor.__nuzi_layout_ui_scale ~= uiScale then
        anchorTopLeft(GearLoadouts.editor, cfg.editor_pos_x, cfg.editor_pos_y)
    end
    syncMoveInteraction(GearLoadouts.bar, cfg, "lock_bar")
    syncMoveInteraction(GearLoadouts.editor, cfg, "lock_editor")
    processEquipQueue(dt)
    processAutoTriggers(dt)
    if GearLoadouts.pending_check_ms ~= nil then
        GearLoadouts.pending_check_ms = GearLoadouts.pending_check_ms - (tonumber(dt) or 0)
        if GearLoadouts.pending_check_ms <= 0 then
            local loadout = nil
            local profile = getProfile(GearLoadouts.settings)
            loadout = getLoadoutById(profile, GearLoadouts.pending_check_loadout_id)
            if loadout ~= nil then
                showIssues(loadout, tostring(loadout.name or "Loadout"))
            end
            GearLoadouts.pending_check_ms = nil
            GearLoadouts.pending_check_loadout_id = nil
            refreshEditor()
            refreshBar()
        end
    end
end

function GearLoadouts.Unload()
    for _, button in ipairs(GearLoadouts.bar_buttons) do
        freeWidget(button)
    end
    GearLoadouts.bar_buttons = {}
    GearLoadouts.slot_widgets = {}
    freeWidget(GearLoadouts.bar)
    freeWidget(GearLoadouts.editor)
    GearLoadouts.bar = nil
    GearLoadouts.editor = nil
    GearLoadouts.settings = nil
    GearLoadouts.equip_queue = {}
    GearLoadouts.equip_target_loadout_id = nil
    GearLoadouts.pending_check_ms = nil
    GearLoadouts.pending_check_loadout_id = nil
    GearLoadouts.auto_accum_ms = 0
    GearLoadouts.auto_active_loadout_id = nil
    GearLoadouts.auto_pending_loadout_id = nil
    GearLoadouts.auto_zone_name = ""
    GearLoadouts.auto_zone_ms = 0
    GearLoadouts.auto_buff_name_cache = {}
end

return GearLoadouts
