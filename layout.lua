local api = require("api")

local Layout = {}

local function readInterfaceNumber(methodName)
    if api == nil or api.Interface == nil or type(api.Interface[methodName]) ~= "function" then
        return nil
    end
    local ok, value = pcall(function()
        return api.Interface[methodName](api.Interface)
    end)
    if ok then
        return tonumber(value)
    end
    return nil
end

local function readUiParentNumber(methodName)
    if UIParent == nil or type(UIParent[methodName]) ~= "function" then
        return nil
    end
    local ok, value = pcall(function()
        return UIParent[methodName](UIParent)
    end)
    if ok then
        return tonumber(value)
    end
    return nil
end

function Layout.GetUiScale()
    local scale = readInterfaceNumber("GetUIScale") or readUiParentNumber("GetUIScale") or 1
    if scale > 10 then
        scale = scale / 100
    end
    if scale <= 0 then
        scale = 1
    end
    return scale
end

function Layout.ToUi(value)
    local number = tonumber(value) or 0
    if F_LAYOUT ~= nil and type(F_LAYOUT.CalcDontApplyUIScale) == "function" then
        local ok, scaled = pcall(function()
            return F_LAYOUT.CalcDontApplyUIScale(number)
        end)
        if ok and tonumber(scaled) ~= nil then
            return tonumber(scaled)
        end
    end
    return number / Layout.GetUiScale()
end

function Layout.ToScreen(value)
    return (tonumber(value) or 0) * Layout.GetUiScale()
end

function Layout.Round(value)
    local number = tonumber(value) or 0
    if number >= 0 then
        return math.floor(number + 0.5)
    end
    return math.ceil(number - 0.5)
end

local function readOffset(widget, methodName)
    if widget == nil or type(widget[methodName]) ~= "function" then
        return nil, nil
    end
    local ok, x, y = pcall(function()
        return widget[methodName](widget)
    end)
    if ok and tonumber(x) ~= nil and tonumber(y) ~= nil then
        return tonumber(x), tonumber(y)
    end
    return nil, nil
end

local function readWidgetScale(widget)
    if widget == nil or type(widget.GetScale) ~= "function" then
        return 1
    end
    local ok, scale = pcall(function()
        return widget:GetScale()
    end)
    scale = ok and tonumber(scale) or nil
    if scale == nil or scale <= 0 then
        return 1
    end
    return scale
end

function Layout.GetWidgetScale(widget)
    return readWidgetScale(widget)
end

function Layout.ReadUiOffset(widget)
    local x, y = readOffset(widget, "GetOffset")
    if x ~= nil and y ~= nil then
        return x, y
    end
    x, y = readOffset(widget, "GetEffectiveOffset")
    if x ~= nil and y ~= nil then
        local scale = readWidgetScale(widget)
        return Layout.ToUi(x) / scale, Layout.ToUi(y) / scale
    end
    return nil, nil
end

function Layout.ReadScreenOffset(widget)
    local x, y = readOffset(widget, "GetOffset")
    if x ~= nil and y ~= nil then
        return Layout.ToScreen(x), Layout.ToScreen(y)
    end
    x, y = readOffset(widget, "GetEffectiveOffset")
    if x ~= nil and y ~= nil then
        local scale = readWidgetScale(widget)
        return x / scale, y / scale
    end
    return nil, nil
end

function Layout.GetScreenSize(defaultWidth, defaultHeight)
    local width = readInterfaceNumber("GetScreenWidth") or readUiParentNumber("GetScreenWidth") or defaultWidth or 1920
    local height = readInterfaceNumber("GetScreenHeight") or readUiParentNumber("GetScreenHeight") or defaultHeight or 1080
    return width, height
end

function Layout.AnchorTopLeftScreen(widget, x, y, clearAnchors)
    if widget == nil or widget.AddAnchor == nil then
        return false
    end
    local uiX = Layout.ToUi(x)
    local uiY = Layout.ToUi(y)
    if clearAnchors ~= false and widget.RemoveAllAnchors ~= nil then
        pcall(function()
            widget:RemoveAllAnchors()
        end)
    end
    local ok = pcall(function()
        widget:AddAnchor("TOPLEFT", "UIParent", uiX, uiY)
    end)
    if ok then
        return true
    end
    ok = pcall(function()
        widget:AddAnchor("TOPLEFT", "UIParent", "TOPLEFT", uiX, uiY)
    end)
    if ok then
        return true
    end
    ok = pcall(function()
        widget:AddAnchor("TOPLEFT", uiX, uiY)
    end)
    return ok and true or false
end

function Layout.AnchorTopLeftUi(widget, x, y, clearAnchors)
    if widget == nil or widget.AddAnchor == nil then
        return false
    end
    if clearAnchors ~= false and widget.RemoveAllAnchors ~= nil then
        pcall(function()
            widget:RemoveAllAnchors()
        end)
    end
    local ok = pcall(function()
        widget:AddAnchor("TOPLEFT", "UIParent", tonumber(x) or 0, tonumber(y) or 0)
    end)
    if ok then
        return true
    end
    ok = pcall(function()
        widget:AddAnchor("TOPLEFT", "UIParent", "TOPLEFT", tonumber(x) or 0, tonumber(y) or 0)
    end)
    if ok then
        return true
    end
    ok = pcall(function()
        widget:AddAnchor("TOPLEFT", tonumber(x) or 0, tonumber(y) or 0)
    end)
    return ok and true or false
end

return Layout
