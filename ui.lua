local api = require("api")
local SafeRequire = require("nuzi-ui/safe_require")

local Nameplates = SafeRequire("nuzi-ui/nameplates", "nuzi-ui.nameplates")
local Runtime = SafeRequire("nuzi-ui/runtime", "nuzi-ui.runtime")
local Layout = SafeRequire("nuzi-ui/layout", "nuzi-ui.layout")
local AlignmentModule = SafeRequire("nuzi-ui/ui_alignment", "nuzi-ui.ui_alignment")
local TargetExtrasModule = SafeRequire("nuzi-ui/ui_target_extras", "nuzi-ui.ui_target_extras")
local CooldownTracker = SafeRequire("nuzi-ui/cooldown_tracker", "nuzi-ui.cooldown_tracker")
local CastBar = SafeRequire("nuzi-ui/castbar", "nuzi-ui.castbar")
local TravelSpeed = SafeRequire("nuzi-ui/travel_speed", "nuzi-ui.travel_speed")
local MountGlider = SafeRequire("nuzi-ui/mount_glider", "nuzi-ui.mount_glider")
local GearLoadouts = SafeRequire("nuzi-ui/gear_loadouts", "nuzi-ui.gear_loadouts")
local QuestWatch = SafeRequire("nuzi-ui/quest_watch", "nuzi-ui.quest_watch")
local SettingsStore = SafeRequire("nuzi-ui/settings_store", "nuzi-ui.settings_store")

local function AnchorTopLeft(wnd, x, y)
    if wnd == nil or wnd.AddAnchor == nil then
        return false
    end
    if Layout ~= nil and type(Layout.AnchorTopLeftScreen) == "function" then
        return Layout.AnchorTopLeftScreen(wnd, x, y, false)
    end

    local anchored = false
    local ok = pcall(function()
        wnd:AddAnchor("TOPLEFT", "UIParent", x, y)
    end)
    anchored = ok and true or false
    if anchored then
        return true
    end

    ok = pcall(function()
        wnd:AddAnchor("TOPLEFT", "UIParent", "TOPLEFT", x, y)
    end)
    anchored = ok and true or false
    if anchored then
        return true
    end

    ok = pcall(function()
        wnd:AddAnchor("TOPLEFT", x, y)
    end)
    anchored = ok and true or false
    return anchored
end

local UI = {
    settings = nil,
    enabled = true,
    accum_ms = 0,
    plates_accum_ms = 0,
    plates_position_accum_ms = 0,
    needs_full_apply = true,
    stock_refreshed = false,
    last_large_hpmp = nil,
    last_aura_enabled = nil,
    last_aura_cfg = nil,
    stock_distance_forced_hidden = false,
    created = {},
    player = {
        wnd = nil
    },
    watchtarget = {
        wnd = nil
    },
    target_of_target = {
        wnd = nil
    },
    target = {
        wnd = nil,
        role = nil,
        class_name = nil,
        gearscore = nil,
        current_target_id = nil,
        guild = nil,
        pdef = nil,
        mdef = nil,
        custom_hp_bg = nil,
        custom_mp_bg = nil
    },
    party = {
        manager = nil,
        overlays = {},
        style_generation = 0
    },
    alignment_grid = {
        wnd = nil,
        v_lines = {},
        h_lines = {},
        last_w = nil,
        last_h = nil
    }
}

local STOCK_LEVEL_ARTIFACT_FIELDS = {
    "levelLabel",
    "level",
    "gradeIcon",
    "ancestralIcon",
    "heirFrame",
    "heirWing",
    "heirIcon",
    "heirTexture",
    "successorFrame",
    "successor_frame"
}

local STOCK_LEVEL_ARTIFACT_PATTERNS = {
    "ancestral",
    "grade",
    "wing",
    "flare",
    "heir",
    "successor"
}

local STOCK_TARGET_BACKGROUND_FIELDS = {
    "bg",
    "background",
    "backdrop",
    "frameBg",
    "bossBg",
    "bossBackground",
    "bossFrameBg",
    "bossDecoLeft",
    "bossDecoRight",
    "leftBg",
    "rightBg",
    "leftDeco",
    "rightDeco",
    "gradeBg",
    "gradeDeco"
}

local STOCK_TARGET_BACKGROUND_EXCLUDE = {
    hpbar = true,
    mpbar = true,
    name = true,
    level = true,
    levellabel = true,
    distancelabel = true,
    buffwindow = true,
    debuffwindow = true,
    eventwindow = true
}

local BuildUiContext

local PARTY_MAX_GROUPS = 10
local PARTY_MEMBERS_PER_GROUP = 5
local ApplyStockFrameStyle
local SafeGetExtent
local SetWidgetVisible
local SetNotClickable
local ColorFrom255
local ApplyBuffWindowPlacement
local ResolveFrameStyleTable
local RefreshFrameBarPresentation


local function NormalizeUnitId(unitId)
    if unitId == nil then
        return nil
    end
    local valueType = type(unitId)
    if valueType == "string" then
        local text = tostring(unitId)
        if text == "" then
            return nil
        end
        return text
    end
    if valueType == "number" then
        return tostring(unitId)
    end
    return nil
end

local function SafeGetUnitInfoById(unitId)
    local normalizedId = NormalizeUnitId(unitId)
    if normalizedId == nil or api == nil or api.Unit == nil or api.Unit.GetUnitInfoById == nil then
        return nil
    end
    local info = nil
    pcall(function()
        info = api.Unit:GetUnitInfoById(normalizedId)
    end)
    if type(info) == "table" then
        return info
    end
    return nil
end

local function TrimText(value)
    local text = tostring(value or "")
    text = string.match(text, "^%s*(.-)%s*$") or text
    return text
end

local function NormalizeRuntimeUnitToken(unit)
    if type(unit) ~= "string" then
        return nil
    end
    local token = TrimText(unit)
    if token == "" then
        return nil
    end
    if token == "targetoftarget" or token == "target_of_target" then
        return "targettarget"
    end
    return token
end

local function SafeUnitInfo(unit)
    local normalizedUnit = NormalizeRuntimeUnitToken(unit)
    if normalizedUnit == nil or api == nil or api.Unit == nil or api.Unit.UnitInfo == nil then
        return nil
    end
    local info = nil
    pcall(function()
        info = api.Unit:UnitInfo(normalizedUnit)
    end)
    if type(info) == "table" then
        return info
    end
    return nil
end

local function NormalizeNumericValue(value)
    local n = tonumber(value)
    if n == nil or n ~= n or n == math.huge or n == -math.huge then
        return nil
    end
    return n
end

local function FormatIntegerValue(value)
    local n = NormalizeNumericValue(value)
    if n == nil then
        return "0"
    end
    return string.format("%.0f", n)
end

local function ResolveFrameRuntimeUnit(frame)
    if type(frame) ~= "table" then
        return nil
    end
    local token = NormalizeRuntimeUnitToken(frame.__polar_runtime_unit)
    if token ~= nil then
        return token
    end
    token = NormalizeRuntimeUnitToken(frame.target)
    if token ~= nil then
        return token
    end
    return NormalizeRuntimeUnitToken(frame.__polar_unit)
end

local function SyncSecondaryFrameBinding(frame, runtimeUnit)
    if frame == nil then
        return
    end

    local unitKey = NormalizeRuntimeUnitToken(runtimeUnit)
    if unitKey == nil then
        return
    end

    frame.__polar_runtime_unit = unitKey
end

local function IsHostileHpOverrideUnit(unit)
    local token = NormalizeRuntimeUnitToken(unit)
    return token == "target" or token == "watchtarget" or token == "targettarget"
end

local function ResolveUnitDisplayName(info)
    if type(info) ~= "table" then
        return ""
    end
    return TrimText(info.name or info.unitName or info.family_name or "")
end

local function ResolveUnitLevelParts(info)
    if type(info) ~= "table" then
        return nil, nil
    end

    local level = tonumber(info.level or info.unitLevel or info.lv)
    if level ~= nil and level > 0 then
        level = math.floor(level + 0.5)
    else
        level = nil
    end

    local heirLevel = tonumber(info.heirLevel)
    if heirLevel ~= nil and heirLevel > 0 then
        heirLevel = math.floor(heirLevel + 0.5)
    else
        heirLevel = nil
    end

    return level, heirLevel
end

local function ResolveUnitLevel(info)
    local level, heirLevel = ResolveUnitLevelParts(info)
    return heirLevel or level
end

local function ApplyFrameNameLevel(frame, unitName, unitLevel, unitHeirLevel)
    if frame == nil then
        return
    end

    local style = ResolveFrameStyleTable ~= nil and ResolveFrameStyleTable(frame) or nil
    if type(style) ~= "table" and type(UI.settings) == "table" then
        style = UI.settings.style
    end

    pcall(function()
        if frame.name ~= nil then
            local showName = type(unitName) == "string" and unitName ~= "" and (type(style) ~= "table" or style.name_visible ~= false)
            if frame.name.SetText ~= nil and showName and frame.name.__polar_text ~= unitName then
                frame.name:SetText(unitName)
                frame.name.__polar_text = unitName
            end
            if frame.name.SetText ~= nil and not showName and frame.name.__polar_text ~= "" then
                frame.name:SetText("")
                frame.name.__polar_text = ""
            end
            if frame.name.Show ~= nil and frame.name.__polar_visible ~= showName then
                frame.name:Show(showName)
                frame.name.__polar_visible = showName
            end
        end
    end)

    pcall(function()
        local levelRoot = frame.level
        local levelLabel = (type(levelRoot) == "table" and levelRoot.label ~= nil) and levelRoot.label or nil
        if levelLabel == nil then
            return
        end

        local level = tonumber(unitLevel)
        local heirLevel = tonumber(unitHeirLevel) or 0
        local displayLevel = heirLevel > 0 and heirLevel or level
        local showLevel = type(displayLevel) == "number" and displayLevel > 0 and (type(style) ~= "table" or style.level_visible ~= false)
        if type(UI.settings) == "table" and UI.settings.hide_ancestral_icon_level then
            showLevel = false
        end

        if showLevel and type(levelRoot) == "table" and type(levelRoot.ChangedLevel) == "function" then
            levelRoot:ChangedLevel(level or displayLevel, heirLevel)
            levelLabel.__polar_text = tostring(displayLevel)
        elseif levelLabel.SetText ~= nil then
            local levelText = showLevel and tostring(displayLevel) or ""
            if levelLabel.__polar_text ~= levelText then
                levelLabel:SetText(levelText)
                levelLabel.__polar_text = levelText
            end
        end

        if levelRoot ~= nil and levelRoot.Show ~= nil and levelRoot.__polar_visible ~= showLevel then
            levelRoot:Show(showLevel)
            levelRoot.__polar_visible = showLevel
        end
        if levelLabel.Show ~= nil and levelLabel.__polar_visible ~= showLevel then
            levelLabel:Show(showLevel)
            levelLabel.__polar_visible = showLevel
        end
        if not showLevel and type(levelRoot) == "table" then
            if levelRoot.levelTexture ~= nil and levelRoot.levelTexture.SetVisible ~= nil then
                levelRoot.levelTexture:SetVisible(false)
            end
            if levelRoot.heirIcon ~= nil and levelRoot.heirIcon.SetVisible ~= nil then
                levelRoot.heirIcon:SetVisible(false)
            end
            if levelRoot.heirTexture ~= nil and levelRoot.heirTexture.SetVisible ~= nil then
                levelRoot.heirTexture:SetVisible(false)
            end
        end
    end)
end

local function ApplyTargetNameLevel(targetName, targetLevel, targetHeirLevel)
    if UI == nil or UI.target == nil or UI.target.wnd == nil then
        return
    end
    ApplyFrameNameLevel(UI.target.wnd, targetName, targetLevel, targetHeirLevel)
end

local function RefreshFrameNameLevelFromUnit(frame, unit)
    if frame == nil then
        return
    end

    local unitId = Runtime ~= nil and Runtime.GetUnitId ~= nil and Runtime.GetUnitId(unit) or nil
    local unitInfo = SafeUnitInfo(unit)
    local idInfo = SafeGetUnitInfoById(unitId)
    if type(unitInfo) ~= "table" and type(idInfo) ~= "table" then
        return
    end

    local name = Runtime ~= nil and Runtime.GetUnitName ~= nil and Runtime.GetUnitName(unit) or ""
    if name == "" then
        name = ResolveUnitDisplayName(unitInfo)
    end
    if name == "" then
        name = ResolveUnitDisplayName(idInfo)
    end

    local level, heirLevel = ResolveUnitLevelParts(unitInfo)
    local idLevel, idHeirLevel = ResolveUnitLevelParts(idInfo)
    if level == nil then
        level = idLevel
    end
    if heirLevel == nil then
        heirLevel = idHeirLevel
    end
    ApplyFrameNameLevel(frame, name, level, heirLevel)
end

local function ResolveWidgetCandidate(value)
    if value == nil then
        return nil
    end
    if type(value) == "table" and value.Show == nil and value.label ~= nil then
        return value.label
    end
    return value
end

local function SetWidgetForcedHidden(widget, hidden)
    widget = ResolveWidgetCandidate(widget)
    if widget == nil then
        return
    end

    if SetNotClickable ~= nil then
        SetNotClickable(widget)
    end

    hidden = hidden and true or false
    if hidden then
        if widget.__polar_forced_hidden then
            return
        end
        widget.__polar_forced_hidden = true
        pcall(function()
            if widget.IsVisible ~= nil then
                widget.__polar_prev_visible = widget:IsVisible() and true or false
            elseif widget.GetVisible ~= nil then
                widget.__polar_prev_visible = widget:GetVisible() and true or false
            end
        end)
        pcall(function()
            if widget.GetAlpha ~= nil then
                widget.__polar_prev_alpha = widget:GetAlpha()
            end
        end)
        pcall(function()
            if widget.SetAlpha ~= nil then
                widget:SetAlpha(0)
            end
        end)
        pcall(function()
            if widget.Show ~= nil then
                widget:Show(false)
            end
        end)
        return
    end

    if not widget.__polar_forced_hidden then
        return
    end

    widget.__polar_forced_hidden = nil
    pcall(function()
        if widget.SetAlpha ~= nil then
            widget:SetAlpha(widget.__polar_prev_alpha or 1)
        end
    end)
    widget.__polar_prev_alpha = nil
    local restoreVisible = widget.__polar_prev_visible
    widget.__polar_prev_visible = nil
    pcall(function()
        if widget.Show ~= nil and restoreVisible ~= nil then
            widget:Show(restoreVisible and true or false)
        end
    end)
end

local function ShouldShowClassIconForUnit(unit)
    local unitKey = NormalizeRuntimeUnitToken(unit)
    if unitKey == nil then
        return false
    end
    if unitKey == "player" then
        return true
    end
    if F_UNIT == nil or type(F_UNIT.GetUnitType) ~= "function" then
        return false
    end

    local unitType = nil
    pcall(function()
        unitType = F_UNIT.GetUnitType(unitKey)
    end)
    return unitType == "player" or unitType == "character"
end

local function ResolveClassIconFrame(frame)
    if type(frame) ~= "table" then
        return nil
    end
    return ResolveWidgetCandidate(frame.abilityIconFrame)
end

local function AnchorClassIconFrame(frame, icon)
    if frame == nil or icon == nil or icon.AddAnchor == nil then
        return
    end
    pcall(function()
        if icon.RemoveAllAnchors ~= nil then
            icon:RemoveAllAnchors()
        end
        icon:AddAnchor("TOPRIGHT", frame, -48, 3)
    end)
end

local function EnsureClassIconFrame(frame, unit)
    if frame == nil or ResolveClassIconFrame(frame) ~= nil or type(CreateAbilityIcon) ~= "function" then
        return
    end

    local unitKey = NormalizeRuntimeUnitToken(unit) or "player"
    pcall(function()
        CreateAbilityIcon("abilityIconFrame", frame, unitKey)
    end)

    local icon = ResolveClassIconFrame(frame)
    if icon ~= nil then
        icon.__polar_class_icon_created = true
        AnchorClassIconFrame(frame, icon)
    end
end

local function RefreshClassIconFrame(frame, settings)
    local icon = ResolveClassIconFrame(frame)
    if icon == nil then
        return
    end

    local hideClassIcon = type(settings) == "table" and settings.show_class_icons == false
    SetWidgetForcedHidden(icon, hideClassIcon)
    if hideClassIcon then
        return
    end

    local unitKey = ResolveFrameRuntimeUnit(frame)
    pcall(function()
        if icon.SetAbility ~= nil and unitKey ~= nil then
            icon:SetAbility(unitKey)
        end
    end)

    local visible = ShouldShowClassIconForUnit(unitKey)
    pcall(function()
        if icon.Show ~= nil then
            icon:Show(visible)
        elseif icon.SetVisible ~= nil then
            icon:SetVisible(visible)
        end
    end)
end

local function ResetClassIconFrame(frame)
    local icon = ResolveClassIconFrame(frame)
    if icon == nil then
        return
    end

    SetWidgetForcedHidden(icon, false)
    if icon.__polar_class_icon_created then
        pcall(function()
            if icon.Show ~= nil then
                icon:Show(false)
            elseif icon.SetVisible ~= nil then
                icon:SetVisible(false)
            end
        end)
    end
end

local function EnsureClassIconFrames()
    EnsureClassIconFrame(UI.player.wnd, "player")
    EnsureClassIconFrame(UI.target.wnd, "target")
    EnsureClassIconFrame(UI.watchtarget.wnd, "watchtarget")
    EnsureClassIconFrame(UI.target_of_target.wnd, "targettarget")
end

local function ResetClassIconFrames()
    ResetClassIconFrame(UI.player.wnd)
    ResetClassIconFrame(UI.target.wnd)
    ResetClassIconFrame(UI.watchtarget.wnd)
    ResetClassIconFrame(UI.target_of_target.wnd)
end

local function MatchesLevelArtifactPattern(key)
    local lower = string.lower(tostring(key or ""))
    for _, pattern in ipairs(STOCK_LEVEL_ARTIFACT_PATTERNS) do
        if string.find(lower, pattern, 1, true) ~= nil then
            return true
        end
    end
    return false
end

local function ApplyLevelArtifactHide(levelRoot, hidden)
    if type(levelRoot) ~= "table" then
        return
    end

    local seen = {}

    local function hideWidget(widget)
        widget = ResolveWidgetCandidate(widget)
        if widget == nil or seen[widget] then
            return
        end
        seen[widget] = true
        SetWidgetForcedHidden(widget, hidden)
    end

    local function visit(node, key, depth)
        if type(node) ~= "table" or (tonumber(depth) or 0) > 5 then
            return
        end

        local lower = string.lower(tostring(key or ""))
        if lower == "icon" or lower == "bg" or lower == "gradeicon" or MatchesLevelArtifactPattern(lower) then
            hideWidget(node)
        end

        for nestedKey, nestedValue in pairs(node) do
            if nestedKey ~= "style" and nestedKey ~= "label" and type(nestedValue) == "table" then
                visit(nestedValue, nestedKey, (tonumber(depth) or 0) + 1)
            end
        end
    end

    visit(levelRoot, "level", 0)
end

local function InvokeFrameMethod(frame, methodName, ...)
    if frame == nil or type(methodName) ~= "string" then
        return false
    end

    local fn = frame["__polar_orig_" .. methodName]
    if type(fn) ~= "function" then
        fn = frame[methodName]
    end
    if type(fn) ~= "function" then
        return false
    end

    local args = { ... }
    return pcall(function()
        fn(frame, unpack(args))
    end)
end

