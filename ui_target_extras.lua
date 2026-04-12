local TargetExtras = {}

local function SetCachedText(widget, text)
    if widget == nil or widget.SetText == nil then
        return
    end
    text = tostring(text or "")
    if widget.__polar_text == text then
        return
    end
    widget:SetText(text)
    widget.__polar_text = text
end

local function SetCachedVisible(widget, visible)
    if widget == nil or widget.Show == nil then
        return
    end
    visible = visible and true or false
    if widget.__polar_visible == visible then
        return
    end
    widget:Show(visible)
    widget.__polar_visible = visible
end

local function NormalizeColorComponent(value)
    local n = tonumber(value)
    if n == nil then
        return 1
    end
    if n > 1 then
        n = n / 255
    end
    if n < 0 then
        return 0
    end
    if n > 1 then
        return 1
    end
    return n
end

local function SetCachedTextColor(widget, rgba)
    if widget == nil or widget.style == nil or widget.style.SetColor == nil then
        return
    end
    local color = type(rgba) == "table" and rgba or { 255, 255, 255, 255 }
    local r = NormalizeColorComponent(color[1] or 255)
    local g = NormalizeColorComponent(color[2] or 255)
    local b = NormalizeColorComponent(color[3] or 255)
    local a = NormalizeColorComponent(color[4] or 255)
    local colorKey = string.format("%.3f:%.3f:%.3f:%.3f", r, g, b, a)
    if widget.__polar_text_color_key == colorKey then
        return
    end
    widget.style:SetColor(r, g, b, a)
    widget.__polar_text_color_key = colorKey
end

local function IsFieldEnabled(style, key)
    if type(style) ~= "table" then
        return true
    end
    return style[key] ~= false
end

local function ResetAnchors(widget)
    if widget ~= nil and widget.RemoveAllAnchors ~= nil then
        widget:RemoveAllAnchors()
    end
end

local function GetNormalizedTargetId(ctx, api)
    if api == nil or api.Unit == nil or api.Unit.GetUnitId == nil then
        return nil
    end
    local targetId = api.Unit:GetUnitId("target")
    if ctx ~= nil and ctx.NormalizeUnitId ~= nil then
        return ctx.NormalizeUnitId(targetId)
    end
    if targetId == nil then
        return nil
    end
    return tostring(targetId)
end

