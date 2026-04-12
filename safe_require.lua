local function SafeRequire(primary, secondary)
    local ok, mod = pcall(require, primary)
    if ok then
        return mod
    end

    if secondary ~= nil then
        ok, mod = pcall(require, secondary)
        if ok then
            return mod
        end
    elseif type(primary) == "string" and string.find(primary, "/", 1, true) ~= nil then
        local dotted = string.gsub(primary, "/", ".")
        ok, mod = pcall(require, dotted)
        if ok then
            return mod
        end
    end

    return nil
end

return SafeRequire
