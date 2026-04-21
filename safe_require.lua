local Require = require("nuzi-core/require")

local function SafeRequire(primary, secondary)
    local mod = Require.WithDotFallback(primary, secondary)
    return mod
end

return SafeRequire