function TargetExtras.Ensure(ctx, settings, baseStyle)
    local UI = ctx.UI
    local api = ctx.api
    local targetStyle = (UI.target.wnd ~= nil and type(UI.target.wnd.__polar_style_override) == "table") and UI.target.wnd.__polar_style_override or baseStyle
    local overlayFontSize = tonumber(targetStyle.overlay_font_size) or tonumber(settings.font_size_value) or 12
    local gsFontSize = tonumber(targetStyle.gs_font_size) or overlayFontSize
    local classFontSize = tonumber(targetStyle.class_font_size) or overlayFontSize
    local guildFontSize = tonumber(targetStyle.target_guild_font_size) or overlayFontSize
    local overlayShadow = (targetStyle.overlay_shadow ~= false)
    local showGuildField = IsFieldEnabled(targetStyle, "target_guild_visible")
    local showClassField = IsFieldEnabled(targetStyle, "target_class_visible")
    local showGearscoreField = IsFieldEnabled(targetStyle, "target_gearscore_visible")
    local showPdefField = IsFieldEnabled(targetStyle, "target_pdef_visible")
    local showMdefField = IsFieldEnabled(targetStyle, "target_mdef_visible")
    local guildColor = targetStyle.target_guild_color
    local classColor = targetStyle.target_class_color
    local gearscoreColor = targetStyle.target_gearscore_color
    local pdefColor = targetStyle.target_pdef_color
    local mdefColor = targetStyle.target_mdef_color
    local guildX = tonumber(targetStyle.target_guild_offset_x) or 10
    local guildY = tonumber(targetStyle.target_guild_offset_y) or -18
    local classRowY = showGuildField and (guildY - 18) or guildY
    local gearRowY = classRowY - 18

    if UI.target.wnd == nil then
        return
    end

    if UI.target.guild == nil then
        UI.target.guild = UI.target.wnd:CreateChildWidget("label", "polarUiTargetGuild", 0, true)
        table.insert(UI.created, UI.target.guild)
        ctx.SetNotClickable(UI.target.guild)
        UI.target.guild.style:SetAlign(ALIGN.LEFT)
        UI.target.guild.style:SetShadow(overlayShadow)
        ctx.ApplyTextColor(UI.target.guild, FONT_COLOR.WHITE)
        if UI.target.guild.SetAutoResize ~= nil then
            UI.target.guild:SetAutoResize(true)
        end
        UI.target.guild.style:SetFontSize(guildFontSize)
        UI.target.guild:Show(false)
    end

    if UI.target.class_name == nil then
        UI.target.class_name = UI.target.wnd:CreateChildWidget("label", "polarUiTargetClass", 0, true)
        table.insert(UI.created, UI.target.class_name)
        ctx.SetNotClickable(UI.target.class_name)
        UI.target.class_name:AddAnchor("TOPLEFT", UI.target.wnd, 10, -18)
        UI.target.class_name.style:SetAlign(ALIGN.LEFT)
        UI.target.class_name.style:SetShadow(overlayShadow)
        ctx.ApplyTextColor(UI.target.class_name, FONT_COLOR.WHITE)
        if UI.target.class_name.SetAutoResize ~= nil then
            UI.target.class_name:SetAutoResize(true)
        end
        UI.target.class_name.style:SetFontSize(classFontSize)
    end

    if UI.target.gearscore == nil then
        UI.target.gearscore = UI.target.wnd:CreateChildWidget("label", "polarUiTargetGearscore", 0, true)
        table.insert(UI.created, UI.target.gearscore)
        ctx.SetNotClickable(UI.target.gearscore)
        UI.target.gearscore:AddAnchor("TOPLEFT", UI.target.wnd, 10, -36)
        UI.target.gearscore.style:SetAlign(ALIGN.LEFT)
        UI.target.gearscore.style:SetShadow(overlayShadow)
        ctx.ApplyTextColor(UI.target.gearscore, FONT_COLOR.WHITE)
        if UI.target.gearscore.SetAutoResize ~= nil then
            UI.target.gearscore:SetAutoResize(true)
        end
        UI.target.gearscore.style:SetFontSize(gsFontSize)
    end

    if UI.target.pdef == nil then
        UI.target.pdef = UI.target.wnd:CreateChildWidget("label", "polarUiTargetPdef", 0, true)
        table.insert(UI.created, UI.target.pdef)
        ctx.SetNotClickable(UI.target.pdef)
        UI.target.pdef.style:SetAlign(ALIGN.LEFT)
        UI.target.pdef.style:SetShadow(overlayShadow)
        ctx.ApplyTextColor(UI.target.pdef, FONT_COLOR.WHITE)
        if UI.target.pdef.SetAutoResize ~= nil then
            UI.target.pdef:SetAutoResize(true)
        end
        UI.target.pdef.style:SetFontSize(gsFontSize)
        UI.target.pdef:Show(false)
    end

    if UI.target.mdef == nil then
        UI.target.mdef = UI.target.wnd:CreateChildWidget("label", "polarUiTargetMdef", 0, true)
        table.insert(UI.created, UI.target.mdef)
        ctx.SetNotClickable(UI.target.mdef)
        UI.target.mdef.style:SetAlign(ALIGN.LEFT)
        UI.target.mdef.style:SetShadow(overlayShadow)
        ctx.ApplyTextColor(UI.target.mdef, FONT_COLOR.WHITE)
        if UI.target.mdef.SetAutoResize ~= nil then
            UI.target.mdef:SetAutoResize(true)
        end
        UI.target.mdef.style:SetFontSize(gsFontSize)
        UI.target.mdef:Show(false)
    end

    pcall(function()
        if UI.target.guild ~= nil and UI.target.guild.style ~= nil then
            UI.target.guild.style:SetFontSize(guildFontSize)
            UI.target.guild.style:SetShadow(overlayShadow)
            SetCachedTextColor(UI.target.guild, guildColor)
        end
        if UI.target.class_name ~= nil and UI.target.class_name.style ~= nil then
            UI.target.class_name.style:SetFontSize(classFontSize)
            UI.target.class_name.style:SetShadow(overlayShadow)
            SetCachedTextColor(UI.target.class_name, classColor)
        end
        if UI.target.gearscore ~= nil and UI.target.gearscore.style ~= nil then
            UI.target.gearscore.style:SetFontSize(gsFontSize)
            UI.target.gearscore.style:SetShadow(overlayShadow)
            SetCachedTextColor(UI.target.gearscore, gearscoreColor)
        end
        if UI.target.pdef ~= nil and UI.target.pdef.style ~= nil then
            UI.target.pdef.style:SetFontSize(gsFontSize)
            UI.target.pdef.style:SetShadow(overlayShadow)
            SetCachedTextColor(UI.target.pdef, pdefColor)
        end
        if UI.target.mdef ~= nil and UI.target.mdef.style ~= nil then
            UI.target.mdef.style:SetFontSize(gsFontSize)
            UI.target.mdef.style:SetShadow(overlayShadow)
            SetCachedTextColor(UI.target.mdef, mdefColor)
        end
    end)

    pcall(function()
        if UI.target.class_name ~= nil and UI.target.gearscore ~= nil then
            if UI.target.guild ~= nil then
                ResetAnchors(UI.target.guild)
                UI.target.guild:AddAnchor("TOPLEFT", UI.target.wnd, guildX, guildY)
            end

            local previousRowWidget = nil

            if UI.target.class_name ~= nil then
                ResetAnchors(UI.target.class_name)
                if showClassField then
                    UI.target.class_name:AddAnchor("TOPLEFT", UI.target.wnd, guildX, classRowY)
                    previousRowWidget = UI.target.class_name
                end
            end
            if UI.target.pdef ~= nil then
                ResetAnchors(UI.target.pdef)
                if showPdefField then
                    if previousRowWidget ~= nil then
                        UI.target.pdef:AddAnchor("TOPLEFT", previousRowWidget, "TOPRIGHT", 10, 0)
                    else
                        UI.target.pdef:AddAnchor("TOPLEFT", UI.target.wnd, guildX, classRowY)
                    end
                    previousRowWidget = UI.target.pdef
                end
            end
            if UI.target.mdef ~= nil then
                ResetAnchors(UI.target.mdef)
                if showMdefField then
                    if previousRowWidget ~= nil then
                        UI.target.mdef:AddAnchor("TOPLEFT", previousRowWidget, "TOPRIGHT", 10, 0)
                    else
                        UI.target.mdef:AddAnchor("TOPLEFT", UI.target.wnd, guildX, classRowY)
                    end
                end
            end

            if UI.target.gearscore ~= nil then
                ResetAnchors(UI.target.gearscore)
                if showGearscoreField then
                    UI.target.gearscore:AddAnchor("TOPLEFT", UI.target.wnd, guildX, gearRowY)
                end
            end

        end
    end)

    ctx.ApplyOverlayAlpha(targetStyle.overlay_alpha)
