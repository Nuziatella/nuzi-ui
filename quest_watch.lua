local api = require("api")
local Runtime = require("nuzi-ui/runtime")
local Layout = require("nuzi-ui/layout")
local SettingsStore = require("nuzi-ui/settings_store")
local QuestWatchData = require("nuzi-ui/quest_watch_data")

local QuestWatch = {
    settings = nil,
    enabled = true,
    frame = nil,
    rows = {},
    title_cache = {},
    accum_ms = 0,
    current_character_key = nil
}

local WINDOW_ID = "NuziUiQuestWatch"
local DEFAULT_POS_X = 620
local DEFAULT_POS_Y = 160
local DEFAULT_WIDTH = 330
local DEFAULT_SCALE = 1
local DEFAULT_MAX_VISIBLE = 12
local DEFAULT_UPDATE_INTERVAL_MS = 10000
local ROW_HEIGHT = 18
local MAX_ROWS = 24

local function getAlignLeft()
    if ALIGN_LEFT ~= nil then
        return ALIGN_LEFT
    end
    if ALIGN ~= nil then
        return ALIGN.LEFT
    end
    return nil
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

local function clampNumber(value, minValue, maxValue, fallback)
    local number = tonumber(value)
    if number == nil or number ~= number then
        return fallback
    end
    if number < minValue then
        return minValue
    elseif number > maxValue then
        return maxValue
    end
    return number
end

local function clampInt(value, minValue, maxValue, fallback)
    return math.floor(clampNumber(value, minValue, maxValue, fallback) + 0.5)
end

local function trimText(value)
    local text = tostring(value or "")
    return string.match(text, "^%s*(.-)%s*$") or text
end

local function getConfig()
    if type(QuestWatch.settings) ~= "table" or type(QuestWatch.settings.quest_watch) ~= "table" then
        return nil
    end
    return QuestWatch.settings.quest_watch
end

local function getCharacterName()
    if Runtime ~= nil and Runtime.GetPlayerName ~= nil then
        return Runtime.GetPlayerName()
    end
    return ""
end

local function getCharacterKey()
    return QuestWatchData.NormalizeCharacterKey(getCharacterName())
end

local function getCharacterProfile(cfg)
    local profile, key = QuestWatchData.EnsureCharacterProfile(cfg, getCharacterName())
    QuestWatch.current_character_key = key
    return profile, key
end

local function isActive()
    local settings = QuestWatch.settings
    local cfg = getConfig()
    return type(settings) == "table"
        and settings.enabled ~= false
        and QuestWatch.enabled
        and type(cfg) == "table"
        and cfg.enabled == true,
        cfg
end

local function setWidgetVisible(widget, visible)
    if widget == nil or widget.Show == nil then
        return
    end
    visible = visible and true or false
    if widget.__nuzi_quest_visible == visible then
        return
    end
    safeCall(function()
        widget:Show(visible)
    end)
    widget.__nuzi_quest_visible = visible
end

local function setText(widget, text)
    if widget == nil or widget.SetText == nil then
        return
    end
    local value = tostring(text or "")
    if widget.__nuzi_quest_text == value then
        return
    end
    safeCall(function()
        widget:SetText(value)
    end)
    widget.__nuzi_quest_text = value
end

local function setLabelColor(label, r, g, b, a)
    if label == nil or label.style == nil or label.style.SetColor == nil then
        return
    end
    local key = string.format("%.3f:%.3f:%.3f:%.3f", r or 1, g or 1, b or 1, a or 1)
    if label.__nuzi_quest_color == key then
        return
    end
    safeCall(function()
        label.style:SetColor(r or 1, g or 1, b or 1, a or 1)
    end)
    label.__nuzi_quest_color = key
end

local function setWidgetInteractive(widget, enabled)
    if widget == nil then
        return
    end
    enabled = enabled and true or false
    if widget.__nuzi_quest_interactive == enabled then
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
    widget.__nuzi_quest_interactive = enabled
end

local function setWidgetClickable(widget, enabled)
    if widget == nil then
        return
    end
    enabled = enabled and true or false
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
end

local function clearCursor()
    if api ~= nil and api.Cursor ~= nil and api.Cursor.ClearCursor ~= nil then
        safeCall(function()
            api.Cursor:ClearCursor()
        end)
    end
