local Alignment = {}

local GRID_STEP = 30
local GRID_ALPHA = 0.18
local CENTER_ALPHA = 0.55
local CENTER_THICKNESS = 3

local function createLine(wnd, alpha)
    if wnd == nil or wnd.CreateColorDrawable == nil then
        return nil
    end

    local drawable = nil
    pcall(function()
        drawable = wnd:CreateColorDrawable(1, 1, 1, alpha, "overlay")
    end)
    return drawable
end

local function setLineColor(drawable, alpha)
    if drawable == nil or drawable.SetColor == nil then
        return
    end
    pcall(function()
        drawable:SetColor(1, 1, 1, alpha)
    end)
end

local function ensureWindow(ctx)
    local UI = ctx.UI
    local api = ctx.api
    if UI.alignment_grid.wnd ~= nil then
        return UI.alignment_grid.wnd
    end
    if api.Interface == nil or api.Interface.CreateEmptyWindow == nil then
        return nil
    end

    local wnd = nil
    pcall(function()
        wnd = api.Interface:CreateEmptyWindow("polarUiAlignmentGrid")
    end)
    if wnd == nil then
        return nil
    end

    UI.alignment_grid.wnd = wnd
    ctx.SetNotClickable(wnd)
    pcall(function()
        if wnd.SetUILayer ~= nil then
            wnd:SetUILayer("hud")
        end
    end)
    pcall(function()
        if wnd.SetZOrder ~= nil then
            wnd:SetZOrder(9999)
        end
    end)
    pcall(function()
        if wnd.RemoveAllAnchors ~= nil then
            wnd:RemoveAllAnchors()
        end
        if wnd.AddAnchor ~= nil then
            wnd:AddAnchor("TOPLEFT", "UIParent", 0, 0)
            wnd:AddAnchor("BOTTOMRIGHT", "UIParent", 0, 0)
        end
    end)
    pcall(function()
        if wnd.Show ~= nil then
            wnd:Show(false)
        end
    end)
    return wnd
end