local function EnsureTargetFallbackBarBackground(frame, key)
    if frame == nil or UI == nil or UI.target == nil or frame ~= UI.target.wnd then
        return nil
    end

    local stateKey = "custom_" .. tostring(key or "") .. "_bg"
    if UI.target[stateKey] ~= nil then
        return UI.target[stateKey]
    end

    local bg = nil
    pcall(function()
        if frame.CreateColorDrawable ~= nil then
            bg = frame:CreateColorDrawable(0, 0, 0, 0.72, "background")
        elseif frame.CreateNinePartDrawable ~= nil and TEXTURE_PATH ~= nil and TEXTURE_PATH.HUD ~= nil then
            bg = frame:CreateNinePartDrawable(TEXTURE_PATH.HUD, "background")
            if bg.SetTextureInfo ~= nil then
                bg:SetTextureInfo("bg_quest")
            end
            if bg.SetColor ~= nil then
                bg:SetColor(0, 0, 0, 0.72)
            end
        end
    end)

    if bg == nil then
        return nil
    end

    pcall(function()
        if bg.AddAnchor ~= nil then
            bg:AddAnchor("TOPLEFT", frame, -8, -6)
            bg:AddAnchor("BOTTOMRIGHT", frame, 8, 6)
        end
    end)
    pcall(function()
        SetNotClickable(bg)
    end)
    pcall(function()
        if bg.Show ~= nil then
            bg:Show(false)
        end
    end)

    UI.target[stateKey] = bg
    table.insert(UI.created, bg)
    return bg
end