end

function TargetExtras.Update(ctx, settings)
    local UI = ctx.UI
    local api = ctx.api
    local targetStyle = (UI.target.wnd ~= nil and type(UI.target.wnd.__polar_style_override) == "table") and UI.target.wnd.__polar_style_override
        or ((type(settings) == "table" and type(settings.style) == "table") and settings.style or {})
    local showGuildField = IsFieldEnabled(targetStyle, "target_guild_visible")
    local showClassField = IsFieldEnabled(targetStyle, "target_class_visible")
    local showGearscoreField = IsFieldEnabled(targetStyle, "target_gearscore_visible")
    local showPdefField = IsFieldEnabled(targetStyle, "target_pdef_visible")
    local showMdefField = IsFieldEnabled(targetStyle, "target_mdef_visible")
    local targetId = api.Unit:GetUnitId("target")
    local normalizedTargetId = GetNormalizedTargetId(ctx, api)
    if targetId == nil or normalizedTargetId == nil then
        return
    end

    local targetUnitInfo = nil
    pcall(function()
        if api.Unit ~= nil and api.Unit.UnitInfo ~= nil then
            local info = api.Unit:UnitInfo("target")
            if type(info) == "table" then
                targetUnitInfo = info
            end
        end
    end)
    local targetInfoById = ctx.SafeGetUnitInfoById(targetId)
    local targetDisplayName = ctx.ResolveUnitDisplayName(targetUnitInfo)
    if targetDisplayName == "" and ctx.Runtime ~= nil and ctx.Runtime.GetUnitName ~= nil then
        targetDisplayName = ctx.TrimText(ctx.Runtime.GetUnitName("target"))
    end
    if targetDisplayName == "" then
        targetDisplayName = ctx.ResolveUnitDisplayName(targetInfoById)
    end
    local targetLevel = ctx.ResolveUnitLevel(targetUnitInfo)
    if targetLevel == nil then
        targetLevel = ctx.ResolveUnitLevel(targetInfoById)
    end

    local isCharacter = true
    if type(targetUnitInfo) == "table" and targetUnitInfo.type ~= nil then
        isCharacter = (targetUnitInfo.type == "character")
    elseif type(targetInfoById) == "table" and targetInfoById.type ~= nil then
        isCharacter = (targetInfoById.type == "character")
    end

    local gs = nil
    pcall(function()
        if api.Unit ~= nil then
            gs = api.Unit:UnitGearScore("target")
        end
    end)
    if gs == nil and type(targetUnitInfo) == "table" then
        gs = targetUnitInfo.gearScore or targetUnitInfo.gearscore or targetUnitInfo.gear_score or targetUnitInfo.gs
    end
    if gs == nil and type(targetInfoById) == "table" then
        gs = targetInfoById.gearScore or targetInfoById.gearscore or targetInfoById.gear_score or targetInfoById.gs
    end

    local className = ""
    pcall(function()
        if api.Ability and api.Ability.GetUnitClassName then
            className = api.Ability:GetUnitClassName("target") or ""
        end
    end)
    className = ctx.TrimText(className)

    pcall(function()
        if UI.target.wnd ~= nil and UI.target.wnd.UpdateTooltip ~= nil then
            UI.target.wnd:UpdateTooltip()
        end
    end)

    local pdef = nil
    local mdef = nil
    if isCharacter and type(targetUnitInfo) == "table" then
        pdef = targetUnitInfo.armor
        mdef = targetUnitInfo.magic_resist
    end
    if isCharacter and type(targetInfoById) == "table" then
        if pdef == nil then
            pdef = targetInfoById.armor
        end
        if mdef == nil then
            mdef = targetInfoById.magic_resist
        end
    end

    local guild = ""
    if isCharacter and type(targetUnitInfo) == "table" then
        guild = ctx.TrimText(targetUnitInfo.expeditionName or targetUnitInfo.guildName or targetUnitInfo.guild or "")
    end
    if guild == "" and isCharacter and type(targetInfoById) == "table" then
        guild = ctx.TrimText(targetInfoById.expeditionName or targetInfoById.guildName or targetInfoById.guild or "")
    end

    if GetNormalizedTargetId(ctx, api) ~= normalizedTargetId then
        return
    end

    ctx.ApplyTargetNameLevel(targetDisplayName, targetLevel)

    local gearscoreText = ""
    if type(gs) == "number" then
        gearscoreText = tostring(math.floor(gs + 0.5)) .. "gs"
    elseif type(gs) == "string" and gs ~= "" then
        gearscoreText = gs .. "gs"
    end
    SetCachedText(UI.target.gearscore, gearscoreText)
    SetCachedVisible(UI.target.gearscore, showGearscoreField and gearscoreText ~= "")

    SetCachedText(UI.target.class_name, className)
    SetCachedVisible(UI.target.class_name, showClassField and className ~= "")

    local guildText = ""
    if guild ~= "" then
        guildText = "<" .. guild .. ">"
    end
    SetCachedText(UI.target.guild, guildText)
    SetCachedVisible(UI.target.guild, showGuildField and guildText ~= "")

    local pdefText = ""
    if type(pdef) == "number" and pdef > 0 then
        pdefText = string.format("PDEF %d", math.floor(pdef + 0.5))
    end
    SetCachedText(UI.target.pdef, pdefText)
    SetCachedVisible(UI.target.pdef, showPdefField and pdefText ~= "")

    local mdefText = ""
    if type(mdef) == "number" and mdef > 0 then
        mdefText = string.format("MDEF %d", math.floor(mdef + 0.5))
    end
    SetCachedText(UI.target.mdef, mdefText)
    SetCachedVisible(UI.target.mdef, showMdefField and mdefText ~= "")
end

return TargetExtras