end

local function setMoveCursor()
    clearCursor()
    if api ~= nil and api.Cursor ~= nil and api.Cursor.SetCursorImage ~= nil and CURSOR_PATH ~= nil and CURSOR_PATH.MOVE ~= nil then
        safeCall(function()
            api.Cursor:SetCursorImage(CURSOR_PATH.MOVE, 0, 0)
        end)
    end
end

local function isShiftDown()
    if api == nil or api.Input == nil or api.Input.IsShiftKeyDown == nil then
        return false
    end
    local down = safeCall(function()
        return api.Input:IsShiftKeyDown()
    end)
    return down and true or false
end

local function readMousePos()
    if api ~= nil and api.Input ~= nil and api.Input.GetMousePos ~= nil then
        local x, y = safeCall(function()
            return api.Input:GetMousePos()
        end)
        if tonumber(x) ~= nil and tonumber(y) ~= nil then
            return tonumber(x), tonumber(y)
        end
    end
    return nil, nil
end

local function createColorDrawable(parent, r, g, b, a, layer)
    if parent == nil or parent.CreateColorDrawable == nil then
        return nil
    end
    return safeCall(function()
        return parent:CreateColorDrawable(r, g, b, a, layer or "background")
    end)
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
    if label == nil and api ~= nil and api.Interface ~= nil and api.Interface.CreateWidget ~= nil then
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
                end
                if label.style.SetShadow ~= nil then
                    label.style:SetShadow(true)
                end
                if label.style.SetEllipsis ~= nil then
                    label.style:SetEllipsis(false)
                end
            end
        end)
    end
    return label
end

local function createButton(parent, id, text)
    if parent == nil then
        return nil
    end
    local button = nil
    if api ~= nil and api.Interface ~= nil and api.Interface.CreateWidget ~= nil then
        button = safeCall(function()
            return api.Interface:CreateWidget("button", id, parent)
        end)
    end
    if button == nil and parent.CreateChildWidget ~= nil then
        button = safeCall(function()
            return parent:CreateChildWidget("button", id, 0, true)
        end)
    end
    if button ~= nil then
        safeCall(function()
            button:SetText(tostring(text or ""))
            button:SetExtent(24, 22)
            if button.style ~= nil then
                button.style:SetFontSize(13)
            end
        end)
        if api ~= nil and api.Interface ~= nil and api.Interface.ApplyButtonSkin ~= nil and BUTTON_BASIC ~= nil and BUTTON_BASIC.DEFAULT ~= nil then
            safeCall(function()
                api.Interface:ApplyButtonSkin(button, BUTTON_BASIC.DEFAULT)
            end)
        end
        setWidgetClickable(button, true)
    end
    return button
end

local function setDrawableRect(drawable, parent, x, y, width, height)
    if drawable == nil then
        return
    end
    safeCall(function()
        if drawable.RemoveAllAnchors ~= nil then
            drawable:RemoveAllAnchors()
        end
        drawable:AddAnchor("TOPLEFT", parent, x, y)
        if drawable.SetExtent ~= nil then
            drawable:SetExtent(width, height)
        end
    end)
end

local function anchorLabel(label, parent, x, y, width, height)
    if label == nil then
        return
    end
    safeCall(function()
        if label.RemoveAllAnchors ~= nil then
            label:RemoveAllAnchors()
        end
        label:AddAnchor("TOPLEFT", parent, x, y)
        label:SetExtent(width, height)
    end)
end

local function anchorTopLeft(frame, x, y)
    if Layout ~= nil and type(Layout.AnchorTopLeftScreen) == "function" then
        Layout.AnchorTopLeftScreen(frame, x, y, true)
        return
    end
    safeCall(function()
        frame:AddAnchor("TOPLEFT", "UIParent", x, y)
    end)
end