local function ensureLines(ctx, w, h)
    local UI = ctx.UI
    local wnd = UI.alignment_grid.wnd
    if wnd == nil then
        return
    end

    local step = GRID_STEP
    local alpha = GRID_ALPHA
    local max_v = math.floor((w or 0) / step)
    local max_h = math.floor((h or 0) / step)
    if max_v < 1 then
        max_v = math.floor(2042 / step)
    end
    if max_h < 1 then
        max_h = math.floor(1124 / step)
    end

    for i = 0, max_v do
        local d = UI.alignment_grid.v_lines[i]
        if d == nil then
            d = createLine(wnd, alpha)
            UI.alignment_grid.v_lines[i] = d
        end
        if d ~= nil then
            pcall(function()
                if d.RemoveAllAnchors ~= nil then
                    d:RemoveAllAnchors()
                end
                if d.AddAnchor ~= nil then
                    local x = i * step
                    d:AddAnchor("TOPLEFT", wnd, x, 0)
                    d:AddAnchor("BOTTOMLEFT", wnd, x, 0)
                end
                if d.SetWidth ~= nil then
                    d:SetWidth(1)
                end
                if d.Show ~= nil then
                    d:Show(true)
                end
            end)
        end
    end

    for i, d in pairs(UI.alignment_grid.v_lines) do
        if type(i) == "number" and i > max_v and d ~= nil and d.Show ~= nil then
            pcall(function()
                d:Show(false)
            end)
        end
    end

    for i = 0, max_h do
        local d = UI.alignment_grid.h_lines[i]
        if d == nil then
            d = createLine(wnd, alpha)
            UI.alignment_grid.h_lines[i] = d
        end
        if d ~= nil then
            pcall(function()
                if d.RemoveAllAnchors ~= nil then
                    d:RemoveAllAnchors()
                end
                if d.AddAnchor ~= nil then
                    local y = i * step
                    d:AddAnchor("TOPLEFT", wnd, 0, y)
                    d:AddAnchor("TOPRIGHT", wnd, 0, y)
                end
                if d.SetHeight ~= nil then
                    d:SetHeight(1)
                end
                if d.Show ~= nil then
                    d:Show(true)
                end
            end)
        end
    end

    for i, d in pairs(UI.alignment_grid.h_lines) do
        if type(i) == "number" and i > max_h and d ~= nil and d.Show ~= nil then
            pcall(function()
                d:Show(false)
            end)
        end
    end

    if UI.alignment_grid.center_v_line == nil then
        UI.alignment_grid.center_v_line = createLine(wnd, CENTER_ALPHA)
    end
    if UI.alignment_grid.center_h_line == nil then
        UI.alignment_grid.center_h_line = createLine(wnd, CENTER_ALPHA)
    end

    local centerX = math.floor(((tonumber(w) or 0) / 2) + 0.5)
    local centerY = math.floor(((tonumber(h) or 0) / 2) + 0.5)
    local halfThickness = math.floor(CENTER_THICKNESS / 2)

    local centerV = UI.alignment_grid.center_v_line
    if centerV ~= nil then
        pcall(function()
            if centerV.RemoveAllAnchors ~= nil then
                centerV:RemoveAllAnchors()
            end
            if centerV.AddAnchor ~= nil then
                centerV:AddAnchor("TOPLEFT", wnd, centerX - halfThickness, 0)
                centerV:AddAnchor("BOTTOMLEFT", wnd, centerX - halfThickness, 0)
            end
            if centerV.SetWidth ~= nil then
                centerV:SetWidth(CENTER_THICKNESS)
            end
            if centerV.Show ~= nil then
                centerV:Show(true)
            end
        end)
        setLineColor(centerV, CENTER_ALPHA)
    end

    local centerH = UI.alignment_grid.center_h_line
    if centerH ~= nil then
        pcall(function()
            if centerH.RemoveAllAnchors ~= nil then
                centerH:RemoveAllAnchors()
            end
            if centerH.AddAnchor ~= nil then
                centerH:AddAnchor("TOPLEFT", wnd, 0, centerY - halfThickness)
                centerH:AddAnchor("TOPRIGHT", wnd, 0, centerY - halfThickness)
            end
            if centerH.SetHeight ~= nil then
                centerH:SetHeight(CENTER_THICKNESS)
            end
            if centerH.Show ~= nil then
                centerH:Show(true)
            end
        end)
        setLineColor(centerH, CENTER_ALPHA)
    end
end

function Alignment.Ensure(ctx, settings)
    local UI = ctx.UI
    local api = ctx.api
    local enabled = (type(settings) == "table" and settings.alignment_grid_enabled) and true or false
    local wnd = ensureWindow(ctx)
    if wnd == nil then
        return
    end
    if not enabled then
        pcall(function()
            wnd:Show(false)
        end)
        return
    end

    local w, h = ctx.SafeGetExtent(wnd)
    if w == nil or h == nil or w <= 0 or h <= 0 then
        w, h = ctx.SafeGetExtent(api.rootWindow)
    end
    if w == nil or h == nil or w <= 0 or h <= 0 then
        w, h = 2042, 1124
    end

    if UI.alignment_grid.last_w ~= w
        or UI.alignment_grid.last_h ~= h
        or UI.alignment_grid.center_v_line == nil
        or UI.alignment_grid.center_h_line == nil then
        UI.alignment_grid.last_w = w
        UI.alignment_grid.last_h = h
        ensureLines(ctx, w, h)
    end

    pcall(function()
        wnd:Show(true)
    end)
end

function Alignment.Reset(ctx)
    local UI = ctx.UI
    if UI.alignment_grid.wnd ~= nil then
        pcall(function()
            if UI.alignment_grid.wnd.Show ~= nil then
                UI.alignment_grid.wnd:Show(false)
            end
        end)
        pcall(function()
            if ctx.api.Interface ~= nil and ctx.api.Interface.Free ~= nil then
                ctx.api.Interface:Free(UI.alignment_grid.wnd)
            end
        end)
    end
    UI.alignment_grid.wnd = nil
    UI.alignment_grid.v_lines = {}
    UI.alignment_grid.h_lines = {}
    UI.alignment_grid.center_v_line = nil
    UI.alignment_grid.center_h_line = nil
    UI.alignment_grid.last_w = nil
    UI.alignment_grid.last_h = nil
end

return Alignment
