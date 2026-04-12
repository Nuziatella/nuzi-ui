local api = require("api")
local Compat = nil
local Runtime = nil
do
    local ok, mod = pcall(require, "nuzi-ui/compat")
    if ok then
        Compat = mod
    else
        ok, mod = pcall(require, "nuzi-ui.compat")
        if ok then
            Compat = mod
        end
    end
end
do
    local ok, mod = pcall(require, "nuzi-ui/runtime")
    if ok then
        Runtime = mod
    else
        ok, mod = pcall(require, "nuzi-ui.runtime")
        if ok then
            Runtime = mod
        end
    end
end

local Nameplates = {
    settings = nil,
    enabled = false,
    frames = {},
    unit_keys = {},
    target_unitframe = nil
}

local function NormalizeUnitToken(unit)
    if type(unit) ~= "string" then
        return nil
    end
    local text = tostring(unit or "")
    if text == "" then
        return nil
    end
    return text
end

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

local function ClampNumber(v, lo, hi, default)
    local n = tonumber(v)
    if n == nil then
        return default
    end
    if lo ~= nil and n < lo then
        return lo
    end
    if hi ~= nil and n > hi then
        return hi
    end
    return n
end

local function Percent01(pct, default)
    local n = tonumber(pct)
    if n == nil then
        local d = tonumber(default)
        if d == nil then
            d = 100
        end
        if d < 0 then
            d = 0
        elseif d > 100 then
            d = 100
        end
        return d / 100
    end
    if n < 0 then
        n = 0
    elseif n > 100 then
        n = 100
    end
    return n / 100
end

local function SafeShow(wnd, show)
    if wnd == nil or wnd.Show == nil then
        return
    end
    show = show and true or false
    if wnd.__polar_visible == show then
        return
    end
    pcall(function()
        wnd:Show(show)
    end)
    wnd.__polar_visible = show
end

local function SafeClickable(wnd, clickable)
    if wnd == nil or wnd.Clickable == nil then
        return
    end
    clickable = clickable and true or false
    if wnd.__polar_clickable == clickable then
        return
    end
    pcall(function()
        wnd:Clickable(clickable)
    end)
    wnd.__polar_clickable = clickable
end

local function SafeSetText(lbl, txt)
    if lbl == nil or lbl.SetText == nil then
        return
    end
    txt = tostring(txt or "")
    if lbl.__polar_text == txt then
        return
    end
    pcall(function()
        lbl:SetText(txt)
    end)
    lbl.__polar_text = txt
end

local function SafeSetTextColor(lbl, r, g, b, a)
    if lbl == nil or lbl.style == nil or lbl.style.SetColor == nil then
        return
    end
    local colorKey = string.format("%.3f:%.3f:%.3f:%.3f", tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0, tonumber(a) or 0)
    if lbl.__polar_text_color_key == colorKey then
        return
    end
    pcall(function()
        lbl.style:SetColor(r, g, b, a)
    end)
    lbl.__polar_text_color_key = colorKey
end

local function Clamp01(v, default)
    local n = tonumber(v)
    if n == nil then
        return default
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

local function ApplyGuildTextColor(lbl, cfg, guild)
    local r, g, b, a = 1, 1, 1, 1
    if type(cfg) == "table" and type(cfg.guild_colors) == "table" and guild ~= nil then
        local function normalize_key(raw)
            local k = tostring(raw or "")
            k = string.match(k, "^%s*(.-)%s*$") or k
            k = string.lower(k)
            k = string.gsub(k, "%s+", "_")
            k = string.gsub(k, "[^%w_]", "")
            if k ~= "" and string.match(k, "^%d") ~= nil then
                k = "_" .. k
            end
            return k
        end

        local key = tostring(guild or "")
        local rule = cfg.guild_colors[key]
        if rule == nil and key ~= "" then
            rule = cfg.guild_colors[string.lower(key)]
        end
        if rule == nil and key ~= "" then
            local norm = normalize_key(key)
            if norm ~= "" then
                rule = cfg.guild_colors[norm]
            end
        end
        if type(rule) == "table" then
            r = Clamp01(rule[1], 1)
            g = Clamp01(rule[2], 1)
            b = Clamp01(rule[3], 1)
            a = Clamp01(rule[4], 1)
        end
    end
    SafeSetTextColor(lbl, r, g, b, a)