local function clampFramePosition(cfg, width, height, scale)
    if type(cfg) ~= "table" then
        return false
    end
    local screenWidth, screenHeight = 1920, 1080
    if Layout ~= nil and type(Layout.GetScreenSize) == "function" then
        screenWidth, screenHeight = Layout.GetScreenSize(screenWidth, screenHeight)
    end

    local visualWidth = math.max(80, (tonumber(width) or DEFAULT_WIDTH) * (tonumber(scale) or DEFAULT_SCALE))
    local visualHeight = math.max(34, (tonumber(height) or 80) * (tonumber(scale) or DEFAULT_SCALE))
    local maxX = math.max(0, (tonumber(screenWidth) or 1920) - visualWidth)
    local maxY = math.max(0, (tonumber(screenHeight) or 1080) - visualHeight)
    local x = tonumber(cfg.pos_x)
    local y = tonumber(cfg.pos_y)
    if x == nil then
        x = DEFAULT_POS_X
    end
    if y == nil then
        y = DEFAULT_POS_Y
    end
    local nextX = clampNumber(x, 0, maxX, math.min(DEFAULT_POS_X, maxX))
    local nextY = clampNumber(y, 0, maxY, math.min(DEFAULT_POS_Y, maxY))
    nextX = math.floor(nextX + 0.5)
    nextY = math.floor(nextY + 0.5)
    local changed = cfg.pos_x ~= nextX or cfg.pos_y ~= nextY
    cfg.pos_x = nextX
    cfg.pos_y = nextY
    return changed
end

local function saveSettings()
    if type(QuestWatch.settings) == "table" and SettingsStore ~= nil and SettingsStore.SaveSettingsFile ~= nil then
        SettingsStore.SaveSettingsFile(QuestWatch.settings)
    end
end

local function updateDragPosition(frame, cfg)
    if frame == nil or type(cfg) ~= "table" then
        return false
    end

    local drag = frame.__nuzi_quest_drag_state
    if type(drag) == "table" then
        local mouseX, mouseY = readMousePos()
        if mouseX == nil or mouseY == nil then
            return false
        end
        local nextX = clampInt((tonumber(drag.pos_x) or DEFAULT_POS_X) + (mouseX - (tonumber(drag.mouse_x) or mouseX)), -5000, 5000, DEFAULT_POS_X)
        local nextY = clampInt((tonumber(drag.pos_y) or DEFAULT_POS_Y) + (mouseY - (tonumber(drag.mouse_y) or mouseY)), -5000, 5000, DEFAULT_POS_Y)
        cfg.pos_x = nextX
        cfg.pos_y = nextY
        anchorTopLeft(frame, nextX, nextY)
        return true
    end

    local x, y = nil, nil
    if Layout ~= nil and type(Layout.ReadScreenOffset) == "function" then
        x, y = Layout.ReadScreenOffset(frame)
    end
    if x ~= nil and y ~= nil then
        cfg.pos_x = math.floor(x + 0.5)
        cfg.pos_y = math.floor(y + 0.5)
        return true
    end
    return false
end

local function syncInteractionState(frame)
    local cfg = getConfig() or {}
    local canMove = frame ~= nil and frame.__nuzi_quest_dragging == true or cfg.lock_position ~= true
    if type(QuestWatch.settings) == "table" and QuestWatch.settings.drag_requires_shift == true then
        canMove = frame ~= nil and frame.__nuzi_quest_dragging == true or (canMove and isShiftDown())
    end
    for _, widget in ipairs({ frame, frame.title, frame.summary }) do
        setWidgetInteractive(widget, canMove)
    end
    setWidgetClickable(frame, true)
    setWidgetClickable(frame.completed, true)
    setWidgetClickable(frame.toggle, true)
end

local renderFrame
local toggleCollapsed
local toggleCompleted

local function attachDragHandlers(frame)
    local function onDragStart()
        local cfg = getConfig()
        if type(cfg) ~= "table" or cfg.lock_position == true then
            return
        end
        if type(QuestWatch.settings) == "table" and QuestWatch.settings.drag_requires_shift == true and not isShiftDown() then
            return
        end
        local mouseX, mouseY = readMousePos()
        if mouseX == nil or mouseY == nil then
            return
        end
        frame.__nuzi_quest_drag_state = {
            mouse_x = mouseX,
            mouse_y = mouseY,
            pos_x = tonumber(cfg.pos_x) or DEFAULT_POS_X,
            pos_y = tonumber(cfg.pos_y) or DEFAULT_POS_Y
        }
        frame.__nuzi_quest_dragging = true
        setMoveCursor()
        syncInteractionState(frame)
    end

    local function onDragStop()
        if not frame.__nuzi_quest_dragging then
            return
        end
        local cfg = getConfig()
        updateDragPosition(frame, cfg)
        frame.__nuzi_quest_dragging = false
        frame.__nuzi_quest_drag_state = nil
        clearCursor()
        if type(cfg) == "table" then
            anchorTopLeft(frame, cfg.pos_x, cfg.pos_y)
        end
        saveSettings()
        syncInteractionState(frame)
    end

    for _, target in ipairs({ frame, frame.title, frame.summary }) do
        if target ~= nil then
            safeCall(function()
                if target.RegisterForDrag ~= nil then
                    target:RegisterForDrag("LeftButton")
                end
            end)
            if target.SetHandler ~= nil then
                target:SetHandler("OnDragStart", onDragStart)
                target:SetHandler("OnDragStop", onDragStop)
            end
            setWidgetInteractive(target, false)
        end
    end
