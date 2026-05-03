local Catalog = {}

local GLIDER_BOOST = {
    key = "glider_boost",
    label = "Boost",
    buff_ids = { 17314 },
    skill_ids = { 13435, 23040 },
    duration_ms = 60000,
    icon_type = "buff",
    icon_id = 17314,
    trigger = "glider_boost"
}

local GLIDER_DIVE = {
    key = "glider_dive",
    label = "Dive",
    buff_ids = { 685 },
    skill_ids = { 21297 },
    duration_ms = 15000,
    icon_type = "buff",
    icon_id = 685,
    trigger = "glider_dive"
}

local MOUNT_DASH = {
    key = "dash",
    label = "Dash",
    buff_ids = { 3523 },
    duration_ms = 30000,
    icon_type = "buff",
    icon_id = 51188
}

local function ability(base, extra)
    local out = {}
    if type(base) == "table" then
        for key, value in pairs(base) do
            out[key] = value
        end
    end
    if type(extra) == "table" then
        for key, value in pairs(extra) do
            out[key] = value
        end
    end
    return out
end

local function gliderAbilities(extra)
    local list = {
        ability(GLIDER_BOOST),
        ability(GLIDER_DIVE)
    }
    if type(extra) == "table" then
        for _, item in ipairs(extra) do
            list[#list + 1] = item
        end
    end
    return list
end

Catalog.DEVICES = {
    {
        key = "general_mount",
        name = "General Mount",
        kind = "Mount",
        summary = "Dash",
        abilities = { ability(MOUNT_DASH) }
    },
    {
        key = "kirin",
        name = "Kirin",
        kind = "Mount",
        summary = "Sprint",
        abilities = {
            {
                key = "kirin_sprint",
                label = "Sprint",
                buff_ids = { 21817 },
                duration_ms = 30000,
                icon_type = "item",
                icon_id = 43800
            }
        }
    },
    {
        key = "rajani",
        name = "Rajani",
        kind = "Mount",
        summary = "Sprint, Dash",
        abilities = {
            {
                key = "rajani_sprint",
                label = "Sprint",
                buff_ids = { 8000208 },
                duration_ms = 30000,
                icon_type = "buff",
                icon_id = 40003
            },
            {
                key = "rajani_dash",
                label = "Dash",
                buff_ids = { 8000211 },
                duration_ms = 60000,
                icon_type = "buff",
                icon_id = 3523
            }
        }
    },
    {
        key = "cloud_mount",
        name = "Cloud Mount",
        kind = "Mount",
        summary = "Cloud",
        abilities = {
            {
                key = "cloud",
                label = "Cloud",
                buff_ids = { 8000565 },
                duration_ms = 60000,
                icon_type = "item",
                icon_id = 43813
            }
        }
    },
    {
        key = "basic_glider",
        name = "Basic / Experimental Glider",
        kind = "Glider",
        summary = "Boost, Dive",
        item_ids = { 14677, 16392, 8000016 },
        abilities = gliderAbilities()
    },
    {
        key = "improved_glider",
        name = "Improved Glider",
        kind = "Glider",
        summary = "Boost, Dive",
        item_ids = { 23383 },
        abilities = gliderAbilities()
    },
    {
        key = "enhanced_glider",
        name = "Enhanced Glider",
        kind = "Glider",
        summary = "Boost, Dive",
        item_ids = { 23382 },
        abilities = gliderAbilities()
    },
    {
        key = "ultimate_glider",
        name = "Ultimate / Inheritor Glider",
        kind = "Glider",
        summary = "Boost, Dive",
        item_ids = { 23381, 27267 },
        abilities = gliderAbilities()
    },
    {
        key = "thunder_glider",
        name = "Thunder Glider",
        kind = "Glider",
        summary = "Boost, Dive",
        item_ids = { 23613, 28054 },
        abilities = gliderAbilities()
    },
    {
        key = "moonshadow_glider",
        name = "Moonshadow Glider",
        kind = "Glider",
        summary = "Boost, Dive",
        item_ids = { 23612 },
        abilities = gliderAbilities()
    },
    {
        key = "red_dragon_glider",
        name = "Red Dragon Glider",
        kind = "Glider",
        summary = "Boost, Dive",
        item_ids = { 18175, 28712 },
        abilities = gliderAbilities()
    },
    {
        key = "dragon_wings",
        name = "Dragon Wings",
        kind = "Glider",
        summary = "Boost, Dive",
        item_ids = { 28069, 29039 },
        abilities = gliderAbilities()
    },
    {
        key = "covenant_wings",
        name = "Covenant Wings",
        kind = "Glider",
        summary = "Boost, Dive",
        item_ids = { 25118, 25119, 25121 },
        abilities = gliderAbilities()
    },
    {
        key = "goblin_glider",
        name = "Goblin Glider",
        kind = "Glider",
        summary = "Boost, Dive",
        item_ids = { 26032, 27950 },
        abilities = gliderAbilities()
    },
    {
        key = "ultra_light_glider",
        name = "Ultra-Light Glider",
        kind = "Glider",
        summary = "Boost, Dive",
        item_ids = { 28887 },
        abilities = gliderAbilities()
    },
    {
        key = "magithopter",
        name = "Magithopter",
        kind = "Magithopter",
        summary = "Boost, Dive",
        abilities = gliderAbilities()
    },
    {
        key = "ezi_glider",
        name = "Ezi's Glider",
        kind = "Glider",
        summary = "Boost, Dive, Ezi",
        item_ids = { 18174 },
        abilities = gliderAbilities({
            {
                key = "ezi",
                label = "Ezi",
                buff_ids = { 8000165 },
                duration_ms = 60000,
                icon_type = "item",
                icon_id = 18174
            }
        })
    },
    {
        key = "sloth_glider",
        name = "Sloth Glider",
        kind = "Glider",
        summary = "Boost, Dive, Roll",
        item_ids = { 30621 },
        abilities = gliderAbilities({
            {
                key = "sloth_roll",
                label = "Roll",
                buff_ids = { 8000138 },
                duration_ms = 10000,
                icon_type = "item",
                icon_id = 30621
            }
        })
    },
    {
        key = "flamefeather_glider",
        name = "Flamefeather / Enhanced Flamefeather Glider",
        kind = "Glider",
        summary = "Boost, Dive, Glider Charge",
        item_ids = { 8001101, 8001102, 8001103, 8001104, 8001105, 8001106, 8001107, 8001108 },
        abilities = gliderAbilities({
            {
                key = "flamefeather",
                label = "Glider Charge",
                buff_ids = { 8000290 },
                duration_ms = 60000,
                icon_type = "buff",
                icon_id = 8000290
            }
        })
    },
    {
        key = "crystal_wings",
        name = "Crystal Wings",
        kind = "Glider",
        summary = "Boost, Dive, Crystal",
        abilities = gliderAbilities({
            {
                key = "crystal_wings",
                label = "Crystal",
                buff_ids = { 22123 },
                duration_ms = 30000,
                icon_type = "buff",
                icon_id = 22123
            }
        })
    },
    {
        key = "frozen_glider",
        name = "Frozen Glider",
        kind = "Glider",
        summary = "Boost, Dive, Frozen",
        abilities = gliderAbilities({
            {
                key = "frozen_glider",
                label = "Frozen",
                buff_ids = { 30300 },
                duration_ms = 60000,
                icon_type = "buff",
                icon_id = 30300,
                trigger = "frozen_glider"
            }
        })
    }
}

Catalog.BY_KEY = {}
for _, device in ipairs(Catalog.DEVICES) do
    Catalog.BY_KEY[device.key] = device
end

local function getConfig(config)
    if type(config) == "table" and type(config.mount_glider) == "table" then
        return config.mount_glider
    end
    return config
end

local function copyAbility(raw)
    if type(raw) ~= "table" or tostring(raw.key or "") == "" then
        return nil
    end
    local keyId = tonumber(string.match(tostring(raw.key or ""), "_(%d+)$"))
    if keyId ~= nil then
        keyId = math.floor(keyId + 0.5)
    end
    local out = {
        key = tostring(raw.key),
        label = tostring(raw.label or raw.key),
        duration_ms = tonumber(raw.duration_ms) or 60000,
        icon_type = tostring(raw.icon_type or "buff"),
        icon_id = tonumber(raw.icon_id),
        icon_path = type(raw.icon_path) == "string" and raw.icon_path or nil,
        exact_spell_id = raw.exact_spell_id == true,
        learned = raw.learned == true,
        device_trigger = raw.device_trigger == true or raw.manual_trigger == true
    }
    if tonumber(raw.spell_id) ~= nil then
        out.spell_id = math.floor(tonumber(raw.spell_id) + 0.5)
        out.exact_spell_id = true
    end
    if tonumber(raw.mount_mana_spent) ~= nil then
        out.mount_mana_spent = math.floor(tonumber(raw.mount_mana_spent) + 0.5)
    end
    if type(raw.buff_ids) == "table" then
        out.buff_ids = {}
        for _, id in ipairs(raw.buff_ids) do
            local n = tonumber(id)
            if n ~= nil then
                out.buff_ids[#out.buff_ids + 1] = math.floor(n + 0.5)
            end
        end
    elseif tonumber(raw.buff_id) ~= nil then
        out.buff_ids = { math.floor(tonumber(raw.buff_id) + 0.5) }
    end
    if out.spell_id ~= nil then
        out.buff_ids = { out.spell_id }
        out.icon_id = out.spell_id
        out.icon_type = "buff"
    end
    if out.icon_id == nil and type(out.buff_ids) == "table" then
        out.icon_id = out.buff_ids[1]
    end
    if type(out.buff_ids) == "table" and #out.buff_ids > 1 and out.exact_spell_id then
        out.buff_ids = { out.buff_ids[1] }
    end
    if out.learned == true
        and out.icon_type == "buff"
        and keyId ~= nil
        and (out.spell_id ~= nil or type(out.buff_ids) == "table") then
        out.spell_id = keyId
        out.buff_ids = { keyId }
        out.icon_id = keyId
        out.exact_spell_id = true
    end
    return out
end

local function copyLearnedDevice(raw)
    if type(raw) ~= "table" or tostring(raw.key or "") == "" then
        return nil
    end
    local device = {
        key = tostring(raw.key),
        name = tostring(raw.name or "Learned Glider"),
        kind = tostring(raw.kind or "Glider"),
        summary = tostring(raw.summary or ""),
        learned = true,
        icon_path = type(raw.icon_path) == "string" and raw.icon_path or nil,
        item_ids = {},
        abilities = {}
    }
    if type(raw.item_ids) == "table" then
        for _, id in ipairs(raw.item_ids) do
            local n = tonumber(id)
            if n ~= nil then
                device.item_ids[#device.item_ids + 1] = math.floor(n + 0.5)
            end
        end
    elseif tonumber(raw.item_id) ~= nil then
        device.item_ids[1] = math.floor(tonumber(raw.item_id) + 0.5)
    end
    local keyItemId = tonumber(string.match(tostring(raw.key or ""), "^learned_glider_(%d+)$"))
    if keyItemId ~= nil then
        device.item_ids = { math.floor(keyItemId + 0.5) }
    end
    for _, abilityDef in ipairs(raw.abilities or {}) do
        local copied = copyAbility(abilityDef)
        if copied ~= nil then
            copied.learned = true
            copied.exact_spell_id = true
            if copied.spell_id == nil and type(copied.buff_ids) == "table" then
                copied.spell_id = copied.buff_ids[1]
            end
            if copied.spell_id ~= nil then
                copied.buff_ids = { copied.spell_id }
                copied.icon_id = copied.spell_id
                copied.icon_type = "buff"
            end
            device.abilities[#device.abilities + 1] = copied
        end
    end
    if device.summary == "" then
        local labels = {}
        for _, abilityDef in ipairs(device.abilities) do
            labels[#labels + 1] = tostring(abilityDef.label or abilityDef.key)
        end
        device.summary = table.concat(labels, ", ")
    end
    if #device.abilities == 0 then
        return nil
    end
    return device
end

local function getLearnedDevices(config)
    local cfg = getConfig(config)
    local out = {}
    if type(cfg) ~= "table" then
        return out
    end

    local function appendLearned(list)
        for _, raw in ipairs(list or {}) do
            local device = copyLearnedDevice(raw)
            if device ~= nil then
                out[#out + 1] = device
            end
        end
    end
    appendLearned(type(cfg.learned_mounts) == "table" and cfg.learned_mounts or {})
    appendLearned(type(cfg.learned_gliders) == "table" and cfg.learned_gliders or {})
    return out
end

local function includeStaticDevice(device)
    return false
end

function Catalog.GetDevices(config)
    local out = {}
    for _, device in ipairs(Catalog.DEVICES) do
        if includeStaticDevice(device) then
            out[#out + 1] = device
        end
    end
    for _, device in ipairs(getLearnedDevices(config)) do
        out[#out + 1] = device
    end
    return out
end

function Catalog.GetDevice(key, config)
    key = tostring(key or "")
    local staticDevice = Catalog.BY_KEY[key]
    if includeStaticDevice(staticDevice) then
        return staticDevice
    end
    for _, device in ipairs(getLearnedDevices(config)) do
        if device.key == key then
            return device
        end
    end
    return nil
end

function Catalog.GetMountDevices(config)
    local out = {}
    for _, device in ipairs(Catalog.GetDevices(config)) do
        if device.kind == "Mount" then
            out[#out + 1] = device
        end
    end
    return out
end

function Catalog.GetGliderDevices(config)
    local out = {}
    for _, device in ipairs(Catalog.GetDevices(config)) do
        if device.kind ~= "Mount" then
            out[#out + 1] = device
        end
    end
    return out
end

function Catalog.HasSelectedAbility(selectedAbilities, device)
    if type(selectedAbilities) ~= "table" or type(device) ~= "table" or type(device.abilities) ~= "table" then
        return false
    end
    local deviceAbilities = selectedAbilities[device.key]
    if type(deviceAbilities) ~= "table" then
        return false
    end
    for _, ability in ipairs(device.abilities) do
        if deviceAbilities[ability.key] == true then
            return true
        end
    end
    return false
end

function Catalog.GetSelectedDevices(selected)
    local out = {}
    if type(selected) ~= "table" then
        return out
    end
    for _, device in ipairs(Catalog.GetDevices()) do
        if selected[device.key] == true then
            out[#out + 1] = device
        end
    end
    return out
end

function Catalog.CountSelected(selected)
    local count = 0
    if type(selected) == "table" then
        for _, device in ipairs(Catalog.GetDevices()) do
            if selected[device.key] == true then
                count = count + 1
            end
        end
    end
    return count
end

function Catalog.EnsureAbilitySelection(selectedAbilities, device)
    if type(selectedAbilities) ~= "table" or type(device) ~= "table" or type(device.abilities) ~= "table" then
        return
    end
    if type(selectedAbilities[device.key]) == "table" then
        return
    end
    selectedAbilities[device.key] = {}
    for _, ability in ipairs(device.abilities) do
        selectedAbilities[device.key][ability.key] = true
    end
end

function Catalog.IsAbilitySelected(selectedAbilities, device, ability)
    if type(device) ~= "table" or type(ability) ~= "table" then
        return false
    end
    if type(selectedAbilities) ~= "table" then
        return true
    end
    local deviceAbilities = selectedAbilities[device.key]
    if type(deviceAbilities) ~= "table" then
        return true
    end
    return deviceAbilities[ability.key] == true
end

return Catalog