end

local function SafeSetAlpha(wnd, a01)
    if wnd == nil then
        return
    end
    if wnd.SetAlpha == nil then
        return
    end
    local alpha = ClampNumber(a01, 0, 1, 1)
    if wnd.__polar_alpha == alpha then
        return
    end
    pcall(function()
        wnd:SetAlpha(alpha)
    end)
    wnd.__polar_alpha = alpha
end

local function SafeSetBg(frame, enabled, alpha01)
    if frame == nil or frame.bg == nil then
        return
    end
    local bg = frame.bg
    enabled = enabled and true or false
    local alpha = ClampNumber(alpha01, 0, 1, 0.8)
    SafeShow(bg, enabled)
    if bg.SetColor ~= nil and (bg.__polar_bg_alpha ~= alpha or bg.__polar_bg_enabled ~= enabled) then
        pcall(function()
            bg:SetColor(1, 1, 1, alpha)
        end)
        bg.__polar_bg_alpha = alpha
        bg.__polar_bg_enabled = enabled
    end
end

local function SafeSetAnchorTopLeft(wnd, x, y)
    if wnd == nil or wnd.AddAnchor == nil then
        return
    end
    x = tonumber(x) or 0
    y = tonumber(y) or 0
    if wnd.__polar_anchor_x == x and wnd.__polar_anchor_y == y then
        return
    end
    pcall(function()
        if wnd.RemoveAllAnchors ~= nil then
            wnd:RemoveAllAnchors()
        end
        wnd:AddAnchor("TOPLEFT", "UIParent", x, y)
    end)
    wnd.__polar_anchor_x = x
    wnd.__polar_anchor_y = y
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

local function ShouldShowUnit(unit, cfg)
    if unit == nil then
        return false
    end
    if unit == "target" then
        return cfg.show_target and true or false
    end
    if unit == "watchtarget" then
        return cfg.show_watchtarget and true or false
    end
    if unit == "playerpet1" then
        return cfg.show_mount and true or false
    end
    if unit == "player" then
        return cfg.show_player and true or false
    end
    if string.match(unit, "^team%d+$") then
        return cfg.show_raid_party and true or false
    end
    return false
end