end

local function createFrame()
    if api == nil or api.Interface == nil or api.Interface.CreateEmptyWindow == nil then
        return nil
    end

    local frame = safeCall(function()
        return api.Interface:CreateEmptyWindow(WINDOW_ID, "UIParent")
    end)
    if frame == nil then
        return nil
    end

    safeCall(function()
        frame:SetExtent(DEFAULT_WIDTH, 120)
        if frame.SetCloseOnEscape ~= nil then
            frame:SetCloseOnEscape(false)
        end
        if frame.EnableHidingIsRemove ~= nil then
            frame:EnableHidingIsRemove(false)
        end
        if frame.SetUILayer ~= nil then
            frame:SetUILayer("game")
        end
        if frame.SetZOrder ~= nil then
            frame:SetZOrder(9997)
        end
    end)

    frame.background = createColorDrawable(frame, 0.05, 0.04, 0.03, 0.86, "background")
    frame.header = createColorDrawable(frame, 0.92, 0.70, 0.32, 0.12, "overlay")
    frame.divider = createColorDrawable(frame, 0.88, 0.70, 0.35, 0.22, "overlay")
    frame.title = createLabel(frame, "NuziUiQuestWatchTitle", 15, getAlignLeft())
    frame.summary = createLabel(frame, "NuziUiQuestWatchSummary", 12, getAlignLeft())
    frame.completed = createButton(frame, "NuziUiQuestWatchCompleted", "C")
    frame.toggle = createButton(frame, "NuziUiQuestWatchToggle", "-")
    frame.footer = createLabel(frame, "NuziUiQuestWatchFooter", 11, getAlignLeft())

    setText(frame.title, "Daily Quests")
    setText(frame.completed, "C")
    setText(frame.toggle, "-")
    setLabelColor(frame.title, 1, 0.86, 0.55, 1)
    setLabelColor(frame.summary, 0.86, 0.78, 0.64, 1)
    setLabelColor(frame.footer, 0.70, 0.64, 0.54, 1)
    if frame.toggle ~= nil and frame.toggle.SetHandler ~= nil then
        frame.toggle:SetHandler("OnClick", function()
            if type(toggleCollapsed) == "function" then
                toggleCollapsed()
            end
        end)
        setWidgetClickable(frame.toggle, true)
    end
    if frame.completed ~= nil and frame.completed.SetHandler ~= nil then
        frame.completed:SetHandler("OnClick", function()
            if type(toggleCompleted) == "function" then
                toggleCompleted()
            end
        end)
        setWidgetClickable(frame.completed, true)
    end

    for index = 1, MAX_ROWS do
        local row = createLabel(frame, "NuziUiQuestWatchRow" .. tostring(index), 12, getAlignLeft())
        QuestWatch.rows[index] = row
        setLabelColor(row, 0.96, 0.92, 0.84, 1)
    end

    attachDragHandlers(frame)
    return frame
end

local function ensureFrame()
    if QuestWatch.frame == nil then
        QuestWatch.frame = createFrame()
    end
    return QuestWatch.frame
end

local function isQuestCompleted(questId)
    if api == nil or api.Quest == nil or api.Quest.IsCompleted == nil then
        return false
    end
    local result = safeCall(function()
        return api.Quest:IsCompleted(questId)
    end)
    return result and true or false
end

local function readActiveQuestTitle(questId)
    if api == nil or api.Quest == nil or api.Quest.GetActiveQuestTitle == nil then
        return ""
    end
    local title = safeCall(function()
        return api.Quest:GetActiveQuestTitle(questId)
    end)
    return trimText(title)
