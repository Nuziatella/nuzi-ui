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
    pending_check_ms = nil,
    pending_check_loadout_id = nil,
    refreshing_dropdown = false
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

local function setWindowInteractive(widget, enabled)
    if widget == nil then
        return
    end
    enabled = enabled and true or false
    if widget.__nuzi_loadouts_interactive == enabled then
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
    if widget.EnableDrag ~= nil then
        safeCall(function()
            widget:EnableDrag(enabled)
        end)
    end
    widget.__nuzi_loadouts_interactive = enabled
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
        setWindowInteractive(window, false)
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
            button:Show(true)
        end)
        applyButtonSkin(button, BUTTON_BASIC ~= nil and BUTTON_BASIC.DEFAULT or nil)
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

local function equipLoadout(loadout)
    if type(loadout) ~= "table" then
        return
    end
    if GearLoadouts.settings == nil then
        return
    end

    showIssues(loadout, tostring(loadout.name or "Loadout"))

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
    GearLoadouts.pending_check_ms = nil
    GearLoadouts.pending_check_loadout_id = nil

    if #queue == 0 then
        setStatus("No gear to equip for " .. tostring(loadout.name or "loadout") .. ".", false)
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
        local loadout = getSelectedLoadout(GearLoadouts.settings)
        GearLoadouts.pending_check_ms = 700
        GearLoadouts.pending_check_loadout_id = loadout ~= nil and loadout.id or nil
        setStatus("Equip requests sent.", false)
    end
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
    setWindowInteractive(window, interactive)
end

local function attachMoveHandlers(window, cfgKeyX, cfgKeyY, lockKey)
    if window == nil then
        return
    end
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
        window:SetExtent(520, 560)
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

    local slotPanel = safeCall(function()
        return window:CreateChildWidget("emptywidget", "nuziGearSlotPanel", 0, true)
    end)
    if slotPanel == nil then
        return
    end
    window.slot_panel = slotPanel
    safeCall(function()
        slotPanel:AddAnchor("TOPLEFT", window, 61, 122)
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

    window.status = createLabel(window, "nuziGearStatus", "", 16, 528, 488, 20, 12)
    setStatus("", false)
    showWidget(window, false)
end

refreshEditor = function()
    if GearLoadouts.editor == nil then
        return
    end
    refreshLoadoutDropdown()
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
        setWindowInteractive(GearLoadouts.bar, false)
        setWindowInteractive(GearLoadouts.editor, false)
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
    GearLoadouts.pending_check_ms = nil
    GearLoadouts.pending_check_loadout_id = nil
end

return GearLoadouts