local function ApplyLayout(frame, cfg)
    if frame == nil or type(cfg) ~= "table" then
        return
    end

    local guildOnly = cfg.guild_only and true or false
    local width = ClampNumber(cfg.width, 50, 400, 120)
    local hpHeight = ClampNumber(cfg.hp_height, 5, 60, 28)
    local mpHeight = ClampNumber(cfg.mp_height, 0, 40, 4)
    local totalHeight = hpHeight + mpHeight

    if guildOnly then
        local guildFs = ClampNumber(cfg.guild_font_size, 6, 32, 11)
        totalHeight = guildFs + 8
    end

    local layoutKey = table.concat({
        guildOnly and "1" or "0",
        tostring(width),
        tostring(hpHeight),
        tostring(mpHeight),
        tostring(ClampNumber(cfg.name_font_size, 6, 32, 14)),
        tostring(ClampNumber(cfg.guild_font_size, 6, 32, 11))
    }, ":")
    if frame.__polar_layout_key == layoutKey then
        return
    end
    frame.__polar_layout_key = layoutKey

    pcall(function()
        if frame.SetExtent ~= nil then
            frame:SetExtent(width, totalHeight)
        end
    end)

    if guildOnly then
        if frame.guildLabel ~= nil and frame.guildLabel.style ~= nil then
            pcall(function()
                local size = ClampNumber(cfg.guild_font_size, 6, 32, 11)
                frame.guildLabel.style:SetFontSize(size)
            end)
        end
        return
    end

    if frame.hpBar ~= nil then
        pcall(function()
            frame.hpBar:RemoveAllAnchors()
            frame.hpBar:AddAnchor("TOPLEFT", frame, 0, 0)
            frame.hpBar:AddAnchor("TOPRIGHT", frame, 0, 0)
            frame.hpBar:SetHeight(hpHeight)
        end)
    end

    if frame.mpBar ~= nil then
        pcall(function()
            frame.mpBar:RemoveAllAnchors()
            frame.mpBar:AddAnchor("TOPLEFT", frame.hpBar, "BOTTOMLEFT", 0, -1)
            frame.mpBar:AddAnchor("TOPRIGHT", frame.hpBar, "BOTTOMRIGHT", 0, -1)
            frame.mpBar:SetHeight(mpHeight)
        end)
        if mpHeight > 0 then
            SafeShow(frame.mpBar, true)
        else
            SafeShow(frame.mpBar, false)
        end
    end

    if frame.nameLabel ~= nil and frame.nameLabel.style ~= nil then
        pcall(function()
            local size = ClampNumber(cfg.name_font_size, 6, 32, 14)
            frame.nameLabel.style:SetFontSize(size)
        end)
    end

    if frame.guildLabel ~= nil and frame.guildLabel.style ~= nil then
        pcall(function()
            local size = ClampNumber(cfg.guild_font_size, 6, 32, 11)
            frame.guildLabel.style:SetFontSize(size)
        end)
    end

    if frame.bg ~= nil then
        pcall(function()
            if frame.bg.RemoveAllAnchors ~= nil then
                frame.bg:RemoveAllAnchors()
            end
            if frame.hpBar ~= nil and frame.mpBar ~= nil and frame.bg.AddAnchor ~= nil then
                frame.bg:AddAnchor("TOPLEFT", frame.hpBar, -3, -3)
                frame.bg:AddAnchor("BOTTOMRIGHT", frame.mpBar, 2, 3)
            end
        end)
    end
end

local function ApplyGuildMode(frame, guildOnly, showMpBar)
    if frame == nil or frame.__polar_guild_only == guildOnly then
        if not guildOnly then
            SafeShow(frame.hpBar, true)
            SafeShow(frame.mpBar, showMpBar and true or false)
        end
        return
    end
    frame.__polar_guild_only = guildOnly

    if guildOnly then
        SafeShow(frame.hpBar, false)
        SafeShow(frame.mpBar, false)
        SafeShow(frame.nameLabel, false)
        SafeSetBg(frame, false, 0)
        SafeShow(frame.eventWindow, false)
        pcall(function()
            if frame.guildLabel ~= nil then
                if frame.guildLabel.RemoveAllAnchors ~= nil then
                    frame.guildLabel:RemoveAllAnchors()
                end
                if frame.guildLabel.AddAnchor ~= nil then
                    frame.guildLabel:AddAnchor("TOPLEFT", frame, 3, -3)
                end
            end
        end)
        return
    end

    SafeShow(frame.nameLabel, true)
    SafeShow(frame.hpBar, true)
    SafeShow(frame.mpBar, showMpBar and true or false)
    SafeShow(frame.eventWindow, false)
    pcall(function()
        if frame.guildLabel ~= nil and frame.nameLabel ~= nil then
            if frame.guildLabel.RemoveAllAnchors ~= nil then
                frame.guildLabel:RemoveAllAnchors()
            end
            if frame.guildLabel.AddAnchor ~= nil then
                frame.guildLabel:AddAnchor("TOPLEFT", frame.nameLabel, "BOTTOMLEFT", 0, 0)
            end
        end
    end)
end