local function ApplyTargetFallbackBackgroundStyle(frame, style, visible)
    if frame == nil or UI == nil or UI.target == nil or frame ~= UI.target.wnd then
        return
    end

    local showBg = visible and true or false
    local function resolveColor(rgba, fallback)
        local r, g, b, a = 0.02, 0.02, 0.02, 0.62
        if type(fallback) == "table" then
            r = ColorFrom255(fallback[1] or 0)
            g = ColorFrom255(fallback[2] or 0)
            b = ColorFrom255(fallback[3] or 0)
            a = 0.52
        end
        if type(rgba) == "table" then
            r = ColorFrom255(rgba[1] or 0)
            g = ColorFrom255(rgba[2] or 0)
            b = ColorFrom255(rgba[3] or 0)
            local rawAlpha = tonumber(rgba[4])
            if rawAlpha == nil or rawAlpha < 32 then
                a = 0.52
            else
                a = ColorFrom255(rawAlpha)
                if a < 0.40 then
                    a = 0.40
                elseif a > 0.78 then
                    a = 0.78
                end
            end
        end
        return r, g, b, a
    end

    local function anchorBackground(bg, bar)
        if bg == nil or bar == nil or bg.AddAnchor == nil then
            return
        end
        pcall(function()
            if bg.RemoveAllAnchors ~= nil then
                bg:RemoveAllAnchors()
            end
            local okTop = pcall(function()
                bg:AddAnchor("TOPLEFT", bar, "TOPLEFT", -2, -1)
            end)
            if not okTop then
                pcall(function()
                    bg:AddAnchor("TOPLEFT", bar, -2, -1)
                end)
            end
            local okBottom = pcall(function()
                bg:AddAnchor("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 2, 1)
            end)
            if not okBottom then
                pcall(function()
                    bg:AddAnchor("BOTTOMRIGHT", bar, 2, 1)
                end)
            end
        end)
    end

    local function applyBarBackground(barKey, barWidget, colorKey, fallbackKey)
        local bg = EnsureTargetFallbackBarBackground(frame, barKey)
        if bg == nil then
            return
        end

        anchorBackground(bg, barWidget)

        local r, g, b, a = 0.02, 0.02, 0.02, 0.62
        if type(style) == "table" and style.bar_colors_enabled then
            r, g, b, a = resolveColor(style[colorKey], style[fallbackKey])
        end

        pcall(function()
            SetNotClickable(bg)
        end)
        pcall(function()
            if bg.SetColor ~= nil then
                bg:SetColor(r, g, b, showBg and a or 0)
            end
        end)
        pcall(function()
            if bg.SetAlpha ~= nil then
                bg:SetAlpha(showBg and 1 or 0)
            end
        end)
        pcall(function()
            if bg.Show ~= nil then
                bg:Show(showBg and barWidget ~= nil)
            end
        end)
    end

    applyBarBackground("hp", frame.hpBar, "hp_after_color", "hp_bar_color")
    applyBarBackground("mp", frame.mpBar, "mp_after_color", "mp_bar_color")
end


local function ClearTargetOverlayWidget(widget)
    if widget == nil then
        return
    end
    if widget.SetText ~= nil then
        widget:SetText("")
        widget.__polar_text = ""
    end
    if widget.Show ~= nil then
        widget:Show(false)
        widget.__polar_visible = false
    end
end

local function ClearTargetOverlayText()
    ClearTargetOverlayWidget(UI.target.guild)
    ClearTargetOverlayWidget(UI.target.class_name)
    ClearTargetOverlayWidget(UI.target.gearscore)
    ClearTargetOverlayWidget(UI.target.pdef)
    ClearTargetOverlayWidget(UI.target.mdef)
end

local function ClampNumber(v, minV, maxV, fallback)
    local n = tonumber(v)
    if n == nil then
        return fallback
    end
    if n < minV then
        return minV
    end
    if n > maxV then
        return maxV
    end
    return n
end

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

local function MergeStyleTables(base, override)
    local out = {}
    if type(base) == "table" then
        for k, v in pairs(base) do
            if k ~= "frames" and k ~= "buff_windows" and k ~= "aura" then
                out[k] = DeepCopyTable(v)
            end
        end
        if type(base.buff_windows) == "table" then
            out.buff_windows = DeepCopyTable(base.buff_windows)
        end
        if type(base.aura) == "table" then
            out.aura = DeepCopyTable(base.aura)
        end
    end

    if type(override) == "table" then
        for k, v in pairs(override) do
            if k ~= "frames" and k ~= "buff_windows" and k ~= "aura" then
                out[k] = DeepCopyTable(v)
            end
        end
    end
    return out
end

local function GetOrCreatePosTable(settings, key)
    if type(settings) ~= "table" then
        return nil
    end
    if type(settings[key]) ~= "table" then
        settings[key] = {}
    end
    return settings[key]
end

local function SafeGetOffset(wnd)
    if Layout ~= nil and type(Layout.ReadScreenOffset) == "function" then
        return Layout.ReadScreenOffset(wnd)
    end
    local ok, x, y = pcall(function()
        return wnd:GetEffectiveOffset()
    end)
    if ok and tonumber(x) ~= nil and tonumber(y) ~= nil then
        return tonumber(x), tonumber(y)
    end
    if wnd == nil or wnd.GetOffset == nil then
        return nil, nil
    end
    ok, x, y = pcall(function()
        return wnd:GetOffset()
    end)
    if not ok or tonumber(x) == nil or tonumber(y) == nil then
        return nil, nil
    end
    if Layout ~= nil and type(Layout.ToScreen) == "function" then
        return Layout.ToScreen(x), Layout.ToScreen(y)
    end
    return tonumber(x), tonumber(y)
end

local function SaveSettingsToFile(settings)
    if type(settings) ~= "table" then
        return
    end

    pcall(function()
        if type(settings.nameplates) ~= "table" or type(settings.nameplates.guild_colors) ~= "table" then
            return
        end
        local gc = settings.nameplates.guild_colors
        local moves = {}
        for k, v in pairs(gc) do
            local key = tostring(k or "")
            key = string.match(key, "^%s*(.-)%s*$") or key
            local norm = string.lower(key)
            norm = string.gsub(norm, "%s+", "_")
            norm = string.gsub(norm, "[^%w_]", "")
            if norm ~= "" and string.match(norm, "^%d") ~= nil then
                norm = "_" .. norm
            end
            if norm ~= "" and norm ~= key then
                table.insert(moves, { from = k, to = norm, val = v })
            end
        end
        for _, m in ipairs(moves) do
            if gc[m.to] == nil then
                gc[m.to] = m.val
            end
            gc[m.from] = nil
        end
    end)

    if SettingsStore ~= nil and type(SettingsStore.SaveSettingsFile) == "function" then
        SettingsStore.SaveSettingsFile(settings)
        return
    end

    api.SaveSettings()
    if api.File ~= nil and api.File.Write ~= nil then
        pcall(function()
            api.File:Write("nuzi-ui/.data/settings.txt", settings)
        end)
    end
end

local function ApplyUnitFramePosition(wnd, settings, key, defaultX, defaultY)
    if wnd == nil or type(settings) ~= "table" then
        return
    end

    local pos = GetOrCreatePosTable(settings, key)
    if pos == nil then
        return
    end

    local x = tonumber(pos.x)
    local y = tonumber(pos.y)
    if x == nil or y == nil then
        pos.x = ClampNumber(defaultX, -5000, 5000, 10)
        pos.y = ClampNumber(defaultY, -5000, 5000, 300)
        SaveSettingsToFile(settings)
        x = tonumber(pos.x)
        y = tonumber(pos.y)
    end

    x = ClampNumber(x, -5000, 5000, 10)
    y = ClampNumber(y, -5000, 5000, 300)

    if math.abs(x) > 3000 or math.abs(y) > 3000 then
        pos.x = ClampNumber(defaultX, -5000, 5000, 10)
        pos.y = ClampNumber(defaultY, -5000, 5000, 300)
        SaveSettingsToFile(settings)
        x = tonumber(pos.x)
        y = tonumber(pos.y)
    end

    if wnd.__polar_dragging then
        return
    end

    local curX, curY = SafeGetOffset(wnd)
    local drifted = false
    if curX ~= nil and curY ~= nil then
        drifted = (math.abs(curX - x) > 0.5) or (math.abs(curY - y) > 0.5)
    else
        drifted = true
    end

    if wnd.__polar_last_pos_x ~= x or wnd.__polar_last_pos_y ~= y or drifted then
        pcall(function()
            if wnd.RemoveAllAnchors ~= nil then
                wnd:RemoveAllAnchors()
            end
            AnchorTopLeft(wnd, x, y)
        end)
        wnd.__polar_last_pos_x = x
        wnd.__polar_last_pos_y = y
    end
end

local function SetFramePositionHook(frame, settings, key, defaultX, defaultY)
    if frame == nil or type(settings) ~= "table" then
        return
    end

    frame.__polar_pos_cfg = {
        settings = settings,
        key = key,
        default_x = defaultX,
        default_y = defaultY
    }

    if frame.__polar_pos_hooked then
        return
    end
    frame.__polar_pos_hooked = true

    local function wrap(methodName)
        if type(frame[methodName]) ~= "function" then
            return
        end
        local origKey = "__polar_orig_" .. methodName
        if type(frame[origKey]) == "function" then
            return
        end

        frame[origKey] = frame[methodName]
        frame[methodName] = function(self, ...)
            local out = nil
            local orig = self[origKey]
            if type(orig) == "function" then
                out = orig(self, ...)
            end

            local cfg = self.__polar_pos_cfg
            if type(cfg) == "table" and not self.__polar_dragging then
                ApplyUnitFramePosition(self, cfg.settings, cfg.key, cfg.default_x, cfg.default_y)
            end
            return out
        end
    end

    pcall(function()
        wrap("ApplyLastWindowOffset")
        wrap("ApplyLastWindowBound")
        wrap("ApplyLastWindowExtent")
        wrap("MakeOriginWindowPos")
        wrap("OnMovedPosition")
    end)
end

local SyncUnitFrameDragState

local function HookUnitFrameDrag(wnd, settings, key)
    if wnd == nil or type(settings) ~= "table" then
        return
    end
    wnd.__polar_drag_settings = settings
    local hookTarget = wnd
    if wnd.eventWindow ~= nil then
        hookTarget = wnd.eventWindow
    end

    local hookTargets = { hookTarget }
    wnd.__polar_drag_targets = hookTargets

    if not wnd.__polar_drag_hooked then
        wnd.__polar_drag_hooked = true

        local origStart = nil
        local origStop = nil
        if type(hookTarget.OnDragStart) == "function" then
            origStart = hookTarget.OnDragStart
        end
        if type(hookTarget.OnDragStop) == "function" then
            origStop = hookTarget.OnDragStop
        end

        wnd.__polar_drag_start = function(self, ...)
            local activeSettings = wnd.__polar_drag_settings or settings
            if activeSettings.drag_requires_shift then
                if api.Input ~= nil and api.Input.IsShiftKeyDown ~= nil and not api.Input:IsShiftKeyDown() then
                    return
                end
            end
            wnd.__polar_dragging = true
            local args = { ... }
            local unpackFn = nil
            if table ~= nil and type(table.unpack) == "function" then
                unpackFn = table.unpack
            elseif type(unpack) == "function" then
                unpackFn = unpack
            end
            if origStart ~= nil then
                pcall(function()
                    if unpackFn ~= nil then
                        origStart(self, unpackFn(args))
                    else
                        origStart(self)
                    end
                end)
            elseif wnd.StartMoving ~= nil then
                pcall(function()
                    wnd:StartMoving()
                end)
            elseif self.StartMoving ~= nil then
                pcall(function()
                    self:StartMoving()
                end)
            end
        end

        wnd.__polar_drag_stop = function(self, ...)
            if not wnd.__polar_dragging then
                return
            end
            local args = { ... }
            local unpackFn = nil
            if table ~= nil and type(table.unpack) == "function" then
                unpackFn = table.unpack
            elseif type(unpack) == "function" then
                unpackFn = unpack
            end

            local beforeX, beforeY = SafeGetOffset(wnd)
            if origStop ~= nil then
                pcall(function()
                    if unpackFn ~= nil then
                        origStop(self, unpackFn(args))
                    else
                        origStop(self)
                    end
                end)
            elseif wnd.StopMovingOrSizing ~= nil then
                pcall(function()
                    wnd:StopMovingOrSizing()
                end)
            elseif self.StopMovingOrSizing ~= nil then
                pcall(function()
                    self:StopMovingOrSizing()
                end)
            end

            wnd.__polar_dragging = nil

            local afterX, afterY = SafeGetOffset(wnd)
            local saveX, saveY = afterX, afterY
            if saveX == nil or saveY == nil then
                saveX, saveY = beforeX, beforeY
            end

            if saveX == nil or saveY == nil then
                return
            end

            local activeSettings = wnd.__polar_drag_settings or settings
            local pos = GetOrCreatePosTable(activeSettings, key)
            if pos == nil then
                return
            end
            pos.x = saveX
            pos.y = saveY
            SaveSettingsToFile(activeSettings)

            wnd.__polar_last_pos_x = saveX
            wnd.__polar_last_pos_y = saveY
        end
    end

    pcall(function()
        for _, t in ipairs(hookTargets) do
            if t ~= nil and t.SetHandler ~= nil then
                t:SetHandler("OnDragStart", wnd.__polar_drag_start)
                t:SetHandler("OnDragStop", wnd.__polar_drag_stop)
            end
            if t ~= nil and t.RegisterForDrag ~= nil then
                t:RegisterForDrag("LeftButton")
            end
        end
    end)
    SyncUnitFrameDragState(wnd, settings)
end

SyncUnitFrameDragState = function(wnd, settings)
    if wnd == nil or type(wnd.__polar_drag_targets) ~= "table" then
        return
    end

    local enabled = UI.enabled and type(settings) == "table"
    if enabled and settings.drag_requires_shift then
        enabled = api.Input ~= nil and api.Input.IsShiftKeyDown ~= nil and api.Input:IsShiftKeyDown() and true or false
    end

    for _, t in ipairs(wnd.__polar_drag_targets) do
        if t ~= nil and t.EnableDrag ~= nil and t.__polar_drag_enabled ~= enabled then
            local ok = pcall(function()
                t:EnableDrag(enabled)
            end)
            if ok then
                t.__polar_drag_enabled = enabled
            end
        end
    end
end

local function SyncAllUnitFrameDragState(settings)
    SyncUnitFrameDragState(UI.player.wnd, settings)
    SyncUnitFrameDragState(UI.target.wnd, settings)
    SyncUnitFrameDragState(UI.watchtarget.wnd, settings)
    SyncUnitFrameDragState(UI.target_of_target.wnd, settings)
end

local function GetStockContent(contentId)
    if Runtime ~= nil and Runtime.GetStockContent ~= nil then
        return Runtime.GetStockContent(contentId)
    end
    return nil
end

local function SetStockDistanceLabelVisible(visible)
    if UI.target.wnd == nil or UI.target.wnd.distanceLabel == nil then
        return
    end
    pcall(function()
        local w = UI.target.wnd.distanceLabel
        if SetNotClickable ~= nil then
            SetNotClickable(w)
        end
        if w.SetAlpha ~= nil then
            w:SetAlpha(visible and 1 or 0)
        end
        if w.Show ~= nil then
            w:Show(visible and true or false)
        end
    end)
end

ColorFrom255 = function(v)
    local n = tonumber(v)
    if n == nil then
        return 1
    end
    if n < 0 then
        n = 0
    elseif n > 255 then
        n = 255
    end
    return n / 255
end

local BAR_STYLE_STATE = {
    orig_statusbar = {}
}

BAR_STYLE_STATE.orig_statusbar.__captured = false

local function NormalizeColor255(rgba, fallback)
    local source = type(rgba) == "table" and rgba or fallback
    if type(source) ~= "table" then
        return { 255, 255, 255, 255 }
    end
    local out = {}
    for i = 1, 4 do
        local value = tonumber(source[i])
        if value == nil then
            value = 255
        elseif value >= 0 and value <= 1 then
            value = value * 255
        end
        if value < 0 then
            value = 0
        elseif value > 255 then
            value = 255
        end
        out[i] = math.floor(value + 0.5)
    end
    return out
end

local function ApplyBarColorState(bar, fillColor, afterColor)
    if bar == nil then
        return
    end

    local fill = NormalizeColor255(fillColor)
    local after = NormalizeColor255(afterColor, fill)
    local fillSig = table.concat(fill, ":")
    local afterSig = table.concat(after, ":")

    if bar.__polar_fill_sig ~= fillSig then
        SetStatusBarFillColor(bar, fill)
        bar.__polar_fill_sig = fillSig
    end
    if bar.__polar_after_sig ~= afterSig then
        SetStatusBarAfterColor(bar, after)
        bar.__polar_after_sig = afterSig
    end
end

local function InvalidateBarColorState(bar)
    if bar == nil then
        return
    end
    bar.__polar_fill_sig = nil
    bar.__polar_after_sig = nil
end

local function BuildTextureAfterColorValues(template, rgba)
    if type(rgba) ~= "table" then
        return nil
    end
    local c = NormalizeColor255(rgba)
    if type(template) == "table" and type(template[1]) == "number" and template[1] > 1 then
        return { c[1], c[2], c[3], c[4] }
    end
    return {
        ColorFrom255(c[1]),
        ColorFrom255(c[2]),
        ColorFrom255(c[3]),
        ColorFrom255(c[4])
    }
end

local function GetTextureAfterColor255(textureInfo, fallback)
    if type(textureInfo) ~= "table" then
        return NormalizeColor255(fallback)
    end
    if type(textureInfo.afterImage_color_up) == "table" then
        return NormalizeColor255(textureInfo.afterImage_color_up, fallback)
    end
    if type(textureInfo.afterImage_color_down) == "table" then
        return NormalizeColor255(textureInfo.afterImage_color_down, fallback)
    end
    return NormalizeColor255(fallback)
end

local function SetAnyWidgetColor(widget, rgba)
    if widget == nil or type(rgba) ~= "table" then
        return
    end
    local r = ColorFrom255(rgba[1])
    local g = ColorFrom255(rgba[2])
    local b = ColorFrom255(rgba[3])
    local a = ColorFrom255(rgba[4] or 255)
    pcall(function()
        if widget.SetBarColor ~= nil then
            widget:SetBarColor(r, g, b, a)
        end
    end)
    pcall(function()
        if widget.SetColor ~= nil then
            widget:SetColor(r, g, b, a)
        end
    end)
    pcall(function()
        if widget.SetLayerColor ~= nil then
            widget:SetLayerColor(r, g, b, a)
        end
    end)
end

local function SetStatusBarFillColor(bar, rgba)
    if bar == nil then
        return
    end
    local target = bar.statusBar or bar
    pcall(function()
        SetAnyWidgetColor(target, rgba)
    end)
end

local function SetStatusBarAfterColor(bar, rgba)
    if bar == nil or type(rgba) ~= "table" then
        return
    end

    local function afterColorValues(texInfo)
        local existing = nil
        if texInfo ~= nil and type(texInfo.afterImage_color_up) == "table" then
            existing = texInfo.afterImage_color_up
        elseif texInfo ~= nil and type(texInfo.afterImage_color_down) == "table" then
            existing = texInfo.afterImage_color_down
        end

        if type(existing) == "table" and type(existing[1]) == "number" and existing[1] > 1 then
            return {
                tonumber(rgba[1]) or 0,
                tonumber(rgba[2]) or 0,
                tonumber(rgba[3]) or 0,
                tonumber(rgba[4] or 255) or 255
            }
        end
        return {
            ColorFrom255(rgba[1]),
            ColorFrom255(rgba[2]),
            ColorFrom255(rgba[3]),
            ColorFrom255(rgba[4] or 255)
        }
    end

    pcall(function()
        if bar.statusBarAfterImage ~= nil then
            SetAnyWidgetColor(bar.statusBarAfterImage, rgba)
        end
    end)

    pcall(function()
        if bar.textureInfo ~= nil and type(bar.textureInfo) == "table" then
            local c = afterColorValues(bar.textureInfo)
            if type(bar.textureInfo.afterImage_color_up) == "table" then
                bar.textureInfo.afterImage_color_up = c
            end
            if type(bar.textureInfo.afterImage_color_down) == "table" then
                bar.textureInfo.afterImage_color_down = c
            end
        end
    end)

    pcall(function()
        if bar.ChangeAfterImageColor ~= nil then
            bar:ChangeAfterImageColor()
        end
    end)
end

local function SetStatusBarDynamicState(bar, enabled)
    if bar == nil then
        return
    end

    local widgets = {
        bar,
        bar.statusBar,
        bar.statusBarAfterImage
    }

    for _, widget in ipairs(widgets) do
        pcall(function()
            if widget ~= nil and widget.UseDynamicContentState ~= nil then
                widget:UseDynamicContentState(enabled and true or false)
            end
        end)
        -- Status bars expose UseDynamicDrawableState(nameLayer, use), but
        -- we do not have a stable layer contract for these widgets.
        -- Passing the boolean directly just spams client-side type errors.
    end
end

local function ApplyLegacyStockBarStyle(frame, style, statusbar_style)
    local function to01(c)
        if type(c) == "table" then
            return {
                ColorFrom255(c[1]),
                ColorFrom255(c[2]),
                ColorFrom255(c[3]),
                ColorFrom255(c[4] or 255)
            }
        end
        return { 1, 1, 1, 1 }
    end

    local function getColor01(key, fallbackKey)
        if type(style[key]) == "table" then
            return to01(style[key])
        end
        if type(style[fallbackKey]) == "table" then
            return to01(style[fallbackKey])
        end
        return { 1, 1, 1, 1 }
    end

    local hpFill01 = getColor01("hp_fill_color", "hp_bar_color")
    local mpFill01 = getColor01("mp_fill_color", "mp_bar_color")
    local hpAfter01 = getColor01("hp_after_color", "hp_bar_color")
    local mpAfter01 = getColor01("mp_after_color", "mp_bar_color")
    local hostileTargetHpColor = NormalizeColor255(style.hostile_target_hp_color, { 255, 54, 40, 255 })

    local LARGE_BAR_COORDS = { 0, 120, 300, 19 }
    local SMALL_BAR_COORDS = { 301, 120, 150, 19 }

    local function setStatusBarStyle(key, coords, afterUp, afterDown)
        if statusbar_style == nil or type(statusbar_style) ~= "table" then
            return
        end
        if statusbar_style[key] == nil or type(statusbar_style[key]) ~= "table" then
            statusbar_style[key] = {}
        end
        statusbar_style[key].coords = coords
        statusbar_style[key].afterImage_color_up = afterUp
        statusbar_style[key].afterImage_color_down = afterDown
    end

    local keys = {
        "L_HP_FRIENDLY",
        "S_HP_FRIENDLY",
        "L_HP_HOSTILE",
        "S_HP_HOSTILE",
        "L_HP_NEUTRAL",
        "S_HP_NEUTRAL",
        "L_MP",
        "S_MP"
    }

    if statusbar_style ~= nil and type(statusbar_style) == "table" and not BAR_STYLE_STATE.orig_statusbar.__captured then
        for _, k in ipairs(keys) do
            local t = statusbar_style[k]
            if type(t) == "table" then
                BAR_STYLE_STATE.orig_statusbar[k] = {
                    coords = t.coords,
                    afterImage_color_up = t.afterImage_color_up,
                    afterImage_color_down = t.afterImage_color_down
                }
            else
                BAR_STYLE_STATE.orig_statusbar[k] = {
                    coords = nil,
                    afterImage_color_up = nil,
                    afterImage_color_down = nil
                }
            end
        end
        BAR_STYLE_STATE.orig_statusbar.__captured = true
    end

    local colorsEnabled = (style.bar_colors_enabled and true or false)
    local mode = tostring(style.hp_texture_mode or "stock")

    local function coordsFor(key, betterCoords)
        local keepOrig = (mode == "stock")
        if type(key) == "string" and string.sub(key, 1, 2) == "S_" then
            keepOrig = true
        end
        if keepOrig and BAR_STYLE_STATE.orig_statusbar.__captured then
            local o = BAR_STYLE_STATE.orig_statusbar[key]
            if type(o) == "table" and type(o.coords) == "table" then
                return o.coords
            end
        end
        return betterCoords
    end

    if statusbar_style ~= nil and type(statusbar_style) == "table" and BAR_STYLE_STATE.orig_statusbar.__captured then
        local function afterColorsFor(key, custom01)
            if colorsEnabled then
                return custom01, custom01
            end
            local orig = BAR_STYLE_STATE.orig_statusbar[key]
            if type(orig) == "table" then
                return orig.afterImage_color_up, orig.afterImage_color_down
            end
            return custom01, custom01
        end

        local hpUp, hpDown = afterColorsFor("L_HP_FRIENDLY", hpAfter01)
        setStatusBarStyle("L_HP_FRIENDLY", coordsFor("L_HP_FRIENDLY", LARGE_BAR_COORDS), hpUp, hpDown)
        hpUp, hpDown = afterColorsFor("S_HP_FRIENDLY", hpAfter01)
        setStatusBarStyle("S_HP_FRIENDLY", coordsFor("S_HP_FRIENDLY", SMALL_BAR_COORDS), hpUp, hpDown)
        hpUp, hpDown = afterColorsFor("L_HP_HOSTILE", hpAfter01)
        setStatusBarStyle("L_HP_HOSTILE", coordsFor("L_HP_HOSTILE", LARGE_BAR_COORDS), hpUp, hpDown)
        hpUp, hpDown = afterColorsFor("S_HP_HOSTILE", hpAfter01)
        setStatusBarStyle("S_HP_HOSTILE", coordsFor("S_HP_HOSTILE", SMALL_BAR_COORDS), hpUp, hpDown)
        hpUp, hpDown = afterColorsFor("L_HP_NEUTRAL", hpAfter01)
        setStatusBarStyle("L_HP_NEUTRAL", coordsFor("L_HP_NEUTRAL", LARGE_BAR_COORDS), hpUp, hpDown)
        hpUp, hpDown = afterColorsFor("S_HP_NEUTRAL", hpAfter01)
        setStatusBarStyle("S_HP_NEUTRAL", coordsFor("S_HP_NEUTRAL", SMALL_BAR_COORDS), hpUp, hpDown)

        local mpUp, mpDown = afterColorsFor("L_MP", mpAfter01)
        setStatusBarStyle("L_MP", coordsFor("L_MP", LARGE_BAR_COORDS), mpUp, mpDown)
        mpUp, mpDown = afterColorsFor("S_MP", mpAfter01)
        setStatusBarStyle("S_MP", coordsFor("S_MP", SMALL_BAR_COORDS), mpUp, mpDown)
    end

    if frame.__polar_last_hp_texture_mode ~= mode then
        frame.__polar_last_hp_texture_mode = mode
        if mode == "pc" then
            pcall(function()
                frame:ChangeHpBarTexture_forPc()
            end)
        elseif mode == "npc" then
            pcall(function()
                frame:ChangeHpBarTexture_forNpc()
            end)
        end
    end

    local function buildUnitTokens(unit)
        local token = tostring(unit or "")
        if token == "" then
            return {}
        end
        local out = { token }
        local function addToken(alias)
            for i = 1, #out do
                if out[i] == alias then
                    return
                end
            end
            out[#out + 1] = alias
        end
        if token == "target_of_target" or token == "targetoftarget" or token == "targettarget" then
            addToken("targetoftarget")
            addToken("target_of_target")
            addToken("targettarget")
        end
        return out
    end

    local function isHostileUnit(unit)
        if api == nil or api.Unit == nil then
            return false
        end
        local tokens = buildUnitTokens(unit)
        if #tokens == 0 then
            return false
        end
        local tid = nil
        for _, token in ipairs(tokens) do
            tid = api.Unit:GetUnitId(token)
            if tid ~= nil then
                break
            end
        end
        if tid == nil then
            return false
        end
        local info = SafeGetUnitInfoById(tid)
        return type(info) == "table" and tostring(info.faction) == "hostile"
    end

    local function usesSmallHpMp()
        return frame.__polar_small_hpmp and true or false
    end

    local function usesCustomSmallFrameTexture()
        if not usesSmallHpMp() or mode == "stock" then
            return false
        end
        local unit = tostring(frame.__polar_unit or "")
        return unit == "watchtarget" or unit == "targettarget"
    end

    local function buildPerFrameTextureInfo(styleKey, afterColor)
        if not usesCustomSmallFrameTexture() or statusbar_style == nil or type(statusbar_style) ~= "table" then
            return nil
        end
        local src = statusbar_style[styleKey]
        if type(src) ~= "table" then
            return nil
        end
        local out = DeepCopyTable(src)
        out.coords = SMALL_BAR_COORDS
        if colorsEnabled then
            local up = BuildTextureAfterColorValues(out.afterImage_color_up, afterColor)
            local down = BuildTextureAfterColorValues(out.afterImage_color_down, afterColor)
            if up ~= nil and type(out.afterImage_color_up) == "table" then
                out.afterImage_color_up = up
            end
            if down ~= nil and type(out.afterImage_color_down) == "table" then
                out.afterImage_color_down = down
            end
        end
        return out
    end

    local function getHpStyleKey(hostile)
        local small = usesSmallHpMp()
        if mode == "pc" then
            if small and statusbar_style ~= nil and statusbar_style.S_HP_PARTY ~= nil then
                return "S_HP_PARTY"
            end
            if (not small) and statusbar_style ~= nil and statusbar_style.L_HP_PARTY ~= nil then
                return "L_HP_PARTY"
            end
            return small and "S_HP_FRIENDLY" or "L_HP_FRIENDLY"
        end
        if mode == "npc" then
            if hostile then
                return small and "S_HP_HOSTILE" or "L_HP_HOSTILE"
            end
            if small and statusbar_style ~= nil and statusbar_style.S_HP_NEUTRAL ~= nil then
                return "S_HP_NEUTRAL"
            end
            if (not small) and statusbar_style ~= nil and statusbar_style.L_HP_NEUTRAL ~= nil then
                return "L_HP_NEUTRAL"
            end
            return small and "S_HP_FRIENDLY" or "L_HP_FRIENDLY"
        end
        if tostring(frame.__polar_unit) == "player" then
            if small and statusbar_style ~= nil and statusbar_style.S_HP_PARTY ~= nil then
                return "S_HP_PARTY"
            end
            if (not small) and statusbar_style ~= nil and statusbar_style.L_HP_PARTY ~= nil then
                return "L_HP_PARTY"
            end
        end
        return hostile and (small and "S_HP_HOSTILE" or "L_HP_HOSTILE") or (small and "S_HP_FRIENDLY" or "L_HP_FRIENDLY")
    end

    local frameUnit = ResolveFrameRuntimeUnit(frame) or frame.__polar_unit
    local frameHostile = isHostileUnit(frameUnit)
    local hostileTargetHpEnabled = style.hostile_target_hp_enabled == true
        and IsHostileHpOverrideUnit(frameUnit)
        and frameHostile

    pcall(function()
        if frame.hpBar ~= nil then
            if statusbar_style ~= nil and type(statusbar_style) == "table" then
                local hpKey = getHpStyleKey(frameHostile)
                local textureInfo = buildPerFrameTextureInfo(hpKey, hpAfter01) or statusbar_style[hpKey]
                frame.hpBar:ApplyBarTexture(textureInfo)
            else
                frame.hpBar:ApplyBarTexture()
            end
        end
    end)
    pcall(function()
        if frame.mpBar ~= nil then
            if statusbar_style ~= nil and type(statusbar_style) == "table" then
                local mpKey = usesSmallHpMp() and "S_MP" or "L_MP"
                local textureInfo = buildPerFrameTextureInfo(mpKey, mpAfter01) or statusbar_style[mpKey]
                frame.mpBar:ApplyBarTexture(textureInfo)
            else
                frame.mpBar:ApplyBarTexture()
            end
        end
    end)

    pcall(function()
        SetStatusBarDynamicState(frame.hpBar, not (colorsEnabled or hostileTargetHpEnabled))
    end)
    pcall(function()
        SetStatusBarDynamicState(frame.mpBar, not colorsEnabled)
    end)

    if not colorsEnabled and not hostileTargetHpEnabled then
        return
    end

    local function setFill(statusBar, c01)
        if statusBar == nil or type(c01) ~= "table" then
            return
        end
        pcall(function()
            statusBar:SetBarColor(c01[1], c01[2], c01[3], c01[4])
        end)
        pcall(function()
            statusBar:SetColor(c01[1], c01[2], c01[3], c01[4])
        end)
    end

    pcall(function()
        if frame.hpBar ~= nil and frame.hpBar.statusBar ~= nil then
            setFill(frame.hpBar.statusBar, hpFill01)
        end
    end)
    pcall(function()
        if frame.mpBar ~= nil and frame.mpBar.statusBar ~= nil then
            setFill(frame.mpBar.statusBar, mpFill01)
        end
    end)

    local function setAnyColor(widget, rgba)
        if widget == nil or type(rgba) ~= "table" then
            return
        end
        local r = ColorFrom255(rgba[1])
        local g = ColorFrom255(rgba[2])
        local b = ColorFrom255(rgba[3])
        local a = ColorFrom255(rgba[4] or 255)
        pcall(function()
            widget:SetBarColor(r, g, b, a)
        end)
        pcall(function()
            widget:SetColor(r, g, b, a)
        end)
    end

    local function setBarFillColor(bar, rgba)
        if bar == nil then
            return
        end
        pcall(function()
            if bar.statusBar ~= nil then
                setAnyColor(bar.statusBar, rgba)
            end
        end)
        pcall(function()
            setAnyColor(bar, rgba)
        end)
    end

    local function setBarAfterColor(bar, rgba)
        if bar == nil then
            return
        end

        local function afterColorValues(texInfo)
            local existing = nil
            if texInfo ~= nil and type(texInfo.afterImage_color_up) == "table" then
                existing = texInfo.afterImage_color_up
            elseif texInfo ~= nil and type(texInfo.afterImage_color_down) == "table" then
                existing = texInfo.afterImage_color_down
            end
            if type(existing) == "table" and type(existing[1]) == "number" and existing[1] > 1 then
                return {
                    tonumber(rgba[1]) or 0,
                    tonumber(rgba[2]) or 0,
                    tonumber(rgba[3]) or 0,
                    tonumber(rgba[4] or 255) or 255
                }
            end
            return {
                ColorFrom255(rgba[1]),
                ColorFrom255(rgba[2]),
                ColorFrom255(rgba[3]),
                ColorFrom255(rgba[4] or 255)
            }
        end

        pcall(function()
            if bar.statusBarAfterImage ~= nil then
                setAnyColor(bar.statusBarAfterImage, rgba)
            end
        end)

        pcall(function()
            if bar.textureInfo ~= nil and type(bar.textureInfo) == "table" then
                local c = afterColorValues(bar.textureInfo)
                if type(bar.textureInfo.afterImage_color_up) == "table" then
                    bar.textureInfo.afterImage_color_up = c
                end
                if type(bar.textureInfo.afterImage_color_down) == "table" then
                    bar.textureInfo.afterImage_color_down = c
                end
            end
        end)

        pcall(function()
            if bar.ChangeAfterImageColor ~= nil then
                bar:ChangeAfterImageColor()
            end
        end)
    end

    local function resolveColor(key, fallbackKey)
        if type(style[key]) == "table" then
            return style[key]
        end
        if type(style[fallbackKey]) == "table" then
            return style[fallbackKey]
        end
        return nil
    end

    local hpFill = hostileTargetHpEnabled and hostileTargetHpColor or resolveColor("hp_fill_color", "hp_bar_color")
    local hpAfter = hostileTargetHpEnabled and hostileTargetHpColor or resolveColor("hp_after_color", "hp_bar_color")
    local mpFill = resolveColor("mp_fill_color", "mp_bar_color")
    local mpAfter = resolveColor("mp_after_color", "mp_bar_color")

    pcall(function()
        if frame.hpBar ~= nil and (colorsEnabled or hostileTargetHpEnabled) then
            if hpFill ~= nil then
                setBarFillColor(frame.hpBar, hpFill)
            end
            if hpAfter ~= nil then
                setBarAfterColor(frame.hpBar, hpAfter)
            end
        end
    end)
    pcall(function()
        if frame.mpBar ~= nil and colorsEnabled then
            if mpFill ~= nil then
                setBarFillColor(frame.mpBar, mpFill)
            end
            if mpAfter ~= nil then
                setBarAfterColor(frame.mpBar, mpAfter)
            end
        end
    end)
end

local function ApplyBarStyle(frame, style)
    if frame == nil or type(style) ~= "table" then
        return
    end
    if frame.__polar_bar_style_running then
        return
    end
    frame.__polar_bar_style_running = true

    local statusbar_style = nil
    pcall(function()
        if type(_G) == "table" and _G.STATUSBAR_STYLE ~= nil then
            statusbar_style = _G.STATUSBAR_STYLE
        elseif STATUSBAR_STYLE ~= nil then
            statusbar_style = STATUSBAR_STYLE
        end
    end)

    if not frame.__polar_party_overlay then
        local ok, err = pcall(function()
            ApplyLegacyStockBarStyle(frame, style, statusbar_style)
        end)
        frame.__polar_bar_style_running = nil
        if not ok and api ~= nil and api.Log ~= nil and api.Log.Err ~= nil then
            api.Log:Err("[Nuzi UI] ApplyLegacyStockBarStyle failed: " .. tostring(err))
        end
        return
    end

    local function resolveColor(key, fallbackKey)
        if type(style[key]) == "table" then
            return style[key]
        end
        if type(style[fallbackKey]) == "table" then
            return style[fallbackKey]
        end
        return nil
    end

    local colorsEnabled = (style.bar_colors_enabled and true or false)
    local mode = tostring(style.hp_texture_mode or "stock")

    local function buildUnitTokens(unit)
        local token = tostring(unit or "")
        if token == "" then
            return {}
        end

        local out = { token }
        local function addToken(alias)
            for i = 1, #out do
                if out[i] == alias then
                    return
                end
            end
            out[#out + 1] = alias
        end

        if token == "target_of_target" or token == "targetoftarget" or token == "targettarget" then
            addToken("targetoftarget")
            addToken("target_of_target")
            addToken("targettarget")
        end

        return out
    end

    local function isHostileUnit(unit)
        if api == nil or api.Unit == nil then
            return false
        end
        local tokens = buildUnitTokens(unit)
        if #tokens == 0 then
            return false
        end

        local tid = nil
        for _, token in ipairs(tokens) do
            tid = api.Unit:GetUnitId(token)
            if tid ~= nil then
                break
            end
        end
        if tid == nil then
            return false
        end
        local info = SafeGetUnitInfoById(tid)
        if type(info) == "table" and tostring(info.faction) == "hostile" then
            return true
        end
        return false
    end

    local function usesSmallHpMp()
        return frame.__polar_small_hpmp and true or false
    end

    local function getHpStyleKey(hostile)
        local small = usesSmallHpMp()
        if mode == "pc" then
            if small and statusbar_style ~= nil and statusbar_style.S_HP_PARTY ~= nil then
                return "S_HP_PARTY"
            end
            if (not small) and statusbar_style ~= nil and statusbar_style.L_HP_PARTY ~= nil then
                return "L_HP_PARTY"
            end
            return small and "S_HP_FRIENDLY" or "L_HP_FRIENDLY"
        end
        if mode == "npc" then
            if hostile then
                return small and "S_HP_HOSTILE" or "L_HP_HOSTILE"
            end
            if small and statusbar_style ~= nil and statusbar_style.S_HP_NEUTRAL ~= nil then
                return "S_HP_NEUTRAL"
            end
            if (not small) and statusbar_style ~= nil and statusbar_style.L_HP_NEUTRAL ~= nil then
                return "L_HP_NEUTRAL"
            end
            return small and "S_HP_FRIENDLY" or "L_HP_FRIENDLY"
        end
        if tostring(frame.__polar_unit) == "player" then
            if small and statusbar_style ~= nil and statusbar_style.S_HP_PARTY ~= nil then
                return "S_HP_PARTY"
            end
            if (not small) and statusbar_style ~= nil and statusbar_style.L_HP_PARTY ~= nil then
                return "L_HP_PARTY"
            end
        end
        return hostile and (small and "S_HP_HOSTILE" or "L_HP_HOSTILE") or (small and "S_HP_FRIENDLY" or "L_HP_FRIENDLY")
    end

    local function BuildTextureInfo(styleKey, afterColor)
        if statusbar_style == nil or type(statusbar_style) ~= "table" then
            return nil
        end
        local src = statusbar_style[styleKey]
        if type(src) ~= "table" then
            return nil
        end

        local out = DeepCopyTable(src)
        if colorsEnabled then
            local up = BuildTextureAfterColorValues(out.afterImage_color_up, afterColor)
            local down = BuildTextureAfterColorValues(out.afterImage_color_down, afterColor)
            if up ~= nil and type(out.afterImage_color_up) == "table" then
                out.afterImage_color_up = up
            end
            if down ~= nil and type(out.afterImage_color_down) == "table" then
                out.afterImage_color_down = down
            end
        end
        return out
    end

    local function ApplyTexture(bar, textureInfo, textureKey)
        if bar == nil then
            return false
        end
        local ok = pcall(function()
            if textureInfo ~= nil then
                bar.textureInfo = textureInfo
                bar:ApplyBarTexture(textureInfo)
            else
                bar:ApplyBarTexture()
            end
        end)
        if ok then
            bar.__polar_texture_key = textureKey
            bar.__polar_applied_texture_info = textureInfo or bar.textureInfo
            InvalidateBarColorState(bar)
        end
        return ok
    end

    local hpFill = resolveColor("hp_fill_color", "hp_bar_color")
    local hpAfter = resolveColor("hp_after_color", "hp_bar_color")
    local mpFill = resolveColor("mp_fill_color", "mp_bar_color")
    local mpAfter = resolveColor("mp_after_color", "mp_bar_color")
    local frameUnit = ResolveFrameRuntimeUnit(frame) or frame.__polar_unit
    local frameHostile = isHostileUnit(frameUnit)
    local hostileTargetHpEnabled = style.hostile_target_hp_enabled == true
        and IsHostileHpOverrideUnit(frameUnit)
        and frameHostile
    local hostileTargetHpColor = NormalizeColor255(style.hostile_target_hp_color, { 255, 54, 40, 255 })

    local hpBar = frame.hpBar
    local mpBar = frame.mpBar

    pcall(function()
        if hpBar ~= nil then
            local styleKey = getHpStyleKey(frameHostile)
            local textureInfo = BuildTextureInfo(styleKey, hpAfter or hpFill)
            ApplyTexture(hpBar, textureInfo, styleKey or mode or "default")
        end
    end)
    pcall(function()
        if mpBar ~= nil then
            local mpKey = usesSmallHpMp() and "S_MP" or "L_MP"
            local textureInfo = BuildTextureInfo(mpKey, mpAfter or mpFill)
            ApplyTexture(mpBar, textureInfo, mpKey or "default")
        end
    end)

    local defaultFill = { 255, 255, 255, 255 }
    pcall(function()
        if hpBar ~= nil then
            local hpColorOverride = colorsEnabled or hostileTargetHpEnabled
            SetStatusBarDynamicState(hpBar, not hpColorOverride)
            local fillColor = hostileTargetHpEnabled
                and hostileTargetHpColor
                or (colorsEnabled and NormalizeColor255(hpFill, defaultFill) or defaultFill)
            local afterColor = hostileTargetHpEnabled
                and hostileTargetHpColor
                or (colorsEnabled
                    and NormalizeColor255(hpAfter or hpFill, fillColor)
                    or GetTextureAfterColor255(hpBar.__polar_applied_texture_info or hpBar.textureInfo, defaultFill))
            ApplyBarColorState(hpBar, fillColor, afterColor)
        end
    end)
    pcall(function()
        if mpBar ~= nil then
            SetStatusBarDynamicState(mpBar, not colorsEnabled)
            local fillColor = colorsEnabled and NormalizeColor255(mpFill, defaultFill) or defaultFill
            local afterColor = colorsEnabled
                and NormalizeColor255(mpAfter or mpFill, fillColor)
                or GetTextureAfterColor255(mpBar.__polar_applied_texture_info or mpBar.textureInfo, defaultFill)
            ApplyBarColorState(mpBar, fillColor, afterColor)
        end
    end)
    frame.__polar_bar_style_running = nil
end

local function ApplyTextLayout(frame, style)
    if frame == nil or type(style) ~= "table" then
        return
    end

    local nameVisible = (style.name_visible ~= false)
    local nameX = tonumber(style.name_offset_x) or 0
    local nameY = tonumber(style.name_offset_y) or 0

    local levelVisible = (style.level_visible ~= false)
    if type(UI.settings) == "table" and UI.settings.hide_ancestral_icon_level then
        levelVisible = false
    end
    local levelX = tonumber(style.level_offset_x) or 0
    local levelY = tonumber(style.level_offset_y) or 0
    local levelSize = tonumber(style.level_font_size)

    pcall(function()
        if frame.name ~= nil and frame.name.Show ~= nil then
            frame.name:Show(nameVisible)
        end
    end)

    local function safeAnchor(widget, point, rel, relPoint, x, y)
        if widget == nil or widget.AddAnchor == nil then
            return false
        end
        local ok = pcall(function()
            widget:AddAnchor(point, rel, relPoint, x, y)
        end)
        if ok then
            return true
        end
        return pcall(function()
            widget:AddAnchor(point, rel, x, y)
        end)
    end

    if nameVisible and (nameX ~= 0 or nameY ~= 0) and frame.name ~= nil and frame.hpBar ~= nil then
        pcall(function()
            if frame.name.RemoveAllAnchors ~= nil then
                frame.name:RemoveAllAnchors()
            end
            if safeAnchor(frame.name, "BOTTOMLEFT", frame.hpBar, "TOPLEFT", nameX, nameY) then
                frame.__polar_name_moved = true
            end
        end)
    elseif frame.__polar_name_moved then
        frame.__polar_name_moved = nil
        pcall(function()
            if frame.UpdateNameStyle ~= nil then
                frame:UpdateNameStyle()
            end
        end)
    end

    local levelLabel = (frame.level ~= nil and frame.level.label ~= nil) and frame.level.label or nil
    pcall(function()
        if levelLabel ~= nil and levelLabel.Show ~= nil then
            levelLabel:Show(levelVisible)
        end
    end)
    pcall(function()
        if levelLabel ~= nil and levelLabel.style ~= nil and levelSize ~= nil then
            levelLabel.style:SetFontSize(levelSize)
        end
    end)

    if levelVisible and (levelX ~= 0 or levelY ~= 0) and levelLabel ~= nil then
        pcall(function()
            if levelLabel.RemoveAllAnchors ~= nil then
                levelLabel:RemoveAllAnchors()
            end
            local anchored = false
            if frame.name ~= nil and nameVisible then
                anchored = safeAnchor(levelLabel, "RIGHT", frame.name, "LEFT", levelX, levelY)
            elseif frame.hpBar ~= nil then
                anchored = safeAnchor(levelLabel, "BOTTOMLEFT", frame.hpBar, "TOPLEFT", levelX, levelY)
            end
            if anchored then
                frame.__polar_level_moved = true
            end
        end)
    elseif frame.__polar_level_moved then
        frame.__polar_level_moved = nil
        pcall(function()
            if frame.UpdateLevel ~= nil then
                frame:UpdateLevel()
            end
        end)
    end
end

local function RefreshTargetReputationButton(frame)
    if frame == nil or UI == nil or UI.target == nil or frame ~= UI.target.wnd then
        return
    end

    local button = ResolveWidgetCandidate(frame.reputationButton)
    if button == nil then
        return
    end

    local canVote = false
    if X2Hero ~= nil and type(X2Hero.CanAddReputation) == "function" then
        local ok, value = pcall(function()
            return X2Hero:CanAddReputation()
        end)
        if not ok then
            ok, value = pcall(function()
                return X2Hero.CanAddReputation()
            end)
        end
        canVote = ok and value and true or false
    end

    pcall(function()
        if button.SetAlpha ~= nil then
            button:SetAlpha(canVote and 1 or 0)
        end
        local visible = nil
        if button.IsVisible ~= nil then
            visible = button:IsVisible() and true or false
        end
        if button.Show ~= nil and (visible ~= canVote or button.__polar_reputation_visible ~= canVote) then
            button:Show(canVote)
            button.__polar_reputation_visible = canVote
        end
    end)

    if not canVote then
        button.__polar_reputation_anchor_target = nil
        button.__polar_reputation_anchor_key = nil
        return
    end

    pcall(function()
        if button.Enable ~= nil then
            button:Enable(true)
        end
        if button.Clickable ~= nil then
            button:Clickable(true)
        end
        if button.EnablePick ~= nil then
            button:EnablePick(true)
        end
        if button.Raise ~= nil then
            button:Raise()
        end
    end)

    pcall(function()
        if not button.__polar_reputation_skin_applied then
            local skin = BUTTON_HUD ~= nil and BUTTON_HUD.REPUTATION or nil
            if skin ~= nil then
                if api ~= nil and api.Interface ~= nil and type(api.Interface.ApplyButtonSkin) == "function" then
                    api.Interface:ApplyButtonSkin(button, skin)
                elseif type(ApplyButtonSkin) == "function" then
                    ApplyButtonSkin(button, skin)
                end
            end
            button.__polar_reputation_skin_applied = true
        end
    end)

    local style = ResolveFrameStyleTable ~= nil and ResolveFrameStyleTable(frame) or nil
    local offsetX = tonumber(type(style) == "table" and style.target_reputation_offset_x or nil) or -2
    local offsetY = tonumber(type(style) == "table" and style.target_reputation_offset_y or nil) or -7
    local anchorTarget = frame.hpBar or frame
    local anchorKey = tostring(anchorTarget) .. ":" .. tostring(offsetX) .. ":" .. tostring(offsetY)
    if button.__polar_reputation_anchor_key == anchorKey then
        return
    end

    pcall(function()
        local anchored = false
        if button.RemoveAllAnchors ~= nil then
            button:RemoveAllAnchors()
        end
        if button.AddAnchor ~= nil and frame.hpBar ~= nil then
            local ok = pcall(function()
                button:AddAnchor("TOPRIGHT", frame.hpBar, "TOPRIGHT", offsetX, offsetY)
            end)
            anchored = ok and true or anchored
            if not ok then
                ok = pcall(function()
                    button:AddAnchor("TOPRIGHT", frame.hpBar, offsetX, offsetY)
                end)
                anchored = ok and true or anchored
            end
        elseif button.AddAnchor ~= nil then
            local ok = pcall(function()
                button:AddAnchor("TOPRIGHT", frame, "TOPRIGHT", offsetX, offsetY)
            end)
            anchored = ok and true or anchored
            if not ok then
                ok = pcall(function()
                    button:AddAnchor("TOPRIGHT", frame, offsetX, offsetY)
                end)
                anchored = ok and true or anchored
            end
        end
        if anchored then
            button.__polar_reputation_anchor_key = anchorKey
        end
    end)
end

local function ApplyStockFrameDecorations(frame, settings)
    if frame == nil then
        return
    end

    local hideLevelArtifacts = type(settings) == "table" and settings.hide_ancestral_icon_level == true
    local isTargetFrame = UI ~= nil and UI.target ~= nil and frame == UI.target.wnd
    local hideBossBackground = type(settings) == "table" and settings.hide_boss_frame_background == true and isTargetFrame
    local hideTargetGradeStar = type(settings) == "table" and settings.hide_target_grade_star == true and isTargetFrame

    RefreshClassIconFrame(frame, settings)

    for _, key in ipairs(STOCK_LEVEL_ARTIFACT_FIELDS) do
        SetWidgetForcedHidden(frame[key], hideLevelArtifacts)
    end
    ApplyLevelArtifactHide(frame.level, hideLevelArtifacts)

    if hideLevelArtifacts then
        InvokeFrameMethod(frame, "ShowHeirFrame", false)
        frame.__polar_heir_art_forced_hidden = true
    elseif frame.__polar_heir_art_forced_hidden then
        frame.__polar_heir_art_forced_hidden = nil
        InvokeFrameMethod(frame, "UpdateLevel")
    end

    if isTargetFrame then
        local style = ResolveFrameStyleTable(frame)
        local gradeStarOffsetX = tonumber(type(style) == "table" and style.target_grade_star_offset_x or nil) or 0
        local gradeStarOffsetY = tonumber(type(style) == "table" and style.target_grade_star_offset_y or nil) or 0
        local moveGradeStar = gradeStarOffsetX ~= 0 or gradeStarOffsetY ~= 0

        pcall(function()
            if not moveGradeStar and frame.__polar_grade_star_moved then
                frame.__polar_grade_star_moved = nil
                if frame.SetGradeBg ~= nil then
                    frame:SetGradeBg()
                end
                if frame.UpdateNameStyle ~= nil then
                    frame:UpdateNameStyle()
                end
            end
        end)

        SetWidgetForcedHidden(frame.gradeStar, hideTargetGradeStar)

        local seen = {}
        local function applyBackground(widget)
            widget = ResolveWidgetCandidate(widget)
            if widget == nil or seen[widget] then
                return
            end
            seen[widget] = true
            SetWidgetForcedHidden(widget, hideBossBackground)
        end

        for _, key in ipairs(STOCK_TARGET_BACKGROUND_FIELDS) do
            applyBackground(frame[key])
        end

        pcall(function()
            for key, value in pairs(frame) do
                local lower = string.lower(tostring(key or ""))
                if not STOCK_TARGET_BACKGROUND_EXCLUDE[lower] and
                    (lower == "bg" or lower == "background" or lower == "backdrop" or lower == "gradebg" or
                        lower == "gradedeco" or string.find(lower, "boss", 1, true) ~= nil or
                        string.find(lower, "background", 1, true) ~= nil) then
                    applyBackground(value)
                end
            end
        end)
        ApplyTargetFallbackBackgroundStyle(frame, style, hideBossBackground)
        RefreshTargetReputationButton(frame)

        pcall(function()
            local gradeStar = ResolveWidgetCandidate(frame.gradeStar)
            if gradeStar == nil or hideTargetGradeStar or not moveGradeStar then
                return
            end

            local function safeAnchor(widget, point, rel, relPoint, x, y)
                if widget == nil or widget.AddAnchor == nil or rel == nil then
                    return false
                end
                local ok = pcall(function()
                    widget:AddAnchor(point, rel, relPoint, x, y)
                end)
                if ok then
                    return true
                end
                return pcall(function()
                    widget:AddAnchor(point, rel, x, y)
                end)
            end

            if gradeStar.RemoveAllAnchors ~= nil then
                gradeStar:RemoveAllAnchors()
            end

            local anchored = false
            if frame.level ~= nil then
                anchored = safeAnchor(gradeStar, "BOTTOMLEFT", frame.level, "BOTTOMRIGHT", gradeStarOffsetX, gradeStarOffsetY)
            end
            if not anchored and frame.level ~= nil and frame.level.label ~= nil then
                anchored = safeAnchor(
                    gradeStar,
                    "BOTTOMLEFT",
                    frame.level.label,
                    "BOTTOMRIGHT",
                    gradeStarOffsetX,
                    gradeStarOffsetY
                )
            end
            if not anchored and frame.name ~= nil then
                anchored = safeAnchor(gradeStar, "LEFT", frame.name, "LEFT", gradeStarOffsetX, gradeStarOffsetY)
            end

            if anchored then
                frame.__polar_grade_star_moved = true
            end
        end)
    end
end

local function ApplyStockDistanceSetting()
    if UI.target.wnd == nil or UI.target.wnd.distanceLabel == nil then
        return
    end

    local forceHide = false
    if UI.enabled and UI.settings ~= nil and UI.settings.show_distance == false then
        forceHide = true
    end

    if forceHide then
        SetStockDistanceLabelVisible(false)
        UI.stock_distance_forced_hidden = true
        return
    end

    if UI.stock_distance_forced_hidden then
        UI.stock_distance_forced_hidden = false
        SetStockDistanceLabelVisible(true)
        pcall(function()
            if UI.target.wnd ~= nil and UI.target.wnd.UpdateAll ~= nil then
                UI.target.wnd:UpdateAll()
            end
        end)
    end
end

local function RefreshStockFrameDecorations(settings)
    for _, frame in ipairs({
        UI.player.wnd,
        UI.target.wnd,
        UI.watchtarget.wnd,
        UI.target_of_target.wnd
    }) do
        if frame ~= nil then
            ApplyStockFrameDecorations(frame, settings)
        end
    end
    ApplyStockDistanceSetting()
end

local function HideLegacyPolarDistanceOverlay(frame)
    if frame == nil then
        return
    end
    local w = frame.polarUiTargetDist
    if w == nil then
        return
    end
    pcall(function()
        if w.SetAlpha ~= nil then
            w:SetAlpha(0)
        end
        if w.Show ~= nil then
            w:Show(false)
        end
        if w.SetText ~= nil then
            w:SetText("")
        end
    end)
end

SetNotClickable = function(widget)
    if widget == nil then
        return
    end
    if widget.Clickable ~= nil then
        pcall(function()
            widget:Clickable(false)
        end)
    end
    if widget.EnablePick ~= nil then
        pcall(function()
            widget:EnablePick(false)
        end)
    end
    if widget.EnableDrag ~= nil then
        pcall(function()
            widget:EnableDrag(false)
        end)
    end
end

SafeGetExtent = function(wnd)
    if wnd == nil then
        return nil, nil
    end

    local ok, w, h = pcall(function()
        if wnd.GetEffectiveExtent ~= nil then
            return wnd:GetEffectiveExtent()
        end
        if wnd.GetExtent ~= nil then
            return wnd:GetExtent()
        end
        if wnd.GetWidth ~= nil and wnd.GetHeight ~= nil then
            return wnd:GetWidth(), wnd:GetHeight()
        end
        return nil, nil
    end)
    if not ok then
        return nil, nil
    end
    return tonumber(w), tonumber(h)
end

local function EnsureAlignmentGrid(settings)
    if AlignmentModule ~= nil and AlignmentModule.Ensure ~= nil then
        AlignmentModule.Ensure(BuildUiContext(), settings)
    end
end

local function ApplyFrameAlpha(frame, alpha)
    if frame == nil then
        return
    end
    local a = tonumber(alpha)
    if a == nil then
        a = 1
    end
    if a < 0 then
        a = 0
    elseif a > 1 then
        a = 1
    end
    pcall(function()
        if frame.SetAlpha ~= nil then
            frame:SetAlpha(a)
        end
    end)
end

local function ApplyOverlayAlpha(alpha)
    local a = tonumber(alpha)
    if a == nil then
        a = 1
    end
    if a < 0 then
        a = 0
    elseif a > 1 then
        a = 1
    end

    local function applyTo(w)
        if w == nil then
            return
        end
        pcall(function()
            if w.SetAlpha ~= nil then
                w:SetAlpha(a)
            end
        end)
    end

    applyTo(UI.target.class_name)
    applyTo(UI.target.guild)
end

local function FormatShortNumber(n)
    n = NormalizeNumericValue(n)
    if n == nil then
        return "0"
    end
    local absN = math.abs(n)
    local sign = n < 0 and "-" or ""
    local v = absN
    local suffix = ""
    if absN >= 1000000000 then
        v = absN / 1000000000
        suffix = "b"
    elseif absN >= 1000000 then
        v = absN / 1000000
        suffix = "m"
    elseif absN >= 1000 then
        v = absN / 1000
        suffix = "k"
    else
        return sign .. FormatIntegerValue(absN)
    end

    local s = string.format("%.1f", v)
    s = s:gsub("%.0$", "")
    return sign .. s .. suffix
end

local function ParseTwoNumbers(text)
    if type(text) ~= "string" then
        return nil, nil
    end
    local cleaned = text:gsub(",", "")
    local found = {}
    for token in cleaned:gmatch("[-+]?%d+%.?%d*[eE]?[-+]?%d*") do
        if token ~= "" and token ~= "+" and token ~= "-" then
            local value = NormalizeNumericValue(token)
            if value ~= nil then
                found[#found + 1] = value
                if #found >= 2 then
                    break
                end
            end
        end
    end
    if #found < 2 then
        return nil, nil
    end
    return found[1], found[2]
end

local function GetUnitVitals(unit)
    unit = NormalizeRuntimeUnitToken(unit)
    if api == nil or api.Unit == nil or unit == nil then
        return nil
    end

    local hp, hpMax, mp, mpMax = nil, nil, nil, nil
    pcall(function()
        if api.Unit.UnitHealth ~= nil then
            hp = api.Unit:UnitHealth(unit)
        end
        if api.Unit.UnitMaxHealth ~= nil then
            hpMax = api.Unit:UnitMaxHealth(unit)
        end
        if api.Unit.UnitMana ~= nil then
            mp = api.Unit:UnitMana(unit)
        end
        if api.Unit.UnitMaxMana ~= nil then
            mpMax = api.Unit:UnitMaxMana(unit)
        end
    end)

    hp = NormalizeNumericValue(hp)
    hpMax = NormalizeNumericValue(hpMax)
    mp = NormalizeNumericValue(mp)
    mpMax = NormalizeNumericValue(mpMax)

    if type(hp) ~= "number" or type(hpMax) ~= "number" or hpMax <= 0 then
        hp, hpMax = nil, nil
    end
    if type(mp) ~= "number" or type(mpMax) ~= "number" or mpMax <= 0 then
        mp, mpMax = nil, nil
    end

    if hp == nil and mp == nil then
        return nil
    end

    return {
        hp = hp,
        hp_max = hpMax,
        mp = mp,
        mp_max = mpMax
    }
end

local function BuildFormattedValueText(cur, max, style, forceCurMax)
    if type(cur) ~= "number" or type(max) ~= "number" or max <= 0 then
        return nil
    end

    local fmt = "stock"
    local short = false
    if type(style) == "table" then
        fmt = tostring(style.value_format or "stock")
        short = style.short_numbers and true or false
    end

    local wantCurMax = forceCurMax or fmt == "curmax" or fmt == "curmax_percent" or short
    local wantPercent = (fmt == "percent" or fmt == "curmax_percent")

    local curMaxText = nil
    if wantCurMax then
        local curTxt = short and FormatShortNumber(cur) or FormatIntegerValue(cur)
        local maxTxt = short and FormatShortNumber(max) or FormatIntegerValue(max)
        curMaxText = curTxt .. "/" .. maxTxt
    end

    local pctText = nil
    if wantPercent then
        local pct = math.floor((cur / max) * 100 + 0.5)
        pctText = tostring(pct) .. "%"
    end

    if curMaxText ~= nil and pctText ~= nil then
        return curMaxText .. " (" .. pctText .. ")"
    end
    if curMaxText ~= nil then
        return curMaxText
    end
    if pctText ~= nil then
        return pctText
    end

    return nil
end

local function SetLabelTextIfChanged(label, text)
    if label == nil or label.SetText == nil then
        return
    end
    local newText = tostring(text or "")
    local currentText = nil
    if label.GetText ~= nil then
        pcall(function()
            currentText = tostring(label:GetText() or "")
        end)
    end
    if label.__polar_text ~= newText or currentText ~= newText then
        label:SetText(newText)
        label.__polar_text = newText
    end
end

local function ApplyValueLabelVisibility(frame, style)
    if frame == nil or type(style) ~= "table" then
        return
    end

    local showHpValue = style.hp_value_visible ~= false
    local showMpValue = style.mp_value_visible ~= false

    local function setValueLabelVisible(label, shown)
        if label == nil then
            return
        end
        if shown then
            if label.__polar_value_forced_hidden then
                label.__polar_value_forced_hidden = nil
                SetWidgetVisible(label, true)
            end
            return
        end
        label.__polar_value_forced_hidden = true
        SetWidgetVisible(label, false)
    end

    pcall(function()
        if frame.hpBar ~= nil and frame.hpBar.hpLabel ~= nil then
            setValueLabelVisible(frame.hpBar.hpLabel, showHpValue)
        end
    end)
    pcall(function()
        if frame.mpBar ~= nil and frame.mpBar.mpLabel ~= nil then
            setValueLabelVisible(frame.mpBar.mpLabel, showMpValue)
        end
    end)
end

local function SafeSetBarValue(statusBar, maxValue, value)
    if statusBar == nil then
        return
    end
    maxValue = tonumber(maxValue) or 0
    value = tonumber(value) or 0
    if statusBar.__polar_max ~= maxValue then
        pcall(function()
            statusBar:SetMinMaxValues(0, maxValue)
        end)
        statusBar.__polar_max = maxValue
    end
    if statusBar.__polar_value == value then
        return
    end
    pcall(function()
        statusBar:SetValue(value)
    end)
    statusBar.__polar_value = value
end

local function ApplyValueTextFormat(frame, style)
    if frame == nil or type(style) ~= "table" then
        return
    end

    local fmt = tostring(style.value_format or "stock")
    local short = style.short_numbers and true or false
    local repairStock = false
    local showHpValue = style.hp_value_visible ~= false
    local showMpValue = style.mp_value_visible ~= false

    ApplyValueLabelVisibility(frame, style)

    local function labelNeedsRepair(label)
        if label == nil or label.GetText == nil then
            return false
        end
        local text = nil
        pcall(function()
            text = tostring(label:GetText() or "")
        end)
        return type(text) == "string" and string.find(text, "[eE][%+%-]?%d+") ~= nil
    end

    if fmt == "stock" and not short then
        repairStock = (showHpValue and labelNeedsRepair(frame.hpBar ~= nil and frame.hpBar.hpLabel or nil)) or
            (showMpValue and labelNeedsRepair(frame.mpBar ~= nil and frame.mpBar.mpLabel or nil))
        if not repairStock then
            return
        end
    end

    local unit = ResolveFrameRuntimeUnit(frame)

    local vitals = GetUnitVitals(unit)

    local function applyTo(label, cur, max, shown)
        if not shown or label == nil or label.SetText == nil then
            return
        end

        local out = BuildFormattedValueText(cur, max, style, repairStock)
        if type(out) == "string" and out ~= "" then
            SetLabelTextIfChanged(label, out)
        end
    end

    pcall(function()
        if frame.hpBar ~= nil then
            if vitals ~= nil and vitals.hp ~= nil and vitals.hp_max ~= nil then
                applyTo(frame.hpBar.hpLabel, vitals.hp, vitals.hp_max, showHpValue)
            else
                local t = (frame.hpBar.hpLabel ~= nil and frame.hpBar.hpLabel.GetText ~= nil) and frame.hpBar.hpLabel:GetText() or nil
                local cur, max = ParseTwoNumbers(t)
                applyTo(frame.hpBar.hpLabel, cur, max, showHpValue)
            end
        end
    end)
    pcall(function()
        if frame.mpBar ~= nil then
            if vitals ~= nil and vitals.mp ~= nil and vitals.mp_max ~= nil then
                applyTo(frame.mpBar.mpLabel, vitals.mp, vitals.mp_max, showMpValue)
            else
                local t = (frame.mpBar.mpLabel ~= nil and frame.mpBar.mpLabel.GetText ~= nil) and frame.mpBar.mpLabel:GetText() or nil
                local cur, max = ParseTwoNumbers(t)
                applyTo(frame.mpBar.mpLabel, cur, max, showMpValue)
            end
        end
    end)
end

local function SyncFrameEventHitbox(frame, width, height)
    if frame == nil or frame.eventWindow == nil then
        return
    end

    local eventWindow = frame.eventWindow
    local w = tonumber(width)
    local h = tonumber(height)
    if (w == nil or h == nil) and SafeGetExtent ~= nil then
        w, h = SafeGetExtent(frame)
    end
    if w == nil or h == nil or w <= 0 or h <= 0 then
        return
    end

    pcall(function()
        if eventWindow.AddAnchor ~= nil then
            if eventWindow.RemoveAllAnchors ~= nil then
                eventWindow:RemoveAllAnchors()
            end
            local ok = pcall(function()
                eventWindow:AddAnchor("TOPLEFT", frame, "TOPLEFT", 0, 0)
            end)
            if not ok then
                pcall(function()
                    eventWindow:AddAnchor("TOPLEFT", frame, 0, 0)
                end)
            end
        end
        if eventWindow.SetExtent ~= nil then
            eventWindow:SetExtent(w, h)
        end
    end)

    eventWindow.__polar_hitbox_w = w
    eventWindow.__polar_hitbox_h = h
end

local function ApplyFrameLayout(frame, settings)
    if frame == nil or type(settings) ~= "table" then
        return
    end

    local styleTable = nil
    if type(frame.__polar_style_override) == "table" then
        styleTable = frame.__polar_style_override
    elseif type(settings.style) == "table" then
        styleTable = settings.style
    end

    local width = nil
    local height = tonumber(settings.frame_height)
    local scale = nil

    if type(styleTable) == "table" then
        width = tonumber(styleTable.frame_width)
        scale = tonumber(styleTable.frame_scale)
    end

    if width == nil then
        width = tonumber(settings.frame_width)
    end
    if scale == nil then
        scale = tonumber(settings.frame_scale)
    end

    local barH = nil
    local hpBarH = nil
    local mpBarH = nil
    local barGap = 0
    if type(styleTable) == "table" then
        barH = tonumber(styleTable.bar_height)
        hpBarH = tonumber(styleTable.hp_bar_height)
        mpBarH = tonumber(styleTable.mp_bar_height)
        barGap = tonumber(styleTable.bar_gap) or 0
    end
    if barH == nil then
        barH = tonumber(settings.bar_height)
    end
    if hpBarH == nil then
        hpBarH = barH
    end
    if mpBarH == nil then
        mpBarH = barH
    end

    if width ~= nil and height ~= nil then
        pcall(function()
            if frame.SetExtent ~= nil then
                frame:SetExtent(width, height)
            end
        end)
    end
    SyncFrameEventHitbox(frame, width, height)

    if scale ~= nil then
        if scale < 0.5 then
            scale = 0.5
        elseif scale > 1.5 then
            scale = 1.5
        end
        pcall(function()
            if frame.SetScale ~= nil then
                frame:SetScale(scale)
            end
        end)
    end

    if hpBarH ~= nil or mpBarH ~= nil then
        local function clampBarHeight(value)
            value = tonumber(value)
            if value == nil then
                return nil
            end
            if value < 6 then
                return 6
            elseif value > 60 then
                return 60
            end
            return value
        end

        hpBarH = clampBarHeight(hpBarH)
        mpBarH = clampBarHeight(mpBarH)

        local function setBarHeight(bar, targetHeight)
            if bar == nil then
                return
            end
            pcall(function()
                if bar.SetHeight ~= nil then
                    bar:SetHeight(targetHeight)
                    return
                end
                if bar.SetExtent ~= nil then
                    local w = nil
                    if bar.GetWidth ~= nil then
                        w = bar:GetWidth()
                    end
                    if type(w) == "number" and w > 0 then
                        bar:SetExtent(w, targetHeight)
                    elseif type(width) == "number" and width > 0 then
                        bar:SetExtent(width, targetHeight)
                    end
                end
            end)
        end

        local function setBarExtent(bar, targetHeight)
            if bar == nil then
                return
            end
            if type(width) ~= "number" or width <= 0 then
                setBarHeight(bar, targetHeight)
                return
            end
            pcall(function()
                if bar.SetExtent ~= nil then
                    bar:SetExtent(width, targetHeight)
                elseif bar.SetWidth ~= nil then
                    bar:SetWidth(width)
                    if bar.SetHeight ~= nil then
                        bar:SetHeight(targetHeight)
                    end
                else
                    setBarHeight(bar, targetHeight)
                end
            end)
        end

        setBarExtent(frame.hpBar, hpBarH)
        setBarExtent(frame.mpBar, mpBarH)

        pcall(function()
            if frame.hpBar ~= nil and frame.mpBar ~= nil and frame.mpBar.AddAnchor ~= nil then
                if frame.mpBar.RemoveAllAnchors ~= nil then
                    frame.mpBar:RemoveAllAnchors()
                end
                local ok = pcall(function()
                    frame.mpBar:AddAnchor("TOPLEFT", frame.hpBar, "BOTTOMLEFT", 0, barGap)
                end)
                if not ok then
                    pcall(function()
                        frame.mpBar:AddAnchor("TOPLEFT", frame.hpBar, 0, hpBarH + barGap)
                    end)
                end
            end
        end)
    end

    if type(styleTable) == "table" then
        ApplyValueTextFormat(frame, styleTable)
        ApplyStockFrameDecorations(frame, settings)
        ApplyTextLayout(frame, styleTable)
        RefreshFrameBarPresentation(frame, styleTable)
    end
end

local function ReapplyFrameBarStyle(frame)
    if frame == nil or frame.__polar_frame_style_applying or frame.__polar_bar_style_running then
        return
    end
    RefreshFrameBarPresentation(frame, nil)
end

local function SetBarWidgetStyleHook(frame, widget, tag)
    if frame == nil or widget == nil or type(tag) ~= "string" then
        return
    end

    local function wrap(methodName)
        if type(widget[methodName]) ~= "function" then
            return
        end
        local origKey = "__polar_orig_" .. tag .. "_" .. methodName
        if type(widget[origKey]) == "function" then
            return
        end

        widget[origKey] = widget[methodName]
        widget[methodName] = function(self, ...)
            local out = nil
            local orig = self[origKey]
            if type(orig) == "function" then
                out = orig(self, ...)
            end
            ReapplyFrameBarStyle(frame)
            return out
        end
    end

    wrap("SetBarColor")
    wrap("SetColor")
    wrap("SetLayerColor")
    wrap("SetBarTexture")
    wrap("SetBarTextureCoords")
    wrap("ApplyBarTexture")
    wrap("ChangeAfterImageColor")
end

local function ClearBarWidgetStyleHook(widget, tag)
    if widget == nil or type(tag) ~= "string" then
        return
    end

    local function restore(methodName)
        local origKey = "__polar_orig_" .. tag .. "_" .. methodName
        if type(widget[origKey]) == "function" then
            widget[methodName] = widget[origKey]
        end
        widget[origKey] = nil
    end

    restore("SetBarColor")
    restore("SetColor")
    restore("SetLayerColor")
    restore("SetBarTexture")
    restore("SetBarTextureCoords")
    restore("ApplyBarTexture")
    restore("ChangeAfterImageColor")
end

local function SetFrameBarStyleHook(frame)
    if frame == nil then
        return
    end

    SetBarWidgetStyleHook(frame, frame.hpBar, "hpbar")
    SetBarWidgetStyleHook(frame, frame.hpBar ~= nil and frame.hpBar.statusBar or nil, "hpstatus")
    SetBarWidgetStyleHook(frame, frame.hpBar ~= nil and frame.hpBar.statusBarAfterImage or nil, "hpafter")

    SetBarWidgetStyleHook(frame, frame.mpBar, "mpbar")
    SetBarWidgetStyleHook(frame, frame.mpBar ~= nil and frame.mpBar.statusBar or nil, "mpstatus")
    SetBarWidgetStyleHook(frame, frame.mpBar ~= nil and frame.mpBar.statusBarAfterImage or nil, "mpafter")
end

local function ClearFrameBarStyleHook(frame)
    if frame == nil then
        return
    end

    ClearBarWidgetStyleHook(frame.hpBar, "hpbar")
    ClearBarWidgetStyleHook(frame.hpBar ~= nil and frame.hpBar.statusBar or nil, "hpstatus")
    ClearBarWidgetStyleHook(frame.hpBar ~= nil and frame.hpBar.statusBarAfterImage or nil, "hpafter")

    ClearBarWidgetStyleHook(frame.mpBar, "mpbar")
    ClearBarWidgetStyleHook(frame.mpBar ~= nil and frame.mpBar.statusBar or nil, "mpstatus")
    ClearBarWidgetStyleHook(frame.mpBar ~= nil and frame.mpBar.statusBarAfterImage or nil, "mpafter")
end

local function SetFrameStyleHook(frame, settings)
    if frame == nil or type(settings) ~= "table" then
        return
    end

    frame.__polar_frame_style_cfg = settings
    SetFrameBarStyleHook(frame)
    if frame.__polar_frame_style_hooked then
        return
    end
    frame.__polar_frame_style_hooked = true

    local function wrap(methodName)
        if type(frame[methodName]) ~= "function" then
            return
        end
        local origKey = "__polar_orig_" .. methodName
        if type(frame[origKey]) == "function" then
            return
        end

        frame[origKey] = frame[methodName]
        frame[methodName] = function(self, ...)
            local out = nil
            local orig = self[origKey]
            if type(orig) == "function" then
                out = orig(self, ...)
            end
            if type(self.__polar_frame_style_cfg) == "table" and not self.__polar_frame_style_applying then
                self.__polar_frame_style_applying = true
                ApplyFrameLayout(self, self.__polar_frame_style_cfg)
                self.__polar_frame_style_applying = nil
            end
            return out
        end
    end

    pcall(function()
        wrap("UpdateAll")
        wrap("UpdateHpMp")
        wrap("SetHp")
        wrap("SetMp")
        wrap("SetLevel")
        wrap("UpdateNameStyle")
        wrap("UpdateName")
        wrap("UpdateLevel")
        wrap("ShowHeirFrame")
        wrap("ChangeTarget")
        wrap("UpdateHpBarTexture_FirstHitByMe")
        wrap("ChangeHpBarTexture_forPc")
        wrap("ChangeHpBarTexture_forNpc")
        wrap("UpdateFrameStyle_ForUniType")
        wrap("ApplyFrameStyle")
    end)
end

local function ClearFrameStyleHook(frame)
    if frame == nil then
        return
    end

    frame.__polar_frame_style_cfg = nil
    ClearFrameBarStyleHook(frame)
    RefreshFrameBarPresentation(frame, nil)
    if not frame.__polar_frame_style_hooked then
        return
    end
    frame.__polar_frame_style_hooked = nil

    local function restore(methodName)
        local origKey = "__polar_orig_" .. methodName
        if type(frame[origKey]) == "function" then
            frame[methodName] = frame[origKey]
        end
        frame[origKey] = nil
    end

    pcall(function()
        restore("UpdateAll")
        restore("UpdateHpMp")
        restore("SetHp")
        restore("SetMp")
        restore("SetLevel")
        restore("UpdateNameStyle")
        restore("UpdateName")
        restore("UpdateLevel")
        restore("ShowHeirFrame")
        restore("ChangeTarget")
        restore("UpdateHpBarTexture_FirstHitByMe")
        restore("ChangeHpBarTexture_forPc")
        restore("ChangeHpBarTexture_forNpc")
        restore("UpdateFrameStyle_ForUniType")
        restore("ApplyFrameStyle")
    end)
end

SetWidgetVisible = function(widget, shown)
    if widget ~= nil and widget.Show ~= nil then
        pcall(function()
            widget:Show(shown and true or false)
        end)
    end
end

ResolveFrameStyleTable = function(frame)
    if frame == nil then
        return nil
    end
    if type(frame.__polar_style_override) == "table" then
        return frame.__polar_style_override
    end
    local settings = frame.__polar_frame_style_cfg
    if type(settings) == "table" and type(settings.style) == "table" then
        return settings.style
    end
    return nil
end

RefreshFrameBarPresentation = function(frame, style)
    if frame == nil then
        return
    end
    local styleTable = style
    if type(styleTable) ~= "table" or type(styleTable.style) == "table" then
        styleTable = ResolveFrameStyleTable(frame)
    end
    if type(styleTable) == "table" then
        ApplyBarStyle(frame, styleTable)
    end
end

local function HideStockPartyBits(host)
    if type(host) ~= "table" then
        return
    end
    pcall(function()
        if host.levelLabel ~= nil and host.levelLabel.Show ~= nil then
            host.levelLabel:Show(false)
        end
    end)
end

local function CreateChildWidgetCompat(parent, widgetType, widgetId)
    local child = nil
    pcall(function()
        if parent ~= nil and parent.CreateChildWidget ~= nil then
            child = parent:CreateChildWidget(widgetType, widgetId, 0, true)
        end
    end)
    if child == nil and api ~= nil and api.Interface ~= nil and api.Interface.CreateWidget ~= nil then
        pcall(function()
            child = api.Interface:CreateWidget(widgetType, widgetId, parent)
        end)
    end
    return child
end

local function CreatePartyOverlayLabel(parent, widgetId, width, height, fontSize, align)
    local label = nil
    pcall(function()
        label = api.Interface:CreateWidget("label", widgetId, parent)
    end)
    if label == nil then
        return nil
    end
    pcall(function()
        if label.SetExtent ~= nil then
            label:SetExtent(width or 180, height or 14)
        end
        if label.SetLimitWidth ~= nil then
            label:SetLimitWidth(true)
        end
        if label.style ~= nil then
            if align ~= nil and label.style.SetAlign ~= nil then
                label.style:SetAlign(align)
            end
            if fontSize ~= nil and label.style.SetFontSize ~= nil then
                label.style:SetFontSize(fontSize)
            end
        end
        label:Show(true)
    end)
    SetNotClickable(label)
    return label
end

local function FreePartyOverlay(unit)
    local record = UI.party.overlays[unit]
    if record == nil then
        return
    end
    pcall(function()
        if record.frame ~= nil then
            record.frame:Show(false)
        end
    end)
    pcall(function()
        if record.frame ~= nil and api ~= nil and api.Interface ~= nil and api.Interface.Free ~= nil then
            api.Interface:Free(record.frame)
        end
    end)
    UI.party.overlays[unit] = nil
end

local function ClearPartyOverlays()
    local keys = {}
    for unit in pairs(UI.party.overlays or {}) do
        keys[#keys + 1] = unit
    end
    for _, unit in ipairs(keys) do
        FreePartyOverlay(unit)
    end
end

local function GetPartyManager()
    if Runtime == nil or Runtime.GetStockContent == nil or UIC == nil or UIC.RAID_MANAGER == nil then
        return nil
    end
    return Runtime.GetStockContent(UIC.RAID_MANAGER)
end

local function GetPartyMemberHosts()
    local manager = GetPartyManager()
    UI.party.manager = manager
    if manager == nil or type(manager.party) ~= "table" then
        return {}
    end

    local hosts = {}
    for partyIndex = 1, PARTY_MAX_GROUPS do
        local partyFrame = manager.party[partyIndex]
        local members = type(partyFrame) == "table" and type(partyFrame.member) == "table" and partyFrame.member or nil
        if members ~= nil then
            for slot = 1, PARTY_MEMBERS_PER_GROUP do
                local memberFrame = members[slot]
                if type(memberFrame) == "table" then
                    local unit = TrimText(memberFrame.target)
                    if unit ~= "" then
                        hosts[#hosts + 1] = {
                            unit = unit,
                            host = memberFrame
                        }
                    end
                end
            end
        end
    end

    return hosts
end

local function EnsurePartyOverlay(host, unit)
    local record = UI.party.overlays[unit]
    if record ~= nil and record.host == host and record.frame ~= nil then
        return record
    end
    if record ~= nil then
        FreePartyOverlay(unit)
    end

    local frameId = "polarUiParty_" .. tostring(unit)
    local frame = CreateChildWidgetCompat(host, "emptywidget", frameId)
    if frame == nil then
        return nil
    end
    pcall(function()
        if frame.RemoveAllAnchors ~= nil then
            frame:RemoveAllAnchors()
        end
        if frame.AddAnchor ~= nil then
            local ok = pcall(function()
                frame:AddAnchor("TOPLEFT", host, "TOPLEFT", 0, 0)
            end)
            if not ok then
                pcall(function()
                    frame:AddAnchor("TOPLEFT", host, 0, 0)
                end)
            end
        end
        frame:Show(false)
    end)
    SetNotClickable(frame)
    pcall(function()
        if frame.EnablePick ~= nil then
            frame:EnablePick(false)
        end
    end)

    local hpBar = nil
    local mpBar = nil
    pcall(function()
        if W_BAR ~= nil and W_BAR.CreateStatusBarOfRaidFrame ~= nil then
            hpBar = W_BAR.CreateStatusBarOfRaidFrame(frameId .. ".hpBar", frame)
            mpBar = W_BAR.CreateStatusBarOfRaidFrame(frameId .. ".mpBar", frame)
        end
    end)
    if hpBar == nil or mpBar == nil then
        pcall(function()
            if api ~= nil and api.Interface ~= nil and api.Interface.Free ~= nil then
                api.Interface:Free(frame)
            end
        end)
        return nil
    end

    pcall(function()
        hpBar:Show(true)
        mpBar:Show(true)
    end)
    SetNotClickable(hpBar)
    SetNotClickable(mpBar)
    if hpBar.statusBar ~= nil then
        SetNotClickable(hpBar.statusBar)
    end
    if mpBar.statusBar ~= nil then
        SetNotClickable(mpBar.statusBar)
    end

    local nameLabel = CreatePartyOverlayLabel(frame, frameId .. ".name", 220, 16, 14, ALIGN.LEFT)
    local levelLabel = CreatePartyOverlayLabel(frame, frameId .. ".level", 28, 14, 12, ALIGN.LEFT)
    local hpValueLabel = CreatePartyOverlayLabel(frame, frameId .. ".hpValue", 120, 14, 16, ALIGN.CENTER)
    local mpValueLabel = CreatePartyOverlayLabel(frame, frameId .. ".mpValue", 120, 12, 11, ALIGN.CENTER)
    if nameLabel ~= nil then
        pcall(function()
            nameLabel:AddAnchor("TOPLEFT", frame, 4, -2)
        end)
    end
    if levelLabel ~= nil then
        pcall(function()
            levelLabel:AddAnchor("TOPLEFT", frame, 2, -2)
        end)
    end

    hpBar.hpLabel = hpValueLabel
    mpBar.mpLabel = mpValueLabel

    frame.name = nameLabel
    frame.level = { label = levelLabel }
    frame.hpBar = hpBar
    frame.mpBar = mpBar
    frame.__polar_unit = unit
    frame.__polar_small_hpmp = true
    frame.__polar_party_overlay = true

    HideStockPartyBits(host)

    record = {
        unit = unit,
        host = host,
        frame = frame,
        last_style_generation = -1,
        unit_id = nil,
        cached_name = "",
        cached_level = nil
    }
    UI.party.overlays[unit] = record
    return record
end

local function ApplyPartyOverlayStyle(record, settings)
    if type(record) ~= "table" or type(settings) ~= "table" or type(settings.style) ~= "table" then
        return
    end

    local baseStyle = settings.style
    local styleFrames = type(baseStyle.frames) == "table" and baseStyle.frames or {}
    record.frame.__polar_style_override = MergeStyleTables(baseStyle, styleFrames.party)
    ApplyFrameLayout(record.frame, settings)
    ApplyStockFrameStyle(record.frame, record.frame.__polar_style_override or baseStyle)
    local alpha = tonumber(record.frame.__polar_style_override.frame_alpha)
    if alpha == nil then
        alpha = tonumber(settings.frame_alpha)
    end
    ApplyFrameAlpha(record.frame, alpha)
    record.last_style_generation = tonumber(UI.party.style_generation) or 0
end

local function UpdatePartyOverlayData(record, settings)
    if type(record) ~= "table" or record.frame == nil or type(settings) ~= "table" then
        return
    end

    local shown = UI.enabled and record.host ~= nil and record.host.IsVisible ~= nil and record.host:IsVisible()
    if not shown then
        SetWidgetVisible(record.frame, false)
        return
    end

    local unit = record.unit
    local unitId = nil
    if Runtime ~= nil and Runtime.GetUnitId ~= nil then
        unitId = Runtime.GetUnitId(unit)
    end
    if unitId == nil then
        SetWidgetVisible(record.frame, false)
        return
    end

    if record.unit_id ~= unitId or record.cached_name == "" or record.cached_level == nil then
        record.unit_id = unitId
        record.cached_name = ""
        record.cached_level = nil
        local info = SafeGetUnitInfoById(unitId)
        if type(info) == "table" then
            record.cached_name = ResolveUnitDisplayName(info)
            record.cached_level = ResolveUnitLevel(info)
        end
    end

    local nameText = ""
    if Runtime ~= nil and Runtime.GetUnitName ~= nil then
        nameText = TrimText(Runtime.GetUnitName(unit))
    end
    if nameText == "" then
        nameText = tostring(record.cached_name or "")
    end
    SetLabelTextIfChanged(record.frame.name, nameText)

    local levelText = ""
    if type(record.cached_level) == "number" and record.cached_level > 0 then
        levelText = tostring(record.cached_level)
    end
    SetLabelTextIfChanged(record.frame.level ~= nil and record.frame.level.label or nil, levelText)

    local vitals = GetUnitVitals(unit)
    if vitals == nil or vitals.hp == nil or vitals.hp_max == nil then
        SetWidgetVisible(record.frame, false)
        return
    end

    if record.frame.hpBar ~= nil then
        SafeSetBarValue(record.frame.hpBar.statusBar or record.frame.hpBar, vitals.hp_max, vitals.hp)
    end

    local hasMp = vitals.mp ~= nil and vitals.mp_max ~= nil and vitals.mp_max > 0
    if record.frame.mpBar ~= nil then
        SetWidgetVisible(record.frame.mpBar, hasMp)
        if hasMp then
            SafeSetBarValue(record.frame.mpBar.statusBar or record.frame.mpBar, vitals.mp_max, vitals.mp)
        end
    end
    local style = record.frame.__polar_style_override or settings.style
    local showHpValue = type(style) ~= "table" or style.hp_value_visible ~= false
    local showMpValue = hasMp and (type(style) ~= "table" or style.mp_value_visible ~= false)
    if record.frame.hpBar ~= nil and record.frame.hpBar.hpLabel ~= nil then
        SetWidgetVisible(record.frame.hpBar.hpLabel, showHpValue)
    end
    if record.frame.mpBar ~= nil and record.frame.mpBar.mpLabel ~= nil then
        SetWidgetVisible(record.frame.mpBar.mpLabel, showMpValue)
    end

    local hpText = BuildFormattedValueText(vitals.hp, vitals.hp_max, style, true) or ""
    if showHpValue then
        SetLabelTextIfChanged(record.frame.hpBar ~= nil and record.frame.hpBar.hpLabel or nil, hpText)
    end

    local mpText = ""
    if hasMp then
        mpText = BuildFormattedValueText(vitals.mp, vitals.mp_max, style, true) or ""
    end
    if showMpValue then
        SetLabelTextIfChanged(record.frame.mpBar ~= nil and record.frame.mpBar.mpLabel or nil, mpText)
    end
    RefreshFrameBarPresentation(record.frame, style)
    SetWidgetVisible(record.frame, true)
    HideStockPartyBits(record.host)
end

local function UpdatePartyOverlays(settings)
    local seen = {}
    local members = GetPartyMemberHosts()
    for _, entry in ipairs(members) do
        seen[entry.unit] = true
        local record = EnsurePartyOverlay(entry.host, entry.unit)
        if record ~= nil then
            if record.last_style_generation ~= (tonumber(UI.party.style_generation) or 0) then
                ApplyPartyOverlayStyle(record, settings)
            end
            UpdatePartyOverlayData(record, settings)
        end
    end

    for unit, record in pairs(UI.party.overlays or {}) do
        if not seen[unit] then
            if record ~= nil and record.frame ~= nil then
                SetWidgetVisible(record.frame, false)
            end
            FreePartyOverlay(unit)
        end
    end
end

local function RefreshTrackedStockFrameBars()
    RefreshFrameBarPresentation(UI.player.wnd, nil)
    RefreshFrameBarPresentation(UI.target.wnd, nil)
    RefreshFrameBarPresentation(UI.watchtarget.wnd, nil)
    RefreshFrameBarPresentation(UI.target_of_target.wnd, nil)
end

local function RefreshTrackedStockFrameValueText(baseStyle)
    baseStyle = type(baseStyle) == "table" and baseStyle or (type(UI.settings) == "table" and UI.settings.style or {})
    if UI.player.wnd ~= nil then
        ApplyValueTextFormat(UI.player.wnd, UI.player.wnd.__polar_style_override or baseStyle)
    end
    if UI.target.wnd ~= nil then
        ApplyValueTextFormat(UI.target.wnd, UI.target.wnd.__polar_style_override or baseStyle)
    end
    if UI.watchtarget.wnd ~= nil then
        ApplyValueTextFormat(UI.watchtarget.wnd, UI.watchtarget.wnd.__polar_style_override or baseStyle)
    end
    if UI.target_of_target.wnd ~= nil then
        ApplyValueTextFormat(UI.target_of_target.wnd, UI.target_of_target.wnd.__polar_style_override or baseStyle)
    end
end

local function ApplyAuraLayout(frame, aura)
    if frame == nil or type(aura) ~= "table" then
        return
    end

    local iconSize = tonumber(aura.icon_size) or 24
    local xGap = tonumber(aura.icon_x_gap) or 2
    local yGap = tonumber(aura.icon_y_gap) or 2
    local perRow = tonumber(aura.buffs_per_row) or 10
    local sortVertical = aura.sort_vertical and true or false
    local reverseGrowth = aura.reverse_growth and true or false

    local function ApplyOverrideFields(window)
        if window == nil then
            return
        end
        local o = window.__polar_aura_override
        if type(o) ~= "table" then
            return
        end
        if window.iconSize ~= nil then
            window.iconSize = o.iconSize
        end
        if window.iconXGap ~= nil then
            window.iconXGap = o.iconXGap
        end
        if window.iconYGap ~= nil then
            window.iconYGap = o.iconYGap
        end
        if window.buffCountOnSingleLine ~= nil then
            window.buffCountOnSingleLine = o.buffCountOnSingleLine
        end
        if window.iconSortVertical ~= nil then
            window.iconSortVertical = o.iconSortVertical
        end
    end

    local function ForceLayoutButtons(window)
        if window == nil then
            return
        end
        local o = window.__polar_aura_override
        if type(o) ~= "table" then
            return
        end
        local btns = window.button
        if type(btns) ~= "table" then
            return
        end

        local perLine = tonumber(o.buffCountOnSingleLine) or 10
        if perLine < 1 then
            perLine = 1
        end
        local iconSizeLocal = tonumber(o.iconSize) or 24
        local xGapLocal = tonumber(o.iconXGap) or 2
        local yGapLocal = tonumber(o.iconYGap) or 2
        local sortVerticalLocal = o.iconSortVertical and true or false
        local reverseGrowthLocal = o.reverseGrowth and true or false

        local visible = tonumber(window.visibleBuffCount)
        if visible == nil or visible < 1 then
            visible = #btns
        end
        if visible < 1 then
            return
        end

        for i = 1, visible do
            local b = btns[i]
            if b ~= nil then
                pcall(function()
                    if b.RemoveAllAnchors ~= nil then
                        b:RemoveAllAnchors()
                    end

                    local row = 0
                    local col = 0
                    if sortVerticalLocal then
                        col = math.floor((i - 1) / perLine)
                        row = (i - 1) % perLine
                    else
                        row = math.floor((i - 1) / perLine)
                        col = (i - 1) % perLine
                    end

                    local x = col * (iconSizeLocal + xGapLocal)
                    local y = (reverseGrowthLocal and 1 or -1) * row * (iconSizeLocal + yGapLocal)

                    if b.AddAnchor ~= nil then
                        local ok = pcall(function()
                            b:AddAnchor("TOPLEFT", window, x, y)
                        end)
                        if not ok then
                            pcall(function()
                                b:AddAnchor("TOPLEFT", window, "TOPLEFT", x, y)
                            end)
                        end
                    end

                    if b.SetExtent ~= nil then
                        b:SetExtent(iconSizeLocal, iconSizeLocal)
                    end
                end)
            end
        end
    end

    local function SetWindowAuraOverride(window)
        if window == nil then
            return
        end

        if type(window.__polar_aura_override) ~= "table" then
            window.__polar_aura_override = {}
        end
        window.__polar_aura_override.iconSize = iconSize
        window.__polar_aura_override.iconXGap = xGap
        window.__polar_aura_override.iconYGap = yGap
        window.__polar_aura_override.buffCountOnSingleLine = perRow
        window.__polar_aura_override.iconSortVertical = sortVertical
        window.__polar_aura_override.reverseGrowth = reverseGrowth

        if window.__polar_aura_hooked then
            return
        end
        window.__polar_aura_hooked = true

        pcall(function()
            if type(window.SetLayout) == "function" then
                window.__polar_orig_SetLayout = window.SetLayout
                window.SetLayout = function(self, ...)
                    ApplyOverrideFields(self)
                    local out = nil
                    if type(self.__polar_orig_SetLayout) == "function" then
                        out = self:__polar_orig_SetLayout(...)
                    end
                    ApplyOverrideFields(self)
                    ForceLayoutButtons(self)
                    return out
                end
            end
        end)

        pcall(function()
            if type(window.BuffUpdate) == "function" then
                window.__polar_orig_BuffUpdate = window.BuffUpdate
                window.BuffUpdate = function(self, ...)
                    ApplyOverrideFields(self)
                    local out = nil
                    if type(self.__polar_orig_BuffUpdate) == "function" then
                        out = self:__polar_orig_BuffUpdate(...)
                    end
                    ApplyOverrideFields(self)
                    ForceLayoutButtons(self)
                    return out
                end
            end
        end)
    end

    local function applyTo(window)
        if window == nil then
            return
        end

        SetWindowAuraOverride(window)

        local function setFields()
            if window.iconSize ~= nil then
                window.iconSize = iconSize
            end
            if window.iconXGap ~= nil then
                window.iconXGap = xGap
            end
            if window.iconYGap ~= nil then
                window.iconYGap = yGap
            end
            if window.buffCountOnSingleLine ~= nil then
                window.buffCountOnSingleLine = perRow
            end
            if window.iconSortVertical ~= nil then
                window.iconSortVertical = sortVertical
            end
        end

        pcall(function()
            setFields()
            if window.SetVisibleBuffCount ~= nil and window.visibleBuffCount ~= nil then
                window:SetVisibleBuffCount(window.visibleBuffCount)
            end
            if window.SetLayout ~= nil then
                window:SetLayout()
            end

            setFields()
            if window.BuffUpdate ~= nil then
                window:BuffUpdate()
            end

            setFields()
            ForceLayoutButtons(window)
        end)
    end

    applyTo(frame.buffWindow)
    applyTo(frame.debuffWindow)
end

local function ClearAuraOverride(frame)
    if frame == nil then
        return
    end

    local function clearWindow(window)
        if window == nil then
            return
        end
        window.__polar_aura_override = nil
        if window.__polar_aura_hooked then
            window.__polar_aura_hooked = nil
            pcall(function()
                if type(window.__polar_orig_SetLayout) == "function" then
                    window.SetLayout = window.__polar_orig_SetLayout
                end
                window.__polar_orig_SetLayout = nil
            end)
            pcall(function()
                if type(window.__polar_orig_BuffUpdate) == "function" then
                    window.BuffUpdate = window.__polar_orig_BuffUpdate
                end
                window.__polar_orig_BuffUpdate = nil
            end)
        end
    end

    clearWindow(frame.buffWindow)
    clearWindow(frame.debuffWindow)
end

local function ApplyFrameRefreshOverrides(frame)
    if frame == nil or frame.__polar_frame_refresh_applying then
        return
    end

    frame.__polar_frame_refresh_applying = true
    if type(frame.__polar_aura_frame_cfg) == "table" then
        ApplyAuraLayout(frame, frame.__polar_aura_frame_cfg)
    end
    if type(frame.__polar_buff_place_cfg) == "table" then
        ApplyBuffWindowPlacement(frame, frame.__polar_buff_place_cfg)
    end
    frame.__polar_frame_refresh_applying = nil
end

local function EnsureFrameRefreshHook(frame)
    if frame == nil or frame.__polar_frame_refresh_hooked then
        return
    end
    frame.__polar_frame_refresh_hooked = true

    local function wrap(methodName)
        if type(frame[methodName]) ~= "function" then
            return
        end

        local origKey = "__polar_refresh_orig_" .. methodName
        if type(frame[origKey]) == "function" then
            return
        end

        frame[origKey] = frame[methodName]
        frame[methodName] = function(self, ...)
            local orig = self[origKey]
            ApplyFrameRefreshOverrides(self)

            local out = nil
            if type(orig) == "function" then
                out = orig(self, ...)
            end

            ApplyFrameRefreshOverrides(self)
            return out
        end
    end

    pcall(function()
        wrap("UpdateBuffDebuff")
        wrap("UpdateAll")
    end)
end

local function SetAuraFrameHook(frame, aura)
    if frame == nil then
        return
    end
    frame.__polar_aura_frame_cfg = type(aura) == "table" and aura or nil
    EnsureFrameRefreshHook(frame)
end

local function SetBuffWindowPlacementHook(frame, cfg)
    if frame == nil then
        return
    end
    frame.__polar_buff_place_cfg = type(cfg) == "table" and cfg or nil
    EnsureFrameRefreshHook(frame)
end

local function ClearFrameRefreshHookIfUnused(frame)
    if frame == nil then
        return
    end
    if type(frame.__polar_aura_frame_cfg) == "table" or type(frame.__polar_buff_place_cfg) == "table" then
        return
    end

    if not frame.__polar_frame_refresh_hooked then
        return
    end
    frame.__polar_frame_refresh_hooked = nil

    local function restore(methodName)
        local origKey = "__polar_refresh_orig_" .. methodName
        if type(frame[origKey]) == "function" then
            frame[methodName] = frame[origKey]
        end
        frame[origKey] = nil
    end

    pcall(function()
        restore("UpdateBuffDebuff")
        restore("UpdateAll")
    end)
end

local function ClearAuraFrameHook(frame)
    if frame == nil then
        return
    end

    frame.__polar_aura_frame_cfg = nil
    ClearFrameRefreshHookIfUnused(frame)
end

local function ClearBuffWindowPlacementHook(frame)
    if frame == nil then
        return
    end
    frame.__polar_buff_place_cfg = nil
    ClearFrameRefreshHookIfUnused(frame)
end

local function AuraWindowMatches(window, aura)
    if window == nil or type(aura) ~= "table" then
        return true
    end
    local iconSize = tonumber(aura.icon_size) or 24
    local xGap = tonumber(aura.icon_x_gap) or 2
    local yGap = tonumber(aura.icon_y_gap) or 2
    local perRow = tonumber(aura.buffs_per_row) or 10
    local sortVertical = aura.sort_vertical and true or false
    local reverseGrowth = aura.reverse_growth and true or false

    if window.iconSize ~= nil and window.iconSize ~= iconSize then
        return false
    end
    if window.iconXGap ~= nil and window.iconXGap ~= xGap then
        return false
    end
    if window.iconYGap ~= nil and window.iconYGap ~= yGap then
        return false
    end
    if window.buffCountOnSingleLine ~= nil and window.buffCountOnSingleLine ~= perRow then
        return false
    end
    if window.iconSortVertical ~= nil and (window.iconSortVertical and true or false) ~= sortVertical then
        return false
    end
    if type(window.__polar_aura_override) == "table" and (window.__polar_aura_override.reverseGrowth and true or false) ~= reverseGrowth then
        return false
    end

    return true
end

local function FrameAuraNeedsApply(frame, aura)
    if frame == nil or type(aura) ~= "table" then
        return false
    end
    if not AuraWindowMatches(frame.buffWindow, aura) then
        return true
    end
    if not AuraWindowMatches(frame.debuffWindow, aura) then
        return true
    end
    return false
end

local function GetAuraCfgKey(aura)
    if type(aura) ~= "table" then
        return nil
    end
    local iconSize = tonumber(aura.icon_size) or 24
    local xGap = tonumber(aura.icon_x_gap) or 2
    local yGap = tonumber(aura.icon_y_gap) or 2
    local perRow = tonumber(aura.buffs_per_row) or 10
    local sortVertical = aura.sort_vertical and 1 or 0
    local reverseGrowth = aura.reverse_growth and 1 or 0
    return string.format("%d:%d:%d:%d:%d:%d", iconSize, xGap, yGap, perRow, sortVertical, reverseGrowth)
end

ApplyBuffWindowPlacement = function(frame, cfg)
    if frame == nil or type(cfg) ~= "table" then
        return
    end

    local function Key(p)
        if type(p) ~= "table" then
            return ""
        end
        return string.format("%s:%d:%d", tostring(p.anchor or ""), tonumber(p.x) or 0, tonumber(p.y) or 0)
    end

    local function Place(widget, placement)
        if widget == nil or type(placement) ~= "table" then
            return
        end
        local anchor = placement.anchor
        if type(anchor) ~= "string" or anchor == "" then
            anchor = "TOPLEFT"
        end
        local x = tonumber(placement.x) or 0
        local y = tonumber(placement.y) or 0

        pcall(function()
            if widget.RemoveAllAnchors ~= nil then
                widget:RemoveAllAnchors()
            end
            if widget.AddAnchor ~= nil then
                local ok = pcall(function()
                    widget:AddAnchor(anchor, frame, anchor, x, y)
                end)
                if not ok then
                    pcall(function()
                        widget:AddAnchor(anchor, frame, x, y)
                    end)
                end
            end
        end)
    end

    Place(frame.buffWindow, cfg.buff)
    Place(frame.debuffWindow, cfg.debuff)

    local placeKey = Key(cfg.buff) .. "|" .. Key(cfg.debuff)
    if frame.__polar_last_buff_place_key ~= placeKey then
        frame.__polar_last_buff_place_key = placeKey
    end
end

ApplyStockFrameStyle = function(frame, style)
    if frame == nil or type(style) ~= "table" then
        return
    end

    pcall(function()
        if frame.name ~= nil and frame.name.style ~= nil then
            local nameSize = tonumber(style.name_font_size)
            if nameSize ~= nil then
                frame.name.style:SetFontSize(nameSize)
            end
            if style.name_shadow ~= nil then
                frame.name.style:SetShadow(style.name_shadow and true or false)
            end
            ApplyTextColor(frame.name, FONT_COLOR.WHITE)
        end
    end)

    ApplyStockFrameDecorations(frame, UI.settings)
    ApplyTextLayout(frame, style)
    RefreshFrameBarPresentation(frame, style)

    pcall(function()
        local function SafeAnchor(widget, target)
            if widget == nil or widget.AddAnchor == nil then
                return
            end
            local ox = 0
            local oy = 0
            if widget == frame.hpBar.hpLabel then
                ox = tonumber(style.hp_value_offset_x) or 0
                oy = tonumber(style.hp_value_offset_y) or 0
            elseif widget == frame.mpBar.mpLabel then
                ox = tonumber(style.mp_value_offset_x) or 0
                oy = tonumber(style.mp_value_offset_y) or 0
            end

            local ok = pcall(function()
                widget:AddAnchor("CENTER", target, ox, oy)
            end)
            if not ok then
                pcall(function()
                    widget:AddAnchor("CENTER", target, "CENTER", ox, oy)
                end)
            end
        end

        if frame.hpBar ~= nil and frame.hpBar.hpLabel ~= nil and frame.hpBar.hpLabel.style ~= nil then
            frame.hpBar.hpLabel.style:SetFontSize(tonumber(style.hp_font_size) or 16)
            if style.value_shadow ~= nil then
                frame.hpBar.hpLabel.style:SetShadow(style.value_shadow and true or false)
            end
            SetNotClickable(frame.hpBar.hpLabel)
            if frame.hpBar.hpLabel.RemoveAllAnchors ~= nil then
                frame.hpBar.hpLabel:RemoveAllAnchors()
            end
            SafeAnchor(frame.hpBar.hpLabel, frame.hpBar)
        end

        if frame.mpBar ~= nil and frame.mpBar.mpLabel ~= nil and frame.mpBar.mpLabel.style ~= nil then
            frame.mpBar.mpLabel.style:SetFontSize(tonumber(style.mp_font_size) or 11)
            if style.value_shadow ~= nil then
                frame.mpBar.mpLabel.style:SetShadow(style.value_shadow and true or false)
            end
            SetNotClickable(frame.mpBar.mpLabel)
            if frame.mpBar.mpLabel.RemoveAllAnchors ~= nil then
                frame.mpBar.mpLabel:RemoveAllAnchors()
            end
            SafeAnchor(frame.mpBar.mpLabel, frame.mpBar)
        end
        ApplyValueLabelVisibility(frame, style)
    end)
end

BuildUiContext = function()
    return {
        UI = UI,
        api = api,
        Runtime = Runtime,
        SetNotClickable = SetNotClickable,
        SafeGetExtent = SafeGetExtent,
        ApplyTextColor = ApplyTextColor,
        ApplyOverlayAlpha = ApplyOverlayAlpha,
        ResolveUnitDisplayName = ResolveUnitDisplayName,
        ResolveUnitLevelParts = ResolveUnitLevelParts,
        ResolveUnitLevel = ResolveUnitLevel,
        SafeUnitInfo = SafeUnitInfo,
        SafeGetUnitInfoById = SafeGetUnitInfoById,
        ApplyTargetNameLevel = ApplyTargetNameLevel,
        TrimText = TrimText,
        NormalizeUnitId = NormalizeUnitId
    }
end

local function EnsureUi(settings)
    EnsureAlignmentGrid(settings)

    UI.player.wnd = GetStockContent(UIC.PLAYER_UNITFRAME)
    UI.target.wnd = GetStockContent(UIC.TARGET_UNITFRAME)
    UI.watchtarget.wnd = GetStockContent(UIC.WATCH_TARGET_FRAME)
    UI.target_of_target.wnd = GetStockContent(UIC.TARGET_OF_TARGET_FRAME)

    if UI.player.wnd ~= nil then
        UI.player.wnd.__polar_unit = "player"
        UI.player.wnd.__polar_small_hpmp = nil
    end
    if UI.target.wnd ~= nil then
        UI.target.wnd.__polar_unit = "target"
        UI.target.wnd.__polar_small_hpmp = nil
    end
    if UI.watchtarget.wnd ~= nil then
        UI.watchtarget.wnd.__polar_unit = "watchtarget"
        UI.watchtarget.wnd.__polar_runtime_unit = "watchtarget"
        UI.watchtarget.wnd.__polar_small_hpmp = true
    end
    if UI.target_of_target.wnd ~= nil then
        UI.target_of_target.wnd.__polar_unit = "targettarget"
        UI.target_of_target.wnd.__polar_runtime_unit = "targettarget"
        UI.target_of_target.wnd.__polar_small_hpmp = true
    end

    if UI.target.wnd ~= nil then
        HideLegacyPolarDistanceOverlay(UI.target.wnd)
    end

    local baseStyle = nil
    if type(settings) == "table" and type(settings.style) == "table" then
        baseStyle = settings.style
    else
        baseStyle = {}
    end

    local styleFrames = (type(baseStyle.frames) == "table") and baseStyle.frames or {}
    if UI.player.wnd ~= nil then
        UI.player.wnd.__polar_style_override = MergeStyleTables(baseStyle, styleFrames.player)
    end
    if UI.target.wnd ~= nil then
        UI.target.wnd.__polar_style_override = MergeStyleTables(baseStyle, styleFrames.target)
    end
    if UI.watchtarget.wnd ~= nil then
        UI.watchtarget.wnd.__polar_style_override = MergeStyleTables(baseStyle, styleFrames.watchtarget)
    end
    if UI.target_of_target.wnd ~= nil then
        UI.target_of_target.wnd.__polar_style_override = MergeStyleTables(baseStyle, styleFrames.target_of_target)
    end
    UI.party.style_generation = (tonumber(UI.party.style_generation) or 0) + 1

    if not UI.enabled then
        UpdatePartyOverlays(settings)
        ApplyStockDistanceSetting()
        return
    end

    EnsureClassIconFrames()

    HookUnitFrameDrag(UI.player.wnd, settings, "player")
    HookUnitFrameDrag(UI.target.wnd, settings, "target")
    HookUnitFrameDrag(UI.watchtarget.wnd, settings, "watchtarget")
    HookUnitFrameDrag(UI.target_of_target.wnd, settings, "target_of_target")
    SyncAllUnitFrameDragState(settings)

    SetFramePositionHook(UI.player.wnd, settings, "player", 10, 300)
    SetFramePositionHook(UI.target.wnd, settings, "target", 10, 380)
    SetFramePositionHook(UI.watchtarget.wnd, settings, "watchtarget", 10, 460)
    SetFramePositionHook(UI.target_of_target.wnd, settings, "target_of_target", 10, 540)

    SetFrameStyleHook(UI.player.wnd, settings)
    SetFrameStyleHook(UI.target.wnd, settings)
    SetFrameStyleHook(UI.watchtarget.wnd, settings)
    SetFrameStyleHook(UI.target_of_target.wnd, settings)
    ApplyFrameLayout(UI.player.wnd, settings)
    ApplyFrameLayout(UI.target.wnd, settings)
    ApplyFrameLayout(UI.watchtarget.wnd, settings)
    ApplyFrameLayout(UI.target_of_target.wnd, settings)

    local function getFrameAlpha(wnd)
        if wnd ~= nil and type(wnd.__polar_style_override) == "table" then
            local a = tonumber(wnd.__polar_style_override.frame_alpha)
            if a ~= nil then
                return a
            end
        end
        return tonumber(settings.frame_alpha)
    end

    ApplyFrameAlpha(UI.player.wnd, getFrameAlpha(UI.player.wnd))
    ApplyFrameAlpha(UI.target.wnd, getFrameAlpha(UI.target.wnd))
    ApplyFrameAlpha(UI.watchtarget.wnd, getFrameAlpha(UI.watchtarget.wnd))
    ApplyFrameAlpha(UI.target_of_target.wnd, getFrameAlpha(UI.target_of_target.wnd))

    local wantLargeHpMp = baseStyle.large_hpmp and true or false
    if UI.last_large_hpmp == nil then
        UI.last_large_hpmp = wantLargeHpMp
    end

    local wantStockRefresh = (not UI.stock_refreshed) or (UI.last_large_hpmp ~= wantLargeHpMp)
    if wantStockRefresh then
        UI.stock_refreshed = true
        pcall(function()
            if UI.player.wnd ~= nil and UI.player.wnd.UpdateAll ~= nil then
                UI.player.wnd:UpdateAll()
            end
        end)
        pcall(function()
            if UI.target.wnd ~= nil and UI.target.wnd.UpdateAll ~= nil then
                UI.target.wnd:UpdateAll()
            end
        end)
        pcall(function()
            if UI.watchtarget.wnd ~= nil and UI.watchtarget.wnd.UpdateAll ~= nil then
                UI.watchtarget.wnd:UpdateAll()
            end
        end)
        pcall(function()
            if UI.target_of_target.wnd ~= nil and UI.target_of_target.wnd.UpdateAll ~= nil then
                UI.target_of_target.wnd:UpdateAll()
            end
        end)
    end

    SyncSecondaryFrameBinding(UI.watchtarget.wnd, "watchtarget")
    SyncSecondaryFrameBinding(UI.target_of_target.wnd, "targettarget")

    ApplyUnitFramePosition(UI.player.wnd, settings, "player", 10, 300)
    ApplyUnitFramePosition(UI.target.wnd, settings, "target", 10, 380)
    ApplyUnitFramePosition(UI.watchtarget.wnd, settings, "watchtarget", 10, 460)
    ApplyUnitFramePosition(UI.target_of_target.wnd, settings, "target_of_target", 10, 540)

    UI.last_large_hpmp = wantLargeHpMp

    if UI.player.wnd ~= nil then
        ApplyStockFrameStyle(UI.player.wnd, UI.player.wnd.__polar_style_override or baseStyle)
    end
    if UI.target.wnd ~= nil then
        ApplyStockFrameStyle(UI.target.wnd, UI.target.wnd.__polar_style_override or baseStyle)
    end
    if UI.watchtarget.wnd ~= nil then
        ApplyStockFrameStyle(UI.watchtarget.wnd, UI.watchtarget.wnd.__polar_style_override or baseStyle)
    end
    if UI.target_of_target.wnd ~= nil then
        ApplyStockFrameStyle(UI.target_of_target.wnd, UI.target_of_target.wnd.__polar_style_override or baseStyle)
    end
    RefreshFrameNameLevelFromUnit(UI.watchtarget.wnd, "watchtarget")
    RefreshFrameNameLevelFromUnit(UI.target_of_target.wnd, "targettarget")

    RefreshTrackedStockFrameBars()
    RefreshTrackedStockFrameValueText(baseStyle)

    UpdatePartyOverlays(settings)

    RefreshStockFrameDecorations(settings)

    local auraEnabled = type(baseStyle.aura) == "table" and (baseStyle.aura.enabled and true or false) or false
    local auraCfgKey = auraEnabled and GetAuraCfgKey(baseStyle.aura) or nil
    if UI.last_aura_enabled == nil then
        UI.last_aura_enabled = auraEnabled
    end

    if auraEnabled and type(baseStyle.aura) == "table" then
        SetAuraFrameHook(UI.player.wnd, baseStyle.aura)
        SetAuraFrameHook(UI.target.wnd, baseStyle.aura)
        if auraCfgKey ~= UI.last_aura_cfg or FrameAuraNeedsApply(UI.player.wnd, baseStyle.aura) or FrameAuraNeedsApply(UI.target.wnd, baseStyle.aura) then
            ApplyAuraLayout(UI.player.wnd, baseStyle.aura)
            ApplyAuraLayout(UI.target.wnd, baseStyle.aura)
        end
    elseif UI.last_aura_enabled then
        ClearAuraFrameHook(UI.player.wnd)
        ClearAuraFrameHook(UI.target.wnd)
        ClearAuraOverride(UI.player.wnd)
        ClearAuraOverride(UI.target.wnd)
        pcall(function()
            if UI.player.wnd ~= nil and UI.player.wnd.UpdateBuffDebuff ~= nil then
                UI.player.wnd:UpdateBuffDebuff()
            end
        end)
        pcall(function()
            if UI.target.wnd ~= nil and UI.target.wnd.UpdateBuffDebuff ~= nil then
                UI.target.wnd:UpdateBuffDebuff()
            end
        end)
        pcall(function()
            if UI.player.wnd ~= nil and UI.player.wnd.UpdateAll ~= nil then
                UI.player.wnd:UpdateAll()
            end
        end)
        pcall(function()
            if UI.target.wnd ~= nil and UI.target.wnd.UpdateAll ~= nil then
                UI.target.wnd:UpdateAll()
            end
        end)
    end

    if type(baseStyle.buff_windows) == "table" and baseStyle.buff_windows.enabled then
        if type(baseStyle.buff_windows.player) == "table" then
            SetBuffWindowPlacementHook(UI.player.wnd, baseStyle.buff_windows.player)
            ApplyBuffWindowPlacement(UI.player.wnd, baseStyle.buff_windows.player)
        else
            ClearBuffWindowPlacementHook(UI.player.wnd)
        end
        if type(baseStyle.buff_windows.target) == "table" then
            SetBuffWindowPlacementHook(UI.target.wnd, baseStyle.buff_windows.target)
            ApplyBuffWindowPlacement(UI.target.wnd, baseStyle.buff_windows.target)
        else
            ClearBuffWindowPlacementHook(UI.target.wnd)
        end
    else
        ClearBuffWindowPlacementHook(UI.player.wnd)
        ClearBuffWindowPlacementHook(UI.target.wnd)
    end

    UI.last_aura_enabled = auraEnabled
    UI.last_aura_cfg = auraCfgKey
    if TargetExtrasModule ~= nil and TargetExtrasModule.Ensure ~= nil then
        TargetExtrasModule.Ensure(BuildUiContext(), settings, baseStyle)
    end
end

local function UpdateTargetExtras(settings)
    if TargetExtrasModule ~= nil and TargetExtrasModule.Update ~= nil then
        TargetExtrasModule.Update(BuildUiContext(), settings)
    end
end

UI.ApplySettings = function(settings)
    if type(settings) ~= "table" then
        return
    end

    UI.settings = settings
    EnsureAlignmentGrid(settings)

    if Nameplates ~= nil and Nameplates.ApplySettings ~= nil then
        pcall(function()
            Nameplates.ApplySettings(settings)
        end)
    end
    if CooldownTracker ~= nil and CooldownTracker.ApplySettings ~= nil then
        pcall(function()
            CooldownTracker.ApplySettings(settings)
        end)
    end
    if CastBar ~= nil and CastBar.ApplySettings ~= nil then
        pcall(function()
            CastBar.ApplySettings(settings)
        end)
    end
    if TravelSpeed ~= nil and TravelSpeed.ApplySettings ~= nil then
        pcall(function()
            TravelSpeed.ApplySettings(settings)
        end)
    end
    if MountGlider ~= nil and MountGlider.ApplySettings ~= nil then
        pcall(function()
            MountGlider.ApplySettings(settings)
        end)
    end
    if GearLoadouts ~= nil and GearLoadouts.ApplySettings ~= nil then
        pcall(function()
            GearLoadouts.ApplySettings(settings)
        end)
    end
    if QuestWatch ~= nil and QuestWatch.ApplySettings ~= nil then
        pcall(function()
            QuestWatch.ApplySettings(settings)
        end)
    end

    local wantEnabled = settings.enabled and true or false
    local enabledChanged = (UI.enabled and true or false) ~= wantEnabled

    if enabledChanged then
        UI.SetEnabled(wantEnabled)
    end

    EnsureUi(settings)
end

UI.Init = function(settings)
    UI.settings = settings
    UI.enabled = settings.enabled and true or false
    UI.accum_ms = 0
    UI.plates_accum_ms = 0
    UI.plates_position_accum_ms = 0
    UI.needs_full_apply = true
    UI.stock_refreshed = false
    UI.last_large_hpmp = nil
    UI.last_aura_enabled = nil
    EnsureAlignmentGrid(settings)
    EnsureUi(settings)
    if Nameplates ~= nil and Nameplates.Init ~= nil then
        pcall(function()
            Nameplates.Init(settings)
        end)
    end
    if CooldownTracker ~= nil and CooldownTracker.Init ~= nil then
        pcall(function()
            CooldownTracker.Init(settings)
        end)
    end
    if CastBar ~= nil and CastBar.Init ~= nil then
        pcall(function()
            CastBar.Init(settings)
        end)
    end
    if TravelSpeed ~= nil and TravelSpeed.Init ~= nil then
        pcall(function()
            TravelSpeed.Init(settings)
        end)
    end
    if MountGlider ~= nil and MountGlider.Init ~= nil then
        pcall(function()
            MountGlider.Init(settings)
        end)
    end
    if GearLoadouts ~= nil and GearLoadouts.Init ~= nil then
        pcall(function()
            GearLoadouts.Init(settings)
        end)
    end
    if QuestWatch ~= nil and QuestWatch.Init ~= nil then
        pcall(function()
            QuestWatch.Init(settings)
        end)
    end
    UI.SetEnabled(UI.enabled)
end

UI.UnLoad = function()
    if Nameplates ~= nil and Nameplates.Unload ~= nil then
        pcall(function()
            Nameplates.Unload()
        end)
    end
    if CooldownTracker ~= nil and CooldownTracker.Unload ~= nil then
        pcall(function()
            CooldownTracker.Unload()
        end)
    end
    if CastBar ~= nil and CastBar.Unload ~= nil then
        pcall(function()
            CastBar.Unload()
        end)
    end
    if TravelSpeed ~= nil and TravelSpeed.Unload ~= nil then
        pcall(function()
            TravelSpeed.Unload()
        end)
    end
    if MountGlider ~= nil and MountGlider.Unload ~= nil then
        pcall(function()
            MountGlider.Unload()
        end)
    end
    if GearLoadouts ~= nil and GearLoadouts.Unload ~= nil then
        pcall(function()
            GearLoadouts.Unload()
        end)
    end
    if QuestWatch ~= nil and QuestWatch.Unload ~= nil then
        pcall(function()
            QuestWatch.Unload()
        end)
    end
    if AlignmentModule ~= nil and AlignmentModule.Reset ~= nil then
        AlignmentModule.Reset(BuildUiContext())
    end
    UI.enabled = false
    local restoreValues = {
        hp_value_visible = true,
        mp_value_visible = true
    }
    ApplyValueLabelVisibility(UI.player.wnd, restoreValues)
    ApplyValueLabelVisibility(UI.target.wnd, restoreValues)
    ApplyValueLabelVisibility(UI.watchtarget.wnd, restoreValues)
    ApplyValueLabelVisibility(UI.target_of_target.wnd, restoreValues)
    RefreshFrameBarPresentation(UI.player.wnd, nil)
    RefreshFrameBarPresentation(UI.target.wnd, nil)
    RefreshFrameBarPresentation(UI.watchtarget.wnd, nil)
    RefreshFrameBarPresentation(UI.target_of_target.wnd, nil)
    ResetClassIconFrames()
    ClearPartyOverlays()
    for _, widget in ipairs(UI.created or {}) do
        pcall(function()
            if widget ~= nil and widget.Show ~= nil then
                widget:Show(false)
            end
        end)
        pcall(function()
            if widget ~= nil and api.Interface ~= nil and api.Interface.Free ~= nil then
                api.Interface:Free(widget)
            end
        end)
    end
    UI.created = {}
    UI.player.wnd = nil
    UI.target.wnd = nil
    UI.watchtarget.wnd = nil
    UI.target_of_target.wnd = nil
    UI.party.manager = nil
    UI.party.style_generation = 0
    UI.needs_full_apply = true
    UI.stock_refreshed = false
    UI.last_large_hpmp = nil
    UI.last_aura_enabled = nil
    UI.stock_distance_forced_hidden = false
    UI.target.guild = nil
    UI.target.class_name = nil
    UI.target.gearscore = nil
    UI.target.current_target_id = nil
    UI.target.pdef = nil
    UI.target.mdef = nil
    UI.target.custom_hp_bg = nil
    UI.target.custom_mp_bg = nil
end

UI.SetEnabled = function(enabled)
    UI.enabled = enabled and true or false
    UI.needs_full_apply = true

    if Nameplates ~= nil and Nameplates.SetEnabled ~= nil then
        pcall(function()
            Nameplates.SetEnabled(UI.enabled)
        end)
    end
    if CooldownTracker ~= nil and CooldownTracker.SetEnabled ~= nil then
        pcall(function()
            CooldownTracker.SetEnabled(UI.enabled)
        end)
    end
    if CastBar ~= nil and CastBar.SetEnabled ~= nil then
        pcall(function()
            CastBar.SetEnabled(UI.enabled)
        end)
    end
    if TravelSpeed ~= nil and TravelSpeed.SetEnabled ~= nil then
        pcall(function()
            TravelSpeed.SetEnabled(UI.enabled)
        end)
    end
    if MountGlider ~= nil and MountGlider.SetEnabled ~= nil then
        pcall(function()
            MountGlider.SetEnabled(UI.enabled)
        end)
    end
    if GearLoadouts ~= nil and GearLoadouts.SetEnabled ~= nil then
        pcall(function()
            GearLoadouts.SetEnabled(UI.enabled)
        end)
    end
    if QuestWatch ~= nil and QuestWatch.SetEnabled ~= nil then
        pcall(function()
            QuestWatch.SetEnabled(UI.enabled)
        end)
    end

    if not UI.enabled then
        ClearFrameStyleHook(UI.player.wnd)
        ClearFrameStyleHook(UI.target.wnd)
        ClearFrameStyleHook(UI.watchtarget.wnd)
        ClearFrameStyleHook(UI.target_of_target.wnd)
        ClearAuraFrameHook(UI.player.wnd)
        ClearAuraFrameHook(UI.target.wnd)
        ClearAuraOverride(UI.player.wnd)
        ClearAuraOverride(UI.target.wnd)
        local restoreValues = {
            hp_value_visible = true,
            mp_value_visible = true
        }
        ApplyValueLabelVisibility(UI.player.wnd, restoreValues)
        ApplyValueLabelVisibility(UI.target.wnd, restoreValues)
        ApplyValueLabelVisibility(UI.watchtarget.wnd, restoreValues)
        ApplyValueLabelVisibility(UI.target_of_target.wnd, restoreValues)
        ResetClassIconFrames()
        pcall(function()
            if UI.player.wnd ~= nil and UI.player.wnd.UpdateAll ~= nil then
                UI.player.wnd:UpdateAll()
            end
        end)
        pcall(function()
            if UI.target.wnd ~= nil and UI.target.wnd.UpdateAll ~= nil then
                UI.target.wnd:UpdateAll()
            end
        end)
        pcall(function()
            if UI.watchtarget.wnd ~= nil and UI.watchtarget.wnd.UpdateAll ~= nil then
                UI.watchtarget.wnd:UpdateAll()
            end
        end)
        pcall(function()
            if UI.target_of_target.wnd ~= nil and UI.target_of_target.wnd.UpdateAll ~= nil then
                UI.target_of_target.wnd:UpdateAll()
            end
        end)
        ApplyFrameAlpha(UI.player.wnd, 1)
        ApplyFrameAlpha(UI.target.wnd, 1)
        ApplyFrameAlpha(UI.watchtarget.wnd, 1)
        ApplyFrameAlpha(UI.target_of_target.wnd, 1)
        pcall(function()
            if UI.player.wnd ~= nil and UI.player.wnd.SetScale ~= nil then
                UI.player.wnd:SetScale(1)
            end
        end)
        pcall(function()
            if UI.target.wnd ~= nil and UI.target.wnd.SetScale ~= nil then
                UI.target.wnd:SetScale(1)
            end
        end)
        pcall(function()
            if UI.watchtarget.wnd ~= nil and UI.watchtarget.wnd.SetScale ~= nil then
                UI.watchtarget.wnd:SetScale(1)
            end
        end)
        pcall(function()
            if UI.target_of_target.wnd ~= nil and UI.target_of_target.wnd.SetScale ~= nil then
                UI.target_of_target.wnd:SetScale(1)
            end
        end)
        UI.stock_refreshed = false
        UI.last_large_hpmp = nil
        UI.last_aura_enabled = nil
        UI.last_aura_cfg = nil
    end

    if UI.target.class_name ~= nil and UI.target.class_name.Show ~= nil then
        if not UI.enabled then
            UI.target.class_name:Show(false)
        end
    end
    if UI.target.guild ~= nil and UI.target.guild.Show ~= nil then
        if not UI.enabled then
            UI.target.guild:Show(false)
        end
    end
    if UI.target.gearscore ~= nil and UI.target.gearscore.Show ~= nil then
        if not UI.enabled then
            UI.target.gearscore:Show(false)
        end
    end

    if UI.target.pdef ~= nil and UI.target.pdef.Show ~= nil then
        if not UI.enabled then
            UI.target.pdef:Show(false)
        end
    end

    if UI.target.mdef ~= nil and UI.target.mdef.Show ~= nil then
        if not UI.enabled then
            UI.target.mdef:Show(false)
        end
    end
    for _, bg in ipairs({ UI.target.custom_hp_bg, UI.target.custom_mp_bg }) do
        if bg ~= nil and bg.Show ~= nil and not UI.enabled then
            bg:Show(false)
        end
    end
    if UI.settings ~= nil then
        UpdatePartyOverlays(UI.settings)
    end
    ApplyStockDistanceSetting()
end

UI.OnUpdate = function(dt)
    if type(dt) ~= "number" then
        return
    end

    if UI.settings == nil then
        return
    end

    EnsureAlignmentGrid(UI.settings)
    SyncAllUnitFrameDragState(UI.settings)
    if UI.needs_full_apply
        or UI.player.wnd == nil
        or UI.target.wnd == nil
        or UI.watchtarget.wnd == nil
        or UI.target_of_target.wnd == nil then
        EnsureUi(UI.settings)
        UI.needs_full_apply = (
            UI.player.wnd == nil
            or UI.target.wnd == nil
            or UI.watchtarget.wnd == nil
            or UI.target_of_target.wnd == nil
        )
    end

    UI.plates_accum_ms = (tonumber(UI.plates_accum_ms) or 0) + dt
    UI.plates_position_accum_ms = (tonumber(UI.plates_position_accum_ms) or 0) + dt
    local fastInterval = 33
    local ranPlateUpdate = false
    if UI.plates_accum_ms >= fastInterval then
        UI.plates_accum_ms = 0
        UI.plates_position_accum_ms = 0
        ranPlateUpdate = true
        if Nameplates ~= nil and Nameplates.OnUpdate ~= nil then
            local ok, err = pcall(function()
                Nameplates.OnUpdate(UI.settings)
            end)
            if not ok and api.Log ~= nil and api.Log.Err ~= nil then
                api.Log:Err("[Nuzi UI] Nameplates.OnUpdate failed: " .. tostring(err))
            end
        end
    end
    if not ranPlateUpdate and UI.plates_position_accum_ms >= 16 then
        UI.plates_position_accum_ms = 0
        if Nameplates ~= nil and Nameplates.OnPositionUpdate ~= nil then
            local ok, err = pcall(function()
                Nameplates.OnPositionUpdate(UI.settings)
            end)
            if not ok and api.Log ~= nil and api.Log.Err ~= nil then
                api.Log:Err("[Nuzi UI] Nameplates.OnPositionUpdate failed: " .. tostring(err))
            end
        end
    end

    if CooldownTracker ~= nil and CooldownTracker.OnUpdate ~= nil then
        local ok, err = pcall(function()
            CooldownTracker.OnUpdate(dt, UI.settings)
        end)
        if not ok and api.Log ~= nil and api.Log.Err ~= nil then
            api.Log:Err("[Nuzi UI] CooldownTracker.OnUpdate failed: " .. tostring(err))
        end
    end

    if CastBar ~= nil and CastBar.OnUpdate ~= nil then
        local ok, err = pcall(function()
            CastBar.OnUpdate(dt, UI.settings)
        end)
        if not ok and api.Log ~= nil and api.Log.Err ~= nil then
            api.Log:Err("[Nuzi UI] CastBar.OnUpdate failed: " .. tostring(err))
        end
    end

    if TravelSpeed ~= nil and TravelSpeed.OnUpdate ~= nil then
        local ok, err = pcall(function()
            TravelSpeed.OnUpdate(dt, UI.settings)
        end)
        if not ok and api.Log ~= nil and api.Log.Err ~= nil then
            api.Log:Err("[Nuzi UI] TravelSpeed.OnUpdate failed: " .. tostring(err))
        end
    end

    if MountGlider ~= nil and MountGlider.OnUpdate ~= nil then
        local ok, err = pcall(function()
            MountGlider.OnUpdate(dt, UI.settings)
        end)
        if not ok and api.Log ~= nil and api.Log.Err ~= nil then
            api.Log:Err("[Nuzi UI] MountGlider.OnUpdate failed: " .. tostring(err))
        end
    end

    if GearLoadouts ~= nil and GearLoadouts.OnUpdate ~= nil then
        local ok, err = pcall(function()
            GearLoadouts.OnUpdate(dt, UI.settings)
        end)
        if not ok and api.Log ~= nil and api.Log.Err ~= nil then
            api.Log:Err("[Nuzi UI] GearLoadouts.OnUpdate failed: " .. tostring(err))
        end
    end

    if QuestWatch ~= nil and QuestWatch.OnUpdate ~= nil then
        local ok, err = pcall(function()
            QuestWatch.OnUpdate(dt, UI.settings)
        end)
        if not ok and api.Log ~= nil and api.Log.Err ~= nil then
            api.Log:Err("[Nuzi UI] QuestWatch.OnUpdate failed: " .. tostring(err))
        end
    end

    UI.accum_ms = UI.accum_ms + dt
    local interval = tonumber(UI.settings.update_interval_ms) or 100
    if UI.accum_ms < interval then
        return
    end

    UI.accum_ms = 0

    if UI.enabled then
        SyncSecondaryFrameBinding(UI.watchtarget.wnd, "watchtarget")
        SyncSecondaryFrameBinding(UI.target_of_target.wnd, "targettarget")
        RefreshFrameNameLevelFromUnit(UI.watchtarget.wnd, "watchtarget")
        RefreshFrameNameLevelFromUnit(UI.target_of_target.wnd, "targettarget")
        ApplyUnitFramePosition(UI.target.wnd, UI.settings, "target", 10, 380)
        ApplyUnitFramePosition(UI.watchtarget.wnd, UI.settings, "watchtarget", 10, 460)
        ApplyUnitFramePosition(UI.target_of_target.wnd, UI.settings, "target_of_target", 10, 540)
        RefreshStockFrameDecorations(UI.settings)
        RefreshTrackedStockFrameValueText()
    end

    UpdatePartyOverlays(UI.settings)

    if UI.enabled and UI.target.wnd ~= nil then
        local tid = api.Unit:GetUnitId("target")
        if tid == nil then
            UI.target.current_target_id = nil
            ClearTargetOverlayText()
        else
            local normalizedTid = NormalizeUnitId(tid)
            if UI.target.current_target_id ~= normalizedTid then
                UI.target.current_target_id = normalizedTid
                ClearTargetOverlayText()
            end
            UpdateTargetExtras(UI.settings)
        end
    end
end

return UI