end

local function isGroupCompleted(group)
    if type(group) ~= "table" or type(group.ids) ~= "table" then
        return false
    end
    for _, questId in ipairs(group.ids) do
        if isQuestCompleted(questId) then
            return true
        end
    end
    return false
end

local function readGroupActiveQuestTitle(group)
    if type(group) ~= "table" or type(group.ids) ~= "table" then
        return ""
    end
    for _, questId in ipairs(group.ids) do
        local title = readActiveQuestTitle(questId)
        if title ~= "" then
            return title
        end
    end
    return ""
end

local function readQuestTitle(group)
    if type(group) ~= "table" then
        return ""
    end
    if QuestWatch.title_cache[group.key] ~= nil then
        return QuestWatch.title_cache[group.key]
    end

    local title = ""
    if api ~= nil and api.Quest ~= nil and api.Quest.GetQuestContextMainTitle ~= nil then
        title = safeCall(function()
            return api.Quest:GetQuestContextMainTitle(group.ids[1])
        end) or ""
    end
    title = trimText(title)
    if title == "" then
        title = tostring(group.label or group.key or "")
    end
    QuestWatch.title_cache[group.key] = title
    return title
end

local function formatIds(group)
    local parts = {}
    for _, id in ipairs(type(group) == "table" and type(group.ids) == "table" and group.ids or {}) do
        parts[#parts + 1] = tostring(id)
    end
    if #parts == 0 then
        return ""
    end
    return " [" .. table.concat(parts, "/") .. "]"
end

local function isTracked(tracked, group)
    if type(group) ~= "table" then
        return false
    end
    if type(tracked) ~= "table" then
        return true
    end
    return tracked[group.key] ~= false
end

local function buildQuestState(tracked)
    local incomplete = {}
    local completed = {}
    local trackedCount = 0
    local completedCount = 0
    for _, group in ipairs(QuestWatchData.GetGroups()) do
        if isTracked(tracked, group) then
            trackedCount = trackedCount + 1
            if isGroupCompleted(group) then
                completedCount = completedCount + 1
                completed[#completed + 1] = {
                    group = group
                }
            else
                local activeTitle = readGroupActiveQuestTitle(group)
                incomplete[#incomplete + 1] = {
                    group = group,
                    missing = activeTitle == "",
                    active_title = activeTitle
                }
            end
        end
    end
    return incomplete, completed, trackedCount, completedCount
end

local function applyFrameSettings(frame, cfg, visibleRows, collapsed)
    local width = clampInt(cfg.width, 240, 520, DEFAULT_WIDTH)
    local scale = clampNumber(cfg.scale, 0.75, 1.6, DEFAULT_SCALE)
    local rowCount = collapsed and 0 or clampInt(visibleRows, 1, MAX_ROWS, DEFAULT_MAX_VISIBLE)
    local height = collapsed and 36 or (52 + (rowCount * ROW_HEIGHT) + 22)
    local layoutKey = string.format("%d:%d:%.2f:%s", width, rowCount, scale, tostring(collapsed and true or false))

    if frame.__nuzi_quest_layout_key ~= layoutKey then
        safeCall(function()
            frame:SetExtent(width, height)
            if frame.SetScale ~= nil then
                frame:SetScale(scale)
            end
        end)
        setDrawableRect(frame.background, frame, 0, 0, width, height)
        setDrawableRect(frame.header, frame, 0, 0, width, 34)
        setDrawableRect(frame.divider, frame, 10, 34, width - 20, 1)
        anchorLabel(frame.title, frame, 12, 8, width - 80, 18)
        anchorLabel(frame.completed, frame, width - 56, 8, 24, 22)
        anchorLabel(frame.toggle, frame, width - 28, 8, 18, 18)
        if not collapsed then
            anchorLabel(frame.summary, frame, 12, 34, width - 24, 16)
            for index, row in ipairs(QuestWatch.rows) do
                anchorLabel(row, frame, 14, 52 + ((index - 1) * ROW_HEIGHT), width - 28, ROW_HEIGHT)
            end
            anchorLabel(frame.footer, frame, 12, 52 + (rowCount * ROW_HEIGHT) + 2, width - 24, 16)
        end
        frame.__nuzi_quest_layout_key = layoutKey
    end

    if not frame.__nuzi_quest_dragging then
        local positionChanged = clampFramePosition(cfg, width, height, scale)
        anchorTopLeft(frame, tonumber(cfg.pos_x) or DEFAULT_POS_X, tonumber(cfg.pos_y) or DEFAULT_POS_Y)
        if positionChanged then
            saveSettings()
        end
    end
    syncInteractionState(frame)
    setWidgetClickable(frame.completed, true)
    setWidgetClickable(frame.toggle, true)
end

toggleCollapsed = function()
    local cfg = getConfig()
    if type(cfg) ~= "table" then
        return
    end
    local profile = getCharacterProfile(cfg)
    if type(profile) ~= "table" then
        return
    end
    profile.collapsed = not (profile.collapsed == true)
    saveSettings()
    renderFrame(true)
end

toggleCompleted = function()
    local cfg = getConfig()
    if type(cfg) ~= "table" then
        return
    end
    local profile = getCharacterProfile(cfg)
    if type(profile) ~= "table" then
        return
    end
    profile.completed_view = not (profile.completed_view == true)
    if profile.completed_view then
        profile.collapsed = false
    end
    saveSettings()
    renderFrame(true)
end

function renderFrame(force)
    local active, cfg = isActive()
    if not active then
        if QuestWatch.frame ~= nil then
            setWidgetVisible(QuestWatch.frame, false)
        end
        return
    end

    local profile = getCharacterProfile(cfg)
    if type(profile) ~= "table" then
        return
    end

    QuestWatchData.EnsureTrackedDefaults(profile)
    local incomplete, completed, trackedCount, completedCount = buildQuestState(profile.tracked)
    local completedView = profile.completed_view == true
    local autoCollapsed = not completedView and trackedCount > 0 and #incomplete == 0 and cfg.hide_when_done ~= false

    local frame = ensureFrame()
    if frame == nil then
        return
    end

    local maxVisible = clampInt(cfg.max_visible, 4, MAX_ROWS, DEFAULT_MAX_VISIBLE)
    local activeListCount = completedView and #completed or #incomplete
    local rowCount = math.max(1, math.min(maxVisible, math.max(activeListCount, trackedCount == 0 and 1 or 0)))
    local collapsed = profile.collapsed == true or autoCollapsed
    applyFrameSettings(frame, cfg, rowCount, collapsed)

    if collapsed then
        local countText = tostring(#incomplete) .. " incomplete"
        if trackedCount == 0 then
            countText = "0 tracked"
        end
        setText(frame.title, "Daily Quests - " .. countText)
        setText(frame.completed, "C")
        setText(frame.toggle, "+")
        setWidgetVisible(frame.summary, false)
        setWidgetVisible(frame.divider, false)
        setWidgetVisible(frame.footer, false)
        for index = 1, MAX_ROWS do
            setWidgetVisible(QuestWatch.rows[index], false)
        end
        setWidgetVisible(frame, true)
        if force then
            QuestWatch.accum_ms = 0
        end
        return
    end

    setText(frame.title, completedView and "Completed Dailies" or "Daily Quests")
    setText(frame.completed, "C")
    setText(frame.toggle, "-")
    setWidgetVisible(frame.summary, true)
    setWidgetVisible(frame.divider, true)
    setWidgetVisible(frame.footer, true)
    if completedView then
        setText(frame.summary, string.format("%d/%d tracked dailies complete", completedCount, trackedCount))
    else
        setText(frame.summary, string.format("%d incomplete, %d/%d complete", #incomplete, completedCount, trackedCount))
    end

    local showIds = cfg.show_ids == true
    if trackedCount == 0 then
        setText(QuestWatch.rows[1], "No daily quests selected.")
        setLabelColor(QuestWatch.rows[1], 0.92, 0.76, 0.48, 1)
        setWidgetVisible(QuestWatch.rows[1], true)
        for index = 2, MAX_ROWS do
            setWidgetVisible(QuestWatch.rows[index], false)
        end
        setText(frame.footer, "Open settings to choose tracked dailies.")
    elseif completedView and #completed == 0 then
        setText(QuestWatch.rows[1], "No completed tracked dailies.")
        setLabelColor(QuestWatch.rows[1], 0.92, 0.76, 0.48, 1)
        setWidgetVisible(QuestWatch.rows[1], true)
        for index = 2, MAX_ROWS do
            setWidgetVisible(QuestWatch.rows[index], false)
        end
        setText(frame.footer, "")
    elseif not completedView and #incomplete == 0 then
        setText(QuestWatch.rows[1], "All tracked dailies complete.")
        setLabelColor(QuestWatch.rows[1], 0.56, 1.00, 0.68, 1)
        setWidgetVisible(QuestWatch.rows[1], true)
        for index = 2, MAX_ROWS do
            setWidgetVisible(QuestWatch.rows[index], false)
        end
        setText(frame.footer, "")
    else
        for index = 1, MAX_ROWS do
            local row = QuestWatch.rows[index]
            local entry = completedView and completed[index] or incomplete[index]
            local group = type(entry) == "table" and entry.group or nil
            if row ~= nil and index <= maxVisible and type(group) == "table" then
                local title = tostring(entry.active_title or "")
                if title == "" then
                    title = readQuestTitle(group)
                end
                local text = tostring(group.category or "Daily") .. ": " .. title
                if showIds then
                    text = text .. formatIds(group)
                end
                setText(row, text)
                if completedView then
                    setLabelColor(row, 0.56, 1.00, 0.68, 1)
                elseif entry.missing then
                    setLabelColor(row, 1.00, 0.68, 0.34, 1)
                else
                    setLabelColor(row, 0.96, 0.92, 0.84, 1)
                end
                setWidgetVisible(row, true)
            else
                setWidgetVisible(row, false)
            end
        end

        local remaining = (completedView and #completed or #incomplete) - maxVisible
        if remaining > 0 then
            setText(frame.footer, "+" .. tostring(remaining) .. (completedView and " more completed dailies" or " more incomplete dailies"))
        else
            setText(frame.footer, "")
        end
    end

    setWidgetVisible(frame, true)
    if force then
        QuestWatch.accum_ms = 0
    end
end

function QuestWatch.Init(settings)
    QuestWatch.settings = settings
    QuestWatch.enabled = type(settings) == "table" and settings.enabled ~= false
    QuestWatch.accum_ms = 0
    renderFrame(true)
end

function QuestWatch.ApplySettings(settings)
    QuestWatch.settings = settings
    renderFrame(true)
end

function QuestWatch.SetEnabled(enabled)
    QuestWatch.enabled = enabled and true or false
    if not QuestWatch.enabled and QuestWatch.frame ~= nil then
        setWidgetVisible(QuestWatch.frame, false)
    else
        renderFrame(true)
    end
end

function QuestWatch.OnUpdate(dt, settings)
    if type(settings) == "table" then
        QuestWatch.settings = settings
    end

    local active, cfg = isActive()
    if not active then
        if QuestWatch.frame ~= nil then
            setWidgetVisible(QuestWatch.frame, false)
        end
        return
    end

    local key = getCharacterKey()
    if QuestWatch.current_character_key ~= nil and key ~= QuestWatch.current_character_key then
        renderFrame(true)
        return
    end

    if QuestWatch.frame ~= nil and QuestWatch.frame.__nuzi_quest_dragging then
        updateDragPosition(QuestWatch.frame, cfg)
        syncInteractionState(QuestWatch.frame)
        return
    end

    QuestWatch.accum_ms = (tonumber(QuestWatch.accum_ms) or 0) + (tonumber(dt) or 0)
    local interval = clampInt(cfg.update_interval_ms, 1000, 60000, DEFAULT_UPDATE_INTERVAL_MS)
    if QuestWatch.accum_ms < interval then
        if QuestWatch.frame ~= nil then
            syncInteractionState(QuestWatch.frame)
        end
        return
    end
    QuestWatch.accum_ms = 0
    renderFrame(false)
end

function QuestWatch.Unload()
    if QuestWatch.frame ~= nil then
        QuestWatch.frame.__nuzi_quest_dragging = false
        setWidgetVisible(QuestWatch.frame, false)
        if api ~= nil and api.Interface ~= nil and api.Interface.Free ~= nil then
            safeCall(function()
                api.Interface:Free(QuestWatch.frame)
            end)
        end
    end
    QuestWatch.frame = nil
    QuestWatch.rows = {}
    QuestWatch.accum_ms = 0
end

return QuestWatch