local function EnsureFrame(unit)
    if Nameplates.frames[unit] ~= nil then
        return Nameplates.frames[unit]
    end

    local frameId = "polarUiPlate_" .. unit
    local frame = api.Interface:CreateEmptyWindow(frameId)
    pcall(function()
        if frame.SetUILayer ~= nil then
            frame:SetUILayer("hud")
        end
    end)
    SafeClickable(frame, false)
    SafeShow(frame, false)

    local bg = nil
    pcall(function()
        if frame.CreateNinePartDrawable ~= nil and TEXTURE_PATH ~= nil and TEXTURE_PATH.RAID ~= nil then
            bg = frame:CreateNinePartDrawable(TEXTURE_PATH.RAID, "background")
            bg:SetCoords(33, 141, 7, 7)
            bg:SetInset(3, 3, 3, 3)
            bg:SetColor(1, 1, 1, 0.8)
            bg:Show(false)
        end
    end)
    frame.bg = bg

    local hpBar = nil
    local mpBar = nil
    pcall(function()
        if W_BAR ~= nil and W_BAR.CreateStatusBarOfRaidFrame ~= nil then
            hpBar = W_BAR.CreateStatusBarOfRaidFrame(frameId .. ".hpBar", frame)
            hpBar:Show(true)
            hpBar:Clickable(false)
            if hpBar.statusBar ~= nil and hpBar.statusBar.Clickable ~= nil then
                hpBar.statusBar:Clickable(false)
            end
            if STATUSBAR_STYLE ~= nil and STATUSBAR_STYLE.HP_RAID ~= nil then
                hpBar:ApplyBarTexture(STATUSBAR_STYLE.HP_RAID)
            end

            mpBar = W_BAR.CreateStatusBarOfRaidFrame(frameId .. ".mpBar", frame)
            mpBar:Show(true)
            mpBar:Clickable(false)
            if mpBar.statusBar ~= nil and mpBar.statusBar.Clickable ~= nil then
                mpBar.statusBar:Clickable(false)
            end
            if STATUSBAR_STYLE ~= nil and STATUSBAR_STYLE.MP_RAID ~= nil then
                mpBar:ApplyBarTexture(STATUSBAR_STYLE.MP_RAID)
            end
        end
    end)
    frame.hpBar = hpBar
    frame.mpBar = mpBar

    local nameLabel = api.Interface:CreateWidget("label", frameId .. ".name", frame)
    pcall(function()
        nameLabel:Show(true)
        if nameLabel.Clickable ~= nil then
            nameLabel:Clickable(false)
        end
        if nameLabel.SetLimitWidth ~= nil then
            nameLabel:SetLimitWidth(true)
        end
        if nameLabel.SetExtent ~= nil then
            nameLabel:SetExtent(220, FONT_SIZE and FONT_SIZE.MIDDLE or 14)
        end
        if nameLabel.style ~= nil then
            nameLabel.style:SetAlign(ALIGN.LEFT)
            nameLabel.style:SetFontSize(FONT_SIZE and FONT_SIZE.MIDDLE or 14)
            nameLabel.style:SetColor(1, 1, 1, 1)
        end
        nameLabel:AddAnchor("TOPLEFT", frame, 3, -3)
    end)
    frame.nameLabel = nameLabel

    local guildLabel = api.Interface:CreateWidget("label", frameId .. ".guild", frame)
    pcall(function()
        guildLabel:Show(true)
        if guildLabel.Clickable ~= nil then
            guildLabel:Clickable(false)
        end
        if guildLabel.SetLimitWidth ~= nil then
            guildLabel:SetLimitWidth(true)
        end
        if guildLabel.SetExtent ~= nil then
            guildLabel:SetExtent(220, FONT_SIZE and FONT_SIZE.SMALL or 11)
        end
        if guildLabel.style ~= nil then
            guildLabel.style:SetAlign(ALIGN.LEFT)
            guildLabel.style:SetFontSize(FONT_SIZE and FONT_SIZE.SMALL or 11)
            guildLabel.style:SetColor(1, 1, 1, 1)
        end
        guildLabel:AddAnchor("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, 0)
        guildLabel:SetText("")
    end)
    frame.guildLabel = guildLabel

    local eventWindow = api.Interface:CreateWidget("emptywidget", frameId .. ".event", frame)
    pcall(function()
        eventWindow:AddAnchor("TOPLEFT", frame, 0, 0)
        eventWindow:AddAnchor("BOTTOMRIGHT", frame, 0, 0)
        eventWindow:Show(false)
        eventWindow:EnableDrag(false)
        if eventWindow.EnablePick ~= nil then
            eventWindow:EnablePick(false)
        end
    end)
    if eventWindow.Clickable ~= nil then
        pcall(function()
            eventWindow:Clickable(false)
        end)
    end
    frame.eventWindow = eventWindow

    Nameplates.frames[unit] = frame
    return frame
end

local function GetCfg(settings)
    if type(settings) ~= "table" or type(settings.nameplates) ~= "table" then
        return {}
    end
    return settings.nameplates
end

local function UpdateOne(unit, settings)
    unit = NormalizeUnitToken(unit)
    if unit == nil then
        return
    end
    local cfg = GetCfg(settings)
    if Compat ~= nil and not Compat.NameplatesSupported() then
        SafeShow(Nameplates.frames[unit], false)
        return
    end

    local guildOnly = cfg.guild_only and true or false

    if not (Nameplates.enabled and cfg.enabled) then
        SafeShow(Nameplates.frames[unit], false)
        return
    end

    if not ShouldShowUnit(unit, cfg) then
        SafeShow(Nameplates.frames[unit], false)
        return
    end

    local frame = EnsureFrame(unit)
    if frame == nil then
        return
    end

    local id = nil
    pcall(function()
        id = api.Unit:GetUnitId(unit)
    end)
    id = NormalizeUnitId(id)
    if id == nil then
        SafeShow(frame, false)
        return
    end

    local offsetX = nil
    local offsetY = nil
    local offsetZ = nil

    if cfg.anchor_to_nametag and api.Unit.GetUnitScreenNameTagOffset ~= nil then
        pcall(function()
            offsetX, offsetY, offsetZ = api.Unit:GetUnitScreenNameTagOffset(unit)
        end)
    end

    if offsetX == nil or offsetY == nil or offsetZ == nil then
        offsetX, offsetY, offsetZ = api.Unit:GetUnitScreenPosition(unit)
    end

    if offsetX == nil or offsetY == nil or offsetZ == nil or offsetZ < 0 then
        SafeShow(frame, false)
        return
    end

    local dist = nil
    pcall(function()
        if api.Unit.UnitDistance ~= nil then
            dist = api.Unit:UnitDistance(unit)
        end
    end)
    local maxDist = ClampNumber(cfg.max_distance, 1, 500, 130)
    if type(dist) == "number" and dist > maxDist then
        SafeShow(frame, false)
        return
    end

    ApplyLayout(frame, cfg)

    local alpha01 = Percent01(cfg.alpha_pct, 100)
    SafeSetAlpha(frame, alpha01)

    if not guildOnly then
        local bgEnabled = cfg.bg_enabled ~= false
        local bgAlpha01 = Percent01(cfg.bg_alpha_pct, 80)
        SafeSetBg(frame, bgEnabled, bgAlpha01)
    end

    local width = ClampNumber(cfg.width, 50, 400, 120)
    local hpHeight = ClampNumber(cfg.hp_height, 5, 60, 28)
    local mpHeight = ClampNumber(cfg.mp_height, 0, 40, 4)
    local totalHeight = hpHeight + mpHeight

    if guildOnly then
        local guildFs = ClampNumber(cfg.guild_font_size, 6, 32, 11)
        totalHeight = guildFs + 8
    end

    offsetX = math.ceil(offsetX) + ClampNumber(cfg.x_offset, -500, 500, 0)
    offsetY = math.ceil(offsetY) - ClampNumber(cfg.y_offset, -200, 200, 22)

    local posX = offsetX - math.ceil(width / 2)
    local posY = offsetY - math.ceil(totalHeight / 2)

    SafeSetAnchorTopLeft(frame, posX, posY)

    ApplyGuildMode(frame, guildOnly, mpHeight > 0)

    local info = nil
    local isCharacter = true
    if guildOnly or cfg.show_guild then
        info = SafeGetUnitInfoById(id)
        if type(info) == "table" and info.type ~= nil then
            isCharacter = (tostring(info.type) == "character")
        end
    end

    local name = ""
    if type(info) == "table" then
        name = tostring(info.name or info.unitName or info.family_name or "")
    end
    if name == "" and Runtime ~= nil and Runtime.GetUnitNameById ~= nil then
        name = Runtime.GetUnitNameById(id)
    end
    SafeSetText(frame.nameLabel, name or "")

    local guild = nil
    if type(info) == "table" then
        guild = info.expeditionName
    end
    guild = tostring(guild or "")

    if cfg.show_guild and isCharacter and guild ~= "" then
        ApplyGuildTextColor(frame.guildLabel, cfg, guild)
        SafeShow(frame.guildLabel, true)
        SafeSetText(frame.guildLabel, "<" .. guild .. ">")
    else
        ApplyGuildTextColor(frame.guildLabel, cfg, nil)
        SafeSetText(frame.guildLabel, "")
        SafeShow(frame.guildLabel, false)
    end

    if not guildOnly then
        if frame.hpBar ~= nil and frame.hpBar.statusBar ~= nil then
            pcall(function()
                local maxHp = api.Unit:UnitMaxHealth(unit) or 0
                local hp = api.Unit:UnitHealth(unit) or 0
                SafeSetBarValue(frame.hpBar.statusBar, maxHp, hp)
            end)
        end

        if frame.mpBar ~= nil and frame.mpBar.statusBar ~= nil and mpHeight > 0 then
            pcall(function()
                local maxMp = api.Unit:UnitMaxMana(unit) or 0
                local mp = api.Unit:UnitMana(unit) or 0
                SafeSetBarValue(frame.mpBar.statusBar, maxMp, mp)
            end)
        end
    end

    SafeShow(frame, true)
end

local function EnsureUnitKeys()
    if #Nameplates.unit_keys > 0 then
        return
    end

    table.insert(Nameplates.unit_keys, "target")
    table.insert(Nameplates.unit_keys, "player")
    for i = 1, 50 do
        table.insert(Nameplates.unit_keys, string.format("team%d", i))
    end
    table.insert(Nameplates.unit_keys, "watchtarget")
    table.insert(Nameplates.unit_keys, "playerpet1")
end

Nameplates.Init = function(settings)
    Nameplates.settings = settings
    if Compat ~= nil then
        Compat.Probe(false)
    end
    EnsureUnitKeys()

    if Runtime ~= nil and UIC ~= nil then
        Nameplates.target_unitframe = Runtime.GetStockContent(UIC.TARGET_UNITFRAME)
    end
end

Nameplates.SetEnabled = function(enabled)
    Nameplates.enabled = enabled and true or false
    if not Nameplates.enabled then
        for _, frame in pairs(Nameplates.frames) do
            SafeShow(frame, false)
        end
    end
end

Nameplates.OnUpdate = function(settings)
    if settings == nil then
        return
    end
    if Compat ~= nil and not Compat.NameplatesSupported() then
        for _, frame in pairs(Nameplates.frames) do
            SafeShow(frame, false)
        end
        return
    end

    local cfg = GetCfg(settings)
    if not (Nameplates.enabled and cfg.enabled) then
        for _, frame in pairs(Nameplates.frames) do
            SafeShow(frame, false)
        end
        return
    end

    for _, unit in ipairs(Nameplates.unit_keys) do
        UpdateOne(unit, settings)
    end
end

Nameplates.Unload = function()
    for _, frame in pairs(Nameplates.frames) do
        SafeShow(frame, false)
        pcall(function()
            if api.Interface ~= nil and api.Interface.Free ~= nil and frame ~= nil then
                api.Interface:Free(frame)
            end
        end)
    end
    Nameplates.frames = {}
    Nameplates.settings = nil
    Nameplates.target_unitframe = nil
    Nameplates.unit_keys = {}
end

return Nameplates
